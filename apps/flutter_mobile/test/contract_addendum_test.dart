import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobile/features/contracts/data/contract_repository.dart';
import 'package:flutter_mobile/features/contracts/presentation/contracts_screen.dart';

void main() {
  test('renewal, signature and cancellation use addendum API and return updated contract', () async {
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
                'data': {'id': 'c1', 'addendums': []},
              },
            ),
          );
        },
      ),
    );
    final repo = ContractRepository(dio);
    expect(
      (await repo.renew('c1', DateTime.utc(2028), note: 'hello'))['id'],
      'c1',
    );
    await repo.signAddendum('c1', 'a1');
    await repo.cancelAddendum('c1', 'a1', 'changed plans');
    expect(calls[0].path, '/contracts/c1/addendums');
    expect(calls[0].data, {
      'type': 'renew',
      'newEndDate': '2028-01-01T00:00:00.000Z',
      'notes': 'hello',
    });
    expect(calls[1].path, '/contracts/c1/addendums/a1/customer-sign');
    expect(calls[1].data, {'termsAccepted': true});
    expect(calls[2].path, '/contracts/c1/addendums/a1/cancel');
    expect(calls[2].data, {'cancellationReason': 'changed plans'});
  });

  testWidgets(
    'overdue contract allows renewal and customer signature updates the addendum',
    (tester) async {
      var signed = false;
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o);
            if (o.path.endsWith('/customer-sign')) signed = true;
            final contract = {
              'id': 'c1',
              'contractCode': 'C-001',
              'status': 'overdue',
              'customerSigned': true,
              'endDate': '2025-01-01T00:00:00Z',
              'addendums': [
                {
                  'id': 'a1',
                  'type': 'renew',
                  'status': 'draft',
                  'addendumCode': 'A-001',
                  'customerSigned': signed,
                  'staffSigned': false,
                },
              ],
            };
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'data': o.path == '/contracts'
                      ? {
                          'items': [contract],
                        }
                      : contract,
                },
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ContractsScreen(dio: dio)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C-001'));
      await tester.pumpAndSettle();
      expect(find.text('Request renewal'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm and sign'));
      await tester.tap(find.text('Confirm and sign'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm and sign').last);
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (r) => r.path == '/contracts/c1/addendums/a1/customer-sign',
        ),
        isTrue,
      );
      expect(find.text('Customer signed: Yes'), findsOneWidget);
      expect(find.text('Confirm and sign'), findsNothing);
    },
  );
}
