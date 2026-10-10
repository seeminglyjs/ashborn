import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/equipment.dart';
import '../../data/inventory.dart';
import '../../data/stats.dart';
import '../../data/transcend.dart';
import '../../services/audio.dart';
import '../odds/odds_screen.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/item_icon.dart';
import '../widgets/pixel_sprite.dart';

/// 직업 무기의 주인 이름 (장비 화면 표시용).
String _ownerName(CharacterId id) =>
    Roster.all.firstWhere((c) => c.id == id).name;

/// 이 등급 이상은 분해하기 전에 한 번 더 묻는다. 일괄 분해에 섞여 있으면 경고한다.
const confirmSalvageFrom = Rarity.hero;

/// 일괄 분해 다이얼로그가 처음 고르고 있는 등급.
const defaultBulkSalvageRarities = {Rarity.normal, Rarity.rare};

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
  _Sort _sort = _Sort.recent;

  /// 일괄 분해 다이얼로그에서 마지막으로 고른 설정. 패널이 열려 있는 동안 기억한다.
  Set<Rarity> _bulkRarities = defaultBulkSalvageRarities;
  bool _bulkKeepUpgraded = true;

  /// 가방 위에 잠깐 띄우는 분해 결과. 다른 장비를 고르면 지운다.
  String? _bagNotice;

  /// 마지막 강화 · 초월 결과 문구. 다른 장비를 고르면 지운다.
  String? _upgradeNotice;

  Inventory get _inventory => widget.inventory;
  late final Gear _gear = _inventory.gear(widget.character.id);

  void _select(Item? item, [EquipSlot? slot]) => setState(() {
    _selected = item;
    _selectedSlot = slot;
    _upgradeNotice = null;
    if (item != null) _bagNotice = null;
  });

  void _enhance(Item item) => setState(() {
    _inventory.enhance(item);
    GameAudio.enhance(item.enhance);
    _upgradeNotice = '강화 완료! +${item.enhance}';
  });

  /// 붙일 초월 옵션을 고르게 하고, 고르면 초월한다. 확률 없이 늘 성공한다.
  Future<void> _transcend(Item item) async {
    final options = TranscendOption.available({
      for (final t in item.transcends) t.option,
    });
    final option = await showDialog<TranscendOption>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('transcend-picker'),
        backgroundColor: AshColors.panel,
        title: Text(
          '초월 옵션 고르기 · ★${item.transcends.length + 1}',
          style: const TextStyle(color: TranscendOption.color, fontSize: 16),
        ),
        children: [
          for (final option in options)
            SimpleDialogOption(
              key: Key('transcend-option-${option.name}'),
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(
                option.format(option.base),
                style: const TextStyle(color: AshColors.parchment),
              ),
            ),
        ],
      ),
    );
    if (option == null || !mounted || !_inventory.canTranscend(item)) return;
    setState(() {
      _inventory.transcend(item, option);
      GameAudio.play(Sfx.transcend);
      _upgradeNotice = '초월 완료! ${option.label}';
    });
  }

  Future<void> _salvage(Item item) async {
    if (item.rarity.index >= confirmSalvageFrom.index &&
        await _confirmSalvage(item) != true) {
      return;
    }
    final ember = item.salvageValue;
    _inventory.salvage(item);
    _select(null);
    setState(() => _bagNotice = '${item.name} 분해 · 잔불 +$ember');
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

  /// 일괄 분해: 다이얼로그에서 등급 · 제외 조건을 고르고, 확인하면 한 번에 분해한다.
  Future<void> _bulkSalvage() async {
    final choice = await showDialog<_BulkChoice>(
      context: context,
      builder: (context) => _BulkSalvageDialog(
        inventory: _inventory,
        rarities: _bulkRarities,
        keepUpgraded: _bulkKeepUpgraded,
      ),
    );
    if (choice == null || !mounted) return;
    final targets = _inventory.salvageTargets(
      choice.rarities,
      keepUpgraded: choice.keepUpgraded,
    );
    final ember = _inventory.salvageAll(targets);
    setState(() {
      _bulkRarities = choice.rarities;
      _bulkKeepUpgraded = choice.keepUpgraded;
      _bagNotice = '${targets.length}개 일괄 분해 · 잔불 +$ember';
    });
  }

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

  /// 닫기. 장비 상세를 보고 있으면 패널을 닫지 않고 가방으로 돌아간다
  /// (런 중에 닫으면 일시정지 메뉴로 튀어나가 버리지 않도록).
  Widget get _close => IconButton(
    key: const Key('close-equipment'),
    tooltip: _selected == null ? '닫기' : '가방으로',
    icon: const Icon(Icons.close, color: AshColors.parchment),
    onPressed: _selected == null ? widget.onClose : () => _select(null),
  );

  /// 세로 화면. 위에 제목과 재화를 두고, 아무것도 고르지 않았으면 장착 칸 · 가방 ·
  /// 장비 능력치 합계를, 장비를 고르면 그 자리를 상세(스크롤)와 하단 고정 행동 바가 쓴다.
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
      if (_selected case final item?)
        Expanded(child: _detail(item))
      else ...[
        _equippedGrid(),
        const SizedBox(height: 10),
        Expanded(flex: 7, child: _bag()),
        // 세로가 짧은 화면에서는 가방이 한 줄도 안 보이지 않게 능력치 합계를 접는다.
        if (MediaQuery.sizeOf(context).height >= _summaryMinHeight) ...[
          const Divider(color: Color(0x33E8C887), height: 16),
          Expanded(flex: 3, child: _statSummary()),
        ],
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
      // 스프라이트의 몸은 프레임의 8~28 줄. 정수 배로 키워 칸 사이에 맞춘다.
      final scale = math
          .min(side * 0.8 / 20, (width - _tile * 2 - 40) / heroFrame.width)
          .floorToDouble();
      final sprite = Rect.fromLTWH(
        (width - heroFrame.width * scale) / 2,
        (side - 20 * scale) / 2 - 8 * scale,
        heroFrame.width * scale,
        heroFrame.height * scale,
      );
      Offset tileAt(_DollSide where, int row) => switch (where) {
        _DollSide.left => Offset(0, (_tile + _dollGap) * row),
        _DollSide.right => Offset(width - _tile, (_tile + _dollGap) * row),
        // 아래 줄은 두 칸 (갑옷 · 장화) 을 가운데에 나란히.
        _DollSide.bottom => Offset(
          width / 2 - _tile - _dollGap / 2 + (_tile + _dollGap) * row,
          side + _dollGap,
        ),
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
                  frameSize: heroFrame,
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

  /// 화면 세로가 이보다 짧으면 가방 아래 장비 능력치 합계를 숨긴다.
  static const double _summaryMinHeight = 720;

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
    (EquipSlot.armor, _DollSide.bottom, 0),
    (EquipSlot.boots, _DollSide.bottom, 1),
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

  bool get _filtered => _rarityFilter != null || _typeFilter != null;

  /// 가방: 개수 · 일괄 분해 줄, 등급 · 부위 · 정렬 드롭다운 줄, 장비 격자.
  /// 칸의 Key 는 정렬과 상관없이 가방 안 위치(`bag-<index>`)다.
  Widget _bag() {
    final bag = _inventory.bag;
    final shown = [
      for (final (i, item) in bag.indexed)
        if (_passes(item)) (i, item),
    ]..sort(_sort.compare);
    final full = _inventory.bagFull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                '가방 ${bag.length} / ${Balance.bagCapacity}'
                '${_filtered ? ' · ${shown.length}개 표시' : ''}',
                key: const Key('bag-count'),
                overflow: TextOverflow.ellipsis,
                style: full
                    ? _Text.heading.copyWith(color: AshColors.ember)
                    : _Text.heading,
              ),
            ),
            if (full) ...[
              const SizedBox(width: 6),
              const _Badge(
                key: Key('bag-full'),
                text: '가득 참',
                color: AshColors.ember,
              ),
            ],
            const Spacer(),
            // 가방이 차면 일괄 분해를 눈에 띄게 해 자리를 비우도록 이끈다.
            SizedBox(
              width: 100,
              child: _ActionButton(
                key: const Key('bulk-salvage'),
                label: '일괄 분해',
                tone: full ? _Tone.danger : _Tone.normal,
                height: 32,
                onPressed: bag.isEmpty ? null : _bulkSalvage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Expanded(
                child: _Dropdown(
                  key: const Key('filter-rarity'),
                  tooltip: '등급 필터',
                  selected: _rarityFilter == null
                      ? 0
                      : Rarity.values.indexOf(_rarityFilter!) + 1,
                  options: [
                    const _Option('filter-rarity-all', '전체 등급'),
                    for (final r in Rarity.values)
                      _Option(
                        'filter-rarity-${r.name}',
                        r.label,
                        color: r.color,
                      ),
                  ],
                  onSelected: (i) => setState(
                    () => _rarityFilter = i == 0 ? null : Rarity.values[i - 1],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Dropdown(
                  key: const Key('filter-type'),
                  tooltip: '부위 필터',
                  selected: _typeFilter == null ? 0 : _typeFilter!.index + 1,
                  options: [
                    const _Option('filter-type-all', '전체 부위'),
                    for (final t in _TypeFilter.values)
                      _Option('filter-type-${t.name}', t.label),
                  ],
                  onSelected: (i) => setState(
                    () =>
                        _typeFilter = i == 0 ? null : _TypeFilter.values[i - 1],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Dropdown(
                  key: const Key('sort'),
                  tooltip: '정렬',
                  icon: Icons.sort,
                  selected: _sort.index,
                  // 기본 정렬은 강조하지 않는다 (필터가 걸린 것처럼 보이지 않게).
                  highlightFrom: 1,
                  options: [
                    for (final s in _Sort.values)
                      _Option('sort-${s.name}', s.label, short: s.short),
                  ],
                  onSelected: (i) => setState(() => _sort = _Sort.values[i]),
                ),
              ),
            ],
          ),
        ),
        if (_bagNotice case final notice?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              notice,
              key: const Key('bag-notice'),
              style: _Text.body.copyWith(color: _Text.ember),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: bag.isEmpty
              ? const _Empty(title: '가방이 비어 있습니다', hint: '런에서 주운 장비가 여기에 쌓입니다')
              : shown.isEmpty
              ? _Empty(
                  title: '조건에 맞는 장비가 없습니다',
                  action: TextButton(
                    key: const Key('filter-reset'),
                    onPressed: () => setState(() {
                      _rarityFilter = null;
                      _typeFilter = null;
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: AshColors.gold,
                    ),
                    child: const Text('필터 초기화'),
                  ),
                )
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

  /// 장착 칸 둘 중 하나에 끼는 장비(반지 · 귀걸이 · 한손장비)를 화면의 왼쪽 → 오른쪽
  /// 순서로 늘어놓는다. 장착 칸 배치와 같아서 버튼과 칸이 같은 쪽에 있다.
  static List<EquipSlot> _targetsFor(Item item) =>
      Gear.slotsFor(item.type)
        ..sort((a, b) => _sideOf(a).index.compareTo(_sideOf(b).index));

  static _DollSide _sideOf(EquipSlot slot) =>
      _dollLayout.firstWhere((e) => e.$1 == slot).$2;

  /// 칸이 둘일 때 버튼에 쓰는 짧은 위치 이름.
  static String _shortPlace(EquipSlot slot) => switch (slot) {
    EquipSlot.earring1 || EquipSlot.ring1 => '왼쪽',
    EquipSlot.earring2 || EquipSlot.ring2 => '오른쪽',
    _ => slot.label,
  };

  /// 상세: 위는 스크롤되는 장비 정보 · 교체 비교, 아래는 고정 행동 바.
  Widget _detail(Item item) {
    final slot = _selectedSlot;
    final targets = _targetsFor(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              key: const Key('close-detail'),
              onPressed: () => _select(null),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('가방으로'),
              style: TextButton.styleFrom(
                foregroundColor: AshColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const Spacer(),
            _Badge(
              key: const Key('detail-place'),
              text: slot == null ? '가방' : '장착 중 · ${slot.place}',
              color: slot == null ? AshColors.ash : AshColors.gold,
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('detail-scroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemDetails(item: item),
                if (slot == null && _gear.canWear(item))
                  for (final target in targets) ...[
                    const SizedBox(height: 10),
                    _OptionHeader(
                      targets.length == 1 ? '장착하면' : '${target.place}에 장착하면',
                    ),
                    _Comparison(
                      item: item,
                      replaced: _gear.displacedBy(item, target),
                      enhance: _gear.enhanceAfterEquip(item, target),
                    ),
                  ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        _actionBar(item, slot, targets),
      ],
    );
  }

  /// 하단 고정 행동 바. 위에서부터 결과 메시지, 강화 · 초월 비용과 확률표,
  /// 보조 행동(강화 · 초월 · 분해) 한 줄, 주 행동(장착 · 해제) 한 줄.
  Widget _actionBar(Item item, EquipSlot? slot, List<EquipSlot> targets) {
    final canEnhance = _inventory.canEnhance(item);
    final canTranscend = _inventory.canTranscend(item);
    return Container(
      key: const Key('action-bar'),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x55E8C887))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_upgradeNotice case final notice?)
            _result('upgrade-result', notice, true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isMaxEnhance)
                      Text(
                        '최대 강화 +${Balance.maxEnhance}',
                        key: const Key('enhance-cost'),
                        style: _Text.tag.copyWith(color: AshColors.gold),
                      )
                    else
                      _cost(
                        'enhance-cost',
                        '강화석 ${item.enhanceStones} · 골드 ${item.enhanceGold}',
                        affordable: canEnhance,
                      ),
                    // 초월은 최대 강화한 영웅 이상 장비만 할 수 있다.
                    if (item.canTranscend)
                      _cost(
                        'transcend-cost',
                        '초월석 ${item.transcendStones} · 골드 ${item.transcendGold}',
                        affordable: canTranscend,
                        color: TranscendOption.color,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const Key('enhance-odds'),
                onTap: () =>
                    Navigator.of(context).push(fadeRoute(const OddsScreen())),
                child: const Text(
                  '확률 정보',
                  style: TextStyle(
                    color: _Text.ember,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationColor: _Text.ember,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: _spaced([
              Expanded(
                child: _ActionButton(
                  key: const Key('enhance'),
                  label: item.isMaxEnhance ? '최대 강화' : '강화',
                  caption: item.isMaxEnhance
                      ? null
                      : '+${item.enhance} → +${item.enhance + 1}',
                  onPressed: canEnhance ? () => _enhance(item) : null,
                ),
              ),
              if (item.canTranscend)
                Expanded(
                  child: _ActionButton(
                    key: const Key('transcend'),
                    label: '초월',
                    caption:
                        '★${item.transcends.length + 1}'
                        '/${item.rarity.maxTranscend}',
                    onPressed: canTranscend ? () => _transcend(item) : null,
                  ),
                ),
              if (slot == null)
                Expanded(
                  child: _ActionButton(
                    key: const Key('salvage'),
                    label: '분해',
                    caption: '잔불 +${item.salvageValue}',
                    tone: _Tone.danger,
                    onPressed: () => _salvage(item),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(
            children: _spaced([
              if (slot != null)
                Expanded(
                  child: _ActionButton(
                    key: const Key('unequip'),
                    label: '해제',
                    caption: '가방으로',
                    tone: _Tone.primary,
                    height: 48,
                    onPressed: () {
                      _gear.unequip(slot);
                      _select(null);
                    },
                  ),
                )
              else if (!_gear.canWear(item))
                Expanded(
                  child: _ActionButton(
                    key: const Key('equip-locked'),
                    label: '${_ownerName(item.kind!.owner)} 전용',
                    caption: '${widget.character.name}은(는) 낄 수 없음',
                    height: 48,
                    onPressed: null,
                  ),
                )
              else
                for (final target in targets)
                  Expanded(
                    child: _ActionButton(
                      key: Key('equip-${target.name}'),
                      label: targets.length == 1
                          ? '장착'
                          : '${_shortPlace(target)}에 장착',
                      tone: _Tone.primary,
                      height: 48,
                      onPressed: () {
                        _gear.equip(item, target);
                        _select(null);
                      },
                    ),
                  ),
            ]),
          ),
        ],
      ),
    );
  }

  /// 버튼 사이에 같은 간격을 넣는다.
  static List<Widget> _spaced(List<Widget> children) => [
    for (final (i, child) in children.indexed) ...[
      if (i > 0) const SizedBox(width: 6),
      child,
    ],
  ];

  /// 비용 한 줄. 재료가 모자라면 붉게 쓴다.
  Widget _cost(
    String key,
    String text, {
    required bool affordable,
    Color color = AshColors.parchment,
  }) => Text(
    text,
    key: Key(key),
    style: _Text.tag.copyWith(
      fontSize: 11,
      color: affordable ? color : _Text.down,
    ),
  );

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
              child: ItemIcon(
                item.type,
                rarity: item.rarity,
                kind: item.kind,
                scale: 3,
              ),
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
                    '${item.kind == null ? item.type.label : '${item.type.label} · ${_ownerName(item.kind!.owner)} 전용'}'
                    ' · Lv ${item.level}'
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
              ItemIcon(item.type, rarity: item.rarity, kind: item.kind)
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
  armor('갑옷', {ItemType.armor}),
  gloves('장갑', {ItemType.gloves}),
  belt('허리띠', {ItemType.belt}),
  ring('반지', {ItemType.ring}),
  boots('장화', {ItemType.boots});

  const _TypeFilter(this.label, this.types);

  final String label;
  final Set<ItemType> types;
}

/// 가방 정렬. 기준이 같으면 최근에 가방에 들어온 장비가 앞에 온다.
enum _Sort {
  recent('최근 획득순', '최근순'),
  rarity('등급 높은순', '등급순'),
  level('레벨 높은순', '레벨순'),
  enhance('강화 높은순', '강화순');

  const _Sort(this.label, this.short);

  final String label;

  /// 드롭다운 버튼에 쓰는 짧은 이름.
  final String short;

  List<int Function(Item)> get _keys => switch (this) {
    recent => const [],
    rarity => [(i) => i.rarity.index, (i) => i.level, (i) => i.enhance],
    level => [(i) => i.level, (i) => i.rarity.index, (i) => i.enhance],
    enhance => [
      (i) => i.enhance,
      (i) => i.transcends.length,
      (i) => i.rarity.index,
    ],
  };

  /// (가방 안 위치, 장비) 를 내림차순으로 비교한다.
  int compare((int, Item) a, (int, Item) b) {
    for (final key in _keys) {
      final c = key(b.$2).compareTo(key(a.$2));
      if (c != 0) return c;
    }
    return b.$1.compareTo(a.$1);
  }
}

enum _DollSide { left, right, bottom }

/// 드롭다운의 항목 하나. [key] 는 펼친 메뉴 안 항목의 Key 이름이다.
class _Option {
  const _Option(this.key, this.label, {this.short, this.color});

  final String key;
  final String label;

  /// 버튼에 접혀 있을 때 쓰는 짧은 이름. 없으면 [label].
  final String? short;

  /// 등급처럼 색이 있는 항목의 색.
  final Color? color;
}

/// 눌러 펼치는 작은 드롭다운. 지금 고른 항목을 버튼에 보여 주고, 펼친 메뉴에서
/// 고른 항목의 위치를 [onSelected] 로 알린다. [highlightFrom] 이상을 고르면
/// 걸러지고 있다는 뜻으로 테두리를 금빛으로 칠한다.
class _Dropdown extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.tooltip,
    this.icon,
    this.highlightFrom = 1,
  });

  final List<_Option> options;
  final int selected;
  final ValueChanged<int> onSelected;
  final String tooltip;
  final IconData? icon;
  final int highlightFrom;

  @override
  Widget build(BuildContext context) {
    final current = options[selected];
    final active = selected >= highlightFrom;
    return PopupMenuButton<int>(
      tooltip: tooltip,
      initialValue: selected,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      color: const Color(0xFF1C1612),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0x66E8C887)),
      ),
      constraints: const BoxConstraints(minWidth: 128),
      itemBuilder: (context) => [
        for (final (i, option) in options.indexed)
          PopupMenuItem<int>(
            key: Key(option.key),
            value: i,
            height: 38,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: i == selected
                      ? const Icon(Icons.check, size: 14, color: AshColors.gold)
                      : null,
                ),
                if (option.color case final color?) ...[
                  _Dot(color),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.label,
                  style: TextStyle(
                    color: option.color ?? AshColors.parchment,
                    fontSize: 13,
                    fontWeight: i == selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0x22E8C887) : const Color(0xFF15110F),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? AshColors.gold : Colors.white24),
        ),
        child: Row(
          children: [
            if (icon case final icon?) ...[
              Icon(icon, size: 14, color: AshColors.ash),
              const SizedBox(width: 4),
            ],
            if (current.color case final color?) ...[
              _Dot(color),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                current.short ?? current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      current.color ??
                      (active ? AshColors.gold : AshColors.parchment),
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: AshColors.ash),
          ],
        ),
      ),
    );
  }
}

/// 등급 색 점.
class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 작은 글씨 딱지. 가득 찬 가방, 상세의 장비 위치에 쓴다.
class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}

/// 가방이 비었거나 걸러진 장비가 없을 때의 안내.
class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.hint, this.action});

  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: _Text.dim),
      if (hint case final hint?) Text(hint, style: _Text.tag),
      ?action,
    ],
  );
}

