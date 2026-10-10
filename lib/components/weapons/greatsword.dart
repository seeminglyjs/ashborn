import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/damage_number.dart';
import '../effects/sparks.dart';
import '../enemies/enemy.dart';
import 'weapon.dart';
import 'weapon_art.dart';

/// 강철 대검의 기술.
enum SwordMove {
  thrust('찌르기'),
  swing('휘두르기'),
  slam('내려찍기');

  const SwordMove(this.label);

  final String label;
}

/// 강철 대검 (잿불 기사): 가까운 적에게 직접 휘두르는 근접 무기.
///
/// 1레벨은 찌르기만, [Balance.swingLevel] 에 휘두르기, [Balance.slamLevel] 에 내려찍기를 익힌다.
/// 쿨다운마다 익힌 기술을 차례로 하나씩 쓰고, [comboChance] 확률로 다음 기술을 곧바로 잇는다.
/// [Balance.onslaughtLevel] 부터는 콤보가 [Balance.onslaughtStreak] 번 연달아 나면
/// 맹공에 들어가 잠시 쿨다운이 짧아진다.
class Greatsword extends Weapon {
  Greatsword() : super(baseCooldown: Balance.greatswordCooldown);

  @override
  WeaponId get id => WeaponId.greatsword;

  /// 지금 쓸 수 있는 기술 (쓰는 차례대로).
  List<SwordMove> get moves => [
    SwordMove.thrust,
    if (level >= Balance.swingLevel) SwordMove.swing,
    if (level >= Balance.slamLevel) SwordMove.slam,
  ];

  bool get hasOnslaught => level >= Balance.onslaughtLevel;

  /// 기술 하나 뒤에 다음 기술을 이어 쓸 확률.
  double get comboChance =>
      stat(WeaponStat.combo) +
      (awakened ? Balance.titanCombo : 0) +
      world.player.extraProjectiles * Balance.comboPerProjectile +
      world.player.comboBonus;

  /// 기술 크기 배율 (범위 패시브 · 레벨업 · 각성).
  double get size => areaMultiplier * (awakened ? Balance.titanArea : 1);

  double get reach => Balance.greatswordReach * size;

  /// 다음에 쓸 기술 차례.
  int _next = 0;

  /// 끊기지 않고 연달아 난 콤보 수. 맹공에 들어가면 0으로 돌아간다.
  int streak = 0;

  /// 이번 런에서 난 콤보 수.
  int combos = 0;

  /// 남은 맹공 시간.
  double onslaught = 0;
  bool get inOnslaught => onslaught > 0;

  /// 콤보로 이어 쓸 기술과 다음 기술까지 남은 시간.
  final _queue = <SwordMove>[];
  double _queueTimer = 0;

  /// 마지막으로 노린 방향 (노릴 적이 사라졌을 때 콤보를 그쪽으로 마저 휘두른다).
  final _aim = Vector2(1, 0);

  @override
  double get cooldown =>
      super.cooldown * (inOnslaught ? Balance.onslaughtCooldown : 1);

  @override
  void update(double dt) {
    if (onslaught > 0) onslaught -= dt;
    if (_queue.isNotEmpty) {
      _queueTimer -= dt;
      if (_queueTimer <= 0) {
        _perform(_queue.removeAt(0), combo: true);
        _queueTimer = Balance.comboDelay;
      }
      return;
    }
    super.update(dt);
  }

  @override
  bool fire() {
    final player = world.player;
    if (world.nearestEnemy(player.position, maxDistance: reach) == null) {
      return false;
    }
    final list = moves;
    final first = list[_next % list.length];
    _next++;
    _perform(first);
    // 콤보: 이어 쓸 때마다 다시 굴린다. 끊기면 연속 콤보도 끊긴다.
    final random = world.game.random;
    for (var i = 1; i < list.length; i++) {
      if (random.nextDouble() >= comboChance) {
        streak = 0;
        break;
      }
      _queue.add(list[(list.indexOf(first) + i) % list.length]);
      _onCombo();
    }
    _queueTimer = Balance.comboDelay;
    return true;
  }

  void _onCombo() {
    combos++;
    streak++;
    if (hasOnslaught && streak >= Balance.onslaughtStreak) {
      streak = 0;
      final starting = !inOnslaught;
      onslaught = Balance.onslaughtDuration + world.player.onslaughtBonus;
      if (starting) _announceOnslaught();
    }
  }

