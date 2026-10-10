import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'class_passives.dart';
import 'inventory.dart';
import 'progress.dart';
import 'save_snapshot.dart';
import 'settings.dart';
import 'upgrades.dart';

/// 기기에 저장되는 플레이어 기록 전부.
class Profile {
  Profile({
    Inventory? inventory,
    Progress? progress,
    Settings? settings,
    Upgrades? upgrades,
    Mastery? mastery,
    DateTime? modifiedAt,
  }) : inventory = inventory ?? Inventory(),
       progress = progress ?? Progress(),
       settings = settings ?? Settings(),
       upgrades = upgrades ?? Upgrades(),
       mastery = mastery ?? Mastery() {
    _modifiedAt = modifiedAt;
    // 저장소에는 밀리초까지만 남으니 처음부터 밀리초로 맞춰 둔다
    // (안 그러면 같은 기록도 시각이 달라 보여 충돌로 오인한다).
    changes.addListener(
      () => _modifiedAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  final Inventory inventory;
  final Progress progress;
  final Settings settings;

  /// 화톳불 영구 강화.
  final Upgrades upgrades;

  /// 직업 숙련과 직업 패시브.
  final Mastery mastery;

  /// 클라우드에 함께 올리는 기록(재화 · 장비 · 진행도 · 화톳불)이 바뀔 때 알린다.
  /// 설정은 기기마다 다를 수 있어 빠진다.
  late final Listenable changes = Listenable.merge([
    inventory,
    progress,
    upgrades,
    mastery,
  ]);

  DateTime? _modifiedAt;

  /// [changes] 의 기록이 마지막으로 바뀐 시각. 한 번도 바뀌지 않았으면 null.
  DateTime? get modifiedAt => _modifiedAt;

  /// 클라우드에 올릴 세이브 한 벌.
  SaveSnapshot snapshot() => SaveSnapshot(
    savedAt: _modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    records: {
      inventoryKey: inventory.toJson(),
      progressKey: progress.toJson(),
      upgradesKey: upgrades.toJson(),
      masteryKey: mastery.toJson(),
    },
  );

  /// [snapshot] 으로 기기 기록을 덮어쓰고 새로 불러온다. 설정은 그대로 둔다.
  /// 지금 [Profile] 은 더 쓰지 않고 돌려받은 것으로 바꿔 끼워야 한다.
  static Future<Profile> restore(SaveSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in syncedKeys) {
      final record = snapshot.records[key];
      if (record == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(record));
      }
    }
    await prefs.setInt(modifiedAtKey, snapshot.savedAt.millisecondsSinceEpoch);
    return load();
  }

  /// 형식이 바뀌면 키를 올린다. 이제는 세이브를 이어 가야 하므로, 키를 올릴 때는
  /// 예전 키를 읽어 새 형식으로 옮기는 코드를 함께 넣는다 (CLAUDE.md "세이브 호환").
  static const inventoryKey = 'inventory.v4';
  static const progressKey = 'progress.v1';
  static const settingsKey = 'settings.v1';
  static const upgradesKey = 'upgrades.v1';
  static const masteryKey = 'mastery.v1';

  /// 클라우드에 함께 올리는 기록의 키.
  static const syncedKeys = [
    inventoryKey,
    progressKey,
    upgradesKey,
    masteryKey,
  ];

  /// [modifiedAt] 을 남겨 두는 키 (밀리초).
  static const modifiedAtKey = 'profile.modifiedAt';

  /// 저장된 기록을 불러오고, 바뀔 때마다 바로 저장하게 한다.
  static Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modified = prefs.getInt(modifiedAtKey);
    final profile = Profile(
      modifiedAt: modified == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modified),
      inventory: _bind(
        prefs,
        inventoryKey,
        Inventory.fromJson,
        Inventory.new,
        (v) => v.toJson(),
      ),
      progress: _bind(
        prefs,
        progressKey,
        Progress.fromJson,
        Progress.new,
        (v) => v.toJson(),
      ),
      settings: _bind(
        prefs,
        settingsKey,
        Settings.fromJson,
        Settings.new,
        (v) => v.toJson(),
      ),
      upgrades: _bind(
        prefs,
        upgradesKey,
        Upgrades.fromJson,
        Upgrades.new,
        (v) => v.toJson(),
      ),
      mastery: _bind(
        prefs,
        masteryKey,
        Mastery.fromJson,
        Mastery.new,
        (v) => v.toJson(),
      ),
    );
    // 생성자에서 먼저 [modifiedAt] 을 갱신하고, 여기서 그 값을 남긴다.
    profile.changes.addListener(
      () => prefs.setInt(
        modifiedAtKey,
        profile.modifiedAt!.millisecondsSinceEpoch,
      ),
    );
    return profile;
  }

  static T _bind<T extends ChangeNotifier>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
    T Function() empty,
    Map<String, dynamic> Function(T) toJson,
  ) {
    final saved = prefs.getString(key);
    T value;
    try {
      value = saved == null
          ? empty()
          : fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on Object catch (e) {
      // 깨진 기록 때문에 앱이 켜지지도 않는 일은 없게 한다. 원본은 [brokenSuffix]
      // 키에 남겨 두고 빈 기록으로 시작한다 (덮어쓰기 전에 살릴 수 있도록).
      debugPrint('$key 기록을 읽지 못해 새로 시작합니다: $e');
      unawaited(prefs.setString('$key$brokenSuffix', saved!));
      value = empty();
    }
    value.addListener(() => prefs.setString(key, jsonEncode(toJson(value))));
    return value;
  }

  /// 읽지 못한 기록을 남겨 두는 키 꼬리표.
  static const brokenSuffix = '.broken';
}
