import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mobile/main.dart';

void main() {
  testWidgets('shows the StorageHub starter screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StorageHubApp());

    expect(find.text('StorageHub'), findsOneWidget);
  });
}
