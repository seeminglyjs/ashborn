import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/enemies.dart';
import '../effects/burst.dart';
import '../effects/sparks.dart';
import 'enemy.dart';
import 'hazards.dart';

/// [kind] 의 행동에 맞는 졸개를 만든다. 체력 · 피해 · 속도는 지역 기본값에 종류 배율을 곱해 넘긴다.
Enemy spawnMinion(
  EnemyKind kind, {
  required Vector2 position,
  required double maxHp,
  required double contactDamage,
  required DamageType damageType,
  required double speed,
  required Color color,
}) {
  final hp = maxHp * kind.hp;
  final damage = contactDamage * kind.damage;
  final s = speed * kind.speed;
  final radius = Balance.enemyRadius * kind.size;
  return switch (kind.behavior) {
    EnemyBehavior.chase => Enemy(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      sprite: kind.sprite,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.swarm => Swarmer(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.phantom => Phantom(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.brute => Brute(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.charger => Charger(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.shooter => Shooter(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.caster => Caster(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.bomber => Bomber(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
    EnemyBehavior.splitter => Splitter(
      position: position,
      maxHp: hp,
      contactDamage: damage,
      damageType: damageType,
      speed: s,
      color: color,
      kind: kind,
      radius: radius,
    ),
  };
}

/// 피해 속성마다 적 탄 · 장판 색.
Color hazardColor(DamageType type) => switch (type) {
  DamageType.physical => const Color(0xFFE0D2C0),
  DamageType.fire => const Color(0xFFFF7A2E),
  DamageType.cold => const Color(0xFF8FD3FF),
  DamageType.lightning => const Color(0xFFFFE45C),
  DamageType.wind => const Color(0xFFE05A8A),
};

/// 플레이어 쪽 단위 벡터를 [out] 에 넣고 거리를 돌려준다.
double _towardPlayer(Enemy e, Vector2 out) {
  out
    ..setFrom(e.world.player.position)
    ..sub(e.position);
  final d = out.length;
  if (d > 1e-6) out.scale(1 / d);
  return d;
}

/// 떼: 다가오며 좌우로 흔들린다. 몇 마리씩 몰려 나온다.
class Swarmer extends Enemy {
  Swarmer({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
  }) : super(sprite: kind.sprite);

  double _phase = 0;

  @override
  void onMount() {
    super.onMount();
    _phase = world.game.random.nextDouble() * math.pi * 2;
  }

  @override
  void steer(double dt, Vector2 out) {
    _phase += dt * Balance.swarmWeaveFrequency * math.pi * 2;
    _towardPlayer(this, out);
    final side = Vector2(-out.y, out.x)
      ..scale(math.sin(_phase) * Balance.swarmWeave);
    out
      ..add(side)
      ..scale(moveSpeed);
  }
}

/// 망령: 크게 지그재그로 날아들고 반쯤 비친다.
class Phantom extends Enemy {
  Phantom({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
  }) : super(sprite: kind.sprite);

  double _phase = 0;

  @override
  double get spriteOpacity => Balance.phantomOpacity;

  @override
  void onMount() {
    super.onMount();
    _phase = world.game.random.nextDouble() * math.pi * 2;
  }

  @override
  void steer(double dt, Vector2 out) {
    _phase += dt * Balance.phantomZigzagFrequency * math.pi * 2;
    _towardPlayer(this, out);
    // 삼각파로 꺾어 지그재그를 또렷하게.
    final wave = (2 / math.pi) * math.asin(math.sin(_phase));
    final side = Vector2(-out.y, out.x)..scale(wave * Balance.phantomZigzag);
    out
      ..add(side)
      ..scale(moveSpeed);
  }
}

/// 거구: 느리고 단단하며 잘 밀리지 않는다 (졸개끼리 밀어내기도 받지 않는다).
class Brute extends Enemy {
  Brute({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
  }) : super(sprite: kind.sprite);

  @override
  double get knockbackScale => Balance.bruteKnockback;
}

enum _ChargeState { approach, windup, dash }

/// 돌진: 가까워지면 멈춰서 떨며 힘을 모으고, 노린 방향으로 곧게 내달린다.
class Charger extends Enemy {
  Charger({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
  }) : super(sprite: kind.sprite);

  var _state = _ChargeState.approach;
  double _timer = 0;
  double _cooldown = Balance.chargeCooldown * 0.5;
  final _aim = Vector2.zero();

  bool get isWindingUp => _state == _ChargeState.windup;
  bool get isDashing => _state == _ChargeState.dash;

  static final _line = Paint()
    ..color = const Color(0x66FF3A2E)
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;

  @override
  void steer(double dt, Vector2 out) {
    renderShake.setZero();
    switch (_state) {
      case _ChargeState.approach:
        _cooldown -= dt;
        final d = _towardPlayer(this, out);
        if (_cooldown <= 0 && d < Balance.chargeRange) {
          _state = _ChargeState.windup;
          _timer = Balance.chargeWindup;
          _aim.setFrom(out);
          out.setZero();
          return;
        }
        out.scale(moveSpeed);
      case _ChargeState.windup:
        _timer -= dt;
        final r = world.game.random;
        renderShake.setValues(
          (r.nextDouble() - 0.5) * 3,
          (r.nextDouble() - 0.5) * 2,
        );
        // 힘을 모으는 동안 노리는 방향을 조금씩 따라간다. 막판엔 고정된다.
        if (_timer > Balance.chargeWindup * 0.4) _towardPlayer(this, _aim);
        out.setZero();
        if (_timer <= 0) {
          _state = _ChargeState.dash;
          _timer = Balance.chargeDash;
        }
      case _ChargeState.dash:
        _timer -= dt;
        out
          ..setFrom(_aim)
          ..scale(speed * Balance.chargeSpeed);
        if (_timer <= 0) {
          _state = _ChargeState.approach;
          _cooldown = Balance.chargeCooldown;
        }
    }
  }

  @override
  void renderUnder(Canvas canvas) {
    if (!isWindingUp) return;
    final c = Offset(radius, radius);
    final reach = speed * Balance.chargeSpeed * Balance.chargeDash;
    final t = 1 - _timer / Balance.chargeWindup;
    canvas.drawLine(c, c + Offset(_aim.x, _aim.y) * reach * t, _line);
  }
}

/// 사격: 일정 거리를 지키며 옆으로 돌다가 조준해 탄을 쏜다.
class Shooter extends Enemy {
  Shooter({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
  }) : super(sprite: kind.sprite);

  double _cooldown = 0;
  double _windup = 0;
  double _strafe = 1;

  late final _aimPaint = Paint()
    ..color = hazardColor(damageType).withValues(alpha: 0.7);

  @override
  void onMount() {
    super.onMount();
    final r = world.game.random;
    _cooldown = Balance.shooterCooldown * (0.5 + r.nextDouble());
    _strafe = r.nextBool() ? 1 : -1;
  }

  @override
  void steer(double dt, Vector2 out) {
    final d = _towardPlayer(this, out);
    if (_windup > 0) {
      _windup -= dt;
      if (_windup <= 0) _fire(out);
      out.setZero();
      return;
    }
    _cooldown -= dt;
    if (_cooldown <= 0 && world.isOnScreen(position) && world.canAddBullet) {
      _windup = Balance.shooterWindup;
      _cooldown = Balance.shooterCooldown;
      out.setZero();
      return;
    }
    keepDistance(d, Balance.shooterRange, _strafe, out);
  }

  /// 원하는 거리보다 멀면 다가가고, 가까우면 물러나고, 그 사이면 옆으로 돈다.
  /// [out] 은 플레이어 쪽 단위 벡터로 들어와 속도로 나간다.
  void keepDistance(double d, double range, double strafe, Vector2 out) {
    if (d > range + 30) {
      out.scale(moveSpeed);
    } else if (d < range - 50) {
      out.scale(-moveSpeed * 0.8);
    } else {
      out
        ..setValues(-out.y * strafe, out.x * strafe)
        ..scale(moveSpeed * 0.5);
    }
  }

  void _fire(Vector2 direction) {
    world.add(
      EnemyBullet(
        position: position.clone(),
        direction: direction.clone(),
        damage: contactDamage * Balance.enemyBulletDamage,
        type: damageType,
        color: hazardColor(damageType),
      ),
    );
  }

  @override
  void renderOver(Canvas canvas) {
    if (_windup <= 0) return;
    // 조준하는 동안 머리 위 빛이 커진다.
    final t = 1 - _windup / Balance.shooterWindup;
    canvas.drawCircle(Offset(radius, -2), 2 + 4 * t, _aimPaint);
  }
}

/// 주술: 멀리서 플레이어 발밑에 예고 장판을 깐다.
class Caster extends Shooter {
  Caster({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required super.kind,
    required super.radius,
  });

  double _castCooldown = 0;
  double _cast = 0;

  @override
  void onMount() {
    super.onMount();
    _castCooldown =
        Balance.casterCooldown * (0.5 + world.game.random.nextDouble());
  }

  @override
  void steer(double dt, Vector2 out) {
    final d = _towardPlayer(this, out);
    if (_cast > 0) {
      _cast -= dt;
      out.setZero();
      return;
    }
    _castCooldown -= dt;
    if (_castCooldown <= 0 && world.isOnScreen(position)) {
      _castCooldown = Balance.casterCooldown;
      _cast = 0.4;
      world.add(
        GroundBlast(
          position: world.player.position.clone(),
          radius: Balance.casterBlastRadius,
          damage: contactDamage * Balance.casterBlastDamage,
          type: damageType,
          color: hazardColor(damageType),
        ),
      );
      out.setZero();
      return;
    }
    keepDistance(d, Balance.casterRange, _strafe, out);
  }

  @override
  void renderOver(Canvas canvas) {
    if (_cast <= 0) return;
    canvas.drawCircle(Offset(radius, -2), 5, _aimPaint);
  }
}

/// 자폭: 가까이 오면 멈춰서 점점 빠르게 깜빡이다 터진다.
/// 터지기 전에 쓰러뜨리면 터지지 않는다.
class Bomber extends Enemy {
  Bomber({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
  }) : super(sprite: kind.sprite);

  double? _fuse;

  bool get isLit => _fuse != null;

  late final _range = Paint()
    ..color = hazardColor(damageType).withValues(alpha: 0.18);
  late final _rangeEdge = Paint()
    ..color = hazardColor(damageType).withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void steer(double dt, Vector2 out) {
    if (_fuse case final fuse?) {
      _fuse = fuse - dt;
      out.setZero();
      if (_fuse! <= 0) _explode();
      return;
    }
    final d = _towardPlayer(this, out);
    if (d < Balance.bomberTrigger) {
      _fuse = Balance.bomberFuse;
      out.setZero();
      return;
    }
    out.scale(moveSpeed);
  }

  void _explode() {
    if (isDead) return;
    final at = position.clone();
    final color = hazardColor(damageType);
    world
      ..add(Burst(position: at, radius: Balance.bomberRadius, color: color))
      ..add(Sparks(position: at.clone(), color: color, count: 12, speed: 220))
      ..shake(0.2);
    final reach = Balance.bomberRadius + Balance.playerRadius;
    if (world.player.position.distanceToSquared(at) <= reach * reach) {
      world.player.takeDamage(
        contactDamage * Balance.bomberDamage,
        type: damageType,
      );
    }
    // 스스로 터지면 처치 보상은 없다.
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_fuse case final fuse?) {
      // 남은 시간이 줄수록 빠르게 깜빡인다.
      final rate = 6 + 18 * (1 - fuse / Balance.bomberFuse);
      if ((fuse * rate).floor().isEven) flashWhite();
    }
  }

  @override
  void renderUnder(Canvas canvas) {
    final fuse = _fuse;
    if (fuse == null) return;
    final c = Offset(radius, radius);
    final t = 1 - fuse / Balance.bomberFuse;
    canvas
      ..drawCircle(c, Balance.bomberRadius * t, _range)
      ..drawCircle(c, Balance.bomberRadius, _rangeEdge);
  }
}

/// 분열: 쓰러지면 작은 새끼 둘로 갈라진다. 새끼는 다시 갈라지지 않는다.
class Splitter extends Enemy {
  Splitter({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required EnemyKind super.kind,
    required super.radius,
    this.child = false,
  }) : super(sprite: kind.sprite);

  final bool child;

  /// 새끼는 재의 결정을 떨어뜨리지 않는다 (한 마리 값을 셋이 나눠 받지 않도록).
  @override
  void onKilled() {
    if (!child) return super.onKilled();
    world.onEnemyKilled(position.clone(), xp: 0);
  }

  @override
  void onDeath() {
    if (child) return;
    final r = world.game.random;
    for (var i = 0; i < Balance.splitCount; i++) {
      final a = r.nextDouble() * math.pi * 2;
      world.add(
        Splitter(
          position: position + Vector2(math.cos(a), math.sin(a)) * radius,
          maxHp: maxHp * Balance.splitHp,
          contactDamage: contactDamage * 0.6,
          damageType: damageType,
          speed: speed * 1.2,
          color: color,
          kind: kind!,
          radius: radius * Balance.splitSize,
          child: true,
        ),
      );
    }
  }
}
