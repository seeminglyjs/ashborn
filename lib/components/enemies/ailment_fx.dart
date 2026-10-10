import 'dart:math' as math;
import 'dart:ui';

import 'ailments.dart';

/// 상태이상을 적 몸 위에 그린다. [body] 는 적 스프라이트가 차지하는 사각형 (적 기준 좌표),
/// [time] 은 흔들림 · 입자 위치를 정하는 시계.
///
/// 적이 수백이라 입자를 컴포넌트로 두지 않고, 시간으로 위치를 계산해 작은 사각형으로 그린다
/// (픽셀 그림체에 맞춘다).
void paintAilments(Canvas canvas, Ailments a, Rect body, double time) {
  if (a.ignited) _ignite(canvas, body, time);
  if (a.poisoned) _poison(canvas, body, time);
  if (a.bleeding) _bleed(canvas, body, time);
  if (a.frozen) {
    _ice(canvas, body);
  } else if (a.chilled) {
    _frost(canvas, body, time);
  }
  if (a.stunned) _crackle(canvas, body, time);
}

final _paint = Paint();

void _px(Canvas canvas, double x, double y, double size, Color color) {
  _paint.color = color;
  canvas.drawRect(
    Rect.fromLTWH(x - size / 2, y - size / 2, size, size),
    _paint,
  );
}

/// 0 이상 1 미만의 결정적 난수 (같은 [i] 면 같은 값).
double _hash(int i) {
  final v = math.sin(i * 12.9898) * 43758.5453;
  return v - v.floorToDouble();
}

/// 입자 크기 배율. 몸이 클수록 입자도 크다 (작은 졸개에서도 보이도록 최소 1.5).
double _unit(Rect body) => (body.height / 14).clamp(1.5, 4.0);

/// 점화: 몸 아래쪽에서 머리 위까지 피어올라 노랑 → 주황 → 빨강으로 식으며 사라지는 불꽃.
void _ignite(Canvas canvas, Rect body, double time) {
  final u = _unit(body);
  _paint.color = const Color(0x40FF6A1A);
  canvas.drawOval(body.inflate(u), _paint);
  const count = 9;
  for (var i = 0; i < count; i++) {
    final phase = (time * 1.6 + i / count) % 1;
    final x =
        body.left +
        body.width * (0.1 + 0.8 * _hash(i)) +
        math.sin(time * 9 + i) * u;
    final y = body.bottom - body.height * (0.1 + 1.2 * phase);
    final size = u * (1.2 + 2.6 * (1 - phase));
    final color = phase < 0.3
        ? const Color(0xFFFFE27A)
        : phase < 0.65
        ? const Color(0xFFFF8A2A)
        : const Color(0xFFD8361E);
    _px(canvas, x, y, size, color.withValues(alpha: 1 - phase * 0.7));
  }
}

/// 중독: 머리 위로 올라가며 터지는 초록 거품과, 몸에서 떨어지는 독 방울.
void _poison(Canvas canvas, Rect body, double time) {
  final u = _unit(body);
  for (var i = 0; i < 4; i++) {
    final phase = (time * 0.9 + i / 4) % 1;
    final x =
        body.left + body.width * (0.15 + 0.23 * i) + math.sin(time * 5 + i) * u;
    final y = body.top + body.height * 0.3 - phase * body.height * 0.6;
    final alpha = 1 - phase;
    final size = u * (2.4 - phase);
    _px(canvas, x, y, size, const Color(0xFF2F7A22).withValues(alpha: alpha));
    _px(
      canvas,
      x - size * 0.15,
      y - size * 0.15,
      size * 0.5,
      const Color(0xFFC8FF8A).withValues(alpha: alpha),
    );
  }
  final drip = (time * 1.1) % 1;
  _px(
    canvas,
    body.left + body.width * 0.6,
    body.top + body.height * (0.5 + 0.5 * drip),
    u * 1.4,
    const Color(0xFF6BD04A).withValues(alpha: 1 - drip * 0.5),
  );
}