  void _announceOnslaught() {
    final at = world.player.position;
    world
      ..add(
        CallOut(
          position: at + Vector2(0, -44),
          text: '맹공!',
          color: const Color(0xFFFF6A3D),
          fontSize: 18,
        ),
      )
      ..add(
        Ring(
          position: at.clone(),
          radius: 70,
          color: const Color(0xFFFF6A3D),
          strokeWidth: 5,
        ),
      );
  }

  /// [move] 를 가장 가까운 적 쪽으로 휘두른다. 피해는 칼이 닿는 순간 준다.
  void _perform(SwordMove move, {bool combo = false}) {
    final player = world.player;
    final target = world.nearestEnemy(
      player.position,
      maxDistance: reach * 1.3,
    );
    if (target != null) {
      _aim
        ..setFrom(target.position)
        ..sub(player.position);
      if (_aim.isZero()) _aim.setValues(1, 0);
      _aim.normalize();
    }
    if (combo) {
      world.add(
        CallOut(
          position: player.position + Vector2(0, -36),
          text: move.label,
          color: const Color(0xFFFFE08A),
          fontSize: 12,
        ),
      );
    }
    world.add(
      SwordStrike(
        move: move,
        angle: math.atan2(_aim.y, _aim.x),
        sizeScale: size,
        fury: inOnslaught,
        awakened: awakened,
        onImpact: (strike) => _impact(move, strike.aimAngle),
      ),
    );
  }

  /// 칼이 닿는 순간: 기술마다 정해진 모양 안의 적을 벤다.
  void _impact(SwordMove move, double angle) {
    final player = world.player;
    final at = player.position.clone();
    final dir = Vector2(math.cos(angle), math.sin(angle));
    final hits = switch (move) {
      SwordMove.thrust => _inLine(at, dir),
      SwordMove.swing => _inArc(at, angle),
      SwordMove.slam => _inCircle(at + dir * (Balance.slamOffset * size)),
    };
    final damage =
        switch (move) {
          SwordMove.thrust => Balance.thrustDamage,
          SwordMove.swing => Balance.swingDamage,
          SwordMove.slam => Balance.slamDamage,
        } *
        damageMultiplier;
    final power = switch (move) {
      SwordMove.thrust => Balance.thrustPower,
      SwordMove.swing => Balance.swingPower,
      SwordMove.slam => Balance.slamPower,
    };
    for (final enemy in hits) {
      player.strike(enemy, damage, id.damageType, power: power);
    }
    if (move == SwordMove.slam) {
      final center = at + dir * (Balance.slamOffset * size);
      for (final enemy in hits) {
        enemy.knock(enemy.position - center, Balance.slamKnockback);
      }
      world
        ..add(GroundCrack(position: center, radius: Balance.slamRadius * size))
        ..add(
          Ring(
            position: center.clone(),
            radius: Balance.slamRadius * size,
            color: const Color(0xFFE8D2A8),
            strokeWidth: 8,
          ),
        )
        ..add(
          Sparks(
            position: center.clone(),
            color: const Color(0xFFB89A74),
            count: 14,
            speed: 210,
            sparkSize: 4,
          ),
        )
        ..shake(0.18);
    } else if (hits.isNotEmpty) {
      world.shake(0.05);
    }
  }

  List<Enemy> _inLine(Vector2 at, Vector2 dir) {
    final length = Balance.thrustLength * size;
    final half = Balance.thrustWidth * size / 2;
    return [
      for (final enemy in world.enemiesNear(at, length + 40))
        if (_alongLine(enemy, at, dir, length, half)) enemy,
    ];
  }

  static bool _alongLine(
    Enemy enemy,
    Vector2 at,
    Vector2 dir,
    double length,
    double half,
  ) {
    final to = enemy.position - at;
    final along = to.dot(dir);
    final across = (to.x * dir.y - to.y * dir.x).abs();
    return along >= -enemy.radius &&
        along <= length + enemy.radius &&
        across <= half + enemy.radius;
  }

