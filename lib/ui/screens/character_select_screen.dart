import 'package:flutter/material.dart';

import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/run_save.dart';
import '../../data/stages.dart';
import '../../services/audio.dart';
import '../equipment/equipment_screen.dart';
import '../grace/grace_screen.dart';
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

  /// 고른 타락 단계. 처음엔 열린 가장 높은 단계.
  int? _corruption;

  int get _currentCorruption =>
      _corruption ?? ProfileScope.of(context).progress.unlockedCorruption;

  /// 아직 공개하지 않은 캐릭터 자리. 앞으로 더 늘어난다는 느낌을 준다.
  static const upcoming = 3;

  bool get _owned => ProfileScope.of(context).progress.owns(_selected);

  @override
  void initState() {
    super.initState();
    GameAudio.music(Bgm.hearth);
  }

  /// 새 런. 이어 할 런이 있으면 버려도 되는지 먼저 묻는다.
  Future<void> _depart() async {
    if (!_owned) return _unlock();
    final runs = ProfileScope.of(context).runs;
    final saved = runs.of(_selected.id);
    if (saved != null) {
      if (await _confirmDiscard(saved) != true || !mounted) return;
      runs.clear(_selected.id);
    }
    await _launch(
      GameScreen(character: _selected, stage: Stage.start(_currentCorruption)),
    );
  }

  /// 클리어하고 돌아온 런을 다음 지역부터 지금 레벨 · 카드로 이어 간다.
  Future<void> _resume(RunSave saved) =>
      _launch(GameScreen(character: _selected, resume: saved));

  Future<void> _launch(GameScreen screen) async {
    await Navigator.of(context).push(fadeRoute(screen));
    GameAudio.music(Bgm.hearth);
    // 돌아오면 새로 열린 가장 높은 단계를 기본으로 보여 준다.
    if (mounted) setState(() => _corruption = null);
  }

  Future<bool?> _confirmDiscard(RunSave saved) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AshColors.panel,
      title: const Text('새로 출정할까요?', style: TextStyle(color: AshColors.gold)),
      content: Text(
        '이어 할 런(${saved.stage.name} · Lv ${saved.level})을 버리고 '
        '레벨 1, 카드 없이 새로 시작합니다.',
        style: const TextStyle(color: AshColors.parchment, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('confirm-new-run'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('새로 출정', style: TextStyle(color: AshColors.ember)),
        ),
      ],
    ),
  );

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

  void _openGrace() =>
      Navigator.of(context).push(fadeRoute(const GraceScreen()));

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
                  profile.runs,
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
                    _CorruptionPicker(
                      corruption: _currentCorruption,
                      unlocked: profile.progress.unlockedCorruption,
                      conquered: profile.progress.conquered(_currentCorruption),
                      onChanged: (c) => setState(() => _corruption = c),
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
                      ],
                    ),
                    // 버튼 넷을 한 줄에 두면 글자가 너무 작아져 두 줄로 나눈다.
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AshButton(
                            key: const Key('open-grace'),
                            // 아직 고르지 않은 은총이 있으면 개수를 붙여 알린다.
                            label:
                                switch (profile.progress.pendingGraces.length) {
                                  > 0 && final n => '은총 +$n',
                                  _ => '은총',
                                },
                            fontSize: 15,
                            onPressed: _openGrace,
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
                      switch (profile.runs.of(_selected.id)) {
                        final saved? => _resumeRow(saved),
                        null => AshButton(
                          key: const Key('depart'),
                          label: '출정하기',
                          fontSize: 20,
                          onPressed: _depart,
                        ),
                      }
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

  /// 이어 할 런이 있을 때: 어디서 · 몇 레벨로 이어 가는지와, 이어 하기 · 새로 출정 버튼.
  Widget _resumeRow(RunSave saved) {
    final cards =
        saved.weapons.length +
        saved.passives.values.fold(0, (sum, _) => sum + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '이어 하기: ${saved.stage.name} (지역 Lv ${saved.stage.level}) · '
          '캐릭터 Lv ${saved.level} · 카드 $cards장',
          key: const Key('resume-info'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AshColors.gold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AshButton(
                key: const Key('depart'),
                label: '새로 출정',
                fontSize: 15,
                onPressed: _depart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: AshButton(
                key: const Key('resume-run'),
                label: '이어 하기',
                fontSize: 20,
                onPressed: () => _resume(saved),
              ),
            ),
          ],
        ),
      ],
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

/// 출정할 타락 단계 고르기. 런은 늘 그 단계의 첫 지역에서 시작해 마지막 지역까지 간다.
/// 클리어한 단계의 다음 단계까지 고를 수 있고, 단계마다 보상과 특수 규칙을 보여 준다.
class _CorruptionPicker extends StatelessWidget {
  const _CorruptionPicker({
    required this.corruption,
    required this.unlocked,
    required this.conquered,
    required this.onChanged,
  });

  final int corruption;
  final int unlocked;
  final bool conquered;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final start = Stage.start(corruption);
    final rules = start.rules;
    final drop = (Balance.corruptionDropBonus * corruption * 100).round();
    final luck = (Balance.corruptionRarityLuck * corruption * 100).round();
    // 가운데 이름 칸이 남는 폭을 모두 써서 화살표가 양 끝에, 이름이 정가운데 온다.
    return Row(
      children: [
        IconButton(
          key: const Key('corruption-prev'),
          tooltip: '낮은 타락 단계',
          onPressed: corruption > 0 ? () => onChanged(corruption - 1) : null,
          icon: const Icon(Icons.chevron_left),
          color: AshColors.gold,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${corruption == 0 ? '타락 없음' : '타락 $corruption단계'}'
                '${conquered ? ' · 클리어' : ''}',
                key: const Key('corruption-name'),
                style: TextStyle(
                  color: corruption > 0 ? AshColors.ember : AshColors.parchment,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                [
                  '장비 Lv ${start.level}~${start.level + Region.values.length - 1}',
                  if (corruption > 0) '드랍 +$drop% · 등급 운 +$luck%',
                ].join(' · '),
                key: const Key('corruption-rewards'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AshColors.ash, fontSize: 11),
              ),
              if (rules.isNotEmpty)
                Text(
                  rules.map((r) => r.label).join(' · '),
                  key: const Key('corruption-rules'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AshColors.ember, fontSize: 11),
                ),
            ],
          ),
        ),
        IconButton(
          key: const Key('corruption-next'),
          tooltip: '높은 타락 단계',
          onPressed: corruption < unlocked
              ? () => onChanged(corruption + 1)
              : null,
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
