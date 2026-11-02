# API & Flutter Customer Re-audit — 2026-10-30

## Scope, evidence and limits

Read-only audit for Flutter Customer Mobile and the supplied `self-storage-system-be-dev.zip`. ZIP contents were read in memory; they were not extracted or modified. No Dart, backend or unrelated documentation files were changed by this audit. Workspace status was checked first; pre-existing local modifications are preserved. No production request other than public Swagger GETs was made. No token was used, and no business mutation or private customer read was attempted.

Evidence precedence used here:

1. Production Swagger fetched from `GET https://self-storage-system-be.onrender.com/api-docs/` (**200**) and the actual linked `swagger-ui-init.js` (**200**, embedded OpenAPI 3.0.0). Declared server: `https://self-storage-system-be.onrender.com`.
2. Supplied ZIP: `self-storage-system-be-dev/src/config/swagger.json`, plus source controller, Zod schema, service and enum files as cited below. Package version `1.0.0`; ZIP snapshot timestamp/commit was not independently established.
3. Flutter source and tests under `apps/flutter_mobile/`.
4. Existing Flutter reports, treated as historical claims and checked against current source/runtime where possible.

The public spec contains **208 method/path operations**, **167 paths**, and **27 tags**. The 23-Oct Flutter audit matrix contained 149 operation rows. Comparing those operation keys against today's production spec yields **59 production operations absent from that old matrix and 0 old keys removed**. This is an inventory delta, not evidence those endpoints were deployed on a particular date. The earlier raw 149-operation OAS snapshot is not available here, so an old-to-current schema/semantics comparison for the 149 common operations is **UNVERIFIED**.

| Production OpenAPI tag | Operations |
|---|---:|
| Amenities | 6 |
| Approval Requests | 6 |
| AuditLogs | 4 |
| Auth | 9 |
| Contracts | 20 |
| Customer Inventories | 14 |
| Customer Inventory Request (Dual Handshake) | 14 |
| Customer SKU | 7 |
| facilities | 9 |
| Facility Amenity Offerings | 8 |
| Facility Manager | 3 |
| Facility Time Slots | 5 |
| Facility Unit Type Offerings | 7 |
| Incident | 8 |
| LegalEntity | 5 |
| Notification | 6 |
| Payments | 9 |
| Profile | 3 |
| Refund Requests | 7 |
| Reservations | 14 |
| SigningAuthorization | 5 |
| Storage Racks | 9 |
| Storage Units | 10 |
| Support Ticket | 6 |
| Unit Types | 6 |
| Upload | 1 |
| Users | 7 |

## Three-source comparison

| Topic | BE ZIP source | Production Swagger (current GET) | Flutter source |
|---|---|---|---|
| OAS version / operation inventory | OpenAPI 3.0.0, package `1.0.0`; 208 operations / 167 paths | OpenAPI 3.0.0; 208 / 167 | FE route/repository inventory below; not all 208 operations are called |
| `paths` and operation objects | `src/config/swagger.json` | Embedded Swagger document | Not applicable |
| Full OAS paths and `components` | JSON comparison: identical to production (`paths` 185,394 compact JSON chars; `components` 193,776) | Reference | FE has no generated OAS |
| Tags | 27, same set as production | 27 | Product/UI scope only; many tags have no customer screen |
| `servers` | ZIP entry declares malformed `https://[object Object]/` (likely generation/template artifact; do not use it as a live base URL) | Correctly declares Render production URL | `AppConfig.apiBaseUrl` defaults to Render; build-time override supported |
| Operation key delta vs 23-Oct Flutter matrix | ZIP also has the same 208 keys as production | 59 additional keys; 0 removed keys vs the old matrix | 149 old rows were a prior snapshot, not current completeness |
| Old schema/semantics delta | No dated 23-Oct OAS artifact supplied for comparison | Current source available | Old matrix did not preserve complete prior schemas; common-operation change history is **UNVERIFIED** |
| Auth/security | Controllers often have commented-out `@Security` and TODO role authorization; temporary caller extractors exist in source | Operations generally declare empty/no security even when response codes include 401/403; schemes are not proof of enforcement | Dio adds stored bearer token; this cannot repair server-side auth/ownership gaps |

The 59 operation additions relative to the old matrix are listed and classified in the next section. Production and ZIP equality proves that the currently supplied ZIP Swagger artifact matches today's deployed `paths` and `components`; it does **not** prove that every controller/service in the ZIP is the deployed source revision.

## New operation inventory vs the 23-Oct matrix

Classification means intended customer capability inferred from the ZIP controller descriptions/TODO comments and service behavior; TODO annotations are not an authorization guarantee.

