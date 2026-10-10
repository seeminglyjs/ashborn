import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/components/enemies/hazards.dart';
import 'package:ashborn/components/enemies/minions.dart';
import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/enemies.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/game/world/dungeon_floor.dart';
import 'package:ashborn/game/world/obstacles.dart';
import 'package:ashborn/game/world/region_theme.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// [kind] 졸개 하나를 플레이어에게서 [offset] 떨어진 곳에 세운다.
Future<Enemy> addMinion(
  AshbornGame game,
  EnemyKind kind,
  Vector2 offset, {
  double hp = 1000,
}) async {
  final enemy = spawnMinion(
    kind,
    position: game.world.player.position + offset,
    maxHp: hp,
    contactDamage: 10,
    damageType: DamageType.physical,
    speed: Balance.enemySpeed,
    color: const Color(0xFFFFFFFF),
  );
  await game.world.add(enemy);
  await game.ready();
  return enemy;
}

/// [theme] 에서 [test] 를 만족하는 첫 타일.
(int, int) findTile(bool Function(int, int) test) {
  for (var r = 0; r < 400; r++) {
    for (var gx = -r; gx <= r; gx++) {
      for (final gy in [-r, r]) {
        if (test(gx, gy)) return (gx, gy);
      }
    }
  }
  throw StateError('타일을 찾지 못했다');
}

