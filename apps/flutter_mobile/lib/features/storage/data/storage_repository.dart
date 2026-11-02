import 'package:dio/dio.dart';

class StoragePage {
  StoragePage(this.items, this.hasNextPage);
  final List<Map<String, dynamic>> items;
  final bool hasNextPage;
}

class StorageRepository {
  StorageRepository(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> get(String path) async {
    final response = await dio.get<Map<String, dynamic>>(path);
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid response');
    }
    return data;
  }

  Future<StoragePage> list(
    String path, {
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {
        'page': page,
        'limit': 20,
        'sortBy': path == '/customer-inventories'
            ? 'lastMovementAt'
            : 'createdAt',
        'sortOrder': 'desc',
        ...filters,
      },
    );
    final data = response.data?['data'];
    if (data is! Map || data['items'] is! List || data['pagination'] is! Map) {
      throw const FormatException('Invalid paginated response');
    }
    return StoragePage(
      (data['items'] as List).whereType<Map<String, dynamic>>().toList(),
      (data['pagination'] as Map)['hasNextPage'] == true,
    );
  }

  Future<void> saveSku(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await dio.post('/customer-skus', data: data);
    } else {
      await dio.patch('/customer-skus/$id', data: data);
    }
  }

  Future<void> deleteSku(String id) async => dio.delete('/customer-skus/$id');
  Future<void> restoreSku(String id) async =>
      dio.post('/customer-skus/$id/restore');
}
