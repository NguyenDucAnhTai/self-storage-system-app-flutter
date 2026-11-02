# Stitch Visual Refinement Report

**Date:** 2026-10-31  
**Scope:** Flutter Customer UI only; existing navigation, repositories, providers, API contracts, authentication and reservation/payment behavior preserved.

## 1. Files changed

- `apps/flutter_mobile/lib/app/router.dart` — Vietnamese labels for the existing bottom navigation.
- `apps/flutter_mobile/lib/features/dashboard/presentation/customer_dashboard_screen.dart` — Vietnamese dashboard headings, metrics, quick actions, and API-backed state copy.
- `apps/flutter_mobile/lib/features/explore/presentation/screens/explore_screen.dart` — Vietnamese search/listing copy and localized known facility-status labels.
- `apps/flutter_mobile/lib/features/explore/presentation/screens/facility_detail_screen.dart` — Vietnamese section title and removal of the duplicate floating back control; the AppBar already provides back navigation.
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_create_screen.dart` — Vietnamese booking labels, availability states, unit selector and retry copy; distinct AppBar title avoids duplicating the submit CTA label. Existing validation and explicit terms consent remain intact.
- `apps/flutter_mobile/lib/features/payments/presentation/screens/payment_screen.dart` — Vietnamese payment hierarchy and labels for backend-provided amount, status, QR, bank information, reference and expiry.
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_list_screen.dart` — Vietnamese booking-list copy and customer-facing status labels.
- `apps/flutter_mobile/test/dashboard_test.dart`, `apps/flutter_mobile/test/integration_contracts_test.dart`, `apps/flutter_mobile/test/stitch_screens_test.dart` — updated expectations for visible Vietnamese text; contract and validation assertions remain.
- `docs/flutter/STITCH-VISUAL-REFINEMENT-REPORT.md` — this report.
- `docs/flutter/screenshots/stitch-explore-android.png`, `authenticated-home-android.png`, `authenticated-bookings-android.png`, `authenticated-facility-hero-android.png`, `authenticated-facility-detail-android.png`, `authenticated-reservation-create-android.png`, `authenticated-reservation-state-android.png`, `reservation-cta-android.png` — emulator captures.

The workspace contained other pre-existing uncommitted work. It was preserved; the list above identifies files touched for this refinement and its verification.

## 2. Screens refined

- **Home Dashboard:** localized greeting, API metric card, section hierarchy, quick actions and empty/error messages. Provider-backed metric, contract, reservation, activity and facility data are unchanged.
- **Explore:** localized search heading, hint, card supporting text, status chip and empty/error copy. Search debounce, API results, facility images and navigation are unchanged.
- **Facility Detail:** localized title and available-unit-type heading; removed duplicate back button noticed during device inspection. Availability and offering information remain API-backed.
- **Reservation Create:** localized date/time/unit/duration/retry states and existing CTA. Availability queries, selected physical unit and slot, rental duration validation, submission guards and unchecked `termsAccepted` consent are preserved.
- **Payment:** localized and grouped the amount, backend status, backend QR, transfer details, payment reference, expiry and status-check actions. No QR, amount, transfer detail or success state is invented; only backend `paid` remains successful.
- **My Bookings:** localized title, empty/error states, unit/detail labels and known status presentation. Unknown backend statuses keep their raw value.
- **App shell:** localized the existing four navigation labels and retained selected navigation behavior.

## 3. Stitch elements matched

- Large section headings and supporting copy with generous vertical spacing.
- Rounded search field and facility cards with prominent image, status badge, location row and detail affordance.
- Facility hero image followed by facility information and available offering section.
- Reservation form grouped into date, time-slot, physical-unit, duration, consent and confirmation sections.
- Payment amount/status hero, QR card, transfer-information card, reference/expiry rows and clear status-check action.
- Consistent green/mint palette, rounded card treatment and existing bottom-navigation selected pill.

## 4. Intentionally omitted

