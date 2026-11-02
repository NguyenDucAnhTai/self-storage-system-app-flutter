# Post-Merge Full Integration Audit — Flutter Customer

**Audit date:** 2026-11-02  
**Workspace:** `apps/flutter_mobile/`  
**Final verdict:** **BLOCKED** — source/build/tests are healthy after localized fixes, but Android runtime and deployed Backend authorization/data isolation were not verified.

## A. Git / Merge Summary

- **Branch:** `Reservation,-Payment`
- **HEAD:** `7a18bfb219556026a9c83ad4fb14d9bc599235c9` — merge commit `Merge branch 'dev' ... into Reservation,-Payment`.
- **Parents:** first parent `a3152b7` (`UpdateTicketSupport`); second parent `10c4bc2` (merged `dev`).
- **Merge base:** `946330f76e25e566f4ffed732e7a618fd2a28447`.
- **Merge impact:** 33 paths changed from first parent: 15 Flutter library/config paths, five test files, shared API constant formatting, iOS asset metadata, and documentation/test-case additions. The incoming tree added settlement/refund UI, inventory request and storage screens, and renewal/addendum handling. No source files were deleted by the merge.
- **Initial worktree:** clean (`git status --short` had no entries); no staged, unstaged, or untracked work was present before this audit.
- **Merge markers:** none found under `apps/flutter_mobile/`.
- **Post-audit changes:** limited to the Flutter router, contract repository/list screen, three existing tests, one new router test, and this report. No Backend source was changed. `pubspec.lock` remained unchanged by dependency resolution.
- **Potential conflict/integration area:** `router.dart`, `contracts_screen.dart`, and `contract_repository.dart` combine existing customer flows with incoming features. The merge left route registrations removed and duplicate/partial contract code in place; details are in section D.
- **Assets/config:** iOS icon/launch metadata changed. No Flutter API URL, production credentials, or signing secret was changed. `packages/shared/src/constants/api.ts` changed formatting only.

## B. Project Health

