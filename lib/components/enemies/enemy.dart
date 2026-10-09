import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show protected;

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/enemies.dart';
import '../../data/monster_sprites.dart';
import '../../game/world/run_world.dart';
import '../effects/sparks.dart';
import 'ailments.dart';
import 'death_puff.dart';

/// 재의 무리(Hollow). 기본은 플레이어를 향해 곧장 걸어온다.
/// 지역에 따라 색, 속도, 닿았을 때 주는 피해의 속성이 다르고,
/// 졸개 종류([kind])마다 움직이고 공격하는 방식이 다르다 (minions.dart 의 하위 클래스).
///
/// [sprite] 가 있으면 게임이 읽어 둔 프레임으로 그리고, 아직 못 읽었거나 없으면 원으로 그린다.
class Enemy extends CircleComponent with HasWorldReference<RunWorld> {
  Enemy({
    required super.position,
    required this.maxHp,
    this.contactDamage = Balance.enemyContactDamage,
    this.damageType = DamageType.physical,
    this.speed = Balance.enemySpeed,
    this.color = const Color(0xFF8A7F7A),
    this.sprite,
    this.kind,
    super.radius = Balance.enemyRadius,
    super.priority,
  }) : hp = maxHp,
       super(anchor: Anchor.center, paint: Paint()..color = color);

  static const flashColor = Color(0xFFFFFFFF);

  final double maxHp;
  double hp;
  double speed;
  final double contactDamage;
  final DamageType damageType;
  final Color color;
  final MonsterSprite? sprite;

  /// 웨이브가 낸 졸개 종류. 테스트나 상자처럼 직접 만든 적은 null.
  final EnemyKind? kind;

  /// [CrowdSystem] 이 매 프레임 채워 주는 밀어내기 속도.
  final separation = Vector2.zero();

  /// 맞아서 밀려나는 속도. 점점 줄어든다.
  final knockback = Vector2.zero();

  /// 맞으면 잠깐 커졌다 돌아온다 (남은 시간).
  double _pop = 0;

  final ailments = Ailments();

  final _velocity = Vector2.zero();
  double _flash = 0;
  bool _dead = false;

  /// 걷기 애니메이션 시간. 적마다 다른 박자로 걷도록 무작위로 시작한다.
  double _walk = 0;
  bool _facingLeft = false;

  /// 맞으면 흰색, 상태이상이면 그 색을 스프라이트에 덧칠한다.
  final _spritePaint = Paint();
  Color? _overlay;

  static final _shadowPaint = Paint()..color = const Color(0x55000000);

  bool get isDead => _dead;

  /// 밀림 배율. 거구는 덜 밀리고 보스 · 상자는 밀리지 않는다.
  double get knockbackScale => 1;

  /// 스프라이트를 비치게 그리는 정도 (1 = 불투명).
  double get spriteOpacity => 1;

  /// 스프라이트를 그릴 때 더하는 흔들림 (힘을 모을 때 떨린다).
  @protected
  final renderShake = Vector2.zero();

  /// [direction] (플레이어 반대쪽) 으로 밀어낸다. 이미 밀리는 중이면 더 센 쪽을 따른다.
  void knock(Vector2 direction, double strength) {
    final scale = strength * knockbackScale;
    if (scale <= 0 || direction.isZero()) return;
    final push = direction.normalized()..scale(scale);
    if (push.length2 > knockback.length2) knockback.setFrom(push);
  }

  /// 맞았을 때 깜빡이는 색을 입힌 스프라이트용 붓. 따로 그리는 하위 클래스가 쓴다.
  @protected
  Paint get spritePaint => _spritePaint;

  @override
  Future<void> onLoad() async {
    // 적끼리는 충돌 검사하지 않도록 passive 로 둔다.
    // isSolid: 빠른 투사체가 한 프레임에 원 안으로 들어와도 맞은 것으로 친다.
    add(CircleHitbox(collisionType: CollisionType.passive, isSolid: true));
  }

  @override
  void onMount() {
    super.onMount();
    world.enemies.add(this);
    _walk = world.game.random.nextDouble();
  }

  @override
  void onRemove() {
    world.enemies.remove(this);
    super.onRemove();
  }

  /// 이번 프레임에 움직일 속도를 [out] 에 채운다. 기본은 플레이어를 향해 곧장.
  /// 동상으로 느려지는 것은 [moveSpeed] 에 들어 있다.
  @protected
  void steer(double dt, Vector2 out) {
    out
      ..setFrom(world.player.position)
      ..sub(position);
    if (out.length2 > 1) {
      out
        ..normalize()
        ..scale(moveSpeed);
    } else {
      out.setZero();
    }
  }

