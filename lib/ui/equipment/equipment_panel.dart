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
import '../widgets/item_icon.dart';
import '../widgets/pixel_sprite.dart';

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

  /// 가방 필터. null 이면 전체.
  Rarity? _rarityFilter;
  _TypeFilter? _typeFilter;

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
            builder: (context, _) => _layout(),
          ),
        ),
      ),
    );
  }

  Widget get _materials => Text(
    '골드 ${_inventory.gold} · 강화석 ${_inventory.stones}'
    ' · 초월석 ${_inventory.transcendStones}',
    key: const Key('materials'),
    style: _Text.heading.copyWith(color: AshColors.gold),
  );

  Widget get _ember => Text(
    '잔불 ${_inventory.ember}',
    key: const Key('ember'),
    style: _Text.heading.copyWith(color: _Text.ember),
  );

  Widget get _close => IconButton(
    key: const Key('close-equipment'),
    icon: const Icon(Icons.close, color: AshColors.parchment),
    onPressed: widget.onClose,
  );

  /// 세로 화면: 위에서부터 장착 칸 · 가방 · 상세. 아무것도 고르지 않았으면
  /// 상세 자리에 장비 능력치 합계를 보여 준다.
  Widget _layout() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text('장비', style: ashTitleStyle(22)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.character.name, style: _Text.heading)),
          _close,
        ],
      ),
      Wrap(spacing: 10, children: [_materials, _ember]),
      const SizedBox(height: 8),
      _equippedGrid(),
      const SizedBox(height: 10),
      // 장비를 고르면 가방 · 능력치 자리를 상세가 넓게 쓴다.
      if (_selected == null) ...[
        Expanded(flex: 3, child: _bag()),
        const Divider(color: Color(0x33E8C887), height: 16),
        Expanded(flex: 2, child: _statSummary()),
      ] else ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('close-detail'),
            onPressed: () => _select(null),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('가방으로'),
            style: TextButton.styleFrom(foregroundColor: AshColors.gold),
          ),
        ),
        Expanded(child: _detail()),
      ],
    ],
  );

  /// 장착 칸. 가운데에 이 캐릭터의 픽셀 스프라이트를 크게 세우고, 칸을 양옆에
  /// 위에서부터 늘어놓는다 (귀걸이 · 손 · 반지는 양쪽 같은 줄). 오른손은
  /// 오른쪽, 왼손은 왼쪽 줄이고, 양손장비를 끼면 왼손 칸은 막힌다.
  Widget _equippedGrid() => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 380.0);
      const side = _tile * 5 + _dollGap * 4;
      const height = side + _dollGap + _tile;
      // 스프라이트의 몸은 16x28 프레임의 8~28 줄. 정수 배로 키워 칸 사이에 맞춘다.
      final scale = math
          .min(side * 0.8 / 20, (width - _tile * 2 - 40) / 16)
          .floorToDouble();
      final sprite = Rect.fromLTWH(
        (width - 16 * scale) / 2,
        (side - 20 * scale) / 2 - 8 * scale,
        16 * scale,
        28 * scale,
      );
      Offset tileAt(_DollSide where, int row) => switch (where) {
        _DollSide.left => Offset(0, (_tile + _dollGap) * row),
        _DollSide.right => Offset(width - _tile, (_tile + _dollGap) * row),
        _DollSide.bottom => Offset((width - _tile) / 2, side + _dollGap),
      };
      Widget slot(EquipSlot slot, Offset pos) => Positioned(
        left: pos.dx,
        top: pos.dy,
        child: slot == EquipSlot.hand2 && _gear.offHandBlocked
            ? const _ItemTile(
                key: Key('slot-hand2-blocked'),
                item: null,
                label: '양손 사용',
                slotType: ItemType.twoHand,
                dimmed: true,
              )
            : _ItemTile(
                key: Key('slot-${slot.name}'),
                item: _gear.equipped[slot],
                label: slot.label,
                slotType: slot.type,
                selected: _selectedSlot == slot,
                onTap: () => _select(_gear.equipped[slot], slot),
              ),
      );
      return Center(
        child: SizedBox(
          key: const Key('paper-doll'),
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: sprite,
                child: PixelSprite(
                  asset: 'assets/images/${widget.character.sprite}',
                  frameSize: const Size(16, 28),
                  count: 4,
                  fps: 4,
                  scale: scale,
                ),
              ),
              for (final (s, where, row) in _dollLayout)
                slot(s, tileAt(where, row)),
            ],
          ),
        ),
      );
    },
  );

  static const double _dollGap = 8;

  /// 칸 자리: (칸, 줄 쪽, 위에서부터 몇 번째). 짝이 있는 귀걸이 · 손 · 반지는
  /// 양쪽 같은 줄에 둔다.
  static const _dollLayout = [
    (EquipSlot.head, _DollSide.left, 0),
    (EquipSlot.earring1, _DollSide.left, 1),
    (EquipSlot.hand2, _DollSide.left, 2),
    (EquipSlot.ring1, _DollSide.left, 3),
    (EquipSlot.gloves, _DollSide.left, 4),
    (EquipSlot.necklace, _DollSide.right, 0),
    (EquipSlot.earring2, _DollSide.right, 1),
    (EquipSlot.hand1, _DollSide.right, 2),
    (EquipSlot.ring2, _DollSide.right, 3),
    (EquipSlot.belt, _DollSide.right, 4),
    (EquipSlot.boots, _DollSide.bottom, 0),
  ];

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

  bool _passes(Item item) =>
      (_rarityFilter == null || item.rarity == _rarityFilter) &&
      (_typeFilter == null || _typeFilter!.types.contains(item.type));

  Widget _bag() {
    final bag = _inventory.bag;
    final shown = [
      for (final (i, item) in bag.indexed)
        if (_passes(item)) (i, item),
    ];
    final filtered = _rarityFilter != null || _typeFilter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가방 ${bag.length} / ${Balance.bagCapacity}'
          '${filtered ? ' · ${shown.length}개 표시' : ''}',
          style: _inventory.bagFull
              ? _Text.heading.copyWith(color: AshColors.ember)
              : _Text.heading,
        ),
        const SizedBox(height: 4),
        _filterRow([
          _chip(
            'filter-rarity-all',
            '전체 등급',
            null,
            _rarityFilter == null,
            () => setState(() => _rarityFilter = null),
          ),
          for (final r in Rarity.values)
            _chip(
              'filter-rarity-${r.name}',
              r.label,
              r.color,
              _rarityFilter == r,
              () => setState(() => _rarityFilter = r),
            ),
        ]),
        const SizedBox(height: 4),
        _filterRow([
          _chip(
            'filter-type-all',
            '전체 부위',
            null,
            _typeFilter == null,
            () => setState(() => _typeFilter = null),
          ),
          for (final t in _TypeFilter.values)
            _chip(
              'filter-type-${t.name}',
              t.label,
              null,
              _typeFilter == t,
              () => setState(() => _typeFilter = t),
            ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: bag.isEmpty
              ? const Text('비어 있음', style: _Text.dim)
              : shown.isEmpty
              ? const Text('조건에 맞는 장비가 없습니다', style: _Text.dim)
              : GridView.extent(
                  key: const Key('bag-grid'),
                  maxCrossAxisExtent: _tile + _gap,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                  children: [
                    for (final (i, item) in shown)
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

  Widget _filterRow(List<Widget> chips) => SizedBox(
    height: 28,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    ),
  );

  /// 필터 칩 하나. 등급 칩은 그 등급 색으로 쓴다.
  Widget _chip(
    String key,
    String label,
    Color? color,
    bool selected,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      key: Key(key),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x33E8C887) : Colors.transparent,
          border: Border.all(
            color: selected ? AshColors.gold : (color ?? Colors.white24),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color ?? (selected ? AshColors.gold : AshColors.parchment),
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ),
  );

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
                targets.length == 1 ? '장착' : '${target.place}에 장착',
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

/// 장비 아이콘 · 이름, 주옵션과 부가 옵션(옵션 등급 색), 고유 효과, 초월 옵션.
/// 묶음마다 제목을 달아 무엇이 주옵션이고 무엇이 부가 옵션인지 한눈에 보이게 한다.
class ItemDetails extends StatelessWidget {
  const ItemDetails({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final [main, ...affixes] = item.effectiveStats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: item.rarity.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: item.rarity.color, width: 1.5),
              ),
              child: ItemIcon(item.type, rarity: item.rarity, scale: 3),
            ),
            const SizedBox(width: 10),
            Expanded(
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
                  Text(
                    '${item.type.label} · Lv ${item.level}'
                    '${item.enhance > 0 ? ' · 강화 +${item.enhance}/${Balance.maxEnhance}' : ''}',
                    style: _Text.tag,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _OptionHeader('주옵션', note: '부위마다 정해진 능력치 · 장비 등급을 따름'),
        _OptionLine(
          key: const Key('main-stat'),
          text: main.stat.format(main.value),
          color: item.rarity.color,
          bold: true,
        ),
        const SizedBox(height: 8),
        _OptionHeader(
          '부가 옵션 ${affixes.length}/${Balance.maxAffixes}',
          note: '무작위 · 줄마다 등급이 따로 붙음',
        ),
        if (affixes.isEmpty)
          const _OptionLine(text: '없음', color: AshColors.ash, bullet: false),
        for (final (i, roll) in affixes.indexed)
          _OptionLine(
            key: Key('affix-$i'),
            text: roll.stat.format(roll.value),
            color: roll.rarity.color,
            grade: roll.rarity.label,
          ),
        if (item.effect case final effect?) ...[
          const SizedBox(height: 8),
          const _OptionHeader('고유 효과'),
          _OptionLine(
            text: effect.label,
            color: Rarity.unique.color,
            bold: true,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(effect.description, style: _Text.dim),
          ),
        ],
        if (item.transcends.isNotEmpty) ...[
          const SizedBox(height: 8),
          _OptionHeader('초월 ★${item.transcends.length}'),
          for (final t in item.transcends)
            _OptionLine(
              text: t.option.format(t.value),
              color: TranscendOption.color,
            ),
        ],
      ],
    );
  }
}

/// 옵션 묶음 제목과 밑줄. [note] 는 그 묶음이 무엇인지 한 줄 설명.
class _OptionHeader extends StatelessWidget {
  const _OptionHeader(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 3),
    padding: const EdgeInsets.only(bottom: 2),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white12)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: _Text.heading.copyWith(fontSize: 12)),
        if (note case final note?) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note,
              style: _Text.tag,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    ),
  );
}

