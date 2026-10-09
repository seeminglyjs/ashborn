import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../data/stages.dart';
import '../equipment/equipment_screen.dart';
import '../hearth/hearth_screen.dart';
import '../profile_scope.dart';
import '../routes.dart';
import '../format.dart';
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

  /// 고른 스테이지. 처음엔 도전할 수 있는 가장 먼 스테이지.
  Stage? _stage;

  Stage get _currentStage =>
      _stage ?? ProfileScope.of(context).progress.unlocked;

  /// 아직 공개하지 않은 캐릭터 자리. 앞으로 더 늘어난다는 느낌을 준다.
  static const upcoming = 3;

  bool get _owned => ProfileScope.of(context).progress.owns(_selected);

  Future<void> _depart() async {
    if (!_owned) return _unlock();
    await Navigator.of(
      context,
    ).push(fadeRoute(GameScreen(character: _selected, stage: _currentStage)));
    // 돌아오면 새로 열린 가장 먼 스테이지를 기본으로 보여 준다.
    if (mounted) setState(() => _stage = null);
  }

  /// 고른 캐릭터를 골드로 해금할지 묻고 해금한다.
  Future<void> _unlock() async {
    final profile = ProfileScope.of(context);
    final character = _selected;
    if (!profile.progress.canUnlock(character, profile.inventory)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AshColors.panel,
        title: Text(character.name, style: TextStyle(color: character.color)),
        content: Text(
          '골드 ${formatGold(character.price)}을(를) 써서 해금합니다.',
          style: const TextStyle(color: AshColors.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('confirm-unlock'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('해금', style: TextStyle(color: AshColors.gold)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => profile.progress.unlock(character, profile.inventory));
    }
  }

  void _openEquipment() =>
      Navigator.of(context)
          .push(fadeRoute(EquipmentScreen(character: _selected)));

  void _openHearth() =>
      Navigator.of(context).push(fadeRoute(const HearthScreen()));

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: BlurredArt(dim: 0.65)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  profile.inventory,
                  profile.progress,
                ]),
                builder: (context, _) => Column(
                  children: [
                    _Header(
                      gold: profile.inventory.gold,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _cards(profile.inventory.gold)),
                    const SizedBox(height: 8),
                    _StagePicker(
                      stage: _currentStage,
                      unlocked: profile.progress.unlocked,
                      onChanged: (stage) => setState(() => _stage = stage),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        AshButton(
                          key: const Key('open-hearth'),
                          label: '화톳불',
                          icon: Icons.upgrade,
                          fontSize: 17,
                          onPressed: _openHearth,
                        ),
                        AshButton(
                          key: const Key('open-equipment'),
                          label: '장비',
                          icon: Icons.backpack,
                          fontSize: 17,
                          onPressed: _openEquipment,
                        ),
                        if (_owned)
                          AshButton(
                            key: const Key('depart'),
                            label: '출정하기',
                            icon: Icons.local_fire_department,
                            fontSize: 17,
                            onPressed: _depart,
                          )
                        else
                          AshButton(
                            key: const Key('unlock'),
                            label: '해금 · 골드 ${formatGold(_selected.price)}',
                            icon: Icons.lock_open,
                            fontSize: 17,
                            onPressed:
                                profile.progress.canUnlock(
                                  _selected,
                                  profile.inventory,
                                )
                                ? _unlock
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 캐릭터 카드와 그 뒤의 공개 예정 카드. 넓으면 한 화면에 다 보이고,
  /// 좁으면 옆으로 넘겨 본다. 다음 카드가 살짝 보이도록 폭을 잡는다.
  Widget _cards(int gold) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth / 3.4).clamp(170.0, 260.0);
      final progress = ProfileScope.of(context).progress;
      return ListView(
        key: const Key('character-list'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in Roster.all)
            Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _CharacterCard(
                character: c,
                selected: c == _selected,
                locked: !progress.owns(c),
                gold: gold,
                onTap: () =>
                    c == _selected ? _depart() : setState(() => _selected = c),
              ),
            ),
          for (var i = 0; i < upcoming; i++)
            Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const _UpcomingCard(),
            ),
        ],
      );
    },
  );
}

