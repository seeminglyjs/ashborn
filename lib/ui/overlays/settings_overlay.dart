import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../settings/settings_panel.dart';

/// 런 중 설정. 여는 동안 게임은 멈춘다.
class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({super.key, required this.game});

  final AshbornGame game;

  @override
  Widget build(BuildContext context) =>
      SettingsPanel(settings: game.settings, onClose: game.closeSettings);
}
