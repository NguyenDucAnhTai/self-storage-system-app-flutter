# Customer Four API Modules — Integration Summary

**Scope:** Flutter Customer app only (`apps/flutter_mobile/`). Backend source was read only. Existing uncommitted changes were preserved. Automated verification uses mock Dio adapters; no production mutations were performed. Production API compatibility and Android visual behavior are not claimed as verified.

## Endpoint and module status

| Method / path | Backend Customer permission evidence | Flutter integration | Request/response tests and errors | Android visual QA / blocker |
|---|---|---|---|---|
| GET `/contracts/{id}` | Contract service owner check is documented in the 2026-10-30 API re-audit. | Reused by contract detail and settlement/reconciliation screens. | Mocked settlement/detail state and GET reconciliation. | Not captured; deployed auth not runtime-verified. |
| POST `/contracts/{id}/settlement/confirm` | Local reference service requires CUSTOMER, owner, completed contract, and unconfirmed settlement; no body. | Integrated with confirmation dialog, lifecycle guard, duplicate-submit lock. | Exact no-body POST and success/error/reconciliation covered by Phase 1 tests. | Not captured; controller auth annotation/middleware needs deployed confirmation. |
| POST `/contracts/{id}/settlement/dispute` | Same owner/lifecycle rules; required `disputeReason`, 1–1000 chars. | Integrated with required reason and explicit confirmation. | Body validation and action response mocked. | Same auth blocker as above. |
| GET `/refund-requests?page=&limit=...` | Reference service forces customer ID from caller; never accept a client-selected customer ID. | Refund list, status timeline, pagination, refresh. | Mock pagination, empty/error and status parsing. | Not captured; live owner scoping unverified. |
| GET `/refund-requests/{id}` | Reference service checks owner. | Refund detail from Profile. | Mock detail and access/error states. | Not captured; deployed owner check unverified. |
| POST `/refund-requests/{id}/cancel` | Customer owner and `pending_approval`; reason 3–500. | Confirmation and cancel only for eligible state. | Mock body, eligibility, duplicate/error reconciliation. | Not captured; deployed authorization unverified. |
| POST `/refund-requests` | Reference service explicitly rejects Customer-initiated creation. | **NOT CUSTOMER ALLOWED**; no create action. | No call is made. | Intentionally absent. |
| GET `/reservations/{id}` | Reference service checks customer ownership. | Existing Reservation Detail extended with proposal and history. | Mock pending/no-pending, detail states, refresh. | Not captured; deployed auth unverified. |
| POST `/reservations/{id}/respond-reassign` | Reference service requires customer owner, eligible lifecycle state, pending proposal; body action accept/reject and optional reason. | Existing Reservation Detail actions with consequence confirmation. | Exact body, no action without proposal, duplicate lock, errors and uncertain-result GET reconciliation mocked. | Not captured; controller auth comments/TODO remain a Backend blocker. |
| GET `/support-tickets?page=&limit=...` | Reference service scopes customer to caller; controller role auth TODO. | Customer list, pagination append, refresh, empty/error/retry. | Mock verifies query and omission of `customerId`. | Not captured; deployed role/ownership behavior unverified. |
| GET `/support-tickets/{id}` | Reference service checks owner; controller role auth TODO. | Detail includes category, description, dates, optional facility/contract and staff response. | Mock status detail and gated controls. | Not captured; deployed auth unverified. |
| POST `/support-tickets` | Reference service creates for caller; category/priority/title/description/attachment schemas verified; controller role auth TODO. | Vietnamese create form; explicit submit, max validation, no attachments by default. | Mock exact payload, validation, no automatic retry after uncertain POST. | Not captured; live creation not attempted. |
| POST `/support-tickets/{id}/cancel` | Owner; customer may cancel pending; optional reason max 500; controller role auth TODO. | Explicit confirmation, pending-only button. | Mock verifies completed has no cancel action. | Not captured; live state rules unverified. |
| GET `/incidents?page=&limit=...` | Reference service forces reporter scope to caller; controller role auth TODO. | Incident list with refresh and pagination. | Uses same mock-tested list repository contract; no reporter/customer ID sent. | Not captured; deployed auth unverified. |
| GET `/incidents/{id}` | Customer reporter or owner of linked contract; controller role auth TODO. | Detail and localized reported→closed status progression; evidence URLs are never rendered. | Mock detail/timeline status. | Not captured; deployed ownership behavior unverified. |
| POST `/incidents` | Reference service permits customer report and checks linked contract/facility ownership; requires at least one evidence image URL; controller role auth TODO. | **BLOCKED** in UI pending approved safe upload path. | No POST; no fabricated evidence URL. | Requires supported upload endpoint/format, size, ownership and safe-access rules. |
| POST `/incidents/{id}/cancel` | Reporter only, `reported`, cancellation reason 5–500; controller role auth TODO. | Explicit customer-entered reason + confirmation, shown only in `reported`. | State gate and request handling covered by mocked repository/UI behavior. | Not captured; live authorization unverified. |
| POST `/incidents/{id}/close` | Reporter or linked-contract owner, `resolved`; optional notes max 1000; controller role auth TODO. | Confirmation and close action only for `resolved`; detail GET refresh after success. | Mock verifies resolved state exposes close action, no POST on render. | Not captured; live state/owner rule unverified. |
| POST `/incidents/{id}/assign`, `/investigate`, `/resolve` | Operational roles only. | **NOT CUSTOMER ALLOWED**; no FE controls or calls. | No call is made. | Intentionally absent. |
| POST `/upload/signature` | Signature endpoint only; reference does not define a file upload flow or safe file limits. | **BACKEND BLOCKED**; not called. | No call is made. | Must not be treated as an upload endpoint. |
| GET `/amenities?page=&limit=&status=active&sortBy=name` | Public read controller; active status and pagination supported. | Typed active amenity list for Explore filters. | Exact query and parsing mocked. | Not captured; current catalog not live-verified. |
| GET `/facilities/search-by-amenity?amenityIds=...&matchAll=...` | Public read; comma-separated ObjectIds; matchAll defaults true; matches facilities with active offerings. | Explore multi-select filter, match-all/any, clear/apply; existing facility search retained when filter empty. | Mock exact path, CSV IDs, matchAll, search and absence of unsupported status query. | Not captured; no live facility results. |
| GET `/facility-amenity-offerings/facility/{facilityId}/available` | Public read; service requires active facility and returns active offerings with availability quantities. | Facility Detail cards and Reservation Create selector. | DTO price/availability and widget selectable/unavailable states mocked. | Not captured; current offering stock unverified. |
| GET `/facility-amenity-offerings/facility/{facilityId}/amenity/{amenityId}` | Public single-offering lookup. | **NOT USED**; the bulk available endpoint supplies all required cards. | No individual request needed. | No blocker for current flow. |
| GET `/facilities?page=&limit=&search=&city=&status=active` | Existing public listing. | Existing Explore search retained for unfiltered mode. | Existing mocked facility tests remain. | Not captured. |
| GET `/facilities/{id}/public-detail` | Existing public facility detail. | Existing unit type detail retained; amenity section reads the dedicated offering endpoint. | Existing screen/widget tests plus amenity repository tests. | Not captured. |
| POST `/reservations` with `amenities: [{facilityAmenityOfferingId, quantity}]` | Schema accepts a 24-hex offering ID and integer quantity >=1. Reference service atomically reserves physical amenity quantities and computes charges; Backend remains authoritative. | Existing create flow now serializes selected amenities; no selected items sends `[]`. | Mock exact ID/integer quantity/empty list and rejects invalid or duplicate quantities before POST. | No production reservation. Backend source did not visibly validate that the offering belongs to the reservation's facility; see concern below. |

