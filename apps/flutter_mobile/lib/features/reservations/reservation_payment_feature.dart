import 'package:dio/dio.dart';

import 'data/repositories/reservation_repository.dart';
import '../payments/application/payment_status_tracker.dart';
import '../payments/data/repositories/payment_repository.dart';

/// Feature dependencies use the host app's configured Dio instance.
class ReservationPaymentFeature {
  ReservationPaymentFeature(Dio sharedApiClient)
    : reservations = ReservationRepository(sharedApiClient),
      payments = PaymentRepository(sharedApiClient),
      paymentStatus = PaymentStatusTracker(PaymentRepository(sharedApiClient));

  final ReservationRepository reservations;
  final PaymentRepository payments;
  final PaymentStatusTracker paymentStatus;
}
