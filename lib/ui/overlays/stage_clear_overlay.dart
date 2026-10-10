import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/card_row.dart';
import '../widgets/fate_card.dart';

/// 보스를 잡은 뒤: 다음 지역으로 가거나 화톳불로 돌아간다. 마지막 지역이면 단계 클리어로 런이
/// 끝나 화톳불로 돌아가는 것만 남는다 (처음 클리어하면 다음 타락 단계가 열린다).
///
/// 이 스테이지를 처음 클리어했으면 신의 은총을 하나 골라야 떠날 수 있다. 고른 은총은 영구히
/// 남아 모든 런에 붙고, 한 스테이지에 한 번뿐이라 다시 깨면 카드가 나오지 않는다.
/// 은총 카드는 위에서 아래로 쌓고, 많아도 한 화면에 모두 보이게 한다.
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
      child: SafeArea(
        child: FitOneScreen(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: ListenableBuilder(
            listenable: Listenable.merge([game.fateOptions, game.chosenFate]),
            builder: (context, _) {
              final fates = game.fateOptions.value;
              final chosen = game.chosenFate.value;
              final canLeave = game.canLeaveClear;
              final conquest = stage.isFinal;
              final levelClear = stage.corruption == 0
                  ? '모든 지역 클리어!'
                  : '타락 ${stage.corruption}단계 클리어!';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conquest ? levelClear : '${stage.region.bossName} 처치',
                    key: const Key('clear-title'),
                    style: ashTitleStyle(24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conquest
                        ? '${stage.region.bossName} 처치'
                        : '${stage.name} 클리어 · 다음: ${next.name} (Lv ${next.level})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AshColors.gold, fontSize: 13),
                  ),
                  if (conquest && game.world.unlockedCorruption)
                    Text(
                      '타락 ${stage.corruption + 1}단계가 열렸습니다: 적과 보상이 강해집니다',
                      key: const Key('corruption-unlocked'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AshColors.ember,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (fates.isEmpty)
                    const Text(
                      '이 지역의 은총은 이미 받았습니다',
                      key: Key('grace-already-taken'),
                      style: TextStyle(color: AshColors.ash, fontSize: 13),
                    )
                  else if (chosen != null) ...[
                    Text('신의 은총을 받았습니다', style: ashTitleStyle(17)),
                    const SizedBox(height: 10),
                    FateCardView(key: const Key('chosen-fate'), fate: chosen),
                  ] else ...[
                    Text('신의 은총을 하나 고르세요', style: ashTitleStyle(17)),
                    const SizedBox(height: 2),
                    const Text(
                      '고른 은총은 영구히 남아 모든 캐릭터에 붙습니다',
                      style: TextStyle(color: AshColors.ash, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    CardColumn(
                      count: fates.length,
                      itemBuilder: (context, i) => FateCardView(
                        key: Key('fate-$i'),
                        fate: fates[i],
                        onTap: () => game.chooseFate(fates[i]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AshButton(
                      key: const Key('reroll-fate'),
                      label: '다시 뽑기 (${game.fateRerolls})',
                      fontSize: 14,
                      onPressed: game.fateRerolls > 0 ? game.rerollFate : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!conquest)
                        AshButton(
                          key: const Key('next-stage'),
                          label: '다음 지역으로',
                          fontSize: 14,
                          onPressed: canLeave ? game.continueToNextStage : null,
                        ),
                      AshButton(
                        key: const Key('return-to-hearth'),
                        label: '화톳불로 귀환',
                        fontSize: 14,
                        onPressed: canLeave ? onReturn : null,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
