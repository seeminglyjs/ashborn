import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/profile.dart';
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

    test('운명 카드 등급 확률도 같은 식이다', () {
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
    testWidgets('설정에서 열고, 강화 · 초월 · 드랍 · 운명 확률을 보여 준다', (tester) async {
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
      for (final title in ['장비 강화', '장비 초월', '장비 드랍', '랜덤옵션', '재화', '운명 카드']) {
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
  });
}
