import 'package:flutter/material.dart';

import '../../data/equipment.dart';
import '../../data/settings.dart';
import '../odds/odds_screen.dart';
import '../routes.dart';
import '../theme.dart';

/// 알림, 소리, 진동 설정. 타이틀의 설정 화면과 런 중 설정 오버레이가 함께 쓴다.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onClose,
  });

  final Settings settings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF20B0908),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('설정', style: ashTitleStyle(22)),
                    const Spacer(),
                    IconButton(
                      key: const Key('close-settings'),
                      icon: const Icon(Icons.close, color: AshColors.parchment),
                      onPressed: onClose,
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(children: _items(context)),
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

  List<Widget> _items(BuildContext context) => [
    const _Section('알림'),
    _Toggle(
      keyName: 'loot-notices',
      label: '장비 획득 알림',
      value: settings.lootNotices,
      onChanged: (v) => settings.lootNotices = v,
    ),
    if (settings.lootNotices)
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('최소 등급', style: _style),
            for (final rarity in Rarity.values)
              ChoiceChip(
                key: Key('loot-min-${rarity.name}'),
                label: Text(rarity.label),
                labelStyle: TextStyle(color: rarity.color, fontSize: 12),
                selected: settings.lootNoticeMinRarity == rarity,
                onSelected: (_) => settings.lootNoticeMinRarity = rarity,
              ),
          ],
        ),
      ),
    _Toggle(
      keyName: 'event-notices',
      label: '진행 알림 (보스, 클리어, 잔불, 가방)',
      value: settings.eventNotices,
      onChanged: (v) => settings.eventNotices = v,
    ),
    const _Section('소리'),
    _Volume(
      keyName: 'music-volume',
      label: '배경음',
      value: settings.musicVolume,
      onChanged: (v) => settings.musicVolume = v,
    ),
    _Volume(
      keyName: 'sfx-volume',
      label: '효과음',
      value: settings.sfxVolume,
      onChanged: (v) => settings.sfxVolume = v,
    ),
    const Padding(
      padding: EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        '사운드가 추가되면 이 볼륨이 적용됩니다.',
        style: TextStyle(color: AshColors.ash, fontSize: 11),
      ),
    ),
    const _Section('진동'),
    _Toggle(
      keyName: 'vibration',
      label: '피격 시 진동 (모바일)',
      value: settings.vibration,
      onChanged: (v) => settings.vibration = v,
    ),
    const _Section('정보'),
    ListTile(
      key: const Key('open-odds'),
      dense: true,
      title: const Text('확률 정보', style: _style),
      subtitle: const Text(
        '강화 · 초월 · 장비 드랍 · 운명 카드 확률표',
        style: TextStyle(color: AshColors.ash, fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right, color: AshColors.ash),
      onTap: () => Navigator.of(context).push(fadeRoute(const OddsScreen())),
    ),
  ];
}

const _style = TextStyle(color: AshColors.parchment, fontSize: 14);

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

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: Key(keyName),
    dense: true,
    title: Text(label, style: _style),
    value: value,
    activeThumbColor: AshColors.ember,
    onChanged: onChanged,
  );
}

class _Volume extends StatelessWidget {
  const _Volume({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: _style)),
        Expanded(
          child: Slider(
            key: Key(keyName),
            value: value,
            activeColor: AshColors.ember,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}', style: _style),
        ),
      ],
    ),
  );
}
