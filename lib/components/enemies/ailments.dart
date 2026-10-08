import 'dart:math' as math;
import 'dart:ui';

import '../../data/balance.dart';

/// 지속 피해 한 갈래.
class _Dot {
  _Dot(this.dps, this.time);

  double dps;
  double time;

  double tick(double dt) {
    final damage = dps * math.min(dt, time);
    time -= dt;
    return damage;
  }
}

/// 적에게 걸린 상태이상.
///
/// 출혈과 화상은 더 센 쪽으로 갱신되고, 중독은 따로따로 쌓인다.
class Ailments {
  _Dot? _bleed;
  _Dot? _burn;
  final _poison = <_Dot>[];
  double _shockTime = 0;
  double _shockEffect = 0;
  double _chillTime = 0;
  double _chillSlow = 0;

  bool get bleeding => _bleed != null;
  bool get burning => _burn != null;
  int get poisonStacks => _poison.length;
  bool get shocked => _shockTime > 0;
  bool get chilled => _chillTime > 0;

  /// 감전된 동안 받는 피해 배율.
  double get damageTakenMultiplier => shocked ? 1 + _shockEffect : 1;

  /// 동상 동안 이동 속도 배율.
  double get speedMultiplier => chilled ? 1 - _chillSlow : 1;

  /// 걸린 상태이상을 보여 줄 색. 없으면 null.
  Color? get tint {
    if (shocked) return const Color(0xFFFFE45C);
    if (burning) return const Color(0xFFFF8A3D);
    if (poisonStacks > 0) return const Color(0xFF7BD15A);
    if (bleeding) return const Color(0xFFC0392B);
    if (chilled) return const Color(0xFF8FD3FF);
    return null;
  }

  /// [total] 피해를 지속 시간 동안 나눠 준다.
  void bleed(double total) => _bleed = _stronger(
    _bleed,
    total / Balance.bleedDuration,
    Balance.bleedDuration,
  );

  void burn(double total) => _burn = _stronger(
    _burn,
    total / Balance.burnDuration,
    Balance.burnDuration,
  );

  void poison(double total) {
    if (_poison.length >= Balance.poisonMaxStacks) _poison.removeAt(0);
    _poison.add(_Dot(total / Balance.poisonDuration, Balance.poisonDuration));
  }

  void shock(double effect) {
    _shockEffect = shocked ? math.max(_shockEffect, effect) : effect;
    _shockTime = Balance.shockDuration;
  }

  void chill(double slow, double duration) {
    _chillSlow = chilled ? math.max(_chillSlow, slow) : slow;
    _chillTime = math.max(_chillTime, duration);
  }

  static _Dot _stronger(_Dot? current, double dps, double time) =>
      current == null || dps >= current.dps
      ? _Dot(dps, time)
      : (current..time = time);

  /// [dt] 동안 들어간 지속 피해의 합.
  double tick(double dt) {
    if (_shockTime > 0) _shockTime -= dt;
    if (_chillTime > 0) _chillTime -= dt;
    var damage = 0.0;
    if (_bleed case final dot?) {
      damage += dot.tick(dt);
      if (dot.time <= 0) _bleed = null;
    }
    if (_burn case final dot?) {
      damage += dot.tick(dt);
      if (dot.time <= 0) _burn = null;
    }
    for (final dot in _poison) {
      damage += dot.tick(dt);
    }
    _poison.removeWhere((dot) => dot.time <= 0);
    return damage;
  }
}
