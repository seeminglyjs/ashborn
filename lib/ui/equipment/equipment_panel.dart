import 'package:flutter/material.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/equipment.dart';
import '../../data/inventory.dart';
import '../../data/stats.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

/// 이 등급 이상은 버리기 전에 한 번 더 묻는다.
const confirmDiscardFrom = Rarity.hero;

/// 한 캐릭터의 장착 칸, 공용 가방, 선택한 장비의 정보.
/// 출발 전 장비 화면과 런 중 장비 오버레이가 함께 쓴다.
class EquipmentPanel extends StatefulWidget {
  const EquipmentPanel({
    super.key,
    required this.inventory,
    required this.character,
    required this.onClose,
  });

  final Inventory inventory;
  final CharacterDef character;
  final VoidCallback onClose;

  @override
  State<EquipmentPanel> createState() => _EquipmentPanelState();
}

class _EquipmentPanelState extends State<EquipmentPanel> {
  static const double _tile = 52;
  static const double _gap = 6;

  Item? _selected;

  /// 선택한 장비가 장착 중이면 그 칸.
  EquipSlot? _selectedSlot;

  Inventory get _inventory => widget.inventory;
  late final Gear _gear = _inventory.gear(widget.character.id);

  void _select(Item? item, [EquipSlot? slot]) => setState(() {
    _selected = item;
    _selectedSlot = slot;
  });

  Future<void> _discard(Item item) async {
    if (item.rarity.index >= confirmDiscardFrom.index &&
        await _confirmDiscard(item) != true) {
      return;
    }
    _inventory.discard(item);
    _select(null);
  }

  Future<bool?> _confirmDiscard(Item item) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AshColors.panel,
      title: Text(item.name, style: TextStyle(color: item.rarity.color)),
      content: const Text(
        '버린 장비는 되찾을 수 없습니다. 버릴까요?',
        style: TextStyle(color: AshColors.parchment),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('confirm-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('버리기', style: TextStyle(color: AshColors.ember)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF20B0908),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: _inventory,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('장비', style: ashTitleStyle(22)),
                    const SizedBox(width: 10),
                    Text(widget.character.name, style: _Text.heading),
                    const Spacer(),
                    IconButton(
                      key: const Key('close-equipment'),
                      icon: const Icon(Icons.close, color: AshColors.parchment),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _tile * 4 + _gap * 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _equippedGrid(),
                            const SizedBox(height: 10),
                            Expanded(child: _statSummary()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _bag()),
                      const SizedBox(width: 12),
                      SizedBox(width: 220, child: _detail()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _equippedGrid() => Wrap(
    spacing: _gap,
    runSpacing: _gap,
    children: [
      for (final slot in EquipSlot.values)
        if (slot == EquipSlot.hand2 && _gear.offHandBlocked)
          const _ItemTile(item: null, label: '양손 사용', dimmed: true)
        else
          _ItemTile(
            key: Key('slot-${slot.name}'),
            item: _gear.equipped[slot],
            label: slot.label,
            selected: _selectedSlot == slot,
            onTap: () => _select(_gear.equipped[slot], slot),
          ),
    ],
  );

  Widget _statSummary() {
    final effects = _gear.effects;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('장비 능력치', style: _Text.heading),
          const SizedBox(height: 4),
          if (effects.isEmpty &&
              StatType.values.every((s) => _gear.bonus(s) == 0))
            const Text('없음', style: _Text.dim),
          for (final effect in effects)
            Text(
              effect.label,
              style: _Text.body.copyWith(color: Rarity.unique.color),
            ),
          for (final group in StatGroup.values)
            if (StatType.values
                    .where((s) => s.group == group && _gear.bonus(s) > 0)
                    .toList()
                case final stats when stats.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(group.label, style: _Text.tag),
              for (final stat in stats)
                Text(stat.format(_gear.bonus(stat)), style: _Text.body),
            ],
        ],
      ),
    );
  }

  Widget _bag() {
    final bag = _inventory.bag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가방 ${bag.length} / ${Balance.bagCapacity}',
          style: _inventory.bagFull
              ? _Text.heading.copyWith(color: AshColors.ember)
              : _Text.heading,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: bag.isEmpty
              ? const Text('비어 있음', style: _Text.dim)
              : GridView.extent(
                  maxCrossAxisExtent: _tile + _gap,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                  children: [
                    for (final (i, item) in bag.indexed)
                      _ItemTile(
                        key: Key('bag-$i'),
                        item: item,
                        label: '',
                        selected: _selectedSlot == null && _selected == item,
                        onTap: () => _select(item),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _detail() {
    final item = _selected;
    if (item == null) {
      return const Text('장비를 눌러 정보를 확인하세요', style: _Text.dim);
    }
    final slot = _selectedSlot;
    final targets = Gear.slotsFor(item.type);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemDetails(item: item),
          const SizedBox(height: 12),
          if (slot != null)
            _action('unequip', '해제', () {
              _gear.unequip(slot);
              _select(null);
            })
          else ...[
            for (final target in targets) ...[
              _action(
                'equip-${target.name}',
                targets.length == 1 ? '장착' : '${target.label}에 장착',
                () {
                  _gear.equip(item, target);
                  _select(null);
                },
              ),
              _Comparison(
                item: item,
                replaced: _gear.displacedBy(item, target),
              ),
              const SizedBox(height: 8),
            ],
            _action('discard', '버리기', () => _discard(item)),
          ],
        ],
      ),
    );
  }

  Widget _action(String key, String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: AshButton(
      key: Key(key),
      label: label,
      fontSize: 13,
      onPressed: onPressed,
    ),
  );
}

/// 장비 이름, 옵션(옵션 등급 색), 고유 효과.
class ItemDetails extends StatelessWidget {
  const ItemDetails({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: TextStyle(
            color: item.rarity.color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        for (final (i, roll) in item.stats.indexed)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: roll.stat.format(roll.value),
                  style: i == 0
                      ? _Text.main
                      : _Text.body.copyWith(color: roll.rarity.color),
                ),
                if (i > 0)
                  TextSpan(text: '  ${roll.rarity.label}', style: _Text.tag),
              ],
            ),
          ),
        if (item.effect case final effect?) ...[
          const SizedBox(height: 6),
          Text(
            effect.label,
            style: _Text.main.copyWith(color: Rarity.unique.color),
          ),
          Text(effect.description, style: _Text.dim),
        ],
      ],
    );
  }
}

