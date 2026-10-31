# Flutter Notifications Integration

**Updated:** 2026-10-23  
**Overall:** REST implementation DONE; authenticated production flow NOT VERIFIED; realtime BLOCKED pending a documented connection contract.

## Implemented

- Reused the existing notifications module and the app's shared Dio client. Its interceptor attaches the current access token and handles refresh according to the existing session policy.
- Added a strict `AppNotification`, `NotificationPagination`, and paginated `NotificationPage` DTO. `facilityId`, `readAt`, timestamps, and metadata are nullable; malformed envelopes/items throw instead of becoming an empty list.
- Added REST repository methods for list, unread count, mark one read, mark all read, and soft delete. Errors propagate to the UI.
- Added Riverpod providers and a feed controller for all/unread filtering, refresh, page loading, mark-read, mark-all, delete, and unread-count invalidation. List/count state is invalidated on login, registration, and logout.
- Added a Notifications screen with loading/error/retry, all/unread filter, empty state, pull-to-refresh, infinite load-more, read/unread indicators, type icons, priority and local date display, delete confirmation, mark-all-read, and a notification detail dialog.
- Added a bell with unread badge to the authenticated Profile app bar. It opens Notifications and stays hidden when signed out.
- On opening the screen and when the app resumes, list/count data is refreshed. No polling or realtime protocol is assumed.
- Navigation only uses an explicit nonempty `metadata.reservationId` for reservation and payment notifications. Contract detail navigation is unavailable because the app has no contract detail route; notifications without a usable route stay in the detail dialog.

## Production API contract review

Public Render OpenAPI was read through `GET /api-docs/swagger-ui-init.js`; no mutation endpoints were called.

| Operation | Flutter request/response handling |
| --- | --- |
| `GET /notifications` | Sends required `page`, `limit`, `sortBy`, and `sortOrder`; optional unread filter sends `isRead=false`. Default: page 1, limit 20, `sortBy=createdAt`, `sortOrder=desc`. Parses `data.items` and `data.pagination`. |
| `GET /notifications/unread-count` | Parses `data.unreadCount`; feeds the profile bell badge. |
| `PATCH /notifications/{id}/read` | Parses returned notification and updates the feed; invalidates unread count. |
| `PATCH /notifications/read-all` | Parses `data.modifiedCount`, updates the local feed, and invalidates unread count. |
| `DELETE /notifications/{id}` | Calls soft-delete route, removes the item after success, and invalidates count if it was unread. |
| `POST /notifications/test` | Not used by customer runtime and was not called. |

OpenAPI accepts `sortOrder` values `asc` and `desc`; `sortBy` is declared as a required string with no documented enum/default. `createdAt` is selected as the descending order field, but the authenticated production query could not be checked without an authorized test account. Query filters include `facilityId`, priority, type, read state, and search. Notification type values are `system`, `system_alert`, `approval_request`, `storage_unit`, `reservation`, `contract`, and `payment`; priorities are `low`, `normal`, `high`, and `urgent`; channels are `in_app` and `email`.

The response schema requires `id`, `recipientId`, `title`, `content`, `type`, `priority`, `channels`, and `isRead`; `facilityId`, `readAt`, `metadata`, `createdAt`, and `updatedAt` are handled as optional. Pagination fields match the public `PaginationMeta` schema.

Unauthenticated safe GET checks to `/notifications?page=1&limit=20&sortBy=createdAt&sortOrder=desc` and `/notifications/unread-count` returned 401. OpenAPI marks these operations with an empty operation-level `security` list despite the runtime 401. The app uses the shared Dio client to attach the current session token, but an authenticated production response remains NOT VERIFIED because no permitted test account was available.

## Realtime

OpenAPI describes `/notifications/test` as a temporary endpoint that sends a realtime notification, but provides no Socket.IO/WebSocket/SSE URL, auth handshake, event name, payload, or reconnection contract. No realtime client was added. Status: **BLOCKED** pending a backend-published contract. REST refresh on screen open and app resume is implemented.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | PASS — no issues. |
| `flutter test` | PASS — 27 tests, including DTOs, empty/paginated responses, REST query and mutation paths, 401/403/404/timeout/invalid response, pagination, and unread badge synchronization. All mutation tests use a mocked Dio adapter. |
| `flutter build apk --debug` | PASS — `apps/flutter_mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| Android emulator startup | PASS — `emulator-5554` installed and launched the app to its signed-out welcome screen. |
| Notifications screen/badge live data/navigation | NOT VERIFIED — no test account was used to enter the authenticated flow. No production POST/PATCH/DELETE request was made. |

## Remaining work

- Provide an authorized non-production or test account and real notification records to verify authenticated list/count responses and the notifications UI on Android.
- Confirm the backend's accepted `sortBy` field and, if metadata navigation keys are standardized, publish their exact shape.
- Publish the realtime connection contract if realtime delivery is required.