| Classification | New method/path operations |
|---|---|
| **CUSTOMER_CORE / CUSTOMER_OPTIONAL, but auth/ownership UNVERIFIED** | `POST /reservations/{id}/respond-reassign` (customer response is described, but controller TODO includes multiple roles); `GET /contracts/{id}/draft-pdf`; `POST /contracts/{id}/settlement/confirm`; `POST /contracts/{id}/settlement/dispute`; `GET /customer-inventories/requests`; `GET /customer-inventories/requests/{id}`; `POST /customer-inventories/outbound-requests`; `POST /customer-inventories/outbound-requests/{id}/cancel`; `POST /customer-inventories/inbound-requests/pre-advised`; `POST /customer-inventories/inbound-requests/{id}/cancel`; `POST /customer-inventories/inbound-requests/{id}/confirm`; `POST /customer-inventories/inbound-requests/{id}/dispute`; `POST /customer-inventories/requests/{id}/regenerate-otp`; `GET /support-tickets`; `GET /support-tickets/{id}`; `POST /support-tickets`; `POST /support-tickets/{id}/cancel`; `GET /incidents`; `GET /incidents/{id}`; `POST /incidents`; `POST /incidents/{id}/close`; `POST /incidents/{id}/cancel`; `GET /refund-requests`; `GET /refund-requests/{id}`; `POST /refund-requests/{id}/cancel` (customer only while pending approval, with ownership check in service) |
| **STAFF_ONLY / manager / operations** | `POST /customer-inventories/inbound-requests` (staff creates inbound record); `POST /customer-inventories/verify-pickup-code`; `POST /customer-inventories/outbound-requests/{id}/complete`; `POST /customer-inventories/inbound-requests/{id}/putaway`; `POST /customer-inventories/requests/process-auto-accept`; `PATCH /customer-inventories/{id}/status`; `POST /customer-inventories/racks/batch-migrate`; `POST /customer-inventories/racks/evacuate-to-holding`; `POST /storage-units/reconcile`; `POST /reservations/{id}/extend-grace`; `POST /reservations/{id}/force-cancel`; `POST /reservations/{id}/mark-arrived`; `POST /incidents/{id}/assign`; `POST /incidents/{id}/investigate`; `POST /incidents/{id}/resolve`; `POST /support-tickets/{id}/process`; `POST /support-tickets/{id}/complete`; `POST /refund-requests`; `POST /refund-requests/{id}/approve`; `POST /refund-requests/{id}/reject`; `POST /refund-requests/{id}/confirm-paid`; `POST /payments/transactions/{id}/assign`; `GET /payments/transactions/unmatched`; `POST /contracts/walk-in`; LegalEntity manager/ops/admin routes: `GET /legal-entities`, `GET /legal-entities/{id}`, `POST /legal-entities`, `PATCH /legal-entities/{id}`, `DELETE /legal-entities/{id}`; SigningAuthorization manager/ops/admin routes: `GET /signing-authorizations`, `GET /signing-authorizations/{id}`, `POST /signing-authorizations`, `PATCH /signing-authorizations/{id}`, `POST /signing-authorizations/{id}/revoke`. These role labels reflect controller TODO/intended roles, not proven enforcement. Refund create is explicitly denied to CUSTOMER and FACILITY_STAFF by service |
| **CONFLICT / deprecated** | `POST /contracts/{id}/renew` remains published, but ZIP `contract.service.ts` labels it deprecated/disabled and throws HTTP 400 `MESSAGE_CODE_416`; customer renewal should use a `RENEW` addendum instead |

The remaining 149 operations retain the old matrix's method/path keys. Their old schema delta cannot be reconstructed from the 23-Oct summary document. Current API coverage and customer eligibility must be read from the live spec plus current source, not copied from that old matrix.

## Customer vs staff/internal operation families

