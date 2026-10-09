import 'dart:ui';

import 'balance.dart';
import 'weapons.dart';

enum CharacterId { knight, witch, hunter }

/// 플레이 가능한 애쉬본 정의.
class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.role,
    required this.startWeapon,
    required this.trait,
    required this.portrait,
    required this.sprite,
    required this.color,
    required this.maxHp,
    required this.speed,
    this.cooldownMultiplier = 1,
    this.damageTakenMultiplier = 1,
    required this.ratings,
    this.price = 0,
  });

  final CharacterId id;
  final String name;
  final String role;
  final WeaponId startWeapon;
  final String trait;
  final String portrait;

  /// 게임 안 스프라이트 시트 (`assets/images/` 기준). 16x28 프레임 9장:
  /// 대기 4 · 달리기 4 · 피격 1. 0x72 DungeonTileset II (CC-0) 를 다시 칠한 것.
  final String sprite;
  final Color color;

  final double maxHp;
  final double speed;
  final double cooldownMultiplier;
  final double damageTakenMultiplier;

  /// 선택 화면에 표시할 체력, 속도, 화력 등급 (1에서 5).
  final ({int hp, int speed, int power}) ratings;

  /// 해금 골드. 0이면 처음부터 쓸 수 있다.
  final int price;

  String get weaponName => startWeapon.label;
  String get weaponDescription => startWeapon.description;
}

abstract final class Roster {
  static const knight = CharacterDef(
    id: CharacterId.knight,
    name: '잿불 기사',
    role: '근접 탱커',
    startWeapon: WeaponId.flameBlade,
    trait: '받는 피해 20% 감소',
    portrait: 'assets/images/characters/knight.webp',
    sprite: 'sprites/knight.png',
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
    startWeapon: WeaponId.emberOrb,
    trait: '공격 쿨다운 20% 감소',
    portrait: 'assets/images/characters/witch.webp',
    sprite: 'sprites/witch.png',
    color: Color(0xFFFFB347),
    maxHp: 90,
    speed: Balance.playerSpeed,
    cooldownMultiplier: 0.8,
    ratings: (hp: 2, speed: 3, power: 4),
    price: Balance.witchPrice,
  );

  static const hunter = CharacterDef(
    id: CharacterId.hunter,
    name: '불씨 사냥꾼',
    role: '기동형 딜러',
    startWeapon: WeaponId.fireCrossbow,
    trait: '이동 속도 20% 증가',
    portrait: 'assets/images/characters/hunter.webp',
    sprite: 'sprites/hunter.png',
    color: Color(0xFF7FB069),
    maxHp: 100,
    speed: Balance.playerSpeed * 1.2,
    ratings: (hp: 3, speed: 5, power: 3),
    price: Balance.hunterPrice,
  );

  static const all = [knight, witch, hunter];
}
