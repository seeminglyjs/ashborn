import 'package:flutter/material.dart';

import '../../data/inventory.dart';
import '../../data/upgrades.dart';
import '../../services/audio.dart';
import '../profile_scope.dart';
import '../theme.dart';

/// 화톳불: 잔불로 영구 강화를 산다. 강화는 모든 캐릭터에 붙는다.
class HearthScreen extends StatelessWidget {
  const HearthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final inventory = profile.inventory;
    final upgrades = profile.upgrades;
    return Scaffold(
      backgroundColor: const Color(0xF20B0908),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: Listenable.merge([inventory, upgrades]),
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('화톳불', style: ashTitleStyle(22)),
                    const Spacer(),
                    const Icon(
                      Icons.local_fire_department,
                      color: AshColors.ember,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '잔불 ${inventory.ember}',
                      key: const Key('hearth-ember'),
                      style: const TextStyle(
                        color: AshColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      key: const Key('close-hearth'),
                      tooltip: '닫기',
                      icon: const Icon(Icons.close, color: AshColors.parchment),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Text(
                  '잔불로 산 강화는 영구히 남고 모든 캐릭터에 붙습니다',
                  style: TextStyle(color: AshColors.ash, fontSize: 12),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: ListView(
                        children: [
                          for (final group in UpgradeGroup.values) ...[
                            _Section(group.label),
                            for (final upgrade in Upgrade.values)
                              if (upgrade.group == group)
                                _UpgradeRow(
                                  upgrade: upgrade,
                                  upgrades: upgrades,
                                  inventory: inventory,
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
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

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.upgrade,
    required this.upgrades,
    required this.inventory,
  });

  final Upgrade upgrade;
  final Upgrades upgrades;
  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    final level = upgrades.level(upgrade);
    final max = upgrades.isMax(upgrade);
    final effect = level == 0 ? '없음' : upgrade.effect(level);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text(
                  '${upgrade.title}  Lv $level/${upgrade.maxLevel}',
                  style: const TextStyle(
                    color: AshColors.parchment,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  max ? effect : '$effect → ${upgrade.effect(level + 1)}',
                  style: const TextStyle(color: AshColors.ash, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: FilledButton(
              key: Key('buy-${upgrade.name}'),
              style: FilledButton.styleFrom(
                backgroundColor: AshColors.ember,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: upgrades.canBuy(upgrade, inventory)
                  ? () {
                      upgrades.buy(upgrade, inventory);
                      GameAudio.enhance(upgrades.level(upgrade));
                    }
                  : null,
              child: Text(max ? '최대' : '${upgrades.cost(upgrade)}'),
            ),
          ),
        ],
      ),
    );
  }
}
