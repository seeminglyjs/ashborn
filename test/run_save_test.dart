import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/passives.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/progress.dart';
import 'package:ashborn/data/run_save.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:ashborn/ui/screens/character_select_screen.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fate_test.dart' show stubOverlays;
import 'helpers.dart';

/// 마녀 런. [runs] 로 이어 할 런 기록을 나눠 보고, [resume] 이면 그 기록으로 이어 한다.
AshbornGame Function() runGame({
  SavedRuns? runs,
  RunSave? resume,
  Progress? progress,
  Stage stage = Stage.first,
}) => () {
  TestWidgetsFlutterBinding.ensureInitialized();
  final game = AshbornGame(
    character: Roster.witch,
    profile: Profile(runs: runs, progress: progress),
    startStage: stage,
    resume: resume,
  );
  stubOverlays(game);
  return game;
};

/// 보스를 잡고 클리어 화면이 뜰 때까지.
Future<void> clearStage(AshbornGame game) async {
  game.world.spawnBoss();
  await game.ready();
  game.world.boss!.takeDamage(double.infinity);
  await game.ready();
  await advance(game, Balance.stageClearDelay + 0.1);
}

const saved = RunSave(
  stage: Stage(3),
  level: 12,
  xp: 5,
  weapons: [
    (id: WeaponId.emberOrb, level: WeaponId.maxLevel, awakened: true),
    (id: WeaponId.fireTornado, level: 3, awakened: false),
  ],
  passives: {PassiveId.fury: 2, PassiveId.vitality: 1},
);