  List<Enemy> _inArc(Vector2 at, double angle) {
    final radius = Balance.swingRadius * size;
    return [
      for (final enemy in world.enemiesNear(at, radius + 40))
        if (enemy.position.distanceTo(at) <= radius + enemy.radius &&
            _angleTo(enemy.position - at, angle) <= Balance.swingArc)
          enemy,
    ];
  }

  static double _angleTo(Vector2 to, double angle) {
    final diff = math.atan2(to.y, to.x) - angle;
    return math.atan2(math.sin(diff), math.cos(diff)).abs();
  }

  List<Enemy> _inCircle(Vector2 center) {
    final radius = Balance.slamRadius * size;
    return [
      for (final enemy in world.enemiesNear(center, radius + 40))
        if (enemy.position.distanceTo(center) <= radius + enemy.radius) enemy,
    ];
  }
}

/// 대검을 한 번 휘두르는 연출. 플레이어를 따라다니며 칼을 그리고,
/// [impactAt] 순간에 [onImpact] 를 부른다 (피해는 무기가 준다).
class SwordStrike extends PositionComponent with HasWorldReference<RunWorld> {
  SwordStrike({
    required this.move,
    required double angle,
    required this.sizeScale,
    required this.onImpact,
    this.fury = false,
    this.awakened = false,
  }) : aimAngle = angle,
       super(priority: 9);

  final SwordMove move;

  /// 휘두르는 방향 (라디안).
  final double aimAngle;

  /// 기술 크기 배율 (대검의 [Greatsword.size]).
  final double sizeScale;
  final void Function(SwordStrike strike) onImpact;

  /// 맹공 중이면 칼자국이 붉다.
  final bool fury;
  final bool awakened;

  double _t = 0;
  bool _hit = false;

  double get duration => switch (move) {
    SwordMove.thrust => 0.26,
    SwordMove.swing => 0.3,
    SwordMove.slam => 0.42,
  };

  /// 전체 시간 중 칼이 닿는 비율.
  double get impactAt => switch (move) {
    SwordMove.thrust => 0.4,
    SwordMove.swing => 0.45,
    SwordMove.slam => 0.55,
  };

  double get _progress => (_t / duration).clamp(0.0, 1.0);

  @override
  void onMount() {
    super.onMount();
    position.setFrom(world.player.position);
  }

  @override
  void update(double dt) {
    position.setFrom(world.player.position);
    _t += dt;
    if (!_hit && _progress >= impactAt) {
      _hit = true;
      onImpact(this);
    }
    if (_t >= duration) removeFromParent();
  }

  Color get _trailColor => fury
      ? const Color(0xFFFF6A3D)
      : awakened
      ? const Color(0xFFFFE08A)
      : const Color(0xFFE6EEFF);

  static double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();
  static double _easeIn(double t) => t * t * t;

  @override
  void render(Canvas canvas) {
    final t = _progress;
    final fade = t > 0.75 ? 1 - (t - 0.75) / 0.25 : 1.0;
    // 칼을 가슴 높이에서 쥔다.
    canvas.translate(0, -8);
    switch (move) {
      case SwordMove.thrust:
        _thrust(canvas, t, fade);
      case SwordMove.swing:
        _swing(canvas, t, fade);
      case SwordMove.slam:
        _slam(canvas, t, fade);
    }
  }

  double get _pixel => Balance.greatswordPixel * sizeScale;
  double get _blade => greatswordReachPixels * _pixel;

