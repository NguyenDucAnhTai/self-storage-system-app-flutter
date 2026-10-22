# Real Backend Test Checklist

**Status: PARTIAL.** Render production public GET endpoints were checked on 2026-10-22. No test credentials or approved write-capable test environment were available. Do not create production reservations or initiate real transfers.

## Configure a permitted test environment

1. Prefer a non-production backend and its required dependencies using the backend team's test-environment instructions. The production base URL is `https://self-storage-system-be.onrender.com`; production verification remains read-only unless a separately approved process authorizes a test.
2. Confirm that the backend has a test customer, active facility, active unit offering, available physical storage unit, and check-in time slot. Ask the backend owner for seeded test records; do not create them in production.
3. Start Android Emulator and confirm it has network access to the HTTPS Render or approved staging host.
4. Run from `apps/flutter_mobile`; default configuration targets Render production. For a permitted staging target, override explicitly:

   ```bash
   flutter run --dart-define=API_BASE_URL=https://<approved-staging-host>
   ```

   Use HTTPS for remote environments. Local HTTP is allowed only in Android debug builds and requires an explicit override.

## E2E sequence and evidence

- [ ] Login with the provided test customer; verify restart restores the session and logout clears it.
- [ ] Search/filter facilities; open facility detail and confirm offering/pricing data.
- [ ] Select an available physical unit, date, and time slot; create the reservation once.
- [ ] Verify the created reservation's `storageUnitId`, `checkInDate`, `checkInTimeSlot`, and server status in the app and backend test logs.
- [ ] Open the backend-created deposit payment session and confirm the returned SePay QR/instructions are displayed without locally fabricated data.
- [ ] In a non-monetary approved sandbox, follow the payment provider's test flow or wait for the backend to report its state. Do not claim payment success until the backend reports `paid`.
- [ ] Verify payment polling updates and stops at a terminal state; verify resulting reservation/contract state from backend responses.
- [ ] Open the customer's contract, review terms, perform the backend customer-acceptance action only if the test account and workflow authorize it, and verify the returned contract status.
- [ ] Check cancellation and renewal only with test records and permitted states; record backend responses.
- [ ] Repeat access checks with a second authorized test account if available to validate customer data isolation.

Record environment, build, test account identifiers (never passwords/tokens), timestamps, request IDs, and observed backend state transitions. A UI path alone does not establish that authorization or webhooks are secure.
