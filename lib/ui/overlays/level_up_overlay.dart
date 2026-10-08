import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../../systems/level_system.dart';
import '../theme.dart';

/// 레벨업 때 무기 또는 패시브 한 장을 고른다. 고르는 동안 게임은 멈춘다.
class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({super.key, required this.game});

  final AshbornGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('레벨 업', style: ashTitleStyle(30)),
                const SizedBox(height: 16),
                ValueListenableBuilder(
                  valueListenable: game.levelUpOptions,
                  builder: (context, options, _) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (i, option) in options.indexed)
                        _OptionCard(
                          key: Key('level-up-$i'),
                          option: option,
                          onTap: () => game.chooseLevelUp(option),
                        ),
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
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({super.key, required this.option, required this.onTap});

  final LevelUpOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (kind, icon) = switch (option) {
      WeaponOption() => ('무기', Icons.whatshot),
      AwakenOption() => ('무기', Icons.bolt),
      PassiveOption() => ('패시브', Icons.auto_awesome),
    };
    final awaken = option is AwakenOption;
    final isNew = option.level == 1;
    final accent = awaken || isNew ? AshColors.ember : AshColors.gold;
    return Semantics(
      button: true,
      label: option.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AshColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent, width: awaken ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AshColors.ember),
                  const SizedBox(width: 6),
                  Text(
                    kind,
                    style: const TextStyle(color: AshColors.ash, fontSize: 12),
                  ),
                  const Spacer(),
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                option.title,
                style: const TextStyle(
                  color: AshColors.parchment,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.description,
                style: const TextStyle(color: AshColors.ash, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