| Check | Result |
|---|---|
| Flutter / Dart | Flutter 3.47.3 stable; Dart 3.13.3. `pubspec.yaml` requires `^3.13.3`. |
| Android toolchain | Android SDK 37.0.0 / API 37 beta; Java 21; licenses accepted. |
| `flutter doctor -v` | Android toolchain, Chrome, Windows, and network checks passed. Visual Studio is absent; this only blocks Windows desktop builds, not Flutter Android. |
| `flutter devices` | Windows, Chrome, Edge only. No connected/booted Android emulator or device was available. Android runtime verification is **NOT VERIFIED**. |
| Dependencies | `flutter pub get` succeeded without upgrading locked versions. It was necessary because the merged `qr_flutter` dependency existed in `pubspec.yaml`/lockfile but was not in the local package configuration/cache. Offline resolution first failed because the package was not cached; online `pub get` fetched the pinned dependency. No lockfile diff resulted. |
| `flutter analyze --no-pub` | **PASS**, no issues after fixes. |
| `flutter test --no-pub --reporter expanded` | **PASS**, all 137 tests passed. |
| `flutter build apk --debug --no-pub` | **PASS**, `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| Release APK | Not run. Android release configuration explicitly uses the debug signing key; no production release signing setup was provided. No distributable was created. |
| `git diff --check` | **PASS**, exit 0; Git emitted normal LF→CRLF notices for edited Windows files. |

## C. Module Audit Matrix

“API” below means Flutter paths/payloads were source-reviewed and mocked where tests exist. It does not mean the deployed API, authorization middleware, or production records were exercised.

| Module | Source | API | Navigation | Tests | Runtime | Status |
|---|---|---|---|---|---|---|
| Authentication / session | Reviewed; secure storage, bearer, refresh and logout cleanup present | Mock/source only | Login, return path and route guards tested | PASS | NOT VERIFIED | PARTIAL |
| Home dashboard / active rental | Reviewed; active rented rooms derived from contract records, distinct from inventory summary | Mock fixtures | Home and contract links source-reviewed | PASS | NOT VERIFIED | PARTIAL |
| Explore / facility / amenities | Reviewed | Mocked amenity list/filter and offering calls | Facility and reservation navigation source-reviewed | PASS | NOT VERIFIED | PARTIAL |
| Reservation creation / detail / reassignment | Reviewed; merge did not replace the existing reservation/payment repository | Mocked availability, payload, action and uncertain-result reconciliation | Routes retained; reassignment within reservation detail | PASS | NOT VERIFIED | PARTIAL |
| Deposit payment / payment detail / history | Reviewed; `paid` remains the only successful payment state | Mocked create/status/history | Payment routes retained; contract/reservation links depend on restored routes | PASS | NOT VERIFIED | PARTIAL |
| Contract list/detail/timeline/signing | Reviewed; fixed malformed merged list/detail integration | Mocked contract and payment states | `/contracts` and `/contracts/:id` restored and guarded | PASS | NOT VERIFIED | PARTIAL |
| Contract renewal/addendum | Reviewed; renewal uses `POST /contracts/{id}/addendums`, not deprecated `/renew` | Mocked create/sign/cancel states | Available from contract-list detail sheet | PASS | NOT VERIFIED | PARTIAL |
| Settlement/refund tracking | Reviewed; confirmation/dispute and refund reads/cancel flow remain explicit | Mocked | Settlement/refund routes restored and guarded | PASS | NOT VERIFIED | PARTIAL |
| Support tickets | Reviewed; explicit create and state-gated cancellation | Mocked | Profile/list/create/detail routes restored and guarded | PASS | NOT VERIFIED | PARTIAL |
| Incident reports | Reviewed; incident creation remains blocked pending safe evidence upload | Mocked list/detail/actions | Profile/list/create-blocked/detail routes restored and guarded | PASS | NOT VERIFIED | PARTIAL / CREATE BLOCKED |
| My Storage / inventory / inbound-outbound requests | Reviewed; includes explicit user-triggered mutation controls | Mocked repository and widget flows | `/storage` route restored and guarded; requests opened from Storage | PASS | NOT VERIFIED | PARTIAL |
| Notifications / profile | Reviewed | Mocked feed/read behavior | Routes retained; Profile navigation test fixed to scroll its item into view | PASS | NOT VERIFIED | PARTIAL |

No module is marked E2E verified. Widget/mock tests do not verify Android rendering, real account ownership, deployed endpoint behavior, or production state transitions.

## D. Merge Regression Findings

### 1. HIGH — Merge removed registered Customer routes and omitted the Storage route

- **Description / evidence:** the first-parent router registered contract detail and settlement, refunds, support, and incidents. The merge removed these registrations while retaining imports, Profile links, dashboard links, and calls such as `/contracts/{id}` and `/refunds/{id}`. It added a Profile link to `/storage` but did not register `/storage`.
- **Reproduction before fix:** open Profile → Refund Tracking, Support, Incidents, or My Storage; or open a contract from Home / a payment’s contract link. GoRouter had no matching route. Contract settlement/detail and support detail links were also unreachable.
- **Affected file:** `apps/flutter_mobile/lib/app/router.dart` (route table; restored routes now near lines 193–269).
- **Root cause:** the merge replaced the tail of the shell route list with a shortened list, dropping routes from the first parent while retaining their callers.
- **Regression introduced by merge:** **YES**, confirmed by `git diff 7a18bfb^1 7a18bfb`.
- **Fix:** restored contract detail/settlement, refund list/detail, support list/create/detail, incident list/create-blocked/detail and Storage routes. Contract list/detail callbacks again invalidate dashboard summary/contract providers after a state-changing flow.
- **Fix status:** fixed and covered by route-auth policy tests; every restored route was source-reviewed. Full app route rendering on Android remains unverified.

### 2. HIGH — Active redirect stopped guarding Home and nested customer routes

- **Description / evidence:** the merged inline redirect guarded `/contracts` only by exact equality and omitted `/home`, refunds, support, and incident routes. The previous `resolveAuthRedirect` helper had the broader policy but was no longer used. A guest could reach the Home shell and nested customer routes were not consistently redirected.
- **Affected file:** `apps/flutter_mobile/lib/app/router.dart` (active redirect now delegates to `resolveAuthRedirect`, around lines 44–54 and 286 onward).
- **Root cause:** guard logic was split between an unused helper and a narrower inline callback during merge integration.
- **Regression introduced by merge:** **YES**, confirmed against first parent.
- **Fix:** one shared redirect function now guards `/home`, reservations, payments, contracts and their subroutes, refunds, support, incidents, Storage, profile, password changes and notifications. It preserves a safe internal return path after login and rejects protocol-relative `//...` return paths.
- **Fix status:** fixed; added `test/router_auth_redirect_test.dart` for loading, nested protected routes, preserved return path, and open-redirect rejection. Backend authorization is still separate and unverified.

