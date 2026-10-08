import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/damage.dart';
import '../../data/equipment.dart';
import '../../data/passives.dart';
import '../../data/stats.dart';
import '../../data/transcend.dart';
import '../../data/weapons.dart';
import '../../game/ashborn_game.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../enemies/boss.dart';
import '../enemies/enemy.dart';
import '../weapons/ember_orb.dart';
import '../weapons/fire_crossbow.dart';
import '../weapons/flame_blade.dart';
import '../weapons/weapon.dart';

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

  late final _bodyPaint = Paint()..color = character.color;
  final _corePaint = Paint()..color = const Color(0xFFFFE6B0);

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
    return total;
  }

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

  double get attackSpeedMultiplier => 1 + bonus(StatType.attackSpeed);

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
    gainWeapon(character.startWeapon);
  }

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
    WeaponId.flameBlade => FlameBlade(),
    WeaponId.emberOrb => EmberOrb(),
    WeaponId.fireCrossbow => FireCrossbow(),
  };

  @override
  void update(double dt) {
    super.update(dt);
    if (_invulnerable > 0) _invulnerable -= dt;
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
  }

  @override
  void render(Canvas canvas) {
    // 무적 시간 동안 깜빡인다.
    if (_invulnerable > 0 && (_invulnerable * 20).floor().isEven) return;
    final center = Offset(size.x / 2, size.y / 2);
    canvas
      ..drawCircle(center, Balance.playerRadius, _bodyPaint)
      ..drawCircle(center, Balance.playerRadius * 0.45, _corePaint);
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
    if (other is Enemy &&
        takeDamage(other.contactDamage, type: other.damageType)) {
      // 가시: 부딪힌 적에게 원래 피해의 일부를 돌려준다.
      final thorns = transcend(TranscendOption.thorns);
      if (thorns > 0) other.takeDamage(other.contactDamage * thorns);
    }
  }

  /// 회피 → 피해 감소(저항, 방어력, 불굴) → 에너지 보호막 → 체력 순으로 처리한다.
  /// 무적이나 회피로 피하지 않고 맞았으면 true.
  bool takeDamage(double amount, {DamageType type = DamageType.physical}) {
    if (_invulnerable > 0 || isDead) return false;
    _invulnerable = Balance.playerInvulnerableTime;
    if (game.random.nextDouble() < evasion) return false;

    var damage =
        amount * character.damageTakenMultiplier * (1 - reduction(type));
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
      game.hitVignette.flash();
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
  /// [secondary] 는 효과로 생긴 추가 타격: 장비 속성 피해를 다시 더하지 않는다.
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
      }
    }
    var multiplier = damageMultiplier;
    if (enemy is Boss) {
      multiplier *= 1 + transcend(TranscendOption.bossDamage);
    }
    if (random.nextDouble() < critChance) {
      hit.crit = true;
      multiplier *= critMultiplier;
    }
    hit.scale(multiplier);

    final dealt = enemy.takeDamage(hit.total);
    world.showDamage(enemy.position, dealt, crit: hit.crit);
    _applyAilments(enemy, hit, random);
    if (!secondary &&
        effects.contains(UniqueEffect.chainLightning) &&
        random.nextDouble() < Balance.chainLightningChance) {
      _chainLightning(
        enemy,
        hit.total *
            Balance.chainLightningRatio *
            effectPower(UniqueEffect.chainLightning),
      );
    }

    final steal = bonus(StatType.lifeSteal);
    if (steal > 0 && hp < maxHp) {
      hp = math.min(maxHp, hp + dealt * steal);
      game.stats.hp.value = hp;
    }
    return dealt;
  }

  void _chainLightning(Enemy from, double damage) {
    final targets = world
        .enemiesNear(from.position, Balance.chainLightningRange)
        .where((e) => e != from)
        .take(Balance.chainLightningTargets)
        .toList();
    for (final target in targets) {
      world.add(LightningArc(from.position.clone(), target.position.clone()));
      strike(target, damage, DamageType.lightning, secondary: true);
    }
  }

  void _applyAilments(Enemy enemy, Hit hit, math.Random random) {
    bool roll(StatType chance, double portion) =>
        portion > 0 && random.nextDouble() < bonus(chance);
    final ailments = enemy.ailments;
    if (roll(StatType.bleedChance, hit[DamageType.physical])) {
      ailments.bleed(
        hit[DamageType.physical] *
            Balance.bleedRatio *
            (1 + bonus(StatType.bleedDamage)),
      );
    }
    if (roll(StatType.burnChance, hit[DamageType.fire])) {
      ailments.burn(
        hit[DamageType.fire] *
            Balance.burnRatio *
            (1 + bonus(StatType.burnDamage)),
      );
    }
    if (roll(StatType.poisonChance, hit.total)) {
      ailments.poison(
        hit.total * Balance.poisonRatio * (1 + bonus(StatType.poisonDamage)),
      );
    }
    if (roll(StatType.shockChance, hit[DamageType.lightning])) {
      ailments.shock(Balance.shockEffect * (1 + bonus(StatType.shockEffect)));
    }
    if (roll(StatType.chillChance, hit[DamageType.cold])) {
      ailments.chill(Balance.chillSlow, Balance.chillDuration);
    }
  }
}
