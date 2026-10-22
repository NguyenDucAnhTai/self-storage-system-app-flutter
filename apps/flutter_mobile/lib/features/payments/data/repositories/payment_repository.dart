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

  static Map<String, dynamic> _data(Map<String, dynamic>? response) {
    final value = response?['data'];
    if (value is Map<String, dynamic>) return value;
    throw const FormatException(
      'Backend response did not include an object in data.',
    );
  }
}
