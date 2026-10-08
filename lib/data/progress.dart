import 'package:flutter/foundation.dart';

import 'characters.dart';
import 'inventory.dart';
import 'stages.dart';

/// 진행도: 스테이지와 해금한 캐릭터. 모든 캐릭터가 함께 쓴다.
class Progress extends ChangeNotifier {
  Progress([this._bestCleared = -1, Set<CharacterId>? characters])
    : _characters = {...?characters};

  factory Progress.fromJson(Map<String, dynamic> json) =>
      Progress(json['bestCleared'] as int, {
        for (final name in json['characters'] as List? ?? const [])
          ?CharacterId.values.asNameMap()[name],
      });

  int _bestCleared;

  /// 골드로 해금한 캐릭터.
  final Set<CharacterId> _characters;

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

  /// 무료이거나 해금한 캐릭터.
  bool owns(CharacterDef character) =>
      character.price == 0 || _characters.contains(character.id);

  bool canUnlock(CharacterDef character, Inventory inventory) =>
      !owns(character) && inventory.gold >= character.price;

  /// [inventory] 의 골드로 [character] 를 해금한다.
  void unlock(CharacterDef character, Inventory inventory) {
    assert(canUnlock(character, inventory), '골드가 모자라거나 이미 해금했다');
    inventory.spendGold(character.price);
    _characters.add(character.id);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'bestCleared': _bestCleared,
    'characters': [for (final id in _characters) id.name],
  };
}
