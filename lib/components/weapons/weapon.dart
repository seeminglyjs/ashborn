import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';

/// 플레이어가 지닌 무기. 레벨업 선택으로 강해진다.
mixin LeveledWeapon on HasWorldReference<RunWorld> {
  WeaponId get id;

  int _level = 1;
  int get level => _level;

  bool get isMaxLevel => _level >= WeaponId.maxLevel;

  bool _awakened = false;
  bool get awakened => _awakened;

  void levelUp() {
    _level++;
    onLevelChanged();
  }

  /// 최대 레벨 무기를 각성시킨다. 무기마다 [onLevelChanged] 에서 모양을 바꾼다.
  void awaken() {
    assert(isMaxLevel && !_awakened, '최대 레벨이고 아직 각성 전이어야 한다');
    _awakened = true;
    onLevelChanged();
  }

  void onLevelChanged() {}

  /// 무기 레벨과 각성에 따른 피해 배율. 장비와 패시브는 [Player.strike] 가 더한다.
  double get damageMultiplier =>
      WeaponId.damageMultiplier(_level) *
      (_awakened ? Balance.awakenDamageMultiplier : 1);

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
