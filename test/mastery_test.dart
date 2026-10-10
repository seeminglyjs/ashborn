import 'package:ashborn/components/weapons/greatsword.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/class_passives.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:ashborn/ui/mastery/mastery_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// [character] 숙련을 [levels] 레벨만큼 쌓은 기록.
Mastery leveled(CharacterId character, int levels) {
  final mastery = Mastery();
  var xp = 0.0;
  for (var l = 0; l < levels; l++) {
    xp += Mastery.xpToNext(l);
  }
  // 부동소수 오차로 한 레벨 모자라지 않게 조금 더 준다.
  return mastery..addXp(character, xp + 1);
}

/// [passive] 를 [level] 까지 올린 기록.
Mastery withPassive(ClassPassive passive, int level) {
  final mastery = leveled(passive.owner, level);
  for (var i = 0; i < level; i++) {
    mastery.raise(passive);
  }
  return mastery;
}

void main() {
  group('직업 숙련', () {
    test('직업마다 고유 패시브가 셋이고, 레벨마다 수치가 오른다', () {
      for (final c in CharacterId.values) {
        expect(ClassPassive.of(c), hasLength(3));
      }
      for (final p in ClassPassive.values) {
        expect(p.value(0), 0);
        expect(p.value(2), isNot(p.value(1)));
        expect(p.effect(ClassPassive.maxLevel), isNotEmpty);
      }
      expect(ClassPassive.parry.value(1), Balance.parryChance);
      expect(
        ClassPassive.parry.value(ClassPassive.maxLevel),
        closeTo(
          Balance.parryChance +
              Balance.parryChancePerLevel * (ClassPassive.maxLevel - 1),
          1e-9,
        ),
      );
    });

    test('숙련 경험치가 쌓여 레벨이 오르면 포인트를 얻고, 패시브에 쓴다', () {
      final mastery = Mastery()
        ..addXp(CharacterId.knight, Mastery.xpToNext(0) - 1);
      expect(mastery.level(CharacterId.knight), 0);
      expect(mastery.canRaise(ClassPassive.parry), isFalse);

      mastery.addXp(CharacterId.knight, 1);
      expect(mastery.level(CharacterId.knight), 1);
      expect(mastery.points(CharacterId.knight), 1);
      expect(mastery.points(CharacterId.witch), 0, reason: '캐릭터마다 따로');

      mastery.raise(ClassPassive.parry);
      expect(mastery.passiveLevel(ClassPassive.parry), 1);
      expect(mastery.points(CharacterId.knight), 0);
      expect(mastery.canRaise(ClassPassive.ironWill), isFalse);
      expect(Mastery.xpToNext(5), greaterThan(Mastery.xpToNext(4)));
    });

    test('골드를 내면 포인트를 모두 되돌린다', () {
      final mastery = withPassive(ClassPassive.envenom, 3);
      final inventory = Inventory();
      expect(mastery.canReset(CharacterId.hunter, inventory), isFalse);
      inventory.addLoot(gold: mastery.resetCost(CharacterId.hunter));

      mastery.reset(CharacterId.hunter, inventory);

      expect(inventory.gold, 0);
      expect(mastery.passiveLevel(ClassPassive.envenom), 0);
      expect(mastery.points(CharacterId.hunter), 3);
    });

    test('저장했다 불러와도 그대로이고, 클라우드에도 함께 올라간다', () {
      final mastery = withPassive(ClassPassive.spellEcho, 2)
        ..addXp(CharacterId.knight, 10);
      final loaded = Mastery.fromJson(mastery.toJson());

      expect(loaded.xp(CharacterId.knight), 10);
      expect(loaded.passiveLevel(ClassPassive.spellEcho), 2);
      expect(loaded.points(CharacterId.witch), 0);
      expect(Profile.syncedKeys, contains(Profile.masteryKey));
      expect(Mastery.fromJson(const {}).xp(CharacterId.witch), 0);
    });
  });

  group('직업 패시브 효과', () {
    testWithGame<AshbornGame>(
      '튕겨내기: 막아 내면 피해를 받지 않고 공격한 적이 다친다',
      gameWith(Roster.knight, mastery: withPassive(ClassPassive.parry, 10)),
      (game) async {
        await game.ready();
        // 몰려드는 졸개에 부딪혀 무적 시간이 겹치지 않도록 웨이브를 멈춘다.
        game.world.children.whereType<WaveSystem>().toList().forEach(
          game.world.remove,
        );
        await clearEnemies(game);
        final player = game.world.player;
        final enemy = await addEnemy(game, Vector2(5000, 0), hp: 1e9);

        var parried = false;
        for (var i = 0; i < 200 && !parried; i++) {
          final hp = player.hp;
          final hit = player.takeDamage(10, source: enemy);
          parried = !hit && player.hp == hp && enemy.hp < enemy.maxHp;
          await advance(game, Balance.playerInvulnerableTime + 0.05);
          player.heal(1000);
        }
        expect(parried, isTrue);
      },
    );

    testWithGame<AshbornGame>(
      '강철 의지: 받는 피해가 줄어든다',
      gameWith(Roster.knight, mastery: withPassive(ClassPassive.ironWill, 10)),
      (game) async {
        await game.ready();
        final player = game.world.player;
        final hp = player.hp;
        player.takeDamage(100, type: DamageType.fire);
        final reduction = ClassPassive.ironWill.value(10);
        expect(
          hp - player.hp,
          closeTo(
            100 * Roster.knight.damageTakenMultiplier * (1 - reduction),
            1e-6,
          ),
        );
      },
    );

    testWithGame<AshbornGame>(
      '연격 숙련: 대검 콤보 확률이 오른다',
      gameWith(
        Roster.knight,
        mastery: withPassive(ClassPassive.swordMastery, 5),
      ),
      (game) async {
        await game.ready();
        final sword =
            game.world.player.weapon(WeaponId.greatsword)! as Greatsword;
        expect(
          sword.comboChance,
          closeTo(ClassPassive.swordMastery.value(5), 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '다른 직업의 패시브는 붙지 않는다',
      gameWith(Roster.witch, mastery: withPassive(ClassPassive.envenom, 5)),
      (game) async {
        await game.ready();
        expect(game.world.player.bonus(StatType.poisonChance), 0);
      },
    );

    testWithGame<AshbornGame>(
      '맹독 바르기 · 급소 노리기: 능력치로 붙는다',
      gameWith(
        Roster.hunter,
        mastery: withPassive(ClassPassive.envenom, 4)
          ..addXp(CharacterId.hunter, 1e9)
          ..raise(ClassPassive.weakSpot),
      ),
      (game) async {
        await game.ready();
        final player = game.world.player;
        expect(
          player.bonus(StatType.poisonChance),
          closeTo(ClassPassive.envenom.value(4), 1e-9),
        );
        expect(
          player.bonus(StatType.critDamage),
          closeTo(ClassPassive.weakSpot.value2(1), 1e-9),
        );
      },
    );

    testWithGame<AshbornGame>(
      '재의 장막: 피해를 한 번 막고 시간이 지나면 다시 생긴다',
      gameWith(Roster.witch, mastery: withPassive(ClassPassive.ashVeil, 1)),
      (game) async {
        await game.ready();
        game.world.children.whereType<WaveSystem>().toList().forEach(
          game.world.remove,
        );
        await clearEnemies(game);
        final player = game.world.player;
        final hp = player.hp;
        expect(player.hasVeil, isTrue);

        expect(player.takeDamage(10), isFalse);
        expect(player.hp, hp);
        expect(player.hasVeil, isFalse);

        await advance(game, ClassPassive.ashVeil.value(1) + 0.1);
        expect(player.hasVeil, isTrue);
      },
    );

    testWithGame<AshbornGame>(
      '런이 끝나면 모은 경험치가 그 캐릭터의 숙련으로 쌓인다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        game.world.gainXp(3);
        game.quitRun();

        expect(game.mastery.xp(CharacterId.witch), 3);
        expect(game.world.runMastery, 3);
        expect(game.mastery.xp(CharacterId.knight), 0);
      },
    );
  });

  testWidgets('숙련 화면에서 포인트로 패시브를 올린다', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = Profile(mastery: leveled(CharacterId.knight, 2));
    await tester.pumpWidget(
      ProfileScope(
        profile: profile,
        child: const MaterialApp(home: MasteryScreen(character: Roster.knight)),
      ),
    );

    expect(find.text('남은 포인트 2'), findsOneWidget);
    expect(find.text('튕겨내기  Lv 0/${ClassPassive.maxLevel}'), findsOneWidget);
    await tester.tap(find.byKey(const Key('raise-parry')));
    await tester.pump();

    expect(profile.mastery.passiveLevel(ClassPassive.parry), 1);
    expect(find.text('남은 포인트 1'), findsOneWidget);
    expect(find.text('튕겨내기  Lv 1/${ClassPassive.maxLevel}'), findsOneWidget);
  });
}
