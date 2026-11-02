import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/customer_care/customer_care.dart';
import 'package:flutter_mobile/features/customer_care/customer_care_screens.dart';

void main() {
  test(
    'support list is customer scoped by session, never query customerId',
    () async {
      RequestOptions? seen;
      final repo = CustomerCareRepository(
        _dio((r) {
          seen = r;
          return {
            'data': {
              'items': [],
              'pagination': {'page': 1},
            },
          };
        }),
      );
      expect(await repo.list('/support-tickets'), isEmpty);
      expect(seen!.path, '/support-tickets');
      expect(seen!.queryParameters, {'page': 1, 'limit': 20});
      expect(seen!.queryParameters.containsKey('customerId'), isFalse);
    },
  );

  test(
    'support creation sends schema fields and empty attachments explicitly',
    () async {
      RequestOptions? seen;
      final repo = CustomerCareRepository(
        _dio((r) {
          seen = r;
          return {
            'data': {'id': 'ticket-1'},
          };
        }),
      );
      await repo.createSupport({
        'category': 'general_inquiry',
        'priority': 'medium',
        'title': 'Help',
        'description': 'Need help',
        'attachments': [],
      });
      expect(seen!.method, 'POST');
      expect(seen!.path, '/support-tickets');
      expect(seen!.data['attachments'], isEmpty);
      expect(seen!.data.containsKey('customerId'), isFalse);
    },
  );

  testWidgets(
    'incident report creation clearly remains unavailable without verified upload',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IncidentCreateBlockedScreen()),
      );
      expect(find.text('Chưa thể gửi báo cáo sự cố'), findsOneWidget);
      expect(
        find.textContaining('ít nhất một ảnh chứng cứ dạng URL'),
        findsOneWidget,
      );
    },
  );

  testWidgets('support form validates before any POST', (tester) async {
    var posts = 0;
    final repo = CustomerCareRepository(
      _dio((r) {
        if (r.method == 'POST') posts++;
        return {
          'data': {'id': 't'},
        };
      }),
    );
    await tester.pumpWidget(MaterialApp(home: SupportCreateScreen(repo: repo)));
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    expect(find.text('Nhập ít nhất 3 ký tự.'), findsOneWidget);
  });

  testWidgets(
    'unknown support POST outcome blocks duplicate retry pending review',
    (tester) async {
      var posts = 0;
      final repo = CustomerCareRepository(
        _dio((r) {
          if (r.method == 'POST') {
            posts++;
            throw DioException(
              requestOptions: r,
              type: DioExceptionType.connectionTimeout,
            );
          }
          return {
            'data': {'items': []},
          };
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SupportCreateScreen(repo: repo)),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tiêu đề'),
        'Cần trợ giúp',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nội dung'),
        'Xin hướng dẫn giúp tôi',
      );
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Mở danh sách yêu cầu'), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('Gửi yêu cầu'),
              matching: find.byType(FilledButton),
            )
            .first,
      );
      expect(submit.onPressed, isNull);
    },
  );

  testWidgets('support cancellation is exposed only for pending state', (
    tester,
  ) async {
    var posts = 0;
    final repo = CustomerCareRepository(
      _dio((r) {
        if (r.method == 'POST') posts++;
        return {'data': _ticket(status: 'completed')};
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CareDetailScreen(repo: repo, id: 't1', incident: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hủy yêu cầu'), findsNothing);
    expect(posts, 0);
  });

  testWidgets(
    'resolved incident shows close action and server-state timeline',
    (tester) async {
      var posts = 0;
      final repo = CustomerCareRepository(
        _dio((r) {
          if (r.method == 'POST') posts++;
          return {'data': _incident(status: 'resolved')};
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CareDetailScreen(repo: repo, id: 'i1', incident: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tiến trình xử lý'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Đóng sự cố'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đóng sự cố'), findsOneWidget);
      expect(posts, 0);
    },
  );
}

Map<String, dynamic> _ticket({required String status}) => {
  'id': 't1',
  'ticketCode': 'SUP-1',
  'category': 'general_inquiry',
  'priority': 'medium',
  'title': 'Cần hỗ trợ',
  'description': 'Nội dung cần trợ giúp',
  'attachments': [],
  'status': status,
  'createdAt': '2026-10-30T10:00:00Z',
  'updatedAt': '2026-10-30T10:00:00Z',
};
Map<String, dynamic> _incident({required String status}) => {
  'id': 'i1',
  'incidentCode': 'INC-1',
  'facility': {'id': 'f1', 'name': 'Cơ sở A'},
  'reporter': 'customer',
  'reporterRole': 'CUSTOMER',
  'category': 'other',
  'severity': 'low',
  'title': 'Kiểm tra kho',
  'description': 'Mô tả sự cố',
  'images': ['https://example.test/evidence.jpg'],
  'status': status,
  'putUnitUnderMaintenance': false,
  'requiresRelocation': false,
  'resolution': {
    'resolutionNotes': 'Đã xử lý',
    'repairCost': 0,
    'liableParty': 'facility',
    'damageFee': 0,
    'staffEvidenceImages': [],
    'resolvedBy': 'staff',
    'resolvedAt': '2026-10-30T11:00:00Z',
  },
  'createdAt': '2026-10-30T10:00:00Z',
  'updatedAt': '2026-10-30T11:00:00Z',
};

Dio _dio(Map<String, dynamic> Function(RequestOptions) respond) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _Adapter(respond);

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
