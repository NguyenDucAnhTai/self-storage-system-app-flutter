# Flutter Feature Status

| Requirement | Status | Evidence / limitation |
| --- | --- | --- |
| App initialization, theme, routing | DONE | Riverpod app root, Material theme, GoRouter session redirects and customer navigation implemented. |
| Shared API client | DONE | One Dio instance; bearer token, secure storage and serialized refresh/retry implemented. |
| Login/register/session restore | PARTIAL | Real API calls implemented; no live backend/account verification. |
| Profile/password flows | PARTIAL | Profile read/address update and backend password operations implemented; live backend not verified. |
| Facility search/detail | PARTIAL | Real public endpoints and UI implemented; live backend not verified. |
| Unit and time-slot availability | PARTIAL | Real endpoints wired and date/slot selection implemented; live backend not verified. |
| Reservation create/list/detail/cancel | PARTIAL | Real endpoints wired; no live backend verification. |
| Deposit payment/QR/polling | PARTIAL | Backend-generated QR only, bounded polling and terminal handling; SePay/live payment not verified. |
| Contracts/storage renewal | PARTIAL | Backend list/detail/terms acceptance/renewal calls implemented; customer endpoint authorization TODO and no runtime verification. |
| Notifications | PARTIAL | List/read endpoints implemented; live backend not verified. |
| Support requests | BLOCKED | No customer support-request module or API was found in BE source. |
| Flutter static analysis | DONE | `flutter analyze --no-pub` — no issues found. |
| Automated tests | PARTIAL | 13 DTO/status and repository/client contract tests pass. Protected route redirects and full lifecycle against a live backend remain unverified. |
| Android debug APK | DONE | `flutter build apk --debug --no-pub` succeeded at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| Real backend end-to-end | BLOCKED | No backend runtime URL, customer test credentials, or seeded test data supplied. No payment transaction was attempted. |
