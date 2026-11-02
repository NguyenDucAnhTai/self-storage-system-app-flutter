# Post-merge developer code preservation audit

Date: 2026-11-02  
Repository: `self-storage-system-app-flutter`  
Incoming developer commit: `10c4bc28d83b72953ee5fb5d23a008033e161082`  
Merge commit audited: `7a18bfb219556026a9c83ad4fb14d9bc599235c9`  
Merge base: `946330f76e25e566f4ffed732e7a618fd2a28447`

## Executive result

**The incoming renewal/addendum, My Storage, inventory request, and settlement implementations are present in the merge tree and current worktree.** No incoming feature source file in the selected modules is deleted by the current uncommitted audit fixes. The current workspace also includes earlier fixes in router/auth routing and contract-screen compilation; those edits remain untouched by this audit.

There are meaningful divergences between the incoming parent and the merge result. They must not be attributed to the current uncommitted fixes: notably, the merge result has two separate settlement screens and the `/contracts` list opens a renewal/addendum sheet rather than the earlier full contract detail/payment route. The full contract detail remains reachable through `/contracts/:id`, but this does not establish that every route into it is wired in every customer flow.

No Android device or emulator is available in `flutter devices`; therefore this audit did not perform device UI verification or claim end-to-end runtime verification.

## A. Feature preservation matrix

| Feature | Incoming implementation and evidence | Current state / routes | Preservation verdict | Test coverage and gaps |
|---|---|---|---|---|
| Contract renewal and addendum | Incoming commit adds `contracts_screen.dart`, `ContractRepository` addendum API, `contract_addendum_test.dart`, and `CONTRACT_RENEWAL_ADDENDUM_FE_BE_GUIDE.md`. Repository methods cover create renewal, customer sign, and cancel addendum. | The current `ContractsScreen` retains the renewal request sheet, lists addendums, allows customer signature on draft addendum, and allows cancellation for draft/pending-approval statuses. `/contracts` is guarded and registered. | **PRESERVED WITH CHANGES** | `contract_addendum_test.dart` checks repository method paths/bodies and one overdue → draft → customer-sign UI path. UI creation of renewal, cancellation, pending-approval state, error/retry and refresh behavior are not exercised. |
| Contract detail and settlement entry | Merge base had contract detail navigation. Incoming and merge implementations differ in `contracts_screen.dart`. | `/contracts/:id` maps to `ContractDetailRouteScreen`; it is guarded. In contrast, tapping a row on `/contracts` opens the renewal/addendum bottom sheet. A completed-contract shortcut there opens `SettlementScreen`. | **PRESERVED WITH CHANGES; ROUTE INTEGRATION PARTLY UNVERIFIED** | Detail route/widget has journey coverage in existing tests, but there is no test proving every list entry invokes `/contracts/:id`. The merge changed list-row behavior relative to the prior detail/payment flow; see §B. |
| My Storage / inventory | Incoming adds `storage_repository.dart`, `storage_screen.dart`, profile tile, storage tests and case docs. | `Profile` links to `/storage`; route is registered and guarded. Screen provides overview, inventory, movements and SKU tabs, links to requests and storage layout. | **PRESERVED** | `storage_repository_test.dart` exercises summary/list API parsing, SKU creation/deletion/undo, and inventory detail → layout. No connected Android/profile journey was exercised. |
| Inbound/outbound requests | Incoming adds `inventory_requests_repository.dart`, `inventory_requests_screen.dart`, QR dependency, tests and cases. | `/storage` reaches the storage screen; it links to `InventoryRequestsScreen`. Screen includes request list/filter, inbound/outbound creation, request detail, OTP regeneration, cancellation, inbound confirm/dispute. | **PRESERVED** | Repository test verifies list/create/regenerate/cancel/confirm/dispute methods, paths and bodies. Widget tests verify confirm/dispute controls are conditionally shown, expiration/OTP visibility and some screens. Actual UI submit paths for confirm/dispute/cancel/regenerate and full create/list navigation lack coverage. |
| Settlement and refund tracking | Incoming adds `settlement_screen.dart` and `settlement_refund_test.dart` with settlement/refund repository interactions. | `SettlementScreen` is still used from the completed contract sheet and includes refund information. Separately, `/contracts/:id/settlement` is registered to `ContractSettlementScreen`, a second Vietnamese settlement UI. | **PRESERVED WITH CHANGES; DUPLICATE UI** | Tests cover repository methods and widget flows for both screens across `settlement_refund_test.dart` and `phase1_settlement_refunds_test.dart`, but not parity of eligibility/state behavior. The two implementations disagree on a guard (see §B). |
| Shared customer routes/auth | Incoming modifies router/auth/login. | Current router registers and guards contracts, detail, settlement, refunds, support, incidents and storage. Login redirect preserves a safe local `from` route. | **PRESERVED WITH REPAIRS** | `router_auth_redirect_test.dart` tests route redirects; screen-level route rendering on Android remains unverified. |

