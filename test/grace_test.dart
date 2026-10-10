import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/fate_system.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fate_test.dart' show fate, grow;
import 'helpers.dart';

/// 신의 은총: 신 정보, 영역, 원소 은총, 확률 공개.
void main() {
  group('신과 영역', () {
    test('모든 카드에 신 이름 · 신화 · 소개가 있고, 은총 이름에 신 이름이 들어간다', () {
      for (final card in FateCard.values) {
        expect(card.god.name, isNotEmpty, reason: card.name);
        expect(card.god.lore.length, greaterThan(8), reason: card.name);
        expect(card.title, contains(card.god.name), reason: card.name);
      }
      // 한 신은 한 장만 맡는다.
      final gods = FateCard.values.map((c) => c.god.name).toSet();
      expect(gods.length, FateCard.values.length);
    });

    test('영역마다 3장 이상, 신화는 여러 곳에서 고르게', () {
      for (final domain in GraceDomain.values) {
        expect(
          FateCard.values.where((c) => c.domain == domain).length,
          greaterThanOrEqualTo(3),
          reason: domain.label,
        );
      }
      final myths = FateCard.values.map((c) => c.god.myth).toSet();
      expect(myths, containsAll(Myth.values));
      for (final myth in Myth.values) {
        expect(
          FateCard.values.where((c) => c.god.myth == myth).length,
          lessThanOrEqualTo(FateCard.values.length ~/ 4),
          reason: '${myth.label} 신화에 몰리지 않는다',
        );
      }
    });

    test('저주는 모두 죽음의 영역이다', () {
      for (final card in FateCard.values.where((c) => c.curse)) {
        expect(card.domain, GraceDomain.death, reason: card.name);
      }
    });

    test('원소 은총은 다섯 속성에 한 장씩, 스킬 종류다', () {
      final elements = {
        for (final card in FateCard.values) ?card.element: card,
      };
      expect(elements.keys, unorderedEquals(DamageType.values));
      expect(elements[DamageType.fire]!.domain, GraceDomain.fire);
      expect(elements[DamageType.cold]!.domain, GraceDomain.cold);
      expect(elements[DamageType.lightning]!.domain, GraceDomain.lightning);
      expect(elements[DamageType.wind]!.domain, GraceDomain.wind);
      expect(elements[DamageType.physical]!.domain, GraceDomain.earth);
      for (final card in elements.values) {
        expect(card.type, FateType.skill);
      }
    });
  });

  group('원소 은총', () {
    testWithGame<AshbornGame>(
      '모든 타격에 기본 피해의 일정 비율만큼 속성 피해를 더한다 (추가 타격은 제외)',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0), hp: 1e9);
        final player = game.world.player;

        expect(player.strike(enemy, 100, DamageType.physical), 100);

        FateSystem.apply(fate(FateCard.fireGrace, Rarity.hero), game.world);
        final ratio = Balance.fateElementDamage * grow(1);
        expect(game.world.fate.extraDamage(DamageType.fire), ratio);
        expect(game.world.fate.extraDamage(DamageType.cold), 0);
        expect(
          player.strike(enemy, 100, DamageType.physical),
          closeTo(100 * (1 + ratio), 1e-9),
        );
        expect(
          player.strike(enemy, 100, DamageType.physical, secondary: true),
          100,
        );

        // 같은 카드를 또 받으면 더해진다.
        FateSystem.apply(fate(FateCard.fireGrace), game.world);
        expect(
          game.world.fate.extraDamage(DamageType.fire),
          closeTo(ratio + Balance.fateElementDamage, 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '더해진 화염 피해가 물리 타격에도 쌓여 점화된다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        await clearEnemies(game);
        final enemy = await addEnemy(game, Vector2(5000, 0));
        final player = game.world.player;

        player.strike(enemy, enemy.ailmentThreshold, DamageType.physical);
        expect(enemy.ailments.fireBuildup, 0);

        FateSystem.apply(fate(FateCard.fireGrace), game.world);
        player.strike(enemy, 10, DamageType.physical);
        expect(
          enemy.ailments.fireBuildup,
          closeTo(
            10 * Balance.fateElementDamage * (1 + Balance.fateElementBuildup),
            1e-6,
          ),
        );
      },
    );

    testWithGame<AshbornGame>(
      '원소 은총은 출혈 확률 · 원소 축적을 속성에 맞게, 바람은 이동 속도를 준다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final speed = player.speed;
        final ailment = Balance.fateElementAilment * grow(2);
        final buildup = Balance.fateElementBuildup * grow(2);
        for (final card in [
          FateCard.fireGrace,
          FateCard.coldGrace,
          FateCard.lightningGrace,
          FateCard.warGrace,
          FateCard.windGrace,
        ]) {
          FateSystem.apply(fate(card, Rarity.legend), game.world);
        }

        expect(player.bonus(StatType.burnChance), closeTo(buildup, 1e-9));
        expect(player.bonus(StatType.chillChance), closeTo(buildup, 1e-9));
        expect(player.bonus(StatType.shockChance), closeTo(buildup, 1e-9));
        expect(player.bonus(StatType.bleedChance), closeTo(ailment, 1e-9));
        expect(
          player.speed,
          closeTo(
            speed + Roster.witch.speed * Balance.fateWindMoveSpeed * grow(2),
            1e-9,
          ),
        );
        expect(fate(FateCard.windGrace).description, contains('바람 피해'));
      },
    );

    testWithGame<AshbornGame>(
      '새 스탯 은총: 보호막 · 치명타 피해 · 회피 · 물리 피해 감소 · 체력 재생',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final expected = {
          FateCard.frostVeil: (StatType.energyShield, Balance.fateEnergyShield),
          FateCard.thunderAxe: (StatType.critDamage, Balance.fateCritDamage),
          FateCard.galeStep: (StatType.evasion, Balance.fateEvasion),
          FateCard.oathShield: (
            StatType.physicalReduction,
            Balance.fatePhysicalReduction,
          ),
          FateCard.renewal: (StatType.hpRegen, Balance.fateHpRegen),
        };
        for (final MapEntry(key: card, value: (stat, base))
            in expected.entries) {
          final before = player.bonus(stat);
          FateSystem.apply(fate(card, Rarity.rare), game.world);
          expect(
            player.bonus(stat) - before,
            closeTo(base * grow(1), 1e-9),
            reason: card.title,
          );
        }
        expect(
          player.maxEnergyShield,
          closeTo(Balance.fateEnergyShield * grow(1), 1e-9),
        );
      },
    );
  });

  group('확률 공개', () {
    test('종류마다 카드별 확률을 더하면 1, 종류별 평균 장수를 더하면 카드 수', () {
      for (final luck in [0.0, 0.5]) {
        for (final type in FateType.values) {
          final sum = FateCard.values
              .where((c) => c.type == type)
              .fold(0.0, (s, c) => s + FateSystem.cardChance(c, luck: luck));
          expect(sum, closeTo(1, 1e-9), reason: '${type.label} 운 $luck');
        }
      }
      for (final count in [Balance.fateChoices, Balance.fateChoices + 1]) {
        expect(
          FateType.values.fold(
            0.0,
            (s, t) => s + FateSystem.expectedTypeCount(t, count),
          ),
          closeTo(count, 1e-9),
        );
      }
      expect(
        FateSystem.expectedTypeCount(FateType.reward, 1),
        closeTo(1 / 3, 1e-9),
      );
    });

    testWithGame<AshbornGame>(
      '확률표의 카드별 확률과 종류별 평균 장수는 실제 추첨과 같다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        const rolls = 30000;
        final random = math.Random(11);
        final first = <FateCard, int>{};
        final types = <FateType, int>{};
        for (var i = 0; i < rolls; i++) {
          final hand = FateSystem.roll(
            stage: game.world.stage,
            upgrades: game.upgrades,
            random: random,
          );
          first.update(hand.first.card, (n) => n + 1, ifAbsent: () => 1);
          for (final f in hand) {
            types.update(f.card.type, (n) => n + 1, ifAbsent: () => 1);
          }
        }

        // 첫 장은 세 종류 중 하나를 같은 확률로 고른 뒤 그 종류에서 뽑는다.
        for (final card in FateCard.values) {
          expect(
            (first[card] ?? 0) / rolls,
            closeTo(
              FateSystem.cardChance(card) / FateType.values.length,
              0.006,
            ),
            reason: card.title,
          );
        }
        for (final type in FateType.values) {
          expect(
            types[type]! / rolls,
            closeTo(
              FateSystem.expectedTypeCount(type, Balance.fateChoices),
              0.03,
            ),
            reason: type.label,
          );
        }
      },
    );
  });
}
