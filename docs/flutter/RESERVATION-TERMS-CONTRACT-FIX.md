# Reservation Terms Contract Fix

Date: 2026-10-31
Scope: Flutter Customer FE; Backend was inspected read-only and not modified.

## Confirmed contract mismatch

Flutter previously omitted `termsAccepted` from `POST /reservations`. The Backend ZIP source at `src/modules/reservation/reservation.service.ts`, `createReservation()`, rejects any value other than `true` with HTTP 400 `MESSAGE_CODE_322` (`Reservation Terms Must Be Accepted`). The published Zod/OpenAPI request schema marks `termsAccepted` optional, so the runtime service behavior is stricter than the request schema. This is a confirmed FE/BE source-contract mismatch and a plausible cause of reservation failure.

Production `MESSAGE_CODE_322` has **not** been observed. No production reservation request was sent, so this fix is source- and mock-verified rather than live-verified.

## Consent behavior and terms content

- The reservation review now has the requested Vietnamese checkbox, unchecked by default.
- Acceptance is held only in the current screen State, survives ordinary rebuilds, and starts false for a new screen/reservation.
- The submit guard requires checked consent in addition to the existing date, unit, slot, duration, and in-flight guards.
- The repository requires an explicit `termsAccepted` argument, rejects false locally, and serializes the value. The screen passes its checkbox value; only a checked box can reach the POST as `true`.
- An in-app information action discloses that customer-facing authoritative reservation terms and cancellation policy content are not available in the app. No legal language was invented. Backend internal business-rule documentation is not presented as approved customer terms. Supplying the authoritative customer-facing terms/policy remains a product/backend content dependency.

## Request shape

The final mocked request includes:

- `facilityId`
- `storageUnitId`
- `facilityUnitTypeOfferingId` (when supplied)
- `checkInDate` as local `YYYY-MM-DD`
- `checkInTimeSlot` using the selected slot's exact `slotName`
- `rentalDuration` as an integer
- `amenities` (empty list when none selected)
- `termsAccepted: true` only after explicit customer consent

The regression fixture verified `rentalDuration: 30` as an `int`, `termsAccepted: true`, and the other listed fields. These are test fixture values, not a real reservation request.

## Error diagnosis

HTTP status, sanitized backend message, `messageCode`, and bounded field-level validation details are retained in the UI. Secret-like strings are redacted; no bearer tokens, cookies, passwords or account data are logged.

Code-specific Vietnamese guidance now covers:

- `MESSAGE_CODE_322`: consent required.
- `MESSAGE_CODE_328`: same-day preparation lead time is insufficient.
- `MESSAGE_CODE_315`: selected check-in slot has passed.
- `MESSAGE_CODE_310`: slot capacity is full.
- `MESSAGE_CODE_311`: slot is invalid or inactive.
- `MESSAGE_CODE_309`: unit was just booked by another customer.
- `MESSAGE_CODE_306`: unit does not match the selected offering.
- `MESSAGE_CODE_313`: check-in date exceeds the allowed advance window.
- `MESSAGE_CODE_314`: customer has reached the active reservation limit.

## Files changed

- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_create_screen.dart` — explicit consent UI, terms-content availability disclosure, consent guard, and code-specific error messages.
- `apps/flutter_mobile/lib/features/reservations/data/repositories/reservation_repository.dart` — required consent parameter, false-consent local rejection, and `termsAccepted` serialization.
- `apps/flutter_mobile/test/integration_contracts_test.dart` — consent, payload, error-code, duration, existing guard, success callback, duplicate-submit, and timeout regressions.
- `docs/flutter/API-RE-AUDIT-2026-10-30.md` — records the source/schema mismatch and corrected FE behavior.
- `docs/flutter/FLUTTER-CUSTOMER-GAP-MATRIX.md` — updates reservation integration status.
- `docs/flutter/RESERVATION-CREATE-FAILURE-FIX.md` — notes the later confirmed source finding.
- `docs/flutter/RESERVATION-TERMS-CONTRACT-FIX.md` — this report.

## Verification

- `flutter analyze --no-pub` — PASS, no issues.
- `flutter test --no-pub` — PASS, 48 tests.
- `flutter build apk --debug --no-pub` — PASS.
- `git diff --check` — PASS; Git reported existing LF-to-CRLF working-copy notices only.

Mocks verified unchecked consent blocks submission, checked consent serializes `true`, all requested error mappings, valid 30-day integer payload, date/unit/slot guards, successful callback only after a parsed response, duplicate submission prevention, and no automatic retry after a timeout.

## Remaining runtime blockers

- Production API behavior and the reported customer failure remain unverified. `MESSAGE_CODE_322` is confirmed in Backend source, not observed in production.
- An authorized disposable Backend environment/account is needed to verify the real response and booking behavior without touching production customer data.
- Product/backend must provide the authoritative customer-facing reservation terms and cancellation-policy content for in-app display.
