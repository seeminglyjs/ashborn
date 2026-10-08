import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../data/balance.dart';

/// 적이 쓰러질 때 잠깐 퍼지는 잿가루.
class DeathPuff extends CircleComponent {
  DeathPuff({required super.position})
    : super(
        radius: Balance.enemyRadius,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xAAB8ADA6),
      );

  static const double duration = 0.25;

  @override
  Future<void> onLoad() async {
    addAll([
      ScaleEffect.to(Vector2.all(1.8), EffectController(duration: duration)),
      OpacityEffect.fadeOut(EffectController(duration: duration)),
      RemoveEffect(delay: duration),
    ]);
  }
}
