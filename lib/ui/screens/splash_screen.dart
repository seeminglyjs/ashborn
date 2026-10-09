import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../routes.dart';
import '../widgets/dungeon_backdrop.dart';
import '../widgets/ember_field.dart';
import '../widgets/pixel_sprite.dart';
import 'title_screen.dart';

/// 검은 화면에서 불씨가 고동치듯 솟다가 화톳불이 피어오른다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const duration = Duration(milliseconds: 4600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: SplashScreen.duration,
  )..forward().whenComplete(_finish);

  bool _done = false;

  /// 심장 박동 시각(초). 점점 빨라지고 세진다.
  static const _beats = [
    (0.35, 0.55),
    (0.62, 0.35),
    (1.30, 0.75),
    (1.55, 0.5),
    (2.10, 1.0),
    (2.30, 0.8),
  ];

  static double _seconds(double t) =>
      t * SplashScreen.duration.inMilliseconds / 1000;

  static double _heartbeat(double s) {
    var v = 0.0;
    for (final (at, strength) in _beats) {
      final d = (s - at) / 0.08;
      v += strength * math.exp(-d * d);
    }
    return v.clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    // 타이틀과 캐릭터 선택에 쓸 픽셀 시트를 미리 읽어 둔다.
    PixelImages.preload([
      PixelScene.tilesAsset,
      PixelScene.columnAsset,
      PixelScene.campfireAsset,
      for (final c in Roster.all) 'assets/images/${c.sprite}',
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(
      fadeRoute(
        const TitleScreen(),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final fireSize = math.min(size.height * 0.62, size.width * 0.42);
            final center = Offset(size.width / 2, size.height * 0.54);
            final base = center + Offset(0, fireSize * 0.12);

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final s = _seconds(_controller.value);
                final beat = _heartbeat(s);
                final rise = Curves.easeOutCubic.transform(
                  ((s - 2.25) / 1.0).clamp(0.0, 1.0),
                );
                final fadeOut = ((s - 4.0) / 0.6).clamp(0.0, 1.0);
                final emberRate = s < 2.4 ? 4 + 160 * beat : 26.0 + 40 * beat;
                final glow = math.max(beat, rise * 0.75);

                return Stack(
                  children: [
                    // 고동치는 불빛
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GlowPainter(
                          center: base,
                          radius: fireSize * (0.45 + 0.35 * glow),
                          opacity: 0.08 + 0.55 * glow,
                        ),
                      ),
                    ),
                    // 피어오르는 픽셀 화톳불
                    Positioned(
                      left: center.dx - fireSize / 2,
                      top:
                          center.dy -
                          fireSize / 2 +
                          (1 - rise) * fireSize * 0.18,
                      width: fireSize,
                      height: fireSize,
                      child: Opacity(
                        opacity: rise,
                        child: Center(
                          child: PixelSprite(
                            asset: PixelScene.campfireAsset,
                            frameSize: const Size(16, 24),
                            count: 6,
                            fps: 10,
                            scale: (fireSize / 24).floorToDouble(),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: EmberField(
                        origin: base,
                        spread: fireSize * 0.3,
                        rate: emberRate,
                        rise: size.height * 0.55,
                        scale: (fireSize / 300).clamp(0.6, 1.6),
                      ),
                    ),
                    if (fadeOut > 0)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: fadeOut),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.center,
    required this.radius,
    required this.opacity,
  });

  final Offset center;
  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || radius <= 0) return;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: opacity.clamp(0, 1)),
            const Color(0x00B3261E),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.center != center || old.radius != radius || old.opacity != opacity;
}
