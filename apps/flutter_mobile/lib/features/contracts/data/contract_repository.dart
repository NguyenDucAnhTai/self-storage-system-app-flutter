import 'package:dio/dio.dart';

class ContractRepository {
  ContractRepository(this._dio);
  final Dio _dio;
  Future<List<Map<String, dynamic>>> list({int page = 1}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/contracts',
      queryParameters: {'page': page, 'limit': 20},
    );
    final d = r.data?['data'];
    final items = d is Map ? d['items'] : d;
    return items is List
        ? items.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/contracts/$id');
    final d = r.data?['data'];
    if (d is! Map<String, dynamic>) {
      throw const FormatException('Invalid contract response');
    }
    return d;
  }

  Future<void> acceptTerms(String id) async {
    await _dio.post(
      '/contracts/$id/customer-sign',
      data: {'termsAccepted': true},
    );
  }

  Future<void> renew(String id, DateTime newEndDate, {String? note}) async {
    await _dio.post(
      '/contracts/$id/renew',
      data: {
        'newEndDate': newEndDate.toIso8601String(),
        if (note?.isNotEmpty == true) 'note': note,
      },
    );
  }
}
