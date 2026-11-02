# Flutter Test Report

## Verified (source and local test environment)

- `flutter pub get` — succeeded.
- `flutter analyze --no-pub` — succeeded with **No issues found**.
- `flutter test --no-pub` — succeeded; **36 tests passed** (run 2026-10-23), including dashboard redirect/widgets and inventory-summary parsing/repository coverage.
- `flutter build apk --debug --no-pub` — succeeded (run 2026-10-23); APK at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — succeeded; no whitespace errors (Git reports existing LF-to-CRLF normalization warnings on modified files).

## Latest verification (2026-10-23)

- `flutter pub get` — succeeded; 9 packages have newer versions outside current dependency constraints.
- `flutter analyze --no-pub` — **No issues found**.
- `flutter test --no-pub` — **36 tests passed**.
- `flutter build apk --debug --no-pub` — **succeeded**; debug APK generated at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Device test — not performed in this dashboard turn. No authorized customer test account was supplied, so authenticated Home data/screens cannot be safely verified on Android.

## Not verified

- Dashboard redirect/widget/repository tests use local providers and mocked Dio. They do not prove production response compatibility or authenticated navigation on a device.
- No permitted authenticated customer test account was provided; dashboard data and account scoping are not live-verified.
- No backend runtime, customer credentials, or real facility data were provided, so real API and full customer journey verification remain blocked.
- No real or test monetary transaction was attempted.
- Automated coverage uses mocked Dio/providers. It covers auth/session redirects, dashboard summary parsing and section failure, auth token persistence/session restoration/expired session/401 refresh retry, facility search filters/empty results, reservation availability/date refresh/validation/payload, payment QR parsing and bounded poll cancellation/timeout, API errors and terminal states. It does not exercise live backend behavior, production account ownership, or payment rails.

## Dashboard/API safety status

- Public Swagger snapshot: OpenAPI 3.0.0, Render production server, 149 operations across 21 tags; inventoried in [API-FEATURE-GAP-ANALYSIS.md](API-FEATURE-GAP-ANALYSIS.md).
- Dashboard uses read endpoints in source. No business endpoint was called in production for this change, and no reservation/payment/inventory mutation was performed.
- Several operations have omitted/inconsistent security declarations despite auth error responses; server-side customer authorization and data scoping remain blockers. See [BACKEND-BLOCKERS.md](BACKEND-BLOCKERS.md).
- Device visual verification requires an authorized test account. Do not mark end-to-end complete until permitted runtime evidence is recorded.

## Earlier build diagnostics

The first Gradle build attempts exposed stale D8 intermediates and an incomplete CMake install collision. Generated Flutter outputs were cleaned, dependencies restored, and one serialized final build succeeded. These transient errors did not require backend or application source changes.
