import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../inventory_scope.dart';
import 'equipment_panel.dart';

/// 출발 전에 캐릭터의 장비를 확인하고 바꾸는 화면.
class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key, required this.character});

  final CharacterDef character;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: EquipmentPanel(
        inventory: InventoryScope.of(context),
        character: character,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
