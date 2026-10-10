import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/damage_number.dart';
import '../effects/ground_fx.dart';
import '../effects/pixel_fx.dart';
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
    final strike = SwordStrike(
      move: move,
      angle: math.atan2(_aim.y, _aim.x),
      sizeScale: size,
      fury: inOnslaught,
      awakened: awakened,
      onImpact: (strike) => _impact(move, strike.aimAngle),
    );
    // 내려찍기는 뛰어올랐다가 칼과 함께 떨어진다. 착지하는 순간이 타격이다.
    if (move == SwordMove.slam) {
      player.leap(strike.duration * strike.impactAt, Balance.slamLeap);
    }
    world.add(strike);
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
          EarthSpikes(
            position: center.clone(),
            radius: Balance.slamRadius * size,
            ember: inOnslaught || awakened,
          ),
        )
        ..add(
          Ring(
            position: center.clone(),
            radius: Balance.slamRadius * size * 1.15,
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
        ..shake(0.22);
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
    SwordMove.slam => 0.62,
  };

  /// 전체 시간 중 칼이 닿는 비율.
  double get impactAt => switch (move) {
    SwordMove.thrust => 0.4,
    SwordMove.swing => 0.45,
    SwordMove.slam => 0.65,
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

  /// 칼자국 색 단계: 바깥 날 → 안쪽.
  List<Color> get _trailTones => [
    Pal.white,
    Color.lerp(_trailColor, Pal.white, 0.4)!,
    _trailColor,
    Color.lerp(_trailColor, Pal.steelDeep, 0.5)!,
  ];

  static double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();
  static double _easeIn(double t) => t * t * t;

  @override
  void render(Canvas canvas) {
    final t = _progress;
    final fade = t > 0.75 ? 1 - (t - 0.75) / 0.25 : 1.0;
    // 칼을 가슴 높이에서 쥔다. 뛰어올라 있으면 몸을 따라 올라간다.
    canvas.translate(0, -8 - world.player.leapLift);
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
      // 칼끝을 따라 뻗는 도트 쐐기: 칼날 쪽은 하얗고 뒤로 갈수록 칼자국 색.
      final streak = (t - 0.32) / 0.68;
      final w = Balance.thrustWidth * sizeScale * 0.5 * (1 - streak * 0.6);
      final tip = grip + _blade + 10;
      final pc = PixelCanvas.fine;
      final px = pc.px;
      final tones = _trailTones;
      final thin = PixelFx.fade(streak, from: 0.3);
      for (var x = (10 / px).floor(); x <= (tip / px).ceil(); x++) {
        final k = ((x + 0.5) * px - 10) / (tip - 10);
        final half = w / 2 * (1 - k);
        final rows = (half / px).ceil();
        for (var y = -rows; y < rows; y++) {
          if (PixelFx.thinned(x, y, thin)) continue;
          final edge = (y + 0.5).abs() * px / math.max(half, 1);
          pc.dot(x, y, tones[edge > 0.7 ? 2 : (k > 0.6 ? 0 : 1)]);
        }
      }
      canvas
        ..save()
        ..rotate(aimAngle);
      pc.flush(canvas);
      canvas.restore();
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
      // 꼬리는 가늘고 칼날 쪽은 두꺼운 도트 초승달 칼자국. 바깥 날은 하얗게 빛난다.
      final pc = PixelCanvas.fine;
      PixelFx.glow(
        canvas,
        Offset(math.cos(angle), math.sin(angle)) * radius * 0.7,
        radius * 0.6,
        _trailColor,
        strength: 0.35 * fade,
      );
      PixelFx.arc(
        pc,
        radius * 0.5,
        radius * 0.98,
        from,
        angle - from,
        _trailTones,
        thin: PixelFx.fade(t, from: 0.6),
      );
      pc.flush(canvas);
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
