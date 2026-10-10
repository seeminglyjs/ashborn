import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../weapons/weapon_art.dart';

/// 내 공격 이펙트를 도트로 그리는 도구.
///
/// 매끈한 원 · 호 대신 [px] 크기의 네모 칸을 찍어 캐릭터 · 무기 도트와 같은 결로 보이게 한다.
/// 칸은 그리는 원점 기준 격자에 맞춰 찍고, 같은 색끼리 모아 한 번에 그린다 ([PixelCanvas]).
/// 흐려지는 것도 알파 대신 바둑판 솎아 내기(디더)로 표현한다 — 도트 게임의 사라짐.
///
/// 적의 공격은 이 도구를 쓰지 않고 빨간 테두리를 두른다 (hazards.dart). 그래서 도트로 그린
/// 것은 내 공격, 빨간 테두리는 적의 공격으로 한눈에 갈린다.
abstract final class PixelFx {
  /// 이펙트 도트 한 칸의 월드 크기. 캐릭터 도트(2)보다 살짝 굵게 해 움직임 속에서도 또렷하다.
  static const double px = 3;

  /// 칸 ([x], [y]) 를 [level] 단계만큼 솎아 낼지. 0 은 그대로, 1 은 바둑판 절반,
  /// 2 는 네 칸에 하나만, 3 이상은 모두 지운다.
  static bool thinned(int x, int y, int level) => switch (level) {
    <= 0 => false,
    1 => (x + y).isOdd,
    2 => x.isOdd || y.isOdd,
    _ => true,
  };

  /// 시간 비율 [t] (0..1) 에서 [from] 이후로 사라지는 솎아 내기 단계.
  static int fade(double t, {double from = 0.55}) {
    if (t <= from) return 0;
    return 1 + ((t - from) / (1 - from) * 3).floor();
  }

  /// 칸마다 정해진 0..1 값. 칸이 늘 같은 모양으로 들쭉날쭉하게 한다.
  static double hash(int x, int y, [int salt = 0]) {
    var h = (x * 374761393 + y * 668265263 + salt * 144269) & 0x7FFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF;
    h ^= h >> 16;
    return h / 0x80000000;
  }

  /// 반지름 [radius] 원 둘레의 [thickness] 칸 두께 고리. [tones] 는 바깥에서 안쪽 순서의 색.
  /// 두께가 색보다 많으면 마지막 색을 이어 쓴다.
  static void ring(
    PixelCanvas pc,
    double radius,
    int thickness,
    List<Color> tones, {
    int thin = 0,
    double jitter = 0,
    int salt = 0,
  }) {
    final px = pc.px;
    final cells = (radius / px).ceil() + 2;
    for (var y = -cells; y < cells; y++) {
      for (var x = -cells; x < cells; x++) {
        if (thinned(x, y, thin)) continue;
        final d = math.sqrt((x + 0.5) * (x + 0.5) + (y + 0.5) * (y + 0.5)) * px;
        final edge =
            radius + (jitter == 0 ? 0 : (hash(x, y, salt) - 0.5) * jitter);
        final depth = ((edge - d) / px).floor();
        if (depth < 0 || depth >= thickness) continue;
        pc.dot(x, y, tones[math.min(depth, tones.length - 1)]);
      }
    }
  }

  /// 반지름 [radius] 의 채운 원. 바깥 칸부터 [tones] 색으로 겹겹이 칠하고 남은 안쪽은 마지막 색.
  /// [bands] 는 바깥 색 한 겹의 두께(칸).
  static void disc(
    PixelCanvas pc,
    double radius,
    List<Color> tones, {
    int bands = 1,
    int thin = 0,
    double jitter = 0,
    int salt = 0,
    double squash = 1,
  }) {
    final px = pc.px;
    final cells = (radius / px).ceil() + 2;
    for (var y = -cells; y < cells; y++) {
      for (var x = -cells; x < cells; x++) {
        if (thinned(x, y, thin)) continue;
        final dy = (y + 0.5) / squash;
        final d = math.sqrt((x + 0.5) * (x + 0.5) + dy * dy) * px;
        final edge =
            radius + (jitter == 0 ? 0 : (hash(x, y, salt) - 0.5) * jitter);
        if (d >= edge) continue;
        final band = ((edge - d) / px / bands).floor();
        pc.dot(x, y, tones[math.min(band, tones.length - 1)]);
      }
    }
  }

