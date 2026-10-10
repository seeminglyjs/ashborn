import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../data/equipment.dart';
import '../data/settings.dart';

/// 효과음. 파일은 `tool/sound/sfx.py` 가 같은 이름으로 만든다 (assets/audio/sfx/<이름>.wav).
///
/// [volume] 은 소리끼리 체감 크기를 맞추는 배율, [voices] 는 동시에 울릴 수 있는 수,
/// [gap] 은 같은 소리를 다시 내기까지 최소 간격 (초), [length] 는 한 번 울리는 길이 (초),
/// [jitter] 는 울릴 때마다 흔드는 음높이 비율. 적 수십 마리가 한꺼번에 맞아도
/// 시끄럽게 뭉개지지 않도록 자주 나는 소리일수록 [voices] 를 줄이고 [gap] 을 둔다.
enum Sfx {
  hit(volume: 0.32, voices: 3, gap: 0.05, length: 0.06, jitter: 0.08),
  crit(volume: 0.4, voices: 2, gap: 0.07, length: 0.12, jitter: 0.06),
  kill(volume: 0.4, voices: 3, gap: 0.06, length: 0.17, jitter: 0.1),
  hurt(volume: 0.7, voices: 1, gap: 0.15, length: 0.26, jitter: 0.04),
  block(volume: 0.55, voices: 1, gap: 0.15, length: 0.22),
  bossAppear(file: 'boss_appear', volume: 0.9, length: 1.7),
  bossDown(file: 'boss_down', volume: 0.9, length: 1.4),

  /// 재의 결정. 연달아 주우면 음이 한 단계씩 올라간다 ([GameAudio.play]).
  shard(volume: 0.3, voices: 3, gap: 0.035, length: 0.07),
  coin(volume: 0.45, voices: 2, gap: 0.08, length: 0.3),
  gem(volume: 0.5, voices: 2, gap: 0.08, length: 0.4),
  heal(volume: 0.55, length: 0.5),
  magnet(volume: 0.5, length: 0.45),
  crate(volume: 0.5, voices: 2, gap: 0.06, length: 0.24, jitter: 0.08),
  equip(volume: 0.5, voices: 2, gap: 0.06, length: 0.16),

  /// 장비가 떨어질 때. 등급이 높을수록 길고 화려하다 ([forRarity]).
  lootNormal(
    file: 'loot_normal',
    volume: 0.35,
    voices: 2,
    gap: 0.08,
    length: 0.18,
  ),
  lootRare(file: 'loot_rare', volume: 0.5, voices: 2, gap: 0.1, length: 0.5),
  lootHero(file: 'loot_hero', volume: 0.6, voices: 2, gap: 0.1, length: 0.8),
  lootLegend(file: 'loot_legend', volume: 0.75, length: 1.3),
  lootEpic(file: 'loot_epic', volume: 0.85, length: 1.7),

  levelUp(file: 'level_up', volume: 0.6, length: 0.7),
  select(volume: 0.5, gap: 0.05, length: 0.17),
  tap(volume: 0.4, voices: 2, gap: 0.03, length: 0.035),
  stageClear(file: 'stage_clear', volume: 0.7, length: 1.6),
  gameOver(file: 'game_over', volume: 0.7, length: 1.9),

  /// 장비 강화 · 화톳불 강화. 강화 단계가 오를수록 음이 올라간다 ([GameAudio.enhance]).
  enhance(volume: 0.6, voices: 2, gap: 0.05, length: 0.65),
  transcend(volume: 0.7, length: 1.1);

  const Sfx({
    this._file,
    required this.volume,
    this.voices = 1,
    this.gap = 0,
    required this.length,
    this.jitter = 0,
  });

  final String? _file;
  final double volume;
  final int voices;
  final double gap;
  final double length;
  final double jitter;

  String get asset => 'assets/audio/sfx/${_file ?? name}.wav';

  static Sfx forRarity(Rarity rarity) => switch (rarity) {
    Rarity.normal => lootNormal,
    Rarity.rare => lootRare,
    Rarity.hero => lootHero,
    Rarity.legend => lootLegend,
    Rarity.epic || Rarity.unique => lootEpic,
  };
}

/// 실제로 소리를 내는 쪽. 앱은 [SoLoudSfxPlayer], 테스트는 기록만 하는 가짜를 쓴다.
abstract interface class SfxPlayer {
  Future<void> load();

  /// [speed] 1 이 원래 음높이. 2 면 한 옥타브 위 (빨라진다).
  void play(Sfx sfx, {required double volume, required double speed});
}

/// 효과음 창구. 게임 코드는 [play] 만 부른다.
///
/// [start] 로 엔진을 켜기 전에는 아무 소리도 내지 않는다. 테스트와 밸런스 시뮬레이터는
/// [start] 를 부르지 않으므로 오디오 플러그인 없이 그대로 돈다.
abstract final class GameAudio {
  static SfxPlayer? _player;

  /// 볼륨을 읽을 설정. 클라우드 기록을 받으면 [main] 이 새 설정으로 바꿔 끼운다.
  static Settings? settings;

