# Home active storage count fix

## Root cause and source fields

The Home metric previously labeled `Kho` displayed `CustomerInventorySummary.totalStorageUnits` from `GET /customer-inventories/summary`. Read-only inspection of Backend source confirms this field is produced by `inventoryRepository.countDistinctStorageUnits(customerId)`. That query counts distinct `storageUnitId` values in customer inventory rows with `quantity > 0` and `deleted != true`—it counts physical locations currently holding managed customer items, not private Self Storage rooms rented under contracts. The same summary separately supplies `totalSkus`, `totalQuantity`, and `totalActiveContracts`.

The Customer contract list is the appropriate existing source for rented rooms: `GET /contracts?page={page}&limit=20`. `ContractService.getContracts` scopes a Customer query with `customerId = callerId` before reading records. Flutter now loads all pages from that same endpoint for the dashboard. The `Phòng kho đang thuê` count includes distinct valid `storageUnitId` values only from contracts whose `status` is `active` and whose `rentalTargetType` is `storage_unit` (or is absent while a valid unit ID is present). Draft, cancelled, completed, overdue, rack-target, missing-ID, and duplicate-unit rows do not increase the count.

The API spec/controller currently has TODO/commented security annotations, so Backend service-level customer scoping is source-verified but live authorization middleware was not tested. The dashboard uses the existing authenticated Dio and does not send a caller-supplied customer ID.

## UI and data behavior

- `Phòng kho đang thuê`: derived from Customer-owned active storage-unit contracts, deduplicated by unit ID.
- `Hợp đồng đang dùng`: remains sourced from `totalActiveContracts` in inventory summary.
- `Vị trí lưu hàng`: renamed from `Kho`; retains `totalStorageUnits` inventory semantics.
- SKU count, stored quantity, category data and recent movements remain sourced from Customer Inventory Summary.
- A contract API load/error shows a loading marker or `—` plus a clear error; a successful empty contract list displays `0`. Inventory summary errors remain independent.
- Active room cards show facility, unit number, floor/zone when present, active state and rental period. Tapping a card opens that exact contract's existing detail route.
- Home fetches providers when opened, refreshes on pull-to-refresh and app foreground resume, and invalidates relevant data after returning from a contract detail/list. Existing auth login/logout invalidation is retained and regression-tested to prevent account data reuse.
- The earlier Contract Detail check-in behavior remains intact: `actualCheckInDate` is displayed as recorded; future dates are not described as completed physical handover.

## Files changed for this task

- `apps/flutter_mobile/lib/features/dashboard/data/active_rental_summary.dart` — active storage-unit filtering and deduplicated unit count.
- `apps/flutter_mobile/lib/features/dashboard/application/dashboard_providers.dart` — paginated contract list and derived active rental provider.
- `apps/flutter_mobile/lib/features/dashboard/presentation/customer_dashboard_screen.dart` — separate rented-room/inventory metrics, active unit cards, navigation and refresh behavior.
- `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart` — paginated `listAll()` for dashboard completeness.
- `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart` — refresh dashboard/list after returning from contract detail.
- `apps/flutter_mobile/lib/features/contracts/presentation/contract_detail_screen.dart` and `contract_detail_route_screen.dart` — notify dashboard on contract refresh.
- `apps/flutter_mobile/test/dashboard_test.dart` — unique count, status/target filtering, inventory-empty plus active rental, loading/error/zero distinction, pull refresh and logout/account-switch regression tests.

The workspace contained existing uncommitted work from earlier tasks; it was preserved. No Backend files, reservation/contract/payment records, or production APIs were modified or written.

## Verification

Executed in `apps/flutter_mobile/`:

- `flutter analyze --no-pub` — passed, no issues.
- `flutter test --no-pub` — passed, all 82 tests.
- `flutter build apk --debug --no-pub` — passed; APK at `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — passed.

No Android screenshot was captured because no emulator/device was launched during this source and automated-test task.

## Remaining concerns

- No live authenticated request was made. Production Customer authorization and current contract-list response compatibility remain runtime-unverified.
- The contract list may contain many pages; the dashboard follows the Backend `pagination.totalPages` response and currently requests 20 rows per page, matching the existing ContractRepository page size.
- `totalActiveContracts` is preserved from inventory summary as a separate contract metric; it is not used to infer a rented-unit count.
