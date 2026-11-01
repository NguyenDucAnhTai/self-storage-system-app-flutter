import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobile/features/storage/data/storage_repository.dart';
import 'package:flutter_mobile/features/storage/presentation/storage_screen.dart';

class Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'items': [
            {'id': '1'},
          ],
          'pagination': {'hasNextPage': true},
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  test(
    'inventory requests include pagination and parse the response envelope',
    () async {
      final adapter = Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final result = await StorageRepository(dio)
          .list('/customer-inventories', page: 2);
      expect(adapter.request!.queryParameters['page'], 2);
      expect(adapter.request!.queryParameters['sortBy'], 'lastMovementAt');
      expect(result.items.single['id'], '1');
      expect(result.hasNextPage, isTrue);
    },
  );

  testWidgets('customer creates a SKU through the screen and shared Dio', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = options.path.endsWith('/summary')
              ? {
                  'totalSkus': 0,
                  'totalQuantity': 0,
                  'totalActiveContracts': 0,
                  'totalStorageUnits': 0,
                  'categoryBreakdown': [],
                  'recentMovements': [],
                }
              : options.method == 'POST'
              ? {'id': 'sku1'}
              : {
                  'items': [],
                  'pagination': {'hasNextPage': false},
                };
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': data},
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: StorageScreen(dio: dio)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(Tab, 'SKUs'));
    await tester.tap(find.widgetWithText(Tab, 'SKUs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add SKU'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'SKU code'),
      'BOX-1',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Box');
    await tester.scrollUntilVisible(
      find.text('Save'),
      400,
      scrollable: find
          .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/customer-skus');
    expect(post.data, containsPair('skuCode', 'BOX-1'));
    expect(post.data, containsPair('name', 'Box'));
    expect(find.text('Add SKU'), findsOneWidget);
  });

  testWidgets('customer can delete and undo a SKU deletion', (tester) async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final sku = {
            'id': 'sku1',
            'name': 'Box',
            'skuCode': 'BOX',
            'status': 'active',
          };
          final data = options.path.endsWith('/summary')
              ? {
                  'totalSkus': 1,
                  'totalQuantity': 0,
                  'totalActiveContracts': 0,
                  'totalStorageUnits': 0,
                  'categoryBreakdown': [],
                  'recentMovements': [],
                }
              : options.path == '/customer-skus'
              ? {
                  'items': [sku],
                  'pagination': {'hasNextPage': false},
                }
              : sku;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': data},
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: StorageScreen(dio: dio)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(Tab, 'SKUs'));
    await tester.tap(find.widgetWithText(Tab, 'SKUs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Box'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete SKU'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(Scaffold).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Delete SKU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete SKU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (r) => r.method == 'DELETE' && r.path == '/customer-skus/sku1',
      ),
      isTrue,
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (r) => r.method == 'POST' && r.path == '/customer-skus/sku1/restore',
      ),
      isTrue,
    );
  });

  testWidgets('inventory details open the storage layout', (tester) async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final item = {
      'id': 'inventory1',
      'storageUnitId': 'unit1',
      'skuId': 'sku1',
      'quantity': 3,
      'availableQuantity': 2,
      'status': 'normal',
      'sku': {'name': 'Box', 'skuCode': 'BOX'},
      'storageUnit': {'unitNumber': 'A1'},
      'facility': {'name': 'Central'},
    };
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = options.path.endsWith('/summary')
              ? {
                  'totalSkus': 1,
                  'totalQuantity': 3,
                  'totalActiveContracts': 1,
                  'totalStorageUnits': 1,
                  'categoryBreakdown': [],
                  'recentMovements': [],
                }
              : options.path == '/customer-inventories'
              ? {
                  'items': [item],
                  'pagination': {'hasNextPage': false},
                }
              : options.path.endsWith('/tree')
              ? {
                  'storageUnit': {'unitNumber': 'A1'},
                  'facility': {'name': 'Central'},
                  'racks': [
                    {'rackCode': 'R1', 'tiers': []},
                  ],
                  'unrackedItems': [],
                }
              : item;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': data},
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: StorageScreen(dio: dio)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Box'));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(Scaffold).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('View storage layout'),
      400,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('View storage layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View storage layout'));
    await tester.pumpAndSettle();
    expect(
      requests.any((r) => r.path == '/customer-inventories/unit/unit1/tree'),
      isTrue,
    );
    expect(find.text('Rack R1'), findsOneWidget);
  });
}
