import 'package:dio/dio.dart';

import '../models/payment.dart';

class PaymentRepository {
  PaymentRepository(this._dio);
  final Dio _dio;

  Future<Payment> createReservationDeposit(String reservationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments',
      data: {'purpose': 'reservation_deposit', 'reservationId': reservationId},
    );
    return Payment.fromJson(_data(response.data));
  }

  Future<Payment> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/payments/$id');
    return Payment.fromJson(_data(response.data));
  }

  /// Lists the authenticated customer's payments. Ownership is derived from
  /// the session by the API; callers must never provide customerId.
  Future<PaymentHistoryPage> getHistoryPage({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments',
      queryParameters: {
        'page': page,
        'limit': limit.clamp(1, 100),
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
      },
    );
    final data = response.data?['data'];
    if (data is! Map) {
      throw const FormatException('Invalid payments list response.');
    }
    return PaymentHistoryPage.fromJson(Map<String, dynamic>.from(data));
  }

  /// Lists only this authenticated customer's matching contract payments.
  /// The backend applies customer ownership from the session and accepts these
  /// documented filters; never send a client-supplied customerId here.
  Future<List<Payment>> listFirstPeriodForContract(String contractId) async {
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(contractId)) {
      throw const FormatException('Invalid contract ID.');
    }
    final payments = <Payment>[];
    var page = 1;
    var totalPages = 1;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments',
        queryParameters: {
          'contractId': contractId,
          'purpose': 'rent_first_period',
          'page': page,
          'limit': 100,
          'sortBy': 'createdAt',
          'sortOrder': 'desc',
        },
      );
      final data = response.data?['data'];
      if (data is! Map) {
        throw const FormatException('Invalid payments list response.');
      }
      final items = data['items'];
      if (items is! List) {
        throw const FormatException('Payments response did not include items.');
      }
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final payment = Payment.fromJson(item);
          if (payment.contractId == contractId &&
              payment.purpose == 'rent_first_period') {
            payments.add(payment);
          }
        }
      }
      final pagination = data['pagination'];
      final parsedTotal = pagination is Map
          ? int.tryParse('${pagination['totalPages'] ?? ''}')
          : null;
      totalPages = parsedTotal == null || parsedTotal < page
          ? page
          : parsedTotal;
      page++;
    } while (page <= totalPages);
    return payments;
  }

  static Map<String, dynamic> _data(Map<String, dynamic>? response) {
    final value = response?['data'];
    if (value is Map<String, dynamic>) return value;
    throw const FormatException(
      'Backend response did not include an object in data.',
    );
  }
}
