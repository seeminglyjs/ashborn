import 'dart:math' as math;
import 'dart:ui';

import '../../data/balance.dart';

/// 원소 피해가 쌓여 상태가 바뀐 결과 (냉기).
enum ColdStage { none, chilled, frozen }

/// 적에게 걸린 상태이상.
///
/// - 중독: 지속 피해 + 이동 · 공격 속도 소폭 감소. 새로 걸리면 마지막 것으로 덮어쓴다.
///   가끔 옆의 적에게 옮는다.
/// - 출혈: 시간이 갈수록 세지는 지속 피해. 출혈 중에 맞으면 추가 피해 ([hitTakenMultiplier]).
/// - 점화: 화염 피해가 쌓여 문턱을 넘으면 불이 붙어 일정 간격으로 탄다. 옆의 적에게 옮는다.
/// - 냉각 → 동결: 냉기 피해가 쌓이면 냉각(느려짐), 냉각 중에 또 쌓이면 동결(움직이지 못함).
/// - 감전: 번개 피해가 쌓이면 잠깐 굳는다 (연쇄 번개는 [Player] 가 쏜다).
///
/// 문턱은 적마다 다르다 ([Enemy.ailmentThreshold]). 쌓인 양은 시간이 지나면 조금씩 빠진다.
class Ailments {
  // 중독
  double _poisonDps = 0;
  double _poisonTime = 0;

  // 출혈: 처음 초당 피해와 걸린 뒤 지난 시간.
  double _bleedDps = 0;
  double _bleedAge = 0;
  double _bleedTime = 0;

  // 점화: 한 번 탈 때의 피해와 다음 탈 때까지 남은 시간.
  double _igniteTick = 0;
  double _igniteTime = 0;
  double _igniteClock = 0;
  double _fire = 0;

  // 냉기
  double _cold = 0;
  double _chillTime = 0;
  double _chillSlow = 0;
  double _frozenTime = 0;

  /// 동결시킨 타격의 냉기 피해. 얼어 있다 쓰러지면 파편 피해가 된다.
  double frozenCold = 0;

  // 번개
  double _lightning = 0;
  double _stunTime = 0;

  /// 전염 판정 시계. 1초마다 한 번씩 굴린다.
  double _spreadClock = 0;

  /// 이번 [tick] 에서 옆의 적에게 옮길 중독 · 점화. 적이 읽고 지운다.
  bool spreadPoison = false;
  bool spreadIgnite = false;

  bool get poisoned => _poisonTime > 0;
  bool get bleeding => _bleedTime > 0;
  bool get ignited => _igniteTime > 0;
  bool get chilled => _chillTime > 0;
  bool get frozen => _frozenTime > 0;
  bool get stunned => _stunTime > 0;

  /// 얼었거나 굳어서 움직이지도 공격하지도 못한다.
  bool get disabled => frozen || stunned;

  double get poisonDps => _poisonDps;
  double get igniteTick => _igniteTick;

  /// 출혈의 지금 초당 피해 (시간이 갈수록 는다).
  double get bleedDps =>
      bleeding ? _bleedDps * (1 + Balance.bleedRamp * _bleedAge) : 0;

  /// 쌓인 화염 · 냉기 · 번개 (문턱 대비 비율을 보려면 문턱으로 나눈다).
  double get fireBuildup => _fire;
  double get coldBuildup => _cold;
  double get lightningBuildup => _lightning;

  /// 이동 속도 배율. 굳으면 0.
  double get speedMultiplier {
    if (disabled) return 0;
    var m = 1.0;
    if (chilled) m *= 1 - _chillSlow;
    if (poisoned) m *= 1 - Balance.poisonSlow;
    return m;
  }

  /// 공격 · 기술 준비 시간이 흐르는 빠르기. 굳으면 0.
  double get actionMultiplier => speedMultiplier;

  /// 직접 맞는 피해 배율. 출혈 중이면 더 아프다 (지속 피해에는 붙지 않는다).
  double get hitTakenMultiplier => bleeding ? 1 + Balance.bleedHitBonus : 1;

  /// 걸린 상태이상을 보여 줄 색. 없으면 null.
  Color? get tint {
    if (frozen) return const Color(0xFFBFF0FF);
    if (stunned) return const Color(0xFFFFE45C);
    if (ignited) return const Color(0xFFFF8A3D);
    if (poisoned) return const Color(0xFF7BD15A);
    if (chilled) return const Color(0xFF6FB8FF);
    if (bleeding) return const Color(0xFFC0392B);
    return null;
  }

  /// 중독: [total] 피해를 지속 시간 동안 나눠 준다. 이미 중독이면 새것으로 덮어쓴다.
  void poison(double total) {
    _poisonDps = total / Balance.poisonDuration;
    _poisonTime = Balance.poisonDuration;
  }

