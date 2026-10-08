import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../game/ashborn_game.dart';
import '../hud/hud.dart';
import '../../data/stages.dart';
import '../profile_scope.dart';
import '../overlays/equipment_overlay.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/level_up_overlay.dart';
import '../overlays/settings_overlay.dart';
import '../overlays/stage_clear_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.character,
    this.stage = Stage.first,
  });

  final CharacterDef character;
  final Stage stage;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final _game = AshbornGame(
    character: widget.character,
    profile: ProfileScope.of(context),
    startStage: widget.stage,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          AshbornGame.equipmentOverlay: (context, game) =>
              EquipmentOverlay(game: game),
          AshbornGame.settingsOverlay: (context, game) =>
              SettingsOverlay(game: game),
          AshbornGame.stageClearOverlay: (context, game) => StageClearOverlay(
            game: game,
            onReturn: () => Navigator.of(context).pop(),
          ),
        },
        initialActiveOverlays: const [AshbornGame.hudOverlay],
      ),
    );
  }
}
