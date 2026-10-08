import 'package:ashborn/data/characters.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/main.dart';
import 'package:ashborn/ui/screens/character_select_screen.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:ashborn/ui/screens/splash_screen.dart';
import 'package:ashborn/ui/screens/title_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 가로 모드 휴대폰(약 19.5:9)과 데스크톱 창 크기.
const phoneLandscape = Size(844, 390);
const desktop = Size(1280, 720);

void useScreen(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 새 화면은 첫 프레임을 화면 밖에서 준비하므로 한 프레임 더 진행한다.
Future<void> settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  for (final size in [phoneLandscape, desktop]) {
    testWidgets('스플래시 → 메인 → 캐릭터 선택 → 게임 (${size.width.toInt()}x'
        '${size.height.toInt()})', (tester) async {
      useScreen(tester, size);
      await tester.pumpWidget(const AshbornApp());
      expect(find.byType(SplashScreen), findsOneWidget);

      await settle(tester, SplashScreen.duration.inMilliseconds + 100);
      await settle(tester);
      expect(find.byType(TitleScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('title-start')));
      await settle(tester);
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
      for (final c in Roster.all) {
        expect(find.text(c.name), findsOneWidget);
      }

      await tester.tap(find.text(Roster.hunter.name));
      await settle(tester, 300);
      await tester.tap(find.byKey(const Key('depart')));
      await settle(tester);

      final screen = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(screen.character, Roster.hunter);
    });
  }

  testWidgets('스플래시는 탭하면 건너뛴다', (tester) async {
    await tester.pumpWidget(const AshbornApp());
    await settle(tester, 300);

    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    expect(find.byType(TitleScreen), findsOneWidget);
  });

  testWidgets('죽으면 게임 오버가 뜨고 다시 일어서면 런이 초기화된다', (tester) async {
    useScreen(tester, phoneLandscape);
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(character: Roster.knight)),
    );
    await settle(tester, 100);

    final game = tester
        .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
        .game!;
    expect(find.text('00:00'), findsOneWidget);

    game.world.player.takeDamage(10000);
    await tester.pump();

    expect(game.paused, isTrue);
    expect(find.text('재가 되었다'), findsOneWidget);

    await tester.tap(find.text('다시 일어서기'));
    await settle(tester, 100);

    expect(game.paused, isFalse);
    expect(find.text('재가 되었다'), findsNothing);
    expect(game.world.player.isDead, isFalse);
    expect(game.stats.hp.value, Roster.knight.maxHp);
  });
}
