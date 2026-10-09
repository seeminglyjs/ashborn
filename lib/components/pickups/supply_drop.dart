import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/supplies.dart';
import 'pickup.dart';

/// 상자에서 나온 소모품. 살짝 떠오르며 빛나 눈에 띈다.
/// 회복 물약은 체력이 가득 차 있으면 줍지 않고 바닥에 남겨 둔다.
class SupplyDrop extends Pickup {
  SupplyDrop({required super.position, required this.supply, this.amount = 1})
    : super(size: Vector2.all(16 * Balance.playerSpriteScale));

  final Supply supply;

  /// 골드 · 강화석 수량.
  final int amount;

  double _time = 0;

  static final _glow = Paint()..color = const Color(0x33FFE6A0);

  @override
  bool get collectable =>
      supply != Supply.potion || world.player.hp < world.player.maxHp;

  @override
  void collect() => world.collectSupply(supply, amount);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final bob = math.sin(_time * 4) * 2;
    canvas.drawCircle(Offset(w / 2, w / 2 + 4), w * 0.45, _glow);
    final sprite = world.game.props.supply(supply);
    if (sprite == null) {
      canvas.drawCircle(
        Offset(w / 2, w / 2),
        w / 4,
        Paint()..color = const Color(0xFFE8463A),
      );
      return;
    }
    sprite.render(canvas, position: Vector2(0, bob), size: size);
  }
}