  /// 원점 둘레 [inner] 에서 [outer] 사이, [start] 부터 [sweep] 라디안만큼의 띠 (초승달 칼자국).
  /// [taper] 이면 양 끝으로 갈수록 가늘어진다. [tones] 는 바깥에서 안쪽 순서.
  static void arc(
    PixelCanvas pc,
    double inner,
    double outer,
    double start,
    double sweep,
    List<Color> tones, {
    bool taper = true,
    int thin = 0,
  }) {
    final px = pc.px;
    if (sweep.abs() < 1e-3) return;
    final cells = (outer / px).ceil() + 1;
    for (var y = -cells; y <= cells; y++) {
      for (var x = -cells; x <= cells; x++) {
        if (thinned(x, y, thin)) continue;
        final cx = (x + 0.5) * px;
        final cy = (y + 0.5) * px;
        final d = math.sqrt(cx * cx + cy * cy);
        if (d > outer || d < inner * 0.6) continue;
        var a = math.atan2(cy, cx) - start;
        a = math.atan2(math.sin(a), math.cos(a));
        if (sweep < 0) a = -a;
        if (a < 0) a += math.pi * 2;
        final k = a / sweep.abs();
        if (k > 1) continue;
        // 칼날 쪽(k 가 1 에 가까운 쪽)은 두껍고 꼬리는 가늘다.
        final width = taper
            ? (outer - inner) * math.sin(k * math.pi * 0.5 + 0.08)
            : outer - inner;
        final from = outer - width;
        if (d < from) continue;
        final depth = ((outer - d) / px).floor();
        pc.dot(x, y, tones[math.min(depth, tones.length - 1)]);
      }
    }
  }

  /// 두 점을 잇는 [width] 칸 굵기의 도트 선 (꺾인 번개 · 금 · 줄).
  static void line(
    PixelCanvas pc,
    Offset from,
    Offset to,
    Color color, {
    int width = 1,
  }) {
    final px = pc.px;
    var x0 = (from.dx / px).floor();
    var y0 = (from.dy / px).floor();
    final x1 = (to.dx / px).floor();
    final y1 = (to.dy / px).floor();
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    final half = width ~/ 2;
    while (true) {
      for (var oy = -half; oy < width - half; oy++) {
        for (var ox = -half; ox < width - half; ox++) {
          pc.dot(x0 + ox, y0 + oy, color);
        }
      }
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
  }

  /// [center] 둘레의 부드러운 빛 번짐. 도트 아래에 깔아 불 · 번개가 빛나 보이게 한다
  /// (참고한 이펙트들의 공통점: 하얀 속 → 색 → 어둠으로 번지는 빛).
  static void glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double strength = 0.55,
  }) {
    if (radius <= 0 || strength <= 0) return;
    _glowPaint.colorFilter = ColorFilter.mode(
      color.withValues(alpha: strength.clamp(0, 1)),
      BlendMode.modulate,
    );
    canvas.drawImageRect(
      _glowImage,
      const Rect.fromLTWH(0, 0, 64, 64),
      Rect.fromCircle(center: center, radius: radius),
      _glowPaint,
    );
  }

  static final _glowPaint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;

  static final Image _glowImage = () {
    const size = 64.0;
    const c = Offset(size / 2, size / 2);
    final recorder = PictureRecorder();
    Canvas(recorder).drawCircle(
      c,
      size / 2,
      Paint()
        ..shader = Gradient.radial(
          c,
          size / 2,
          const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.35, 1],
        ),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    picture.dispose();
    return image;
  }();

  /// 가운데서 사방으로 뻗는 가시 광선 (폭발 · 타격 섬광). 광선마다 길이가 다르다.
  static void rays(
    PixelCanvas pc,
    int count,
    double inner,
    double outer,
    Color tip,
    Color body, {
    int salt = 0,
    double turn = 0,
  }) {
    for (var i = 0; i < count; i++) {
      final a = turn + math.pi * 2 * (i + hash(i, salt) * 0.5) / count;
      final len = inner + (outer - inner) * (0.45 + 0.55 * hash(i, salt, 7));
      final dir = Offset(math.cos(a), math.sin(a));
      line(pc, dir * inner, dir * (inner + (len - inner) * 0.6), body);
      line(pc, dir * (inner + (len - inner) * 0.6), dir * len, tip);
    }
  }

  /// 오른쪽(+x)으로 날아가는 도트 불덩이: 하얀 속 → 노랑 → 주황 머리에, 뒤로 길게 끌리며
  /// 빨강 · 검붉은색으로 식어 가는 일렁이는 꼬리. [tones] 는 뜨거운 것부터 (기본 불 색).
  static void comet(
    PixelCanvas pc,
    double head,
    double tail, {
    double time = 0,
    int salt = 0,
    List<Color> tones = FxTones.fire,
  }) {
    final px = pc.px;
    final beat = (time * 14).floor();
    // 꼬리: 머리에서 멀어질수록 가늘어지고 끝이 갈라진다.
    final x0 = (-tail / px).floor();
    for (var x = x0; x <= 0; x++) {
      final k = -(x + 0.5) * px / tail; // 0 머리 → 1 꼬리 끝
      if (k >= 1 || tail <= 0) continue;
      final half =
          head * math.pow(1 - k, 0.7) * (0.85 + 0.3 * hash(x, beat, salt));
      final rows = (half / px).ceil();
      for (var y = -rows; y < rows; y++) {
        if (k > 0.45 && hash(x, y + beat, salt + 3) < k * 0.55) continue;
        final i = 2 + (k * (tones.length - 2)).floor();
        pc.dot(x, y, tones[math.min(i, tones.length - 1)]);
      }
    }
    // 머리: 바깥 주황 → 금 → 노랑 → 하얀 속.
    final cells = (head / px).ceil() + 1;
    for (var y = -cells; y < cells; y++) {
      for (var x = -cells; x < cells; x++) {
        final d = math.sqrt((x + 0.5) * (x + 0.5) + (y + 0.5) * (y + 0.5)) * px;
        if (d > head) continue;
        final k = d / head;
        final i = k < 0.35 ? 0 : (k < 0.6 ? 1 : (k < 0.85 ? 2 : 3));
        pc.dot(x, y, tones[math.min(i, tones.length - 1)]);
      }
    }
  }

  /// [base] 색의 밝은 · 본 · 어두운 세 단계 (빛은 왼쪽 위, 그림자는 차가운 쪽).
  static List<Color> tones(Color base) => [
    Color.lerp(base, Pal.white, 0.55)!,
    base,
    Color.lerp(base, Pal.outline, 0.45)!,
  ];
}

