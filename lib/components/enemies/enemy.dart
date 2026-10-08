import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../game/world/run_world.dart';
import 'ailments.dart';
import 'death_puff.dart';

/// 재의 무리(Hollow). 플레이어를 향해 곧장 걸어온다.
/// 지역에 따라 색, 속도, 닿았을 때 주는 피해의 속성이 다르다.
class Enemy extends CircleComponent with HasWorldReference<RunWorld> {
  Enemy({
    required super.position,
    required this.maxHp,
    this.contactDamage = Balance.enemyContactDamage,
    this.damageType = DamageType.physical,
    this.speed = Balance.enemySpeed,
    this.color = const Color(0xFF8A7F7A),
    super.radius = Balance.enemyRadius,
    super.priority,
  }) : hp = maxHp,
       super(anchor: Anchor.center, paint: Paint()..color = color);

  static const flashColor = Color(0xFFFFFFFF);

  final double maxHp;
  double hp;
  double speed;
  final double contactDamage;
  final DamageType damageType;
  final Color color;

  /// [CrowdSystem] 이 매 프레임 채워 주는 밀어내기 속도.
  final separation = Vector2.zero();

  final ailments = Ailments();

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
        ..scale(speed * ailments.speedMultiplier);
    }
    _velocity.add(separation);
    position.addScaled(_velocity, dt);

    if (_flash > 0) _flash -= dt;
    paint.color = _flash > 0 ? flashColor : ailments.tint ?? color;

    final dot = ailments.tick(dt);
    if (dot > 0) takeDamage(dot, flash: false);
  }

  /// 감전 중이면 더 아프다. 실제로 들어간 피해를 돌려준다.
  double takeDamage(double amount, {bool flash = true}) {
    if (_dead) return 0;
    final dealt = amount * ailments.damageTakenMultiplier;
    hp -= dealt;
    if (flash) {
      _flash = 0.08;
      paint.color = flashColor;
    }
    if (hp <= 0) _die();
    return dealt;
  }

  void _die() {
    _dead = true;
    world
      ..add(DeathPuff(position: position.clone()))
      ..onEnemyKilled(position.clone());
    onDeath();
    removeFromParent();
  }

  /// 쓰러질 때 추가로 할 일.
  void onDeath() {}
}
