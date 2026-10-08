import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/fate_system.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:ashborn/ui/overlays/stage_clear_overlay.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'unique_test.dart' show withEffect;

/// 위젯 없이 돌리므로 오버레이 자리만 등록해 둔다.
void stubOverlays(AshbornGame game) {
  for (final name in [
    AshbornGame.stageClearOverlay,
    AshbornGame.levelUpOverlay,
    AshbornGame.gameOverOverlay,
  ]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
}

void main() {
  group('추첨', () {
    testWithGame<AshbornGame>(
      '서로 다른 카드 세 장. 종류는 고르게, 종류 안에서 등급은 가중치대로',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final random = math.Random(3);
        final types = <FateType, int>{};
        final tiers = <FateType, Map<FateTier, int>>{};
        const rolls = 6000;
        for (var i = 0; i < rolls; i++) {
          final hand = FateSystem.roll(game.world.player, random);
          expect(hand.length, Balance.fateChoices);
          expect(hand.toSet().length, hand.length);
          final first = hand.first;
          types.update(first.type, (n) => n + 1, ifAbsent: () => 1);
          tiers
              .putIfAbsent(first.type, () => {})
              .update(first.tier, (n) => n + 1, ifAbsent: () => 1);
        }

        for (final type in FateType.values) {
          expect(
            types[type]! / rolls,
            closeTo(1 / 3, 0.03),
            reason: type.label,
          );
          final present = {
            for (final c in FateCard.values)
              if (c.type == type) c.tier,
          };
          final total = present.fold(0.0, (s, t) => s + t.weight);
          for (final tier in present) {
            expect(
              tiers[type]![tier]! / types[type]!,
              closeTo(tier.weight / total, 0.04),
              reason: '${type.label} ${tier.label}',
            );
          }
        }
      },
    );

    testWithGame<AshbornGame>(
      '같은 종류는 두 장까지, 보상은 한 장까지. 종류 조합은 고정이 아니다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final random = math.Random(7);
        final combos = <String>{};
        for (var i = 0; i < 3000; i++) {
          final hand = FateSystem.roll(game.world.player, random);
          expect(hand.length, Balance.fateChoices);
          for (final type in FateType.values) {
            expect(
              hand.where((c) => c.type == type).length,
              lessThanOrEqualTo(type.limit),
            );
          }
          combos.add((hand.map((c) => c.type.index).toList()..sort()).join());
        }

        // 스탯 2 + 스킬 1, 스탯 1 + 스킬 1 + 보상 1 같은 여러 조합이 나온다.
        expect(combos, containsAll(['001', '011', '012', '112', '002']));
        expect(FateType.reward.limit, 1);
      },
    );

    testWithGame<AshbornGame>(
      '이미 가진 효과와 더 얻을 수 없는 무기 카드는 나오지 않는다',
      gameWith(Roster.witch, inventory: withEffect(UniqueEffect.emberBurst)),
      (game) async {
        await game.ready();
        final player = game.world.player;
        for (final id in WeaponId.values) {
          while ((player.weapon(id)?.level ?? 0) < WeaponId.maxLevel) {
            player.gainWeapon(id);
          }
        }
        await game.ready();

        expect(FateSystem.available(FateCard.emberBurst, player), isFalse);
        expect(FateSystem.available(FateCard.smithsTouch, player), isFalse);
        expect(FateSystem.available(FateCard.newArms, player), isFalse);
        expect(FateSystem.available(FateCard.chainLightning, player), isTrue);
        expect(FateSystem.available(FateCard.hardenedAsh, player), isTrue);
      },
    );
  });

  group('선택', () {
    Future<void> clearStage(AshbornGame game) async {
      game.world.spawnBoss();
      await game.ready();
      game.world.boss!.takeDamage(double.infinity);
      await game.ready();
      await advance(game, Balance.stageClearDelay + 0.1);
    }

    testWithGame<AshbornGame>(
      '보스를 잡으면 운명 카드가 나오고, 고르면 다음 지역으로 간다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        stubOverlays(game);

        await clearStage(game);
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isTrue);
        expect(game.fateOptions.value.length, Balance.fateChoices);

        game.chooseFate(FateCard.sharpEmber);

        expect(game.world.stage, const Stage(1));
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isFalse);
        expect(game.paused, isFalse);
        expect(game.world.fate.taken, [FateCard.sharpEmber]);
        expect(game.world.player.bonus(StatType.damage), Balance.fateDamage);
        expect(
          game.notices.value.last.text,
          '운명: ${FateCard.sharpEmber.title}',
        );
      },
    );

    testWithGame<AshbornGame>('다시 뽑기는 런마다 정해진 횟수만큼', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      stubOverlays(game);
      await clearStage(game);
      var hand = game.fateOptions.value;

      for (var i = 0; i < Balance.fateRerolls; i++) {
        game.rerollFate();
        expect(game.fateOptions.value, isNot(same(hand)));
        hand = game.fateOptions.value;
      }
      expect(game.world.fate.rerolls, 0);

      game.rerollFate();
      expect(game.fateOptions.value, same(hand));
    });
  });

  group('효과', () {
    testWithGame<AshbornGame>(
      '능력치 카드는 겹치고, 최대 체력은 비율을 지킨다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        player.hp = player.maxHp / 2;

        FateSystem.apply(FateCard.hardenedAsh, game.world);
        FateSystem.apply(FateCard.hardenedAsh, game.world);

        expect(player.maxHp, Roster.witch.maxHp + Balance.fateMaxHp * 2);
        expect(player.hp, player.maxHp / 2);
        expect(game.stats.maxHp.value, player.maxHp);
      },
    );

    testWithGame<AshbornGame>('숨 고르기는 체력을 모두 채운다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final player = game.world.player;
      player.hp = 1;

      FateSystem.apply(FateCard.breather, game.world);

      expect(player.hp, player.maxHp);
      expect(game.stats.hp.value, player.maxHp);
    });

    testWithGame<AshbornGame>(
      '대장장이의 손길은 무기를 2레벨, 낯선 무기는 새 무기를 준다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final start = Roster.witch.startWeapon;

        FateSystem.apply(FateCard.smithsTouch, game.world);
        expect(player.weapon(start)!.level, 1 + Balance.fateWeaponLevels);

        FateSystem.apply(FateCard.newArms, game.world);
        await game.ready();
        expect(player.weapons.length, 2);
      },
    );

    testWithGame<AshbornGame>(
      '재의 홍수는 바로 레벨을 올려 레벨업 선택을 띄운다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        stubOverlays(game);

        FateSystem.apply(FateCard.ashFlood, game.world);

        expect(game.stats.level.value, 1 + Balance.fateLevels);
        expect(game.overlays.isActive(AshbornGame.levelUpOverlay), isTrue);
      },
    );

    testWithGame<AshbornGame>(
      '효과 카드는 고유 장비와 같은 효과를 준다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();

        FateSystem.apply(FateCard.berserk, game.world);

        expect(game.world.player.effects, contains(UniqueEffect.berserk));
      },
    );

    testWithGame<AshbornGame>(
      '불사조의 깃털은 고유 장비의 부활과 따로 센다',
      gameWith(Roster.witch, inventory: withEffect(UniqueEffect.phoenix)),
      (game) async {
        await game.ready();
        stubOverlays(game);
        final player = game.world.player;
        FateSystem.apply(FateCard.phoenixFeather, game.world);

        for (var i = 0; i < 2; i++) {
          player.takeDamage(1e9);
          expect(player.isDead, isFalse);
          await advance(game, Balance.phoenixInvulnerableTime + 0.1);
        }
        player.takeDamage(1e9);
        expect(player.isDead, isTrue);
      },
    );
  });

  group('저주', () {
    testWithGame<AshbornGame>(
      '짙어지는 재: 적 체력이 늘고 잔불은 두 배',
      gameWith(Roster.witch, stage: const Stage(2)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        FateSystem.apply(FateCard.thickAsh, game.world);

        await advance(game, Balance.baseSpawnInterval + 0.1);
        final enemy = game.world.enemies.first;
        expect(
          enemy.maxHp,
          closeTo(
            WaveSystem.enemyHp(game.world.stageTime) *
                const Stage(2).enemyHpMultiplier *
                Balance.curseEnemyHp,
            enemy.maxHp * 0.02,
          ),
        );

        final before = game.inventory.ember;
        game.world.bankEmber(bonus: 10);
        expect(game.inventory.ember - before, 10 * Balance.curseEmber);
      },
    );

    testWithGame<AshbornGame>(
      '피의 맹세: 적 피해가 늘고 장비 드랍 확률은 두 배',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        FateSystem.apply(FateCard.bloodOath, game.world);
        FateSystem.apply(FateCard.bloodOath, game.world);

        expect(
          game.world.fate.dropMultiplier,
          Balance.curseDrop * Balance.curseDrop,
        );
        await advance(game, Balance.baseSpawnInterval + 0.1);
        expect(
          game.world.enemies.first.contactDamage,
          closeTo(
            Balance.enemyContactDamage *
                Balance.curseEnemyDamage *
                Balance.curseEnemyDamage,
            1e-9,
          ),
        );
      },
    );

    testWithGame<AshbornGame>(
      '타오르는 대가: 최대 체력이 줄고 피해가 크게 는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;

        FateSystem.apply(FateCard.burningPrice, game.world);

        expect(player.maxHp, Roster.witch.maxHp + Balance.curseMaxHp);
        expect(player.hp, player.maxHp);
        expect(player.damageMultiplier, 1 + Balance.curseDamage);
      },
    );
  });

  testWithGame<AshbornGame>(
    '보상 카드: 경험치, 잔불, 드랍 배율이 오른다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      final world = game.world;

      FateSystem.apply(FateCard.learningEmber, world);
      FateSystem.apply(FateCard.emberCollector, world);
      FateSystem.apply(FateCard.treasureHunter, world);
      FateSystem.apply(FateCard.thickAsh, world);

      expect(world.player.xpMultiplier, 1 + Balance.fateXpGain);
      expect(
        world.fate.emberMultiplier,
        closeTo(Balance.curseEmber * (1 + Balance.fateEmberGain), 1e-9),
      );
      expect(world.fate.dropMultiplier, 1 + Balance.fateDropGain);
    },
  );

  testWidgets('클리어 화면에 운명 카드와 남은 다시 뽑기 횟수가 보인다', (tester) async {
    final game = gameWith(Roster.witch)();
    game.fateOptions.value = [
      FateCard.hardenedAsh,
      FateCard.thickAsh,
      FateCard.phoenixFeather,
    ];
    game.world.fate.rerolls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StageClearOverlay(game: game, onReturn: () {}),
      ),
    );

    expect(find.text(FateCard.hardenedAsh.title), findsOneWidget);
    expect(find.text(FateCard.thickAsh.description), findsOneWidget);
    expect(find.text(FateTier.legendary.label), findsOneWidget);
    expect(find.text(FateType.reward.label), findsOneWidget);
    expect(find.text(FateType.stat.label), findsOneWidget);
    expect(find.text('다시 뽑기 (0)'), findsOneWidget);
  });

  test('카드 설명은 비어 있지 않다', () {
    for (final card in FateCard.values) {
      expect(card.description, isNotEmpty, reason: card.name);
    }
  });
}
