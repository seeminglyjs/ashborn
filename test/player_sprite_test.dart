import 'package:ashborn/components/player/player.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 플레이어에 붙은 캐릭터 스프라이트. 이미지를 읽을 때까지 진행시킨다.
Future<SpriteAnimationGroupComponent<PlayerPose>> spriteOf(
  AshbornGame game,
) async {
  for (var i = 0; i < 60; i++) {
    final found = game.world.player.children
        .whereType<SpriteAnimationGroupComponent<PlayerPose>>();
    if (found.isNotEmpty) return found.single;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await advance(game, 1 / 60);
  }
  throw StateError('스프라이트를 읽지 못했다');
}

void main() {
  for (final character in Roster.all) {
    testWithGame<AshbornGame>(
      '${character.name} 스프라이트: 서 있으면 대기, 움직이면 달리기',
      gameWith(character),
      (game) async {
        await game.ready();
        final sprite = await spriteOf(game);
        expect(sprite.current, PlayerPose.idle);
        expect(sprite.animations!.keys, PlayerPose.values);

        game.joystick.delta.setValues(game.joystick.knobRadius, 0);
        await advance(game, 0.1);
        expect(sprite.current, PlayerPose.run);
        expect(sprite.isFlippedHorizontally, isFalse);

        game.joystick.delta.setValues(-game.joystick.knobRadius, 0);
        await advance(game, 0.1);
        expect(sprite.isFlippedHorizontally, isTrue);
      },
    );
  }

  testWithGame<AshbornGame>('맞으면 잠깐 피격 자세가 된다', gameWith(Roster.knight), (
    game,
  ) async {
    await game.ready();
    final sprite = await spriteOf(game);
    await clearEnemies(game);

    game.world.player.takeDamage(1);
    await advance(game, 1 / 60);
    expect(sprite.current, PlayerPose.hit);

    await advance(game, 0.3);
    expect(sprite.current, PlayerPose.idle);
  });
}
