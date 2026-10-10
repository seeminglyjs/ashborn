import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../weapons/weapon_art.dart';
import 'pixel_fx.dart';

/// 내 공격이 터지는 자리: 하얀 속에서 색 · 어둠으로 식어 가는 도트 불덩이와 사방으로 뻗는 섬광.
/// 불빛 색이면 불 색 단계를, 아니면 [color] 의 밝은 · 본 · 어두운 세 단계를 쓴다.
/// 적의 폭발은 [HostileBurst] (빨간 테두리) 를 쓴다.
class Burst extends PositionComponent {
  Burst({required super.position, required this.radius, required this.color})
    : _salt = _random.nextInt(1 << 20),
      super(priority: 6);

  final double radius;
  final Color color;
  final int _salt;
  static const double duration = 0.36;
  static final _random = math.Random();
  double _life = 0;

  /// 주황 · 노랑 계열이면 불 색 단계로 그린다.
  bool get _fiery {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return r > 200 && g > 60 && g < 215 && b < 120;
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    final grow = 1 - math.pow(1 - math.min(1.0, t / 0.4), 3).toDouble();
    final r = radius * (0.35 + 0.65 * grow);
    final List<Color> ramp = _fiery
        ? FxTones.fire
        : [Pal.white, ...PixelFx.tones(color)];
    PixelFx.glow(
      canvas,
      Offset.zero,
      r * 1.7,
      ramp[2],
      strength: 0.6 * (1 - t),
    );
    final pc = PixelCanvas.shared;
    final thin = PixelFx.fade(t, from: 0.45);
    // 바깥은 식은 색, 안으로 갈수록 뜨겁다. 시간이 갈수록 뜨거운 속이 줄어든다.
    PixelFx.disc(
      pc,
      r,
      [ramp.last, ramp[ramp.length - 2]],
      thin: thin,
      jitter: PixelFx.px * 2.5,
      salt: _salt,
    );
    PixelFx.disc(
      pc,
      r * (0.75 - 0.35 * t),
      [ramp[2], ramp[1]],
      bands: 2,
      thin: thin,
      jitter: PixelFx.px * 2,
      salt: _salt + 1,
    );
    if (t < 0.6) PixelFx.disc(pc, r * 0.32 * (1 - t), [ramp[0]]);
    // 터지는 순간 사방으로 뻗는 섬광.
    if (t < 0.5) {
      PixelFx.rays(
        pc,
        9,
        r * 0.7,
        r * (1.15 + 0.5 * t),
        ramp[1],
        ramp[2],
        salt: _salt,
      );
    }
    pc.flush(canvas);
  }
}

/// 두 점을 잇는 번개 줄기. 지그재그로 꺾이며 깜빡이다 사라진다 (연쇄 번개).
class LightningArc extends Component {
  LightningArc(this.from, this.to, {this.color = const Color(0xFFFFF27A)})
    : super(priority: 6);

  final Vector2 from;
  final Vector2 to;
  final Color color;
  static const double duration = 0.22;
  double _life = duration;
  double _reshape = 0;
  final _points = <Offset>[];

  static final _random = math.Random();

  /// 두 점 사이를 몇 마디로 나눠 옆으로 흔든다. 길수록 마디가 많다.
  void _shape() {
    _points.clear();
    final d = to - from;
    final length = d.length;
    final segments = math.max(3, (length / 18).round());
    final nx = length == 0 ? 0.0 : -d.y / length;
    final ny = length == 0 ? 0.0 : d.x / length;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final off = i == 0 || i == segments
          ? 0.0
          : (_random.nextDouble() - 0.5) * 16;
      _points.add(
        Offset(from.x + d.x * t + nx * off, from.y + d.y * t + ny * off),
      );
    }
  }

  @override
  void update(double dt) {
    _life -= dt;
    _reshape -= dt;
    if (_reshape <= 0) {
      _reshape = 0.05;
      _shape();
    }
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_points.isEmpty) return;
    final pc = PixelCanvas.shared;
    for (var i = 0; i < _points.length - 1; i++) {
      PixelFx.line(pc, _points[i], _points[i + 1], color, width: 2);
    }
    for (var i = 0; i < _points.length - 1; i++) {
      PixelFx.line(pc, _points[i], _points[i + 1], Pal.white);
    }
    pc.flush(canvas);
  }
}

/// 중독 · 점화가 옆의 적에게 옮을 때 잠깐 보이는 점선.
class SpreadArc extends Component {
  SpreadArc(this.from, this.to, this.color) : super(priority: 6);

