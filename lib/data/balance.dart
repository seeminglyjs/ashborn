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

  /// 레벨업 때 제시되는 선택지 수.
  static const int levelUpChoices = 3;

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

  // 패시브
  static const int passiveMaxLevel = 5;
  static const double passiveMaxHpPerLevel = 20;
  static const double passiveMoveSpeedPerLevel = 0.08;
  static const double passiveMagnetPerLevel = 0.25;

  // 전투
  /// 치명타 기본 배율. 치명타 피해 능력치가 더해진다.
  static const double critMultiplier = 1.5;

  /// 회피와 피해 감소율의 상한.
  static const double maxEvasion = 0.75;
  static const double maxReduction = 0.75;

  /// 방어력 A 이면 받는 물리 피해가 armorScale / (armorScale + A) 배.
  static const double armorScale = 100;

  /// 에너지 보호막은 마지막 피격 후 이 시간이 지나면 초당 최대치의 일정 비율씩 찬다.
  static const double energyShieldRechargeDelay = 3;
  static const double energyShieldRechargeRate = 0.25;

  // 상태이상: 지속 피해는 원래 타격 중 해당 속성 피해의 비율만큼을 지속 시간 동안 나눠 준다.
  static const double bleedDuration = 4;
  static const double bleedRatio = 1;
  static const double burnDuration = 3;
  static const double burnRatio = 1;
  static const double poisonDuration = 3;

  /// 중독은 타격 전체 피해의 이 비율. 여러 번 쌓인다.
  static const double poisonRatio = 0.4;
  static const int poisonMaxStacks = 20;
  static const double shockDuration = 3;

  /// 감전된 적이 받는 피해 증가율.
  static const double shockEffect = 0.2;
  static const double chillDuration = 2;

  /// 동상에 걸린 적의 이동 속도 감소율.
  static const double chillSlow = 0.3;

  // 고유 장비 효과
  static const double phoenixHp = 0.5;
  static const double phoenixInvulnerableTime = 2;
  static const double emberBurstChance = 0.25;
  static const double emberBurstDamage = 25;
  static const double emberBurstRadius = 80;
  static const double chainLightningChance = 0.15;
  static const int chainLightningTargets = 3;

  /// 연쇄 번개는 원래 타격 피해의 이 비율.
  static const double chainLightningRatio = 0.5;
  static const double chainLightningRange = 160;
  static const double frostArmorRadius = 120;
  static const double frostArmorSlow = 0.6;
  static const double frostArmorDuration = 2;

  /// 광전사: 잃은 체력 비율만큼 피해가 이 배율로 는다.
  static const double berserkScale = 1;

  /// 화면 알림이 떠 있는 시간과 한 번에 보이는 수.
  static const double noticeDuration = 3;
  static const int maxNotices = 4;

  /// 공용 가방에 넣을 수 있는 장비 수.
  static const int bagCapacity = 60;

  // 장비 드랍: 처치당 드랍 확률, 등급이 오를 때마다 드랍 가중치는 이 배율로 준다.
  static const double itemDropChance = 0.02;
  static const double rarityDropRatio = 0.25;

  /// 등급이 오를 때마다 장비 수치가 이 배율로 는다.
  static const double rarityStatGrowth = 1.4;

  /// 랜덤옵션 최대 개수와, 장비 등급별로 옵션 한 칸이 붙을 확률 (노말부터 고유).
  static const int maxAffixes = 5;
  static const List<double> affixChance = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85];

  /// 옵션 등급도 한 등급 오를 때마다 이 배율로 드물어진다. 장비 등급을 넘지 않는다.
  static const double affixRarityRatio = 0.25;

  /// 랜덤옵션은 주옵션 기준 수치의 이 비율.
  static const double affixScale = 0.5;
  static const double twoHandMainScale = 2;

  /// 수치가 기준값의 ±이 비율 안에서 무작위로 정해진다.
  static const double statVariance = 0.2;

  // 노말 등급 기준 수치
  static const double rollMaxHp = 10;
  static const double rollHpRegen = 0.3;
  static const double rollLifeSteal = 0.005;
  static const double rollAddedDamage = 2;
  static const double rollDamage = 0.05;
  static const double rollAttackSpeed = 0.04;
  static const double rollCritChance = 0.03;
  static const double rollCritDamage = 0.1;
  static const double rollAilmentChance = 0.04;
  static const double rollAilmentDamage = 0.1;
  static const double rollArmor = 5;
  static const double rollEvasion = 0.02;
  static const double rollEnergyShield = 8;
  static const double rollPhysicalReduction = 0.02;
  static const double rollResist = 0.04;
  static const double rollMoveSpeed = 0.03;
  static const double rollMagnetRange = 0.1;
  static const double rollXpGain = 0.05;

  // 무기 공통
  static const int weaponMaxLevel = 5;

  /// 레벨당 무기 피해 증가율.
  static const double weaponDamagePerLevel = 0.2;

  // 무기: 잔불 구체 (재의 마녀)
  static const double emberOrbCooldown = 0.6;
  static const double emberOrbDamage = 12;
  static const double emberOrbRange = 420;
  static const double emberOrbSpeed = 520;
  static const double emberOrbLifetime = 1.2;
  static const double emberOrbRadius = 6;

  /// 구체를 여러 발 쏠 때 사이 각도(라디안).
  static const double emberOrbSpread = 0.2;

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
