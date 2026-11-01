import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mobile/core/providers/app_providers.dart';
import 'package:flutter_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_mobile/features/auth/data/models/auth_user.dart';
import 'package:flutter_mobile/features/notifications/application/notification_providers.dart';
import 'package:flutter_mobile/features/notifications/data/notification_models.dart';
import 'package:flutter_mobile/features/notifications/data/notification_repository.dart';
import 'package:flutter_mobile/features/notifications/presentation/notification_bell.dart';
import 'package:flutter_mobile/features/profile/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('bell opens provider-backed anchored popup and toggles closed', (
    tester,
  ) async {
    final repository = _NotificationRepository(_notifications());
    await _pumpBell(tester, repository);

    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Thông báo thật 1'), findsOneWidget);
    expect(find.text('Thông báo thật 5'), findsOneWidget);
    expect(find.text('Thông báo thật 6'), findsNothing);
    expect(find.text('1 chưa đọc'), findsOneWidget);

    await tester.tap(find.byTooltip('Thông báo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Thông báo'), findsNothing);
    expect(find.text('Home content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside dismisses the overlay', (tester) async {
    await _pumpBell(tester, _NotificationRepository(_notifications()));
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thật 1'), findsOneWidget);

    await tester.tapAt(const Offset(18, 450));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thật 1'), findsNothing);
    expect(find.text('Home content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay is removed when its bell is disposed', (tester) async {
    await _pumpBell(tester, _NotificationRepository(_notifications()));
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thật 1'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: Text('Another route')));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thật 1'), findsNothing);
    expect(find.text('Another route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, empty and retryable error states are shown', (
    tester,
  ) async {
    final completer = Completer<NotificationPage>();
    final repository = _NotificationRepository(_notifications())
      ..pendingPage = completer;
    await _pumpBell(tester, repository);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    completer.complete(_notificationPage(const []));
    repository.pendingPage = null;
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có thông báo nào'), findsOneWidget);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    repository.fetchError = true;
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải thông báo'), findsOneWidget);
    repository.fetchError = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thật 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marking an unread notification updates its state and badge', (
    tester,
  ) async {
    final repository = _NotificationRepository(_notifications());
    await _pumpBell(tester, repository);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Thông báo thật 1'));
    await tester.pumpAndSettle();
    expect(repository.markReadCalls, 1);
    expect(find.text('Nội dung thông báo thật 1'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.byTooltip('Quay lại danh sách'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed mark-read does not update the badge or claim success', (
    tester,
  ) async {
    final repository = _NotificationRepository(_notifications())
      ..markReadError = true;
    await _pumpBell(tester, repository);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông báo thật 1'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Quay lại danh sách'), findsNothing);
    expect(
      find.text('Không thể cập nhật trạng thái thông báo'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup fits narrow width with enlarged text and long content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    final long = _notification(
      id: 'long',
      title: 'Tiêu đề thông báo rất dài ' * 8,
      content: 'Nội dung chi tiết rất dài để kiểm tra việc cắt gọn. ' * 30,
      isRead: true,
    );
    final repository = _NotificationRepository([long]);
    await _pumpBell(tester, repository, textScale: 1.3);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiêu đề thông báo rất dài'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('popup remains fully inside 320, 360 and 510dp viewports', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 360.0, 510.0]) {
      tester.view.physicalSize = Size(width, 760);
      await _pumpBell(tester, _NotificationRepository(_notifications()));
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pumpAndSettle();

      final popupRect = tester.getRect(
        find.byKey(const ValueKey('notification-popup-panel')),
      );
      final bellRect = tester.getRect(find.byTooltip('Thông báo'));
      expect(
        popupRect.left,
        greaterThanOrEqualTo(12),
        reason: '$width dp left edge',
      );
      expect(
        popupRect.right,
        lessThanOrEqualTo(width - 12),
        reason: '$width dp right edge',
      );
      expect(
        popupRect.top,
        greaterThan(bellRect.bottom),
        reason: '$width dp anchor',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('only one popup is open across multiple bell locations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedInAuthController.new),
          notificationRepositoryProvider.overrideWithValue(
            _NotificationRepository(_notifications()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [const NotificationBell(), const NotificationBell()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thông báo').first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thông báo').last);
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thật 1'), findsOneWidget);
    expect(find.text('Home content'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile Notifications menu still opens the full screen', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = _ProfileAdapter();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/notifications',
          builder: (_, _) =>
              const Scaffold(body: Text('Full notifications screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedInAuthController.new),
          notificationRepositoryProvider.overrideWithValue(
            _NotificationRepository(_notifications()),
          ),
          dioProvider.overrideWithValue(dio),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Full notifications screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpBell(
  WidgetTester tester,
  _NotificationRepository repository, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(actions: const [NotificationBell()]),
          body: const Center(child: Text('Home content')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SignedInAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 'customer-test',
    name: 'Customer',
    email: 'customer@example.test',
    role: 'customer',
  );
}

class _NotificationRepository extends NotificationRepository {
  _NotificationRepository(this.items) : super(Dio());

  List<AppNotification> items;
  bool fetchError = false;
  bool markReadError = false;
  Completer<NotificationPage>? pendingPage;
  int markReadCalls = 0;

  @override
  Future<NotificationPage> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
    String? facilityId,
    String? priority,
    String? type,
    String? search,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) {
    if (fetchError) return Future.error(const FormatException('fetch failed'));
    final pending = pendingPage;
    if (pending != null) return pending.future;
    return Future.value(_notificationPage(items.take(limit).toList()));
  }

  @override
  Future<int> getUnreadCount() async =>
      items.where((item) => !item.isRead).length;

  @override
  Future<AppNotification> markAsRead(String id) async {
    markReadCalls++;
    if (markReadError) throw StateError('mark-read failed');
    final index = items.indexWhere((item) => item.id == id);
    final updated = items[index].copyWith(isRead: true, readAt: DateTime.now());
    items = [...items]..[index] = updated;
    return updated;
  }

  @override
  Future<int> markAllAsRead() async {
    items = items
        .map((item) => item.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();
    return items.length;
  }
}

class _ProfileAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'data': {'address': 'Test address'},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

NotificationPage _notificationPage(List<AppNotification> items) =>
    NotificationPage(
      items: items,
      pagination: NotificationPagination(
        page: 1,
        limit: 20,
        totalItems: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        hasNextPage: false,
        hasPrevPage: false,
      ),
    );

List<AppNotification> _notifications() => [
  for (var i = 1; i <= 6; i++)
    _notification(
      id: 'notification-$i',
      title: 'Thông báo thật $i',
      content: 'Nội dung thông báo thật $i',
      isRead: i != 1,
    ),
];

AppNotification _notification({
  required String id,
  required String title,
  required String content,
  required bool isRead,
}) => AppNotification(
  id: id,
  recipientId: 'customer-test',
  title: title,
  content: content,
  type: 'reservation',
  priority: 'normal',
  channels: const ['in_app'],
  isRead: isRead,
  createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
);
