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
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/change_password_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/contracts/presentation/contracts_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/reservations/data/models/reservation.dart';
import '../features/reservations/presentation/screens/reservation_create_screen.dart';
import '../features/reservations/presentation/screens/reservation_detail_screen.dart';
import '../features/reservations/presentation/screens/reservation_list_screen.dart';
import '../features/payments/application/payment_status_tracker.dart';
import '../features/payments/presentation/screens/payment_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final features = ref.watch(reservationPaymentProvider);
  final facilityRepo = ref.watch(facilityRepositoryProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (auth.isLoading) return path == '/splash' ? null : '/splash';
      final signedIn = auth.value != null;
      if (path == '/splash') return signedIn ? '/explore' : '/login';
      final guarded =
          path.startsWith('/reservations') ||
          path.startsWith('/payments') ||
          path == '/profile' ||
          path == '/change-password' ||
          path == '/contracts' ||
          path == '/notifications';
      if (guarded && !signedIn) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (signedIn && (path == '/login' || path == '/register')) {
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
            path: '/explore',
            builder: (context, _) => ExploreScreen(
              repository: facilityRepo,
              onSelect: (f) => context.push('/facilities/${f.id}'),
            ),
          ),
          GoRoute(
            path: '/facilities/:id',
            builder: (context, state) => FacilityDetailScreen(
              facilityId: state.pathParameters['id']!,
              repository: facilityRepo,
              onBook: (selection) {
                if (auth.value == null) {
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
              onCreated: (r) => context.go('/payments/${r.id}'),
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
              onPayment: (Reservation r) => context.push('/payments/${r.id}'),
            ),
          ),
          GoRoute(
            path: '/payments/:id',
            builder: (context, state) => PaymentScreen(
              reservationId: state.pathParameters['id']!,
              repository: features.payments,
              tracker: PaymentStatusTracker(features.payments),
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
            builder: (_, _) => NotificationsScreen(dio: ref.read(dioProvider)),
          ),
        ],
      ),
    ],
  );
});

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
  int get _index => location.startsWith('/profile')
      ? 2
      : location.startsWith('/reservations') || location.startsWith('/payments')
      ? 1
      : 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => context.go(switch (i) {
        0 => '/explore',
        1 => '/reservations',
        _ => '/profile',
      }),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'My bookings',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
