import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/core/network/api_client.dart';
import 'package:flutter_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_mobile/features/explore/data/repositories/facility_repository.dart';
import 'package:flutter_mobile/features/payments/application/payment_status_tracker.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_mobile/features/reservations/data/repositories/reservation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secrets;
  setUp(() {
    secrets = {};
    FlutterSecureStorage.setMockInitialValues(secrets);
  });

  Dio mockDio(ResponseBody Function(RequestOptions) respond) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.httpClientAdapter = _MockAdapter(respond);
    return dio;
  }

  test('login stores tokens; restore calls /auth/me and accepts current user', () async {
    final dio = mockDio((options) => ResponseBody.fromString(jsonEncode(
      options.path == '/auth/login'
          ? {'data': {'user': {'id': 'u1', 'name': 'Test', 'email': 't@example.test', 'role': 'customer'}, 'tokens': {'accessToken': 'access-1', 'refreshToken': 'refresh-1'}}}
          : {'data': {'id': 'u1', 'name': 'Test', 'email': 't@example.test', 'role': 'customer'}},
    ), 200, headers: {Headers.contentTypeHeader: ['application/json']}));
    final client = ApiClient(dio: dio);
    final repo = AuthRepository(dio, client);
    expect((await repo.login('t@example.test', 'password')).id, 'u1');
    expect(await client.accessToken, 'access-1');
    expect((await repo.restore())?.email, 't@example.test');
  });

  test('failed session restoration clears an expired session', () async {
    final dio = mockDio((options) => ResponseBody.fromString('{}', 401,
      headers: {Headers.contentTypeHeader: ['application/json']}));
    final client = ApiClient(dio: dio);
    await client.saveTokens({'accessToken': 'expired', 'refreshToken': 'old'});
    expect(await AuthRepository(dio, client).restore(), isNull);
    expect(await client.accessToken, isNull);
    expect(await client.refreshToken, isNull);
  });

  test('401 response refreshes once and retries with new bearer token', () async {
    var protectedCalls = 0;
    final dio = mockDio((options) {
      if (options.path == '/auth/refresh') {
        return ResponseBody.fromString(jsonEncode({'data': {'accessToken': 'new-access', 'refreshToken': 'new-refresh'}}), 200,
          headers: {Headers.contentTypeHeader: ['application/json']});
      }
      protectedCalls++;
      if (options.headers['Authorization'] == 'Bearer new-access') {
        return ResponseBody.fromString('{"data":{}}', 200,
          headers: {Headers.contentTypeHeader: ['application/json']});
      }
      return ResponseBody.fromString('{}', 401,
        headers: {Headers.contentTypeHeader: ['application/json']});
    });
    final client = ApiClient(dio: dio);
    await client.saveTokens({'accessToken': 'old-access', 'refreshToken': 'refresh'});
    await dio.get('/profile/me');
    expect(protectedCalls, 2);
    expect(await client.accessToken, 'new-access');
  });

  test('facility listing passes search and city filters and parses empty results', () async {
    RequestOptions? seen;
    final dio = mockDio((options) { seen = options; return ResponseBody.fromString('{"data":{"items":[]}}', 200, headers: {Headers.contentTypeHeader: ['application/json']}); });
    expect(await FacilityRepository(dio).search(search: '  North ', city: 'Hanoi'), isEmpty);
    expect(seen?.queryParameters['search'], 'North');
    expect(seen?.queryParameters['city'], 'Hanoi');
    expect(seen?.queryParameters['status'], 'active');
  });

  test('reservation request includes physical unit, date-only and selected slot', () async {
    RequestOptions? seen;
    final dio = mockDio((options) { seen = options; return ResponseBody.fromString(jsonEncode({'data': {
        'id': 'r1', 'reservationCode': 'R1', 'customerId': 'c1', 'facilityId': 'f1',
        'facilityUnitTypeOfferingId': 'o1', 'storageUnitId': 'u1',
        'checkInDate': '2026-12-03', 'checkInTimeSlot': 'Morning',
        'startDate': '2026-12-03', 'rentalDuration': 2, 'billingUnit': 'month',
        'basePrice': 10, 'depositAmount': 10, 'totalAmount': 20, 'status': 'pending_payment',
        'refundAmount': 0, 'createdAt': '2026-10-22T00:00:00Z', 'updatedAt': '2026-10-22T00:00:00Z'
      }}), 200, headers: {Headers.contentTypeHeader: ['application/json']}); });
    final date = DateTime(2026, 12, 3, 17, 45);
    await ReservationRepository(dio).create(
      facilityId: 'f1', storageUnitId: 'u1', checkInDate: date,
      checkInTimeSlot: 'Morning', rentalDuration: 2, facilityUnitTypeOfferingId: 'o1',
    );
    expect(seen?.data, containsPair('storageUnitId', 'u1'));
    expect(seen?.data, containsPair('checkInDate', '2026-12-03'));
    expect(seen?.data, containsPair('checkInTimeSlot', 'Morning'));
  });

  test('reservation rejects missing required identifiers and past date locally', () async {
    final repo = ReservationRepository(mockDio((options) => ResponseBody.fromString('{}', 200)));
    Future<void> create({String unit = 'u', String offering = 'o', DateTime? date}) => repo.create(
      facilityId: 'f', storageUnitId: unit, checkInDate: date ?? DateTime.now().add(const Duration(days: 1)),
      checkInTimeSlot: 'Morning', rentalDuration: 1, facilityUnitTypeOfferingId: offering,
    );
    await expectLater(create(unit: ''), throwsArgumentError);
    await expectLater(create(offering: ''), throwsArgumentError);
    await expectLater(create(date: DateTime(2000)), throwsArgumentError);
  });

  test('payment session request parses backend QR and amount', () async {
    RequestOptions? seen;
    final dio = mockDio((options) { seen = options; return ResponseBody.fromString(jsonEncode({'data': {
        'id': 'p1', 'paymentCode': 'PAY1', 'purpose': 'reservation_deposit',
        'reservationId': 'r1', 'amount': 250, 'paidAmount': 0, 'status': 'pending',
        'method': 'sepay_qr', 'qrUrl': 'https://bank.test/qr',
        'createdAt': '2026-10-22T00:00:00Z', 'updatedAt': '2026-10-22T00:00:00Z'
      }}), 200, headers: {Headers.contentTypeHeader: ['application/json']}); });
    final payment = await PaymentRepository(dio).createReservationDeposit('r1');
    expect(seen?.data, containsPair('purpose', 'reservation_deposit'));
    expect(payment.qrUrl, 'https://bank.test/qr');
    expect(payment.amount, 250);
  });

  test('payment tracker reports timeout and supports cancellation', () async {
    var calls = 0;
    final dio = mockDio((options) { calls++; return ResponseBody.fromString(jsonEncode({'data': {
        'id': 'p1', 'paymentCode': 'PAY1', 'purpose': 'reservation_deposit',
        'amount': 250, 'paidAmount': 0, 'status': 'pending', 'method': 'sepay_qr',
        'createdAt': '2026-10-22T00:00:00Z', 'updatedAt': '2026-10-22T00:00:00Z'
      }}), 200, headers: {Headers.contentTypeHeader: ['application/json']}); });
    final tracker = PaymentStatusTracker(PaymentRepository(dio), interval: Duration.zero, maxAttempts: 2);
    final timedOut = Completer<void>();
    final timeoutSubscription = tracker.watch('p1').listen((event) {
      if (event is PaymentPollTimeout && !timedOut.isCompleted) timedOut.complete();
    });
    await timedOut.future.timeout(const Duration(seconds: 2));
    await timeoutSubscription.cancel();
    expect(calls, 2);

    calls = 0;
    final subscription = tracker.watch('p1').listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await subscription.cancel();
    final stoppedAt = calls;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, stoppedAt);
  });

  test('API error exposes backend message and status code', () {
    final error = ApiClient.normalize(DioException(
      requestOptions: RequestOptions(path: '/reservations'),
      response: Response(requestOptions: RequestOptions(path: '/reservations'), statusCode: 409, data: {'message': 'Unit conflict', 'messageCode': 'CONFLICT'}),
      type: DioExceptionType.badResponse,
    ));
    expect(error.toString(), contains('Unit conflict'));
    expect((error as dynamic).statusCode, 409);
  });

  test('terminal payment statuses reflect backend state transitions', () {
    Payment from(String status) => Payment.fromJson({
      'id': 'p', 'paymentCode': 'P', 'purpose': 'reservation_deposit', 'amount': 1,
      'paidAmount': 0, 'status': status, 'method': 'sepay_qr',
      'createdAt': '2026-10-22T00:00:00Z', 'updatedAt': '2026-10-22T00:00:00Z',
    });
    expect(from('pending').isTerminal, isFalse);
    expect(from('paid').isTerminal, isTrue);
    expect(from('failed').isTerminal, isFalse);
    expect(from('expired').isTerminal, isTrue);
  });
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => respond(options);
  @override
  void close({bool force = false}) {}
}
