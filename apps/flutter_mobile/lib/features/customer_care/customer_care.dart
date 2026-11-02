import 'package:dio/dio.dart';

class CustomerCareRepository {
  CustomerCareRepository(this.dio);
  final Dio dio;

  Future<List<Map<String, dynamic>>> list(String path, {int page = 1}) async {
    final response = await dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'page': page, 'limit': 20},
    );
    final data = response.data?['data'];
    final items = data is Map ? data['items'] : data;
    if (items is! List) {
      throw const FormatException('Dữ liệu danh sách không hợp lệ.');
    }
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> detail(String path, String id) async {
    final response = await dio.get<Map<String, dynamic>>('$path/$id');
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu chi tiết không hợp lệ.');
    }
    return data;
  }

  Future<Map<String, dynamic>> createSupport(
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/support-tickets',
      data: payload,
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi tạo yêu cầu không hợp lệ.');
    }
    return data;
  }

  Future<void> cancelSupport(String id, {String? reason}) async => dio.post(
    '/support-tickets/$id/cancel',
    data: {
      if (reason?.trim().isNotEmpty == true)
        'cancellationReason': reason!.trim(),
    },
  );
  Future<void> cancelIncident(String id, String reason) async => dio.post(
    '/incidents/$id/cancel',
    data: {'cancellationReason': reason.trim()},
  );
  Future<void> closeIncident(String id, {String? notes}) async => dio.post(
    '/incidents/$id/close',
    data: {if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim()},
  );
}
