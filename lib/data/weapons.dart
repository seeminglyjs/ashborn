import 'balance.dart';
import 'damage.dart';
import 'passives.dart';

/// 자동 공격 무기 정의. 레벨마다 피해가 늘고 [bonusLabel] 이 주기적으로 는다.
/// 무기 기본 피해는 [damageType] 이고, 장비의 속성 피해가 따로 더해진다.
///
/// 최대 레벨에서 [catalyst] 패시브를 갖고 있으면 [awakenedLabel] 로 각성할 수 있다.
enum WeaponId {
  flameBlade(
    '불꽃 대검',
    '주변을 도는 불꽃 칼날',
    '칼날',
    DamageType.physical,
    catalyst: PassiveId.vitality,
    awakenedLabel: '업화의 대검',
  ),
  emberOrb(
    '잔불 구체',
    '가장 가까운 적을 노리는 불씨',
    '구체',
    DamageType.fire,
    catalyst: PassiveId.magnetism,
    awakenedLabel: '유성 잔불',
  ),
  fireCrossbow(
    '화염 석궁',
    '적을 꿰뚫는 불화살',
    '관통',
    DamageType.physical,
    catalyst: PassiveId.swiftness,
    awakenedLabel: '폭풍 석궁',
  );

  const WeaponId(
    this.label,
    this.description,
    this.bonusLabel,
    this.damageType, {
    required this.catalyst,
    required this.awakenedLabel,
  });

  final String label;
  final String description;
  final String bonusLabel;
  final DamageType damageType;

  /// 각성에 필요한 패시브.
  final PassiveId catalyst;
  final String awakenedLabel;

  /// 각성하면 얻는 효과.
  String get awakenedDescription {
    final damage = '피해 ×${Balance.awakenDamageMultiplier}';
    return switch (this) {
      flameBlade => '$damage, 칼날 +${Balance.infernoBladeBonus}, 더 넓게 돈다',
      emberOrb =>
        '$damage, 맞힌 자리에서 터져 주변 적에게 '
            '${(Balance.meteorRatio * 100).round()}% 피해',
      fireCrossbow =>
        '$damage, 화살 ${Balance.stormArrows}발을 부채꼴로, '
            '관통 +${Balance.stormPierceBonus}',
    };
  }

  static const int maxLevel = Balance.weaponMaxLevel;

  static double damageMultiplier(int level) =>
      1 + Balance.weaponDamagePerLevel * (level - 1);

  /// 1레벨 대비 늘어난 칼날 수, 구체 수, 관통 수.
  int bonusCount(int level) => switch (this) {
    flameBlade || emberOrb => (level - 1) ~/ 2,
    fireCrossbow => level - 1,
  };

  /// [level] 이 되면 얻는 효과.
  String upgradeText(int level) {
    final percent = (Balance.weaponDamagePerLevel * 100).round();
    final bonus = bonusCount(level) > bonusCount(level - 1);
    return '피해 +$percent%${bonus ? ', $bonusLabel +1' : ''}';
  }
}
