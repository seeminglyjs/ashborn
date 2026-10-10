import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/settings.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/ui/equipment/equipment_panel.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:ashborn/ui/settings/settings_screen.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

AshbornGame Function() gameWithSettings(Settings settings) => () {
  TestWidgetsFlutterBinding.ensureInitialized();
  return AshbornGame(
    character: Roster.witch,
    profile: Profile(settings: settings),
  );
};

Future<void> pickUp(AshbornGame game, Item item) async {
  await game.world.add(
    ItemDrop(position: game.world.player.position.clone(), item: item),
  );
  await advance(game, 0.1);
}

void main() {
  group('설정', () {
    test('획득 알림은 최소 등급 이상만 보인다', () {
      final settings = Settings()..lootNoticeMinRarity = Rarity.legend;

      expect(settings.showsLoot(Rarity.hero), isFalse);
      expect(settings.showsLoot(Rarity.legend), isTrue);

      settings.lootNotices = false;
      expect(settings.showsLoot(Rarity.unique), isFalse);
    });

    test('기기에 저장되고 다음 실행에 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      (await Profile.load()).settings
        ..vibration = false
        ..sfxVolume = 0.3
        ..lootNoticeMinRarity = Rarity.epic;
      await pumpEventQueue();

      final loaded = (await Profile.load()).settings;

      expect(loaded.vibration, isFalse);
      expect(loaded.sfxVolume, 0.3);
      expect(loaded.lootNoticeMinRarity, Rarity.epic);
      expect(loaded.musicVolume, Settings().musicVolume);
    });
  });

  group('분해 설정', () {
    test('고른 분해 등급 · 강화 제외 · 자동 분해가 저장되고, 예전 세이브는 기본값으로 읽는다', () async {
      SharedPreferences.setMockInitialValues({});
      (await Profile.load()).settings
        ..salvageRarities = {Rarity.normal, Rarity.hero}
        ..salvageKeepUpgraded = false
        ..autoSalvage = true;
      await pumpEventQueue();

      final loaded = (await Profile.load()).settings;
      expect(loaded.salvageRarities, {Rarity.normal, Rarity.hero});
      expect(loaded.salvageKeepUpgraded, isFalse);
      expect(loaded.autoSalvage, isTrue);

      final old = Settings().toJson()
        ..remove('salvageRarities')
        ..remove('salvageKeepUpgraded')
        ..remove('autoSalvage');
      final migrated = Settings.fromJson(old);
      expect(migrated.salvageRarities, defaultSalvageRarities);
      expect(migrated.salvageKeepUpgraded, isTrue);
      expect(migrated.autoSalvage, isFalse);
    });

    testWidgets('일괄 분해 창에서 고른 등급은 창을 닫았다 열어도 남는다', (tester) async {
      final settings = Settings();
      final inventory = Inventory();
      final gear = inventory.gear(CharacterId.knight);
      gear.add(item(ItemType.ring));
      gear.add(item(ItemType.ring));
      gear.add(item(ItemType.ring));
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(
              inventory: inventory,
              character: Roster.knight,
              settings: settings,
              onClose: () {},
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('bulk-salvage')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await open();
      await tester.tap(find.byKey(const Key('bulk-rarity-hero')));
      await tester.tap(find.byKey(const Key('bulk-rarity-rare')));
      await tester.tap(find.byKey(const Key('auto-salvage')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cancel-bulk-salvage')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 화면을 새로 열어도 (취소했어도) 그대로다.
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(settings.salvageRarities, {Rarity.normal, Rarity.hero});
      expect(settings.autoSalvage, isTrue);
    });

    testWithGame<AshbornGame>(
      '자동 분해: 고른 등급은 주우면 바로 잔불이 되고, 빈 칸 · 전투력이 오르는 장비 · 다른 등급은 남긴다',
      gameWithSettings(Settings()..autoSalvage = true),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        game.gear.add(item(ItemType.belt, value: 20));
        final ember = game.inventory.ember;

        final junk = item(ItemType.belt);
        await pickUp(game, junk);
        expect(game.inventory.bag, isEmpty);
        expect(game.inventory.ember, ember + junk.salvageValue);

        // 빈 칸에 끼는 장비, 지금보다 센 장비, 고르지 않은 등급은 남는다.
        final helm = item(ItemType.head);
        final better = item(ItemType.belt, value: 500);
        final hero = item(ItemType.belt, rarity: Rarity.hero);
        for (final i in [helm, better, hero]) {
          await pickUp(game, i);
        }
        expect(game.gear.equipped.values, contains(helm));
        expect(game.inventory.bag, containsAll([better, hero]));
      },
    );

    testWithGame<AshbornGame>(
      '자동 분해할 장비는 가방이 가득 차도 줍는다',
      gameWithSettings(Settings()..autoSalvage = true),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        game.gear.add(item(ItemType.belt, value: 20));
        for (var i = 0; i < Balance.bagCapacity; i++) {
          game.gear.add(item(ItemType.belt, rarity: Rarity.hero));
        }
        final ember = game.inventory.ember;
        await pickUp(game, item(ItemType.belt));
        expect(game.inventory.ember, greaterThan(ember));
        expect(game.inventory.bag, hasLength(Balance.bagCapacity));
      },
    );
  });

  group('알림 설정', () {
    testWithGame<AshbornGame>(
      '최소 등급보다 낮은 장비는 알리지 않는다',
      gameWithSettings(Settings()..lootNoticeMinRarity = Rarity.legend),
      (game) async {
        await game.ready();
        await clearEnemies(game);

        await pickUp(game, item(ItemType.head));
        expect(game.notices.value, isEmpty);

        await pickUp(game, item(ItemType.boots, rarity: Rarity.legend));
        expect(game.notices.value, hasLength(1));
      },
    );

    testWithGame<AshbornGame>(
      '진행 알림을 끄면 보스 등장도 알리지 않는다',
      gameWithSettings(Settings()..eventNotices = false),
      (game) async {
        await game.ready();

        game.world.spawnBoss();

        expect(game.notices.value, isEmpty);
      },
    );
  });

  testWidgets('타이틀의 설정 화면에서 바꾼 값이 저장된다', (tester) async {
    final profile = Profile();
    await tester.pumpWidget(
      ProfileScope(
        profile: profile,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('vibration')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loot-min-hero')));
    await tester.pump();

    expect(profile.settings.vibration, isFalse);
    expect(profile.settings.lootNoticeMinRarity, Rarity.hero);
  });

  testWidgets('런 중 일시정지 → 설정을 열고 닫으면 일시정지 메뉴로 돌아온다', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProfileScope(
        profile: Profile(),
        child: const MaterialApp(home: GameScreen(character: Roster.witch)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
        .game!;

    await tester.tap(find.byKey(const Key('open-pause')));
    await tester.pump();
    expect(game.paused, isTrue);

    await tester.tap(find.byKey(const Key('pause-settings')));
    await tester.pump();
    expect(game.paused, isTrue);
    expect(find.text('설정'), findsOneWidget);
    expect(find.byKey(const Key('pause-resume')), findsNothing);

    // 닫으면 게임은 멈춘 채 일시정지 메뉴로 돌아온다.
    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pump();
    expect(game.paused, isTrue);
    expect(find.byKey(const Key('pause-resume')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pause-resume')));
    await tester.pump();
    expect(game.paused, isFalse);
    expect(find.byKey(const Key('pause-resume')), findsNothing);
  });
}
