import 'package:flutter/material.dart';

import '../../data/fates.dart';
import '../../game/ashborn_game.dart';
import '../theme.dart';
import '../widgets/ash_button.dart';
import '../widgets/card_row.dart';

/// 보스를 잡은 뒤: 신의 은총을 하나 골라 다음 지역으로 가거나, 화톳불로 돌아간다.
/// 은총 카드는 위에서 아래로 쌓고, 많아도 한 화면에 모두 보이게 한다.
class StageClearOverlay extends StatelessWidget {
  const StageClearOverlay({
    super.key,
    required this.game,
    required this.onReturn,
  });

  final AshbornGame game;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final stage = game.world.stage;
    final next = stage.next;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: FitOneScreen(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${stage.region.bossName} 처치', style: ashTitleStyle(24)),
              const SizedBox(height: 4),
              Text(
                '${stage.name} 클리어 · 다음: ${next.name} (Lv ${next.level})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AshColors.gold, fontSize: 13),
              ),
              if (next.corruption > stage.corruption)
                Text(
                  '타락 ${next.corruption}단계: 적과 보상이 강해집니다',
                  style: const TextStyle(color: AshColors.ember, fontSize: 12),
                ),
              const SizedBox(height: 12),
              Text('신의 은총을 하나 고르세요', style: ashTitleStyle(17)),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: game.fateOptions,
                builder: (context, fates, _) {
                  final rerolls = game.world.fate.rerolls;
                  return Column(
                    children: [
                      CardColumn(
                        count: fates.length,
                        itemBuilder: (context, i) => _FateCardView(
                          key: Key('fate-$i'),
                          fate: fates[i],
                          onTap: () => game.chooseFate(fates[i]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          AshButton(
                            key: const Key('reroll-fate'),
                            label: '다시 뽑기 ($rerolls)',
                            fontSize: 14,
                            onPressed: rerolls > 0 ? game.rerollFate : null,
                          ),
                          AshButton(
                            key: const Key('return-to-hearth'),
                            label: '화톳불로 귀환',
                            fontSize: 14,
                            onPressed: onReturn,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 은총 카드 한 장 (가로형). 왼쪽은 영역 아이콘과 신 이름 · 신화, 오른쪽은
/// 등급 · 저주 딱지 · 종류, 은총 이름, 효과, 신 소개. 테두리는 등급 색, 신 쪽은 영역 색이다.
class _FateCardView extends StatelessWidget {
  const _FateCardView({super.key, required this.fate, required this.onTap});

  final Fate fate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = fate.rarity.color;
    final card = fate.card;
    final domain = card.domain;
    final god = card.god;
    return Semantics(
      button: true,
      label: '${card.title} ${fate.rarity.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.alphaBlend(
                  domain.color.withValues(alpha: 0.16),
                  AshColors.panel,
                ),
                Color.alphaBlend(
                  color.withValues(alpha: 0.06),
                  AshColors.panel,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 어느 신의 은총인지.
              SizedBox(
                width: 76,
                child: Column(
                  children: [
                    Container(
                      key: Key('grace-domain-${domain.name}'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: domain.color.withValues(alpha: 0.18),
                        border: Border.all(
                          color: domain.color.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Icon(domain.icon, color: domain.color, size: 22),
                    ),
                    const SizedBox(height: 4),
                    OneLineText(
                      god.name,
                      center: true,
                      style: TextStyle(
                        color: domain.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    OneLineText(
                      '${god.myth.label} 신화 · ${domain.label}',
                      center: true,
                      style: const TextStyle(
                        color: AshColors.ash,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 오른쪽: 무엇을 주는지.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          fate.rarity.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // 에픽 등급도 붉은색이라 저주는 채운 딱지로 따로 보인다.
                        if (card.curse) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A0D0D),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              '저주',
                              style: TextStyle(
                                color: Color(0xFFFF9C8C),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          card.type.label,
                          style: const TextStyle(
                            color: AshColors.ash,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    OneLineText(
                      card.title,
                      style: const TextStyle(
                        color: AshColors.parchment,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keepWords(fate.description),
                      style: const TextStyle(
                        color: AshColors.parchment,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keepWords(god.lore),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AshColors.ash,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
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
