import 'package:flutter_test/flutter_test.dart';

import 'package:flappy_bird/main.dart';

void main() {
  testWidgets('Startbildschirm zeigt Titel und Startaufforderung',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FlappyBirdApp());

    expect(find.text('Flappy Bird'), findsOneWidget);
    expect(find.text('Tippen zum Starten'), findsOneWidget);
  });

  testWidgets('Tippen startet das Spiel und blendet den Titel aus',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FlappyBirdApp());

    await tester.tap(find.text('Tippen zum Starten'));
    await tester.pump();

    expect(find.text('Tippen zum Starten'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });
}
