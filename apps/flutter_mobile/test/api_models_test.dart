import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/reservations/data/models/reservation.dart';
import 'package:flutter_mobile/features/notifications/data/notification_models.dart';
import 'package:flutter_mobile/features/dashboard/data/customer_inventory_summary.dart';

void main() {
  test(
    'customer inventory dashboard summary parses backend metrics and activity',
    () {
      final summary = CustomerInventorySummary.fromJson({
        'totalSkus': 12,
        'totalQuantity': 105.5,
        'totalStorageUnits': 3,
        'totalActiveContracts': 2,
        'categoryBreakdown': [
          {'category': 'Boxes', 'skuCount': 4, 'totalQuantity': 20},
        ],
        'recentMovements': [
          {'movementCode': 'MOV-1', 'type': 'IN', 'quantity': 5},
        ],
      });

      expect(summary.totalSkus, 12);
      expect(summary.totalQuantity, 105.5);
      expect(summary.totalStorageUnits, 3);
      expect(summary.totalActiveContracts, 2);
      expect(summary.categoryBreakdown.single['category'], 'Boxes');
      expect(summary.recentMovements.single['movementCode'], 'MOV-1');
    },
  );

  test(
    'customer inventory dashboard summary rejects missing required metrics',
    () {
      expect(
        () => CustomerInventorySummary.fromJson({}),
        throwsFormatException,
      );
    },
  );

  group('Notification backend DTO', () {
    test('parses notification with nullable fields absent', () {
      final notification = AppNotification.fromJson({
        'id': 'n1',
        'recipientId': 'customer-1',
        'title': 'Reservation updated',
        'content': 'Your reservation changed.',
        'type': 'reservation',
        'priority': 'normal',
        'channels': ['in_app'],
        'isRead': false,
      });
      expect(notification.id, 'n1');
      expect(notification.facilityId, isNull);
      expect(notification.readAt, isNull);
      expect(notification.metadata, isNull);
    });

    test('parses paginated response and pagination flags', () {
      final page = NotificationPage.fromJson({
        'items': [
          {
            'id': 'n1',
            'recipientId': 'customer-1',
            'title': 'Payment received',
            'content': 'Payment details',
            'type': 'payment',
            'priority': 'high',
            'channels': ['in_app', 'email'],
            'isRead': true,
            'readAt': '2026-10-23T10:00:00Z',
            'facilityId': 'facility-1',
            'metadata': {'reservationId': 'reservation-1'},
            'createdAt': '2026-10-23T09:00:00Z',
            'updatedAt': '2026-10-23T10:00:00Z',
          },
        ],
        'pagination': {
          'page': 1,
          'limit': 20,
          'totalItems': 21,
          'totalPages': 2,
          'hasNextPage': true,
          'hasPrevPage': false,
        },
      });
      expect(page.items.single.metadata?['reservationId'], 'reservation-1');
      expect(page.pagination.hasNextPage, isTrue);
      expect(page.pagination.totalItems, 21);
    });
  });

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
