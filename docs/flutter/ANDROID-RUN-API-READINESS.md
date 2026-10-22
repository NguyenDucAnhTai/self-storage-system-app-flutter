# Android Run & Real API Readiness

> Historical device snapshot from before the Render production URL was supplied. Current API connectivity and production configuration are documented in [RENDER-PRODUCTION-INTEGRATION.md](RENDER-PRODUCTION-INTEGRATION.md).

**Date:** 2026-10-22  
**Overall:** PARTIAL — Android startup and unauthenticated navigation verified on an emulator. Real API flows and authenticated screens remain NOT VERIFIED.

## Environment

| Check | Result |
| --- | --- |
| Flutter | PASS — stable 3.47.3, Dart 3.13.3 at `D:\flutter`. |
| Android SDK/toolchain | PASS — SDK 37.0.0 at `C:\Users\laptop\AppData\Local\Android\Sdk`; build tools 37.0.0; emulator 36.5.11; licenses accepted; bundled Java 21. |
| `flutter doctor -v` | Android checks pass. Visual Studio is absent for Windows desktop builds, which does not block Android. |
| AVDs | Pixel_6 and Small_Phone available. Pixel_6 launched successfully (emulator-5554; Android 17/API 37, x86_64). |
| Physical device | None attached. ADB executable is installed under SDK `platform-tools` but not on PATH; use its full path or add platform-tools to PATH. |
| Debug APK | PASS — rebuilt at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`, installed and launched successfully. |

## Device checks

| Flow | Status | Result |
| --- | --- | --- |
| Cold start / app startup | PASS | Flutter splash resolved to Login. `MainActivity` remained foreground. No app `FATAL EXCEPTION` or Flutter startup error was found in the inspected log window. |
| Login screen | PASS | Rendered at 1080×2400. Email/password fields and Forgot password, Sign in, and Create account controls displayed. |
| Register screen | PASS | Reached from Create account. Form fits the available viewport and scrolls. The Send email code control is enabled while idle after fixing its inverted busy condition. No OTP request was submitted. |
| Back navigation | PASS | Android Back from Register returned to Login. |
| Keyboard/IME | PARTIAL | Register field focus was checked; this AVD exposed an IME toolbar but did not show a normal soft keyboard. Keyboard overlap behavior is therefore not fully verified. |
| Explore/facility detail/reservation/payment/profile/contracts/notifications | NOT VERIFIED | These flows require authenticated navigation and/or backend data. No credentials were available, and protected flows were not bypassed. No reservation/payment requests were initiated. |
| Loading, error, disconnected API | PARTIAL | Startup loading resolved. No test backend was listening on local port 5000, so real API error rendering and data-backed screen states were not exercised. |
| Screen overflow / lifecycle / QR | NOT VERIFIED | No complete authenticated/device scenario or payment QR was available. |

Screenshots captured from this emulator:

- [Login](device-login.png)
- [Register](device-register.png)

## API and transport readiness

- `API_BASE_URL` is compile-time configured with `--dart-define`; the current default is `https://self-storage-system-be.onrender.com`.
- Host loopback TCP port 5000 was not listening during the check. No approved remote test URL or test credentials were supplied; no authenticated HTTP status/response was obtained.
- INTERNET permission is present. Cleartext HTTP is now enabled only through `src/debug/AndroidManifest.xml`; the main/release manifest no longer opts into cleartext. Release builds must supply an HTTPS URL.
- Bearer token handling remains through `flutter_secure_storage` and shared Dio. No token was available in the emulator, and the auth refresh path was validated by automated tests rather than a live server.
- Backend reservation/payment/contract authorization TODOs remain blockers documented in [BACKEND-BLOCKERS.md](BACKEND-BLOCKERS.md) and [SECURITY-REVIEW.md](SECURITY-REVIEW.md).

## Change and verification

Device review found and fixed an inverted busy condition that disabled the Register screen's Send email code button at idle. Android transport configuration was also tightened so cleartext is debug-only. After these changes:

- `flutter analyze --no-pub` — PASS, no issues.
- `flutter test --no-pub` — PASS, all 13 tests.
- `flutter build apk --debug --no-pub` — PASS; rebuilt APK installed and launched on Pixel_6.

## How to run with a permitted test backend

Run from `apps/flutter_mobile` to use the Render default:

```bash
flutter run
```

For approved staging, pass its HTTPS base URL explicitly. Obtain test credentials and seeded facility/unit/slot data from the environment owner. First perform read-only login/session and facility calls. Only proceed to reservation/payment if the environment and account explicitly authorize those actions; the app does not consider payment successful until the backend reports `paid`.
