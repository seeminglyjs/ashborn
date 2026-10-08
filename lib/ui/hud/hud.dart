import 'package:flutter/material.dart';

import '../../game/ashborn_game.dart';
import '../format.dart';
import '../theme.dart';

/// 경험치, 체력과 보호막, 스테이지, 처치 수, 설정·장비 버튼, 알림.
/// 버튼 밖의 터치는 게임(조이스틱)으로 그대로 통과시킨다.
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('open-settings'),
                      tooltip: '설정',
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: game.openSettings,
                    ),
                    IconButton(
                      key: const Key('open-equipment'),
                      tooltip: '장비',
                      icon: const Icon(Icons.backpack, color: Colors.white70),
                      onPressed: game.openEquipment,
                    ),
                  ],
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
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            stats.stage,
                            stats.bossCountdown,
                            stats.bossHealth,
                            stats.stageCleared,
                          ]),
                          builder: (context, _) => _StageInfo(
                            name: stats.stage.value.name,
                            level: stats.stage.value.level,
                            bossName: stats.stage.value.region.bossName,
                            countdown: stats.bossCountdown.value,
                            bossHealth: stats.bossHealth.value,
                            cleared: stats.stageCleared.value,
                          ),
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

/// 지역 이름과, 보스까지 남은 시간 또는 보스 체력.
class _StageInfo extends StatelessWidget {
  const _StageInfo({
    required this.name,
    required this.level,
    required this.bossName,
    required this.countdown,
    required this.bossHealth,
    required this.cleared,
  });

  final String name;
  final int level;
  final String bossName;
  final int countdown;
  final double? bossHealth;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final health = bossHealth;
    return Column(
      children: [
        Text(
          '$name  Lv $level',
          style: Hud._textStyle(13).copyWith(color: AshColors.gold),
        ),
        const SizedBox(height: 2),
        if (cleared)
          Text('클리어', style: Hud._textStyle(20))
        else if (health != null) ...[
          Text(bossName, style: Hud._textStyle(13)),
          const SizedBox(height: 2),
          SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: health,
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: AshColors.ember,
              ),
            ),
          ),
        ] else
          Text('보스까지 ${formatTime(countdown)}', style: Hud._textStyle(18)),
      ],
    );
  }
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
