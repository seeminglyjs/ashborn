import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../game/ashborn_game.dart';
import '../hud/hud.dart';
import '../inventory_scope.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/level_up_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.character});

  final CharacterDef character;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final _game = AshbornGame(
    character: widget.character,
    inventory: InventoryScope.of(context),
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
        },
        initialActiveOverlays: const [AshbornGame.hudOverlay],
      ),
    );
  }
}
