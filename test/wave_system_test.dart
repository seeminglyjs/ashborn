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
      expect(WaveSystem.spawnInterval(3600), Balance.minSpawnInterval);
    });

    test('한 번에 스폰되는 수는 주기마다 1씩 는다', () {
      expect(WaveSystem.batchSize(0), 1);
      expect(WaveSystem.batchSize(Balance.batchGrowthPeriod - 0.1), 1);
      expect(WaveSystem.batchSize(Balance.batchGrowthPeriod), 2);
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
