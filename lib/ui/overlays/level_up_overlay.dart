import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../../systems/level_system.dart';
import '../theme.dart';
import '../widgets/build_strip.dart';
import '../widgets/card_row.dart';
import '../widgets/pixel_sprite.dart';

/// 레벨업 때 무기 또는 패시브 한 장을 고른다. 고르는 동안 게임은 멈춘다.
/// 카드는 위에서 아래로 쌓고, 많아도 한 화면에 모두 보이게 한다. 아래에 지금 가진 카드를 보인다.
class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({super.key, required this.game});

  final AshbornGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: FitOneScreen(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('레벨 업', style: ashTitleStyle(28)),
              const SizedBox(height: 14),
              ValueListenableBuilder(
                valueListenable: game.levelUpOptions,
                builder: (context, options, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CardColumn(
                      count: options.length,
                      itemBuilder: (context, i) => _OptionCard(
                        key: Key('level-up-$i'),
                        option: options[i],
                        onTap: () => game.chooseLevelUp(options[i]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '지금 가진 카드',
                      style: TextStyle(color: AshColors.ash, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    BuildStrip(
                      key: const Key('level-up-build-strip'),
                      player: game.world.player,
                      graces: game.progress.graceRecords.length,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 가로형 카드: 왼쪽에 스킬 · 패시브 도트 아이콘, 오른쪽에 등급 · 종류 · 이름 · 효과.
class _OptionCard extends StatelessWidget {
  const _OptionCard({super.key, required this.option, required this.onTap});

  final LevelUpOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = switch (option) {
      WeaponOption(:final id) => id.owner == null ? '공용 무기' : '전용 무기',
      AwakenOption() => '무기 각성',
      PassiveOption() => '패시브',
    };
    final awaken = option is AwakenOption;
    final isNew = option.level == 1;
    final accent = awaken || isNew ? AshColors.ember : AshColors.gold;
    final (sheet, index) = switch (option) {
      WeaponOption(:final id) ||
      AwakenOption(:final id) => ('skills', id.index),
      PassiveOption(:final id) => ('passives', id.index),
    };
    return Semantics(
      button: true,
      label: option.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AshColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent, width: awaken ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: PixelSprite(
                  key: Key('level-up-icon-$sheet-$index'),
                  asset: 'assets/images/sprites/items/$sheet.png',
                  frameSize: const Size(16, 16),
                  start: index,
                  scale: 3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          awaken
                              ? '각성'
                              : isNew
                              ? 'NEW'
                              : 'Lv ${option.level}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          kind,
                          style: const TextStyle(
                            color: AshColors.ash,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    OneLineText(
                      option.title,
                      style: const TextStyle(
                        color: AshColors.parchment,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keepWords(option.description),
                      style: const TextStyle(
                        color: AshColors.ash,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
