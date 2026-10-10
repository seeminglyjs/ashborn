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
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:ashborn/ui/widgets/card_row.dart';
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

/// [card] 를 [rarity] (기본: 최소 등급) 로.
Fate fate(FateCard card, [Rarity? rarity]) =>
    Fate(card, rarity ?? card.minRarity);

double grow(int steps) => math.pow(Balance.fateRarityGrowth, steps).toDouble();

/// [rolls] 번 뽑은 카드 전부.
List<List<Fate>> rollMany(AshbornGame game, int rolls, int seed) {
  final random = math.Random(seed);
  return [
    for (var i = 0; i < rolls; i++) FateSystem.roll(game.world.player, random),
  ];
}

void main() {
  group('추첨', () {
    testWithGame<AshbornGame>(
      '서로 다른 카드 세 장. 같은 종류는 두 장, 보상은 한 장까지. 조합은 고정이 아니다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final combos = <String>{};
        for (final hand in rollMany(game, 3000, 7)) {
          expect(hand.length, Balance.fateChoices);
          expect(hand.map((f) => f.card).toSet().length, hand.length);
          for (final type in FateType.values) {
            expect(
              hand.where((f) => f.card.type == type).length,
              lessThanOrEqualTo(type.limit),
            );
          }
          combos.add(
            (hand.map((f) => f.card.type.index).toList()..sort()).join(),
          );
        }

        expect(combos, containsAll(['001', '011', '012', '112', '002']));
        expect(FateType.reward.limit, 1);
      },
    );

    testWithGame<AshbornGame>(
      '카드마다 등급을 뽑는다. 최소 등급 아래는 없고, 높을수록 드물다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final counts = <Rarity, int>{};
        final cards = <FateCard, Set<Rarity>>{};
        for (final hand in rollMany(game, 20000, 3)) {
          for (final f in hand) {
            expect(
              f.rarity.index,
              greaterThanOrEqualTo(f.card.minRarity.index),
            );
            if (f.card.minRarity == Rarity.normal) {
              counts.update(f.rarity, (n) => n + 1, ifAbsent: () => 1);
            }
            cards.putIfAbsent(f.card, () => {}).add(f.rarity);
          }
        }

        // 최소 등급이 노말인 카드 기준. 최소 등급이 높은 카드는 그 아래가 그 등급으로 올라간다.
        for (var i = 1; i < Rarity.values.length; i++) {
          expect(
            counts[Rarity.values[i]]!,
            lessThan(counts[Rarity.values[i - 1]]!),
            reason: Rarity.values[i].label,
          );
        }
        // 같은 카드가 여러 등급으로 나온다.
        expect(cards[FateCard.sharpEmber]!.length, greaterThan(3));
      },
    );

    testWithGame<AshbornGame>(
      '타락 단계가 높으면 높은 등급 카드가 잘 나온다',
      gameWith(Roster.witch, stage: Stage(Region.values.length * 3)),
      (game) async {
        await game.ready();
        double average(List<List<Fate>> hands) {
          final all = hands.expand((h) => h).toList();
          return all.fold(0, (s, f) => s + f.rarity.index) / all.length;
        }

        final corrupted = average(rollMany(game, 3000, 5));
        game.world.stage = Stage.first;
        final first = average(rollMany(game, 3000, 5));

        expect(corrupted, greaterThan(first + 0.2));
      },
    );

    testWithGame<AshbornGame>('저주는 가끔만 나온다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final all = rollMany(game, 5000, 9).expand((h) => h).toList();
      final curses = all.where((f) => f.card.curse).length / all.length;

      expect(curses, greaterThan(0.02));
      expect(curses, lessThan(Balance.fateCurseChance));
    });

    testWithGame<AshbornGame>(
      '가진 효과는 더 높은 등급으로만, 더 얻을 수 없는 무기 카드는 나오지 않는다',
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

        // 고유 장비 효과는 영웅 등급 카드와 같은 세기다.
        expect(
          FateSystem.available(fate(FateCard.emberBurst), player),
          isFalse,
        );
        expect(
          FateSystem.available(
            fate(FateCard.emberBurst, Rarity.legend),
            player,
          ),
          isTrue,
        );
        expect(
          FateSystem.available(fate(FateCard.smithsTouch), player),
          isFalse,
        );
        expect(FateSystem.available(fate(FateCard.newArms), player), isFalse);
        expect(
          FateSystem.available(fate(FateCard.hardenedAsh), player),
          isTrue,
        );
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
      '보스를 잡으면 은총 카드가 나오고, 고르면 다음 지역으로 간다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        stubOverlays(game);

        await clearStage(game);
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isTrue);
        expect(game.fateOptions.value.length, Balance.fateChoices);

        final pick = fate(FateCard.sharpEmber, Rarity.hero);
        game.chooseFate(pick);

        expect(game.world.stage, const Stage(1));
        expect(game.overlays.isActive(AshbornGame.stageClearOverlay), isFalse);
        expect(game.paused, isFalse);
        expect(game.world.fate.taken, [pick]);
        expect(
          game.world.player.bonus(StatType.damage),
          closeTo(Balance.fateDamage * grow(2), 1e-9),
        );
        expect(game.notices.value.last.text, contains(Rarity.hero.label));
        expect(game.notices.value.last.text, contains('신의 은총'));
        expect(game.notices.value.last.text, contains(pick.card.title));
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

  group('등급별 효과', () {
    test('최소 등급 위로 한 등급마다 수치가 커진다', () {
      expect(
        fate(FateCard.hardenedAsh, Rarity.unique).stats[StatType.maxHp],
        closeTo(Balance.fateMaxHp * grow(5), 1e-9),
      );
      expect(fate(FateCard.ashLord).power, 1);
      expect(fate(FateCard.ashLord, Rarity.unique).power, grow(2));
      expect(fate(FateCard.smithsTouch).weaponLevels, Balance.fateWeaponLevels);
      expect(
        fate(FateCard.smithsTouch, Rarity.unique).weaponLevels,
        Balance.fateWeaponLevels + 2,
      );
      expect(
        fate(FateCard.ashFlood, Rarity.legend).levels,
        Balance.fateLevels + 1,
      );
    });

    testWithGame<AshbornGame>(
      '능력치 카드는 겹치고, 최대 체력은 비율을 지킨다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        player.hp = player.maxHp / 2;

        FateSystem.apply(fate(FateCard.hardenedAsh), game.world);
        FateSystem.apply(fate(FateCard.hardenedAsh, Rarity.rare), game.world);

        expect(
          player.maxHp,
          closeTo(Roster.witch.maxHp + Balance.fateMaxHp * (1 + grow(1)), 1e-9),
        );
        expect(player.hp, closeTo(player.maxHp / 2, 1e-9));
        expect(game.stats.maxHp.value, player.maxHp);
      },
    );

    testWithGame<AshbornGame>(
      '신농의 약초는 등급이 높을수록 많이, 최대 체력까지 회복한다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;

        player.hp = 1;
        FateSystem.apply(fate(FateCard.breather), game.world);
        expect(player.hp, closeTo(1 + player.maxHp * Balance.fateHeal, 1e-9));

        player.hp = 1;
        FateSystem.apply(fate(FateCard.breather, Rarity.legend), game.world);
        expect(player.hp, player.maxHp);
        expect(game.stats.hp.value, player.maxHp);
      },
    );

    testWithGame<AshbornGame>(
      '헤파이스토스의 망치는 무기 레벨을, 루의 무기고는 새 무기를 등급만큼 높은 레벨로 준다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final start = Roster.witch.startWeapon;

        FateSystem.apply(fate(FateCard.smithsTouch), game.world);
        expect(player.weapon(start)!.level, 1 + Balance.fateWeaponLevels);

        FateSystem.apply(fate(FateCard.newArms, Rarity.legend), game.world);
        await game.ready();
        final added = player.weapons.firstWhere((w) => w.id != start);
        expect(added.level, 2);
        expect(WeaponId.poolFor(CharacterId.witch), contains(added.id));
      },
    );

    testWithGame<AshbornGame>(
      '다그다의 가마솥은 바로 레벨을 올려 레벨업 선택을 띄운다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        stubOverlays(game);

        FateSystem.apply(fate(FateCard.ashFlood), game.world);

        expect(game.stats.level.value, 1 + Balance.fateLevels);
        expect(game.overlays.isActive(AshbornGame.levelUpOverlay), isTrue);
      },
    );

    testWithGame<AshbornGame>(
      '효과 카드는 등급만큼 세고, 고유 장비와 겹치면 센 쪽을 쓴다',
      gameWith(Roster.witch, inventory: withEffect(UniqueEffect.berserk)),
      (game) async {
        await game.ready();
        final player = game.world.player;
        player.hp = player.maxHp / 2;
        expect(player.effectPower(UniqueEffect.berserk), 1);
        expect(player.damageMultiplier, 1 + 0.5 * Balance.berserkScale);

        FateSystem.apply(fate(FateCard.berserk, Rarity.unique), game.world);

        expect(player.effectPower(UniqueEffect.berserk), grow(2));
        expect(
          player.damageMultiplier,
          closeTo(1 + 0.5 * Balance.berserkScale * grow(2), 1e-9),
        );
        expect(player.effectPower(UniqueEffect.chainLightning), 0);
      },
    );

    testWithGame<AshbornGame>(
      '수르트의 불꽃 검 폭발 피해는 카드 등급만큼 크다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        FateSystem.apply(fate(FateCard.emberBurst, Rarity.epic), game.world);
        final enemy = await addEnemy(game, Vector2(20, 0));

        game.world.emberBurst(enemy.position);

        expect(
          enemy.maxHp - enemy.hp,
          closeTo(Balance.emberBurstDamage * grow(2), 1e-6),
        );
      },
    );

    testWithGame<AshbornGame>(
      '오시리스의 부활은 고유 장비의 부활과 따로 세고, 등급이 높으면 더 많이 채운다',
      gameWith(Roster.witch, inventory: withEffect(UniqueEffect.phoenix)),
      (game) async {
        await game.ready();
        stubOverlays(game);
        final player = game.world.player;
        FateSystem.apply(
          fate(FateCard.phoenixFeather, Rarity.unique),
          game.world,
        );

        player.takeDamage(1e9);
        expect(player.hp, closeTo(player.maxHp * Balance.phoenixHp, 1e-9));
        await advance(game, Balance.phoenixInvulnerableTime + 0.1);

        player.takeDamage(1e9);
        expect(
          player.hp,
          closeTo(
            player.maxHp * math.min(1, Balance.phoenixHp * grow(2)),
            1e-9,
          ),
        );
        await advance(game, Balance.phoenixInvulnerableTime + 0.1);

        player.takeDamage(1e9);
        expect(player.isDead, isTrue);
      },
    );

    testWithGame<AshbornGame>(
      '보상 카드: 경험치, 잔불, 드랍 배율이 등급만큼 오른다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final world = game.world;

        FateSystem.apply(fate(FateCard.learningEmber), world);
        FateSystem.apply(fate(FateCard.emberCollector, Rarity.hero), world);
        FateSystem.apply(fate(FateCard.treasureHunter), world);

        expect(world.player.xpMultiplier, 1 + Balance.fateXpGain);
        expect(
          world.fate.emberMultiplier,
          closeTo(1 + Balance.fateEmberGain * grow(1), 1e-9),
        );
        expect(world.fate.dropMultiplier, 1 + Balance.fateDropGain);
      },
    );
  });

  group('저주', () {
    testWithGame<AshbornGame>(
      '하데스의 계약: 적 체력은 고정으로 늘고, 잔불 보상은 등급만큼',
      gameWith(Roster.witch, stage: const Stage(2)),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        FateSystem.apply(fate(FateCard.thickAsh, Rarity.rare), game.world);

        await advance(game, Balance.baseSpawnInterval + 0.1);
        final enemy = game.world.enemies.first;
        expect(
          enemy.maxHp,
          closeTo(
            WaveSystem.enemyHp(game.world.stageTime) *
                const Stage(2).enemyHpMultiplier *
                Balance.curseEnemyHp *
                enemy.kind!.hp,
            enemy.maxHp * 0.02,
          ),
        );

        final multiplier = 1 + Balance.curseEmberGain * grow(1);
        expect(game.world.fate.emberMultiplier, closeTo(multiplier, 1e-9));
        final before = game.inventory.ember;
        game.world.bankEmber(bonus: 10);
        expect(game.inventory.ember - before, (10 * multiplier).round());
      },
    );

    testWithGame<AshbornGame>(
      '믹틀란테쿠틀리의 피의 맹세: 적 피해가 늘고 장비 드랍 확률이 커진다. 여러 장이면 곱해진다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        FateSystem.apply(fate(FateCard.bloodOath), game.world);
        FateSystem.apply(fate(FateCard.bloodOath), game.world);

        final drop = 1 + Balance.curseDropGain;
        expect(game.world.fate.dropMultiplier, drop * drop);
        await advance(game, Balance.baseSpawnInterval + 0.1);
        final enemy = game.world.enemies.first;
        expect(
          enemy.contactDamage,
          closeTo(
            Balance.enemyContactDamage *
                game.world.stage.enemyDamageMultiplier *
                Balance.curseEnemyDamage *
                Balance.curseEnemyDamage *
                enemy.kind!.damage,
            1e-9,
          ),
        );
      },
    );

    testWithGame<AshbornGame>(
      '세트의 대가: 최대 체력은 고정으로 줄고 피해는 등급만큼 는다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;

        FateSystem.apply(fate(FateCard.burningPrice, Rarity.rare), game.world);

        expect(player.maxHp, Roster.witch.maxHp + Balance.curseMaxHp);
        expect(player.hp, player.maxHp);
        expect(
          player.damageMultiplier,
          closeTo(1 + Balance.curseDamage * grow(1), 1e-9),
        );
      },
    );
  });

  testWidgets('클리어 화면에 은총 · 신 · 영역 · 등급, 저주, 종류, 남은 다시 뽑기 횟수가 보인다', (
    tester,
  ) async {
    final game = gameWith(Roster.witch)();
    final curse = fate(FateCard.thickAsh, Rarity.epic);
    game.fateOptions.value = [
      fate(FateCard.hardenedAsh, Rarity.unique),
      curse,
      fate(FateCard.ashLord),
    ];
    game.world.fate.rerolls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StageClearOverlay(game: game, onReturn: () {}),
      ),
    );

    expect(find.text('신의 은총을 하나 고르세요'), findsOneWidget);
    for (final f in game.fateOptions.value) {
      final card = f.card;
      expect(find.text(card.title), findsOneWidget);
      expect(find.text(card.god.name), findsOneWidget);
      expect(find.text(keepWords(card.god.lore)), findsOneWidget);
      expect(
        find.text('${card.god.myth.label} 신화 · ${card.domain.label}'),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('grace-domain-${card.domain.name}')),
        findsOneWidget,
      );
      expect(find.byIcon(card.domain.icon), findsOneWidget);
    }
    expect(find.text(Rarity.unique.label), findsOneWidget);
    expect(find.text(Rarity.epic.label), findsOneWidget);
    expect(find.text(Rarity.legend.label), findsOneWidget);
    expect(find.text('저주'), findsOneWidget);
    expect(find.text(keepWords(curse.description)), findsOneWidget);
    expect(find.text(FateType.reward.label), findsOneWidget);
    expect(find.text('다시 뽑기 (0)'), findsOneWidget);
  });

  test('모든 카드는 나올 수 있는 모든 등급에서 설명이 있다', () {
    for (final card in FateCard.values) {
      for (final rarity in Rarity.values.skip(card.minRarity.index)) {
        expect(Fate(card, rarity).description, isNotEmpty, reason: card.name);
      }
    }
  });
}
