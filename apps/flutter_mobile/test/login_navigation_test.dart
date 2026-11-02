import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/core/network/api_client.dart';
import 'package:flutter_mobile/core/providers/app_providers.dart';
import 'package:flutter_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('failed login stays on form and shows the backend error', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          h.reject(
            DioException(
              requestOptions: o,
              response: Response(
                requestOptions: o,
                statusCode: 401,
                data: {'message': 'Invalid credentials'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWith((ref) => client)],
        child: const StorageHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'badpassword',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid credentials'), findsOneWidget);
    expect(find.text('user@example.test'), findsOneWidget);
  });
  testWidgets('successful login opens the customer screen', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final data = o.path == '/auth/login'
              ? {
                  'user': {
                    'id': 'c1',
                    'name': 'Customer',
                    'email': 'user@example.test',
                    'role': 'customer',
                  },
                  'tokens': {
                    'accessToken': 'access',
                    'refreshToken': 'refresh',
                  },
                }
              : {'items': []};
          h.resolve(
            Response(requestOptions: o, statusCode: 200, data: {'data': data}),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWith((ref) => client)],
        child: const StorageHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsWidgets);
  });
}
