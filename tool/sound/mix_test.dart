// 소리 기록: 봇이 실제 게임을 플레이하는 동안 울린 효과음 · 배경음을 시간순으로 남긴다.
// tool/sound/mix.py 가 이 기록을 실제 소리 파일로 섞어 "플레이 중에 들리는 소리"를 만들고
// 음량 균형 · 소리별 비중 · 겹침 · 클리핑을 잰다. 일반 `flutter test` 에는 포함되지 않는다.
//
// flutter test tool/sound/mix_test.dart \
//   --dart-define=CHAR=witch --dart-define=STAGES=2 --dart-define=SEED=1 \
//   --dart-define=OUT=build/sound/witch.jsonl
// python -I tool/sound/mix.py build/sound/witch.jsonl
//
// 테스트처럼 도는 도구라 테스트용 GameAudio.debugReset 을 쓴다.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/services/audio.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../balance_sim/bot.dart';

const _char = String.fromEnvironment('CHAR', defaultValue: 'witch');
const _stages = int.fromEnvironment('STAGES', defaultValue: 2);
const _seed = int.fromEnvironment('SEED', defaultValue: 1);
const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/sound/mix.jsonl',
);

/// 엔진에 들어온 명령을 [clock] 시각과 함께 한 줄씩 남긴다.
class TimelineBackend implements AudioBackend {
  TimelineBackend(this.clock, this.sink);

  final double Function() clock;
  final IOSink sink;

  void _log(Map<String, Object?> event) =>
      sink.writeln(jsonEncode({'t': clock(), ...event}));

  @override
  Future<void> loadSfx() async {}

  @override
  Future<void> loadMusic() async {}

  @override
  void play(Sfx sfx, {required double volume, required double speed}) => _log({
    'kind': 'sfx',
    'name': sfx.name,
    'asset': sfx.asset,
    'vol': volume,
    'speed': speed,
  });

  @override
  void playMusic(Bgm? bgm, {required double volume, required Duration fade}) =>
      _log({
        'kind': 'music',
        'name': bgm?.name,
        'asset': bgm?.asset,
        'vol': volume,
        'fade': fade.inMilliseconds / 1000,
      });

  @override
  void setMusicVolume(double volume, {required Duration fade}) => _log({
    'kind': 'musicVol',
    'vol': volume,
    'fade': fade.inMilliseconds / 1000,
  });

  @override
  void pauseMusic(bool paused) => _log({'kind': 'pause', 'paused': paused});
}

void main() {
  final character = Roster.all.firstWhere((c) => c.id.name == _char);

  testWithGame<AshbornGame>(
    'sound timeline $_char seed $_seed',
    () {
      TestWidgetsFlutterBinding.ensureInitialized();
      return AshbornGame(character: character, profile: Profile());
    },
    (game) async {
      await game.ready();
      final file = File(_out)..createSync(recursive: true);
      final sink = file.openWrite();
      double clock() => game.world.elapsed;
      GameAudio.debugReset(backend: TimelineBackend(clock, sink), now: clock);
      GameAudio.settings = game.settings;
      // 게임을 만들 때 고른 전투곡은 위에서 기록을 비우며 사라졌으니 다시 고른다.
      GameAudio.music(Bgm.battle);

      final bot = Bot(game, math.Random(_seed));
      final result = await bot.run(maxStages: _stages, maxSeconds: 900);
      await sink.flush();
      await sink.close();
      GameAudio.debugReset();
      // ignore: avoid_print
      print(
        '$_char: ${result.seconds.round()}s, 클리어 ${result.cleared}, '
        '처치 ${result.kills}, 레벨 ${result.level} → $_out',
      );
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
