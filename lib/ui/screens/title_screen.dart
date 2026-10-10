import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../services/audio.dart';
import '../routes.dart';
import '../settings/settings_screen.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/dungeon_backdrop.dart';
import '../widgets/ember_field.dart';
import '../widgets/fire_light.dart';
import '../widgets/pixel_sprite.dart';
import 'character_select_screen.dart';

/// 메인 화면. 던전 바닥의 화톳불 둘레에 세 애쉬본이 서 있고, 위에 로고가 뜬다.
/// 배경 · 인물 · 불은 모두 픽셀 스프라이트이고 로고와 버튼은 코드로 그린다.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  void initState() {
    super.initState();
    GameAudio.music(Bgm.title);
  }

  Future<void> _start(BuildContext context) async {
    await Navigator.of(context).push(fadeRoute(const CharacterSelectScreen()));
    GameAudio.music(Bgm.title);
  }

  void _openSettings(BuildContext context) =>
      Navigator.of(context).push(fadeRoute(const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AshColors.night,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final px = PixelScene.pixelFor(size);
          final tile = PixelScene.tile * px;
          // 화톳불 밑동. 인물들도 이 높이에 발을 딛는다.
          final base = Offset(size.width / 2, size.height * 0.64);
          final fireTop = base.dy - 24 * px;
          // 세로 화면이라 로고 크기는 폭에 맞춘다.
          final logo = (size.width * 0.17).clamp(34.0, 96.0);

          Widget hero(
            CharacterDef c,
            double dx,
            double dy, {
            required bool flip,
            required int phase,
          }) => Positioned(
            left: base.dx + dx * tile - heroFrame.width / 2 * px,
            top: base.dy + dy * tile - 28 * px,
            child: PixelSprite(
              asset: 'assets/images/${c.sprite}',
              frameSize: heroFrame,
              count: 4,
              fps: 6,
              scale: px,
              flip: flip,
              phase: phase,
            ),
          );

          return Stack(
            children: [
              Positioned.fill(
                child: DungeonBackdrop(
                  pixel: px,
                  light: base.translate(0, -8 * px),
                  lightRadius: size.shortestSide * 0.75,
                ),
              ),
              Positioned.fill(
                child: FireLight(
                  center: base.translate(0, -10 * px),
                  radius: 40 * px,
                ),
              ),
              hero(Roster.knight, -2.3, 0, flip: false, phase: 0),
              hero(Roster.witch, 2.3, -0.7, flip: true, phase: 2),
              hero(Roster.hunter, 1.5, 0.6, flip: true, phase: 1),
              Positioned(
                left: base.dx - 8 * px,
                top: fireTop,
                child: PixelSprite(
                  asset: PixelScene.campfireAsset,
                  frameSize: const Size(16, 24),
                  count: 6,
                  fps: 10,
                  scale: px,
                ),
              ),
              Positioned.fill(
                child: EmberField(
                  origin: Offset(base.dx, fireTop + 6 * px),
                  spread: 5 * px,
                  rate: 14,
                  rise: size.height * 0.5,
                  scale: (px / 3).clamp(0.6, 1.6),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: size.height * 0.08,
                child: Center(
                  // 벽 무늬 위에서도 글씨가 읽히도록 로고 뒤를 어둡게 한다.
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.7,
                        colors: [Color(0xE60B0908), Color(0x000B0908)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: logo * 0.5,
                        vertical: logo * 0.25,
                      ),
                      child: _Logo(size: logo),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: size.height * 0.06,
                child: Center(
                  child: AshButton(
                    key: const Key('title-start'),
                    label: '게임 시작',
                    fontSize: (logo * 0.36).clamp(16.0, 26.0),
                    onPressed: () => _start(context),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: IconButton(
                    key: const Key('title-settings'),
                    tooltip: '설정',
                    iconSize: (tile * 0.6).clamp(24.0, 40.0),
                    color: AshColors.gold,
                    icon: const Icon(Icons.settings),
                    onPressed: () => _openSettings(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 픽셀 글꼴 로고. 한글 이름 아래에 영문 이름과 한 줄 문구.
class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('애쉬본', style: ashTitleStyle(size).copyWith(height: 1.1)),
        Text(
          'A S H B O R N',
          style: TextStyle(
            color: AshColors.parchment,
            fontFamily: pixelFont,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.3,
            letterSpacing: size * 0.05,
            shadows: const [Shadow(color: Colors.black, offset: Offset(0, 2))],
          ),
        ),
        SizedBox(height: size * 0.12),
        Text(
          '재에서 다시 태어나는 자',
          style: TextStyle(
            color: AshColors.ash,
            fontFamily: pixelFont,
            fontWeight: FontWeight.w700,
            fontSize: (size * 0.22).clamp(11.0, 18.0),
            shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1))],
          ),
        ),
      ],
    );
  }
}
