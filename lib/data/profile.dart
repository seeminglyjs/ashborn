import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inventory.dart';
import 'progress.dart';
import 'settings.dart';
import 'upgrades.dart';

/// 기기에 저장되는 플레이어 기록 전부.
class Profile {
  Profile({
    Inventory? inventory,
    Progress? progress,
    Settings? settings,
    Upgrades? upgrades,
  }) : inventory = inventory ?? Inventory(),
       progress = progress ?? Progress(),
       settings = settings ?? Settings(),
       upgrades = upgrades ?? Upgrades();

  final Inventory inventory;
  final Progress progress;
  final Settings settings;

  /// 화톳불 영구 강화.
  final Upgrades upgrades;

  /// 형식이 바뀌면 키를 올린다. 예전 형식은 읽지 않는다.
  static const inventoryKey = 'inventory.v4';
  static const progressKey = 'progress.v1';
  static const settingsKey = 'settings.v1';
  static const upgradesKey = 'upgrades.v1';

  /// 저장된 기록을 불러오고, 바뀔 때마다 바로 저장하게 한다.
  static Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Profile(
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
    );
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
