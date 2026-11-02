# First-period rental payment integration

## Scope and safety

Flutter Customer now reads a first-period rental payment that already exists for a contract. Opening a manager-created payment uses GET requests only. No Backend files or production records were changed, and no production credentials or live API calls were used. Tests use synthetic IDs and mocked Dio responses.

## API discovery and payment ID resolution

The Customer discovery call is:

```http
GET /payments?contractId={contractId}&purpose=rent_first_period&page={page}&limit=100&sortBy=createdAt&sortOrder=desc
```

The Flutter request uses the application's existing authenticated Dio instance; it does not pass `customerId`. `PaymentRepository.listFirstPeriodForContract` reads the paginated `data.items` response and independently retains records whose `contractId` equals the opened contract and whose `purpose` is `rent_first_period`.

Contract Detail selects an unexpired `pending` or `partially_paid` record first, followed by `paid`, `expired`, then `cancelled`, preferring most recently updated within a state. It does not infer that no payment exists from a null `firstPeriodPaymentId`. If the list is empty and the contract exposes a valid `firstPeriodPaymentId`, the screen makes `GET /payments/{id}` and validates the returned contract and purpose. Otherwise it shows a distinct no-request state; list errors show a retryable error state.

The read-only route is `/payments/{paymentId}/view?contractId={contractId}`. It loads exactly that payment with `GET /payments/{id}`, validates contract/purpose when the contract ID is supplied, and refreshes by GET. It does not create a payment session or show a recreate action. Backend QR and bank details are displayed as returned; QR is withheld for paid, expired, cancelled, and expired-by-time payments. Payment success is not simulated.

## UI and navigation

Contract Detail includes a `Thanh toán tiền thuê kỳ đầu` card showing Backend amount, status, payment code, available expiry/confirmation data, and `Xem QR thanh toán` only for a current pending or partially paid payment. The contract progress timeline incorporates first-period payment state. Notifications can open a payment read-only route when valid `paymentId` metadata is present, or the contract detail when valid `contractId` metadata is present. IDs are checked as 24-character hexadecimal ObjectIds. Existing reservation notification behavior remains available for reservation IDs.

No screenshots were captured: no Android emulator/device session was run for this task. Widget tests cover rendered states and interactions.

## Files changed for this integration

- `apps/flutter_mobile/lib/features/payments/data/models/payment.dart` — contract linkage and payment confirmation timestamps.
- `apps/flutter_mobile/lib/features/payments/data/repositories/payment_repository.dart` — paginated contract/purpose discovery.
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart` — discovery, status selection, refresh, read states and payment card.
- `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart` — passes the shared Dio-backed repository and opens the read-only route.
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_route_screen.dart` — standalone contract deep link loads contract and payment details.
- `apps/flutter_mobile/lib/app/router.dart` — contract detail and existing-payment routes plus auth guard.
- `apps/flutter_mobile/lib/features/payments/presentation/screens/payment_screen.dart` — GET-only existing-payment mode.
- `apps/flutter_mobile/lib/features/notifications/presentation/notifications_screen.dart` and `notification_bell.dart` — validated contract/payment notification navigation.
- `apps/flutter_mobile/test/contract_customer_journey_test.dart` — mocked discovery, status, linkage, retry, refresh, GET-only, and no-POST coverage.

Other existing uncommitted contract journey UI work was present and preserved.

## Verification

Executed in `apps/flutter_mobile/`:

- `flutter analyze --no-pub` — passed, no issues.
- `flutter test --no-pub` — passed, all 72 tests.
- `flutter build apk --debug --no-pub` — passed; generated `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — see final repository check before delivery.

The integration tests verify a manager-created pending payment appears under its matching contract and opens its exact ID, existing-payment view sends GET only, wrong-contract linkage is rejected, no-payment differs from error, retry/refresh work, and paid/expired/cancelled states do not offer a QR or create action. Test adapter also asserts there are no POSTs in these flows.

## Backend and runtime limitations

The checked-in audit and supplied Backend source indicate `GET /payments` has `contractId` and `purpose` filters, and its service scopes a non-staff caller by the caller ID. The source also contains controller TODOs/commented security decorators; an API schema or service-level filter is not proof that production authorization middleware permits this Customer flow. `GET /payments/{id}` has a service-level customer ownership check, but live enforcement is likewise unverified. Contract response `firstPeriodPaymentId` is populated after the payment is paid in the inspected source, so it cannot discover a pending row by itself.

The public Swagger was not reachable during the prior audit, no authenticated production GET was performed, and no device session was used. Therefore production Customer authorization, response compatibility against current live data, and display of the referenced real case remain NOT VERIFIED. If production rejects the list call for Customer role, Backend must provide/authorize a Customer-readable discovery path; Flutter does not bypass that boundary.
