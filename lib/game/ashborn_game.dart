import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Ashborn 게임 루트. 지역, 웨이브, 플레이어 등은 이후 단계에서 추가한다.
class AshbornGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF1A1414);

  @override
  Future<void> onLoad() async {
    add(
      TextComponent(
        text: 'ASHBORN',
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }
}
