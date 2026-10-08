import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';

/// 초월 옵션. 기본 옵션과 랜덤옵션에는 없는 특별한 효과만 있다.
/// 한 장비에 같은 초월 옵션은 붙지 않고, 여러 장비의 초월 옵션은 더해진다.
enum TranscendOption {
  extraProjectiles('투사체', Balance.transcendProjectiles, whole: true),
  bossDamage('보스 피해', Balance.transcendBossDamage),
  healOnKill('처치 시 회복', Balance.transcendHealOnKill),
  thorns('가시', Balance.transcendThorns),
  lastStand('불굴', Balance.transcendLastStand),
  goldFind('골드 획득', Balance.transcendGoldFind);

  const TranscendOption(this.label, this.base, {this.whole = false});

  final String label;

  /// 기본 수치. [whole] 이 아니면 ±[Balance.statVariance] 안에서 굴린다.
  final double base;

  /// 정수로만 붙는 옵션 (투사체 수).
  final bool whole;

  /// 초월 옵션을 보여 줄 색.
  static const color = Color(0xFFFF7AD9);

  String format(double value) {
    String p(double v) => '${(v * 100).round()}%';
    return switch (this) {
      extraProjectiles => '모든 무기 투사체 · 칼날 +${value.round()}',
      bossDamage => '보스에게 주는 피해 +${p(value)}',
      healOnKill => '적 처치 시 체력 ${value.toStringAsFixed(1)} 회복',
      thorns => '부딪힌 적에게 받은 피해의 ${p(value)} 반사',
      lastStand =>
        '체력 ${p(Balance.lastStandThreshold)} 이하일 때 받는 피해 -${p(value)}',
      goldFind => '골드 획득량 +${p(value)}',
    };
  }

  /// [have] 에 없는 초월 옵션 하나를 굴린다.
  static TranscendRoll roll(math.Random random, Set<TranscendOption> have) {
    final options = values.where((o) => !have.contains(o)).toList();
    final option = options[random.nextInt(options.length)];
    final variance = option.whole
        ? 1
        : 1 + (random.nextDouble() * 2 - 1) * Balance.statVariance;
    return (option: option, value: option.base * variance);
  }
}

typedef TranscendRoll = ({TranscendOption option, double value});