### 3. HIGH — Merged contract repository and list screen did not compile

- **Description / evidence:** `ContractRepository` declared `confirmSettlement` and `disputeSettlement` twice. `ContractsScreen` declared `_reload` twice, passed the void-returning declaration where `RefreshCallback` is required, referenced undefined `contracts` and helper members, and had no `_openDetail` implementation. The analyzer initially reported 31 issues, including these failures.
- **Affected files:** `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart` and `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart`.
- **Root cause:** settlement/refund and renewal/addendum implementations were merged into an existing contract flow without reconciling duplicate methods and screen state/helper definitions.
- **Regression introduced by merge:** **YES**, confirmed by the merge diff and first post-merge analyzer run.
- **Fix:** retained the response-validating settlement methods; removed duplicate declarations; restored list state/helpers; retained the renewal detail sheet and connected its row actions to the contract detail modal and provider refresh.
- **Fix status:** fixed; analyzer, full tests, and debug APK pass.

### 4. MEDIUM — Two settlement UIs remain reachable

- **Description / evidence:** the incoming `settlement_screen.dart` is pushed from the renewal detail sheet in `contracts_screen.dart`; the existing `contract_settlement_screen.dart` is reachable from the registered `/contracts/:id/settlement` route. They represent the same settlement task through different navigation and UI implementations (including different language/presentation). Both invoke settlement operations through `ContractRepository`.
- **Affected files:** `apps/flutter_mobile/lib/features/contracts/presentation/settlement_screen.dart`, `contract_settlement_screen.dart`, `contracts_screen.dart`, and `app/router.dart`.
- **Root cause:** the merge added another settlement surface without consolidating the pre-existing contract settlement route.
- **Regression introduced by merge:** **YES**, duplicate reachable surface confirmed by merge diff/source.
- **Recommended fix:** select one canonical settlement flow and route all contract entry points through it; retain any refund list/details as shared components. Verify eligible active/completed states and refresh behavior before removing either surface.
- **Fix status:** documented, not changed; this is a behavior/UI consolidation beyond a localized safe fix.

### 5. LOW — Test fixtures assumed a fixed calendar date remained future

- **Description / evidence:** two contract timeline tests asserted a “future check-in” explanation for timestamps fixed at 2026-11-01/02. Their result depended on the date/time when the test ran.
- **Affected file:** `apps/flutter_mobile/test/contract_customer_journey_test.dart`.
- **Regression introduced by merge:** **NO / UNKNOWN**; this was a test determinism defect, not an observed production UI defect.
- **Fix:** use a timestamp relative to `DateTime.now()` and assert the localized formatted value derived from the fixture.
- **Fix status:** fixed; both tests pass.

### 6. LOW — Profile navigation test tapped an offscreen tile

- **Description / evidence:** after the Storage menu item was added, “Thông báo” fell below the test’s 600dp viewport. The Profile is a `ListView`, but the test tapped the item at an out-of-bounds coordinate.
- **Affected file:** `apps/flutter_mobile/test/notification_bell_test.dart`.
- **Regression introduced by merge:** **YES**, the additional menu item changed the fixture’s vertical position; the product screen remained scrollable.
- **Fix:** call `ensureVisible` before tapping; no Profile UI change was needed.
- **Fix status:** fixed; full suite passes.

### 7. LOW — Login test asserted an obsolete English Home title

- **Description / evidence:** the test expected “Explore storage”; the current Home dashboard exposes Vietnamese “Trang chủ”. Navigation itself succeeded.
- **Affected file:** `apps/flutter_mobile/test/login_navigation_test.dart`.
- **Regression introduced by merge:** **NO / UNKNOWN**; stale assertion.
- **Fix:** assert the current Home label.
- **Fix status:** fixed; full suite passes.

