import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'characters.dart';
import 'equipment.dart';
import 'stats.dart';

/// 모든 캐릭터가 함께 쓰는 가방과, 캐릭터마다 따로인 장착 칸.
/// 런이 끝나도 유지된다 ([Profile]).
class Inventory extends ChangeNotifier {
  Inventory();

  factory Inventory.fromJson(Map<String, dynamic> json) {
    final inventory = Inventory().._ember = json['ember'] as int;
    for (final item in json['bag'] as List) {
      inventory._bag.add(Item.fromJson(item as Map<String, dynamic>));
    }
    (json['equipped'] as Map<String, dynamic>).forEach((character, slots) {
      inventory._equipped[CharacterId.values.byName(character)] = {
        for (final MapEntry(:key, :value)
            in (slots as Map<String, dynamic>).entries)
          EquipSlot.values.byName(key): Item.fromJson(
            value as Map<String, dynamic>,
          ),
      };
    });
    return inventory;
  }

  final _bag = <Item>[];
  final _equipped = <CharacterId, Map<EquipSlot, Item>>{};
  int _ember = 0;

  /// 잔불. 장비 강화에 쓴다.
  int get ember => _ember;

  void addEmber(int amount) {
    if (amount <= 0) return;
    _ember += amount;
    notifyListeners();
  }

  bool canEnhance(Item item) =>
      !item.isMaxEnhance && _ember >= item.enhanceCost;

  /// 잔불을 써서 [item] 을 한 단계 강화한다. 장착 중인 장비도 된다.
  void enhance(Item item) {
    assert(canEnhance(item), '잔불이 모자라거나 최대 강화다');
    _ember -= item.enhanceCost;
    item.enhance++;
    notifyListeners();
  }

  /// 가방의 [item] 을 분해해 잔불로 바꾼다.
  void salvage(Item item) {
    if (!_bag.remove(item)) return;
    _ember += item.salvageValue;
    notifyListeners();
  }

  List<Item> get bag => UnmodifiableListView(_bag);

  /// 가방이 차면 바닥의 장비를 더 주울 수 없다.
  bool get bagFull => _bag.length >= Balance.bagCapacity;

  Gear gear(CharacterId character) => Gear._(this, character);

  void _changed() => notifyListeners();

  Map<String, dynamic> toJson() => {
    'ember': _ember,
    'bag': [for (final item in _bag) item.toJson()],
    'equipped': {
      for (final MapEntry(key: character, value: slots) in _equipped.entries)
        if (slots.isNotEmpty)
          character.name: {
            for (final MapEntry(:key, :value) in slots.entries)
              key.name: value.toJson(),
          },
    },
  };
}

/// 한 캐릭터의 장착 칸. 빼거나 밀려난 장비는 공용 가방으로 간다.
class Gear {
  Gear._(this._inventory, this.character);

  final Inventory _inventory;
  final CharacterId character;

  Map<EquipSlot, Item> get _slots =>
      _inventory._equipped.putIfAbsent(character, () => {});

  Map<EquipSlot, Item> get equipped => UnmodifiableMapView(_slots);

  /// [hand1] 에 양손장비를 끼고 있으면 [hand2] 는 막힌다.
  bool get offHandBlocked => _slots[EquipSlot.hand1]?.type == ItemType.twoHand;

  /// 장착한 장비로 오른 [stat] 의 합.
  double bonus(StatType stat) {
    var total = 0.0;
    for (final item in _slots.values) {
      for (final roll in item.effectiveStats) {
        if (roll.stat == stat) total += roll.value;
      }
    }
    return total;
  }

  /// 장착한 고유 장비의 특수 효과.
  Set<UniqueEffect> get effects => {
    for (final item in _slots.values) ?item.effect,
  };

  static List<EquipSlot> slotsFor(ItemType type) =>
      EquipSlot.values.where((s) => s.accepts(type)).toList();

  /// 아무것도 밀어내지 않고 [item] 을 낄 수 있는 칸.
  EquipSlot? freeSlotFor(Item item) =>
      slotsFor(item.type).where((s) => _fits(item, s)).firstOrNull;

  bool _fits(Item item, EquipSlot slot) {
    if (_slots.containsKey(slot)) return false;
    if (item.type == ItemType.twoHand) {
      return !_slots.containsKey(EquipSlot.hand2);
    }
    return slot != EquipSlot.hand2 || !offHandBlocked;
  }

  /// 빈 칸이 있거나 가방에 자리가 있으면 주울 수 있다.
  bool canAdd(Item item) => freeSlotFor(item) != null || !_inventory.bagFull;

  /// 주운 장비. 빈 칸이 있으면 바로 끼고 그 칸을, 없으면 가방에 넣고 null 을 돌려준다.
  EquipSlot? add(Item item) {
    assert(canAdd(item), '가방이 가득 찼다');
    final slot = freeSlotFor(item);
    if (slot != null) {
      _slots[slot] = item;
    } else {
      _inventory._bag.add(item);
    }
    _inventory._changed();
    return slot;
  }

  /// [slot] 에 [item] 을 끼면 빠지게 되는 장비들.
  List<Item> displacedBy(Item item, EquipSlot slot) => [
    ?_slots[slot],
    if (item.type == ItemType.twoHand) ?_slots[EquipSlot.hand2],
    if (slot == EquipSlot.hand2 && offHandBlocked) ?_slots[EquipSlot.hand1],
  ];

  /// 가방의 [item] 을 [slot] 에 낀다. 밀려난 장비는 가방으로 간다.
  void equip(Item item, EquipSlot slot) {
    assert(slot.accepts(item.type), '${item.type} 은 ${slot.label} 에 낄 수 없다');
    final displaced = displacedBy(item, slot);
    _inventory._bag.remove(item);
    _slots.removeWhere((_, equipped) => displaced.contains(equipped));
    _inventory._bag.addAll(displaced);
    _slots[slot] = item;
    _inventory._changed();
  }

  void unequip(EquipSlot slot) {
    final item = _slots.remove(slot);
    if (item == null) return;
    _inventory._bag.add(item);
    _inventory._changed();
  }
}
