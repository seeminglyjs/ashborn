import 'package:ashborn/data/balance.dart';
import 'package:ashborn/systems/wave_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaveSystem 난이도 곡선', () {
    test('스폰 간격은 시간이 지날수록 줄고 최솟값 아래로 내려가지 않는다', () {
      expect(WaveSystem.spawnInterval(0), Balance.baseSpawnInterval);
      expect(
        WaveSystem.spawnInterval(Balance.spawnIntervalHalfLife),
        closeTo(Balance.baseSpawnInterval / 2, 1e-9),
      );
      expect(
        WaveSystem.spawnInterval(Balance.stageDuration - 1),
        WaveSystem.spawnInterval(Balance.spawnGrowthCap),
        reason: '막판에는 더 늘지 않는다',
      );
      expect(
        WaveSystem.spawnInterval(Balance.stageDuration),
        closeTo(
          WaveSystem.spawnInterval(Balance.spawnGrowthCap) *
              Balance.bossSpawnSlow,
          1e-9,
        ),
        reason: '보스가 나오면 느려진다',
      );
    });

    test('막판 스폰 속도는 시작의 8배를 넘지 않는다', () {
      double rate(double t) =>
          WaveSystem.batchSize(t) / WaveSystem.spawnInterval(t);
      expect(rate(Balance.stageDuration - 1) / rate(0), lessThan(8));
      expect(
        rate(Balance.stageDuration + 60),
        lessThan(rate(Balance.stageDuration - 1)),
      );
    });

    test('한 번에 스폰되는 수는 주기마다 1씩 는다', () {
      expect(WaveSystem.batchSize(0), 1);
      expect(WaveSystem.batchSize(Balance.batchGrowthPeriod - 0.1), 1);
      expect(WaveSystem.batchSize(Balance.batchGrowthPeriod), 2);
      expect(
        WaveSystem.batchSize(3600),
        WaveSystem.batchSize(Balance.spawnGrowthCap),
      );
    });

    test('적 체력은 시간에 비례해 늘어난다', () {
      expect(WaveSystem.enemyHp(0), Balance.enemyBaseHp);
      expect(
        WaveSystem.enemyHp(Balance.enemyHpGrowthPeriod),
        Balance.enemyBaseHp * 2,
      );
    });
  });
}