/// [item] 을 끼면 [replaced] 대신 바뀌는 능력치.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.item, required this.replaced});

  final Item item;
  final List<Item> replaced;

  static Map<StatType, double> _sum(Iterable<Item> items) {
    final total = <StatType, double>{};
    for (final item in items) {
      for (final roll in item.stats) {
        total.update(
          roll.stat,
          (v) => v + roll.value,
          ifAbsent: () => roll.value,
        );
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final gain = _sum([item]);
    final loss = _sum(replaced);
    final lines = <Widget>[
      Text(
        replaced.isEmpty
            ? '빈 칸'
            : '교체: ${replaced.map((i) => i.name).join(', ')}',
        style: _Text.tag,
      ),
      for (final stat in StatType.values)
        if (((gain[stat] ?? 0) - (loss[stat] ?? 0)) case final d
            when d.abs() > 1e-9)
          Text(
            '${d > 0 ? '▲' : '▼'} ${stat.label} ${stat.formatValue(d)}',
            style: _Text.body.copyWith(color: d > 0 ? _Text.up : _Text.down),
          ),
      if (item.effect case final effect?)
        if (!replaced.any((r) => r.effect == effect))
          Text(
            '▲ ${effect.label}',
            style: _Text.body.copyWith(color: _Text.up),
          ),
      for (final r in replaced)
        if (r.effect case final effect? when effect != item.effect)
          Text(
            '▼ ${effect.label}',
            style: _Text.body.copyWith(color: _Text.down),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }
}

abstract final class _Text {
  static const up = Color(0xFF7BD15A);
  static const down = Color(0xFFE5383B);
  static const heading = TextStyle(
    color: AshColors.gold,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
  static const main = TextStyle(
    color: AshColors.parchment,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
  static const body = TextStyle(color: AshColors.parchment, fontSize: 12);
  static const dim = TextStyle(color: AshColors.ash, fontSize: 12);
  static const tag = TextStyle(color: AshColors.ash, fontSize: 10);
}

/// 등급 색 테두리를 두른 장비 칸.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.label,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  final Item? item;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = item?.rarity.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _EquipmentPanelState._tile,
        height: _EquipmentPanelState._tile,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.18) ?? Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AshColors.gold : color ?? Colors.white24,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (item?.effect != null)
              BoxShadow(color: color!.withValues(alpha: 0.6), blurRadius: 8),
          ],
        ),
        child: Text(
          item?.type.label ?? label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: item != null
                ? AshColors.parchment
                : AshColors.ash.withValues(alpha: dimmed ? 0.5 : 1),
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
