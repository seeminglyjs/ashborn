import '../data/balance.dart';

/// 경험치 곡선.
abstract final class LevelSystem {
  /// [level] 에서 다음 레벨까지 필요한 경험치.
  static double xpToNext(int level) =>
      Balance.xpBase + Balance.xpGrowth * (level - 1);
}
