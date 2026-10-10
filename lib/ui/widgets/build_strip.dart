import 'package:flutter/material.dart';

import '../../components/player/player.dart';
import '../../data/passives.dart';
import '../../data/weapons.dart';
import '../theme.dart';
import 'pixel_sprite.dart';

/// 이번 런에서 고른 무기 · 패시브 카드를 아이콘 한 줄로 보인다. 아이콘 오른쪽 아래가 레벨
/// (최대면 MAX, 각성이면 ★). 끝에 받은 은총 수를 붙인다. [onTap] 을 주면 눌러 자세히 본다.
class BuildStrip extends StatelessWidget {
  const BuildStrip({
    super.key,
    required this.player,
    required this.graces,
    this.onTap,
  });

  final Player player;
  final int graces;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strip = Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final weapon in player.weapons)
          CardIcon.weapon(
            weapon.id,
            weapon.level,
            awakened: weapon.awakened,
            size: 36,
          ),
        for (final MapEntry(key: id, value: level) in player.passives.entries)
          CardIcon.passive(id, level, size: 36),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AshColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AshColors.gold.withValues(alpha: 0.5)),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              '은총 $graces',
              key: const Key('build-strip-graces'),
              style: const TextStyle(
                color: AshColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return strip;
    return Semantics(
      button: true,
      label: '카드 · 은총 자세히 보기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: strip,
      ),
    );
  }
}

/// 무기 · 패시브 카드 아이콘 하나와 레벨 딱지.
class CardIcon extends StatelessWidget {
  CardIcon.weapon(
    WeaponId id,
    this.level, {
    super.key,
    this.awakened = false,
    this.size = 44,
  }) : sheet = 'skills',
       index = id.index,
       maxLevel = WeaponId.maxLevel;

  CardIcon.passive(PassiveId id, this.level, {super.key, this.size = 44})
    : sheet = 'passives',
      index = id.index,
      maxLevel = PassiveId.maxLevel,
      awakened = false;

  final String sheet;
  final int index;
  final int level;
  final int maxLevel;
  final bool awakened;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = awakened || level >= maxLevel;
    final accent = awakened
        ? AshColors.ember
        : full
        ? AshColors.gold
        : AshColors.ash;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accent.withValues(alpha: 0.6),
                  width: awakened ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: PixelSprite(
                asset: 'assets/images/sprites/items/$sheet.png',
                frameSize: const Size(16, 16),
                start: index,
                // 도트가 고르게 보이도록 정수 배율.
                scale: ((size - 4) / 16).floorToDouble(),
              ),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 0,
            child: Text(
              awakened
                  ? '★'
                  : full
                  ? 'MAX'
                  : '$level',
              style: TextStyle(
                color: full ? accent : AshColors.parchment,
                fontSize: size < 40 ? 10 : 11,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