void main() {
  test('스테이지 시간이 지나며 로스터 순서대로 졸개 종류가 풀린다', () {
    final region = Region.ashPlains;
    expect(WaveSystem.unlocked(region, 0), region.roster.take(2));
    expect(
      WaveSystem.unlocked(region, Balance.rosterUnlock.last),
      region.roster,
    );
    for (final r in Region.values) {
      // 같은 행동은 많아야 두 종류 (나머지는 모두 다르다).
      final behaviors = r.roster.map((k) => k.behavior).toList();
      for (final b in behaviors.toSet()) {
        expect(
          behaviors.where((x) => x == b).length,
          lessThanOrEqualTo(2),
          reason: '${r.label}: ${b.label}',
        );
      }
      expect(behaviors.toSet().length, greaterThanOrEqualTo(6));
    }
  });

  group('졸개 행동', () {
    testWithGame<AshbornGame>(
      '분열은 쓰러지면 둘로 갈라지고, 새끼는 결정을 남기지 않는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final slime = await addMinion(
          game,
          EnemyKind.ashSlime,
          Vector2(300, 0),
        );
        slime.takeDamage(1e9);
        await game.ready();

        final kids = game.world.enemies.whereType<Splitter>().toList();
        expect(kids, hasLength(Balance.splitCount));
        expect(kids.every((k) => k.child), isTrue);
        expect(game.world.children.whereType<AshShard>(), hasLength(1));

        for (final k in kids) {
          k.takeDamage(1e9);
        }
        await game.ready();
        expect(game.world.enemies.whereType<Splitter>(), isEmpty);
        expect(game.world.children.whereType<AshShard>(), hasLength(1));
      },
    );

    testWithGame<AshbornGame>('거구는 결정을 여럿 남기고 덜 밀린다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final ogre = await addMinion(game, EnemyKind.ashOgre, Vector2(300, 0));
      ogre.knock(Vector2(1, 0), 100);
      expect(
        ogre.knockback.length,
        closeTo(100 * Balance.bruteKnockback, 1e-6),
      );
      ogre.takeDamage(1e9);
      await game.ready();
      expect(
        game.world.children.whereType<AshShard>(),
        hasLength(EnemyKind.ashOgre.xp),
      );
    });

    testWithGame<AshbornGame>(
      '돌진은 멈춰서 힘을 모은 뒤 빠르게 내달린다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final orc = await addMinion(
          game,
          EnemyKind.ashRaider,
          Vector2(200, 0),
        ) as Charger;
        await advance(game, Balance.chargeCooldown * 0.5 + 0.05);
        expect(orc.isWindingUp, isTrue);
        final before = orc.position.clone();
        await advance(game, 0.2);
        expect(orc.position.distanceTo(before), lessThan(5));

        await advance(game, Balance.chargeWindup);
        expect(orc.isDashing, isTrue);
      },
    );

    testWithGame<AshbornGame>('사격은 탄을 쏘고, 탄에 맞으면 다친다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      await addMinion(game, EnemyKind.boneThrower, Vector2(150, 0));
      for (var i = 0; i < 60; i++) {
        await advance(game, 0.1);
        if (game.world.children.whereType<EnemyBullet>().isNotEmpty) break;
      }
      expect(game.world.children.whereType<EnemyBullet>(), isNotEmpty);
      final hp = player.hp;
      await advance(game, 1.5);
      expect(player.hp, lessThan(hp));
    });

    testWithGame<AshbornGame>('자폭은 가까이 오면 깜빡이다 터진다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final bomber = await addMinion(
        game,
        EnemyKind.bloatedDrowned,
        Vector2(40, 0),
      ) as Bomber;
      await advance(game, 1 / 60);
      expect(bomber.isLit, isTrue);
      final hp = player.hp;
      // 접촉 피해 무적 시간이 끝난 뒤에 터지도록 조금 더 기다린다.
      await advance(game, Balance.bomberFuse + 0.1);
      expect(bomber.isMounted, isFalse);
      expect(player.hp, lessThan(hp));
      expect(game.stats.kills.value, 0, reason: '스스로 터지면 처치가 아니다');
    });

    testWithGame<AshbornGame>(
      '주술은 플레이어 발밑에 예고 장판을 깐다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        await addMinion(game, EnemyKind.paleChanter, Vector2(200, 0));
        for (var i = 0; i < 80; i++) {
          await advance(game, 0.1);
          if (game.world.children.whereType<GroundBlast>().isNotEmpty) break;
        }
        final blast = game.world.children.whereType<GroundBlast>().single;
        expect(blast.exploded, isFalse);
        expect(
          blast.position.distanceTo(game.world.player.position),
          lessThan(Balance.casterBlastRadius),
        );
      },
    );
  });

  group('맵', () {
    testWithGame<AshbornGame>(
      '기둥 밑동은 발로 지나갈 수 없다',
      gameWith(Roster.witch, stage: const Stage(1)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final world = game.world;
        final (gx, gy) = findTile(
          (x, y) => world.obstacles.structureAt(x, y) != null,
        );
        final foot = Obstacles.footOf(gx, gy);
        // 발 자리가 밑동 한가운데 오도록 세운다.
        final player = world.player
          ..position.setValues(foot.x, foot.y - Balance.playerFootOffset);
        await advance(game, 1 / 60);
        final s = world.obstacles.structureAt(gx, gy)!;
        final feet = player.position + Vector2(0, Balance.playerFootOffset);
        expect(
          feet.distanceTo(foot),
          greaterThanOrEqualTo(
            s.foot * DungeonFloor.pixel + Balance.playerFootRadius - 1e-3,
          ),
        );
      },
    );

    testWithGame<AshbornGame>(
      '솟은 가시를 밟으면 다친다',
      gameWith(Roster.witch, stage: const Stage(3)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final world = game.world;
        final theme = RegionTheme.of(world.stage.region);
        final (gx, gy) = findTile(
          (x, y) => TrapSystem.trapAt(x, y, theme) == Decor.spikes,
        );
        final player = world.player;
        const tile = DungeonFloor.tile * DungeonFloor.pixel;
        final center = Vector2((gx + 0.5) * tile, (gy + 0.5) * tile);

        // 가시가 솟을 때까지 그 자리에 서 있는다.
        final hp = player.hp;
        for (var i = 0; i < 300 && player.hp >= hp; i++) {
          player.position.setFrom(center);
          await advance(game, 1 / 60);
        }
        expect(player.hp, lessThan(hp));
        expect(TrapSystem.spikeState(gx, gy, world.elapsed), TrapState.up);
      },
    );
  });
}
