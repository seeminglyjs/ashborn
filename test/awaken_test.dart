import 'package:ashborn/components/player/player.dart';
import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/weapons/fire_crossbow.dart';
import 'package:ashborn/components/weapons/flame_blade.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// [id] 무기를 최대 레벨까지 올린다.
Future<void> maxOut(AshbornGame game, WeaponId id) async {
  final player = game.world.player;
  while ((player.weapon(id)?.level ?? 0) < WeaponId.maxLevel) {
    player.gainWeapon(id);
  }
  await game.ready();
}

List<AwakenOption> awakenings(Player player) =>
    LevelSystem.available(player).whereType<AwakenOption>().toList();

void main() {
  testWithGame<AshbornGame>(
    '최대 레벨 무기에 짝 패시브가 있어야 각성이 나오고, 각성하면 사라진다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      final player = game.world.player;
      await maxOut(game, WeaponId.emberOrb);
      expect(awakenings(player), isEmpty);

      player.gainPassive(WeaponId.emberOrb.catalyst);
      final options = awakenings(player);
      expect(options.map((o) => o.id), [WeaponId.emberOrb]);
      expect(options.single.title, WeaponId.emberOrb.awakenedLabel);

      final before = player.weapon(WeaponId.emberOrb)!.damageMultiplier;
      options.single.apply(player);

      final orb = player.weapon(WeaponId.emberOrb)!;
      expect(orb.awakened, isTrue);
      expect(
        orb.damageMultiplier,
        closeTo(before * Balance.awakenDamageMultiplier, 1e-9),
      );
      expect(awakenings(player), isEmpty);
    },
  );

  testWithGame<AshbornGame>('업화의 대검: 칼날이 늘고 더 넓게 돈다', gameWith(Roster.knight), (
    game,
  ) async {
    await game.ready();
    await maxOut(game, WeaponId.flameBlade);
    final blade = game.world.player.weapon(WeaponId.flameBlade)! as FlameBlade;
    final count = blade.bladeCount;

    blade.awaken();
    await game.ready();

    expect(blade.bladeCount, count + Balance.infernoBladeBonus);
    expect(blade.children.length, blade.bladeCount);
    expect(
      blade.orbitRadius,
      Balance.flameBladeOrbitRadius * Balance.infernoOrbitScale,
    );
  });

  testWithGame<AshbornGame>(
    '유성 잔불: 불씨가 맞힌 자리에서 터져 주변 적에게 피해를 준다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      await maxOut(game, WeaponId.emberOrb);
      final orb = game.world.player.weapon(WeaponId.emberOrb)! as EmberOrb;
      orb.awaken();
      final hit = await addEnemy(game, Vector2(200, 0));
      final near = await addEnemy(game, Vector2(200, 40));
      final far = await addEnemy(game, Vector2(200, 200));

      orb.fire();
      await game.ready();
      final bolts = game.world.children.whereType<EmberBolt>().toList();
      expect(bolts, isNotEmpty);
      expect(bolts.every((b) => b.explodes), isTrue);

      bolts.first.onHit(hit);

      expect(
        near.maxHp - near.hp,
        closeTo(bolts.first.damage * Balance.meteorRatio, 1e-6),
      );
      expect(far.hp, far.maxHp);
      expect(hit.hp, hit.maxHp, reason: '맞은 적은 폭발로 두 번 맞지 않는다');
    },
  );

  testWithGame<AshbornGame>(
    '폭풍 석궁: 화살 여러 발을 쏘고 더 많이 꿰뚫는다',
    gameWith(Roster.hunter),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      await maxOut(game, WeaponId.fireCrossbow);
      final bow =
          game.world.player.weapon(WeaponId.fireCrossbow)! as FireCrossbow;
      final pierce = bow.pierce;
      bow.awaken();
      await addEnemy(game, Vector2(200, 0));

      bow.fire();
      await game.ready();

      final arrows = game.world.children.whereType<FireArrow>().toList();
      expect(arrows.length, Balance.stormArrows);
      expect(
        arrows.every((a) => a.pierce == pierce + Balance.stormPierceBonus),
        isTrue,
      );
    },
  );
}
