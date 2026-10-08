import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/equipment.dart';
import '../../game/ashborn_game.dart';
import 'pickup.dart';

/// 바닥에 떨어진 장비. 등급 색으로 빛나고, 높은 등급일수록 빛이 크다.
class ItemDrop extends Pickup with HasGameReference<AshbornGame> {
  ItemDrop({required super.position, required this.item})
    : super(size: Vector2.all(14));

  final Item item;

  late final _glow = Paint()..color = item.rarity.color.withValues(alpha: 0.3);
  late final _body = Paint()..color = item.rarity.color;

  @override
  bool collect() {
    game.inventory.add(item);
    return true;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final c = Offset(w / 2, w / 2);
    canvas
      ..drawCircle(c, w * (0.8 + 0.2 * item.rarity.index), _glow)
      ..drawRect(Rect.fromCenter(center: c, width: w, height: w), _body);
  }
}
