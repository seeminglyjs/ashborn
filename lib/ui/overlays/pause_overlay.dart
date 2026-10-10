import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';

/// 전투 중 일시정지 메뉴. 여는 동안 게임은 멈추고 '계속하기'로만 다시 돈다.
/// 장비 · 설정을 열었다 닫으면 이 메뉴로 돌아온다.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game, required this.onQuit});

  final AshbornGame game;

  /// 런을 끝내기로 확인했을 때. 정산은 [AshbornGame.quitRun] 이 한다.
  final VoidCallback onQuit;

  static const double _buttonWidth = 240;

  @override
  Widget build(BuildContext context) {
    final stats = game.stats;
    final stage = game.world.stage;
    const statStyle = TextStyle(color: AshColors.parchment, fontSize: 15);
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('일시정지', style: ashTitleStyle(32)),
                const SizedBox(height: 6),
                Text(
                  '${game.character.name} · ${stage.name} (Lv ${stage.level})',
                  style: const TextStyle(color: AshColors.ash, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Text(
                  '경과 시간  ${formatTime(stats.elapsedSeconds.value)}'
                  '   ·   처치  ${stats.kills.value}'
                  '   ·   Lv ${stats.level.value}',
                  key: const Key('pause-status'),
                  style: statStyle,
                ),
                const SizedBox(height: 28),
                for (final (key, label, onPressed) in [
                  ('pause-resume', '계속하기', game.resumeFromPause),
                  ('pause-equipment', '장비', game.openEquipment),
                  ('pause-settings', '설정', game.openSettings),
                  ('pause-quit', '캐릭터 선택으로', () => _confirmQuit(context)),
                ]) ...[
                  SizedBox(
                    width: _buttonWidth,
                    child: AshButton(
                      key: Key(key),
                      label: label,
                      fontSize: 17,
                      onPressed: onPressed,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 런을 끝낼지 묻는다. 모은 재화는 정산된다는 걸 먼저 알려 준다.
  Future<void> _confirmQuit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AshColors.panel,
        title: const Text('런을 끝낼까?', style: TextStyle(color: AshColors.gold)),
        content: const Text(
          '메인 화면으로 돌아가면 이번 런은 여기서 끝난다.\n'
          '지금까지 모은 잔불 · 골드 · 강화석은 정산되어 남고, '
          '주운 장비도 가방에 그대로 있다.\n'
          '런 안에서 올린 레벨과 운명은 사라진다.',
          style: TextStyle(color: AshColors.parchment, height: 1.4),
        ),
        actions: [
          TextButton(
            key: const Key('cancel-quit'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 싸우기'),
          ),
          TextButton(
            key: const Key('confirm-quit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '런 끝내기',
              style: TextStyle(color: AshColors.ember),
            ),
          ),
        ],
      ),
    );
    if (ok == true) onQuit();
  }
}
