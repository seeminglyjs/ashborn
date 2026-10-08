import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 화톳불이 주변을 일렁이며 비추는 빛.
class FireLight extends StatefulWidget {
  const FireLight({
    super.key,
    required this.center,
    required this.radius,
    this.strength = 0.35,
  });

  final Offset center;
  final double radius;
  final double strength;

  @override
  State<FireLight> createState() => _FireLightState();
}

class _FireLightState extends State<FireLight>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FireLightPainter(widget, _time),
      ),
    );
  }
}

class _FireLightPainter extends CustomPainter {
  _FireLightPainter(this.config, this.time) : super(repaint: time);

  final FireLight config;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final flicker =
        0.10 * math.sin(t * 7.3) +
        0.07 * math.sin(t * 13.1 + 1.3) +
        0.05 * math.sin(t * 23.7 + 2.1);
    final r = config.radius * (1 + flicker * 0.4);
    final rect = Rect.fromCircle(center: config.center, radius: r);
    canvas.drawCircle(
      config.center,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(
              0xFFFF8C42,
            ).withValues(alpha: (config.strength * (1 + flicker)).clamp(0, 1)),
            const Color(0x00FF5A1F),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FireLightPainter oldDelegate) =>
      oldDelegate.config != config;
}
