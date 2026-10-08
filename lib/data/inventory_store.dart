import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'inventory.dart';

/// 인벤토리를 기기에 저장한다. 바뀔 때마다 바로 쓴다.
abstract final class InventoryStore {
  static const _key = 'inventory';

  static Future<Inventory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final inventory = saved == null
        ? Inventory()
        : Inventory.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    inventory.addListener(
      () => prefs.setString(_key, jsonEncode(inventory.toJson())),
    );
    return inventory;
  }
}
