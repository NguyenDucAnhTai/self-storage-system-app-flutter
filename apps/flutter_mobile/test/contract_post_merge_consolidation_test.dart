import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mobile/features/contracts/presentation/contracts_screen.dart';
import 'package:flutter_mobile/features/contracts/presentation/contract_detail_route_screen.dart';

void main() {
  testWidgets(
    'contract list opens full detail and detail exposes renewal entry',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      var customerSignedAddendum = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add(options.path);
              if (options.path.endsWith('/customer-sign')) {
                customerSignedAddendum = true;
              }
              final contract = {
                ..._contract,
                'status': 'overdue',
                'addendums': [
                  {
                    'id': 'a1',
                    'type': 'renew',
                    'status': 'draft',
                    'addendumCode': 'ADD-1',
                    'customerSigned': customerSignedAddendum,
                    'staffSigned': false,
                  },
                ],
              };
              final response = options.path == '/contracts'
                  ? {
                      'items': [contract],
                    }
                  : options.path == '/payments'
                  ? {
                      'items': [],
                      'pagination': {
                        'page': 1,
                        'totalPages': 0,
                        'hasNextPage': false,
                      },
                    }
                  : contract;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'data': response},
                ),
              );
            },
          ),
        );
      final router = GoRouter(
        initialLocation: '/contracts',
        routes: [
          GoRoute(
            path: '/contracts',
            builder: (_, _) => ContractsScreen(dio: dio),
          ),
          GoRoute(
            path: '/contracts/:id',
            builder: (_, state) => ContractDetailRouteScreen(
              contractId: state.pathParameters['id']!,
              dio: dio,
            ),
          ),
          GoRoute(
            path: '/payments/:id/view',
            builder: (_, _) => const Scaffold(body: Text('Payment detail')),
          ),
          GoRoute(
            path: '/refunds/:id',
            builder: (_, _) => const Scaffold(body: Text('Refund detail')),
          ),
          GoRoute(
            path: '/contracts/:id/settlement',
            builder: (_, _) => const Scaffold(body: Text('Settlement')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tiến trình hợp đồng'), findsOneWidget);
      expect(find.text('Thanh toán tiền thuê kỳ đầu'), findsWidgets);
      expect(find.text('Gia hạn & phụ lục hợp đồng'), findsOneWidget);
      expect(paths, contains('/contracts/0123456789abcdef01234567'));

      await tester.ensureVisible(find.text('Gia hạn & phụ lục hợp đồng'));
      await tester.tap(find.text('Gia hạn & phụ lục hợp đồng'));
      await tester.pumpAndSettle();
      expect(find.text('Request renewal'), findsOneWidget);
      expect(find.text('Renewal addendums'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm and sign'));
      await tester.tap(find.text('Confirm and sign'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm and sign').last);
      await tester.pumpAndSettle();
      expect(
        paths,
        contains(
          '/contracts/0123456789abcdef01234567/addendums/a1/customer-sign',
        ),
      );
    },
  );
}

final Map<String, dynamic> _contract = {
  'id': '0123456789abcdef01234567',
  'contractCode': 'CTR-TEST',
  'status': 'active',
  'customerSigned': true,
  'staffSigned': true,
  'facility': {'name': 'Cơ sở thử nghiệm'},
  'storageUnit': {'unitNumber': 'A-101', 'status': 'occupied'},
  'startDate': '2026-01-01T00:00:00Z',
  'endDate': '2027-01-01T00:00:00Z',
  'rentalPrice': 100000,
  'billingUnit': 'month',
  'depositAmount': 100000,
  'depositPaidAt': '2026-01-01T00:00:00Z',
  'actualCheckInDate': '2026-01-02T00:00:00Z',
  'addendums': [],
};
