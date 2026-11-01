import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/contracts/data/contract_repository.dart';
import 'package:flutter_mobile/features/contracts/presentation/contract_settlement_screen.dart';
import 'package:flutter_mobile/features/refunds/data/refund_repository.dart';
import 'package:flutter_mobile/features/refunds/data/refund_request.dart';

void main() {
  test(
    'settlement confirm uses verified POST path without invented body',
    () async {
      RequestOptions? request;
      final dio = _dio((options) {
        request = options;
        return {'data': _contract('completed')};
      });
      final result = await ContractRepository(dio)
          .confirmSettlement('0123456789abcdef01234567');
      expect(request?.method, 'POST');
      expect(
        request?.path,
        '/contracts/0123456789abcdef01234567/settlement/confirm',
      );
      expect(request?.data, isNull);
      expect(result['settlementConfirmedAt'], isNotNull);
    },
  );

  test(
    'settlement dispute sends required reason and validates before request',
    () async {
      RequestOptions? request;
      final dio = _dio((options) {
        request = options;
        return {'data': _contract('completed')};
      });
      final repository = ContractRepository(dio);
      await expectLater(
        repository.disputeSettlement('0123456789abcdef01234567', '  '),
        throwsFormatException,
      );
      expect(request, isNull);
      await repository.disputeSettlement(
        '0123456789abcdef01234567',
        'Chưa đồng ý mức phí',
      );
      expect(request?.data, {'disputeReason': 'Chưa đồng ý mức phí'});
    },
  );

  testWidgets(
    'settlement action only appears for eligible completed contract',
    (tester) async {
      final dio = _dio((options) => {'data': _contract('active')});
      await tester.pumpWidget(
        MaterialApp(
          home: ContractSettlementScreen(
            contractId: '0123456789abcdef01234567',
            dio: dio,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận quyết toán'), findsNothing);
      expect(
        find.textContaining('chỉ khả dụng khi hợp đồng đã hoàn tất'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'refund cancel validates reason locally and maps server response',
    () async {
      RequestOptions? request;
      final dio = _dio((options) {
        request = options;
        return {'data': _refundJson(status: 'cancelled')};
      });
      final repository = RefundRepository(dio);
      await expectLater(
        repository.cancel('0123456789abcdef01234567', 'x'),
        throwsFormatException,
      );
      expect(request, isNull);
      final result = await repository.cancel(
        '0123456789abcdef01234567',
        'Đã đổi ý',
      );
      expect(request?.method, 'POST');
      expect(request?.data, {'cancellationReason': 'Đã đổi ý'});
      expect(result.status, 'cancelled');
    },
  );

  test('refund page parses documented pagination and only pending approval is cancellable', () {
    final pending = RefundRequest.fromJson(
      _refundJson(status: 'pending_approval'),
    );
    final approved = RefundRequest.fromJson(_refundJson(status: 'approved'));
    expect(pending.canCancel, isTrue);
    expect(approved.canCancel, isFalse);
    final page = RefundPage.fromJson({
      'items': [_refundJson()],
      'pagination': {'page': 1, 'totalPages': 2, 'hasNextPage': true},
    });
    expect(page.hasNextPage, isTrue);
    expect(page.items.single.amount, 24000);
  });
}

Map<String, dynamic> _contract(String status) => {
  'id': '0123456789abcdef01234567',
  'contractCode': 'CTR-1',
  'status': status,
  'depositAmount': 94000,
  'depositStatus': 'refunded',
  'damageFee': 1000,
  'overdueFee': 2000,
  'forfeitedAmount': 0,
  'refundAmount': 91000,
  'additionalPaymentRequired': 0,
  'settlementConfirmedAt': status == 'completed'
      ? '2026-10-30T00:00:00Z'
      : null,
};

Map<String, dynamic> _refundJson({String status = 'pending_approval'}) => {
  'id': '0123456789abcdef01234567',
  'refundCode': 'RF-1',
  'reservationId': null,
  'contractId': 'abcdefabcdefabcdefabcdef',
  'paymentId': null,
  'facility': {'id': 'facility-id', 'name': 'Cơ sở A'},
  'customer': {'id': 'customer-id'},
  'amount': 24000,
  'reason': 'deposit_settlement',
  'status': status,
  'refundBankName': null,
  'refundAccountNumberMasked': null,
  'refundAccountHolder': null,
  'referenceCode': null,
  'proofImageUrl': null,
  'rejectionReason': null,
  'cancellationReason': null,
  'note': null,
  'requestedBy': {'id': 'customer-id'},
  'requestedAt': '2026-10-30T00:00:00Z',
  'approvedBy': null,
  'approvedAt': null,
  'rejectedBy': null,
  'rejectedAt': null,
  'paidBy': null,
  'paidAt': null,
  'cancelledBy': null,
  'cancelledAt': null,
  'createdAt': '2026-10-30T00:00:00Z',
  'updatedAt': '2026-10-30T00:00:00Z',
};

Dio _dio(Map<String, dynamic> Function(RequestOptions) response) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _Adapter(response);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Map<String, dynamic> Function(RequestOptions) respond;
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
