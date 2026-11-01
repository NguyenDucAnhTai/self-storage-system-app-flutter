# Phase 2 — Reservation Reassignment

## Endpoint and permission evidence

| Method/path | Verified reference behavior | Flutter status |
|---|---|---|
| `GET /reservations/{id}` | Returns `pendingUnitChange`, old/new unit snapshots and `unitChangeHistory`; source service checks ownership for customer detail | **IMPLEMENTED / source verified**; runtime auth not verified |
| `POST /reservations/{id}/respond-reassign` | Body `{action:'accept'|'reject', rejectReason?:string}`; rejectReason max 500; service allows customer owner when reservation status is `confirmed`, `payment_successful`, or `overdue` and proposal is pending | **IMPLEMENTED / source verified**; controller auth annotations are commented/TODO, so deployed auth remains blocked/unverified |

Backend service consequences verified in read-only source:

- Accept applies the proposed physical unit and offering, updates `basePrice` from `newPricePerUnit`, clears the proposal, and records unit-change history.
- Reject releases both unit reservations, cancels the reservation, and internally creates a refund request for the full deposit amount when that amount is positive. The final refund state/details remain server-authored and are not predicted by Flutter.
- Expired/stale proposals and invalid lifecycle states are rejected by the backend; Flutter reconciles with GET and does not automatically retry uncertain POST outcomes.

## Flutter behavior

- Extended the existing Reservation DTO with typed pending proposal and unit-change history.
- Reservation Detail shows the proposal only when `pendingUnitChange` exists, including current/proposed unit, floor/zone where returned, facility, server-provided price difference/new price, reason, and proposal time.
- Customer must explicitly choose accept/reject and confirm the consequence. Optional rejection reason follows backend max length.
- Duplicate response taps are disabled. After POST success, the returned reservation is applied; after an uncertain error, a GET refresh reconciles state and the UI does not resend.
- Error handling distinguishes 401, 403, 404, 409, 400 and network outcomes in Vietnamese.

## Files changed

- `apps/flutter_mobile/lib/features/reservations/data/models/reservation.dart`
- `apps/flutter_mobile/lib/features/reservations/data/repositories/reservation_repository.dart`
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_detail_screen.dart`
- `apps/flutter_mobile/test/phase2_reservation_reassignment_test.dart`

## Verification

- Focused Phase 2 tests: **4 passed** (DTO mapping, exact POST body, no proposal/no write, pending proposal/action requires explicit user action).
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub -r compact`: passed, all 94 tests.
- `flutter build apk --debug --no-pub`: passed; APK at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed (only standard Windows line-ending notices).
- Android visual QA: **NOT VERIFIED**; no emulator was launched.
