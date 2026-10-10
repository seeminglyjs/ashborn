import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/corruption.dart';
import '../../data/damage.dart';
import '../../data/stages.dart';
import '../effects/sparks.dart';
import 'enemy.dart';
import 'hazards.dart';
import 'minions.dart';

/// 보스가 쓰는 기술. 지역마다 다른 조합을 쓴다 ([BossMove.of]).
enum BossMove {
  /// 힘을 모았다가 노린 방향으로 돌진.
  charge,

  /// 짧게 힘을 모아 세 번 연달아 돌진.
  rush,

  /// 땅을 내려찍어 바깥으로 퍼지는 충격파.
  slam,

  /// 사방으로 탄을 고르게 뿌린다.
  radial,

  /// 제자리에서 돌며 나선으로 탄을 뿌린다.
  spiral,

  /// 플레이어를 노려 부채꼴 탄을 세 번 쏜다.
  volley,

  /// 주변에 졸개를 부른다.
  summon,

  /// 플레이어 주변에 운석 장판을 떨어뜨린다.
  meteor,

  /// 사라졌다가 플레이어 근처에 나타나며 탄을 뿌린다.
  blink;

  static List<BossMove> of(Region region) => switch (region) {
    Region.ashPlains => const [charge, slam, summon],
    Region.sunkenCathedral => const [radial, blink, volley, summon],
    Region.burningForest => const [meteor, charge, slam, radial],
    Region.rustedFortress => const [rush, volley, summon, slam],
    Region.undyingHeart => const [spiral, meteor, rush, radial, summon],
  };
}

/// 지역의 보스. 크고 단단하며, 걸어오다가 일정 간격으로 지역 기술을 하나씩 쓴다.
/// 체력이 절반 아래로 떨어지면 격노해 기술을 더 자주, 더 세게 쓴다.
class Boss extends Enemy {
  Boss({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    super.sprite,
    required this.name,
    this.region = Region.ashPlains,
  }) : _walkSpeed = speed,
       moves = BossMove.of(region),
       super(radius: Balance.bossRadius, priority: 8);

  final String name;
  final Region region;
  final List<BossMove> moves;
  final double _walkSpeed;

  /// 다음 기술까지 남은 시간.
  double _next = Balance.bossMoveInterval * 0.6;

  /// 쓰고 있는 기술과 그 기술에서 지난 시간.
  BossMove? _move;
  double _t = 0;
  int _step = 0;
  BossMove? _last;

  final _aim = Vector2.zero();
  bool _enraged = false;

  bool get isEnraged => _enraged;
  BossMove? get currentMove => _move;
  bool get isCharging =>
      (_move == BossMove.charge || _move == BossMove.rush) && _dashing;
  bool _dashing = false;
  bool _hidden = false;

  @override
  double get knockbackScale => 0;

  @override
  double get spriteSize => Balance.bossSpriteSize;

  /// 보스는 체력이 졸개의 수십 배라 문턱을 따로 낮춘다. 얼어도 짧게 언다.
  @override
  double get ailmentThreshold => maxHp * Balance.bossAilmentThreshold;

  @override
  double get freezeScale => Balance.bossFreezeScale;

  @override
  double get spriteOpacity => _hidden ? 0.15 : 1;

  double get _interval =>
      Balance.bossMoveInterval * (_enraged ? Balance.bossEnragedInterval : 1);

  static const _chargeLane = Color(0x40FF3A2E);
  static final _slamFill = Paint()..color = const Color(0x22FF3A2E);
  static final _slamEdge = dangerStroke(3.5);

  Color get _hazard => hazardColor(damageType);

  /// 마지막으로 맞은 뒤 지난 시간 (타락 "보스 재생").
  double _sinceHit = 0;
  double _regenFx = 0;

  @override
  double takeDamage(double amount, {bool flash = true}) {
    _sinceHit = 0;
    return super.takeDamage(amount, flash: flash);
  }

  /// 격노하는 체력 비율. 타락 "이른 격노" 면 더 일찍.
  double get enrageHp => world.stage.has(CorruptionRule.earlyEnrage)
      ? Balance.earlyEnrageHp
      : Balance.bossEnrageHp;

  /// 타락 "보스 재생": 잠시 맞지 않으면 체력을 회복하고 초록 불티가 피어오른다.
  void _regenerate(double dt) {
    if (!world.stage.has(CorruptionRule.bossRegen) || isDead) return;
    _sinceHit += dt;
    if (_sinceHit < Balance.bossRegenDelay || hp >= maxHp) return;
    hp = math.min(maxHp, hp + maxHp * Balance.bossRegenRate * dt);
    _regenFx -= dt;
    if (_regenFx > 0) return;
    _regenFx = 0.3;
    final random = world.game.random;
    world.add(
      Sparks(
        position:
            position +
            Vector2(
              (random.nextDouble() - 0.5) * radius * 1.4,
              -random.nextDouble() * radius,
            ),
        color: const Color(0xFF63C74D),
        count: 4,
        speed: 70,
      ),
    );
  }

