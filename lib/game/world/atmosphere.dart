import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../ashborn_game.dart';
import 'dungeon_floor.dart';
import 'region_theme.dart';

/// 지역 분위기: 떠다니는 안개 · 연기, 떠오르는 불티, 화면 가장자리의 열기.
///
/// 적 · 전리품 위, 플레이어 아래에 그린다. 플레이어는 언제나 또렷하게 보인다.
class Atmosphere extends Component with HasGameReference<AshbornGame> {
  Atmosphere() : super(priority: 9);

  /// 안개 덩어리를 흩뿌리는 격자 크기와 덩어리가 흘러가는 바람.
  static const double _cell = 360;
  static const double _windX = 14;
  static const double _windY = 4;
  static const double _maxFogRadius = 340;

  ui.Image? _blob;
  final _embers = <_Ember>[];
  final _random = math.Random();
  double _time = 0;

  final _fogPaint = Paint()..filterQuality = FilterQuality.low;
  final _emberPaint = Paint();
  final _hazePaint = Paint();

  RegionTheme get _theme => RegionTheme.of(game.world.stage.region);

  @override
  void onLoad() => _blob = _bakeBlob();

  /// 가장자리가 아주 부드러운 둥근 덩어리. 겹쳐 그려 안개를 만든다.
  static ui.Image _bakeBlob() {
    const size = 64.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      center,
      size / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          size / 2,
          const [Color(0xFFFFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.45, 1],
        ),
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
    final count = _theme.embers;
    if (_embers.length > count) _embers.length = count;
    final view = game.camera.visibleWorldRect;
    while (_embers.length < count) {
      _embers.add(_Ember()..spawn(_random, view, anywhere: true));
    }
    for (final e in _embers) {
      e
        ..life -= dt
        ..y -= e.rise * dt
        ..x += math.sin(_time * 2 + e.wobble) * 12 * dt;
      if (e.life <= 0 || !view.inflate(40).contains(Offset(e.x, e.y))) {
        e.spawn(_random, view);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final theme = _theme;
    final view = game.camera.visibleWorldRect;
    if (theme.fog case final fog?) {
      _renderFog(canvas, view, fog, theme.fogAlpha);
    }
    for (final e in _embers) {
      final fade = math.min(1.0, e.life / 0.6) * math.min(1.0, e.age / 0.3);
      _emberPaint.color =
          (e.hot ? const Color(0xFFFFD27A) : const Color(0xFFFF7A2E))
              .withValues(alpha: 0.9 * fade);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(e.x, e.y),
          width: e.size,
          height: e.size,
        ),
        _emberPaint,
      );
    }
    if (theme.heat case final heat?) {
      final pulse = 0.85 + 0.15 * math.sin(_time * 1.3);
      _hazePaint.shader = ui.Gradient.radial(
        view.center,
        math.max(view.width, view.height) * 0.62,
        [const Color(0x00000000), heat.withValues(alpha: heat.a * pulse)],
        const [0.4, 1],
      );
      canvas.drawRect(view, _hazePaint);
      _hazePaint.shader = null;
    }
  }

  /// 격자 칸마다 해시로 정한 안개 덩어리를 바람 방향으로 흘려 보낸다.
  void _renderFog(Canvas canvas, Rect view, Color fog, double alpha) {
    final blob = _blob;
    if (blob == null) return;
    // 옅은 안개가 화면 전체에 깔리고, 그 위에 진한 덩어리가 떠다닌다.
    _hazePaint.color = fog.withValues(alpha: alpha * 0.35);
    canvas.drawRect(view, _hazePaint);
    final dx = _windX * _time;
    final dy = _windY * _time;
    final area = view.translate(-dx, -dy).inflate(_maxFogRadius);
    final x0 = (area.left / _cell).floor();
    final x1 = (area.right / _cell).floor();
    final y0 = (area.top / _cell).floor();
    final y1 = (area.bottom / _cell).floor();
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        final h = DungeonFloor.hash(cx, cy, 40);
        if (h < 0.2) continue;
        final x = (cx + DungeonFloor.hash(cx, cy, 41)) * _cell + dx;
        final y = (cy + DungeonFloor.hash(cx, cy, 42)) * _cell + dy;
        final radius =
            _maxFogRadius * (0.5 + 0.5 * DungeonFloor.hash(cx, cy, 43));
        final breathe = 0.75 + 0.25 * math.sin(_time * 0.4 + h * 20);
        _fogPaint.colorFilter = ColorFilter.mode(
          fog.withValues(alpha: alpha * h * breathe),
          BlendMode.modulate,
        );
        canvas.drawImageRect(
          blob,
          const Rect.fromLTWH(0, 0, 64, 64),
          Rect.fromCircle(center: Offset(x, y), radius: radius),
          _fogPaint,
        );
      }
    }
  }
}

/// 떠오르는 불티 하나.
class _Ember {
  double x = 0;
  double y = 0;
  double rise = 0;
  double wobble = 0;
  double life = 0;
  double _lifetime = 1;
  double size = 2;
  bool hot = false;

  double get age => _lifetime - life;

  /// 화면 안 아무 곳에서 (처음) 또는 화면 아래쪽에서 새로 생긴다.
  void spawn(math.Random random, Rect view, {bool anywhere = false}) {
    x = view.left + random.nextDouble() * view.width;
    y = anywhere
        ? view.top + random.nextDouble() * view.height
        : view.top + view.height * (0.4 + 0.6 * random.nextDouble());
    rise = 30 + random.nextDouble() * 50;
    wobble = random.nextDouble() * math.pi * 2;
    _lifetime = life = 2 + random.nextDouble() * 3;
    size = random.nextDouble() < 0.3 ? 4 : 2.5;
    hot = random.nextDouble() < 0.3;
  }
}
