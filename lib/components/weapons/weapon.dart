import 'package:flame/components.dart';

import '../../data/weapons.dart';
import '../../game/world/run_world.dart';

/// 플레이어가 지닌 무기. 레벨업 선택으로 강해진다.
mixin LeveledWeapon on HasWorldReference<RunWorld> {
  WeaponId get id;

  int _level = 1;
  int get level => _level;

  bool get isMaxLevel => _level >= WeaponId.maxLevel;

  void levelUp() {
    _level++;
    onLevelChanged();
  }

  void onLevelChanged() {}

  /// 무기 레벨에 따른 피해 배율. 장비와 패시브는 [Player.strike] 가 더한다.
  double get damageMultiplier => WeaponId.damageMultiplier(_level);

  int get bonusCount => id.bonusCount(_level);
}

/// 쿨다운마다 자동으로 발동하는 무기. 플레이어의 자식으로 붙는다.
abstract class Weapon extends Component
    with HasWorldReference<RunWorld>, LeveledWeapon {
  Weapon({required this.baseCooldown});

  final double baseCooldown;
  double _charge = 0;

  double get cooldown =>
      baseCooldown *
      world.player.character.cooldownMultiplier /
      world.player.attackSpeedMultiplier;

  @override
  void update(double dt) {
    super.update(dt);
    if (_charge < cooldown) _charge += dt;
    // 쏠 대상이 없으면 충전된 상태로 기다렸다가 적이 나타나면 바로 쏜다.
    if (_charge >= cooldown && fire()) _charge = 0;
  }

  /// 실제로 발동했으면 true.
  bool fire();
}
