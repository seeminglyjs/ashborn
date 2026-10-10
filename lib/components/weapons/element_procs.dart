import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../game/world/run_world.dart';
import '../effects/pixel_fx.dart';
import 'projectile.dart';
import 'weapon_art.dart';

/// 얼어 있던 적이 쓰러지며 튀는 얼음 파편. 맞은 적에게 냉기 피해 (다시 쌓여 얼 수 있다).
class IceShard extends Projectile {
  IceShard({
    required super.position,
    required super.direction,
    required super.damage,
  }) : super(
         type: DamageType.cold,
         speed: Balance.shardSpeed,
         lifetime: Balance.shardLifetime,
         size: Vector2(14, 6),
         secondary: true,
       );

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  /// 도트 얼음 파편: 뾰족한 결정과 뒤로 흩어지는 서리 가루.
  @override
  void render(Canvas canvas) {
    canvas
      ..save()
      ..translate(0, size.y / 2);
    iceShardArt.draw(
      canvas,
      pivot: Offset(0, iceShardArt.height / 2),
      scale: size.x / iceShardArt.width,
    );
    canvas.restore();
  }
}

/// 바람 검기: 일직선으로 날아가며 닿는 적을 모두 벤다.
class WindSlash extends Projectile {
  WindSlash({
    required super.position,
    required super.direction,
    required super.damage,
  }) : super(
         type: DamageType.wind,
         speed: Balance.windSlashSpeed,
         lifetime: Balance.windSlashLifetime,
         size: Vector2(18, 34),
         pierce: 999,
         secondary: true,
       );

  double _age = 0;

  static const _wind = [
    Pal.white,
    Color(0xFF9CF0C0),
    Color(0xFF63C74D),
    Color(0xFF3E8948),
  ];

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
  }

  /// 진행 방향(오른쪽)으로 볼록한 도트 초승달 바람 날.
  @override
  void render(Canvas canvas) {
    final t = (_age / Balance.windSlashLifetime).clamp(0.0, 1.0);
    final pc = PixelCanvas.fine;
    PixelFx.arc(
      pc,
      size.y * 0.3,
      size.y * 0.55,
      -math.pi / 2.3,
      math.pi / 1.15,
      _wind,
      thin: PixelFx.fade(t, from: 0.7),
    );
    canvas
      ..save()
      ..translate(-size.y * 0.15, size.y / 2);
    pc.flush(canvas);
    canvas.restore();
  }
}

/// 소용돌이: 자리에 [Balance.vortexDuration] 초 머물며 둘레 적을 끌어당기고 계속 벤다.
class Vortex extends PositionComponent with HasWorldReference<RunWorld> {
  Vortex({required super.position, required this.damage})
    : super(priority: 6, anchor: Anchor.center);

  /// 한 번 칠 때의 바람 피해.
  final double damage;
  double _age = 0;
  double _tick = 0;

  @override
  void update(double dt) {
    _age += dt;
    _tick -= dt;
    const r = Balance.vortexRadius;
    for (final enemy in world.enemiesNear(position, r)) {
      final pull = position - enemy.position;
      if (pull.length2 > 16) {
        enemy.position.addScaled(pull.normalized(), Balance.vortexPull * dt);
      }
    }
    if (_tick <= 0) {
      _tick = Balance.vortexTick;
      for (final enemy in world.enemiesNear(position, r)) {
        world.player.strike(enemy, damage, DamageType.wind, secondary: true);
      }
    }
    if (_age >= Balance.vortexDuration) removeFromParent();
  }

  /// 도트 소용돌이: 안쪽으로 감겨 드는 바람 가닥 넷이 돌고, 가운데는 하얗게 빛난다.
  @override
  void render(Canvas canvas) {
    const r = Balance.vortexRadius;
    final grow = math.min(1.0, _age / 0.2);
    final left = (Balance.vortexDuration - _age) / 0.3;
    final thin = left >= 1 ? 0 : PixelFx.fade(1 - left, from: 0);
    final pc = PixelCanvas.fine;
    PixelFx.glow(
      canvas,
      Offset.zero,
      r * grow,
      const Color(0xFF9CF0C0),
      strength: 0.3,
    );
    for (var k = 0; k < 4; k++) {
      final spin = _age * 9 + k * math.pi / 2;
      for (var ring = 0; ring < 3; ring++) {
        final radius = r * grow * (0.35 + 0.3 * ring);
        PixelFx.arc(
          pc,
          radius - 4,
          radius,
          spin - ring * 0.6,
          0.9,
          ring == 0
              ? const [Pal.white, Color(0xFF9CF0C0)]
              : const [Color(0xFF9CF0C0), Color(0xFF63C74D)],
          thin: thin,
        );
      }
    }
    pc.flush(canvas);
  }
}
