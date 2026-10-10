import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../equipment/equipment_panel.dart';

/// 런 중 장비 화면. 여는 동안 게임은 멈춘다.
class EquipmentOverlay extends StatelessWidget {
  const EquipmentOverlay({super.key, required this.game});

  final AshbornGame game;

  @override
  Widget build(BuildContext context) => EquipmentPanel(
    inventory: game.inventory,
    character: game.character,
    extra: game.profile.permanentBonus,
    amplify: game.profile.upgrades.amplify,
    settings: game.settings,
    onClose: game.closeEquipment,
  );
}
