import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/equipment.dart';
import '../../game/ashborn_game.dart';
import 'pickup.dart';

/// 바닥에 떨어진 장비. 부위 아이콘이 등급 색으로 빛나고, 높은 등급일수록 빛이 크다.
class ItemDrop extends Pickup with HasGameReference<AshbornGame> {
  ItemDrop({required super.position, required this.item})
    : super(size: Vector2.all(16 * Balance.playerSpriteScale));

  final Item item;

  late final _glow = Paint()..color = item.rarity.color.withValues(alpha: 0.3);
  late final _body = Paint()..color = item.rarity.color;

  @override
  bool get collectable => game.gear.canAdd(item);

  @override
  void collect() {
    final slot = game.gear.add(item);
    game.notifyLoot(item, '${item.name} 획득${slot == null ? '' : ' · 장착'}');
  }

  @override
  void onBlocked() =>
      game.notify('가방이 가득 찼습니다', color: const Color(0xFFFF6B35));

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final c = Offset(w / 2, w / 2);
    canvas.drawCircle(c, w * (0.35 + 0.1 * item.rarity.index), _glow);
    final sprite = game.props.gear(item.type);
    if (sprite == null) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w / 2, height: w / 2),
        _body,
      );
      return;
    }
    // 등급 색 받침 위에 아이콘이 둥실 떠 있다.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, w - 3), width: w * 0.7, height: 6),
      _body,
    );
    sprite.render(
      canvas,
      position: Vector2(0, math.sin(_time * 4) * 2 - 3),
      size: size,
    );
  }
}
