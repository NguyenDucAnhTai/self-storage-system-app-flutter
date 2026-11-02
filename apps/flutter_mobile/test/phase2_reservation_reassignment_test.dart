import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';
import 'package:flutter_mobile/features/reservations/data/repositories/reservation_repository.dart';
import 'package:flutter_mobile/features/reservations/presentation/screens/reservation_detail_screen.dart';

void main() {
  test('reservation DTO parses pending proposal and change history', () {
    final r = Reservation.fromJson(_reservation(pending: true));
    expect(r.pendingUnitChange?.newStorageUnit?['unitNumber'], 'B-202');
    expect(r.pendingUnitChange?.priceDifference, 12000);
    expect(r.unitChangeHistory.single.status, 'pending');
  });

  test(
    'respond-reassign sends verified action and optional rejectReason',
    () async {
      RequestOptions? seen;
      final dio = _dio((options) {
        seen = options;
        return {'data': _reservation(pending: false)};
      });
      final repo = ReservationRepository(dio);
      await repo.respondUnitReassign(
        '0123456789abcdef01234567',
        action: 'reject',
        rejectReason: 'Không phù hợp',
      );
      expect(seen?.method, 'POST');
      expect(
        seen?.path,
        '/reservations/0123456789abcdef01234567/respond-reassign',
      );
      expect(seen?.data, {'action': 'reject', 'rejectReason': 'Không phù hợp'});
    },
  );

  testWidgets(
    'no pending proposal means no reassignment controls or mutation',
    (tester) async {
      var postCalls = 0;
      final dio = _dio((options) {
        if (options.method == 'POST') postCalls++;
        return {'data': _reservation(pending: false)};
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationDetailScreen(
            reservationId: '0123456789abcdef01234567',
            repository: ReservationRepository(dio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đề xuất đổi phòng kho'), findsNothing);
      expect(find.text('Chấp nhận đổi kho'), findsNothing);
      expect(postCalls, 0);
    },
  );

  testWidgets(
    'pending proposal is shown but requires explicit customer action',
    (tester) async {
      var postCalls = 0;
      final dio = _dio((options) {
        if (options.method == 'POST') postCalls++;
        return {'data': _reservation(pending: true)};
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationDetailScreen(
            reservationId: '0123456789abcdef01234567',
            repository: ReservationRepository(dio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đề xuất đổi phòng kho'), findsOneWidget);
      expect(find.textContaining('Phòng B-202'), findsOneWidget);
      expect(find.text('Chấp nhận đổi kho'), findsOneWidget);
      expect(postCalls, 0);
    },
  );
}

Map<String, dynamic> _reservation({required bool pending}) => {
  'id': '0123456789abcdef01234567',
  'reservationCode': 'RS-1',
  'customerId': 'customer-id',
  'facilityId': 'facility-id',
  'facilityUnitTypeOfferingId': 'offering-id',
  'storageUnitId': 'unit-old',
  'checkInDate': '2026-11-10T00:00:00Z',
  'checkInTimeSlot': 'Morning',
  'startDate': '2026-11-10T00:00:00Z',
  'rentalDuration': 2,
  'billingUnit': 'month',
  'basePrice': 50000,
  'depositAmount': 100000,
  'totalAmount': 100000,
  'status': 'confirmed',
  'refundAmount': 0,
  'createdAt': '2026-10-01T00:00:00Z',
  'updatedAt': '2026-10-01T00:00:00Z',
  'facility': {'id': 'facility-id', 'name': 'Cơ sở A'},
  'storageUnit': {
    'id': 'unit-old',
    'unitNumber': 'A-101',
    'floor': 1,
    'status': 'under_maintenance',
  },
  'pendingUnitChange': pending
      ? {
          'newStorageUnitId': 'unit-new',
          'newFacilityUnitTypeOfferingId': 'offering-new',
          'newPricePerUnit': 62000,
          'priceDifference': 12000,
          'reason': 'Phòng hiện tại cần bảo trì',
          'oldUnitStatus': 'under_maintenance',
          'proposedAt': '2026-10-30T00:00:00Z',
          'newStorageUnit': {
            'id': 'unit-new',
            'unitNumber': 'B-202',
            'floor': 2,
            'zone': 'B',
            'status': 'reserved',
          },
          'newOffering': {
            'id': 'offering-new',
            'billingUnit': 'month',
            'pricePerUnit': 62000,
          },
        }
      : null,
  'unitChangeHistory': pending
      ? [
          {
            'fromUnitId': 'unit-old',
            'toUnitId': 'unit-new',
            'fromUnit': {
              'unitNumber': 'A-101',
              'floor': 1,
              'status': 'under_maintenance',
            },
            'toUnit': {'unitNumber': 'B-202', 'floor': 2, 'status': 'reserved'},
            'fromPrice': 50000,
            'toPrice': 62000,
            'reason': 'Phòng hiện tại cần bảo trì',
            'status': 'pending',
            'proposedAt': '2026-10-30T00:00:00Z',
          },
        ]
      : [],
};

Dio _dio(Map<String, dynamic> Function(RequestOptions) respond) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _Adapter(respond);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Map<String, dynamic> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(respond(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}
