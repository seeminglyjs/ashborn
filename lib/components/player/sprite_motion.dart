import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// 플레이어 스프라이트에 얹는 코드 연출: 숨쉬기, 달리기 통통 튐, 기울기, 방향 전환 접힘, 피격 찌그러짐.
///
/// 프레임 그림은 그대로 두고 크기 · 각도 · 높이만 바꾼다. 기울기와 찌그러짐은 용수철로 따라가게 해서
/// 멈추거나 방향을 바꿀 때 살짝 넘쳤다 돌아오는 관성이 생긴다.
/// 스프라이트는 바닥 가운데 기준(Anchor.bottomCenter)이어야 발이 땅에 붙은 채로 늘었다 줄었다 한다.
class SpriteMotion {
  SpriteMotion(this.base, {this.pixel = 1});

  /// 연출이 없을 때 스프라이트의 위치 (발 위치).
  final Vector2 base;

  /// 스프라이트 도트 한 칸의 크기. 뜨는 높이를 이 단위로 끊어 도트가 반 칸씩 번지지 않게 한다.
  final double pixel;

  // 숨쉬기: 서 있을 때 세로로 아주 조금 부풀었다 가라앉는다.
  static const breathPeriod = 1.8;
  static const breathAmount = 0.025;

  // 달리기: 한 걸음마다 뜨고(늘어나고) 디딜 때 눌린다. 걸음은 달리기 프레임 2장마다 한 번.
  // 뜨는 높이는 도트 칸 수 (실제 높이는 [pixel] 을 곱한다).
  static const hopHeight = 1.4;
  static const stepSquash = 0.06;

  // 가는 쪽으로 기우는 정도 (라디안). 멈추면 반대로 살짝 넘쳤다 돌아온다.
  static const leanMax = 0.09;

  // 방향을 바꿀 때 종이를 뒤집듯 가로로 접혔다 펴지는 시간과 깊이.
  static const turnTime = 0.12;
  static const turnFold = 0.45;

  // 출발 · 정지 · 피격 때 용수철에 주는 충격 (세로 늘어남 속도).
  static const startKick = 1.2;
  static const stopKick = -1.6;
  static const hitKick = -3.2;

  final _lean = _Spring(stiffness: 260, damping: 14);
  final _squash = _Spring(stiffness: 420, damping: 16);

  double _time = 0;
  double _turn = 0;
  bool _wasMoving = false;
  bool _wasHit = false;
  bool? _facingLeft;
  int _lastStep = -1;

  /// 지금 떠 있는 높이 (그림자를 줄이는 데 쓴다).
  double hop = 0;

  // 도약 (대검 내려찍기): 남은 시간 · 전체 시간 · 최고 높이.
  double _leapLeft = 0;
  double _leapTime = 0;
  double _leapHeight = 0;

  /// 도약해 있는 높이 (월드). 내려찍기 칼이 몸을 따라 올라가는 데 쓴다.
  double get leapLift => _leapLeft > 0 ? _leapCurve * _leapHeight : 0;

  /// 뛰어올라 [time] 초 뒤에 착지한다. 빨리 솟았다가 정점에서 잠깐 머물고 세게 떨어진다.
  void leap(double time, double height) {
    _leapLeft = _leapTime = time;
    _leapHeight = height;
    _squash.velocity += startKick * 1.6;
  }

  double get _leapCurve {
    final p = 1 - _leapLeft / _leapTime;
    if (p < 0.55) return 1 - math.pow(1 - p / 0.55, 2).toDouble();
    final fall = (p - 0.55) / 0.45;
    return 1 - fall * fall * fall;
  }

