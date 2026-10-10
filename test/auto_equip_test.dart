import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/combat_power.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/systems/auto_equip.dart';
import 'package:ashborn/ui/equipment/equipment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// [item] 을 가방에 넣는다 (빈 칸이 있으면 한 번 끼었다가 뺀다).
void toBag(Gear gear, Item item) {
  if (gear.add(item) case final slot?) gear.unequip(slot);
}

int power(Iterable<Item> items) => CombatPower.of(Roster.knight, items);

void main() {
  group('종합 전투력', () {
    test('맨몸에도 있고, 공격 · 생존 옵션과 강화가 모두 올린다', () {
      final naked = power(const []);
      expect(naked, greaterThan(0));
      expect(
        power([item(ItemType.ring, stat: StatType.physicalDamage, value: 5)]),
        greaterThan(naked),
      );
      expect(
        power([item(ItemType.head, stat: StatType.maxHp, value: 30)]),
        greaterThan(naked),
      );
      final ring = item(ItemType.ring, stat: StatType.damage, value: 0.1);
      final before = power([ring]);
      ring.enhance = 10;
      expect(power([ring]), greaterThan(before));
    });

    test('공격과 생존을 고르게 키울수록 높다', () {
      final balanced = power([
        item(ItemType.ring, stat: StatType.physicalDamage, value: 20),
        item(ItemType.head, stat: StatType.maxHp, value: 150),
      ]);
      final offenseOnly = power([
        item(ItemType.ring, stat: StatType.physicalDamage, value: 40),
      ]);
      expect(balanced, greaterThan(offenseOnly));
    });

    test('장비 밖 능력치(화톳불 · 은총)도 함께 친다', () {
      expect(
        CombatPower.of(
          Roster.knight,
          const [],
          extra: (s) => s == StatType.damage ? 0.5 : 0,
        ),
        greaterThan(power(const [])),
      );
    });
  });

  group('자동 장착', () {
    late Inventory inventory;
    late Gear gear;
    setUp(() {
      inventory = Inventory();
      gear = inventory.gear(CharacterId.knight);
    });

    test('빈 칸은 채우고, 약한 장비는 더 센 장비로 바꾸며, 더 약한 것은 가방에 남긴다', () {
      final weak = item(ItemType.ring, stat: StatType.damage, value: 0.05);
      gear.add(weak);
      final strong = item(ItemType.ring, stat: StatType.damage, value: 0.3);
      final worse = item(ItemType.ring, stat: StatType.damage, value: 0.01);
      final helm = item(ItemType.head, stat: StatType.maxHp, value: 40);
      for (final i in [strong, worse, helm]) {
        toBag(gear, i);
      }
      // 반지 칸은 둘이라 약한 반지도 한 칸에 남는다.
      final before = AutoEquip.current(gear, Roster.knight);

      final count = AutoEquip.run(gear, inventory, Roster.knight);

      expect(count, greaterThan(0));
      expect(gear.equipped.values, containsAll([strong, helm]));
      expect(inventory.bag, contains(worse));
      expect(AutoEquip.current(gear, Roster.knight), greaterThan(before));
      // 더 오를 것이 없으면 아무것도 바꾸지 않는다.
      expect(AutoEquip.run(gear, inventory, Roster.knight), 0);
    });

    test('다른 직업 무기는 끼지 않는다', () {
      final wand = Item(
        type: ItemType.oneHand,
        rarity: Rarity.legend,
        stats: [
          (stat: StatType.physicalDamage, value: 99, rarity: Rarity.legend),
        ],
        kind: WeaponKind.wand,
      );
      inventory.gear(CharacterId.witch).add(wand);
      inventory.gear(CharacterId.witch).unequip(EquipSlot.hand1);

      expect(AutoEquip.run(gear, inventory, Roster.knight), 0);
      expect(inventory.bag, contains(wand));
    });

    test('한손장비 둘이 양손장비보다 세면 둘을 함께 바꿔 낀다', () {
      final twoHand = item(
        ItemType.twoHand,
        stat: StatType.physicalDamage,
        value: 10,
      );
      gear.add(twoHand);
      final a = item(ItemType.oneHand, stat: StatType.physicalDamage, value: 8);
      final b = item(ItemType.oneHand, stat: StatType.physicalDamage, value: 8);
      toBag(gear, a);
      toBag(gear, b);
      // 한 장씩 바꾸면 10 → 8 이라 손해다.
      expect(power([a]), lessThan(power([twoHand])));

      AutoEquip.run(gear, inventory, Roster.knight);

      expect(gear.equipped[EquipSlot.hand1], anyOf(a, b));
      expect(gear.equipped[EquipSlot.hand2], anyOf(a, b));
      expect(inventory.bag, contains(twoHand));
    });

    test('강화 계승을 반영해 고른다: 강화 높은 장비를 밀어내면 강화를 이어받는다', () {
      final old = item(ItemType.ring, stat: StatType.damage, value: 0.1)
        ..enhance = 15;
      final other = item(ItemType.ring, stat: StatType.damage, value: 0.1)
        ..enhance = 15;
      gear
        ..add(old)
        ..add(other);
      final fresh = item(ItemType.ring, stat: StatType.damage, value: 0.12);
      toBag(gear, fresh);

      AutoEquip.run(gear, inventory, Roster.knight);

      expect(gear.equipped.values, contains(fresh));
      expect(fresh.enhance, 15);
    });
  });

  testWidgets('장비 화면에 전투력을 보이고, 자동 장착을 누르면 끼우고 결과를 알린다', (tester) async {
    final inventory = Inventory();
    final gear = inventory.gear(CharacterId.knight);
    final helm = item(ItemType.head, stat: StatType.maxHp, value: 40);
    toBag(gear, helm);
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentPanel(
          inventory: inventory,
          character: Roster.knight,
          onClose: () {},
        ),
      ),
    );
    String shown() =>
        tester.widget<Text>(find.byKey(const Key('combat-power'))).data!;
    final before = shown();

    await tester.tap(find.byKey(const Key('auto-equip')));
    await tester.pump();

    expect(gear.equipped.values, contains(helm));
    expect(shown(), isNot(before));
    expect(find.textContaining('자동 장착 1개'), findsOneWidget);
  });
}
