import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/progress.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  group('진행도', () {
    test('처음엔 타락 0단계만 열려 있다', () {
      final progress = Progress();

      expect(progress.bestCleared, isNull);
      expect(progress.unlockedCorruption, 0);
      expect(progress.conquered(0), isFalse);
    });

    test('마지막 지역까지 클리어해야 다음 타락 단계가 열리고, 낮은 스테이지 기록은 무시한다', () {
      final progress = Progress()..recordClear(const Stage(3));
      expect(progress.unlockedCorruption, 0);

      progress.recordClear(Stage(Region.values.length - 1));
      expect(progress.conquered(0), isTrue);
      expect(progress.unlockedCorruption, 1);
      expect(progress.conquered(1), isFalse);

      progress.recordClear(const Stage(1));
      expect(progress.bestCleared, Stage(Region.values.length - 1));
    });

    test('예전 기록(스테이지를 이어서 가던 때)은 클리어한 단계 수만큼 단계가 열린다', () {
      final regions = Region.values.length;
      expect(Progress(regions * 3 + 2).unlockedCorruption, 3);
      expect(Progress(regions * 3 - 1).unlockedCorruption, 3);
      expect(Progress(regions * 3 - 2).unlockedCorruption, 2);
    });

    test('기기에 저장되고 다음 실행에 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      (await Profile.load()).progress.recordClear(const Stage(6));
      await pumpEventQueue();

      final loaded = (await Profile.load()).progress;

      expect(loaded.bestCleared, const Stage(6));
      expect(loaded.unlockedCorruption, 1);
    });
  });

  group('캐릭터 해금', () {
    test('잿불 기사만 무료이고, 나머지는 골드를 내고 해금한다', () {
      final progress = Progress();
      final inventory = Inventory()..addLoot(gold: Roster.witch.price);

      expect(progress.owns(Roster.knight), isTrue);
      expect(progress.owns(Roster.witch), isFalse);
      expect(progress.canUnlock(Roster.hunter, inventory), isFalse);

      progress.unlock(Roster.witch, inventory);

      expect(progress.owns(Roster.witch), isTrue);
      expect(inventory.gold, 0);
      expect(progress.canUnlock(Roster.witch, inventory), isFalse);
    });

    test('해금한 캐릭터는 저장되고, 예전 저장에는 무료 캐릭터만 있다', () async {
      SharedPreferences.setMockInitialValues({
        Profile.progressKey: '{"bestCleared": 2}',
      });
      final profile = await Profile.load();
      expect(profile.progress.owns(Roster.hunter), isFalse);

      profile.inventory.addLoot(gold: Roster.hunter.price);
      profile.progress.unlock(Roster.hunter, profile.inventory);
      await pumpEventQueue();

      final loaded = (await Profile.load()).progress;
      expect(loaded.owns(Roster.hunter), isTrue);
      expect(loaded.bestCleared, const Stage(2));
    });
  });

  final progress = Progress();
  testWithGame<AshbornGame>(
    '보스를 잡으면 진행도에 기록된다',
    gameWith(Roster.witch, progress: progress, stage: const Stage(2)),
    (game) async {
      await game.ready();
      game.overlays.addEntry(
        AshbornGame.stageClearOverlay,
        (_, _) => const SizedBox(),
      );
      game.world.spawnBoss();
      await game.ready();

      game.world.boss!.takeDamage(double.infinity);

      expect(progress.bestCleared, const Stage(2));
      expect(progress.frontier, const Stage(3));
    },
  );

  testWithGame<AshbornGame>(
    '다시 시작하면 고른 스테이지부터 새 런이 열린다',
    gameWith(Roster.witch, stage: const Stage(2)),
    (game) async {
      await game.ready();
      game.world.advanceStage();

      game.restart(stage: game.world.stage);
      await game.ready();

      expect(game.world.stage, const Stage(3));
      expect(game.world.stageTime, 0);
    },
  );

  group('신의 은총 저장', () {
    test('은총이 없던 예전 기록은 클리어한 스테이지마다 받을 은총이 하나씩 생긴다', () {
      final old = Progress.fromJson({'bestCleared': 2, 'characters': []});

      expect(old.graces, isEmpty);
      expect(old.pendingGraces, [
        const Stage(0),
        const Stage(1),
        const Stage(2),
      ]);
      expect(old.offerFor(Stage.first), isNull);
    });

    test('받은 은총과 남은 카드 패는 저장했다 불러와도 그대로다', () {
      final progress = Progress(3);
      final taken = Fate(FateCard.sharpEmber, Rarity.hero);
      final hand = [
        Fate(FateCard.hardenedAsh, Rarity.normal),
        Fate(FateCard.berserk, Rarity.unique),
      ];
      expect(progress.takeGrace(const Stage(1), taken), isTrue);
      progress.offerGrace(const Stage(2), hand, rerolls: 1);

      final loaded = Progress.fromJson(progress.toJson());

      expect(loaded.graces, [taken]);
      expect(loaded.hasGrace(const Stage(1)), isTrue);
      expect(loaded.pendingGraces, [
        const Stage(0),
        const Stage(2),
        const Stage(3),
      ]);
      expect(loaded.offerFor(const Stage(2))!.hand, hand);
      expect(loaded.offerFor(const Stage(2))!.rerolls, 1);
    });

    test('한 스테이지에 은총은 하나, 클리어하지 않은 스테이지는 받을 수 없다', () {
      final progress = Progress(0);
      final fate = Fate(FateCard.sharpEmber, Rarity.normal);

      expect(progress.takeGrace(const Stage(1), fate), isFalse);
      expect(progress.takeGrace(Stage.first, fate), isTrue);
      expect(progress.takeGrace(Stage.first, fate), isFalse);
      expect(progress.graces, [fate]);
    });

    test('모르는 카드 이름은 건너뛴다 (앞선 버전 기록)', () {
      final loaded = Progress.fromJson({
        'bestCleared': 1,
        'graces': {
          '0': {'card': 'sharpEmber', 'rarity': 'rare'},
          '1': {'card': 'futureCard', 'rarity': 'rare'},
        },
      });

      expect(loaded.graces, [Fate(FateCard.sharpEmber, Rarity.rare)]);
      expect(loaded.pendingGraces, [const Stage(1)]);
    });
  });
}
