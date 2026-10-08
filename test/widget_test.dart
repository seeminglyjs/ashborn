import 'dart:math' as math;

import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/progress.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/main.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:ashborn/ui/equipment/equipment_screen.dart';
import 'package:ashborn/ui/hearth/hearth_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:ashborn/ui/screens/character_select_screen.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:ashborn/ui/screens/splash_screen.dart';
import 'package:ashborn/ui/screens/title_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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
    ProfileScope(
      profile: Profile(inventory: inventory),
      child: MaterialApp(home: GameScreen(character: character)),
    );

void main() {
  for (final size in [phoneLandscape, desktop]) {
    testWidgets('스플래시 → 메인 → 캐릭터 선택 → 게임 (${size.width.toInt()}x'
        '${size.height.toInt()})', (tester) async {
      useScreen(tester, size);
      await tester.pumpWidget(AshbornApp(profile: Profile()));
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
    await tester.pumpWidget(AshbornApp(profile: Profile()));
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
    expect(find.text('보스까지 02:00'), findsOneWidget);

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

  group('출발 전 장비 화면', () {
    Future<Inventory> openFor(
      WidgetTester tester,
      CharacterDef character, {
      required void Function(Inventory) fill,
    }) async {
      useScreen(tester, phoneLandscape);
      final inventory = Inventory();
      fill(inventory);
      await tester.pumpWidget(
        ProfileScope(
          profile: Profile(inventory: inventory),
          child: const MaterialApp(home: CharacterSelectScreen()),
        ),
      );
      await settle(tester, 300);
      await tester.tap(find.text(character.name));
      await settle(tester, 300);
      await tester.tap(find.byKey(const Key('open-equipment')));
      await settle(tester);
      return inventory;
    }

    testWidgets('캐릭터 선택에서 그 캐릭터의 장비를 보고 바꾼다', (tester) async {
      final helm = item(ItemType.head, rarity: Rarity.rare, value: 25);
      final inventory = await openFor(
        tester,
        Roster.hunter,
        fill: (inv) => inv
          ..gear(CharacterId.knight).add(helm)
          ..gear(CharacterId.knight).unequip(EquipSlot.head),
      );
      expect(find.byType(EquipmentScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EquipmentScreen),
          matching: find.text(Roster.hunter.name),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      // 빈 칸에 끼우므로 오르기만 한다.
      expect(find.text('빈 칸'), findsOneWidget);
      expect(find.text('▲ 최대 체력 +25'), findsOneWidget);

      await tester.tap(find.byKey(const Key('equip-head')));
      await tester.pump();
      expect(inventory.gear(CharacterId.hunter).equipped[EquipSlot.head], helm);
      expect(inventory.gear(CharacterId.knight).equipped, isEmpty);

      await tester.tap(find.byKey(const Key('close-equipment')));
      await settle(tester);
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
    });

    testWidgets('교체하면 바뀌는 능력치를 비교해 보여 준다', (tester) async {
      await openFor(
        tester,
        Roster.witch,
        fill: (inv) => inv.gear(CharacterId.witch)
          ..add(item(ItemType.head, value: 30))
          ..add(
            item(
              ItemType.head,
              value: 20,
              extra: [
                (stat: StatType.fireResist, value: 0.1, rarity: Rarity.normal),
              ],
            ),
          ),
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();

      expect(find.text('▼ 최대 체력 -10'), findsOneWidget);
      expect(find.text('▲ 화염 저항 +10%'), findsOneWidget);
    });

    testWidgets('영웅 이상 장비는 분해하기 전에 한 번 더 묻는다', (tester) async {
      final hero = item(ItemType.ring, rarity: Rarity.hero);
      final normal = item(ItemType.ring);
      final inventory = await openFor(
        tester,
        Roster.witch,
        fill: (inv) {
          final gear = inv.gear(CharacterId.witch);
          for (final ring in [
            item(ItemType.ring),
            item(ItemType.ring),
            hero,
            normal,
          ]) {
            gear.add(ring);
          }
        },
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('salvage')));
      await tester.pump();
      expect(find.byKey(const Key('confirm-salvage')), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pump();
      expect(inventory.bag, contains(hero));

      await tester.tap(find.byKey(const Key('salvage')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-salvage')));
      await tester.pump();
      expect(inventory.bag, [normal]);

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('salvage')));
      await tester.pump();
      expect(find.byKey(const Key('confirm-salvage')), findsNothing);
      expect(inventory.bag, isEmpty);
    });
  });

  testWidgets('캐릭터 선택에서 화톳불을 열어 강화를 살 수 있다', (tester) async {
    useScreen(tester, phoneLandscape);
    await tester.pumpWidget(
      ProfileScope(
        profile: Profile(),
        child: const MaterialApp(home: CharacterSelectScreen()),
      ),
    );
    await settle(tester, 300);

    await tester.tap(find.byKey(const Key('open-hearth')));
    await settle(tester);

    expect(find.byType(HearthScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-hearth')));
    // 첫 프레임에 닫는 전환이 시작된다.
    await tester.pump();
    await settle(tester);
    expect(find.byType(HearthScreen), findsNothing);
  });

  testWidgets('출정할 스테이지는 클리어한 다음 스테이지까지 고를 수 있다', (tester) async {
    useScreen(tester, phoneLandscape);
    final progress = Progress()..recordClear(const Stage(5));
    await tester.pumpWidget(
      ProfileScope(
        profile: Profile(progress: progress),
        child: const MaterialApp(home: CharacterSelectScreen()),
      ),
    );
    await settle(tester, 300);

    String shown() =>
        tester.widget<Text>(find.byKey(const Key('stage-name'))).data!;
    expect(shown(), const Stage(6).name);

    await tester.tap(find.byKey(const Key('stage-next')));
    await tester.pump();
    expect(shown(), const Stage(6).name);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('stage-prev')));
      await tester.pump();
    }
    expect(shown(), Stage.first.name);

    await tester.tap(find.byKey(const Key('stage-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('depart')));
    await settle(tester);

    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.stage, const Stage(1));
  });
}