| API family | Customer-facing operations evidenced in ZIP | Out of customer scope / separate role | Flutter status |
|---|---|---|---|
| Auth (9) | send OTP, register, login, refresh, logout, me, forgot/reset/change password | — | Implemented routes/repository; production auth not E2E verified |
| Profile (3) | `GET/PATCH /profile/me` | `GET /profile/{userId}` is not a customer profile route absent explicit ownership semantics | Profile flows exist; response/authorization not live verified |
| Facilities / unit discovery | `GET /facilities`, `GET /facilities/search-by-amenity`, `GET /facilities/{id}/public-detail`; available units, unit map if product exposes it; GET available offerings/amenities/time slots | create/update/delete/restore/assign-manager and facility config writes | Explore, detail, facility search and availability calls exist; amenity-filter parity incomplete |
| Reservations (14) | `POST /reservations`; customer list/detail; cancel; `respond-reassign` accept/reject as described | process-expired/process-overdue, unit reassign proposal, confirm, assign staff, confirm refund, force-cancel, mark-arrived, extend-grace are operational staff/system actions | Create/list/detail/cancel exist. Reassign response is missing. Reservation customer authorization remains blocked by commented security/TODO role checks |
| Payments (9) | `POST /payments` with `reservation_deposit`, `contract_deposit`, or `rent_first_period`; `GET /payments` own history per controller description; detail/cancel subject to ownership/business conditions | SePay webhook, process-expired, unmatched transactions, assign transaction, manual confirm | FE creates reservation deposit and reads one payment status; no history/other purpose workflows. Only `paid` means successful payment |
| Contracts (20) | list/detail, draft HTML read, customer sign, customer `RENEW` addendum request and addendum sign, customer settlement confirm/dispute; customer cancellation only under source business rules | create/walk-in, check-in/staff sign, addendum approve/reject/staff-sign, checkout, terminate, overdue batch | list/sign/legacy renew path exist. Legacy renew is a confirmed 400 conflict; addendum, draft, settlement screens missing |
| Customer SKU (7) and direct inventory ledger (14) | SKU CRUD; inventory GET/list/tree/locations/movements/summary; direct stock in/out/move/adjust according to controller role TODO | rack migrate/evacuate operations | Summary GET used by dashboard only. No SKU or ledger screens. Direct stock mutations and new dual-handshake request flow need a single product policy to prevent duplicate/conflicting workflows |
| Inventory request dual handshake (14) | outbound create/cancel, inbound create/pre-advised/cancel/confirm/dispute, list/detail, regenerate OTP | verify pickup code, outbound complete, inbound putaway, auto-accept batch | No customer request screens. `pre-advised` and OTP regeneration responses include raw OTP/QR material; show once as needed, never log/send to analytics, and avoid exposing secrets in screenshots |
| Support tickets (6) | create/list/detail/cancel pending ticket | process/complete | No FE route/repository/screen |
| Incidents (8) | report/list/detail/close/cancel, subject to reporter/linked-contract ownership and state | assign/investigate/resolve | No FE route/repository/screen |
| Refund requests (7) | list/detail/cancel may be customer-owned subject to service ownership/state checks | approve/reject/confirm-paid; **create is not a customer operation in ZIP service** | No FE module. Controller TODO mentions CUSTOMER, but `refundRequest.service.ts:188-194` explicitly returns 403 for CUSTOMER and FACILITY_STAFF when calling direct create. Do not expose client control of `customerId` or refund amount. Reservation cancel internally creates a refund request when policy requires one |
| Notifications (6) | list, unread count, mark read/read-all, delete own item subject to ownership | `/notifications/test` is test/internal | FE notification list/badge/read actions exist; push/realtime not evidenced |
| Audit, users, manager dashboard, approval requests, amenities and configuration CRUD | no general customer operation identified beyond facility read APIs above | staff/manager/ops/admin tools and approval decisions | No customer screens for operations APIs |
| Upload signature (1) | role/ownership not established by available evidence | **UNVERIFIED** | Not used by current FE |

## High-risk contract findings

### Reservation

- ZIP Zod `createReservationSchema` requires `facilityId`, physical `storageUnitId`, `checkInDate`, `checkInTimeSlot` (3–50 chars, trimmed), and positive integer `rentalDuration`; optional `rentedRackIds`, `facilityUnitTypeOfferingId`, `startDate`, `amenities`, `notes`, `termsAccepted`. Production OAS request schema matches these fields and marks the first five as required.
- The published request schema marks `termsAccepted` optional, but Backend ZIP source `reservation.service.ts:createReservation()` rejects any value other than `true` with HTTP 400 `MESSAGE_CODE_322`. This is a confirmed source-contract mismatch. Flutter now sends `termsAccepted: true` only after the customer checks the explicit consent box; it continues to omit optional `rentedRackIds` and notes. The physical unit and slot values are not conflated.
- Reservation status values in current OAS: `pending_payment`, `payment_successful`, `confirmed`, `completed`, `cancelled`, `expired`, `overdue`. Response adds `pendingUnitChange`, `unitChangeHistory`, `graceExpiresAt`, `arrivedAt` and warning/policy fields. Current FE status UX is not built for the reassign/grace/arrival lifecycle.
- Controller comments specify same-day lead-time and `startDate`-offset business constraints. The date format/timezone details must be verified from Zod `dateStringSchema` and service code before treating ISO timestamp input as interchangeable with date-only. Current Flutter deliberately serializes local calendar date `YYYY-MM-DD`.
- Cancel body in ZIP has optional refund bank/account fields. Current FE cancellation flow needs an explicit schema parity review; do not infer refund policy solely from button availability. Source policy: at least 24h before check-in 100% deposit refund, under 24h 0%, plus state/link constraints; this is from controller/service, not guaranteed by Swagger descriptions.
- `respond-reassign` request accepts action `accept|reject` and optional reason; accept can change unit/price, reject cancels and initiates full refund. No customer screen exists.

