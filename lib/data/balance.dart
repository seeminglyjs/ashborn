/// 전투 밸런스 수치. 튜닝은 이 파일에서만 한다.
abstract final class Balance {
  // 캐릭터 해금: 골드로 산다. 잿불 기사는 처음부터 쓸 수 있다.
  static const int witchPrice = 10000;
  static const int hunterPrice = 30000;

  // 플레이어
  static const double playerRadius = 16;
  static const double playerSpeed = 160;
  static const double playerInvulnerableTime = 0.5;

  /// 16x28 캐릭터 스프라이트를 몇 배로 그릴지와, 맞았을 때 피격 프레임을 보여 주는 시간.
  static const double playerSpriteScale = 2;
  static const double playerHitPoseTime = 0.15;

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

  /// 적 · 보스 스프라이트의 큰 변이 충돌 지름의 몇 배인지. 키 큰 스프라이트는 높이를
  /// 0.75 배로 쳐서 너무 작아지지 않게 한다.
  static const double enemySpriteSize = 1.15;

  /// 적 걷기 애니메이션 한 프레임의 시간.
  static const double enemyWalkFrameTime = 0.12;
  static const double enemySpeed = 70;
  static const double enemyBaseHp = 20;
  static const double enemyContactDamage = 10;

  /// 한 스테이지 안에서 이 시간(초)이 지날 때마다 적 체력이 기본값만큼 늘어난다.
  static const double enemyHpGrowthPeriod = 240;

  /// 겹친 적끼리 밀어내는 속도.
  static const double enemySeparationStrength = 120;

  // 스테이지: 레벨(1부터)이 오를 때마다 적 체력과 피해가 이 배율로 는다.
  static const double stageHpGrowth = 1.35;
  static const double stageDamageGrowth = 1.2;

  /// 첫 스테이지들의 적 체력 · 피해 배율. 그 뒤는 1.
  static const List<double> earlyStageEase = [0.5, 0.7, 0.85];

  /// 스테이지 시작 후 이 시간(초)이 지나면 보스가 나온다.
  static const double stageDuration = 120;

  /// 보스를 잡은 뒤 다음 지역 선택이 뜨기까지 전리품을 줍는 시간.
  static const double stageClearDelay = 3;

  // 보스: 그 스테이지 보스 등장 시점의 졸개 대비 배율.
  static const double bossHpMultiplier = 60;
  static const double bossDamageMultiplier = 2;
  static const double bossSpeedMultiplier = 0.8;
  static const double bossRadius = 40;

  /// 보스가 나온 뒤 이 시간(초) 안에 잡지 못하면 런이 끝난다.
  /// 피하기만으로는 깰 수 없고, 보스를 잡을 화력(장비 · 강화)이 있어야 한다.
  static const double bossTimeLimit = 180;

  /// 보스는 이 간격마다 잠깐 빠르게 돌진한다.
  static const double bossChargeInterval = 4;
  static const double bossChargeDuration = 0.6;
  static const double bossChargeSpeed = 3.5;

  /// 타락 단계마다 적 이동 속도 증가율과 그 상한 배율.
  static const double corruptionSpeedBonus = 0.04;
  static const double maxCorruptionSpeed = 1.4;

  /// 타락 단계마다 장비 드랍 확률 증가율과 높은 등급 가중치 증가율.
  static const double corruptionDropBonus = 0.25;
  static const double corruptionRarityLuck = 0.1;

  // 웨이브 (스테이지마다 처음부터)
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

  // 장비 레벨: 장비는 떨어진 스테이지 레벨을 갖는다. 고정치 옵션은 레벨마다 이 배율로 크고,
  // 비율(%) 옵션은 상한이 있어 레벨과 상관없다.
  static const double itemLevelGrowth = 1.15;

  /// 타락으로 높은 등급 가중치가 커져도 한 등급 위 비율이 이 값을 넘지 않는다.
  static const double maxRarityRatio = 0.8;

  // 보스 상자
  static const int bossChestItems = 3;
  static const double bossChestRadius = 40;

