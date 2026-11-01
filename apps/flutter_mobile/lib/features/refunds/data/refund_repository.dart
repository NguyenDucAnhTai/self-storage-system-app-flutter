import 'package:dio/dio.dart';

import 'refund_request.dart';

class RefundRepository {
  RefundRepository(this._dio);
  final Dio _dio;

  Future<RefundPage> list({int page = 1, int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/refund-requests',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
      },
    );
    final data = response.data?['data'];
    if (data is! Map) throw const FormatException('Invalid refunds response.');
    return RefundPage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<RefundRequest> detail(String id) async {
    _requireId(id);
    final response = await _dio.get<Map<String, dynamic>>(
      '/refund-requests/$id',
    );
    return RefundRequest.fromJson(_data(response.data));
  }

  Future<RefundRequest> cancel(String id, String reason) async {
    _requireId(id);
    final text = reason.trim();
    if (text.length < 3 || text.length > 500) {
      throw const FormatException('Lý do hủy cần từ 3 đến 500 ký tự.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/refund-requests/$id/cancel',
      data: {'cancellationReason': text},
    );
    return RefundRequest.fromJson(_data(response.data));
  }

  static Map<String, dynamic> _data(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid refund detail response.');
    }
    return data;
  }

  static void _requireId(String id) {
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
      throw const FormatException('Mã yêu cầu hoàn tiền không hợp lệ.');
    }
  }
}