  final Vector2 from;
  final Vector2 to;
  final Color color;
  static const double duration = 0.35;
  double _life = 0;
  final _paint = Paint();

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    _paint.color = color.withValues(alpha: 1 - t);
    const dots = 6;
    for (var i = 0; i <= dots; i++) {
      final k = i / dots;
      // 옮겨 가는 쪽으로 점이 흘러간다.
      if (k > t * 1.6) break;
      final x = from.x + (to.x - from.x) * k;
      final y = from.y + (to.y - from.y) * k - math.sin(k * math.pi) * 14;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 3, height: 3),
        _paint,
      );
    }
  }
}

/// 퍼져 나가는 도트 충격 고리. 앞쪽 가장자리가 가장 밝고 뒤로 갈수록 어둡다 (피해는 무기가 따로 준다).
class Ring extends PositionComponent {
  Ring({
    required super.position,
    required this.radius,
    required this.color,
    this.duration = 0.35,
    this.strokeWidth = 6,
  }) : _salt = _random.nextInt(1 << 20),
       super(priority: 6);

  final double radius;
  final Color color;
  final double duration;

  /// 고리 두께 (월드). 도트 칸 수로 바꿔 쓴다.
  final double strokeWidth;
  final int _salt;
  static final _random = math.Random();
  double _life = 0;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    final ease = 1 - math.pow(1 - t, 2).toDouble();
    final r = radius * (0.25 + 0.75 * ease);
    final cells = math.max(
      1,
      (strokeWidth / PixelFx.px * (1 - t * 0.6)).round(),
    );
    final tones = PixelFx.tones(color);
    final pc = PixelCanvas.shared;
    PixelFx.ring(
      pc,
      r,
      cells + 1,
      [tones[0], color, tones[2]],
      thin: PixelFx.fade(t, from: 0.5),
      jitter: PixelFx.px * 1.5,
      salt: _salt,
    );
    pc.flush(canvas);
  }
}

/// 하늘에서 내리꽂히는 도트 벼락. 꺾인 줄기에서 잔가지가 갈라지고, 땅에 닿은 자리에 섬광이 튄다.
class LightningBolt extends PositionComponent {
  LightningBolt({
    required super.position,
    required this.color,
    this.length = 220,
  }) : super(priority: 9);

  final Color color;
  final double length;
  static const double duration = 0.22;
  double _life = 0;
  late final List<Offset> _points;
  late final List<(Offset, Offset)> _branches;

  static final _random = math.Random();

  @override
  Future<void> onLoad() async {
    _points = [
      for (var i = 0; i <= 8; i++)
        Offset(
          i == 8 ? 0 : (_random.nextDouble() - 0.5) * 26,
          -length + length * i / 8,
        ),
    ];
    _branches = [
      for (final i in [2, 4, 5])
        if (_random.nextBool())
          (
            _points[i],
            _points[i] +
                Offset(
                  (_random.nextBool() ? 1 : -1) *
                      (14 + _random.nextDouble() * 18),
                  18 + _random.nextDouble() * 14,
                ),
          ),
    ];
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    final tones = PixelFx.tones(color);
    PixelFx.glow(canvas, Offset.zero, 46, color, strength: 0.8 * (1 - t));
    PixelFx.glow(
      canvas,
      Offset(0, -length / 2),
      length * 0.45,
      color,
      strength: 0.25 * (1 - t),
    );
    final pc = PixelCanvas.shared;
    for (var i = 0; i < _points.length - 1; i++) {
      PixelFx.line(pc, _points[i], _points[i + 1], color, width: 3);
    }
    for (final (a, b) in _branches) {
      PixelFx.line(pc, a, b, tones[2], width: 2);
    }
    for (var i = 0; i < _points.length - 1; i++) {
      PixelFx.line(pc, _points[i], _points[i + 1], Pal.white);
    }
    // 땅에 닿은 자리: 위로 튀는 섬광 반원.
    if (t < 0.7) {
      for (var k = 0; k < 7; k++) {
        final a = math.pi + math.pi * (k + 0.5) / 7;
        final len = 14 + 12 * PixelFx.hash(k, 3);
        final dir = Offset(math.cos(a), math.sin(a) * 0.7);
        PixelFx.line(pc, dir * 6, dir * len, k.isEven ? Pal.white : color);
      }
    }
    pc.flush(canvas);
  }
}
