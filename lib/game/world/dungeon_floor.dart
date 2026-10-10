import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/stages.dart';
import '../../data/characters.dart';
import '../../components/enemies/hazards.dart';
import '../ashborn_game.dart';
import 'obstacles.dart';
import 'region_theme.dart';

/// 끝없는 전투 맵 바닥. 지역마다 다른 바닥 타일을 깔고 장식 · 구조물 · 물을 흩뿌린다
/// ([RegionTheme]).
///
/// 타일 좌표의 해시로 무늬와 장식을 정해 같은 자리는 언제 돌아와도 같은 모습이다.
/// [chunkTiles] x [chunkTiles] 타일을 원본 픽셀 크기의 그림 한 장으로 구워 두고
/// 카메라가 보는 조각만 키워 그린다. 지역이 바뀌면 새로 굽는다.
/// 구조물의 불꽃과 함정(가시)만은 굽지 않고 매 프레임 상태에 맞춰 그린다.
/// 장식은 밟고 지나갈 수 있고, 구조물 밑동은 [Obstacles] 가 막는다.
class DungeonFloor extends Component with HasGameReference<AshbornGame> {
  DungeonFloor() : super(priority: -100);

  /// 원본 1 픽셀의 월드 크기. 캐릭터와 같은 배율이다.
  static const double pixel = Balance.playerSpriteScale;
  static const int tile = 16;
  static const int chunkTiles = 8;
  static const double chunkSize = chunkTiles * tile * pixel;

  /// 구워 둔 조각을 이만큼만 들고 있는다. 화면 하나는 많아야 4x8 조각.
  static const int _maxChunks = 48;

  /// 불꽃 시트 (16x24 프레임 6장). 불꽃 밑동은 프레임의 21번째 줄이다.
  static const _flamePath = 'sprites/scene/flame.png';
  static const _decorPath = 'sprites/scene/decor.png';
  static const _flameFrames = 6;
  static const double _flameBase = 21;
  static const double _flameFps = 10;

  final _images = <String, ui.Image>{};
  ui.Image? _glow;
  bool _loaded = false;
  Region? _region;

  /// 넣은 순서를 기억한다: 맨 앞이 가장 오래 안 쓴 조각.
  final _chunks = <int, _Chunk>{};
  final _paint = Paint()..filterQuality = FilterQuality.none;
  final _glowPaint = Paint()..blendMode = BlendMode.plus;
  double _time = 0;

  @override
  void onLoad() {
    // 기다리지 않는다. 다 읽기 전에는 배경색만 보인다.
    unawaited(_load());
  }

  Future<void> _load() async {
    final paths = {
      _flamePath,
      _decorPath,
      for (final r in Region.values) RegionTheme.of(r).floorSheet,
      for (final s in Structure.values) s.path,
    };
    final images = await Future.wait(paths.map(game.images.load));
    _images.addAll(Map.fromIterables(paths, images));
    _glow = _bakeGlow();
    _loaded = true;
  }

