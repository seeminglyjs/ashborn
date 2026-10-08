import 'dart:convert';
import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/inventory_store.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Item item(ItemType type, {Rarity rarity = Rarity.normal, double value = 1}) =>
    Item(
      type: type,
      rarity: rarity,
      stats: [(stat: type.mainStat, value: value)],
    );

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

  group('장비 생성', () {
    test('주옵션은 파츠가 정하고 추가옵션 수는 등급이 정한다', () {
      final random = math.Random(1);
      for (final type in ItemType.values) {
        for (final rarity in Rarity.values) {
          final it = LootSystem.generate(random, type: type, rarity: rarity);
          final stats = it.stats.map((s) => s.stat).toList();

          expect(stats.first, type.mainStat);
          expect(stats, hasLength(1 + rarity.affixCount));
          expect(stats.toSet(), hasLength(stats.length));
          expect(it.stats.every((s) => s.value > 0), isTrue);
        }
      }
    });

    test('등급이 높을수록 주옵션 수치가 크다', () {
      final random = math.Random(2);
      double main(Rarity r) => LootSystem.generate(
        random,
        type: ItemType.head,
        rarity: r,
      ).stats.first.value;

      for (var i = 0; i < 50; i++) {
        expect(main(Rarity.unique), greaterThan(main(Rarity.normal)));
      }
    });
  });

  group('인벤토리', () {
    test('빈 칸이 있으면 바로 끼고, 칸이 차면 가방에 넣는다', () {
      final inv = Inventory();
      final rings = [for (var i = 0; i < 3; i++) item(ItemType.ring)];

      rings.forEach(inv.add);

      expect(inv.equipped[EquipSlot.ring1], rings[0]);
      expect(inv.equipped[EquipSlot.ring2], rings[1]);
      expect(inv.bag, [rings[2]]);
    });

    test('양손장비는 두 손이 다 비어야 바로 낀다', () {
      final inv = Inventory();
      final sword = item(ItemType.oneHand);
      final greatsword = item(ItemType.twoHand);

      inv
        ..add(sword)
        ..add(greatsword);

      expect(inv.equipped[EquipSlot.hand1], sword);
      expect(inv.bag, [greatsword]);
    });

    test('양손장비를 끼면 두 손의 장비가 가방으로 간다', () {
      final inv = Inventory();
      final a = item(ItemType.oneHand);
      final b = item(ItemType.oneHand);
      final greatsword = item(ItemType.twoHand);
      inv
        ..add(a)
        ..add(b)
        ..add(greatsword);
      expect(inv.equipped[EquipSlot.hand2], b);

      inv.equip(greatsword, EquipSlot.hand1);

      expect(inv.equipped[EquipSlot.hand1], greatsword);
      expect(inv.equipped[EquipSlot.hand2], isNull);
      expect(inv.offHandBlocked, isTrue);
      expect(inv.bag, unorderedEquals([a, b]));
    });

    test('양손장비를 낀 채 보조 손에 끼면 양손장비가 빠진다', () {
      final inv = Inventory();
      final greatsword = item(ItemType.twoHand);
      final dagger = item(ItemType.oneHand);
      inv
        ..add(greatsword)
        ..add(dagger);
      expect(inv.bag, [dagger]);

      inv.equip(dagger, EquipSlot.hand2);

      expect(inv.equipped[EquipSlot.hand1], isNull);
      expect(inv.equipped[EquipSlot.hand2], dagger);
      expect(inv.bag, [greatsword]);
    });

    test('같은 칸에 끼면 원래 장비와 맞바꾼다', () {
      final inv = Inventory();
      final old = item(ItemType.head);
      final better = item(ItemType.head, rarity: Rarity.legend);
      inv
        ..add(old)
        ..add(better);

      inv.equip(better, EquipSlot.head);

      expect(inv.equipped[EquipSlot.head], better);
      expect(inv.bag, [old]);
    });

    test('해제하면 가방으로, 버리면 사라진다', () {
      final inv = Inventory();
      final helm = item(ItemType.head);
      inv.add(helm);

      inv.unequip(EquipSlot.head);
      expect(inv.equipped, isEmpty);
      expect(inv.bag, [helm]);

      inv.discard(helm);
      expect(inv.bag, isEmpty);
    });

    test('장착한 장비의 능력치만 합산한다', () {
      final inv = Inventory();
      inv
        ..add(
          Item(
            type: ItemType.head,
            rarity: Rarity.rare,
            stats: [
              (stat: StatType.maxHp, value: 12),
              (stat: StatType.damage, value: 0.05),
            ],
          ),
        )
        ..add(item(ItemType.oneHand, value: 0.1))
        ..add(item(ItemType.head, value: 99));

      expect(inv.bonus(StatType.maxHp), 12);
      expect(inv.bonus(StatType.damage), closeTo(0.15, 1e-9));
    });
  });

  group('저장', () {
    test('JSON 으로 저장했다가 그대로 불러온다', () {
      final random = math.Random(5);
      final inv = Inventory();
      for (var i = 0; i < 30; i++) {
        inv.add(LootSystem.generate(random));
      }

      final json = jsonEncode(inv.toJson());
      final loaded = Inventory.fromJson(jsonDecode(json));

      expect(jsonEncode(loaded.toJson()), json);
      expect(loaded.bag, hasLength(inv.bag.length));
    });

    test('바뀔 때마다 기기에 저장되고 다음 실행에 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await InventoryStore.load();
      first.add(item(ItemType.boots, rarity: Rarity.epic, value: 0.12));
      await pumpEventQueue();

      final second = await InventoryStore.load();

      final boots = second.equipped[EquipSlot.boots]!;
      expect(boots.rarity, Rarity.epic);
      expect(boots.stats.single.value, 0.12);
    });
  });
}
