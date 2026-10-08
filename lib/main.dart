import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/ashborn_game.dart';

void main() {
  runApp(const AshbornApp());
}

class AshbornApp extends StatelessWidget {
  const AshbornApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ashborn',
      debugShowCheckedModeBanner: false,
      home: GameWidget(game: AshbornGame()),
    );
  }
}
