import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/systems/fate_system.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:ashborn/ui/odds/odds_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:ashborn/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _sum(double Function(Rarity) chance) =>
    Rarity.values.fold(0, (s, r) => s + chance(r));

void main() {
  group('확률 계산', () {
    test('등급 운이 있어도 등급 확률의 합은 1 이고, 높은 등급이 늘어난다', () {
      for (final luck in [0.0, 0.3, 1.0, 10.0]) {
        expect(
          _sum((r) => LootSystem.rarityChance(r, luck: luck)),
          closeTo(1, 1e-9),
        );
      }
      expect(
        LootSystem.rarityChance(Rarity.unique, luck: 0.5),
        greaterThan(LootSystem.rarityChance(Rarity.unique)),
      );
    });

    test('보스 상자는 노말이 없고 레어 이상 합이 1 이다', () {
      expect(LootSystem.bossChestChance(Rarity.normal), 0);
      expect(_sum(LootSystem.bossChestChance), closeTo(1, 1e-9));
      expect(
        LootSystem.bossChestChance(Rarity.rare),
        closeTo(
          LootSystem.rarityChance(Rarity.normal) +
              LootSystem.rarityChance(Rarity.rare),
          1e-9,
        ),
      );
    });

    test('은총 카드 등급 확률도 같은 식이다', () {
      expect(
        _sum((r) => LootSystem.rarityChance(r, ratio: Balance.fateRarityRatio)),
        closeTo(1, 1e-9),
      );
    });

    test('퍼센트 표기는 작은 확률도 0 으로 감추지 않는다', () {
      expect(pct(1), '100%');
      expect(pct(0.25), '25%');
      expect(pct(0.188), '18.8%');
      expect(pct(0.0007324), '0.0732%');
      expect(pct(0), '0%');
    });
  });

  group('확률 정보 화면', () {
    testWidgets('설정에서 열고, 드랍 · 은총 확률과 강화 · 초월은 확률이 없다는 안내를 보여 준다', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProfileScope(
          profile: Profile(),
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      final open = find.byKey(const Key('open-odds'));
      await tester.scrollUntilVisible(open, 100);
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(find.byType(OddsScreen), findsOneWidget);
      for (final title in ['장비 강화 · 초월', '장비 드랍', '랜덤옵션', '재화', '신의 은총']) {
        await tester.scrollUntilVisible(find.text(title), 200);
        expect(find.text(title), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('close-odds')));
      await tester.pumpAndSettle();
      expect(find.byType(OddsScreen), findsNothing);
    });

    testWidgets('타락 단계가 있으면 지금 받는 확률을 함께 보여 준다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OddsList(corruption: 2, fateLuck: 0.1)),
        ),
      );
      await tester.scrollUntilVisible(find.text('장비 드랍'), 200);
      await tester.pumpAndSettle();
      expect(find.text('타락 2'), findsWidgets);
    });

    testWidgets('신의 은총: 모든 카드와 그 확률(기본 · 지금)을 계산값 그대로 보여 준다', (tester) async {
      const luck = 0.3;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OddsList(corruption: 0, fateLuck: luck)),
        ),
      );
      for (final card in FateCard.values) {
        final label =
            '${card.title} (${card.domain.label}${card.curse ? ' · 저주' : ''})';
        await tester.scrollUntilVisible(find.text(label), 200);
        final row = find.ancestor(
          of: find.text(label),
          matching: find.byType(Table),
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(pct(FateSystem.cardChance(card))),
          ),
          findsWidgets,
          reason: card.title,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(pct(FateSystem.cardChance(card, luck: luck))),
          ),
          findsWidgets,
          reason: card.title,
        );
      }
    });
  });
}
