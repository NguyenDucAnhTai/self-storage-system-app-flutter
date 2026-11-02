import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/app/router.dart';
import 'package:flutter_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_mobile/features/auth/data/models/auth_user.dart';
import 'package:flutter_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:flutter_mobile/features/dashboard/data/active_rental_summary.dart';
import 'package:flutter_mobile/features/dashboard/data/customer_inventory_summary.dart';
import 'package:flutter_mobile/features/dashboard/presentation/customer_dashboard_screen.dart';
import 'package:flutter_mobile/features/explore/data/models/facility.dart';
import 'package:flutter_mobile/features/notifications/application/notification_providers.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';
import 'package:flutter_mobile/core/network/api_client.dart';

void main() {
  const summary = CustomerInventorySummary(
    totalSkus: 8,
    totalQuantity: 125,
    totalStorageUnits: 3,
    totalActiveContracts: 2,
    categoryBreakdown: [],
    recentMovements: [],
  );

  test('guest redirects to login and preserves protected deep link', () {
    expect(
      resolveAuthRedirect(
        authLoading: false,
        signedIn: false,
        path: '/splash',
        currentUri: '/splash',
      ),
      '/login',
    );
    expect(
      resolveAuthRedirect(
        authLoading: false,
        signedIn: false,
        path: '/payments/reservation-1',
        currentUri: '/payments/reservation-1?source=notification',
      ),
      '/login?from=%2Fpayments%2Freservation-1%3Fsource%3Dnotification',
    );
  });

  test('restored and newly authenticated users land on Home', () {
    for (final path in ['/splash', '/login', '/register']) {
      expect(
        resolveAuthRedirect(
          authLoading: false,
          signedIn: true,
          path: path,
          currentUri: path,
        ),
        '/home',
      );
    }
  });

  test('auth loading waits on splash before deciding the destination', () {
    expect(
      resolveAuthRedirect(
        authLoading: true,
        signedIn: false,
        path: '/splash',
        currentUri: '/splash',
      ),
      isNull,
    );
    expect(
      resolveAuthRedirect(
        authLoading: true,
        signedIn: false,
        path: '/explore',
        currentUri: '/explore',
      ),
      '/splash',
    );
  });

  test('one active storage-unit contract counts as one rented room', () {
    final summary = ActiveRentalSummary.fromContracts([_activeContract()]);
    expect(summary.rentedUnitCount, 1);
    expect(summary.contracts, hasLength(1));
  });

  test('active contracts for the same unit are deduplicated', () {
    final summary = ActiveRentalSummary.fromContracts([
      _activeContract(id: '111111111111111111111111'),
      _activeContract(id: '222222222222222222222222'),
    ]);
    expect(summary.rentedUnitCount, 1);
    expect(summary.contracts.single['id'], '111111111111111111111111');
  });

  test('draft, cancelled, completed and rack rentals are not active rooms', () {
    final summary = ActiveRentalSummary.fromContracts([
      _activeContract(status: 'draft'),
      _activeContract(status: 'cancelled'),
      _activeContract(status: 'completed'),
      _activeContract(rentalTargetType: 'storage_rack'),
    ]);
    expect(summary.rentedUnitCount, 0);
  });

  test(
    'logout and account switch invalidate contract-derived rental data',
    () async {
      final repository = _SwitchableAuthRepository();
      var contractFetches = 0;
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          dashboardContractsProvider.overrideWith((ref) async {
            contractFetches++;
            return [
              _activeContract(
                id: repository.user?.id ?? 'cccccccccccccccccccccccc',
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);
      final authSubscription = container.listen(
        authControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final contractsSubscription = container.listen(
        dashboardContractsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(authSubscription.close);
      addTearDown(contractsSubscription.close);
      await container.read(authControllerProvider.future);
      await container.read(dashboardContractsProvider.future);
      expect(contractFetches, 1);

      await container.read(authControllerProvider.notifier).logout();
      await container.read(dashboardContractsProvider.future);
      expect(contractFetches, 2);

      await container
          .read(authControllerProvider.notifier)
          .login('next@example.invalid', 'unused-test-password');
      await container.read(dashboardContractsProvider.future);
      expect(contractFetches, 3);
    },
  );

  testWidgets(
    'dashboard displays API metrics and handles empty active storage',
    (tester) async {
      await tester.pumpWidget(_dashboardApp(summary: summary));
      await tester.pumpAndSettle();

      expect(find.text('Tổng quan kho của bạn'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('125'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dashboard keeps other sections available when summary API fails',
    (tester) async {
      await tester.pumpWidget(
        _dashboardApp(summaryError: StateError('summary unavailable')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải tổng quan kho.'), findsOneWidget);
      expect(find.text('Truy cập nhanh'), findsOneWidget);
      expect(find.text('Truy cập nhanh'), findsOneWidget);
      expect(find.text('Việc cần lưu ý'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty inventory remains zero while active rental is one', (
    tester,
  ) async {
    const emptyInventory = CustomerInventorySummary(
      totalSkus: 0,
      totalQuantity: 0,
      totalStorageUnits: 0,
      totalActiveContracts: 1,
      categoryBreakdown: [],
      recentMovements: [],
    );
    await tester.pumpWidget(
      _dashboardApp(summary: emptyInventory, contracts: [_activeContract()]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rentedUnitsValue')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rentedUnitsValue'))).data,
      '1',
    );
    expect(find.text('Phòng kho đang thuê'), findsOneWidget);
    expect(find.text('Vị trí lưu hàng'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Q1-CL-401'), findsOneWidget);
    expect(find.textContaining('Tầng 1 · Khu Q1'), findsOneWidget);
    expect(find.text('Hợp đồng: Đang hoạt động'), findsOneWidget);
    expect(find.textContaining('Thời hạn'), findsOneWidget);
  });

  testWidgets('contract loading/error is distinct from a real zero count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dashboardApp(summary: summary, contractsError: StateError('offline')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rentedUnitsValue'))).data,
      '—',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải hợp đồng đang sử dụng.'), findsOneWidget);

    await tester.pumpWidget(
      _dashboardApp(
        key: const ValueKey('contracts-empty'),
        summary: summary,
        contracts: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rentedUnitsValue'))).data,
      '0',
    );
  });

  testWidgets('pull to refresh picks up backend contract activation', (
    tester,
  ) async {
    var contracts = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _dashboardApp(summary: summary, contractSource: () => contracts),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rentedUnitsValue'))).data,
      '0',
    );

    contracts = [_activeContract()];
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rentedUnitsValue'))).data,
      '1',
    );
  });
}

Widget _dashboardApp({
  Key? key,
  CustomerInventorySummary? summary,
  Object? summaryError,
  List<Map<String, dynamic>> contracts = const [],
  Object? contractsError,
  List<Map<String, dynamic>> Function()? contractSource,
}) => ProviderScope(
  key: key,
  overrides: [
    authControllerProvider.overrideWith(_DashboardTestAuthController.new),
    dashboardInventorySummaryProvider.overrideWith((ref) async {
      if (summaryError != null) throw summaryError;
      return summary!;
    }),
    dashboardContractsProvider.overrideWith((ref) async {
      if (contractsError != null) throw contractsError;
      return contractSource?.call() ?? contracts;
    }),
    dashboardReservationsProvider.overrideWith(
      (ref) async => const <Reservation>[],
    ),
    dashboardFacilitiesProvider.overrideWith((ref) async => const <Facility>[]),
    notificationUnreadCountProvider.overrideWith((ref) async => 0),
  ],
  child: const MaterialApp(home: CustomerDashboardScreen()),
);

Map<String, dynamic> _activeContract({
  String id = '111111111111111111111111',
  String status = 'active',
  String rentalTargetType = 'storage_unit',
}) => {
  'id': id,
  'contractCode': 'CTR-TEST-001',
  'status': status,
  'rentalTargetType': rentalTargetType,
  'storageUnitId': 'aaaaaaaaaaaaaaaaaaaaaaaa',
  'facility': {'name': 'Kho thử nghiệm'},
  'storageUnit': {
    'id': 'aaaaaaaaaaaaaaaaaaaaaaaa',
    'unitNumber': 'Q1-CL-401',
    'floor': 1,
    'zone': 'Q1',
    'status': 'occupied',
  },
  'startDate': '2026-10-01T00:00:00.000Z',
  'endDate': '2027-10-01T00:00:00.000Z',
};

class _DashboardTestAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 'customer-test',
    name: 'Test Customer',
    email: 'customer@example.invalid',
    role: 'customer',
  );
}

class _SwitchableAuthRepository extends AuthRepository {
  _SwitchableAuthRepository() : super(Dio(), ApiClient(dio: Dio()));

  AuthUser? user = const AuthUser(
    id: 'aaaaaaaaaaaaaaaaaaaaaaaa',
    name: 'Account A',
    email: 'a@example.invalid',
    role: 'customer',
  );

  @override
  Future<AuthUser?> restore() async => user;

  @override
  Future<void> logout() async {
    user = null;
  }

  @override
  Future<AuthUser> login(String email, String password) async {
    user = const AuthUser(
      id: 'bbbbbbbbbbbbbbbbbbbbbbbb',
      name: 'Account B',
      email: 'b@example.invalid',
      role: 'customer',
    );
    return user!;
  }
}
