import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 픽셀 이미지를 한 번만 읽어 두는 저장소. 화면마다 같은 시트를 다시 읽지 않는다.
abstract final class PixelImages {
  static final _cache = <String, Future<ui.Image>>{};

  static Future<ui.Image> load(String asset) =>
      _cache.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      });

  /// 화면에 나오기 전에 미리 읽어 둔다.
  static void preload(Iterable<String> assets) {
    for (final asset in assets) {
      unawaited(load(asset));
    }
  }
}

/// 가로로 프레임을 붙인 픽셀 스프라이트 시트에서 [start] 번째부터 [count] 장을
/// [fps] 로 돌려 그린다. 최근접 필터로 키워 픽셀이 뭉개지지 않는다.
///
/// [silhouette] 를 주면 그 색 한 가지로 칠한다 (잠긴 캐릭터 · 공개 예정 캐릭터).
/// 원본은 오른쪽을 보고 있고, [flip] 이면 왼쪽을 본다.
class PixelSprite extends StatefulWidget {
  const PixelSprite({
    super.key,
    required this.asset,
    required this.frameSize,
    this.start = 0,
    this.count = 1,
    this.fps = 7,
    this.scale = 4,
    this.flip = false,
    this.silhouette,
    this.phase = 0,
  });

  /// 전체 에셋 경로 (예: `assets/images/sprites/knight.png`).
  final String asset;
  final Size frameSize;
  final int start;
  final int count;
  final double fps;
  final double scale;
  final bool flip;
  final Color? silhouette;

  /// 같은 시트를 여럿 그릴 때 박자가 겹치지 않도록 미는 프레임 수.
  final int phase;

  @override
  State<PixelSprite> createState() => _PixelSpriteState();
}

class _PixelSpriteState extends State<PixelSprite>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  final _frame = ValueNotifier<int>(0);
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.count > 1) {
      _ticker = createTicker((elapsed) {
        final frame =
            (elapsed.inMicroseconds / 1e6 * widget.fps).floor() + widget.phase;
        _frame.value = frame % widget.count;
      })..start();
    }
  }

  @override
  void didUpdateWidget(PixelSprite old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _load();
  }

  Future<void> _load() async {
    final image = await PixelImages.load(widget.asset);
    if (mounted) setState(() => _image = image);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: widget.frameSize * widget.scale,
    painter: _SpritePainter(
      image: _image,
      frame: _frame,
      start: widget.start,
      frameSize: widget.frameSize,
      flip: widget.flip,
      silhouette: widget.silhouette,
    ),
  );
}

class _SpritePainter extends CustomPainter {
  _SpritePainter({
    required this.image,
    required this.frame,
    required this.start,
    required this.frameSize,
    required this.flip,
    required this.silhouette,
  }) : super(repaint: frame);

  final ui.Image? image;
  final ValueNotifier<int> frame;
  final int start;
  final Size frameSize;
  final bool flip;
  final Color? silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    final src = Offset(frameSize.width * (start + frame.value), 0) & frameSize;
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (silhouette case final color?) {
      paint.colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    }
    if (flip) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
    if (flip) canvas.restore();
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image ||
      old.start != start ||
      old.flip != flip ||
      old.silhouette != silhouette;
}
