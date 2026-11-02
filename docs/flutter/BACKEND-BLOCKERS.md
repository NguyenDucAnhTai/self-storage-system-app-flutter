# Backend Blockers

Backend source was read-only throughout.

1. **Reservation/payment/contract authorization:** `reservation.controller.ts`, `payment.controller.ts`, and `contract.controller.ts` contain commented bearer/cookie security decorators and TODO role authorization. Controllers use caller extraction fallbacks in some modules. This prevents treating mobile customer data isolation as production-verified until backend route security and role checks are enforced and confirmed.
2. **Support requests:** no customer support-request controller/module/API was found. Support creation, details and tracking remain blocked; no local/mock requests were substituted.
3. **Runtime verification:** no deployed base URL, customer credentials, or test facility data were provided. Auth, facility search, reservation, SePay webhook, payments and contracts have source-verified contracts only; they were not exercised against a running backend.
4. **Shared FE type drift:** `packages/shared/src/types/reservation.types.ts` omits current BE `checkInDate` and `checkInTimeSlot` response fields and differs on reservation/payment snapshots. Flutter parses the BE Zod schema fields directly.

Core routes verified in backend include facility public list/detail, physical storage-unit availability, date-specific time slots, reservation create/list/detail/cancel, deposit payment create/status, auth/profile, customer contract list/detail/terms acceptance/renewal, and notification list/read. No missing reservation or payment endpoint blocked the implementation.

## Source-Level API Contract Notes

- Reservation create schema requires 24-hex `facilityId` and `storageUnitId`, valid date strings for `checkInDate`, a 3–50 character `checkInTimeSlot`, and positive integer `rentalDuration`. `facilityUnitTypeOfferingId` is optional in the current backend schema even though the Flutter booking flow supplies it. The mobile payload uses a date-only ISO string and the selected slot name.
- Payment create schema accepts `purpose=reservation_deposit` only with `reservationId`; backend payment status enum is `pending`, `partially_paid`, `paid`, `expired`, or `cancelled`. The Flutter client waits for `paid` before displaying success.
- Contract renewal requires a valid `newEndDate`; customer terms acceptance request schema defaults `termsAccepted` to true. Flutter sends true explicitly.
- No Flutter/backend request-schema mismatch was identified in these audited flows. This is source review; it does not confirm deployed runtime configuration, auth middleware, or provider callbacks.
