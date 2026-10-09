import 'package:flutter/material.dart';

import '../../data/balance.dart';
import '../../data/equipment.dart';
import '../../data/fates.dart';
import '../../data/supplies.dart';
import '../../data/transcend.dart';
import '../../data/upgrades.dart';
import '../../systems/fate_system.dart';
import '../../systems/loot_system.dart';
import '../profile_scope.dart';
import '../theme.dart';

/// 확률형 요소의 확률표. 수치는 모두 [Balance] 와 [LootSystem] 에서 계산해
/// 밸런스를 바꿔도 표가 어긋나지 않는다.
///
/// 타락 단계 · 깊은 신앙(화톳불 강화)으로 확률이 바뀌는 표는 기본 확률과 지금 플레이어가
/// 받는 확률(최전선 스테이지 기준)을 나란히 보여 준다.
class OddsScreen extends StatelessWidget {
  const OddsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final stage = profile.progress.unlocked;
    return Scaffold(
      backgroundColor: AshColors.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('확률 정보', style: ashTitleStyle(22)),
                  const Spacer(),
                  IconButton(
                    key: const Key('close-odds'),
                    icon: const Icon(Icons.close, color: AshColors.parchment),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: OddsList(
                      corruption: stage.corruption,
                      fateLuck: profile.upgrades.value(Upgrade.fateLuck),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 확률표 목록. [corruption] 은 지금 최전선의 타락 단계, [fateLuck] 은 깊은 신앙 강화의 등급 운.
class OddsList extends StatelessWidget {
  const OddsList({super.key, required this.corruption, required this.fateLuck});

  final int corruption;
  final double fateLuck;

  double get _luck => Balance.corruptionRarityLuck * corruption;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('odds-list'),
    children: [
      _Note(
        '모든 확률은 게임 안의 실제 계산과 같은 값입니다. '
        '타락 단계와 화톳불 강화 ${Upgrade.fateLuck.title}에 따라 바뀌는 확률은 '
        '기본값과 지금 값을 함께 보여 줍니다.',
      ),
      ..._enhance(),
      ..._transcend(),
      ..._drops(),
      ..._affixes(),
      ..._currency(),
      ..._crates(),
      ..._fates(),
    ],
  );

  List<Widget> _crates() => [
    const _Section('전투 맵 상자'),
    _Table(
      header: const ['나무 상자에서 나오는 것', '확률'],
      rows: [
        for (final drop in CrateDrop.values)
          [drop.label, pct(LootSystem.crateDropChance(drop))],
      ],
    ),
    _Note(
      '상자가 나올 때 ${pct(Balance.chestChance)} 확률로 보물 상자가 됩니다. '
      '보물 상자에서는 장비 1개(등급 확률은 보스 상자와 같음)와 '
      '골드 주머니가 확정으로 나옵니다. 나무 상자의 장비는 일반 드랍과 같은 등급 확률입니다.',
    ),
  ];

  /// 강화: 확률이 같은 단계끼리 묶는다.
  List<Widget> _enhance() {
    final rows = <List<String>>[];
    final chances = Balance.enhanceChances;
    int stones(int step) =>
        Balance.enhanceStones + Balance.enhanceStonesPerStep * step;
    var from = 0;
    for (var i = 1; i <= chances.length; i++) {
      if (i < chances.length && chances[i] == chances[from]) continue;
      final last = i - 1;
      rows.add([
        from == last ? '+$from' : '+$from ~ +$last',
        from == last ? '${stones(from)}' : '${stones(from)} ~ ${stones(last)}',
        pct(chances[from]),
      ]);
      from = i;
    }
    return [
      const _Section('장비 강화'),
      _Table(header: const ['지금 단계', '강화석', '성공 확률'], rows: rows),
      const _Note('실패하면 강화석과 골드만 사라지고 강화 단계는 내려가지 않습니다.'),
    ];
  }

  List<Widget> _transcend() {
    final options = TranscendOption.values.length;
    return [
      const _Section('장비 초월'),
      _Table(
        header: const ['단계', '초월석', '성공 확률'],
        rows: [
          for (var i = 0; i < Balance.transcendChances.length; i++)
            [
              '★$i → ★${i + 1}',
              '${Balance.transcendStones[i]}',
              pct(Balance.transcendChances[i]),
            ],
        ],
      ),
      _Note(
        '성공하면 이 장비에 아직 없는 초월 옵션 중 하나가 같은 확률로 붙습니다 '
        '(★1: 각 ${pct(1 / options)}, ★2: 각 ${pct(1 / (options - 1))}, '
        '★3: 각 ${pct(1 / (options - 2))}). 실패하면 초월석과 골드만 사라집니다.',
      ),
    ];
  }

  List<Widget> _drops() {
    final now = corruption > 0;
    final dropNow =
        Balance.itemDropChance * (1 + Balance.corruptionDropBonus * corruption);
    return [
      const _Section('장비 드랍'),
      _Note(
        '적 처치당 장비 드랍 ${pct(Balance.itemDropChance)}'
        '${now ? ' (타락 $corruption: ${pct(dropNow)})' : ''}. '
        '보스를 잡으면 레어 이상 장비 ${Balance.bossChestItems}개가 확정으로 떨어집니다.',
      ),
      _Table(
        header: [
          '등급',
          '일반 드랍',
          if (now) '타락 $corruption',
          '보스 상자',
          if (now) '타락 $corruption',
        ],
        rows: [
          for (final r in Rarity.values)
            [
              r.label,
              pct(LootSystem.rarityChance(r)),
              if (now) pct(LootSystem.rarityChance(r, luck: _luck)),
              pct(LootSystem.bossChestChance(r)),
              if (now) pct(LootSystem.bossChestChance(r, luck: _luck)),
            ],
        ],
        colors: [for (final r in Rarity.values) r.color],
      ),
      _Note(
        '부위는 ${ItemType.values.length}종이 같은 확률(각 ${pct(1 / ItemType.values.length)})로 정해집니다. '
        '고유 장비에는 특수 효과 ${UniqueEffect.values.length}종 중 하나가 같은 확률'
        '(각 ${pct(1 / UniqueEffect.values.length)})로 붙습니다.',
      ),
    ];
  }

  List<Widget> _affixes() => [
    const _Section('랜덤옵션'),
    _Table(
      header: const ['장비 등급', '옵션 한 칸이 붙을 확률'],
      rows: [
        for (final r in Rarity.values)
          [r.label, '${pct(r.affixChance)} × ${Balance.maxAffixes}칸'],
      ],
      colors: [for (final r in Rarity.values) r.color],
    ),
    const _Note('옵션 한 줄의 등급 (장비 등급보다 높을 수 없음). 행: 장비 등급, 열: 옵션 등급'),
    _Table(
      header: ['', for (final r in Rarity.values) r.label],
      rows: [
        for (final item in Rarity.values)
          [
            item.label,
            for (final r in Rarity.values)
              r.index > item.index
                  ? '-'
                  : pct(LootSystem.affixRarityChance(r, item)),
          ],
      ],
      colors: [for (final r in Rarity.values) r.color],
      dense: true,
    ),
  ];

  List<Widget> _currency() {
    String withCorruption(double base, double perStep) => corruption > 0
        ? '${pct(base)} (타락 $corruption: ${pct(base + perStep * corruption)})'
        : pct(base);
    final stoneNow =
        Balance.stoneDropChance *
        (1 + Balance.corruptionDropBonus * corruption);
    return [
      const _Section('재화'),
      _Table(
        header: const ['항목', '확률'],
        rows: [
          [
            '처치당 강화석 1개',
            '${pct(Balance.stoneDropChance)}'
                '${corruption > 0 ? ' (타락 $corruption: ${pct(stoneNow)})' : ''}',
          ],
          ['보스 강화석 ${Balance.bossStones}개 + 타락 단계', '100%'],
          [
            '보스 초월석 1개',
            withCorruption(
              Balance.transcendStoneChance,
              Balance.transcendStoneChancePerCorruption,
            ),
          ],
        ],
      ),
    ];
  }

  List<Widget> _fates() {
    final luck = _luck + fateLuck;
    final now = luck > 0;
    final luckLabel = '지금 (운 +${(luck * 100).round()}%)';
    double chance(Rarity r, double luck) => LootSystem.rarityChance(
      r,
      luck: luck,
      ratio: Balance.fateRarityRatio,
      highScale: 1,
    );
    bool hasCurse(FateType type) =>
        FateCard.values.any((c) => c.type == type && c.curse);
    Iterable<FateCard> cardsOf(FateType type) =>
        FateCard.values.where((c) => c.type == type);
    String gods(Iterable<FateCard> cards) =>
        cards.map((c) => c.god.name).join(' · ');
    const choices = Balance.fateChoices;
    final moreChoices =
        choices +
        (Upgrade.fateChoices.perLevel * Upgrade.fateChoices.maxLevel).round();
    String average(FateType t, int count) =>
        '${FateSystem.expectedTypeCount(t, count).toStringAsFixed(2)}장';
    return [
      const _Section('신의 은총'),
      _Note(
        '보스를 잡으면 은총 카드 $choices장(화톳불 강화 ${Upgrade.fateChoices.title}: '
        '$moreChoices장)이 나옵니다. 카드마다 같은 종류 상한'
        '(${[for (final t in FateType.values) '${t.label} ${t.limit}장'].join(' · ')})이 '
        '차지 않은 종류 중 하나를 같은 확률로 고르고, 그 종류 안에서 아래 순서로 한 장을 뽑습니다. '
        '한 번에 같은 카드는 나오지 않습니다.',
      ),
      _Table(
        header: ['종류', '카드 수', '$choices장 중 평균', '$moreChoices장 중 평균', '저주 확률'],
        rows: [
          for (final t in FateType.values)
            [
              t.label,
              '${cardsOf(t).length}종',
              average(t, choices),
              average(t, moreChoices),
              hasCurse(t) ? pct(Balance.fateCurseChance) : '없음',
            ],
        ],
      ),
      const _Note('카드 한 장의 등급 확률'),
      _Table(
        header: ['등급', '기본', if (now) luckLabel],
        rows: [
          for (final r in Rarity.values)
            [r.label, pct(chance(r, 0)), if (now) pct(chance(r, luck))],
        ],
        colors: [for (final r in Rarity.values) r.color],
      ),
      _Note(
        '1) 저주가 있는 종류는 ${pct(Balance.fateCurseChance)} 확률로 저주 카드 중에서, '
        '아니면 저주가 아닌 카드 중에서 고릅니다. '
        '2) 등급을 위 확률로 뽑고, 고를 수 있는 카드의 최소 등급보다 낮으면 그 최소 등급으로 올립니다. '
        '3) 최소 등급이 그 등급 이하인 카드 중 하나를 같은 확률로 고릅니다. '
        '등급 운은 타락 단계마다 +${(Balance.corruptionRarityLuck * 100).round()}%, '
        '화톳불 강화 ${Upgrade.fateLuck.title} 레벨마다 '
        '+${(Balance.upgradeFateLuck * 100).round()}% 입니다.',
      ),
      for (final type in FateType.values) ...[
        _Note('${type.label} 은총: 이 종류에서 한 장을 뽑을 때 그 카드가 나올 확률 (모든 등급 합계)'),
        _Table(
          header: ['은총 (영역)', '최소 등급', '기본', if (now) luckLabel],
          rows: [
            for (final card in cardsOf(type))
              [
                '${card.title} (${card.domain.label}${card.curse ? ' · 저주' : ''})',
                card.minRarity.label,
                pct(FateSystem.cardChance(card)),
                if (now) pct(FateSystem.cardChance(card, luck: luck)),
              ],
          ],
          colors: [for (final card in cardsOf(type)) card.domain.color],
        ),
      ],
      _Note(
        '위 카드별 확률은 빠지는 카드가 없을 때 기준입니다. 이미 손에 든 카드, '
        '같거나 더 높은 세기로 이미 가진 효과'
        '(${gods(FateCard.values.where((c) => c.effect != null))}), '
        '더 올리거나 새로 얻을 무기가 없는 무기 카드'
        '(${gods([FateCard.smithsTouch, FateCard.newArms])})는 빠지고, '
        '남은 카드끼리 같은 확률로 나눕니다.',
      ),
    ];
  }
}

/// 확률을 퍼센트 문자열로. 작은 확률도 0 으로 보이지 않게 유효 숫자를 남긴다.
String pct(double p) {
  if (p <= 0) return '0%';
  final v = p * 100;
  final digits = v >= 10
      ? 1
      : v >= 1
      ? 2
      : v >= 0.1
      ? 3
      : 4;
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return '$s%';
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(title, style: ashTitleStyle(16)),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(color: AshColors.ash, fontSize: 11, height: 1.4),
    ),
  );
}

/// 머리글 한 줄과 본문 줄. [colors] 를 주면 줄마다 첫 칸을 그 색으로 칠한다.
class _Table extends StatelessWidget {
  const _Table({
    required this.header,
    required this.rows,
    this.colors,
    this.dense = false,
  });

