# Flutter Customer FE — Missing Features Plan

This roadmap is based on the public OpenAPI snapshot in [API-FEATURE-GAP-ANALYSIS.md](API-FEATURE-GAP-ANALYSIS.md). Items remain proposals until product roles, backend authorization, response contracts, and a safe test environment are confirmed. No BE changes are included.

| Priority | Feature / gap | Public API surface | Current state | Safe next step / dependency |
|---|---|---|---|---|
| P0 blocker | Verify authenticated customer reads and ownership | `/customer-inventories/summary`, `/contracts`, `/reservations`, `/payments` | OpenAPI auth annotations incomplete; FE only mock-tested | BE confirms bearer/session requirements, ownership filtering, and role authorization; provide seeded disposable test account/runtime. Do not verify with customer production data. |
| P1 | Customer inventory and SKU management | `/customer-skus*`; `/customer-inventories*` | Dashboard summary only; no inventory workflows | Confirm validation, idempotency and inventory ownership; design SKU list/detail plus stock-in/out/move/adjust and movement history. Mutations only in test env with approval. |
| P1 | Payment history | `GET /payments` | Not called by Flutter | Verify customer-scoped filtering and pagination/auth; then add a read-only payment history screen. Keep payment session creation explicit and user-initiated. |
| P1 | Reservation amenity selection | `/facility-amenity-offerings/facility/{facilityId}/available`; reservation create payload | Facility detail exposes offerings; no complete amenity selection workflow verified | Confirm whether reservation schema accepts offering IDs, prices, and optionality; implement UI/payload only after contract review. |
| P1 | Facility search by amenity | `/facilities/search-by-amenity` and amenity offerings | General facility search exists; parity with this operation is incomplete | Confirm query/filter contract and paging; add only if product requires amenity filters. |
| P2 | Contract addendum customer flow | `/contracts/{id}/addendums`; `.../customer-sign`; `.../cancel` | No customer addendum UI | Confirm lifecycle, legal copy, authorization and cancellation policy; use test contracts only. |
| P2 | Reservation lifecycle details | `GET /reservations/{id}`, cancel; customer list | Existing booking flows, no live runtime verification | Verify state transitions and cancellation constraints in permitted test backend. Preserve exact server statuses. |
| P2 | Notification delivery/realtime | Notification list/read endpoints; no stream operation found in snapshot | Existing list/read/badge; no realtime source found | Confirm polling/push requirements and an authoritative backend contract before adding delivery behavior. |
| Out of scope pending role | Staff, facility manager, system admin and operations console | Users, facility/unit/rack/slot configuration, audit logs, approvals, manager dashboard, batch processors | No customer FE workflow | Keep out of customer app unless product grants a role-specific requirement and backend authorization is defined. |
| Not evidenced in this Swagger snapshot | Support requests, reviews, promotions, access/key management | No corresponding customer operations identified | No FE implementation | Product/backend must provide an authoritative API contract before planning implementation. |

## Exit criteria for real-backend validation

1. A dedicated test environment, test customer, and seeded disposable facilities/records are available.
2. BE confirms route authorization, account ownership, and exact response schemas for dashboard reads.
3. Read-only authenticated requests are tested first and recorded with status and sanitized response examples.
4. Reservation/payment/contract mutations are attempted only after explicit authorization and only against disposable test data; no real payment rails are used.
5. Android emulator/device screenshots and logs are attached for each verified screen and error state.
