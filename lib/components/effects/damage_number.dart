import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../game/world/run_world.dart';

/// 맞은 적 위로 떠올랐다 사라지는 피해 숫자. 치명타는 크고 노랗다.
class DamageNumber extends TextComponent with HasWorldReference<RunWorld> {
  DamageNumber({
    required super.position,
    required double amount,
    required bool crit,
    Color color = const Color(0xFFFFFFFF),
  }) : super(
         text: crit ? '${amount.round()}!' : '${amount.round()}',
         anchor: Anchor.center,
         priority: 7,
         textRenderer: crit ? _crit : _paint(color),
       );

  /// 속성 색마다 한 번만 만든다.
  static final _paints = <Color, TextPaint>{};
  static TextPaint _paint(Color color) => _paints.putIfAbsent(
    color,
    () => TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        shadows: _shadows,
      ),
    ),
  );

  static const double duration = 0.6;

  /// 사라질 때까지 떠오르는 거리.
  static const double rise = 28;

  /// 한꺼번에 떠 있을 수 있는 수. 넘으면 새 숫자는 띄우지 않는다.
  static const int maxAlive = 60;

  static const _shadows = [Shadow(blurRadius: 2)];
  static final _crit = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 20,
      fontWeight: FontWeight.w900,
      shadows: _shadows,
    ),
  );

  double _life = 0;

  @override
  void onMount() {
    super.onMount();
    world.damageNumbers++;
  }

  @override
  void onRemove() {
    world.damageNumbers--;
    super.onRemove();
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) {
      removeFromParent();
      return;
    }
    position.y -= rise / duration * dt;
    // 처음엔 크게 튀어나왔다가 끝에서 작아지며 사라진다.
    final t = _life / duration;
    scale.setAll(
      t < 0.15
          ? 1.4 - t / 0.15 * 0.4
          : t > 0.75
          ? (1 - t) / 0.25
          : 1,
    );
  }
}

/// 머리 위로 떠올랐다 사라지는 짧은 글씨 ('콤보!', '맹공!', '튕겨내기!').
class CallOut extends TextComponent {
  CallOut({
    required super.position,
    required String text,
    Color color = const Color(0xFFFFFFFF),
    double fontSize = 14,
  }) : super(
         text: text,
         anchor: Anchor.center,
         priority: 9,
         textRenderer: TextPaint(
           style: TextStyle(
             color: color,
             fontSize: fontSize,
             fontWeight: FontWeight.w900,
             shadows: const [Shadow(blurRadius: 3)],
           ),
         ),
       );

  static const double duration = 0.7;
  double _life = 0;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) {
      removeFromParent();
      return;
    }
    position.y -= 30 * dt;
    final t = _life / duration;
    scale.setAll(
      t < 0.12 ? 1.5 - t / 0.12 * 0.5 : (t > 0.8 ? (1 - t) / 0.2 : 1),
    );
  }
}
