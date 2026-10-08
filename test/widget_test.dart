import 'dart:math' as math;

import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/main.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:ashborn/ui/inventory_scope.dart';
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

Widget gameScreen(CharacterDef character, {Inventory? inventory}) =>
    InventoryScope(
      inventory: inventory ?? Inventory(),
      child: MaterialApp(home: GameScreen(character: character)),
    );

void main() {
  for (final size in [phoneLandscape, desktop]) {
    testWidgets('스플래시 → 메인 → 캐릭터 선택 → 게임 (${size.width.toInt()}x'
        '${size.height.toInt()})', (tester) async {
      useScreen(tester, size);
      await tester.pumpWidget(AshbornApp(inventory: Inventory()));
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
    await tester.pumpWidget(AshbornApp(inventory: Inventory()));
    await settle(tester, 300);

    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    expect(find.byType(TitleScreen), findsOneWidget);
  });

  testWidgets('죽으면 게임 오버가 뜨고 다시 일어서면 런이 초기화된다', (tester) async {
    useScreen(tester, phoneLandscape);
    await tester.pumpWidget(gameScreen(Roster.knight));
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

  testWidgets('레벨이 오르면 게임이 멈추고 고른 만큼 강해진다', (tester) async {
    useScreen(tester, phoneLandscape);
    await tester.pumpWidget(gameScreen(Roster.witch));
    await settle(tester, 100);
    final game = tester
        .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
        .game!;
    final player = game.world.player;
    int totalLevels() =>
        player.weapons.fold(0, (sum, w) => sum + w.level) +
        player.passives.values.fold(0, (sum, l) => sum + l);
    final before = totalLevels();

    // 두 레벨이 한꺼번에 오른다.
    game.world.gainXp(LevelSystem.xpToNext(1) + LevelSystem.xpToNext(2));
    await tester.pump();

    expect(game.paused, isTrue);
    expect(find.text('레벨 업'), findsOneWidget);
    expect(find.byKey(const Key('level-up-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('level-up-0')));
    await tester.pump();
    expect(totalLevels(), before + 1);
    expect(find.text('레벨 업'), findsOneWidget);

    await tester.tap(find.byKey(const Key('level-up-1')));
    await tester.pump();
    expect(totalLevels(), before + 2);
    expect(find.text('레벨 업'), findsNothing);
    expect(game.paused, isFalse);
  });

  for (final size in [phoneLandscape, desktop]) {
    testWidgets('장비 화면에서 가방의 반지를 끼면 원래 반지는 가방으로 간다 '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      useScreen(tester, size);
      final random = math.Random(4);
      final inventory = Inventory();
      // 칸을 다 채우고 가방도 넉넉히 채워 레이아웃을 확인한다.
      for (var i = 0; i < 40; i++) {
        inventory
            .gear(CharacterId.witch)
            .add(LootSystem.generate(random, rarity: Rarity.unique));
      }
      final ring = LootSystem.generate(random, type: ItemType.ring);
      final gear = inventory.gear(CharacterId.witch);
      gear.add(ring);
      final oldRing = gear.equipped[EquipSlot.ring1]!;
      await tester.pumpWidget(gameScreen(Roster.witch, inventory: inventory));
      await settle(tester, 100);
      final game = tester
          .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
          .game!;

      await tester.tap(find.byKey(const Key('open-equipment')));
      await tester.pump();
      expect(game.paused, isTrue);
      expect(find.text('장비'), findsOneWidget);

      final index = inventory.bag.indexOf(ring);
      await tester.ensureVisible(find.byKey(Key('bag-$index')));
      await tester.tap(find.byKey(Key('bag-$index')));
      await tester.pump();
      expect(find.text(ring.name), findsWidgets);

      await tester.tap(find.byKey(const Key('equip-ring1')));
      await tester.pump();
      expect(gear.equipped[EquipSlot.ring1], ring);
      expect(inventory.bag, contains(oldRing));

      await tester.tap(find.byKey(const Key('close-equipment')));
      await tester.pump();
      expect(find.text('장비'), findsNothing);
      expect(game.paused, isFalse);
    });
  }
}
