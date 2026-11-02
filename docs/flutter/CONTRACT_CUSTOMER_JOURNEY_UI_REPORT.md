# Flutter Customer Contract Journey UI Report

**Date:** 2026-10-31  
**Scope:** Flutter customer app only. Backend source and production data were not changed.

## Implementation

- Replaced the contract list's ID-focused rows with customer-facing cards showing contract code, facility/unit names when returned, contract period, rental amount when available, Vietnamese status, and a next-step summary.
- Replaced the short bottom sheet with a scrollable full-screen detail page. It displays returned facility/unit information, dates, rental terms, payment states, customer/staff signatures, actual/expected check-in data, and a vertical progress timeline. Missing fields are called out as unavailable instead of being inferred.
- A `draft` contract with `customerSigned: true` is treated as signed. The sign action is not shown again. Staff signing and actual check-in remain separate milestones; status is called active only when the server status is `active` and both signature flags are true.
- If contract detail does not include terms, the customer can request the read-only `GET /contracts/{id}/draft-pdf` endpoint. Returned HTML is presented as text. Signing remains unavailable until actual server-provided terms are present and the customer explicitly checks the consent box.
- After the customer-sign POST succeeds or has an uncertain/failing response, the app performs a safe contract GET and reconciles from `customerSigned`. It never automatically repeats the signing POST. Submission is guarded while in progress.
- Removed the old legacy renewal control from this screen. The existing API re-audit documents `/contracts/{id}/renew` as stale and rejected by Backend service; no replacement addendum workflow was introduced here.

## Payment and Backend boundaries

The existing Flutter payment flow only creates reservation-deposit sessions. Repository/API documentation lists `rent_first_period` and `contractId` as supported payment request values, but does not establish the eligibility conditions or confirm that contract detail supplies an authoritative eligibility flag. There is also no contract-payment screen/session reuse flow in Flutter. Therefore the UI reports missing or unverified first-period rent state and does not expose a payment CTA or create a payment session. A backend/API owner must confirm eligibility and pending-session reuse semantics before this action can be enabled.

Current project documentation also records contract route authorization/ownership as blocked and live contract responses as unverified. No production GET or mutation was executed during this task.

## Tests and verification

Added isolated widget fixtures for:

- Signed-but-draft state and hidden repeat-sign action.
- Failed signing response followed by GET reconciliation to `customerSigned: true`.
- First-period payment eligibility not inferred from an unpaid flag.
- Missing payment/check-in/terms fields.
- Loading actual contract terms from the server response before enabling signing.
- Progress display for paid deposit/rent, both signatures, actual check-in, and active status.
- Detail layout at 320dp width.

Commands run from `apps/flutter_mobile/`:

- `flutter analyze --no-pub` — **PASS**, no issues.
- `flutter test --no-pub` — **PASS**, 66 tests.
- `flutter build apk --debug --no-pub` — **PASS**, APK built at `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — **PASS**. Git emitted only the existing-style LF-to-CRLF notices for edited files.

## Device/runtime evidence

No authorized contract test session was available for this task. No production contract was opened, signed, or otherwise mutated, and no actual device screenshot was captured. The new screen was verified with isolated mocked widget fixtures only. Production authorization, returned contract DTO fields, draft HTML rendering against a live response, payment eligibility, and signing reconciliation against a live service remain **NOT VERIFIED**.

## Files changed

- `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart`
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart`
- `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart`
- `apps/flutter_mobile/test/contract_customer_journey_test.dart`
- `docs/flutter/CONTRACT_CUSTOMER_JOURNEY_UI_REPORT.md`
