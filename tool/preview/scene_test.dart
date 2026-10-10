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
import 'dart:ui' as ui;

import 'package:ashborn/components/enemies/minions.dart';
import 'package:ashborn/components/weapons/greatsword.dart';
import 'package:ashborn/components/weapons/weapon_art.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/class_passives.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/data/enemies.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/crate_system.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:ashborn/ui/mastery/mastery_screen.dart';
import 'package:ashborn/ui/profile_scope.dart';
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
}) async {
  tester.view
    ..physicalSize = Size(390 * ratio, 600 * ratio)
    ..devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await _fonts();
  final game = AshbornGame(character: character, profile: Profile());
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
      world.add(
        SwordStrike(
          move: move,
          angle: 0.5,
          sizeScale: size,
          fury: move == SwordMove.slam,
          onImpact: (_) {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      var elapsed = 16;
      for (final f in switch (move) {
        SwordMove.thrust => [60, 120, 180],
        SwordMove.swing => [60, 120, 200],
        SwordMove.slam => [80, 180, 240],
      }) {
        await tester.pump(Duration(milliseconds: f - elapsed));
        elapsed = f;
        await _shot(tester, key, 'sword_${n++}_${move.name}_$f');
      }
      await tester.pump(const Duration(milliseconds: 600));
    }
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