  /// 상태이상까지 반영한 지금 이동 속도.
  double get moveSpeed => speed * ailments.speedMultiplier;

  @override
  void update(double dt) {
    super.update(dt);
    steer(dt, _velocity);
    _velocity
      ..add(separation)
      ..add(knockback);
    position.addScaled(_velocity, dt);
    knockback.scale(math.max(0, 1 - Balance.knockbackDecay * dt));
    world.obstacles.pushOut(position, radius * 0.8);
    _walk += dt;
    if (_velocity.x.abs() > 1) _facingLeft = _velocity.x < 0;
    if (_pop > 0) _pop -= dt;

    if (_flash > 0) _flash -= dt;
    final overlay = _flash > 0 ? flashColor : ailments.tint;
    paint.color = overlay ?? color;
    if (overlay != _overlay) {
      _overlay = overlay;
      // 흰색은 실루엣 전체를, 상태이상 색은 반투명하게 덮는다.
      _spritePaint.colorFilter = switch (overlay) {
        null => null,
        flashColor => const ColorFilter.mode(flashColor, BlendMode.srcIn),
        final tint => ColorFilter.mode(
          tint.withValues(alpha: 0.55),
          BlendMode.srcATop,
        ),
      };
    }

    final dot = ailments.tick(dt);
    if (dot > 0) takeDamage(dot, flash: false);
  }

  @override
  void render(Canvas canvas) {
    final sheet = sprite;
    final frames = sheet == null ? null : world.game.monsterSprites[sheet];
    if (sheet == null || frames == null) {
      super.render(canvas);
      return;
    }
    // 발이 충돌 원의 아래쪽 끝에 오도록 바닥 가운데에 맞춘다.
    final scale =
        radius *
        2 *
        Balance.enemySpriteSize /
        math.max(sheet.width, sheet.height * 0.75);
    final pop = _pop > 0 ? 1 + Balance.hitPop * _pop / Balance.hitPopTime : 1;
    final w = sheet.width * scale * pop;
    final h = sheet.height * scale * pop;
    final feet = radius * 2;
    renderUnder(canvas);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(radius, feet),
        width: w * 0.8,
        height: radius * 0.5,
      ),
      _shadowPaint,
    );
    final frame =
        frames[(_walk / Balance.enemyWalkFrameTime).floor() % frames.length];
    canvas
      ..save()
      ..translate(renderShake.x, renderShake.y);
    if (_facingLeft) {
      canvas
        ..translate(radius * 2, 0)
        ..scale(-1, 1);
    }
    _spritePaint.color = Color.fromRGBO(0, 0, 0, spriteOpacity);
    frame.render(
      canvas,
      position: Vector2(radius - w / 2, feet - h),
      size: Vector2(w, h),
      overridePaint: _spritePaint,
    );
    canvas.restore();
    renderOver(canvas);
  }

  /// 그림자 · 스프라이트 아래에 그릴 것 (돌진 방향, 폭발 범위 같은 예고).
  @protected
  void renderUnder(Canvas canvas) {}

  /// 스프라이트 위에 그릴 것 (조준 빛 같은 예고).
  @protected
  void renderOver(Canvas canvas) {}

  /// 잠깐 하얗게 깜빡인다 (자폭 직전 같은 예고).
  void flashWhite() => _flash = 0.08;

  /// 감전 중이면 더 아프다. 실제로 들어간 피해를 돌려준다.
  double takeDamage(double amount, {bool flash = true}) {
    if (_dead) return 0;
    final dealt = amount * ailments.damageTakenMultiplier;
    hp -= dealt;
    if (flash) {
      _flash = 0.08;
      _pop = Balance.hitPopTime;
    }
    if (hp <= 0) _die();
    return dealt;
  }

  void _die() {
    _dead = true;
    world
      ..add(DeathPuff(position: position.clone()))
      ..add(Sparks(position: position.clone(), color: color, count: 7));
    onKilled();
    onDeath();
    removeFromParent();
  }

  /// 처치 보상 (처치 수 · 경험치 · 잔불 · 장비). 상자는 자기 보상을 따로 준다.
  void onKilled() => world.onEnemyKilled(position.clone(), xp: kind?.xp ?? 1);

  /// 쓰러질 때 추가로 할 일.
  void onDeath() {}
}
