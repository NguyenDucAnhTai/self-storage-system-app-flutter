import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../application/notification_providers.dart';
import '../data/notification_models.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  static _NotificationBellState? _activeBell;

  final _portalController = OverlayPortalController();
  final _bellKey = GlobalKey();
  AppNotification? _detail;

  void _toggle() {
    if (_portalController.isShowing) {
      _close();
      return;
    }
    _activeBell?._close();
    _activeBell = this;
    _detail = null;
    final feed = ref.read(notificationFeedProvider);
    if (!feed.isLoading) ref.invalidate(notificationFeedProvider);
    _portalController.show();
  }

  void _close() {
    if (_portalController.isShowing) _portalController.hide();
    _detail = null;
    if (identical(_activeBell, this)) _activeBell = null;
  }

  @override
  void dispose() {
    if (identical(_activeBell, this)) _activeBell = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) _close();
    });
    final auth = ref.watch(authControllerProvider).value;
    if (auth == null) return const SizedBox.shrink();
    final count = ref.watch(notificationUnreadCountProvider).asData?.value ?? 0;
    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: _overlay,
      child: IconButton(
        key: _bellKey,
        tooltip: 'Thông báo',
        onPressed: _toggle,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final overlayObject = Overlay.of(context).context.findRenderObject();
    final anchorObject = _bellKey.currentContext?.findRenderObject();
    final overlayBox = overlayObject is RenderBox && overlayObject.hasSize
        ? overlayObject
        : null;
    final anchorBox = anchorObject is RenderBox && anchorObject.hasSize
        ? anchorObject
        : null;
    final viewportWidth = overlayBox?.size.width ?? mediaSize.width;
    final viewportHeight = overlayBox?.size.height ?? mediaSize.height;
    final leftInset = math.max(12.0, viewPadding.left + 12);
    final rightInset = math.max(12.0, viewPadding.right + 12);
    final width = math.max(
      0.0,
      math.min(340.0, viewportWidth - leftInset - rightInset),
    );
    final anchorTopLeft = overlayBox != null && anchorBox != null
        ? anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : Offset(viewportWidth - rightInset, viewPadding.top + 56);
    final anchorBottom = anchorTopLeft.dy + (anchorBox?.size.height ?? 48);
    final top = math.max(viewPadding.top + 8, anchorBottom + 8);
    final left = (anchorTopLeft.dx + (anchorBox?.size.width ?? 0) - width)
        .clamp(
          leftInset,
          math.max(leftInset, viewportWidth - rightInset - width),
        )
        .toDouble();
    final availableHeight = viewportHeight - top - viewPadding.bottom - 12;
    final maxHeight = math.max(120.0, math.min(440.0, availableHeight));

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: width,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .94, end: 1),
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) => Opacity(
                opacity: ((scale - .94) / .06).clamp(0, 1),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topRight,
                  child: child,
                ),
              ),
              child: _NotificationPopup(
                maxHeight: maxHeight,
                detail: _detail,
                onClose: _close,
                onSelect: _selectNotification,
                onMarkAllRead: _markAllRead,
                onRetry: () => ref.invalidate(notificationFeedProvider),
                onBackToList: () => setState(() => _detail = null),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectNotification(AppNotification notification) async {
    try {
      if (!notification.isRead) {
        await ref
            .read(notificationFeedProvider.notifier)
            .markAsRead(notification.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật trạng thái thông báo'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final destination = _destinationFor(notification);
    if (destination != null) {
      _close();
      context.push(destination);
      return;
    }
    setState(() {
      _detail = notification.isRead
          ? notification
          : notification.copyWith(isRead: true, readAt: DateTime.now());
    });
  }

  String? _destinationFor(AppNotification notification) {
    final metadata = notification.metadata;
    if (metadata == null) return null;
    final rawId = metadata['reservationId'];
    if (rawId is! String || rawId.trim().isEmpty) return null;
    final id = Uri.encodeComponent(rawId.trim());
    if (notification.type == 'reservation') return '/reservations/$id';
    if (notification.type == 'payment') return '/payments/$id';
    return null;
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationFeedProvider.notifier).markAllAsRead();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể đánh dấu thông báo đã đọc')),
        );
      }
    }
  }
}