  /// 옆의 적에게서 옮은 중독: 같은 세기로 처음부터.
  void catchPoison(double dps) {
    _poisonDps = dps;
    _poisonTime = Balance.poisonDuration;
  }

  /// 출혈: [total] 은 세지기 전 기준 피해. 더 센 출혈이면 바꾸고, 아니면 시간만 새로 한다.
  void bleed(double total) {
    final dps = total / Balance.bleedDuration;
    if (!bleeding || dps >= _bleedDps) {
      _bleedDps = dps;
      _bleedAge = 0;
    }
    _bleedTime = Balance.bleedDuration;
  }

  /// 화염 피해 [amount] 를 쌓는다. 문턱을 넘으면 한 번에 [tick] 씩 타는 점화가 붙고 true.
  bool addFire(double amount, double threshold, double tick) {
    if (amount <= 0) return false;
    _fire += amount;
    if (_fire < threshold) return false;
    _fire = 0;
    ignite(tick);
    return true;
  }

  /// 점화를 붙인다. 이미 타고 있으면 더 센 쪽으로 바꾸고 시간을 새로 한다.
  void ignite(double tick) {
    if (!ignited || tick >= _igniteTick) _igniteTick = tick;
    if (!ignited) _igniteClock = Balance.igniteInterval;
    _igniteTime = Balance.igniteDuration;
  }

  /// 냉기 피해 [amount] 를 쌓는다. 문턱을 넘으면 냉각, 냉각 중에 또 넘으면 동결.
  /// 동결은 [freezeTime] 초. [cold] 는 동결 파편 피해로 기억해 둔다.
  ColdStage addCold(
    double amount,
    double threshold, {
    required double cold,
    double freezeTime = Balance.freezeDuration,
  }) {
    if (amount <= 0 || frozen) return ColdStage.none;
    _cold += amount;
    if (_cold < threshold) return ColdStage.none;
    _cold = 0;
    if (!chilled) {
      chill(Balance.chillSlow, Balance.chillDuration);
      return ColdStage.chilled;
    }
    _frozenTime = freezeTime;
    frozenCold = cold;
    // 녹은 뒤에도 남은 냉각 시간 동안은 느리다.
    _chillTime = math.max(_chillTime, freezeTime + 0.5);
    return ColdStage.frozen;
  }

  /// 냉각(느려짐)을 건다. 서리 갑옷 · 지옥불 고리처럼 냉기 축적 없이 바로 거는 것도 여기로 온다.
  void chill(double slow, double duration) {
    _chillSlow = chilled ? math.max(_chillSlow, slow) : slow;
    _chillTime = math.max(_chillTime, duration);
  }

  /// 번개 피해 [amount] 를 쌓는다. 문턱을 넘으면 [stun] 초 굳고 true (감전).
  bool addLightning(double amount, double threshold, {double? stun}) {
    if (amount <= 0) return false;
    _lightning += amount;
    if (_lightning < threshold) return false;
    _lightning = 0;
    _stunTime = math.max(_stunTime, stun ?? Balance.shockStun);
    return true;
  }

  /// [dt] 동안 들어간 지속 피해의 합. [threshold] 는 쌓인 원소가 빠지는 빠르기의 기준.
  /// 전염할 차례면 [spreadPoison] · [spreadIgnite] 를 켠다.
  double tick(double dt, {double threshold = 0, math.Random? random}) {
    var damage = 0.0;
    if (poisoned) {
      damage += _poisonDps * math.min(dt, _poisonTime);
      _poisonTime -= dt;
    }
    if (bleeding) {
      damage += bleedDps * math.min(dt, _bleedTime);
      _bleedAge += dt;
      _bleedTime -= dt;
    }
    if (ignited) {
      _igniteClock -= dt;
      while (_igniteClock <= 0 && _igniteTime > 0) {
        damage += _igniteTick;
        _igniteClock += Balance.igniteInterval;
      }
      _igniteTime -= dt;
    }
    if (_chillTime > 0) _chillTime -= dt;
    if (_frozenTime > 0) _frozenTime -= dt;
    if (_stunTime > 0) _stunTime -= dt;

    // 쌓인 원소는 시간이 지나면 빠진다 (드문드문 맞는 것으로는 터지지 않게).
    final decay = threshold * Balance.ailmentDecay * dt;
    _fire = math.max(0, _fire - decay);
    _cold = math.max(0, _cold - decay);
    _lightning = math.max(0, _lightning - decay);

    if ((poisoned || ignited) && random != null) {
      _spreadClock += dt;
      while (_spreadClock >= 1) {
        _spreadClock -= 1;
        if (poisoned && random.nextDouble() < Balance.poisonSpreadChance) {
          spreadPoison = true;
        }
        if (ignited && random.nextDouble() < Balance.igniteSpreadChance) {
          spreadIgnite = true;
        }
      }
    } else {
      _spreadClock = 0;
    }
    return damage;
  }
}