  /// 한 프레임 연출을 계산해 [sprite] 에 입힌다.
  /// [move] 는 입력 방향 (길이 0..1), [facingLeft] 는 바라보는 쪽, [hit] 은 피격 자세 중인지.
  /// 발을 디딘 순간이면 true 를 돌려준다 (먼지를 일으키는 데 쓴다).
  bool apply(
    SpriteAnimationGroupComponent<Object?> sprite,
    double dt, {
    required Vector2 move,
    required bool facingLeft,
    required bool hit,
    required bool running,
    double frameTime = 0.1,
  }) {
    _time += dt;
    final pace = math.min(1.0, move.length);
    final moving = running && pace > 0.05;

    if (_facingLeft != null && _facingLeft != facingLeft) _turn = turnTime;
    _facingLeft = facingLeft;
    if (_turn > 0) _turn = math.max(0, _turn - dt);

    if (moving && !_wasMoving) _squash.velocity += startKick;
    if (!moving && _wasMoving) _squash.velocity += stopKick;
    if (hit && !_wasHit) _squash.velocity += hitKick;
    _wasMoving = moving;
    _wasHit = hit;

    _lean.update(
      dt,
      moving ? move.x / math.max(pace, 1e-6) * leanMax * pace : 0,
    );
    _squash.update(dt, 0);

    // 걸음 위상: 달리기 프레임과 맞춘다 (프레임 2장 = 한 걸음).
    var stepped = false;
    var stretch = 0.0;
    hop = 0;
    if (moving) {
      final ticker = sprite.animationTicker;
      final frames = ticker == null
          ? _time / frameTime
          : ticker.currentIndex + math.min(1.0, ticker.clock / frameTime);
      final phase = frames / 2;
      final swing = math.sin(phase * math.pi).abs();
      hop = (hopHeight * swing * pace).roundToDouble() * pixel;
      // 공중(swing 1)에서 늘고, 디딜 때(swing 0)는 눌린다.
      stretch = stepSquash * (swing * 2 - 1) * pace;
      final step = phase.floor();
      if (step != _lastStep) {
        stepped = _lastStep >= 0;
        _lastStep = step;
      }
    } else {
      _lastStep = -1;
      stretch = breathAmount * math.sin(_time * math.pi * 2 / breathPeriod);
    }

    if (_leapLeft > 0) {
      _leapLeft -= dt;
      if (_leapLeft <= 0) {
        // 착지: 세게 눌렸다가 튀어 오른다.
        _squash.velocity += hitKick * 1.4;
      } else {
        final lift = (_leapCurve * _leapHeight / pixel).roundToDouble() * pixel;
        hop = math.max(hop, lift);
        // 오를 때는 길게 늘고, 떨어질 때는 웅크린다.
        stretch += (1 - _leapLeft / _leapTime) < 0.55 ? 0.1 : -0.06;
      }
    }

    final sy = 1 + stretch + _squash.value * 0.08;
    // 세로로 늘면 가로는 줄여 부피를 비슷하게 둔다.
    var sx = 1 - (sy - 1) * 0.6;
    if (_turn > 0) {
      sx *= 1 - turnFold * math.sin(_turn / turnTime * math.pi);
    }
    sprite
      ..scale.setValues(facingLeft ? -sx : sx, sy)
      ..angle = _lean.value
      ..position.setValues(base.x, base.y - hop);
    return stepped;
  }
}

/// 잘 감쇠되는 용수철: [update] 로 목표값을 따라가며 살짝 넘쳤다 돌아온다.
class _Spring {
  _Spring({required this.stiffness, required this.damping});

  final double stiffness;
  final double damping;
  double value = 0;
  double velocity = 0;

  void update(double dt, double target) {
    // 프레임이 길어도 튀지 않도록 잘게 나눠 적분한다.
    var left = dt;
    while (left > 0) {
      final h = math.min(left, 1 / 120);
      velocity += (stiffness * (target - value) - damping * velocity) * h;
      value += velocity * h;
      left -= h;
    }
  }
}

/// 발을 디딜 때 이는 작은 잿빛 먼지. 뒤쪽으로 퍼지며 사라진다.
class DustPuff extends PositionComponent {
  DustPuff({required super.position, required this.drift, this.pixel = 2})
    : super(priority: 5);

  /// 먼지가 흘러가는 방향과 빠르기 (보통 달리는 반대쪽).
  final Vector2 drift;

  /// 도트 한 칸의 크기 (스프라이트 확대 배율에 맞춘다).
  final double pixel;

  static const duration = 0.32;
  static const _color = Color(0xFFC0CBDC); // Endesga 32 의 밝은 잿빛
  static final _random = math.Random();

  late final List<Offset> _bits = [
    for (var i = 0; i < 3; i++)
      Offset(
        (_random.nextDouble() - 0.5) * 6 * pixel,
        -_random.nextDouble() * 2 * pixel,
      ),
  ];
  double _life = 0;
  final _paint = Paint();

  @override
  void update(double dt) {
    _life += dt;
    position.addScaled(drift, dt);
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    _paint.color = _color.withValues(alpha: 0.55 * (1 - t));
    // 처음엔 2칸, 사라질 때쯤 1칸. 칸 단위로만 바꿔 도트 크기를 지킨다.
    final side = (t < 0.5 ? 2 : 1) * pixel;
    for (final b in _bits) {
      final rise = -t * 3 * pixel;
      canvas.drawRect(
        Rect.fromLTWH(
          (b.dx / pixel).roundToDouble() * pixel,
          ((b.dy + rise) / pixel).roundToDouble() * pixel,
          side,
          side,
        ),
        _paint,
      );
    }
  }
}
