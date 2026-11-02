# Customer Dashboard

## Entry and navigation

- `/home` is the authenticated landing page after session restoration, login, and registration.
- Guest deep links remain preserved through login; authentication loading stays on splash until restoration resolves.
- The customer shell has Home, Explore, My Bookings, and Profile tabs. Explore remains a dedicated facility-search view.
- Dashboard is read-only. It does not create reservations, payment sessions, contracts, or inventory movements.

## Data contract

| Dashboard section | Source | Mapping / empty behavior |
|---|---|---|
| Storage overview | `GET /customer-inventories/summary` | `totalStorageUnits`, `totalActiveContracts`, `totalSkus`, `totalQuantity`; required response fields are validated strictly. |
| Upcoming actions | `GET /reservations` | Only `pending_payment` reservations are highlighted; other statuses follow the current Swagger enum and booking screen. |
| Active storage | `GET /contracts` | Only rows with status exactly `active`; facility, unit, offering and end date are read from returned nested values when present. |
| Recent activity | `GET /customer-inventories/summary` | Uses actual `recentMovements`; no synthetic activity. |
| Facility highlights | `GET /facilities` | Shows up to three returned listings; no generated recommendations. |
| Notification badge | `GET /notifications/unread-count` | Shares the notification provider used by the notification UI. |

Providers use the shared Dio configured with `AppConfig.apiBaseUrl` and secure bearer token storage. No customer/user ID is added to the dashboard summary request; backend caller scoping is expected and must be verified server-side. Auth changes invalidate dashboard and notification providers so one account's cached data is not retained after login/logout. Reservation, payment status, and contract changes invalidate the relevant dashboard data.

## State and interaction

- Each API section owns its own loading/error/empty state, so one failed request does not hide unrelated sections.
- Error cards offer a retry for that data source. Pull-to-refresh requests each source again.
- Malformed summary payloads remain errors; metric counters are never replaced with guessed values.
- Explore, Bookings, and Contracts are navigation-only quick actions. They do not trigger writes.

## Verification status

Widget and redirect tests use provider overrides; repository parsing tests use a mocked Dio adapter. Flutter analyze/test/build results are in [TEST-REPORT.md](TEST-REPORT.md). Production dashboard data, authorization scoping, and authenticated emulator rendering are **NOT VERIFIED** because no permitted customer test account/runtime was supplied. No production business endpoint was called for this dashboard change.
