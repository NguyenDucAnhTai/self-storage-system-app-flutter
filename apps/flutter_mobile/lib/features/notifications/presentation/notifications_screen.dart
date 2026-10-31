import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../application/notification_providers.dart';
import '../data/notification_models.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(notificationUnreadCountProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(notificationFeedProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider);
    final current = feed.asData?.value;
    final unreadCount =
        ref.watch(notificationUnreadCountProvider).asData?.value ?? 0;
    final hasUnread =
        unreadCount > 0 ||
        (current?.items.any((item) => !item.isRead) ?? false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: hasUnread ? () => _markAllRead() : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<NotificationFilter>(
              segments: const [
                ButtonSegment(
                  value: NotificationFilter.all,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: NotificationFilter.unread,
                  label: Text('Unread'),
                ),
              ],
              selected: {
                current?.filter ??
                    ref.read(notificationFeedProvider.notifier).selectedFilter,
              },
              onSelectionChanged: feed.isLoading
                  ? null
                  : (selection) => unawaited(
                      ref
                          .read(notificationFeedProvider.notifier)
                          .setFilter(selection.first),
                    ),
            ),
          ),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _errorState(error),
              data: _notificationList,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(_errorMessage(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(
              ref.read(notificationFeedProvider.notifier).refresh(),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  String _errorMessage(Object error) {
    final dioError = error is DioException ? error : null;
    final apiError = dioError?.error is ApiError
        ? dioError!.error as ApiError
        : error is ApiError
        ? error
        : null;
    final statusCode = dioError?.response?.statusCode ?? apiError?.statusCode;
    if (statusCode == 401) {
      return 'Your session has expired. Sign in again to load notifications.';
    }
    if (statusCode == 403) {
      return 'You are not authorized to view these notifications.';
    }
    if (statusCode == 404) {
      return 'Notifications could not be found.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The server could not load notifications. Please retry.';
    }
    if (dioError?.type == DioExceptionType.connectionTimeout ||
        dioError?.type == DioExceptionType.receiveTimeout ||
        dioError?.type == DioExceptionType.sendTimeout) {
      return 'The request timed out. Check your connection and retry.';
    }
    if (dioError?.type == DioExceptionType.connectionError) {
      return 'Unable to connect. Check your network and retry.';
    }
    final message = error.toString().toLowerCase();
    if (message.contains('401') || message.contains('unauthorized')) {
      return 'Your session has expired. Sign in again to load notifications.';
    }
    if (message.contains('403') || message.contains('forbidden')) {
      return 'You are not authorized to view these notifications.';
    }
    if (message.contains('404') || message.contains('not found')) {
      return 'Notifications could not be found.';
    }
    if (message.contains('timeout')) {
      return 'The request timed out. Check your connection and retry.';
    }
    if (message.contains('connect') || message.contains('socket')) {
      return 'Unable to connect. Check your network and retry.';
    }
    if (error is FormatException) {
      return 'The server returned notifications in an unsupported format.';
    }
    return 'Could not load notifications. Please retry.';
  }

  Widget _notificationList(NotificationFeed feed) {
    if (feed.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(notificationFeedProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      feed.filter == NotificationFilter.unread
                          ? 'No unread notifications.'
                          : 'You are all caught up.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    final showFooter =
        feed.pagination.hasNextPage || feed.loadMoreError != null;
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationFeedProvider.notifier).refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 280 &&
              feed.pagination.hasNextPage &&
              !feed.isLoadingMore) {
            unawaited(ref.read(notificationFeedProvider.notifier).loadMore());
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: feed.items.length + (showFooter ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == feed.items.length) {
              if (feed.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (feed.loadMoreError != null) {
                return TextButton.icon(
                  onPressed: () => unawaited(
                    ref.read(notificationFeedProvider.notifier).loadMore(),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Could not load more. Retry'),
                );
              }
              return const SizedBox(height: 24);
            }
            return _notificationTile(feed.items[index]);
          },
        ),
      ),
    );
  }

  Widget _notificationTile(AppNotification notification) => Card(
    color: notification.isRead
        ? null
        : Theme.of(context).colorScheme.secondaryContainer
              .withValues(alpha: .35),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(_iconFor(notification.type)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              notification.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!notification.isRead) ...[
            const SizedBox(width: 8),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Text(
              [
                if (notification.createdAt != null)
                  DateFormat('MMM d, y · h:mm a')
                      .format(notification.createdAt!.toLocal()),
                if (notification.priority != 'normal')
                  notification.priority.toUpperCase(),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete notification',
        onPressed: () => _confirmDelete(notification),
        icon: const Icon(Icons.delete_outline),
      ),
      onTap: () => _openNotification(notification),
    ),
  );

  IconData _iconFor(String type) => switch (type) {
    'reservation' => Icons.event_available_outlined,
    'payment' => Icons.payments_outlined,
    'contract' => Icons.description_outlined,
    'storage_unit' => Icons.inventory_2_outlined,
    'system_alert' => Icons.warning_amber_outlined,
    _ => Icons.notifications_outlined,
  };

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationFeedProvider.notifier).markAllAsRead();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _confirmDelete(AppNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text(
          'This notification will be removed from your list.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(notificationFeedProvider.notifier)
          .deleteNotification(notification.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    try {
      if (!notification.isRead) {
        await ref
            .read(notificationFeedProvider.notifier)
            .markAsRead(notification.id);
      }
    } catch (error) {
      _showError(error);
    }
    if (!mounted) return;
    final destination = _destinationFor(notification);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(child: Text(notification.content)),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
          if (destination != null)
            FilledButton(
              onPressed: () {
                context.pop();
                context.push(destination);
              },
              child: const Text('Open'),
            ),
        ],
      ),
    );
  }

  String? _destinationFor(AppNotification notification) {
    final metadata = notification.metadata;
    if (metadata == null) return null;
    String? id(String key) {
      final value = metadata[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    if (notification.type == 'reservation') {
      final reservationId = id('reservationId');
      return reservationId == null
          ? null
          : '/reservations/${Uri.encodeComponent(reservationId)}';
    }
    if (notification.type == 'payment') {
      final reservationId = id('reservationId');
      return reservationId == null
          ? null
          : '/payments/${Uri.encodeComponent(reservationId)}';
    }
    return null;
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
  }
}
