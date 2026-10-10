import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 직업 기본 무기가 레벨에 따라 익히는 기술.
void main() {
  testWithGame<AshbornGame>(
    '잔불 구체: 원소 폭주를 익히면 네 번째 시전은 구체 대신 4원소 레이저가 줄 위의 적을 모두 꿰뚫는다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final orb = player.weapon(WeaponId.emberOrb)! as EmberOrb;
      while (orb.level < Balance.surgeLevel) {
        player.gainWeapon(WeaponId.emberOrb);
      }
      final near = await addEnemy(game, Vector2(150, 0), hp: 1e9);
      final far = await addEnemy(game, Vector2(400, 10), hp: 1e9);
      final aside = await addEnemy(game, Vector2(150, 120), hp: 1e9);

      for (var i = 0; i < Balance.surgeEvery - 1; i++) {
        orb.fire();
      }
      await game.ready();
      expect(game.world.children.whereType<ElementalBeam>(), isEmpty);
      for (final b in game.world.children.whereType<EmberBolt>().toList()) {
        b.removeFromParent();
      }
      await game.ready();

      orb.fire();
      await game.ready();
      expect(game.world.children.whereType<ElementalBeam>(), hasLength(1));
      expect(game.world.children.whereType<EmberBolt>(), isEmpty);
      expect(near.hp, lessThan(1e9));
      expect(far.hp, lessThan(1e9));
      expect(aside.hp, 1e9);
    },
  );

  testWithGame<AshbornGame>(
    '사냥 석궁: 헤드샷을 익히면 확률로 3배 피해에 끝없이 꿰뚫는 화살이 나간다',
    gameWith(Roster.hunter),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final bow = player.weapon(WeaponId.fireCrossbow)! as FireCrossbow;
      while (bow.level < Balance.headshotLevel) {
        player.gainWeapon(WeaponId.fireCrossbow);
      }
      await addEnemy(game, Vector2(300, 0), hp: 1e9);

      Iterable<FireArrow> headshots() =>
          game.world.children.whereType<FireArrow>().where((a) => a.headshot);
      Iterable<FireArrow> normals() =>
          game.world.children.whereType<FireArrow>().where((a) => !a.headshot);
      // 무작위라 헤드샷과 보통 화살이 둘 다 나올 때까지 쏜다.
      for (
        var i = 0;
        i < 400 && (headshots().isEmpty || normals().isEmpty);
        i++
      ) {
        bow.fire();
        await game.ready();
      }
      final normal = normals().first;
      expect(headshots(), isNotEmpty);
      expect(headshots().first.pierce, Balance.headshotPierce);
      expect(
        headshots().first.damage,
        closeTo(normal.damage * Balance.headshotDamage, 1e-9),
      );
    },
  );

  testWithGame<AshbornGame>(
    '사냥 석궁: 맹공을 익히면 연사가 두 번 연달아 날 때 쿨다운이 줄어든다',
    gameWith(Roster.hunter),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      final bow = player.weapon(WeaponId.fireCrossbow)! as FireCrossbow;
      while (bow.level < Balance.hunterOnslaughtLevel) {
        player.gainWeapon(WeaponId.fireCrossbow);
      }
      await addEnemy(game, Vector2(300, 0), hp: 1e9);
      final normal = bow.cooldown;

      for (var i = 0; i < 2000 && !bow.inOnslaught; i++) {
        bow.fire();
      }

      expect(bow.inOnslaught, isTrue);
      expect(bow.cooldown, closeTo(normal * Balance.onslaughtCooldown, 1e-9));
    },
  );

  testWithGame<AshbornGame>(
    '사냥 석궁: 헤드샷 화살에 맞은 적은 출혈 확률과 상관없이 반드시 출혈',
    gameWith(Roster.hunter),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final player = game.world.player;
      expect(player.bonus(StatType.bleedChance), 0);
      final first = await addEnemy(game, Vector2(80, 0), hp: 1e9);
      final second = await addEnemy(game, Vector2(140, 0), hp: 1e9);
      final plain = await addEnemy(game, Vector2(0, 80), hp: 1e9);

      await game.world.addAll([
        FireArrow(
          position: player.position.clone(),
          direction: Vector2(1, 0),
          damage: 10,
          type: DamageType.physical,
          pierce: Balance.headshotPierce,
          headshot: true,
        ),
        FireArrow(
          position: player.position.clone(),
          direction: Vector2(0, 1),
          damage: 10,
          type: DamageType.physical,
          pierce: 0,
        ),
      ]);
      await game.ready();
      for (var i = 0; i < 20; i++) {
        game.update(1 / 60);
      }

      expect(first.ailments.bleeding, isTrue);
      expect(second.ailments.bleeding, isTrue);
      expect(plain.hp, lessThan(1e9));
      expect(plain.ailments.bleeding, isFalse);
    },
  );
}
