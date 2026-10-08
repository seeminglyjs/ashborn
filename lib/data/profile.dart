import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inventory.dart';
import 'progress.dart';

/// 기기에 저장되는 플레이어 기록 전부.
class Profile {
  Profile({Inventory? inventory, Progress? progress})
    : inventory = inventory ?? Inventory(),
      progress = progress ?? Progress();

  final Inventory inventory;
  final Progress progress;

  /// 형식이 바뀌면 키를 올린다. 예전 형식은 읽지 않는다.
  static const inventoryKey = 'inventory.v4';
  static const progressKey = 'progress.v1';

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
    final value = saved == null
        ? empty()
        : fromJson(jsonDecode(saved) as Map<String, dynamic>);
    value.addListener(() => prefs.setString(key, jsonEncode(toJson(value))));
    return value;
  }
}
