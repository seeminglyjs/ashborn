import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../game/world/run_world.dart';

/// 바닥에 떨어진 아이템. 플레이어 자석 범위에 들어오면 끌려가 먹힌다.
abstract class Pickup extends PositionComponent
    with HasWorldReference<RunWorld> {
  Pickup({required super.position, required super.size})
    : super(anchor: Anchor.center, priority: 5);

  bool _attracted = false;
  final _toPlayer = Vector2.zero();

  /// false 면 끌려오지 않고 바닥에 남는다.
  bool get collectable => true;

  /// 플레이어에게 닿았을 때.
  void collect();

  /// [collectable] 이 아닌데 플레이어가 닿았을 때.
  void onBlocked() {}

  @override
  void update(double dt) {
    super.update(dt);
    final player = world.player;
    _toPlayer
      ..setFrom(player.position)
      ..sub(position);
    final distance = _toPlayer.length;
    if (!collectable) {
      _attracted = false;
      if (distance <= Balance.playerRadius) onBlocked();
      return;
    }
    if (distance <= Balance.playerRadius) {
      collect();
      removeFromParent();
      return;
    }
    // 한 번 끌려오기 시작하면 범위를 벗어나도 끝까지 따라간다.
    if (!_attracted && distance <= player.magnetRange) _attracted = true;
    if (!_attracted) return;
    final step = Balance.pickupSpeed * dt;
    if (step >= distance) {
      position.setFrom(player.position);
    } else {
      position.addScaled(_toPlayer, step / distance);
    }
  }
}
