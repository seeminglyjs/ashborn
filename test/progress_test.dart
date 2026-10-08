import 'package:ashborn/data/characters.dart';
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
    test('처음엔 첫 스테이지만 열려 있다', () {
      final progress = Progress();

      expect(progress.bestCleared, isNull);
      expect(progress.unlocked, Stage.first);
      expect(progress.isUnlocked(const Stage(1)), isFalse);
    });

    test('클리어하면 다음 스테이지가 열리고, 낮은 스테이지 기록은 무시한다', () {
      final progress = Progress()..recordClear(const Stage(3));

      expect(progress.unlocked, const Stage(4));
      expect(progress.isUnlocked(const Stage(4)), isTrue);
      expect(progress.isUnlocked(const Stage(5)), isFalse);

      progress.recordClear(const Stage(1));
      expect(progress.bestCleared, const Stage(3));
    });

    test('기기에 저장되고 다음 실행에 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      (await Profile.load()).progress.recordClear(const Stage(6));
      await pumpEventQueue();

      final loaded = (await Profile.load()).progress;

      expect(loaded.unlocked, const Stage(7));
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
      expect(progress.unlocked, const Stage(3));
    },
  );

  testWithGame<AshbornGame>(
    '다시 시작하면 고른 스테이지부터 새 런이 열린다',
    gameWith(Roster.witch, stage: const Stage(4)),
    (game) async {
      await game.ready();
      game.world.advanceStage();

      game.restart(stage: game.world.stage);
      await game.ready();

      expect(game.world.stage, const Stage(5));
      expect(game.world.stageTime, 0);
    },
  );
}
