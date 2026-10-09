import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

/// 화면 어디든 누른 곳에 나타나는 이동 조이스틱.
/// 손을 떼면 왼쪽 아래 기본 자리로 돌아가 흐리게 보인다.
///
/// 감도: 손잡이가 [deadZone] 안에서 떨리는 건 무시하고, 바탕 반지름의
/// [fullSpeedRatio] 만큼만 밀어도 최대 속도가 난다. 손가락이 바탕 밖으로 나가면
/// 바탕 중심이 손가락을 따라와서, 반대로 끌면 곧바로 방향이 바뀐다.
class FloatingJoystick extends PositionComponent with DragCallbacks {
  FloatingJoystick() : super(priority: -1);

  /// 바탕 원 반지름이자 손잡이가 움직일 수 있는 거리.
  final double knobRadius = 42;
  static const double _knobSize = 15;

  /// 이보다 짧게 민 건 손 떨림으로 보고 멈춰 있는다.
  static const double deadZone = 4;

  /// 바탕 반지름의 이 비율만큼 밀면 최대 속도.
  static const double fullSpeedRatio = 0.65;

  /// 기본 자리의 화면 왼쪽 · 아래 여백.
  static const double _margin = 40;

  static final _baseIdle = Paint()..color = const Color(0x0DFFFFFF);
  static final _baseActive = Paint()..color = const Color(0x1AFFFFFF);
  static final _ringIdle = Paint()
    ..color = const Color(0x1FFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _ringActive = Paint()
    ..color = const Color(0x40FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _knobIdle = Paint()..color = const Color(0x40F3E3C3);
  static final _knobActive = Paint()..color = const Color(0x99F3E3C3);

  /// 바탕 원 중심에서 손잡이까지. 길이는 [knobRadius] 를 넘지 않는다.
  final delta = Vector2.zero();

  /// 바탕 원 중심. 누르면 누른 곳이고, 손가락이 바탕 밖으로 나가면 따라간다.
  final origin = Vector2.zero();

  int? _pointer;

  bool get isHeld => _pointer != null;

  /// 길이가 0에서 1인 이동 방향. [deadZone] 이하는 0, 바탕 반지름의
  /// [fullSpeedRatio] 이상은 1이고 그 사이는 고르게 오른다.
  Vector2 get relativeDelta {
    final distance = delta.length;
    if (distance <= deadZone) return Vector2.zero();
    final full = knobRadius * fullSpeedRatio;
    final strength = ((distance - deadZone) / (full - deadZone)).clamp(
      0.0,
      1.0,
    );
    return delta.normalized()..scale(strength);
  }

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

  /// 손가락이 [to] 로 움직였다. 바탕 밖이면 바탕을 손가락 쪽으로 끌고 온다.
  void moveTo(Vector2 to) {
    delta
      ..setFrom(to)
      ..sub(origin);
    if (delta.length > knobRadius) {
      delta.scaleTo(knobRadius);
      origin
        ..setFrom(to)
        ..sub(delta);
    }
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
    // Flame 의 localEndPosition 은 지금 손가락 위치에 이번 이동량을 한 번 더 더한
    // 값이라 손가락보다 앞서 나간다. 지금 손가락 위치는 localStartPosition 이다.
    if (event.pointerId == _pointer) moveTo(event.localStartPosition);
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
      ..drawCircle(center, knobRadius, isHeld ? _ringActive : _ringIdle)
      ..drawCircle(
        center + delta.toOffset(),
        _knobSize,
        isHeld ? _knobActive : _knobIdle,
      );
  }
}
