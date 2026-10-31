import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/app/router.dart';
import 'package:flutter_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_mobile/features/auth/data/models/auth_user.dart';
import 'package:flutter_mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:flutter_mobile/features/dashboard/data/customer_inventory_summary.dart';
import 'package:flutter_mobile/features/dashboard/presentation/customer_dashboard_screen.dart';
import 'package:flutter_mobile/features/explore/data/models/facility.dart';
import 'package:flutter_mobile/features/notifications/application/notification_providers.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';

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
}

Widget _dashboardApp({
  CustomerInventorySummary? summary,
  Object? summaryError,
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_DashboardTestAuthController.new),
    dashboardInventorySummaryProvider.overrideWith((ref) async {
      if (summaryError != null) throw summaryError;
      return summary!;
    }),
    dashboardContractsProvider.overrideWith((ref) async => const []),
    dashboardReservationsProvider.overrideWith(
      (ref) async => const <Reservation>[],
    ),
    dashboardFacilitiesProvider.overrideWith((ref) async => const <Facility>[]),
    notificationUnreadCountProvider.overrideWith((ref) async => 0),
  ],
  child: const MaterialApp(home: CustomerDashboardScreen()),
);

class _DashboardTestAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 'customer-test',
    name: 'Test Customer',
    email: 'customer@example.invalid',
    role: 'customer',
  );
}
