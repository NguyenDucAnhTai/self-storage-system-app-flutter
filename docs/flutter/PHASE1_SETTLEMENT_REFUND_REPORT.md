# Phase 1 — Contract Settlement & Refund Tracking

## Verified contract and permission evidence

Backend reference source was inspected read-only. Current public Swagger could not be fetched via the web reader in this turn; the 2026-10-30 audit plus local Backend schemas/services were used. Source snapshot is not proof of deployed production behavior.

| Method/path | Backend evidence | Flutter status |
|---|---|---|
| `GET /contracts/{id}` | Contract detail; service checks customer ownership (per API re-audit) | **IMPLEMENTED**; reused for display and reconciliation |
| `POST /contracts/{id}/settlement/confirm` | Service requires `role=CUSTOMER`, owner match, `status=completed`, and no `settlementConfirmedAt`; no body | **IMPLEMENTED** behind explicit confirmation and completed-contract UI gate |
| `POST /contracts/{id}/settlement/dispute` | Same ownership/lifecycle conditions; body `{disputeReason}`; schema 1–1000 chars | **IMPLEMENTED** with reason validation and explicit consequence confirmation |
| `GET /refund-requests` | Customer service scoping sets `customerId=callerId`; pagination/filter schema | **IMPLEMENTED**; client does not send customerId |
| `GET /refund-requests/{id}` | Customer owner check; other owner's record yields not found | **IMPLEMENTED** |
| `POST /refund-requests/{id}/cancel` | Customer must own request and status `pending_approval`; body reason length 3–500 | **IMPLEMENTED** only for pending approval with reason and confirmation |
| `POST /refund-requests` | Backend service explicitly rejects direct Customer-created refund requests | **NOT_CUSTOMER_ALLOWED**; no FE create action |

Controller security annotations remain commented with role authorization TODOs. FE guards are UX only; production endpoint authorization and middleware enforcement remain **BACKEND_BLOCKED / NOT VERIFIED**. No production API requests or mutations were performed.

## UI and behavior

- Contract Detail exposes settlement navigation only for a server-reported `completed` contract.
- The settlement page GETs current Contract data and shows server-calculated deposit, damage/overdue fees, forfeiture, refund and additional payment fields when present. It does not calculate refund values.
- Confirmation and dispute require explicit dialogs. Disputes require a reason. Duplicate submits are disabled.
- On uncertain mutation outcome, the screen performs one safe contract GET reconciliation and does not resend automatically.
- Refund list/detail display server amount, references, masked bank information, dates and status timeline. Empty/error/retry/refresh/pagination states are present. Cancellation is offered only for `pending_approval` and reconciles with GET after uncertain outcomes.
- Refund tracking is reachable from Profile. The FE does not generate refund requests and does not expose staff approve/reject/confirm-paid controls.

## Changed files

- `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_route_screen.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_settlement_screen.dart`
- `apps/flutter_mobile/lib/features/refunds/data/refund_request.dart`
- `apps/flutter_mobile/lib/features/refunds/data/refund_repository.dart`
- `apps/flutter_mobile/lib/features/refunds/presentation/refund_screens.dart`
- `apps/flutter_mobile/lib/app/router.dart`
- `apps/flutter_mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `apps/flutter_mobile/test/phase1_settlement_refunds_test.dart`

## Verification

- Focused phase tests: **5 passed** (settlement request contracts and validation, lifecycle gate, refund cancellation validation, DTO/pagination/cancel eligibility).
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub -r compact`: passed, all 90 tests.
- `flutter build apk --debug --no-pub`: passed; APK at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed (only Git line-ending conversion notices for existing Windows working-tree files).
- Android visual QA: **NOT VERIFIED**; no emulator screenshot was captured.
