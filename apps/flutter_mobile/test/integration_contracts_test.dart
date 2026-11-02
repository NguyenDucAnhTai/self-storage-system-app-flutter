import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mobile/core/network/api_client.dart';
import 'package:flutter_mobile/features/notifications/application/notification_providers.dart';
import 'package:flutter_mobile/features/notifications/data/notification_repository.dart';
import 'package:flutter_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_mobile/features/dashboard/data/customer_inventory_summary_repository.dart';
import 'package:flutter_mobile/features/explore/data/repositories/facility_repository.dart';
import 'package:flutter_mobile/features/explore/data/models/facility.dart';
import 'package:flutter_mobile/features/payments/application/payment_status_tracker.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_mobile/features/reservations/data/repositories/reservation_repository.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';
import 'package:flutter_mobile/features/reservations/presentation/screens/reservation_create_screen.dart';

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

  test('offering without an availability hint stays unknown', () {
    final offering = FacilityOffering.fromJson({
      'id': 'offering-1',
      'unitTypeId': 'type-1',
      'unitType': {'name': 'Standard'},
      'pricePerUnit': 1000,
      'billingUnit': 'month',
      'depositMultiplier': 1,
      'minRentalDays': 1,
    });
    expect(offering.availableUnitsCount, isNull);
  });

  test('physical unit availability accepts an explicit empty array', () async {
    RequestOptions? seen;
    final dio = mockDio((options) {
      seen = options;
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'data': []}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });

    final units = await ReservationRepository(dio)
        .getAvailableUnits('facility-1', unitTypeId: 'type-1');

    expect(units, isEmpty);
    expect(seen?.path, '/storage-units/facility/facility-1/available');
    expect(seen?.queryParameters['unitTypeId'], 'type-1');
  });

  test(
    'malformed physical availability is an error rather than empty',
    () async {
      final dio = mockDio(
        (_) => ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {'items': []},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      await expectLater(
        ReservationRepository(dio).getAvailableUnits('facility-1'),
        throwsFormatException,
      );
    },
  );

  test('notification repository fetches paginated items with accepted query values', () async {
    RequestOptions? seen;
    final dio = mockDio((options) {
      seen = options;
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'items': [notificationJson()],
            'pagination': paginationJson(),
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final page = await NotificationRepository(dio).getNotifications(
      page: 2,
      limit: 20,
      isRead: false,
      sortBy: 'createdAt',
      sortOrder: 'desc',
    );
    expect(seen?.method, 'GET');
    expect(seen?.path, '/notifications');
    expect(seen?.queryParameters, containsPair('page', 2));
    expect(seen?.queryParameters, containsPair('limit', 20));
    expect(seen?.queryParameters, containsPair('isRead', false));
    expect(seen?.queryParameters, containsPair('sortBy', 'createdAt'));
    expect(seen?.queryParameters, containsPair('sortOrder', 'desc'));
    expect(page.items.single.id, 'n1');
    expect(page.pagination.page, 1);
  });

  test('notification repository parses empty list and unread count', () async {
    final dio = mockDio(
      (options) => ResponseBody.fromString(
        options.path == '/notifications/unread-count'
            ? '{"data":{"unreadCount":4}}'
            : '{"data":{"items":[],"pagination":${jsonEncode(paginationJson(totalItems: 0, totalPages: 0, hasNextPage: false))}}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    final repo = NotificationRepository(dio);
    expect((await repo.getNotifications()).items, isEmpty);
    expect(await repo.getUnreadCount(), 4);
  });

  test(
    'notification mutations use the documented PATCH and DELETE routes',
    () async {
      final calls = <String>[];
      final dio = mockDio((options) {
        calls.add('${options.method} ${options.path}');
        final body = switch (options.path) {
          '/notifications/n1/read' => {'data': notificationJson(isRead: true)},
          '/notifications/read-all' => {
            'data': {'modifiedCount': 2},
          },
          '/notifications/n1' => {'success': true, 'data': null},
          _ => <String, dynamic>{},
        };
        return ResponseBody.fromString(
          jsonEncode(body),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final repo = NotificationRepository(dio);
      expect((await repo.markAsRead('n1')).isRead, isTrue);
      expect(await repo.markAllAsRead(), 2);
      await repo.deleteNotification('n1');
      expect(calls, [
        'PATCH /notifications/n1/read',
        'PATCH /notifications/read-all',
        'DELETE /notifications/n1',
      ]);
    },
  );

  test('notification repository propagates HTTP, timeout, connection and parse errors', () async {
    for (final status in [401, 403, 404]) {
      final repo = NotificationRepository(
        mockDio(
          (_) => ResponseBody.fromString(
            '{"message":"request failed"}',
            status,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        ),
      );
      await expectLater(repo.getNotifications(), throwsA(isA<DioException>()));
    }
    final timeoutRepo = NotificationRepository(
      throwingDio(
        DioException(
          requestOptions: RequestOptions(path: '/notifications'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    );
    await expectLater(
      timeoutRepo.getNotifications(),
      throwsA(isA<DioException>()),
    );
    final connectionRepo = NotificationRepository(
      throwingDio(
        DioException(
          requestOptions: RequestOptions(path: '/notifications'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    await expectLater(
      connectionRepo.getNotifications(),
      throwsA(isA<DioException>()),
    );
    final invalidRepo = NotificationRepository(
      mockDio(
        (_) => ResponseBody.fromString(
          '{"data":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      ),
    );
    await expectLater(invalidRepo.getNotifications(), throwsFormatException);
  });

  test('notification feed paginates and synchronizes unread badge after marking read', () async {
    var unread = 1;
    Object? requestedReadFilter;
    final dio = mockDio((options) {
      if (options.path == '/notifications/unread-count') {
        return ResponseBody.fromString(
          '{"data":{"unreadCount":$unread}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/notifications/n1/read') {
        unread = 0;
        return ResponseBody.fromString(
          jsonEncode({'data': notificationJson(isRead: true)}),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/notifications/read-all') {
        unread = 0;
        return ResponseBody.fromString(
          '{"data":{"modifiedCount":1}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.method == 'DELETE' && options.path == '/notifications/n1') {
        return ResponseBody.fromString(
          '{"success":true,"data":null}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/notifications' &&
          options.queryParameters['page'] == 2) {
        requestedReadFilter = options.queryParameters['isRead'];
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'items': [notificationJson(id: 'n2')],
              'pagination': paginationJson(
                page: 2,
                totalItems: 2,
                totalPages: 2,
                hasPrevPage: true,
              ),
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (options.path == '/notifications') {
        requestedReadFilter = options.queryParameters['isRead'];
      }
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'items': [notificationJson()],
            'pagination': paginationJson(
              totalItems: 2,
              totalPages: 2,
              hasNextPage: true,
            ),
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(
          NotificationRepository(dio),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      notificationUnreadCountProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final feedSubscription = container.listen(
      notificationFeedProvider,
      (_, _) {},
    );
    addTearDown(feedSubscription.close);
    expect(await container.read(notificationUnreadCountProvider.future), 1);
    final firstPage = await container.read(notificationFeedProvider.future);
    expect(firstPage.pagination.hasNextPage, isTrue);
    await container
        .read(notificationFeedProvider.notifier)
        .setFilter(NotificationFilter.unread);
    expect(requestedReadFilter, false);
    await container
        .read(notificationFeedProvider.notifier)
        .setFilter(NotificationFilter.all);
    await container.read(notificationFeedProvider.notifier).loadMore();
    expect(
      container
          .read(notificationFeedProvider)
          .requireValue
          .items
          .map((item) => item.id),
      ['n1', 'n2'],
    );
    await container.read(notificationFeedProvider.notifier).markAsRead('n1');
    expect(
      container.read(notificationFeedProvider).requireValue.items.first.isRead,
      isTrue,
    );
    expect(await container.read(notificationUnreadCountProvider.future), 0);
    await container.read(notificationFeedProvider.notifier).markAllAsRead();
    expect(
      container
          .read(notificationFeedProvider)
          .requireValue
          .items
          .every((item) => item.isRead),
      isTrue,
    );
    await container
        .read(notificationFeedProvider.notifier)
        .deleteNotification('n1');
    expect(
      container
          .read(notificationFeedProvider)
          .requireValue
          .items
          .map((item) => item.id),
      ['n2'],
    );
  });

  test(
    'login stores tokens; restore calls /auth/me and accepts current user',
    () async {
      final dio = mockDio(
        (options) => ResponseBody.fromString(
          jsonEncode(
            options.path == '/auth/login'
                ? {
                    'data': {
                      'user': {
                        'id': 'u1',
                        'name': 'Test',
                        'email': 't@example.test',
                        'role': 'customer',
                      },
                      'tokens': {
                        'accessToken': 'access-1',
                        'refreshToken': 'refresh-1',
                      },
                    },
                  }
                : {
                    'data': {
                      'id': 'u1',
                      'name': 'Test',
                      'email': 't@example.test',
                      'role': 'customer',
                    },
                  },
          ),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      final client = ApiClient(dio: dio);
      final repo = AuthRepository(dio, client);
      expect((await repo.login('t@example.test', 'password')).id, 'u1');
      expect(await client.accessToken, 'access-1');
      expect((await repo.restore())?.email, 't@example.test');
    },
  );

  test('failed session restoration clears an expired session', () async {
    final dio = mockDio(
      (options) => ResponseBody.fromString(
        '{}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    final client = ApiClient(dio: dio);
    await client.saveTokens({'accessToken': 'expired', 'refreshToken': 'old'});
    expect(await AuthRepository(dio, client).restore(), isNull);
    expect(await client.accessToken, isNull);
    expect(await client.refreshToken, isNull);
  });

  test(
    '401 response refreshes once and retries with new bearer token',
    () async {
      var protectedCalls = 0;
      final dio = mockDio((options) {
        if (options.path == '/auth/refresh') {
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'accessToken': 'new-access',
                'refreshToken': 'new-refresh',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        protectedCalls++;
        if (options.headers['Authorization'] == 'Bearer new-access') {
          return ResponseBody.fromString(
            '{"data":{}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          '{}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final client = ApiClient(dio: dio);
      await client.saveTokens({
        'accessToken': 'old-access',
        'refreshToken': 'refresh',
      });
      await dio.get('/profile/me');
      expect(protectedCalls, 2);
      expect(await client.accessToken, 'new-access');
    },
  );

  test(
    'facility listing passes search and city filters and parses empty results',
    () async {
      RequestOptions? seen;
      final dio = mockDio((options) {
        seen = options;
        return ResponseBody.fromString(
          '{"data":{"items":[]}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      expect(
        await FacilityRepository(dio).search(search: '  North ', city: 'Hanoi'),
        isEmpty,
      );
      expect(seen?.queryParameters['search'], 'North');
      expect(seen?.queryParameters['city'], 'Hanoi');
      expect(seen?.queryParameters['status'], 'active');
    },
  );

  test(
    'reservation request includes physical unit, date-only and selected slot',
    () async {
      RequestOptions? seen;
      final dio = mockDio((options) {
        seen = options;
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'id': 'r1',
              'reservationCode': 'R1',
              'customerId': 'c1',
              'facilityId': 'f1',
              'facilityUnitTypeOfferingId': 'o1',
              'storageUnitId': 'u1',
              'checkInDate': '2026-12-03',
              'checkInTimeSlot': 'Morning',
              'startDate': '2026-12-03',
              'rentalDuration': 30,
              'billingUnit': 'month',
              'basePrice': 10,
              'depositAmount': 10,
              'totalAmount': 20,
              'status': 'pending_payment',
              'refundAmount': 0,
              'createdAt': '2026-10-22T00:00:00Z',
              'updatedAt': '2026-10-22T00:00:00Z',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final date = DateTime(2026, 12, 3, 17, 45);
      await ReservationRepository(dio).create(
        facilityId: 'f1',
        storageUnitId: 'u1',
        checkInDate: date,
        checkInTimeSlot: 'Morning',
        rentalDuration: 30,
        facilityUnitTypeOfferingId: 'o1',
        termsAccepted: true,
      );
      expect(seen?.data, containsPair('storageUnitId', 'u1'));
      expect(seen?.data, containsPair('facilityId', 'f1'));
      expect(seen?.data, containsPair('facilityUnitTypeOfferingId', 'o1'));
      expect(seen?.data, containsPair('checkInDate', '2026-12-03'));
      expect(seen?.data, containsPair('checkInTimeSlot', 'Morning'));
      expect(seen?.data['rentalDuration'], 30);
      expect(seen?.data['rentalDuration'], isA<int>());
      expect(seen?.data['amenities'], isEmpty);
      expect(seen?.data['termsAccepted'], isTrue);
    },
  );

  test(
    'reservation rejects missing required identifiers and past date locally',
    () async {
      final repo = ReservationRepository(
        mockDio((options) => ResponseBody.fromString('{}', 200)),
      );
      Future<void> create({
        String unit = 'u',
        String offering = 'o',
        DateTime? date,
        bool termsAccepted = true,
      }) => repo.create(
        facilityId: 'f',
        storageUnitId: unit,
        checkInDate: date ?? DateTime.now().add(const Duration(days: 1)),
        checkInTimeSlot: 'Morning',
        rentalDuration: 1,
        facilityUnitTypeOfferingId: offering,
        termsAccepted: termsAccepted,
      );
      await expectLater(create(unit: ''), throwsArgumentError);
      await expectLater(create(offering: ''), throwsArgumentError);
      await expectLater(create(date: DateTime(2000)), throwsArgumentError);
      await expectLater(create(termsAccepted: false), throwsArgumentError);
    },
  );

  test('dashboard summary reads the documented customer-only endpoint without caller IDs', () async {
    RequestOptions? seen;
    final repo = CustomerInventorySummaryRepository(
      mockDio((options) {
        seen = options;
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'totalSkus': 4,
              'totalQuantity': 25,
              'totalStorageUnits': 2,
              'totalActiveContracts': 1,
              'categoryBreakdown': [],
              'recentMovements': [],
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }),
    );
    final result = await repo.getSummary();

    expect(seen?.method, 'GET');
    expect(seen?.path, '/customer-inventories/summary');
    expect(seen?.queryParameters, isEmpty);
    expect(result.totalSkus, 4);
    expect(result.totalActiveContracts, 1);
    expect(result.totalQuantity, 25);
  });

  test('dashboard summary rejects malformed payload instead of showing fake metrics', () async {
    final repo = CustomerInventorySummaryRepository(
      mockDio((_) => ResponseBody.fromString('{"data":{}}', 200)),
    );
    await expectLater(repo.getSummary(), throwsFormatException);
  });

  test('availability parses valid slots and sends facility plus local date-only query', () async {
    RequestOptions? seen;
    final repo = ReservationRepository(
      mockDio((options) {
        seen = options;
        return ResponseBody.fromString(
          '{"data":[{"id":"slot-1","facilityId":"facility-7","slotName":"Morning","startTime":"08:00","endTime":"12:00","maxCapacity":5,"bookedCount":2,"availableCapacity":3,"isAvailable":true}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }),
    );
    final slots = await repo.getAvailability(
      'facility-7',
      DateTime(2026, 10, 28, 23),
    );
    expect(seen?.method, 'GET');
    expect(seen?.path, '/facility-time-slots/facility/facility-7/available');
    expect(seen?.queryParameters['date'], '2026-10-28');
    expect(slots.single.slotName, 'Morning');
    expect(slots.single.availableCapacity, 3);
    expect(slots.single.isAvailable, isTrue);
  });

  test('empty availability response is a valid empty list', () async {
    final repo = ReservationRepository(
      mockDio(
        (_) => ResponseBody.fromString(
          '{"data":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      ),
    );
    expect(
      await repo.getAvailability('facility-7', DateTime(2026, 10, 28)),
      isEmpty,
    );
  });

  test('malformed availability response stays a parsing error', () async {
    final invalidEnvelope = ReservationRepository(
      mockDio(
        (_) => ResponseBody.fromString(
          '{"data":{}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      ),
    );
    await expectLater(
      invalidEnvelope.getAvailability('facility-7', DateTime(2026, 10, 28)),
      throwsFormatException,
    );
    final invalidItem = ReservationRepository(
      mockDio(
        (_) => ResponseBody.fromString(
          '{"data":[{"slotName":"Morning"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      ),
    );
    await expectLater(
      invalidItem.getAvailability('facility-7', DateTime(2026, 10, 28)),
      throwsFormatException,
    );
  });

  test('availability HTTP errors and timeouts remain errors instead of empty slots', () async {
    for (final status in [401, 500]) {
      final repo = ReservationRepository(
        mockDio(
          (options) => ResponseBody.fromString(
            '{"message":"availability failed"}',
            status,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        ),
      );
      await expectLater(
        repo.getAvailability('facility-7', DateTime(2026, 10, 28)),
        throwsA(isA<DioException>()),
      );
    }
    final timeoutRepo = ReservationRepository(
      throwingDio(
        DioException(
          requestOptions: RequestOptions(
            path: '/facility-time-slots/facility/facility-7/available',
          ),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    );
    await expectLater(
      timeoutRepo.getAvailability('facility-7', DateTime(2026, 10, 28)),
      throwsA(isA<DioException>()),
    );
  });

  testWidgets(
    'reservation create screen refreshes availability when the date changes',
    (tester) async {
      final repo = _ScreenRepository();
      final firstDate = DateTime.now().add(const Duration(days: 1));
      final secondDate = firstDate.add(const Duration(days: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationCreateScreen(
            facilityId: 'facility-7',
            offeringId: 'offering-2',
            unitTypeId: 'type-3',
            minRentalDays: 2,
            repository: repo,
            onCreated: (_) {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${firstDate.day}').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      if (firstDate.month != secondDate.month ||
          firstDate.year != secondDate.year) {
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('${secondDate.day}').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(repo.requestedDates, hasLength(2));
      expect(
        repo.requestedDates.map((date) => (date.year, date.month, date.day)),
        [
          (firstDate.year, firstDate.month, firstDate.day),
          (secondDate.year, secondDate.month, secondDate.day),
        ],
      );
      expect(repo.requestedFacilities, ['facility-7', 'facility-7']);
    },
  );

  testWidgets('create button requires an available selected slot and unit', (
    tester,
  ) async {
    Reservation? created;
    final repo = _ScreenRepository(
      slots: const [
        AvailableTimeSlot(
          id: 'slot-1',
          slotName: 'Morning',
          startTime: '08:00',
          endTime: '12:00',
          availableCapacity: 2,
          isAvailable: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreateScreen(
          facilityId: 'facility-7',
          offeringId: 'offering-2',
          unitTypeId: 'type-3',
          minRentalDays: 30,
          repository: repo,
          onCreated: (reservation) => created = reservation,
        ),
      ),
    );
    await tester.tap(find.text('Chọn ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('28').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Chọn giờ nhận kho'), findsOneWidget);
    await tester.tap(find.text('Chọn giờ nhận kho'));
    await tester.pumpAndSettle();
    expect(find.text('Morning'), findsOneWidget);
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    expect(find.text('08:00–12:00 · Còn 2 chỗ'), findsOneWidget);
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
    );
    expect(button.onPressed, isNull, reason: 'unit is still missing');
    await tester.ensureVisible(find.text('LK-301 · Tầng 1'));
    await tester.tap(find.text('LK-301 · Tầng 1'));
    await tester.pumpAndSettle();
    expect(
      repo.requestedDates,
      hasLength(1),
      reason:
          'slot availability is facility/date based, not physical-unit based',
    );
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(button.onPressed, isNull, reason: 'explicit consent is required');
    expect(repo.createCalls, 0);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.enterText(find.byType(TextFormField), '29');
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.text('Thời hạn thuê tối thiểu là 30 ngày.'), findsOneWidget);
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
    );
    expect(button.onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), '30');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '30',
    );
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.tap(find.text('Xác nhận đặt kho'));
    await tester.pumpAndSettle();
    expect(repo.createdRentalDuration, 30);
    expect(repo.createdRentalDuration, isA<int>());
    expect(created?.rentalDuration, 30);
    expect(repo.createdTermsAccepted, isTrue);
  });

  testWidgets(
    'time slot selector is compact and unavailable slots stay disabled',
    (tester) async {
      final repo = _ScreenRepository(
        slots: const [
          AvailableTimeSlot(
            id: 'slot-full',
            slotName: 'Evening',
            startTime: '18:00',
            endTime: '20:00',
            availableCapacity: 0,
            isAvailable: false,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationCreateScreen(
            facilityId: 'facility-7',
            offeringId: 'offering-2',
            unitTypeId: 'type-3',
            minRentalDays: 1,
            repository: repo,
            onCreated: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Chọn ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('28').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Chọn giờ nhận kho'), findsOneWidget);
      expect(find.text('Evening'), findsNothing);
      await tester.tap(find.text('Chọn giờ nhận kho'));
      await tester.pumpAndSettle();
      expect(find.text('Evening'), findsOneWidget);
      expect(find.textContaining('Hết chỗ'), findsOneWidget);
      final disabledSlot = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Evening'),
          matching: find.byType(ListTile),
        ),
      );
      expect(disabledSlot.onTap, isNull);
      await tester.tap(find.byType(ModalBarrier).last);
      await tester.pumpAndSettle();
      expect(find.text('Chọn giờ nhận kho'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reservation POST errors show status-specific backend guidance', (
    tester,
  ) async {
    final cases = <(int, String?, String)>[
      (400, null, 'storageUnitId: unavailable'),
      (
        400,
        'MESSAGE_CODE_322',
        'Bạn cần đồng ý với điều khoản đặt kho trước khi tiếp tục.',
      ),
      (400, 'MESSAGE_CODE_328', 'Khung giờ nhận kho cần đủ thời gian chuẩn bị'),
      (400, 'MESSAGE_CODE_315', 'Khung giờ nhận kho đã qua.'),
      (400, 'MESSAGE_CODE_310', 'đạt sức chứa tối đa'),
      (400, 'MESSAGE_CODE_311', 'không hợp lệ hoặc không còn hoạt động'),
      (400, 'MESSAGE_CODE_309', 'vừa được khách hàng khác đặt'),
      (400, 'MESSAGE_CODE_306', 'không thuộc loại kho này'),
      (400, 'MESSAGE_CODE_313', 'vượt quá thời hạn đặt trước'),
      (400, 'MESSAGE_CODE_314', 'đạt giới hạn số đơn đặt kho'),
      (401, null, 'Phiên đăng nhập đã hết hạn'),
      (403, null, 'Bạn không có quyền tạo đơn đặt kho này.'),
      (404, null, 'không còn khả dụng'),
      (409, null, 'vừa được đặt'),
    ];
    for (final (status, messageCode, expected) in cases) {
      final requestOptions = RequestOptions(path: '/reservations');
      final repo = _ScreenRepository(slots: _availableTestSlots)
        ..createError = DioException(
          requestOptions: requestOptions,
          response: Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: status,
            data: {
              'messageCode': messageCode ?? 'MESSAGE_CODE_TEST',
              'message': 'Booking validation failed',
              'errors': {'storageUnitId': 'unavailable'},
            },
          ),
          type: DioExceptionType.badResponse,
        );
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationCreateScreen(
            facilityId: 'facility-7',
            offeringId: 'offering-2',
            unitTypeId: 'type-3',
            minRentalDays: 30,
            repository: repo,
            onCreated: (_) {},
          ),
        ),
      );
      await _prepareValidReservationForm(tester);
      await tester.ensureVisible(find.text('Xác nhận đặt kho'));
      await tester.tap(find.text('Xác nhận đặt kho'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(expected),
        findsOneWidget,
        reason: 'HTTP $status',
      );
      if (messageCode == null && status == 400) {
        expect(find.textContaining('MESSAGE_CODE_TEST'), findsOneWidget);
      }
      if (messageCode != null) {
        expect(find.textContaining(messageCode), findsOneWidget);
      }
      if (messageCode == 'MESSAGE_CODE_322') {
        expect(
          find.textContaining('storageUnitId: unavailable'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Booking validation failed'),
          findsOneWidget,
        );
      }
      if (status == 409) {
        expect(find.text('Tải lại tình trạng kho'), findsOneWidget);
      }
      expect(repo.createCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'reservation timeout warns of unknown outcome and never retries automatically',
    (tester) async {
      final requestOptions = RequestOptions(path: '/reservations');
      final repo = _ScreenRepository(slots: _availableTestSlots)
        ..createError = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.receiveTimeout,
        );
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationCreateScreen(
            facilityId: 'facility-7',
            offeringId: 'offering-2',
            unitTypeId: 'type-3',
            minRentalDays: 30,
            repository: repo,
            onCreated: (_) {},
          ),
        ),
      );
      await _prepareValidReservationForm(tester);
      await tester.ensureVisible(find.text('Xác nhận đặt kho'));
      await tester.tap(find.text('Xác nhận đặt kho'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa xác định'), findsOneWidget);
      expect(repo.createCalls, 1);
      var button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
      );
      expect(button.onPressed, isNull);
      await tester.ensureVisible(
        find.text('Tôi đã kiểm tra Đơn đặt kho, cho phép thử lại'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Tôi đã kiểm tra Đơn đặt kho, cho phép thử lại'),
      );
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận đặt kho'),
      );
      expect(button.onPressed, isNotNull);
      expect(repo.createCalls, 1);
    },
  );

  testWidgets('reservation submission disables duplicate taps until response', (
    tester,
  ) async {
    final repo = _ScreenRepository(slots: _availableTestSlots)
      ..createCompleter = Completer<Reservation>();
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreateScreen(
          facilityId: 'facility-7',
          offeringId: 'offering-2',
          unitTypeId: 'type-3',
          minRentalDays: 30,
          repository: repo,
          onCreated: (_) {},
        ),
      ),
    );
    await _prepareValidReservationForm(tester);
    await tester.ensureVisible(find.text('Xác nhận đặt kho'));
    await tester.tap(find.text('Xác nhận đặt kho'));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Đang xác nhận…'),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(repo.createCalls, 1);

    repo.createCompleter!.complete(
      Reservation(
        id: 'reservation-1',
        reservationCode: 'RES-1',
        customerId: 'customer-1',
        facilityId: 'facility-7',
        facilityUnitTypeOfferingId: 'offering-2',
        storageUnitId: 'unit-301',
        checkInDate: DateTime(2026, 11, 28),
        checkInTimeSlot: 'Morning',
        startDate: DateTime(2026, 11, 28),
        rentalDuration: 30,
        billingUnit: 'day',
        basePrice: 0,
        depositAmount: 0,
        totalAmount: 0,
        status: 'pending_payment',
        refundAmount: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.createCalls, 1);
  });

  testWidgets(
    'availability failure is not shown as no slots and can be retried',
    (tester) async {
      final repo = _ScreenRepository(
        slotError: DioException(
          requestOptions: RequestOptions(
            path: '/facility-time-slots/facility/facility-7/available',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/facility-time-slots/facility/facility-7/available',
            ),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationCreateScreen(
            facilityId: 'facility-7',
            offeringId: 'offering-2',
            unitTypeId: 'type-3',
            minRentalDays: 2,
            repository: repo,
            onCreated: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Chọn ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('28').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tải tình trạng kho.',
        ),
        findsOneWidget,
      );
      expect(find.text('Không có khung giờ nhận kho'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
    },
  );

  test('payment session request parses backend QR and amount', () async {
    RequestOptions? seen;
    final dio = mockDio((options) {
      seen = options;
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'id': 'p1',
            'paymentCode': 'PAY1',
            'purpose': 'reservation_deposit',
            'reservationId': 'r1',
            'amount': 250,
            'paidAmount': 0,
            'status': 'pending',
            'method': 'sepay_qr',
            'qrUrl': 'https://bank.test/qr',
            'createdAt': '2026-10-22T00:00:00Z',
            'updatedAt': '2026-10-22T00:00:00Z',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final payment = await PaymentRepository(dio).createReservationDeposit('r1');
    expect(seen?.data, containsPair('purpose', 'reservation_deposit'));
    expect(payment.qrUrl, 'https://bank.test/qr');
    expect(payment.amount, 250);
  });

  test('payment tracker reports timeout and supports cancellation', () async {
    var calls = 0;
    final dio = mockDio((options) {
      calls++;
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'id': 'p1',
            'paymentCode': 'PAY1',
            'purpose': 'reservation_deposit',
            'amount': 250,
            'paidAmount': 0,
            'status': 'pending',
            'method': 'sepay_qr',
            'createdAt': '2026-10-22T00:00:00Z',
            'updatedAt': '2026-10-22T00:00:00Z',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final tracker = PaymentStatusTracker(
      PaymentRepository(dio),
      interval: Duration.zero,
      maxAttempts: 2,
    );
    final timedOut = Completer<void>();
    final timeoutSubscription = tracker.watch('p1').listen((event) {
      if (event is PaymentPollTimeout && !timedOut.isCompleted) {
        timedOut.complete();
      }
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
    final error = ApiClient.normalize(
      DioException(
        requestOptions: RequestOptions(path: '/reservations'),
        response: Response(
          requestOptions: RequestOptions(path: '/reservations'),
          statusCode: 409,
          data: {'message': 'Unit conflict', 'messageCode': 'CONFLICT'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(error.toString(), contains('Unit conflict'));
    expect((error as dynamic).statusCode, 409);
  });

  test('terminal payment statuses reflect backend state transitions', () {
    Payment from(String status) => Payment.fromJson({
      'id': 'p',
      'paymentCode': 'P',
      'purpose': 'reservation_deposit',
      'amount': 1,
      'paidAmount': 0,
      'status': status,
      'method': 'sepay_qr',
      'createdAt': '2026-10-22T00:00:00Z',
      'updatedAt': '2026-10-22T00:00:00Z',
    });
    expect(from('pending').isTerminal, isFalse);
    expect(from('paid').isTerminal, isTrue);
    expect(from('failed').isTerminal, isFalse);
    expect(from('expired').isTerminal, isTrue);
  });
}

Map<String, dynamic> notificationJson({
  String id = 'n1',
  bool isRead = false,
}) => {
  'id': id,
  'recipientId': 'customer-1',
  'title': 'Reservation updated',
  'content': 'Your reservation has been updated.',
  'type': 'reservation',
  'priority': 'normal',
  'channels': ['in_app'],
  'isRead': isRead,
  if (isRead) 'readAt': '2026-10-23T10:00:00Z',
  'createdAt': '2026-10-23T09:00:00Z',
  'updatedAt': '2026-10-23T10:00:00Z',
};

Map<String, dynamic> paginationJson({
  int page = 1,
  int limit = 20,
  int totalItems = 1,
  int totalPages = 1,
  bool hasNextPage = false,
  bool hasPrevPage = false,
}) => {
  'page': page,
  'limit': limit,
  'totalItems': totalItems,
  'totalPages': totalPages,
  'hasNextPage': hasNextPage,
  'hasPrevPage': hasPrevPage,
};

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);
  final DioException error;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error;
  @override
  void close({bool force = false}) {}
}

Dio throwingDio(DioException error) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
  dio.httpClientAdapter = _ThrowingAdapter(error);
  return dio;
}

class _ScreenRepository extends ReservationRepository {
  _ScreenRepository({this.slots = const [], this.slotError}) : super(Dio());
  final List<AvailableTimeSlot> slots;
  final Object? slotError;
  final List<DateTime> requestedDates = [];
  final List<String> requestedFacilities = [];
  int? createdRentalDuration;
  bool? createdTermsAccepted;
  int createCalls = 0;
  Object? createError;
  Completer<Reservation>? createCompleter;

  @override
  Future<List<AvailableTimeSlot>> getAvailability(
    String facilityId,
    DateTime date,
  ) async {
    requestedDates.add(date);
    requestedFacilities.add(facilityId);
    if (slotError != null) throw slotError!;
    return slots;
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableUnits(
    String facilityId, {
    String? unitTypeId,
  }) async => [
    {
      'id': 'unit-301',
      'unitNumber': 'LK-301',
      'floor': 1,
      'status': 'available',
    },
  ];

  @override
  Future<Reservation> create({
    required String facilityId,
    required String storageUnitId,
    required DateTime checkInDate,
    required String checkInTimeSlot,
    required int rentalDuration,
    required String facilityUnitTypeOfferingId,
    required bool termsAccepted,
    DateTime? startDate,
    List<Map<String, dynamic>> amenities = const [],
    String? notes,
  }) async {
    createCalls++;
    createdRentalDuration = rentalDuration;
    createdTermsAccepted = termsAccepted;
    if (!termsAccepted) throw ArgumentError('Terms acceptance required.');
    if (createError != null) throw createError!;
    final result = Reservation(
      id: 'reservation-1',
      reservationCode: 'RES-1',
      customerId: 'customer-1',
      facilityId: facilityId,
      facilityUnitTypeOfferingId: facilityUnitTypeOfferingId,
      storageUnitId: storageUnitId,
      checkInDate: checkInDate,
      checkInTimeSlot: checkInTimeSlot,
      startDate: checkInDate,
      rentalDuration: rentalDuration,
      billingUnit: 'day',
      basePrice: 0,
      depositAmount: 0,
      totalAmount: 0,
      status: 'pending_payment',
      refundAmount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final completer = createCompleter;
    if (completer != null) return completer.future;
    return result;
  }
}

Future<void> _prepareValidReservationForm(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn ngày'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('28').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Chọn giờ nhận kho'));
  await tester.tap(find.text('Chọn giờ nhận kho'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Morning'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('LK-301 · Tầng 1'));
  await tester.tap(find.text('LK-301 · Tầng 1'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(TextFormField));
  await tester.enterText(find.byType(TextFormField), '30');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

const _availableTestSlots = [
  AvailableTimeSlot(
    id: 'slot-1',
    slotName: 'Morning',
    startTime: '08:00',
    endTime: '12:00',
    availableCapacity: 2,
    isAvailable: true,
  ),
];
