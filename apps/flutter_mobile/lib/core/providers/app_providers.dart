import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../../features/reservations/reservation_payment_feature.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dio.close);
  return client;
});
final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
final reservationPaymentProvider = Provider<ReservationPaymentFeature>(
  (ref) => ReservationPaymentFeature(ref.watch(dioProvider)),
);
final sharedDioProvider = dioProvider;
