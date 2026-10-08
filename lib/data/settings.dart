import 'package:flutter/foundation.dart';

import 'equipment.dart';

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
    .._vibration = json['vibration'] as bool;

  bool _lootNotices = true;
  Rarity _lootNoticeMinRarity = Rarity.normal;
  bool _eventNotices = true;
  double _musicVolume = 0.8;
  double _sfxVolume = 0.8;
  bool _vibration = true;

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
  };
}
