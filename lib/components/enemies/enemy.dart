import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../game/world/run_world.dart';
import 'death_puff.dart';

/// 재의 무리(Hollow). 플레이어를 향해 곧장 걸어온다.
class Enemy extends CircleComponent with HasWorldReference<RunWorld> {
  Enemy({required super.position, required this.maxHp})
    : hp = maxHp,
      super(
        radius: Balance.enemyRadius,
        anchor: Anchor.center,
        paint: Paint()..color = baseColor,
      );

  static const baseColor = Color(0xFF8A7F7A);
  static const flashColor = Color(0xFFFFFFFF);

  final double maxHp;
  double hp;
  final double speed = Balance.enemySpeed;
  final double contactDamage = Balance.enemyContactDamage;

  /// [CrowdSystem] 이 매 프레임 채워 주는 밀어내기 속도.
  final separation = Vector2.zero();

  final _velocity = Vector2.zero();
  double _flash = 0;
  bool _dead = false;

  bool get isDead => _dead;

  @override
  Future<void> onLoad() async {
    // 적끼리는 충돌 검사하지 않도록 passive 로 둔다.
    // isSolid: 빠른 투사체가 한 프레임에 원 안으로 들어와도 맞은 것으로 친다.
    add(CircleHitbox(collisionType: CollisionType.passive, isSolid: true));
  }

  @override
  void onMount() {
    super.onMount();
    world.enemies.add(this);
  }

  @override
  void onRemove() {
    world.enemies.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _velocity
      ..setFrom(world.player.position)
      ..sub(position);
    if (_velocity.length2 > 1) {
      _velocity
        ..normalize()
        ..scale(speed);
    }
    _velocity.add(separation);
    position.addScaled(_velocity, dt);

    if (_flash > 0) {
      _flash -= dt;
      paint.color = _flash > 0 ? flashColor : baseColor;
    }
  }

  void takeDamage(double amount) {
    if (_dead) return;
    hp -= amount;
    _flash = 0.08;
    paint.color = flashColor;
    if (hp <= 0) _die();
  }

  void _die() {
    _dead = true;
    world
      ..add(DeathPuff(position: position.clone()))
      ..onEnemyKilled(position.clone());
    removeFromParent();
  }
}
