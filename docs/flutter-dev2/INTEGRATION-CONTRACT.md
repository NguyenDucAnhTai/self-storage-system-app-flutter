# Developer 1 / Developer 2 Integration Contract

> This initial handoff is superseded: Developer 1 and Developer 2 scopes are now integrated. See [docs/flutter/ARCHITECTURE.md](../flutter/ARCHITECTURE.md) and [docs/flutter/FEATURE-STATUS.md](../flutter/FEATURE-STATUS.md).

## Developer 1 provides

- A shared configured `Dio` instance with API base URL, JSON handling, timeout, access token/cookie strategy, refresh/retry behavior, and typed error handling.
- Authentication readiness and a way to require customer sign-in before customer reservation/payment requests.
- Facility/detail/explore navigation values: facility ID, physical storage unit ID and/or unit type offering ID. The booking request requires the physical unit ID and check-in time slot.
- App route registration and any app-wide locale/theme conventions.

`ReservationPaymentFeature(sharedDio)` is the feature dependency facade. No second client or authentication implementation is created here.

## Developer 2 exports

- `ReservationRepository`, `Reservation`, `AvailableTimeSlot`, `ReservationListScreen`, `ReservationDetailScreen`.
- `PaymentRepository`, `Payment`, `PaymentStatusTracker`, `PaymentScreen`.
- `ReservationPaymentFeature` to assemble repositories from the shared Dio client.

## Proposed navigation

| Route | Parameters | Destination |
| --- | --- | --- |
| `/reservations` | none | reservation list |
| `/reservations/new` | facilityId, storageUnitId, facilityUnitTypeOfferingId | booking form/availability selection (not yet implemented) |
| `/reservations/:id` | id | reservation detail |
| `/payments/reservation/:reservationId` | reservationId | create/retrieve and track deposit payment |

Reservation detail's payment callback can navigate to the payment route with reservation ID. List/detail/payment screens accept feature repositories through constructors for dependency injection.

## Integration blockers

- No app router/auth/shared Dio client exists in the Flutter starter; Developer 1 must supply these before app-level flow wiring.
- Reservation creation requires a concrete storageUnitId and offering ID. The customer selection flow that supplies those values is not in current Flutter code.
- Backend auth/role enforcement requires resolution (details in BACKEND-BLOCKERS.md).
