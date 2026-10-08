import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/characters.dart';
import '../data/equipment.dart';
import '../data/fates.dart';
import '../data/inventory.dart';
import '../data/profile.dart';
import '../data/progress.dart';
import '../data/settings.dart';
import '../data/stages.dart';
import '../data/upgrades.dart';
import '../systems/fate_system.dart';
import '../systems/level_system.dart';
import 'notices.dart';
import 'run_stats.dart';
import 'world/run_world.dart';

/// Ashborn 게임 루트. 런 하나가 [RunWorld] 하나에 대응한다.
class AshbornGame extends FlameGame<RunWorld>
    with HasKeyboardHandlerComponents {
  AshbornGame({
    required this.character,
    required this.profile,
    this.startStage = Stage.first,
  }) : super(world: RunWorld(character, stage: startStage)) {
    camera.viewport.add(joystick);
  }

  static const hudOverlay = 'hud';
  static const gameOverOverlay = 'gameOver';
  static const levelUpOverlay = 'levelUp';
  static const equipmentOverlay = 'equipment';
  static const stageClearOverlay = 'stageClear';
  static const settingsOverlay = 'settings';

  /// 화면 짧은 변에 보이는 월드 크기. 기기 해상도와 상관없이 시야를 고정한다.
  static const double viewShortSide = 540;

  final CharacterDef character;

  /// 이 런을 시작한 스테이지.
  final Stage startStage;

  /// 런이 끝나도 유지되는 기록.
  final Profile profile;

  Inventory get inventory => profile.inventory;
  Progress get progress => profile.progress;
  Settings get settings => profile.settings;
  Upgrades get upgrades => profile.upgrades;

  /// 이 캐릭터가 낀 장비.
  late final gear = inventory.gear(character.id);
  final stats = RunStats();
  final notices = Notices();
  final random = math.Random();

  /// 레벨업 오버레이에 보여 줄 선택지.
  final levelUpOptions = ValueNotifier<List<LevelUpOption>>(const []);
  int _pendingLevelUps = 0;

  /// 스테이지 클리어 때 고를 운명 카드.
  final fateOptions = ValueNotifier<List<Fate>>(const []);

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
  Color backgroundColor() => world.stage.region.background;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.zoom = math.min(size.x, size.y) / viewShortSide;
  }

  /// 진행 알림. 설정에서 끌 수 있다.
  void notify(String text, {Color color = Colors.white}) {
    if (settings.eventNotices) notices.add(text, color);
  }

  /// 장비 획득 알림. 설정한 최소 등급 이상만.
  void notifyLoot(Item item, String text) {
    if (settings.showsLoot(item.rarity)) notices.add(text, item.rarity.color);
  }

  @override
  void update(double dt) {
    super.update(dt);
    notices.tick(dt);
  }

  void onPlayerDied() {
    world
      ..bankEmber()
      ..bankLoot();
    pauseEngine();
    overlays.add(gameOverOverlay);
  }

  /// 보스를 잡고 전리품을 주울 시간이 끝나면 운명 카드와 다음 지역 선택을 띄운다.
  void onStageCleared() {
    fateOptions.value = FateSystem.roll(world.player, random);
    if (overlays.add(stageClearOverlay)) pauseEngine();
  }

  void rerollFate() {
    final fate = world.fate;
    if (fate.rerolls <= 0) return;
    fate.rerolls--;
    fateOptions.value = FateSystem.roll(world.player, random);
  }

  /// 운명을 고르면 다음 지역으로 간다. 레벨업 같은 효과가 바로 이어지도록
  /// 게임을 다시 돌린 뒤에 적용한다.
  void chooseFate(Fate fate) {
    continueToNextStage();
    FateSystem.apply(fate, world);
    notify(
      '운명: ${fate.card.title} (${fate.rarity.label})',
      color: fate.rarity.color,
    );
  }

  void continueToNextStage() {
    world.advanceStage();
    if (overlays.remove(stageClearOverlay)) resumeEngine();
  }

  void openSettings() {
    if (overlays.add(settingsOverlay)) pauseEngine();
  }

  void closeSettings() {
    if (overlays.remove(settingsOverlay)) resumeEngine();
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

  /// [stage] 부터 새 런을 시작한다. 기본은 이 런을 시작한 스테이지.
  void restart({Stage? stage}) {
    _pendingLevelUps = 0;
    notices.clear();
    overlays.removeAll([
      gameOverOverlay,
      levelUpOverlay,
      equipmentOverlay,
      stageClearOverlay,
      settingsOverlay,
    ]);
    world = RunWorld(character, stage: stage ?? startStage);
    resumeEngine();
  }
}