/// 행동 버튼의 결: 주 행동, 보조 행동, 되돌릴 수 없는 위험 행동.
enum _Tone { primary, normal, danger }

/// 장비 화면의 작은 행동 버튼. 아이콘과 짧은 라벨, 필요하면 아래에 작은 [caption].
/// [onPressed] 가 null 이면 흐리게 그리고 눌리지 않는다.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.caption,
    this.tone = _Tone.normal,
    this.height = 44,
  });

  final String label;
  final String? caption;
  final VoidCallback? onPressed;
  final _Tone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (List<Color> fill, Color border, Color fg) = !enabled
        ? (
            const [Color(0xFF2A2522), Color(0xFF1A1714)],
            Colors.white12,
            AshColors.ash.withValues(alpha: 0.7),
          )
        : switch (tone) {
            _Tone.primary => (
              const [Color(0xFF7A3418), Color(0xFF3E1A0C)],
              AshColors.gold,
              AshColors.parchment,
            ),
            _Tone.normal => (
              const [Color(0xFF3A2E22), Color(0xFF201811)],
              const Color(0x99E8C887),
              AshColors.parchment,
            ),
            _Tone.danger => (
              const [Color(0xFF3E1616), Color(0xFF1E0B0B)],
              const Color(0xFFB33A3A),
              const Color(0xFFFFB0A8),
            ),
          };
    final radius = BorderRadius.circular(4);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: fill,
            ),
            borderRadius: radius,
            border: Border.all(
              color: border,
              width: tone == _Tone.primary && enabled ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            splashColor: AshColors.ember.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              color: fg,
                              fontSize: tone == _Tone.primary ? 14 : 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (caption case final caption?)
                            Text(
                              caption,
                              maxLines: 1,
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.75),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 일괄 분해 다이얼로그에서 고른 설정.
typedef _BulkChoice = ({Set<Rarity> rarities, bool keepUpgraded});

/// 일괄 분해: 분해할 등급과 "강화 · 초월한 장비 제외" 를 고르면 대상 개수와
/// 얻을 잔불을 바로 보여 준다. 확인하면 고른 설정을 돌려준다.
class _BulkSalvageDialog extends StatefulWidget {
  const _BulkSalvageDialog({
    required this.inventory,
    required this.rarities,
    required this.keepUpgraded,
  });

  final Inventory inventory;
  final Set<Rarity> rarities;
  final bool keepUpgraded;

  @override
  State<_BulkSalvageDialog> createState() => _BulkSalvageDialogState();
}

class _BulkSalvageDialogState extends State<_BulkSalvageDialog> {
  late final Set<Rarity> _rarities = {...widget.rarities};
  late bool _keepUpgraded = widget.keepUpgraded;

  @override
  Widget build(BuildContext context) {
    final inventory = widget.inventory;
    final targets = inventory.salvageTargets(
      _rarities,
      keepUpgraded: _keepUpgraded,
    );
    final ember = targets.fold(0, (sum, item) => sum + item.salvageValue);
    final risky = targets
        .where((i) => i.rarity.index >= confirmSalvageFrom.index)
        .length;
    // 등급마다 지금 조건으로 분해될 개수.
    final counts = {
      for (final r in Rarity.values)
        r: inventory.salvageTargets({r}, keepUpgraded: _keepUpgraded).length,
    };
    Widget toggle(Rarity r) => _RarityToggle(
      key: Key('bulk-rarity-${r.name}'),
      rarity: r,
      count: counts[r]!,
      selected: _rarities.contains(r),
      onTap: () => setState(() {
        if (!_rarities.remove(r)) _rarities.add(r);
      }),
    );
    return Dialog(
      backgroundColor: const Color(0xFF1A1411),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0x66E8C887)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('일괄 분해', style: ashTitleStyle(18)),
              const SizedBox(height: 4),
              const Text(
                '가방의 장비만 분해합니다. 장착 중인 장비는 대상이 아닙니다.',
                style: _Text.tag,
              ),
              const SizedBox(height: 12),
              const Text('분해할 등급', style: _Text.heading),
              const SizedBox(height: 6),
              for (var i = 0; i < Rarity.values.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: toggle(Rarity.values[i])),
                      const SizedBox(width: 6),
                      Expanded(child: toggle(Rarity.values[i + 1])),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              InkWell(
                key: const Key('bulk-keep-upgraded'),
                onTap: () => setState(() => _keepUpgraded = !_keepUpgraded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _keepUpgraded
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: _keepUpgraded ? AshColors.gold : AshColors.ash,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('강화했거나 초월한 장비는 제외', style: _Text.body),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x22FF6B35),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x55FF6B35)),
                ),
                child: Text(
                  '대상 ${targets.length}개 · 잔불 +$ember',
                  key: const Key('bulk-summary'),
                  style: _Text.main.copyWith(color: _Text.ember),
                ),
              ),
              if (risky > 0) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: _Text.down,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '영웅 이상 장비 $risky개가 포함되어 있습니다. '
                        '분해한 장비는 되찾을 수 없습니다.',
                        key: const Key('bulk-warning'),
                        style: _Text.body.copyWith(color: _Text.down),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      key: const Key('cancel-bulk-salvage'),
                      label: '취소',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      key: const Key('confirm-bulk-salvage'),
                      label: '${targets.length}개 분해',
                      tone: _Tone.danger,
                      onPressed: targets.isEmpty
                          ? null
                          : () => Navigator.of(context).pop<_BulkChoice>((
                              rarities: {..._rarities},
                              keepUpgraded: _keepUpgraded,
                            )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 일괄 분해 등급 하나를 켜고 끄는 칸. 등급 색과 지금 조건의 대상 개수를 보여 준다.
class _RarityToggle extends StatelessWidget {
  const _RarityToggle({
    super.key,
    required this.rarity,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Rarity rarity;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected
            ? rarity.color.withValues(alpha: 0.18)
            : const Color(0xFF15110F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? rarity.color : Colors.white24,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: selected ? rarity.color : AshColors.ash,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              rarity.label,
              style: TextStyle(
                color: rarity.color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text('$count', style: _Text.tag.copyWith(fontSize: 11)),
        ],
      ),
    ),
  );
}
