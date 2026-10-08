import 'balance.dart';
import 'stats.dart';

/// 레벨업으로 얻는 패시브. 레벨마다 [stat] 을 [perLevel] 만큼 올린다.
enum PassiveId {
  vitality('단련된 육체', StatType.maxHp, Balance.passiveMaxHpPerLevel),
  swiftness('재바람', StatType.moveSpeed, Balance.passiveMoveSpeedPerLevel),
  magnetism('불씨 끌림', StatType.magnetRange, Balance.passiveMagnetPerLevel);

  const PassiveId(this.label, this.stat, this.perLevel);

  final String label;
  final StatType stat;
  final double perLevel;

  static const int maxLevel = Balance.passiveMaxLevel;
}