Stitch HTML demo values and interactions were not copied: sample bookings/metrics, fabricated availability or discounts, unsupported distance claims, countdown promises, payment completion simulation, hardcoded bank details/QR, and smart-lock/door access controls. The payment display is based only on the current `Payment` model. No business-flow or Backend changes were made.

## 5. Localization

Customer-facing navigation and requested core screens were translated to Vietnamese. Backend enum values and identifiers remain unchanged internally. Known reservation/payment status values are mapped only for display; unknown values remain visible as returned. Existing dates use the app’s current Flutter locale formatter; a project-wide locale/delegate migration was outside this UI pass.

## 6. Emulator screenshots and screen access

Device: **sdk gphone16k x86 64, Android 17 (API 37), emulator-5554**, 720×1280 physical pixels (360×640 dp). The debug app installed and launched successfully.

- Home Dashboard (authenticated): [authenticated-home-android.png](screenshots/authenticated-home-android.png)
- Explore (actual facility listing rendered): [stitch-explore-android.png](screenshots/stitch-explore-android.png)
- Facility Detail (hero and facility information): [authenticated-facility-hero-android.png](screenshots/authenticated-facility-hero-android.png)
- Facility Detail (available offering and unit state): [authenticated-facility-detail-android.png](screenshots/authenticated-facility-detail-android.png)
- My Bookings (authenticated empty state): [authenticated-bookings-android.png](screenshots/authenticated-bookings-android.png)
- Reservation Create (facility summary): [authenticated-reservation-create-android.png](screenshots/authenticated-reservation-create-android.png)
- Reservation Create (real slots and unit availability loaded for 2026-11-01): [authenticated-reservation-state-android.png](screenshots/authenticated-reservation-state-android.png)
- Reservation Create (consent unchecked; submit disabled): [reservation-cta-android.png](screenshots/reservation-cta-android.png)

Signed in with the test account supplied by the user. Home, My Bookings, Explore, Facility Detail and Reservation Create were opened on device. Home metrics displayed zero; My Bookings displayed the empty state. The facility detail showed an offering with one available physical unit. On Reservation Create, selecting 2026-11-01 loaded available time slots and a physical unit (`BT-ST-202`, Floor 2). The terms checkbox remained unchecked, so the CTA remained disabled. Only read requests were used; no reservation POST was sent.

Payment was **not** opened. `PaymentScreen.initState` creates a reservation deposit session using POST, and My Bookings had no existing reservation. Opening the screen would mutate Backend state. No payment session or financial transaction was created.

Visual comparison was performed against the four HTML references in `docs/stitch_flutter_handoff/` and the constraints in `docs/flutter/STITCH-SCREEN-BRIEF.md`. Five of the six requested screens were inspected on-device; Payment remains unverified on-device.

## 7. Verification results

Executed in `apps/flutter_mobile/`:

- `flutter analyze --no-pub` — **PASS**, no issues found.
- `flutter test --no-pub` — **PASS**, all 48 tests passed.
- `flutter build apk --debug --no-pub` — **PASS**, generated `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — **PASS**. Git printed its standard LF-to-CRLF working-copy notices for already modified text files; no whitespace errors were reported.
- `flutter doctor -v` — Android toolchain and connected emulator available. Visual Studio for Windows desktop development is missing; it does not affect Android APK build.
- Device install/launch — **PASS**. Public Explore route was opened through Flutter’s route argument; facility detail was opened by tapping the actual listing. Only read-only listing/detail requests were involved.

## 8. Remaining UI gaps and readiness

- Payment runtime states remain unverified because opening the screen would create a payment session. A safe QA session needs a non-mutating preview/test path or explicit authorization to create a test payment session in a suitable environment.
- System date strings continue to use the app’s existing Flutter locale formatting (for example, the date picker shows English weekday/month text); Vietnamese locale configuration remains a separate localization task.
- A successful analyze, widget suite and APK build do not establish full payment E2E readiness.

Five of the six requested screens were opened and visually inspected on-device. The UI refinement is ready for review, while six-screen visual QA remains **PARTIAL** until Payment can be inspected safely.
