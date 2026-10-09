import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/stages.dart';
import '../ashborn_game.dart';

/// `assets/images/sprites/scene/decor.png` 의 16x16 바닥 장식 순서.
/// `tool/assets/sprites.py` 의 DECOR 와 같아야 한다.
enum Decor {
  skull,
  bones,
  rubble,
  crack,
  ash,
  puddle,
  candles,
  stump,
  embers,
  blood,
  brokenSword,
  spikes,
  hole,
  grass,
}

/// 끝없는 던전 바닥. 0x72 바닥 타일을 깔고 지역마다 다른 장식과 기둥을 흩뿌린다.
///
/// 타일 좌표의 해시로 무늬와 장식을 정해 같은 자리는 언제 돌아와도 같은 모습이다.
/// [chunkTiles] x [chunkTiles] 타일을 원본 픽셀 크기의 그림 한 장으로 구워 두고
/// 카메라가 보는 조각만 키워 그린다. 지역이 바뀌면 색과 장식이 달라 새로 굽는다.
/// 장식은 밟고 지나갈 수 있는 그림일 뿐 충돌하지 않는다.
class DungeonFloor extends Component with HasGameReference<AshbornGame> {
  DungeonFloor() : super(priority: -100);

  /// 원본 1 픽셀의 월드 크기. 캐릭터와 같은 배율이다.
  static const double pixel = Balance.playerSpriteScale;
  static const int tile = 16;
  static const int chunkTiles = 8;
  static const double chunkSize = chunkTiles * tile * pixel;

  /// 구워 둔 조각을 이만큼만 들고 있는다. 화면 하나는 많아야 4x7 조각.
  static const int _maxChunks = 48;

  ui.Image? _tiles;
  ui.Image? _decor;
  ui.Image? _column;
  ui.Image? _brokenColumn;
  Region? _region;
  final _chunks = <int, ui.Image>{}; // 넣은 순서를 기억한다: 맨 앞이 가장 오래 안 쓴 조각.
  final _paint = Paint()..filterQuality = FilterQuality.none;

  bool get _loaded => _tiles != null;

  @override
  void onLoad() {
    // 기다리지 않는다. 다 읽기 전에는 배경색만 보인다.
    unawaited(_load());
  }

  Future<void> _load() async {
    final images = game.images;
    final [tiles, decor, column, broken] = await Future.wait([
      images.load('sprites/scene/tiles.png'),
      images.load('sprites/scene/decor.png'),
      images.load('sprites/scene/column.png'),
      images.load('sprites/scene/column_broken.png'),
    ]);
    _decor = decor;
    _column = column;
    _brokenColumn = broken;
    _tiles = tiles;
  }

  @override
  void onRemove() {
    _clear();
    super.onRemove();
  }

