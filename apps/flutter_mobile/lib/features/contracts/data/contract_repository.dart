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
