import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('스테이지', () {
    test('마지막 지역 다음은 첫 지역이고 타락 단계가 오른다', () {
      final regions = Region.values.length;

      expect(Stage.first.region, Region.ashPlains);
      expect(Stage.first.corruption, 0);
      expect(Stage(regions - 1).region, Region.undyingHeart);
      expect(Stage(regions - 1).next.region, Region.ashPlains);
      expect(Stage(regions - 1).next.corruption, 1);
      expect(Stage(regions * 7 + 2).corruption, 7);
      expect(Stage(regions * 7 + 2).level, regions * 7 + 3);
    });

    test('이름에 타락 단계가 붙는다', () {
      expect(Stage.first.name, '잿빛 평원');
      expect(Stage(Region.values.length + 1).name, '타락 1 · 가라앉은 성당');
    });

    test('레벨이 오를수록 적이 강해지고, 타락 단계가 오를수록 보상이 커진다', () {
      final early = Stage.first;
      final late = Stage(Region.values.length * 3);

      expect(late.enemyHpMultiplier, greaterThan(early.enemyHpMultiplier));
      expect(
        late.enemyDamageMultiplier,
        greaterThan(early.enemyDamageMultiplier),
      );
      expect(
        late.dropChanceMultiplier,
        greaterThan(early.dropChanceMultiplier),
      );
      expect(late.rarityLuck, greaterThan(early.rarityLuck));
    });

    test('타락 단계의 속도 증가는 상한이 있다', () {
      final far = Stage(Region.values.length * 100);

      expect(
        far.enemySpeedMultiplier,
        far.region.speed * Balance.maxCorruptionSpeed,
      );
    });
  });

  testWithGame<AshbornGame>(
    '스폰되는 적은 지역의 색, 속성, 강도를 따른다',
    gameWith(Roster.witch, stage: const Stage(7)),
    (game) async {
      await game.ready();
      final stage = game.world.stage;
      await advance(game, 2);

      final enemy = game.world.enemies.first;
      expect(stage.region, Region.burningForest);
      expect(enemy.color, Region.burningForest.enemy);
      expect(enemy.damageType, DamageType.fire);
      expect(
        enemy.maxHp,
        closeTo(
          WaveSystem.enemyHp(game.world.stageTime) * stage.enemyHpMultiplier,
          stage.enemyHpMultiplier,
        ),
      );
      expect(
        enemy.contactDamage,
        Balance.enemyContactDamage * stage.enemyDamageMultiplier,
      );
    },
  );

  testWithGame<AshbornGame>(
    '원소 적의 피해는 그 속성 저항이 줄인다',
    gameWith(
      Roster.witch,
      inventory: wearing({StatType.fireResist: 0.5}),
      stage: const Stage(2),
    ),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      await game.world.add(
        Enemy(
          position: game.world.player.position.clone(),
          maxHp: 1000,
          contactDamage: 20,
          damageType: DamageType.fire,
        ),
      );

      await advance(game, 0.1);

      expect(game.world.player.hp, Roster.witch.maxHp - 10);
    },
  );
}