### Payment

- Purpose enum is exactly `reservation_deposit`, `contract_deposit`, `rent_first_period`; `CreatePaymentRequest` requires purpose, reservation/contract IDs are optional at OAS level. Confirm cross-field requirements/ownership with service before adding UI.
- `GET /payments` description says customers only see their own payments; staff may filter across facilities. This is intended behavior, not verified production ownership enforcement.
- FE status logic should treat only `paid` as success. Current source does this; session creation/polling is present only for reservation deposit.
- Transactions/unmatched and transaction assignment are staff/manager/ops operations, never customer controls.

### Contracts, addendums and settlement

- `POST /contracts/{id}/renew` is a published stale operation but disabled in service with 400 `MESSAGE_CODE_416` (ZIP `contract.service.ts:1476-1488`). Current Flutter `ContractRepository.renew()` still calls this endpoint: confirmed source-to-service conflict; do not design customer renewal around it.
- Replacement is `POST /contracts/{id}/addendums` with `type: renew|unit_change`. Customer may request RENEW; manager approval is required before customer signature according to controller/service. UNIT_CHANGE has separate manager/staff workflow and inventory constraints.
- `GET /contracts/{id}/draft-pdf` response is an API envelope containing HTML string and `contractCode` per production OAS, not a binary PDF. The UI should render/print HTML only after Flutter capability and safe-content handling are decided.
- Contract signing requires `termsAccepted`; FE currently sends true in customer sign. Actual check-in is facility-side two-party completion and may adjust dates/reset customer signature; do not show customer-only “active” success before staff signature.
- Settlement confirmation and dispute are customer endpoints by controller TODO and service ownership/state checks. Not implemented in Flutter.

### Inventory requests, support, incidents and refunds

- Request-based inbound/outbound operations form a dual-handshake workflow; direct stock-in/out/move/adjust also remain in the old API. Product and BE must decide whether customers can use both. Prefer request workflow for physical handover; don't design duplicate stock mutation affordances without an explicit rule.
- OTP/raw OTP/QR responses are short-lived sensitive material; do not add to logs, analytics, deep links, generic error text or screenshots. API expiry/state should drive UX.
- Support ticket status values: `pending`, `processing`, `completed`, `cancelled`. Incident statuses: `reported`, `assigned`, `investigating`, `in_progress`, `resolved`, `closed`, `cancelled`. Customer close/cancel are state/ownership-dependent.
- Refund request create is forbidden to customers by ZIP service even though controller TODO includes CUSTOMER. Customer refund experience should read status/detail and use the reservation cancellation or settlement path where permitted; direct create endpoint is **STAFF_ONLY** until service/role policy changes.

## Security and production evidence

- ZIP controllers (examples: reservation controller lines 61–116, payment/contract/support/inventory/incident/refund controllers) have bearer/cookie `@Security` decorators commented out and explicit `TODO: Role authorization`. Several `extractCaller` helpers accept caller identity/role from `x-user-id` / `x-user-role` headers as development fallback before JWT/cookie parsing. Do not treat the presence of FE bearer attachment as a solved authorization boundary.
- Production OpenAPI operations frequently have `security: []` or no security requirement while some declare 401/403 responses. Previous docs recorded unauthenticated protected GETs returning 401 on 23-Oct; that is historical, not a fresh test in this audit. No protected business GET was repeated here.
- `GET /api-docs/` and its discovered init script are the only production requests executed in this re-audit. No auth credentials, user records, reservations, payments, contracts or private inventory data were accessed. All live customer operations are **NOT E2E VERIFIED**.

## Current Flutter inventory (verified source)

### GoRouter routes (`apps/flutter_mobile/lib/app/router.dart`)

`/splash`, `/login`, `/register`, `/forgot-password`, `/home`, `/explore`, `/facilities/:id`, `/reservations/create`, `/reservations`, `/reservations/:id`, `/payments/:id`, `/profile`, `/change-password`, `/contracts`, `/notifications`. Bottom tabs: Home, Explore, My bookings, Profile. No route exists for payment history, contract addendum/draft/settlement, inventory requests, refund requests, support tickets or incidents.

### Providers, repositories, models and current tests

