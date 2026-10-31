# Facility Booking Availability and Stitch UI Fix Report

Date: 2026-10-31
Scope: Flutter Customer FE only

## Findings

The Facility Detail CTA previously depended on `FacilityOffering.availableUnitsCount > 0`. The public detail parser converted a missing count to `0`, so “unknown count” silently became unavailable. The same count was displayed as a status chip even though the reservation flow separately calls the physical storage-unit availability API. This conflated an offering summary/hint with actual bookable units and could also show a misleading zero or empty-looking badge.

The correct availability source already used by reservation creation is `GET /storage-units/facility/{facilityId}/available` with optional `unitTypeId`. The Facility Detail action now checks that endpoint per offering. An explicit valid `data: []` displays **Hết phòng trống**; loading has a progress state; API/format failures show a specific error and retry; only one or more returned units with `status == available` enables navigation. Missing/invalid `unitTypeId`, offering ID, or facility ID cannot enable the CTA.

The route continues to pass `facilityId`, the physical `unitTypeId`, the distinct offering `id` as `offeringId`, and the minimum rental days. The reservation screen still re-fetches physical units and check-in slots separately and still requires a selected API-returned unit, a valid API-returned slot, valid duration/date and no active submission before POST. No reservation or payment was created.

### Runtime verification limits

Two unauthenticated read-only requests to the Render facility detail and available-units endpoints were attempted. Both failed before an HTTP response because DNS resolution failed (`No such host is known`). Public Swagger could not be reached from this environment either. Therefore current production count/availability, response compatibility and authorization behavior are **NOT VERIFIED**. Historical API evidence in existing project documentation is not treated as current runtime evidence.

Android emulator `emulator-5554` (Android 17 / API 37) was available. The debug APK installed and launched to the sign-in screen. Facility Detail and authenticated booking were not opened because there is no authorized test session; auth was not bypassed. Screenshot: [facility-booking-auth-gate.png](screenshots/facility-booking-auth-gate.png). This screenshot verifies app launch/login rendering only, not the changed screen.

## Stitch review and UI changes

The four references (`A2_home_dashboard.html`, `A3_explore.html`, `A4_reservation_create.html`, `A6_payment_vietqr.html`) were reviewed against the existing native Flutter screens. The existing Home, Explore, Reservation Create and Payment implementations retain their backend-driven content, Material/native widgets, existing providers, and shell navigation. No HTML/WebView, fictional content, demo QR, payment simulation, fake availability, or unsupported capability was introduced.

Facility Detail was rebuilt in the shared forest-green/M3 design language with a responsive card hierarchy, flexible long names and metadata wrapping, separated price/deposit/dimensions, and explicit availability/error states. The reservation summary no longer repeats the offering count as if it represented physical stock. Existing screens’ prior Stitch adaptations remain; this change did not attempt a broad redesign of all four referenced screens. Customer-facing additions on Facility Detail are in Vietnamese.

Design elements intentionally excluded across the four references include fictional facilities and addresses, unverified distance/location claims, discounts/guarantees/amenities, fake available units or time slots, and decorative/non-server QR content. Backend data and existing navigation/validation remain authoritative.

## Changed files

- `apps/flutter_mobile/lib/features/explore/data/models/facility.dart` — availability hint is nullable; malformed count fails parsing rather than defaulting to zero.
- `apps/flutter_mobile/lib/features/explore/presentation/screens/facility_detail_screen.dart` — physical availability state, retry/error mapping, responsive offering card and Vietnamese customer copy.
- `apps/flutter_mobile/lib/features/reservations/data/repositories/reservation_repository.dart` — malformed physical-unit envelopes/rows now throw; a valid empty list remains empty.
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_create_screen.dart` — remove offering-count text from the physical unit summary.
- `apps/flutter_mobile/lib/app/router.dart` — inject the existing reservation repository into Facility Detail; route IDs remain unchanged.
- `apps/flutter_mobile/test/stitch_screens_test.dart` — available, empty, malformed availability UI and selection/navigation parameter coverage.
- `apps/flutter_mobile/test/integration_contracts_test.dart` — unknown count, explicit empty response, malformed response and request path/query contract coverage.
- `docs/flutter/screenshots/facility-booking-auth-gate.png` — actual emulator launch screenshot; authenticated screen not reached.

## Verification

- `flutter analyze --no-pub` — PASS, no issues.
- `flutter test --no-pub` — PASS, 45 tests.
- `flutter build apk --debug --no-pub` — PASS (`build/app/outputs/flutter-apk/app-debug.apk`).
- `git diff --check` — PASS. Git emitted only existing/configured LF-to-CRLF working-copy notices.
- Emulator install and launch — PASS to sign-in screen; no authenticated screen verified.
- Render GET diagnostics — NOT VERIFIED; DNS resolution failed before HTTP response.

## Remaining blockers

1. Re-run safe GETs from a network that resolves `self-storage-system-be.onrender.com` and confirm current public-detail and unit-availability response shapes.
2. Confirm server authorization policy for the availability endpoint and test an authorized test account/environment if provided.
3. Review Facility Detail on emulator using an authorized test session to inspect real data, loading/error/empty states and reservation navigation. No production customer credential or auth bypass was used here.
4. The four Stitch screens were source-reviewed, but authenticated Home/Reservation/Payment device screenshots and real-backend journey verification remain outstanding.
