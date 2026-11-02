# Reservation Creation Failure Fix

Date: 2026-10-31
Scope: Flutter Customer application only

## Result

The exact production failure cause is **not established**. The failure shown by the customer is generic UI text, and no production reservation request was sent. A safe unauthenticated GET to the Render Swagger endpoint also failed before receiving an HTTP response because DNS could not resolve `self-storage-system-be.onrender.com`. There is no captured HTTP status, `messageCode`, or sanitized production response for the reported ST-202 / 19:00–21:00 case. The production issue therefore remains **NOT VERIFIED**.

Source inspection confirms that the form stores rental duration in `_duration`, updates it from the field's `onChanged`, and validates it against the `minRentalDays` route parameter. Selecting the unit, date, or slot does not reset duration. The serializer accepts `int` and adds `rentalDuration` as an integer. The form serializes the selected slot's exact `slotName` and the local date as `YYYY-MM-DD`. The actual customer-entered `30`, offering minimum for this reservation, and the reported slot/unit compatibility could not be verified without the authorized runtime response.

The Backend ZIP/OpenAPI findings already recorded in `API-RE-AUDIT-2026-10-30.md` state that create reservation requires `facilityId`, `storageUnitId`, `checkInDate`, `checkInTimeSlot`, and positive integer `rentalDuration`; `facilityUnitTypeOfferingId`, `amenities`, `notes`, `startDate`, and `termsAccepted` are optional in the published request schema. A subsequent source check confirmed `reservation.service.ts:createReservation()` requires `termsAccepted === true` and throws `MESSAGE_CODE_322` otherwise. The FE omission was fixed in the follow-up terms-contract task; production `MESSAGE_CODE_322` was not observed. Backend business rules include same-day lead-time and start-date constraints; the exact production validation response for the reported case remains unavailable. No Backend file or API contract was changed.

## Changes

- Removed the decorative lock icon.
- Changed the action label to **Xác nhận đặt kho** and the submitting label to **Đang xác nhận…**; the normal primary button shows a spinner while submitting.
- Replaced the duration field's `initialValue`-only state with a `TextEditingController` initialized from the offering minimum. Controller and parsed integer state stay synchronized on every edit. Specific Vietnamese validation messages cover empty, non-positive, and below-minimum values. Date/unit/slot selection does not reset duration.
- Mapped reservation POST failures to distinct Vietnamese guidance for HTTP 400/401/403/404/409, preserving safe response message, `messageCode`, and bounded validation details when present. No sensitive values are logged.
- A 409 offers an explicit availability refresh. A timeout/network outcome is described as unknown and disables another POST until the customer confirms that they checked **Đơn đặt kho**. No automatic POST retry was added.
- Existing guards still require an available API-returned physical unit, valid date, API-returned selectable slot, minimum rental duration, and no pending submission. `onCreated`/routing occurs only after the repository returns a parsed reservation.

## Request evidence

Mocked repository contract test observed these serialized fields (fixture values only, not a customer/production request):

- `facilityId: f1`
- `storageUnitId: u1`
- `facilityUnitTypeOfferingId: o1`
- `checkInDate: 2026-12-03` (local date-only form)
- `checkInTimeSlot: Morning` (the selected slot's `slotName`)
- `rentalDuration: 30` (Dart `int`)
- `amenities: []`

`startDate` and `notes` are omitted when absent. No real POST was sent. Compatibility of ST-202 with the selected facility/offering and acceptance of the selected 19:00–21:00 slot require Backend validation/runtime evidence.

## Tests and build

- `flutter analyze --no-pub` — PASS, no issues.
- `flutter test --no-pub` — PASS, 48 tests.
- `flutter build apk --debug --no-pub` — PASS.
- `git diff --check` — PASS; Git printed existing LF-to-CRLF working-copy notices only.

Regression coverage includes a 30-day duration retained as integer in the serialized payload; below-minimum duration disable/error and valid submission; no lock icon; status-specific mocked 400/401/403/404/409 UI; timeout unknown-outcome lockout and explicit acknowledgment; duplicate-submit prevention; existing date, slot and unit guards; and callback only after a successful mock response.

## Remaining runtime verification

Use an authorized disposable Backend test environment/account to submit a single test reservation only after permission is established. Capture the HTTP status, `messageCode`, sanitized response envelope and sanitized request fields without credentials. Verify the actual offering minimum, selected unit/facility/offering relationship, exact slot `slotName`, local check-in date and same-day lead-time rule. Do not retry a timeout until the reservation list has been checked for a created record. Until that evidence exists, the user's reported production failure is not claimed resolved.
