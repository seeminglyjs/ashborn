import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/inventory.dart';
import 'data/inventory_store.dart';
import 'ui/inventory_scope.dart';
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
  final inventory = await InventoryStore.load();
  runApp(AshbornApp(inventory: inventory));
}

class AshbornApp extends StatelessWidget {
  const AshbornApp({super.key, required this.inventory});

  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    return InventoryScope(
      inventory: inventory,
      child: MaterialApp(
        title: 'Ashborn',
        debugShowCheckedModeBanner: false,
        theme: buildAshTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
