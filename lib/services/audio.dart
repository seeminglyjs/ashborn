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

/// 배경음. 파일은 `tool/sound/music.py` 가 같은 이름으로 만든다 (assets/audio/music/<이름>.ogg).
/// 모두 이음매 없이 반복된다. [volume] 은 효과음 아래에 깔리도록 맞춘 배율.
enum Bgm {
  /// 타이틀 · 설정.
  title(volume: 0.5),

  /// 캐릭터 선택 · 화톳불 · 장비 · 숙련. 출정 전 쉬는 곳.
  hearth(volume: 0.45),

  /// 웨이브를 버티는 동안.
  battle(volume: 0.38),

  /// 보스가 나온 뒤.
  boss(volume: 0.42);

  const Bgm({required this.volume});

  final double volume;

  String get asset => 'assets/audio/music/$name.ogg';
}

/// 실제로 소리를 내는 쪽. 앱은 [SoLoudBackend], 테스트는 기록만 하는 가짜를 쓴다.
abstract interface class AudioBackend {
  Future<void> loadSfx();

  Future<void> loadMusic();

  /// [speed] 1 이 원래 음높이. 2 면 한 옥타브 위 (빨라진다).
  void play(Sfx sfx, {required double volume, required double speed});

  /// 지금 곡을 [fade] 동안 줄이며 멈추고, [bgm] 을 [fade] 동안 키우며 반복해서 튼다.
  /// [bgm] 이 null 이면 멈추기만 한다.
  void playMusic(Bgm? bgm, {required double volume, required Duration fade});

  void setMusicVolume(double volume, {required Duration fade});

  void pauseMusic(bool paused);
}

/// 효과음 · 배경음 창구. 게임 코드는 [play] 와 [music] 만 부른다.
///
/// [start] 로 엔진을 켜기 전에는 아무 소리도 내지 않는다. 테스트와 밸런스 시뮬레이터는
/// [start] 를 부르지 않으므로 오디오 플러그인 없이 그대로 돈다.
abstract final class GameAudio {
  static AudioBackend? _backend;

  /// 배경음 파일을 다 읽었다. 그 전에 [music] 으로 고른 곡은 다 읽은 뒤 튼다.
  static bool _musicReady = false;

  static Settings? _settings;

  /// 볼륨을 읽을 설정. 클라우드 기록을 받으면 [main] 이 새 설정으로 바꿔 끼운다.
  /// 배경음 볼륨을 바꾸면 지금 곡에 바로 적용한다.
  static Settings? get settings => _settings;
  static set settings(Settings? value) {
    _settings?.removeListener(_applyMusicVolume);
    _settings = value?..addListener(_applyMusicVolume);
    _applyMusicVolume();
  }

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

  /// 지금 고른 곡. null 이면 조용하다.
  static Bgm? _bgm;
  static Bgm? get currentMusic => _bgm;

  /// 일시정지 · 레벨업처럼 게임이 멈춘 동안 배경음을 줄인다.
  static bool _ducked = false;
  static const duckRatio = 0.35;

  /// 마지막으로 엔진에 알린 배경음 크기. 같은 값을 거듭 보내지 않는다.
  static double? _sentMusicVolume;

  static const _crossfade = Duration(milliseconds: 900);
  static const _duckFade = Duration(milliseconds: 300);

  /// 엔진을 켜고 효과음, 배경음 순으로 읽는다. 실패하면 (출력 장치가 없다든가) 소리 없이 계속한다.
  static Future<void> start(Settings settings, {AudioBackend? backend}) async {
    GameAudio.settings = settings;
    final b = backend ?? SoLoudBackend();
    try {
      await b.loadSfx();
      _backend = b;
    } catch (e) {
      debugPrint('효과음을 켜지 못했습니다: $e');
      return;
    }
    try {
      await b.loadMusic();
      _musicReady = true;
      _sentMusicVolume = _musicVolume;
      b.playMusic(_bgm, volume: _musicVolume, fade: _crossfade);
    } catch (e) {
      debugPrint('배경음을 읽지 못했습니다: $e');
    }
  }

  /// 테스트용: 엔진과 시계를 바꿔 끼우고 기록을 비운다. [backend] 가 null 이면 소리를 끈다.
  @visibleForTesting
  static void debugReset({AudioBackend? backend, double Function()? now}) {
    _backend = backend;
    _musicReady = backend != null;
    settings = null;
    _now = now ?? () => _clock.elapsedMicroseconds / 1e6;
    for (final list in _endsAt.values) {
      list.clear();
    }
    _lastAt.clear();
    _shardChain = 0;
    _lastShard = -1;
    _bgm = null;
    _ducked = false;
    _sentMusicVolume = null;
  }

