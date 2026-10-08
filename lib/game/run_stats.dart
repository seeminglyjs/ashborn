import 'package:flutter/foundation.dart';

/// 현재 런의 상태. Flutter 오버레이(HUD, 게임 오버)가 구독한다.
class RunStats {
  final hp = ValueNotifier<double>(0);
  final maxHp = ValueNotifier<double>(1);
  final elapsedSeconds = ValueNotifier<int>(0);
  final kills = ValueNotifier<int>(0);
  final level = ValueNotifier<int>(1);
  final xp = ValueNotifier<double>(0);
  final xpToNext = ValueNotifier<double>(1);

  void reset({required double maxHp, required double xpToNext}) {
    this.maxHp.value = maxHp;
    hp.value = maxHp;
    elapsedSeconds.value = 0;
    kills.value = 0;
    level.value = 1;
    xp.value = 0;
    this.xpToNext.value = xpToNext;
  }
}
