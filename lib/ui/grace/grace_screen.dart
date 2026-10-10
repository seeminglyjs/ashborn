import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/fates.dart';
import '../../data/stages.dart';
import '../../data/stats.dart';
import '../../services/audio.dart';
import '../../systems/fate_system.dart';
import '../profile_scope.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/card_row.dart';
import '../widgets/fate_card.dart';

/// 신의 은총: 받은 은총과 그 합계를 보고, 클리어했지만 아직 고르지 않은 은총을 고른다.
/// 은총은 스테이지를 처음 클리어할 때마다 하나씩 받고, 영구히 모든 캐릭터에 붙는다.
class GraceScreen extends StatefulWidget {
  const GraceScreen({super.key});

  @override
  State<GraceScreen> createState() => _GraceScreenState();
}

class _GraceScreenState extends State<GraceScreen> {
  final _random = math.Random();

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final progress = profile.progress;
    return Scaffold(
      backgroundColor: const Color(0xF20B0908),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: progress,
            builder: (context, _) {
              final pending = progress.pendingGraces;
              final records = progress.graceRecords;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('신의 은총', style: ashTitleStyle(22)),
                      const Spacer(),
                      Text(
                        '${records.length}개',
                        key: const Key('grace-count'),
                        style: const TextStyle(
                          color: AshColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        key: const Key('close-grace'),
                        tooltip: '닫기',
                        icon: const Icon(
                          Icons.close,
                          color: AshColors.parchment,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Text(
                    '스테이지를 처음 클리어할 때마다 은총을 하나 받습니다. '
                    '받은 은총은 영구히 남고 모든 캐릭터에 붙습니다',
                    style: TextStyle(color: AshColors.ash, fontSize: 12),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ListView(
                          children: [
                            if (pending.isNotEmpty) _offer(pending),
                            _Section('합계'),
                            GraceTotals(graces: progress.graces),
                            _Section('받은 은총'),
                            if (records.isEmpty)
                              const Text(
                                '아직 받은 은총이 없습니다. 보스를 잡고 스테이지를 클리어하세요',
                                style: TextStyle(
                                  color: AshColors.ash,
                                  fontSize: 13,
                                ),
                              ),
                            for (final (stage, fate) in records.reversed)
                              GraceRow(stage: stage, fate: fate),
                          ],
                        ),
                      ),
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

  /// 아직 고르지 않은 은총 가운데 가장 앞 스테이지의 카드 패.
  Widget _offer(List<Stage> pending) {
    final profile = ProfileScope.of(context);
    final progress = profile.progress;
    final stage = pending.first;
    final offer = progress.offerFor(stage);
    if (offer == null) {
      // 패를 만들면 진행도가 바뀌어 다시 그리므로, 그리는 도중이 아니라 그린 뒤에 만든다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FateSystem.offer(progress, profile.upgrades, stage, _random);
        }
      });
      return const SizedBox(height: 40);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section('받을 은총 ${pending.length}개'),
        Text(
          '${stage.name} (Lv ${stage.level}) 클리어 은총을 하나 고르세요',
          key: const Key('grace-offer-stage'),
          style: const TextStyle(color: AshColors.parchment, fontSize: 13),
        ),
        const SizedBox(height: 8),
        CardColumn(
          count: offer.hand.length,
          itemBuilder: (context, i) => FateCardView(
            key: Key('offer-$i'),
            fate: offer.hand[i],
            onTap: () {
              GameAudio.play(Sfx.select);
              progress.takeGrace(stage, offer.hand[i]);
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: AshButton(
            key: const Key('reroll-grace'),
            label: '다시 뽑기 (${offer.rerolls})',
            fontSize: 14,
            onPressed: offer.rerolls > 0
                ? () => FateSystem.reroll(
                    progress,
                    profile.upgrades,
                    stage,
                    _random,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        color: AshColors.gold,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

/// 받은 은총을 모두 더한 능력치와, 능력치가 아닌 효과(출정 · 클리어 · 특수 효과) 목록.
class GraceTotals extends StatelessWidget {
  const GraceTotals({super.key, required this.graces});

  final List<Fate> graces;

  @override
  Widget build(BuildContext context) {
    final totals = {
      for (final stat in StatType.values)
        stat: graces.fold(0.0, (sum, f) => sum + (f.stats[stat] ?? 0)),
    }..removeWhere((_, v) => v.abs() < 1e-9);
    final others = [
      for (final f in graces)
        if (f.stats.isEmpty || f.card.element != null || f.card.curse)
          f.description,
    ];
    if (totals.isEmpty && others.isEmpty) {
      return const Text(
        '없음',
        style: TextStyle(color: AshColors.ash, fontSize: 13),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AshColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33E8C887)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totals.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final MapEntry(key: stat, value: v) in totals.entries)
                  Text(
                    stat.format(v),
                    style: const TextStyle(
                      color: AshColors.parchment,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          for (final line in others)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '· ${keepWords(line)}',
                style: const TextStyle(color: AshColors.ash, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// 받은 은총 한 줄: 준 스테이지 · 등급 · 이름 · 효과.
class GraceRow extends StatelessWidget {
  const GraceRow({super.key, required this.stage, required this.fate});

  final Stage stage;
  final Fate fate;

  @override
  Widget build(BuildContext context) {
    final domain = fate.card.domain;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AshColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fate.rarity.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(domain.icon, color: domain.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fate.rarity.label,
                      style: TextStyle(
                        color: fate.rarity.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OneLineText(
                        fate.card.title,
                        style: const TextStyle(
                          color: AshColors.parchment,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      stage.name,
                      style: const TextStyle(
                        color: AshColors.ash,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  keepWords(fate.description),
                  style: const TextStyle(color: AshColors.ash, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
