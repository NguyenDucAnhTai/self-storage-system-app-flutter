# Contract timeline API mapping fix

## Root cause

The Customer Contract Detail implementation has no typed Contract model/deserializer and no Riverpod Contract provider. `ContractRepository.detail()` performs `GET /contracts/{id}`, unwraps only the response `data` object, and returns its fields unchanged as `Map<String, dynamic>`. The detail route and Contract Detail refresh both use this method, so the wrapper and refresh flow were not dropping the supplied values.

The timeline read different keys from the API response:

- Deposit state was inferred from `depositPaid`, payment-status aliases, or nested payment objects. It did not treat `depositPaidAt` as the authoritative paid marker, nor did it show `depositAmount`.
- Check-in only searched `actualCheckInAt`, `checkedInAt`, and `checkInCompletedAt`; the response field is `actualCheckInDate`.
- Signature and first-period payment timestamps were already read, but the UI showed date-only values and therefore lost the local time.
- Active state also unnecessarily required both signature booleans in addition to `status == active`.

## Field mapping and behavior

| API field | Customer UI behavior |
|---|---|
| `depositPaidAt` | Marks deposit paid; shows timestamp in Vietnam time (UTC+7). |
| `depositAmount` | Shows localized VND amount when the paid timestamp exists. |
| `depositPaymentId` | Preserved by the repository; not exposed as an actionable payment link because the current task does not establish a supported deposit lookup flow. |
| `customerSigned`, `customerSignedAt` | Shows signature state and localized timestamp. |
| `firstPeriodPaidAt`, `firstPeriodPaymentId` | Contract payment timestamp takes precedence over a stale payment-list status; shows localized timestamp. Existing payment lookup remains unchanged. |
| `staffSigned`, `staffSignedAt` | Shows staff signature state and localized timestamp, separately from physical check-in. |
| `actualCheckInDate` | Shows server-recorded check-in time in Vietnam time. A future timestamp is described as a recorded upcoming check-in time and does not mark physical handover complete. |
| `status == active` | Shows active contract state directly from the Backend status. |
| `storageUnit.status` | Maps known values such as `occupied` to Vietnamese (`Đang có khách thuê`); no raw enum is displayed. |

Times are rendered as `HH:mm dd/MM/yyyy` in Asia/Ho_Chi_Minh (UTC+7), independent of the test host timezone. Missing timestamps remain explicitly unavailable; no time is derived from contract status or another field.

## UI result

Before: a contract with `depositPaidAt` and `actualCheckInDate` could show “Chưa có dữ liệu tiền cọc từ máy chủ” and “Chưa có xác nhận nhận kho thực tế từ máy chủ.”

After: the deposit step shows its paid state, amount, and local payment time. Signature and rent steps show their local confirmation times. The scheduled future check-in is shown as a Backend-recorded time without claiming that physical handover already happened. Active status and occupied unit status appear in Vietnamese.

The existing vertical timeline remains compact with consistent completion, pending, and missing-data icons. Unknown contract/payment enum values no longer appear raw.

## Files changed

- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart` — authoritative field mapping, Vietnam time formatting, future check-in semantics, active-state condition, and localized unit state.
- `apps/flutter_mobile/test/contract_customer_journey_test.dart` — Backend-shaped contract fixture, API envelope preservation, timestamp/state assertions, null behavior, and refresh regression.

No Backend, reservation, contract, or payment records were changed. No production API writes were made.

## Verification

- `flutter analyze --no-pub` — passed, no issues.
- `flutter test --no-pub` — passed, all 75 tests.
- `flutter build apk --debug --no-pub` — passed; debug APK generated at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — run before delivery.

New regression coverage verifies the response envelope retains the timestamp fields, the supplied active-contract response shape renders the expected VND amount and UTC-to-UTC+7 times, a future `actualCheckInDate` is not represented as completed physical handover, missing values remain unavailable, and refresh replaces stale values with the latest GET response.

No Android screenshot is included because an emulator/device was not launched for this source/test/build task.

## Remaining Backend concerns

No Backend contract changes are indicated by the supplied response shape. Production response compatibility and Customer authorization were not re-verified with an authenticated live API request in this task. The UI depends on the existing `GET /contracts/{id}` response continuing to expose the listed fields. When `firstPeriodPaidAt` is present, it takes precedence over a stale payment-list status in both the timeline and first-period payment card, so an already-paid contract does not keep showing a pending state or actionable QR.

