import 'package:ashborn/components/enemies/boss.dart';
import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/corruption.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
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
      final kind = enemy.kind!;
      expect(stage.region, Region.burningForest);
      expect(Region.burningForest.roster, contains(kind));
      expect(enemy.color, Region.burningForest.enemy);
      expect(enemy.damageType, DamageType.fire);
      expect(
        enemy.maxHp,
        closeTo(
          WaveSystem.enemyHp(game.world.stageTime) *
              stage.enemyHpMultiplier *
              kind.hp,
          stage.enemyHpMultiplier * kind.hp,
        ),
      );
      expect(
        enemy.contactDamage,
        closeTo(
          Balance.enemyContactDamage *
              stage.enemyDamageMultiplier *
              kind.damage,
          1e-9,
        ),
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

  group('보스', () {
    /// 위젯 없이 돌리므로 스테이지 클리어 오버레이 자리만 등록해 둔다.
    void stubOverlay(AshbornGame game) => game.overlays.addEntry(
      AshbornGame.stageClearOverlay,
      (_, _) => const SizedBox(),
    );

    Future<Boss> reachBoss(AshbornGame game) async {
      game.world.stageTime = Balance.stageDuration - 0.05;
      await advance(game, 0.1);
      return game.world.boss!;
    }

    testWithGame<AshbornGame>(
      '스테이지 시간이 다 되면 지역 보스가 나온다',
      gameWith(Roster.witch, stage: const Stage(1)),
      (game) async {
        await game.ready();
        expect(game.world.boss, isNull);
        expect(game.stats.bossCountdown.value, Balance.stageDuration.ceil());

        final boss = await reachBoss(game);

        expect(boss.name, Region.sunkenCathedral.bossName);
        expect(boss.damageType, DamageType.cold);
        expect(boss.isMounted, isTrue);
        expect(game.stats.bossHealth.value, 1);
        expect(game.notices.value.last.text, contains('등장'));
      },
    );

    testWithGame<AshbornGame>('보스는 주기적으로 지역 기술을 쓴다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final boss = await reachBoss(game);
      expect(boss.moves, BossMove.of(boss.region));
      expect(boss.currentMove, isNull);

      // 첫 기술은 나온 뒤 간격의 0.6 배에 쓴다.
      await advance(game, Balance.bossMoveInterval * 0.6 + 0.1);

      expect(boss.currentMove, isNotNull);
      expect(boss.moves, contains(boss.currentMove));
    });

    testWithGame<AshbornGame>('보스는 체력이 절반 아래면 격노한다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final boss = await reachBoss(game);
      expect(boss.isEnraged, isFalse);
      boss.takeDamage(boss.maxHp * (1 - Balance.bossEnrageHp) + 1);
      await advance(game, 1 / 30);
      expect(boss.isEnraged, isTrue);
      expect(game.notices.value.last.text, contains('격노'));
    });

    testWithGame<AshbornGame>(
      '제한 시간 안에 보스를 못 잡으면 런이 끝나고 얻은 재화는 정산된다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        game.overlays.addEntry(
          AshbornGame.gameOverOverlay,
          (_, _) => const SizedBox(),
        );
        await reachBoss(game);
        expect(game.stats.bossTimeLeft.value, Balance.bossTimeLimit.ceil());

        // 처치당 골드가 1 보다 작아 두 번 잡아야 정산할 골드가 생긴다.
        game.world
          ..onEnemyKilled(Vector2.zero())
          ..onEnemyKilled(Vector2.zero())
          ..bossTime = Balance.bossTimeLimit - 0.05;
        await advance(game, 0.1);

        expect(game.world.timedOut, isTrue);
        expect(game.world.player.isDead, isFalse);
        expect(game.overlays.isActive(AshbornGame.gameOverOverlay), isTrue);
        expect(game.paused, isTrue);
        expect(game.inventory.gold, greaterThan(0));
      },
    );

    testWithGame<AshbornGame>(
      '보스를 잡으면 졸개가 사라지고, 잠시 뒤 다음 지역으로 넘어갈 수 있다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        stubOverlay(game);
        final boss = await reachBoss(game);
        await addEnemy(game, Vector2(300, 0));

        boss.takeDamage(boss.maxHp);
        await game.ready();

        expect(game.world.stageCleared, isTrue);
        expect(game.world.enemies, isEmpty);
        expect(game.stats.stageCleared.value, isTrue);

        // 전리품을 줍는 동안은 웨이브가 쉬고 선택창도 아직 없다.
        await advance(game, Balance.stageClearDelay - 0.5);
        expect(game.world.enemies, isEmpty);
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isFalse);

        await advance(game, 0.6);
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isTrue);
        expect(game.paused, isTrue);

        game.continueToNextStage();
        expect(game.world.stage, const Stage(1));
        expect(game.world.stageTime, 0);
        expect(game.world.stageCleared, isFalse);
        expect(game.stats.stage.value, const Stage(1));
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isFalse);
      },
    );

    testWithGame<AshbornGame>(
      '마지막 지역 보스를 잡으면 그 단계 클리어: 다음 지역은 없고, 클리어 보상과 다음 타락 단계가 열린다',
      gameWith(Roster.witch, stage: Stage(Region.values.length - 1)),
      (game) async {
        await game.ready();
        game.overlays.addEntry(
          AshbornGame.stageClearOverlay,
          (_, _) => const SizedBox(),
        );
        final stones = game.inventory.stones;
        game.world.spawnBoss();
        await game.ready();
        game.world.boss!.takeDamage(double.infinity);
        await game.ready();

        expect(game.world.conquered, isTrue);
        expect(game.world.unlockedCorruption, isTrue);
        expect(game.progress.unlockedCorruption, 1);
        expect(
          game.inventory.stones - stones,
          greaterThanOrEqualTo(Balance.bossStones + Balance.conquestStones),
        );
        expect(
          game.notices.value.map((n) => n.text),
          contains(startsWith('첫 클리어')),
        );

        game.world.advanceStage();
        game.continueToNextStage();
        expect(game.world.stage, Stage(Region.values.length - 1));
      },
    );

    test('타락 단계는 런 안의 지역 순서와 따로 적을 키운다', () {
      final regions = Region.values.length;
      // 같은 지역 순서면 타락 한 단계마다 정해진 배율.
      final a = Stage.start(2);
      final b = Stage.start(3);
      expect(
        b.enemyHpMultiplier / a.enemyHpMultiplier,
        closeTo(Balance.corruptionHpGrowth, 1e-9),
      );
      expect(
        b.enemyDamageMultiplier / a.enemyDamageMultiplier,
        closeTo(Balance.corruptionDamageGrowth, 1e-9),
      );
      // 타락 단계의 첫 지역은 이전 단계 마지막 지역보다 약할 수 있다 (런은 레벨 1 부터).
      expect(Stage.start(3).step, 0);
      expect(Stage(regions * 3 + 4).isFinal, isTrue);
      // 보상 쪽 레벨은 계속 오른다.
      expect(Stage.start(3).level, regions * 3 + 1);
    });

    test('특수 규칙은 정해진 단계부터 붙고 위 단계에도 남는다', () {
      expect(Stage.start(0).rules, isEmpty);
      expect(Stage.start(1).rules, [CorruptionRule.elite]);
      expect(Stage.start(2).has(CorruptionRule.bossRegen), isTrue);
      expect(Stage.start(3).has(CorruptionRule.deathBlast), isFalse);
      expect(Stage.start(8).rules, CorruptionRule.values);
      for (final rule in CorruptionRule.values) {
        expect(rule.label, isNotEmpty);
        expect(rule.description, isNotEmpty);
      }
    });
  });

  group('보상', () {
    testWithGame<AshbornGame>(
      '보스를 잡으면 상자 장비가 떨어지고 클리어 잔불을 받는다',
      gameWith(Roster.witch, stage: const Stage(2)),
      (game) async {
        await game.ready();
        game.overlays.addEntry(
          AshbornGame.stageClearOverlay,
          (_, _) => const SizedBox(),
        );
        game.world.spawnBoss();
        await game.ready();

        game.world.boss!.takeDamage(double.infinity);
        await game.ready();

        final drops = game.world.children.whereType<ItemDrop>().toList();
        expect(drops.length, greaterThanOrEqualTo(Balance.bossChestItems));
        expect(game.inventory.ember, (Balance.stageClearEmber * 3).round());
        expect(game.world.runEmber, game.inventory.ember);
      },
    );

    testWithGame<AshbornGame>(
      '처치로 모은 잔불은 쓰러질 때 정산된다',
      gameWith(Roster.witch, stage: const Stage(4)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        game.overlays.addEntry(
          AshbornGame.gameOverOverlay,
          (_, _) => const SizedBox(),
        );
        for (var i = 0; i < 10; i++) {
          final enemy = await addEnemy(game, Vector2(5000.0 + i * 50, 0));
          enemy.takeDamage(double.infinity);
        }
        expect(game.inventory.ember, 0);

        game.world.player.takeDamage(double.infinity);

        expect(game.inventory.ember, (10 * Balance.killEmber * 5).floor());
      },
    );

    testWithGame<AshbornGame>(
      '처치로 모은 골드와 강화석도 쓰러질 때 정산된다',
      gameWith(Roster.witch, stage: const Stage(4)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        game.overlays.addEntry(
          AshbornGame.gameOverOverlay,
          (_, _) => const SizedBox(),
        );
        for (var i = 0; i < 10; i++) {
          final enemy = await addEnemy(game, Vector2(5000.0 + i * 50, 0));
          enemy.takeDamage(double.infinity);
        }
        expect(game.inventory.gold, 0);

        game.world.player.takeDamage(double.infinity);

        expect(game.inventory.gold, (10 * Balance.killGold * 5).floor());
        expect(game.world.runGold, game.inventory.gold);
        expect(game.world.runStones, game.inventory.stones);
      },
    );

    testWithGame<AshbornGame>(
      '보스는 클리어 골드와 강화석을 준다. 타락 단계마다 강화석이 하나씩 더',
      gameWith(Roster.witch, stage: Stage(Region.values.length + 2)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        game.overlays.addEntry(
          AshbornGame.stageClearOverlay,
          (_, _) => const SizedBox(),
        );
        final stage = game.world.stage;
        game.world.spawnBoss();
        await game.ready();

        game.world.boss!.takeDamage(double.infinity);
        await game.ready();

        expect(
          game.inventory.gold,
          greaterThanOrEqualTo(
            (Balance.stageClearGold * stage.level * stage.dropChanceMultiplier)
                .round(),
          ),
        );
        expect(
          game.inventory.stones,
          greaterThanOrEqualTo(Balance.bossStones + 1),
        );
        expect(
          game.notices.value.map((n) => n.text),
          contains(startsWith('골드 +')),
        );
      },
    );
  });
}
