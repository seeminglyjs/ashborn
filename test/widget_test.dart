import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/main.dart';

void main() {
  testWidgets('앱이 Flame GameWidget 을 띄운다', (WidgetTester tester) async {
    await tester.pumpWidget(const AshbornApp());

    expect(find.byType(GameWidget<AshbornGame>), findsOneWidget);
  });
}
