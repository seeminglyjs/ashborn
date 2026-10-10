import '../data/characters.dart';
import '../data/combat_power.dart';
import '../data/equipment.dart';
import '../data/inventory.dart';
import '../data/stats.dart';

/// 장비 자동 장착: 가방의 장비로 종합 전투력([CombatPower])이 가장 높아지게 낀다.
///
/// 한 번에 가장 많이 오르는 교체 하나씩, 더 오르는 것이 없을 때까지 되풀이한다. 강화 계승
/// (밀려나는 장비의 강화가 더 높으면 맞바꿈)을 미리 반영해 비교하고, 양손장비를 한손장비 둘로
/// 바꾸는 경우처럼 두 칸을 함께 바꿔야 오르는 교체도 본다.
abstract final class AutoEquip {
  /// [character] 의 [gear] 를 바꾸고, 새로 낀 장비 수를 돌려준다. [extra] 는 장비 밖 능력치,
  /// [amplify] 는 화톳불의 곱하는 강화 배율.
  static int run(
    Gear gear,
    Inventory inventory,
    CharacterDef character, {
    double Function(StatType stat)? extra,
    double Function(StatType stat)? amplify,
  }) {
    var equipped = 0;
    // 교체마다 전투력이 오르므로 끝나지만, 혹시 모를 되풀이를 막는다.
    for (var guard = 0; guard < 64; guard++) {
      final move = _best(gear, inventory, character, extra, amplify);
      if (move == null) break;
      for (final (item, slot) in move) {
        gear.equip(item, slot);
        equipped++;
      }
    }
    return equipped;
  }

  /// 지금 장비 그대로의 전투력.
  static int current(
    Gear gear,
    CharacterDef character, {
    double Function(StatType stat)? extra,
    double Function(StatType stat)? amplify,
  }) => CombatPower.of(
    character,
    gear.equipped.values,
    extra: extra,
    amplify: amplify,
  );

  /// 가방 밖의 [item] 을 가장 알맞은 칸에 끼면 오르는 전투력 (강화 계승 반영). 낄 수 없거나
  /// 오르지 않으면 0 이하. 자동 분해가 쓸 만한 장비를 남기려고 본다.
  static int gain(
    Gear gear,
    Item item,
    CharacterDef character, {
    double Function(StatType stat)? extra,
    double Function(StatType stat)? amplify,
  }) {
    final now = current(gear, character, extra: extra, amplify: amplify);
    if (!gear.canWear(item)) return 0;
    var best = 0;
    for (final slot in Gear.slotsFor(item.type)) {
      final removed = gear.displacedBy(item, slot);
      final inherited = gear.enhanceAfterEquip(item, slot);
      final power = CombatPower.of(
        character,
        [
          for (final i in gear.equipped.values)
            if (!removed.contains(i)) i,
          item,
        ],
        extra: extra,
        amplify: amplify,
        enhanceOf: (i) => identical(i, item) ? inherited : i.enhance,
      );
      if (power - now > best) best = power - now;
    }
    return best;
  }

  /// 가장 많이 오르는 교체 (칸 하나 또는 한손장비 둘). 오르는 것이 없으면 null.
  static List<(Item, EquipSlot)>? _best(
    Gear gear,
    Inventory inventory,
    CharacterDef character,
    double Function(StatType stat)? extra,
    double Function(StatType stat)? amplify,
  ) {
    var best = current(gear, character, extra: extra, amplify: amplify);
    List<(Item, EquipSlot)>? move;
    final candidates = inventory.bag.where(gear.canWear).toList();

    int powerAfter(List<Item> removed, Map<Item, int> added) => CombatPower.of(
      character,
      [
        for (final item in gear.equipped.values)
          if (!removed.contains(item)) item,
        ...added.keys,
      ],
      extra: extra,
      amplify: amplify,
      enhanceOf: (item) => added[item] ?? item.enhance,
    );

    for (final item in candidates) {
      for (final slot in Gear.slotsFor(item.type)) {
        final power = powerAfter(gear.displacedBy(item, slot), {
          item: gear.enhanceAfterEquip(item, slot),
        });
        if (power > best) {
          best = power;
          move = [(item, slot)];
        }
      }
    }

    // 양손장비를 빼고 한손장비 둘을 끼는 교체. 한 장씩은 손해라 위에서 못 찾는다.
    if (gear.offHandBlocked) {
      final twoHand = gear.equipped[EquipSlot.hand1]!;
      final oneHands = candidates
          .where((i) => i.type == ItemType.oneHand)
          .toList();
      for (final a in oneHands) {
        final inherited = gear.enhanceAfterEquip(a, EquipSlot.hand1);
        for (final b in oneHands) {
          if (identical(a, b)) continue;
          final power = powerAfter([twoHand], {a: inherited, b: b.enhance});
          if (power > best) {
            best = power;
            move = [(a, EquipSlot.hand1), (b, EquipSlot.hand2)];
          }
        }
      }
    }
    return move;
  }
}
