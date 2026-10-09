import 'package:flutter/widgets.dart';

import '../../data/equipment.dart';
import 'pixel_sprite.dart';

/// 장비 부위 픽셀 아이콘 (16x16 을 [scale] 배).
/// [silhouette] 를 주면 빈 칸 표시처럼 그 색 한 가지로 칠한다.
class ItemIcon extends StatelessWidget {
  const ItemIcon(this.type, {super.key, this.scale = 2, this.silhouette});

  static const asset = 'assets/images/sprites/items/gear.png';

  final ItemType type;
  final double scale;
  final Color? silhouette;

  @override
  Widget build(BuildContext context) => PixelSprite(
    asset: asset,
    frameSize: const Size(16, 16),
    start: type.index,
    scale: scale,
    silhouette: silhouette,
  );
}
