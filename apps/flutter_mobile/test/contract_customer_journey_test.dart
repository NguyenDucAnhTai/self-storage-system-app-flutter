import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/core/theme/app_theme.dart';
import 'package:flutter_mobile/features/contracts/data/contract_repository.dart';
import 'package:flutter_mobile/features/contracts/presentation/contract_detail_screen.dart';
import 'package:flutter_mobile/features/payments/application/payment_status_tracker.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_mobile/features/payments/presentation/screens/payment_screen.dart';

void main() {
  group('ContractDetailScreen customer journey', () {
    test(
      'contract detail keeps authoritative fields from the data envelope',
      () async {
        final fixture = _backendActiveContract();
        final adapter = _SigningAdapter()..contractResponse = fixture;
        final result = await ContractRepository(_dio(adapter))
            .detail(fixture['id'] as String);
        expect(result['depositPaidAt'], fixture['depositPaidAt']);
        expect(result['depositAmount'], 9400);
        expect(result['actualCheckInDate'], fixture['actualCheckInDate']);
        expect(result['firstPeriodPaidAt'], fixture['firstPeriodPaidAt']);
        expect(result['storageUnit'], fixture['storageUnit']);
      },
    );

    testWidgets(
      'signed draft shows signed state and never offers signing again',
      (tester) async {
        _useTallViewport(tester);
        final contract = _baseContract()
          ..['customerSigned'] = true
          ..['customerSignedAt'] = '2026-10-31T08:00:00.000Z';
        await tester.pumpWidget(_app(contract, _SigningAdapter()));
        await tester.pumpAndSettle();

        expect(find.text('Bạn đã ký hợp đồng'), findsWidgets);
        expect(find.textContaining('Đã xác nhận lúc'), findsOneWidget);
        expect(
          find.text('Chờ nhân viên hoàn tất thủ tục nhận kho.'),
          findsOneWidget,
        );
        expect(find.text('Xem điều khoản và ký'), findsNothing);
        expect(find.text('Xác nhận ký'), findsNothing);
      },
    );

    testWidgets(
      'failed sign reconciles with GET and displays confirmed signed state',
      (tester) async {
        _useTallViewport(tester);
        final adapter = _SigningAdapter(signFails: true);
        final contract = _baseContract();
        await tester.pumpWidget(_app(contract, adapter, pushDetail: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Xem điều khoản và ký'));
        await tester.pumpAndSettle();
        expect(find.text('Điều khoản do máy chủ cung cấp:'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận ký'),
              )
              .onPressed,
          isNull,
        );
        expect(adapter.postCalls, 0);
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.text('Xác nhận ký'));
        await tester.pumpAndSettle();

        expect(adapter.postCalls, 1);
        expect(adapter.getCalls, 1);
        expect(find.text('Returned: signed'), findsOneWidget);
        expect(find.text('Xem điều khoản và ký'), findsNothing);
      },
    );

    testWidgets(
      'does not create a payment when no manager-created request is listed',
      (tester) async {
        _useTallViewport(tester);
        final contract = _baseContract()
          ..['customerSigned'] = true
          ..['staffSigned'] = false
          ..['firstPeriodRentPaid'] = false;
        final adapter = _SigningAdapter();
        await tester.pumpWidget(_app(contract, adapter));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(FilledButton, 'Thanh toán tiền thuê kỳ đầu'),
          findsNothing,
        );
        expect(find.text('Chưa có yêu cầu thanh toán kỳ đầu.'), findsOneWidget);
        expect(adapter.postCalls, 0);
        expect(
          find.text('Chờ nhân viên hoàn tất thủ tục nhận kho.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'missing backend data is called out and progress remains unknown',
      (tester) async {
        _useTallViewport(tester);
        final contract = <String, dynamic>{
          'id': '111111111111111111111111',
          'contractCode': 'CTR-123',
          'status': 'draft',
          'customerSigned': false,
          'staffSigned': false,
        };
        await tester.pumpWidget(_app(contract, _SigningAdapter()));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Chưa có dữ liệu tiền cọc từ máy chủ'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Chưa có dữ liệu thanh toán kỳ đầu từ máy chủ'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Chưa có xác nhận nhận kho thực tế từ máy chủ'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Chưa thể ký vì nội dung điều khoản chưa được cung cấp.',
          ),
          findsOneWidget,
        );
        expect(find.text('Xem điều khoản và ký'), findsNothing);
      },
    );

    testWidgets('loads genuine terms from the server before exposing signing', (
      tester,
    ) async {
      _useTallViewport(tester);
      final contract = _baseContract()..remove('terms');
      final adapter = _SigningAdapter();
      await tester.pumpWidget(_app(contract, adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tải điều khoản từ máy chủ'));
      await tester.pumpAndSettle();
      expect(adapter.termsGetCalls, 1);
      await tester.tap(find.text('Xem điều khoản và ký'));
      await tester.pumpAndSettle();
      expect(find.text('Điều khoản thật do máy chủ trả về.'), findsOneWidget);
    });

    testWidgets(
      'timeline displays backend payment, signature and check-in states',
      (tester) async {
        _useTallViewport(tester);
        final contract = _baseContract()
          ..['depositPaid'] = true
          ..['firstPeriodRentPaid'] = true
          ..['customerSigned'] = true
          ..['staffSigned'] = true
          ..['actualCheckInDate'] = '2026-11-01T17:00:00.000Z'
          ..['status'] = 'active';
        await tester.pumpWidget(_app(contract, _SigningAdapter()));
        await tester.pumpAndSettle();

        expect(
          find.text('Máy chủ xác nhận đã thanh toán tiền cọc'),
          findsOneWidget,
        );
        expect(find.text('Hợp đồng đang hoạt động.'), findsOneWidget);
        expect(
          find.textContaining('Chưa thể xác nhận đã bàn giao thực tế'),
          findsOneWidget,
        );
      },
    );

    testWidgets('detail layout remains valid at 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_baseContract(), _SigningAdapter()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'manager-created pending payment appears and opens its exact ID',
      (tester) async {
        _useTallViewport(tester);
        final adapter = _SigningAdapter()..payments = [_paymentJson()];
        Payment? opened;
        await tester.pumpWidget(
          _app(
            _baseContract(),
            adapter,
            onPaymentViewed: (payment) async {
              opened = payment;
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(adapter.paymentListCalls, 1);
        expect(adapter.postCalls, 0);
        expect(
          adapter.paymentListQueries.single,
          containsPair('contractId', '111111111111111111111111'),
        );
        expect(
          adapter.paymentListQueries.single,
          containsPair('purpose', 'rent_first_period'),
        );
        expect(find.text('Chờ thanh toán'), findsOneWidget);
        expect(find.text('SSM74D3K9H7'), findsOneWidget);
        expect(find.textContaining('9.400'), findsOneWidget);

        await tester.tap(find.text('Xem QR thanh toán'));
        await tester.pumpAndSettle();
        expect(opened?.id, '222222222222222222222222');
        expect(adapter.postCalls, 0);
      },
    );

    testWidgets(
      'existing payment screen uses GET only and verifies contract linkage',
      (tester) async {
        _useTallViewport(tester);
        final adapter = _SigningAdapter()..paymentDetail = _paymentJson();
        final dio = _dio(adapter);
        final repository = PaymentRepository(dio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: PaymentScreen(
              existingPaymentId: '222222222222222222222222',
              expectedContractId: '111111111111111111111111',
              repository: repository,
              tracker: PaymentStatusTracker(repository),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(adapter.paymentDetailCalls, 1);
        expect(adapter.postCalls, 0);
        expect(adapter.requestMethods, ['GET']);
        expect(find.text('Chi tiết thanh toán'), findsOneWidget);
        expect(find.text('SSM74D3K9H7'), findsNWidgets(2));
        expect(find.text('Tạo lại phiên thanh toán'), findsNothing);
      },
    );

    testWidgets('existing payment from another contract is not displayed', (
      tester,
    ) async {
      _useTallViewport(tester);
      final adapter = _SigningAdapter()
        ..paymentDetail = _paymentJson(contractId: '333333333333333333333333');
      final dio = _dio(adapter);
      final repository = PaymentRepository(dio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PaymentScreen(
            existingPaymentId: '222222222222222222222222',
            expectedContractId: '111111111111111111111111',
            repository: repository,
            tracker: PaymentStatusTracker(repository),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Không thể tải khoản thanh toán này'),
        findsOneWidget,
      );
      expect(find.text('SSM74D3K9H7'), findsNothing);
      expect(adapter.postCalls, 0);
    });

    testWidgets(
      'payment read errors stay distinct from no request and can retry',
      (tester) async {
        _useTallViewport(tester);
        final adapter = _SigningAdapter(failPaymentList: true);
        await tester.pumpWidget(_app(_baseContract(), adapter));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Không thể tải khoản thanh toán'),
          findsOneWidget,
        );
        expect(find.text('Chưa có yêu cầu thanh toán kỳ đầu.'), findsNothing);
        adapter.failPaymentList = false;
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        expect(adapter.paymentListCalls, 2);
        expect(find.text('Chưa có yêu cầu thanh toán kỳ đầu.'), findsOneWidget);
        expect(adapter.postCalls, 0);
      },
    );

    testWidgets(
      'paid, expired and cancelled payments use backend states without renewal CTA',
      (tester) async {
        _useTallViewport(tester);
        final adapter = _SigningAdapter();
        for (final status in ['paid', 'expired', 'cancelled']) {
          adapter.payments = [_paymentJson(status: status)];
          await tester.pumpWidget(
            _app(_baseContract(), adapter, key: ValueKey(status)),
          );
          await tester.pumpAndSettle();
          final expectedLabel = switch (status) {
            'paid' => 'Đã thanh toán',
            'expired' => 'Đã hết hạn',
            _ => 'Đã hủy',
          };
          expect(find.text(expectedLabel), findsOneWidget);
          expect(find.text('Xem QR thanh toán'), findsNothing);
          expect(find.text('Tạo lại phiên thanh toán'), findsNothing);
        }
        expect(adapter.postCalls, 0);
      },
    );

    testWidgets('refresh re-reads payment list and updates contract progress', (
      tester,
    ) async {
      _useTallViewport(tester);
      final adapter = _SigningAdapter()..payments = [_paymentJson()];
      await tester.pumpWidget(_app(_baseContract(), adapter));
      await tester.pumpAndSettle();
      expect(find.text('Chờ thanh toán'), findsOneWidget);

      adapter.payments = [_paymentJson(status: 'paid')];
      await tester.tap(find.byTooltip('Tải lại trạng thái'));
      await tester.pumpAndSettle();

      expect(adapter.paymentListCalls, 2);
      expect(find.text('Đã thanh toán'), findsOneWidget);
      expect(adapter.postCalls, 0);
    });

    testWidgets('maps authoritative active contract response timestamps', (
      tester,
    ) async {
      _useTallViewport(tester);
      final fixture = _backendActiveContract();
      final adapter = _SigningAdapter()
        ..contractResponse = fixture
        ..payments = [_paymentJson(status: 'pending')];

      await tester.pumpWidget(_app(fixture, adapter));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đã thanh toán tiền cọc · 9.400 ₫'),
        findsOneWidget,
      );
      expect(find.textContaining('11:58 31/10/2026'), findsOneWidget);
      expect(find.textContaining('12:17 31/10/2026'), findsOneWidget);
      expect(find.textContaining('12:38 31/10/2026'), findsNWidgets(2));
      expect(find.textContaining('12:46 31/10/2026'), findsOneWidget);
      expect(find.textContaining('07:30 02/11/2026'), findsOneWidget);
      expect(
        find.textContaining('Chưa thể xác nhận đã bàn giao thực tế'),
        findsOneWidget,
      );
      expect(find.text('Đang hoạt động'), findsOneWidget);
      expect(find.text('Đang có khách thuê'), findsOneWidget);
      expect(find.text('Chờ thanh toán'), findsNothing);
      expect(find.text('Xem QR thanh toán'), findsNothing);
      expect(find.textContaining('Chưa có dữ liệu tiền cọc'), findsNothing);
      expect(
        find.textContaining('Chưa có xác nhận nhận kho thực tế'),
        findsNothing,
      );
    });

    testWidgets(
      'refresh replaces old timeline values with latest contract data',
      (tester) async {
        _useTallViewport(tester);
        final adapter = _SigningAdapter();
        final initial = _baseContract()
          ..['customerSigned'] = true
          ..['staffSigned'] = true
          ..['status'] = 'draft';
        await tester.pumpWidget(_app(initial, adapter));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa có dữ liệu tiền cọc'), findsOneWidget);

        adapter.contractResponse = _backendActiveContract();
        adapter.payments = [_paymentJson(status: 'paid')];
        await tester.tap(find.byTooltip('Tải lại trạng thái'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Đã thanh toán tiền cọc · 9.400 ₫'),
          findsOneWidget,
        );
        expect(find.text('Đang hoạt động'), findsOneWidget);
        expect(find.textContaining('Chưa có dữ liệu tiền cọc'), findsNothing);
      },
    );
  });
}

Widget _app(
  Map<String, dynamic> contract,
  _SigningAdapter adapter, {
  bool pushDetail = false,
  Key? key,
  Future<void> Function(Payment)? onPaymentViewed,
}) => MaterialApp(
  key: key,
  theme: AppTheme.light,
  home: Builder(
    builder: (context) {
      final dio = _dio(adapter);
      final detail = ContractDetailScreen(
        contract: contract,
        repository: ContractRepository(dio),
        paymentRepository: PaymentRepository(dio),
        onViewPayment: onPaymentViewed ?? (_) async {},
      );
      return pushDetail ? _DetailRouteHost(detail: detail) : detail;
    },
  ),
);

class _DetailRouteHost extends StatefulWidget {
  const _DetailRouteHost({required this.detail});
  final Widget detail;
  @override
  State<_DetailRouteHost> createState() => _DetailRouteHostState();
}

class _DetailRouteHostState extends State<_DetailRouteHost> {
  String _result = 'Waiting';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => widget.detail));
      if (mounted) {
        setState(() => _result = result == true ? 'signed' : 'not signed');
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Returned: $_result')));
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> _baseContract() => {
  'id': '111111111111111111111111',
  'contractCode': 'CTR-123',
  'status': 'draft',
  'facility': {'name': 'Cơ sở thử nghiệm'},
  'storageUnit': {'unitNumber': 'A-201'},
  'startDate': '2026-11-01T17:00:00.000Z',
  'endDate': '2027-11-01T17:00:00.000Z',
  'rentalPrice': 1200000,
  'billingUnit': 'month',
  'customerSigned': false,
  'staffSigned': false,
  'terms': 'Điều khoản được trả về bởi máy chủ.',
};

Dio _dio(_SigningAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
  dio.httpClientAdapter = adapter;
  return dio;
}

class _SigningAdapter implements HttpClientAdapter {
  _SigningAdapter({this.signFails = false, this.failPaymentList = false});
  final bool signFails;
  bool failPaymentList;
  Map<String, dynamic>? contractResponse;
  List<Map<String, dynamic>> payments = [];
  Map<String, dynamic>? paymentDetail;
  int postCalls = 0;
  int getCalls = 0;
  int termsGetCalls = 0;
  int paymentListCalls = 0;
  int paymentDetailCalls = 0;
  final List<String> requestMethods = [];
  final List<Map<String, dynamic>> paymentListQueries = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestMethods.add(options.method);
    if (options.method == 'POST') {
      postCalls++;
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'messageCode': 'MESSAGE_CODE_TEST'}),
        signFails ? 400 : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path.endsWith('/draft-pdf')) {
      termsGetCalls++;
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {
            'html': '<html><body><p>Điều khoản thật do máy chủ trả về.</p></body></html>',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/payments') {
      paymentListCalls++;
      paymentListQueries.add(
        Map<String, dynamic>.from(options.queryParameters),
      );
      if (failPaymentList) {
        return ResponseBody.fromString(
          jsonEncode({'success': false, 'message': 'unavailable'}),
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {
            'items': payments,
            'pagination': {'totalPages': 1},
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path.startsWith('/payments/')) {
      paymentDetailCalls++;
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'data': paymentDetail ?? payments.first}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    getCalls++;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data':
            contractResponse ?? (_baseContract()..['customerSigned'] = true),
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _paymentJson({
  String id = '222222222222222222222222',
  String status = 'pending',
  String contractId = '111111111111111111111111',
  double amount = 9400,
}) => {
  'id': id,
  'paymentCode': 'SSM74D3K9H7',
  'purpose': 'rent_first_period',
  'reservationId': null,
  'contractId': contractId,
  'amount': amount,
  'paidAmount': status == 'paid' ? amount : 0,
  'status': status,
  'method': 'sepay_qr',
  'qrUrl': 'https://example.invalid/qr.png',
  'bankInfo': {
    'bankCode': 'TEST',
    'accountNumber': '0000000000',
    'accountName': 'TEST',
  },
  'expiresAt': status == 'pending'
      ? DateTime.now().add(const Duration(hours: 2)).toIso8601String()
      : null,
  'paidAt': status == 'paid' ? '2026-10-31T12:00:00.000Z' : null,
  'confirmedAt': null,
  'referenceCode': 'SSM74D3K9H7',
  'createdAt': '2026-10-31T10:00:00.000Z',
  'updatedAt': '2026-10-31T10:00:00.000Z',
};

Map<String, dynamic> _backendActiveContract() => {
  'id': '111111111111111111111111',
  'contractCode': 'CTR-FIXTURE-001',
  'status': 'active',
  'depositAmount': 9400,
  'depositPaidAt': '2026-10-31T04:58:29.315Z',
  'depositPaymentId': '333333333333333333333333',
  'customerSigned': true,
  'customerSignedAt': '2026-10-31T05:17:39.099Z',
  'firstPeriodPaidAt': '2026-10-31T05:38:56.918Z',
  'firstPeriodPaymentId': '222222222222222222222222',
  'staffSigned': true,
  'staffSignedAt': '2026-10-31T05:46:32.381Z',
  'actualCheckInDate': '2026-11-02T00:30:00.000Z',
  'facility': {'name': 'Cơ sở thử nghiệm'},
  'storageUnit': {'unitNumber': 'A-201', 'status': 'occupied'},
  'startDate': '2026-11-01T17:00:00.000Z',
  'endDate': '2027-11-01T17:00:00.000Z',
  'rentalPrice': 1200000,
  'billingUnit': 'month',
};
