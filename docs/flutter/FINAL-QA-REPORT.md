# Flutter Mobile Final QA Report

> This final QA snapshot predates the Render deployment details. See [RENDER-PRODUCTION-INTEGRATION.md](RENDER-PRODUCTION-INTEGRATION.md) for the current production API verification.

**Date:** 2026-10-23
**Overall:** PARTIAL — source quality and local checks are ready for a permitted backend test environment; runtime E2E and device validation remain NOT VERIFIED. Reservation availability on the reported production date is confirmed empty; the Flutter screen now shows this separately from request failures.

## Results

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Authentication and token lifecycle | PARTIAL | Source and automated tests cover login token persistence, session restoration, expired-session clearing, refresh/retry. Real backend credentials unavailable. |
| Router/navigation | PARTIAL | Source guards reservation/payment/profile/contracts/notifications. Automated router interaction coverage remains a gap. |
| Shared networking/errors | PARTIAL | Source uses a shared Dio client and normalized errors; tests cover refresh and backend error parsing. |
| Facility search/detail | PARTIAL | Source contract and filters reviewed; automated test covers listing filters/empty response. Runtime detail/search error flow not exercised against backend. |
| Reservation lifecycle | PARTIAL | Payload test verifies physical `storageUnitId`, date-only `checkInDate`, and `checkInTimeSlot`; local required field/past-date checks tested. The reported production facility/date returned a valid empty slots array; the screen now distinguishes this from HTTP, network, and parsing failures. Conflict/list/detail/cancel runtime behavior remains unverified. |
| Payment lifecycle | PARTIAL | Backend QR/session parsing, terminal statuses, timeout, and cancellation are tested. SePay sandbox and duplicate concurrent stream behavior need runtime verification. |
| Facility detail, profile, notifications, contracts | PARTIAL | Source contracts reviewed; dedicated runtime responses and device behavior remain unverified. |
| Contracts, profile, notifications | PARTIAL | API calls reviewed against source. Contract status/renewal and account data isolation remain backend/runtime blocked. |
| Responsive UI, keyboard, back navigation, lifecycle, QR rendering | NOT VERIFIED | No emulator or physical Android device session was available in this QA run. |
| Backend authorization | BLOCKED | Reservation/payment/contract backend authorization TODOs remain unresolved and were not changed. |
| Support request flow | BLOCKED | Backend endpoint absent. |
| Real E2E | NOT VERIFIED | No approved test backend, credentials, or seeded test data supplied. No reservation/payment was created. |

## Automated coverage added

Added repository/client contract tests for authentication token storage and restoration, expired-session clearing, 401 refresh/retry, facility filters/empty results, reservation payload and validation, slot response parsing (valid, empty, malformed, 401, 500, timeout), date refresh, submit validation, payment session/QR parsing, timeout/cancellation, API errors, and terminal payment states. Total: 20 tests pass.

## Reservation availability bug report (2026-10-23)

- The reported unit is `LK-301` (facility `660000000000000000000003`, storage unit `663000000000000000000006`, unit type `661000000000000000000002`); the production unit availability GET returned it with status `available`.
- The same production facility/date request used by Flutter, `GET /facility-time-slots/facility/660000000000000000000003/available?date=2026-10-28`, returned HTTP 200 with `{ "data": [] }`. This is confirmed empty backend availability for the reported date, not a frontend-filtered slot.
- Public OpenAPI documents this as a facility/date GET returning an array of slot records. Its fields (`id`, `slotName`, `startTime`, `endTime`, `availableCapacity`, `isAvailable`) match the Flutter parser. The successful GET required no authorization header; authenticated and protected APIs still require a valid session.
- Root UI bug: the catch path stored a generic error while the empty `_slots` list still triggered “No time slots are available on this date.” A failed request could therefore masquerade as a valid empty response. The screen now displays a specific error and retry action, keeps no-slots for a successful empty response only, and ignores stale responses from earlier date requests.
- Physical unit is not part of the slot API contract, so changing LK-301 does not trigger a slot request. The facility/date slot refresh occurs on every selected date; the unit list is separately fetched by facility and unit type.
- No reservation or payment request was made. Production has no available check-in slot on 2026-10-28 for this facility, so reservation creation remains blocked by backend availability data.

These tests use a mocked Dio HTTP adapter and secure-storage test backing. They verify client behavior and request shapes, not a live server or payment provider.

## Bugs fixed during QA

- Reservation repository now rejects missing unit-offering identifiers and past check-in dates locally.
- Payment status polling now emits a typed timeout event when its configured attempt bound is reached instead of silently closing as if complete.

## Final commands

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS — dependencies resolved; 9 packages have newer versions outside current constraints. |
| `flutter analyze --no-pub` | PASS — no issues found. |
| `flutter test` | PASS — all 20 tests passed. |
| `flutter build apk --debug --no-pub` | PASS — `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| `git diff --check` | PASS — no whitespace errors; Git printed an informational LF-to-CRLF notice for README. |

## Handoff

See [REAL-BACKEND-TEST-CHECKLIST.md](REAL-BACKEND-TEST-CHECKLIST.md), [SECURITY-REVIEW.md](SECURITY-REVIEW.md), and [BACKEND-BLOCKERS.md](BACKEND-BLOCKERS.md). Use the checklist with an approved non-production environment before calling E2E complete.
