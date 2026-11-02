import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/explore/application/facility_providers.dart';
import '../features/explore/presentation/screens/explore_screen.dart';
import '../features/explore/presentation/screens/facility_detail_screen.dart';
import '../features/dashboard/presentation/customer_dashboard_screen.dart';
import '../features/dashboard/application/dashboard_providers.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/change_password_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/contracts/presentation/contracts_screen.dart';
import '../features/contracts/presentation/contract_detail_route_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/reservations/data/models/reservation.dart';
import '../features/reservations/presentation/screens/reservation_create_screen.dart';
import '../features/reservations/presentation/screens/reservation_detail_screen.dart';
import '../features/reservations/presentation/screens/reservation_list_screen.dart';
import '../features/payments/application/payment_status_tracker.dart';
import '../features/payments/presentation/screens/payment_screen.dart';
import '../features/payments/presentation/screens/payment_history_screen.dart';
import '../features/contracts/presentation/contract_settlement_screen.dart';
import '../features/refunds/presentation/refund_screens.dart';
import '../features/customer_care/customer_care.dart';
import '../features/customer_care/customer_care_screens.dart';
import '../features/amenities/amenity_repository.dart';
import '../features/storage/presentation/storage_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  final features = ref.watch(reservationPaymentProvider);
  final facilityRepo = ref.watch(facilityRepositoryProvider);
  final amenityRepo = AmenityRepository(ref.watch(dioProvider));
  final careRepo = CustomerCareRepository(ref.watch(dioProvider));
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      if (auth.isLoading) {
        return path == '/splash' || path == '/login' || path == '/register'
            ? null
            : '/splash';
      }
      final signedIn = auth.value != null;
      if (path == '/splash') return signedIn ? '/explore' : '/login';
      final guarded =
          path.startsWith('/reservations') ||
          path.startsWith('/payments') ||
          path == '/profile' ||
          path == '/change-password' ||
          path == '/contracts' ||
          path == '/storage' ||
          path == '/notifications';
      if (guarded && !signedIn) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (signedIn && (path == '/login' || path == '/register')) {
        final from = state.uri.queryParameters['from'];
        if (path == '/login' &&
            from != null &&
            from.startsWith('/') &&
            !from.startsWith('//')) {
          return from;
        }
        return '/explore';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginScreen(returnTo: state.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) => const CustomerDashboardScreen(),
          ),
          GoRoute(
            path: '/explore',
            builder: (context, _) => ExploreScreen(
              repository: facilityRepo,
              amenityRepository: amenityRepo,
              onSelect: (f) => context.push('/facilities/${f.id}'),
            ),
          ),
          GoRoute(
            path: '/facilities/:id',
            builder: (context, state) => FacilityDetailScreen(
              facilityId: state.pathParameters['id']!,
              repository: facilityRepo,
              availabilityRepository: features.reservations,
              amenityRepository: amenityRepo,
              onBook: (selection) {
                if (ref.read(authControllerProvider).value == null) {
                  context.go(
                    '/login?from=${Uri.encodeComponent('/reservations/create?facilityId=${selection.facility.id}&offeringId=${selection.offering.id}&unitTypeId=${selection.offering.unitTypeId}&minRentalDays=${selection.offering.minRentalDays}')}',
                  );
                  return;
                }
                context.push(
                  '/reservations/create?facilityId=${selection.facility.id}&offeringId=${selection.offering.id}&unitTypeId=${selection.offering.unitTypeId}&minRentalDays=${selection.offering.minRentalDays}',
                );
              },
            ),
          ),
          GoRoute(
            path: '/reservations/create',
            builder: (context, state) => ReservationCreateScreen(
              facilityId: state.uri.queryParameters['facilityId'] ?? '',
              offeringId: state.uri.queryParameters['offeringId'] ?? '',
              unitTypeId: state.uri.queryParameters['unitTypeId'] ?? '',
              minRentalDays:
                  int.tryParse(
                    state.uri.queryParameters['minRentalDays'] ?? '',
                  ) ??
                  1,
              repository: features.reservations,
              facilityRepository: facilityRepo,
              amenityRepository: amenityRepo,
              onCreated: (r) {
                ref.invalidate(dashboardInventorySummaryProvider);
                ref.invalidate(dashboardContractsProvider);
                ref.invalidate(dashboardReservationsProvider);
                context.go('/payments/${r.id}');
              },
            ),
          ),
          GoRoute(
            path: '/reservations',
            builder: (context, _) => ReservationListScreen(
              repository: features.reservations,
              onSelect: (r) => context.push('/reservations/${r.id}'),
            ),
          ),
          GoRoute(
            path: '/reservations/:id',
            builder: (context, state) => ReservationDetailScreen(
              reservationId: state.pathParameters['id']!,
              repository: features.reservations,
              onReservationChanged: () {
                ref.invalidate(dashboardInventorySummaryProvider);
                ref.invalidate(dashboardContractsProvider);
                ref.invalidate(dashboardReservationsProvider);
              },
              onPayment: (Reservation r) => context.push('/payments/${r.id}'),
            ),
          ),
          GoRoute(
            path: '/payments/history',
            builder: (_, _) => const PaymentHistoryScreen(),
          ),
          GoRoute(
            path: '/payments/:id/view',
            builder: (context, state) => PaymentScreen(
              existingPaymentId: state.pathParameters['id']!,
              expectedContractId: state.uri.queryParameters['contractId'],
              expectedReservationId: state.uri.queryParameters['reservationId'],
              repository: features.payments,
              tracker: PaymentStatusTracker(features.payments),
              onOpenReservation:
                  _validId(state.uri.queryParameters['reservationId'])
                  ? () => context.push(
                      '/reservations/${Uri.encodeComponent(state.uri.queryParameters['reservationId']!)}',
                    )
                  : null,
              onOpenContract: _validId(state.uri.queryParameters['contractId'])
                  ? () => context.push(
                      '/contracts/${Uri.encodeComponent(state.uri.queryParameters['contractId']!)}',
                    )
                  : null,
              onPaymentStatusChanged: () {
                ref.invalidate(dashboardInventorySummaryProvider);
                ref.invalidate(dashboardContractsProvider);
                ref.invalidate(dashboardReservationsProvider);
              },
            ),
          ),
          GoRoute(
            path: '/payments/:id',
            builder: (context, state) => PaymentScreen(
              reservationId: state.pathParameters['id']!,
              repository: features.payments,
              tracker: PaymentStatusTracker(features.payments),
              onPaymentStatusChanged: () {
                ref.invalidate(dashboardInventorySummaryProvider);
                ref.invalidate(dashboardContractsProvider);
                ref.invalidate(dashboardReservationsProvider);
              },
            ),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/change-password',
            builder: (_, _) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: '/contracts',
            builder: (_, _) => ContractsScreen(dio: ref.read(dioProvider)),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

bool _validId(String? value) =>
    value != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(value);

String? resolveAuthRedirect({
  required bool authLoading,
  required bool signedIn,
  required String path,
  required String currentUri,
}) {
  if (authLoading) return path == '/splash' ? null : '/splash';
  if (path == '/splash') return signedIn ? '/home' : '/login';
  final guarded =
      path == '/home' ||
      path.startsWith('/reservations') ||
      path.startsWith('/payments') ||
      path == '/profile' ||
      path == '/change-password' ||
      path.startsWith('/contracts') ||
      path.startsWith('/support') ||
      path.startsWith('/incidents') ||
      path == '/notifications';
  if (guarded && !signedIn) {
    return '/login?from=${Uri.encodeComponent(currentUri)}';
  }
  if (signedIn && (path == '/login' || path == '/register')) return '/home';
  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});
  final String location;
  final Widget child;
  int get _index => location.startsWith('/profile') || location == '/storage'
      ? 3
      : location.startsWith('/reservations') || location.startsWith('/payments')
      ? 2
      : location.startsWith('/explore') || location.startsWith('/facilities')
      ? 1
      : 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F3515),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => context.go(switch (i) {
                0 => '/home',
                1 => '/explore',
                2 => '/reservations',
                _ => '/profile',
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Khám phá',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Đơn đặt kho',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Cá nhân',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
