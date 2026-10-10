import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'characters.dart';
import 'equipment.dart';
import 'stats.dart';
import 'transcend.dart';

/// 모든 캐릭터가 함께 쓰는 가방과, 캐릭터마다 따로인 장착 칸.
/// 런이 끝나도 유지된다 ([Profile]).
class Inventory extends ChangeNotifier {
  Inventory();

  factory Inventory.fromJson(Map<String, dynamic> json) {
    final inventory = Inventory()
      .._ember = json['ember'] as int
      .._gold = json['gold'] as int? ?? 0
      .._stones = json['stones'] as int? ?? 0
      .._transcendStones = json['transcendStones'] as int? ?? 0;
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

  /// 잔불. 화톳불 영구 강화에 쓴다.
  int get ember => _ember;

  int _gold = 0;
  int _stones = 0;
  int _transcendStones = 0;

  /// 골드와 강화석은 장비 강화에, 초월석은 골드와 함께 초월에 쓴다.
  int get gold => _gold;
  int get stones => _stones;
  int get transcendStones => _transcendStones;

  void addLoot({int gold = 0, int stones = 0, int transcendStones = 0}) {
    if (gold <= 0 && stones <= 0 && transcendStones <= 0) return;
    _gold += gold;
    _stones += stones;
    _transcendStones += transcendStones;
    notifyListeners();
  }

  void addEmber(int amount) {
    if (amount <= 0) return;
    _ember += amount;
    notifyListeners();
  }

  void spendEmber(int amount) {
    assert(amount <= _ember, '잔불이 모자란다');
    _ember -= amount;
    notifyListeners();
  }

  void spendGold(int amount) {
    assert(amount <= _gold, '골드가 모자란다');
    _gold -= amount;
    notifyListeners();
  }

  bool canEnhance(Item item) =>
      !item.isMaxEnhance &&
      _stones >= item.enhanceStones &&
      _gold >= item.enhanceGold;

  /// 강화석과 골드를 써서 [item] 을 한 단계 강화한다. 확률 없이 늘 성공한다.
  /// 장착 중인 장비도 된다.
  void enhance(Item item) {
    assert(canEnhance(item), '재료가 모자라거나 최대 강화다');
    _stones -= item.enhanceStones;
    _gold -= item.enhanceGold;
    item.enhance++;
    notifyListeners();
  }

  bool canTranscend(Item item) =>
      item.canTranscend &&
      _transcendStones >= item.transcendStones &&
      _gold >= item.transcendGold;

  /// 초월석과 골드를 써서 [item] 에 [option] 초월 옵션을 붙인다. 확률 없이 늘 성공한다.
  /// [option] 은 아직 그 장비에 없는 것이어야 한다 ([TranscendOption.available]).
  void transcend(Item item, TranscendOption option) {
    assert(canTranscend(item), '재료가 모자라거나 초월할 수 없다');
    assert(item.transcends.every((t) => t.option != option), '이미 붙은 초월 옵션이다');
    _transcendStones -= item.transcendStones;
    _gold -= item.transcendGold;
    item.transcends.add(TranscendOption.pick(option));
    notifyListeners();
  }

  /// 가방의 [item] 을 분해해 잔불로 바꾼다.
  void salvage(Item item) {
    if (!_bag.remove(item)) return;
    _ember += item.salvageValue;
    notifyListeners();
  }

  /// 강화했거나 초월한 장비. 재료가 들어간 장비라 일괄 분해에서 기본으로 지킨다.
  static bool isUpgraded(Item item) =>
      item.enhance > 0 || item.transcends.isNotEmpty;

  /// 일괄 분해 대상: 가방에서 등급이 [rarities] 에 드는 장비. [keepUpgraded] 면
  /// 강화했거나 초월한 장비는 뺀다. 장착 중인 장비는 가방에 없으니 대상이 아니다.
  List<Item> salvageTargets(
    Set<Rarity> rarities, {
    bool keepUpgraded = true,
  }) => [
    for (final item in _bag)
      if (rarities.contains(item.rarity) && !(keepUpgraded && isUpgraded(item)))
        item,
  ];

  /// 가방의 [items] 를 한꺼번에 분해해 잔불로 바꾸고, 얻은 잔불 합계를 돌려준다.
  /// 가방에 없는 장비(장착 중이거나 이미 분해한 것)는 건너뛴다. 알림은 한 번만 보낸다.
  int salvageAll(Iterable<Item> items) {
    final targets = Set<Item>.identity()..addAll(items);
    var removed = 0;
    var ember = 0;
    _bag.removeWhere((item) {
      if (!targets.contains(item)) return false;
      removed++;
      ember += item.salvageValue;
      return true;
    });
    if (removed == 0) return 0;
    _ember += ember;
    notifyListeners();
    return ember;
  }

  List<Item> get bag => UnmodifiableListView(_bag);

  /// 가방이 차면 바닥의 장비를 더 주울 수 없다.
  bool get bagFull => _bag.length >= Balance.bagCapacity;

  Gear gear(CharacterId character) => Gear._(this, character);

  void _changed() => notifyListeners();

  Map<String, dynamic> toJson() => {
    'ember': _ember,
    'gold': _gold,
    'stones': _stones,
    'transcendStones': _transcendStones,
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

  /// 장착한 장비의 [option] 초월 수치 합.
  double transcend(TranscendOption option) =>
      _slots.values.fold(0, (sum, item) => sum + item.transcend(option));

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

  /// [slot] 에 [item] 을 끼면 강화를 넘겨줄 장비. 밀려나는 장비 중 [item] 보다
  /// 강화가 높은 것 가운데 가장 높은 것이고, 없으면 null.
  Item? enhanceDonor(Item item, EquipSlot slot) {
    Item? donor;
    for (final d in displacedBy(item, slot)) {
      if (d.enhance > (donor?.enhance ?? item.enhance)) donor = d;
    }
    return donor;
  }

  /// [slot] 에 끼고 나면 [item] 이 갖게 될 강화 단계.
  int enhanceAfterEquip(Item item, EquipSlot slot) =>
      enhanceDonor(item, slot)?.enhance ?? item.enhance;

  /// 가방의 [item] 을 [slot] 에 낀다. 밀려난 장비는 가방으로 간다.
  ///
  /// 강화 계승: 밀려난 장비의 강화가 더 높으면 두 장비의 강화 단계를 맞바꾼다.
  /// 산 강화석이 장비를 바꿔도 힘으로 남게 하려는 것이다. 초월 단계 · 초월 옵션은
  /// 장비에 그대로 남는다.
  void equip(Item item, EquipSlot slot) {
    assert(slot.accepts(item.type), '${item.type} 은 ${slot.place} 에 낄 수 없다');
    final displaced = displacedBy(item, slot);
    if (enhanceDonor(item, slot) case final donor?) {
      final enhance = donor.enhance;
      donor.enhance = item.enhance;
      item.enhance = enhance;
    }
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
