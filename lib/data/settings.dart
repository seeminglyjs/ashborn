import 'package:flutter/foundation.dart';

import 'equipment.dart';

/// 일괄 분해 · 자동 분해가 처음 고르고 있는 등급.
const defaultSalvageRarities = {Rarity.normal, Rarity.rare};

/// 기본 설정. 바뀌면 바로 저장된다 ([Profile]).
class Settings extends ChangeNotifier {
  Settings();

  factory Settings.fromJson(Map<String, dynamic> json) => Settings()
    .._lootNotices = json['lootNotices'] as bool
    .._lootNoticeMinRarity = Rarity.values.byName(
      json['lootNoticeMinRarity'] as String,
    )
    .._eventNotices = json['eventNotices'] as bool
    .._musicVolume = (json['musicVolume'] as num).toDouble()
    .._sfxVolume = (json['sfxVolume'] as num).toDouble()
    .._vibration = json['vibration'] as bool
    // 아래는 나중에 더한 값이라 예전 세이브에는 없다 (없으면 기본값).
    .._salvageRarities = switch (json['salvageRarities']) {
      final List<dynamic> names => {
        for (final name in names) ?Rarity.values.asNameMap()[name],
      },
      _ => {...defaultSalvageRarities},
    }
    .._salvageKeepUpgraded = json['salvageKeepUpgraded'] as bool? ?? true
    .._autoSalvage = json['autoSalvage'] as bool? ?? false;

  bool _lootNotices = true;
  Rarity _lootNoticeMinRarity = Rarity.normal;
  bool _eventNotices = true;
  double _musicVolume = 0.8;
  double _sfxVolume = 0.8;
  bool _vibration = true;
  Set<Rarity> _salvageRarities = {...defaultSalvageRarities};
  bool _salvageKeepUpgraded = true;
  bool _autoSalvage = false;

  /// 장비 획득 알림. [lootNoticeMinRarity] 이상만 알린다.
  bool get lootNotices => _lootNotices;
  set lootNotices(bool value) => _set(() => _lootNotices = value);

  Rarity get lootNoticeMinRarity => _lootNoticeMinRarity;
  set lootNoticeMinRarity(Rarity value) =>
      _set(() => _lootNoticeMinRarity = value);

  /// 보스 등장, 스테이지 클리어, 잔불, 가방 가득 등 진행 알림.
  bool get eventNotices => _eventNotices;
  set eventNotices(bool value) => _set(() => _eventNotices = value);

  /// 배경음과 효과음 볼륨 (0에서 1).
  double get musicVolume => _musicVolume;
  set musicVolume(double value) => _set(() => _musicVolume = value);

  double get sfxVolume => _sfxVolume;
  set sfxVolume(double value) => _set(() => _sfxVolume = value);

  /// 피격 시 진동 (모바일).
  bool get vibration => _vibration;
  set vibration(bool value) => _set(() => _vibration = value);

  /// 일괄 분해 · 자동 분해가 고르는 등급. 한 번 고르면 다음에도 그대로 남는다.
  Set<Rarity> get salvageRarities => Set.unmodifiable(_salvageRarities);
  set salvageRarities(Set<Rarity> value) =>
      _set(() => _salvageRarities = {...value});

  /// 일괄 분해에서 강화했거나 초월한 장비는 뺀다.
  bool get salvageKeepUpgraded => _salvageKeepUpgraded;
  set salvageKeepUpgraded(bool value) =>
      _set(() => _salvageKeepUpgraded = value);

  /// 자동 분해: [salvageRarities] 등급 장비를 주우면 가방에 넣지 않고 바로 잔불로 바꾼다.
  bool get autoSalvage => _autoSalvage;
  set autoSalvage(bool value) => _set(() => _autoSalvage = value);

  /// [rarity] 장비를 주우면 자동 분해하는가.
  bool autoSalvages(Rarity rarity) =>
      _autoSalvage && _salvageRarities.contains(rarity);

  bool showsLoot(Rarity rarity) =>
      _lootNotices && rarity.index >= _lootNoticeMinRarity.index;

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'lootNotices': _lootNotices,
    'lootNoticeMinRarity': _lootNoticeMinRarity.name,
    'eventNotices': _eventNotices,
    'musicVolume': _musicVolume,
    'sfxVolume': _sfxVolume,
    'vibration': _vibration,
    'salvageRarities': [
      for (final r in Rarity.values)
        if (_salvageRarities.contains(r)) r.name,
    ],
    'salvageKeepUpgraded': _salvageKeepUpgraded,
    'autoSalvage': _autoSalvage,
  };
}