  /// [sfx] 를 울린다. 같은 소리가 이미 [Sfx.voices] 개 울리고 있거나 [Sfx.gap] 안에
  /// 다시 부르면 건너뛴다. [pitch] 는 음높이 배율 (1 이 원래 음).
  static void play(Sfx sfx, {double pitch = 1}) {
    final backend = _backend;
    final volume = (settings?.sfxVolume ?? 0.8) * sfx.volume;
    if (backend == null || volume <= 0) return;
    final now = _now();
    if (sfx == Sfx.shard) pitch *= _chainPitch(now);
    final ends = _endsAt[sfx]!..removeWhere((t) => t <= now);
    final last = _lastAt[sfx];
    if (ends.length >= sfx.voices) return;
    if (last != null && now - last < sfx.gap) return;
    ends.add(now + sfx.length / pitch);
    _lastAt[sfx] = now;
    final wobble = sfx.jitter * (_random.nextDouble() * 2 - 1);
    backend.play(sfx, volume: volume, speed: pitch * (1 + wobble));
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

  /// 배경음을 [bgm] 으로 바꾼다 (null 이면 서서히 멈춘다). 이미 그 곡이면 이어서 튼다.
  static void music(Bgm? bgm) {
    if (bgm == _bgm) return;
    _bgm = bgm;
    final backend = _backend;
    if (backend == null || !_musicReady) return;
    _sentMusicVolume = _musicVolume;
    backend.playMusic(bgm, volume: _musicVolume, fade: _crossfade);
  }

  /// 게임이 멈춘 동안 배경음을 줄인다.
  static void duck(bool on) {
    if (on == _ducked) return;
    _ducked = on;
    _applyMusicVolume(fade: _duckFade);
  }

  /// 앱을 내리거나 탭을 가리면 배경음을 멈추고, 돌아오면 이어서 튼다.
  static void setHidden(bool hidden) {
    if (_musicReady) _backend?.pauseMusic(hidden);
  }

  static double get _musicVolume {
    final bgm = _bgm;
    if (bgm == null) return 0;
    return (settings?.musicVolume ?? 0.8) *
        bgm.volume *
        (_ducked ? duckRatio : 1);
  }

  static void _applyMusicVolume({Duration fade = Duration.zero}) {
    final backend = _backend;
    final volume = _musicVolume;
    if (backend == null || !_musicReady || _bgm == null) return;
    if (volume == _sentMusicVolume) return;
    _sentMusicVolume = volume;
    backend.setMusicVolume(volume, fade: fade);
  }
}

/// flutter_soloud 로 소리를 낸다. 웹은 `web/index.html` 의 init_soloud.js 가 필요하다.
class SoLoudBackend implements AudioBackend {
  final _sfx = <Sfx, AudioSource>{};
  final _music = <Bgm, AudioSource>{};

  /// 지금 반복 중인 배경음.
  SoundHandle? _playing;

  SoLoud get _soloud => SoLoud.instance;

  @override
  Future<void> loadSfx() async {
    if (!_soloud.isInitialized) await _soloud.init(bufferSize: 1024);
    // 짧은 소리가 많이 겹치는 게임이라 기본 16 보다 넉넉히.
    _soloud.setMaxActiveVoiceCount(48);
    final loaded = await Future.wait([
      for (final sfx in Sfx.values) _soloud.loadAsset(sfx.asset),
    ]);
    for (final (i, sfx) in Sfx.values.indexed) {
      _sfx[sfx] = loaded[i];
    }
  }

  @override
  Future<void> loadMusic() async {
    // 앱에서는 곡을 통째로 풀어 두지 않고 흘려 읽어 메모리를 아낀다 (웹은 늘 통째로 읽는다).
    for (final bgm in Bgm.values) {
      _music[bgm] = await _soloud.loadAsset(
        bgm.asset,
        mode: kIsWeb ? LoadMode.memory : LoadMode.disk,
      );
    }
  }

  @override
  void play(Sfx sfx, {required double volume, required double speed}) {
    final source = _sfx[sfx];
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

  @override
  void playMusic(Bgm? bgm, {required double volume, required Duration fade}) {
    try {
      if (_playing case final old?) {
        _soloud
          ..fadeVolume(old, 0, fade)
          ..scheduleStop(old, fade);
      }
      _playing = null;
      final source = bgm == null ? null : _music[bgm];
      if (source == null) return;
      final handle = _soloud.play(source, volume: 0, looping: true);
      // 효과음이 아무리 몰려도 배경음 목소리를 빼앗기지 않게 한다.
      _soloud
        ..setProtectVoice(handle, true)
        ..fadeVolume(handle, volume, fade);
      _playing = handle;
    } on SoLoudException catch (e) {
      debugPrint('배경음 재생 실패 ($bgm): $e');
    }
  }

  @override
  void setMusicVolume(double volume, {required Duration fade}) {
    final handle = _playing;
    if (handle == null) return;
    try {
      if (fade == Duration.zero) {
        _soloud.setVolume(handle, volume);
      } else {
        _soloud.fadeVolume(handle, volume, fade);
      }
    } on SoLoudException catch (e) {
      debugPrint('배경음 볼륨 실패: $e');
    }
  }

  @override
  void pauseMusic(bool paused) {
    final handle = _playing;
    if (handle == null) return;
    try {
      _soloud.setPause(handle, paused);
    } on SoLoudException catch (e) {
      debugPrint('배경음 일시정지 실패: $e');
    }
  }
}