  // 잔불: 스테이지 클리어와 처치로 얻고, 장비 분해로도 얻는다. 화톳불 영구 강화에 쓴다.
  static const double stageClearEmber = 20;
  static const double killEmber = 0.2;
  static const double salvageEmber = 3;

  /// 분해 잔불은 등급이 오를 때마다 이 배율로 는다.
  static const double salvageRarityGrowth = 3;

  /// 장비 레벨 1 오를 때마다 분해 잔불과 강화 골드가 이 비율씩 는다.
  static const double emberPerItemLevel = 0.1;

  // 골드와 강화석: 처치와 보스로 얻고, 쓰러지거나 클리어할 때 정산된다. 장비 강화에 쓴다.
  /// 처치당 골드 (스테이지 레벨마다).
  static const double killGold = 1;

  /// 스테이지 클리어 골드 (스테이지 레벨마다, 타락 보상 배율이 붙는다).
  static const double stageClearGold = 50;

  /// 처치당 강화석이 나올 확률 (타락 보상 배율이 붙는다).
  static const double stoneDropChance = 0.03;

  /// 보스가 주는 강화석. 타락 단계마다 하나씩 더.
  static const int bossStones = 3;

  // 장비 강화: 강화석과 골드를 쓰고 확률로 성공한다. 실패하면 재료만 사라진다.
  static const int maxEnhance = 30;

  /// 지금 단계에서 다음 단계로 성공할 확률. 길이가 [maxEnhance] 와 같다.
  /// 최대 단계를 늘리면 여기에 확률을 덧붙인다.
  static const List<double> enhanceChances = [
    1, 1, 1, 1, 1, //
    0.9, 0.85, 0.8, 0.75, 0.7,
    0.6, 0.55, 0.5, 0.45, 0.4,
    0.3, 0.3, 0.25, 0.25, 0.25,
    0.2, 0.2, 0.2, 0.2, 0.2,
    0.2, 0.2, 0.2, 0.2, 0.2,
  ];

  /// 다음 단계 강화석 = enhanceStones + enhanceStonesPerStep × 지금 단계.
  static const int enhanceStones = 1;
  static const int enhanceStonesPerStep = 1;

  /// 다음 단계 골드 = enhanceGold × enhanceGoldGrowth^단계
  /// × enhanceRarityGrowth^등급 × 장비 레벨 배율.
  static const double enhanceGold = 50;
  static const double enhanceGoldGrowth = 1.1;
  static const double enhanceRarityGrowth = 1.5;

  /// 강화 1단계마다 모든 옵션 수치가 이 배율로 커진다 (복리: +20 은 약 6.7배, +30 은 약 17배).
  /// 적이 스테이지마다 지수로 강해지니, 재화로 사는 힘도 천장 없이 커지게 한다.
  static const double enhanceStatGrowth = 1.1;

  /// 이 강화 단계부터 초월할 수 있다.
  static const int transcendEnhance = 20;

  // 초월: +20 강화 이상 영웅 이상 장비에 초월 옵션을 하나씩 더한다.
  // 초월석과 골드를 쓰고 확률로 성공한다. 실패하면 재료만 사라진다.
  /// 등급별 최대 초월 단계 (노말부터 고유).
  static const List<int> maxTranscend = [0, 0, 1, 2, 3, 3];

  /// 지금 초월 단계에서 다음 단계로 갈 때 드는 초월석과 성공 확률.
  static const List<int> transcendStones = [1, 2, 3];
  static const List<double> transcendChances = [0.5, 0.35, 0.2];

  /// 초월 골드 = transcendGold × transcendGoldGrowth^단계 × 장비 레벨 배율.
  static const double transcendGold = 3000;
  static const double transcendGoldGrowth = 2;

  /// 보스가 초월석을 떨어뜨릴 확률. 타락 단계마다 더해진다.
  static const double transcendStoneChance = 0.25;
  static const double transcendStoneChancePerCorruption = 0.05;

  // 초월 옵션 기본 수치
  static const double transcendProjectiles = 1;
  static const double transcendBossDamage = 0.25;
  static const double transcendHealOnKill = 0.5;
  static const double transcendThorns = 0.5;
  static const double transcendLastStand = 0.3;
  static const double transcendGoldFind = 0.3;

