import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  runApp(const AshbornApp());
}

class AshbornApp extends StatelessWidget {
  const AshbornApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ashborn',
      debugShowCheckedModeBanner: false,
      theme: buildAshTheme(),
      home: const SplashScreen(),
    );
  }
}
