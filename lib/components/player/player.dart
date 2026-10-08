import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/passives.dart';
import '../../data/stats.dart';
import '../../data/weapons.dart';
import '../../game/ashborn_game.dart';
import '../../game/world/run_world.dart';
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

  late double hp = maxHp;
  double _invulnerable = 0;

  final _keyDirection = Vector2.zero();
  final _move = Vector2.zero();

  late final _bodyPaint = Paint()..color = character.color;
  final _corePaint = Paint()..color = const Color(0xFFFFE6B0);

  bool get isDead => hp <= 0;

  /// 패시브로 오른 [stat] 의 합.
  double bonus(StatType stat) {
    var total = 0.0;
    passives.forEach((id, level) {
      if (id.stat == stat) total += id.perLevel * level;
    });
    return total;
  }

  double get maxHp => character.maxHp + bonus(StatType.maxHp);
  double get speed => character.speed * (1 + bonus(StatType.moveSpeed));
  double get magnetRange =>
      Balance.magnetRange * (1 + bonus(StatType.magnetRange));

  void gainPassive(PassiveId id) {
    final before = maxHp;
    passives.update(id, (level) => level + 1, ifAbsent: () => 1);
    _onMaxHpChanged(before);
  }

  /// 최대 체력이 늘면 늘어난 만큼 현재 체력도 채운다.
  void _onMaxHpChanged(double before) {
    final after = maxHp;
    if (after > before) hp += after - before;
    hp = hp.clamp(0, after);
    game.stats
      ..maxHp.value = after
      ..hp.value = hp;
  }

  @override
  Future<void> onLoad() async {
    // isSolid: 적이 플레이어 안에 완전히 들어와도 충돌로 친다.
    addAll([CircleHitbox(isSolid: true), _createWeapon(character.startWeapon)]);
  }

  Iterable<LeveledWeapon> get weapons => children.whereType<LeveledWeapon>();

  LeveledWeapon? weapon(WeaponId id) =>
      weapons.where((w) => w.id == id).firstOrNull;

  /// 처음 얻는 무기는 1레벨로 붙이고, 이미 있으면 레벨을 올린다.
  void gainWeapon(WeaponId id) {
    final owned = weapon(id);
    if (owned != null) {
      owned.levelUp();
    } else {
      add(_createWeapon(id));
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
    if (other is Enemy) takeDamage(other.contactDamage);
  }

  void takeDamage(double amount) {
    if (_invulnerable > 0 || isDead) return;
    hp = (hp - amount * character.damageTakenMultiplier).clamp(0, maxHp);
    _invulnerable = Balance.playerInvulnerableTime;
    game.stats.hp.value = hp;
    if (isDead) game.onPlayerDied();
  }
}
