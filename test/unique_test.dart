import 'dart:math' as math;

import 'package:ashborn/components/effects/burst.dart';
import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// [effect] 가 붙은 고유 장비를 마녀에게 끼운 인벤토리.
Inventory withEffect(UniqueEffect effect) => Inventory()
  ..gear(CharacterId.witch).add(
    Item(
      type: ItemType.belt,
      rarity: Rarity.unique,
      stats: const [(stat: StatType.armor, value: 0, rarity: Rarity.unique)],
      effect: effect,
    ),
  );

/// 위젯 없이 돌리므로 게임 오버 오버레이 자리만 등록해 둔다.
void stubOverlays(AshbornGame game) => game.overlays.addEntry(
  AshbornGame.gameOverOverlay,
  (_, _) => const SizedBox(),
);

void main() {
  test('고유 장비만 특수 효과를 갖는다', () {
    final random = math.Random(6);
    for (final rarity in Rarity.values) {
      final it = LootSystem.generate(random, rarity: rarity);
      expect(it.effect != null, rarity == Rarity.unique);
    }
  });

  testWithGame<AshbornGame>(
    '불사조의 재: 런마다 한 번 되살아난다',
    gameWith(Roster.witch, inventory: withEffect(UniqueEffect.phoenix)),
    (game) async {
      await game.ready();
      stubOverlays(game);
      final player = game.world.player;

      player.takeDamage(10000);
      expect(player.isDead, isFalse);
      expect(player.hp, player.maxHp * Balance.phoenixHp);
      expect(game.notices.value.single.text, contains('다시 일어섰다'));

      await advance(game, Balance.phoenixInvulnerableTime + 0.1);
      player.takeDamage(10000);
      expect(player.isDead, isTrue);
    },
  );

  testWithGame<AshbornGame>(
    '잿불 폭발: 주변 적에게 화염 피해',
    gameWith(Roster.witch, inventory: withEffect(UniqueEffect.emberBurst)),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final near = await addEnemy(game, Vector2(5000, 0));
      final far = await addEnemy(game, Vector2(5000 + 300, 0));

      game.world.emberBurst(near.position + Vector2(20, 0));
      await game.ready();

      expect(near.hp, near.maxHp - Balance.emberBurstDamage);
      expect(far.hp, far.maxHp);
      expect(game.world.children.whereType<Burst>(), isNotEmpty);
    },
  );

  testWithGame<AshbornGame>(
    '연쇄 번개: 타격이 가까운 적에게 번진다',
    gameWith(Roster.witch, inventory: withEffect(UniqueEffect.chainLightning)),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final target = await addEnemy(game, Vector2(5000, 0));
      final others = [
        for (var i = 1; i <= 4; i++)
          await addEnemy(game, Vector2(5000.0 + i * 30, 0)),
      ];

      // 확률 효과라 여러 번 때려 한 번은 터지게 한다.
      for (var i = 0; i < 100; i++) {
        game.world.player.strike(target, 1, DamageType.physical);
      }

      final hitCount = others.where((e) => e.hp < e.maxHp).length;
      expect(hitCount, Balance.chainLightningTargets);
      expect(others.last.hp, others.last.maxHp);
    },
  );

  testWithGame<AshbornGame>(
    '서리 갑옷: 맞으면 주변 적이 느려진다',
    gameWith(Roster.witch, inventory: withEffect(UniqueEffect.frostArmor)),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final enemy = await addEnemy(game, Vector2(80, 0));

      game.world.player.takeDamage(1);

      expect(enemy.ailments.chilled, isTrue);
      expect(enemy.ailments.speedMultiplier, 1 - Balance.frostArmorSlow);
    },
  );

  testWithGame<AshbornGame>(
    '광전사의 분노: 잃은 체력만큼 피해가 는다',
    gameWith(Roster.witch, inventory: withEffect(UniqueEffect.berserk)),
    (game) async {
      await game.ready();
      final player = game.world.player;
      expect(player.damageMultiplier, 1);

      player.takeDamage(player.maxHp / 2);

      expect(player.damageMultiplier, closeTo(1.5, 1e-9));
    },
  );

  testWithGame<AshbornGame>(
    '장비를 주우면 알림이 뜨고 시간이 지나면 사라진다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      final helm = item(ItemType.head, rarity: Rarity.legend);

      game.world.add(
        ItemDrop(position: game.world.player.position.clone(), item: helm),
      );
      await advance(game, 0.3);
      expect(game.notices.value.single.text, '${helm.name} 획득 · 장착');
      expect(game.notices.value.single.color, Rarity.legend.color);

      await advance(game, Balance.noticeDuration);
      expect(game.notices.value, isEmpty);
    },
  );
}
