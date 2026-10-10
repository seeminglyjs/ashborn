import 'dart:math' as math;

import 'balance.dart';
import 'characters.dart';
import 'damage.dart';
import 'equipment.dart';
import 'stats.dart';
import 'transcend.dart';

/// 종합 전투력: 장비 · 화톳불 강화 · 은총으로 오른 능력치를 숫자 하나로 모은 것.
///
/// 공격력(한 타의 기대 피해 × 공격 속도)과 버티는 힘(체력 · 보호막을 받는 피해 배율로 나눈 값)의
/// 기하평균이다. 그래서 한쪽만 키우기보다 둘을 고르게 키울수록 높고, 높은 레벨 장비의 고정 수치와
/// 비율 옵션이 실제 계산처럼 서로 곱해진다. 장비 자동 장착([AutoEquip])이 이 값을 가장 높이는
/// 장비를 고른다. 실제 전투 공식을 단순하게 줄인 어림값이라 직업 무기 · 스킬 차이는 넣지 않는다.
abstract final class CombatPower {
  /// 장비 피해가 더해지기 전 한 타의 기준 피해.
  static const double baseHit = 20;

  /// 표시 배율 (맨몸 기사가 수백 정도로 보이게).
  static const double scale = 10;

  /// 상태이상 옵션 1 (100%) 이 공격력에 더하는 비율. 걸리는 조건이 있어 직접 피해보다 낮게 친다.
  static const double ailmentWeight = 0.3;

  /// 편의 옵션이 전투력에 더하는 비율.
  static const double moveWeight = 0.5;
  static const double magnetWeight = 0.05;
  static const double xpWeight = 0.2;

  /// 고유 효과 하나가 공격력 · 버티는 힘에 더하는 비율.
  static const _effectOffense = {
    UniqueEffect.emberBurst: 0.1,
    UniqueEffect.chainLightning: 0.1,
    UniqueEffect.berserk: 0.15,
  };
  static const _effectDefense = {
    UniqueEffect.phoenix: 0.3,
    UniqueEffect.frostArmor: 0.1,
  };

  /// [character] 가 [items] 를 꼈을 때의 전투력. [extra] 는 장비 밖에서 오른 능력치
  /// (화톳불 강화 · 은총). [enhanceOf] 를 주면 그 장비를 그 강화 단계로 친다 (강화 계승 미리 보기).
  static int of(
    CharacterDef character,
    Iterable<Item> items, {
    double Function(StatType stat)? extra,
    int Function(Item item)? enhanceOf,
  }) {
    final totals = {for (final s in StatType.values) s: extra?.call(s) ?? 0.0};
    final effects = <UniqueEffect>{};
    final transcend = {for (final t in TranscendOption.values) t: 0.0};
    for (final item in items) {
      for (final roll in item.statsAt(enhanceOf?.call(item) ?? item.enhance)) {
        totals[roll.stat] = totals[roll.stat]! + roll.value;
      }
      if (item.effect case final effect?) effects.add(effect);
      for (final option in TranscendOption.values) {
        transcend[option] = transcend[option]! + item.transcend(option);
      }
    }
    double t(StatType s) => totals[s]!;

    // 공격력: 한 타 × 피해 증가 × 치명타 기대 × 공격 속도 × 상태이상 · 효과 · 초월.
    final added = DamageType.values.fold(0.0, (sum, d) => sum + t(d.added));
    final crit = math.min(1.0, t(StatType.critChance));
    final ailments = [
      StatType.bleedChance,
      StatType.poisonChance,
      StatType.burnChance,
      StatType.shockChance,
      StatType.chillChance,
      StatType.bleedDamage,
      StatType.burnDamage,
      StatType.poisonDamage,
      StatType.shockEffect,
    ].fold(0.0, (sum, s) => sum + t(s));
    var offense =
        (baseHit + added) *
        (1 + t(StatType.damage)) *
        (1 + crit * (Balance.critMultiplier + t(StatType.critDamage) - 1)) *
        (1 + t(StatType.attackSpeed)) *
        (1 + ailmentWeight * ailments) *
        (1 + 0.2 * transcend[TranscendOption.extraProjectiles]!) *
        (1 + 0.5 * transcend[TranscendOption.bossDamage]!);
    for (final e in effects) {
      offense *= 1 + (_effectOffense[e] ?? 0);
    }

    // 버티는 힘: (체력 + 보호막) ÷ 다섯 속성에서 고르게 맞을 때 받는 피해 배율.
    final armor = Balance.armorScale / (Balance.armorScale + t(StatType.armor));
    final taken =
        DamageType.values.fold(0.0, (sum, d) {
          final reduction = math.min(t(d.reduction), Balance.maxReduction);
          final hit = (1 - reduction) * (d == DamageType.physical ? armor : 1);
          return sum + hit;
        }) /
        DamageType.values.length *
        (1 - math.min(t(StatType.evasion), Balance.maxEvasion)) *
        character.damageTakenMultiplier *
        (1 -
            Balance.lastStandThreshold *
                transcend[TranscendOption.lastStand]!.clamp(0, 1));
    var defense =
        (character.maxHp + t(StatType.maxHp) + t(StatType.energyShield)) /
        taken *
        (1 + t(StatType.hpRegen) / 20 + t(StatType.lifeSteal) * 5) *
        (1 + 0.02 * transcend[TranscendOption.healOnKill]!) *
        (1 + 0.1 * transcend[TranscendOption.thorns]!);
    for (final e in effects) {
      defense *= 1 + (_effectDefense[e] ?? 0);
    }

    final utility =
        1 +
        moveWeight * t(StatType.moveSpeed) +
        magnetWeight * t(StatType.magnetRange) +
        xpWeight * t(StatType.xpGain);
    return (math.sqrt(offense * defense) * utility * scale).round();
  }
}
