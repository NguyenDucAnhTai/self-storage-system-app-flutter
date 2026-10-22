# API Integration

All endpoints below are mounted at the backend root. Successful endpoints return `{success,statusCode,messageCode,message,data}`. The Flutter client base URL is centralized in `AppConfig` and defaults to `https://self-storage-system-be.onrender.com`; `API_BASE_URL` can override it at build/run time.

| Area | Endpoints used | Notes |
| --- | --- | --- |
| Auth | `POST /auth/send-otp`, `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `GET /auth/me`, `POST /auth/forgot-password`, `/auth/reset-password`, `PATCH /auth/change-password` | BE returns access/refresh tokens in `data`; Flutter stores both securely. Refresh is serialized and each request is retried once. |
| Profile | `GET /profile/me`, `PATCH /profile/me` | Profile updates currently expose address editing. |
| Explore | `GET /facilities?status=active&search=&city=&page=&limit=`, `GET /facilities/{id}/public-detail` | Listing filters active facilities; public detail contains facility, unit type offerings/pricing and amenity offerings. |
| Unit availability | `GET /storage-units/facility/{facilityId}/available?unitTypeId=...` | UI filters returned physical units to status `available`. |
| Time slots | `GET /facility-time-slots/facility/{facilityId}/available?date=YYYY-MM-DD` | Reservation sends exact backend `slotName`, not slot ID. |
| Reservation | `POST /reservations`, `GET /reservations`, `GET /reservations/{id}`, `POST /reservations/{id}/cancel` | Creation sends required `facilityId`, physical `storageUnitId`, `checkInDate`, `checkInTimeSlot`, offering ID and rental duration. |
| Payment | `POST /payments`, `GET /payments/{id}` | Deposit session sends `purpose=reservation_deposit`; QR and transfer instructions are only read from backend response. `paid` alone means paid. |
| Contract/storage | `GET /contracts`, `GET /contracts/{id}`, `POST /contracts/{id}/customer-sign`, `POST /contracts/{id}/renew` | Customer acceptance is a BE operation recording terms accepted; no client-side/digital signature is fabricated. Renewal sends a selected new end date. |
| Notifications | `GET /notifications`, `PATCH /notifications/{id}/read`, `PATCH /notifications/read-all` | Read state is changed through backend. |

Contract and reservation/payment APIs contain disabled security decorators/TODO role checks; see BACKEND-BLOCKERS.md.

Production endpoint/schema verification on 2026-10-22 is recorded in [RENDER-PRODUCTION-INTEGRATION.md](RENDER-PRODUCTION-INTEGRATION.md). It uses deployed public OpenAPI and GET responses; live GETs for protected routes returned 401, and OpenAPI security annotations did not match those observed responses.

## API Coverage Audit (2026-10-22)

Status meanings: **SUPPORTED** = source route/schema and Flutter call shape align; **MISMATCH** = confirmed contract difference; **BLOCKED** = backend/runtime prerequisite prevents safe verification; **NOT VERIFIED** = no mismatch seen in source, but no live runtime response has been observed.

| Flutter operation | Endpoint / method | Request and response audit | Status |
| --- | --- | --- | --- |
| Login, OTP/register, refresh/logout, session | `/auth/*` POST; `/auth/me` GET | Root-mounted paths; auth wrapper/token envelope parsed. Flutter secure storage and one retry on a non-auth 401. | NOT VERIFIED (live); source contract supported |
| Profile get/update | `/profile/me` GET/PATCH | Address update only; runtime schema and validation not exercised. | NOT VERIFIED |
| Facility list/search | `/facilities` GET | Uses `status=active`, search/city, page/limit; parses `data.items`; automated test covers filters and empty list. | SUPPORTED (source/test) |
| Facility public detail | `/facilities/{id}/public-detail` GET | Parses `data.facility` and `unitTypeOfferings`; source schema reviewed; no live response test. | NOT VERIFIED |
| Available units | `/storage-units/facility/{facilityId}/available` GET | Sends `unitTypeId`; filters response rows to `status=available`. | NOT VERIFIED |
| Available time slots | `/facility-time-slots/facility/{facilityId}/available` GET | Sends date as `YYYY-MM-DD`; request creation uses exact `slotName`. | SUPPORTED (source/test for create payload) |
| Create reservation | `/reservations` POST | Sends facility ID, physical `storageUnitId`, date-only `checkInDate`, `checkInTimeSlot`, offering ID and duration. Tested request fields and local required/date validation. | SUPPORTED (source/test) |
| Reservation list/detail/cancel | `/reservations` GET, `/{id}` GET, `/{id}/cancel` POST | List expects `data.items`; cancel sends trimmed `cancellationReason` (min 3 chars). Server conflict/state/error path not exercised live. | NOT VERIFIED |
| Create/read deposit payment | `/payments` POST, `/{id}` GET | Sends `purpose=reservation_deposit` plus reservation ID; parses backend QR. `paid` is the only success status; other terminal states are expired/cancelled. | SUPPORTED (source/test) |
| SePay status polling | `/payments/{id}` GET | Sequential, bounded polls; stop on terminal status, app pause/dispose, or emit timeout event. Webhook transition requires backend test environment. | BLOCKED (runtime/webhook) |
| Contract list/detail/accept/renew | `/contracts` GET, `/{id}` GET, `/{id}/customer-sign` POST, `/{id}/renew` POST | Renewal sends valid date as ISO timestamp in `newEndDate`; accept sends `termsAccepted=true`. Backend schemas accept these fields. Role/ownership enforcement is a blocker. | BLOCKED (authorization); runtime NOT VERIFIED |
| Notifications list/read | `/notifications` GET, `/{id}/read` PATCH, `/read-all` PATCH | Source call reviewed; live payload, pagination and error behavior not exercised. | NOT VERIFIED |

No known Flutter/backend contract mismatch was established from source review. Pagination beyond first/default page and error/status transitions need permitted runtime coverage. Backend auth TODOs remain blockers, not client-side fixes.
