import 'package:flutter/foundation.dart';

import 'characters.dart';
import 'passives.dart';
import 'stages.dart';
import 'weapons.dart';

/// 이어 할 런: 스테이지를 클리어하고 화톳불로 돌아가면 남는다. 다음 출정 때 [stage] 처음부터
/// 레벨 · 경험치와 무기 · 패시브 카드를 그대로 이어 간다. 쓰러지거나 싸우는 도중에 나가면 지운다.
class RunSave {
  const RunSave({
    required this.stage,
    required this.level,
    required this.xp,
    required this.weapons,
    required this.passives,
    this.levelUps = 0,
  });

  factory RunSave.fromJson(Map<String, dynamic> json) => RunSave(
    stage: Stage(json['stage'] as int),
    level: json['level'] as int,
    xp: (json['xp'] as num).toDouble(),
    weapons: [
      for (final w in json['weapons'] as List<dynamic>)
        if (WeaponId.values.asNameMap()[(w as Map<String, dynamic>)['id']]
            case final id?)
          (
            id: id,
            level: w['level'] as int,
            awakened: w['awakened'] as bool? ?? false,
          ),
    ],
    passives: {
      for (final MapEntry(:key, :value)
          in (json['passives'] as Map<String, dynamic>).entries)
        ?PassiveId.values.asNameMap()[key]: value as int,
    },
    levelUps: json['levelUps'] as int? ?? 0,
  );

  /// 이어서 시작할 스테이지 (그 스테이지 처음부터).
  final Stage stage;
  final int level;
  final double xp;

  /// 가진 무기와 레벨 · 각성. 얻은 차례대로.
  final List<({WeaponId id, int level, bool awakened})> weapons;

  /// 가진 패시브와 레벨. 얻은 차례대로.
  final Map<PassiveId, int> passives;

  /// 오른 레벨 중 아직 카드를 고르지 않은 수. 이어 하면 바로 고른다.
  final int levelUps;

  Map<String, dynamic> toJson() => {
    'stage': stage.index,
    'level': level,
    'xp': xp,
    'weapons': [
      for (final w in weapons)
        {'id': w.id.name, 'level': w.level, 'awakened': w.awakened},
    ],
    'passives': {
      for (final MapEntry(:key, :value) in passives.entries) key.name: value,
    },
    'levelUps': levelUps,
  };
}

/// 캐릭터마다 하나씩 남는 이어 할 런. 전용 무기 카드가 직업마다 달라 따로 둔다.
class SavedRuns extends ChangeNotifier {
  SavedRuns([Map<CharacterId, RunSave>? runs]) : _runs = {...?runs};

  factory SavedRuns.fromJson(Map<String, dynamic> json) => SavedRuns({
    for (final MapEntry(:key, :value) in json.entries)
      ?CharacterId.values.asNameMap()[key]: RunSave.fromJson(
        value as Map<String, dynamic>,
      ),
  });

  final Map<CharacterId, RunSave> _runs;

  RunSave? of(CharacterId character) => _runs[character];

  void save(CharacterId character, RunSave run) {
    _runs[character] = run;
    notifyListeners();
  }

  void clear(CharacterId character) {
    if (_runs.remove(character) != null) notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    for (final MapEntry(:key, :value) in _runs.entries)
      key.name: value.toJson(),
  };
}
