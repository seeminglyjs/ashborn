import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.game,
    required this.onChooseCharacter,
  });

  final AshbornGame game;
  final VoidCallback onChooseCharacter;

  @override
  Widget build(BuildContext context) {
    final stats = game.stats;
    const statStyle = TextStyle(color: AshColors.parchment, fontSize: 16);
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('재가 되었다', style: ashTitleStyle(34)),
              const SizedBox(height: 4),
              Text(
                game.character.name,
                style: const TextStyle(color: AshColors.ash, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Text(
                '생존 시간  ${formatTime(stats.elapsedSeconds.value)}',
                style: statStyle,
              ),
              const SizedBox(height: 6),
              Text('처치  ${stats.kills.value}', style: statStyle),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  AshButton(
                    label: '다시 일어서기',
                    icon: Icons.local_fire_department,
                    fontSize: 17,
                    onPressed: game.restart,
                  ),
                  AshButton(
                    label: '캐릭터 선택',
                    fontSize: 17,
                    onPressed: onChooseCharacter,
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
