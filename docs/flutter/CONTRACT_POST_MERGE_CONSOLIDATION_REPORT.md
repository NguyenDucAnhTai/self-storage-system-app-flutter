# Contract post-merge integration consolidation

Date: 2026-11-02  
Scope: Flutter Customer only; no Backend edits or production writes.

## Final verdict: **PASS**

Both contract integration inconsistencies are resolved in source and covered by the automated suite. Android device QA remains unverified because Flutter currently detects Windows, Chrome and Edge only.

## Root causes

1. `ContractsScreen` opened the incoming renewal/addendum bottom sheet directly from each list row, bypassing the original full Contract Detail route. The app already had `/contracts/:id` and `ContractDetailRouteScreen`, but the list did not use it.
2. The merge left two settlement experiences. The incoming `SettlementScreen` allowed actions for any completed, unconfirmed contract; the existing Vietnamese `ContractSettlementScreen` also blocked a contract whose deposit was already disputed. Refund list/detail capability was only available from the incoming screen.

## Task 1 — Contract detail and renewal navigation

- Contract list row and “Xem chi tiết” now push `/contracts/:id`.
- The existing full detail remains responsible for storage summary, contract timeline, customer/facility signatures, first-period payment information, payment navigation and settlement entry.
- A “Gia hạn & phụ lục hợp đồng” button in Contract Detail opens the existing renewal/addendum sheet via the shared `showContractRenewalAddendums` function. The renewal form, addendum list, signature and cancellation handlers remain in one implementation; no second form or API logic was added.
- After the sheet closes, Contract Detail reloads and the registered callback invalidates contract and Home dashboard providers. Detail refresh, payment return and settlement return also refresh current contract state/providers through existing callbacks.
- The integration test taps a contract list action, verifies full detail/timeline/payment content, opens the renewal/addendum sheet and signs an addendum against a mocked Dio fixture. The repository test continues to verify renewal creation, signing and cancellation paths/bodies.

## Task 2 — Canonical settlement and Backend evidence

### Backend rule reviewed

Read-only review of local Backend source:

- `self-storage-system-be-dev/src/modules/contract/contract.service.ts`, `confirmSettlement()` and `disputeSettlement()` (around lines 2554–2635): both require an existing contract, customer role and matching owner, `status == completed`, and no `settlementConfirmedAt`.
- Neither service method checks `depositStatus == disputed`. Dispute sets `depositStatus` to `disputed`, sets dispute metadata, and does not confirm settlement.
- Controller declarations are in `src/modules/contract/contract.controller.ts` around lines 832–889. They call those service methods. The deployed Render version was not queried, so the local source is the inspected contract evidence, not proof of deployed code.

### Decision

`ContractSettlementScreen` is canonical: it is the existing Vietnamese customer screen and already has the safer disputed-state handling and uncertain-write reconciliation. This keeps the client from presenting another financial action after a dispute has been recorded, even though local Backend service checks do not explicitly block it. No Backend rule was invented or changed.

All Customer contract settlement entry points now reach the canonical screen:

- Contract Detail → `/contracts/:id/settlement` → `ContractSettlementScreen`.
- Completed contract from the renewal/addendum panel → the retained `SettlementScreen` compatibility entry point, which delegates to `ContractSettlementScreen`.

The old `SettlementScreen` implementation was reduced to a compatibility wrapper only after its unique capabilities were migrated:

- Deposit calculation/status and settlement confirmation/dispute details remain in the canonical Vietnamese UI.
- Contract-filtered refund list, page navigation, reason/status/amount presentation and retry are now embedded in the canonical settlement UI.
- Refund detail and customer cancellation remain available through the existing `/refunds/:id` route, reached from each settlement refund row.
- Settlement mutation success updates the view/provider. An uncertain failure performs a GET reconciliation and never automatically repeats the POST; backend message/code are surfaced when reconciliation says the action did not complete.

Eligibility is consistently `completed && settlementConfirmedAt == null && depositStatus != disputed`. Tests verify the eligible completed case and block active, already-confirmed and disputed cases without issuing POSTs. A mocked dispute interaction asserts one settlement POST with the expected reason, and busy state disables repeated submission.

## Files changed for this consolidation

- `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart` — route list taps to full detail; expose the existing renewal sheet through a shared entry function.
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_route_screen.dart` — open renewal/addendum sheet from detail and refresh on return.
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart` — add the renewal/addendum entry point.
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_settlement_screen.dart` — consolidate refund tracking and retain safe eligibility/error reconciliation.
- `apps/flutter_mobile/lib/features/contracts/presentation/settlement_screen.dart` — preserve compatibility by delegating to the canonical screen.
- `apps/flutter_mobile/lib/features/refunds/presentation/refund_screens.dart` — avoid disposing the cancellation input while its dialog is closing.
- `apps/flutter_mobile/test/contract_post_merge_consolidation_test.dart` — new list → full detail → renewal sheet → addendum sign regression.
- `apps/flutter_mobile/test/contract_addendum_test.dart` — keep repository contract tests for create/sign/cancel endpoints and payloads.
- `apps/flutter_mobile/test/phase1_settlement_refunds_test.dart` — settlement eligibility matrix.
- `apps/flutter_mobile/test/settlement_refund_test.dart` — canonical settlement/refund tests and single-POST assertion.

Earlier uncommitted changes in the workspace were preserved. No commit or push was made.

## Regression verification

Commands run in `apps/flutter_mobile/`:

- `flutter analyze --no-pub` — **PASS**, no issues.
- `flutter test --no-pub --reporter expanded` — **PASS**, all **138 tests** passed.
- `flutter build apk --debug --no-pub` — **PASS**, exit code **0**; APK built at `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — **PASS**, exit code **0**; Git printed only line-ending conversion notices for Windows working copies.
- `flutter devices` — Windows, Chrome and Edge found; no Android emulator/device available.

Existing test coverage continues to include contract list/detail/timeline/payment screens, payment history, refunds, My Storage/inventory requests and route auth redirects. New widget tests cover the repaired Contract Detail and renewal entry journey and canonical settlement states.

## Remaining blockers / limits

- Device UI inspection of Contract Detail, Renewal and Settlement was not possible without an Android device/emulator.
- Production Render settlement behavior and deployed Backend version were not exercised. No production writes were attempted.
- Local Backend controllers still contain commented security decorators/TODOs even though the service methods perform customer role/owner checks; deployed middleware and authorization must be confirmed independently before production readiness.
- Existing `/payments/:id` and Payment History flows were regression-tested by the full suite, but no live account/payment data was used.

