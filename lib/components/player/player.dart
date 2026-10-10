import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/class_passives.dart';
import '../../data/damage.dart';
import '../../data/equipment.dart';
import '../../data/passives.dart';
import '../../data/stats.dart';
import '../../data/transcend.dart';
import '../../data/weapons.dart';
import '../../game/ashborn_game.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/damage_number.dart';
import '../effects/sparks.dart';
import '../enemies/boss.dart';
import '../enemies/enemy.dart';
import '../enemies/ailments.dart';
import '../weapons/common_weapons.dart';
import '../weapons/element_procs.dart';
import '../weapons/ember_orb.dart';
import '../weapons/fire_crossbow.dart';
import '../weapons/greatsword.dart';
import '../weapons/hunter_weapons.dart';
import '../weapons/knight_weapons.dart';
import '../weapons/weapon.dart';
import '../weapons/witch_weapons.dart';

/// 캐릭터 스프라이트의 자세.
enum PlayerPose { idle, run, hit }

class Player extends PositionComponent
    with
        HasGameReference<AshbornGame>,
        HasWorldReference<RunWorld>,
        KeyboardHandler,
        CollisionCallbacks {
  Player(this.character)
    : super(
        size: Vector2.all(Balance.playerRadius * 2),
        anchor: Anchor.center,
        priority: 10,
      );

  final CharacterDef character;

  /// 얻은 패시브와 그 레벨.
  final passives = <PassiveId, int>{};

  /// 레벨업으로 게임이 멈춘 동안 붙인 무기는 아직 마운트 전이므로 직접 들고 있는다.
  final _weapons = <LeveledWeapon>[];

  late double hp;
  late double _knownMaxHp;
  double energyShield = 0;
  double _invulnerable = 0;

  /// 마지막 피격 후 지난 시간. 에너지 보호막 재충전에 쓴다.
  double _sinceHit = 0;

  /// 이번 런에서 되살아난 횟수.
  int _revivesUsed = 0;

  final _keyDirection = Vector2.zero();
  final _move = Vector2.zero();

  /// 발밑 그림자.
  final _shadowPaint = Paint()..color = const Color(0x66000000);

  /// 캐릭터 스프라이트. 이미지를 다 읽기 전에는 null 이다.
  SpriteAnimationGroupComponent<PlayerPose>? _sprite;
  bool _facingLeft = false;
  double _hitPose = 0;

  bool get isDead => hp <= 0;

  /// 패시브, 장비, 운명, 화톳불 강화로 오른 [stat] 의 합.
  double bonus(StatType stat) {
    var total =
        game.gear.bonus(stat) +
        world.fate.bonus(stat) +
        game.upgrades.bonus(stat);
    passives.forEach((id, level) {
      if (id.stat == stat) total += id.perLevel * level;
    });
    return total + _classBonus(stat);
  }

  /// 직업 패시브 [passive] 의 레벨. 다른 직업의 패시브는 0.
  int classLevel(ClassPassive passive) =>
      passive.owner == character.id ? game.mastery.passiveLevel(passive) : 0;

  /// 직업 패시브가 올려 주는 능력치.
  double _classBonus(StatType stat) {
    double v(ClassPassive p) => p.value(classLevel(p));
    double v2(ClassPassive p) => p.value2(classLevel(p));
    return switch (stat) {
      StatType.burnChance ||
      StatType.chillChance ||
      StatType.shockChance => v(ClassPassive.affinity),
      StatType.burnDamage => v2(ClassPassive.affinity),
      StatType.poisonChance => v(ClassPassive.envenom),
      StatType.poisonDamage => v2(ClassPassive.envenom),
      StatType.critChance => v(ClassPassive.weakSpot),
      StatType.critDamage => v2(ClassPassive.weakSpot),
      _ => 0,
    };
  }

  /// 연격 숙련: 대검 콤보 확률과 맹공 지속 시간 증가.
  double get comboBonus =>
      ClassPassive.swordMastery.value(classLevel(ClassPassive.swordMastery));
  double get onslaughtBonus =>
      ClassPassive.swordMastery.value2(classLevel(ClassPassive.swordMastery));

  /// 잔향 시전: 무기가 한 번 더 발동할 확률.
  double get echoChance =>
      ClassPassive.spellEcho.value(classLevel(ClassPassive.spellEcho));

  /// 재의 장막: 다시 생길 때까지 남은 시간. 0 이하면 장막이 있다.
  double _veilCooldown = 0;
  bool get hasVeil =>
      classLevel(ClassPassive.ashVeil) > 0 && _veilCooldown <= 0;

  /// 지금 움직이고 있는가 (질주 사격).
  bool get isMoving => _move.length2 > 0.01;

  /// 패시브로 늘어난 무기 범위 배율.
  double get areaMultiplier =>
      1 + (passives[PassiveId.spread] ?? 0) * PassiveId.spread.perLevel;

  double get maxHp => character.maxHp + bonus(StatType.maxHp);
  double get speed => character.speed * (1 + bonus(StatType.moveSpeed));
  double get magnetRange =>
      Balance.magnetRange * (1 + bonus(StatType.magnetRange));
  Set<UniqueEffect> get effects => {
    ...game.gear.effects,
    ...world.fate.effects,
  };

  /// [effect] 의 세기. 고유 장비는 1, 운명 카드는 등급만큼. 없으면 0.
  double effectPower(UniqueEffect effect) => math.max(
    game.gear.effects.contains(effect) ? 1 : 0,
    world.fate.effectPower(effect),
  );

  /// 되살아날 때마다 차례로 쓸 체력 비율. 불사조의 재는 런마다 한 번,
  /// 불사조의 깃털은 고른 순서대로 한 장마다 한 번.
  List<double> get reviveHps => [
    if (game.gear.effects.contains(UniqueEffect.phoenix)) Balance.phoenixHp,
    ...world.fate.reviveHps,
  ];

  double get damageMultiplier {
    var multiplier = 1 + bonus(StatType.damage);
    if (effects.contains(UniqueEffect.berserk)) {
      multiplier *=
          1 +
          (1 - hp / maxHp) *
              Balance.berserkScale *
              effectPower(UniqueEffect.berserk);
    }
    return multiplier;
  }

  double get attackSpeedMultiplier =>
      1 +
      bonus(StatType.attackSpeed) +
      (isMoving
          ? ClassPassive.momentum.value(classLevel(ClassPassive.momentum))
          : 0);

  /// 장착한 장비의 [option] 초월 수치 합.
  double transcend(TranscendOption option) => game.gear.transcend(option);

  /// 초월 옵션으로 늘어난 투사체 · 칼날 수.
  int get extraProjectiles =>
      transcend(TranscendOption.extraProjectiles).round();
  double get xpMultiplier => 1 + bonus(StatType.xpGain);
  double get critChance => bonus(StatType.critChance);
  double get critMultiplier =>
      Balance.critMultiplier + bonus(StatType.critDamage);
  double get evasion => math.min(bonus(StatType.evasion), Balance.maxEvasion);
  double get maxEnergyShield => bonus(StatType.energyShield);

  /// [type] 피해 감소율. 상한이 있다.
  double reduction(DamageType type) =>
      math.min(bonus(type.reduction), Balance.maxReduction);

  /// 방어력은 물리 피해만 줄인다.
  double get armorMultiplier =>
      Balance.armorScale / (Balance.armorScale + bonus(StatType.armor));

  void gainPassive(PassiveId id) {
    passives.update(id, (level) => level + 1, ifAbsent: () => 1);
    syncMaxHp();
  }

  void heal(double amount) {
    hp = math.min(maxHp, hp + amount);
    game.stats.hp.value = hp;
  }

  /// 최대 체력이 바뀌면 현재 체력도 같은 비율로 맞춘다.
  /// 장비를 뺐다 껴서 체력을 채우는 일이 없도록 비율을 쓴다.
  void syncMaxHp() {
    final after = maxHp;
    if (after != _knownMaxHp) {
      hp = hp * after / _knownMaxHp;
      _knownMaxHp = after;
    }
    energyShield = math.min(energyShield, maxEnergyShield);
    _publish();
  }

  void _publish() {
    game.stats
      ..maxHp.value = maxHp
      ..hp.value = hp
      ..maxEnergyShield.value = maxEnergyShield
      ..energyShield.value = energyShield;
  }

  @override
  void onMount() {
    super.onMount();
    game.inventory.addListener(syncMaxHp);
  }

  @override
  void onRemove() {
    game.inventory.removeListener(syncMaxHp);
    super.onRemove();
  }

  @override
  Future<void> onLoad() async {
    hp = _knownMaxHp = maxHp;
    energyShield = maxEnergyShield;
    _publish();
    // isSolid: 적이 플레이어 안에 완전히 들어와도 충돌로 친다.
    add(CircleHitbox(isSolid: true));
    // 스프라이트는 기다리지 않고 읽는다. 다 읽기 전에는 그림자만 보인다.
    unawaited(_loadSprite());
    gainWeapon(character.startWeapon);
  }

  /// 캐릭터 스프라이트 시트를 읽어 자세별 애니메이션으로 붙인다.
  /// 무기 이펙트 아래에 그려지도록 우선순위를 낮춘다.
  Future<void> _loadSprite() async {
    final sheet = await game.images.load(character.sprite);
    final frame = Vector2(16, 28);
    // 시트의 [start] 번째 프레임부터 [count] 장.
    SpriteAnimation clip(int start, int count, double step) =>
        SpriteAnimation.fromFrameData(
          sheet,
          SpriteAnimationData.sequenced(
            amount: count,
            stepTime: step,
            textureSize: frame,
            texturePosition: Vector2(frame.x * start, 0),
          ),
        );
    final sprite = SpriteAnimationGroupComponent<PlayerPose>(
      animations: {
        PlayerPose.idle: clip(0, 4, 0.15),
        PlayerPose.run: clip(4, 4, 0.1),
        PlayerPose.hit: clip(8, 1, 1),
      },
      current: PlayerPose.idle,
      size: frame * Balance.playerSpriteScale,
      // 발이 충돌 원의 아래쪽 끝에 오도록 바닥 가운데를 기준으로 둔다.
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, size.y / 2 + Balance.playerRadius),
      priority: -1,
    );
    if (_facingLeft) sprite.flipHorizontally();
    _sprite = sprite;
    add(sprite);
  }

  /// 움직임에 맞춰 자세와 방향을 바꾸고, 무적 시간 동안 깜빡인다.
  void _updateSprite(double dt) {
    final sprite = _sprite;
    if (_hitPose > 0) _hitPose -= dt;
    if (sprite == null) return;
    if (_move.x.abs() > 0.05 && (_move.x < 0) != _facingLeft) {
      _facingLeft = !_facingLeft;
      sprite.flipHorizontally();
    }
    sprite
      ..current = _hitPose > 0
          ? PlayerPose.hit
          : _move.length2 > 0.0025
          ? PlayerPose.run
          : PlayerPose.idle
      ..opacity = _blinking ? 0 : 1;
  }

  bool get _blinking =>
      _invulnerable > 0 && (_invulnerable * 20).floor().isEven;

  List<LeveledWeapon> get weapons => List.unmodifiable(_weapons);

  LeveledWeapon? weapon(WeaponId id) =>
      weapons.where((w) => w.id == id).firstOrNull;

  /// 처음 얻는 무기는 1레벨로 붙이고, 이미 있으면 레벨을 올린다.
  void gainWeapon(WeaponId id) {
    final owned = weapon(id);
    if (owned != null) {
      owned.levelUp();
    } else {
      final weapon = _createWeapon(id);
      _weapons.add(weapon);
      add(weapon);
    }
  }

  static LeveledWeapon _createWeapon(WeaponId id) => switch (id) {
    WeaponId.greatsword => Greatsword(),
    WeaponId.earthSlam => EarthSlam(),
    WeaponId.cleave => Cleave(),
    WeaponId.emberOrb => EmberOrb(),
    WeaponId.meteor => Meteor(),
    WeaponId.fireTornado => FireTornado(),
    WeaponId.fireCrossbow => FireCrossbow(),
    WeaponId.emberMine => EmberMine(),
    WeaponId.throwingKnives => ThrowingKnives(),
    WeaponId.ashAura => AshAura(),
    WeaponId.thunder => Thunder(),
    WeaponId.chakram => Chakram(),
  };

  /// 최대 레벨 [id] 무기를 각성시키고, 금빛 기둥이 솟는 연출을 띄운다.
  void awaken(WeaponId id) {
    weapon(id)!.awaken();
    const gold = Color(0xFFFFE08A);
    world
      ..add(
        Burst(
          position: position.clone(),
          radius: Balance.awakenBurstRadius,
          color: gold,
        ),
      )
      ..add(
        Ring(
          position: position.clone(),
          radius: Balance.awakenBurstRadius * 1.3,
          color: const Color(0xFFFFFFFF),
          duration: 0.6,
          strokeWidth: 8,
        ),
      )
      ..add(
        Sparks(
          position: position.clone(),
          color: gold,
          count: 28,
          speed: 320,
          duration: 0.7,
          sparkSize: 4,
        ),
      )
      ..add(LightningBolt(position: position.clone(), color: gold, length: 320))
      ..shake(0.5);
    game.notify('각성! ${id.awakenedLabel}', color: gold);
    if (game.settings.vibration) HapticFeedback.mediumImpact();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_invulnerable > 0) _invulnerable -= dt;
    if (_veilCooldown > 0) _veilCooldown -= dt;
    final regen = bonus(StatType.hpRegen);
    if (regen > 0 && hp < maxHp) {
      hp = (hp + regen * dt).clamp(0, maxHp);
      game.stats.hp.value = hp;
    }
    _sinceHit += dt;
    final maxShield = maxEnergyShield;
    if (_sinceHit >= Balance.energyShieldRechargeDelay &&
        energyShield < maxShield) {
      energyShield = math.min(
        maxShield,
        energyShield + maxShield * Balance.energyShieldRechargeRate * dt,
      );
      game.stats.energyShield.value = energyShield;
    }

    _move
      ..setFrom(_keyDirection)
      ..add(game.joystick.relativeDelta);
    if (_move.length2 > 1) _move.normalize();
    position.addScaled(_move, speed * dt);
    world.obstacles.pushOut(position, Balance.playerRadius * 0.7);
    _updateSprite(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_blinking) return;
    if (hasVeil) _renderVeil(canvas);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + Balance.playerRadius),
        width: Balance.playerRadius * 1.6,
        height: Balance.playerRadius * 0.6,
      ),
      _shadowPaint,
    );
  }

  static final _veilPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// 재의 장막: 몸 둘레를 천천히 도는 잿빛 보랏빛 고리.
  void _renderVeil(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2 - 6);
    final t = world.elapsed;
    for (var i = 0; i < 3; i++) {
      _veilPaint.color = const Color(0xFFB8A6FF)
          .withValues(alpha: 0.35 + 0.25 * math.sin(t * 3 + i * 2));
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 26),
        t * 1.6 + i * math.pi * 2 / 3,
        1.4,
        false,
        _veilPaint,
      );
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool any(List<LogicalKeyboardKey> keys) => keys.any(keysPressed.contains);
    _keyDirection.setValues(
      (any([LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight]) ? 1 : 0) -
          (any([LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft])
              ? 1
              : 0),
      (any([LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown]) ? 1 : 0) -
          (any([LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp]) ? 1 : 0),
    );
    return true;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    // 상자처럼 피해가 없는 적은 밟고 지나간다 (무적 시간도 걸리지 않는다).
    // 얼었거나 감전으로 굳은 적은 부딪혀도 아프지 않다.
    if (other is Enemy &&
        other.contactDamage > 0 &&
        !other.disabled &&
        takeDamage(
          other.contactDamage,
          type: other.damageType,
          source: other,
        )) {
      // 가시: 부딪힌 적에게 원래 피해의 일부를 돌려준다.
      final thorns = transcend(TranscendOption.thorns);
      if (thorns > 0) other.takeDamage(other.contactDamage * thorns);
    }
  }

  /// 재의 장막 → 회피 → 튕겨내기 → 피해 감소(저항, 방어력, 강철 의지, 불굴)
  /// → 에너지 보호막 → 체력 순으로 처리한다. [source] 는 부딪힌 적 (튕겨내기가 노린다).
  /// 무적이나 회피 · 장막 · 튕겨내기로 피하지 않고 맞았으면 true.
  bool takeDamage(
    double amount, {
    DamageType type = DamageType.physical,
    Enemy? source,
  }) {
    if (_invulnerable > 0 || isDead) return false;
    _invulnerable = Balance.playerInvulnerableTime;
    if (hasVeil) {
      _veilCooldown = ClassPassive.ashVeil.value(
        classLevel(ClassPassive.ashVeil),
      );
      world
        ..add(
          Ring(
            position: position.clone(),
            radius: 40,
            color: const Color(0xFFB8A6FF),
          ),
        )
        ..add(
          CallOut(
            position: position + Vector2(0, -40),
            text: '장막',
            color: const Color(0xFFB8A6FF),
          ),
        );
      return false;
    }
    if (game.random.nextDouble() < evasion) return false;
    if (_parry(amount, source)) return false;

    var damage =
        amount *
        character.damageTakenMultiplier *
        (1 - reduction(type)) *
        (1 - ClassPassive.ironWill.value(classLevel(ClassPassive.ironWill)));
    if (type == DamageType.physical) damage *= armorMultiplier;
    if (hp <= maxHp * Balance.lastStandThreshold) {
      damage *=
          1 -
          math.min(transcend(TranscendOption.lastStand), Balance.maxReduction);
    }
    final absorbed = math.min(energyShield, damage);
    energyShield -= absorbed;
    damage -= absorbed;
    _sinceHit = 0;
    if (effects.contains(UniqueEffect.frostArmor)) _frostArmor();

    hp = (hp - damage).clamp(0, maxHp);
    if (damage > 0) {
      _hitPose = Balance.playerHitPoseTime;
      game.hitVignette.flash();
      world.shake(damage >= maxHp * 0.15 ? 0.3 : 0.12);
      if (game.settings.vibration) HapticFeedback.lightImpact();
    }
    final revives = isDead ? reviveHps : const <double>[];
    if (_revivesUsed < revives.length) {
      hp = maxHp * revives[_revivesUsed++];
      _invulnerable = Balance.phoenixInvulnerableTime;
      game.notify('재에서 다시 일어섰다', color: Rarity.unique.color);
    }
    _publish();
    if (isDead) game.onPlayerDied();
    return true;
  }

  /// 튕겨내기: 확률로 공격을 막고, 받을 뻔한 피해 [amount] 의 몇 배를 공격한 적에게 돌려준다.
  /// 탄 · 장판처럼 공격한 적을 모르면 가장 가까운 적에게 돌려준다. 막았으면 true.
  bool _parry(double amount, Enemy? source) {
    final level = classLevel(ClassPassive.parry);
    if (level <= 0 ||
        game.random.nextDouble() >= ClassPassive.parry.value(level)) {
      return false;
    }
    final target =
        source ?? world.nearestEnemy(position, maxDistance: Balance.parryRange);
    world
      ..add(
        CallOut(
          position: position + Vector2(0, -40),
          text: '튕겨내기!',
          color: const Color(0xFFE6EEFF),
        ),
      )
      ..add(
        Sparks(
          position: position.clone(),
          color: const Color(0xFFFFFFFF),
          count: 10,
          speed: 240,
        ),
      );
    if (target != null && !target.isDead) {
      world.add(
        Ring(
          position: target.position.clone(),
          radius: target.radius * 1.8,
          color: const Color(0xFFE6EEFF),
          strokeWidth: 4,
        ),
      );
      strike(
        target,
        amount * ClassPassive.parry.value2(level),
        DamageType.physical,
        secondary: true,
      );
      target.knock(target.position - position, Balance.hitKnockback * 2);
    }
    return true;
  }

  void _frostArmor() {
    world.add(
      Burst(
        position: position.clone(),
        radius: Balance.frostArmorRadius,
        color: const Color(0xFF8FD3FF),
      ),
    );
    for (final enemy in world.enemiesNear(position, Balance.frostArmorRadius)) {
      enemy.ailments.chill(
        Balance.frostArmorSlow,
        Balance.frostArmorDuration * effectPower(UniqueEffect.frostArmor),
      );
    }
  }

  /// 무기의 [base] 피해에 장비의 속성 피해를 더해 [enemy] 를 때린다.
  /// 치명타, 상태이상, 생명력 흡수를 처리하고 실제로 들어간 피해를 돌려준다.
  ///
  /// [secondary] 는 효과로 생긴 추가 타격: 장비 속성 피해를 다시 더하지 않고,
  /// 바람 검기 · 소용돌이 · 연쇄 번개를 다시 일으키지 않는다.
  double strike(
    Enemy enemy,
    double base,
    DamageType type, {
    bool secondary = false,
  }) {
    if (enemy.isDead) return 0;
    final random = game.random;
    final hit = Hit()..add(type, base);
    if (!secondary) {
      for (final t in DamageType.values) {
        hit.add(t, bonus(t.added));
        hit.add(t, base * world.fate.extraDamage(t));
      }
    }
    // 배율을 곱하기 전 속성별 피해. 원소 효과(파편 · 연쇄 번개 · 바람)의 기준이 된다.
    final raw = Map.of(hit.parts);
    var multiplier = damageMultiplier * enemy.ailments.hitTakenMultiplier;
    if (enemy is Boss) {
      multiplier *= 1 + transcend(TranscendOption.bossDamage);
    }
    if (random.nextDouble() < critChance) {
      hit.crit = true;
      multiplier *= critMultiplier;
    }
    hit.scale(multiplier);

    final dealt = enemy.takeDamage(hit.total);
    world.showDamage(enemy.position, dealt, crit: hit.crit, type: hit.main);
    if (!secondary) {
      final away = enemy.position - position;
      enemy.knock(
        away,
        Balance.hitKnockback * (hit.crit ? Balance.critKnockback : 1),
      );
      world.add(
        Sparks(
          position: enemy.position.clone(),
          color: hitColor(hit.main, crit: hit.crit),
          count: hit.crit ? 8 : 4,
          speed: hit.crit ? 220 : 150,
          angle: math.atan2(away.y, away.x),
          spread: 1.6,
        ),
      );
      if (hit.crit && enemy is Boss) world.shake(0.08);
    }
    _applyAilments(enemy, hit, raw, random, secondary: secondary);
    if (!secondary) {
      if (effects.contains(UniqueEffect.chainLightning) &&
          random.nextDouble() < Balance.chainLightningChance) {
        _chainLightning(
          enemy,
          hit.total *
              Balance.chainLightningRatio *
              effectPower(UniqueEffect.chainLightning),
          Balance.chainLightningTargets,
        );
      }
      _windProcs(enemy, raw[DamageType.wind] ?? 0, random);
    }

    final steal = bonus(StatType.lifeSteal);
    if (steal > 0 && hp < maxHp) {
      hp = math.min(maxHp, hp + dealt * steal);
      game.stats.hp.value = hp;
    }
    return dealt;
  }

  void _chainLightning(Enemy from, double damage, int count) {
    final targets = world
        .enemiesNear(from.position, Balance.chainLightningRange)
        .where((e) => e != from)
        .take(count)
        .toList();
    for (final target in targets) {
      world.add(LightningArc(from.position.clone(), target.position.clone()));
      strike(target, damage, DamageType.lightning, secondary: true);
    }
  }

  void _applyAilments(
    Enemy enemy,
    Hit hit,
    Map<DamageType, double> raw,
    math.Random random, {
    required bool secondary,
  }) {
    final ailments = enemy.ailments;
    final threshold = enemy.ailmentThreshold;
    final physical = hit[DamageType.physical];
    if (physical > 0 && random.nextDouble() < bonus(StatType.bleedChance)) {
      ailments.bleed(
        physical * Balance.bleedRatio * (1 + bonus(StatType.bleedDamage)),
      );
    }
    if (random.nextDouble() < bonus(StatType.poisonChance)) {
      ailments.poison(
        hit.total * Balance.poisonRatio * (1 + bonus(StatType.poisonDamage)),
      );
    }

    // 화염 · 냉기 · 번개는 쌓여서 걸린다.
    final fire = hit[DamageType.fire];
    if (ailments.addFire(
      fire * (1 + bonus(StatType.burnChance)),
      threshold,
      fire * Balance.igniteRatio * (1 + bonus(StatType.burnDamage)),
    )) {
      world.add(
        Burst(
          position: enemy.position.clone(),
          radius: enemy.radius * 1.6,
          color: const Color(0xFFFF7A2E),
        ),
      );
    }

    final cold = hit[DamageType.cold];
    final stage = ailments.addCold(
      cold * (1 + bonus(StatType.chillChance)),
      threshold,
      cold: raw[DamageType.cold] ?? 0,
      freezeTime: Balance.freezeDuration * enemy.freezeScale,
    );
    if (stage != ColdStage.none) {
      world.add(
        Sparks(
          position: enemy.position.clone(),
          color: const Color(0xFFCFF3FF),
          count: stage == ColdStage.frozen ? 10 : 5,
          speed: 120,
        ),
      );
    }

    final lightning = hit[DamageType.lightning];
    if (ailments.addLightning(
      lightning * (1 + bonus(StatType.shockChance)),
      threshold,
    )) {
      world.add(
        Sparks(
          position: enemy.position.clone(),
          color: const Color(0xFFFFF27A),
          count: 8,
          speed: 200,
        ),
      );
      // 연쇄 번개는 직접 타격으로 감전됐을 때만 튄다 (번개가 번개를 끝없이 부르지 않게).
      if (!secondary) {
        _chainLightning(
          enemy,
          (raw[DamageType.lightning] ?? 0) *
              Balance.shockChainRatio *
              (1 + bonus(StatType.shockEffect)),
          Balance.shockChainTargets,
        );
      }
    }
  }

  /// 바람 검기 · 소용돌이를 쏠 수 있게 되는 시각.
  double _windSlashReady = 0;
  double _vortexReady = 0;

  /// 바람 피해가 섞인 타격이면 확률로 소용돌이(드묾)나 바람 검기를 일으킨다.
  void _windProcs(Enemy enemy, double wind, math.Random random) {
    if (wind <= 0) return;
    final now = world.elapsed;
    if (now >= _vortexReady && random.nextDouble() < Balance.vortexChance) {
      _vortexReady = now + Balance.vortexCooldown;
      world.add(
        Vortex(
          position: enemy.position.clone(),
          damage: wind * Balance.vortexRatio,
        ),
      );
      return;
    }
    if (now >= _windSlashReady &&
        random.nextDouble() < Balance.windSlashChance) {
      _windSlashReady = now + Balance.windSlashCooldown;
      world.add(
        WindSlash(
          position: position.clone(),
          direction: enemy.position - position,
          damage: wind * Balance.windSlashRatio,
        ),
      );
    }
  }

  /// 얼어 있던 적이 [at] 에서 쓰러졌다: 동결시킨 냉기 피해 [cold] 기준으로 6방향 얼음 파편.
  void shatter(Vector2 at, double cold) {
    final damage = cold * Balance.shardRatio;
    world
      ..add(
        Sparks(
          position: at.clone(),
          color: const Color(0xFFE6F8FF),
          count: 12,
          speed: 180,
        ),
      )
      ..add(
        Ring(position: at.clone(), radius: 40, color: const Color(0xFF9FE0FF)),
      );
    if (damage <= 0) return;
    for (var i = 0; i < Balance.shardCount; i++) {
      final a = math.pi * 2 * i / Balance.shardCount;
      world.add(
        IceShard(
          position: at.clone(),
          direction: Vector2(math.cos(a), math.sin(a)),
          damage: damage,
        ),
      );
    }
  }
}
