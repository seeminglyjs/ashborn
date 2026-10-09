import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/equipment.dart';
import '../../data/inventory.dart';
import '../../data/stats.dart';
import '../../data/transcend.dart';
import '../odds/odds_screen.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

/// 이 등급 이상은 분해하기 전에 한 번 더 묻는다.
const confirmSalvageFrom = Rarity.hero;

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

  /// 마지막 강화 · 초월 시도 결과. 다른 장비를 고르면 지운다.
  bool? _enhanced;
  bool? _transcended;
  final _random = math.Random();

  Inventory get _inventory => widget.inventory;
  late final Gear _gear = _inventory.gear(widget.character.id);

  void _select(Item? item, [EquipSlot? slot]) => setState(() {
    _selected = item;
    _selectedSlot = slot;
    _enhanced = null;
    _transcended = null;
  });

  void _enhance(Item item) => setState(() {
    _enhanced = _inventory.enhance(item, _random);
    _transcended = null;
  });

  void _transcend(Item item) => setState(() {
    _transcended = _inventory.transcend(item, _random);
    _enhanced = null;
  });

  Future<void> _salvage(Item item) async {
    if (item.rarity.index >= confirmSalvageFrom.index &&
        await _confirmSalvage(item) != true) {
      return;
    }
    _inventory.salvage(item);
    _select(null);
  }

  Future<bool?> _confirmSalvage(Item item) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AshColors.panel,
      title: Text(item.name, style: TextStyle(color: item.rarity.color)),
      content: Text(
        '분해한 장비는 되찾을 수 없습니다. 잔불 ${item.salvageValue}을(를) 얻습니다.',
        style: const TextStyle(color: AshColors.parchment),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('confirm-salvage'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('분해', style: TextStyle(color: AshColors.ember)),
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
                    Text(
                      '골드 ${_inventory.gold} · 강화석 ${_inventory.stones}'
                      ' · 초월석 ${_inventory.transcendStones}',
                      key: const Key('materials'),
                      style: _Text.heading.copyWith(color: AshColors.gold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '잔불 ${_inventory.ember}',
                      key: const Key('ember'),
                      style: _Text.heading.copyWith(color: _Text.ember),
                    ),
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
              StatType.values.every((s) => _gear.bonus(s) == 0) &&
              TranscendOption.values.every((o) => _gear.transcend(o) == 0))
            const Text('없음', style: _Text.dim),
          for (final effect in effects)
            Text(
              effect.label,
              style: _Text.body.copyWith(color: Rarity.unique.color),
            ),
          for (final option in TranscendOption.values)
            if (_gear.transcend(option) case final value when value > 0)
              Text(
                option.format(value),
                style: _Text.body.copyWith(color: TranscendOption.color),
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
          if (!item.isMaxEnhance)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '강화석 ${item.enhanceStones} · 골드 ${item.enhanceGold} · '
                      '성공 ${(item.enhanceChance * 100).round()}%',
                      key: const Key('enhance-cost'),
                      style: _Text.tag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const Key('enhance-odds'),
                    onTap: () =>
                        Navigator.of(context)
                            .push(fadeRoute(const OddsScreen())),
                    child: const Text(
                      '확률표',
                      style: TextStyle(
                        color: _Text.ember,
                        fontSize: 10,
                        decoration: TextDecoration.underline,
                        decorationColor: _Text.ember,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _action(
            'enhance',
            item.isMaxEnhance ? '최대 강화' : '강화',
            _inventory.canEnhance(item) ? () => _enhance(item) : null,
          ),
          if (_enhanced case final success?)
            _result(
              'enhance-result',
              success ? '강화 성공! +${item.enhance}' : '강화 실패: 재료만 사라졌습니다',
              success,
            ),
          // 초월은 최대 강화한 영웅 이상 장비만 할 수 있다.
          if (item.canTranscend) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '초월석 ${item.transcendStones} · 골드 ${item.transcendGold}'
                ' · 성공 ${(item.transcendChance * 100).round()}%',
                key: const Key('transcend-cost'),
                style: _Text.tag,
              ),
            ),
            _action(
              'transcend',
              '초월 ★${item.transcends.length + 1}'
                  '/${item.rarity.maxTranscend}',
              _inventory.canTranscend(item) ? () => _transcend(item) : null,
            ),
          ],
          if (_transcended case final success?)
            _result(
              'transcend-result',
              success
                  ? '초월 성공! ${item.transcends.last.option.label}'
                  : '초월 실패: 재료만 사라졌습니다',
              success,
            ),
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
                enhance: _gear.enhanceAfterEquip(item, target),
              ),
              const SizedBox(height: 8),
            ],
            _action(
              'salvage',
              '분해 (잔불 +${item.salvageValue})',
              () => _salvage(item),
            ),
          ],
        ],
      ),
    );
  }

  Widget _result(String key, String text, bool success) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      key: Key(key),
      style: TextStyle(
        color: success ? AshColors.gold : AshColors.ash,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _action(String key, String label, VoidCallback? onPressed) => Padding(
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
        Text(
          'Lv ${item.level}'
          '${item.enhance > 0 ? ' · 강화 +${item.enhance}/${Balance.maxEnhance}' : ''}',
          style: _Text.tag,
        ),
        const SizedBox(height: 6),
        for (final (i, roll) in item.effectiveStats.indexed)
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
        if (item.transcends.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '초월 ★${item.transcends.length}',
            style: _Text.main.copyWith(color: TranscendOption.color),
          ),
          for (final t in item.transcends)
            Text(
              t.option.format(t.value),
              style: _Text.body.copyWith(color: TranscendOption.color),
            ),
        ],
      ],
    );
  }
}

/// [item] 을 끼면 [replaced] 대신 바뀌는 능력치. [item] 은 계승한 강화 단계
/// [enhance] 로 계산한다.
class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.item,
    required this.replaced,
    required this.enhance,
  });

  final Item item;
  final List<Item> replaced;
  final int enhance;

  static Map<StatType, double> _sum(Iterable<Item> items) {
    final total = <StatType, double>{};
    for (final item in items) {
      for (final roll in item.effectiveStats) {
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
    final gain = <StatType, double>{};
    for (final roll in item.statsAt(enhance)) {
      gain.update(roll.stat, (v) => v + roll.value, ifAbsent: () => roll.value);
    }
    final loss = _sum(replaced);
    final lines = <Widget>[
      Text(
        replaced.isEmpty
            ? '빈 칸'
            : '교체: ${replaced.map((i) => i.name).join(', ')}',
        style: _Text.tag,
      ),
      if (enhance > item.enhance)
        Text(
          '강화 계승 +${item.enhance} → +$enhance',
          key: const Key('enhance-inherit'),
          style: _Text.body.copyWith(color: _Text.ember),
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
  static const ember = Color(0xFFFFB347);
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
