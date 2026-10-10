// 도트 · 이펙트 확인용 미리보기: 게임 장면을 PNG 로 찍어 build/preview/ 에 둔다.
// 일반 `flutter test` 에는 포함되지 않는다 (tool/ 아래).
//
// flutter test tool/preview/scene_test.dart
// flutter test tool/preview/scene_test.dart --plain-name 무기   # 하나만
//
// 찍는 것: 무기 픽셀 그림 (art_*.png), 대검 기술 프레임 (sword_*.png),
// 상태이상 진열 (ailments.png), 사냥꾼 전투 (hunter_fight.png), 숙련 화면 (mastery.png),
// 플레이어 움직임 프레임 (motion/f_*.png → tool/preview/motion.py 로 묶는다).
// Windows 빌드가 막혀 있어 게임을 띄우지 않고 그림을 확인하는 방법이다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ashborn/components/effects/burst.dart';
import 'package:ashborn/components/effects/ground_fx.dart';
import 'package:ashborn/components/enemies/hazards.dart';
import 'package:ashborn/components/weapons/ember_orb.dart';
import 'package:ashborn/components/enemies/minions.dart';
import 'package:ashborn/components/weapons/witch_weapons.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/components/weapons/greatsword.dart';
import 'package:ashborn/components/weapons/weapon_art.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/class_passives.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/enemies.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/passives.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:ashborn/ui/equipment/equipment_screen.dart';
import 'package:ashborn/ui/grace/grace_screen.dart';
import 'package:ashborn/ui/overlays/level_up_overlay.dart';
import 'package:ashborn/ui/overlays/stage_clear_overlay.dart';
import 'package:ashborn/ui/screens/character_select_screen.dart';
import 'package:ashborn/ui/screens/game_screen.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/progress.dart';
import 'package:ashborn/data/run_save.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/game/world/obstacles.dart';
import 'package:ashborn/game/world/region_theme.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/crate_system.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:ashborn/ui/mastery/mastery_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 한글이 네모로 나오지 않도록 픽셀 글꼴을 기본 글꼴 자리에 올린다.
Future<void> _fonts() async {
  final data = File('assets/fonts/Galmuri11-Bold.ttf').readAsBytesSync();
  for (final family in ['Roboto', 'Galmuri11']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(data.buffer)));
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/preview/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// 게임을 띄우고 이미지를 읽은 뒤, 웨이브 · 상자 · 적을 치운 빈 전장을 돌려준다.
/// [ratio] 는 기기 픽셀 배율 (실제 폰은 3 안팎). 도트가 뭉개지는지 볼 때는 3 으로 찍는다.
Future<(AshbornGame, GlobalKey)> _arena(
  WidgetTester tester,
  CharacterDef character, {
  double ratio = 1,
  Stage stage = Stage.first,
}) async {
  tester.view
    ..physicalSize = Size(390 * ratio, 600 * ratio)
    ..devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await _fonts();
  final game = AshbornGame(
    character: character,
    profile: Profile(),
    startStage: stage,
  );
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: GameWidget(game: game),
    ),
  );
  await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
  await tester.pump(const Duration(milliseconds: 16));
  final world = game.world;
  world.children.whereType<WaveSystem>().toList().forEach(world.remove);
  world.children.whereType<CrateSystem>().toList().forEach(world.remove);
  for (final e in world.enemies.toList()) {
    e.removeFromParent();
  }
  await tester.pump(const Duration(milliseconds: 16));
  return (game, key);
}

dynamic _dummy(EnemyKind kind, Vector2 at, {double speed = 0}) => spawnMinion(
  kind,
  position: at,
  maxHp: 1e12,
  contactDamage: 0,
  damageType: DamageType.physical,
  speed: speed,
  color: const Color(0xFF8A7F7A),
);

/// 픽셀 그림 하나를 [scale] 배로, 픽셀 격자가 보이게 그린다.
class _ArtBoard extends CustomPainter {
  _ArtBoard(this.art, this.scale);

