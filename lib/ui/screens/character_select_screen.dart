import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../equipment/equipment_screen.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/title_art.dart';
import 'game_screen.dart';

class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  CharacterDef _selected = Roster.all.first;

  void _depart() =>
      Navigator.of(context).push(fadeRoute(GameScreen(character: _selected)));

  void _openEquipment() =>
      Navigator.of(context)
          .push(fadeRoute(EquipmentScreen(character: _selected)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: BlurredArt(dim: 0.65)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        for (final c in Roster.all)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: _CharacterCard(
                                character: c,
                                selected: c == _selected,
                                onTap: () => c == _selected
                                    ? _depart()
                                    : setState(() => _selected = c),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    children: [
                      AshButton(
                        key: const Key('open-equipment'),
                        label: '장비',
                        icon: Icons.backpack,
                        fontSize: 17,
                        onPressed: _openEquipment,
                      ),
                      AshButton(
                        key: const Key('depart'),
                        label: '출정하기',
                        icon: Icons.local_fire_department,
                        fontSize: 17,
                        onPressed: _depart,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: '뒤로',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AshColors.gold),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('누구로 다시 일어설 것인가', style: ashTitleStyle(20)),
              const Text(
                '재 속에서 깨어날 애쉬본을 선택하세요',
                style: TextStyle(color: AshColors.ash, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final CharacterDef character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = character.color;
    return Semantics(
      button: true,
      selected: selected,
      label: character.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1 : 0.94,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0.62,
            duration: const Duration(milliseconds: 220),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: AshColors.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AshColors.gold : const Color(0x33E8C887),
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 24,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Portrait(character: character)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoLine(
                          icon: Icons.whatshot,
                          color: accent,
                          text:
                              '${character.weaponName} · '
                              '${character.weaponDescription}',
                        ),
                        const SizedBox(height: 2),
                        _InfoLine(
                          icon: Icons.auto_awesome,
                          color: AshColors.gold,
                          text: character.trait,
                        ),
                        const SizedBox(height: 6),
                        _Ratings(character: character),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.character});

  final CharacterDef character;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          character.portrait,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.3),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xAA000000),
                Colors.transparent,
                Colors.transparent,
                AshColors.panel,
              ],
              stops: [0, 0.18, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.role,
                style: TextStyle(
                  color: character.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                character.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ashTitleStyle(18).copyWith(letterSpacing: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AshColors.parchment, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _Ratings extends StatelessWidget {
  const _Ratings({required this.character});

  final CharacterDef character;

  @override
  Widget build(BuildContext context) {
    final r = character.ratings;
    return Row(
      children: [
        _Rating(label: '체력', value: r.hp, color: character.color),
        _Rating(label: '속도', value: r.speed, color: character.color),
        _Rating(label: '화력', value: r.power, color: character.color),
      ],
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AshColors.ash, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: i < value ? color : const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}
