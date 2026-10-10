import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../enemies/enemy.dart';

/// 부술 수 있는 상자. 움직이지도 때리지도 않는 적으로 다뤄 무기가 알아서 겨누고 부순다.
/// 부서지면 처치 보상 대신 보급품이 나온다 ([RunWorld.breakCrate]).
/// [chest] 면 더 단단하고 레어 이상 장비가 나오는 보물 상자다.
class Crate extends Enemy {
  Crate({required super.position, required super.maxHp, this.chest = false})
    : super(
        contactDamage: 0,
        speed: 0,
        radius: Balance.crateRadius,
        color: chest ? const Color(0xFFE0A030) : const Color(0xFF8A5A34),
      );

  final bool chest;

  static final _shadow = Paint()..color = const Color(0x55000000);

  /// 살아 있지 않아 타거나 얼거나 중독되지 않는다.
  @override
  bool get ailmentImmune => true;

  @override
  void onKilled() => world.breakCrate(this);

  @override
  void render(Canvas canvas) {
    final props = world.game.props;
    final sprite = chest ? props.chest : props.crate;
    if (sprite == null) {
      super.render(canvas);
      return;
    }
    // 바닥 가운데에 맞춰 원본 픽셀을 캐릭터와 같은 배율로 키운다.
    final w = sprite.srcSize.x * Balance.playerSpriteScale;
    final h = sprite.srcSize.y * Balance.playerSpriteScale;
    final feet = radius * 2 + 4;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(radius, feet - 2),
        width: w * 0.9,
        height: radius * 0.6,
      ),
      _shadow,
    );
    sprite.render(
      canvas,
      position: Vector2(radius - w / 2, feet - h),
      size: Vector2(w, h),
      overridePaint: spritePaint,
    );
  }
}