  final PixelArt art;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF2E2A28),
    );
    art.draw(canvas, pivot: Offset.zero, scale: scale);
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var x = 0; x <= art.width; x++) {
      canvas.drawLine(
        Offset(x * scale, 0),
        Offset(x * scale, art.height * scale),
        grid,
      );
    }
    for (var y = 0; y <= art.height; y++) {
      canvas.drawLine(
        Offset(0, y * scale),
        Offset(art.width * scale, y * scale),
        grid,
      );
    }
  }

  @override
  bool shouldRepaint(_ArtBoard old) => false;
}

void main() {
  testWidgets('무기 픽셀 그림', (tester) async {
    const scale = 12.0;
    for (final (name, art) in [
      ('greatsword', greatswordArt),
      ('bolt', boltArt),
      ('knife', knifeArt),
      ('chakram', chakramArt),
    ]) {
      final size = Size(art.width * scale, art.height * scale);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CustomPaint(painter: _ArtBoard(art, scale), size: size),
        ),
      );
      await _shot(tester, key, 'art_$name');
    }
    tester.view.reset();
  });

  testWidgets('대검 기술 · 상태이상', (tester) async {
    final (game, key) = await _arena(tester, Roster.knight);
    final world = game.world;
    final player = world.player;
    final at = player.position;

    // 위쪽 줄: 중독 · 출혈 · 점화 · 냉각 · 동결 · 감전.
    final shows = <void Function(dynamic)>[
      (e) => e.ailments.poison(100000.0),
      (e) => e.ailments.bleed(100000.0),
      (e) => e.ailments.ignite(1.0),
      (e) => e.ailments.chill(0.25, 100.0),
      (e) {
        e.ailments.chill(0.25, 100.0);
        e.ailments.addCold(1e9, 1.0, cold: 1.0, freezeTime: 100.0);
      },
      (e) => e.ailments.addLightning(1e9, 1.0, stun: 100.0),
    ];
    final row = [
      for (var i = 0; i < shows.length; i++)
        _dummy(EnemyKind.ashWalker, at + Vector2(-150 + i * 60, -170)),
    ];
    for (final e in row) {
      world.add(e);
    }
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < row.length; i++) {
      shows[i](row[i]);
    }
    await tester.pump(const Duration(milliseconds: 300));
    await _shot(tester, key, 'ailments');

    // 대검: 레벨을 올려 두고 기술마다 세 순간을 찍는다 (자동 공격은 막아 둔다).
    final sword = player.weapon(WeaponId.greatsword)! as Greatsword;
    for (var i = 1; i < WeaponId.maxLevel; i++) {
      player.gainWeapon(WeaponId.greatsword);
    }
    final size = sword.size;
    sword.removeFromParent();
    await tester.pump(const Duration(milliseconds: 16));
    var n = 0;
    for (final move in SwordMove.values) {
      final strike = SwordStrike(
        move: move,
        angle: 0.5,
        sizeScale: size,
        fury: move == SwordMove.slam,
        onImpact: (_) {
          if (move != SwordMove.slam) return;
          final center =
              at +
              Vector2(math.cos(0.5), math.sin(0.5)) * Balance.slamOffset * size;
          world
            ..add(
              GroundCrack(position: center, radius: Balance.slamRadius * size),
            )
            ..add(
              EarthBurst(
                position: center.clone(),
                radius: Balance.slamRadius * size,
                ember: true,
              ),
            );
        },
      );
      player.attackPose(
        windup: strike.duration * strike.impactAt,
        strike: strike.duration * (1 - strike.impactAt),
        aimX: math.cos(0.5),
      );
      if (move == SwordMove.slam) {
        player.leap(strike.duration * strike.impactAt, Balance.slamLeap);
      }
      world.add(strike);
      await tester.pump(const Duration(milliseconds: 16));
      var elapsed = 16;
      for (final f in switch (move) {
        SwordMove.thrust => [60, 120, 180],
        SwordMove.swing => [60, 120, 200],
        SwordMove.slam => [120, 300, 430, 480, 560, 660, 800],
      }) {
        await tester.pump(Duration(milliseconds: f - elapsed));
        elapsed = f;
        await _shot(tester, key, 'sword_${n++}_${move.name}_$f');
      }
      await tester.pump(const Duration(milliseconds: 600));
    }
    game.pauseEngine();
  });

  testWidgets('흙 분출', (tester) async {
    // 내려찍기 분출(보통 · 잿불)과 대지 강타의 흙벽을 크게 놓고 시간 순서로 찍는다.
    final (game, key) = await _arena(tester, Roster.knight, ratio: 2);
    final world = game.world;
    final at = world.player.position.clone();
    world
      ..add(
        EarthBurst(
          position: at + Vector2(-90, -70),
          radius: Balance.slamRadius,
        ),
      )
      ..add(
        EarthBurst(
          position: at + Vector2(90, -70),
          radius: Balance.slamRadius,
          ember: true,
        ),
      )
      ..add(
        EarthBurst(
          position: at + Vector2(0, 170),
          radius: Balance.earthSlamRadius * 0.85,
          count: 12,
          ringAt: 0.8,
        ),
      );
    var elapsed = 0;
    for (final f in [40, 90, 160, 260, 380, 520]) {
      await tester.pump(Duration(milliseconds: f - elapsed));
      elapsed = f;
      await _shot(tester, key, 'earth_burst_$f');
    }
    game.pauseEngine();
  });

  testWidgets('보스 지진파', (tester) async {
    // 보스 내려찍기의 지진파를 퍼지는 순서대로 찍는다 (earthquake_*.png).
    final (game, key) = await _arena(tester, Roster.knight, ratio: 2);
    final world = game.world;
    world.add(
      Shockwave(
        position: world.player.position + Vector2(0, -40),
        maxRadius: Balance.bossSlamRadius,
        damage: 0,
        type: DamageType.physical,
        color: hazardColor(DamageType.physical),
      ),
    );
    var elapsed = 0;
    for (final f in [250, 600, 1000, 1400]) {
      await tester.pump(Duration(milliseconds: f - elapsed));
      elapsed = f;
      await _shot(tester, key, 'earthquake_$f');
    }
    game.pauseEngine();
  });

  testWidgets('원소 폭주', (tester) async {
    // 마녀 원소 폭주의 4원소 레이저를 시간 순서로 찍는다 (surge_*.png).
    final (game, key) = await _arena(tester, Roster.witch, ratio: 2);
    final world = game.world;
    final at = world.player.position.clone();
    world.add(_dummy(EnemyKind.ashWalker, at + Vector2(150, -60)));
    world.add(
      ElementalBeam(
        position: at.clone(),
        angle: math.atan2(-60, 150),
        damage: 0,
        beamWidth: Balance.surgeWidth,
      ),
    );
    var elapsed = 0;
    for (final f in [30, 150, 300]) {
      await tester.pump(Duration(milliseconds: f - elapsed));
      elapsed = f;
      await _shot(tester, key, 'surge_$f');
    }
    game.pauseEngine();
  });

  testWidgets('정예', (tester) async {
    final (game, key) = await _arena(tester, Roster.knight, ratio: 2);
    final world = game.world;
    final at = world.player.position.clone();
    for (final (i, elite) in [(0, false), (1, true), (2, true)]) {
      final e = _dummy(
        [EnemyKind.ashWalker, EnemyKind.ashWalker, EnemyKind.ashRaider][i],
        at + Vector2(-90.0 + i * 90, -110),
      );
      if (elite) e.makeElite();
      world.add(e);
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _shot(tester, key, 'elite');
    game.pauseEngine();
  });

  testWidgets('사냥꾼 전투', (tester) async {
    final (game, key) = await _arena(tester, Roster.hunter);
    final world = game.world;
    final player = world.player;
    for (var i = 1; i < WeaponId.maxLevel; i++) {
      player.gainWeapon(WeaponId.fireCrossbow);
    }
    player
      ..gainWeapon(WeaponId.throwingKnives)
      ..gainWeapon(WeaponId.chakram);
    for (var i = 0; i < 14; i++) {
      world.add(
        _dummy(
          EnemyKind.values[i % 6],
          player.position +
              (Vector2(170 * (1 + i % 3 * 0.3), 0)..rotate(i * 0.45)),
          speed: 60,
        ),
      );
    }
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _shot(tester, key, 'hunter_fight');
    game.pauseEngine();
  });

  testWidgets('플레이어 움직임', (tester) async {
    // 서 있기 → 오른쪽 달리기 → 왼쪽으로 돌기 → 멈추기 → 맞기 를 30fps 로 찍는다.
    // build/preview/motion/ 의 프레임은 tool/preview/motion.py 로 GIF · 띠 그림으로 묶는다.
    final dir = Directory('build/preview/motion');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final (game, key) = await _arena(tester, Roster.knight, ratio: 3);
    final player = game.world.player;
    final stick = game.joystick.delta;
    var n = 0;
    Future<void> run(double seconds, Vector2 input) async {
      stick.setFrom(input);
      for (var i = 0; i < (seconds * 30).round(); i++) {
        await tester.pump(const Duration(microseconds: 33333));
        await _shot(
          tester,
          key,
          'motion/f_${(n++).toString().padLeft(3, '0')}',
        );
      }
    }

    await run(1.8, Vector2.zero());
    await run(1.0, Vector2(1000, 0));
    await run(0.6, Vector2(-1000, 0));
    await run(0.8, Vector2.zero());
    player.takeDamage(1);
    await run(0.7, Vector2.zero());
    game.pauseEngine();
  });

  testWidgets('내 공격 이펙트', (tester) async {
    // 회오리 셋(나이 다르게) · 폭발 · 충격 고리 · 벼락을 한 화면에 놓고 몇 순간 찍는다.
    final (game, key) = await _arena(tester, Roster.witch, ratio: 2);
    final world = game.world;
    final player = world.player;
    player.gainWeapon(WeaponId.fireTornado);
    final weapon = player.weapon(WeaponId.fireTornado)! as FireTornado;
    weapon.removeFromParent();
    final at = player.position;
    Tornado tornado(Vector2 p) => Tornado(
      weapon: weapon,
      position: p,
      direction: Vector2(1, 0),
      radius: Balance.tornadoRadius,
      speed: 0,
      lifetime: 30,
    );
    world.add(tornado(at + Vector2(-150, -40)));
    await tester.pump(const Duration(milliseconds: 120));
    world
      ..add(tornado(at + Vector2(-60, -40)))
      ..add(tornado(at + Vector2(30, -40)));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 3; i++) {
      world
        ..add(
          Burst(
            position: at + Vector2(-130, 130),
            radius: 55,
            color: const Color(0xFFFF7A2E),
          ),
        )
        ..add(
          Burst(
            position: at + Vector2(-10, 130),
            radius: 40,
            color: const Color(0xFF8FE3FF),
          ),
        )
        ..add(
          Ring(
            position: at + Vector2(120, 130),
            radius: 90,
            color: const Color(0xFFE0A060),
            strokeWidth: 10,
          ),
        )
        ..add(
          LightningBolt(
            position: at + Vector2(140, -20),
            color: const Color(0xFFFFF27A),
          ),
        );
      await tester.pump(Duration(milliseconds: 40 + i * 70));
      await _shot(tester, key, 'fx_$i');
      await tester.pump(const Duration(milliseconds: 600));
    }
    game.pauseEngine();
  });

  for (final (who, weapons) in [
    (
      Roster.knight,
      [
        WeaponId.greatsword,
        WeaponId.earthSlam,
        WeaponId.cleave,
        WeaponId.warCry,
      ],
    ),
    (
      Roster.witch,
      [
        WeaponId.emberOrb,
        WeaponId.meteor,
        WeaponId.fireTornado,
        WeaponId.emberSpirits,
      ],
    ),
    (
      Roster.hunter,
      [WeaponId.fireCrossbow, WeaponId.emberMine, WeaponId.snareNet],
    ),
  ]) {
    testWidgets('전투 이펙트 ${who.id.name}', (tester) async {
      final (game, key) = await _arena(tester, who, ratio: 2);
      final world = game.world;
      final player = world.player;
      for (final id in weapons) {
        for (
          var i = player.weapon(id) == null ? 0 : 1;
          i < WeaponId.maxLevel;
          i++
        ) {
          player.gainWeapon(id);
        }
      }
      for (var i = 0; i < 16; i++) {
        world.add(
          _dummy(
            EnemyKind.values[i % 6],
            player.position +
                (Vector2(110 * (1 + i % 3 * 0.5), 0)..rotate(i * 0.4)),
            speed: 40,
          ),
        );
      }
      for (var shot = 0; shot < 4; shot++) {
        for (var i = 0; i < 9; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await _shot(tester, key, 'battle_${who.id.name}_$shot');
      }
      game.pauseEngine();
    });
  }

  testWidgets('기둥 앞뒤', (tester) async {
    // 기둥이 있는 지역에서 기둥 뒤 · 앞에 서 보고, 기둥 쪽으로 걸어 막히는지 찍는다.
    final stage = [for (var i = 0; i < 12; i++) Stage(i)].firstWhere(
      (s) => RegionTheme.of(s.region).structures.containsKey(Structure.pillar),
    );
    final (game, key) = await _arena(
      tester,
      Roster.knight,
      ratio: 2,
      stage: stage,
    );
    final world = game.world;
    final player = world.player;
    (int, int)? found;
    for (var r = 0; r < 60 && found == null; r++) {
      for (var gx = -r; gx <= r && found == null; gx++) {
        for (var gy = -r; gy <= r; gy++) {
          if (world.obstacles.structureAt(gx, gy) == Structure.pillar) {
            found = (gx, gy);
            break;
          }
        }
      }
    }
    final foot = Obstacles.footOf(found!.$1, found.$2);
    // 뒤 (위쪽): 발이 밑동보다 위.
    player.position.setValues(foot.x + 6, foot.y - 30);
    await tester.pump(const Duration(milliseconds: 100));
    await _shot(tester, key, 'pillar_behind');
    // 앞 (아래쪽).
    player.position.setValues(foot.x - 4, foot.y + 6);
    await tester.pump(const Duration(milliseconds: 100));
    await _shot(tester, key, 'pillar_front');
    // 위에서 아래로 걸어 내려가 본다: 밑동에 막혀 비켜 가야 한다.
    player.position.setValues(foot.x, foot.y - 60);
    game.joystick.delta.setValues(0, 1000);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    game.joystick.delta.setZero();
    await tester.pump(const Duration(milliseconds: 16));
    await _shot(tester, key, 'pillar_blocked');
    game.pauseEngine();
  });

  for (final (who, id) in [
    (Roster.knight, WeaponId.warCry),
    (Roster.hunter, WeaponId.snareNet),
  ]) {
    testWidgets('새 스킬 ${id.name}', (tester) async {
      final (game, key) = await _arena(tester, who, ratio: 2);
      final world = game.world;
      final player = world.player;
      for (final w in player.weapons.toList()) {
        (w as Component).removeFromParent();
      }
      for (var i = 0; i < WeaponId.maxLevel; i++) {
        player.gainWeapon(id);
      }
      for (var i = 0; i < 10; i++) {
        world.add(
          _dummy(
            EnemyKind.values[i % 6],
            player.position + (Vector2(70 + (i % 3) * 25, 0)..rotate(i * 0.63)),
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 16));
      final weapon = player.weapon(id)!;
      (weapon as Component).removeFromParent();
      await tester.pump(const Duration(milliseconds: 16));
      world.add(weapon as Component);
      await tester.pump(const Duration(milliseconds: 16));
      (weapon as dynamic).fire();
      var t = 0;
      for (final ms in [80, 200, 420, 900]) {
        await tester.pump(Duration(milliseconds: ms - t));
        t = ms;
        await _shot(tester, key, 'skill_${id.name}_$ms');
      }
      game.pauseEngine();
    });
  }

  group('화면', () {
    Future<GlobalKey> screen(
      WidgetTester tester,
      Widget child, {
      Size size = const Size(390, 844),
      Progress? progress,
      SavedRuns? runs,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _fonts();
      final key = GlobalKey();
      final mastery = Mastery()..addXp(CharacterId.knight, 30000);
      final inventory = Inventory()..addLoot(gold: 99999);
      final random = math.Random(4);
      for (final c in CharacterId.values) {
        for (final t in [ItemType.oneHand, ItemType.twoHand]) {
          inventory
              .gear(CharacterId.knight)
              .add(
                LootSystem.generate(
                  random,
                  type: t,
                  owner: c,
                  rarity: Rarity.values[c.index + 2],
                ),
              );
        }
      }
      inventory
          .gear(CharacterId.knight)
          .add(
            LootSystem.generate(
              random,
              type: ItemType.armor,
              rarity: Rarity.legend,
            ),
          );
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProfileScope(
            profile: Profile(
              mastery: mastery,
              inventory: inventory,
              progress: progress,
              runs: runs,
            ),
            child: MaterialApp(theme: ThemeData.dark(), home: child),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      return key;
    }

    testWidgets('캐릭터 선택', (tester) async {
      final key = await screen(tester, const CharacterSelectScreen());
      await _shot(tester, key, 'ui_select');
    });

    testWidgets('특성', (tester) async {
      final key = await screen(
        tester,
        const MasteryScreen(character: Roster.knight),
      );
      await _shot(tester, key, 'ui_traits');
    });

    testWidgets('장비', (tester) async {
      final key = await screen(
        tester,
        const EquipmentScreen(character: Roster.knight),
      );
      await _shot(tester, key, 'ui_equipment');
      await tester.tap(find.byKey(const Key('bag-2')));
      await tester.pump();
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _shot(tester, key, 'ui_equipment_locked');
      // 가방 장비 하나를 골라 전투력 변화를 보고, 돌아와 자동 장착한다.
      await tester.tap(find.byKey(const Key('close-equipment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bag-0')));
      await tester.pump(const Duration(milliseconds: 50));
      await _shot(tester, key, 'ui_equipment_compare');
      await tester.tap(find.byKey(const Key('close-equipment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('auto-equip')));
      await tester.pump(const Duration(milliseconds: 50));
      await _shot(tester, key, 'ui_equipment_auto');
      await tester.tap(find.byKey(const Key('bulk-salvage')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('auto-salvage')));
      await tester.pump(const Duration(milliseconds: 50));
      await _shot(tester, key, 'ui_bulk_salvage');
    });

    for (final n in [3, 4]) {
      testWidgets('레벨업 카드 $n장', (tester) async {
        final game = AshbornGame(character: Roster.witch, profile: Profile());
        game.levelUpOptions.value = [
          const WeaponOption(WeaponId.emberSpirits, 1),
          const WeaponOption(WeaponId.fireTornado, 4),
          const AwakenOption(WeaponId.meteor),
          const PassiveOption(PassiveId.haste, 2),
        ].take(n).toList();
        final key = await screen(
          tester,
          Scaffold(
            backgroundColor: const Color(0xFF2E2A28),
            body: LevelUpOverlay(game: game),
          ),
        );
        await _shot(tester, key, 'ui_levelup_$n');
      });
    }

    testWidgets('은총 카드 4장', (tester) async {
      final game = AshbornGame(character: Roster.knight, profile: Profile());
      game.fateOptions.value = [
        for (final (i, card) in FateCard.values.take(12).indexed)
          if (i % 3 == 0)
            Fate(card, Rarity.values[math.max(card.minRarity.index, i % 6)]),
      ].take(4).toList();
      final key = await screen(
        tester,
        Scaffold(
          backgroundColor: const Color(0xFF2E2A28),
          body: StageClearOverlay(game: game, onReturn: () {}),
        ),
      );
      await _shot(tester, key, 'ui_fate_4');
      // 짧은 화면에서도 스크롤 없이 한 화면에 모두 보여야 한다.
      tester.view.physicalSize = const Size(390, 560);
      await tester.pump();
      await _shot(tester, key, 'ui_fate_4_short');
    });

    testWidgets('은총 받은 뒤 클리어 화면', (tester) async {
      final game = AshbornGame(character: Roster.knight, profile: Profile());
      final pick = Fate(FateCard.sharpEmber, Rarity.hero);
      game.fateOptions.value = [pick, Fate(FateCard.newArms, Rarity.rare)];
      game.chosenFate.value = pick;
      final key = await screen(
        tester,
        Scaffold(
          backgroundColor: const Color(0xFF2E2A28),
          body: StageClearOverlay(game: game, onReturn: () {}),
        ),
      );
      await _shot(tester, key, 'ui_fate_chosen');
    });

    testWidgets('은총 메뉴', (tester) async {
      final progress = Progress(4, null, {
        0: Fate(FateCard.sharpEmber, Rarity.rare),
        1: Fate(FateCard.hardenedAsh, Rarity.normal),
        2: Fate(FateCard.berserk, Rarity.legend),
        3: Fate(FateCard.smithsTouch, Rarity.hero),
      });
      final key = await screen(tester, const GraceScreen(), progress: progress);
      await _shot(tester, key, 'ui_grace');
    });

    testWidgets('카드 · 은총 (일시정지 · 자세히 · 레벨업)', (tester) async {
      final progress = Progress(4, null, {
        0: Fate(FateCard.sharpEmber, Rarity.rare),
        1: Fate(FateCard.hardenedAsh, Rarity.normal),
        2: Fate(FateCard.berserk, Rarity.legend),
      });
      final key = await screen(
        tester,
        const GameScreen(character: Roster.witch),
        progress: progress,
      );
      final game = tester
          .widget<GameWidget<AshbornGame>>(find.byType(GameWidget<AshbornGame>))
          .game!;
      final player = game.world.player;
      for (final id in [
        WeaponId.emberSpirits,
        WeaponId.emberSpirits,
        WeaponId.fireTornado,
      ]) {
        player.gainWeapon(id);
      }
      while (!player.weapons.first.isMaxLevel) {
        player.gainWeapon(player.weapons.first.id);
      }
      for (final id in [
        PassiveId.fury,
        PassiveId.fury,
        PassiveId.haste,
        PassiveId.vitality,
        PassiveId.vitality,
        PassiveId.vitality,
        PassiveId.vitality,
        PassiveId.vitality,
        player.weapons.first.id.catalyst,
      ]) {
        player.gainPassive(id);
      }
      Future<void> settle() async {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      game.openPauseMenu();
      await settle();
      await _shot(tester, key, 'ui_pause_build');
      game.openBuild();
      await settle();
      await _shot(tester, key, 'ui_build');
      game.resumeFromPause();
      game.world.gainXp(LevelSystem.xpToNext(game.stats.level.value));
      await settle();
      await _shot(tester, key, 'ui_levelup_build');
    });

    testWidgets('정복 화면', (tester) async {
      final game = AshbornGame(
        character: Roster.knight,
        profile: Profile(),
        startStage: Stage.start(1).next.next.next.next,
      );
      game.world.unlockedCorruption = true;
      final key = await screen(
        tester,
        Scaffold(
          backgroundColor: const Color(0xFF2E2A28),
          body: StageClearOverlay(game: game, onReturn: () {}),
        ),
      );
      await _shot(tester, key, 'ui_conquest');
    });

    testWidgets('캐릭터 선택 (타락 단계)', (tester) async {
      final key = await screen(
        tester,
        const CharacterSelectScreen(),
        progress: Progress(Region.values.length * 4 + 2),
      );
      await _shot(tester, key, 'ui_select_corruption');
    });

    testWidgets('캐릭터 선택 (이어 하기)', (tester) async {
      final profileRuns = SavedRuns({
        CharacterId.knight: const RunSave(
          stage: Stage(3),
          level: 14,
          xp: 0,
          weapons: [(id: WeaponId.greatsword, level: 5, awakened: false)],
          passives: {PassiveId.fury: 2, PassiveId.haste: 1},
        ),
      });
      final key = await screen(
        tester,
        const CharacterSelectScreen(),
        progress: Progress(4),
        runs: profileRuns,
      );
      await _shot(tester, key, 'ui_select_resume');
    });

    testWidgets('캐릭터 선택 (받을 은총)', (tester) async {
      final key = await screen(
        tester,
        const CharacterSelectScreen(),
        progress: Progress(2),
      );
      await _shot(tester, key, 'ui_select_grace');
    });
  });

  testWidgets('숙련 화면', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _fonts();
    final mastery = Mastery()..addXp(CharacterId.knight, 9000);
    mastery
      ..raise(ClassPassive.parry)
      ..raise(ClassPassive.parry)
      ..raise(ClassPassive.swordMastery);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProfileScope(
          profile: Profile(mastery: mastery),
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const MasteryScreen(character: Roster.knight),
          ),
        ),
      ),
    );
    await tester.pump();
    await _shot(tester, key, 'mastery');
  });
}
