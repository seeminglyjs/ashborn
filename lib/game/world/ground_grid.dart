import 'dart:ui';

import 'package:flame/components.dart';

import '../ashborn_game.dart';

/// 끝없는 바닥 격자. 이동감을 주기 위해 카메라가 보는 영역에만 그린다.
/// 색은 지금 지역을 따른다.
class GroundGrid extends Component with HasGameReference<AshbornGame> {
  GroundGrid() : super(priority: -100);

  static const double spacing = 64;

  final _paint = Paint()..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    _paint.color = game.world.stage.region.grid;
    final rect = game.camera.visibleWorldRect;
    for (
      var x = (rect.left / spacing).floor() * spacing;
      x <= rect.right;
      x += spacing
    ) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), _paint);
    }
    for (
      var y = (rect.top / spacing).floor() * spacing;
      y <= rect.bottom;
      y += spacing
    ) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), _paint);
    }
  }
}