/// 불 · 강철 · 번개 · 얼음 · 흙 이펙트에 쓰는 고정 색 단계 (Endesga 32).
abstract final class FxTones {
  /// 밝은 것부터: 노란 속, 금빛, 주황, 빨강, 검붉은.
  static const fire = [
    Color(0xFFFFFFFF),
    Pal.goldLight,
    Pal.gold,
    Color(0xFFF77622),
    Pal.red,
    Pal.redDark,
  ];

  static const steel = [Pal.white, Pal.steelLight, Pal.steel, Pal.steelDark];
  static const spark = [Pal.white, Pal.goldLight, Pal.gold];
  static const ice = [
    Pal.white,
    Color(0xFF2CE8F5),
    Color(0xFF0099DB),
    Color(0xFF124E89),
  ];
  static const earth = [
    Color(0xFFEAD4AA),
    Color(0xFFE4A672),
    Pal.leatherLight,
    Pal.leather,
    Color(0xFF3E2731),
  ];
}

/// 칸 단위로 찍은 점을 색별로 모았다가 한 번에 그리는 캔버스.
/// 그리는 순서는 색을 처음 찍은 순서다 — 뒤에 둘 색을 먼저 찍는다.
class PixelCanvas {
  PixelCanvas([this.px = PixelFx.px]);

  final double px;
  final _buckets = <Color, List<double>>{};
  static final _paint = Paint()
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = false;

  void dot(int x, int y, Color color) => (_buckets[color] ??= <double>[])
    ..add((x + 0.5) * px)
    ..add((y + 0.5) * px);

  /// 모은 점을 [canvas] 의 지금 원점 기준으로 그리고 비운다.
  void flush(Canvas canvas, {double opacity = 1}) {
    _paint.strokeWidth = px;
    for (final MapEntry(key: color, value: points) in _buckets.entries) {
      if (points.isEmpty) continue;
      _paint.color = opacity >= 1
          ? color
          : color.withValues(alpha: color.a * opacity.clamp(0, 1));
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList(points),
        _paint,
      );
    }
    _buckets.clear();
  }

  /// 여러 이펙트가 함께 쓰는 캔버스. 그리기는 한 스레드에서 차례로 일어난다.
  static final shared = PixelCanvas();

  /// 캐릭터 도트와 같은 크기(2)의 칸. 회오리 · 불덩이처럼 작고 결이 많은 이펙트에 쓴다.
  static final fine = PixelCanvas(2);
}