## E. API Contract Mismatches and Backend Dependencies

### Source-level endpoint review

- **Contract renewal:** Flutter calls `POST /contracts/{id}/addendums` with `type: renew`, `newEndDate`, and optional `notes`; signing/cancellation call the corresponding addendum paths. This matches the local Backend request/controller source inspected. The legacy direct `POST /contracts/{id}/renew` is not used by the current Flutter repository.
- **Contract settlement:** `POST /contracts/{id}/settlement/confirm` has no body; dispute sends `disputeReason`. Flutter validates locally and parses the response envelope.
- **Refunds:** list/detail use `GET /refund-requests` and `GET /refund-requests/{id}`; customer cancellation sends `cancellationReason`.
- **Inventory:** repository paths reviewed against local source: `/customer-inventories` reads, `/customer-skus` list/create/update/delete/restore, `/customer-inventories/requests` list/detail, pre-advised inbound and outbound request creation, OTP regeneration, inbound confirm/dispute/cancel, and outbound cancel. Mock tests cover request construction. No production API request was made.
- **Amenities / reservations / payments / support / incidents:** existing phase reports describe exact request and envelope tests; the complete suite passed. No live compatibility claim is made.
- **No confirmed Flutter method/path/body mismatch** was found in the audited merge paths against the local Backend reference. Pagination schema defaults `sortBy`/`sortOrder`, so the contract `listAll()` omission is accepted by that source. Swagger metadata and deployed behavior may differ.

### Backend authorization / data integrity blockers

- Local Backend reference controllers contain commented security decorators or role-authorization TODOs for contract, inventory-request, customer-SKU, support/incident, reservation/payment and related Customer routes. This is a **Backend authorization blocker / unverified concern**, not something Flutter route guards can solve. Production cross-customer isolation cannot be certified from this client audit.
- The phase 4 report notes that the Backend reservation service did not visibly verify an amenity offering belongs to the reservation’s facility. Flutter only submits offerings loaded for the selected facility, but only Backend validation can enforce that invariant.
- Incident creation remains deliberately blocked in Flutter until a safe, supported evidence upload contract is confirmed. Do not use `/upload/signature` as a file-upload substitute.
- Settlement, reassignment, support/incident and inventory mutations were not sent to production. Local Backend source review is not proof that Render is running that source.

### Documentation drift

- `CONTRACT_RENEWAL_ADDENDUM_FE_BE_GUIDE.md` says the current Flutter repository still uses deprecated `/contracts/{id}/renew`; the audited current code uses the addendum endpoint. The guide should be refreshed by its owner.
- `docs/flutter/SECURITY-REVIEW.md` and `docs/flutter/BACKEND-BLOCKERS.md` contain earlier statements that conflict with the later Four Modules Integration Summary about customer support endpoints. Reconcile the documents against the deployed Backend contract before release.

## F. Business Journey Verification

| Journey | Evidence in this audit | Result |
|---|---|---|
| 1. Reservation: Login → Explore → Facility → unit/date/slot/amenities → create → detail | Existing widget/repository suite passed; no reservation POST was sent to production. | **PARTIAL — mocks only** |
| 2. Deposit: reservation → payment session → QR/status → paid → refresh reservation | Mocked API tests pass; code uses Backend QR and recognizes only `paid`; no live payment session/webhook was exercised. | **PARTIAL — mocks only** |
| 3. Contract activation: customer signature → first rent → active → Home rented room | Contract timeline and dashboard contract fixtures pass; Manager/facility transitions and customer data were not exercised live. | **PARTIAL — fixtures only** |
| 4. Payment history → filters/detail/related record | Payment history tests and route/source review pass; read-only behavior was not tested against a deployed account. | **PARTIAL — mocks only** |
| 5. Reassignment proposal → accept/reject → reconcile | Phase 2 mocked stale/pending/uncertain outcomes pass; no authorized live proposal was available. | **PARTIAL — mocks only** |
| 6. Completed contract → settlement → refund tracking | Phase 1 mocked eligibility, confirm/dispute and refunds pass; no settlement/refund mutation was executed. | **PARTIAL — mocks only** |
| 7. Profile → support ticket → detail/cancel | Phase 3 widget/API mocks pass; route registrations restored; no deployed ownership or mutation check. | **PARTIAL — mocks only** |
| 8. Incident list/detail/cancel/close | Mocked read/action flows pass and Flutter creation is blocked by design pending safe upload requirements. | **PARTIAL — creation intentionally blocked** |
| 9. Explore amenity filter → Facility → Reservation selector | Phase 4 mocked all/any/filter/selection/payload coverage passes; no current catalog or stock verified. | **PARTIAL — mocks only** |
| 10. Newly merged inventory and renewal/addendum journeys | Inventory repository/UI and contract addendum tests pass; route registrations and source-level contracts reviewed. No authorized staging lifecycle fixture/device run. | **PARTIAL — mocks only** |

