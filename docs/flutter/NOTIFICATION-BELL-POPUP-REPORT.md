# Notification bell anchored popup report

**Date:** 2026-10-31  
**Scope:** Flutter Customer frontend only. Notification API contracts and the full Notifications route were not changed.

## Implementation

- Replaced bell navigation with a reusable `OverlayPortal` popup, integrated at the existing Home, Explore and Profile app-bar bell locations.
- Anchors the panel to the bell by measuring its render-box position in the active overlay, then clamps the panel's left/right edges to the safe viewport. It sits below the icon, uses up to 340dp width, and is limited to 440dp or the remaining safe height.
- Used a transparent full-screen hit target behind the popup (no dim barrier), rounded surface, shadow, and a short fade/scale animation. Reopening a second bell closes the previous popup; disposal and account identity changes close it as well.
- Opening reuses `notificationFeedProvider` and `notificationUnreadCountProvider`, backed by the existing `NotificationRepository` and shared Dio client. The feed is sorted newest-first by the existing controller; the popup displays at most five records. The badge and popup share the same unread-count provider.
- Read actions call the existing notifier and update the count only after the repository call succeeds. “Đánh dấu tất cả đã đọc” uses the existing mark-all endpoint. Failed requests show an error and do not locally mark an unread notification as read.
- Tapping a notification with supported reservation/payment metadata opens only the existing matching route. Other notifications show their full content inside the popup. The bell itself never navigates to `/notifications`.
- Profile’s existing “Notifications” menu item still pushes `/notifications`; the full screen and its filtering, pagination, read, delete and detail actions remain intact.

## Popup states and content

- Loading indicator; empty message “Bạn chưa có thông báo nào”; retryable “Không thể tải thông báo” error.
- Latest five real notifications, type icon, truncated title/content, relative time, unread dot/mint surface and read surface.
- On 320dp width with 1.3x text scaling, long title/content test passes without a Flutter layout exception. Panel bounds are asserted within 320dp, 360dp and 510dp viewports.
- Provider state and overlay are invalidated/closed on auth account changes; existing auth controller already invalidates notification feed/count on login and logout.

## Files changed for this task

- `apps/flutter_mobile/lib/features/notifications/presentation/notification_bell.dart`
- `apps/flutter_mobile/test/notification_bell_test.dart`
- `docs/flutter/NOTIFICATION-BELL-POPUP-REPORT.md`

The workspace already contained unrelated uncommitted changes; they were preserved.

## Verification

- `flutter analyze --no-pub` — **PASS**, no issues found.
- `flutter test --no-pub` — **PASS**, all 60 tests passed.
- `flutter build apk --debug --no-pub` — **PASS**, `build/app/outputs/flutter-apk/app-debug.apk` created.
- `git diff --check` — **PASS**, no whitespace errors. Git emitted existing LF-to-CRLF working-copy notices.
- Popup widget tests cover opening without navigation, toggle close, outside dismissal, provider-backed latest-five display, loading/empty/error/retry states, unread badge and mark-read success/failure, 320dp enlarged-text layout, viewport bounds at 320/360/510dp, multiple bell instances, disposal, and Profile → full Notifications navigation.

## Runtime evidence and limitations

No Android screenshot is attached. The currently installed emulator session is at Login, and this task did not enter credentials. Popup positioning and narrow-width behavior were verified in Flutter widget tests; an authenticated emulator screenshot remains unverified. Production notification data and server-driven expiry behavior were not exercised in this UI task.
