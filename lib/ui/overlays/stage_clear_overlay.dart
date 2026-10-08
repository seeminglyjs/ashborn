import 'package:flutter/material.dart';

import '../../data/fates.dart';
import '../../game/ashborn_game.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

/// 보스를 잡은 뒤: 운명을 하나 골라 다음 지역으로 가거나, 화톳불로 돌아간다.
class StageClearOverlay extends StatelessWidget {
  const StageClearOverlay({
    super.key,
    required this.game,
    required this.onReturn,
  });

  final AshbornGame game;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final stage = game.world.stage;
    final next = stage.next;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${stage.region.bossName} 처치', style: ashTitleStyle(28)),
              const SizedBox(height: 6),
              Text(
                '${stage.name} 클리어',
                style: const TextStyle(
                  color: AshColors.parchment,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '다음: ${next.name} (Lv ${next.level})',
                style: const TextStyle(color: AshColors.gold, fontSize: 14),
              ),
              if (next.corruption > stage.corruption)
                Text(
                  '타락 ${next.corruption}단계: 적과 보상이 강해집니다',
                  style: const TextStyle(color: AshColors.ember, fontSize: 13),
                ),
              const SizedBox(height: 20),
              Text('운명을 하나 고르세요', style: ashTitleStyle(18)),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: game.fateOptions,
                builder: (context, cards, _) {
                  final rerolls = game.world.fate.rerolls;
                  return Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final (i, card) in cards.indexed)
                            _FateCardView(
                              key: Key('fate-$i'),
                              card: card,
                              onTap: () => game.chooseFate(card),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AshButton(
                        key: const Key('reroll-fate'),
                        label: '다시 뽑기 ($rerolls)',
                        icon: Icons.refresh,
                        fontSize: 15,
                        onPressed: rerolls > 0 ? game.rerollFate : null,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              AshButton(
                key: const Key('return-to-hearth'),
                label: '화톳불로 귀환',
                fontSize: 17,
                onPressed: onReturn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FateCardView extends StatelessWidget {
  const _FateCardView({super.key, required this.card, required this.onTap});

  final FateCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = card.tier.color;
    return Semantics(
      button: true,
      label: card.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AshColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.tier.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.title,
                style: const TextStyle(
                  color: AshColors.parchment,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.description,
                style: const TextStyle(color: AshColors.ash, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
