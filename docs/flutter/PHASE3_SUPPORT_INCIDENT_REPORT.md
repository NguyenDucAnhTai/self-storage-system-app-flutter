# Phase 3 — Support Tickets & Incident Reports

## Result

Flutter customer support tickets are integrated for list, detail, create and eligible cancellation. Incident records are integrated for list, detail and state-eligible customer close/cancel actions. Incident creation remains **BLOCKED** in the app because the Backend requires at least one evidence image URL, while the available upload-signature endpoint does not define verified upload formats, size limits, ownership checks or safe file access. The app does not invent URLs or render private evidence links.

## Endpoint checklist

| Method / path | Customer permission evidence (read-only local Backend source) | Flutter status | Tested behavior |
|---|---|---|---|
| GET `/support-tickets?page=&limit=` | Service scopes customer queries to authenticated caller; client must not supply `customerId`. Controller role authorization remains TODO. | DONE | Mock verifies pagination query and omission of `customerId`; list parser and empty/error/retry states implemented. |
| GET `/support-tickets/{id}` | Service checks owner. Controller role authorization remains TODO. | DONE | Detail fields and optional staff response mapped from returned JSON; mock screen test covers status-gated controls. |
| POST `/support-tickets` | Service creates the ticket for caller; contract validates category, priority, 3–200 title, 5–3000 description and max 5 attachment URLs. Controller role authorization remains TODO. | DONE | Explicit submit only; payload includes category, medium priority, title, description and empty attachments. Validation and one-submit lock tested. An unknown outcome blocks another POST until customer acknowledges checking the list; known HTTP failures show status-specific guidance. |
| POST `/support-tickets/{id}/cancel` | Owner only; customer may cancel while pending. Cancellation reason is optional, max 500. Controller role authorization remains TODO. | DONE | Cancel control shown only for pending state; explicit confirmation; tested completed state has no action. |
| GET `/incidents?page=&limit=` | Service forces customer reporter scope. Controller role authorization remains TODO. | DONE | Uses session auth and paginated list; no caller-selected reporter/customer ID. |
| GET `/incidents/{id}` | Customer may read as reporter or owner of linked contract. Controller role authorization remains TODO. | DONE | Detail/status timeline shows localized states without inventing per-state timestamps or exposing evidence URLs. |
| POST `/incidents` | Service permits Customer reporter, validates linked contract ownership and facility association. Requires at least one image URL. Controller role authorization remains TODO. | BLOCKED | No POST UI is enabled. Backend Upload API only issues a Cloudinary signature; safe upload constraints are not specified/verified. |
| POST `/incidents/{id}/cancel` | Reporter only and only in `reported`; requires 5–500 character reason. Controller role authorization remains TODO. | DONE | Action shown only in `reported`; requires entered reason and explicit confirmation. |
| POST `/incidents/{id}/close` | Reporter or linked-contract owner; only `resolved`; optional notes max 1000. Controller role authorization remains TODO. | DONE | Action shown only in `resolved`; explicit confirmation then detail GET refresh. |
| POST `/incidents/{id}/assign`, `/investigate`, `/resolve` | Operational roles only. | NOT CUSTOMER ALLOWED | No customer controls or calls added. |
| POST `/upload/signature` | Upload signature endpoint; this is not itself an upload endpoint and does not establish safe file rules. | BACKEND_BLOCKED | Not called or integrated. |

## Implementation

- Added `CustomerCareRepository` for ticket and incident endpoints. List calls do not send `customerId` or `reporterId`.
- Added Vietnamese support list, validated create form, detail and pending-only cancellation.
- Added incident list/detail, localized status progression, reported-only cancellation and resolved-only closure.
- Added Profile links for “Hỗ trợ khách hàng” and “Báo cáo sự cố”; retained four bottom-navigation destinations.
- Added a clear blocked-state screen for incident creation rather than faking evidence or silently submitting invalid requests.
- Backend controller comments show role authorization TODOs for these routes. Flutter session auth is not a substitute; live ownership/authorization remains unverified.

## Files

- `apps/flutter_mobile/lib/features/customer_care/customer_care.dart`
- `apps/flutter_mobile/lib/features/customer_care/customer_care_screens.dart`
- `apps/flutter_mobile/lib/app/router.dart`
- `apps/flutter_mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `apps/flutter_mobile/test/phase3_customer_care_test.dart`

## Verification

- `flutter analyze --no-pub` — passed, no issues.
- `flutter test --no-pub` — passed, 101 tests at Phase 3 completion (the final four-phase suite is recorded in the integration summary).
- `flutter build apk --debug --no-pub` — passed (`apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`).
- `git diff --check` — run after this report was added; see task summary.
- No production API requests or mutations were made. Tests use a mocked Dio adapter.
- No Android emulator visual QA or screenshots were performed in this phase.

## Remaining blockers

1. Backend authorization annotations/role enforcement need confirmation before production readiness.
2. Incident creation needs an approved upload contract or safe, verified customer evidence upload flow with format, size, ownership and access controls.
3. Live API compatibility, ownership behavior and state conflicts remain unverified against a permitted staging/test account.
