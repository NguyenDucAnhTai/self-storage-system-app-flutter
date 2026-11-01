import 'package:dio/dio.dart';

class ContractRepository {
  ContractRepository(this._dio);
  final Dio _dio;
  Future<List<Map<String, dynamic>>> list({int page = 1}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/contracts',
      queryParameters: {
        'page': page,
        'limit': 20,
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
      },
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

  Future<Map<String, dynamic>> renew(
    String id,
    DateTime newEndDate, {
    String? note,
  }) async {
    return _postContract(
      '/contracts/$id/addendums',
      data: {
        'type': 'renew',
        'newEndDate': newEndDate.toIso8601String(),
        if (note?.trim().isNotEmpty == true) 'notes': note!.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> signAddendum(String id, String addendumId) =>
      _postContract(
        '/contracts/$id/addendums/$addendumId/customer-sign',
        data: {'termsAccepted': true},
      );

  Future<Map<String, dynamic>> cancelAddendum(
    String id,
    String addendumId,
    String reason,
  ) => _postContract(
    '/contracts/$id/addendums/$addendumId/cancel',
    data: {'cancellationReason': reason.trim()},
  );

  Future<Map<String, dynamic>> _postContract(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    final contract = response.data?['data'];
    if (contract is! Map<String, dynamic>) {
      throw const FormatException('Invalid contract response');
    }
    return contract;
  }
}
