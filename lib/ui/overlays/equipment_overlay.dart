import 'package:flutter/material.dart';

import '../../data/equipment.dart';
import '../../data/inventory.dart';
import '../../data/stats.dart';
import '../../game/ashborn_game.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

/// 장착 칸, 가방, 선택한 장비의 정보. 여는 동안 게임은 멈춘다.
class EquipmentOverlay extends StatefulWidget {
  const EquipmentOverlay({super.key, required this.game});

  final AshbornGame game;

  @override
  State<EquipmentOverlay> createState() => _EquipmentOverlayState();
}

class _EquipmentOverlayState extends State<EquipmentOverlay> {
  static const double _tile = 52;
  static const double _gap = 6;

  Item? _selected;

  /// 선택한 장비가 장착 중이면 그 칸.
  EquipSlot? _selectedSlot;

  Inventory get _inventory => widget.game.inventory;
  Gear get _gear => widget.game.gear;

  void _select(Item? item, [EquipSlot? slot]) => setState(() {
    _selected = item;
    _selectedSlot = slot;
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF20B0908),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('장비', style: ashTitleStyle(22)),
                  const Spacer(),
                  IconButton(
                    key: const Key('close-equipment'),
                    icon: const Icon(Icons.close, color: AshColors.parchment),
                    onPressed: widget.game.closeEquipment,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListenableBuilder(
                  listenable: _inventory,
                  builder: (context, _) => Row(
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
                      SizedBox(width: 210, child: _detail()),
                    ],
                  ),
                ),
              ),
            ],
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
    final lines = [
      for (final stat in StatType.values)
        if (_gear.bonus(stat) > 0) stat.format(_gear.bonus(stat)),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('장비 능력치', style: _Text.heading),
          const SizedBox(height: 4),
          if (lines.isEmpty) const Text('없음', style: _Text.dim),
          for (final line in lines) Text(line, style: _Text.body),
        ],
      ),
    );
  }

  Widget _bag() {
    final bag = _inventory.bag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('가방 ${bag.length}', style: _Text.heading),
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
            Text(
              roll.stat.format(roll.value),
              style: i == 0 ? _Text.main : _Text.body,
            ),
          const SizedBox(height: 12),
          if (slot != null)
            _action('unequip', '해제', () {
              _gear.unequip(slot);
              _select(null);
            })
          else ...[
            for (final target in targets)
              _action(
                'equip-${target.name}',
                targets.length == 1 ? '장착' : '${target.label}에 장착',
                () {
                  _gear.equip(item, target);
                  _select(null);
                },
              ),
            _action('discard', '버리기', () {
              _inventory.discard(item);
              _select(null);
            }),
          ],
        ],
      ),
    );
  }

  Widget _action(String key, String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AshButton(
      key: Key(key),
      label: label,
      fontSize: 13,
      onPressed: onPressed,
    ),
  );
}

abstract final class _Text {
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
        width: _EquipmentOverlayState._tile,
        height: _EquipmentOverlayState._tile,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.18) ?? Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AshColors.gold : color ?? Colors.white24,
            width: selected ? 2.5 : 1.5,
          ),
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
