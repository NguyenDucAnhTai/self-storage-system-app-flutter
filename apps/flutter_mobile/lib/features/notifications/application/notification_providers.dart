import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

enum NotificationFilter { all, unread }

class NotificationFeed {
  const NotificationFeed({
    required this.items,
    required this.pagination,
    required this.filter,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<AppNotification> items;
  final NotificationPagination pagination;
  final NotificationFilter filter;
  final bool isLoadingMore;
  final Object? loadMoreError;

  NotificationFeed copyWith({
    List<AppNotification>? items,
    NotificationPagination? pagination,
    NotificationFilter? filter,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => NotificationFeed(
    items: items ?? this.items,
    pagination: pagination ?? this.pagination,
    filter: filter ?? this.filter,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
  );
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(dioProvider)),
);

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationRepositoryProvider).getUnreadCount(),
);

final notificationFeedProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationFeedController,
      NotificationFeed
    >(NotificationFeedController.new);

class NotificationFeedController extends AsyncNotifier<NotificationFeed> {
  static const _pageSize = 20;
  late NotificationRepository _repository;
  NotificationFilter _filter = NotificationFilter.all;
  NotificationFilter get selectedFilter => _filter;

  @override
  Future<NotificationFeed> build() async {
    _repository = ref.watch(notificationRepositoryProvider);
    return _fetch(_filter, page: 1);
  }

  Future<NotificationFeed> _fetch(
    NotificationFilter filter, {
    required int page,
  }) async {
    final result = await _repository.getNotifications(
      page: page,
      limit: _pageSize,
      isRead: filter == NotificationFilter.unread ? false : null,
      sortBy: 'createdAt',
      sortOrder: 'desc',
    );
    return NotificationFeed(
      items: result.items,
      pagination: result.pagination,
      filter: filter,
    );
  }

  Future<void> refresh() async {
    final filter = state.asData?.value.filter ?? _filter;
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(filter, page: 1));
    ref.invalidate(notificationUnreadCountProvider);
  }

  Future<void> setFilter(NotificationFilter filter) async {
    if (_filter == filter && state.hasValue) return;
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(filter, page: 1));
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.pagination.hasNextPage) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final result = await _repository.getNotifications(
        page: current.pagination.page + 1,
        limit: _pageSize,
        isRead: current.filter == NotificationFilter.unread ? false : null,
        sortBy: 'createdAt',
        sortOrder: 'desc',
      );
      final latest = state.asData?.value;
      if (latest == null) return;
      final ids = latest.items.map((item) => item.id).toSet();
      state = AsyncData(
        latest.copyWith(
          items: [
            ...latest.items,
            ...result.items.where((item) => !ids.contains(item.id)),
          ],
          pagination: result.pagination,
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      final latest = state.asData?.value;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(isLoadingMore: false, loadMoreError: error),
        );
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> markAsRead(String id) async {
    final updated = await _repository.markAsRead(id);
    final current = state.asData?.value;
    if (current != null) {
      final exists = current.items.any((item) => item.id == id);
      if (current.filter == NotificationFilter.unread) {
        state = AsyncData(
          current.copyWith(
            items: current.items.where((item) => item.id != id).toList(),
            pagination: exists
                ? current.pagination.decrementTotal()
                : current.pagination,
          ),
        );
      } else {
        state = AsyncData(
          current.copyWith(
            items: [
              for (final item in current.items) item.id == id ? updated : item,
            ],
          ),
        );
      }
    }
    ref.invalidate(notificationUnreadCountProvider);
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    final current = state.asData?.value;
    if (current != null) {
      if (current.filter == NotificationFilter.unread) {
        state = AsyncData(
          current.copyWith(
            items: const [],
            pagination: NotificationPagination(
              page: 1,
              limit: current.pagination.limit,
              totalItems: 0,
              totalPages: 0,
              hasNextPage: false,
              hasPrevPage: false,
            ),
          ),
        );
      } else {
        state = AsyncData(
          current.copyWith(
            items: current.items
                .map(
                  (item) => item.copyWith(isRead: true, readAt: DateTime.now()),
                )
                .toList(),
          ),
        );
      }
    }
    ref.invalidate(notificationUnreadCountProvider);
  }

  Future<void> deleteNotification(String id) async {
    final current = state.asData?.value;
    final deleted = current?.items.where((item) => item.id == id).firstOrNull;
    await _repository.deleteNotification(id);
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: current.items.where((item) => item.id != id).toList(),
          pagination: deleted == null
              ? current.pagination
              : current.pagination.decrementTotal(),
        ),
      );
    }
    if (deleted?.isRead == false) {
      ref.invalidate(notificationUnreadCountProvider);
    }
  }
}
