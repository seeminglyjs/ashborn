import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/profile.dart';
import 'ui/profile_scope.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 모바일은 가로 고정, 전체 화면. 데스크톱에서는 무시된다.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final profile = await Profile.load();
  runApp(AshbornApp(profile: profile));
}

class AshbornApp extends StatelessWidget {
  const AshbornApp({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return ProfileScope(
      profile: profile,
      child: MaterialApp(
        title: 'Ashborn',
        debugShowCheckedModeBanner: false,
        theme: buildAshTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
