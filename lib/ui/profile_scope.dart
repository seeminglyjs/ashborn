import 'package:flutter/widgets.dart';

import '../data/profile.dart';

/// 앱 전체가 공유하는 플레이어 기록.
class ProfileScope extends InheritedWidget {
  const ProfileScope({super.key, required this.profile, required super.child});

  final Profile profile;

  static Profile of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProfileScope>()!.profile;

  @override
  bool updateShouldNotify(ProfileScope oldWidget) =>
      profile != oldWidget.profile;
}