  /// 가운데가 밝고 가장자리로 갈수록 사라지는 둥근 빛. 불꽃 둘레를 밝힌다.
  static ui.Image _bakeGlow() {
    const size = 64.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      center,
      size / 2,
      Paint()
        ..shader = ui.Gradient.radial(center, size / 2, const [
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ]),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    picture.dispose();
    return image;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void onRemove() {
    _clear();
    super.onRemove();
  }

  void _clear() {
    for (final chunk in _chunks.values) {
      chunk.image.dispose();
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
    final theme = RegionTheme.of(region);
    final view = game.camera.visibleWorldRect;
    final x0 = (view.left / chunkSize).floor();
    final x1 = (view.right / chunkSize).floor();
    final y0 = (view.top / chunkSize).floor();
    // 아래 조각의 불꽃이 위로 솟아 화면에 들어올 수 있어 한 줄 더 본다.
    final y1 = (view.bottom / chunkSize).floor() + 1;
    final visible = <_Chunk>[];
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        final chunk = _chunk(cx, cy, theme);
        visible.add(chunk);
        final image = chunk.image;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(cx * chunkSize, cy * chunkSize, chunkSize, chunkSize),
          _paint,
        );
      }
    }
    _renderSpikes(canvas, visible);
    _renderFlames(canvas, visible);
    _renderVentWarnings(canvas, visible);
  }

  /// 화염 분출구: 예고 · 분출 중에는 불이 닿는 범위를 빨간 테두리 원으로 보여 준다.
  void _renderVentWarnings(Canvas canvas, List<_Chunk> chunks) {
    final time = game.world.elapsed;
    for (final chunk in chunks) {
      for (final f in chunk.flames) {
        final (gx, gy) = f.vent ?? (0, 0);
        if (f.vent == null) continue;
        final state = TrapSystem.ventState(gx, gy, time);
        if (state == TrapState.down) continue;
        final c = Obstacles.footOf(gx, gy);
        final r = Balance.ventRadius;
        if (state == TrapState.up) {
          canvas.drawCircle(Offset(c.x, c.y), r, _ventFill);
        }
        canvas.drawCircle(
          Offset(c.x, c.y),
          r,
          dangerStroke(state == TrapState.up ? 2.5 : 1.5),
        );
      }
    }
  }

  static final _ventFill = Paint()..color = const Color(0x33FF3A2E);

  /// 가시 함정. 들어가 있을 땐 구멍만, 예고 동안 끝이 차오르고, 솟으면 다 보인다.
  void _renderSpikes(Canvas canvas, List<_Chunk> chunks) {
    final decor = _images[_decorPath]!;
    final time = game.world.elapsed;
    final index = Decor.spikes.index * tile.toDouble();
    for (final chunk in chunks) {
      for (final (gx, gy) in chunk.spikes) {
        final x = gx * tile * pixel;
        final y = gy * tile * pixel;
        final rise = switch (TrapSystem.spikeState(gx, gy, time)) {
          TrapState.down => 0.0,
          TrapState.warning => 0.15 + 0.25 * TrapSystem.spikeRise(gx, gy, time),
          TrapState.up => 1.0,
        };
        // 구멍 네 개.
        for (final (hx, hy) in const [(4, 5), (11, 5), (4, 12), (11, 12)]) {
          canvas.drawRect(
            Rect.fromLTWH(x + hx * pixel, y + hy * pixel, 2 * pixel, pixel),
            _hole,
          );
        }
        if (rise <= 0) continue;
        // 솟는 가시는 적의 공격처럼 빨간 테두리로 감싼다 (예고 때는 깜빡인다).
        final state = TrapSystem.spikeState(gx, gy, time);
        if (state == TrapState.up || (_time * 8).floor().isEven) {
          canvas.drawRect(
            Rect.fromLTWH(x + pixel, y + 3 * pixel, 14 * pixel, 12 * pixel),
            dangerStroke(state == TrapState.up ? 2.5 : 1.5),
          );
        }
        final h = 16 * rise;
        canvas.drawImageRect(
          decor,
          Rect.fromLTWH(index, 0, 16, h),
          Rect.fromLTWH(x, y + (16 - h) * pixel, 16 * pixel, h * pixel),
          _paint,
        );
      }
    }
  }

  static final _hole = Paint()..color = const Color(0xFF0A0706);

  /// 화염 분출구 불꽃 크기: 쉬는 동안 작게 일렁이고, 예고 동안 떨며 커지고, 분출하면 크게.
  double _ventScale(_Flame f) {
    final (gx, gy) = f.vent!;
    return switch (TrapSystem.ventState(gx, gy, game.world.elapsed)) {
      TrapState.down => 0.35,
      TrapState.warning => 0.55 + 0.1 * math.sin(_time * 40),
      TrapState.up => 1.7,
    };
  }

  /// 구조물의 불꽃과 그 둘레의 빛. 불꽃마다 박자를 달리해 함께 일렁이지 않게 한다.
  void _renderFlames(Canvas canvas, List<_Chunk> chunks) {
    final flame = _images[_flamePath]!;
    final glow = _glow!;
    for (final chunk in chunks) {
      for (final f in chunk.flames) {
        final scale = f.vent == null ? f.scale : f.scale * _ventScale(f);
        final flicker = 0.85 + 0.15 * math.sin(_time * 9 + f.phase * 7);
        _glowPaint.colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 110, 40, 0.5 * flicker),
          BlendMode.modulate,
        );
        canvas.drawImageRect(
          glow,
          const Rect.fromLTWH(0, 0, 64, 64),
          Rect.fromCircle(
            center: Offset(f.x, f.y - 10 * scale),
            radius: 46 * scale * flicker,
          ),
          _glowPaint,
        );
      }
    }
    for (final chunk in chunks) {
      for (final f in chunk.flames) {
        final frame =
            (_time * _flameFps + f.phase * _flameFrames).floor() % _flameFrames;
        final scale = f.vent == null ? f.scale : f.scale * _ventScale(f);
        final w = 16 * pixel * scale;
        final h = 24 * pixel * scale;
        canvas.drawImageRect(
          flame,
          Rect.fromLTWH(frame * 16.0, 0, 16, 24),
          Rect.fromLTWH(f.x - w / 2, f.y - _flameBase * pixel * scale, w, h),
          _paint,
        );
      }
    }
  }

  /// 플레이어 앞쪽(아래)에 서서 플레이어 그림과 겹치는 구조물을 플레이어 위에 한 번 더 그린다.
  /// 바닥 그림은 늘 캐릭터 아래라, 이것이 없으면 기둥 뒤로 걸어가도 기둥 위에 그려져
  /// 기둥을 뚫고 지나가는 것처럼 보인다. 조금 비치게 그려 가려진 캐릭터도 보이게 한다.
  void renderFront(Canvas canvas) {
    if (!_loaded) return;
    final world = game.world;
    final theme = RegionTheme.of(world.stage.region);
    final player = world.player;
    final feetY = player.position.y + Balance.playerRadius;
    final halfW = heroFrame.width * Balance.playerSpriteScale / 2;
    final body = Rect.fromLTRB(
      player.position.x - halfW,
      feetY - heroFrame.height * Balance.playerSpriteScale - player.leapLift,
      player.position.x + halfW,
      feetY,
    );
    const span = tile * pixel;
    final x0 = ((body.left - span) / span).floor();
    final x1 = ((body.right + span) / span).floor();
    final y0 = (feetY / span).floor() - 1;
    final y1 = ((feetY + 48 * pixel) / span).floor() + 1;
    _frontPaint.colorFilter = ColorFilter.mode(
      Color.lerp(
        theme.floorTint,
        const Color(0xFFFFFFFF),
        0.45,
      )!.withValues(alpha: 0.8),
      BlendMode.modulate,
    );
    for (var gy = y0; gy <= y1; gy++) {
      for (var gx = x0; gx <= x1; gx++) {
        final s = world.obstacles.structureAt(gx, gy);
        if (s == null) continue;
        if (Obstacles.footOf(gx, gy).y <= feetY) continue;
        final image = _images[s.path]!;
        final w = image.width.toDouble();
        final h = image.height.toDouble();
        final rect = Rect.fromLTWH(
          (gx * tile + 8 - w / 2) * pixel,
          ((gy + 1) * tile + s.bottomPad - h) * pixel,
          w * pixel,
          h * pixel,
        );
        if (!rect.overlaps(body)) continue;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, w, h),
          rect,
          _frontPaint,
        );
      }
    }
  }

  final _frontPaint = Paint()..filterQuality = FilterQuality.none;

  _Chunk _chunk(int cx, int cy, RegionTheme theme) {
    final key = ((cx & 0xFFFF) << 16) | (cy & 0xFFFF);
    final cached = _chunks.remove(key);
    if (cached != null) return _chunks[key] = cached;
    if (_chunks.length >= _maxChunks) {
      _chunks.remove(_chunks.keys.first)!.image.dispose();
    }
    return _chunks[key] = _bake(cx, cy, theme);
  }

  /// 조각 하나를 원본 픽셀 크기로 굽는다. 위 줄부터 그려 키 큰 구조물이 윗 타일을 덮는다.
  _Chunk _bake(int cx, int cy, RegionTheme theme) {
    const size = chunkTiles * tile;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(theme.floorTint, BlendMode.modulate);
    // 장식은 바닥보다 덜 어둡게 칠해 어두운 바닥에 묻히지 않게 한다.
    final propPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(
        Color.lerp(theme.floorTint, const Color(0xFFFFFFFF), 0.45)!,
        BlendMode.modulate,
      );
    final floor = _images[theme.floorSheet]!;
    final decor = _images[_decorPath]!;
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
        cell(floor, floorAt(gx, gy, theme), tx * 16.0, ty * 16.0, paint);
      }
    }
    if (theme.water case final threshold?) {
      _paintWater(canvas, cx * size, cy * size, threshold);
    }
    final flames = <_Flame>[];
    final spikes = <(int, int)>[];
    for (var ty = 0; ty < chunkTiles; ty++) {
      for (var tx = 0; tx < chunkTiles; tx++) {
        final gx = cx * chunkTiles + tx;
        final gy = cy * chunkTiles + ty;
        final x = tx * 16.0;
        final bottom = (ty + 1) * 16.0;
        switch (propAt(gx, gy, theme)) {
          case null:
            break;
          case Decor.spikes:
            spikes.add((gx, gy));
          case final Decor d:
            cell(decor, d.index, x, bottom - 16, propPaint);
          case final Structure s:
            final image = _images[s.path]!;
            final w = image.width.toDouble();
            final h = image.height.toDouble();
            // 조각 밖으로 잘리지 않을 만큼 안쪽 타일에만 선다.
            if (!s.fitsChunk(tx, ty, chunkTiles)) break;
            final left = x + 8 - w / 2;
            final top = bottom + s.bottomPad - h;
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(0, 0, w, h),
              Rect.fromLTWH(left, top, w, h),
              propPaint,
            );
            for (final (i, (fx, fy, scale)) in s.flames.indexed) {
              flames.add(
                _Flame(
                  x: (cx * size + left + fx) * pixel,
                  y: (cy * size + top + fy) * pixel,
                  scale: scale,
                  phase: hash(gx, gy, 10 + i),
                  vent: s == Structure.fireVent ? (gx, gy) : null,
                ),
              );
            }
          default:
            break;
        }
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size, size);
    picture.dispose();
    return _Chunk(image, flames, spikes);
  }

  static final _deep = Paint()..color = const Color(0xE81A3448);
  static final _shallow = Paint()..color = const Color(0xE0305878);
  static final _shore = Paint()..color = const Color(0xFF5E8EB0);
  static final _sparkle = Paint()..color = const Color(0xFFA8D8EE);

  /// 물에 잠긴 땅. 원본 픽셀마다 물인지 보고, 한 줄에서 같은 색이 이어지는 만큼 한 번에 칠한다.
  /// 가장자리는 밝은 물가, 깊은 곳은 어둡게, 가끔 반짝임을 찍는다.
  static void _paintWater(Canvas canvas, int ox, int oy, double threshold) {
    const size = chunkTiles * tile;
    // 둘레 한 줄까지 물 높이를 한 번만 계산해 둔다.
    const span = size + 2;
    final levels = List<double>.generate(
      span * span,
      (i) => waterLevel(ox + i % span - 1, oy + i ~/ span - 1),
    );
    double levelAt(int x, int y) => levels[(y + 1) * span + x + 1];
    bool wet(int x, int y) => levelAt(x, y) > threshold;
    for (var y = 0; y < size; y++) {
      Paint? run;
      var start = 0;
      for (var x = 0; x <= size; x++) {
        Paint? paint;
        if (x < size) {
          final level = levelAt(x, y);
          if (level > threshold) {
            if (!wet(x - 1, y) ||
                !wet(x + 1, y) ||
                !wet(x, y - 1) ||
                !wet(x, y + 1)) {
              paint = _shore;
            } else if (hash(ox + x, oy + y, 20) < 0.0015) {
              paint = _sparkle;
            } else {
              paint = level > threshold + 0.06 ? _deep : _shallow;
            }
          }
        }
        if (identical(paint, run)) continue;
        if (run != null) {
          canvas.drawRect(
            Rect.fromLTRB(start.toDouble(), y.toDouble(), x.toDouble(), y + 1),
            run,
          );
        }
        run = paint;
        start = x;
      }
    }
  }

  /// 원본 픽셀 좌표의 물 높이 (0~1). 넓게 퍼진 웅덩이 위에 작은 굴곡을 더한다.
  static double waterLevel(int x, int y) =>
      _valueNoise(x / 72, y / 72, 30) * 0.75 +
      _valueNoise(x / 18, y / 18, 31) * 0.25;

  /// 격자 점마다 해시 값을 두고 부드럽게 이어 붙인 노이즈 (0~1).
  static double _valueNoise(double x, double y, int salt) {
    final ix = x.floor();
    final iy = y.floor();
    double smooth(double t) => t * t * (3 - 2 * t);
    final fx = smooth(x - ix);
    final fy = smooth(y - iy);
    double at(int dx, int dy) => hash(ix + dx, iy + dy, salt);
    final top = at(0, 0) + (at(1, 0) - at(0, 0)) * fx;
    final bottom = at(0, 1) + (at(1, 1) - at(0, 1)) * fx;
    return top + (bottom - top) * fy;
  }

  /// 타일 (가운데 픽셀) 이 물에 잠겼는가.
  static bool flooded(int x, int y, RegionTheme theme) => switch (theme.water) {
    null => false,
    final threshold => waterLevel(x * tile + 8, y * tile + 8) > threshold,
  };

  /// 타일 좌표의 0 이상 1 미만 해시. [salt] 마다 독립적이다.
  static double hash(int x, int y, [int salt = 0]) {
    var h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0x7FFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF;
    h ^= h >> 16;
    return h / 0x80000000;
  }

  static T _pick<T>(Map<T, int> weights, double r) {
    final total = weights.values.fold(0, (sum, w) => sum + w);
    var pick = r * total;
    for (final MapEntry(key: value, value: weight) in weights.entries) {
      pick -= weight;
      if (pick < 0) return value;
    }
    return weights.keys.last;
  }

  /// 바닥 타일 (지역 바닥 시트의 0~7).
  static int floorAt(int x, int y, RegionTheme theme) {
    final weights = theme.floorWeights;
    final total = weights.fold(0, (sum, w) => sum + w);
    var pick = hash(x, y) * total;
    for (final (i, w) in weights.indexed) {
      pick -= w;
      if (pick < 0) return i;
    }
    return weights.length - 1;
  }

  /// 이 타일에 놓인 장식([Decor])이나 구조물([Structure]). 대부분 null.
  /// 물 위에는 기둥만 선다.
  static Object? propAt(int x, int y, RegionTheme theme) {
    final r = hash(x, y, 1);
    final Object prop;
    if (r < theme.decorChance) {
      prop = _pick(theme.decor, hash(x, y, 2));
    } else if (r < theme.decorChance + theme.structureChance) {
      prop = _pick(theme.structures, hash(x, y, 3));
    } else {
      return null;
    }
    if (flooded(x, y, theme) && !(prop is Structure && prop.standsInWater)) {
      return null;
    }
    return prop;
  }
}

class _Chunk {
  _Chunk(this.image, this.flames, this.spikes);

  final ui.Image image;

  /// 이 조각 구조물들의 불꽃 (월드 좌표).
  final List<_Flame> flames;

  /// 이 조각의 가시 함정 타일 좌표.
  final List<(int, int)> spikes;
}

class _Flame {
  _Flame({
    required this.x,
    required this.y,
    required this.scale,
    required this.phase,
    this.vent,
  });

  /// 화염 분출구 불꽃이면 그 타일. 분출 주기에 맞춰 크기가 바뀐다.
  final (int, int)? vent;

  /// 불꽃 밑동 가운데.
  final double x;
  final double y;
  final double scale;

  /// 0~1. 불꽃마다 다른 박자.
  final double phase;
}

/// 플레이어 위에 그리는 앞쪽 구조물 ([DungeonFloor.renderFront]).
class StructureFront extends Component {
  StructureFront(this.floor) : super(priority: 11);

  final DungeonFloor floor;

  @override
  void render(Canvas canvas) => floor.renderFront(canvas);
}
