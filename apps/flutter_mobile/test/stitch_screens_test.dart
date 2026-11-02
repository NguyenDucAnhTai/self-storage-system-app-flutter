import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_mobile/features/auth/data/models/auth_user.dart';
import 'package:flutter_mobile/features/explore/data/models/facility.dart';
import 'package:flutter_mobile/features/explore/data/repositories/facility_repository.dart';
import 'package:flutter_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:flutter_mobile/features/explore/presentation/screens/facility_detail_screen.dart';
import 'package:flutter_mobile/features/payments/application/payment_status_tracker.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_mobile/features/payments/presentation/screens/payment_screen.dart';
import 'package:flutter_mobile/features/notifications/application/notification_providers.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';
import 'package:flutter_mobile/features/reservations/data/repositories/reservation_repository.dart';
import 'package:flutter_mobile/features/reservations/presentation/screens/reservation_create_screen.dart';

void main() {
  testWidgets(
    'facility booking checks physical availability and passes selection',
    (tester) async {
      ({Facility facility, FacilityOffering offering})? selected;
      final availability = _ReservationRepository(
        units: [
          {'id': 'unit-1', 'status': 'available', 'unitNumber': 'A-1'},
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FacilityDetailScreen(
            facilityId: 'facility-1',
            repository: _FacilityRepository(),
            availabilityRepository: availability,
            onBook: (value) => selected = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 kho trống'), findsOneWidget);
      expect(find.text('Chọn loại kho này'), findsOneWidget);
      await tester.ensureVisible(find.text('Chọn loại kho này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn loại kho này'));
      expect(selected?.facility.id, 'facility-1');
      expect(selected?.offering.id, 'offering-1');
      expect(selected?.offering.unitTypeId, 'unit-type-1');
      expect(availability.requestedUnitTypeIds, ['unit-type-1']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('facility booking distinguishes empty and failed availability', (
    tester,
  ) async {
    final availability = _ReservationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: FacilityDetailScreen(
          facilityId: 'facility-1',
          repository: _FacilityRepository(),
          availabilityRepository: availability,
          onBook: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hết phòng trống'), findsOneWidget);
    expect(find.text('Chọn loại kho này'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('facility booking surfaces malformed availability as an error', (
    tester,
  ) async {
    final availability = _ReservationRepository()
      ..unitError = const FormatException('invalid');
    await tester.pumpWidget(
      MaterialApp(
        home: FacilityDetailScreen(
          facilityId: 'facility-1',
          repository: _FacilityRepository(),
          availabilityRepository: availability,
          onBook: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Dữ liệu tình trạng kho không đúng định dạng.'),
      findsOneWidget,
    );
    expect(find.text('Hết phòng trống'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Explore shows API facility details and opens the selected item',
    (tester) async {
      Facility? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_SignedOutAuthController.new),
            notificationUnreadCountProvider.overrideWith((ref) async => 0),
          ],
          child: MaterialApp(
            home: ExploreScreen(
              repository: _FacilityRepository(facilities: const [_facility]),
              onSelect: (facility) => selected = facility,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('API Storage Center'), findsOneWidget);
      expect(find.text('Ward 1 · 10 Sample Road'), findsOneWidget);
      expect(find.text('Đang hoạt động · Ward 1'), findsOneWidget);
      await tester.tap(find.text('API Storage Center'));
      expect(selected?.id, 'facility-1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reservation summary uses the selected facility API data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreateScreen(
          facilityId: 'facility-1',
          offeringId: 'offering-1',
          unitTypeId: 'unit-type-1',
          minRentalDays: 1,
          repository: _ReservationRepository(),
          facilityRepository: _FacilityRepository(
            detail: const FacilityDetail(
              facility: _facility,
              offerings: [_offering],
            ),
          ),
          onCreated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API Storage Center'), findsOneWidget);
    expect(find.text('Small unit · 2.0 m²'), findsOneWidget);
    expect(find.text('4 available'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'payment screen shows server payment data and pending is not success',
    (tester) async {
      final repository = _PaymentRepository(_payment('pending'));
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            reservationId: 'reservation-1',
            repository: repository,
            tracker: PaymentStatusTracker(
              repository,
              interval: const Duration(hours: 1),
              maxAttempts: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mã thanh toán PAY-1'), findsOneWidget);
      expect(find.text('Có liên kết với đơn đặt kho'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Thông tin chuyển khoản'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Thông tin chuyển khoản'), findsOneWidget);
      expect(find.text('Example Bank'), findsOneWidget);
      expect(find.text('0123456789'), findsOneWidget);
      expect(find.text('Chờ thanh toán'), findsWidgets);
      expect(find.text('Payment confirmed'), findsNothing);
      expect(find.textContaining('1.250.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

const _facility = Facility(
  id: 'facility-1',
  name: 'API Storage Center',
  address: '10 Sample Road',
  city: 'Ward 1',
  status: 'active',
);

const _offering = FacilityOffering(
  id: 'offering-1',
  unitTypeId: 'unit-type-1',
  name: 'Small unit',
  pricePerUnit: 500000,
  billingUnit: 'month',
  depositMultiplier: 1,
  minRentalDays: 1,
  availableUnitsCount: 4,
  area: 2,
);

class _FacilityRepository extends FacilityRepository {
  _FacilityRepository({this.facilities = const [], this.detail}) : super(Dio());

  final List<Facility> facilities;
  final FacilityDetail? detail;

  @override
  Future<List<Facility>> search({
    String? search,
    String? city,
    int page = 1,
    List<String> amenityIds = const [],
    bool matchAllAmenities = true,
  }) async => facilities;

  @override
  Future<FacilitySearchPage> searchPage({
    String? search,
    String? city,
    int page = 1,
    List<String> amenityIds = const [],
    bool matchAllAmenities = true,
  }) async =>
      FacilitySearchPage(items: facilities, page: page, hasNextPage: false);

  @override
  Future<FacilityDetail> getDetail(String id) async =>
      detail ??
      const FacilityDetail(facility: _facility, offerings: [_offering]);
}

class _ReservationRepository extends ReservationRepository {
  _ReservationRepository({this.units = const []}) : super(Dio());

  final List<Map<String, dynamic>> units;
  Object? unitError;
  final List<String?> requestedUnitTypeIds = [];

  @override
  Future<List<AvailableTimeSlot>> getAvailability(
    String facilityId,
    DateTime date,
  ) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getAvailableUnits(
    String facilityId, {
    String? unitTypeId,
  }) async {
    requestedUnitTypeIds.add(unitTypeId);
    if (unitError != null) throw unitError!;
    return units;
  }
}

class _PaymentRepository extends PaymentRepository {
  _PaymentRepository(this.payment) : super(Dio());

  final Payment payment;

  @override
  Future<Payment> createReservationDeposit(String reservationId) async =>
      payment;

  @override
  Future<Payment> getById(String id) async => payment;
}

class _SignedOutAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => null;
}

Payment _payment(String status) => Payment(
  id: 'payment-1',
  paymentCode: 'PAY-1',
  purpose: 'reservation_deposit',
  reservationId: 'reservation-1',
  amount: 1250000,
  paidAmount: 0,
  status: status,
  method: 'sepay_qr',
  qrUrl: null,
  expiresAt: DateTime(2026, 10, 30, 12),
  referenceCode: 'TRANSFER-1',
  bankInfo: const {'bankName': 'Example Bank', 'accountNumber': '0123456789'},
  createdAt: DateTime(2026, 10, 30),
  updatedAt: DateTime(2026, 10, 30),
);
