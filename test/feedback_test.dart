import 'package:ashborn/components/effects/damage_number.dart';
import 'package:ashborn/components/effects/hit_vignette.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('피해 숫자', () {
    testWithGame<AshbornGame>('때리면 들어간 피해가 떠올랐다 사라진다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      await clearEnemies(game);
      final enemy = await addEnemy(game, Vector2(5000, 5000), hp: 1000);

      final dealt = game.world.player.strike(enemy, 20, DamageType.physical);
      await game.ready();

      final number = game.world.children.whereType<DamageNumber>().single;
      expect(number.text, '${dealt.round()}');
      expect(number.position.y, lessThan(enemy.position.y));

      await advance(game, DamageNumber.duration + 0.1);
      expect(game.world.children.whereType<DamageNumber>(), isEmpty);
      expect(game.world.damageNumbers, 0);
    });

    testWithGame<AshbornGame>('치명타 숫자는 더 크다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      game.world
        ..showDamage(Vector2.zero(), 10, crit: false)
        ..showDamage(Vector2.zero(), 10, crit: true);
      await game.ready();

      final [normal, crit] = game.world.children
          .whereType<DamageNumber>()
          .map((n) => (n.textRenderer as TextPaint).style.fontSize!)
          .toList();
      expect(crit, greaterThan(normal));
    });

    testWithGame<AshbornGame>('한꺼번에 떠 있는 수에는 상한이 있다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      for (var i = 0; i < DamageNumber.maxAlive + 10; i++) {
        game.world.showDamage(Vector2.zero(), 10, crit: false);
        await game.ready();
      }

      expect(
        game.world.children.whereType<DamageNumber>(),
        hasLength(DamageNumber.maxAlive),
      );
    });
  });

  testWithGame<AshbornGame>('맞으면 화면 가장자리가 잠깐 붉어진다', gameWith(Roster.witch), (
    game,
  ) async {
    await game.ready();
    await clearEnemies(game);
    expect(game.hitVignette.isShowing, isFalse);

    game.world.player.takeDamage(10);
    expect(game.hitVignette.isShowing, isTrue);

    await advance(game, HitVignette.duration + 0.05);
    expect(game.hitVignette.isShowing, isFalse);
  });

  group('조이스틱', () {
    testWithGame<AshbornGame>(
      '누른 곳에 나타나고 손잡이는 반지름 안에서만 움직인다',
      gameWith(Roster.witch),
      (game) async {
        await game.ready();
        final joystick = game.joystick;
        final rest = joystick.origin.clone();

        joystick.hold(Vector2(500, 200));
        expect(joystick.origin, Vector2(500, 200));

        joystick.moveTo(Vector2(530, 200));
        expect(joystick.relativeDelta, Vector2(0.5, 0));

        joystick.moveTo(Vector2(500, 500));
        expect(joystick.delta.length, closeTo(joystick.knobRadius, 1e-9));
        expect(joystick.relativeDelta.y, closeTo(1, 1e-9));

        joystick.release();
        expect(joystick.delta, Vector2.zero());
        expect(joystick.origin, rest);
      },
    );

    testWithGame<AshbornGame>('손을 떼면 왼쪽 아래 기본 자리에 있다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final origin = game.joystick.origin;

      expect(origin.x, lessThan(game.size.x / 2));
      expect(origin.y, greaterThan(game.size.y / 2));
    });
  });
}
