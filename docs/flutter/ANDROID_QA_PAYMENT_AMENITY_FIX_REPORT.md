# Android QA Fix Report: Payment Filters, Amenity Search, and Incident Blocker

**Date:** 2026-11-01  
**Scope:** Flutter customer app. Static Backend contract inspection and mocked Flutter verification. No live API calls, uploads, incidents, reservations, or payments were made.

## Summary

- Payment history filter chips now have explicit foreground, selected, unselected, checkmark, border, and background colors. The selected state uses white text/checkmark on the primary emerald color; unselected chips use dark text on white.
- Facility amenity search retains and exposes pagination, carries the current amenity/search/match mode into subsequent pages, ignores late results when newer searches are active, distinguishes error and empty states, and displays selected amenity names and match mode.
- A 320px reservation layout test exposed horizontal overflow in the amenity-loading row. Its text is now constrained to the remaining card width.
- Profile menu copy and app date-picker localization now use Vietnamese. The notification navigation assertion was updated to the localized “Thông báo” label.
- Incident creation remains blocked pending the Backend security and evidence-ownership contract described in [INCIDENT_EVIDENCE_UPLOAD_BACKEND_HANDOFF.md](INCIDENT_EVIDENCE_UPLOAD_BACKEND_HANDOFF.md).

## Evidence and test classification

| ID | Feature | Expected result | Actual result | Status | Evidence | Related API | Suggested fix / owner |
|---|---|---|---|---|---|---|---|
| PAY-UI-01 | Payment history filters | Selected and unselected states remain readable and filters combine | Widget test verifies selected/unselected colors and status+purpose filtering | PASS | Mocked Flutter test `test/payment_history_test.dart`; `flutter test` | `GET /payments` (history payload rendered locally) | None; FE fix is in place / FE |
| PAY-UI-02 | Payment filter responsive layout | Filter rows remain usable at narrow phone widths | Widget test at 320/360/390dp reports no framework exception; rows scroll horizontally | PASS | Mocked Flutter test `test/payment_history_test.dart` | None | None / FE |
| AMN-API-01 | Facility amenity search contract | IDs, `matchAll`, text, page, limit, and sorting use backend contract | Static FE serialization test confirms `GET /facilities/search-by-amenity`, CSV `amenityIds`, boolean `matchAll`, search, city, page and sorting; no unsupported `status` field | PASS | Mocked repository test `test/phase4_amenities_test.dart`; source inspection of local Backend schema/service | `GET /facilities/search-by-amenity` | None identified from static contract / FE+BE |
| AMN-API-02 | Search response and pagination | FE reads the response envelope and exposes later pages | `data.items` and pagination flags are parsed; Explore loads and appends the next page with active search/amenity/match filters | PASS | Mocked repository and screen tests in `test/phase4_amenities_test.dart`, `test/explore_amenity_filter_test.dart` | `GET /facilities/search-by-amenity` | None identified from static contract / FE |
| AMN-UI-01 | Apply, match-any, Clear | User selections change request and Clear resets it | Mock verifies selected IDs, `matchAll=false`, page reset, and cleared request | PASS | Mocked Flutter test `test/explore_amenity_filter_test.dart` | `GET /facilities/search-by-amenity` | None / FE |
| AMN-UI-02 | Stale response and pagination filters | Older responses cannot replace new results; next page retains filters | Mocked delayed-response test and page-two assertions pass | PASS | Mocked Flutter test `test/explore_amenity_filter_test.dart` | `GET /facilities/search-by-amenity` | None / FE |
| AMN-UI-03 | Empty/error and mobile amenity picker | Empty results differ from errors; long names fit on mobile | Both states are distinct; long amenity label sheet at 320/360/390dp has no layout exception | PASS | Mocked Flutter test `test/explore_amenity_filter_test.dart` | Facility/amenity read endpoints | None / FE |
| RES-UI-01 | Reservation amenity section narrow layout | Loading and content fit 320/360/390dp | Found and fixed a horizontal overflow in the loading row; availability/disabled option test is clean at all three widths | PASS | Mocked Flutter test `test/phase4_amenities_test.dart` | `GET /facility-amenity-offerings/facility/{facilityId}/available` (mocked) | Fixed by constraining loading text / FE |
| LOC-01 | Date and Profile localization | Customer-facing Profile menu and date picker use Vietnamese | Widget verification confirms Vietnamese date formatting and Profile entries are Vietnamese | PASS | Mocked Flutter test `test/app_locale_test.dart`; full suite | None | Updated stale localized navigation assertion / FE |
| INCIDENT-SEC-01 | Incident evidence signing/creation | Only verified, scoped evidence can be uploaded and submitted | Not safe to enable: local Backend source has commented auth annotations, identity header fallback, no scoped asset registration/ownership verification; FE create remains blocked | BLOCKED | Static source findings documented in handoff; no request attempted | `POST /upload/signature`; `POST /incidents` | Backend must secure principal/roles and define purpose-bound upload + registration/ownership contract / BE |
| LIVE-01 | Live amenity result parity | Isolated Backend returns facility results matching query semantics | Not run: no dedicated isolated test environment/test DB was verified; production/live endpoints were not called | NOT_TESTED | Environment was not used for live API calls | `GET /facilities/search-by-amenity` | Provide isolated Backend and test data / Environment |
| DEVICE-01 | Emulator/device UI verification | Install and inspect app on Android device/emulator | Not run: `adb` is not on PATH and no configured SDK device was found; no AVD was created | NOT_TESTED | Local device/tool availability check | None | Provide existing emulator/device and SDK platform-tools / Environment |

## Automated verification

Commands executed from `apps/flutter_mobile`:

| Command | Result |
|---|---|
| `flutter analyze --no-pub` | PASS — no issues found |
| Focused payment/amenity/locale/support regression tests | PASS — 31 tests |
| `flutter test --no-pub --reporter expanded` | PASS — 116 tests |
| `flutter build apk --debug --no-pub` | PASS — produced `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | PASS — no whitespace errors; Git emitted only LF-to-CRLF working-copy notices |

## Remaining blockers and limits

1. Incident creation must remain blocked until Backend authentication, role authorization, evidence purpose/scope, provider upload constraints, asset registration, ownership checks, and security tests are implemented and reviewed. Details and exact source observations are in the linked handoff.
2. Amenity behavior was verified against mocks and static local Backend source. Live query results were not exercised because an isolated nonproduction environment was not verified.
3. No emulator/device screenshots or manual Android interaction were performed because no accessible `adb` device setup was available.
4. Existing unrelated modifications in the Flutter checkout were preserved; this report does not claim they were introduced by this task.
