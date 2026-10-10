import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/data/upgrades.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/fate_system.dart';
import 'package:ashborn/ui/hearth/hearth_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Inventory withEmber(int ember) => Inventory()..addEmber(ember);

void main() {
  group('구매', () {
    test('잔불을 써서 레벨을 올리고, 다음 비용은 커진다', () {
      final inventory = withEmber(1000);
      final upgrades = Upgrades();
      final first = upgrades.cost(Upgrade.maxHp);

      upgrades.buy(Upgrade.maxHp, inventory);

      expect(upgrades.level(Upgrade.maxHp), 1);
      expect(inventory.ember, 1000 - first);
      expect(
        upgrades.cost(Upgrade.maxHp),
        (Upgrade.maxHp.baseCost * Balance.upgradeCostGrowth).round(),
      );
      expect(upgrades.bonus(StatType.maxHp), Balance.upgradeMaxHp);
    });

    test('잔불이 모자라거나 최대 레벨이면 살 수 없다', () {
      final upgrades = Upgrades({Upgrade.fateChoices: 1});

      expect(upgrades.canBuy(Upgrade.maxHp, withEmber(0)), isFalse);
      expect(upgrades.isMax(Upgrade.fateChoices), isTrue);
      expect(upgrades.canBuy(Upgrade.fateChoices, withEmber(99999)), isFalse);
    });

    test('모든 강화는 모든 레벨에서 효과 문구가 있다', () {
      for (final upgrade in Upgrade.values) {
        for (var level = 1; level <= upgrade.maxLevel; level++) {
          expect(upgrade.effect(level), isNotEmpty, reason: upgrade.name);
        }
      }
    });

    test('기기에 저장되고 다음 실행에 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await Profile.load();
      profile.inventory.addEmber(500);
      profile.upgrades
        ..buy(Upgrade.damage, profile.inventory)
        ..buy(Upgrade.damage, profile.inventory);
      await pumpEventQueue();

      final loaded = await Profile.load();

      expect(loaded.upgrades.level(Upgrade.damage), 2);
      expect(loaded.inventory.ember, profile.inventory.ember);
    });
  });

  group('런에 붙는 효과', () {
    testWithGame<AshbornGame>(
      '능력치 강화는 플레이어에게 바로 붙는다',
      gameWith(
        Roster.witch,
        upgrades: Upgrades({Upgrade.maxHp: 3, Upgrade.damage: 2}),
      ),
      (game) async {
        await game.ready();
        final player = game.world.player;

        expect(player.maxHp, Roster.witch.maxHp + Balance.upgradeMaxHp * 3);
        expect(player.hp, player.maxHp);
        expect(player.damageMultiplier, 1 + Balance.upgradeDamage * 2);
      },
    );

    testWithGame<AshbornGame>(
      '잔불 수확은 처치와 클리어 잔불 모두를 늘린다',
      gameWith(Roster.witch, upgrades: Upgrades({Upgrade.emberGain: 4})),
      (game) async {
        await game.ready();
        final multiplier = 1 + Balance.upgradeEmberGain * 4;
        expect(game.world.emberMultiplier, multiplier);

        game.world.bankEmber(bonus: 100);

        expect(game.inventory.ember, (100 * multiplier).round());
      },
    );

    testWithGame<AshbornGame>(
      '신탁: 다시 기도하기는 다시 뽑기 횟수를, 만신전의 문은 카드 수를 늘린다',
      gameWith(
        Roster.witch,
        upgrades: Upgrades({Upgrade.fateRerolls: 2, Upgrade.fateChoices: 1}),
      ),
      (game) async {
        await game.ready();

        expect(FateSystem.rerolls(game.upgrades), Balance.fateRerolls + 2);
        final hand = FateSystem.roll(
          stage: game.world.stage,
          upgrades: game.upgrades,
          random: math.Random(1),
        );
        expect(hand.length, Balance.fateChoices + 1);
      },
    );

    testWithGame<AshbornGame>('깊은 신앙은 은총 카드 등급을 높인다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      double average() {
        final random = math.Random(4);
        final all = [
          for (var i = 0; i < 3000; i++)
            ...FateSystem.roll(
              stage: game.world.stage,
              upgrades: game.upgrades,
              random: random,
            ),
        ];
        return all.fold(0, (s, f) => s + f.rarity.index) / all.length;
      }

      final before = average();
      for (var i = 0; i < Upgrade.fateLuck.maxLevel; i++) {
        game.inventory.addEmber(game.upgrades.cost(Upgrade.fateLuck));
        game.upgrades.buy(Upgrade.fateLuck, game.inventory);
      }

      expect(average(), greaterThan(before + 0.1));
    });
  });

  testWidgets('화톳불에서 잔불이 있으면 강화를 사고, 모자라면 버튼이 꺼진다', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cost = Upgrade.maxHp.cost(0);
    final profile = Profile(inventory: withEmber(cost));

    await tester.pumpWidget(
      ProfileScope(
        profile: profile,
        child: const MaterialApp(home: HearthScreen()),
      ),
    );
    expect(find.text('잔불 $cost'), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy-maxHp')));
    await tester.pump();

    expect(profile.upgrades.level(Upgrade.maxHp), 1);
    expect(find.text('잔불 0'), findsOneWidget);
    expect(
      find.textContaining('Lv 1/${Upgrade.maxHp.maxLevel}'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('buy-maxHp')),
    );
    expect(button.onPressed, isNull);
  });
}
