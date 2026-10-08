import 'dart:math' as math;

import '../components/player/player.dart';
import '../data/balance.dart';
import '../data/passives.dart';
import '../data/weapons.dart';

/// 경험치 곡선과 레벨업 선택지.
abstract final class LevelSystem {
  /// [level] 에서 다음 레벨까지 필요한 경험치.
  static double xpToNext(int level) =>
      Balance.xpBase + Balance.xpGrowth * (level - 1);

  /// 지금 고를 수 있는 모든 선택지. 최대 레벨인 것은 빠지고,
  /// 최대 레벨 무기에 짝 패시브가 있으면 각성이 들어간다.
  static List<LevelUpOption> available(Player player) => [
    for (final weapon in player.weapons)
      if (weapon.isMaxLevel &&
          !weapon.awakened &&
          (player.passives[weapon.id.catalyst] ?? 0) > 0)
        AwakenOption(weapon.id),
    for (final id in WeaponId.values)
      if ((player.weapon(id)?.level ?? 0) < WeaponId.maxLevel)
        WeaponOption(id, (player.weapon(id)?.level ?? 0) + 1),
    for (final id in PassiveId.values)
      if ((player.passives[id] ?? 0) < PassiveId.maxLevel)
        PassiveOption(id, (player.passives[id] ?? 0) + 1),
  ];

  /// 무작위 선택지 최대 [Balance.levelUpChoices] 장.
  static List<LevelUpOption> roll(Player player, math.Random random) =>
      (available(
        player,
      )..shuffle(random)).take(Balance.levelUpChoices).toList();
}

sealed class LevelUpOption {
  const LevelUpOption(this.level);

  /// 고르면 도달하는 레벨. 1이면 새로 얻는다.
  final int level;

  String get title;
  String get description;
  void apply(Player player);
}

class WeaponOption extends LevelUpOption {
  const WeaponOption(this.id, super.level);

  final WeaponId id;

  @override
  String get title => id.label;

  @override
  String get description => level == 1 ? id.description : id.upgradeText(level);

  @override
  void apply(Player player) => player.gainWeapon(id);
}

/// 최대 레벨 무기를 각성시킨다.
class AwakenOption extends LevelUpOption {
  const AwakenOption(this.id) : super(WeaponId.maxLevel);

  final WeaponId id;

  @override
  String get title => id.awakenedLabel;

  @override
  String get description => id.awakenedDescription;

  @override
  void apply(Player player) => player.weapon(id)!.awaken();
}

class PassiveOption extends LevelUpOption {
  const PassiveOption(this.id, super.level);

  final PassiveId id;

  @override
  String get title => id.label;

  @override
  String get description => id.stat.format(id.perLevel);

  @override
  void apply(Player player) => player.gainPassive(id);
}
