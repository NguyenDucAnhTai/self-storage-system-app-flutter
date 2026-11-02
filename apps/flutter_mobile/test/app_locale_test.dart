import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mobile/app/router.dart';
import 'package:flutter_mobile/main.dart';

void main() {
  testWidgets(
    'app date picker localization uses Vietnamese instead of English',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Builder(
              builder: (context) => Text(
                MaterialLocalizations.of(context)
                    .formatFullDate(DateTime(2026, 11, 3)),
                key: const ValueKey('localized-date'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appRouterProvider.overrideWithValue(router)],
          child: const StorageHubApp(),
        ),
      );
      await tester.pumpAndSettle();
      final rendered = tester
          .widget<Text>(find.byKey(const ValueKey('localized-date')))
          .data!;
      expect(rendered.toLowerCase(), contains('tháng'));
      expect(rendered, isNot(contains('Nov')));
      expect(rendered, isNot(contains('Tue')));
    },
  );
}
