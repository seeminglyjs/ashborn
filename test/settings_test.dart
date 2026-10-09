import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/settings.dart';
import 'package:ashborn/game/ashborn_game.dart';
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

  testWidgets('런 중 설정을 열면 게임이 멈추고 닫으면 이어진다', (tester) async {
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

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pump();
    expect(game.paused, isTrue);
    expect(find.text('설정'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pump();
    expect(game.paused, isFalse);
  });
}
