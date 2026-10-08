import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 능력치 하나만 올려 주는 장비를 낀 인벤토리. 목걸이부터 차례로 칸을 채운다.
Inventory wearing(
  Map<StatType, double> stats, {
  CharacterId character = CharacterId.witch,
}) {
  final inv = Inventory();
  final types = [
    ItemType.necklace,
    ItemType.head,
    ItemType.boots,
    ItemType.gloves,
    ItemType.belt,
    ItemType.ring,
    ItemType.ring,
    ItemType.earring,
    ItemType.earring,
  ];
  for (final (i, MapEntry(:key, :value)) in stats.entries.indexed) {
    inv.gear(character).add(item(types[i], stat: key, value: value));
  }
  return inv;
}

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
      '출혈은 물리 피해를 지속 시간 동안 나눠 준다',
      gameWith(Roster.witch, inventory: wearing({StatType.bleedChance: 1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));

        game.world.player.strike(enemy, 20, DamageType.physical);
        expect(enemy.ailments.bleeding, isTrue);
        expect(enemy.hp, enemy.maxHp - 20);

        enemy.update(Balance.bleedDuration + 1);

        expect(enemy.hp, closeTo(enemy.maxHp - 20 - 20, 1e-6));
        expect(enemy.ailments.bleeding, isFalse);
      },
    );

    testWithGame<AshbornGame>(
      '화상은 화염 피해가 섞인 타격에만 걸린다',
      gameWith(Roster.witch, inventory: wearing({StatType.burnChance: 1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));
        final player = game.world.player;

        player.strike(enemy, 10, DamageType.physical);
        expect(enemy.ailments.burning, isFalse);

        player.strike(enemy, 10, DamageType.fire);
        expect(enemy.ailments.burning, isTrue);
      },
    );

    testWithGame<AshbornGame>(
      '중독은 타격마다 쌓인다',
      gameWith(Roster.witch, inventory: wearing({StatType.poisonChance: 1})),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));

        for (var i = 0; i < 3; i++) {
          game.world.player.strike(enemy, 10, DamageType.physical);
        }

        expect(enemy.ailments.poisonStacks, 3);
      },
    );

    testWithGame<AshbornGame>(
      '감전된 적은 피해를 더 받는다',
      gameWith(
        Roster.witch,
        inventory: wearing({
          StatType.shockChance: 1,
          StatType.lightningDamage: 1,
        }),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));

        game.world.player.strike(enemy, 9, DamageType.physical);
        expect(enemy.ailments.shocked, isTrue);

        expect(
          enemy.takeDamage(10),
          closeTo(10 * (1 + Balance.shockEffect), 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '동상에 걸린 적은 느려진다',
      gameWith(
        Roster.witch,
        inventory: wearing({StatType.chillChance: 1, StatType.coldDamage: 1}),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(400, 0));

        game.world.player.strike(enemy, 1, DamageType.physical);
        final start = enemy.position.x;
        enemy.update(0.5);

        expect(enemy.ailments.chilled, isTrue);
        expect(
          start - enemy.position.x,
          closeTo(Balance.enemySpeed * (1 - Balance.chillSlow) * 0.5, 0.01),
        );
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
