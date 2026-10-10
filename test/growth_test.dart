import 'dart:math' as math;

import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/passives.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/level_system.dart';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<AshShard> addShard(AshbornGame game, Vector2 offset) async {
  final shard = AshShard(position: game.world.player.position + offset);
  await game.world.add(shard);
  await game.ready();
  return shard;
}

void main() {
  test('다음 레벨까지 필요한 경험치는 레벨마다 늘어난다', () {
    expect(LevelSystem.xpToNext(1), Balance.xpBase);
    expect(LevelSystem.xpToNext(3), Balance.xpBase + Balance.xpGrowth * 2);
  });

  group('재의 결정', () {
    testWithGame<AshbornGame>('적을 처치하면 그 자리에 떨어진다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final enemy = await addEnemy(game, Vector2(5000, 5000), hp: 1);
      final at = enemy.position.clone();

      enemy.takeDamage(1);
      await game.ready();

      final shard = game.world.children.whereType<AshShard>().single;
      expect(shard.position, at);
    });

    testWithGame<AshbornGame>('자석 범위 안이면 끌려와 경험치가 된다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final shard = await addShard(game, Vector2(Balance.magnetRange - 5, 0));

      await advance(game, 1);

      expect(shard.isMounted, isFalse);
      expect(game.stats.xp.value, Balance.ashShardXp);
    });

    testWithGame<AshbornGame>('자석 범위 밖이면 그대로 있다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final offset = Vector2(Balance.magnetRange + 50, 0);
      final shard = await addShard(game, offset);

      await advance(game, 1);

      expect(shard.isMounted, isTrue);
      expect(shard.position, game.world.player.position + offset);
      expect(game.stats.xp.value, 0);
    });
  });

  testWithGame<AshbornGame>(
    '경험치가 차면 레벨이 오르고 남은 경험치는 이월된다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      final stats = game.stats;
      final toLv3 = LevelSystem.xpToNext(1) + LevelSystem.xpToNext(2);
      // 위젯 없이 돌리므로 레벨업 오버레이 자리만 등록해 둔다.
      game.overlays.addEntry(
        AshbornGame.levelUpOverlay,
        (_, _) => const SizedBox(),
      );

      game.world.gainXp(toLv3 + 2);

      expect(stats.level.value, 3);
      expect(stats.xp.value, 2);
      expect(stats.xpToNext.value, LevelSystem.xpToNext(3));
    },
  );

  group('패시브', () {
    testWithGame<AshbornGame>(
      '최대 체력이 늘면 현재 체력도 같은 비율로 는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        player.takeDamage(30);

        player.gainPassive(PassiveId.vitality);

        final max = Roster.witch.maxHp + Balance.passiveMaxHpPerLevel;
        expect(player.maxHp, max);
        expect(
          player.hp,
          closeTo((Roster.witch.maxHp - 30) * max / Roster.witch.maxHp, 1e-9),
        );
        expect(game.stats.maxHp.value, max);
        expect(game.stats.hp.value, player.hp);
      },
    );

    testWithGame<AshbornGame>('이동 속도와 획득 범위가 레벨만큼 는다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final player = game.world.player;

      player
        ..gainPassive(PassiveId.swiftness)
        ..gainPassive(PassiveId.swiftness)
        ..gainPassive(PassiveId.magnetism);

      expect(
        player.speed,
        closeTo(
          Roster.witch.speed * (1 + Balance.passiveMoveSpeedPerLevel * 2),
          1e-9,
        ),
      );
      expect(
        player.magnetRange,
        Balance.magnetRange * (1 + Balance.passiveMagnetPerLevel),
      );
    });
  });

  group('레벨업 선택지', () {
    testWithGame<AshbornGame>(
      '가진 무기는 다음 레벨, 없는 무기와 패시브는 1레벨로 나온다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final options = LevelSystem.available(game.world.player);

        String describe(LevelUpOption o) => switch (o) {
          WeaponOption(:final id) => '${id.name} ${o.level}',
          AwakenOption(:final id) => 'awaken ${id.name}',
          PassiveOption(:final id) => '${id.name} ${o.level}',
        };
        // 무기는 마녀 전용 넷과 공용 셋만 (기사 · 사냥꾼 전용은 없다).
        expect(options.map(describe), [
          'emberOrb 2',
          'meteor 1',
          'fireTornado 1',
          'emberSpirits 1',
          'ashAura 1',
          'thunder 1',
          'chakram 1',
          for (final p in PassiveId.values) '${p.name} 1',
        ]);
      },
    );

    testWithGame<AshbornGame>('최대 레벨은 선택지에서 빠진다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final player = game.world.player;
      for (var i = 1; i < WeaponId.maxLevel; i++) {
        player.gainWeapon(WeaponId.emberOrb);
      }
      for (var i = 0; i < PassiveId.maxLevel; i++) {
        player.gainPassive(PassiveId.vitality);
      }

      final options = LevelSystem.available(player);

      expect(
        options.whereType<WeaponOption>().map((o) => o.id),
        isNot(contains(WeaponId.emberOrb)),
      );
      expect(
        options.whereType<PassiveOption>().map((o) => o.id),
        isNot(contains(PassiveId.vitality)),
      );
    });

    testWithGame<AshbornGame>(
      '멈춘 동안 얻은 무기도 바로 선택지에 반영된다',
      gameWith(Roster.knight),
      (game) async {
        await game.ready();
        final player = game.world.player;

        // 레벨업 중에는 엔진이 멈춰 있어 새 무기가 아직 마운트되지 않는다.
        player.gainWeapon(WeaponId.emberOrb);

        final orb = LevelSystem.available(player)
            .whereType<WeaponOption>()
            .where((o) => o.id == WeaponId.emberOrb);
        expect(orb.single.level, 2);
      },
    );

    testWithGame<AshbornGame>('한 번에 서로 다른 세 장을 뽑는다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();

      final options = LevelSystem.roll(game.world.player, math.Random(1));

      expect(options, hasLength(Balance.levelUpChoices));
      expect(options.map((o) => o.title).toSet(), hasLength(3));
    });
  });
}
