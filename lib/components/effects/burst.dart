import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

/// 퍼져 나가며 사라지는 고리. 폭발이나 냉기 파동을 보여 준다.
class Burst extends CircleComponent {
  Burst({required super.position, required double radius, required Color color})
    : super(
        radius: radius,
        anchor: Anchor.center,
        scale: Vector2.all(0.3),
        paint: Paint()..color = color.withValues(alpha: 0.45),
        priority: 6,
      );

  static const double duration = 0.3;

  @override
  Future<void> onLoad() async {
    addAll([
      ScaleEffect.to(Vector2.all(1), EffectController(duration: duration)),
      OpacityEffect.fadeOut(EffectController(duration: duration)),
      RemoveEffect(delay: duration),
    ]);
  }
}

/// 두 점을 잇는 번개 줄기. 잠깐 보였다 사라진다.
class LightningArc extends Component {
  LightningArc(this.from, this.to) : super(priority: 6);

  final Vector2 from;
  final Vector2 to;
  double _life = 0.15;

  static final _paint = Paint()
    ..color = const Color(0xFFFFF27A)
    ..strokeWidth = 2.5;

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) =>
      canvas.drawLine(from.toOffset(), to.toOffset(), _paint);
}

/// 퍼져 나가는 테두리 고리. 충격파 무기의 연출이다 (피해는 무기가 따로 준다).
class Ring extends PositionComponent {
  Ring({
    required super.position,
    required this.radius,
    required Color color,
    this.duration = 0.35,
    this.strokeWidth = 6,
  }) : _paint = Paint()
         ..color = color
         ..style = PaintingStyle.stroke,
       _color = color,
       super(priority: 6);

  final double radius;
  final double duration;
  final double strokeWidth;
  final Paint _paint;
  final Color _color;
  double _life = 0;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    _paint
      ..strokeWidth = strokeWidth * (1 - t * 0.5)
      ..color = _color.withValues(alpha: 1 - t);
    canvas.drawCircle(Offset.zero, radius * (0.25 + 0.75 * t), _paint);
  }
}

/// 하늘에서 내리꽂히는 벼락 줄기. 꺾인 선을 잠깐 보였다 지운다.
class LightningBolt extends PositionComponent {
  LightningBolt({
    required super.position,
    required this.color,
    this.length = 220,
  }) : super(priority: 9);

  final Color color;
  final double length;
  double _life = 0.18;
  late final List<Offset> _points;

  static final _random = math.Random();

  @override
  Future<void> onLoad() async {
    _points = [
      for (var i = 0; i <= 8; i++)
        Offset(
          i == 8 ? 0 : (_random.nextDouble() - 0.5) * 22,
          -length + length * i / 8,
        ),
    ];
  }

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final path = Path()..addPolygon(_points, false);
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      )
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
  }
}
