import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/profile.dart';
import 'data/save_snapshot.dart';
import 'services/audio.dart';
import 'services/cloud_save.dart';
import 'services/cloud_sync.dart';
import 'ui/profile_scope.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 모바일은 세로 고정, 전체 화면. 데스크톱에서는 무시된다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final profile = await Profile.load();
  // 효과음은 기다리지 않는다. 다 읽기 전에 난 소리는 건너뛴다.
  unawaited(GameAudio.start(profile.settings));
  runApp(AshbornApp(profile: profile));
}

/// 앱 뿌리. 클라우드 기록을 내려받으면 새 [Profile] 로 바꿔 끼우고 첫 화면부터 다시 연다.
class AshbornApp extends StatefulWidget {
  const AshbornApp({
    super.key,
    required this.profile,
    this.cloud = const UnconfiguredCloudSave(),
  });

  final Profile profile;

  /// 클라우드 저장소. Firebase 를 연결하면 여기에 바꿔 끼운다 ([CloudSaveBackend]).
  final CloudSaveBackend cloud;

  @override
  State<AshbornApp> createState() => _AshbornAppState();
}

class _AshbornAppState extends State<AshbornApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late Profile _profile = widget.profile;
  late final _cloud = CloudSync(
    backend: widget.cloud,
    profile: _profile,
    onRestore: _restore,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_cloud.start());
  }

  Future<Profile> _restore(SaveSnapshot snapshot) async {
    final profile = await Profile.restore(snapshot);
    if (!mounted) return profile;
    setState(() => _profile = profile);
    GameAudio.settings = profile.settings;
    // 화면들이 예전 기록을 들고 있지 않게 첫 화면부터 다시 연다.
    await _navigator.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (_) => false,
    );
    return profile;
  }

  @override
  void dispose() {
    _cloud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScope(
      profile: _profile,
      cloud: _cloud,
      child: MaterialApp(
        navigatorKey: _navigator,
        title: 'Ashborn',
        debugShowCheckedModeBanner: false,
        theme: buildAshTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
