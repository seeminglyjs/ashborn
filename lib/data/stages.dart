import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';
import 'corruption.dart';
import 'damage.dart';
import 'enemies.dart';
import 'monster_sprites.dart';

/// 한 루프를 이루는 지역. 지역마다 적의 색, 피해 속성, 졸개 여섯 종류와 보스가 다르다.
enum Region {
  ashPlains(
    '잿빛 평원',
    '잿더미 거인',
    DamageType.physical,
    background: Color(0xFF1A1414),
    enemy: Color(0xFF8A7F7A),
    roster: [
      EnemyKind.ashWalker,
      EnemyKind.ashBat,
      EnemyKind.ashSlime,
      EnemyKind.carrionCrow,
      EnemyKind.boneThrower,
      EnemyKind.ashRaider,
      EnemyKind.ashRam,
      EnemyKind.ashOgre,
    ],
    bossSprite: MonsterSprite.bigZombie,
  ),
  sunkenCathedral(
    '가라앉은 성당',
    '가라앉은 사제',
    DamageType.cold,
    background: Color(0xFF0F161D),
    enemy: Color(0xFF6F8FA8),
    roster: [
      EnemyKind.drownedSkeleton,
      EnemyKind.frostWisp,
      EnemyKind.frostSlime,
      EnemyKind.paleChanter,
      EnemyKind.bogCroc,
      EnemyKind.bloatedDrowned,
      EnemyKind.tideWarden,
    ],
    bossSprite: MonsterSprite.necromancer,
  ),
  burningForest(
    '불타는 숲',
    '불타는 수호목',
    DamageType.fire,
    background: Color(0xFF1E120C),
    enemy: Color(0xFFB5552B),
    roster: [
      EnemyKind.fireImp,
      EnemyKind.emberBat,
      EnemyKind.lavaSlime,
      EnemyKind.emberDrake,
      EnemyKind.emberShaman,
      EnemyKind.emberMaw,
      EnemyKind.flameWisp,
      EnemyKind.charredHulk,
    ],
    bossSprite: MonsterSprite.ogre,
    speed: 1.25,
  ),
  rustedFortress(
    '녹슨 요새',
    '녹슨 기사단장',
    DamageType.lightning,
    background: Color(0xFF16140E),
    enemy: Color(0xFF8C7A4B),
    roster: [
      EnemyKind.orcSoldier,
      EnemyKind.sparkWisp,
      EnemyKind.powderGoblin,
      EnemyKind.rustScorpion,
      EnemyKind.rustArcher,
      EnemyKind.orcLancer,
      EnemyKind.rustOgre,
    ],
    bossSprite: MonsterSprite.maskedOrc,
    speed: 0.9,
    hp: 1.4,
  ),
  undyingHeart(
    '꺼지지 않는 심장',
    '꺼지지 않는 심장',
    DamageType.wind,
    background: Color(0xFF1C0A0E),
    enemy: Color(0xFFA33A4F),
    roster: [
      EnemyKind.chort,
      EnemyKind.bloodBat,
      EnemyKind.bloodSlime,
      EnemyKind.bloodPriest,
      EnemyKind.flameLizard,
      EnemyKind.voidRunner,
      EnemyKind.fleshHulk,
    ],
    bossSprite: MonsterSprite.bigDemon,
    speed: 1.1,
    hp: 1.2,
  );

  const Region(
    this.label,
    this.bossName,
    this.damageType, {
    required this.background,
    required this.enemy,
    required this.roster,
    required this.bossSprite,
    this.speed = 1,
    this.hp = 1,
  });

  final String label;
  final String bossName;

  /// 이 지역 적과 보스가 주는 피해 속성.
  final DamageType damageType;
  final Color background;

  final Color enemy;

  /// 이 지역 졸개 종류. 앞에서부터 스테이지 시간이 지나며 차례로 나오기 시작한다
  /// ([Balance.rosterUnlock]).
  final List<EnemyKind> roster;

  /// 이 지역 보스의 스프라이트.
  final MonsterSprite bossSprite;

  /// 기본 대비 적 이동 속도와 체력 배율.
  final double speed;
  final double hp;
}

/// 스테이지 하나 = 타락 단계 하나의 지역 하나. [index] = 타락 단계 × 지역 수 + 지역 순서.
///
/// 런은 늘 고른 타락 단계의 첫 지역([Stage.start])에서 시작해 다섯 지역을 차례로 지나고,
/// 마지막 지역 보스를 잡으면 그 단계 클리어로 끝난다. 클리어하면 다음 타락 단계가 열린다.
/// 적 강도는 런 안의 지역 순서([step])만큼 오르고, 타락 단계마다 [Balance.corruptionHpGrowth]
/// 배가 된다 — 런은 늘 레벨 1 에서 시작하므로, 단계를 올리는 힘은 장비 · 은총 · 화톳불 · 특성이다.
class Stage {
  const Stage(this.index) : assert(index >= 0);

  static const first = Stage(0);

  /// 타락 [corruption] 단계 런의 첫 스테이지.
  factory Stage.start(int corruption) =>
      Stage(corruption * Region.values.length);

  final int index;

  int get corruption => index ~/ Region.values.length;
  Region get region => Region.values[index % Region.values.length];

  /// 런 안의 지역 순서 (0 이 첫 지역).
  int get step => index % Region.values.length;

  /// 그 단계의 마지막 지역. 이 보스를 잡으면 단계 클리어다.
  bool get isFinal => step == Region.values.length - 1;

  /// 이 스테이지에 붙는 타락 특수 규칙.
  List<CorruptionRule> get rules => CorruptionRule.at(corruption);

  bool has(CorruptionRule rule) => corruption >= rule.from;

  /// 스테이지 레벨. 보상(잔불 · 골드)과 떨어지는 장비 레벨을 정한다. 타락 단계가 오를수록 높다.
  int get level => index + 1;

  Stage get next => Stage(index + 1);

  String get name =>
      corruption == 0 ? region.label : '타락 $corruption · ${region.label}';

  double get enemyHpMultiplier =>
      math.pow(Balance.stageHpGrowth, step) *
      math.pow(Balance.corruptionHpGrowth, corruption) *
      region.hp *
      _ease;

  double get enemyDamageMultiplier =>
      math.pow(Balance.stageDamageGrowth, step) *
      math.pow(Balance.corruptionDamageGrowth, corruption) *
      _ease;

  /// 타락 0단계 처음 몇 지역은 적이 약하다. 처음 하는 사람도 바로바로 넘어가도록.
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
