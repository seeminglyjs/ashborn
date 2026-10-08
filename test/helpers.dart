import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/progress.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';

/// 게임을 [seconds] 동안 60fps 로 진행시킨다.
Future<void> advance(AshbornGame game, double seconds) async {
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds; t += dt) {
    game.update(dt);
    await game.ready();
  }
}

AshbornGame Function() gameWith(
  CharacterDef character, {
  Inventory? inventory,
  Progress? progress,
  Stage stage = Stage.first,
}) =>
    () => AshbornGame(
      character: character,
      profile: Profile(inventory: inventory, progress: progress),
      startStage: stage,
    );

/// 웨이브 스폰과 섞이지 않도록 기존 적을 모두 치운다.
Future<void> clearEnemies(AshbornGame game) async {
  for (final e in game.world.enemies.toList()) {
    e.removeFromParent();
  }
  await game.ready();
}

Future<Enemy> addEnemy(
  AshbornGame game,
  Vector2 offset, {
  double hp = 1000,
}) async {
  final enemy = Enemy(position: game.world.player.position + offset, maxHp: hp);
  await game.world.add(enemy);
  await game.ready();
  return enemy;
}

/// 테스트용 장비. 주옵션은 [stat] (기본: 파츠의 첫 후보).
Item item(
  ItemType type, {
  Rarity rarity = Rarity.normal,
  StatType? stat,
  double value = 1,
  List<StatRoll> extra = const [],
}) => Item(
  type: type,
  rarity: rarity,
  stats: [
    (stat: stat ?? type.mainStats.first, value: value, rarity: rarity),
    ...extra,
  ],
);

/// 능력치 하나만 올려 주는 장비를 낀 인벤토리. 목걸이부터 차례로 칸을 채운다.
Inventory wearing(
  Map<StatType, double> stats, {
  CharacterId character = CharacterId.witch,
}) {
  final inv = Inventory();
  final types = [
    ItemType.necklace,
    ItemType.head,
    ItemType.boots,
    ItemType.gloves,
    ItemType.belt,
    ItemType.ring,
    ItemType.ring,
    ItemType.earring,
    ItemType.earring,
  ];
  for (final (i, MapEntry(:key, :value)) in stats.entries.indexed) {
    inv.gear(character).add(item(types[i], stat: key, value: value));
  }
  return inv;
}
