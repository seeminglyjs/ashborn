import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 직업 기본 무기가 레벨에 따라 익히는 기술.
void main() {
  testWithGame<AshbornGame>(
    '잔불 구체: 과열을 익히면 네 번째 시전마다 큰 화염구가 섞인다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final orb = player.weapon(WeaponId.emberOrb)! as EmberOrb;
      while (orb.level < Balance.overheatLevel) {
        player.gainWeapon(WeaponId.emberOrb);
      }
      await addEnemy(game, Vector2(300, 0), hp: 1e9);

      for (var i = 0; i < Balance.overheatEvery - 1; i++) {
        orb.fire();
      }
      await game.ready();
      bool big(EmberBolt b) => b.bulk > 1;
      expect(game.world.children.whereType<EmberBolt>().where(big), isEmpty);

      orb.fire();
      await game.ready();
      final fireball = game.world.children.whereType<EmberBolt>().where(big);
      expect(fireball, hasLength(1));
      expect(fireball.single.explodes, isTrue);
    },
  );

  testWithGame<AshbornGame>(
    '사냥 석궁: 저격을 익히면 네 번째 사격은 끝없이 꿰뚫는 강한 화살',
    gameWith(Roster.hunter),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final bow = player.weapon(WeaponId.fireCrossbow)! as FireCrossbow;
      while (bow.level < Balance.sniperLevel) {
        player.gainWeapon(WeaponId.fireCrossbow);
      }
      await addEnemy(game, Vector2(300, 0), hp: 1e9);

      while (bow.shots < Balance.sniperEvery) {
        bow.fire();
      }
      await game.ready();

      final snipers = game.world.children.whereType<FireArrow>().where(
        (a) => a.sniper,
      );
      expect(snipers, isNotEmpty);
      expect(snipers.first.pierce, Balance.sniperPierce);
    },
  );
}