  void _clear() {
    for (final image in _chunks.values) {
      image.dispose();
    }
    _chunks.clear();
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded) return;
    final region = game.world.stage.region;
    if (region != _region) {
      _clear();
      _region = region;
    }
    final view = game.camera.visibleWorldRect;
    final x0 = (view.left / chunkSize).floor();
    final x1 = (view.right / chunkSize).floor();
    final y0 = (view.top / chunkSize).floor();
    final y1 = (view.bottom / chunkSize).floor();
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        final image = _chunk(cx, cy, region);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(cx * chunkSize, cy * chunkSize, chunkSize, chunkSize),
          _paint,
        );
      }
    }
  }

  ui.Image _chunk(int cx, int cy, Region region) {
    final key = ((cx & 0xFFFF) << 16) | (cy & 0xFFFF);
    final cached = _chunks.remove(key);
    if (cached != null) return _chunks[key] = cached;
    if (_chunks.length >= _maxChunks) {
      _chunks.remove(_chunks.keys.first)!.dispose();
    }
    return _chunks[key] = _bake(cx, cy, region);
  }

  /// 조각 하나를 원본 픽셀 크기로 굽는다. 위 줄부터 그려 키 큰 기둥이 윗 타일을 덮는다.
  ui.Image _bake(int cx, int cy, Region region) {
    const size = chunkTiles * tile;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(region.floor, BlendMode.modulate);
    // 장식은 바닥보다 덜 어둡게 칠해 어두운 바닥에 묻히지 않게 한다.
    final propPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(
        Color.lerp(region.floor, const Color(0xFFFFFFFF), 0.45)!,
        BlendMode.modulate,
      );
    final tiles = _tiles!;
    final decor = _decor!;
    void cell(ui.Image sheet, int index, double x, double y, Paint paint) =>
        canvas.drawImageRect(
          sheet,
          Rect.fromLTWH(index * tile.toDouble(), 0, 16, 16),
          Rect.fromLTWH(x, y, 16, 16),
          paint,
        );

    for (var ty = 0; ty < chunkTiles; ty++) {
      for (var tx = 0; tx < chunkTiles; tx++) {
        final gx = cx * chunkTiles + tx;
        final gy = cy * chunkTiles + ty;
        cell(tiles, floorAt(gx, gy), tx * 16.0, ty * 16.0, paint);
      }
    }
    for (var ty = 0; ty < chunkTiles; ty++) {
      for (var tx = 0; tx < chunkTiles; tx++) {
        final gx = cx * chunkTiles + tx;
        final gy = cy * chunkTiles + ty;
        final x = tx * 16.0;
        final bottom = (ty + 1) * 16.0;
        switch (propAt(gx, gy, region)) {
          case null:
            break;
          case final Decor d:
            cell(decor, d.index, x, bottom - 16, propPaint);
          // 키 큰 기둥은 조각 위로 잘리지 않을 만큼 아래 줄에만 선다.
          case _Pillar.full when ty >= 2:
            _pillar(canvas, _column!, x, bottom + 9, propPaint);
          case _Pillar.broken when ty >= 1:
            _pillar(canvas, _brokenColumn!, x, bottom, propPaint);
          case _Pillar():
            break;
        }
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size, size);
    picture.dispose();
    return image;
  }

  /// 기둥 그림의 맨 아래가 [bottom] 에 오도록 세운다.
  /// 원본 기둥은 아래 9줄이 비어 있어 그만큼 내려 그린다.
  static void _pillar(
    Canvas canvas,
    ui.Image image,
    double x,
    double bottom,
    Paint paint,
  ) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, w, h),
      Rect.fromLTWH(x, bottom - h, w, h),
      paint,
    );
  }

  /// 타일 좌표의 0 이상 1 미만 해시. [salt] 마다 독립적이다.
  static double hash(int x, int y, [int salt = 0]) {
    var h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0x7FFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF;
    h ^= h >> 16;
    return h / 0x80000000;
  }

  /// 바닥 무늬 (scene/tiles.png 의 0~7). 대부분 민바닥이고 가끔 금 간 바닥이 섞인다.
  static int floorAt(int x, int y) {
    final r = hash(x, y);
    if (r < 0.86) return 0;
    return 1 + ((r - 0.86) / 0.14 * 7).floor().clamp(0, 6);
  }

  /// 이 타일에 놓인 장식이나 기둥. 대부분 null.
  static Object? propAt(int x, int y, Region region) {
    final r = hash(x, y, 1);
    if (r < Balance.floorDecorChance) {
      final set = decorSet(region);
      final total = set.values.fold(0, (sum, w) => sum + w);
      var pick = hash(x, y, 2) * total;
      for (final MapEntry(key: decor, value: weight) in set.entries) {
        pick -= weight;
        if (pick < 0) return decor;
      }
      return set.keys.last;
    }
    if (r < Balance.floorDecorChance + Balance.floorPillarChance) {
      return hash(x, y, 3) < 0.35 ? _Pillar.full : _Pillar.broken;
    }
    return null;
  }

  /// 지역마다 흩뿌리는 장식과 가중치.
  static Map<Decor, int> decorSet(Region region) => switch (region) {
    Region.ashPlains => const {
      Decor.bones: 3,
      Decor.skull: 2,
      Decor.ash: 3,
      Decor.grass: 3,
      Decor.crack: 3,
      Decor.rubble: 2,
    },
    Region.sunkenCathedral => const {
      Decor.puddle: 4,
      Decor.candles: 2,
      Decor.rubble: 3,
      Decor.crack: 2,
      Decor.skull: 1,
      Decor.bones: 1,
    },
    Region.burningForest => const {
      Decor.embers: 4,
      Decor.stump: 3,
      Decor.ash: 3,
      Decor.grass: 2,
      Decor.crack: 1,
    },
    Region.rustedFortress => const {
      Decor.brokenSword: 3,
      Decor.spikes: 2,
      Decor.rubble: 3,
      Decor.crack: 2,
      Decor.hole: 1,
      Decor.skull: 1,
    },
    Region.undyingHeart => const {
      Decor.blood: 4,
      Decor.bones: 3,
      Decor.skull: 2,
      Decor.crack: 2,
      Decor.hole: 1,
    },
  };
}

/// 바닥에 선 기둥. 온전한 것과 윗단이 깨진 것.
enum _Pillar { full, broken }