  void _sword(
    Canvas canvas,
    double angle,
    double grip,
    double alpha, {
    double scale = 1,
  }) {
    canvas
      ..save()
      ..rotate(angle)
      ..translate(grip, 0);
    if (alpha < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)),
      );
    }
    greatswordArt.draw(canvas, pivot: greatswordGrip, scale: _pixel * scale);
    if (alpha < 1) canvas.restore();
    canvas.restore();
  }

  /// 찌르기: 살짝 당겼다가 앞으로 쭉 내지르며 칼끝에 하얀 궤적을 남긴다.
  void _thrust(Canvas canvas, double t, double fade) {
    final length = Balance.thrustLength * sizeScale;
    final far = length - _blade;
    final grip = t < 0.3
        ? -8 * (t / 0.3)
        : t < 0.5
        ? -8 + (far + 8) * _easeOut((t - 0.3) / 0.2)
        : far;
    if (t > 0.32) {
      final streak = (t - 0.32) / 0.68;
      final paint = Paint()
        ..color = _trailColor.withValues(alpha: 0.7 * (1 - streak));
      final w = Balance.thrustWidth * sizeScale * 0.5 * (1 - streak * 0.6);
      canvas
        ..save()
        ..rotate(aimAngle)
        ..drawPath(
          Path()
            ..moveTo(10, -w / 2)
            ..lineTo(grip + _blade + 10, 0)
            ..lineTo(10, w / 2)
            ..close(),
          paint,
        )
        ..restore();
    }
    _sword(canvas, aimAngle, grip, fade);
  }

  /// 휘두르기: 한쪽에서 반대쪽으로 크게 베며 초승달 칼자국을 남긴다.
  void _swing(Canvas canvas, double t, double fade) {
    const arc = Balance.swingArc * 1.1;
    final sweep = _easeOut(math.min(1, t / 0.6));
    final from = aimAngle - arc;
    final angle = from + arc * 2 * sweep;
    final radius = Balance.swingRadius * sizeScale;
    if (sweep > 0.05) {
      // 꼬리는 가늘고 칼날 쪽은 두꺼운 초승달 칼자국.
      final outer = radius * 0.98;
      final path = Path();
      const steps = 16;
      for (var i = 0; i <= steps; i++) {
        final a = from + (angle - from) * i / steps;
        final p = Offset(math.cos(a) * outer, math.sin(a) * outer);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      for (var i = steps; i >= 0; i--) {
        final k = i / steps;
        final a = from + (angle - from) * k;
        final inner = outer - radius * 0.5 * k * k;
        path.lineTo(math.cos(a) * inner, math.sin(a) * inner);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = _trailColor.withValues(alpha: 0.45 * fade),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: outer),
        from + (angle - from) * 0.35,
        (angle - from) * 0.65,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95 * fade),
      );
    }
    _sword(canvas, angle, 6, fade);
  }

  /// 내려찍기: 칼을 머리 위로 크게 들었다가 앞쪽 땅에 내리꽂는다.
  void _slam(Canvas canvas, double t, double fade) {
    final down = math.min(1.0, t / impactAt);
    final angle = aimAngle - 2.6 * (1 - _easeIn(down));
    // 들어 올릴 때는 화면 쪽으로 다가오듯 커지고, 내리꽂으면 제 크기.
    final lift = down < 1 ? 1 + 0.25 * math.sin(down * math.pi) : 1.0;
    final grip = Balance.slamOffset * sizeScale - _blade * 0.55;
    _sword(canvas, angle, math.max(4, grip * down), fade, scale: lift);
  }
}

/// 내려찍은 자리에 갈라지는 땅. 금이 사방으로 뻗었다가 흐려진다.
class GroundCrack extends PositionComponent {
  GroundCrack({required super.position, required this.radius})
    : super(priority: 1);

  final double radius;
  static const double duration = 0.7;
  double _life = 0;
  late final List<List<Offset>> _cracks;
  static final _random = math.Random();

  static final _dark = Paint()
    ..color = const Color(0xFF2A1E18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round;
  static final _light = Paint()
    ..color = const Color(0xFFFFC27A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  Future<void> onLoad() async {
    _cracks = [
      for (var i = 0; i < 7; i++)
        _crack(math.pi * 2 * i / 7 + _random.nextDouble() * 0.5),
    ];
  }

  List<Offset> _crack(double angle) {
    final points = [Offset.zero];
    var a = angle;
    var r = 0.0;
    final end = radius * (0.6 + _random.nextDouble() * 0.4);
    while (r < end) {
      r += radius * 0.18;
      a += (_random.nextDouble() - 0.5) * 0.7;
      points.add(Offset(math.cos(a) * r, math.sin(a) * r));
    }
    return points;
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    final grow = math.min(1.0, t / 0.15);
    _dark.color = const Color(0xFF2A1E18).withValues(alpha: 0.85 * (1 - t));
    _light.color = const Color(0xFFFFC27A).withValues(alpha: 0.8 * (1 - t));
    for (final crack in _cracks) {
      final n = math.max(2, (crack.length * grow).ceil());
      final path = Path()..addPolygon(crack.take(n).toList(), false);
      canvas
        ..drawPath(path, _dark)
        ..drawPath(path, _light);
    }
  }
}
