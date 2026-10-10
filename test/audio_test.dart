import 'dart:io';

import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/settings.dart';
import 'package:ashborn/services/audio.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 울린 소리를 기록만 하는 가짜 엔진.
class RecordingBackend implements AudioBackend {
  final played = <({Sfx sfx, double volume, double speed})>[];

  List<Sfx> get sounds => [for (final p in played) p.sfx];

  /// 배경음을 바꾼 기록 (null 은 멈춤).
  final tracks = <Bgm?>[];

  /// 지금 배경음 크기.
  double musicVolume = 0;
  bool musicPaused = false;

  @override
  Future<void> loadSfx() async {}

  @override
  Future<void> loadMusic() async {}

  @override
  void play(Sfx sfx, {required double volume, required double speed}) =>
      played.add((sfx: sfx, volume: volume, speed: speed));

  @override
  void playMusic(Bgm? bgm, {required double volume, required Duration fade}) {
    tracks.add(bgm);
    musicVolume = bgm == null ? 0 : volume;
  }

  @override
  void setMusicVolume(double volume, {required Duration fade}) =>
      musicVolume = volume;

  @override
  void pauseMusic(bool paused) => musicPaused = paused;
}

void main() {
  late RecordingBackend player;
  var now = 0.0;

  setUp(() {
    player = RecordingBackend();
    now = 0;
    GameAudio.debugReset(backend: player, now: () => now);
  });

  tearDown(GameAudio.debugReset);

  group('효과음', () {
    test('모든 효과음 파일이 있다 (tool/sound/sfx.py 와 이름이 같다)', () {
      for (final sfx in Sfx.values) {
        expect(File(sfx.asset).existsSync(), isTrue, reason: sfx.asset);
      }
    });

    test('엔진을 켜기 전에는 아무것도 울리지 않는다', () {
      GameAudio.debugReset();
      GameAudio.play(Sfx.levelUp);
      expect(player.played, isEmpty);
    });

    test('같은 소리는 최소 간격 안에 다시 울리지 않는다', () {
      GameAudio.play(Sfx.hit);
      GameAudio.play(Sfx.hit);
      expect(player.played, hasLength(1));

      now += Sfx.hit.gap;
      GameAudio.play(Sfx.hit);
      expect(player.played, hasLength(2));
    });

    test('동시에 울리는 수가 차면 앞의 소리가 끝날 때까지 건너뛴다', () {
      const sfx = Sfx.coin;
      for (var t = 0.0; t < sfx.length * 0.9; t += sfx.gap) {
        now = t;
        GameAudio.play(sfx);
      }
      expect(player.played, hasLength(sfx.voices));

      now = sfx.length + 0.01;
      GameAudio.play(sfx);
      expect(player.played, hasLength(sfx.voices + 1));
    });

    test('다른 소리끼리는 서로 막지 않는다', () {
      GameAudio.play(Sfx.hit);
      GameAudio.play(Sfx.kill);
      GameAudio.play(Sfx.levelUp);
      expect(player.sounds, [Sfx.hit, Sfx.kill, Sfx.levelUp]);
    });

    test('효과음 볼륨을 따르고, 0 이면 울리지 않는다', () {
      final settings = Settings()..sfxVolume = 0.5;
      GameAudio.settings = settings;
      GameAudio.play(Sfx.levelUp);
      expect(
        player.played.single.volume,
        closeTo(0.5 * Sfx.levelUp.volume, 1e-9),
      );

      settings.sfxVolume = 0;
      now += 5;
      GameAudio.play(Sfx.levelUp);
      expect(player.played, hasLength(1));
    });

    test('재의 결정을 연달아 주우면 음이 올라가고, 쉬었다 주우면 처음 음으로 돌아간다', () {
      final speeds = <double>[];
      for (var i = 0; i < 4; i++) {
        GameAudio.play(Sfx.shard);
        speeds.add(player.played.last.speed);
        now += 0.1;
      }
      for (var i = 1; i < speeds.length; i++) {
        expect(speeds[i], greaterThan(speeds[i - 1]));
      }

      now += 2;
      GameAudio.play(Sfx.shard);
      expect(player.played.last.speed, 1);
    });

    test('연속 줍기 음은 한 옥타브에서 멈춘다', () {
      for (var i = 0; i < 40; i++) {
        GameAudio.play(Sfx.shard);
        now += 0.1;
      }
      expect(player.played.last.speed, closeTo(2, 1e-9));
    });

    test('강화음은 단계가 오를수록 높고, 5단계마다 팡파르가 붙는다', () {
      GameAudio.enhance(1);
      now += 1;
      GameAudio.enhance(4);
      expect(player.played[1].speed, greaterThan(player.played[0].speed));
      expect(player.sounds, isNot(contains(Sfx.levelUp)));

      now += 1;
      GameAudio.enhance(5);
      expect(player.sounds, contains(Sfx.levelUp));
    });

    test('장비 등급마다 드롭 소리가 있고, 높은 등급일수록 길다', () {
      final lengths = [for (final r in Rarity.values) Sfx.forRarity(r).length];
      for (var i = 1; i < lengths.length; i++) {
        expect(lengths[i], greaterThanOrEqualTo(lengths[i - 1]));
      }
    });
  });

  group('배경음', () {
    test('모든 배경음 파일이 있다 (tool/sound/music.py 와 이름이 같다)', () {
      for (final bgm in Bgm.values) {
        expect(File(bgm.asset).existsSync(), isTrue, reason: bgm.asset);
      }
    });

    test('곡을 바꾸면 배경음 볼륨에 맞춰 틀고, 같은 곡은 다시 틀지 않는다', () {
      GameAudio.settings = Settings()..musicVolume = 0.5;
      GameAudio.music(Bgm.battle);
      GameAudio.music(Bgm.battle);
      GameAudio.music(Bgm.boss);
      GameAudio.music(null);

      expect(player.tracks, [Bgm.battle, Bgm.boss, null]);
      expect(player.musicVolume, 0);
    });

    test('배경음 볼륨을 바꾸면 지금 곡에 바로 적용된다', () {
      final settings = Settings()..musicVolume = 1;
      GameAudio.settings = settings;
      GameAudio.music(Bgm.hearth);
      expect(player.musicVolume, closeTo(Bgm.hearth.volume, 1e-9));

      settings.musicVolume = 0.25;
      expect(player.musicVolume, closeTo(0.25 * Bgm.hearth.volume, 1e-9));
    });

    test('게임이 멈춘 동안 배경음을 줄였다가 이어지면 되돌린다', () {
      GameAudio.settings = Settings()..musicVolume = 1;
      GameAudio.music(Bgm.battle);
      GameAudio.duck(true);
      expect(
        player.musicVolume,
        closeTo(Bgm.battle.volume * GameAudio.duckRatio, 1e-9),
      );

      GameAudio.duck(false);
      expect(player.musicVolume, closeTo(Bgm.battle.volume, 1e-9));
    });

    test('엔진을 켜기 전에 고른 곡은 다 읽은 뒤에 튼다', () async {
      GameAudio.debugReset();
      GameAudio.music(Bgm.title);
      expect(player.tracks, isEmpty);

      await GameAudio.start(Settings(), backend: player);
      expect(player.tracks, [Bgm.title]);
    });

    test('앱을 내리면 배경음을 멈추고 돌아오면 이어 튼다', () {
      GameAudio.music(Bgm.title);
      GameAudio.setHidden(true);
      expect(player.musicPaused, isTrue);
      GameAudio.setHidden(false);
      expect(player.musicPaused, isFalse);
    });
  });

  group('게임 속 배경음', () {
    testWithGame('출정하면 전투곡, 보스가 나오면 보스곡', gameWith(Roster.witch), (game) async {
      expect(GameAudio.currentMusic, Bgm.battle);
      game.world.spawnBoss();
      expect(GameAudio.currentMusic, Bgm.boss);
    });

    testWithGame(
      '보스를 잡으면 배경음을 거두고 다음 지역에서 전투곡을 다시 튼다',
      gameWith(Roster.witch),
      (game) async {
        game.world.spawnBoss();
        await game.ready();
        game.world.boss!.takeDamage(1e12);
        expect(GameAudio.currentMusic, isNull);
        expect(player.sounds, contains(Sfx.bossDown));

        game.continueToNextStage();
        expect(GameAudio.currentMusic, Bgm.battle);
      },
    );

    testWithGame('게임이 멈추면 배경음이 줄고 다시 돌면 돌아온다', gameWith(Roster.witch), (
      game,
    ) async {
      GameAudio.settings = Settings()..musicVolume = 1;
      final full = player.musicVolume;
      game.pauseEngine();
      expect(player.musicVolume, lessThan(full));
      game.resumeEngine();
      expect(player.musicVolume, closeTo(full, 1e-9));
    });

    testWithGame('런을 끝내면 배경음이 멈춘다', gameWith(Roster.witch), (game) async {
      game.quitRun();
      expect(GameAudio.currentMusic, isNull);
    });
  });

  group('전투 효과음', () {
    testWithGame('적을 쓰러뜨리면 처치음이 난다', gameWith(Roster.witch), (game) async {
      await clearEnemies(game);
      final enemy = await addEnemy(game, Vector2(300, 0), hp: 1);
      enemy.takeDamage(10);
      expect(player.sounds, contains(Sfx.kill));
    });

    testWithGame('장비가 떨어지면 등급에 맞는 소리가 난다', gameWith(Roster.witch), (
      game,
    ) async {
      await game.world.add(
        ItemDrop(
          position: game.world.player.position + Vector2(300, 0),
          item: item(ItemType.ring, rarity: Rarity.legend),
        ),
      );
      await game.ready();
      expect(player.sounds, contains(Sfx.lootLegend));
    });
  });
}
