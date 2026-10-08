import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import 'pickup.dart';

/// 재의 결정: 적이 떨어뜨리는 경험치.
class AshShard extends Pickup {
  AshShard({required super.position})
    : super(size: Vector2.all(Balance.ashShardSize));

  static final _glow = Paint()..color = const Color(0x449FD8E8);
  static final _body = Paint()..color = const Color(0xFF9FD8E8);

  @override
  bool collect() {
    world.gainXp(Balance.ashShardXp * world.player.xpMultiplier);
    return true;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    canvas
      ..drawCircle(Offset(w / 2, h / 2), w * 0.8, _glow)
      ..drawPath(
        Path()
          ..moveTo(w / 2, 0)
          ..lineTo(w, h / 2)
          ..lineTo(w / 2, h)
          ..lineTo(0, h / 2)
          ..close(),
        _body,
      );
  }
}
