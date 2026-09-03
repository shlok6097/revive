import 'package:flutter_test/flutter_test.dart';
import 'package:revive/app/app.dart';

void main() {
  testWidgets('App smoke test loads root ReviveApp widget', (WidgetTester tester) async {
    await tester.pumpWidget(const ReviveApp());
    expect(find.byType(ReviveApp), findsOneWidget);
  });
}
