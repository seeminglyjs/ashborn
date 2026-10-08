import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/components/weapons/flame_blade.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// 게임을 [seconds] 동안 60fps 로 진행시킨다.
Future<void> advance(AshbornGame game, double seconds) async {
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds; t += dt) {
    game.update(dt);
    await game.ready();
  }
}

AshbornGame Function() gameWith(CharacterDef character) =>
    () => AshbornGame(character: character);

/// 웨이브 스폰과 섞이지 않도록 기존 적을 모두 치운다.
Future<void> clearEnemies(AshbornGame game) async {
  for (final e in game.world.enemies.toList()) {
    e.removeFromParent();
  }
  await game.ready();
}

Future<Enemy> addEnemy(
  AshbornGame game,
  Vector2 offset, {
  double hp = 1000,
}) async {
  final enemy = Enemy(position: game.world.player.position + offset, maxHp: hp);
  await game.world.add(enemy);
  await game.ready();
  return enemy;
}

void main() {
  testWithGame<AshbornGame>('시간이 지나면 적이 스폰된다', gameWith(Roster.witch), (
    game,
  ) async {
    await game.ready();
    await advance(game, 3);

    expect(game.world.enemies, isNotEmpty);
  });

  testWithGame<AshbornGame>(
    '체력이 다한 적은 사라지고 처치 수가 오른다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      final enemy = await addEnemy(game, Vector2(5000, 5000), hp: 10);

      enemy.takeDamage(10);
      await advance(game, 0.1);

      expect(enemy.isMounted, isFalse);
      expect(game.world.enemies, isNot(contains(enemy)));
      expect(game.stats.kills.value, 1);
    },
  );

  testWithGame<AshbornGame>('적과 닿으면 피해를 입고 잠시 무적이 된다', gameWith(Roster.witch), (
    game,
  ) async {
    await game.ready();
    final player = game.world.player;
    await addEnemy(game, Vector2.zero());

    await advance(game, Balance.playerInvulnerableTime * 0.5);

    expect(player.hp, Roster.witch.maxHp - Balance.enemyContactDamage);
    expect(game.stats.hp.value, player.hp);
  });

  group('캐릭터', () {
    for (final c in Roster.all) {
      testWithGame<AshbornGame>('${c.name}: 체력과 시작 무기가 적용된다', gameWith(c), (
        game,
      ) async {
        await game.ready();
        final player = game.world.player;
        final weapons = player.children.where(
          (w) => w is EmberOrb || w is FlameBlade || w is FireCrossbow,
        );

        expect(player.maxHp, c.maxHp);
        expect(game.stats.maxHp.value, c.maxHp);
        expect(weapons.single.runtimeType, switch (c.id) {
          CharacterId.knight => FlameBlade,
          CharacterId.witch => EmberOrb,
          CharacterId.hunter => FireCrossbow,
        });
      });
    }

    testWithGame<AshbornGame>('잿불 기사는 받는 피해가 줄어든다', gameWith(Roster.knight), (
      game,
    ) async {
      await game.ready();
      final player = game.world.player;

      player.takeDamage(10);

      expect(player.hp, Roster.knight.maxHp - 10 * 0.8);
    });

    testWithGame<AshbornGame>('불씨 사냥꾼은 더 빠르게 움직인다', gameWith(Roster.hunter), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final start = player.position.clone();

      game.joystick.delta.setValues(game.joystick.knobRadius, 0);
      player.update(1);

      expect(
        player.position.x - start.x,
        closeTo(Balance.playerSpeed * 1.2, 0.01),
      );
    });
  });

  group('무기', () {
    testWithGame<AshbornGame>(
      '잔불 구체가 가까운 적을 자동으로 맞힌다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final enemy = await addEnemy(game, Vector2(150, 0));

        await advance(game, Balance.emberOrbCooldown + 0.5);

        expect(enemy.hp, lessThan(enemy.maxHp));
      },
    );

    testWithGame<AshbornGame>('재의 마녀는 쿨다운이 짧다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final weapon = game.world.player.children.whereType<EmberOrb>().single;

      expect(weapon.cooldown, closeTo(Balance.emberOrbCooldown * 0.8, 1e-9));
    });

    testWithGame<AshbornGame>('대상이 없으면 무기는 쏘지 않는다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);

      final weapon = game.world.player.children.whereType<EmberOrb>().single;
      expect(weapon.fire(), isFalse);
    });

    testWithGame<AshbornGame>('불꽃 대검이 궤도 위의 적을 벤다', gameWith(Roster.knight), (
      game,
    ) async {
      await game.ready();
      final enemy = await addEnemy(
        game,
        Vector2(Balance.flameBladeOrbitRadius, 0),
      );

      // 한 바퀴 돌면 칼날이 반드시 지나간다.
      await advance(game, 2 * 3.1416 / Balance.flameBladeAngularSpeed);

      expect(enemy.hp, lessThan(enemy.maxHp));
    });

    testWithGame<AshbornGame>(
      '화염 석궁 화살은 일렬로 선 적을 여럿 꿰뚫는다',
      gameWith(Roster.hunter),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final line = [
          for (var i = 0; i < 3; i++)
            await addEnemy(game, Vector2(120.0 + i * 40, 0)),
        ];

        final weapon = game.world.player.children
            .whereType<FireCrossbow>()
            .single;
        expect(weapon.fire(), isTrue);
        await advance(game, 0.5);

        for (final enemy in line) {
          expect(enemy.hp, enemy.maxHp - Balance.crossbowDamage);
        }
      },
    );
  });
}