  final List<String> header;
  final List<List<String>> rows;
  final List<Color>? colors;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 10.0 : 12.0;
    final pad = EdgeInsets.symmetric(vertical: 4, horizontal: dense ? 2 : 6);
    Widget cell(String text, TextStyle style, {bool first = false}) => Padding(
      padding: pad,
      child: Text(
        text,
        textAlign: first ? TextAlign.start : TextAlign.end,
        style: style,
      ),
    );
    return Table(
      columnWidths: {
        0: dense ? const FlexColumnWidth(1.2) : const FlexColumnWidth(1.6),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: AshColors.ash.withValues(alpha: 0.2),
        ),
        bottom: BorderSide(color: AshColors.ash.withValues(alpha: 0.2)),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: AshColors.panel),
          children: [
            for (final (i, h) in header.indexed)
              cell(
                h,
                TextStyle(
                  color: i > 0 && colors != null && dense
                      ? colors![i - 1]
                      : AshColors.gold,
                  fontSize: size,
                  fontWeight: FontWeight.bold,
                ),
                first: i == 0,
              ),
          ],
        ),
        for (final (r, row) in rows.indexed)
          TableRow(
            children: [
              for (final (i, text) in row.indexed)
                cell(
                  text,
                  TextStyle(
                    color: i == 0 && colors != null
                        ? colors![r]
                        : AshColors.parchment,
                    fontSize: size,
                  ),
                  first: i == 0,
                ),
            ],
          ),
      ],
    );
  }
}
