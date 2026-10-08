import 'dart:ui';

import 'package:flame/components.dart';

/// 플레이어가 맞으면 화면 가장자리가 잠깐 붉어진다.
class HitVignette extends PositionComponent {
  HitVignette() : super(priority: 10);

  static const double duration = 0.35;
  static const color = Color(0xAAE53935);

  final _paint = Paint();
  double _life = 0;

  bool get isShowing => _life > 0;

  void flash() => _life = duration;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    final center = (size / 2).toOffset();
    _paint.shader = Gradient.radial(
      center,
      center.distance,
      [const Color(0x00000000), color],
      [0.55, 1],
    );
  }

  @override
  void update(double dt) {
    if (_life > 0) _life -= dt;
  }

  @override
  void render(Canvas canvas) {
    if (_life <= 0) return;
    _paint.color = Color.fromRGBO(0, 0, 0, _life / duration);
    canvas.drawRect(size.toRect(), _paint);
  }
}
