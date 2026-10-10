// 메타 성장 캠페인: 런 → 정비 → 다음 런을 정해진 플레이 시간만큼 반복하고,
// 런마다 결과를 CSV 한 줄로 남긴다. 일반 `flutter test` 에는 포함되지 않는다.
//
// flutter test tool/balance_sim/campaign_test.dart \
//   --dart-define=CHAR=witch --dart-define=SKILL=normal \
//   --dart-define=HOURS=8 --dart-define=SEED=1 \
//   --dart-define=PAID_STONES=0 --dart-define=OUT=/tmp/sim/witch.csv
import 'dart:io';
import 'dart:math' as math;

import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot.dart';

const _char = String.fromEnvironment('CHAR', defaultValue: 'witch');
const _skill = String.fromEnvironment('SKILL', defaultValue: 'normal');
const _hours = String.fromEnvironment('HOURS', defaultValue: '4');
const _seed = int.fromEnvironment('SEED', defaultValue: 1);

/// 과금 가정: 런이 끝날 때마다 사는 강화석.
const _paidStones = int.fromEnvironment('PAID_STONES');
const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/balance_sim.csv',
);

/// CSV 열 이름.
const header =
    'char,skill,seed,run,minutes,start,death,cleared,boss,deathStageTime,'
    'level,kills,gold,stones,ember,transcendStones,frontier,'
    'invGold,invStones,invEmber,invTranscendStones';

void main() {
  final character = Roster.all.firstWhere((c) => c.id.name == _char);
  final skill = Skill.all.firstWhere((s) => s.name == _skill);
  final budget = double.parse(_hours) * 3600;

  testWithGame<AshbornGame>(
    'balance campaign $_char/$_skill seed $_seed',
    () {
      TestWidgetsFlutterBinding.ensureInitialized();
      return AshbornGame(character: character, profile: Profile());
    },
    (game) async {
      await game.ready();
      final file = File(_out)..createSync(recursive: true);
      file.writeAsStringSync('$header\n');
      void out(String s) =>
          file.writeAsStringSync('$s\n', mode: FileMode.append);
      final log = File('$_out.log')..writeAsStringSync('');
      void note(String s) =>
          log.writeAsStringSync('$s\n', mode: FileMode.append);

      final random = math.Random(_seed);
      final meta = Meta(game, random);
      final bot = Bot(game, random, skill: skill)
        ..log = note
        // 런 중에도 스테이지를 깰 때마다 장비를 바꾸고 강화한다 (HUD 가방).
        ..onClear = () => meta
          ..tidy()
          ..enhance();

      var total = 0.0;
      var back = 0;
      var run = 0;
      while (total < budget) {
        run++;
        // 열린 가장 높은 타락 단계로 출정하고, 첫 지역도 못 깨면 한 단계 낮춰 파밍한다.
        // 낮춘 단계를 정복하면 다시 올라간다.
        final corruption = math.max(0, game.progress.unlockedCorruption - back);
        final start = Stage.start(corruption).index;
        game.restart(stage: Stage(start));
        await game.ready();
        final r = await bot.run(maxSeconds: budget - total + 1);
        total += r.seconds;
        if (r.cleared == 0) {
          back++;
        } else if (r.conquered) {
          back = math.max(0, back - 1);
        }
        if (_paidStones > 0) game.inventory.addLoot(stones: _paidStones);
        meta
          ..tidy()
          ..hearth()
          ..mastery()
          ..enhance();
        final inv = game.inventory;
        out(
          '$_char,$_skill,$_seed,$run,${(total / 60).toStringAsFixed(1)},'
          '${start + 1},${r.deathStage + 1},${r.cleared},'
          '${r.diedToBoss ? 1 : 0},${r.deathStageTime.round()},${r.level},'
          '${r.kills},${r.gold},${r.stones},${r.ember},${r.transcendStones},'
          '${game.progress.frontier.index},${inv.gold},${inv.stones},'
          '${inv.ember},${inv.transcendStones}',
        );
        note('run $run: ${meta.gearSummary()}');
      }
    },
    timeout: Timeout.none,
  );
}