  /// 불굴은 체력이 이 비율 이하일 때만 붙는다.
  static const double lastStandThreshold = 0.3;

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

  // 운명: 스테이지를 클리어하면 카드 몇 장 중 하나를 고른다.
  static const int fateChoices = 3;

  /// 한 번에 나오는 같은 종류 카드 수 상한. 보상 카드는 더 적다.
  static const int fateTypeLimit = 2;
  static const int fateRewardLimit = 1;

  /// 런마다 운명 카드를 다시 뽑을 수 있는 횟수.
  static const int fateRerolls = 1;

  /// 카드 등급은 장비와 같은 6등급. 한 등급 오를 때마다 나올 가중치가 이 배율로 준다
  /// (장비보다 완만하다). 타락 단계의 등급 운도 똑같이 붙는다.
  static const double fateRarityRatio = 0.4;

  /// 카드 최소 등급 위로 한 등급마다 수치가 이 배율로 는다.
  static const double fateRarityGrowth = 1.4;

  /// 카드 한 장이 저주로 나올 확률 (저주가 있는 종류에서만).
  static const double fateCurseChance = 0.1;

  // 운명 카드 수치
  static const double fateMaxHp = 20;
  static const double fateMoveSpeed = 0.08;
  static const double fateDamage = 0.1;
  static const double fateMagnetRange = 0.4;
  static const double fateArmor = 15;

  /// 숨 고르기: 최대 체력의 이 비율을 회복한다.
  static const double fateHeal = 0.5;

  /// 잔불 줍기: 스테이지 레벨마다 이만큼.
  static const double fateEmber = 10;
  static const double fateXpGain = 0.2;
  static const double fateEmberGain = 0.3;
  static const double fateDropGain = 0.3;
  static const int fateWeaponLevels = 2;
  static const double fateAttackSpeed = 0.15;
  static const double fateCritChance = 0.08;

  /// 재의 홍수: 이만큼 레벨이 오른다.
  static const int fateLevels = 2;
  static const double fateLifeSteal = 0.03;
  static const double fateLordDamage = 0.3;
  static const double fateLordMaxHp = 50;

  // 저주: 고정 페널티와 등급만큼 커지는 보상을 함께 준다. 같은 저주를 또 고르면 곱해진다.
  static const double curseEnemyHp = 1.3;
  static const double curseEmberGain = 1;
  static const double curseEnemyDamage = 1.3;
  static const double curseDropGain = 1;
  static const double curseMaxHp = -30;
  static const double curseDamage = 0.4;

  // 화톳불 영구 강화: 레벨마다 오르는 양. 다음 레벨 비용은 이 배율씩 는다.
  static const double upgradeCostGrowth = 1.5;
  static const double upgradeMaxHp = 10;
  static const double upgradeDamage = 0.05;
  static const double upgradeMoveSpeed = 0.03;
  static const double upgradeArmor = 5;
  static const double upgradeHpRegen = 0.2;
  static const double upgradeMagnetRange = 0.1;
  static const double upgradeXpGain = 0.05;
  static const double upgradeEmberGain = 0.05;

  /// 운명 카드 등급 운. 타락 단계의 등급 운에 더해진다.
  static const double upgradeFateLuck = 0.1;

  // 무기 공통
  static const int weaponMaxLevel = 5;

  // 무기 각성: 최대 레벨 무기 + 짝이 되는 패시브가 있으면 레벨업 때 고를 수 있다.
  static const double awakenDamageMultiplier = 1.5;

  /// 업화의 대검: 칼날 수 증가와 궤도 반지름 배율.
  static const int infernoBladeBonus = 2;
  static const double infernoOrbitScale = 1.3;

  /// 유성 잔불: 맞힌 자리에서 터져 주변에 원래 피해의 이 비율을 준다.
  static const double meteorRadius = 70;
  static const double meteorRatio = 0.6;

  /// 폭풍 석궁: 한 번에 쏘는 화살 수, 사이 각도(라디안), 추가 관통.
  static const int stormArrows = 3;
  static const double stormSpread = 0.15;
  static const int stormPierceBonus = 3;

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