/// 옵션 한 줄. 앞에 [color] 마름모, 뒤에 옵션 등급 [grade].
class _OptionLine extends StatelessWidget {
  const _OptionLine({
    super.key,
    required this.text,
    required this.color,
    this.grade,
    this.bold = false,
    this.bullet = true,
  });

  final String text;
  final Color color;
  final String? grade;
  final bool bold;
  final bool bullet;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Row(
      children: [
        SizedBox(
          width: 12,
          child: bullet
              ? Text('◆', style: TextStyle(color: color, fontSize: 8))
              : null,
        ),
        Expanded(
          child: Text(
            text,
            style: bold
                ? _Text.main.copyWith(color: color, fontSize: 14)
                : _Text.body.copyWith(color: color),
          ),
        ),
        if (grade case final grade?)
          Text(grade, style: _Text.tag.copyWith(color: color)),
      ],
    ),
  );
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
    this.slotType,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  final Item? item;
  final String label;

  /// 빈 장착 칸이면 끼울 수 있는 부위. 흐린 실루엣 아이콘으로 그린다.
  final ItemType? slotType;
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
          // 바탕을 불투명하게 칠해 빛이 칸 안으로 비쳐 들지 않고 둘레에만 번지게 한다.
          color: Color.alphaBlend(
            color?.withValues(alpha: 0.18) ?? Colors.white10,
            const Color(0xFF15110F),
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AshColors.gold : color ?? Colors.white24,
            width: selected ? 2.5 : 1.5,
          ),
          // 영웅 이상은 칸 둘레도 등급 색으로 빛난다. 높은 등급일수록 넓고 진하게.
          boxShadow: [
            if (item case final item? when ItemIcon.glows(item.rarity))
              BoxShadow(
                color: item.rarity.color.withValues(
                  alpha: 0.35 + 0.1 * ItemIcon.glowLevel(item.rarity),
                ),
                blurRadius: 6 + 3.0 * ItemIcon.glowLevel(item.rarity),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (item case final item?)
              ItemIcon(item.type, rarity: item.rarity)
            else
              // 빈 칸: 무엇을 끼는 칸인지 흐린 실루엣과 이름으로 보여 준다.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slotType case final type?)
                    ItemIcon(
                      type,
                      scale: 1.5,
                      silhouette: Colors.white.withValues(
                        alpha: dimmed ? 0.06 : 0.14,
                      ),
                    ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: AshColors.ash.withValues(
                          alpha: dimmed ? 0.5 : 1,
                        ),
                        fontSize: slotType == null ? 10 : 9,
                      ),
                    ),
                  ),
                ],
              ),
            if (dimmed)
              const Positioned(
                top: 2,
                child: Icon(Icons.block, size: 12, color: Colors.white24),
              ),
            if (item case final item? when item.enhance > 0)
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '+${item.enhance}',
                  style: const TextStyle(
                    color: AshColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 가방 부위 필터. 무기는 한손 · 양손을 함께 본다.
enum _TypeFilter {
  head('머리', {ItemType.head}),
  necklace('목걸이', {ItemType.necklace}),
  earring('귀걸이', {ItemType.earring}),
  weapon('무기', {ItemType.oneHand, ItemType.twoHand}),
  gloves('장갑', {ItemType.gloves}),
  belt('허리띠', {ItemType.belt}),
  ring('반지', {ItemType.ring}),
  boots('장화', {ItemType.boots});

  const _TypeFilter(this.label, this.types);

  final String label;
  final Set<ItemType> types;
}

enum _DollSide { left, right, bottom }