  @override
  void update(double dt) {
    _regenerate(dt);
    if (!_enraged && hp <= maxHp * enrageHp) {
      _enraged = true;
      world.game.notify('$name 격노!', color: const Color(0xFFE8463A));
      world
        ..add(
          HostileBurst(
            position: position.clone(),
            radius: radius * 3,
            color: color,
          ),
        )
        ..shake(0.4);
    }
    super.update(dt);
  }

  @override
  void steer(double dt, Vector2 out) {
    renderShake.setZero();
    final move = _move;
    if (move == null) {
      _next -= dt;
      if (_next <= 0) _start();
      _walk(out, 1);
      return;
    }
    _t += dt;
    out.setZero();
    switch (move) {
      case BossMove.charge:
        _charge(dt, out, windup: Balance.bossChargeWindup, repeats: 1);
      case BossMove.rush:
        _charge(dt, out, windup: Balance.bossRushWindup, repeats: 3);
      case BossMove.slam:
        _shake(4);
        if (_t >= Balance.bossSlamWindup) {
          world
            ..add(
              Shockwave(
                position: position.clone(),
                maxRadius: Balance.bossSlamRadius,
                damage: contactDamage * Balance.bossHazardDamage,
                type: damageType,
                color: _hazard,
              ),
            )
            ..add(Sparks(position: position.clone(), color: color, count: 14))
            ..shake(0.35);
          if (_enraged) {
            // 격노하면 한 박자 늦게 두 번째 고리.
            world.add(
              _DelayedShockwave(
                delay: 0.45,
                position: position.clone(),
                maxRadius: Balance.bossSlamRadius,
                damage: contactDamage * Balance.bossHazardDamage,
                type: damageType,
                color: _hazard,
              ),
            );
          }
          _end();
        }
      case BossMove.radial:
        _shake(2);
        if (_t >= 0.5) {
          _ring(_enraged ? 20 : 14, world.game.random.nextDouble());
          _end();
        }
      case BossMove.spiral:
        const step = 0.12;
        while (_step * step <= _t && _t < Balance.bossSpiralTime) {
          final a = _step * 0.42;
          final arms = _enraged ? 3 : 2;
          for (var i = 0; i < arms; i++) {
            _bullet(a + math.pi * 2 * i / arms);
          }
          _step++;
        }
        if (_t >= Balance.bossSpiralTime) _end();
      case BossMove.volley:
        // 0.4초 조준 뒤 0.35초 간격으로 부채꼴 세 번.
        final shots = _enraged ? 4 : 3;
        if (_step < shots && _t >= 0.4 + _step * 0.35) {
          final to = world.player.position - position;
          final base = math.atan2(to.y, to.x);
          for (var i = -2; i <= 2; i++) {
            _bullet(base + i * 0.18, speed: Balance.enemyBulletSpeed * 1.3);
          }
          _step++;
        }
        if (_step >= shots) _end();
      case BossMove.summon:
        _shake(2);
        if (_t >= 0.6) {
          _summon(_enraged ? Balance.bossEnragedSummon : Balance.bossSummon);
          _end();
        }
      case BossMove.meteor:
        if (_step == 0) {
          _meteors(_enraged ? 6 : 4);
          _step = 1;
        }
        _walk(out, 0.5);
        if (_t >= Balance.bossMeteorDelay) _end();
      case BossMove.blink:
        _blink();
    }
  }

  void _walk(Vector2 out, double scale) {
    out
      ..setFrom(world.player.position)
      ..sub(position);
    if (out.length2 > 1) {
      out
        ..normalize()
        ..scale(_walkSpeed * ailments.speedMultiplier * scale);
    } else {
      out.setZero();
    }
  }

  void _shake(double amount) {
    final r = world.game.random;
    renderShake.setValues(
      (r.nextDouble() - 0.5) * amount,
      (r.nextDouble() - 0.5) * amount * 0.6,
    );
  }

  /// 같은 기술을 연달아 쓰지 않도록 고른다.
  void _start() {
    final r = world.game.random;
    final pool = moves.where((m) => m != _last).toList();
    final move = pool[r.nextInt(pool.length)];
    _move = move;
    _last = move;
    _t = 0;
    _step = 0;
    _dashing = false;
    _aim
      ..setFrom(world.player.position)
      ..sub(position)
      ..normalize();
  }

  void _end() {
    _move = null;
    _dashing = false;
    _hidden = false;
    _next = _interval;
  }

  /// 힘 모으기 → 돌진을 [repeats] 번. [_step] 은 끝낸 돌진 수.
  void _charge(
    double dt,
    Vector2 out, {
    required double windup,
    required int repeats,
  }) {
    final dash = Balance.bossChargeDuration;
    final local = _t - _step * (windup + dash);
    if (local < windup) {
      _dashing = false;
      _shake(5);
      if (local < windup * 0.6) {
        _aim
          ..setFrom(world.player.position)
          ..sub(position)
          ..normalize();
      }
      return;
    }
    if (local < windup + dash) {
      _dashing = true;
      out
        ..setFrom(_aim)
        ..scale(_walkSpeed * Balance.bossChargeSpeed);
      return;
    }
    _step++;
    if (_step >= repeats) _end();
  }

