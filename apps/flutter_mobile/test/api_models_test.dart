import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';

void main() {
  group('Reservation backend DTO', () {
    test('parses required check-in fields, physical unit and status', () {
      final reservation = Reservation.fromJson({
        'id': 'r1',
        'reservationCode': 'RS-100',
        'customerId': 'c1',
        'facilityId': 'f1',
        'facilityUnitTypeOfferingId': 'o1',
        'storageUnitId': 'u1',
        'checkInDate': '2026-11-01T00:00:00.000Z',
        'checkInTimeSlot': 'Morning',
        'startDate': '2026-11-01T00:00:00.000Z',
        'rentalDuration': 6,
        'billingUnit': 'month',
        'basePrice': 1200000,
        'depositAmount': 1200000,
        'totalAmount': 7200000,
        'status': 'pending_payment',
        'refundAmount': 0,
        'createdAt': '2026-10-22T00:00:00.000Z',
        'updatedAt': '2026-10-22T00:00:00.000Z',
      });
      expect(reservation.storageUnitId, 'u1');
      expect(reservation.checkInTimeSlot, 'Morning');
      expect(reservation.status, 'pending_payment');
      expect(reservation.depositAmount, 1200000);
    });
  });

  group('Payment backend status', () {
    Payment parse(String status) => Payment.fromJson({
      'id': 'p1',
      'paymentCode': 'PAY-1',
      'purpose': 'reservation_deposit',
      'customerId': 'c1',
      'facilityId': 'f1',
      'reservationId': 'r1',
      'amount': 100,
      'paidAmount': 0,
      'overpaidAmount': 0,
      'method': 'sepay_qr',
      'status': status,
      'createdAt': '2026-10-22T00:00:00.000Z',
      'updatedAt': '2026-10-22T00:00:00.000Z',
    });
    test('only backend terminal statuses stop polling', () {
      expect(parse('pending').isTerminal, isFalse);
      expect(parse('partially_paid').isTerminal, isFalse);
      expect(parse('paid').isTerminal, isTrue);
      expect(parse('expired').isTerminal, isTrue);
      expect(parse('cancelled').isTerminal, isTrue);
    });
    test(
      'missing backend QR stays null',
      () => expect(parse('pending').qrUrl, isNull),
    );
  });
}
