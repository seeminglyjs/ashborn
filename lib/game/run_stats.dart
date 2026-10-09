import 'package:flutter/foundation.dart';

import '../data/stages.dart';

/// 현재 런의 상태. Flutter 오버레이(HUD, 게임 오버)가 구독한다.
class RunStats {
  final hp = ValueNotifier<double>(0);
  final maxHp = ValueNotifier<double>(1);
  final energyShield = ValueNotifier<double>(0);
  final maxEnergyShield = ValueNotifier<double>(0);
  final elapsedSeconds = ValueNotifier<int>(0);
  final kills = ValueNotifier<int>(0);
  final level = ValueNotifier<int>(1);
  final xp = ValueNotifier<double>(0);
  final xpToNext = ValueNotifier<double>(1);

  final stage = ValueNotifier<Stage>(Stage.first);

  /// 보스가 나오기까지 남은 초.
  final bossCountdown = ValueNotifier<int>(0);

  /// 살아 있는 보스의 남은 체력 비율. 보스가 없으면 null.
  final bossHealth = ValueNotifier<double?>(null);

  /// 보스를 잡아야 하는 남은 초.
  final bossTimeLeft = ValueNotifier<int>(0);
  final stageCleared = ValueNotifier<bool>(false);

  /// 체력은 [Player] 가 로드될 때 채운다.
  void reset({required double xpToNext}) {
    elapsedSeconds.value = 0;
    kills.value = 0;
    level.value = 1;
    xp.value = 0;
    this.xpToNext.value = xpToNext;
  }
}