/// 출정할 스테이지 고르기. 클리어한 다음 스테이지까지 고를 수 있다.
class _StagePicker extends StatelessWidget {
  const _StagePicker({
    required this.stage,
    required this.unlocked,
    required this.onChanged,
  });

  final Stage stage;
  final Stage unlocked;
  final ValueChanged<Stage> onChanged;

  @override
  Widget build(BuildContext context) {
    final canPrev = stage.index > 0;
    final canNext = stage.index < unlocked.index;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('stage-prev'),
          tooltip: '이전 스테이지',
          onPressed: canPrev ? () => onChanged(Stage(stage.index - 1)) : null,
          icon: const Icon(Icons.chevron_left),
          color: AshColors.gold,
        ),
        SizedBox(
          width: 230,
          child: Column(
            children: [
              Text(
                stage.name,
                key: const Key('stage-name'),
                style: TextStyle(
                  color: stage.corruption > 0
                      ? AshColors.ember
                      : AshColors.parchment,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Lv ${stage.level}'
                '${stage == unlocked ? ' · 최전선' : ''}',
                style: const TextStyle(color: AshColors.ash, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('stage-next'),
          tooltip: '다음 스테이지',
          onPressed: canNext ? () => onChanged(stage.next) : null,
          icon: const Icon(Icons.chevron_right),
          color: AshColors.gold,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.gold, required this.onBack});

  final int gold;
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
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '골드 ${formatGold(gold)}',
              key: const Key('select-gold'),
              style: const TextStyle(
                color: AshColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
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
    required this.locked,
    required this.gold,
    required this.onTap,
  });

  final CharacterDef character;
  final bool selected;

  /// 아직 해금하지 않았다. 해금 골드까지 얼마나 모았는지 보여 준다.
  final bool locked;
  final int gold;
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
                  Expanded(
                    child: _Portrait(
                      character: character,
                      lock: locked
                          ? _LockOverlay(price: character.price, gold: gold)
                          : null,
                    ),
                  ),
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
  const _Portrait({required this.character, this.lock});

  final CharacterDef character;

  /// 해금 전이면 그림 위, 이름 아래에 덮는다.
  final Widget? lock;

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
        ?lock,
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

/// 해금하지 않은 캐릭터 위에 덮는 자물쇠와 모은 골드.
/// 그림은 어둡게 가리고, 이름과 겹치지 않도록 위쪽에 놓는다.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.price, required this.gold});

  final int price;
  final int gold;

  @override
  Widget build(BuildContext context) {
    final ready = gold >= price;
    return ColoredBox(
      color: const Color(0x99000000),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    ready ? Icons.lock_open : Icons.lock,
                    color: AshColors.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${formatGold(gold.clamp(0, price))} / '
                        '${formatGold(price)}',
                        style: const TextStyle(
                          color: AshColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (gold / price).clamp(0, 1),
                  minHeight: 4,
                  color: AshColors.gold,
                  backgroundColor: const Color(0x33FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아직 공개하지 않은 캐릭터 자리. 실루엣만 보인다.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: AshColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x22E8C887)),
          gradient: const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 0.8,
            colors: [Color(0x40FF6B35), AshColors.panel],
          ),
        ),
        child: const Column(
          children: [
            Expanded(
              child: FittedBox(
                child: Icon(
                  Icons.person,
                  color: Color(0xFF050404),
                  shadows: [Shadow(color: Color(0x88FF6B35), blurRadius: 12)],
                ),
              ),
            ),
            Text(
              '???',
              style: TextStyle(
                color: AshColors.parchment,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '아직 재 속에 잠들어 있다',
              style: TextStyle(color: AshColors.ash, fontSize: 11),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