- Riverpod: `authControllerProvider`; shared `reservationPaymentProvider`; `facilityRepositoryProvider`; dashboard providers for inventory summary, contracts, reservations and facilities; notification feed/unread providers. No providers for support/incidents/refunds/inventory requests/addendums/payment list.
- Repositories: `AuthRepository`, `ProfileRepository`, `FacilityRepository`, `ReservationRepository`, `PaymentRepository`, `ContractRepository`, `NotificationRepository`, `CustomerInventorySummaryRepository`.
- Models: auth user; facility/offerings; reservation and `AvailableTimeSlot`; payment; notification; customer inventory summary. Reservation/payment/contract status fields are strings, not exhaustive enums. UI recognizes only selected statuses (not all current server lifecycle states).
- Tests: `api_models_test.dart`, `integration_contracts_test.dart`, `dashboard_test.dart`. Historical report says 36 tests passed on 23-Oct (mock/provider coverage). No tests were executed during this read-only audit. A mock pass is not production or device E2E.
- Dio: `AppConfig.apiBaseUrl` defaults to Render; shared Dio bearer token attachment, 401 refresh/retry; no TLS bypass. `INTERNET` permission present in Android main manifest. Debug manifest permits cleartext for local debug, not the release/main manifest.

## Full production operation ledger (208 operations)

All operations below are present in the supplied ZIP and production Swagger with identical operation and schema objects. The ZIP OpenAPI server declaration itself is malformed as documented above. BE role text is source intent/TODO evidence, not proof of authorization.

