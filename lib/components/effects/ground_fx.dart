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

/// 땅에서 솟아오르는 도트 바위 가시 (대검 내려찍기 · 대지 강타).
/// 둘레에 비스듬히 솟았다가 가라앉으며 부서진다. 왼쪽 면은 밝고 오른쪽 면은 어둡다.
class EarthSpikes extends PositionComponent {
  EarthSpikes({
    required super.position,
    required this.radius,
    this.count = 9,
    this.ember = false,
  }) : _salt = _random.nextInt(1 << 16),
       super(priority: 4);

  final double radius;
  final int count;

  /// 잿불이 서린 가시 (끝이 달아오른다).
  final bool ember;
  final int _salt;
  static const double duration = 0.55;
  static final _random = math.Random();
  double _life = 0;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    final pc = PixelCanvas.fine;
    final px = pc.px;
    // 빠르게 솟고(0.12초) 버티다 가라앉는다.
    final rise = t < 0.2 ? 1 - math.pow(1 - t / 0.2, 3).toDouble() : 1.0;
    final sink = t > 0.6 ? (t - 0.6) / 0.4 : 0.0;
    final thin = PixelFx.fade(t, from: 0.7);
    // 아래쪽(앞) 가시가 위쪽(뒤) 가시를 덮도록 위에서부터 그린다.
    final spikes = [
      for (var i = 0; i < count; i++)
        (
          math.pi * 2 * (i + PixelFx.hash(i, 1, _salt) * 0.6) / count,
          0.55 + 0.45 * PixelFx.hash(i, 2, _salt),
          0.6 + 0.5 * PixelFx.hash(i, 3, _salt),
        ),
    ]..sort((a, b) => math.sin(a.$1).compareTo(math.sin(b.$1)));
    for (final (a, dist, size) in spikes) {
      final bx = (math.cos(a) * radius * dist / px).round();
      final by = (math.sin(a) * radius * dist * 0.7 / px).round();
      final h = (radius * 0.42 * size * rise * (1 - sink) / px).round();
      final w = math.max(2, (radius * 0.16 * size / px).round());
      for (var y = 0; y < h; y++) {
        // 끝으로 갈수록 좁아지는 삼각 가시.
        final half = (w * (1 - y / h)).ceil();
        for (var x = -half; x <= half; x++) {
          final cx = bx + x;
          final cy = by - y;
          if (PixelFx.thinned(cx, cy, thin)) continue;
          final Color color;
          if (y >= h - 2) {
            color = ember ? Pal.goldLight : const Color(0xFFEAD4AA);
          } else if (x == -half) {
            color = const Color(0xFF3E2731);
          } else if (x < 0) {
            color = const Color(0xFFE4A672);
          } else if (x == half) {
            color = const Color(0xFF3E2731);
          } else {
            color = ember && y > h * 0.6
                ? const Color(0xFFF77622)
                : Pal.leatherLight;
          }
          pc.dot(cx, cy, color);
        }
      }
    }
    pc.flush(canvas);
  }
}