class _NotificationPopup extends ConsumerWidget {
  const _NotificationPopup({
    required this.maxHeight,
    required this.detail,
    required this.onClose,
    required this.onSelect,
    required this.onMarkAllRead,
    required this.onRetry,
    required this.onBackToList,
  });

  final double maxHeight;
  final AppNotification? detail;
  final VoidCallback onClose;
  final ValueChanged<AppNotification> onSelect;
  final VoidCallback onMarkAllRead;
  final VoidCallback onRetry;
  final VoidCallback onBackToList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationFeedProvider);
    final count =
        ref.watch(notificationUnreadCountProvider).asData?.value ??
        (feed.asData?.value.items.where((item) => !item.isRead).length ?? 0);
    final data = feed.asData?.value;
    final listHeight = feed.isLoading
        ? math.min(180.0, maxHeight - 76)
        : feed.hasError || data?.items.isEmpty != false
        ? math.min(132.0, maxHeight - 76)
        : math.min(data!.items.take(5).length * 70.0, maxHeight - 76);

    return Material(
      key: const ValueKey('notification-popup-panel'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 14,
      shadowColor: const Color(0x33003327),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 9),
              child: Row(
                children: [
                  if (detail != null) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quay lại danh sách',
                      onPressed: onBackToList,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(
                      detail?.title ?? 'Thông báo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (detail == null && count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count chưa đọc',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  if (detail == null && count > 0)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Đánh dấu tất cả đã đọc',
                      onPressed: onMarkAllRead,
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Đóng',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: detail == null
                  ? listHeight
                  : math.min(250.0, maxHeight - 76),
              child: detail != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(detail!.content),
                    )
                  : feed.when(
                      loading: () => const _PopupLoading(),
                      error: (_, _) => _PopupError(onRetry: onRetry),
                      data: (value) => value.items.isEmpty
                          ? const _PopupEmpty()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: math.min(5, value.items.length),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 2),
                              itemBuilder: (context, index) =>
                                  _NotificationPreview(
                                    notification: value.items[index],
                                    onTap: () => onSelect(value.items[index]),
                                  ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    return Material(
      color: unread
          ? theme.colorScheme.secondaryContainer.withValues(alpha: .28)
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: unread
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _notificationIcon(notification.type),
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _relativeTime(notification.createdAt!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 7),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupLoading extends StatelessWidget {
  const _PopupLoading();
  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    ),
  );
}

class _PopupEmpty extends StatelessWidget {
  const _PopupEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 28),
          SizedBox(height: 7),
          Text('Bạn chưa có thông báo nào'),
        ],
      ),
    ),
  );
}

class _PopupError extends StatelessWidget {
  const _PopupError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Không thể tải thông báo'),
          const SizedBox(height: 5),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

IconData _notificationIcon(String type) => switch (type) {
  'reservation' => Icons.event_available_outlined,
  'payment' => Icons.payments_outlined,
  'contract' => Icons.description_outlined,
  'storage_unit' => Icons.inventory_2_outlined,
  'system_alert' => Icons.warning_amber_outlined,
  _ => Icons.notifications_outlined,
};

String _relativeTime(DateTime value) {
  final age = DateTime.now().difference(value.toLocal());
  if (age.isNegative || age.inSeconds < 45) return 'Vừa xong';
  if (age.inMinutes < 60) return '${age.inMinutes} phút trước';
  if (age.inHours < 24) return '${age.inHours} giờ trước';
  if (age.inDays < 7) return '${age.inDays} ngày trước';
  return '${(age.inDays / 7).floor()} tuần trước';
}
