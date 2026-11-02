# Backend Blockers and Risks

> Current full-app status is maintained in [docs/flutter/BACKEND-BLOCKERS.md](../flutter/BACKEND-BLOCKERS.md).

Backend was inspected read-only. No backend files were changed.

1. **Authorization decorators and role checks are disabled/TODO.** `src/modules/reservation/reservation.controller.ts` and `src/modules/payment/payment.controller.ts` comment out bearer/cookie `@Security` and repeatedly mark role authorization TODO. Controllers extract caller from request user, `x-user-id`, bearer token or access cookie, but this is not equivalent to endpoint authorization. Customer ownership checks in services are not enough to establish a production-safe deployment contract while headers can be supplied and route middleware requirements are unclear. Impact: authenticated mobile integration and customer data/payment access cannot be considered secure/verified until backend authorization is confirmed/enforced.
2. **FE shared DTO drift.** `packages/shared/src/types/reservation.types.ts` omits required BE response `checkInDate`, `checkInTimeSlot`, refund/status fields and uses different snapshots; shared payment type includes optional `bankAccount` while BE schema provides `bankInfo`. Impact: consumers based on shared types can misparse or omit mobile-required fields. Flutter models follow current BE Zod response schemas.
3. **No BE runtime/test credentials provided.** Source inspection establishes the contract but does not verify deployed base URL, CORS/cookie configuration, auth runtime, or SePay webhook operation. Impact: real backend flow remains unverified.

No missing customer availability endpoint blocker: verified physical-unit and time-slot availability endpoints exist. No separate payment-status endpoint is needed because `GET /payments/{id}` is explicitly documented for polling.
