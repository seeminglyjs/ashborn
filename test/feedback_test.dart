import 'package:ashborn/components/effects/damage_number.dart';
import 'package:ashborn/components/effects/hit_vignette.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/damage.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/game/floating_joystick.dart';
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
    test('바탕은 작고, 손잡이는 바탕 반지름 안에서만 움직인다', () {
      final joystick = FloatingJoystick();
      expect(joystick.knobRadius, inInclusiveRange(40, 44));

      joystick.hold(Vector2(500, 200));
      expect(joystick.origin, Vector2(500, 200));

      joystick.moveTo(Vector2(500, 200 + joystick.knobRadius * 0.9));
      expect(joystick.origin, Vector2(500, 200));
      expect(joystick.delta.length, closeTo(joystick.knobRadius * 0.9, 1e-4));
      expect(joystick.relativeDelta.y, closeTo(1, 1e-4));

      joystick.release();
      expect(joystick.delta, Vector2.zero());
    });

    test('데드존 안의 작은 떨림은 무시한다', () {
      final joystick = FloatingJoystick()..hold(Vector2(500, 200));

      joystick.moveTo(Vector2(500 + FloatingJoystick.deadZone - 0.5, 200));
      expect(joystick.relativeDelta, Vector2.zero());

      joystick.moveTo(Vector2(500 + FloatingJoystick.deadZone + 2, 200));
      expect(joystick.relativeDelta.x, greaterThan(0));
    });

    test('바탕 반지름보다 짧게 밀어도 최대 속도가 나고, 길이는 0~1 이다', () {
      final joystick = FloatingJoystick()..hold(Vector2(500, 200));
      final full = joystick.knobRadius * FloatingJoystick.fullSpeedRatio;
      expect(full, lessThan(joystick.knobRadius * 0.75));

      // 데드존과 최대 속도 사이는 고르게 오른다.
      final halfway = (FloatingJoystick.deadZone + full) / 2;
      joystick.moveTo(Vector2(500 + halfway, 200));
      expect(joystick.relativeDelta.x, closeTo(0.5, 1e-4));
      expect(joystick.relativeDelta.y, 0);

      joystick.moveTo(Vector2(500 + full, 200));
      expect(joystick.relativeDelta.length, closeTo(1, 1e-4));

      // 대각선으로 바탕 끝까지 밀어도 1을 넘지 않는다.
      joystick.moveTo(Vector2(530, 230));
      expect(joystick.relativeDelta.length, closeTo(1, 1e-4));
      expect(joystick.relativeDelta.x, closeTo(joystick.relativeDelta.y, 1e-4));
    });

    test('손가락이 바탕 밖으로 나가면 바탕이 따라와 반대로 끌면 바로 방향이 바뀐다', () {
      final joystick = FloatingJoystick()..hold(Vector2(500, 200));
      final r = joystick.knobRadius;

      // 오른쪽으로 바탕 반지름보다 100 더 끌었다.
      joystick.moveTo(Vector2(500 + r + 100, 200));
      expect(joystick.origin.x, closeTo(600, 1e-4));
      expect(joystick.delta.length, closeTo(r, 1e-4));
      expect(joystick.relativeDelta.x, closeTo(1, 1e-4));

      // 따라온 바탕 덕에 조금만 되돌려도 왼쪽으로 꺾인다.
      // 바탕이 따라오지 않았다면 여전히 오른쪽(+x)이었을 자리다.
      joystick.moveTo(Vector2(600 - 10, 200));
      expect(joystick.relativeDelta.x, lessThan(0));
      expect(joystick.relativeDelta.length, lessThanOrEqualTo(1));
    });

    testWithGame<AshbornGame>('손을 떼면 기본 자리로 돌아간다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.ready();
      final joystick = game.joystick;
      final rest = joystick.origin.clone();

      joystick
        ..hold(Vector2(300, 200))
        ..moveTo(Vector2(500, 200));
      joystick.release();

      expect(joystick.delta, Vector2.zero());
      expect(joystick.relativeDelta, Vector2.zero());
      expect(joystick.origin, rest);
    });

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
