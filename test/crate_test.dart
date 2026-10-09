import 'dart:math' as math;

import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/components/pickups/supply_drop.dart';
import 'package:ashborn/components/props/crate.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/supplies.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/game/world/dungeon_floor.dart';
import 'package:ashborn/systems/crate_system.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<Crate> addCrate(
  AshbornGame game,
  Vector2 offset, {
  bool chest = false,
  double hp = 10,
}) async {
  final crate = Crate(
    position: game.world.player.position + offset,
    maxHp: hp,
    chest: chest,
  );
  await game.world.add(crate);
  await game.ready();
  return crate;
}

void main() {
  group('상자', () {
    testWithGame<AshbornGame>(
      '부수면 처치로 치지 않고 보급품이나 장비가 나온다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final crate = await addCrate(game, Vector2(5000, 5000));

        crate.takeDamage(10);
        await game.ready();

        expect(crate.isMounted, isFalse);
        expect(game.stats.kills.value, 0);
        final world = game.world;
        expect(world.children.whereType<AshShard>(), isEmpty);
        expect(
          world.children.whereType<SupplyDrop>().length +
              world.children.whereType<ItemDrop>().length,
          1,
        );
      },
    );

    testWithGame<AshbornGame>(
      '보물 상자는 레어 이상 장비와 골드 주머니를 준다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final crate = await addCrate(game, Vector2(5000, 5000), chest: true);

        crate.takeDamage(10);
        await game.ready();

        final items = game.world.children.whereType<ItemDrop>().toList();
        expect(items, hasLength(1));
        expect(items.single.item.rarity.index, greaterThanOrEqualTo(1));
        final gold = game.world.children.whereType<SupplyDrop>().single;
        expect(gold.supply, Supply.gold);
      },
    );

    testWithGame<AshbornGame>('닿아도 아프지 않고 밀리지도 않는다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final crate = await addCrate(game, Vector2.zero(), hp: 1e9);
      final at = crate.position.clone();

      await advance(game, 0.5);

      expect(game.world.player.hp, Roster.witch.maxHp);
      expect(crate.position, at);
    });

    testWithGame<AshbornGame>('무기가 알아서 겨눠 부순다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final crate = await addCrate(game, Vector2(120, 0));

      await advance(game, 3);

      expect(crate.isMounted, isFalse);
    });

    testWithGame<AshbornGame>('시간이 지나면 플레이어 둘레에 생긴다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await advance(game, Balance.crateFirstDelay + 0.5);

      final crates = game.world.enemies.whereType<Crate>();
      expect(crates, hasLength(1));
      expect(
        crates.single.position.distanceTo(game.world.player.position),
        lessThan(Balance.crateDespawnDistance),
      );
    });

    testWithGame<AshbornGame>(
      '너무 멀어진 상자는 치우고 최대 개수를 넘지 않는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final far = await addCrate(
          game,
          Vector2(Balance.crateDespawnDistance + 100, 0),
        );
        final system = game.world.children.whereType<CrateSystem>().single;
        for (var i = 0; i < Balance.maxCrates + 2; i++) {
          system.update(Balance.crateInterval);
          await game.ready();
        }

        expect(far.isMounted, isFalse);
        expect(game.world.enemies.whereType<Crate>().length, Balance.maxCrates);
      },
    );
  });

  group('보급품', () {
    testWithGame<AshbornGame>(
      '회복 물약은 체력을 채우고, 가득 찼으면 바닥에 남는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        final full = SupplyDrop(
          position: player.position.clone(),
          supply: Supply.potion,
        );
        await game.world.add(full);
        await advance(game, 0.1);
        expect(full.isMounted, isTrue);

        player.hp = 10;
        await advance(game, 0.1);

        expect(full.isMounted, isFalse);
        expect(
          player.hp,
          closeTo(10 + player.maxHp * Balance.potionHeal, 1e-6),
        );
      },
    );

    testWithGame<AshbornGame>('골드 · 강화석은 모아 뒀다가 정산된다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final world = game.world;
      world
        ..collectSupply(Supply.gold, 40)
        ..collectSupply(Supply.stone, 1);

      final loot = world.bankLoot();

      expect(loot.gold, greaterThanOrEqualTo(40));
      expect(loot.stones, greaterThanOrEqualTo(1));
    });

    testWithGame<AshbornGame>('자석은 재의 결정을 모두 끌어당긴다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final world = game.world;
      final shard = AshShard(position: world.player.position + Vector2(800, 0));
      await world.add(shard);
      await game.ready();

      world.collectSupply(Supply.magnet, 1);
      await advance(game, 3);

      expect(shard.isMounted, isFalse);
    });
  });

  test('나무 상자 확률을 모두 더하면 1이고 굴린 결과도 그 비율을 따른다', () {
    final total = CrateDrop.values.fold(
      0.0,
      (sum, d) => sum + LootSystem.crateDropChance(d),
    );
    expect(total, closeTo(1, 1e-9));

    final random = math.Random(1);
    final counts = <CrateDrop, int>{};
    const n = 20000;
    for (var i = 0; i < n; i++) {
      counts.update(
        LootSystem.rollCrate(random),
        (c) => c + 1,
        ifAbsent: () => 1,
      );
    }
    for (final d in CrateDrop.values) {
      expect(counts[d]! / n, closeTo(LootSystem.crateDropChance(d), 0.015));
    }
  });

  group('전투 맵 바닥', () {
    test('같은 타일은 언제나 같은 무늬와 장식이다', () {
      for (var i = 0; i < 200; i++) {
        final x = i * 37 - 3000;
        final y = i * -91 + 1234;
        expect(DungeonFloor.floorAt(x, y), DungeonFloor.floorAt(x, y));
        expect(DungeonFloor.floorAt(x, y), inInclusiveRange(0, 7));
        expect(
          DungeonFloor.propAt(x, y, Region.ashPlains),
          DungeonFloor.propAt(x, y, Region.ashPlains),
        );
      }
    });

    test('지역마다 장식이 있고, 장식 · 기둥 밀도는 밸런스 값을 따른다', () {
      for (final region in Region.values) {
        expect(DungeonFloor.decorSet(region), isNotEmpty);
        var decor = 0;
        var pillars = 0;
        const side = 200;
        for (var x = 0; x < side; x++) {
          for (var y = 0; y < side; y++) {
            switch (DungeonFloor.propAt(x, y, region)) {
              case null:
                break;
              case Decor():
                decor++;
              default:
                pillars++;
            }
          }
        }
        expect(decor / (side * side), closeTo(Balance.floorDecorChance, 0.01));
        expect(
          pillars / (side * side),
          closeTo(Balance.floorPillarChance, 0.003),
        );
      }
    });
  });
}
