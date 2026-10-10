import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../game/world/run_world.dart';
import '../effects/pixel_fx.dart';
import '../effects/sparks.dart';
import '../weapons/weapon_art.dart';

/// 적 공격 테두리 색. 적의 탄 · 장판 · 충격파 · 예고선은 모두 이 빨간 테두리를 둘러
/// 도트로 그린 내 공격과 한눈에 갈린다.
const enemyOutline = Color(0xFFFF1F3D);

/// 적 공격 테두리 붓. [width] 굵기로 그린다.
Paint dangerStroke(double width, [double opacity = 1]) => Paint()
  ..color = enemyOutline.withValues(alpha: opacity.clamp(0, 1))
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// 두 점 사이 적 예고선 (돌진 경로): 옅게 칠한 띠에 빨간 테두리.
void drawDangerLane(
  Canvas canvas,
  Offset from,
  Offset to,
  double width,
  Color fill,
) {
  final d = to - from;
  if (d.distance < 1) return;
  final angle = math.atan2(d.dy, d.dx);
  final rect = Rect.fromLTWH(0, -width / 2, d.distance, width);
  final shape = RRect.fromRectAndRadius(rect, Radius.circular(width / 2));
  canvas
    ..save()
    ..translate(from.dx, from.dy)
    ..rotate(angle)
    ..drawRRect(shape, Paint()..color = fill)
    ..drawRRect(shape, dangerStroke(2.5))
    ..restore();
}

/// 적의 폭발 (자폭 · 장판이 터질 때). 매끈한 원에 빨간 테두리.
class HostileBurst extends PositionComponent {
  HostileBurst({
    required super.position,
    required this.radius,
    required this.color,
  }) : super(priority: 6);

  final double radius;
  final Color color;
  static const double duration = 0.32;
  double _life = 0;
  final _fill = Paint();

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    final r = radius * (0.3 + 0.7 * (1 - (1 - t) * (1 - t)));
    _fill.color = color.withValues(alpha: 0.45 * (1 - t));
    canvas
      ..drawCircle(Offset.zero, r, _fill)
      ..drawCircle(Offset.zero, r, dangerStroke(3, 1 - t));
  }
}

/// 적이 남긴 공격 (탄 · 장판 · 충격파). 플레이어에게만 피해를 준다.
/// 보스를 잡으면 졸개와 함께 모두 사라진다.
abstract class Hazard extends PositionComponent
    with HasWorldReference<RunWorld> {
  Hazard({required super.position, super.priority = 5})
    : super(anchor: Anchor.center);

  /// 플레이어 중심이 [at] 에서 [reach] 안에 있는가 (플레이어 몸 크기 포함).
  bool touchesPlayer(Vector2 at, double reach) {
    final r = reach + Balance.playerRadius;
    return world.player.position.distanceToSquared(at) <= r * r;
  }
}

/// 곧게 날아가는 적 탄. 플레이어에 닿으면 사라진다.
class EnemyBullet extends Hazard {
  EnemyBullet({
    required super.position,
    required Vector2 direction,
    required this.damage,
    required this.type,
    required this.color,
    double speed = Balance.enemyBulletSpeed,
    this.radius = Balance.enemyBulletRadius,
  }) : velocity = (direction.isZero() ? Vector2(1, 0) : direction.normalized())
         ..scale(speed),
       super(priority: 6);

  final Vector2 velocity;
  final double damage;
  final DamageType type;
  final Color color;
  final double radius;
  double _life = Balance.enemyBulletLifetime;

  late final _glow = Paint()..color = color.withValues(alpha: 0.35);
  late final _core = Paint()..color = color;
  static final _center = Paint()..color = const Color(0xFFFFFFFF);
  static final _edge = dangerStroke(2);

  @override
  void onMount() {
    super.onMount();
    world.enemyBullets++;
  }

  @override
  void onRemove() {
    world.enemyBullets--;
    super.onRemove();
  }

