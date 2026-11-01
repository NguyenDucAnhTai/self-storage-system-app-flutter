import 'package:dio/dio.dart';

class InventoryRequestsRepository {
  InventoryRequestsRepository(this.dio);
  final Dio dio;
  static const root = '/customer-inventories';

  Future<Map<String, dynamic>> _data(Future<Response<dynamic>> request) async {
    final response = await request;
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid inventory request response');
    }
    return data;
  }

  Future<Map<String, dynamic>> list({
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) => _data(
    dio.get(
      '$root/requests',
      queryParameters: {
        'page': page,
        'limit': 20,
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
        ...filters,
      },
    ),
  );
  Future<Map<String, dynamic>> detail(String id) =>
      _data(dio.get('$root/requests/${Uri.encodeComponent(id)}'));
  Future<Map<String, dynamic>> create(
    String type,
    Map<String, dynamic> payload,
  ) => _data(
    dio.post(
      type == 'inbound'
          ? '$root/inbound-requests/pre-advised'
          : '$root/outbound-requests',
      data: payload,
    ),
  );
  Future<Map<String, dynamic>> regenerate(String id) => _data(
    dio.post('$root/requests/${Uri.encodeComponent(id)}/regenerate-otp'),
  );
  Future<Map<String, dynamic>> cancel(String id, String type, String reason) =>
      _data(
        dio.post(
          '$root/$type-requests/${Uri.encodeComponent(id)}/cancel',
          data: {if (reason.isNotEmpty) 'reason': reason},
        ),
      );
  Future<Map<String, dynamic>> confirm(String id) => _data(
    dio.post('$root/inbound-requests/${Uri.encodeComponent(id)}/confirm'),
  );
  Future<Map<String, dynamic>> dispute(String id, String reason) => _data(
    dio.post(
      '$root/inbound-requests/${Uri.encodeComponent(id)}/dispute',
      data: {'disputeReason': reason},
    ),
  );
}
