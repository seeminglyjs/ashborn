import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'equipment.dart';
import 'stats.dart';

/// 장착한 장비와 가방. 런이 끝나도 유지된다 ([InventoryStore]).
class Inventory extends ChangeNotifier {
  Inventory();

  factory Inventory.fromJson(Map<String, dynamic> json) {
    final inventory = Inventory();
    (json['equipped'] as Map<String, dynamic>).forEach((slot, item) {
      inventory._equipped[EquipSlot.values.byName(slot)] = Item.fromJson(
        item as Map<String, dynamic>,
      );
    });
    for (final item in json['bag'] as List) {
      inventory._bag.add(Item.fromJson(item as Map<String, dynamic>));
    }
    return inventory;
  }

  final _equipped = <EquipSlot, Item>{};
  final _bag = <Item>[];

  Map<EquipSlot, Item> get equipped => UnmodifiableMapView(_equipped);
  List<Item> get bag => UnmodifiableListView(_bag);

  /// [hand1] 에 양손장비를 끼고 있으면 [hand2] 는 막힌다.
  bool get offHandBlocked =>
      _equipped[EquipSlot.hand1]?.type == ItemType.twoHand;

  /// 장착한 장비로 오른 [stat] 의 합.
  double bonus(StatType stat) {
    var total = 0.0;
    for (final item in _equipped.values) {
      for (final roll in item.stats) {
        if (roll.stat == stat) total += roll.value;
      }
    }
    return total;
  }

  static List<EquipSlot> slotsFor(ItemType type) =>
      EquipSlot.values.where((s) => s.accepts(type)).toList();

  /// 주운 장비. 아무것도 밀어내지 않고 낄 칸이 있으면 바로 끼고, 없으면 가방에 넣는다.
  void add(Item item) {
    final slot = slotsFor(item.type).where((s) => _fits(item, s)).firstOrNull;
    if (slot != null) {
      _equipped[slot] = item;
    } else {
      _bag.add(item);
    }
    notifyListeners();
  }

  bool _fits(Item item, EquipSlot slot) {
    if (_equipped.containsKey(slot)) return false;
    if (item.type == ItemType.twoHand) {
      return !_equipped.containsKey(EquipSlot.hand2);
    }
    return slot != EquipSlot.hand2 || !offHandBlocked;
  }

  /// 가방의 [item] 을 [slot] 에 낀다. 밀려난 장비는 가방으로 간다.
  void equip(Item item, EquipSlot slot) {
    assert(slot.accepts(item.type), '${item.type} 은 ${slot.label} 에 낄 수 없다');
    _bag.remove(item);
    final displaced = [
      _equipped.remove(slot),
      if (item.type == ItemType.twoHand) _equipped.remove(EquipSlot.hand2),
      if (slot == EquipSlot.hand2 && offHandBlocked)
        _equipped.remove(EquipSlot.hand1),
    ].nonNulls;
    _bag.addAll(displaced);
    _equipped[slot] = item;
    notifyListeners();
  }

  void unequip(EquipSlot slot) {
    final item = _equipped.remove(slot);
    if (item == null) return;
    _bag.add(item);
    notifyListeners();
  }

  void discard(Item item) {
    if (_bag.remove(item)) notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'equipped': {
      for (final MapEntry(:key, :value) in _equipped.entries)
        key.name: value.toJson(),
    },
    'bag': [for (final item in _bag) item.toJson()],
  };
}
