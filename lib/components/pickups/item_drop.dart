import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/equipment.dart';
import '../../game/ashborn_game.dart';
import '../../services/audio.dart';
import '../../systems/auto_equip.dart';
import 'pickup.dart';

/// 바닥에 떨어진 장비. 부위 아이콘이 등급 색으로 빛나고, 높은 등급일수록 빛이 크다.
/// 영웅 이상은 아이콘 둘레가 맥박처럼 빛나고, 전설 이상은 하늘로 빛기둥이 솟는다.
class ItemDrop extends Pickup with HasGameReference<AshbornGame> {
  ItemDrop({required super.position, required this.item})
    : super(size: Vector2.all(16 * Balance.playerSpriteScale));

  final Item item;

  late final _glow = Paint()..color = item.rarity.color.withValues(alpha: 0.3);
  late final _body = Paint()..color = item.rarity.color;

  /// 영웅 0 부터 고유 3 까지. 영웅 미만은 음수.
  late final int _tier = item.rarity.index - Rarity.hero.index;

  /// 아이콘 모양 그대로 번지는 등급 색 빛 (영웅 이상).
  late final _aura = Paint()
    ..imageFilter = ImageFilter.blur(sigmaX: 3.0 + _tier, sigmaY: 3.0 + _tier);

  /// 전설 이상: 아이콘에서 위로 옅어지는 빛기둥.
  static const double _beamHeight = 110;
  late final _beam = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, -_beamHeight), [
      item.rarity.color.withValues(alpha: 0.45),
      item.rarity.color.withValues(alpha: 0),
    ]);

  /// 가방이 차도 자동 분해할 장비는 줍는다 (자리를 차지하지 않는다).
  @override
  bool get collectable => game.gear.canAdd(item) || _autoSalvages;

  /// 자동 분해할 장비: 설정에서 고른 등급이고, 빈 칸에 낄 수도 없고 지금 캐릭터의
  /// 전투력을 올리지도 않는다. 쓸 만한 장비를 실수로 잃지 않게 그런 것은 남긴다.
  bool get _autoSalvages =>
      game.settings.autoSalvages(item.rarity) &&
      game.gear.freeSlotFor(item) == null &&
      AutoEquip.gain(
            game.gear,
            item,
            game.character,
            extra: game.profile.permanentBonus,
          ) <=
          0;

  /// 떨어지는 순간 등급별 소리. 높은 등급일수록 길고 화려하다.
  @override
  void onMount() {
    super.onMount();
    GameAudio.play(Sfx.forRarity(item.rarity));
  }

  @override
  void collect() {
    if (_autoSalvages) {
      game.inventory.addEmber(item.salvageValue);
      game.notifyLoot(item, '${item.name} 자동 분해 · 잔불 +${item.salvageValue}');
      return;
    }
    GameAudio.play(Sfx.equip);
    final slot = game.gear.add(item);
    game.notifyLoot(item, '${item.name} 획득${slot == null ? '' : ' · 장착'}');
  }

  @override
  void onBlocked() =>
      game.notify('가방이 가득 찼습니다', color: const Color(0xFFFF6B35));

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final c = Offset(w / 2, w / 2);
    canvas.drawCircle(c, w * (0.35 + 0.1 * item.rarity.index), _glow);
    final sprite = game.props.gear(
      item.type,
      unique: item.rarity == Rarity.unique,
    );
    if (sprite == null) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w / 2, height: w / 2),
        _body,
      );
      return;
    }
    // 등급 색 받침 위에 아이콘이 둥실 떠 있다.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, w - 3), width: w * 0.7, height: 6),
      _body,
    );
    final at = Vector2(0, math.sin(_time * 4) * 2 - 3);
    if (_tier >= 1) {
      final beamWidth = w * (0.35 + 0.08 * _tier);
      canvas
        ..save()
        ..translate(w / 2, w - 3)
        ..drawRect(
          Rect.fromLTRB(-beamWidth / 2, -_beamHeight, beamWidth / 2, 0),
          _beam,
        )
        ..restore();
    }
    if (_tier >= 0) {
      final pulse = 0.6 + 0.4 * math.sin(_time * 3.5);
      _aura.colorFilter = ColorFilter.mode(
        item.rarity.color.withValues(alpha: pulse),
        BlendMode.srcIn,
      );
      final grow = 4.0 + _tier * 2;
      sprite.render(
        canvas,
        position: at - Vector2.all(grow / 2),
        size: size + Vector2.all(grow),
        overridePaint: _aura,
      );
    }
    sprite.render(canvas, position: at, size: size);
  }
}
