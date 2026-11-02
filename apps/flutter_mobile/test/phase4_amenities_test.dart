import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/amenities/amenity_repository.dart';
import 'package:flutter_mobile/features/explore/data/repositories/facility_repository.dart';
import 'package:flutter_mobile/features/reservations/data/repositories/reservation_repository.dart';
import 'package:flutter_mobile/features/reservations/presentation/screens/reservation_create_screen.dart';

void main() {
  test(
    'amenity catalogue uses active filter and parses verified fields',
    () async {
      RequestOptions? seen;
      final repo = AmenityRepository(
        _dio((r) {
          seen = r;
          return {
            'data': {
              'items': [_amenity],
            },
          };
        }),
      );
      final rows = await repo.listActive();
      expect(seen!.path, '/amenities');
      expect(seen!.queryParameters, {
        'page': 1,
        'limit': 100,
        'status': 'active',
        'sortBy': 'name',
      });
      expect(rows.single.name, 'Lưu kho');
    },
  );

  test('amenity facility search serializes CSV IDs, matchAll and no unsupported status', () async {
    RequestOptions? seen;
    final repo = FacilityRepository(
      _dio((r) {
        seen = r;
        return {
          'data': {
            'items': [],
            'pagination': {
              'page': 2,
              'limit': 20,
              'totalItems': 40,
              'totalPages': 2,
              'hasNextPage': true,
              'hasPrevPage': true,
            },
          },
        };
      }),
    );
    final page = await repo.searchPage(
      search: 'Kho A',
      city: 'Hà Nội',
      page: 2,
      amenityIds: ['0123456789abcdef01234567', '1123456789abcdef01234567'],
      matchAllAmenities: false,
    );
    expect(seen!.path, '/facilities/search-by-amenity');
    expect(
      seen!.queryParameters['amenityIds'],
      '0123456789abcdef01234567,1123456789abcdef01234567',
    );
    expect(seen!.queryParameters['matchAll'], false);
    expect(seen!.queryParameters['search'], 'Kho A');
    expect(seen!.queryParameters['city'], 'Hà Nội');
    expect(seen!.queryParameters['page'], 2);
    expect(seen!.queryParameters['limit'], 20);
    expect(seen!.queryParameters['sortBy'], 'name');
    expect(seen!.queryParameters['sortOrder'], 'asc');
    expect(page.page, 2);
    expect(page.hasNextPage, isTrue);
    expect(seen!.queryParameters.containsKey('status'), isFalse);
  });

  test('available facility offering preserves backend price, availability and quantity', () async {
    RequestOptions? seen;
    final repo = AmenityRepository(
      _dio((r) {
        seen = r;
        return {
          'data': [_offering],
        };
      }),
    );
    final row = (await repo.availableAt('0123456789abcdef01234567')).single;
    expect(
      seen!.path,
      '/facility-amenity-offerings/facility/0123456789abcdef01234567/available',
    );
    expect(row.pricePerUnit, 2500);
    expect(row.availableQuantity, 3);
    expect(row.isAvailable, isTrue);
  });

  testWidgets(
    'reservation amenity selection toggles, unavailable option stays disabled',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _dio((r) {
        if (r.path.contains('/facility-amenity-offerings/')) {
          return {
            'data': [
              _offering,
              {
                ..._offering,
                'id': 'offering-2',
                'amenityId': 'amenity-2',
                'amenity': {
                  'id': 'amenity-2',
                  'name': 'Đã hết',
                  'type': 'goods',
                },
                'availableQuantity': 0,
              },
            ],
          };
        }
        return {'data': []};
      });
      for (final width in [320.0, 360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 840);
        await tester.pumpWidget(
          MaterialApp(
            home: ReservationCreateScreen(
              facilityId: '0123456789abcdef01234567',
              offeringId: 'offering-unit',
              unitTypeId: 'type',
              minRentalDays: 1,
              repository: ReservationRepository(api),
              amenityRepository: AmenityRepository(api),
              onCreated: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Lưu kho'));
        expect(find.text('Lưu kho'), findsOneWidget);
        await tester.tap(find.text('Lưu kho'));
        await tester.pumpAndSettle();
        expect(find.text('Tiện ích tùy chọn'), findsOneWidget);
        expect(find.text('Đã hết'), findsOneWidget);
        final disabled = tester.widget<CheckboxListTile>(
          find
              .ancestor(
                of: find.text('Đã hết'),
                matching: find.byType(CheckboxListTile),
              )
              .first,
        );
        expect(disabled.onChanged, isNull);
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('reservation request includes selected amenity IDs and integer quantity; empty stays empty', () async {
    RequestOptions? seen;
    final repo = ReservationRepository(
      _dio((r) {
        seen = r;
        return {'data': _reservation};
      }),
    );
    final date = DateTime.now().add(const Duration(days: 1));
    await repo.create(
      facilityId: '0123456789abcdef01234567',
      storageUnitId: '1123456789abcdef01234567',
      facilityUnitTypeOfferingId: '2123456789abcdef01234567',
      checkInDate: date,
      checkInTimeSlot: '09:00-11:00',
      rentalDuration: 1,
      termsAccepted: true,
      amenities: [
        {
          'facilityAmenityOfferingId': '3123456789abcdef01234567',
          'quantity': 2,
        },
      ],
    );
    expect(seen!.data['amenities'], [
      {'facilityAmenityOfferingId': '3123456789abcdef01234567', 'quantity': 2},
    ]);
    expect(seen!.data['amenities'][0]['quantity'], isA<int>());
    await repo.create(
      facilityId: '0123456789abcdef01234567',
      storageUnitId: '1123456789abcdef01234567',
      facilityUnitTypeOfferingId: '2123456789abcdef01234567',
      checkInDate: date,
      checkInTimeSlot: '09:00-11:00',
      rentalDuration: 1,
      termsAccepted: true,
    );
    expect(seen!.data['amenities'], isEmpty);
  });

  test(
    'reservation rejects invalid and duplicate amenity quantities before POST',
    () async {
      var posts = 0;
      final repo = ReservationRepository(
        _dio((r) {
          if (r.method == 'POST') posts++;
          return {'data': _reservation};
        }),
      );
      final date = DateTime.now().add(const Duration(days: 1));
      Future<void> send(List<Map<String, dynamic>> amenities) => repo.create(
        facilityId: '0123456789abcdef01234567',
        storageUnitId: '1123456789abcdef01234567',
        facilityUnitTypeOfferingId: '2123456789abcdef01234567',
        checkInDate: date,
        checkInTimeSlot: '09:00-11:00',
        rentalDuration: 1,
        termsAccepted: true,
        amenities: amenities,
      );
      await expectLater(
        send([
          {
            'facilityAmenityOfferingId': '3123456789abcdef01234567',
            'quantity': 0,
          },
        ]),
        throwsArgumentError,
      );
      await expectLater(
        send([
          {
            'facilityAmenityOfferingId': '3123456789abcdef01234567',
            'quantity': 1,
          },
          {
            'facilityAmenityOfferingId': '3123456789abcdef01234567',
            'quantity': 1,
          },
        ]),
        throwsArgumentError,
      );
      expect(posts, 0);
    },
  );
}

const _amenity = {
  'id': '0123456789abcdef01234567',
  'name': 'Lưu kho',
  'type': 'service',
  'status': 'active',
  'description': 'Dịch vụ lưu giữ',
  'images': [],
  'tags': [],
  'createdAt': '2026-10-30T00:00:00Z',
  'updatedAt': '2026-10-30T00:00:00Z',
};
const _offering = {
  'id': 'offering-1',
  'facilityId': '0123456789abcdef01234567',
  'amenityId': 'amenity-1',
  'amenity': {
    'id': 'amenity-1',
    'name': 'Lưu kho',
    'type': 'service',
    'status': 'active',
    'images': [],
    'tags': [],
  },
  'pricePerUnit': 2500,
  'billingUnit': 'month',
  'availableQuantity': 3,
  'totalQuantity': 10,
  'status': 'active',
  'createdAt': '2026-10-30T00:00:00Z',
  'updatedAt': '2026-10-30T00:00:00Z',
};
const _reservation = {
  'id': 'r1',
  'reservationCode': 'RS-1',
  'customerId': 'c1',
  'facilityId': 'f1',
  'facilityUnitTypeOfferingId': 'o1',
  'storageUnitId': 'u1',
  'checkInDate': '2026-11-01T00:00:00Z',
  'checkInTimeSlot': '09:00-11:00',
  'startDate': '2026-11-01T00:00:00Z',
  'rentalDuration': 1,
  'billingUnit': 'month',
  'basePrice': 1000,
  'depositAmount': 1000,
  'totalAmount': 1000,
  'status': 'pending',
  'refundAmount': 0,
  'createdAt': '2026-10-31T00:00:00Z',
  'updatedAt': '2026-10-31T00:00:00Z',
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
