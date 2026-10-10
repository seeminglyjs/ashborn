import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/build_strip.dart';

/// 전투 중 일시정지 메뉴. 여는 동안 게임은 멈추고 '계속하기'로만 다시 돈다.
/// 이번 런의 카드 · 은총을 아이콘으로 한눈에 보이고, 누르면 자세히 본다.
/// 장비 · 설정 · 카드 화면을 열었다 닫으면 이 메뉴로 돌아온다.
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
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: BuildStrip(
                    key: const Key('pause-build-strip'),
                    player: game.world.player,
                    graces: game.progress.graceRecords.length,
                    onTap: game.openBuild,
                  ),
                ),
                const SizedBox(height: 24),
                for (final (key, label, onPressed) in [
                  ('pause-resume', '계속하기', game.resumeFromPause),
                  ('pause-build', '카드 · 은총', game.openBuild),
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
  /// 보스를 잡은 뒤면 이어 할 수 있고, 싸우는 도중이면 포기로 끝나 레벨 · 카드가 사라진다.
  Future<void> _confirmQuit(BuildContext context) async {
    final keep =
        '보스를 잡았으니 다음에 ${game.world.stage.next.name}부터 '
        '지금 레벨과 무기 · 패시브 카드로 이어 할 수 있다.';
    const abandon =
        '싸우는 도중에 나가면 이번 런은 포기로 끝나 레벨과 무기 · 패시브 카드가 사라진다. '
        '이어 하려면 보스를 잡고 클리어 화면에서 화톳불로 돌아가라.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AshColors.panel,
        title: const Text('런을 끝낼까?', style: TextStyle(color: AshColors.gold)),
        content: Text(
          '${game.canKeepRun ? keep : abandon}\n'
          '지금까지 모은 잔불 · 골드 · 강화석은 정산되어 남고, '
          '주운 장비와 받은 은총도 그대로 있다.',
          key: const Key('quit-message'),
          style: const TextStyle(color: AshColors.parchment, height: 1.4),
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
