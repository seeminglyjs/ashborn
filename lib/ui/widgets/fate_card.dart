import 'package:flutter/material.dart';

import '../../data/fates.dart';
import '../theme.dart';
import 'card_row.dart';

/// 은총 카드 한 장 (가로형). 왼쪽은 영역 아이콘과 신 이름 · 신화, 오른쪽은
/// 등급 · 저주 딱지 · 종류, 은총 이름, 효과, 신 소개. 테두리는 등급 색, 신 쪽은 영역 색이다.
class FateCardView extends StatelessWidget {
  const FateCardView({super.key, required this.fate, this.onTap});

  final Fate fate;

  /// 누르면 고른다. null 이면 보여 주기만 한다 (받은 은총).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = fate.rarity.color;
    final card = fate.card;
    final domain = card.domain;
    final god = card.god;
    return Semantics(
      button: onTap != null,
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
