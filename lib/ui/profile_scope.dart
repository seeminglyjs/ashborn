import 'package:flutter/widgets.dart';

import '../data/profile.dart';
import '../services/cloud_sync.dart';

/// 앱 전체가 공유하는 플레이어 기록과 클라우드 저장.
class ProfileScope extends InheritedWidget {
  const ProfileScope({
    super.key,
    required this.profile,
    this.cloud,
    required super.child,
  });

  final Profile profile;

  /// 클라우드 저장. 테스트처럼 앱 전체를 띄우지 않으면 null.
  final CloudSync? cloud;

  static Profile of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProfileScope>()!.profile;

  static CloudSync? cloudOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProfileScope>()?.cloud;

  @override
  bool updateShouldNotify(ProfileScope oldWidget) =>
      profile != oldWidget.profile || cloud != oldWidget.cloud;
}