/// 출혈: 몸에서 조금씩 떨어지는 핏방울과 바닥에 번지는 핏자국.
void _bleed(Canvas canvas, Rect body, double time) {
  final u = _unit(body);
  for (var i = 0; i < 3; i++) {
    final phase = (time * 1.3 + i / 3) % 1;
    final x = body.left + body.width * (0.25 + 0.25 * i);
    final y = body.top + body.height * 0.35 + phase * body.height * 0.65;
    final alpha = 1 - phase * 0.3;
    _paint.color = const Color(0xFF5A0A10).withValues(alpha: alpha);
    canvas.drawRect(Rect.fromLTWH(x - u, y - u * 1.5, u * 2, u * 2.6), _paint);
    _paint.color = const Color(0xFFE0202E).withValues(alpha: alpha);
    canvas.drawRect(
      Rect.fromLTWH(x - u * 0.6, y - u, u * 1.2, u * 1.8),
      _paint,
    );
    // 바닥에 닿으면 작게 튄다.
    if (phase > 0.85) {
      _px(canvas, x - u * 2, body.bottom, u, const Color(0xFFB0141E));
      _px(canvas, x + u * 2, body.bottom, u, const Color(0xFFB0141E));
    }
  }
  _paint.color = const Color(0x66A0101A);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(body.center.dx, body.bottom),
      width: body.width * 0.7,
      height: u * 2,
    ),
    _paint,
  );
}

/// 냉각: 몸 둘레에서 반짝이는 서리 조각.
void _frost(Canvas canvas, Rect body, double time) {
  for (var i = 0; i < 4; i++) {
    final twinkle = math.sin(time * 6 + i * 1.9);
    if (twinkle < 0) continue;
    final u = _unit(body);
    final x = body.left + body.width * _hash(i + 11);
    final y = body.top + body.height * _hash(i + 23);
    final c = const Color(0xFFE6F8FF).withValues(alpha: twinkle);
    _px(canvas, x, y, u * 1.4, c);
    _px(canvas, x - u * 1.6, y, u * 0.8, c);
    _px(canvas, x + u * 1.6, y, u * 0.8, c);
    _px(canvas, x, y - u * 1.6, u * 0.8, c);
    _px(canvas, x, y + u * 1.6, u * 0.8, c);
  }
}

final _iceFill = Paint()..color = const Color(0x7094DCF5);
final _iceShade = Paint()..color = const Color(0x664A9CC8);
final _iceEdge = Paint()
  ..color = const Color(0xDDEFFBFF)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5;
final _iceShine = Paint()..color = const Color(0xCCFFFFFF);

/// 동결: 몸 크기에 맞춘 얼음 덩어리. 아래 오른쪽은 어둡게, 왼쪽 위에는 빛 줄기.
void _ice(Canvas canvas, Rect body) {
  final r = body.inflate(math.max(3, body.shortestSide * 0.08));
  final cut = r.shortestSide * 0.18;
  final block = Path()
    ..moveTo(r.left + cut, r.top)
    ..lineTo(r.right - cut * 0.5, r.top)
    ..lineTo(r.right, r.top + cut)
    ..lineTo(r.right, r.bottom - cut * 0.5)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut * 0.5, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..lineTo(r.left, r.top + cut * 0.5)
    ..close();
  canvas.drawPath(block, _iceFill);
  canvas.drawPath(
    Path()
      ..moveTo(r.right, r.top + r.height * 0.45)
      ..lineTo(r.right, r.bottom - cut * 0.5)
      ..lineTo(r.right - cut, r.bottom)
      ..lineTo(r.left + r.width * 0.35, r.bottom)
      ..close(),
    _iceShade,
  );
  canvas.drawPath(block, _iceEdge);
  final s = math.max(2.0, r.shortestSide * 0.06);
  for (var i = 0; i < 4; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        r.left + cut * 0.6 + i * s,
        r.top + cut * 0.9 + i * s * 1.6,
        s,
        s * 1.6,
      ),
      _iceShine,
    );
  }
}

final _arc = Paint()
  ..color = const Color(0xFFFFF27A)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5;
final _arcGlow = Paint()
  ..color = const Color(0x66FFE45C)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 4;

/// 감전: 몸을 타고 튀는 전기 줄기. 순간마다 모양이 바뀐다.
void _crackle(Canvas canvas, Rect body, double time) {
  final seed = (time * 24).floor();
  for (var k = 0; k < 2; k++) {
    final path = Path();
    final y0 = body.top + body.height * _hash(seed * 7 + k);
    path.moveTo(body.left - 2, y0);
    for (var i = 1; i <= 4; i++) {
      path.lineTo(
        body.left - 2 + (body.width + 4) * i / 4,
        body.top + body.height * _hash(seed * 13 + k * 5 + i),
      );
    }
    canvas
      ..drawPath(path, _arcGlow)
      ..drawPath(path, _arc);
  }
}
