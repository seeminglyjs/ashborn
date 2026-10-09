import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/monster_sprites.dart';
import '../../game/world/run_world.dart';
import 'ailments.dart';
import 'death_puff.dart';

/// 재의 무리(Hollow). 플레이어를 향해 곧장 걸어온다.
/// 지역에 따라 색, 속도, 닿았을 때 주는 피해의 속성이 다르다.
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

  /// [CrowdSystem] 이 매 프레임 채워 주는 밀어내기 속도.
  final separation = Vector2.zero();

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

  @override
  void update(double dt) {
    super.update(dt);
    _velocity
      ..setFrom(world.player.position)
      ..sub(position);
    if (_velocity.length2 > 1) {
      _velocity
        ..normalize()
        ..scale(speed * ailments.speedMultiplier);
    }
    _velocity.add(separation);
    position.addScaled(_velocity, dt);
    _walk += dt;
    if (_velocity.x.abs() > 1) _facingLeft = _velocity.x < 0;

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
    final w = sheet.width * scale;
    final h = sheet.height * scale;
    final feet = radius * 2;
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
    if (_facingLeft) {
      canvas
        ..save()
        ..translate(radius * 2, 0)
        ..scale(-1, 1);
    }
    frame.render(
      canvas,
      position: Vector2(radius - w / 2, feet - h),
      size: Vector2(w, h),
      overridePaint: _spritePaint,
    );
    if (_facingLeft) canvas.restore();
  }

  /// 감전 중이면 더 아프다. 실제로 들어간 피해를 돌려준다.
  double takeDamage(double amount, {bool flash = true}) {
    if (_dead) return 0;
    final dealt = amount * ailments.damageTakenMultiplier;
    hp -= dealt;
    if (flash) _flash = 0.08;
    if (hp <= 0) _die();
    return dealt;
  }

  void _die() {
    _dead = true;
    world
      ..add(DeathPuff(position: position.clone()))
      ..onEnemyKilled(position.clone());
    onDeath();
    removeFromParent();
  }

  /// 쓰러질 때 추가로 할 일.
  void onDeath() {}
}
