import 'package:flutter/material.dart';

abstract final class AshColors {
  static const ember = Color(0xFFFF6B35);
  static const gold = Color(0xFFE8C887);
  static const parchment = Color(0xFFF3E3C3);
  static const ash = Color(0xFF9A8F88);
  static const night = Color(0xFF0B0908);
  static const panel = Color(0xE01A1411);
}

ThemeData buildAshTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AshColors.ember,
    brightness: Brightness.dark,
  ),
);

/// 금박 느낌의 제목 글씨.
TextStyle ashTitleStyle(double size) => TextStyle(
  color: AshColors.gold,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: size * 0.12,
  shadows: const [
    Shadow(color: Color(0xAAFF6B35), blurRadius: 18),
    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
  ],
);
