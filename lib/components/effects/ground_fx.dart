import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../weapons/weapon_art.dart';
import 'pixel_fx.dart';

/// 내려찍은 자리에 갈라지는 도트 땅. 검붉은 금 속에 잿불빛이 비치다가 솎아 내며 사라진다.
class GroundCrack extends PositionComponent {
  GroundCrack({required super.position, required this.radius})
    : super(priority: 1);

  final double radius;
  static const double duration = 0.8;
  double _life = 0;
  late final List<List<Offset>> _cracks;
  static final _random = math.Random();

  @override
  Future<void> onLoad() async {
    _cracks = [
      for (var i = 0; i < 7; i++)
        _crack(math.pi * 2 * i / 7 + _random.nextDouble() * 0.5),
    ];
  }

  List<Offset> _crack(double angle) {
    final points = [Offset.zero];
    var a = angle;
    var r = 0.0;
    final end = radius * (0.6 + _random.nextDouble() * 0.4);
    while (r < end) {
      r += radius * 0.18;
      a += (_random.nextDouble() - 0.5) * 0.7;
      // 땅은 비스듬히 보이므로 세로를 눌러 납작하게.
      points.add(Offset(math.cos(a) * r, math.sin(a) * r * 0.75));
    }
    return points;
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    final grow = math.min(1.0, t / 0.12);
    final pc = PixelCanvas.fine;
    final thin = PixelFx.fade(t, from: 0.5);
    for (final crack in _cracks) {
      final n = math.max(2, (crack.length * grow).ceil());
      for (var i = 0; i < n - 1; i++) {
        PixelFx.line(
          pc,
          crack[i],
          crack[i + 1],
          const Color(0xFF3E2731),
          width: 2,
        );
      }
    }
    for (final crack in _cracks) {
      final n = math.max(2, (crack.length * grow).ceil());
      for (var i = 0; i < n - 1; i++) {
        PixelFx.line(
          pc,
          crack[i],
          crack[i + 1],
          i < 2 ? Pal.goldLight : const Color(0xFFF77622),
        );
      }
    }
    if (thin > 0) {
      // 칸을 솎아 낼 때는 캔버스를 한 번 비우고 다시 찍는 대신 전체를 흐린다.
      pc.flush(canvas, opacity: 1 - (thin / 4));
    } else {
      pc.flush(canvas);
    }
  }
}

/// 땅이 터져 솟구치는 도트 흙 분출 (대검 내려찍기 · 대지 강타).
///
/// 흙더미가 혀처럼 솟아 왕관 모양으로 바깥으로 벌어졌다가 부서져 가라앉고, 바닥에는 납작한
/// 먼지 고리가 퍼지며, 돌조각이 포물선을 그리며 튀어 떨어진다. 흙 혀는 [ringAt] 비율의
/// 둘레에서 바깥으로 기운다 — 0 에 가까우면 한 점에서 터지는 분출(내려찍기), 크면 몸 둘레를
/// 빙 둘러 솟는 흙벽(대지 강타). 빛은 왼쪽 위: 흙 혀의 왼쪽 면이 밝고 오른쪽 면이 어둡다.
class EarthBurst extends PositionComponent {
  EarthBurst({
    required super.position,
    required this.radius,
    this.count = 5,
    this.ringAt = 0.12,
    this.ember = false,
  }) : _salt = _random.nextInt(1 << 16),
       super(priority: 4);

  final double radius;

  /// 솟는 흙 혀 수.
  final int count;

  /// 흙 혀가 솟는 둘레 (반지름 비율).
  final double ringAt;

  /// 잿불이 서린 분출 (흙 끝과 속이 달아오른다).
  final bool ember;
  final int _salt;
  static const double duration = 0.7;
  static final _random = math.Random();
  double _life = 0;

  // 흙 색 단계 (Endesga 32): 밝은 면 → 그늘, 외곽, 먼지.
  static const _dirtLight = Color(0xFFEAD4AA);
  static const _dirt = Color(0xFFE4A672);
  static const _dirtShade = Pal.leatherLight;
  static const _dirtDeep = Pal.leather;
  static const _edge = Color(0xFF3E2731);
  static const _dust = Pal.steelLight;
  static const _emberCore = Color(0xFFF77622);

  /// 땅은 비스듬히 보이므로 바닥 위 거리는 세로를 이만큼 누른다.
  static const double _ground = 0.5;

