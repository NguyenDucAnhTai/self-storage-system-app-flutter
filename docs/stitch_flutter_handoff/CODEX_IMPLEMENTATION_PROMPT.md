# CODEX TASK — Apply 4 Stitch designs to existing Flutter Customer app (UI-first, preserve business logic)

## Goal and source of truth

Implement the visual/UI patterns from **four exported Stitch HTML reference files** in the existing Flutter Customer application, **not** a WebView/HTML embed and **not** a rewrite of the app. Use native Flutter widgets and the existing Material 3 theme, Dio, Riverpod and GoRouter architecture.

Design references located in this folder:
- `A2_home_dashboard.html` — Home Dashboard (`/home`)
- `A3_explore.html` — Explore (`/explore`)
- `A4_reservation_create.html` — Reservation Create (`/reservations/create`)
- `A6_payment_vietqr.html` — Payment (`/payments/:id`)

**Data and behavior authority:** Existing Flutter source and tests, `docs/flutter/API-RE-AUDIT-2026-10-30.md`, `docs/flutter/FLUTTER-CUSTOMER-GAP-MATRIX.md`, `docs/flutter/STITCH-SCREEN-BRIEF.md`, and the current production OpenAPI (for read-only contract verification only). Treat all HTML copy, images, fictional addresses, prices, dates, timers, QR and JavaScript as *illustrative only*. Backend responses and validated app models have precedence over examples in HTML. Do not assume the ZIP source is definitely the deployed runtime.

## Preconditions

1. From workspace root, inspect `git status --short` and read local `AGENTS.md`/project guidance if present. Preserve **all** uncommitted changes and do not reset/clean/overwrite unrelated files. Inspect current Flutter source before editing; resolve actual file names and routes, do not assume initial state.
2. Read `apps/flutter_mobile/lib/app/router.dart`, existing theme, shared UI widgets, affected screen implementation, repositories/providers/models and relevant existing tests.
3. Produce a brief in-terminal map of reference HTML → actual screen files, design patterns to port, and elements that must be rejected because they have no reliable API support.
4. Work in `apps/flutter_mobile` only (plus documentation/test changes under `docs/flutter` if needed). Do not change Backend, Swagger, TypeScript shared types or unrelated apps. Don't execute production POST/PATCH/PUT/DELETE or privileged GET; don't make real bank payments. Do not create new auth client/repositories if existing ones work.

## Scope and sequence

Use **four separately reviewable phases**, beginning with Home and Explore, then Reservation Create, then Payment. Preserve existing behavior at every phase. If the work exceeds one session, finish cleanly at phase boundaries and report remainder. No blanket redesign of other app routes.

### Phase 1: Home `/home`

Port Stitch visual direction: green forest/emerald palette, welcoming header, navigation hierarchy, storage summary, pending booking card, quick actions, actual recent movements, API-backed facility highlight, four-tab bottom bar handled by existing app shell. Adapt to actual screen width, keyboard/safe area and 200% text scaling.

**Do NOT port:** `Phương Thảo` as a fixed user name; `Unit A-204`/`RES-8921` and other fake entries; fake recent activity, temperature, Bluetooth/QR door unlock or `#SEC-...` token; wallet-payment claim; fabricated facility price/recommendations. There is **no verified customer door-access/key API** in the audited OpenAPI. If current app does not already have a backend-supported door-access flow, omit the card/action completely. Do not imitate screenshot-only fake data.

Use existing dashboard providers for `GET /customer-inventories/summary`, `GET /reservations`, `GET /contracts`, `GET /facilities`, `GET /notifications/unread-count`. Keep independent loading/error/empty and retry per section, actual status mapping and cross-account cache invalidation. Quick actions must navigate only to real routes. If a proposed module lacks a route, omit or visibly disable rather than make a dead button.

### Phase 2: Explore `/explore`

Port clean search, facility card hierarchy, image and typography, filter design only for fields currently supported by the real repository and response, and bottom tab style via existing shell. Use server-returned facility names, images, addresses, pricing and available counts. Preserve search queries, pagination, loading, no-result, timeout and retry.

**Do NOT port:** the three fictional named facilities; manufactured distances (`2.1km`, etc.) without a verified user location and geocoding/distance source; free insurance, 100% protection / VND 200M guarantees, first-month -20% discount, 24/7 claims, camera AI, NFC/Bluetooth, 'recommended' badges, climate claims or facilities that aren't in the API. Do not turn mock `href="#"` actions into active dead controls. Map, nearby and voice-search UI only when working capabilities/permissions exist; otherwise omit. Amenity search is a potential P1 extension, not automatically implemented by styling work.

### Phase 3: Reservation Create `/reservations/create`

