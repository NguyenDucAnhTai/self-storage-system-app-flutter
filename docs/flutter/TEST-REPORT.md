# Flutter Test Report

## Verified

- `flutter pub get` — succeeded.
- `flutter analyze --no-pub` — succeeded with **No issues found**.
- `flutter test --no-pub` — succeeded; 13 tests passed (3 DTO/status tests and 10 integration contract tests).
- `flutter build apk --debug --no-pub` — succeeded; APK at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — clean on the final source diff.

## Not verified

- No Flutter app was run on an emulator/device in this session.
- No backend runtime, customer credentials, or real facility data were provided, so real API and full customer journey verification remain blocked.
- No real or test monetary transaction was attempted.
- Automated coverage uses a mocked Dio HTTP adapter; it covers auth token persistence/session restoration/expired session/401 refresh retry, facility search filters/empty results, reservation create payload and local required/date validation, payment session QR parsing and bounded poll cancellation/timeout, API errors, and terminal statuses. It does not exercise GoRouter redirects, reservation conflict/cancel endpoints, facility detail runtime responses, or live backend behavior.

## Earlier build diagnostics

The first Gradle build attempts exposed stale D8 intermediates and an incomplete CMake install collision. Generated Flutter outputs were cleaned, dependencies restored, and one serialized final build succeeded. These transient errors did not require backend or application source changes.