| Method | Path | Production tag | BE ZIP source role / scope | Production OAS security | Flutter customer source |
|---|---|---|---|---|---|
| `GET` | `/users` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/users` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/users/search` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/users/{id}` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/users/{id}` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `DELETE` | `/users/{id}` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | operation requirement set | No matching customer repository call found |
| `POST` | `/users/{id}/restore` | Users | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/auth/send-otp` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | AuthRepository; register |
| `POST` | `/auth/register` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | AuthRepository; register |
| `POST` | `/auth/login` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | AuthRepository; login |
| `POST` | `/auth/refresh` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | ApiClient interceptor |
| `POST` | `/auth/logout` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | AuthRepository; logout |
| `GET` | `/auth/me` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | operation requirement set | AuthRepository; session restore |
| `POST` | `/auth/forgot-password` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | AuthRepository; recovery |
| `POST` | `/auth/reset-password` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | explicit [] | AuthRepository; recovery |
| `PATCH` | `/auth/change-password` | Auth | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | operation requirement set | AuthRepository; change password |
| `GET` | `/profile/me` | Profile | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | operation requirement set | ProfileRepository; ProfileScreen |
| `PATCH` | `/profile/me` | Profile | CUSTOMER_CORE (ZIP TODO; server enforcement unverified) | operation requirement set | ProfileRepository; ProfileScreen |
| `GET` | `/profile/{userId}` | Profile | STAFF_ONLY / out of Customer scope | operation requirement set | No matching customer repository call found |
| `GET` | `/audit-logs` | AuditLogs | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/audit-logs/me` | AuditLogs | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/audit-logs/resource/{resourceType}/{resourceId}` | AuditLogs | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/audit-logs/{id}` | AuditLogs | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/upload/signature` | Upload | UNVERIFIED role/ownership; not used by FE | explicit [] | No matching customer repository call found |
| `GET` | `/unit-types` | Unit Types | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `POST` | `/unit-types` | Unit Types | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/unit-types/{id}` | Unit Types | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `PATCH` | `/unit-types/{id}` | Unit Types | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `DELETE` | `/unit-types/{id}` | Unit Types | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/unit-types/{id}/restore` | Unit Types | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/support-tickets` | Support Ticket | CUSTOMER + staff per ZIP TODO; ownership/state required | explicit [] | No matching customer repository call found |
| `GET` | `/support-tickets` | Support Ticket | CUSTOMER + staff per ZIP TODO; ownership/state required | explicit [] | No matching customer repository call found |
| `GET` | `/support-tickets/{id}` | Support Ticket | CUSTOMER + staff per ZIP TODO; ownership/state required | explicit [] | No matching customer repository call found |
| `POST` | `/support-tickets/{id}/process` | Support Ticket | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/support-tickets/{id}/complete` | Support Ticket | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/support-tickets/{id}/cancel` | Support Ticket | CUSTOMER + staff per ZIP TODO; ownership/state required | explicit [] | No matching customer repository call found |
| `GET` | `/storage-units` | Storage Units | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `POST` | `/storage-units` | Storage Units | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `GET` | `/storage-units/facility/{facilityId}/available` | Storage Units | CUSTOMER_CORE candidate read; auth not explicit | explicit [] | ReservationRepository; create screen |
| `GET` | `/storage-units/facility/{facilityId}/map-layout` | Storage Units | CUSTOMER_CORE candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `GET` | `/storage-units/{id}` | Storage Units | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `PATCH` | `/storage-units/{id}` | Storage Units | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `DELETE` | `/storage-units/{id}` | Storage Units | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `PATCH` | `/storage-units/{id}/maintenance` | Storage Units | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/storage-units/{id}/restore` | Storage Units | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/storage-units/reconcile` | Storage Units | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `GET` | `/storage-racks` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/storage-racks` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/storage-racks/unit/{unitId}` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/storage-racks/{id}` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/storage-racks/{id}` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `DELETE` | `/storage-racks/{id}` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/storage-racks/unit/{unitId}/provision` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/storage-racks/tiers/{id}` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/storage-racks/{id}/restore` | Storage Racks | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/signing-authorizations` | SigningAuthorization | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/signing-authorizations` | SigningAuthorization | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/signing-authorizations/{id}` | SigningAuthorization | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `PATCH` | `/signing-authorizations/{id}` | SigningAuthorization | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/signing-authorizations/{id}/revoke` | SigningAuthorization | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations` | Reservations | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | ReservationRepository; create screen |
| `GET` | `/reservations` | Reservations | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | ReservationRepository; list + dashboard |
| `POST` | `/reservations/process-expired` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/process-overdue` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/reservations/{id}` | Reservations | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | ReservationRepository; detail |
| `POST` | `/reservations/{id}/reassign-unit` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/respond-reassign` | Reservations | CUSTOMER action + staff (ZIP TODO); ownership/auth unverified | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/confirm` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/cancel` | Reservations | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | ReservationRepository; detail |
| `POST` | `/reservations/{id}/assign-staff` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/confirm-refund` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/force-cancel` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/mark-arrived` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/reservations/{id}/extend-grace` | Reservations | STAFF_ONLY/system or manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/refund-requests` | Refund Requests | NOT CUSTOMER: ZIP service explicitly denies customer/staff create | explicit [] | No matching customer repository call found |
| `GET` | `/refund-requests` | Refund Requests | Customer + staff per TODO; service enforces own pending cancel only | explicit [] | No matching customer repository call found |
| `POST` | `/refund-requests/{id}/approve` | Refund Requests | STAFF/manager/ops per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/refund-requests/{id}/reject` | Refund Requests | STAFF/manager/ops per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/refund-requests/{id}/confirm-paid` | Refund Requests | STAFF/manager/ops per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/refund-requests/{id}/cancel` | Refund Requests | Customer + staff per TODO; service enforces own pending cancel only | explicit [] | No matching customer repository call found |
| `GET` | `/refund-requests/{id}` | Refund Requests | Customer + staff per TODO; service enforces own pending cancel only | explicit [] | No matching customer repository call found |
| `POST` | `/payments/sepay/webhook` | Payments | BACKEND_INTERNAL or STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/payments` | Payments | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | PaymentRepository; payment screen (reservation deposit only) |
| `GET` | `/payments` | Payments | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | No matching customer repository call found |
| `POST` | `/payments/process-expired` | Payments | BACKEND_INTERNAL or STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/payments/transactions/unmatched` | Payments | BACKEND_INTERNAL or STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/payments/transactions/{id}/assign` | Payments | BACKEND_INTERNAL or STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/payments/{id}` | Payments | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | PaymentRepository; payment status |
| `POST` | `/payments/{id}/cancel` | Payments | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | No matching customer repository call found |
| `POST` | `/payments/{id}/confirm-manual` | Payments | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | No matching customer repository call found |
| `POST` | `/notifications/test` | Notification | BACKEND_INTERNAL/test only | explicit [] | No matching customer repository call found |
| `GET` | `/notifications` | Notification | CUSTOMER per module; ownership still must be enforced | explicit [] | NotificationRepository; notifications screen |
| `GET` | `/notifications/unread-count` | Notification | CUSTOMER per module; ownership still must be enforced | explicit [] | NotificationRepository; badge |
| `PATCH` | `/notifications/{id}/read` | Notification | CUSTOMER per module; ownership still must be enforced | explicit [] | NotificationRepository; notifications screen |
| `PATCH` | `/notifications/read-all` | Notification | CUSTOMER per module; ownership still must be enforced | explicit [] | NotificationRepository; notifications screen |
| `DELETE` | `/notifications/{id}` | Notification | CUSTOMER per module; ownership still must be enforced | explicit [] | NotificationRepository; notifications screen |
| `POST` | `/legal-entities` | LegalEntity | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/legal-entities` | LegalEntity | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/legal-entities/{id}` | LegalEntity | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `PATCH` | `/legal-entities/{id}` | LegalEntity | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `DELETE` | `/legal-entities/{id}` | LegalEntity | STAFF/MANAGER/OPS/ADMIN per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/incidents` | Incident | CUSTOMER + staff per ZIP TODO; linked ownership/state required | explicit [] | No matching customer repository call found |
| `GET` | `/incidents` | Incident | CUSTOMER + staff per ZIP TODO; linked ownership/state required | explicit [] | No matching customer repository call found |
| `GET` | `/incidents/{id}` | Incident | CUSTOMER + staff per ZIP TODO; linked ownership/state required | explicit [] | No matching customer repository call found |
| `POST` | `/incidents/{id}/assign` | Incident | STAFF/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/incidents/{id}/investigate` | Incident | STAFF/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/incidents/{id}/resolve` | Incident | STAFF/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/incidents/{id}/close` | Incident | CUSTOMER + staff per ZIP TODO; linked ownership/state required | explicit [] | No matching customer repository call found |
| `POST` | `/incidents/{id}/cancel` | Incident | CUSTOMER + staff per ZIP TODO; linked ownership/state required | explicit [] | No matching customer repository call found |
| `GET` | `/facility-unit-type-offerings` | Facility Unit Type Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/facility-unit-type-offerings` | Facility Unit Type Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/facility-unit-type-offerings/{id}` | Facility Unit Type Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/facility-unit-type-offerings/{id}` | Facility Unit Type Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `DELETE` | `/facility-unit-type-offerings/{id}` | Facility Unit Type Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/facility-unit-type-offerings/facility/{facilityId}/unit-type/{unitTypeId}` | Facility Unit Type Offerings | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `POST` | `/facility-unit-type-offerings/{id}/restore` | Facility Unit Type Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/facility-time-slots/facility/{facilityId}/available` | Facility Time Slots | CUSTOMER_CORE candidate read; auth not explicit | explicit [] | ReservationRepository; create screen |
| `GET` | `/facility-time-slots/facility/{facilityId}` | Facility Time Slots | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `POST` | `/facility-time-slots` | Facility Time Slots | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `PATCH` | `/facility-time-slots/{id}` | Facility Time Slots | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `DELETE` | `/facility-time-slots/{id}` | Facility Time Slots | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `GET` | `/my-facility` | Facility Manager | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/my-facility/dashboard` | Facility Manager | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/my-facility/staffs` | Facility Manager | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/facility-amenity-offerings` | Facility Amenity Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/facility-amenity-offerings` | Facility Amenity Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/facility-amenity-offerings/facility/{facilityId}/available` | Facility Amenity Offerings | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `GET` | `/facility-amenity-offerings/facility/{facilityId}/amenity/{amenityId}` | Facility Amenity Offerings | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `GET` | `/facility-amenity-offerings/{id}` | Facility Amenity Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/facility-amenity-offerings/{id}` | Facility Amenity Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `DELETE` | `/facility-amenity-offerings/{id}` | Facility Amenity Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/facility-amenity-offerings/{id}/restore` | Facility Amenity Offerings | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/facilities` | facilities | CUSTOMER_CORE candidate read; authorization not explicit | explicit [] | FacilityRepository; Explore + dashboard |
| `POST` | `/facilities` | facilities | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `GET` | `/facilities/search-by-amenity` | facilities | CUSTOMER_CORE candidate read; authorization not explicit | explicit [] | No matching customer repository call found |
| `GET` | `/facilities/{id}/public-detail` | facilities | CUSTOMER_CORE candidate read; authorization not explicit | explicit [] | FacilityRepository; FacilityDetailScreen |
| `GET` | `/facilities/{id}` | facilities | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `PATCH` | `/facilities/{id}` | facilities | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `DELETE` | `/facilities/{id}` | facilities | STAFF_ONLY / out of Customer scope | explicit [] | No matching customer repository call found |
| `PATCH` | `/facilities/{id}/assign-manager` | facilities | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/facilities/{id}/restore` | facilities | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/customer-skus` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `GET` | `/customer-skus` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `GET` | `/customer-skus/barcode/{barcode}` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `GET` | `/customer-skus/{id}` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `PATCH` | `/customer-skus/{id}` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `DELETE` | `/customer-skus/{id}` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-skus/{id}/restore` | Customer SKU | CUSTOMER per ZIP controller TODO; enforcement unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/outbound-requests` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/verify-pickup-code` | Customer Inventory Request (Dual Handshake) | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/outbound-requests/{id}/complete` | Customer Inventory Request (Dual Handshake) | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/outbound-requests/{id}/cancel` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/inbound-requests` | Customer Inventory Request (Dual Handshake) | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/inbound-requests/pre-advised` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/inbound-requests/{id}/cancel` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/inbound-requests/{id}/confirm` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/inbound-requests/{id}/dispute` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/inbound-requests/{id}/putaway` | Customer Inventory Request (Dual Handshake) | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/requests` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/requests/process-auto-accept` | Customer Inventory Request (Dual Handshake) | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/requests/{id}/regenerate-otp` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/requests/{id}` | Customer Inventory Request (Dual Handshake) | CUSTOMER + staff dual-handshake by operation; auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/in` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/out` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/move` | Customer Inventories | STAFF/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/adjust` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/movements` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/unit/{storageUnitId}/tree` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/sku/{skuId}/locations` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/barcode/{barcode}/locations` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `GET` | `/customer-inventories/summary` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | CustomerInventorySummaryRepository; dashboard |
| `GET` | `/customer-inventories/{id}` | Customer Inventories | CUSTOMER + ops per ZIP TODO; direct stock flow policy unresolved | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/racks/batch-migrate` | Customer Inventories | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/customer-inventories/racks/evacuate-to-holding` | Customer Inventories | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `PATCH` | `/customer-inventories/{id}/status` | Customer Inventories | STAFF_ONLY per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts` | Contracts | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | No matching customer repository call found |
| `GET` | `/contracts` | Contracts | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | ContractRepository; contracts + dashboard |
| `POST` | `/contracts/walk-in` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `GET` | `/contracts/{id}` | Contracts | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | ContractRepository; contracts screen |
| `GET` | `/contracts/{id}/draft-pdf` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/customer-sign` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | ContractRepository; contracts screen |
| `POST` | `/contracts/{id}/check-in` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/cancel` | Contracts | Customer + staff per ZIP TODO; ownership/auth unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/renew` | Contracts | DEPRECATED; service throws 400 MESSAGE_CODE_416 | explicit [] | ContractRepository; KNOWN deprecated 400 conflict |
| `POST` | `/contracts/{id}/addendums` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/addendums/{addendumId}/approve` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/addendums/{addendumId}/reject` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/addendums/{addendumId}/customer-sign` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/addendums/{addendumId}/staff-sign` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/addendums/{addendumId}/cancel` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/check-out` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/terminate` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/settlement/confirm` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/{id}/settlement/dispute` | Contracts | CUSTOMER action (RENEW only where relevant); auth/ownership unverified | explicit [] | No matching customer repository call found |
| `POST` | `/contracts/process-overdue` | Contracts | STAFF_ONLY/manager per ZIP TODO | explicit [] | No matching customer repository call found |
| `POST` | `/approval-requests` | Approval Requests | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/approval-requests` | Approval Requests | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/approval-requests/my-requests` | Approval Requests | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/approval-requests/{id}` | Approval Requests | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/approval-requests/{id}/cancel` | Approval Requests | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `PATCH` | `/approval-requests/{id}/review` | Approval Requests | STAFF/MANAGER/OPS/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/amenities` | Amenities | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `POST` | `/amenities` | Amenities | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `GET` | `/amenities/{id}` | Amenities | CUSTOMER_OPTIONAL candidate read; auth not explicit | explicit [] | No matching customer repository call found |
| `PATCH` | `/amenities/{id}` | Amenities | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `DELETE` | `/amenities/{id}` | Amenities | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |
| `POST` | `/amenities/{id}/restore` | Amenities | STAFF/MANAGER/ADMIN; not Customer UI | explicit [] | No matching customer repository call found |

## Evidence index

BE ZIP source paths are prefixed `self-storage-system-be-dev/` inside the supplied archive. Line numbers below are archive-member line numbers.

- Reservation create schema: `src/modules/reservation/schemas/reservation.request.schema.ts:26-47`; statuses/response `src/modules/reservation/schemas/reservation.response.schema.ts`; controller auth/roles and policies `src/modules/reservation/reservation.controller.ts:61-165`, service `src/modules/reservation/reservation.service.ts`.
- Payment purpose/status: `src/modules/payment/schemas/payment.request.schema.ts:14-25`, `src/common/enums/payment.enum.ts`, `src/modules/payment/payment.controller.ts:215-220`.
- Contract renew/addendums/settlement: `src/modules/contract/contract.controller.ts:309-359, 441-490, 604-655, 827-871`; `src/modules/contract/contract.service.ts:1476-1558, 2506-2604`.
- Inventory request roles/OTP: `src/modules/customerInventory/inventoryRequest.controller.ts:139-149, 310-416, 538-570`; request validation `src/modules/customerInventory/schemas/inventoryRequest.request.schema.ts`; service `src/modules/customerInventory/inventoryRequest.service.ts`.
- Refund create conflict: controller `src/modules/refundRequest/refundRequest.controller.ts:121-138`; service explicitly denies customer/staff `src/modules/refundRequest/refundRequest.service.ts:182-198`; client-supplied `customerId`/`amount` fields `src/modules/refundRequest/schemas/refundRequest.request.schema.ts:14-29`.
- Support: `src/modules/support/supportTicket.controller.ts:146-302`; incidents `src/modules/incident/incident.controller.ts:126-349` and ownership checks `src/modules/incident/incident.service.ts:188-225, 661-707, 821-839`.
- Flutter routes `apps/flutter_mobile/lib/app/router.dart`; API contracts `apps/flutter_mobile/lib/features/*/data`; tests `apps/flutter_mobile/test/*`.
