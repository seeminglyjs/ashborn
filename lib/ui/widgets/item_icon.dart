import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../data/equipment.dart';
import 'pixel_sprite.dart';

/// 장비 부위 픽셀 아이콘 (16x16 을 [scale] 배). 직업 무기면 [kind] 의 무기 아이콘을 쓴다.
///
/// [rarity] 가 고유면 고유 전용 아이콘을 쓰고, 영웅 이상이면 아이콘 둘레가 등급 색으로
/// 빛난다 (등급이 높을수록 넓게). [silhouette] 를 주면 빈 칸 표시처럼 그 색 한 가지로 칠한다.
class ItemIcon extends StatelessWidget {
  const ItemIcon(
    this.type, {
    super.key,
    this.rarity,
    this.kind,
    this.scale = 2,
    this.silhouette,
  });

  static const asset = 'assets/images/sprites/items/gear.png';
  static const uniqueAsset = 'assets/images/sprites/items/gear_unique.png';
  static const weaponAsset = 'assets/images/sprites/items/weapons.png';
  static const uniqueWeaponAsset =
      'assets/images/sprites/items/weapons_unique.png';

  final ItemType type;
  final WeaponKind? kind;
  final Rarity? rarity;
  final double scale;
  final Color? silhouette;

  /// 아이콘이 빛나는 등급인가 (영웅 이상).
  static bool glows(Rarity rarity) => rarity.index >= Rarity.hero.index;

  /// 영웅 0 부터 고유 3 까지, 빛의 세기 단계.
  static int glowLevel(Rarity rarity) => rarity.index - Rarity.hero.index;

  @override
  Widget build(BuildContext context) {
    final rarity = this.rarity;
    final unique = rarity == Rarity.unique;
    final kind = this.kind;
    PixelSprite sprite({Color? silhouette}) => PixelSprite(
      asset: kind != null
          ? (unique ? uniqueWeaponAsset : weaponAsset)
          : (unique ? uniqueAsset : asset),
      frameSize: const Size(16, 16),
      start: kind?.index ?? type.index,
      scale: scale,
      silhouette: silhouette,
    );
    if (rarity == null || silhouette != null || !glows(rarity)) {
      return sprite(silhouette: silhouette);
    }
    final sigma = scale * (0.9 + 0.35 * glowLevel(rarity));
    // 넓게 번진 빛과 아이콘에 붙은 진한 빛을 겹쳐 또렷한 후광을 만든다.
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final s in [sigma * 1.6, sigma * 0.6])
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: s, sigmaY: s),
            child: sprite(silhouette: rarity.color),
          ),
        sprite(),
      ],
    );
  }
}
