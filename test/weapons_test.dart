import 'dart:ui';

import 'package:ashborn/components/weapons/flame_blade.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 월드의 모든 컴포넌트를 한 번 그려 본다. 예외 없이 그려지면 된다.
void drawAll(AshbornGame game) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  void draw(Component c) {
    c.render(canvas);
    c.children.forEach(draw);
  }

  game.world.children.forEach(draw);
  recorder.endRecording().dispose();
}

CharacterDef ownerOf(WeaponId id) =>
    Roster.all.firstWhere((c) => c.id == (id.owner ?? CharacterId.knight));

void main() {
  for (final id in WeaponId.values) {
    for (final awakened in [false, true]) {
      testWithGame<AshbornGame>(
        '${id.label}${awakened ? ' (각성: ${id.awakenedLabel})' : ''}는 가까운 적을 다치게 한다',
        gameWith(ownerOf(id)),
        (game) async {
          await game.ready();
          await clearEnemies(game);
          final player = game.world.player;
          if (awakened) {
            while ((player.weapon(id)?.level ?? 0) < WeaponId.maxLevel) {
              player.gainWeapon(id);
            }
            await game.ready();
            player.awaken(id);
          } else if (player.weapon(id) == null) {
            player.gainWeapon(id);
          }
          await game.ready();
          // 대검은 궤도 위에 둔다.
          final weapon = player.weapon(id);
          final at = Vector2(weapon is FlameBlade ? weapon.orbitRadius : 45, 0);
          final enemy = await addEnemy(game, at, hp: 1e9);

          for (var i = 0; i < 40 && enemy.hp >= enemy.maxHp; i++) {
            await advance(game, 0.1);
            // 적이 밀려나거나 다가와도 같은 자리에 둔다.
            enemy.position.setFrom(player.position + at);
            drawAll(game);
          }

          expect(enemy.hp, lessThan(enemy.maxHp));
          expect(player.weapon(id)!.awakened, awakened);
        },
      );
    }
  }

  testWithGame<AshbornGame>('각성하면 연출과 알림이 뜬다', gameWith(Roster.knight), (
    game,
  ) async {
    await game.ready();
    final player = game.world.player;
    while (player.weapon(WeaponId.flameBlade)!.level < WeaponId.maxLevel) {
      player.gainWeapon(WeaponId.flameBlade);
    }
    player.awaken(WeaponId.flameBlade);
    await game.ready();
    expect(game.notices.value.last.text, contains('각성'));
    expect(
      game.notices.value.last.text,
      contains(WeaponId.flameBlade.awakenedLabel),
    );
  });
}
