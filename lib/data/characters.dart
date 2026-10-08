import 'dart:ui';

import 'balance.dart';

enum CharacterId { knight, witch, hunter }

/// 플레이 가능한 애쉬본 정의. 시작 무기는 [Player] 가 [id] 로 고른다.
class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.role,
    required this.weaponName,
    required this.weaponDescription,
    required this.trait,
    required this.portrait,
    required this.color,
    required this.maxHp,
    required this.speed,
    this.cooldownMultiplier = 1,
    this.damageTakenMultiplier = 1,
    required this.ratings,
  });

  final CharacterId id;
  final String name;
  final String role;
  final String weaponName;
  final String weaponDescription;
  final String trait;
  final String portrait;
  final Color color;

  final double maxHp;
  final double speed;
  final double cooldownMultiplier;
  final double damageTakenMultiplier;

  /// 선택 화면에 표시할 체력, 속도, 화력 등급 (1에서 5).
  final ({int hp, int speed, int power}) ratings;
}

abstract final class Roster {
  static const knight = CharacterDef(
    id: CharacterId.knight,
    name: '잿불 기사',
    role: '근접 탱커',
    weaponName: '불꽃 대검',
    weaponDescription: '주변을 도는 불꽃 칼날',
    trait: '받는 피해 20% 감소',
    portrait: 'assets/images/characters/knight.webp',
    color: Color(0xFFD64545),
    maxHp: 150,
    speed: Balance.playerSpeed * 0.875,
    damageTakenMultiplier: 0.8,
    ratings: (hp: 5, speed: 2, power: 3),
  );

  static const witch = CharacterDef(
    id: CharacterId.witch,
    name: '재의 마녀',
    role: '원거리 마법사',
    weaponName: '잔불 구체',
    weaponDescription: '가장 가까운 적을 노리는 불씨',
    trait: '공격 쿨다운 20% 감소',
    portrait: 'assets/images/characters/witch.webp',
    color: Color(0xFFFFB347),
    maxHp: 90,
    speed: Balance.playerSpeed,
    cooldownMultiplier: 0.8,
    ratings: (hp: 2, speed: 3, power: 4),
  );

  static const hunter = CharacterDef(
    id: CharacterId.hunter,
    name: '불씨 사냥꾼',
    role: '기동형 딜러',
    weaponName: '화염 석궁',
    weaponDescription: '적을 꿰뚫는 불화살',
    trait: '이동 속도 20% 증가',
    portrait: 'assets/images/characters/hunter.webp',
    color: Color(0xFF7FB069),
    maxHp: 100,
    speed: Balance.playerSpeed * 1.2,
    ratings: (hp: 3, speed: 5, power: 3),
  );

  static const all = [knight, witch, hunter];
}