void main() {
  group('이어 할 런 기록', () {
    test('JSON 으로 오가고, 모르는 무기 · 패시브 · 캐릭터는 건너뛴다', () {
      final json = SavedRuns({CharacterId.witch: saved}).toJson();
      final run = SavedRuns.fromJson(json).of(CharacterId.witch)!;
      expect(run.stage, saved.stage);
      expect(run.level, 12);
      expect(run.xp, 5);
      expect(run.weapons, saved.weapons);
      expect(run.passives, saved.passives);

      final odd = saved.toJson()
        ..['weapons'] = [
          {'id': 'gone', 'level': 3},
          {'id': 'emberOrb', 'level': 2},
        ]
        ..['passives'] = {'gone': 1, 'fury': 1};
      final read = SavedRuns.fromJson({'witch': odd, 'nobody': odd});
      expect(read.of(CharacterId.witch)!.weapons, [
        (id: WeaponId.emberOrb, level: 2, awakened: false),
      ]);
      expect(read.of(CharacterId.witch)!.passives, {PassiveId.fury: 1});
    });

    test('기기에 저장되고 다음 실행에 불러온다 (예전 세이브에는 없다)', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await Profile.load()).runs.of(CharacterId.witch), isNull);
      (await Profile.load()).runs.save(CharacterId.witch, saved);
      await pumpEventQueue();

      final loaded = (await Profile.load()).runs.of(CharacterId.witch);
      expect(loaded?.stage, saved.stage);
      expect(loaded?.level, saved.level);
    });
  });

  group('남기기', () {
    testWithGame<AshbornGame>(
      '다음 지역으로 가면 그 지역 처음부터 지금 레벨 · 카드로 남긴다',
      runGame(),
      (game) async {
        await game.ready();
        game.world.gainXp(LevelSystem.xpToNext(1));
        game.chooseLevelUp(const PassiveOption(PassiveId.fury, 1));
        await clearStage(game);
        game.chooseFate(game.fateOptions.value.first);
        game.continueToNextStage();

        final run = game.profile.runs.of(CharacterId.witch)!;
        expect(run.stage, const Stage(1));
        expect(run.level, game.stats.level.value);
        expect(run.passives[PassiveId.fury], 1);
        expect(
          run.weapons.map((w) => w.id),
          game.world.player.weapons.map((w) => w.id),
        );
      },
    );

    testWithGame<AshbornGame>(
      '클리어 화면에서 화톳불로 돌아가면 다음 지역부터 이어 할 수 있다',
      runGame(),
      (game) async {
        await game.ready();
        await clearStage(game);
        game.chooseFate(game.fateOptions.value.first);
        game.returnToHearth();

        expect(game.profile.runs.of(CharacterId.witch)?.stage, const Stage(1));
      },
    );

    testWithGame<AshbornGame>(
      '단계의 마지막 지역을 클리어하면 런이 끝나 기록을 지운다',
      runGame(
        runs: SavedRuns({CharacterId.witch: saved}),
        resume: RunSave(
          stage: Stage(Region.values.length - 1),
          level: 5,
          xp: 0,
          weapons: saved.weapons,
          passives: saved.passives,
        ),
        progress: Progress(Region.values.length),
      ),
      (game) async {
        await game.ready();
        await clearStage(game);
        game.returnToHearth();
        expect(game.profile.runs.of(CharacterId.witch), isNull);
      },
    );
  });

  group('지우기', () {
    testWithGame<AshbornGame>(
      '쓰러지면 이어 할 런이 사라진다',
      runGame(runs: SavedRuns({CharacterId.witch: saved}), resume: saved),
      (game) async {
        await game.ready();
        game.world.player.takeDamage(1e9);
        await game.ready();
        expect(game.profile.runs.of(CharacterId.witch), isNull);
      },
    );

    testWithGame<AshbornGame>(
      '싸우는 도중에 나가면 포기로 지우고, 보스를 잡은 뒤 나가면 다음 지역부터 남긴다',
      runGame(runs: SavedRuns({CharacterId.witch: saved}), resume: saved),
      (game) async {
        await game.ready();
        expect(game.canKeepRun, isFalse);
        game.quitRun();
        expect(game.profile.runs.of(CharacterId.witch), isNull);

        game.world.spawnBoss();
        await game.ready();
        game.world.boss!.takeDamage(double.infinity);
        await game.ready();
        expect(game.canKeepRun, isTrue);
        game.quitRun();
        expect(
          game.profile.runs.of(CharacterId.witch)?.stage,
          saved.stage.next,
        );
      },
    );

    testWithGame<AshbornGame>(
      '새로 출정하면 그 캐릭터의 이어 할 런은 버린다 (다른 캐릭터 것은 그대로)',
      runGame(
        runs: SavedRuns({CharacterId.witch: saved, CharacterId.knight: saved}),
      ),
      (game) async {
        await game.ready();
        expect(game.profile.runs.of(CharacterId.witch), isNull);
        expect(game.profile.runs.of(CharacterId.knight), isNotNull);
      },
    );
  });

  group('이어 하기', () {
    testWithGame<AshbornGame>(
      '기록의 지역 처음부터 레벨 · 경험치 · 무기(각성 포함) · 패시브를 되살리고 체력은 가득',
      runGame(runs: SavedRuns({CharacterId.witch: saved}), resume: saved),
      (game) async {
        await game.ready();
        final player = game.world.player;

        expect(game.world.stage, saved.stage);
        expect(game.world.stageTime, 0);
        expect(game.stats.level.value, 12);
        expect(game.stats.xp.value, 5);
        expect(game.stats.xpToNext.value, LevelSystem.xpToNext(12));
        expect(player.weapons, hasLength(2));
        expect(player.weapon(WeaponId.emberOrb)!.level, WeaponId.maxLevel);
        expect(player.weapon(WeaponId.emberOrb)!.awakened, isTrue);
        expect(player.weapon(WeaponId.fireTornado)!.level, 3);
        expect(player.passives, saved.passives);
        expect(player.hp, player.maxHp);
        // 이어 하는 동안에도 기록은 남아 있다 (앱이 꺼져도 이 지역 처음부터).
        expect(game.profile.runs.of(CharacterId.witch), isNotNull);
      },
    );

    testWithGame<AshbornGame>(
      '카드를 고르지 않은 레벨이 남아 있으면 바로 고르게 한다',
      runGame(
        resume: RunSave(
          stage: saved.stage,
          level: 4,
          xp: 0,
          weapons: saved.weapons,
          passives: const {},
          levelUps: 2,
        ),
      ),
      (game) async {
        await game.ready();
        expect(game.overlays.isActive(AshbornGame.levelUpOverlay), isTrue);
        expect(game.levelUpOptions.value, isNotEmpty);
      },
    );
  });

  testWidgets('캐릭터 선택: 이어 할 런이 있으면 이어 하기, 새로 출정은 한 번 묻는다', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = Profile(
      progress: Progress(4),
      runs: SavedRuns({CharacterId.knight: saved}),
    );
    await tester.pumpWidget(
      ProfileScope(
        profile: profile,
        child: const MaterialApp(home: CharacterSelectScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('resume-run')), findsOneWidget);
    expect(find.textContaining('캐릭터 Lv 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('depart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('confirm-new-run')), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(profile.runs.of(CharacterId.knight), isNotNull);

    await tester.tap(find.byKey(const Key('resume-run')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.resume?.stage, saved.stage);
  });
}
