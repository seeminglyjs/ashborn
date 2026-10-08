import 'dart:convert';
import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  group('드랍', () {
    test('등급이 오를 때마다 확률이 일정 배율로 줄어든다', () {
      final chances = Rarity.values.map(LootSystem.rarityChance).toList();

      expect(chances.reduce((a, b) => a + b), closeTo(1, 1e-9));
      for (var i = 1; i < chances.length; i++) {
        expect(
          chances[i] / chances[i - 1],
          closeTo(Balance.rarityDropRatio, 1e-9),
        );
      }
    });

    test('뽑힌 등급 분포가 확률을 따른다', () {
      final random = math.Random(7);
      const n = 200000;
      final counts = {for (final r in Rarity.values) r: 0};
      for (var i = 0; i < n; i++) {
        counts.update(LootSystem.rollRarity(random), (c) => c + 1);
      }

      for (final r in Rarity.values.take(4)) {
        expect(counts[r]! / n, closeTo(LootSystem.rarityChance(r), 0.005));
      }
      expect(counts[Rarity.unique]!, lessThan(counts[Rarity.epic]!));
    });

    test('처치당 장비가 떨어질 확률', () {
      final random = math.Random(3);
      const n = 100000;
      var drops = 0;
      for (var i = 0; i < n; i++) {
        if (LootSystem.rollDrop(random) != null) drops++;
      }

      expect(drops / n, closeTo(Balance.itemDropChance, 0.003));
    });
  });

  group('랜덤옵션', () {
    test('옵션 등급은 장비 등급을 넘지 않고, 낮을수록 흔하다', () {
      for (final cap in Rarity.values) {
        final chances = [
          for (final r in Rarity.values) LootSystem.affixRarityChance(r, cap),
        ];
        expect(chances.reduce((a, b) => a + b), closeTo(1, 1e-9));
        for (final r in Rarity.values) {
          if (r.index > cap.index) expect(chances[r.index], 0);
        }
      }

      final random = math.Random(9);
      for (var i = 0; i < 2000; i++) {
        final it = LootSystem.generate(random, rarity: Rarity.rare);
        for (final roll in it.stats.skip(1)) {
          expect(roll.rarity.index, lessThanOrEqualTo(Rarity.rare.index));
        }
      }
    });

    test('고유 장비에도 낮은 등급 옵션이 붙을 수 있다', () {
      final random = math.Random(10);
      final grades = <Rarity>{};
      for (var i = 0; i < 500; i++) {
        final it = LootSystem.generate(random, rarity: Rarity.unique);
        grades.addAll(it.stats.skip(1).map((s) => s.rarity));
      }

      expect(grades, containsAll([Rarity.normal, Rarity.rare, Rarity.hero]));
    });

    test('옵션은 최대 5개이고, 등급이 높을수록 많이 붙는다', () {
      final random = math.Random(11);
      double average(Rarity rarity) {
        var total = 0;
        for (var i = 0; i < 5000; i++) {
          final count = LootSystem.rollAffixCount(random, rarity);
          expect(count, inInclusiveRange(0, Balance.maxAffixes));
          total += count;
        }
        return total / 5000;
      }

      final averages = Rarity.values.map(average).toList();
      for (var i = 1; i < averages.length; i++) {
        expect(averages[i], greaterThan(averages[i - 1]));
      }
      expect(averages.first, greaterThan(0));
    });

    test('주옵션은 파츠가 정한 후보 중 하나이고 옵션끼리 겹치지 않는다', () {
      final random = math.Random(1);
      for (final type in ItemType.values) {
        for (final rarity in Rarity.values) {
          final it = LootSystem.generate(random, type: type, rarity: rarity);
          final stats = it.stats.map((s) => s.stat).toList();

          expect(type.mainStats, contains(stats.first));
          expect(it.stats.first.rarity, rarity);
          expect(stats.toSet(), hasLength(stats.length));
          expect(it.stats.every((s) => s.value > 0), isTrue);
        }
      }
    });

    test('등급이 높을수록 수치가 크다', () {
      final random = math.Random(2);
      double scaled(Rarity r) {
        final main = LootSystem.generate(
          random,
          type: ItemType.gloves,
          rarity: r,
        ).stats.first;
        return main.value / main.stat.roll;
      }

      for (var i = 0; i < 50; i++) {
        expect(scaled(Rarity.unique), greaterThan(scaled(Rarity.normal)));
      }
    });
  });

  group('인벤토리', () {
    test('빈 칸이 있으면 바로 끼고, 칸이 차면 가방에 넣는다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final rings = [for (var i = 0; i < 3; i++) item(ItemType.ring)];

      rings.forEach(gear.add);

      expect(gear.equipped[EquipSlot.ring1], rings[0]);
      expect(gear.equipped[EquipSlot.ring2], rings[1]);
      expect(inv.bag, [rings[2]]);
    });

    test('양손장비는 두 손이 다 비어야 바로 낀다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final sword = item(ItemType.oneHand);
      final greatsword = item(ItemType.twoHand);

      gear
        ..add(sword)
        ..add(greatsword);

      expect(gear.equipped[EquipSlot.hand1], sword);
      expect(inv.bag, [greatsword]);
    });

    test('양손장비를 끼면 두 손의 장비가 가방으로 간다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final a = item(ItemType.oneHand);
      final b = item(ItemType.oneHand);
      final greatsword = item(ItemType.twoHand);
      gear
        ..add(a)
        ..add(b)
        ..add(greatsword);
      expect(gear.equipped[EquipSlot.hand2], b);

      gear.equip(greatsword, EquipSlot.hand1);

      expect(gear.equipped[EquipSlot.hand1], greatsword);
      expect(gear.equipped[EquipSlot.hand2], isNull);
      expect(gear.offHandBlocked, isTrue);
      expect(inv.bag, unorderedEquals([a, b]));
    });

    test('양손장비를 낀 채 보조 손에 끼면 양손장비가 빠진다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final greatsword = item(ItemType.twoHand);
      final dagger = item(ItemType.oneHand);
      gear
        ..add(greatsword)
        ..add(dagger);
      expect(inv.bag, [dagger]);

      gear.equip(dagger, EquipSlot.hand2);

      expect(gear.equipped[EquipSlot.hand1], isNull);
      expect(gear.equipped[EquipSlot.hand2], dagger);
      expect(inv.bag, [greatsword]);
    });

    test('같은 칸에 끼면 원래 장비와 맞바꾼다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final old = item(ItemType.head);
      final better = item(ItemType.head, rarity: Rarity.legend);
      gear
        ..add(old)
        ..add(better);

      gear.equip(better, EquipSlot.head);

      expect(gear.equipped[EquipSlot.head], better);
      expect(inv.bag, [old]);
    });

    test('해제하면 가방으로, 분해하면 사라지고 잔불이 된다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final helm = item(ItemType.head);
      gear.add(helm);

      gear.unequip(EquipSlot.head);
      expect(gear.equipped, isEmpty);
      expect(inv.bag, [helm]);

      inv.salvage(helm);
      expect(inv.bag, isEmpty);
      expect(inv.ember, helm.salvageValue);
    });

    test('장착한 장비의 주옵션과 랜덤옵션을 모두 합산한다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      gear
        ..add(
          item(
            ItemType.head,
            value: 12,
            extra: [
              (stat: StatType.damage, value: 0.05, rarity: Rarity.normal),
            ],
          ),
        )
        ..add(item(ItemType.necklace, stat: StatType.damage, value: 0.1))
        ..add(item(ItemType.head, value: 99));

      expect(gear.bonus(StatType.maxHp), 12);
      expect(gear.bonus(StatType.damage), closeTo(0.15, 1e-9));
    });
  });

  group('캐릭터별 장착과 공용 가방', () {
    test('장착은 캐릭터마다 따로이고 가방은 함께 쓴다', () {
      final inv = Inventory();
      final knight = inv.gear(CharacterId.knight);
      final witch = inv.gear(CharacterId.witch);
      final helm = item(ItemType.head, value: 30);

      knight.add(helm);
      expect(knight.equipped[EquipSlot.head], helm);
      expect(witch.equipped, isEmpty);
      expect(witch.bonus(StatType.maxHp), 0);

      knight.unequip(EquipSlot.head);
      witch.equip(inv.bag.single, EquipSlot.head);
      expect(witch.equipped[EquipSlot.head], helm);
      expect(knight.equipped, isEmpty);
      expect(inv.bag, isEmpty);
    });

    test('가방이 차면 빈 칸에 낄 장비만 주울 수 있다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      gear.add(item(ItemType.head));
      for (var i = 0; i < Balance.bagCapacity; i++) {
        gear.add(item(ItemType.head));
      }

      expect(inv.bagFull, isTrue);
      expect(gear.canAdd(item(ItemType.head)), isFalse);
      expect(gear.canAdd(item(ItemType.boots)), isTrue);
    });

    test('끼면 빠지는 장비를 미리 알려 준다', () {
      final inv = Inventory();
      final gear = inv.gear(CharacterId.witch);
      final a = item(ItemType.oneHand);
      final b = item(ItemType.oneHand);
      gear
        ..add(a)
        ..add(b);

      expect(gear.displacedBy(item(ItemType.twoHand), EquipSlot.hand1), [a, b]);
      expect(gear.displacedBy(item(ItemType.oneHand), EquipSlot.hand2), [b]);
    });
  });

  group('저장', () {
    test('JSON 으로 저장했다가 그대로 불러온다', () {
      final random = math.Random(5);
      final inv = Inventory();
      for (final character in CharacterId.values) {
        for (var i = 0; i < 15; i++) {
          inv.gear(character).add(LootSystem.generate(random));
        }
      }

      final json = jsonEncode(inv.toJson());
      final loaded = Inventory.fromJson(jsonDecode(json));

      expect(jsonEncode(loaded.toJson()), json);
      expect(loaded.bag, hasLength(inv.bag.length));
    });

    test('바뀔 때마다 기기에 저장되고 다음 실행에 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      final first = (await Profile.load()).inventory;
      first
          .gear(CharacterId.hunter)
          .add(item(ItemType.boots, rarity: Rarity.epic, value: 0.12));
      await pumpEventQueue();

      final second = (await Profile.load()).inventory;

      final boots = second.gear(CharacterId.hunter).equipped[EquipSlot.boots]!;
      expect(boots.rarity, Rarity.epic);
      expect(boots.stats.single.value, 0.12);
    });
  });

  group('장비 레벨', () {
    test('고정치 옵션은 장비 레벨만큼 크고, 비율 옵션은 그대로다', () {
      final random = math.Random(31);
      double average(StatType stat, int level) {
        var total = 0.0;
        var count = 0;
        while (count < 200) {
          final it = LootSystem.generate(
            random,
            type: ItemType.head,
            rarity: Rarity.normal,
            level: level,
          );
          if (it.stats.first.stat != stat) continue;
          total += it.stats.first.value;
          count++;
        }
        return total / count;
      }

      final low = average(StatType.maxHp, 1);
      final high = average(StatType.maxHp, 11);
      expect(high / low, closeTo(math.pow(Balance.itemLevelGrowth, 10), 2));

      final gloves = LootSystem.generate(
        random,
        type: ItemType.gloves,
        rarity: Rarity.normal,
        level: 50,
      ).stats.first;
      expect(gloves.value, lessThanOrEqualTo(gloves.stat.roll * 1.21));
    });

    test('스테이지에서 떨어진 장비는 그 스테이지 레벨이다', () {
      final random = math.Random(32);
      const stage = Stage(12);
      Item? drop;
      while (drop == null) {
        drop = LootSystem.rollDrop(random, stage);
      }

      expect(drop.level, stage.level);
    });

    test('타락 보상: 높은 등급이 더 자주 나온다', () {
      final random = math.Random(33);
      double highShare(double luck) {
        var high = 0;
        for (var i = 0; i < 50000; i++) {
          if (LootSystem.rollRarity(random, luck: luck).index >= 2) high++;
        }
        return high / 50000;
      }

      expect(highShare(1), greaterThan(highShare(0) * 2));
    });

    test('보스 상자는 레어 이상 장비를 정해진 수만큼 준다', () {
      final items = LootSystem.bossChest(math.Random(34), const Stage(3));

      expect(items, hasLength(Balance.bossChestItems));
      for (final it in items) {
        expect(it.rarity.index, greaterThanOrEqualTo(Rarity.rare.index));
        expect(it.level, 4);
      }
    });
  });

  group('잔불 강화', () {
    test('강화하면 잔불을 쓰고 모든 옵션이 오른다', () {
      final inv = Inventory()..addEmber(1000);
      final gear = inv.gear(CharacterId.witch);
      final helm = item(
        ItemType.head,
        value: 20,
        extra: [(stat: StatType.armor, value: 10, rarity: Rarity.normal)],
      );
      gear.add(helm);
      final cost = helm.enhanceCost;

      inv.enhance(helm);

      expect(inv.ember, 1000 - cost);
      expect(helm.enhance, 1);
      expect(helm.name, endsWith('+1'));
      expect(gear.bonus(StatType.maxHp), closeTo(22, 1e-9));
      expect(gear.bonus(StatType.armor), closeTo(11, 1e-9));
      expect(helm.enhanceCost, greaterThan(cost));
    });

    test('잔불이 모자라거나 최대 강화면 할 수 없다', () {
      final inv = Inventory();
      final helm = item(ItemType.head);
      expect(inv.canEnhance(helm), isFalse);

      helm.enhance = Balance.maxEnhance;
      inv.addEmber(1 << 30);
      expect(inv.canEnhance(helm), isFalse);
    });

    test('높은 등급, 높은 레벨일수록 분해 잔불도 강화 비용도 크다', () {
      Item at(Rarity r, int level) =>
          Item(type: ItemType.ring, rarity: r, stats: const [], level: level);

      expect(
        at(Rarity.legend, 1).salvageValue,
        greaterThan(at(Rarity.normal, 1).salvageValue),
      );
      expect(
        at(Rarity.normal, 20).salvageValue,
        greaterThan(at(Rarity.normal, 1).salvageValue),
      );
      expect(
        at(Rarity.legend, 1).enhanceCost,
        greaterThan(at(Rarity.normal, 1).enhanceCost),
      );
    });
  });
}
