import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';

/// `assets/images/sprites/scene/tiles.png` 의 16x16 타일 순서.
/// `tool/assets/sprites.py` 의 TILES 와 같아야 한다.
enum DungeonTile {
  floor1,
  floor2,
  floor3,
  floor4,
  floor5,
  floor6,
  floor7,
  floor8,
  wallTop,
  wall,
  bannerRed,
  bannerBlue,
  wallHole,
  skull,
}

/// 화면 배경용 픽셀 크기와 위치 계산.
abstract final class PixelScene {
  static const tilesAsset = 'assets/images/sprites/scene/tiles.png';
  static const columnAsset = 'assets/images/sprites/scene/column.png';
  static const campfireAsset = 'assets/images/sprites/scene/campfire.png';
  static const tile = 16.0;

  /// 위쪽 벽이 차지하는 타일 줄 수.
  static const wallRows = 3;

  /// 원본 1 픽셀을 화면 몇 픽셀로 그릴지. 정수라야 픽셀이 고르게 보인다.
  static double pixelFor(Size screen) =>
      (screen.shortestSide / 130).floorToDouble().clamp(2, 8);

  /// 벽이 끝나고 바닥이 시작하는 높이.
  static double floorTop(double pixel) => wallRows * tile * pixel;
}

/// 0x72 타일로 깐 던전 바닥과 벽. [light] 둘레만 밝고 바깥은 [darkness] 만큼 어둡다.
/// [walls] 가 false 면 바닥만 깐다 (글자가 많은 화면용).
class DungeonBackdrop extends StatefulWidget {
  const DungeonBackdrop({
    super.key,
    required this.pixel,
    this.light,
    this.lightRadius = 300,
    this.darkness = 0.8,
    this.walls = true,
  });

  final double pixel;
  final bool walls;
  final Offset? light;
  final double lightRadius;
  final double darkness;

  @override
  State<DungeonBackdrop> createState() => _DungeonBackdropState();
}

class _DungeonBackdropState extends State<DungeonBackdrop> {
  ui.Image? _tiles;
  ui.Image? _column;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tiles = await PixelImages.load(PixelScene.tilesAsset);
    final column = await PixelImages.load(PixelScene.columnAsset);
    if (mounted) {
      setState(() {
        _tiles = tiles;
        _column = column;
      });
    }
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BackdropPainter(
      tiles: _tiles,
      column: _column,
      pixel: widget.pixel,
      light: widget.light,
      lightRadius: widget.lightRadius,
      darkness: widget.darkness,
      walls: widget.walls,
    ),
    size: Size.infinite,
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.tiles,
    required this.column,
    required this.pixel,
    required this.light,
    required this.lightRadius,
    required this.darkness,
    required this.walls,
  });

  final ui.Image? tiles;
  final ui.Image? column;
  final double pixel;
  final Offset? light;
  final double lightRadius;
  final double darkness;
  final bool walls;

  static const _night = Color(0xFF0B0908);

  /// 바닥 무늬. 대부분 민바닥이고 가끔 금 간 바닥이 섞인다.
  static DungeonTile _floor(int x, int y) {
    final r = math.Random(x * 7349 + y * 1931).nextDouble();
    if (r < 0.6) return DungeonTile.floor1;
    return DungeonTile.values[1 + ((r - 0.6) / 0.4 * 7).floor().clamp(0, 6)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _night);
    final tiles = this.tiles;
    if (tiles != null) _paintTiles(canvas, size, tiles);
    _paintDarkness(canvas, size);
  }

  void _paintTiles(Canvas canvas, Size size, ui.Image tiles) {
    final t = PixelScene.tile * pixel;
    final paint = Paint()..filterQuality = FilterQuality.none;
    // 가운데에 타일 경계가 오도록 맞춘다.
    final x0 = (size.width / 2) % t - t;
    final cols = (size.width / t).ceil() + 2;
    final rows = (size.height / t).ceil() + 1;
    void draw(DungeonTile tile, double x, double y) => canvas.drawImageRect(
      tiles,
      Offset(PixelScene.tile * tile.index, 0) &
          const Size(PixelScene.tile, PixelScene.tile),
      Rect.fromLTWH(x, y, t, t),
      paint,
    );

    final floorRow = walls ? PixelScene.wallRows : 0;
    for (var c = 0; c < cols; c++) {
      final x = x0 + c * t;
      // 벽: 맨 윗줄은 벽 머리, 그 아래는 벽돌. 깃발과 구멍을 띄엄띄엄.
      if (walls) draw(DungeonTile.wallTop, x, 0);
      for (var r = 1; r < floorRow; r++) {
        final tile = switch ((c % 6, r)) {
          (2, 1) =>
            c % 12 == 2 ? DungeonTile.bannerRed : DungeonTile.bannerBlue,
          (5, 2) when c % 18 == 5 => DungeonTile.wallHole,
          _ => DungeonTile.wall,
        };
        draw(tile, x, r * t);
      }
      for (var r = floorRow; r < rows; r++) {
        final tile = (c * 13 + r * 7) % 41 == 0
            ? DungeonTile.skull
            : _floor(c, r);
        if (tile == DungeonTile.skull) draw(_floor(c, r), x, r * t);
        draw(tile, x, r * t);
      }
    }
    // 벽 앞의 기둥. 바닥 첫 줄에 발을 딛는다.
    final column = this.column;
    if (walls && column != null) {
      final h = column.height * pixel;
      for (var c = 0; c < cols; c += 9) {
        canvas.drawImageRect(
          column,
          Offset.zero & Size(column.width.toDouble(), column.height.toDouble()),
          Rect.fromLTWH(
            x0 + (c + 4) * t,
            PixelScene.floorTop(pixel) + t - h,
            column.width * pixel,
            h,
          ),
          paint,
        );
      }
    }
  }

  void _paintDarkness(Canvas canvas, Size size) {
    final dark = _night.withValues(alpha: darkness);
    final light = this.light;
    final paint = Paint();
    if (light == null) {
      paint.color = dark;
    } else {
      paint.shader = ui.Gradient.radial(
        light,
        lightRadius,
        [_night.withValues(alpha: darkness * 0.15), dark],
        [0.2, 1],
      );
    }
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.tiles != tiles ||
      old.column != column ||
      old.pixel != pixel ||
      old.light != light ||
      old.lightRadius != lightRadius ||
      old.darkness != darkness ||
      old.walls != walls;
}
