import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/payments/application/payment_history_provider.dart';
import 'package:flutter_mobile/features/payments/data/models/payment.dart';
import 'package:flutter_mobile/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_mobile/features/payments/presentation/screens/payment_history_screen.dart';
import 'package:flutter_mobile/core/theme/app_theme.dart';

void main() {
  test(
    'payment history uses paginated GET without customer identifier',
    () async {
      RequestOptions? seen;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _Adapter((options) {
          seen = options;
          return {
            'data': {
              'items': [_paymentJson()],
              'pagination': {
                'page': 1,
                'limit': 20,
                'totalItems': 1,
                'totalPages': 1,
                'hasNextPage': false,
                'hasPrevPage': false,
              },
            },
          };
        });

      final page = await PaymentRepository(dio).getHistoryPage();
      expect(seen?.method, 'GET');
      expect(seen?.path, '/payments');
      expect(seen?.queryParameters, containsPair('page', 1));
      expect(seen?.queryParameters, containsPair('limit', 20));
      expect(seen?.queryParameters.containsKey('customerId'), isFalse);
      expect(page.items.single.facility?.name, 'Cơ sở A');
      expect(page.items.single.confirmedBy?.name, 'Nhân viên');
      expect(page.items.single.overpaidAmount, 5);
      expect(page.items.single.proofImageUrl, 'https://example.test/proof.png');
    },
  );

  test('payment model handles nullable fields and unknown enums safely', () {
    final payment = Payment.fromJson({
      'id': 'payment-1',
      'paymentCode': 'PAY-1',
      'purpose': 'future_purpose',
      'amount': 100,
      'paidAmount': 0,
      'method': 'new_method',
      'status': 'new_status',
    });
    expect(payment.createdAt, isNull);
    expect(payment.updatedAt, isNull);
    expect(payment.facility, isNull);
    expect(payment.confirmedAt, isNull);
  });

  testWidgets('history renders backend payment cards and Vietnamese labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentHistoryRepositoryProvider.overrideWithValue(_Repository()),
        ],
        child: const MaterialApp(home: PaymentHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử thanh toán'), findsOneWidget);
    expect(find.text('Tiền cọc đặt kho'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsWidgets);
    expect(find.text('Cơ sở A'), findsOneWidget);
    expect(find.textContaining('123.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filter chips have readable selected and unselected colors and combine filters',
    (tester) async {
      final payments = [
        Payment.fromJson(_paymentJson()),
        Payment.fromJson({
          ..._paymentJson(),
          'id': '1123456789abcdef01234567',
          'paymentCode': 'PAY-RENT',
          'purpose': 'rent_first_period',
          'status': 'pending',
          'paidAmount': 0,
        }),
        Payment.fromJson({
          ..._paymentJson(),
          'id': '2123456789abcdef01234567',
          'paymentCode': 'PAY-CANCELLED',
          'purpose': 'contract_deposit',
          'status': 'cancelled',
        }),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentHistoryRepositoryProvider.overrideWithValue(
              _Repository(payments: payments),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PaymentHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final allStatus = find.ancestor(
        of: find.text('Tất cả').first,
        matching: find.byType(ChoiceChip),
      );
      final unselectedStatus = find.ancestor(
        of: find.text('Đã thanh toán').first,
        matching: find.byType(ChoiceChip),
      );
      final selected = tester.widget<ChoiceChip>(allStatus.first);
      final unselected = tester.widget<ChoiceChip>(unselectedStatus.first);
      expect(selected.selected, isTrue);
      expect(selected.selectedColor, AppTheme.primaryEmerald);
      expect(selected.labelStyle?.color, Colors.white);
      expect(selected.checkmarkColor, Colors.white);
      expect(unselected.selected, isFalse);
      expect(unselected.backgroundColor, Colors.white);
      expect(unselected.labelStyle?.color, AppTheme.primaryText);
      final purposeChoice = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Tiền thuê'),
      );
      expect(purposeChoice.selected, isFalse);
      expect(purposeChoice.backgroundColor, Colors.white);
      expect(purposeChoice.labelStyle?.color, AppTheme.primaryText);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang xử lý'));
      await tester.pumpAndSettle();
      final statusChoice = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Đang xử lý'),
      );
      expect(statusChoice.selected, isTrue);
      expect(statusChoice.labelStyle?.color, Colors.white);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tiền thuê'));
      await tester.pumpAndSettle();
      final selectedPurpose = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Tiền thuê'),
      );
      expect(selectedPurpose.selected, isTrue);
      expect(selectedPurpose.labelStyle?.color, Colors.white);
      expect(selectedPurpose.checkmarkColor, Colors.white);
      expect(find.text('PAY-RENT'), findsOneWidget);
      expect(find.text('PAY-1'), findsNothing);
      expect(find.text('PAY-CANCELLED'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('payment filter rows scroll horizontally on narrow screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentHistoryRepositoryProvider.overrideWithValue(_Repository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PaymentHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái'), findsOneWidget);
      expect(find.text('Khoản thu'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });
}

Map<String, dynamic> _paymentJson() => {
  'id': '0123456789abcdef01234567',
  'paymentCode': 'PAY-1',
  'purpose': 'reservation_deposit',
  'reservationId': 'abcdefabcdefabcdefabcdef',
  'customerId': 'customer-id',
  'facilityId': 'facility-id',
  'amount': 123000,
  'paidAmount': 123000,
  'overpaidAmount': 5,
  'method': 'sepay_qr',
  'status': 'paid',
  'confirmedBy': {'id': 'staff-id', 'name': 'Nhân viên'},
  'confirmedAt': '2026-10-30T05:00:00Z',
  'proofImageUrl': 'https://example.test/proof.png',
  'facility': {'id': 'facility-id', 'name': 'Cơ sở A', 'city': 'Hà Nội'},
  'createdAt': '2026-10-30T04:00:00Z',
  'updatedAt': '2026-10-30T05:00:00Z',
  'paidAt': '2026-10-30T05:00:00Z',
};

class _Repository extends PaymentRepository {
  _Repository({List<Payment>? payments})
    : payments = payments ?? [Payment.fromJson(_paymentJson())],
      super(Dio());
  final List<Payment> payments;
  @override
  Future<PaymentHistoryPage> getHistoryPage({
    int page = 1,
    int limit = 20,
  }) async => PaymentHistoryPage(
    items: payments,
    page: 1,
    limit: 20,
    totalItems: 1,
    totalPages: 1,
    hasNextPage: false,
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Map<String, dynamic> Function(RequestOptions options) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(respond(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}
