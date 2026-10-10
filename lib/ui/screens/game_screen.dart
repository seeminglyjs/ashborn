import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../game/ashborn_game.dart';
import '../../services/audio.dart';
import '../hud/hud.dart';
import '../../data/run_save.dart';
import '../../data/stages.dart';
import '../profile_scope.dart';
import '../overlays/build_overlay.dart';
import '../overlays/equipment_overlay.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/level_up_overlay.dart';
import '../overlays/pause_overlay.dart';
import '../overlays/settings_overlay.dart';
import '../overlays/stage_clear_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.character,
    this.stage = Stage.first,
    this.resume,
  });

  final CharacterDef character;
  final Stage stage;

  /// 이어 하는 런. 있으면 [stage] 대신 그 기록의 스테이지에서 시작한다.
  final RunSave? resume;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final _game = AshbornGame(
    character: widget.character,
    profile: ProfileScope.of(context),
    startStage: widget.stage,
    resume: widget.resume,
  );

  @override
  void dispose() {
    // 멈춘 채로 나가면 줄인 배경음이 다음 화면까지 이어지지 않게 한다.
    GameAudio.duck(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 뒤로 가기로 바로 나가지 않고 일시정지 메뉴를 연다 (떠 있으면 닫는다).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _game.handleBack();
      },
      child: Scaffold(
        body: GameWidget<AshbornGame>(
          game: _game,
          overlayBuilderMap: {
            AshbornGame.hudOverlay: (context, game) => Hud(game: game),
            AshbornGame.gameOverOverlay: (context, game) => GameOverOverlay(
              game: game,
              onChooseCharacter: () => Navigator.of(context).pop(),
            ),
            AshbornGame.levelUpOverlay: (context, game) =>
                LevelUpOverlay(game: game),
            AshbornGame.pauseOverlay: (context, game) => PauseOverlay(
              game: game,
              // 런을 끝내면 캐릭터 선택으로 돌아가 바로 다시 출정할 수 있게 한다.
              onQuit: () {
                game.quitRun();
                Navigator.of(context).pop();
              },
            ),
            AshbornGame.equipmentOverlay: (context, game) =>
                EquipmentOverlay(game: game),
            AshbornGame.settingsOverlay: (context, game) =>
                SettingsOverlay(game: game),
            AshbornGame.buildOverlay: (context, game) =>
                BuildOverlay(game: game),
            AshbornGame.stageClearOverlay: (context, game) => StageClearOverlay(
              game: game,
              onReturn: () {
                game.returnToHearth();
                Navigator.of(context).pop();
              },
            ),
          },
          initialActiveOverlays: const [AshbornGame.hudOverlay],
        ),
      ),
    );
  }
}
