import 'dart:ui';

import 'stats.dart';

/// 피해 속성. 각 속성은 더해 주는 능력치와 줄여 주는 능력치가 있다.
enum DamageType {
  physical('물리', StatType.physicalDamage, StatType.physicalReduction),
  fire('화염', StatType.fireDamage, StatType.fireResist),
  cold('냉기', StatType.coldDamage, StatType.coldResist),
  lightning('번개', StatType.lightningDamage, StatType.lightningResist),
  wind('바람', StatType.windDamage, StatType.windResist);

  const DamageType(this.label, this.added, this.reduction);

  final String label;
  final StatType added;
  final StatType reduction;
}

/// 타격 불꽃과 피해 숫자 색. 치명타는 금빛.
Color hitColor(DamageType type, {bool crit = false}) {
  if (crit) return const Color(0xFFFFD54F);
  return switch (type) {
    DamageType.physical => const Color(0xFFFFF1D6),
    DamageType.fire => const Color(0xFFFF9A3D),
    DamageType.cold => const Color(0xFF9FE0FF),
    DamageType.lightning => const Color(0xFFFFF27A),
    DamageType.wind => const Color(0xFF9CF0C0),
  };
}

/// 속성별로 나뉜 한 번의 타격.
class Hit {
  Hit([Map<DamageType, double>? parts]) : parts = parts ?? {};

  final Map<DamageType, double> parts;
  bool crit = false;

  double operator [](DamageType type) => parts[type] ?? 0;

  void add(DamageType type, double amount) {
    if (amount <= 0) return;
    parts.update(type, (v) => v + amount, ifAbsent: () => amount);
  }

  void scale(double factor) => parts.updateAll((_, v) => v * factor);

  double get total => parts.values.fold(0, (sum, v) => sum + v);

  /// 가장 큰 몫의 속성. 피해 숫자 · 타격 불꽃 색을 정한다.
  DamageType get main {
    var best = DamageType.physical;
    var most = -1.0;
    parts.forEach((type, v) {
      if (v > most) {
        most = v;
        best = type;
      }
    });
    return best;
  }
}
