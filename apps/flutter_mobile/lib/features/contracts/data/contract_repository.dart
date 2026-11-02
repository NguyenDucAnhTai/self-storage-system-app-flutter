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

  Future<List<Map<String, dynamic>>> listAll({int limit = 20}) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/contracts',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data?['data'];
      if (data is List) {
        result.addAll(data.whereType<Map<String, dynamic>>());
        break;
      }
      if (data is! Map || data['items'] is! List) {
        throw const FormatException('Invalid contracts list response.');
      }
      result.addAll((data['items'] as List).whereType<Map<String, dynamic>>());
      final pagination = data['pagination'];
      final parsed = pagination is Map
          ? int.tryParse('${pagination['totalPages'] ?? ''}')
          : null;
      totalPages = parsed == null || parsed < page ? page : parsed;
      page++;
    } while (page <= totalPages);
    return result;
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/contracts/$id');
    final d = r.data?['data'];
    if (d is! Map<String, dynamic>) {
      throw const FormatException('Invalid contract response');
    }
    return d;
  }

  /// Reads the server-generated draft contract HTML without changing contract state.
  Future<String> draftTerms(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/contracts/$id/draft-pdf',
    );
    final data = response.data?['data'];
    final html = data is Map ? data['html'] : null;
    if (html is! String || html.trim().isEmpty) {
      throw const FormatException('Draft contract terms are unavailable.');
    }
    return _htmlToText(html);
  }

  static String _htmlToText(String html) => html
      .replaceAll(
        RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'<br\s*/?>|</(p|div|li|h[1-6]|tr)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s+'), '\n')
      .trim();

  Future<void> acceptTerms(String id) async {
    await _dio.post(
      '/contracts/$id/customer-sign',
      data: {'termsAccepted': true},
    );
  }

  Future<Map<String, dynamic>> refunds(
    String contractId, {
    int page = 1,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/refund-requests',
      queryParameters: {
        'contractId': contractId,
        'page': page,
        'limit': 20,
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
      },
    );
    final data = r.data?['data'];
    if (data is! Map<String, dynamic> ||
        data['items'] is! List ||
        data['pagination'] is! Map) {
      throw const FormatException('Invalid refund list response');
    }
    return data;
  }

  Future<Map<String, dynamic>> refundDetail(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/refund-requests/$id');
    final data = r.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid refund response');
    }
    return data;
  }

  Future<Map<String, dynamic>> cancelRefund(String id, String reason) =>
      _postContract(
        '/refund-requests/$id/cancel',
        data: {'cancellationReason': reason.trim()},
      );

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

  Future<Map<String, dynamic>> confirmSettlement(String id) async =>
      _postSettlement('/contracts/$id/settlement/confirm');

  Future<Map<String, dynamic>> disputeSettlement(
    String id,
    String reason,
  ) async {
    if (reason.trim().isEmpty || reason.trim().length > 1000) {
      throw const FormatException('Settlement dispute reason is invalid.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/contracts/$id/settlement/dispute',
      data: {'disputeReason': reason.trim()},
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid settlement response.');
    }
    return data;
  }

  Future<Map<String, dynamic>> _postSettlement(String path) async {
    final response = await _dio.post<Map<String, dynamic>>(path);
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid settlement response.');
    }
    return data;
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
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    final contract = response.data?['data'];
    if (contract is! Map<String, dynamic>) {
      throw const FormatException('Invalid contract response');
    }
    return contract;
  }
}
