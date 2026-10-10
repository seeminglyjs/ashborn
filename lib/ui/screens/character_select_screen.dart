import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../data/stages.dart';
import '../equipment/equipment_screen.dart';
import '../hearth/hearth_screen.dart';
import '../mastery/mastery_screen.dart';
import '../profile_scope.dart';
import '../routes.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/dungeon_backdrop.dart';
import '../widgets/pixel_sprite.dart';
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

  void _openMastery() =>
      Navigator.of(context)
          .push(fadeRoute(MasteryScreen(character: _selected)));

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return Scaffold(
      backgroundColor: AshColors.night,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return DungeonBackdrop(
                  pixel: PixelScene.pixelFor(size),
                  light: Offset(size.width / 2, size.height * 0.4),
                  lightRadius: size.longestSide * 0.55,
                  darkness: 0.85,
                  walls: false,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  profile.inventory,
                  profile.progress,
                  profile.mastery,
                ]),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      gold: profile.inventory.gold,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _Showcase(
                        character: _selected,
                        locked: !_owned,
                        gold: profile.inventory.gold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _picks(),
                    const SizedBox(height: 6),
                    _StagePicker(
                      stage: _currentStage,
                      unlocked: profile.progress.unlocked,
                      onChanged: (stage) => setState(() => _stage = stage),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AshButton(
                            key: const Key('open-hearth'),
                            label: '화톳불',
                            fontSize: 15,
                            onPressed: _openHearth,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AshButton(
                            key: const Key('open-equipment'),
                            label: '장비',
                            fontSize: 15,
                            onPressed: _openEquipment,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AshButton(
                            key: const Key('open-mastery'),
                            // 남은 포인트가 있으면 개수를 붙여 올릴 것이 있다고 알린다.
                            label: switch (profile.mastery.points(
                              _selected.id,
                            )) {
                              > 0 && final points => '특성 +$points',
                              _ => '특성',
                            },
                            fontSize: 15,
                            onPressed: _owned ? _openMastery : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_owned)
                      AshButton(
                        key: const Key('depart'),
                        label: '출정하기',
                        fontSize: 20,
                        onPressed: _depart,
                      )
                    else
                      AshButton(
                        key: const Key('unlock'),
                        label: '해금 · 골드 ${formatGold(_selected.price)}',
                        fontSize: 20,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 캐릭터 고르기 줄. 그 뒤로 공개 예정 캐릭터 자리가 이어져 옆으로 넘겨 본다.
  Widget _picks() {
    final progress = ProfileScope.of(context).progress;
    return SizedBox(
      height: _Pick.height,
      child: ListView(
        key: const Key('character-list'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in Roster.all)
            _Pick(
              character: c,
              selected: c == _selected,
              locked: !progress.owns(c),
              onTap: () => setState(() => _selected = c),
            ),
          for (var i = 0; i < upcoming; i++)
            _UpcomingPick(
              sprite: _UpcomingPick.sprites[i % _UpcomingPick.sprites.length],
            ),
        ],
      ),
    );
  }
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
    // 가운데 이름 칸이 남는 폭을 모두 써서 화살표가 양 끝에, 이름이 정가운데 온다.
    return Row(
      children: [
        IconButton(
          key: const Key('stage-prev'),
          tooltip: '이전 스테이지',
          onPressed: canPrev ? () => onChanged(Stage(stage.index - 1)) : null,
          icon: const Icon(Icons.chevron_left),
          color: AshColors.gold,
        ),
        Expanded(
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
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AshColors.gold),
            ),
            const Spacer(),
            Text(
              '골드 ${formatGold(gold)}',
              key: const Key('select-gold'),
              style: const TextStyle(
                color: AshColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('누구로 다시 일어설 것인가', style: ashTitleStyle(22)),
        ),
        const SizedBox(height: 2),
        const Text(
          '재 속에서 깨어날 애쉬본을 선택하세요',
          style: TextStyle(color: AshColors.ash, fontSize: 11),
        ),
      ],
    );
  }
}

/// 카드 바탕. 뒤의 바닥 무늬가 비치지 않도록 불투명하다.
const _cardColor = Color(0xFF1A1411);

/// 칸에 맞는 정수 배율. 정수 배로 키워야 픽셀이 고르게 보인다.
double _spriteScale(BoxConstraints c, {double fill = 0.95}) => [
  c.maxHeight * fill / 28,
  c.maxWidth * 0.7 / heroFrame.width,
].reduce((a, b) => a < b ? a : b).floorToDouble().clamp(2.0, 14.0);

/// 고른 캐릭터를 크게 보여 주는 자리. 캐릭터 색으로 밝힌 바닥 위에 픽셀 캐릭터가
/// 숨 쉬고, 아래에 이름 · 무기 · 특성 · 능력 막대가 온다. 잠긴 캐릭터는 실루엣.
class _Showcase extends StatelessWidget {
  const _Showcase({
    required this.character,
    required this.locked,
    required this.gold,
  });

  final CharacterDef character;
  final bool locked;
  final int gold;

  @override
  Widget build(BuildContext context) {
    final accent = character.color;
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: AshColors.gold, width: 2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.5),
                      radius: 0.8,
                      colors: [
                        // 잠긴 캐릭터는 검은 실루엣이라 뒤를 조금 더 밝혀 윤곽이 보이게 한다.
                        accent.withValues(alpha: locked ? 0.4 : 0.3),
                        _cardColor,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.bottomCenter,
                      child: PixelSprite(
                        key: Key('portrait-${character.id.name}'),
                        asset: 'assets/images/${character.sprite}',
                        frameSize: heroFrame,
                        count: 4,
                        fps: 6,
                        scale: _spriteScale(constraints, fill: 0.9),
                        silhouette: locked ? Colors.black : null,
                      ),
                    ),
                  ),
                ),
                if (locked) _LockOverlay(price: character.price, gold: gold),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.role,
                  style: TextStyle(
                    color: accent,
                    fontFamily: pixelFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  character.name,
                  key: const Key('showcase-name'),
                  style: ashTitleStyle(24),
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  tag: '무기',
                  color: accent,
                  text:
                      '${character.weaponName} · '
                      '${character.weaponDescription}',
                ),
                const SizedBox(height: 2),
                _InfoLine(
                  tag: '고유',
                  color: AshColors.gold,
                  text: character.trait,
                ),
                const SizedBox(height: 8),
                _Ratings(character: character),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 캐릭터 고르기 칸. 작은 픽셀 캐릭터와 이름.
class _Pick extends StatelessWidget {
  const _Pick({
    required this.character,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  static const double width = 76;
  static const double height = 96;

  final CharacterDef character;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: character.name,
      child: GestureDetector(
        key: Key('pick-${character.id.name}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            border: Border.all(
              color: selected ? AshColors.gold : const Color(0x33E8C887),
              width: selected ? 2 : 1,
            ),
            gradient: RadialGradient(
              center: const Alignment(0, 0.3),
              colors: [
                character.color.withValues(alpha: selected ? 0.35 : 0.15),
                _cardColor,
              ],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.bottomCenter,
                      child: PixelSprite(
                        asset: 'assets/images/${character.sprite}',
                        frameSize: heroFrame,
                        count: selected ? 4 : 1,
                        fps: 6,
                        scale: _spriteScale(constraints),
                        silhouette: locked ? Colors.black : null,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (locked)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(Icons.lock, size: 10, color: AshColors.ash),
                      ),
                    Flexible(
                      child: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? AshColors.parchment : AshColors.ash,
                          fontFamily: pixelFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.tag, required this.color, required this.text});

  /// 줄 앞의 짧은 머리말 (무엇에 대한 줄인지).
  final String tag;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          tag,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
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
    // 위쪽만 어둡게 덮어 실루엣은 그대로 보이게 한다.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
          stops: [0.12, 0.4],
        ),
      ),
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

/// 아직 공개하지 않은 캐릭터 자리. 다음에 나올 영웅이 실루엣으로만 보인다.
class _UpcomingPick extends StatelessWidget {
  const _UpcomingPick({required this.sprite});

  /// 0x72 팩에서 아직 쓰지 않은 영웅 (`assets/images/sprites/upcoming/`).
  static const sprites = ['lizard_m', 'dwarf_m', 'knight_f'];

  final String sprite;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Pick.width,
      margin: const EdgeInsets.only(right: 8),
      // 흐리게 보이도록 어둡게 덮는다. 투명하게 하면 바닥 무늬가 비친다.
      foregroundDecoration: const BoxDecoration(color: Color(0x66000000)),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x22E8C887)),
        gradient: const RadialGradient(
          center: Alignment(0, 0.3),
          colors: [Color(0x66FF6B35), _cardColor],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.bottomCenter,
                  child: PixelSprite(
                    asset: 'assets/images/sprites/upcoming/$sprite.png',
                    frameSize: const Size(16, 28),
                    scale: _spriteScale(constraints),
                    silhouette: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 6),
            child: Text(
              '???',
              style: TextStyle(
                color: AshColors.ash,
                fontFamily: pixelFont,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
