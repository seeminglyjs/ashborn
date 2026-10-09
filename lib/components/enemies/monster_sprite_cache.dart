import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../data/monster_sprites.dart';

/// 적 · 보스 스프라이트 프레임. 적이 수백 마리라 컴포넌트를 따로 붙이지 않고,
/// 게임이 한 번 읽어 둔 프레임을 [Enemy] 가 직접 그린다.
class MonsterSpriteCache {
  final _frames = <MonsterSprite, List<Sprite>>{};

  /// 아직 읽지 않았으면 null. 그동안 적은 원으로 그린다.
  List<Sprite>? operator [](MonsterSprite sprite) => _frames[sprite];

  Future<void> load(Images images) async {
    for (final sprite in MonsterSprite.values) {
      if (_frames.containsKey(sprite)) continue;
      final image = await images.load(sprite.path);
      final size = Vector2(sprite.width, sprite.height);
      _frames[sprite] = [
        for (var i = 0; i < MonsterSprite.frameCount; i++)
          Sprite(
            image,
            srcPosition: Vector2(sprite.width * i, 0),
            srcSize: size,
          ),
      ];
    }
  }
}