## Phase reports

- [Phase 1 — Settlement & refunds](PHASE1_SETTLEMENT_REFUND_REPORT.md)
- [Phase 2 — Reservation reassignment](PHASE2_RESERVATION_REASSIGNMENT_REPORT.md)
- [Phase 3 — Support & incidents](PHASE3_SUPPORT_INCIDENT_REPORT.md)
- [Phase 4 — Facility amenities](PHASE4_FACILITY_AMENITIES_REPORT.md)

## Files changed by these phases

- `apps/flutter_mobile/lib/app/router.dart`
- `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_route_screen.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_settlement_screen.dart`
- `apps/flutter_mobile/lib/features/refunds/data/refund_request.dart`
- `apps/flutter_mobile/lib/features/refunds/data/refund_repository.dart`
- `apps/flutter_mobile/lib/features/refunds/presentation/refund_screens.dart`
- `apps/flutter_mobile/lib/features/reservations/data/models/reservation.dart`
- `apps/flutter_mobile/lib/features/reservations/data/repositories/reservation_repository.dart`
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_detail_screen.dart`
- `apps/flutter_mobile/lib/features/customer_care/customer_care.dart`
- `apps/flutter_mobile/lib/features/customer_care/customer_care_screens.dart`
- `apps/flutter_mobile/lib/features/amenities/amenity_repository.dart`
- `apps/flutter_mobile/lib/features/explore/data/repositories/facility_repository.dart`
- `apps/flutter_mobile/lib/features/explore/presentation/screens/explore_screen.dart`
- `apps/flutter_mobile/lib/features/explore/presentation/screens/facility_detail_screen.dart`
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_create_screen.dart`
- `apps/flutter_mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `apps/flutter_mobile/test/phase1_settlement_refunds_test.dart`
- `apps/flutter_mobile/test/phase2_reservation_reassignment_test.dart`
- `apps/flutter_mobile/test/phase3_customer_care_test.dart`
- `apps/flutter_mobile/test/phase4_amenities_test.dart`
- `apps/flutter_mobile/test/stitch_screens_test.dart` (mock repository signature only)

Workspace also contained earlier uncommitted Payment History, active-storage dashboard and unrelated Flutter edits before this task. Those were preserved and are not attributed to these four modules.

## Final verification

Executed in `apps/flutter_mobile/` after Phase 4:

- `flutter analyze --no-pub` — **PASS**, no issues.
- `flutter test --no-pub` — **PASS**, 107 tests.
- `flutter build apk --debug --no-pub` — **PASS**, `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — **PASS** after reports were written; Git may emit normal LF→CRLF notices for existing Windows files.
- Android emulator screenshots/visual QA — **NOT VERIFIED**; no emulator was launched.
- Production Backend requests — **NOT RUN** during implementation; all endpoint tests are mocked.

## Backend and production blockers

1. Support/incident/settlement/reassignment controller source contains missing/commented role-security annotations or TODOs. Flutter auth is not server authorization; verify deployed owner enforcement before production readiness.
2. Incident creation remains blocked until Backend/app has a verified evidence upload contract with allowed formats, size limits, ownership and safe access rules.
3. Local reservation service source does not visibly ensure a submitted amenity offering belongs to the selected reservation facility; Backend should enforce this relationship.
4. Current production availability, state transitions, and authorization have not been validated with a permitted staging/test account. No customer production journey is marked E2E PASS.
