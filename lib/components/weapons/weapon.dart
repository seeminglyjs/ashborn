import 'package:flame/components.dart';

import '../../game/world/run_world.dart';

/// 쿨다운마다 자동으로 발동하는 무기. 플레이어의 자식으로 붙는다.
abstract class Weapon extends Component with HasWorldReference<RunWorld> {
  Weapon({required this.baseCooldown});

  final double baseCooldown;
  double _charge = 0;

  double get cooldown =>
      baseCooldown * world.player.character.cooldownMultiplier;

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
