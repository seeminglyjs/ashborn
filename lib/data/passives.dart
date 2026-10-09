import 'balance.dart';
import 'stats.dart';

/// 레벨업으로 얻는 패시브 (모든 캐릭터 공용). 레벨마다 [stat] 을 [perLevel] 만큼 올린다.
/// [stat] 이 null 인 것은 능력치가 아니라 무기에 직접 붙는다 (공격 범위).
enum PassiveId {
  vitality('단련된 육체', StatType.maxHp, Balance.passiveMaxHpPerLevel),
  swiftness('재바람', StatType.moveSpeed, Balance.passiveMoveSpeedPerLevel),
  magnetism('불씨 끌림', StatType.magnetRange, Balance.passiveMagnetPerLevel),
  fury('타오르는 의지', StatType.damage, Balance.passiveDamagePerLevel),
  haste('날랜 손', StatType.attackSpeed, Balance.passiveAttackSpeedPerLevel),
  keenEye('매의 눈', StatType.critChance, Balance.passiveCritChancePerLevel),
  brutality('처형자의 낙인', StatType.critDamage, Balance.passiveCritDamagePerLevel),
  ironSkin('잿빛 갑주', StatType.armor, Balance.passiveArmorPerLevel),
  regrowth('재생의 불씨', StatType.hpRegen, Balance.passiveRegenPerLevel),
  wisdom('배움의 재', StatType.xpGain, Balance.passiveXpPerLevel),
  spread('번지는 불길', null, Balance.passiveAreaPerLevel);

  const PassiveId(this.label, this.stat, this.perLevel);

  final String label;
  final StatType? stat;
  final double perLevel;

  /// 카드에 쓰는 한 레벨 효과.
  String get description => switch (stat) {
    final stat? => stat.format(perLevel),
    null => '모든 무기 범위 +${(perLevel * 100).round()}%',
  };

  static const int maxLevel = Balance.passiveMaxLevel;
}
