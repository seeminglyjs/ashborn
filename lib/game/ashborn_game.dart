import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/characters.dart';
import '../data/inventory.dart';
import '../systems/level_system.dart';
import 'notices.dart';
import 'run_stats.dart';
import 'world/run_world.dart';

/// Ashborn 게임 루트. 런 하나가 [RunWorld] 하나에 대응한다.
class AshbornGame extends FlameGame<RunWorld>
    with HasKeyboardHandlerComponents {
  AshbornGame({required this.character, required this.inventory})
    : super(world: RunWorld(character)) {
    camera.viewport.add(joystick);
  }

  static const hudOverlay = 'hud';
  static const gameOverOverlay = 'gameOver';
  static const levelUpOverlay = 'levelUp';
  static const equipmentOverlay = 'equipment';

  /// 화면 짧은 변에 보이는 월드 크기. 기기 해상도와 상관없이 시야를 고정한다.
  static const double viewShortSide = 540;

  final CharacterDef character;

  /// 런이 끝나도 유지되는 장비.
  final Inventory inventory;

  /// 이 캐릭터가 낀 장비.
  late final gear = inventory.gear(character.id);
  final stats = RunStats();
  final notices = Notices();
  final random = math.Random();

  /// 레벨업 오버레이에 보여 줄 선택지.
  final levelUpOptions = ValueNotifier<List<LevelUpOption>>(const []);
  int _pendingLevelUps = 0;

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

  void notify(String text, {Color color = Colors.white}) =>
      notices.add(text, color);

  @override
  void update(double dt) {
    super.update(dt);
    notices.tick(dt);
  }

  void onPlayerDied() {
    pauseEngine();
    overlays.add(gameOverOverlay);
  }

  void openEquipment() {
    if (overlays.add(equipmentOverlay)) pauseEngine();
  }

  void closeEquipment() {
    if (overlays.remove(equipmentOverlay)) resumeEngine();
  }

  /// 한꺼번에 여러 레벨이 오르면 한 장씩 차례로 고른다.
  void onLevelUp(int levels) {
    _pendingLevelUps += levels;
    if (!overlays.isActive(levelUpOverlay)) _offerLevelUp();
  }

  void chooseLevelUp(LevelUpOption option) {
    option.apply(world.player);
    _pendingLevelUps--;
    _offerLevelUp();
  }

  void _offerLevelUp() {
    final options = _pendingLevelUps > 0
        ? LevelSystem.roll(world.player, random)
        : const <LevelUpOption>[];
    levelUpOptions.value = options;
    if (options.isEmpty) {
      // 모두 최대 레벨이면 고를 것이 없으니 넘어간다.
      _pendingLevelUps = 0;
      if (overlays.remove(levelUpOverlay)) resumeEngine();
      return;
    }
    if (overlays.add(levelUpOverlay)) pauseEngine();
  }

  void restart() {
    _pendingLevelUps = 0;
    notices.clear();
    overlays.removeAll([gameOverOverlay, levelUpOverlay, equipmentOverlay]);
    world = RunWorld(character);
    resumeEngine();
  }
}
