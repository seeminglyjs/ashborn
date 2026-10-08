import 'package:flutter/widgets.dart';

import '../data/inventory.dart';

/// 앱 전체가 공유하는 인벤토리.
class InventoryScope extends InheritedWidget {
  const InventoryScope({
    super.key,
    required this.inventory,
    required super.child,
  });

  final Inventory inventory;

  static Inventory of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<InventoryScope>()!.inventory;

  @override
  bool updateShouldNotify(InventoryScope oldWidget) =>
      inventory != oldWidget.inventory;
}
