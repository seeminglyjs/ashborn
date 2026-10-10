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
import '../../data/corruption.dart';
import '../effects/burst.dart';
import '../effects/sparks.dart';
import 'ailment_fx.dart';
import 'ailments.dart';
import 'death_puff.dart';
import 'hazards.dart';

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

  /// 정예 (타락 특수 규칙 "정예 출현"). 크고 단단하며 발밑에 금빛 기운이 돈다.
  /// 체력 · 피해는 만들 때 이미 키워서 넘긴다 ([makeElite] 는 크기와 표시만 바꾼다).
  bool get elite => _elite;
  bool _elite = false;

  /// 정예로 만든다: 몸을 [Balance.eliteSize] 배로 키우고 표시를 켠다.
  void makeElite() {
    _elite = true;
    radius *= Balance.eliteSize;
  }

  /// [CrowdSystem] 이 매 프레임 채워 주는 밀어내기 속도.
  final separation = Vector2.zero();

  /// 맞아서 밀려나는 속도. 점점 줄어든다.
  final knockback = Vector2.zero();

  /// 맞으면 잠깐 커졌다 돌아온다 (남은 시간).
  double _pop = 0;

  late final ailments = Ailments(immune: ailmentImmune);

  /// 상태이상이 걸리지 않는가 (상자).
  bool get ailmentImmune => false;

  final _velocity = Vector2.zero();
  double _flash = 0;
  bool _dead = false;

  /// 걷기 애니메이션 시간. 적마다 다른 박자로 걷도록 무작위로 시작한다.
  double _walk = 0;
  bool _facingLeft = false;

  /// 상태이상 이펙트 시계. 얼어도 계속 흐른다.
  double _fxTime = 0;

  /// 맞으면 흰색, 상태이상이면 그 색을 스프라이트에 덧칠한다.
  final _spritePaint = Paint();
  Color? _overlay;

  static final _shadowPaint = Paint()..color = const Color(0x55000000);

  bool get isDead => _dead;

  /// 화염 · 냉기 · 번개가 이만큼 쌓이면 점화 · 냉각(동결) · 감전이 걸린다.
  double get ailmentThreshold => maxHp * Balance.ailmentThreshold;

  /// 동결 시간 배율. 보스는 짧게 언다.
  double get freezeScale => 1;

  /// 얼었거나 감전으로 굳어 부딪혀도 피해를 주지 못한다.
  bool get disabled => ailments.disabled;

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
  /// 냉각 · 중독으로 느려지는 것은 [moveSpeed] 에, 공격 준비가 느려지는 것은
  /// [update] 가 줄여서 넘기는 [dt] 에 들어 있다. 얼거나 굳으면 부르지 않는다.
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
    if (ailments.disabled) {
      _velocity
        ..setFrom(knockback)
        ..scale(0.3);
      renderShake.setZero();
    } else {
      steer(dt * ailments.actionMultiplier, _velocity);
      _velocity
        ..add(separation)
        ..add(knockback);
      _walk += dt * ailments.actionMultiplier;
    }
    position.addScaled(_velocity, dt);
    knockback.scale(math.max(0, 1 - Balance.knockbackDecay * dt));
    world.obstacles.pushOut(position, radius * 0.8);
    _fxTime += dt;
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

    final dot = ailments.tick(
      dt,
      threshold: ailmentThreshold,
      random: world.game.random,
    );
    if (ailments.spreadPoison || ailments.spreadIgnite) _spread();
    if (dot > 0) takeDamage(dot, flash: false);
  }

  /// 중독 · 점화를 [Balance.spreadRange] 안의 다른 적 하나에게 옮긴다.
  /// 아직 그 상태가 아닌 적을 먼저 고른다.
  void _spread() {
    final poison = ailments.spreadPoison;
    final ignite = ailments.spreadIgnite;
    ailments
      ..spreadPoison = false
      ..spreadIgnite = false;
    final near = world
        .enemiesNear(position, Balance.spreadRange + radius)
        .where((e) => e != this && !e.ailments.immune)
        .toList();
    if (near.isEmpty) return;
    if (poison) {
      final target = near.firstWhere(
        (e) => !e.ailments.poisoned,
        orElse: () => near.first,
      );
      target.ailments.catchPoison(ailments.poisonDps);
      world.add(
        SpreadArc(position.clone(), target.position.clone(), _poisonArc),
      );
    }
    if (ignite) {
      final target = near.firstWhere(
        (e) => !e.ailments.ignited,
        orElse: () => near.first,
      );
      target.ailments.ignite(ailments.igniteTick);
      world.add(SpreadArc(position.clone(), target.position.clone(), _fireArc));
    }
  }

  static const _poisonArc = Color(0xFF8BE05A);
  static const _fireArc = Color(0xFFFF8A2A);

  @override
  void render(Canvas canvas) {
    final sheet = sprite;
    final frames = sheet == null ? null : world.game.monsterSprites[sheet];
    if (sheet == null || frames == null) {
      super.render(canvas);
      paintAilments(
        canvas,
        ailments,
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        _fxTime,
      );
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
    if (_elite) _renderElite(canvas, feet, w);
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
    _bounce(canvas, feet);
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
    paintAilments(
      canvas,
      ailments,
      Rect.fromLTWH(radius - w / 2, feet - h, w, h),
      _fxTime,
    );
    renderOver(canvas);
  }

  /// 걷는 동안 발을 기준으로 통통 튀며 늘었다 줄었다 하고, 가는 쪽으로 살짝 기운다.
  /// 같은 그림이 미끄러지듯 움직이는 단조로움을 덜어 준다. 얼거나 굳으면 멈춘다.
  void _bounce(Canvas canvas, double feet) {
    final pace = _velocity.length;
    if (ailments.disabled || pace < 1) return;
    final strength = math.min(1.0, pace / Balance.enemySpeed);
    final step = math.sin(
      _walk * math.pi * 2 / (Balance.enemyWalkFrameTime * 4),
    );
    final squash = Balance.enemyBounceSquash * step * strength;
    final hop = Balance.enemyBounceHop * step.abs() * strength * radius / 14;
    // 오른쪽으로 걸으면 오른쪽으로, 왼쪽이면 왼쪽으로 기운다.
    final lean = _velocity.x / pace * Balance.enemyBounceLean * strength;
    canvas
      ..translate(radius, feet - hop)
      ..rotate(lean)
      ..scale(1 - squash * 0.6, 1 + squash)
      ..translate(-radius, -feet);
  }

  static final _eliteGlow = Paint();
  static final _eliteRim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// 정예 표시: 발밑에서 맥박치는 검붉은 기운과 금빛 테두리. 적 공격의 빨간 테두리와
  /// 헷갈리지 않게 금빛으로 두른다.
  void _renderElite(Canvas canvas, double feet, double width) {
    final pulse = 0.5 + 0.5 * math.sin(_fxTime * 5);
    final rect = Rect.fromCenter(
      center: Offset(radius, feet),
      width: width * (1.05 + 0.1 * pulse),
      height: radius * (0.75 + 0.1 * pulse),
    );
    _eliteGlow.color = const Color(0xFFA22633)
        .withValues(alpha: 0.35 + 0.2 * pulse);
    _eliteRim.color = const Color(0xFFFEAE34)
        .withValues(alpha: 0.6 + 0.4 * pulse);
    canvas
      ..drawOval(rect, _eliteGlow)
      ..drawOval(rect, _eliteRim);
  }

  /// 그림자 · 스프라이트 아래에 그릴 것 (돌진 방향, 폭발 범위 같은 예고).
  @protected
  void renderUnder(Canvas canvas) {}

  /// 스프라이트 위에 그릴 것 (조준 빛 같은 예고).
  @protected
  void renderOver(Canvas canvas) {}

  /// 잠깐 하얗게 깜빡인다 (자폭 직전 같은 예고).
  void flashWhite() => _flash = 0.08;

  /// 실제로 들어간 피해를 돌려준다. 출혈 추가 피해는 [Player.strike] 가 더한다.
  double takeDamage(double amount, {bool flash = true}) {
    if (_dead) return 0;
    final dealt = amount;
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
    // 얼어 있다 쓰러지면 얼음 파편이 사방으로 튄다.
    if (ailments.frozen) {
      world.player.shatter(position.clone(), ailments.frozenCold);
    }
    world
      ..add(DeathPuff(position: position.clone()))
      ..add(Sparks(position: position.clone(), color: color, count: 7));
    onKilled();
    onDeath();
    _leaveRemains();
    removeFromParent();
  }

  /// 타락 특수 규칙 "잿불 유해": 웨이브 졸개가 쓰러지면 확률로 그 자리가 예고 뒤 터진다.
  void _leaveRemains() {
    if (kind == null || !world.stage.has(CorruptionRule.deathBlast)) return;
    if (world.deathBlasts >= Balance.maxDeathBlasts) return;
    if (world.game.random.nextDouble() >= Balance.deathBlastChance) return;
    world.add(
      DeathBlast(
        position: position.clone(),
        damage: contactDamage * Balance.deathBlastDamage,
        type: damageType,
        color: color,
      ),
    );
  }

  /// 처치 보상 (처치 수 · 경험치 · 잔불 · 장비). 상자는 자기 보상을 따로 준다.
  /// 정예는 재의 결정을 [Balance.eliteXp] 배로, 강화석과 장비를 더 준다.
  void onKilled() => world.onEnemyKilled(
    position.clone(),
    xp: (kind?.xp ?? 1) * (_elite ? Balance.eliteXp : 1),
    elite: _elite,
  );

  /// 쓰러질 때 추가로 할 일.
  void onDeath() {}
}
