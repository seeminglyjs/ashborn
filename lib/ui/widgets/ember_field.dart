import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// [origin] 에서 피어올라 흩날리는 불씨 파티클.
///
/// 위젯이 다시 빌드되어도 파티클은 유지되므로 [rate] 를 매 프레임 바꿔
/// 고동치듯 뿜어낼 수 있다.
class EmberField extends StatefulWidget {
  const EmberField({
    super.key,
    required this.origin,
    this.spread = 30,
    this.rate = 20,
    this.rise = 260,
    this.scale = 1,
  });

  /// 위젯 로컬 좌표 기준 발생 지점.
  final Offset origin;

  /// 발생 지점의 가로 퍼짐.
  final double spread;

  /// 초당 생성 수.
  final double rate;

  /// 불씨가 수명 동안 대략 올라가는 높이.
  final double rise;

  /// 크기와 흔들림 배율.
  final double scale;

  @override
  State<EmberField> createState() => _EmberFieldState();
}

class _Ember {
  _Ember(this.x, this.y, this.vx, this.vy, this.life, this.size, this.phase);

  double x, y, vx, vy;
  double age = 0;
  final double life, size, phase;
}

class _EmberFieldState extends State<EmberField>
    with SingleTickerProviderStateMixin {
  static const _maxEmbers = 400;

  final _embers = <_Ember>[];
  final _random = math.Random();
  final _repaint = _Repaint();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _pending = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;

    _pending += widget.rate * dt;
    while (_pending >= 1) {
      _pending -= 1;
      if (_embers.length < _maxEmbers) _spawn();
    }

    final s = widget.scale;
    for (final e in _embers) {
      e.age += dt;
      e.x += (e.vx + math.sin(e.age * 3 + e.phase) * 14 * s) * dt;
      e.y += e.vy * dt;
    }
    _embers.removeWhere((e) => e.age >= e.life);
    _repaint.notify();
  }

  void _spawn() {
    final s = widget.scale;
    final life = 1.2 + _random.nextDouble() * 1.6;
    _embers.add(
      _Ember(
        widget.origin.dx + (_random.nextDouble() - 0.5) * widget.spread,
        widget.origin.dy + (_random.nextDouble() - 0.5) * widget.spread * 0.3,
        (_random.nextDouble() - 0.5) * 30 * s,
        -widget.rise * (0.6 + _random.nextDouble() * 0.6) / life,
        life,
        (0.8 + _random.nextDouble() * 2.2) * s,
        _random.nextDouble() * math.pi * 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EmberPainter(_embers, _repaint),
      ),
    );
  }
}

class _Repaint extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.embers, Listenable repaint) : super(repaint: repaint);

  final List<_Ember> embers;

  static const _hot = Color(0xFFFFF1B5);
  static const _warm = Color(0xFFFF7A2F);
  static const _cool = Color(0xFFB3261E);

  final _paint = Paint()..blendMode = BlendMode.plus;
  final _glow = Paint()
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      final t = e.age / e.life;
      final alpha = t < 0.12 ? t / 0.12 : 1 - (t - 0.12) / 0.88;
      final color = t < 0.4
          ? Color.lerp(_hot, _warm, t / 0.4)!
          : Color.lerp(_warm, _cool, (t - 0.4) / 0.6)!;
      final center = Offset(e.x, e.y);
      final r = e.size * (1 - t * 0.5);
      canvas
        ..drawCircle(
          center,
          r * 2.6,
          _glow..color = color.withValues(alpha: alpha * 0.35),
        )
        ..drawCircle(center, r, _paint..color = color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_EmberPainter oldDelegate) => false;
}
