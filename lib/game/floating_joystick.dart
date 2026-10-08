import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

/// 화면 어디든 누른 곳에 나타나는 이동 조이스틱.
/// 손을 떼면 왼쪽 아래 기본 자리로 돌아가 흐리게 보인다.
class FloatingJoystick extends PositionComponent with DragCallbacks {
  FloatingJoystick() : super(priority: -1);

  /// 바탕 원 반지름이자 손잡이가 움직일 수 있는 거리.
  final double knobRadius = 60;
  static const double _knobSize = 24;

  /// 기본 자리의 화면 왼쪽 · 아래 여백.
  static const double _margin = 48;

  static final _baseIdle = Paint()..color = const Color(0x1AFFFFFF);
  static final _baseActive = Paint()..color = const Color(0x33FFFFFF);
  static final _knobIdle = Paint()..color = const Color(0x66FF6B35);
  static final _knobActive = Paint()..color = const Color(0xCCFF6B35);

  /// 바탕 원 중심에서 손잡이까지.
  final delta = Vector2.zero();

  /// 바탕 원 중심. 누르는 동안은 처음 누른 곳이다.
  final origin = Vector2.zero();

  int? _pointer;

  bool get isHeld => _pointer != null;

  /// 길이가 0에서 1인 이동 방향.
  Vector2 get relativeDelta => delta / knobRadius;

  Vector2 get _rest =>
      Vector2(_margin + knobRadius, size.y - _margin - knobRadius);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    if (!isHeld) origin.setFrom(_rest);
  }

  /// [at] 에 조이스틱을 놓고 잡는다.
  void hold(Vector2 at) {
    origin.setFrom(at);
    delta.setZero();
  }

  /// 손가락이 [to] 로 움직였다.
  void moveTo(Vector2 to) {
    delta
      ..setFrom(to)
      ..sub(origin);
    if (delta.length > knobRadius) delta.scaleTo(knobRadius);
  }

  /// 손을 뗐다.
  void release() {
    _pointer = null;
    delta.setZero();
    origin.setFrom(_rest);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // 두 번째 손가락은 무시한다.
    if (isHeld) return;
    _pointer = event.pointerId;
    hold(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId == _pointer) moveTo(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId == _pointer) release();
  }

  @override
  void render(Canvas canvas) {
    final center = origin.toOffset();
    canvas
      ..drawCircle(center, knobRadius, isHeld ? _baseActive : _baseIdle)
      ..drawCircle(
        center + delta.toOffset(),
        _knobSize,
        isHeld ? _knobActive : _knobIdle,
      );
  }
}
