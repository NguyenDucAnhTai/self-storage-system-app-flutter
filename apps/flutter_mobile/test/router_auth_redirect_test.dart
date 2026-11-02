import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/app/router.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('holds protected paths while authentication is restoring', () {
      expect(
        resolveAuthRedirect(
          authLoading: true,
          signedIn: false,
          path: '/contracts/contract-1',
          currentUri: '/contracts/contract-1',
        ),
        '/splash',
      );
      expect(
        resolveAuthRedirect(
          authLoading: true,
          signedIn: false,
          path: '/login',
          currentUri: '/login',
        ),
        isNull,
      );
    });

    test('guards dashboard and nested customer module routes', () {
      for (final path in [
        '/home',
        '/contracts',
        '/contracts/contract-1',
        '/contracts/contract-1/settlement',
        '/refunds',
        '/refunds/refund-1',
        '/support',
        '/support/ticket-1',
        '/incidents',
        '/incidents/incident-1',
        '/storage',
      ]) {
        final redirect = resolveAuthRedirect(
          authLoading: false,
          signedIn: false,
          path: path,
          currentUri: path,
        );
        expect(redirect, startsWith('/login?from='), reason: path);
        expect(Uri.parse(redirect!).queryParameters['from'], path);
      }
    });

    test('restores safe in-app return path after sign in', () {
      expect(
        resolveAuthRedirect(
          authLoading: false,
          signedIn: true,
          path: '/login',
          currentUri: '/login?from=%2Fcontracts%2Fcontract-1',
        ),
        '/contracts/contract-1',
      );
      expect(
        resolveAuthRedirect(
          authLoading: false,
          signedIn: true,
          path: '/login',
          currentUri: '/login?from=%2F%2Fevil.example',
        ),
        '/home',
      );
    });

    test('sends signed-in sessions from splash to Home', () {
      expect(
        resolveAuthRedirect(
          authLoading: false,
          signedIn: true,
          path: '/splash',
          currentUri: '/splash',
        ),
        '/home',
      );
    });
  });
}
