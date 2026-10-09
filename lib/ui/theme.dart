import 'package:flutter/material.dart';

abstract final class AshColors {
  static const ember = Color(0xFFFF6B35);
  static const gold = Color(0xFFE8C887);
  static const parchment = Color(0xFFF3E3C3);
  static const ash = Color(0xFF9A8F88);
  static const night = Color(0xFF0B0908);
  static const panel = Color(0xE01A1411);
}

/// 픽셀 한글 글꼴 Galmuri11 (Bold). 제목 · 버튼 · 로고에 쓴다.
const pixelFont = 'Galmuri11';

ThemeData buildAshTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AshColors.ember,
    brightness: Brightness.dark,
  ),
);

/// 픽셀 글꼴의 금빛 제목 글씨. 번지지 않는 짙은 그림자를 아래로 떨군다.
TextStyle ashTitleStyle(double size) => TextStyle(
  color: AshColors.gold,
  fontFamily: pixelFont,
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: size * 0.04,
  shadows: [
    Shadow(color: const Color(0xFF3A1A0E), offset: Offset(0, size * 0.1)),
    const Shadow(color: Color(0x66FF6B35), blurRadius: 12),
  ],
);