## B. Exact merge differences and risks

### 1. Contract list opens a different screen than the prior detail flow

- The pre-merge customer flow used `ContractDetailScreen` with `PaymentRepository` support and GoRouter navigation for payment/detail actions.
- In the merge result and current tree, `ContractsScreen` row tap opens `_detail(id)`, which shows `_ContractDetail` in a modal bottom sheet. That sheet is centered on renewal/addendums; completed contracts open `SettlementScreen` locally.
- The previous `PaymentRepository` / `ContractDetailScreen` list-row path is not present in the current `ContractsScreen` imports/fields. The full detail is still registered at `/contracts/:id` in the current repaired router.
- This change is **present in the merge result’s contract screen direction**, not introduced by the current uncommitted router/contracts-screen repair. The post-merge repair restored the malformed contract screen structure and keeps the incoming renewal/addendum controls. It did not restore a list-row push to `/contracts/:id`.
- Impact: the route itself exists, but list-origin discoverability and payment/detail navigation from that list need an explicit integration test and product decision. Do not describe the old list path as verified in the current behavior.

### 2. Two settlement implementations have different action eligibility

- `SettlementScreen` (`lib/features/contracts/presentation/settlement_screen.dart`) enables confirm/dispute based on completed contract and missing `settlementConfirmedAt`.
- `ContractSettlementScreen` (`lib/features/contracts/presentation/contract_settlement_screen.dart`) additionally excludes `depositStatus == disputed` and renders a disputed explanation.
- Both screens remain in the current tree and have separate entry points. This is a **merge integration inconsistency**, not deletion of the incoming settlement feature.
- Impact: a disputed settlement may still expose actions on the incoming English screen even though the Vietnamese route screen blocks them. Canonicalize the flow or align the guard in a separate approved implementation task.

### 3. Audit repair scope and current uncommitted changes

Before this audit, status showed prior audit changes in `router.dart`, `contract_repository.dart`, `contracts_screen.dart`, three tests, plus an untracked auth redirect test and prior audit report. They have been preserved.

- `router.dart`: earlier uncommitted repair registers the detail/settlement/refund/support/incident/storage routes and routes auth decisions through `resolveAuthRedirect`. The previous merge tree had those customer modules in source but the router did not expose all of them. Guard tests were added.
- `contract_repository.dart`: earlier uncommitted repair removes duplicate `confirmSettlement` / `disputeSettlement` declarations. The retained definitions validate and send the same API operations; this is a compile cleanup, not removal of settlement functionality.
- `contracts_screen.dart`: earlier repair restores a valid list/detail-sheet structure and keeps renewal/addendum actions. It adds contract-change callbacks to refresh dashboard providers. It does not remove the incoming renewal code.
- Tests `contract_customer_journey_test.dart`, `login_navigation_test.dart`, `notification_bell_test.dart` and `router_auth_redirect_test.dart`, and `POST_MERGE_FULL_INTEGRATION_AUDIT.md` pre-existed this preservation audit. They were not overwritten.
- This audit added no production implementation files and did not modify Backend, reservations, contracts, payments, credentials or production data.

### 4. Incoming file tracking

Git comparison `merge-base → incoming commit` identifies the incoming sources as additions/changes, including:

- `lib/features/contracts/presentation/settlement_screen.dart`
- `lib/features/inventory_requests/data/inventory_requests_repository.dart`
- `lib/features/inventory_requests/presentation/inventory_requests_screen.dart`
- `lib/features/storage/data/storage_repository.dart`
- `lib/features/storage/presentation/storage_screen.dart`
- `test/contract_addendum_test.dart`
- `test/inventory_requests_test.dart`
- `test/settlement_refund_test.dart`
- `test/storage_repository_test.dart`

