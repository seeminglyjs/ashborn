import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/data/characters.dart';
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

AshbornGame Function() gameWith(CharacterDef character) =>
    () => AshbornGame(character: character);

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
