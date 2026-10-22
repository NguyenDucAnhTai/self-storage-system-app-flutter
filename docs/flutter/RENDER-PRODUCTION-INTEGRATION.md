# Render Production Integration

**Checked:** 2026-10-22  
**Overall:** PARTIAL — production HTTPS and public facility GET flows verified; authentication and protected customer flows are not verified. No production writes were issued.

## Configuration

- Central default: `https://self-storage-system-be.onrender.com` in `AppConfig.apiBaseUrl`.
- Override: `--dart-define=API_BASE_URL=<https-url>` for a deliberately selected staging/test environment.
- All Flutter repositories continue to use the shared Dio instance; no repository-level URL was added.
- Android INTERNET permission is present. Dio keeps normal platform TLS certificate validation; no certificate bypass was added. Cleartext is enabled only by the Android debug manifest. The main/release manifest does not permit cleartext.
- Localhost, `127.0.0.1`, and `10.0.2.2` are absent from Flutter source. Earlier local-development commands were removed from current build/run guidance.

## Connectivity and API discovery

Requests used HTTPS GET only, with no Authorization header. Response bodies from protected routes were not inspected.

| Request | Result | Notes |
| --- | --- | --- |
| `GET /` | 200, `text/html` | Server responds over HTTPS. |
| `GET /api-docs` | 200, `text/html` | Public Swagger UI. |
| `GET /api-docs/swagger-ui-init.js` | 200, `application/javascript` | Contains an embedded OpenAPI 3.0.0 document, declares the production Render URL as its server, and lists 116 paths. |
| `GET /openapi.json`, `/swagger.json`, `/docs` | 404 | No standalone JSON spec was exposed at these common paths. |
| `GET /api/facilities` | 404 | Deployed API paths are rooted at `/`; no `/api` prefix was observed. |
| `GET /health` | 404 | This path is not a health endpoint in the deployed app; the root and public APIs responded successfully. |

## Verified read-only public APIs

| Endpoint | HTTP | Deployed response | Flutter compatibility |
| --- | --- | --- | --- |
| `GET /facilities?page=1&limit=20&status=active&sortBy=name&sortOrder=asc` | 200 | Standard `{success,statusCode,messageCode,message,data}` envelope; `data` has `items` and `pagination`; 20 items returned. Item keys include `id`, `name`, `address`, `city`, `status`, `images`, `operatingHours`; optional `phone`/`email` are absent and ignored safely. | Compatible with `Facility.fromJson` and listing parser. |
| Same listing with `search=codex-qa-no-match-20261022` | 200 | Same envelope, empty `items`. | Compatible with empty-state list parsing. |
| `GET /facilities/{id}/public-detail` | 200 | `data` contains `facility`, `unitTypeOfferings`, `amenityOfferings`; first tested facility had 2 unit type offerings and 1 amenity offering. Offering keys include `unitTypeId`, `pricePerUnit`, `billingUnit`, `depositMultiplier`, `minRentalDays`, and `availableUnitsCount`; nested `unitType` includes `id`, `name`, `area`, `volume`, and `dimensions`. | Compatible with Flutter's facility/offerings response shape. |
| `GET /storage-units/facility/{facilityId}/available` | 200 | Standard envelope; `data` is an array; 0 rows for the tested facility. | Compatible with physical-unit list parser; no unit could be selected from this response. |
| `GET /facility-time-slots/facility/{facilityId}/available?date=2026-10-22` | 200 | Standard envelope; `data` is an array; 0 rows for the tested facility/date. | Compatible with time-slot list parser; no slot was available in this response. |

No facility records, reservations, payments, OTPs, or other production data were created or changed.

## Protected API and authentication status

| Safe request | HTTP | Result |
| --- | --- | --- |
| `GET /auth/me` | 401 | Authentication required; no test access token was available. |
| `GET /reservations` | 401 | Authentication required. |
| `GET /payments` | 401 | Authentication required. |
| `GET /contracts` | 401 | Authentication required. |
| `GET /profile/me` | 401 | Authentication required. |
| `GET /notifications` | 401 | Authentication required. |

These 401 responses confirm the host is responding and are not treated as an outage. Swagger declares login, register, refresh, logout and session routes, but no POST auth request was sent: there are no authorized test credentials, and no production account or OTP may be created here. Session restore, token refresh, login, logout and authenticated navigation remain NOT VERIFIED against Render.

### Deployed OpenAPI notes

The embedded OpenAPI request schemas include:

- Reservation: required `facilityId`, `storageUnitId`, `checkInDate`, `checkInTimeSlot`, `rentalDuration`; `facilityUnitTypeOfferingId` is optional in the published schema. Flutter supplies it. The three requested storage/check-in fields match the deployed contract.
- Payment: `purpose`, optional `reservationId` and `contractId`; Flutter's reservation-deposit call uses the matching purpose and reservation ID.
- Customer contract acceptance: required `termsAccepted`; renewal: required `newEndDate`; Flutter sends these fields.

**Mismatch requiring backend documentation/security follow-up:** the embedded OpenAPI marks `GET /reservations`, `/payments`, `/contracts`, and `/notifications` with an empty operation-level `security` list, while the deployed GET requests returned 401. `GET /profile/me` and `/auth/me` declare security and returned 401 as expected. Flutter must honor actual 401 behavior and must not bypass it. Backend authorization and the OpenAPI/security discrepancy remain blockers; no backend changes were made.

## Android emulator

- Pixel 6 AVD was available (Android 17/API 37, emulator-5554). The Render-default debug APK built, installed and started; Login rendered. Register rendered with the corrected enabled idle **Send email code** button. No login/OTP action was submitted.
- Screenshots: [Render-default Login](render-emulator-login.png), [Render-default Register](render-emulator-register.png).
- Startup is verified, but the emulator app did not issue a Render request on the Login/Register screens. Device-side TLS/API response rendering is therefore NOT VERIFIED; the HTTPS GET checks above were performed from the host.
- Explore/facility screens require app navigation; no credentials were available to enter the customer flow. Protected screens, payment QR/polling and contract/profile/notification responses remain NOT VERIFIED.
- AVD had no visible app startup failure after ordinary launch. A system Android-runtime crash entry during an earlier attempt belonged to Google App Prediction (`com.google.android.as`), not this app.

## Flutter verification

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS; dependencies resolved (9 newer versions are outside current constraints). |
| `flutter analyze` | PASS; no issues. |
| `flutter test` | PASS; all 13 tests. |
| `flutter build apk --debug` | PASS; `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`, installed on emulator. |

## Production safety and remaining blockers

- No production login, OTP, reservation creation/cancellation, payment-session creation, transfer, contract acceptance, or renewal was attempted.
- A test customer and approved non-production write environment are needed for authenticated lifecycle testing.
- Backend route authorization TODOs recorded in [BACKEND-BLOCKERS.md](BACKEND-BLOCKERS.md) remain BLOCKED; the deployed OpenAPI security annotation discrepancy also needs backend review.
- Available physical units and slots were empty for the public facility/date sampled, so a reservation path could not be evaluated safely even if credentials were available.
- Device-side network call, Login/Register API actions, protected response schemas, SePay callbacks, payment status transitions, contract statuses, and customer data isolation remain NOT VERIFIED.
