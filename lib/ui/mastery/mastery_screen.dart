import 'package:flutter/material.dart';

import '../../data/characters.dart';
import '../../data/class_passives.dart';
import '../format.dart';
import '../profile_scope.dart';
import '../theme.dart';

/// 특성: [character] 의 특성 레벨 · 경험치와 특성 여섯 개 (공통 셋 · 고유 스킬 셋).
/// 특성 레벨 하나마다 포인트 하나를 얻어 특성을 올리고, 골드를 내면 되돌릴 수 있다.
class MasteryScreen extends StatelessWidget {
  const MasteryScreen({super.key, required this.character});

  final CharacterDef character;

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final mastery = profile.mastery;
    final inventory = profile.inventory;
    return Scaffold(
      backgroundColor: const Color(0xF20B0908),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: Listenable.merge([mastery, inventory]),
            builder: (context, _) {
              final id = character.id;
              final progress = mastery.progress(id);
              final points = mastery.points(id);
              final maxed = progress.level >= Mastery.maxLevel;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('특성', style: ashTitleStyle(22)),
                      const SizedBox(width: 8),
                      Text(
                        character.name,
                        style: TextStyle(
                          color: character.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('close-mastery'),
                        tooltip: '닫기',
                        icon: const Icon(
                          Icons.close,
                          color: AshColors.parchment,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    '특성 레벨 ${progress.level}',
                    key: const Key('mastery-level'),
                    style: const TextStyle(
                      color: AshColors.parchment,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: maxed ? 1 : progress.into / progress.next,
                      minHeight: 6,
                      backgroundColor: const Color(0x33E8C887),
                      color: const Color(0xFFB8A6FF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    maxed
                        ? '최대 레벨'
                        : '경험치 ${progress.into.floor()} / ${progress.next.floor()}',
                    style: const TextStyle(color: AshColors.ash, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '이 캐릭터로 모은 경험치가 특성 경험치로 쌓이고, 보스를 잡으면 더 많이 쌓입니다. '
                    '특성 레벨이 오를 때마다 특성 포인트 1을 얻습니다. 스킬 특성은 런에서 그 스킬을 '
                    '얻었을 때 힘을 냅니다.',
                    style: TextStyle(color: AshColors.ash, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '남은 포인트 $points',
                    key: const Key('mastery-points'),
                    style: const TextStyle(
                      color: AshColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        const _GroupHeader('공통 특성', '이 캐릭터 전체가 강해진다'),
                        for (final passive in ClassPassive.of(id))
                          if (!passive.isSkillTrait)
                            _PassiveRow(passive: passive, mastery: mastery),
                        const SizedBox(height: 12),
                        const _GroupHeader('스킬 특성', '고유 스킬 하나를 깊게 강화한다'),
                        for (final passive in ClassPassive.of(id))
                          if (passive.isSkillTrait)
                            _PassiveRow(passive: passive, mastery: mastery),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('mastery-reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AshColors.parchment,
                    ),
                    onPressed: mastery.canReset(id, inventory)
                        ? () => mastery.reset(id, inventory)
                        : null,
                    child: Text(
                      '포인트 되돌리기 · 골드 ${formatGold(mastery.resetCost(id))}',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PassiveRow extends StatelessWidget {
  const _PassiveRow({required this.passive, required this.mastery});

  final ClassPassive passive;
  final Mastery mastery;

  @override
  Widget build(BuildContext context) {
    final level = mastery.passiveLevel(passive);
    final max = level >= ClassPassive.maxLevel;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AshColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33E8C887)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (passive.skill case final skill?)
                  Text(
                    skill.label,
                    style: const TextStyle(
                      color: AshColors.ember,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  '${passive.label}  Lv $level/${ClassPassive.maxLevel}',
                  style: const TextStyle(
                    color: AshColors.parchment,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  passive.description,
                  style: const TextStyle(color: AshColors.ash, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  level == 0
                      ? '다음: ${passive.effect(1)}'
                      : max
                      ? passive.effect(level)
                      : '${passive.effect(level)}\n→ ${passive.effect(level + 1)}',
                  key: Key('passive-effect-${passive.name}'),
                  style: const TextStyle(
                    color: Color(0xFFB8A6FF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: Key('raise-${passive.name}'),
            tooltip: '올리기',
            style: IconButton.styleFrom(
              backgroundColor: AshColors.ember,
              foregroundColor: Colors.black,
            ),
            icon: Icon(max ? Icons.check : Icons.add),
            onPressed: mastery.canRaise(passive)
                ? () => mastery.raise(passive)
                : null,
          ),
        ],
      ),
    );
  }
}

/// 특성 묶음 제목과 한 줄 설명.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title, this.hint);

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: ashTitleStyle(16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hint,
            style: const TextStyle(color: AshColors.ash, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
