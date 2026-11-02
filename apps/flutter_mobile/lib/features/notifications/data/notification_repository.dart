import 'package:dio/dio.dart';

import 'notification_models.dart';

class NotificationRepository {
  NotificationRepository(this._dio);
  final Dio _dio;

  Future<NotificationPage> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
    String? facilityId,
    String? priority,
    String? type,
    String? search,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    if (page < 1 || limit < 1) {
      throw ArgumentError('Notification page and limit must be positive.');
    }
    if (sortBy.trim().isEmpty || !const {'asc', 'desc'}.contains(sortOrder)) {
      throw ArgumentError('Notification sorting is invalid.');
    }
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (isRead != null) query['isRead'] = isRead;
    if (facilityId?.isNotEmpty == true) query['facilityId'] = facilityId;
    if (priority != null) query['priority'] = priority;
    if (type != null) query['type'] = type;
    if (search?.trim().isNotEmpty == true) query['search'] = search!.trim();
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: query,
    );
    final data = response.data?['data'];
    if (data is! Map) {
      throw const FormatException(
        'Backend did not return paginated notifications.',
      );
    }
    return NotificationPage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    final data = response.data?['data'];
    if (data is! Map ||
        data['unreadCount'] is! num ||
        (data['unreadCount'] as num) < 0) {
      throw const FormatException(
        'Backend did not return a valid unread count.',
      );
    }
    return (data['unreadCount'] as num).toInt();
  }

  Future<AppNotification> markAsRead(String id) async {
    if (id.trim().isEmpty) throw ArgumentError('Notification id is required.');
    final response = await _dio.patch<Map<String, dynamic>>(
      '/notifications/${Uri.encodeComponent(id)}/read',
    );
    final data = response.data?['data'];
    if (data is! Map) {
      throw const FormatException(
        'Backend did not return the updated notification.',
      );
    }
    return AppNotification.fromJson(Map<String, dynamic>.from(data));
  }

  Future<int> markAllAsRead() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/notifications/read-all',
    );
    final data = response.data?['data'];
    if (data is! Map || data['modifiedCount'] is! num) {
      throw const FormatException('Backend did not return modifiedCount.');
    }
    return (data['modifiedCount'] as num).toInt();
  }

  Future<void> deleteNotification(String id) async {
    if (id.trim().isEmpty) throw ArgumentError('Notification id is required.');
    final response = await _dio.delete<Map<String, dynamic>>(
      '/notifications/${Uri.encodeComponent(id)}',
    );
    final data = response.data;
    if (data == null || !data.containsKey('data') || data['data'] != null) {
      throw const FormatException(
        'Backend did not return the expected delete response.',
      );
    }
  }
}
