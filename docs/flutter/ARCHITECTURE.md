# Flutter Mobile Architecture

## App layers

- `lib/main.dart`: Riverpod root, Material 3 theme and router.
- `lib/app/router.dart`: GoRouter routes, session-aware redirects and customer bottom navigation.
- `lib/core/config`: centralized `API_BASE_URL` environment setting. The default is the Render production API; an explicit `--dart-define=API_BASE_URL=...` can select staging or another approved environment.
- `lib/core/network`: one shared Dio client, secure token storage, bearer attachment, serialized refresh-and-retry, and API error normalization.
- `lib/core/providers`: shared API and reservation/payment dependency providers.
- `lib/features/auth`: email OTP registration, login, session restore, refresh, logout and password reset.
- `lib/features/explore`: facility search/list and public facility details with unit-type pricing/availability.
- `lib/features/reservations`: physical unit and time-slot availability, create/list/detail/cancel.
- `lib/features/payments`: backend VietQR display and bounded payment polling.
- `lib/features/contracts`, `profile`, `notifications`: supported contract, profile and notification operations.

Feature repositories receive the shared Dio instance. Authentication tokens are stored using `flutter_secure_storage`; passwords are sent only to the backend and are never persisted locally.

## Android networking

By default the app connects to `https://self-storage-system-be.onrender.com`. Override with `--dart-define=API_BASE_URL=https://...` for an approved staging environment. The Android debug manifest permits HTTP only for local development; the main/release manifest does not enable cleartext traffic. TLS certificate validation remains enabled by Dio's platform transport.

## Not implemented

Customer support requests have no corresponding backend support-request API in the inspected backend. Smart locks, simulated payment and fake reservation success are not implemented.
