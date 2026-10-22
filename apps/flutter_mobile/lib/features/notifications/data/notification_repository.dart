import 'package:dio/dio.dart';

class NotificationRepository {
  NotificationRepository(this._dio);
  final Dio _dio;
  Future<List<Map<String, dynamic>>> list() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': 1, 'limit': 50},
    );
    final d = r.data?['data'];
    final items = d is Map ? d['items'] : d;
    return items is List
        ? items.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  Future<void> markRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _dio.patch('/notifications/read-all');
  }
}
