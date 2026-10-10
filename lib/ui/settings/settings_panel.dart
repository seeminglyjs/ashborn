import 'package:flutter/material.dart';

import '../../data/equipment.dart';
import '../../data/settings.dart';
import '../../data/save_snapshot.dart';
import '../../services/audio.dart';
import '../../services/cloud_sync.dart';
import '../odds/odds_screen.dart';
import '../routes.dart';
import '../theme.dart';

/// 알림, 소리, 진동 설정. 타이틀의 설정 화면과 런 중 설정 오버레이가 함께 쓴다.
/// [cloud] 를 주면 클라우드 저장 칸도 보인다 (타이틀에서만: 런 중에 기록을 바꿔 끼우지 않도록).
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onClose,
    this.cloud,
  });

  final Settings settings;
  final VoidCallback onClose;
  final CloudSync? cloud;

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
    if (cloud case final cloud?) ...[
      const _Section('클라우드 저장'),
      CloudSection(cloud: cloud),
    ],
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
      // 놓으면 바뀐 크기로 한 번 들려준다.
      onChangeEnd: (_) => GameAudio.play(Sfx.select),
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
        '강화 · 초월 · 장비 드랍 · 신의 은총 확률표',
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
    this.onChangeEnd,
  });

  final String keyName;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

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
            onChangeEnd: onChangeEnd,
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

/// 클라우드 저장: 로그인 상태, 마지막 저장, 지금 저장 · 로그아웃, 충돌 때 고르기.
class CloudSection extends StatelessWidget {
  const CloudSection({super.key, required this.cloud});

  final CloudSync cloud;

  static const _dim = TextStyle(color: AshColors.ash, fontSize: 11);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cloud,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (cloud.status) {
          CloudStatus.unavailable => [
            const Text('Google 계정으로 저장 (준비 중)', style: _style),
            const SizedBox(height: 2),
            const Text(
              '지금은 이 기기에만 저장됩니다. 앱을 지우면 기록도 함께 지워지니, '
              '새 버전은 지우지 말고 덮어 설치하세요.',
              key: Key('cloud-unavailable'),
              style: _dim,
            ),
            const SizedBox(height: 6),
            const _CloudButton('cloud-sign-in', 'Google 로그인', null),
          ],
          CloudStatus.signedOut => [
            const Text(
              '로그인하면 기록이 계정에 저장되어, 앱을 다시 깔거나 기기를 바꿔도 이어서 할 수 있습니다.',
              style: _dim,
            ),
            const SizedBox(height: 6),
            _CloudButton('cloud-sign-in', 'Google 로그인', cloud.signIn),
          ],
          CloudStatus.syncing => [
            Text('${cloud.user?.name ?? ''} 맞추는 중...', style: _style),
          ],
          CloudStatus.synced => [
            Text(cloud.user?.name ?? '', style: _style),
            Text(
              '마지막 저장 ${_time(cloud.lastSynced)}',
              key: const Key('cloud-synced'),
              style: _dim,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _CloudButton('cloud-sync', '지금 저장', cloud.sync),
                const SizedBox(width: 8),
                _CloudButton('cloud-sign-out', '로그아웃', cloud.signOut),
              ],
            ),
          ],
          CloudStatus.conflict => _conflict(cloud.conflict!),
          CloudStatus.error => [
            Text(
              '저장하지 못했습니다: ${cloud.error}',
              key: const Key('cloud-error'),
              style: const TextStyle(color: AshColors.ember, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _CloudButton('cloud-retry', '다시 시도', cloud.sync),
                const SizedBox(width: 8),
                _CloudButton('cloud-sign-out', '로그아웃', cloud.signOut),
              ],
            ),
          ],
        },
      ),
    ),
  );

  List<Widget> _conflict(SaveConflict conflict) => [
    const Text(
      '이 기기와 계정의 기록이 다릅니다. 어느 쪽으로 이어서 할까요? '
      '고르지 않은 쪽은 사라집니다.',
      key: Key('cloud-conflict'),
      style: TextStyle(color: AshColors.ember, fontSize: 12),
    ),
    const SizedBox(height: 6),
    _choice('cloud-use-local', '이 기기 기록', conflict.local, false),
    const SizedBox(height: 6),
    _choice('cloud-use-cloud', '계정 기록', conflict.cloud, true),
  ];

  Widget _choice(String key, String title, SaveSnapshot save, bool useCloud) =>
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title · ${_time(save.savedAt)}', style: _style),
                  Text(save.summary.describe(), style: _dim),
                ],
              ),
            ),
            _CloudButton(key, '이걸로', () => cloud.resolve(useCloud: useCloud)),
          ],
        ),
      );

  static String _time(DateTime? at) {
    if (at == null || at.millisecondsSinceEpoch == 0) return '없음';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}.${two(at.month)}.${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _CloudButton extends StatelessWidget {
  const _CloudButton(this.keyName, this.label, this.onPressed);

  final String keyName;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: Key(keyName),
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AshColors.parchment,
      side: BorderSide(
        color: onPressed == null ? Colors.white12 : AshColors.gold,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    ),
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );
}
