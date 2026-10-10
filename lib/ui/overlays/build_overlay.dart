import 'package:flutter/material.dart';

import '../../components/weapons/weapon.dart';
import '../../data/passives.dart';
import '../../data/weapons.dart';
import '../../game/ashborn_game.dart';
import '../grace/grace_screen.dart';
import '../theme.dart';
import '../widgets/build_strip.dart';
import '../widgets/card_row.dart';

/// 런 중 카드 · 은총: 이번 런에서 고른 무기 · 패시브 카드와, 영구히 받은 은총을 한 화면에 모아 본다.
/// 일시정지 메뉴에서 열고, 닫으면 메뉴로 돌아간다.
class BuildOverlay extends StatelessWidget {
  const BuildOverlay({super.key, required this.game});

  final AshbornGame game;

  @override
  Widget build(BuildContext context) {
    final player = game.world.player;
    final passives = player.passives;
    final records = game.progress.graceRecords;
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
                  Text('카드 · 은총', style: ashTitleStyle(22)),
                  const Spacer(),
                  Text(
                    'Lv ${game.stats.level.value}',
                    style: const TextStyle(
                      color: Color(0xFF9FD8E8),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    key: const Key('close-build'),
                    tooltip: '닫기',
                    icon: const Icon(Icons.close, color: AshColors.parchment),
                    onPressed: game.closeBuild,
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      children: [
                        _Section('무기 ${player.weapons.length}개'),
                        for (final weapon in player.weapons)
                          _WeaponRow(
                            weapon: weapon,
                            catalyst: passives[weapon.id.catalyst] ?? 0,
                          ),
                        _Section('패시브 ${passives.length}개'),
                        if (passives.isEmpty) const _Empty('아직 고른 패시브가 없습니다'),
                        for (final MapEntry(key: id, value: level)
                            in passives.entries)
                          _PassiveRow(id: id, level: level),
                        _Section('은총 ${records.length}개 · 합계'),
                        GraceTotals(graces: game.progress.graces),
                        const SizedBox(height: 8),
                        if (records.isEmpty) const _Empty('아직 받은 은총이 없습니다'),
                        for (final (stage, fate) in records.reversed)
                          GraceRow(stage: stage, fate: fate),
                      ],
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

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        color: AshColors.gold,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: AshColors.ash, fontSize: 13));
}

/// 카드 한 줄의 틀: 왼쪽 아이콘, 오른쪽에 이름 · 레벨과 설명 줄.
class _CardRow extends StatelessWidget {
  const _CardRow({
    super.key,
    required this.icon,
    required this.title,
    required this.level,
    required this.lines,
    this.accent = AshColors.ash,
  });

  final Widget icon;
  final String title;
  final String level;
  final List<(String, Color)> lines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AshColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OneLineText(
                        title,
                        style: const TextStyle(
                          color: AshColors.parchment,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      level,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                for (final (text, color) in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      keepWords(text),
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 무기 한 줄. 각성 전이면 각성 조건(최대 레벨 + 짝 패시브)과 지금 채운 것을 보인다.
class _WeaponRow extends StatelessWidget {
  const _WeaponRow({required this.weapon, required this.catalyst});

  final LeveledWeapon weapon;

  /// 각성에 필요한 짝 패시브의 지금 레벨.
  final int catalyst;

  @override
  Widget build(BuildContext context) {
    final id = weapon.id;
    final awakened = weapon.awakened;
    final full = weapon.isMaxLevel;
    return _CardRow(
      key: Key('build-weapon-${id.name}'),
      icon: CardIcon.weapon(id, weapon.level, awakened: awakened),
      title: awakened ? id.awakenedLabel : id.label,
      level: awakened ? '각성' : 'Lv ${weapon.level} / ${WeaponId.maxLevel}',
      accent: awakened
          ? AshColors.ember
          : full
          ? AshColors.gold
          : AshColors.ash,
      lines: [
        (awakened ? id.awakenedDescription : id.description, AshColors.ash),
        if (!awakened)
          (
            full && catalyst > 0
                ? '각성 조건을 채웠습니다 → 레벨업 카드에서 ${id.awakenedLabel}'
                : '각성 → ${id.awakenedLabel} · 필요: '
                      '${[if (!full) '최대 레벨', if (catalyst == 0) id.catalyst.label].join(', ')}',
            full && catalyst > 0 ? AshColors.gold : const Color(0x99B8AFA6),
          ),
      ],
    );
  }
}

/// 패시브 한 줄: 지금 레벨까지 쌓인 효과.
class _PassiveRow extends StatelessWidget {
  const _PassiveRow({required this.id, required this.level});

  final PassiveId id;
  final int level;

  @override
  Widget build(BuildContext context) {
    final full = level >= PassiveId.maxLevel;
    final total = switch (id.stat) {
      final stat? => stat.format(id.perLevel * level),
      null => '모든 무기 범위 +${(id.perLevel * level * 100).round()}%',
    };
    return _CardRow(
      key: Key('build-passive-${id.name}'),
      icon: CardIcon.passive(id, level),
      title: id.label,
      level: 'Lv $level / ${PassiveId.maxLevel}',
      accent: full ? AshColors.gold : AshColors.ash,
      lines: [(total, AshColors.parchment)],
    );
  }
}