Port the multi-step information hierarchy where this can be done without changing existing route/flow: facility summary, available physical unit choices, check-in calendar, available time-slot chips, rental duration and review/CTA. Maintain navigation parameters and existing repository/provider integration.

**Must remain true:**
- physical unit list from `GET /storage-units/facility/{facilityId}/available` (including optional unitTypeId) and time slots from `GET /facility-time-slots/facility/{facilityId}/available?date=YYYY-MM-DD` are separate requests;
- calendar date is a local date-only `YYYY-MM-DD`, not UTC-converted;
- submit only with an API-returned `storageUnitId`, an API-returned valid time slot `slotName` with `isAvailable == true` and `availableCapacity > 0`, valid date and rental duration, no concurrent request/submission;
- date change re-fetches slots; stale responses do not override a newer date selection; preserve all `400/401/403/404/409` and network states; avoid duplicate create;
- only POST `/reservations` on deliberate final customer confirmation; server response determines next navigation.

**Do NOT port:** fixed booking date `2025-05-15`, selectable fictitious time slots, fake available units, fake rental prices or totals, generic 'insurance is free', automatic 15-minute lock before reservation creation, stale `08/2025` occupied date or purported guaranteed customer amenities. If pricing details are not returned for the current selection, display no invented total and use truthful informative copy. The Stitch HTML's JS `selectedUnit && selectedSlot` validity check is **insufficient**; preserve existing Flutter validation.

### Phase 4: VietQR Payment `/payments/:id`

Port content hierarchy: amount, reservation reference, backend QR, receiving bank/account holder/account number, transfer content, expiration and payment status CTA. Adapt for loading, no QR, `pending`, `partially_paid`, `paid`, `expired`, `cancelled`, error/timeout, app pause/resume.

**Critical: DO NOT port the SVG QR pattern. It is decorative and may not scan.** Render only `qrUrl` from a valid `POST /payments` response, with a secure placeholder/error when absent. Bank info, amount, reference and transfer note must come from backend `bankInfo`/payment model, NEVER from the hard-coded Techcombank name, account number, company name, 'SS RES8921' or `1.450.000₫`. Avoid locally generated fake 'paid' state. `GET /payments/{id}` polling is authoritative; only `status == paid` is success, never assume confirmation just because bank app opened.

Use server expiry/hold fields if present to calculate countdown, and handle stale/unknown expiry conservatively. Do NOT hard-code 15 minutes or claim 'auto cancel after 15 min'. Do not promise '30 seconds to 2 minutes' confirmation, automatic storage activation, or '256-bit SSL Banking' unless backend policy expressly supports it. The HTML `setTimeout` status check is **not** a payment check: use repository/state tracker. Download/copy actions may only act on actual server-provided data and must work; otherwise omit. Do not log/store payment QR or sensitive account details beyond current app policy. Payment success does not imply contract or storage active.

## Shared design and accessibility

- Reuse/extend `lib/core/widgets/app_ui.dart` and existing Material 3 theme rather than duplicating widget classes or creating multiple incompatible design systems.
- Use consistent forest green (#164A3C) / darker green (#003327) and mint, while keeping readable contrast on light backgrounds. Do not blindly copy Tailwind CSS into Flutter.
- Keep tab bar and GoRouter navigation consistent and preserve auth gating/deep links.
- Use real API data and localized VND/date display. No HTML-only fake JS behaviors or externally hosted demo avatar/image assets. API-sourced facility images can use the current loading/failure placeholder logic.
- Buttons and tiles must have working navigation/actions, or intentionally be omitted/disabled with clear reasons. Avoid inaccessible icon-only hit targets; provide semantics and sufficient size.
- Support small Android displays, system navigation SafeArea, scroll and keyboard avoidance. Responsive tests/screenshots if emulator is available.
- No new packages unless strictly justified and approved by existing project policy. Respect project formatting conventions.

## Verification

At each phase: inspect diff and maintain behavior. Add/update widget and provider-mock tests for UI loading/empty/error/content; regression tests for reservation slot/date/submit guards and payment paid-only truth. Confirm uncommitted work intact. After changes run where environment permits:

```sh
cd apps/flutter_mobile
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Then `git diff --check`. If build/test cannot run, report the exact blocker, not PASS. Do not claim live E2E from mocked tests.

## Required final report

1. Changed/added files with short purpose.
2. Which HTML visual elements were implemented, adapted, or **rejected due to missing API/business contract** for each of the four screens.
3. API/provider/route preservation evidence; any intentional behavior changes or unresolved blockers.
4. Commands and exact verification results.
5. A focused checklist of screens to review next on Android emulator; clarify what remains not verified in production.

**Do not implement the proposed P1/P2 screens in this task.** The current scope is strictly visual integration of A2, A3, A4 and A6, preserving production-source-of-truth data.
