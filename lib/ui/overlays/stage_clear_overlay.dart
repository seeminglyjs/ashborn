import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

/// 보스를 잡은 뒤: 다음 지역으로 계속 갈지, 화톳불로 돌아갈지.
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
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  AshButton(
                    key: const Key('next-stage'),
                    label: '다음 지역으로',
                    icon: Icons.local_fire_department,
                    fontSize: 17,
                    onPressed: game.continueToNextStage,
                  ),
                  AshButton(
                    key: const Key('return-to-hearth'),
                    label: '화톳불로 귀환',
                    fontSize: 17,
                    onPressed: onReturn,
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