All five feature source files and all four incoming test files are still present and tracked in the audited tree. The focused `incoming commit → merge commit` comparison reports changes to shared/divergent files such as router/auth/contracts, but does not report deletion of these feature source files.

## C. Confirmed code behavior

### Renewal/addendum

`ContractRepository.renew()` posts to `/contracts/{id}/addendums` with `type: renew`, ISO `newEndDate`, and optional notes. Customer signing posts to `/contracts/{id}/addendums/{addendumId}/customer-sign` with `termsAccepted: true`. Cancellation posts to `/contracts/{id}/addendums/{addendumId}/cancel` with a cancellation reason. The contract sheet exposes these operations according to status and shows errors as UI feedback.

### My Storage and requests

`StorageRepository` uses customer-inventory summary/list and SKU management endpoints. `StorageScreen` exposes inventory/movements/SKU views and links to request management and unit layout. `InventoryRequestsRepository` uses GET list/detail and POST inbound pre-advice/outbound creation, OTP regeneration, cancellation, inbound confirmation and dispute endpoints. The request detail screen gates available actions on request type/status/expiry and refreshes state after actions.

These source/API paths are verified locally; deployed authorization, production response behavior and customer ownership enforcement have not been verified by this audit.

### Settlement

Both screens call the contract settlement repository APIs. Refund retrieval/details and customer cancellation paths exist on the incoming screen. Differences in UI language and eligibility logic make the duplicate paths observable behavior, not just styling duplication.

## D. Verification

Commands actually run from `apps/flutter_mobile/`:

- `flutter analyze --no-pub` — **PASS**, no analyzer findings.
- `flutter test --no-pub --reporter expanded` — **PASS**, all **137 tests** passed.
- `flutter build apk --debug --no-pub` — Gradle `assembleDebug` was still running when the tool returned its final available output. **Build completion was not confirmed; report as NOT VERIFIED**, not pass.
- `git diff --check` — **PASS**; only Git line-ending conversion warnings for two pre-existing modified tests (`LF will be replaced by CRLF`).
- `flutter devices` — Windows, Chrome and Edge only; **no Android device/emulator detected**.
- Git comparisons — incoming commit, merge base, merge commit, and current working-tree status inspected. No reset/checkout/restore/cherry-pick was performed.

No production API mutations or authenticated production reads were made.

## E. Direct answers

1. **Did the current post-merge repairs remove an incoming feature?** No. The four requested feature areas and their implementation files remain present. The repairs restored routing and compile integrity while retaining renewal/addendum behavior.
2. **Was business behavior altered?** Yes, the merge result differs from the prior pre-merge contract list behavior: list taps now open a renewal/addendum sheet rather than the former full detail/payment screen. The current uncommitted repair keeps that merge behavior and separately restores `/contracts/:id`. There are also two settlement UIs with different eligibility guards. These are integration differences that need follow-up, not evidence that the incoming feature files were deleted.
3. **Are incoming feature routes reachable?** My Storage is reachable through Profile → `/storage`; contract renewal is reachable from `/contracts`. Settlement is reachable from the completed-contract sheet and `/contracts/:id/settlement`. These routes are registered and guarded in current source. Widget/static verification does not prove Android runtime behavior.
4. **Are feature APIs intact?** Repository implementations and local mocked tests show endpoint paths/bodies remain in place. Production authorization, deployed contract compatibility and ownership behavior are **NOT VERIFIED**.
5. **Are tests complete?** They cover repository contracts and several important UI states. They do not cover all request action taps, the whole route journey, duplicate settlement parity or all renewal UI outcomes.
6. **What remains?** Run/confirm APK completion, Android emulator QA, test list-row → contract detail/payment navigation, test all inventory request actions from the UI, test renewal create/cancel/refresh states, and align the two settlement screens/eligibility rules before claiming consistent customer behavior.

## Verdict

| Area | Verdict |
|---|---|
| Contract renewal/addendum | **PRESERVED WITH CHANGES** |
| My Storage | **PRESERVED** |
| Inbound/outbound inventory requests | **PRESERVED** |
| Settlement/refund | **PRESERVED WITH CHANGES; INCONSISTENT DUPLICATE UI** |
| Shared routes/auth | **PRESERVED WITH ROUTING REPAIRS** |
| Android E2E runtime | **NOT VERIFIED — no emulator/device** |
| Production API/auth behavior | **NOT VERIFIED** |

