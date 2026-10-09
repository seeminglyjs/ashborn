import 'package:flutter/material.dart';

import '../profile_scope.dart';
import 'settings_panel.dart';

/// 타이틀에서 여는 설정 화면.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SettingsPanel(
      settings: ProfileScope.of(context).settings,
      cloud: ProfileScope.cloudOf(context),
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