  static final _clock = Stopwatch()..start();
  static double Function() _now = () => _clock.elapsedMicroseconds / 1e6;
  static final _random = math.Random();

  /// 소리별로 지금 울리고 있는 것들이 끝나는 시각.
  static final _endsAt = {for (final s in Sfx.values) s: <double>[]};
  static final _lastAt = <Sfx, double>{};

  /// 재의 결정을 연달아 주운 수. [_shardChainGap] 안에 다음 것을 주우면 이어진다.
  static int _shardChain = 0;
  static double _lastShard = -1;
  static const _shardChainGap = 0.4;
  static const _shardChainMax = 12;

  /// 엔진을 켜고 효과음을 읽는다. 실패하면 (기기에 출력 장치가 없다든가) 소리 없이 계속한다.
  static Future<void> start(Settings settings, {SfxPlayer? player}) async {
    GameAudio.settings = settings;
    final p = player ?? SoLoudSfxPlayer();
    try {
      await p.load();
      _player = p;
    } catch (e) {
      debugPrint('효과음을 켜지 못했습니다: $e');
    }
  }

  /// 테스트용: 엔진과 시계를 바꿔 끼우고 기록을 비운다. [player] 가 null 이면 소리를 끈다.
  @visibleForTesting
  static void debugReset({SfxPlayer? player, double Function()? now}) {
    _player = player;
    settings = null;
    _now = now ?? () => _clock.elapsedMicroseconds / 1e6;
    for (final list in _endsAt.values) {
      list.clear();
    }
    _lastAt.clear();
    _shardChain = 0;
    _lastShard = -1;
  }

  /// [sfx] 를 울린다. 같은 소리가 이미 [Sfx.voices] 개 울리고 있거나 [Sfx.gap] 안에
  /// 다시 부르면 건너뛴다. [pitch] 는 음높이 배율 (1 이 원래 음).
  static void play(Sfx sfx, {double pitch = 1}) {
    final player = _player;
    final volume = (settings?.sfxVolume ?? 0.8) * sfx.volume;
    if (player == null || volume <= 0) return;
    final now = _now();
    if (sfx == Sfx.shard) pitch *= _chainPitch(now);
    final ends = _endsAt[sfx]!..removeWhere((t) => t <= now);
    final last = _lastAt[sfx];
    if (ends.length >= sfx.voices) return;
    if (last != null && now - last < sfx.gap) return;
    ends.add(now + sfx.length / pitch);
    _lastAt[sfx] = now;
    final wobble = sfx.jitter * (_random.nextDouble() * 2 - 1);
    player.play(sfx, volume: volume, speed: pitch * (1 + wobble));
  }

  /// 연달아 주울수록 반음씩, 한 옥타브까지 올라간다. 줍는 재미가 쌓이는 느낌을 준다.
  static double _chainPitch(double now) {
    _shardChain = now - _lastShard <= _shardChainGap
        ? math.min(_shardChain + 1, _shardChainMax)
        : 0;
    _lastShard = now;
    return math.pow(2, _shardChain / 12).toDouble();
  }

  /// 강화 성공음. [level] (강화 뒤 단계) 이 오를수록 음이 올라가고, 5단계마다 팡파르를 더한다.
  static void enhance(int level) {
    play(Sfx.enhance, pitch: math.pow(2, math.min(level, 15) / 24).toDouble());
    if (level > 0 && level % 5 == 0) play(Sfx.levelUp);
  }
}

/// flutter_soloud 로 효과음을 낸다. 웹은 `web/index.html` 의 init_soloud.js 가 필요하다.
class SoLoudSfxPlayer implements SfxPlayer {
  final _sources = <Sfx, AudioSource>{};

  SoLoud get _soloud => SoLoud.instance;

  @override
  Future<void> load() async {
    if (!_soloud.isInitialized) await _soloud.init(bufferSize: 1024);
    // 짧은 소리가 많이 겹치는 게임이라 기본 16 보다 넉넉히.
    _soloud.setMaxActiveVoiceCount(48);
    final loaded = await Future.wait([
      for (final sfx in Sfx.values) _soloud.loadAsset(sfx.asset),
    ]);
    for (final (i, sfx) in Sfx.values.indexed) {
      _sources[sfx] = loaded[i];
    }
  }

  @override
  void play(Sfx sfx, {required double volume, required double speed}) {
    final source = _sources[sfx];
    if (source == null) return;
    try {
      if (speed == 1) {
        _soloud.play(source, volume: volume);
        return;
      }
      // 처음 몇 샘플이 원래 속도로 새지 않게 멈춘 채로 만들고 속도를 바꾼 뒤 튼다.
      final handle = _soloud.play(source, volume: volume, paused: true);
      _soloud
        ..setRelativePlaySpeed(handle, speed)
        ..setPause(handle, false);
    } on SoLoudException catch (e) {
      debugPrint('효과음 재생 실패 ($sfx): $e');
    }
  }
}