## G. Changes Made During Audit

- `apps/flutter_mobile/lib/app/router.dart` — restored missing route registrations; centralized and expanded auth redirect coverage; preserved Home as the post-login/splash destination.
- `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart` — removed duplicate settlement method declarations.
- `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart` — repaired the merged contract list/detail integration while retaining renewal/addendum controls.
- `apps/flutter_mobile/test/router_auth_redirect_test.dart` — new guard/return-path coverage.
- `apps/flutter_mobile/test/contract_customer_journey_test.dart` — made future-date fixture deterministic and timestamp assertion fixture-derived.
- `apps/flutter_mobile/test/notification_bell_test.dart` — scrolls Profile item into view before tapping.
- `apps/flutter_mobile/test/login_navigation_test.dart` — asserts current Vietnamese Home title.
- `docs/flutter/POST_MERGE_FULL_INTEGRATION_AUDIT.md` — this report.

No Backend or production data was changed. `flutter pub get` populated local dependency state for the already-pinned `qr_flutter` package; it did not change `pubspec.lock`.

## H. Remaining Blockers

### Flutter / runtime

- Android runtime QA was not possible: `flutter devices` found no Android emulator/device. Screen overflow, SafeArea, keyboard behavior and real navigation on 320/360/390dp Android devices remain **NOT VERIFIED**.
- The `flutter emulators` listing command did not return in the allotted check and was interrupted; this does not prove that no AVD is configured, only that no Android device was connected to Flutter at audit time.
- The incoming `My Storage`, settlement and addendum UI contains English-facing text in several places while the main customer app is Vietnamese. This is a localization polish issue; no business flow was changed for it.

### Backend / authorization / fixtures

- Verify Customer role and owner checks for all deployed contract, inventory, support/incident, reservation, payment, refund, settlement and reassignment operations. Client-side route guards are not authorization.
- Confirm amenity-offering/facility association on reservation creation in Backend.
- Confirm a non-production staging base URL and authorized test customer plus legitimate fixtures for pending reassignment, completed settlement/refund, support/incident records, storage inventory requests, and amenity availability.
- Confirm the approved incident evidence upload endpoint, file constraints, ownership, and private evidence access behavior.
- No production POST/PATCH/PUT/DELETE, login, or customer account access was performed.

### Environment / release

- Debug APK is built and local checks pass. Release build was not attempted because the Gradle release signing configuration uses the debug key and no release signing configuration was supplied.

## I. Final Verdict and Prioritized Actions

### Verdict: **BLOCKED**

The confirmed Flutter merge regressions were repaired. Static analysis, all 137 tests, and the debug APK build pass. This cannot be called PASS because Android runtime QA and deployed Backend authorization/ownership verification remain incomplete.

1. **P0:** Have Backend owners confirm and enforce Customer role/ownership checks in deployed routes; verify using separate authorized staging accounts.
2. **P0:** Run the restored routes and the 10 journeys on a stable Android emulator/device using authorized staging fixtures; capture screenshots and verify responsive UI states.
3. **P1:** Confirm amenity-offering facility ownership validation and the incident evidence-upload contract.
4. **P1:** Update the stale renewal and security/blocker documents to reflect current source/API ownership.
5. **P2:** Localize remaining English labels in My Storage, settlement, and renewal/addendum surfaces after product terminology is agreed.
