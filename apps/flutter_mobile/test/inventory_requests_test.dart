import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_mobile/features/inventory_requests/data/inventory_requests_repository.dart';
import 'package:flutter_mobile/features/inventory_requests/presentation/inventory_requests_screen.dart';

void main() {
  test('customer requests use correct routes, filters and bodies', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          requests.add(o);
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'data': {'id': 'r1'},
              },
            ),
          );
        },
      ),
    );
    final repo = InventoryRequestsRepository(dio);
    await repo.list(page: 2, filters: {'status': 'pending', 'type': 'inbound'});
    await repo.create('outbound', {
      'contractId': 'c1',
      'items': [
        {'skuId': 's1', 'quantity': 2, 'storageRackId': 'r', 'rackTierId': 't'},
      ],
    });
    await repo.create('inbound', {
      'contractId': 'c1',
      'items': [
        {'skuId': 's1', 'quantity': 3},
      ],
    });
    await repo.regenerate('r1');
    await repo.cancel('r1', 'outbound', 'reason');
    await repo.confirm('r1');
    await repo.dispute('r1', 'damaged goods');
    expect(requests[0].queryParameters, containsPair('page', 2));
    expect(requests[0].queryParameters, containsPair('sortBy', 'createdAt'));
    expect(requests[1].path, '/customer-inventories/outbound-requests');
    expect(
      requests[2].path,
      '/customer-inventories/inbound-requests/pre-advised',
    );
    expect(
      requests[3].path,
      '/customer-inventories/requests/r1/regenerate-otp',
    );
    expect(
      requests[4].path,
      '/customer-inventories/outbound-requests/r1/cancel',
    );
    expect(requests[4].data, {'reason': 'reason'});
    expect(
      requests[5].path,
      '/customer-inventories/inbound-requests/r1/confirm',
    );
    expect(requests[6].data, {'disputeReason': 'damaged goods'});
    expect(requests.every((r) => !r.headers.containsKey('x-user-id')), isTrue);
  });

  testWidgets(
    'staff-assisted inbound presents confirm and dispute only while awaiting confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InventoryRequestsRepository(Dio());
      await tester.pumpWidget(
        MaterialApp(
          home: RequestDetailScreen(
            repo: repo,
            id: 'r1',
            initial: {
              'id': 'r1',
              'requestCode': 'R1',
              'type': 'inbound',
              'status': 'pending_confirmation',
              'items': [],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirm receipt'), findsOneWidget);
      expect(find.text('Dispute'), findsOneWidget);
      expect(find.text('Regenerate OTP'), findsNothing);
    },
  );

  testWidgets(
    'expired pending request does not show credentials or regenerate action',
    (tester) async {
      final repo = InventoryRequestsRepository(Dio());
      await tester.pumpWidget(
        MaterialApp(
          home: RequestDetailScreen(
            repo: repo,
            id: 'r1',
            initial: {
              'id': 'r1',
              'requestCode': 'R1',
              'type': 'outbound',
              'status': 'pending',
              'expiresAt': '2020-01-01T00:00:00Z',
              'pickupQrPayload': 'PICKUP:R1:secret',
              'rawOtpCode': '123456',
              'items': [],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('123456'), findsNothing);
      expect(find.text('Regenerate OTP'), findsNothing);
    },
  );
  testWidgets(
    'credentials disappear when a pending request expires on screen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final expiry = DateTime.now().add(const Duration(seconds: 2));
      final repo = InventoryRequestsRepository(Dio());
      await tester.pumpWidget(
        MaterialApp(
          home: RequestDetailScreen(
            repo: repo,
            id: 'r1',
            initial: {
              'id': 'r1',
              'requestCode': 'R1',
              'type': 'outbound',
              'status': 'pending',
              'expiresAt': expiry.toIso8601String(),
              'pickupQrPayload': 'PICKUP:R1:secret',
              'rawOtpCode': '123456',
              'items': [],
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('123456'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('123456'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
    },
  );
}
