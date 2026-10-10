import 'dart:ui';

import 'package:ashborn/components/enemies/enemy.dart';
import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/monster_sprites.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 게임이 적 스프라이트를 다 읽을 때까지 진행시킨다.
Future<void> loadSprites(AshbornGame game) async {
  for (var i = 0; i < 100; i++) {
    if (MonsterSprite.values.every((s) => game.monsterSprites[s] != null)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await advance(game, 1 / 60);
  }
  throw StateError('적 스프라이트를 읽지 못했다');
}

/// [enemy] 를 그림으로 그려 본다. 예외 없이 그려지면 된다.
void draw(Enemy enemy) {
  final recorder = PictureRecorder();
  enemy.render(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  test('지역마다 졸개 일곱에서 여덟 종류와 보스 스프라이트가 모두 다르다', () {
    for (final r in Region.values) {
      expect(r.roster.length, inInclusiveRange(7, 8), reason: r.label);
      expect(
        r.roster.length,
        lessThanOrEqualTo(Balance.rosterUnlock.length),
        reason: '풀리는 시각이 정해져 있어야 한다',
      );
    }
    final all = [
      for (final r in Region.values) ...[
        for (final k in r.roster) k.sprite,
        r.bossSprite,
      ],
    ];
    expect(all.toSet().length, all.length);
    expect(all.toSet(), MonsterSprite.values.toSet());
  });

  testWithGame<AshbornGame>(
    '졸개와 보스는 지역 스프라이트로 나오고, 프레임이 시트 크기와 맞다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      await loadSprites(game);
      for (final s in MonsterSprite.values) {
        final frames = game.monsterSprites[s]!;
        expect(frames, hasLength(MonsterSprite.frameCount));
        expect(frames.first.srcSize, Vector2(s.width, s.height));
      }

      await advance(game, 3);
      final region = game.world.stage.region;
      final minion = game.world.enemies.first;
      expect(region.roster.map((k) => k.sprite), contains(minion.sprite));
      draw(minion);

      game.world.spawnBoss();
      await game.ready();
      expect(game.world.boss!.sprite, region.bossSprite);
      draw(game.world.boss!);
    },
  );

  testWithGame<AshbornGame>(
    '스프라이트를 읽기 전이나 없으면 원으로 그린다',
    gameWith(Roster.witch),
    (game) async {
      await game.ready();
      await clearEnemies(game);
      final plain = await addEnemy(game, Vector2(200, 0));
      expect(plain.sprite, isNull);
      draw(plain);
    },
  );
}
