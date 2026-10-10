import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/components/weapons/element_procs.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('능력치', () {
    testWithGame<AshbornGame>(
      '장착한 장비 능력치가 플레이어에 반영된다',
      gameWith(
        Roster.witch,
        inventory: wearing({
          StatType.maxHp: 20,
          StatType.moveSpeed: 0.1,
          StatType.attackSpeed: 0.25,
          StatType.xpGain: 1,
          StatType.energyShield: 30,
        }),
      ),
      (game) async {
        await game.ready();
        final player = game.world.player;

        expect(player.maxHp, Roster.witch.maxHp + 20);
        expect(player.hp, player.maxHp);
        expect(player.speed, closeTo(Roster.witch.speed * 1.1, 1e-9));
        expect(player.attackSpeedMultiplier, 1.25);
        expect(player.xpMultiplier, 2);
        expect(player.energyShield, 30);
        expect(game.stats.maxEnergyShield.value, 30);
      },
    );

    testWithGame<AshbornGame>(
      '회피와 피해 감소율은 75% 를 넘지 않는다',
      gameWith(
        Roster.witch,
        inventory: wearing({
          StatType.evasion: 2,
          StatType.fireResist: 2,
          StatType.coldResist: 0.3,
        }),
      ),
      (game) async {
        await game.ready();
        final player = game.world.player;

        expect(player.evasion, Balance.maxEvasion);
        expect(player.reduction(DamageType.fire), Balance.maxReduction);
        expect(player.reduction(DamageType.cold), 0.3);
      },
    );
  });

  group('공격', () {
    testWithGame<AshbornGame>(
      '장비의 속성 피해가 무기 타격마다 더해지고 피해 증가가 곱해진다',
      gameWith(
        Roster.hunter,
        inventory: wearing({
          StatType.physicalDamage: 5,
          StatType.fireDamage: 3,
          StatType.damage: 0.5,
        }, character: CharacterId.hunter),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(120, 0));
        final weapon = game.world.player.weapons.single as FireCrossbow;

        weapon.fire();
        await advance(game, 0.5);

        expect(
          enemy.hp,
          closeTo(enemy.maxHp - (Balance.crossbowDamage + 5 + 3) * 1.5, 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '공격 속도만큼 쿨다운이 줄어든다',
      gameWith(
        Roster.hunter,
        inventory: wearing({
          StatType.attackSpeed: 0.25,
        }, character: CharacterId.hunter),
      ),
      (game) async {
        await game.ready();
        final weapon = game.world.player.weapons.single as FireCrossbow;

        expect(weapon.cooldown, closeTo(Balance.crossbowCooldown / 1.25, 1e-9));
      },
    );

    testWithGame<AshbornGame>(
      '치명타는 기본 배율에 치명타 피해가 더해진다',
      gameWith(
        Roster.witch,
        inventory: wearing({StatType.critChance: 1, StatType.critDamage: 0.5}),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));

        final dealt = game.world.player.strike(enemy, 10, DamageType.physical);

        expect(dealt, closeTo(10 * (Balance.critMultiplier + 0.5), 1e-9));
      },
    );

    testWithGame<AshbornGame>(
      '생명력 흡수로 준 피해의 일부를 회복한다',
      gameWith(Roster.witch, inventory: wearing({StatType.lifeSteal: 0.1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        player.takeDamage(30);
        final before = player.hp;
        final enemy = await addEnemy(game, Vector2(5000, 0));

        player.strike(enemy, 50, DamageType.physical);

        expect(player.hp, closeTo(before + 5, 1e-9));
      },
    );
  });

  group('상태이상', () {
    testWithGame<AshbornGame>(
      '출혈은 5초 동안 점점 세지는 지속 피해를 주고, 출혈 중에 맞으면 더 아프다',
      gameWith(Roster.witch, inventory: wearing({StatType.bleedChance: 1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));
        final player = game.world.player;

        player.strike(enemy, 20, DamageType.physical);
        expect(enemy.ailments.bleeding, isTrue);
        expect(enemy.hp, enemy.maxHp - 20);
        final early = enemy.ailments.bleedDps;
        enemy.update(1);
        expect(enemy.ailments.bleedDps, greaterThan(early), reason: '점점 세진다');

        final before = enemy.hp;
        player.strike(enemy, 20, DamageType.physical);
        expect(
          before - enemy.hp,
          closeTo(20 * (1 + Balance.bleedHitBonus), 1e-6),
          reason: '출혈 중 직접 타격은 추가 피해',
        );

        for (var i = 0; i < 60; i++) {
          enemy.update(0.1);
        }
        expect(enemy.ailments.bleeding, isFalse);
      },
    );

    testWithGame<AshbornGame>(
      '중독은 겹치지 않고 마지막 것으로 덮어쓰며 이동을 늦춘다',
      gameWith(Roster.witch, inventory: wearing({StatType.poisonChance: 1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));
        final player = game.world.player;

        player.strike(enemy, 50, DamageType.physical);
        player.strike(enemy, 10, DamageType.physical);

        expect(enemy.ailments.poisoned, isTrue);
        expect(
          enemy.ailments.poisonDps,
          closeTo(10 * Balance.poisonRatio / Balance.poisonDuration, 1e-9),
        );
        expect(enemy.ailments.speedMultiplier, 1 - Balance.poisonSlow);
      },
    );

    testWithGame<AshbornGame>('중독은 가끔 옆의 적에게 옮는다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final a = await addEnemy(game, Vector2(5000, 0));
      final b = await addEnemy(game, Vector2(5030, 0));
      a.ailments.poison(100);

      // 1초마다 낮은 확률로 굴리니, 충분히 오래 두면 한 번은 옮는다.
      for (var i = 0; i < 400 && !b.ailments.poisoned; i++) {
        a.ailments.poison(100);
        a.update(0.25);
        b.position.setFrom(a.position + Vector2(30, 0));
      }
      expect(b.ailments.poisoned, isTrue);
    });

    testWithGame<AshbornGame>(
      '화염 피해가 문턱만큼 쌓이면 점화되어 0.5초마다 탄다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));
        final player = game.world.player;
        final threshold = enemy.ailmentThreshold;

        player.strike(enemy, threshold * 0.5, DamageType.physical);
        expect(enemy.ailments.ignited, isFalse, reason: '물리는 쌓이지 않는다');

        player.strike(enemy, threshold * 0.6, DamageType.fire);
        expect(enemy.ailments.ignited, isFalse);
        player.strike(enemy, threshold * 0.6, DamageType.fire);
        expect(enemy.ailments.ignited, isTrue);
        expect(
          enemy.ailments.igniteTick,
          closeTo(threshold * 0.6 * Balance.igniteRatio, 1e-6),
        );

        final before = enemy.hp;
        enemy.update(Balance.igniteInterval + 0.01);
        expect(before - enemy.hp, closeTo(enemy.ailments.igniteTick, 1e-6));
      },
    );

    testWithGame<AshbornGame>(
      '냉기가 쌓이면 냉각, 냉각 중에 또 쌓이면 1초 동결되고 움직이지 못한다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(400, 0));
        final player = game.world.player;
        final threshold = enemy.ailmentThreshold;

        player.strike(enemy, threshold, DamageType.cold);
        expect(enemy.ailments.chilled, isTrue);
        expect(enemy.ailments.frozen, isFalse);
        enemy.knockback.setZero();
        var start = enemy.position.x;
        enemy.update(0.5);
        expect(
          start - enemy.position.x,
          closeTo(Balance.enemySpeed * (1 - Balance.chillSlow) * 0.5, 0.01),
        );

        player.strike(enemy, threshold, DamageType.cold);
        expect(enemy.ailments.frozen, isTrue);
        expect(enemy.disabled, isTrue);
        enemy.knockback.setZero();
        start = enemy.position.x;
        enemy.update(0.5);
        expect(enemy.position.x, start, reason: '얼어서 움직이지 못한다');

        enemy.update(Balance.freezeDuration);
        expect(enemy.ailments.frozen, isFalse);
      },
    );

    testWithGame<AshbornGame>(
      '얼어 있다 쓰러지면 6방향으로 얼음 파편이 튄다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0), hp: 100);
        final player = game.world.player;
        final threshold = enemy.ailmentThreshold;

        player.strike(enemy, threshold, DamageType.cold);
        player.strike(enemy, threshold, DamageType.cold);
        expect(enemy.ailments.frozen, isTrue);
        player.strike(enemy, 1000, DamageType.physical);
        await game.ready();

        expect(
          game.world.children.whereType<IceShard>().length,
          Balance.shardCount,
        );
      },
    );

    testWithGame<AshbornGame>(
      '번개가 쌓이면 감전되어 잠깐 굳고 주변 적에게 연쇄 번개가 튄다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));
        final other = await addEnemy(game, Vector2(5060, 0));
        final player = game.world.player;

        player.strike(enemy, enemy.ailmentThreshold, DamageType.lightning);

        expect(enemy.ailments.stunned, isTrue);
        expect(enemy.disabled, isTrue);
        expect(other.hp, lessThan(other.maxHp), reason: '연쇄 번개');
        enemy.update(Balance.shockStun + 0.01);
        expect(enemy.ailments.stunned, isFalse);
      },
    );

    testWithGame<AshbornGame>(
      '바람 피해가 섞인 타격은 바람 검기나 소용돌이를 일으킨다',
      gameWith(Roster.witch, inventory: wearing({StatType.windDamage: 5})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0), hp: 1e9);
        final player = game.world.player;

        // 확률이 낮고 재사용 대기 시간이 있어 시간을 흘려 가며 여러 번 때린다.
        for (var i = 0; i < 400; i++) {
          player.strike(enemy, 1, DamageType.physical);
          game.world.elapsed += 1.3;
        }
        await game.ready();

        expect(game.world.children.whereType<WindSlash>(), isNotEmpty);
        expect(game.world.children.whereType<Vortex>(), isNotEmpty);
      },
    );
  });

  group('방어', () {
    testWithGame<AshbornGame>(
      '방어력은 물리 피해만, 저항은 그 속성 피해만 줄인다',
      gameWith(
        Roster.witch,
        inventory: wearing({StatType.armor: 100, StatType.fireResist: 0.5}),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;

        player.takeDamage(20);
        expect(player.hp, Roster.witch.maxHp - 10);

        await advance(game, Balance.playerInvulnerableTime + 0.1);
        player.takeDamage(20, type: DamageType.fire);
        expect(player.hp, Roster.witch.maxHp - 20);

        await advance(game, Balance.playerInvulnerableTime + 0.1);
        player.takeDamage(20, type: DamageType.cold);
        expect(player.hp, Roster.witch.maxHp - 40);
      },
    );

    testWithGame<AshbornGame>(
      '에너지 보호막이 먼저 막고, 한동안 맞지 않으면 다시 찬다',
      gameWith(Roster.witch, inventory: wearing({StatType.energyShield: 20})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;

        player.takeDamage(30);
        expect(player.energyShield, 0);
        expect(player.hp, Roster.witch.maxHp - 10);

        await advance(game, Balance.energyShieldRechargeDelay - 0.5);
        expect(player.energyShield, 0);

        await advance(game, 0.5 + 1 / Balance.energyShieldRechargeRate);
        expect(player.energyShield, closeTo(20, 1e-9));
        expect(game.stats.energyShield.value, player.energyShield);
      },
    );

    testWithGame<AshbornGame>(
      '런 도중 장비를 바꾸면 체력은 같은 비율을 유지한다',
      gameWith(Roster.witch, inventory: wearing({StatType.maxHp: 30})),
      (game) async {
        await game.ready();
        final player = game.world.player;
        player.takeDamage(40);
        final ratio = player.hp / player.maxHp;

        game.gear.unequip(EquipSlot.necklace);
        expect(player.maxHp, Roster.witch.maxHp);
        expect(player.hp / player.maxHp, closeTo(ratio, 1e-9));

        // 뺐다 다시 껴도 체력이 공짜로 차지 않는다.
        game.gear.equip(game.inventory.bag.single, EquipSlot.necklace);
        expect(player.hp / player.maxHp, closeTo(ratio, 1e-9));
        expect(game.stats.hp.value, player.hp);
      },
    );

    testWithGame<AshbornGame>(
      '체력 재생으로 체력이 찬다',
      gameWith(Roster.witch, inventory: wearing({StatType.hpRegen: 2})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        player.takeDamage(10);

        player.update(1);

        expect(player.hp, Roster.witch.maxHp - 8);
      },
    );
  });

  group('줍기', () {
    testWithGame<AshbornGame>(
      '가방이 가득 차면 낄 칸이 없는 장비는 바닥에 남는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        game.gear.add(item(ItemType.belt));
        for (var i = 0; i < Balance.bagCapacity; i++) {
          game.gear.add(item(ItemType.belt));
        }
        final drop = ItemDrop(
          position: game.world.player.position + Vector2(20, 0),
          item: item(ItemType.belt),
        );
        await game.world.add(drop);

        await advance(game, 0.5);

        expect(drop.isMounted, isTrue);
        expect(game.inventory.bag, hasLength(Balance.bagCapacity));
      },
    );

    testWithGame<AshbornGame>(
      '경험치 획득량이 재의 결정에 적용된다',
      gameWith(Roster.witch, inventory: wearing({StatType.xpGain: 1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        await game.world.add(AshShard(position: game.world.player.position));

        await advance(game, 0.1);

        expect(game.stats.xp.value, Balance.ashShardXp * 2);
      },
    );

    testWithGame<AshbornGame>(
      '바닥의 장비를 주우면 인벤토리에 들어간다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final helm = item(ItemType.head, rarity: Rarity.unique);
        await game.world.add(
          ItemDrop(
            position: game.world.player.position + Vector2(20, 0),
            item: helm,
          ),
        );

        await advance(game, 0.5);

        expect(game.gear.equipped[EquipSlot.head], helm);
        expect(game.world.children.whereType<ItemDrop>(), isEmpty);
      },
    );
  });
}
