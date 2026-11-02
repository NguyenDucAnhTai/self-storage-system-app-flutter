# Phase 4 — Facility Amenity Selection

## Result

Implemented amenity discovery/filtering in Explore, live facility amenity cards in Facility Detail, and optional amenity selection in Reservation Create. Existing reservation guards remain intact. The selected request format matches the Backend schema, and no client-side reservation total is calculated.

## Endpoint checklist

| Method / path | Contract / permission evidence | Flutter status | Verification |
|---|---|---|---|
| GET `/amenities?page=&limit=&status=active&sortBy=name` | Backend amenity query supports `status`, pagination, and `sortBy=name`; read endpoint is public in controller. | DONE | DTO parse and exact query tested. Loads up to 100 active amenity rows. |
| GET `/facilities/search-by-amenity?amenityIds=id,id&matchAll=true|false&page=&limit=&search=&city=&sortBy=&sortOrder=` | Query schema requires comma-separated ObjectIds; `matchAll` defaults true; service matches active offerings and returns active facilities. Public read endpoint. | DONE | Mock verifies path, CSV IDs, `matchAll`, search, and that unsupported `status` is omitted. Existing facility search remains `/facilities` when no amenity filter is selected. |
| GET `/facility-amenity-offerings/facility/{facilityId}/available` | Response is active offerings with populated amenity, server price/billing unit, and computed `availableQuantity` for physical amenity inventory. Public read endpoint; service verifies active facility. | DONE | Mock validates response parsing and quantity; Facility Detail and Reservation Create consume offerings for the selected facility. |
| GET `/facility-amenity-offerings/facility/{facilityId}/amenity/{amenityId}` | Public single-offering lookup. | NOT USED | The bulk available-offerings endpoint returns all cards and avoids one request per amenity; no customer flow currently needs the individual lookup. |
| GET `/facilities?page=&limit=&search=&city=&status=active` | Existing public facility query. | DONE | Existing Explore search retained for no-amenity mode. |
| GET `/facilities/{id}/public-detail` | Existing public facility detail with unit-type offerings. | DONE | Existing `FacilityRepository`/Facility Detail flow retained; amenity reads remain separate endpoint data. |
| POST `/reservations` body `amenities: [{facilityAmenityOfferingId, quantity}]` | Schema requires ObjectId offering and integer quantity >=1. Backend service atomically reserves physical amenity quantity and computes amenity costs; amenities are billed periodically. | DONE | Mock verifies selected offering ID, integer quantity, empty selection remains `[]`, duplicate/invalid quantity rejected before POST. No production POST. |

## Implementation notes

- Added typed `Amenity`, `FacilityAmenityOffering` and `AmenityRepository` parsing.
- Explore offers a bottom-sheet amenity filter with multi-select, clear, and match-all / match-any semantics.
- Facility Detail displays server name, description, price, billing unit, notes and availability; unknown enums are not shown raw.
- Reservation Create offers selectable available offerings, shows Backend unit price only, caps physical quantity by returned availability, disables zero-stock options and sends selected IDs/quantities. The Backend remains authoritative for concurrent availability and totals.
- No offering price is presented as the reservation total.

## Backend source concern

The reservation service verifies that each selected amenity offering exists and reserves physical quantity atomically. In the inspected source it does not visibly compare each offering's `facilityId` with the reservation's `facilityId`. Flutter only submits offering IDs loaded from the selected facility, but the relationship should also be enforced by Backend. No Backend changes were made.

## Files

- `apps/flutter_mobile/lib/features/amenities/amenity_repository.dart`
- `apps/flutter_mobile/lib/features/explore/data/repositories/facility_repository.dart`
- `apps/flutter_mobile/lib/features/explore/presentation/screens/explore_screen.dart`
- `apps/flutter_mobile/lib/features/explore/presentation/screens/facility_detail_screen.dart`
- `apps/flutter_mobile/lib/features/reservations/data/repositories/reservation_repository.dart`
- `apps/flutter_mobile/lib/features/reservations/presentation/screens/reservation_create_screen.dart`
- `apps/flutter_mobile/lib/app/router.dart`
- `apps/flutter_mobile/test/phase4_amenities_test.dart`
- `apps/flutter_mobile/test/stitch_screens_test.dart` (mock override signature updated)

## Verification

- `flutter analyze --no-pub` — passed, no issues.
- `flutter test --no-pub` — passed, 107 tests in the final four-phase run.
- `flutter build apk --debug --no-pub` — passed (`apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`).
- `git diff --check` — run after reports; see final summary.
- Tests use mocked adapters. No production reads or writes were run for this phase.
- Android emulator screenshots/visual QA were not captured.

## Remaining blockers

- Live API compatibility and current amenity availability are unverified.
- Backend should verify amenity-offering/facility relationship on reservation creation.
- Client quantity limits can become stale; atomic Backend reservation is authoritative.
