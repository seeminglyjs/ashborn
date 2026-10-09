import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';
import 'damage.dart';

/// 한 루프를 이루는 지역. 지역마다 적의 색, 피해 속성, 성향과 보스가 다르다.
enum Region {
  ashPlains(
    '잿빛 평원',
    '잿더미 거인',
    DamageType.physical,
    background: Color(0xFF1A1414),
    grid: Color(0x1FFFFFFF),
    enemy: Color(0xFF8A7F7A),
  ),
  sunkenCathedral(
    '가라앉은 성당',
    '가라앉은 사제',
    DamageType.cold,
    background: Color(0xFF0F161D),
    grid: Color(0x1F9FD8E8),
    enemy: Color(0xFF6F8FA8),
  ),
  burningForest(
    '불타는 숲',
    '불타는 수호목',
    DamageType.fire,
    background: Color(0xFF1E120C),
    grid: Color(0x1FFF8A3D),
    enemy: Color(0xFFB5552B),
    speed: 1.25,
  ),
  rustedFortress(
    '녹슨 요새',
    '녹슨 기사단장',
    DamageType.lightning,
    background: Color(0xFF16140E),
    grid: Color(0x1FFFE45C),
    enemy: Color(0xFF8C7A4B),
    speed: 0.9,
    hp: 1.4,
  ),
  undyingHeart(
    '꺼지지 않는 심장',
    '꺼지지 않는 심장',
    DamageType.wind,
    background: Color(0xFF1C0A0E),
    grid: Color(0x1FE8463A),
    enemy: Color(0xFFA33A4F),
    speed: 1.1,
    hp: 1.2,
  );

  const Region(
    this.label,
    this.bossName,
    this.damageType, {
    required this.background,
    required this.grid,
    required this.enemy,
    this.speed = 1,
    this.hp = 1,
  });

  final String label;
  final String bossName;

  /// 이 지역 적과 보스가 주는 피해 속성.
  final DamageType damageType;
  final Color background;
  final Color grid;
  final Color enemy;

  /// 기본 대비 적 이동 속도와 체력 배율.
  final double speed;
  final double hp;
}

/// 스테이지 하나 = 타락 단계 하나의 지역 하나. [index] 0 이 첫 지역이고,
/// 마지막 지역 다음은 첫 지역으로 돌아가며 타락 단계가 하나 오른다 (끝없음).
class Stage {
  const Stage(this.index) : assert(index >= 0);

  static const first = Stage(0);

  final int index;

  int get corruption => index ~/ Region.values.length;
  Region get region => Region.values[index % Region.values.length];

  /// 스테이지 레벨. 적 강도와 떨어지는 장비 레벨을 정한다.
  int get level => index + 1;

  Stage get next => Stage(index + 1);

  String get name =>
      corruption == 0 ? region.label : '타락 $corruption · ${region.label}';

  double get enemyHpMultiplier =>
      math.pow(Balance.stageHpGrowth, index) * region.hp * _ease;

  double get enemyDamageMultiplier =>
      math.pow(Balance.stageDamageGrowth, index) * _ease;

  /// 처음 몇 스테이지는 적이 약하다. 처음 하는 사람도 바로바로 넘어가도록.
  double get _ease =>
      index < Balance.earlyStageEase.length ? Balance.earlyStageEase[index] : 1;

  double get enemySpeedMultiplier =>
      region.speed *
      math.min(
        1 + Balance.corruptionSpeedBonus * corruption,
        Balance.maxCorruptionSpeed,
      );

  /// 타락 보상: 장비 드랍 확률 배율.
  double get dropChanceMultiplier =>
      1 + Balance.corruptionDropBonus * corruption;

  /// 타락 보상: 높은 등급이 나올 가중치를 키운다.
  double get rarityLuck => Balance.corruptionRarityLuck * corruption;

  @override
  bool operator ==(Object other) => other is Stage && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'Stage($index)';
}
