import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// 한 점에서 사방으로 튀었다 사라지는 작은 파편들. 타격 · 처치 · 폭발의 손맛을 더한다.
///
/// 적이 수백이라 파편마다 컴포넌트를 두지 않고 한 컴포넌트가 배열로 그린다.
class Sparks extends PositionComponent {
  Sparks({
    required super.position,
    required this.color,
    this.count = 6,
    this.speed = 160,
    this.sparkSize = 3,
    this.duration = 0.35,
    double? angle,
    this.spread = math.pi * 2,
  }) : _aim = angle,
       super(priority: 7);

  final Color color;
  final int count;
  final double speed;
  final double sparkSize;
  final double duration;

  /// [angle] 을 주면 그 방향 [spread] 부채꼴로만 튄다.
  final double? _aim;
  final double spread;

  static final _random = math.Random();

  late final List<double> _dx;
  late final List<double> _dy;
  double _life = 0;
  final _paint = Paint();

  @override
  Future<void> onLoad() async {
    _dx = List.filled(count, 0);
    _dy = List.filled(count, 0);
    for (var i = 0; i < count; i++) {
      final a = _aim == null
          ? _random.nextDouble() * math.pi * 2
          : _aim + (_random.nextDouble() - 0.5) * spread;
      final v = speed * (0.5 + _random.nextDouble() * 0.7);
      _dx[i] = math.cos(a) * v;
      _dy[i] = math.sin(a) * v;
    }
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    // 빠르게 튀었다가 느려지며 사라진다.
    final travel = (1 - (1 - t) * (1 - t)) * duration;
    _paint.color = color.withValues(alpha: 1 - t);
    final s = sparkSize * (1 - t * 0.6);
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(_dx[i] * travel, _dy[i] * travel),
          width: s,
          height: s,
        ),
        _paint,
      );
    }
  }
}
