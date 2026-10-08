import 'dart:ui';

import 'package:flutter/material.dart';

/// 타이틀 원화 (assets/images/title.webp).
abstract final class TitleArt {
  static const asset = 'assets/images/title.webp';
  static const size = Size(1678, 937);

  /// 원화 픽셀 좌표 기준 주요 위치.
  static const fire = Offset(850, 600);
  static const startButton = Rect.fromLTRB(612, 705, 1062, 812);
  static const settingsButton = Rect.fromLTRB(1553, 18, 1633, 98);
}

/// 원화를 화면에 contain 으로 맞췄을 때 원화 좌표를 화면 좌표로 바꾼다.
class ArtSpace {
  factory ArtSpace(Size screen) {
    final fitted = applyBoxFit(BoxFit.contain, TitleArt.size, screen);
    final rect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & screen,
    );
    return ArtSpace._(rect, rect.width / TitleArt.size.width);
  }

  const ArtSpace._(this.rect, this.scale);

  /// 화면에서 원화가 차지하는 영역.
  final Rect rect;
  final double scale;

  Offset point(Offset p) => rect.topLeft + p * scale;

  Rect area(Rect r) => Rect.fromPoints(point(r.topLeft), point(r.bottomRight));
}

/// 화면을 꽉 채우는, 흐리고 어둡게 처리한 원화. 여백 채우기와 배경용.
class BlurredArt extends StatelessWidget {
  const BlurredArt({super.key, this.sigma = 24, this.dim = 0.55});

  final double sigma;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Image.asset(TitleArt.asset, fit: BoxFit.cover),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: dim)),
      ],
    );
  }
}
