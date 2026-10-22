# Flutter Mobile Security Review

## Findings

| Area | Status | Finding |
| --- | --- | --- |
| Token storage | PARTIAL | Access and refresh tokens are held through `flutter_secure_storage`; no token values are intentionally logged. Platform behavior still needs validation on physical Android/iOS devices. |
| API transport | PARTIAL | `API_BASE_URL` is injectable and defaults to Render HTTPS. Cleartext is enabled only in the Android debug manifest; the main/release manifest uses Android's HTTPS-only default. TLS certificate validation is not disabled. |
| Auth refresh | DONE (source/unit verified) | Shared Dio attaches bearer tokens to non-auth routes, serializes refresh, retries a failed request once, and clears stored tokens when refresh fails. Runtime behavior against the backend remains unverified. |
| Sensitive logging/secrets | DONE (source reviewed) | No embedded API credentials or token logging found in reviewed Flutter sources. Build-time API URL is configuration, not a secret. |
| Route guards | PARTIAL | Router guards customer screens based on restored client state. These guards are navigation UX only and provide no backend access control. |
| Customer data isolation | BLOCKED | Reservation, payment, and contract backend controllers have disabled/commented security decorators or TODO role checks. Cross-account isolation cannot be vouched for from the client. |
| Payment confirmation | PARTIAL | The app treats only the backend `paid` status as successful and renders backend-provided QR data. Actual SePay webhook authenticity, replay handling, and reconciliation require backend verification. |
| Support API | BLOCKED | No customer support API was found in backend source; no fake local submission was added. |

## Release gates

- Enforce authentication and customer ownership/role checks on reservation, payment, and contract routes in the backend, then verify with separate test accounts.
- Restrict Android cleartext traffic to local development and use TLS in deployed environments.
- Validate token storage, app background/resume behavior, screen capture policy if required, and network behavior on supported physical Android versions.
- Verify SePay callback signature/secret, replay protection, amount/reference matching, and server-side payment state transitions in the backend.
- Do not treat mobile route guards or a successful QR display as authorization or payment proof.
