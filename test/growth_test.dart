import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/passives.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
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

      game.world.gainXp(toLv3 + 2);

      expect(stats.level.value, 3);
      expect(stats.xp.value, 2);
      expect(stats.xpToNext.value, LevelSystem.xpToNext(3));
    },
  );

  group('패시브', () {
    testWithGame<AshbornGame>(
      '최대 체력이 늘면 현재 체력도 같이 는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        player.takeDamage(30);

        player.gainPassive(PassiveId.vitality);

        final max = Roster.witch.maxHp + Balance.passiveMaxHpPerLevel;
        expect(player.maxHp, max);
        expect(player.hp, max - 30);
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
}
