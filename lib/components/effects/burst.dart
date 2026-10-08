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
