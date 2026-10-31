# Stitch Flutter Customer — Android Emulator UI/UX QA

**Date:** 2026-10-30  
**Scope:** Flutter Customer `/home`, `/explore`, `/reservations/create`, `/payments/:id`  
**Result:** Automated regression checks PASS; requested four-screen emulator visual QA BLOCKED by app routing/auth access. No production journey E2E claim.

## 1. Device and environment

| Item | Result |
|---|---|
| Flutter / Dart | Flutter 3.47.3 stable; Dart 3.13.3 |
| Android SDK | SDK 37.0.0; Android toolchain and licenses available |
| AVD | `Small_Phone`, connected as `emulator-5554`; emulator product `sdk_gphone16k_x86_64` |
| Android version | 17 |
| Display | 720×1280 physical pixels, density 320 dpi (approximately 360×640 dp) |
| Flutter device list | Emulator plus Windows, Chrome and Edge |
| `flutter doctor -v` | Android toolchain passed. Visual Studio missing for Windows desktop only; unrelated to Android. |

The Flutter debug app was installed and launched. The package was not installed on this AVD before the run, so no previous customer session was reused. No credentials were entered.

## 2. Screens opened

| Screen | Emulator result | Evidence |
|---|---|---|
| Home `/home` | **BLOCKED** by auth redirect; no authorized test account/session provided | Not rendered |
| Explore `/explore` | **BLOCKED for this emulator run.** `flutter run --route /explore` and an Android activity route extra both landed on Login because the app starts at `/splash`, which redirects signed-out users to `/login`. Explore is not listed as guarded, but Login has no Explore link and platform route launch did not override the configured GoRouter initial location. | Screenshot below shows the actual Login screen, not Explore. |
| Reservation Create `/reservations/create` | **BLOCKED** by auth redirect; no authorized test account/session provided | Not rendered |
| Payment `/payments/:id` | **BLOCKED** by auth redirect; no authorized test account/session provided | Not rendered |

Actual screenshot captured from the running AVD:

`docs/flutter/screenshots/stitch-android-qa-2026-10-30/login-auth-gate-small-phone.png`

The screenshot is intentionally named for the screen it shows. It is not evidence that any of the four Stitch screens rendered.

## 3. Stitch versus Flutter source review

The four Stitch HTML files and current Flutter source were reviewed. This comparison is source-based because the target screens could not be opened on the emulator.

| Reference | Source-level implementation reviewed | Illustrative elements excluded | On-device visual comparison |
|---|---|---|---|
| A2 Home Dashboard | API-backed inventory metrics, active contracts, pending reservations, recent movements, facility listing, quick actions and existing shell navigation | Fixed sample name/unit/reservation, fake activity/telemetry, wallet-payment claims and smart-lock/QR/Bluetooth access | **Not performed — auth blocked** |
| A3 Explore | Searchable facility listing, server facility fields, API images with fallback, facility selection/detail navigation, loading/empty/error/retry states | Fictional facilities, distances, promotions, guarantees and unsupported service claims | **Not performed — route entry landed on Login** |
| A4 Reservation Create | Existing unit and facility/date availability calls, local date-only query, API-returned slot/unit validation, date refresh and guarded submit; facility/offering summary uses existing facility detail repository | Fixed dates, fake unit/slot/capacity/prices, fabricated totals/insurance and 15-minute hold claims | **Not performed — auth blocked** |
| A6 Payment | Payment amount/reference/expiry/status/bank details from the payment model, backend `qrUrl`, repository status polling, `paid`-only success | Decorative SVG QR, fixed account/bank/amount, client-side timer and simulated confirmation | **Not performed — auth blocked** |

## 4. Layout and interaction findings

- The Login screen rendered at approximately 360 dp wide without a visible overflow or clipping issue in the captured frame. Filtered emulator logcat contained no `RenderFlex`, `overflow`, `Exception`, or fatal runtime lines during this short run.
- This does **not** establish the four target screens are free of overflow. Their small-width rendering, SafeArea/bottom-tab spacing, 200% text scale, scroll behavior and keyboard overlap remain unverified on device.
- Explore search, result cards and selection are covered by repository/widget mocks, but on-device typing, keyboard behavior and facility detail navigation were not exercised.
- Reservation physical-unit selection, date-change availability refresh, valid-slot/button guards, availability error handling and request payload have mocked regression coverage; no emulator interaction or reservation submission was performed.
- Payment pending UI and backend-sourced amount/reference/bank display have widget-mock coverage; model tests cover `pending`, `partially_paid`, `paid`, `expired` and `cancelled` terminal/polling rules. No emulator payment screen, QR image, payment creation, or real transfer was exercised.
- Home API metrics and independent summary-error behavior are mocked-tested. Quick-action navigation was not exercised on device.

No Flutter visual fixes were applied: no confirmed defect in the four target screens could be observed while those screens were inaccessible. The router/auth gate and business behavior were left unchanged.

## 5. Automated verification

| Command | Result |
|---|---|
| `flutter analyze --no-pub` | PASS — no issues found |
| `flutter test --no-pub` | PASS — all 39 tests passed (mocked/local fixtures) |
| `flutter build apk --debug --no-pub` | PASS — Gradle `assembleDebug` succeeded and APK installed/launched on the AVD |
| `git diff --check` | PASS — no whitespace errors; Git emitted existing LF-to-CRLF normalization notices |

Automated mocks validate app behavior but are not live API or production E2E evidence.

## 6. Remaining blockers

1. Provide an explicitly authorized QA account/session on a test backend to inspect Home, Reservation Create and Payment without using production customer credentials.
2. Provide a supported way to open the public Explore route from a signed-out launch (for example, an approved test navigation entry/deep-link configuration) or an accessible emulator session. No auth guard was bypassed in this QA.
3. Repeat visual checks for all four screens at 320–360 dp, standard/enlarged text, keyboard open, scroll boundaries, loading/empty/error states, and Android system navigation.
4. Exercise real backend read-only facility data only in the authorized test environment. Keep reservation/payment writes disabled until a suitable test environment and explicit authorization exist.

## 7. Readiness for next UI phase

**Not yet visually verified / not ready to mark complete.** Analyzer, mocked tests and debug build pass, but only Login was actually rendered. Do not treat this as customer journey E2E PASS or as final emulator approval for the four Stitch screens. Repeat emulator QA after the access blockers above are resolved.