  /// 돌조각이 떨어지는 중력 (월드/초²).
  static const double _gravity = 900;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    final pc = PixelCanvas.fine;
    if (ember) {
      PixelFx.glow(
        canvas,
        Offset.zero,
        radius * 0.9,
        _emberCore,
        strength: 0.5 * (1 - t),
      );
    }
    _dustRing(pc, t);
    _tongues(pc, t);
    _rocks(pc, t);
    _puffs(pc, t);
    pc.flush(canvas);
  }

  static double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();

  /// 바닥을 따라 납작하게 퍼지는 먼지 고리. 세 칸 두께, 퍼질수록 솎아 낸다.
  void _dustRing(PixelCanvas pc, double t) {
    final px = pc.px;
    final r = radius * (0.3 + 0.85 * _easeOut(math.min(1, t / 0.5)));
    final thin = PixelFx.fade(t, from: 0.25);
    final cells = (r / px).ceil() + 2;
    final rows = (cells * _ground).ceil() + 1;
    for (var y = -rows; y <= rows; y++) {
      for (var x = -cells; x <= cells; x++) {
        if (PixelFx.thinned(x, y, thin)) continue;
        final dx = (x + 0.5) * px;
        final dy = (y + 0.5) * px / _ground;
        final depth = (r - math.sqrt(dx * dx + dy * dy)) / px;
        if (depth < 0 || depth >= 3) continue;
        // 바깥 칸은 밝은 먼지, 안쪽은 흙빛. 앞쪽(아래)은 그늘이 진다.
        pc.dot(
          x,
          y,
          depth < 1
              ? _dust
              : y > 0
              ? _dirtShade
              : _dirt,
        );
      }
    }
  }

  /// 솟구치는 흙: 밑동의 흙무더기와 거기서 뻗는 굵은 흙 혀들을 한 덩어리로 모아 그린다.
  /// 처음엔 혀들이 겹쳐 한 기둥으로 솟고, 시간이 지나며 왕관처럼 바깥으로 벌어진다.
  /// 외곽선은 덩어리 바깥 둘레에만 둘러 막대 다발처럼 갈라져 보이지 않게 한다.
  void _tongues(PixelCanvas pc, double t) {
    final px = pc.px;
    // 0.12초 만에 솟고, 잠깐 버티다 0.4 부터 무너져 가라앉는다.
    final rise = _easeOut(math.min(1, t / 0.17));
    final sink = t > 0.4 ? math.min(1.0, (t - 0.4) / 0.45) : 0.0;
    final thin = PixelFx.fade(t, from: 0.55);
    final open = 0.15 + 0.75 * _easeOut(t);
    // 칸 → (높이 비율 s, 혀 안에서 왼쪽부터의 위치 across). 뒤(위쪽) 혀부터 써서 앞 혀가 덮는다.
    final cells = <int, (double, double)>{};
    int key(int x, int y) => (x + 2048) * 4096 + (y + 2048);

    // 흙무더기: 바닥에 낮게 솟은 둥근 언덕. 아래는 땅에 묻힌 듯 두 칸만 내려온다.
    final moundW = radius * (ringAt + 0.22);
    final moundH = radius * 0.12 * rise * (1 - sink * 0.7);
    if (ringAt < 0.5) {
      for (var x = (-moundW / px).floor(); x <= (moundW / px).ceil(); x++) {
        final k = ((x + 0.5) * px / moundW).abs();
        if (k >= 1) continue;
        final top = moundH * math.pow(1 - k * k, 0.7);
        final bottom = (moundW * _ground * 0.35 * math.sqrt(1 - k * k) / px)
            .ceil();
        for (var y = -(top / px).ceil(); y <= bottom; y++) {
          cells[key(x, y)] = (0.1, (x * px + moundW) / (moundW * 2));
        }
      }
    }

    final tongues = [
      for (var i = 0; i < count; i++)
        (
          math.pi * 2 * (i + PixelFx.hash(i, 1, _salt) * 0.5) / count,
          0.75 + 0.45 * PixelFx.hash(i, 2, _salt),
        ),
    ]..sort((a, b) => math.sin(a.$1).compareTo(math.sin(b.$1)));
    for (final (a, size) in tongues) {
      final out = Offset(math.cos(a), math.sin(a) * _ground);
      final base = out * (radius * ringAt);
      // 뒤쪽 혀는 키가 크고 앞쪽 혀는 낮아 가운데가 솟은 왕관이 된다.
      final height =
          radius *
          (ringAt < 0.5 ? 0.7 : 0.45) *
          size *
          (0.85 - 0.3 * math.sin(a)) *
          rise *
          (1 - sink);
      final width = radius * (ringAt < 0.5 ? 0.2 : 0.12) * size;
      if (height < px) continue;
      // 한 줄에 세 번씩 찍어, 많이 기운 끝도 줄 사이가 끊기지 않게 한다.
      final steps = (height / px * 3).ceil();
      for (var k = 0; k <= steps; k++) {
        final s = k / steps;
        final c = base + out * (height * open * s * s) + Offset(0, -height * s);
        final half = width * math.pow(1 - s, 0.6) + px * 0.5;
        final y = (c.dy / px).floor();
        final x0 = ((c.dx - half) / px).floor();
        final x1 = ((c.dx + half) / px).floor();
        for (var x = x0; x <= x1; x++) {
          cells[key(x, y)] = (s, (x - x0) / math.max(1, x1 - x0));
        }
      }
    }

    for (final MapEntry(key: k, value: (s, across)) in cells.entries) {
      final x = k ~/ 4096 - 2048;
      final y = k % 4096 - 2048;
      if (PixelFx.thinned(x, y, thin)) continue;
      // 무너지는 동안 위쪽부터 칸이 떨어져 나간다.
      if (sink > 0 && PixelFx.hash(x, y, _salt) < sink * (s + 0.2) * 1.4) {
        continue;
      }
      final edge =
          !cells.containsKey(key(x - 1, y)) ||
          !cells.containsKey(key(x + 1, y)) ||
          !cells.containsKey(key(x, y - 1)) ||
          !cells.containsKey(key(x, y + 1));
      pc.dot(x, y, edge ? _edge : _earthColor(x, y, s, across));
    }
  }

  /// 흙 혀 한 칸의 색. 왼쪽 위가 밝고 오른쪽 아래가 어둡다. 잿불이면 끝이 금빛으로 달아오르고
  /// 가운데 갈라진 틈으로 불빛이 비친다.
  Color _earthColor(int x, int y, double s, double across) {
    if (ember) {
      if (s > 0.8) return Pal.goldLight;
      if (s > 0.62) return Pal.gold;
      if ((across - 0.5).abs() < 0.12 && PixelFx.hash(x, y, _salt + 1) < 0.6) {
        return _emberCore;
      }
    } else if (s > 0.84) {
      return _dirtLight;
    }
    if (across < 0.3) return _dirtLight;
    if (across < 0.62) return _dirt;
    return s < 0.25 ? _dirtDeep : _dirtShade;
  }

  /// 포물선으로 튀었다가 떨어지는 돌조각.
  void _rocks(PixelCanvas pc, double t) {
    final px = pc.px;
    final time = t * duration;
    final thin = PixelFx.fade(t, from: 0.7);
    final n = count + 4;
    for (var i = 0; i < n; i++) {
      final a = math.pi * 2 * (i + PixelFx.hash(i, 4, _salt)) / n;
      final speed = radius * (1.1 + 0.9 * PixelFx.hash(i, 5, _salt));
      final up = 170 + 120 * PixelFx.hash(i, 6, _salt);
      final airborne = math.min(time, 2 * up / _gravity);
      final dist = radius * ringAt + speed * airborne;
      final z = math.max(
        0.0,
        up * airborne - _gravity * airborne * airborne / 2,
      );
      final x = (math.cos(a) * dist / px).floor();
      final y = ((math.sin(a) * dist * _ground - z) / px).floor();
      if (PixelFx.thinned(x, y, thin)) continue;
      // 2x2 돌 (큰 것은 3x2): 왼쪽 위는 밝고 오른쪽 아래는 외곽.
      pc
        ..dot(x, y, ember && i.isEven ? _emberCore : _dirt)
        ..dot(x + 1, y, _dirtShade)
        ..dot(x, y + 1, _dirtShade)
        ..dot(x + 1, y + 1, _edge);
      if (PixelFx.hash(i, 7, _salt) > 0.5) {
        pc
          ..dot(x - 1, y, _dirtLight)
          ..dot(x - 1, y + 1, _dirtDeep);
      }
    }
  }

  /// 흙 밑동에서 바닥을 따라 밀려 나가는 뭉게 먼지. 동그라미 서너 개를 겹친 덩어리로,
  /// 윗면은 밝은 먼지색, 아랫줄은 흙빛 그늘이다.
  void _puffs(PixelCanvas pc, double t) {
    if (t < 0.06) return;
    final px = pc.px;
    final grow = _easeOut(math.min(1, (t - 0.06) / 0.45));
    final thin = PixelFx.fade(t, from: 0.3);
    final n = math.max(4, count - 1);
    for (var i = 0; i < n; i++) {
      final a = math.pi * 2 * (i + 0.5 + PixelFx.hash(i, 8, _salt) * 0.5) / n;
      // 앞쪽(아래) 먼지만 보이면 무겁다: 뒤쪽은 조금 더 멀리, 덜 피어오른다.
      final dist =
          radius * (ringAt + 0.3 + 0.45 * grow * (0.7 + 0.3 * math.cos(a)));
      final cx = math.cos(a) * dist;
      final cy = math.sin(a) * dist * _ground - radius * 0.05 * grow;
      final r = radius * (0.05 + 0.05 * grow);
      for (var j = 0; j < 3; j++) {
        final ox = (j - 1) * r * 0.9;
        final oy = j == 1 ? -r * 0.6 : 0.0;
        final rr =
            r *
            (j == 1 ? 1.1 : 0.8) *
            (0.8 + 0.4 * PixelFx.hash(i, 9 + j, _salt));
        final gx = ((cx + ox) / px).floor();
        final gy = ((cy + oy) / px).floor();
        final cells = (rr / px).ceil();
        for (var y = -cells; y <= cells; y++) {
          for (var x = -cells; x <= cells; x++) {
            final d = math.sqrt((x * x + y * y).toDouble()) * px;
            if (d > rr) continue;
            if (PixelFx.thinned(gx + x, gy + y, thin)) continue;
            pc.dot(
              gx + x,
              gy + y,
              y > cells * 0.4
                  ? _dirt
                  : x < 0 && y < 0
                  ? _dust
                  : _dirtLight,
            );
          }
        }
      }
    }
  }
}
