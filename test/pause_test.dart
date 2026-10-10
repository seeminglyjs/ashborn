import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/passives.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 캐릭터 선택 자리(첫 라우트) 위에 게임 화면을 띄운다. 런을 끝내면 그리로 돌아가는지 보려고.
Future<AshbornGame> openGame(
  WidgetTester tester, {
  Inventory? inventory,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProfileScope(
      profile: Profile(inventory: inventory),
      child: MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('캐릭터 선택 자리')),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => const GameScreen(character: Roster.witch),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return tester
      .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
      .game!;
}

/// 안드로이드 뒤로 가기 버튼.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pump();
}

final pauseMenu = find.byKey(const Key('pause-resume'));

void main() {
  testWidgets('HUD 오른쪽 위에는 48dp 이상의 일시정지 버튼 하나만 있다', (tester) async {
    await openGame(tester);

    expect(find.byKey(const Key('open-settings')), findsNothing);
    expect(find.byKey(const Key('open-equipment')), findsNothing);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.backpack), findsNothing);

    final size = tester.getSize(find.byKey(const Key('open-pause')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('일시정지 버튼을 누르면 멈추고 현황을 보여 주며, 계속하기로만 다시 돈다', (tester) async {
    final game = await openGame(tester);
    game.stats.kills.value = 7;

    await tester.tap(find.byKey(const Key('open-pause')));
    await tester.pump();

    expect(game.paused, isTrue);
    expect(find.text('일시정지'), findsOneWidget);
    for (final key in [
      'pause-resume',
      'pause-build',
      'pause-equipment',
      'pause-settings',
      'pause-quit',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    final status = tester.widget<Text>(find.byKey(const Key('pause-status')));
    expect(status.data, contains('처치  7'));
    expect(find.textContaining(game.world.stage.name), findsWidgets);

    // 장비를 열었다 닫아도 멈춘 채 메뉴로 돌아온다.
    await tester.tap(find.byKey(const Key('pause-equipment')));
    await tester.pump();
    expect(find.byKey(const Key('close-equipment')), findsOneWidget);
    expect(pauseMenu, findsNothing);
    await tester.tap(find.byKey(const Key('close-equipment')));
    await tester.pump();
    expect(pauseMenu, findsOneWidget);
    expect(game.paused, isTrue);

    await tester.tap(pauseMenu);
    await tester.pump();
    expect(game.paused, isFalse);
    expect(pauseMenu, findsNothing);
  });

  testWidgets('카드 · 은총: 고른 무기 · 패시브와 받은 은총을 한눈에 보고, 닫으면 메뉴로 돌아온다', (
    tester,
  ) async {
    final game = await openGame(tester);
    final player = game.world.player;
    final start = player.weapons.first.id;
    player
      ..gainWeapon(start)
      ..gainPassive(PassiveId.fury)
      ..gainPassive(PassiveId.fury);
    final grace = Fate(FateCard.sharpEmber, FateCard.sharpEmber.minRarity);
    game.progress
      ..recordClear(Stage.first)
      ..takeGrace(Stage.first, grace);

    await tester.tap(find.byKey(const Key('open-pause')));
    await tester.pump();
    // 메뉴에도 아이콘 줄로 바로 보인다.
    expect(find.byKey(const Key('pause-build-strip')), findsOneWidget);
    expect(find.text('은총 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pause-build')));
    await tester.pump();
    expect(pauseMenu, findsNothing);
    expect(game.paused, isTrue);
    expect(find.byKey(Key('build-weapon-${start.name}')), findsOneWidget);
    expect(find.text('Lv 2 / ${WeaponId.maxLevel}'), findsOneWidget);
    expect(find.byKey(const Key('build-passive-fury')), findsOneWidget);
    expect(find.text('Lv 2 / ${PassiveId.maxLevel}'), findsOneWidget);
    expect(find.text(grace.card.title), findsOneWidget);

    await pressBack(tester);
    expect(find.byKey(const Key('close-build')), findsNothing);
    expect(pauseMenu, findsOneWidget);

    // 아이콘 줄을 눌러도 열린다.
    await tester.tap(find.byKey(const Key('pause-build-strip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('close-build')));
    await tester.pump();
    expect(pauseMenu, findsOneWidget);
    expect(game.paused, isTrue);
  });

  testWidgets('레벨업 화면 아래에 지금 가진 카드를 보인다', (tester) async {
    final game = await openGame(tester);
    game.world.gainXp(LevelSystem.xpToNext(1));
    await tester.pump();
    expect(find.byKey(const Key('level-up-build-strip')), findsOneWidget);
  });

  testWidgets('캐릭터 선택으로: 취소하면 그대로, 확인하면 재화를 정산하고 캐릭터 선택으로', (tester) async {
    final inventory = Inventory();
    final game = await openGame(tester, inventory: inventory);
    // 처치로 잔불 · 골드를 모았지만 아직 정산하지 않았다.
    for (var i = 0; i < 30; i++) {
      game.world.onEnemyKilled(game.world.player.position + Vector2(9999, 0));
    }
    expect(inventory.ember, 0);
    expect(inventory.gold, 0);

    await tester.tap(find.byKey(const Key('open-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pause-quit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('정산'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-quit')));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(pauseMenu, findsOneWidget);
    expect(inventory.ember, 0);

    await tester.tap(find.byKey(const Key('pause-quit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-quit')));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('캐릭터 선택 자리'), findsOneWidget);
    expect(inventory.ember, greaterThan(0));
    expect(inventory.ember, game.world.runEmber);
    expect(inventory.gold, greaterThan(0));
    expect(inventory.gold, game.world.runGold);
  });

  testWidgets('쓰러진 화면에는 메인 화면 버튼 없이 캐릭터 선택으로 돌아간다', (tester) async {
    final game = await openGame(tester);

    game.world.player.takeDamage(100000);
    await tester.pump();
    expect(find.text('재가 되었다'), findsOneWidget);
    expect(find.text('다시 일어서기'), findsOneWidget);
    expect(find.text('캐릭터 선택'), findsOneWidget);

    expect(find.text('메인 화면'), findsNothing);
    await tester.tap(find.byKey(const Key('game-over-choose-character')));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('캐릭터 선택 자리'), findsOneWidget);
  });

  testWidgets('뒤로 가기는 나가지 않고 일시정지 메뉴를 열고 닫는다', (tester) async {
    final game = await openGame(tester);

    await pressBack(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(pauseMenu, findsOneWidget);
    expect(game.paused, isTrue);

    // 설정에서 누르면 메뉴로 돌아온다.
    await tester.tap(find.byKey(const Key('pause-settings')));
    await tester.pump();
    await pressBack(tester);
    expect(find.byKey(const Key('close-settings')), findsNothing);
    expect(pauseMenu, findsOneWidget);
    expect(game.paused, isTrue);

    // 메뉴에서 누르면 계속하기와 같다.
    await pressBack(tester);
    expect(pauseMenu, findsNothing);
    expect(game.paused, isFalse);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('레벨업 선택 중에는 일시정지 메뉴가 열리지 않는다', (tester) async {
    final game = await openGame(tester);

    game.world.gainXp(LevelSystem.xpToNext(1));
    await tester.pump();
    expect(find.text('레벨 업'), findsOneWidget);

    expect(game.openPauseMenu(), isFalse);
    await pressBack(tester);
    await tester.pump();
    expect(pauseMenu, findsNothing);
    expect(find.byType(GameScreen), findsOneWidget);
  });
}
