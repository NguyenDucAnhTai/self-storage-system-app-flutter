import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/contracts/data/contract_repository.dart';
import 'package:flutter_mobile/features/contracts/presentation/settlement_screen.dart';

void main() {
  test(
    'settlement and refund APIs use correct paths, bodies and paging',
    () async {
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'data': o.path == '/refund-requests'
                      ? {
                          'items': [],
                          'pagination': {'hasNextPage': false},
                        }
                      : {'id': '1'},
                },
              ),
            );
          },
        ),
      );
      final repo = ContractRepository(dio);
      await repo.confirmSettlement('c1');
      await repo.disputeSettlement('c1', 'incorrect fee');
      await repo.refunds('c1', page: 2);
      await repo.refundDetail('r1');
      await repo.cancelRefund('r1', 'other arrangement');
      expect(calls[0].path, '/contracts/c1/settlement/confirm');
      expect(calls[0].data, isNull);
      expect(calls[1].data, {'disputeReason': 'incorrect fee'});
      expect(calls[2].queryParameters, containsPair('contractId', 'c1'));
      expect(calls[2].queryParameters, containsPair('page', 2));
      expect(calls[3].path, '/refund-requests/r1');
      expect(calls[4].data, {'cancellationReason': 'other arrangement'});
    },
  );
  testWidgets('approved refund shows awaiting payout and cannot be cancelled', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'data': {
                  'id': 'r1',
                  'refundCode': 'RF-1',
                  'reason': 'deposit_settlement',
                  'status': 'approved',
                  'amount': 100000,
                },
              },
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RefundDetailScreen(repo: ContractRepository(dio), id: 'r1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approved · awaiting payout'), findsOneWidget);
    expect(find.text('Cancel refund request'), findsNothing);
    expect(find.text('Payout recorded'), findsNothing);
  });
  testWidgets(
    'completed unconfirmed settlement shows customer actions and all refund reasons',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            final data = o.path == '/refund-requests'
                ? {
                    'items': [
                      {
                        'id': 'r1',
                        'refundCode': 'RF-1',
                        'reason': 'facility_fault',
                        'status': 'pending_approval',
                        'amount': 100,
                      },
                    ],
                    'pagination': {'hasNextPage': false},
                  }
                : {
                    'id': 'c1',
                    'contractCode': 'C-1',
                    'status': 'completed',
                    'depositStatus': 'refunded',
                    'depositAmount': 100,
                    'damageFee': 0,
                    'overdueFee': 0,
                    'refundAmount': 100,
                    'additionalPaymentRequired': 0,
                  };
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {'data': data},
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SettlementScreen(
            repo: ContractRepository(dio),
            contractId: 'c1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirm settlement'), findsOneWidget);
      expect(find.text('Dispute'), findsOneWidget);
      expect(find.textContaining('facility_fault'), findsOneWidget);
      expect(find.textContaining('Check each refund request'), findsOneWidget);
    },
  );
  testWidgets('dispute sends reason and displays backend settlement status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls.add(o);
          final data = o.path == '/refund-requests'
              ? {
                  'items': [],
                  'pagination': {'hasNextPage': false},
                }
              : {
                  'id': 'c1',
                  'contractCode': 'C-1',
                  'status': 'completed',
                  'depositStatus': o.method == 'POST' ? 'disputed' : 'refunded',
                  'depositAmount': 100,
                  'refundAmount': 100,
                  if (o.method == 'POST') 'disputeReason': 'Wrong fee',
                };
          h.resolve(
            Response(requestOptions: o, statusCode: 200, data: {'data': data}),
          );
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettlementScreen(repo: ContractRepository(dio), contractId: 'c1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dispute'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wrong fee');
    await tester.tap(find.text('Submit dispute'));
    await tester.pumpAndSettle();
    expect(calls.last.path, '/contracts/c1/settlement/dispute');
    expect(calls.last.data, {'disputeReason': 'Wrong fee'});
    expect(find.text('Wrong fee'), findsOneWidget);
  });
  testWidgets('pending refund requires a reason and reflects cancellation', (
    tester,
  ) async {
    final calls = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls.add(o);
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'data': {
                  'id': 'r1',
                  'refundCode': 'RF-1',
                  'reason': 'deposit_settlement',
                  'status': o.method == 'POST'
                      ? 'cancelled'
                      : 'pending_approval',
                  'amount': 100,
                },
              },
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RefundDetailScreen(repo: ContractRepository(dio), id: 'r1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel refund request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 3 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Other method');
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(calls.last.data, {'cancellationReason': 'Other method'});
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel refund request'), findsNothing);
  });
}
