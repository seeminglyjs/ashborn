import 'package:flutter/material.dart';

import '../../data/balance.dart';
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
              Text(
                game.world.timedOut ? '시간 초과' : '재가 되었다',
                style: ashTitleStyle(34),
              ),
              if (game.world.timedOut)
                Text(
                  '${formatTime(Balance.bossTimeLimit.toInt())} 안에 '
                  '${game.world.stage.region.bossName}을(를) 쓰러뜨리지 못했다',
                  style: const TextStyle(color: AshColors.ember, fontSize: 13),
                ),
              const SizedBox(height: 4),
              Text(
                '${game.character.name} · ${game.world.stage.name} '
                '(Lv ${game.world.stage.level})',
                style: const TextStyle(color: AshColors.ash, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Text(
                '생존 시간  ${formatTime(stats.elapsedSeconds.value)}',
                style: statStyle,
              ),
              const SizedBox(height: 6),
              Text('처치  ${stats.kills.value}', style: statStyle),
              const SizedBox(height: 6),
              Text('잔불  +${game.world.runEmber}', style: statStyle),
              const SizedBox(height: 6),
              Text(
                '골드  +${game.world.runGold} · 강화석  +${game.world.runStones}'
                '${game.world.runTranscendStones > 0 ? ' · 초월석  +${game.world.runTranscendStones}' : ''}',
                style: statStyle,
              ),
              const SizedBox(height: 4),
              Text(
                '보유 잔불 ${game.inventory.ember} · 화톳불에서 영구 강화에 쓸 수 있다',
                style: const TextStyle(color: AshColors.ash, fontSize: 12),
              ),
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
                    // 쓰러진 스테이지부터 다시.
                    onPressed: () => game.restart(stage: game.world.stage),
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
