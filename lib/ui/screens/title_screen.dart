import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme.dart';
import '../widgets/ember_field.dart';
import '../widgets/fire_light.dart';
import '../widgets/title_art.dart';
import 'character_select_screen.dart';

/// 메인 화면. 원화 위에 화톳불 불빛과 불씨를 얹고, 원화의 버튼 자리에 터치 영역을 둔다.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  void _start(BuildContext context) =>
      Navigator.of(context).push(fadeRoute(const CharacterSelectScreen()));

  void _openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AshColors.panel,
        title: Text('설정', style: ashTitleStyle(20)),
        content: const Text(
          '사운드, 진동 등 설정은 준비 중이에요.',
          style: TextStyle(color: AshColors.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기', style: TextStyle(color: AshColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final art = ArtSpace(constraints.biggest);
          final fire = art.point(TitleArt.fire);
          return Stack(
            children: [
              const Positioned.fill(child: BlurredArt()),
              Positioned.fromRect(
                rect: art.rect,
                child: Image.asset(TitleArt.asset, fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: FireLight(center: fire, radius: 260 * art.scale),
              ),
              Positioned.fill(
                child: EmberField(
                  origin: fire.translate(0, -30 * art.scale),
                  spread: 120 * art.scale,
                  rate: 14,
                  rise: 420 * art.scale,
                  scale: art.scale.clamp(0.5, 1.5),
                ),
              ),
              Positioned.fromRect(
                rect: art.area(TitleArt.startButton),
                child: _ArtHotspot(
                  key: const Key('title-start'),
                  label: '게임 시작',
                  radius: 10 * art.scale,
                  pulse: true,
                  onTap: () => _start(context),
                ),
              ),
              Positioned.fromRect(
                rect: art.area(TitleArt.settingsButton),
                child: _ArtHotspot(
                  key: const Key('title-settings'),
                  label: '설정',
                  radius: 999,
                  onTap: () => _openSettings(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 원화에 그려진 버튼 위에 겹치는 투명 터치 영역. 누르거나 올리면 빛난다.
class _ArtHotspot extends StatefulWidget {
  const _ArtHotspot({
    super.key,
    required this.label,
    required this.onTap,
    required this.radius,
    this.pulse = false,
  });

  final String label;
  final VoidCallback onTap;
  final double radius;
  final bool pulse;

  @override
  State<_ArtHotspot> createState() => _ArtHotspotState();
}

class _ArtHotspotState extends State<_ArtHotspot>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _hover = false;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final lit = _down ? 1.0 : (_hover ? 0.75 : _pulse.value * 0.35);
              return AnimatedScale(
                scale: _down ? 0.97 : 1,
                duration: const Duration(milliseconds: 90),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    color: Colors.white.withValues(alpha: 0.06 * lit),
                    boxShadow: [
                      BoxShadow(
                        color: AshColors.ember.withValues(alpha: 0.45 * lit),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
