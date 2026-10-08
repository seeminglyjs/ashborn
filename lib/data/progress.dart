import 'package:flutter/foundation.dart';

import 'stages.dart';

/// 스테이지 진행도. 모든 캐릭터가 함께 쓴다.
class Progress extends ChangeNotifier {
  Progress([this._bestCleared = -1]);

  factory Progress.fromJson(Map<String, dynamic> json) =>
      Progress(json['bestCleared'] as int);

  int _bestCleared;

  /// 가장 멀리 클리어한 스테이지. 아직 없으면 null.
  Stage? get bestCleared => _bestCleared < 0 ? null : Stage(_bestCleared);

  /// 도전할 수 있는 가장 먼 스테이지: 클리어한 다음 스테이지.
  Stage get unlocked => Stage(_bestCleared + 1);

  bool isUnlocked(Stage stage) => stage.index <= unlocked.index;

  void recordClear(Stage stage) {
    if (stage.index <= _bestCleared) return;
    _bestCleared = stage.index;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {'bestCleared': _bestCleared};
}
