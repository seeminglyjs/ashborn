import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/enemies/minions.dart';
import '../data/balance.dart';
import '../data/corruption.dart';
import '../data/enemies.dart';
import '../data/stages.dart';
import '../game/ashborn_game.dart';
import '../game/world/run_world.dart';

/// 스테이지 시간에 따라 점점 더 많고 강한 적을 화면 밖에서 스폰한다.
/// 적의 기본 강도는 스테이지(레벨, 지역, 타락 단계)가 정하고, 종류는 지역 로스터에서
/// 스테이지 시간에 따라 풀린 것 중 가중치로 뽑는다.
class WaveSystem extends Component
    with HasGameReference<AshbornGame>, HasWorldReference<RunWorld> {
  double _timer = 0;

  /// 스폰 간격. [Balance.spawnGrowthCap] 까지 줄어들고 그 뒤로는 그대로이며,
  /// 보스가 나온 뒤([Balance.stageDuration] 이후)에는 [Balance.bossSpawnSlow] 배로 길어진다.
  static double spawnInterval(double elapsed) =>
      math.max(
        Balance.minSpawnInterval,
        Balance.baseSpawnInterval *
            math.pow(
              0.5,
              math.min(elapsed, Balance.spawnGrowthCap) /
                  Balance.spawnIntervalHalfLife,
            ),
      ) *
      (elapsed >= Balance.stageDuration ? Balance.bossSpawnSlow : 1);

  static int batchSize(double elapsed) =>
      1 +
      (math.min(elapsed, Balance.spawnGrowthCap) / Balance.batchGrowthPeriod)
          .floor();

  static double enemyHp(double elapsed) =>
      Balance.enemyBaseHp * (1 + elapsed / Balance.enemyHpGrowthPeriod);

  @override
  void update(double dt) {
    super.update(dt);
    // 보스를 잡으면 다음 지역으로 넘어갈 때까지 쉰다.
    if (world.stageCleared) return;
    _timer -= dt;
    if (_timer > 0) return;
    final time = world.stageTime;
    _timer = spawnInterval(time);

    final stage = world.stage;
    final region = stage.region;
    final fate = world.fate;
    final hp = enemyHp(time) * stage.enemyHpMultiplier * fate.enemyHpMultiplier;
    final damage =
        Balance.enemyContactDamage *
        stage.enemyDamageMultiplier *
        fate.enemyDamageMultiplier;
    // 무리 습격: 더 빠르고 한 번에 더 많이.
    final frenzy = stage.has(CorruptionRule.frenzy);
    final speed =
        Balance.enemySpeed *
        stage.enemySpeedMultiplier *
        (frenzy ? 1 + Balance.frenzySpeed : 1);
    final elites = stage.has(CorruptionRule.elite);
    final kinds = unlocked(region, time);
    var count = batchSize(time) + (frenzy ? Balance.frenzyBatch : 0);
    while (count > 0 && world.enemies.length < Balance.maxEnemies) {
      final kind = pick(kinds, game.random);
      // 떼는 한자리에 몇 마리씩 몰려 나온다 (한 마리로 친다).
      final pack = kind.behavior == EnemyBehavior.swarm ? Balance.swarmPack : 1;
      final at = world.offscreenPoint();
      // 정예 출현: 떼는 무리째로 정예가 되지 않게 한 마리짜리만.
      final elite =
          elites && pack == 1 && game.random.nextDouble() < Balance.eliteChance;
      for (var i = 0; i < pack; i++) {
        final minion = spawnMinion(
          kind,
          position: at + Vector2(i * 18.0, (i % 2) * 18.0),
          maxHp: hp * (elite ? Balance.eliteHp : 1),
          contactDamage: damage * (elite ? Balance.eliteDamage : 1),
          damageType: region.damageType,
          speed: speed,
          color: region.enemy,
        );
        if (elite) minion.makeElite();
        world.add(minion);
      }
      count--;
    }
  }

  /// [time] 에 나올 수 있는 [region] 졸개 종류 (로스터 앞에서부터 차례로 풀린다).
  static List<EnemyKind> unlocked(Region region, double time) => [
    for (final (i, kind) in region.roster.indexed)
      if (time >=
          Balance.rosterUnlock[math.min(i, Balance.rosterUnlock.length - 1)])
        kind,
  ];

  /// 가중치대로 하나 고른다.
  static EnemyKind pick(List<EnemyKind> kinds, math.Random random) {
    final total = kinds.fold(0, (sum, k) => sum + k.weight);
    var r = random.nextInt(total);
    for (final kind in kinds) {
      r -= kind.weight;
      if (r < 0) return kind;
    }
    return kinds.last;
  }
}
