import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/characters.dart';
import 'run_stats.dart';
import 'world/run_world.dart';

/// Ashborn 게임 루트. 런 하나가 [RunWorld] 하나에 대응한다.
class AshbornGame extends FlameGame<RunWorld>
    with HasKeyboardHandlerComponents {
  AshbornGame({required this.character}) : super(world: RunWorld(character)) {
    camera.viewport.add(joystick);
  }

  static const hudOverlay = 'hud';
  static const gameOverOverlay = 'gameOver';

  /// 화면 짧은 변에 보이는 월드 크기. 기기 해상도와 상관없이 시야를 고정한다.
  static const double viewShortSide = 540;

  final CharacterDef character;
  final stats = RunStats();

  final joystick = JoystickComponent(
    knob: CircleComponent(
      radius: 24,
      paint: Paint()..color = const Color(0xCCFF6B35),
    ),
    background: CircleComponent(
      radius: 60,
      paint: Paint()..color = const Color(0x33FFFFFF),
    ),
    margin: const EdgeInsets.only(left: 48, bottom: 48),
  );

  @override
  Color backgroundColor() => const Color(0xFF1A1414);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.zoom = math.min(size.x, size.y) / viewShortSide;
  }

  void onPlayerDied() {
    pauseEngine();
    overlays.add(gameOverOverlay);
  }

  void restart() {
    overlays.remove(gameOverOverlay);
    world = RunWorld(character);
    resumeEngine();
  }
}