  @override
  void update(double dt) {
    position.addScaled(velocity, dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    if (touchesPlayer(position, radius * 0.7)) {
      world.player.takeDamage(damage, type: type);
      world.add(Sparks(position: position.clone(), color: color, count: 4));
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawCircle(Offset.zero, radius * 1.8, _glow)
      ..drawCircle(Offset.zero, radius, _core)
      ..drawCircle(Offset.zero, radius * 0.45, _center)
      ..drawCircle(Offset.zero, radius + 1.5, _edge);
  }
}

/// 바닥에 예고 원을 그린 뒤 [delay] 초 뒤 터지는 장판. [linger] 가 있으면 터진 자리가
/// 그 시간 동안 타오르며 들어온 플레이어를 계속 아프게 한다.
class GroundBlast extends Hazard {
  GroundBlast({
    required super.position,
    required this.radius,
    required this.damage,
    required this.type,
    required this.color,
    this.delay = Balance.casterBlastDelay,
    this.linger = 0,
  }) : super(priority: -50);

  final double radius;
  final double damage;
  final DamageType type;
  final Color color;
  final double delay;
  final double linger;
  double _time = 0;
  bool _exploded = false;

  static final _ring = dangerStroke(3);
  static final _burnEdge = dangerStroke(2, 0.8);
  late final _fill = Paint()..color = color.withValues(alpha: 0.28);
  late final _burn = Paint()..color = color.withValues(alpha: 0.35);

  bool get exploded => _exploded;

  @override
  void update(double dt) {
    _time += dt;
    if (!_exploded && _time >= delay) {
      _exploded = true;
      world.add(
        HostileBurst(position: position.clone(), radius: radius, color: color),
      );
      world.add(Sparks(position: position.clone(), color: color, count: 10));
      if (touchesPlayer(position, radius)) {
        world.player.takeDamage(damage, type: type);
      }
      world.shake(0.15);
    }
    if (_exploded) {
      if (_time >= delay + linger) {
        removeFromParent();
      } else if (linger > 0 && touchesPlayer(position, radius * 0.85)) {
        // 무적 시간이 있어 매 프레임 불러도 0.5초에 한 번만 아프다.
        world.player.takeDamage(damage * 0.5, type: type);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_exploded) {
      final flicker = 0.85 + 0.15 * math.sin(_time * 18);
      canvas
        ..drawCircle(Offset.zero, radius * 0.85 * flicker, _burn)
        ..drawCircle(Offset.zero, radius * 0.85, _burnEdge);
      return;
    }
    // 예고: 테두리 안에서 채움 원이 자라 테두리에 닿으면 터진다.
    canvas
      ..drawCircle(Offset.zero, radius, _ring)
      ..drawCircle(Offset.zero, radius * (_time / delay), _fill);
  }
}

/// 타락 특수 규칙 "잿불 유해": 쓰러진 졸개 자리에 남아 예고 뒤 터지는 작은 장판.
/// 한꺼번에 너무 많이 깔리지 않도록 월드가 수를 센다 ([RunWorld.deathBlasts]).
class DeathBlast extends GroundBlast {
  DeathBlast({
    required super.position,
    required super.damage,
    required super.type,
    required super.color,
  }) : super(radius: Balance.deathBlastRadius, delay: Balance.deathBlastDelay);

  @override
  void onMount() {
    super.onMount();
    world.deathBlasts++;
  }

  @override
  void onRemove() {
    world.deathBlasts--;
    super.onRemove();
  }
}

/// 보스 내려찍기의 지진파. 땅이 갈라지며 금이 뻗어 나가고, 그 끝에서 흙 둔덕이 고리를 이루며
/// 밀려 나간다. 둔덕이 지나가는 순간 플레이어에게 한 번 피해. 둔덕을 뛰어넘을 수는 없지만
/// [speed] 가 플레이어보다 조금 느려서, 예고를 보고 바로 바깥으로 달리면 따돌릴 수 있다.
///
/// 흙 · 금은 도트로 그리되 적 공격이므로 둔덕 바깥에 빨간 테두리를 두른다. 금 속 빛은 피해 속성 색.
class Shockwave extends Hazard {
  Shockwave({
    required super.position,
    required this.maxRadius,
    required this.damage,
    required this.type,
    required this.color,
    double speed = Balance.bossSlamSpeed,
  }) : duration = maxRadius / speed,
       _salt = _random.nextInt(1 << 16),
       super(priority: -40);

  final double maxRadius;
  final double damage;
  final DamageType type;
  final Color color;
  final double duration;
  final int _salt;
  static const double thickness = 16;

  /// 둔덕이 퍼지는 동안 화면이 낮게 계속 흔들리는 세기.
  static const double rumble = 0.08;

  static final _random = math.Random();

  // 흙 둔덕 색 (Endesga 32, 바깥 → 안쪽): 솟은 흙 등의 밝은 면에서 패인 그늘로.
  static const _rubble = [
    Color(0xFFEAD4AA),
    Color(0xFFE4A672),
    Pal.leatherLight,
    Pal.leather,
    Color(0xFF3E2731),
  ];
  static const _crevice = Color(0xFF3E2731);

  double _time = 0;
  bool _hit = false;

  /// 가운데서 뻗는 금. 점마다 가운데로부터의 거리를 함께 두어, 둔덕이 지나간 곳까지만 그린다.
  late final List<List<(Offset, double)>> _cracks = [
    for (var i = 0; i < 9; i++)
      _crack(math.pi * 2 * i / 9 + _random.nextDouble() * 0.5),
  ];

  List<(Offset, double)> _crack(double angle) {
    final points = [(Offset.zero, 0.0)];
    var a = angle;
    var r = 0.0;
    final end = maxRadius * (0.55 + _random.nextDouble() * 0.4);
    while (r < end) {
      r += 14 + _random.nextDouble() * 10;
      a += (_random.nextDouble() - 0.5) * 0.6;
      points.add((Offset(math.cos(a) * r, math.sin(a) * r), r));
    }
    return points;
  }

  /// 둔덕 위 바위 덩어리: 둘레 위 각도, 크기(칸), 들썩이는 박자.
  late final List<(double, int, double)> _rocks = [
    for (var i = 0; i < 22; i++)
      (
        math.pi * 2 * (i + _random.nextDouble() * 0.6) / 22,
        4 + _random.nextInt(3),
        _random.nextDouble() * math.pi,
      ),
  ];

  /// 금 속 빛: 어두운 틈과 속성 색 사이. 이 거리만큼 둔덕 뒤까지만 빛난다.
  late final _glow = Color.lerp(_crevice, color, 0.55)!;
  static const double _glowBehind = 45;

  double get _radius => maxRadius * (_time / duration);

  @override
  void update(double dt) {
    _time += dt;
    if (_time >= duration) {
      removeFromParent();
      return;
    }
    world.shake(rumble);
    if (_hit) return;
    final d = world.player.position.distanceTo(position);
    if ((d - _radius).abs() <= thickness / 2 + Balance.playerRadius * 0.6) {
      _hit = true;
      world.player.takeDamage(damage, type: type);
    }
  }

  @override
  void render(Canvas canvas) {
    final t = _time / duration;
    final radius = _radius;
    final pc = PixelCanvas.shared;
    // 갈라진 금: 어두운 틈. 둔덕 바로 뒤 막 벌어진 틈에만 속성 빛이 비친다.
    for (final crack in _cracks) {
      for (var i = 0; i < crack.length - 1 && crack[i + 1].$2 <= radius; i++) {
        PixelFx.line(pc, crack[i].$1, crack[i + 1].$1, _crevice, width: 2);
      }
    }
    for (final crack in _cracks) {
      for (var i = 0; i < crack.length - 1 && crack[i + 1].$2 <= radius; i++) {
        if (radius - crack[i + 1].$2 > _glowBehind) continue;
        PixelFx.line(pc, crack[i].$1, crack[i + 1].$1, _glow);
      }
    }
    pc.flush(canvas, opacity: 1 - PixelFx.fade(t, from: 0.6) / 4);
    // 밀려 나가는 흙 둔덕. 칸마다 들쭉날쭉해 퍼지는 동안 흙이 들끓는 듯 보인다.
    final outer = radius + thickness / 2;
    PixelFx.ring(pc, outer, 4, _rubble.sublist(1), jitter: 9, salt: _salt);
    // 둔덕 위로 들썩이는 바위 덩어리. 빛은 왼쪽 위라 윗줄 · 왼줄이 밝다.
    final px = pc.px;
    for (final (angle, size, phase) in _rocks) {
      final at = Offset(math.cos(angle), math.sin(angle)) * (radius + 2);
      final lift = (math.sin(_time * 14 + phase).abs() * 3).round();
      final cx = (at.dx / px).floor() - size ~/ 2;
      final cy = (at.dy / px).floor() - size ~/ 2 - lift;
      // 들린 만큼 바닥에 그림자.
      for (var x = 1; x < size; x++) {
        pc.dot(cx + x, cy + size + lift, _crevice);
      }
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          // 모서리를 깎아 네모가 아닌 돌덩이로.
          if ((x == 0 || x == size - 1) && (y == 0 || y == size - 1)) continue;
          final edge = x == 0 || y == 0 || x == size - 1 || y == size - 1;
          final color = edge && (x == size - 1 || y == size - 1)
              ? _crevice
              : y == 0 || x == 0
              ? _rubble[0]
              : _rubble[1];
          pc.dot(cx + x, cy + y, color);
        }
      }
    }
    pc.flush(canvas);
    canvas
      ..drawCircle(Offset.zero, outer + 2, dangerStroke(2.5, 1 - t * 0.5))
      ..drawCircle(
        Offset.zero,
        math.max(0, radius - thickness / 2),
        dangerStroke(1.5, 0.6 * (1 - t)),
      );
  }
}
