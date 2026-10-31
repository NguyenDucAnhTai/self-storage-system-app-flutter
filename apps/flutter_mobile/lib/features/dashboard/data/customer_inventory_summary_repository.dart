import 'package:dio/dio.dart';

import 'customer_inventory_summary.dart';

class CustomerInventorySummaryRepository {
  CustomerInventorySummaryRepository(this._dio);

  final Dio _dio;

  Future<CustomerInventorySummary> getSummary() async {
    final response = await _dio.get<dynamic>(
      '/customer-inventories/summary',
    );
    final envelope = response.data;
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const FormatException(
        'The backend response did not include an inventory summary object.',
      );
    }
    return CustomerInventorySummary.fromJson(
      Map<String, dynamic>.from(envelope['data'] as Map),
    );
  }
}
