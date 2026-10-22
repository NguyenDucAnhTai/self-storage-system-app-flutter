# Reservation and Payment API Contract

> The current all-feature API inventory is maintained in [docs/flutter/API-INTEGRATION.md](../flutter/API-INTEGRATION.md).

Base URL is supplied by the shared app client. All successful endpoints wrap payloads in `{success,statusCode,messageCode,message,data}`. Error envelopes include status/message/messageCode and may include validation errors. Backend validators return 400 for invalid inputs; authentication/ownership paths can return 401/403 and missing records 404. Controller security decorators are currently commented (see BACKEND-BLOCKERS.md).

| Operation | Request | Response data | Source |
| --- | --- | --- | --- |
| `GET /storage-units/facility/{facilityId}/available` | optional `unitTypeId`, `floor`, `zone` query | `StorageUnitResponse[]`, including physical `id`, status and optional unit type/facility | BE `storageUnit.controller.ts`, request/response schemas |
| `GET /facility-time-slots/facility/{facilityId}/available?date={ISO date}` | facility path, date query | array `{id,facilityId,slotName,startTime,endTime,maxCapacity,bookedCount,availableCapacity,isAvailable}` | BE `facilityTimeSlot.controller.ts`, schemas |
| `POST /reservations` | `{facilityId,storageUnitId,checkInDate,checkInTimeSlot,facilityUnitTypeOfferingId?,startDate?,rentalDuration,amenities?,notes?}`; amenities `{facilityAmenityOfferingId,quantity}` | reservation DTO; 201 | BE `reservation.request.schema.ts`, controller, response schema |
| `GET /reservations?page=1&limit=20&sortBy=createdAt&sortOrder=desc` | pagination/filter query | `{items: Reservation[],pagination}` | BE reservation controller and pagination type |
| `GET /reservations/{id}` | reservation ID | reservation DTO | BE reservation controller |
| `POST /reservations/{id}/cancel` | `{cancellationReason}` (3–500 chars) | updated reservation DTO | BE reservation controller/schema |
| `POST /payments` | `{purpose:"reservation_deposit",reservationId}` | payment DTO with `qrUrl`, `bankInfo`, amount, status and optional expiry/reference | BE payment request/response schemas and service |
| `GET /payments/{id}` | payment ID | payment DTO used for polling | BE payment controller/response schema |

Reservation DTO fields include ID/code, facility/offering IDs, required `checkInDate` and `checkInTimeSlot`, start date, physical unit ID, pricing/deposit, status, expiry, payment fields and optional snapshots. Payment statuses are `pending`, `partially_paid`, `paid`, `expired`, `cancelled`. Reservation statuses in BE include pending, received, pending_payment, payment_failed, payment_successful, confirmed, completed, cancelled, expired and rejected. `payment_failed` describes reservation status, not a Payment status.

The FE `packages/shared` reservation DTO omits check-in date/time and has drift from BE payment/reservation response schemas. The Flutter models follow BE schemas instead.
