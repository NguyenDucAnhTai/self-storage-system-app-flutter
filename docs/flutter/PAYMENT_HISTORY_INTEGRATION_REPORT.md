# Payment History Integration Report

## Implementation

- Added a read-only customer payment history at `/payments/history`, linked from Profile as **Lịch sử thanh toán**.
- The screen uses the shared authenticated Dio client and calls `GET /payments` with only `page`, `limit`, `sortBy=createdAt`, and `sortOrder=desc`. It does not send `customerId`; the API is expected to scope records to the authenticated caller.
- Parses the documented `data.items` and `data.pagination` envelope and supports refresh, client filters, empty/error states, and deduplicated load-more.
- Cards show Vietnamese purpose/status/method labels, backend amount, facility name, payment code, and backend paid/created time. Filters apply only to loaded pages; the screen discloses that when additional pages remain.
- History opens `/payments/{id}/view`, which uses `GET /payments/{id}` only. Related reservation/contract links are offered only for valid ObjectId-shaped values and are validated against the fetched payment. No payment creation, confirmation, cancellation, or polling is triggered from history.
- The detail model now accepts optional response fields including overpaid amount, confirmation, proof URL, facility, cancellation information, and note. Missing timestamps no longer make DTO parsing fail. A proof action appears only for a valid HTTP(S) URL, and payment detail timestamps are rendered in Asia/Ho_Chi_Minh time.
- History state is invalidated on login, registration, and logout to prevent cross-session data reuse.

## API contract and authorization notes

The existing API re-audit documents `GET /payments` as the own-payment history endpoint and records the pagination and filter contract. This implementation relies on backend session scoping and intentionally supplies no customer identifier. The re-audit also records unresolved backend authorization/TODO concerns. This client change does not resolve or bypass those concerns. No live authenticated API request was made during this implementation, so current production authorization and response compatibility remain **NOT VERIFIED**.

## Files changed

- `apps/flutter_mobile/lib/features/payments/data/models/payment.dart`
- `apps/flutter_mobile/lib/features/payments/data/repositories/payment_repository.dart`
- `apps/flutter_mobile/lib/features/payments/application/payment_history_provider.dart`
- `apps/flutter_mobile/lib/features/payments/presentation/screens/payment_history_screen.dart`
- `apps/flutter_mobile/lib/features/payments/presentation/screens/payment_screen.dart`
- `apps/flutter_mobile/lib/app/router.dart`
- `apps/flutter_mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `apps/flutter_mobile/lib/features/auth/application/auth_controller.dart`
- `apps/flutter_mobile/test/payment_history_test.dart`

## Verification

- Automated coverage added for GET method/path/query and omission of `customerId`, extended response parsing, nullable timestamps, and rendering of Vietnamese history card content.
- `flutter analyze --no-pub`: passed, no issues found.
- `flutter test --no-pub -r compact`: passed, all 85 tests.
- `flutter build apk --debug --no-pub`: passed; output at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed. Git emitted only its standard LF-to-CRLF working-copy notices.
- No production payment or reservation mutation was performed.
- No Android screenshot is included; the emulator was not launched as part of this implementation turn.

## Remaining blockers and limitations

- Customer role authorization for payment list/detail remains dependent on the backend's enforcement. The existing API audit identifies controller authorization TODOs; do not consider this production-ready until backend owners verify authenticated customer ownership enforcement.
- The exact live response envelope, populated facility/confirmation fields, and proof URL accessibility have not been checked against production in this run.
- Status and purpose filters are client-side over the pages currently loaded, not server-side full-history filters.
