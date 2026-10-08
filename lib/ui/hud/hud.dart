import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../format.dart';

/// 경험치, 체력과 보호막, 생존 시간, 처치 수, 장비 버튼, 알림.
/// 장비 버튼 밖의 터치는 게임(조이스틱)으로 그대로 통과시킨다.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final AshbornGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _stats(),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 52, right: 6),
              child: Material(
                type: MaterialType.transparency,
                child: IconButton(
                  key: const Key('open-equipment'),
                  tooltip: '장비',
                  icon: const Icon(Icons.backpack, color: Colors.white70),
                  onPressed: game.openEquipment,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 100, right: 16),
              child: IgnorePointer(child: _notices()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notices() => ValueListenableBuilder(
    valueListenable: game.notices,
    builder: (context, notices, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              notice.text,
              style: _textStyle(13).copyWith(color: notice.color),
            ),
          ),
      ],
    ),
  );

  Widget _stats() {
    final stats = game.stats;
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([
                    stats.level,
                    stats.xp,
                    stats.xpToNext,
                  ]),
                  builder: (context, _) => _XpBar(
                    level: stats.level.value,
                    xp: stats.xp.value,
                    xpToNext: stats.xpToNext.value,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          stats.hp,
                          stats.maxHp,
                          stats.energyShield,
                          stats.maxEnergyShield,
                        ]),
                        builder: (context, _) => _HpBar(
                          hp: stats.hp.value,
                          maxHp: stats.maxHp.value,
                          shield: stats.energyShield.value,
                          maxShield: stats.maxEnergyShield.value,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ValueListenableBuilder(
                          valueListenable: stats.elapsedSeconds,
                          builder: (context, seconds, _) =>
                              Text(formatTime(seconds), style: _textStyle(22)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: ValueListenableBuilder(
                          valueListenable: stats.kills,
                          builder: (context, kills, _) =>
                              Text('💀 $kills', style: _textStyle(18)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle _textStyle(double size) => TextStyle(
    color: Colors.white,
    fontSize: size,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(blurRadius: 4)],
  );
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.level, required this.xp, required this.xpToNext});

  final int level;
  final double xp;
  final double xpToNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Lv $level',
          style: const TextStyle(
            color: Color(0xFF9FD8E8),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: xpToNext <= 0 ? 0 : xp / xpToNext,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: const Color(0xFF9FD8E8),
            ),
          ),
        ),
      ],
    );
  }
}

/// 체력 바. 에너지 보호막이 있으면 그 위에 얇은 보호막 바를 겹친다.
class _HpBar extends StatelessWidget {
  const _HpBar({
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.maxShield,
  });

  final double hp;
  final double maxHp;
  final double shield;
  final double maxShield;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxShield > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: shield / maxShield,
              minHeight: 4,
              backgroundColor: Colors.white12,
              color: const Color(0xFF6FD6FF),
            ),
          ),
          const SizedBox(height: 2),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: maxHp <= 0 ? 0 : hp / maxHp,
            minHeight: 10,
            backgroundColor: Colors.white24,
            color: const Color(0xFFE5383B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${hp.ceil()} / ${maxHp.ceil()}'
          '${maxShield > 0 ? '  (+${shield.ceil()})' : ''}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
