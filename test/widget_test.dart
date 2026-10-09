import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/progress.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/main.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:ashborn/ui/equipment/equipment_screen.dart';
import 'package:ashborn/ui/format.dart';
import 'package:ashborn/ui/hearth/hearth_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:ashborn/ui/screens/character_select_screen.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:ashborn/ui/screens/splash_screen.dart';
import 'package:ashborn/ui/screens/title_screen.dart';
import 'package:ashborn/ui/widgets/ash_button.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 세로 모드 휴대폰(약 9:19.5)과 데스크톱 창 크기.
const phonePortrait = Size(390, 844);
const desktop = Size(480, 960);

void useScreen(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 새 화면은 첫 프레임을 화면 밖에서 준비하므로 한 프레임 더 진행한다.
Future<void> settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 16));
}

/// 장비 화면의 드롭다운 [dropdown] 을 펼쳐 [option] 항목을 고른다.
Future<void> pickOption(
  WidgetTester tester,
  String dropdown,
  String option,
) async {
  await tester.ensureVisible(find.byKey(Key(dropdown)));
  await tester.tap(find.byKey(Key(dropdown)));
  // 메뉴가 펼쳐지는 애니메이션이 끝나야 항목이 눌린다.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.byKey(Key(option)));
  await tester.tap(find.byKey(Key(option)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget gameScreen(CharacterDef character, {Inventory? inventory}) =>
    ProfileScope(
      profile: Profile(inventory: inventory),
      child: MaterialApp(home: GameScreen(character: character)),
    );

void main() {
  for (final size in [phonePortrait, desktop]) {
    testWidgets('스플래시 → 메인 → 캐릭터 선택 → 게임 (${size.width.toInt()}x'
        '${size.height.toInt()})', (tester) async {
      useScreen(tester, size);
      final inventory = Inventory()..addLoot(gold: Roster.hunter.price);
      await tester.pumpWidget(
        AshbornApp(profile: Profile(inventory: inventory)),
      );
      expect(find.byType(SplashScreen), findsOneWidget);

      await settle(tester, SplashScreen.duration.inMilliseconds + 100);
      await settle(tester);
      expect(find.byType(TitleScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('title-start')));
      await settle(tester);
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
      for (final c in Roster.all) {
        expect(find.byKey(Key('pick-${c.id.name}')), findsOneWidget);
      }

      // 사냥꾼은 골드로 해금해야 출정할 수 있다.
      await tester.tap(find.byKey(const Key('pick-hunter')));
      await settle(tester, 300);
      expect(find.byKey(const Key('depart')), findsNothing);
      await tester.tap(find.byKey(const Key('unlock')));
      await settle(tester, 300);
      await tester.tap(find.byKey(const Key('confirm-unlock')));
      await settle(tester, 300);
      expect(inventory.gold, 0);

      await tester.tap(find.byKey(const Key('depart')));
      await settle(tester);

      final screen = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(screen.character, Roster.hunter);
    });
  }

  testWidgets('골드가 모자라면 해금할 수 없고, 공개 예정 캐릭터는 실루엣으로 보인다', (tester) async {
    useScreen(tester, desktop);
    final inventory = Inventory()..addLoot(gold: Roster.witch.price - 1);
    await tester.pumpWidget(
      ProfileScope(
        profile: Profile(inventory: inventory),
        child: const MaterialApp(home: CharacterSelectScreen()),
      ),
    );
    await settle(tester, 300);

    expect(find.byKey(const Key('depart')), findsOneWidget);
    expect(find.text('???'), findsWidgets);

    await tester.tap(find.byKey(const Key('pick-witch')));
    await settle(tester, 300);
    final unlock = tester.widget<AshButton>(find.byKey(const Key('unlock')));
    expect(unlock.onPressed, isNull);
    final price = Roster.witch.price;
    expect(
      find.text('${formatGold(price - 1)} / ${formatGold(price)}'),
      findsOneWidget,
    );
  });

  testWidgets('스플래시는 탭하면 건너뛴다', (tester) async {
    await tester.pumpWidget(AshbornApp(profile: Profile()));
    await settle(tester, 300);

    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    expect(find.byType(TitleScreen), findsOneWidget);
  });

  testWidgets('죽으면 게임 오버가 뜨고 다시 일어서면 런이 초기화된다', (tester) async {
    useScreen(tester, phonePortrait);
    await tester.pumpWidget(gameScreen(Roster.knight));
    await settle(tester, 100);

    final game = tester
        .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
        .game!;
    expect(find.text('보스까지 03:00'), findsOneWidget);

    game.world.player.takeDamage(10000);
    await tester.pump();

    expect(game.paused, isTrue);
    expect(find.text('재가 되었다'), findsOneWidget);

    await tester.tap(find.text('다시 일어서기'));
    await settle(tester, 100);

    expect(game.paused, isFalse);
    expect(find.text('재가 되었다'), findsNothing);
    expect(game.world.player.isDead, isFalse);
    expect(game.stats.hp.value, Roster.knight.maxHp);
  });

  testWidgets('HUD 가 떠 있어도 화면을 끌면 누른 곳의 조이스틱으로 움직인다', (tester) async {
    useScreen(tester, phonePortrait);
    await tester.pumpWidget(gameScreen(Roster.witch));
    await settle(tester, 100);

    final game = tester
        .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
        .game!;
    final start = game.world.player.position.clone();

    final joystick = game.joystick;
    final gesture = await tester.startGesture(const Offset(200, 500));
    await gesture.moveBy(const Offset(20, 0));
    expect(joystick.isHeld, isTrue);
    expect(joystick.origin.x, closeTo(200, 1));
    expect(joystick.delta.x, closeTo(20, 1));

    // 바탕 밖으로 끌면 바탕이 손가락을 따라온다.
    await gesture.moveBy(const Offset(80, 0));
    expect(joystick.origin.x, closeTo(300 - joystick.knobRadius, 1));
    expect(joystick.relativeDelta.x, closeTo(1, 1e-4));

    await settle(tester, 200);
    expect(game.world.player.position.x, greaterThan(start.x));

    await gesture.up();
    await tester.pump();
    expect(game.joystick.isHeld, isFalse);
  });

  testWidgets('레벨이 오르면 게임이 멈추고 고른 만큼 강해진다', (tester) async {
    useScreen(tester, phonePortrait);
    await tester.pumpWidget(gameScreen(Roster.witch));
    await settle(tester, 100);
    final game = tester
        .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
        .game!;
    final player = game.world.player;
    int totalLevels() =>
        player.weapons.fold(0, (sum, w) => sum + w.level) +
        player.passives.values.fold(0, (sum, l) => sum + l);
    final before = totalLevels();

    // 두 레벨이 한꺼번에 오른다.
    game.world.gainXp(LevelSystem.xpToNext(1) + LevelSystem.xpToNext(2));
    await tester.pump();

    expect(game.paused, isTrue);
    expect(find.text('레벨 업'), findsOneWidget);
    expect(find.byKey(const Key('level-up-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('level-up-0')));
    await tester.pump();
    expect(totalLevels(), before + 1);
    expect(find.text('레벨 업'), findsOneWidget);

    await tester.tap(find.byKey(const Key('level-up-1')));
    await tester.pump();
    expect(totalLevels(), before + 2);
    expect(find.text('레벨 업'), findsNothing);
    expect(game.paused, isFalse);
  });

  for (final size in [phonePortrait, desktop]) {
    testWidgets('장비 화면에서 가방의 반지를 끼면 원래 반지는 가방으로 간다 '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      useScreen(tester, size);
      final random = math.Random(4);
      final inventory = Inventory();
      // 칸을 다 채우고 가방도 넉넉히 채워 레이아웃을 확인한다.
      for (var i = 0; i < 40; i++) {
        inventory
            .gear(CharacterId.witch)
            .add(LootSystem.generate(random, rarity: Rarity.unique));
      }
      final ring = LootSystem.generate(random, type: ItemType.ring);
      final gear = inventory.gear(CharacterId.witch);
      gear.add(ring);
      final oldRing = gear.equipped[EquipSlot.ring1]!;
      await tester.pumpWidget(gameScreen(Roster.witch, inventory: inventory));
      await settle(tester, 100);
      final game = tester
          .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
          .game!;

      await tester.tap(find.byKey(const Key('open-pause')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pause-equipment')));
      await tester.pump();
      expect(game.paused, isTrue);
      expect(find.text('장비'), findsOneWidget);

      final index = inventory.bag.indexOf(ring);
      // 가방이 가득해도 등급 · 부위 드롭다운으로 반지만 추려 찾는다.
      await pickOption(tester, 'filter-type', 'filter-type-ring');
      await pickOption(
        tester,
        'filter-rarity',
        'filter-rarity-${ring.rarity.name}',
      );
      for (final (i, item) in inventory.bag.indexed) {
        final visible =
            item.type == ItemType.ring && item.rarity == ring.rarity;
        expect(
          find.byKey(Key('bag-$i')),
          visible ? findsOneWidget : findsNothing,
        );
      }
      await tester.tap(find.byKey(Key('bag-$index')));
      await tester.pump();
      expect(find.text(ring.name), findsWidgets);

      await tester.tap(find.byKey(const Key('equip-ring1')));
      await tester.pump();
      expect(gear.equipped[EquipSlot.ring1], ring);
      expect(inventory.bag, contains(oldRing));

      // 닫으면 멈춘 채 일시정지 메뉴로 돌아오고, 계속하기로 이어 간다.
      await tester.tap(find.byKey(const Key('close-equipment')));
      await tester.pump();
      expect(find.byKey(const Key('close-equipment')), findsNothing);
      expect(find.byKey(const Key('pause-resume')), findsOneWidget);
      expect(game.paused, isTrue);

      await tester.tap(find.byKey(const Key('pause-resume')));
      await tester.pump();
      expect(game.paused, isFalse);
    });
  }

  group('출발 전 장비 화면', () {
    Future<Inventory> openFor(
      WidgetTester tester,
      CharacterDef character, {
      required void Function(Inventory) fill,
    }) async {
      useScreen(tester, phonePortrait);
      final inventory = Inventory();
      fill(inventory);
      await tester.pumpWidget(
        ProfileScope(
          profile: Profile(inventory: inventory),
          child: const MaterialApp(home: CharacterSelectScreen()),
        ),
      );
      await settle(tester, 300);
      await tester.tap(find.byKey(Key('pick-${character.id.name}')));
      await settle(tester, 300);
      await tester.tap(find.byKey(const Key('open-equipment')));
      await settle(tester);
      return inventory;
    }

    testWidgets('캐릭터 선택에서 그 캐릭터의 장비를 보고 바꾼다', (tester) async {
      final helm = item(ItemType.head, rarity: Rarity.rare, value: 25);
      final inventory = await openFor(
        tester,
        Roster.hunter,
        fill: (inv) => inv
          ..gear(CharacterId.knight).add(helm)
          ..gear(CharacterId.knight).unequip(EquipSlot.head),
      );
      expect(find.byType(EquipmentScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EquipmentScreen),
          matching: find.text(Roster.hunter.name),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      // 빈 칸에 끼우므로 오르기만 한다.
      expect(find.text('빈 칸'), findsOneWidget);
      expect(find.text('▲ 최대 체력 +25'), findsOneWidget);

      await tester.tap(find.byKey(const Key('equip-head')));
      await tester.pump();
      expect(inventory.gear(CharacterId.hunter).equipped[EquipSlot.head], helm);
      expect(inventory.gear(CharacterId.knight).equipped, isEmpty);

      await tester.tap(find.byKey(const Key('close-equipment')));
      await settle(tester);
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
    });

    testWidgets('장착 칸은 캐릭터 양옆에 부위 순서로 놓이고, 양손장비면 왼손이 막힌다', (tester) async {
      await openFor(
        tester,
        Roster.witch,
        fill: (inv) => inv.gear(CharacterId.witch).add(item(ItemType.twoHand)),
      );
      expect(find.byKey(const Key('paper-doll')), findsOneWidget);
      Offset center(String slot) =>
          tester.getCenter(find.byKey(Key('slot-$slot')));

      // 캐릭터 양옆에 칸이 늘어서고 (귀걸이 · 손 · 반지는 좌우 한 쌍), 장화는 발밑.
      for (final (left, right) in [
        ('earring1', 'earring2'),
        ('hand2-blocked', 'hand1'),
        ('ring1', 'ring2'),
      ]) {
        expect(center(left).dx, lessThan(center(right).dx));
      }
      // 짝이 있는 칸은 양쪽 같은 줄.
      for (final (left, right) in [
        ('earring1', 'earring2'),
        ('hand2-blocked', 'hand1'),
        ('ring1', 'ring2'),
      ]) {
        expect(center(left).dy, closeTo(center(right).dy, 1));
      }
      expect(center('head').dy, lessThan(center('earring1').dy));
      expect(center('boots').dy, greaterThan(center('belt').dy));
      expect(
        center('boots').dx,
        closeTo(tester.getCenter(find.byKey(const Key('paper-doll'))).dx, 1),
      );

      expect(find.byKey(const Key('slot-hand2')), findsNothing);
      expect(find.byKey(const Key('slot-hand2-blocked')), findsOneWidget);
      expect(find.text('양손 사용'), findsOneWidget);
    });

    testWidgets('가방을 등급과 부위로 거른다', (tester) async {
      final inventory = await openFor(
        tester,
        Roster.witch,
        fill: (inv) {
          final gear = inv.gear(CharacterId.witch);
          for (final i in [
            item(ItemType.ring),
            item(ItemType.ring),
            item(ItemType.ring, rarity: Rarity.legend),
            item(ItemType.head, rarity: Rarity.legend),
            item(ItemType.twoHand, rarity: Rarity.legend),
            item(ItemType.oneHand),
            item(ItemType.oneHand),
          ]) {
            gear.add(i);
          }
          // 빈 칸에 바로 끼워진 것까지 모두 가방으로 뺀다.
          for (final slot in EquipSlot.values) {
            gear.unequip(slot);
          }
        },
      );
      expect(inventory.bag, hasLength(7));
      List<int> shown() => [
        for (var i = 0; i < inventory.bag.length; i++)
          if (find.byKey(Key('bag-$i')).evaluate().isNotEmpty) i,
      ];
      String label(String dropdown) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(Key(dropdown)),
              matching: find.byType(Text),
            ),
          )
          .single
          .data!;

      expect(shown(), hasLength(inventory.bag.length));
      expect(
        (label('filter-rarity'), label('filter-type')),
        ('전체 등급', '전체 부위'),
      );
      await pickOption(tester, 'filter-rarity', 'filter-rarity-legend');
      // 펼친 메뉴는 닫히고, 버튼에는 고른 등급이 보인다.
      expect(find.byKey(const Key('filter-rarity-rare')), findsNothing);
      expect(label('filter-rarity'), '전설');
      expect(shown().map((i) => inventory.bag[i].rarity).toSet(), {
        Rarity.legend,
      });
      expect(
        find.text('가방 7 / ${Balance.bagCapacity} · 3개 표시'),
        findsOneWidget,
      );
      // 무기는 한손 · 양손을 함께 본다.
      await pickOption(tester, 'filter-type', 'filter-type-weapon');
      expect(label('filter-type'), '무기');
      expect(shown().map((i) => inventory.bag[i].type).toSet(), {
        ItemType.twoHand,
      });
      await pickOption(tester, 'filter-rarity', 'filter-rarity-all');
      expect(
        shown().map((i) => inventory.bag[i].type).toSet(),
        containsAll([ItemType.twoHand]),
      );
      expect(
        shown().every(
          (i) => {
            ItemType.oneHand,
            ItemType.twoHand,
          }.contains(inventory.bag[i].type),
        ),
        isTrue,
      );
      await pickOption(tester, 'filter-type', 'filter-type-all');
      expect(shown(), hasLength(inventory.bag.length));

      // 걸러서 하나도 없으면 안내와 필터 초기화 버튼을 보여 준다.
      await pickOption(tester, 'filter-type', 'filter-type-boots');
      expect(find.text('조건에 맞는 장비가 없습니다'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-reset')));
      await tester.pump();
      expect(shown(), hasLength(inventory.bag.length));
      expect(label('filter-type'), '전체 부위');
    });

    testWidgets('정렬 드롭다운으로 가방을 최근 획득 · 등급 · 레벨 · 강화 순으로 본다', (tester) async {
      final normal = item(ItemType.ring);
      final legend = item(ItemType.ring, rarity: Rarity.legend);
      final rare = item(ItemType.ring, rarity: Rarity.rare)..enhance = 5;
      final inventory = await openFor(
        tester,
        Roster.witch,
        fill: (inv) {
          final gear = inv.gear(CharacterId.witch);
          for (final i in [normal, legend, rare]) {
            gear.add(i);
          }
          gear
            ..unequip(EquipSlot.ring1)
            ..unequip(EquipSlot.ring2);
        },
      );
      // 가방에 들어온 순서: rare(바로 가방), normal · legend(해제한 순서).
      expect(inventory.bag, [rare, normal, legend]);
      List<Item> order() {
        final tiles = [
          for (var i = 0; i < inventory.bag.length; i++)
            (tester.getTopLeft(find.byKey(Key('bag-$i'))), inventory.bag[i]),
        ]..sort((a, b) => a.$1.dx.compareTo(b.$1.dx));
        return [for (final (_, item) in tiles) item];
      }

      // 기본은 최근에 가방에 들어온 것부터.
      expect(order(), [legend, normal, rare]);
      await pickOption(tester, 'sort', 'sort-rarity');
      expect(order(), [legend, rare, normal]);
      await pickOption(tester, 'sort', 'sort-enhance');
      expect(order().first, rare);
      await pickOption(tester, 'sort', 'sort-recent');
      expect(order(), [legend, normal, rare]);
    });

    testWidgets('일괄 분해: 등급을 골라 가방의 장비를 한 번에 분해한다', (tester) async {
      final normal = item(ItemType.ring);
      final rare = item(ItemType.head, rarity: Rarity.rare);
      final enhanced = item(ItemType.ring)..enhance = 3;
      final hero = item(ItemType.belt, rarity: Rarity.hero);
      final worn = item(ItemType.boots);
      final inventory = await openFor(
        tester,
        Roster.witch,
        fill: (inv) {
          final gear = inv.gear(CharacterId.witch);
          for (final i in [normal, rare, enhanced, hero]) {
            gear.add(i);
          }
          for (final slot in EquipSlot.values) {
            gear.unequip(slot);
          }
          // 장착 중인 장비는 대상이 아니다.
          gear.add(worn);
        },
      );
      expect(inventory.bag, hasLength(4));

      await tester.tap(find.byKey(const Key('bulk-salvage')));
      await settle(tester, 300);
      String summary() =>
          tester.widget<Text>(find.byKey(const Key('bulk-summary'))).data!;
      // 기본: 노말 · 레어, 강화한 장비 제외.
      expect(
        summary(),
        '대상 2개 · 잔불 +${normal.salvageValue + rare.salvageValue}',
      );
      expect(find.byKey(const Key('bulk-warning')), findsNothing);

      // 강화한 장비 제외를 끄면 강화한 노말도 들어간다.
      await tester.tap(find.byKey(const Key('bulk-keep-upgraded')));
      await tester.pump();
      expect(summary(), startsWith('대상 3개'));
      await tester.tap(find.byKey(const Key('bulk-keep-upgraded')));
      await tester.pump();

      // 영웅을 고르면 경고한다.
      await tester.tap(find.byKey(const Key('bulk-rarity-hero')));
      await tester.pump();
      expect(summary(), startsWith('대상 3개'));
      expect(find.byKey(const Key('bulk-warning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk-rarity-hero')));
      await tester.pump();

      // 취소하면 아무것도 사라지지 않는다.
      await tester.tap(find.byKey(const Key('cancel-bulk-salvage')));
      await settle(tester, 300);
      expect(inventory.bag, hasLength(4));

      await tester.tap(find.byKey(const Key('bulk-salvage')));
      await settle(tester, 300);
      await tester.tap(find.byKey(const Key('confirm-bulk-salvage')));
      await settle(tester, 300);
      expect(inventory.bag, unorderedEquals([enhanced, hero]));
      expect(inventory.ember, normal.salvageValue + rare.salvageValue);
      expect(inventory.gear(CharacterId.witch).equipped.values, [worn]);
      expect(find.byKey(const Key('bag-notice')), findsOneWidget);
    });

    testWidgets('교체하면 바뀌는 능력치를 비교해 보여 준다', (tester) async {
      await openFor(
        tester,
        Roster.witch,
        fill: (inv) => inv.gear(CharacterId.witch)
          ..add(item(ItemType.head, value: 30))
          ..add(
            item(
              ItemType.head,
              value: 20,
              extra: [
                (stat: StatType.fireResist, value: 0.1, rarity: Rarity.normal),
              ],
            ),
          ),
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();

      expect(find.text('▼ 최대 체력 -10'), findsOneWidget);
      expect(find.text('▲ 화염 저항 +10%'), findsOneWidget);
    });

    testWidgets('강화를 계승하면 계승 후 능력치로 비교한다', (tester) async {
      await openFor(
        tester,
        Roster.witch,
        fill: (inv) => inv.gear(CharacterId.witch)
          ..add(item(ItemType.head, value: 30)..enhance = 10)
          ..add(item(ItemType.head, value: 30)),
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();

      // 같은 수치에 강화도 그대로 넘어오니 잃는 능력치가 없다.
      expect(find.text('강화 계승 +0 → +10'), findsOneWidget);
      expect(find.textContaining('▼ 최대 체력'), findsNothing);
    });

    testWidgets('강화석과 골드로 강화하고 비용 · 확률 · 결과를 보여 준다', (tester) async {
      final helm = item(ItemType.head);
      final inventory = await openFor(
        tester,
        Roster.witch,
        fill: (inv) => inv
          ..addLoot(gold: helm.enhanceGold, stones: helm.enhanceStones)
          ..gear(CharacterId.witch).add(helm)
          ..gear(CharacterId.witch).unequip(EquipSlot.head),
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('enhance-cost'))).data,
        '강화석 ${helm.enhanceStones} · 골드 ${helm.enhanceGold} · 성공 100%',
      );

      await tester.tap(find.byKey(const Key('enhance')));
      await tester.pump();

      expect(helm.enhance, 1);
      expect((inventory.gold, inventory.stones), (0, 0));
      expect(find.text('강화 성공! +1'), findsOneWidget);
      expect(find.text('골드 0 · 강화석 0 · 초월석 0'), findsOneWidget);
    });

    testWidgets('영웅 이상 장비는 분해하기 전에 한 번 더 묻는다', (tester) async {
      final hero = item(ItemType.ring, rarity: Rarity.hero);
      final normal = item(ItemType.ring);
      final inventory = await openFor(
        tester,
        Roster.witch,
        fill: (inv) {
          final gear = inv.gear(CharacterId.witch);
          for (final ring in [
            item(ItemType.ring),
            item(ItemType.ring),
            hero,
            normal,
          ]) {
            gear.add(ring);
          }
        },
      );

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('salvage')));
      await tester.tap(find.byKey(const Key('salvage')));
      await tester.pump();
      expect(find.byKey(const Key('confirm-salvage')), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pump();
      expect(inventory.bag, contains(hero));

      await tester.tap(find.byKey(const Key('salvage')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-salvage')));
      await tester.pump();
      expect(inventory.bag, [normal]);

      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('salvage')));
      await tester.tap(find.byKey(const Key('salvage')));
      await tester.pump();
      expect(find.byKey(const Key('confirm-salvage')), findsNothing);
      expect(inventory.bag, isEmpty);
    });
  });

  testWidgets('캐릭터 선택에서 화톳불을 열어 강화를 살 수 있다', (tester) async {
    useScreen(tester, phonePortrait);
    await tester.pumpWidget(
      ProfileScope(
        profile: Profile(),
        child: const MaterialApp(home: CharacterSelectScreen()),
      ),
    );
    await settle(tester, 300);

    await tester.tap(find.byKey(const Key('open-hearth')));
    await settle(tester);

    expect(find.byType(HearthScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-hearth')));
    // 첫 프레임에 닫는 전환이 시작된다.
    await tester.pump();
    await settle(tester);
    expect(find.byType(HearthScreen), findsNothing);
  });

  testWidgets('출정할 스테이지는 클리어한 다음 스테이지까지 고를 수 있다', (tester) async {
    useScreen(tester, phonePortrait);
    final progress = Progress()..recordClear(const Stage(5));
    await tester.pumpWidget(
      ProfileScope(
        profile: Profile(progress: progress),
        child: const MaterialApp(home: CharacterSelectScreen()),
      ),
    );
    await settle(tester, 300);

    String shown() =>
        tester.widget<Text>(find.byKey(const Key('stage-name'))).data!;
    expect(shown(), const Stage(6).name);

    await tester.tap(find.byKey(const Key('stage-next')));
    await tester.pump();
    expect(shown(), const Stage(6).name);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('stage-prev')));
      await tester.pump();
    }
    expect(shown(), Stage.first.name);

    await tester.tap(find.byKey(const Key('stage-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('depart')));
    await settle(tester);

    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.stage, const Stage(1));
  });
}
