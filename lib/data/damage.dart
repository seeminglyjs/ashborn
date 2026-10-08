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
}
