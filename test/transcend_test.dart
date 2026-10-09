import 'dart:math' as math;

import 'package:ashborn/components/enemies/boss.dart';
import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/weapons/flame_blade.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/data/transcend.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/ui/equipment/equipment_panel.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 늘 [value] 를 내는 난수. 성공 여부와 고르는 옵션을 정해 둔다.
class _Roll implements math.Random {
  _Roll(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => value < 0.5;

  @override
  int nextInt(int max) => (value * max).floor();
}

/// 초월할 수 있게 강화한 [rarity] 허리띠. [transcends] 를 미리 붙인다.
Item maxed(Rarity rarity, [List<TranscendRoll> transcends = const []]) => Item(
  type: ItemType.belt,
  rarity: rarity,
  stats: [(stat: StatType.armor, value: 0, rarity: rarity)],
  enhance: Balance.transcendEnhance,
  transcends: [...transcends],
);

Inventory rich() =>
    Inventory()..addLoot(gold: 1 << 30, transcendStones: 1 << 10);

/// [option] 초월이 붙은 장비를 마녀에게 끼운 인벤토리.
Inventory wearingTranscend(
  TranscendOption option,
  double value, {
  CharacterId character = CharacterId.witch,
}) =>
    Inventory()
      ..gear(character)
          .add(maxed(Rarity.hero, [(option: option, value: value)]));

void main() {
  group('초월 조건과 비용', () {
    test('영웅 이상, +20 강화여야 하고, 등급마다 최대 단계가 다르다', () {
      expect(maxed(Rarity.rare).canEverTranscend, isFalse);
      expect(maxed(Rarity.hero).canTranscend, isTrue);
      expect((maxed(Rarity.hero)..enhance = 19).canTranscend, isFalse);
      expect(
        (maxed(Rarity.hero)..enhance = 19).canEverTranscend,
        isTrue,
        reason: '초월 단계는 남아 있다',
      );
      expect(Rarity.hero.maxTranscend, 1);
      expect(Rarity.legend.maxTranscend, 2);
      expect(Rarity.epic.maxTranscend, 3);
      expect(Rarity.unique.maxTranscend, 3);
    });

    test('성공하면 초월석과 골드를 쓰고 아직 없는 초월 옵션이 붙는다', () {
      final inv = rich();
      final belt = maxed(Rarity.epic);
      final (stones, gold) = (inv.transcendStones, inv.gold);
      final (needStones, needGold) = (belt.transcendStones, belt.transcendGold);

      for (var i = 0; i < Rarity.epic.maxTranscend; i++) {
        expect(inv.transcend(belt, _Roll(0)), isTrue);
      }

      expect(belt.transcends.length, Rarity.epic.maxTranscend);
      expect(belt.transcends.map((t) => t.option).toSet().length, 3);
      expect(belt.canTranscend, isFalse);
      expect(belt.name, endsWith('★3'));
      expect(inv.transcendStones, lessThan(stones - needStones));
      expect(inv.gold, lessThan(gold - needGold));
      expect(belt.enhance, Balance.transcendEnhance, reason: '강화 단계는 그대로');
    });

    test('실패하면 재료만 사라진다', () {
      final inv = rich();
      final belt = maxed(Rarity.legend);
      final stones = inv.transcendStones;

      expect(inv.transcend(belt, _Roll(belt.transcendChance)), isFalse);

      expect(belt.transcends, isEmpty);
      expect(inv.transcendStones, stones - belt.transcendStones);
    });

    test('초월석이 모자라면 할 수 없고, 단계가 오를수록 비싸고 어렵다', () {
      final belt = maxed(Rarity.unique);
      expect((Inventory()..addLoot(gold: 1 << 30)).canTranscend(belt), isFalse);

      final next = maxed(Rarity.unique, [
        (option: TranscendOption.thorns, value: 0.5),
      ]);
      expect(next.transcendStones, greaterThan(belt.transcendStones));
      expect(next.transcendGold, greaterThan(belt.transcendGold));
      expect(next.transcendChance, lessThan(belt.transcendChance));
    });

    test('초월 옵션과 초월석이 저장되고, 예전 장비에는 없이 들어간다', () {
      final inv = Inventory()..addLoot(transcendStones: 2);
      inv
          .gear(CharacterId.knight)
          .add(
            maxed(Rarity.hero, [
              (option: TranscendOption.goldFind, value: 0.3),
            ]),
          );

      final loaded = Inventory.fromJson(inv.toJson());

      expect(loaded.transcendStones, 2);
      expect(
        loaded.gear(CharacterId.knight).transcend(TranscendOption.goldFind),
        0.3,
      );
      final old = maxed(Rarity.hero).toJson()..remove('transcends');
      expect(Item.fromJson(old).transcends, isEmpty);
    });

    test('모든 초월 옵션은 기본 옵션에 없는 효과다', () {
      final labels = StatType.values.map((s) => s.label).toSet();
      for (final option in TranscendOption.values) {
        expect(labels, isNot(contains(option.label)));
        expect(option.format(option.base), isNotEmpty);
      }
    });
  });

  group('초월 효과', () {
    testWithGame<AshbornGame>(
      '투사체: 잔불 구체가 한 발 더 쏜다',
      gameWith(
        Roster.witch,
        inventory: wearingTranscend(TranscendOption.extraProjectiles, 1),
      ),
      (game) async {
        await game.ready();
        final orb = game.world.player.weapon(WeaponId.emberOrb)! as EmberOrb;
        expect(orb.boltCount, 2);
      },
    );

    testWithGame<AshbornGame>(
      '투사체: 런 중에 장비를 끼면 칼날이 바로 는다',
      gameWith(Roster.knight),
      (game) async {
        await game.ready();
        final blade =
            game.world.player.weapon(WeaponId.flameBlade)! as FlameBlade;
        final before = blade.children.length;

        game.gear.add(
          maxed(Rarity.hero, [
            (option: TranscendOption.extraProjectiles, value: 1),
          ]),
        );
        await advance(game, 0.05);

        expect(blade.children.length, before + 1);
      },
    );

    testWithGame<AshbornGame>(
      '보스 피해: 보스에게만 더 아프다',
      gameWith(
        Roster.witch,
        inventory: wearingTranscend(TranscendOption.bossDamage, 0.25),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        final boss = Boss(
          position: player.position + Vector2(300, 0),
          maxHp: 1e6,
          contactDamage: 1,
          damageType: DamageType.physical,
          speed: 0,
          color: const Color(0xFFFFFFFF),
          name: '시험 보스',
        );
        await game.world.add(boss);
        final minion = await addEnemy(game, Vector2(-300, 0));

        expect(player.strike(boss, 100, DamageType.physical), 125);
        expect(player.strike(minion, 100, DamageType.physical), 100);
      },
    );

    testWithGame<AshbornGame>(
      '처치 시 회복',
      gameWith(
        Roster.witch,
        inventory: wearingTranscend(TranscendOption.healOnKill, 3),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;
        player.hp = 10;

        final enemy = await addEnemy(game, Vector2(3000, 0));
        enemy.takeDamage(double.infinity);

        expect(player.hp, 13);
      },
    );

    testWithGame<AshbornGame>(
      '가시: 부딪힌 적에게 받은 피해를 돌려준다',
      gameWith(
        Roster.witch,
        inventory: wearingTranscend(TranscendOption.thorns, 0.5),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2.zero());

        await advance(game, 0.05);

        expect(
          enemy.maxHp - enemy.hp,
          closeTo(enemy.contactDamage * 0.5, 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '불굴: 체력이 낮을 때만 받는 피해가 준다',
      gameWith(
        Roster.witch,
        inventory: wearingTranscend(TranscendOption.lastStand, 0.5),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final player = game.world.player;

        player.takeDamage(10);
        expect(player.hp, player.maxHp - 10);

        player.hp = player.maxHp * Balance.lastStandThreshold;
        final low = player.hp;
        await advance(game, Balance.playerInvulnerableTime + 0.05);
        player.takeDamage(10);
        expect(player.hp, closeTo(low - 5, 1e-9));
      },
    );

    testWithGame<AshbornGame>(
      '골드 획득: 처치 골드가 는다',
      gameWith(
        Roster.witch,
        inventory: wearingTranscend(TranscendOption.goldFind, 0.5),
      ),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        for (var i = 0; i < 10; i++) {
          final enemy = await addEnemy(game, Vector2(3000.0 + i * 50, 0));
          enemy.takeDamage(double.infinity);
        }

        expect(
          game.world.bankLoot().gold,
          (10 * Balance.killGold * 1.5).floor(),
        );
      },
    );

    testWithGame<AshbornGame>(
      '초월석은 보스가 확률로 떨어뜨린다 (타락이 깊으면 반드시)',
      gameWith(Roster.witch, stage: Stage(Region.values.length * 15)),
      (game) async {
        await game.ready();
        game.overlays.addEntry(
          AshbornGame.stageClearOverlay,
          (_, _) => const SizedBox(),
        );
        game.world.spawnBoss();
        await game.ready();

        game.world.boss!.takeDamage(double.infinity);

        expect(game.inventory.transcendStones, 1);
        expect(game.world.runTranscendStones, 1);
        expect(game.notices.value.map((n) => n.text), contains('초월석 +1'));
      },
    );
  });

  testWidgets('장비 화면: +20 영웅 장비에 초월 비용과 버튼이 보이고 시도하면 재료를 쓴다', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final belt = maxed(Rarity.hero);
    final inv = Inventory()
      ..addLoot(
        gold: belt.transcendGold,
        transcendStones: belt.transcendStones,
      );
    inv.gear(CharacterId.witch)
      ..add(belt)
      ..unequip(EquipSlot.belt);

    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentPanel(
          inventory: inv,
          character: Roster.witch,
          onClose: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('bag-0')));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('transcend-cost'))).data,
      '초월석 ${belt.transcendStones} · 골드 ${belt.transcendGold} · '
      '성공 ${(Balance.transcendChances[0] * 100).round()}%',
    );

    await tester.tap(find.byKey(const Key('transcend')));
    await tester.pump();

    expect((inv.transcendStones, inv.gold), (0, 0));
    expect(find.byKey(const Key('transcend-result')), findsOneWidget);
  });
}
