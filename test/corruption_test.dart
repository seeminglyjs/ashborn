import 'package:ashborn/components/enemies/hazards.dart';
import 'package:ashborn/components/enemies/minions.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/enemies.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 플레이어 옆에 웨이브 졸개 하나 (종류가 있어야 잿불 유해가 남는다).
Future<dynamic> addMinion(AshbornGame game, {bool elite = false}) async {
  final minion = spawnMinion(
    EnemyKind.ashWalker,
    position: game.world.player.position + Vector2(120, 0),
    maxHp: 10,
    contactDamage: 5,
    damageType: DamageType.physical,
    speed: 0,
    color: const Color(0xFF8A7F7A),
  );
  if (elite) minion.makeElite();
  await game.world.add(minion);
  await game.ready();
  return minion;
}

/// 보스를 불러 체력을 [ratio] 만큼 남긴다.
Future<dynamic> bossAt(AshbornGame game, double ratio) async {
  game.world.spawnBoss();
  await game.ready();
  final boss = game.world.boss!;
  boss.takeDamage(boss.maxHp * (1 - ratio));
  return boss;
}

void main() {
  testWithGame<AshbornGame>(
    '출정하면 그 단계의 특수 규칙을 알린다',
    gameWith(Roster.witch, stage: Stage.start(2)),
    (game) async {
      await game.ready();
      expect(
        game.notices.value.map((n) => n.text),
        contains('타락 2단계: 정예 출현 · 보스 재생'),
      );
    },
  );

  group('정예 출현', () {
    testWithGame<AshbornGame>(
      '정예는 크고, 잡으면 재의 결정을 더 떨어뜨리고 강화석을 확정으로 준다',
      gameWith(Roster.witch, stage: Stage.start(1)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final plain = await addMinion(game);
        final elite = await addMinion(game, elite: true);
        expect(elite.elite, isTrue);
        expect(elite.radius, closeTo(plain.radius * Balance.eliteSize, 1e-4));

        final stones = game.inventory.stones;
        final kills = game.stats.kills.value;
        elite.takeDamage(double.infinity);
        await game.ready();
        game.world.bankLoot();

        expect(game.stats.kills.value, kills + 1);
        expect(
          game.inventory.stones - stones,
          greaterThanOrEqualTo(Balance.eliteStones),
        );
      },
    );
  });

  group('보스 재생', () {
    for (final (corruption, regen) in [(1, false), (2, true)]) {
      testWithGame<AshbornGame>(
        '타락 $corruption단계: 맞지 않는 보스는 ${regen ? '체력을 회복한다' : '회복하지 않는다'}',
        gameWith(Roster.witch, stage: Stage.start(corruption)),
        (game) async {
          await game.ready();
          final boss = await bossAt(game, 0.9);
          final hp = boss.hp;
          // 플레이어를 멀리 두어 보스가 맞지 않게 한다 (무기가 닿지 않는 거리).
          game.world.player.position.add(Vector2(5000, 5000));
          await advance(game, Balance.bossRegenDelay + 1);

          if (regen) {
            expect(boss.hp, greaterThan(hp));
          } else {
            expect(boss.hp, hp);
          }
        },
      );
    }
  });

  group('이른 격노', () {
    for (final (corruption, enraged) in [(0, false), (8, true)]) {
      testWithGame<AshbornGame>(
        '타락 $corruption단계: 체력 70% 보스는 ${enraged ? '격노한다' : '아직 격노하지 않는다'}',
        gameWith(Roster.witch, stage: Stage.start(corruption)),
        (game) async {
          await game.ready();
          final boss = await bossAt(game, 0.7);
          await advance(game, 0.05);
          expect(boss.isEnraged, enraged);
        },
      );
    }
  });

  group('잿불 유해', () {
    for (final (corruption, blasts) in [(3, false), (4, true)]) {
      testWithGame<AshbornGame>(
        '타락 $corruption단계: 쓰러진 졸개 자리가 ${blasts ? '가끔 터진다' : '터지지 않는다'}',
        gameWith(Roster.witch, stage: Stage.start(corruption)),
        (game) async {
          await game.ready();
          var seen = 0;
          for (var i = 0; i < 60; i++) {
            await clearEnemies(game);
            final minion = await addMinion(game);
            minion.takeDamage(double.infinity);
            await game.ready();
            seen = game.world.children.whereType<DeathBlast>().length;
            if (seen > 0) break;
          }
          expect(seen > 0, blasts);
          if (blasts) {
            expect(game.world.deathBlasts, seen);
            expect(seen, lessThanOrEqualTo(Balance.maxDeathBlasts));
          }
        },
      );
    }
  });
}
