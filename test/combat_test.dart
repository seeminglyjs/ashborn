import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/components/weapons/greatsword.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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
          (w) => w is EmberOrb || w is Greatsword || w is FireCrossbow,
        );

        expect(player.maxHp, c.maxHp);
        expect(game.stats.maxHp.value, c.maxHp);
        expect(weapons.single.runtimeType, switch (c.id) {
          CharacterId.knight => Greatsword,
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

    testWithGame<AshbornGame>('강철 대검은 앞의 적을 꿰뚫어 찌른다', gameWith(Roster.knight), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final near = await addEnemy(game, Vector2(50, 0));
      final far = await addEnemy(game, Vector2(110, 0));
      final behind = await addEnemy(game, Vector2(-60, 0));

      final sword =
          game.world.player.weapon(WeaponId.greatsword)! as Greatsword;
      expect(sword.moves, [SwordMove.thrust]);
      expect(sword.fire(), isTrue);
      // 칼이 닿는 순간까지 진행한다. 적이 밀려나지 않게 자리를 지킨다.
      for (var i = 0; i < 20; i++) {
        game.update(1 / 60);
        near.position.setFrom(game.world.player.position + Vector2(50, 0));
      }

      const thrust = Balance.thrustDamage * Balance.thrustPower;
      expect(near.hp, closeTo(near.maxHp - thrust, 1e-9));
      expect(far.hp, closeTo(far.maxHp - thrust, 1e-9), reason: '꿰뚫는다');
      expect(behind.hp, behind.maxHp, reason: '뒤는 찌르지 않는다');
    });

    testWithGame<AshbornGame>(
      '강철 대검은 레벨에 따라 휘두르기 · 내려찍기를 익혀 차례로 쓴다',
      gameWith(Roster.knight),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final sword = player.weapon(WeaponId.greatsword)! as Greatsword;
        for (var i = 1; i < Balance.slamLevel; i++) {
          player.gainWeapon(WeaponId.greatsword);
        }
        expect(sword.moves, [
          SwordMove.thrust,
          SwordMove.swing,
          SwordMove.slam,
        ]);
        expect(
          WeaponId.greatsword.upgradeText(Balance.swingLevel),
          startsWith('휘두르기 습득'),
        );
        expect(
          WeaponId.greatsword.upgradeText(Balance.slamLevel),
          startsWith('내려찍기 습득'),
        );
        expect(
          WeaponId.greatsword.upgradeText(Balance.onslaughtLevel),
          startsWith('맹공 습득'),
        );
      },
    );

    testWithGame<AshbornGame>(
      '콤보가 두 번 연달아 나면 맹공으로 쿨다운이 줄어든다',
      gameWith(Roster.knight),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        final sword = player.weapon(WeaponId.greatsword)! as Greatsword;
        while (sword.level < Balance.onslaughtLevel) {
          player.gainWeapon(WeaponId.greatsword);
        }
        final enemy = await addEnemy(game, Vector2(60, 0), hp: 1e9);
        final normal = sword.cooldown;

        // 콤보가 날 때까지 휘두르게 둔다. 맞아서 밀려나도 제자리로 돌려놓는다.
        for (var i = 0; i < 6000 && !sword.inOnslaught; i++) {
          game.update(1 / 30);
          enemy.position.setFrom(player.position + Vector2(60, 0));
        }

        expect(sword.combos, greaterThanOrEqualTo(Balance.onslaughtStreak));
        expect(sword.inOnslaught, isTrue);
        expect(
          sword.cooldown,
          closeTo(normal * Balance.onslaughtCooldown, 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '사냥 석궁 화살은 일렬로 선 적을 여럿 꿰뚫는다',
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

  group('무기 레벨', () {
    test('레벨업 효과 설명', () {
      expect(WeaponId.emberOrb.upgradeText(2), '구체 +1');
      expect(WeaponId.emberOrb.upgradeText(3), '피해 +20%');
      expect(
        WeaponId.fireCrossbow.upgradeText(2),
        '연사 습득, 연사 확률 +15%, 피해 +10%',
      );
      expect(WeaponId.greatsword.upgradeText(5), '피해 +25%');
      expect(WeaponId.fireTornado.upgradeText(2), '지속 시간 +25%');
      expect(WeaponId.earthSlam.upgradeText(4), '쿨다운 -12%');
    });

    test('무기마다 최대 레벨까지 오를 것이 정해져 있고, 같은 표를 쓰지 않는다', () {
      for (final id in WeaponId.values) {
        expect(id.upgrades, hasLength(WeaponId.maxLevel - 1), reason: id.name);
      }
      final tables = WeaponId.values.map((id) => id.upgrades.toString());
      expect(tables.toSet(), hasLength(WeaponId.values.length));
    });

    test('캐릭터마다 전용 무기 셋과 공용 무기를 얻을 수 있다', () {
      for (final c in Roster.all) {
        final pool = WeaponId.poolFor(c.id);
        expect(pool, contains(c.startWeapon));
        expect(pool.where((id) => id.owner == c.id), hasLength(3));
        expect(pool.where((id) => id.owner == null), hasLength(3));
      }
    });

    testWithGame<AshbornGame>(
      '레벨이 오르면 피해와 연사 확률이 는다',
      gameWith(Roster.hunter),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        player
          ..gainWeapon(WeaponId.fireCrossbow)
          ..gainWeapon(WeaponId.fireCrossbow);
        final weapon = player.children.whereType<FireCrossbow>().single;
        expect(weapon.level, 3);
        expect(weapon.volleyChance, closeTo(0.15, 1e-9));

        final enemy = await addEnemy(game, Vector2(120, 0));
        weapon.fire();
        await advance(game, 0.5);

        // 연사가 나면 한 발 더 맞는다.
        final hits = (enemy.maxHp - enemy.hp) / (Balance.crossbowDamage * 1.1);
        expect(hits.round(), anyOf(1, 2));
        expect(hits, closeTo(hits.roundToDouble(), 1e-9));
      },
    );

    testWithGame<AshbornGame>('잔불 구체는 3레벨에 두 발을 쏜다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      player
        ..gainWeapon(WeaponId.emberOrb)
        ..gainWeapon(WeaponId.emberOrb);
      await addEnemy(game, Vector2(150, 0));

      player.children.whereType<EmberOrb>().single.fire();
      await game.ready();

      expect(game.world.children.whereType<EmberBolt>(), hasLength(2));
    });

    testWithGame<AshbornGame>(
      '강철 대검은 레벨이 오를수록 콤보 확률이 오른다',
      gameWith(Roster.knight),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final sword = player.children.whereType<Greatsword>().single;
        expect(sword.comboChance, 0);
        player
          ..gainWeapon(WeaponId.greatsword)
          ..gainWeapon(WeaponId.greatsword);
        expect(sword.comboChance, closeTo(0.2, 1e-9));
      },
    );

    testWithGame<AshbornGame>('다른 캐릭터의 무기도 얻을 수 있다', gameWith(Roster.knight), (
      game,
    ) async {
      await game.ready();
      final player = game.world.player;

      player.gainWeapon(WeaponId.emberOrb);
      await game.ready();

      expect(player.weapons.map((w) => w.id), [
        WeaponId.greatsword,
        WeaponId.emberOrb,
      ]);
      expect(player.weapon(WeaponId.emberOrb)!.level, 1);
    });
  });
}
