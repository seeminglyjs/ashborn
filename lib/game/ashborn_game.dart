import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/effects/hit_vignette.dart';
import '../components/enemies/monster_sprite_cache.dart';
import '../components/props/prop_sprites.dart';
import '../data/characters.dart';
import '../data/equipment.dart';
import '../data/fates.dart';
import '../data/inventory.dart';
import '../data/class_passives.dart';
import '../data/profile.dart';
import '../data/progress.dart';
import '../data/settings.dart';
import '../data/stages.dart';
import '../data/upgrades.dart';
import '../systems/fate_system.dart';
import '../systems/level_system.dart';
import 'floating_joystick.dart';
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
    camera.viewport.addAll([joystick, hitVignette]);
  }

  static const hudOverlay = 'hud';
  static const gameOverOverlay = 'gameOver';
  static const levelUpOverlay = 'levelUp';
  static const equipmentOverlay = 'equipment';
  static const stageClearOverlay = 'stageClear';
  static const settingsOverlay = 'settings';
  static const pauseOverlay = 'pause';

  /// 각자 게임을 멈추고 자기 버튼으로만 닫히는 화면. 떠 있는 동안 일시정지 메뉴를 열지 않는다.
  static const _blockingOverlays = [
    gameOverOverlay,
    levelUpOverlay,
    stageClearOverlay,
  ];

  /// 일시정지 메뉴와 거기서 여는 화면.
  static const _pauseMenuOverlays = [
    pauseOverlay,
    settingsOverlay,
    equipmentOverlay,
  ];

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
  Mastery get mastery => profile.mastery;

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

  final joystick = FloatingJoystick();

  /// 플레이어가 맞았을 때 붉어지는 화면 가장자리.
  final hitVignette = HitVignette();

  /// 적 · 보스 스프라이트 프레임. [RunWorld] 가 읽기 시작한다.
  final monsterSprites = MonsterSpriteCache();

  /// 상자 · 떨어진 장비 · 소모품 그림. [RunWorld] 가 읽기 시작한다.
  final props = PropSprites();

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
      ..bankLoot()
      ..bankMastery();
    pauseEngine();
    overlays.add(gameOverOverlay);
  }

  /// 보스를 제한 시간 안에 잡지 못하면 쓰러진 것과 같이 런이 끝난다.
  void onBossTimeout() => onPlayerDied();

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
      '신의 은총: ${fate.card.title} (${fate.rarity.label})',
      color: fate.rarity.color,
    );
  }

  void continueToNextStage() {
    world.advanceStage();
    if (overlays.remove(stageClearOverlay)) resumeEngine();
  }

  /// 일시정지 메뉴, 또는 거기서 연 설정 · 장비 화면이 떠 있다.
  bool get isPauseMenuOpen => _pauseMenuOverlays.any(overlays.isActive);

  /// 설정 · 장비 화면을 일시정지 메뉴에서 열었으면 닫을 때 메뉴로 돌아간다.
  bool _returnToPauseMenu = false;

  /// 게임을 멈추고 일시정지 메뉴를 연다. 레벨업 · 클리어 · 사망 화면이 떠 있거나
  /// 이미 메뉴가 열려 있으면 아무것도 하지 않고 false 를 돌려준다.
  bool openPauseMenu() {
    if (_blockingOverlays.any(overlays.isActive) || isPauseMenuOpen) {
      return false;
    }
    overlays.add(pauseOverlay);
    pauseEngine();
    return true;
  }

  /// 일시정지 메뉴(와 거기서 연 화면)를 닫고 게임을 다시 돌린다.
  void resumeFromPause() {
    _returnToPauseMenu = false;
    overlays.removeAll(_pauseMenuOverlays);
    if (!_blockingOverlays.any(overlays.isActive)) resumeEngine();
  }

  /// 안드로이드 뒤로 가기. 설정 · 장비는 닫고 일시정지 메뉴로, 일시정지 메뉴는
  /// 닫고 이어서 싸우고, 전투 중이면 일시정지 메뉴를 연다.
  void handleBack() {
    if (overlays.isActive(settingsOverlay)) {
      closeSettings();
    } else if (overlays.isActive(equipmentOverlay)) {
      closeEquipment();
    } else if (overlays.isActive(pauseOverlay)) {
      resumeFromPause();
    } else {
      openPauseMenu();
    }
  }

  /// 런을 여기서 끝낸다. 쓰러졌을 때처럼 처치로 모은 잔불 · 골드 · 강화석을
  /// 정산하고 게임을 멈춘다. 메인 화면으로 가는 화면 이동은 부르는 쪽이 한다.
  void quitRun() {
    world
      ..bankEmber()
      ..bankLoot()
      ..bankMastery();
    pauseEngine();
  }

  void openSettings() => _openFromPauseMenu(settingsOverlay);

  void closeSettings() => _closeToPauseMenu(settingsOverlay);

  void openEquipment() => _openFromPauseMenu(equipmentOverlay);

  void closeEquipment() => _closeToPauseMenu(equipmentOverlay);

  void _openFromPauseMenu(String overlay) {
    _returnToPauseMenu = overlays.remove(pauseOverlay);
    if (overlays.add(overlay)) pauseEngine();
  }

  /// 일시정지 메뉴에서 열었으면 메뉴로 돌아가고(게임은 계속 멈춤), 아니면 게임을 이어 간다.
  void _closeToPauseMenu(String overlay) {
    if (!overlays.remove(overlay)) return;
    if (_returnToPauseMenu) {
      _returnToPauseMenu = false;
      overlays.add(pauseOverlay);
    } else {
      resumeEngine();
    }
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
    _returnToPauseMenu = false;
    notices.clear();
    overlays.removeAll([
      gameOverOverlay,
      levelUpOverlay,
      equipmentOverlay,
      stageClearOverlay,
      settingsOverlay,
      pauseOverlay,
    ]);
    world = RunWorld(character, stage: stage ?? startStage);
    resumeEngine();
  }
}