  void _bullet(double angle, {double speed = Balance.enemyBulletSpeed}) {
    if (!world.canAddBullet) return;
    world.add(
      EnemyBullet(
        position: position.clone(),
        direction: Vector2(math.cos(angle), math.sin(angle)),
        damage: contactDamage * Balance.bossBulletDamage,
        type: damageType,
        color: _hazard,
        speed: speed,
        radius: Balance.enemyBulletRadius * 1.4,
      ),
    );
  }

  void _ring(int count, double offset) {
    for (var i = 0; i < count; i++) {
      _bullet(math.pi * 2 * (i + offset) / count);
    }
  }

  void _summon(int count) {
    final stage = world.stage;
    final roster = region.roster;
    final r = world.game.random;
    for (var i = 0; i < count; i++) {
      if (world.enemies.length >= Balance.maxEnemies) break;
      final a = math.pi * 2 * i / count;
      final kind = roster[r.nextInt(2)];
      world.add(
        spawnMinion(
          kind,
          position: position + Vector2(math.cos(a), math.sin(a)) * radius * 2,
          maxHp: maxHp / Balance.bossHpMultiplier,
          contactDamage: contactDamage / Balance.bossDamageMultiplier,
          damageType: damageType,
          speed: Balance.enemySpeed * stage.enemySpeedMultiplier,
          color: color,
        ),
      );
    }
    world.add(
      HostileBurst(
        position: position.clone(),
        radius: radius * 2,
        color: _hazard,
      ),
    );
  }

  void _meteors(int count) {
    final r = world.game.random;
    final target = world.player.position;
    for (var i = 0; i < count; i++) {
      final offset = i == 0
          ? Vector2.zero()
          : (Vector2(r.nextDouble() - 0.5, r.nextDouble() - 0.5)
              ..scale(Balance.bossMeteorSpread * 2));
      world.add(
        GroundBlast(
          position: target + offset,
          radius: Balance.bossMeteorRadius,
          damage: contactDamage * Balance.bossHazardDamage,
          type: damageType,
          color: _hazard,
          delay: Balance.bossMeteorDelay + i * 0.15,
          linger: region == Region.burningForest ? Balance.bossMeteorLinger : 0,
        ),
      );
    }
  }

  /// 0.45초 동안 흐려지다 플레이어 근처로 옮겨 가 나타나며 탄을 뿌린다.
  void _blink() {
    if (_step == 0) {
      _hidden = true;
      if (_t >= 0.45) {
        final r = world.game.random;
        final a = r.nextDouble() * math.pi * 2;
        position.setFrom(
          world.player.position +
              Vector2(math.cos(a), math.sin(a)) * Balance.bossBlinkDistance,
        );
        _hidden = false;
        world.add(
          HostileBurst(
            position: position.clone(),
            radius: radius * 2,
            color: _hazard,
          ),
        );
        _step = 1;
      }
      return;
    }
    if (_t >= 0.75) {
      _ring(_enraged ? 14 : 10, 0.5);
      _end();
    }
  }

  @override
  void renderUnder(Canvas canvas) {
    final c = Offset(radius, radius);
    switch (_move) {
      case BossMove.charge || BossMove.rush when !_dashing:
        final reach =
            _walkSpeed * Balance.bossChargeSpeed * Balance.bossChargeDuration;
        drawDangerLane(
          canvas,
          c,
          c + Offset(_aim.x, _aim.y) * reach,
          radius * 1.1,
          _chargeLane,
        );
      case BossMove.slam:
        // 지진파가 닿는 실제 거리를 처음부터 테두리로 보여 주고, 안쪽을 차오르게 칠한다.
        final t = (_t / Balance.bossSlamWindup).clamp(0.0, 1.0);
        canvas
          ..drawCircle(c, Balance.bossSlamRadius * t, _slamFill)
          ..drawCircle(c, Balance.bossSlamRadius, _slamEdge);
      default:
        break;
    }
  }

  @override
  void onDeath() => world.onBossDefeated(this);
}

/// [delay] 초 뒤에 충격파를 낸다 (격노한 내려찍기의 두 번째 고리).
class _DelayedShockwave extends Hazard {
  _DelayedShockwave({
    required this.delay,
    required super.position,
    required this.maxRadius,
    required this.damage,
    required this.type,
    required this.color,
  });

  final double delay;
  final double maxRadius;
  final double damage;
  final DamageType type;
  final Color color;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t < delay) return;
    world.add(
      Shockwave(
        position: position.clone(),
        maxRadius: maxRadius,
        damage: damage,
        type: type,
        color: color,
      ),
    );
    removeFromParent();
  }
}
