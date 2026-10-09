import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../data/equipment.dart';
import '../../data/supplies.dart';

/// 전투 맵의 상자 · 떨어진 장비 · 소모품 그림. 게임이 한 번 읽어 두고 각 컴포넌트가 직접 그린다.
/// 아직 읽지 않았으면 null 이고, 그동안은 단순한 도형으로 그린다.
class PropSprites {
  static const gearPath = 'sprites/items/gear.png';
  static const suppliesPath = 'sprites/items/pickups.png';

  Sprite? crate;
  Sprite? chest;
  List<Sprite>? _gear;
  List<Sprite>? _supplies;

  Sprite? gear(ItemType type) => _gear?[type.index];
  Sprite? supply(Supply supply) => _supplies?[supply.index];

  Future<void> load(Images images) async {
    if (crate != null) return;
    final [crateImage, chestImage, gearImage, supplyImage] = await Future.wait([
      images.load('sprites/scene/crate.png'),
      images.load('sprites/scene/chest.png'),
      images.load(gearPath),
      images.load(suppliesPath),
    ]);
    List<Sprite> frames(int count, Image image) => [
      for (var i = 0; i < count; i++)
        Sprite(
          image,
          srcPosition: Vector2(16.0 * i, 0),
          srcSize: Vector2.all(16),
        ),
    ];
    _gear = frames(ItemType.values.length, gearImage);
    _supplies = frames(Supply.values.length, supplyImage);
    chest = Sprite(chestImage);
    crate = Sprite(crateImage);
  }
}
