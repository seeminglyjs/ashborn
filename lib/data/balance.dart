/// 전투 밸런스 수치. 튜닝은 이 파일에서만 한다.
abstract final class Balance {
  // 플레이어
  static const double playerRadius = 16;
  static const double playerSpeed = 160;
  static const double playerInvulnerableTime = 0.5;

  /// 바닥 아이템이 끌려오기 시작하는 거리.
  static const double magnetRange = 70;

  // 줍는 아이템
  static const double pickupSpeed = 360;
  static const double ashShardSize = 10;
  static const double ashShardXp = 1;

  // 레벨: 다음 레벨까지 xpBase + xpGrowth * (레벨 - 1) 경험치.
  static const double xpBase = 5;
  static const double xpGrowth = 5;

  // 적 (재의 무리)
  static const double enemyRadius = 14;
  static const double enemySpeed = 70;
  static const double enemyBaseHp = 20;
  static const double enemyContactDamage = 10;

  /// 이 시간(초)이 지날 때마다 적 체력이 기본값만큼 늘어난다.
  static const double enemyHpGrowthPeriod = 90;

  /// 겹친 적끼리 밀어내는 속도.
  static const double enemySeparationStrength = 120;

  // 웨이브
  static const double baseSpawnInterval = 1.2;
  static const double minSpawnInterval = 0.3;

  /// 이 시간(초)마다 스폰 간격이 절반이 된다.
  static const double spawnIntervalHalfLife = 90;

  /// 이 시간(초)마다 한 번에 스폰되는 수가 1 늘어난다.
  static const double batchGrowthPeriod = 45;
  static const int maxEnemies = 300;

  /// 화면 밖 스폰 거리 여유분.
  static const double spawnMargin = 60;

  // 무기: 잔불 구체 (재의 마녀)
  static const double emberOrbCooldown = 0.6;
  static const double emberOrbDamage = 12;
  static const double emberOrbRange = 420;
  static const double emberOrbSpeed = 520;
  static const double emberOrbLifetime = 1.2;
  static const double emberOrbRadius = 6;

  // 무기: 불꽃 대검 (잿불 기사)
  static const int flameBladeCount = 2;
  static const double flameBladeOrbitRadius = 58;
  static const double flameBladeAngularSpeed = 3.4;
  static const double flameBladeDamage = 11;

  /// 같은 적을 다시 벨 수 있을 때까지의 시간.
  static const double flameBladeHitInterval = 0.45;
  static const double flameBladeLength = 34;
  static const double flameBladeWidth = 10;

  // 무기: 화염 석궁 (불씨 사냥꾼)
  static const double crossbowCooldown = 0.9;
  static const double crossbowDamage = 16;
  static const double crossbowRange = 520;
  static const double crossbowSpeed = 720;
  static const double crossbowLifetime = 1.0;

  /// 첫 적을 맞힌 뒤 추가로 꿰뚫는 수.
  static const int crossbowPierce = 3;
}
