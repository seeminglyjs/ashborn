/// 전투 밸런스 수치. 튜닝은 이 파일에서만 한다.
abstract final class Balance {
  // 캐릭터 해금: 골드로 산다. 잿불 기사는 처음부터 쓸 수 있다.
  static const int witchPrice = 10000;
  static const int hunterPrice = 30000;

  // 플레이어
  static const double playerRadius = 16;

  /// 구조물에 부딪히는 발 자리: 몸 중심에서 아래로 [playerFootOffset], 반지름 [playerFootRadius].
  static const double playerFootOffset = 11;
  static const double playerFootRadius = 8;
  static const double playerSpeed = 160;
  static const double playerInvulnerableTime = 0.5;

  /// 16x28 캐릭터 스프라이트를 몇 배로 그릴지와, 맞았을 때 피격 프레임을 보여 주는 시간.
  static const double playerSpriteScale = 2;
  static const double playerHitPoseTime = 0.15;

  /// 원거리 기본 무기(석궁 · 잔불 구체)를 쏜 뒤 발사 자세와 장전 · 거두기 자세를 보여 주는 시간.
  static const double shotPoseTime = 0.12;
  static const double reloadPoseTime = 0.14;

  /// 바닥 아이템이 끌려오기 시작하는 거리.
  static const double magnetRange = 70;

  // 줍는 아이템
  static const double pickupSpeed = 360;
  static const double ashShardSize = 10;
  // 막판 적 수를 줄이며(아래 웨이브 절) 처치 수가 약 절반이 되어, 처치당 보상(경험치 ·
  // 잔불 · 골드 · 강화석 · 장비 드랍)을 그만큼 올려 진행 속도는 그대로 둔다.
  static const double ashShardXp = 1.9;

  // 레벨: 다음 레벨까지 xpBase + xpGrowth * (레벨 - 1) 경험치.
  static const double xpBase = 5;

  /// 졸개가 다양해지며 (떼 · 거구) 경험치가 늘어난 만큼 레벨 곡선을 가파르게 했다.
  static const double xpGrowth = 9;

  /// 레벨업 때 제시되는 선택지 수.
  static const int levelUpChoices = 3;

  /// 레벨업 · 은총 카드는 한 화면에 가로로 늘어놓으므로 많아야 이만큼.
  static const int maxCardChoices = 4;

  // 적 (재의 무리)
  static const double enemyRadius = 14;

  /// 적 · 보스 스프라이트의 큰 변이 충돌 지름의 몇 배인지. 키 큰 스프라이트는 높이를
  /// 0.75 배로 쳐서 너무 작아지지 않게 한다.
  static const double enemySpriteSize = 1.15;

  /// 적 걷기 애니메이션 한 프레임의 시간.
  static const double enemyWalkFrameTime = 0.12;

  /// 걷는 적이 늘었다 줄었다 하는 비율, 통통 튀는 높이(보통 졸개 기준 픽셀), 기우는 각도(라디안).
  static const double enemyBounceSquash = 0.07;
  static const double enemyBounceHop = 2.5;
  static const double enemyBounceLean = 0.08;
  static const double enemySpeed = 70;
  static const double enemyBaseHp = 20;
  static const double enemyContactDamage = 10;

  /// 한 스테이지 안에서 이 시간(초)이 지날 때마다 적 체력이 기본값만큼 늘어난다.
  static const double enemyHpGrowthPeriod = 240;

  /// 겹친 적끼리 밀어내는 속도.
  static const double enemySeparationStrength = 120;

  // 졸개 행동 (EnemyBehavior)
  /// 떼: 한 번에 몇 마리씩 몰려 나오고, 다가오며 좌우로 흔들리는 세기와 빠르기.
  static const int swarmPack = 3;
  static const double swarmWeave = 0.6;
  static const double swarmWeaveFrequency = 3;

  /// 망령: 지그재그 세기와 빠르기, 비치는 정도.
  static const double phantomZigzag = 1.1;
  static const double phantomZigzagFrequency = 2.2;
  static const double phantomOpacity = 0.7;

  /// 돌진: 이 거리 안에 들면 멈춰서 [chargeWindup] 초 동안 힘을 모은 뒤
  /// 이동 속도의 [chargeSpeed] 배로 [chargeDash] 초 돌진한다. 다음 돌진까지 [chargeCooldown] 초.
  static const double chargeRange = 260;
  static const double chargeWindup = 0.7;
  static const double chargeDash = 0.55;
  static const double chargeSpeed = 4.5;
  static const double chargeCooldown = 3.5;

  /// 사격: 이 거리를 지키며 [shooterCooldown] 초마다 [shooterWindup] 초 조준한 뒤 쏜다.
  static const double shooterRange = 240;
  static const double shooterCooldown = 2.8;
  static const double shooterWindup = 0.45;

  /// 적 탄: 속도, 반지름, 수명, 접촉 피해 대비 배율. 한꺼번에 날아다닐 수 있는 수.
  static const double enemyBulletSpeed = 200;
  static const double enemyBulletRadius = 6;
  static const double enemyBulletLifetime = 4;
  static const double enemyBulletDamage = 0.8;
  static const int maxEnemyBullets = 60;

  /// 주술: 이 거리를 지키며 [casterCooldown] 초마다 플레이어 발밑에 장판을 깐다.
  /// 장판은 [casterBlastDelay] 초 뒤 터지며 접촉 피해의 [casterBlastDamage] 배.
  static const double casterRange = 280;
  static const double casterCooldown = 4;
  static const double casterBlastRadius = 55;
  static const double casterBlastDelay = 1.1;
  static const double casterBlastDamage = 1.2;

  /// 자폭: 이 거리 안에 들면 멈춰서 [bomberFuse] 초 깜빡이다 터진다.
  static const double bomberTrigger = 60;
  static const double bomberFuse = 0.9;
  static const double bomberRadius = 75;
  static const double bomberDamage = 1.5;

  /// 분열: 쓰러지면 이만큼 갈라지고, 새끼는 부모 최대 체력과 크기의 이 비율.
  static const int splitCount = 2;
  static const double splitHp = 0.35;
  static const double splitSize = 0.65;

  // 맵 함정
  /// 가시: 이 주기마다 [spikeUpTime] 초 솟는다. 솟기 [spikeWarning] 초 전부터 끝이 차오른다.
  static const double spikePeriod = 3.5;
  static const double spikeUpTime = 1;
  static const double spikeWarning = 0.6;

  /// 화염 분출구: 이 주기마다 [ventBurstTime] 초 불기둥을 뿜고, 밑동에서 [ventRadius] 안이 탄다.
  static const double ventPeriod = 4.5;
  static const double ventBurstTime = 1.2;
  static const double ventWarning = 0.8;
  static const double ventRadius = 30;

  /// 함정 피해: 플레이어는 그 스테이지 졸개 접촉 피해의 이 배율, 적은 최대 체력의 이 비율.
  static const double trapDamage = 1.5;
  static const double trapEnemyDamage = 0.3;

  // 타격감
  /// 맞은 졸개가 뒤로 밀리는 속도와 그 속도가 줄어드는 빠르기. 치명타는 [critKnockback] 배.
  static const double hitKnockback = 110;
  static const double knockbackDecay = 9;
  static const double critKnockback = 1.8;

  /// 거구는 밀림이 이 비율로 줄어든다. 보스는 밀리지 않는다.
  static const double bruteKnockback = 0.25;

  /// 화면 흔들림 최대 폭 (월드 단위, 흔들림 0.5초어치일 때).
  static const double shakePower = 14;

  /// 맞은 적이 커졌다 돌아오는 정도와 시간.
  static const double hitPop = 0.18;
  static const double hitPopTime = 0.12;

  // 스테이지: 런 안에서 지역을 하나 지날 때마다 적 체력과 피해가 이 배율로 는다.
  static const double stageHpGrowth = 1.35;
  static const double stageDamageGrowth = 1.2;

  /// 타락 단계가 하나 오를 때마다 적 체력 · 피해 배율. 런은 늘 레벨 1 로 시작하므로 예전처럼
  /// 스테이지 다섯 개만큼(체력 1.35^5 ≈ 4.5배) 키우지 않고, 장비 · 은총으로 따라갈 만큼만 키운다.
  /// 체력 3.3 · 피해 2.2 에서는 시뮬레이터 봇이 4시간에 타락 11단계까지 막힘 없이 올라가
  /// (예전 진행은 약 6단계) 올렸다.
  static const double corruptionHpGrowth = 4.0;
  static const double corruptionDamageGrowth = 2.5;

  /// 타락 0단계 첫 지역들의 적 체력 · 피해 배율. 그 뒤는 1.
  static const List<double> earlyStageEase = [0.35, 0.55, 0.75, 0.9];

  // 타락 특수 규칙 (CorruptionRule).
  /// 정예 출현: 웨이브 적이 정예일 확률, 체력 · 피해 · 크기 배율, 장비 드랍 확률 배율,
  /// 경험치(재의 결정) 배율. 잡으면 강화석 [eliteStones] 개를 확정으로 준다.
  static const double eliteChance = 0.04;
  static const double eliteHp = 4;
  static const double eliteDamage = 1.5;
  static const double eliteSize = 1.35;
  static const double eliteDropBonus = 6;
  static const int eliteXp = 3;
  static const int eliteStones = 1;

  /// 보스 재생: 이 시간(초) 동안 맞지 않으면 초당 최대 체력의 [bossRegenRate] 만큼 회복한다.
  static const double bossRegenDelay = 3;
  static const double bossRegenRate = 0.015;

  /// 잿불 유해: 쓰러진 졸개가 터질 확률, 예고 시간, 반지름, 접촉 피해 대비 피해.
  /// 한꺼번에 깔리는 유해는 [maxDeathBlasts] 개까지.
  static const double deathBlastChance = 0.2;
  static const double deathBlastDelay = 0.9;
  static const double deathBlastRadius = 34;
  static const double deathBlastDamage = 0.8;
  static const int maxDeathBlasts = 12;

  /// 무리 습격: 적 이동 속도 증가율과 스폰 한 번에 더 나오는 수.
  static const double frenzySpeed = 0.12;
  static const int frenzyBatch = 1;

  /// 이른 격노: 보스가 격노하는 체력 비율.
  static const double earlyEnrageHp = 0.75;

  /// 정복 (마지막 지역 보스 처치): 강화석 [conquestStones] × (타락 단계 + 1) 과
  /// 스테이지 레벨 × [conquestGold] 골드. 그 단계를 처음 정복하면 초월석 [firstConquestTranscend] 개.
  static const int conquestStones = 5;
  static const double conquestGold = 150;
  static const int firstConquestTranscend = 1;

  /// 스테이지 시작 후 이 시간(초)이 지나면 보스가 나온다.
  static const double stageDuration = 180;

  /// 지역 졸개 종류(로스터 순서대로)가 나오기 시작하는 스테이지 시간(초).
  /// 지역 로스터는 일곱에서 여덟 종류라, 짧은 로스터는 앞의 일곱 칸만 쓴다.
  static const List<double> rosterUnlock = [0, 0, 20, 40, 60, 80, 100, 120];

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

  /// 보스는 걸어오다 이 간격마다 지역 기술을 하나 쓴다 (BossMove).
  /// 소환은 [bossSummon] 마리 (격노하면 [bossEnragedSummon]).
  static const int bossSummon = 3;
  static const int bossEnragedSummon = 5;

  /// 체력이 [bossEnrageHp] 아래로 떨어지면 격노해 간격이 [bossEnragedInterval] 배가 된다.
  static const double bossMoveInterval = 3.6;
  static const double bossEnrageHp = 0.5;
  static const double bossEnragedInterval = 0.65;

  /// 돌진: 힘 모으는 시간(연속 돌진은 더 짧다), 돌진 시간과 걷기 대비 속도.
  static const double bossChargeWindup = 0.8;
  static const double bossRushWindup = 0.45;
  static const double bossChargeDuration = 0.6;
  static const double bossChargeSpeed = 3.5;

  /// 내려찍기: 힘 모으는 시간, 지진파가 퍼지는 거리와 속도.
  /// 속도는 [playerSpeed] 보다 조금 느려서, 예고를 보고 바로 바깥으로 달리면 따돌릴 수 있다.
  /// (예전 340 거리 · 약 378/s 는 화면 안이면 피할 길이 없었다.)
  static const double bossSlamWindup = 0.8;
  static const double bossSlamRadius = 230;
  static const double bossSlamSpeed = 150;

  /// 충격파 · 운석은 보스 접촉 피해의 이 배율, 탄은 [bossBulletDamage] 배.
  static const double bossHazardDamage = 1;
  static const double bossBulletDamage = 0.5;
  static const double bossSpiralTime = 2.4;

  /// 운석: 떨어지기까지의 시간, 크기, 플레이어 둘레로 흩어지는 거리, 불타는 숲에서 타오르는 시간.
  static const double bossMeteorDelay = 1.2;
  static const double bossMeteorRadius = 70;
  static const double bossMeteorSpread = 150;
  static const double bossMeteorLinger = 2.5;

  /// 순간이동: 플레이어에게서 이 거리에 나타난다.
  static const double bossBlinkDistance = 160;

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

  /// 스테이지 시간이 이만큼 지나면 스폰이 더 늘지 않는다 (보스 직전에 쏟아지지 않게).
  /// 이 뒤로는 초당 약 6마리로 일정하다.
  static const double spawnGrowthCap = 120;

  /// 보스가 나온 뒤에는 스폰 간격이 이 배율로 길어진다 (보스에 집중하도록).
  static const double bossSpawnSlow = 1.6;
  static const int maxEnemies = 220;

  /// 화면 밖 스폰 거리 여유분.
  static const double spawnMargin = 60;

  // 패시브
  static const int passiveMaxLevel = 5;
  static const double passiveMaxHpPerLevel = 20;
  static const double passiveMoveSpeedPerLevel = 0.08;
  static const double passiveMagnetPerLevel = 0.25;
  static const double passiveDamagePerLevel = 0.08;
  static const double passiveAttackSpeedPerLevel = 0.08;
  static const double passiveCritChancePerLevel = 0.05;
  static const double passiveCritDamagePerLevel = 0.2;
  static const double passiveArmorPerLevel = 8;
  static const double passiveRegenPerLevel = 0.5;
  static const double passiveXpPerLevel = 0.1;
  static const double passiveAreaPerLevel = 0.1;

  // 직업 숙련: 캐릭터마다 따로 쌓는 숙련 경험치. 숙련 레벨 1마다 직업 패시브 포인트 1.
  /// 런에서 모은 재의 결정 경험치가 그대로 숙련 경험치가 되고, 보스를 잡으면 스테이지 레벨마다 더 준다.
  static const double masteryBossXp = 120;

  /// 숙련 레벨 L → L+1 경험치 = masteryXpBase × masteryXpGrowth^L.
  static const double masteryXpBase = 800;
  static const double masteryXpGrowth = 1.12;

  /// 직업 패시브 최대 레벨. 숙련 레벨 상한은 이 값 × 직업 패시브 수.
  static const int classPassiveMaxLevel = 10;

  /// 포인트 되돌리기 골드: 쓴 포인트 하나마다.
  static const int masteryResetGold = 400;

  // 직업 패시브 수치: 1레벨 값과 레벨마다 더해지는 값.
  /// 튕겨내기 (기사): 피격 시 막을 확률과, 받을 뻔한 피해 대비 되돌려 주는 피해 배율.
  static const double parryChance = 0.06;
  static const double parryChancePerLevel = 0.02;
  static const double parryReflect = 1.5;
  static const double parryReflectPerLevel = 0.35;

  /// 고유 스킬 특성: 그 스킬 하나만 강하게 한다. (첫째 수치, 둘째 수치) 의 1레벨 값과 레벨마다 더하는 값.
  /// 대지의 울림 (기사 · 대지 강타): 피해 · 범위.
  static const double quakeDamage = 0.06;
  static const double quakeDamagePerLevel = 0.04;
  static const double quakeArea = 0.04;
  static const double quakeAreaPerLevel = 0.02;

  /// 심판관 (기사 · 심판의 일격): 피해 · 범위.
  static const double judgeDamage = 0.06;
  static const double judgeDamagePerLevel = 0.04;
  static const double judgeArea = 0.04;
  static const double judgeAreaPerLevel = 0.02;

  /// 불굴의 함성 (기사 · 전투 함성): 쿨다운 감소 · 함성 뒤 받는 피해 감소 추가.
  static const double rallyCooldown = 0.04;
  static const double rallyCooldownPerLevel = 0.02;
  static const double rallyGuard = 0.02;
  static const double rallyGuardPerLevel = 0.01;

  /// 별똥 부르기 (마녀 · 운석 낙하): 피해 · 폭발 범위.
  static const double starfallDamage = 0.06;
  static const double starfallDamagePerLevel = 0.04;
  static const double starfallArea = 0.04;
  static const double starfallAreaPerLevel = 0.02;

  /// 불바람 (마녀 · 화염 회오리): 피해 · 지속 시간.
  static const double firestormDamage = 0.06;
  static const double firestormDamagePerLevel = 0.04;
  static const double firestormDuration = 0.05;
  static const double firestormDurationPerLevel = 0.03;

  /// 정령 계약 (마녀 · 잔불 정령): 피해 · 회전 속도.
  static const double pactDamage = 0.06;
  static const double pactDamagePerLevel = 0.04;
  static const double pactSpeed = 0.04;
  static const double pactSpeedPerLevel = 0.03;

  /// 덫 장인 (사냥꾼 · 불씨 덫): 피해 · 폭발 범위.
  static const double trapperDamage = 0.06;
  static const double trapperDamagePerLevel = 0.04;
  static const double trapperArea = 0.04;
  static const double trapperAreaPerLevel = 0.02;

  /// 칼날 비 (사냥꾼 · 투척 단검): 피해 · 단검 속도.
  static const double bladeDamage = 0.06;
  static const double bladeDamagePerLevel = 0.04;
  static const double bladeSpeed = 0.05;
  static const double bladeSpeedPerLevel = 0.03;

  /// 사냥 그물 (사냥꾼 · 올가미 그물): 묶는 시간 · 감속 추가.
  static const double netterDuration = 0.06;
  static const double netterDurationPerLevel = 0.04;
  static const double netterSlow = 0.02;
  static const double netterSlowPerLevel = 0.01;

  /// 탄 · 장판을 튕겨 낼 때 되돌려 줄 적을 찾는 거리.
  static const double parryRange = 220;

  /// 연격의 달인 (기사): 대검 콤보 확률과 맹공 지속 시간(초).
  static const double swordMasteryCombo = 0.03;
  static const double swordMasteryComboPerLevel = 0.03;
  static const double swordMasteryOnslaught = 0.25;
  static const double swordMasteryOnslaughtPerLevel = 0.25;

  /// 강철 의지 (기사): 받는 피해 감소.
  static const double ironWill = 0.03;
  static const double ironWillPerLevel = 0.02;

  /// 원소 친화 (마녀): 점화 · 냉각 · 감전 축적과 점화 피해.
  static const double affinityBuildup = 0.1;
  static const double affinityBuildupPerLevel = 0.1;
  static const double affinityIgnite = 0.1;
  static const double affinityIgnitePerLevel = 0.1;

  /// 잔향 시전 (마녀): 무기가 한 번 더 나갈 확률.
  static const double spellEcho = 0.04;
  static const double spellEchoPerLevel = 0.02;

  /// 재의 장막 (마녀): 피해를 한 번 막는 장막이 다시 생기는 시간(초). 레벨마다 줄어든다.
  static const double ashVeil = 15;
  static const double ashVeilPerLevel = -1;

  /// 맹독 바르기 (사냥꾼): 중독 확률과 중독 피해.
  static const double envenomChance = 0.05;
  static const double envenomChancePerLevel = 0.025;
  static const double envenomDamage = 0.1;
  static const double envenomDamagePerLevel = 0.1;

  /// 질주 사격 (사냥꾼): 움직이는 동안 공격 속도.
  static const double momentum = 0.05;
  static const double momentumPerLevel = 0.025;

  /// 급소 노리기 (사냥꾼): 치명타 확률과 치명타 피해.
  static const double weakSpotChance = 0.03;
  static const double weakSpotChancePerLevel = 0.012;
  static const double weakSpotDamage = 0.1;
  static const double weakSpotDamagePerLevel = 0.05;

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

  // 상태이상
  /// 화염 · 냉기 · 번개는 확률이 아니라 쌓여서 터진다. 적 최대 체력의 이 비율만큼
  /// 그 속성 피해가 쌓이면 점화 · 냉각(→ 동결) · 감전이 걸린다. 보스는 [bossAilmentThreshold].
  static const double ailmentThreshold = 0.3;
  static const double bossAilmentThreshold = 0.02;

  /// 쌓인 원소가 초당 문턱의 이 비율씩 빠진다.
  static const double ailmentDecay = 0.15;

  /// 중독: 타격 전체 피해의 [poisonRatio] 배를 [poisonDuration] 초 동안 나눠 준다.
  /// 겹치지 않고 마지막에 걸린 중독으로 덮어쓴다. 중독된 적은 이동 · 공격 속도가 [poisonSlow] 느려지고,
  /// 1초마다 [poisonSpreadChance] 확률로 [spreadRange] 안의 적 하나에게 옮는다.
  static const double poisonDuration = 5;
  static const double poisonRatio = 1;
  static const double poisonSlow = 0.15;
  static const double poisonSpreadChance = 0.08;
  static const double spreadRange = 70;

  /// 출혈: 물리 피해의 [bleedRatio] 배가 기준. 걸린 뒤 1초마다 초당 피해가 [bleedRamp] 씩 커진다
  /// (5초 동안 평균 1.5배). 출혈 중에 맞으면 [bleedHitBonus] 만큼 더 아프다.
  static const double bleedDuration = 5;
  static const double bleedRatio = 1;
  static const double bleedRamp = 0.2;
  static const double bleedHitBonus = 0.15;

  /// 점화: 화염 피해가 쌓여 걸리고, [igniteInterval] 초마다 점화시킨 타격 화염 피해의
  /// [igniteRatio] 를 [igniteDuration] 초 동안 준다. 1초마다 [igniteSpreadChance] 확률로 옮는다.
  static const double igniteRatio = 0.1;
  static const double igniteInterval = 0.5;
  static const double igniteDuration = 4;
  static const double igniteSpreadChance = 0.08;

  /// 냉각: 냉기 피해가 쌓여 걸리고 [chillDuration] 초 동안 이동 · 공격 속도가 [chillSlow] 느려진다.
  /// 냉각 중에 또 쌓이면 [freezeDuration] 초 동결 (보스는 [bossFreezeScale] 배).
  static const double chillDuration = 3;
  static const double chillSlow = 0.25;
  static const double freezeDuration = 1;
  static const double bossFreezeScale = 0.5;

  /// 얼어 있다 쓰러지면 6방향으로 얼음 파편이 튄다. 동결시킨 냉기 피해의 [shardRatio] 배.
  static const int shardCount = 6;
  static const double shardRatio = 1;
  static const double shardSpeed = 420;
  static const double shardLifetime = 0.4;

  /// 감전: 번개 피해가 쌓여 걸리고 [shockStun] 초 굳으며, 주변 적 [shockChainTargets] 명에게
  /// 감전시킨 번개 피해의 [shockChainRatio] 배 연쇄 번개가 튄다.
  static const double shockStun = 0.3;
  static const int shockChainTargets = 3;
  static const double shockChainRatio = 0.6;
  static const double shockChainRange = 150;

  /// 바람: 바람 피해가 섞인 타격에 확률로 바람 검기(일직선 관통)나 소용돌이(넓은 범위, 2초)가 나간다.
  /// 둘 다 그 타격 바람 피해 기준. 너무 자주 나가지 않게 각각 재사용 대기 시간이 있다.
  static const double windSlashChance = 0.12;
  static const double windSlashCooldown = 0.35;
  static const double windSlashRatio = 1.5;
  static const double windSlashSpeed = 520;
  static const double windSlashLifetime = 0.6;
  static const double vortexChance = 0.04;
  static const double vortexCooldown = 1.2;
  static const double vortexRadius = 65;
  static const double vortexDuration = 2;
  static const double vortexTick = 0.25;

  /// 소용돌이 한 번 칠 때 바람 피해 배율 (2초 동안 8번 → 4.8배).
  static const double vortexRatio = 0.6;
  static const double vortexPull = 60;

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
  static const double killEmber = 0.28;
  static const double salvageEmber = 3;

  /// 분해 잔불은 등급이 오를 때마다 이 배율로 는다.
  static const double salvageRarityGrowth = 3;

  /// 장비 레벨 1 오를 때마다 분해 잔불과 강화 골드가 이 비율씩 는다.
  static const double emberPerItemLevel = 0.1;

  // 골드와 강화석: 처치와 보스로 얻고, 쓰러지거나 클리어할 때 정산된다. 장비 강화에 쓴다.
  // 졸개가 다양해지며(떼 · 분열) 처치 수가 약 두 배가 되어 처치당 보상을 낮췄다.
  // 강화석은 1/3, 골드 · 잔불 · 장비 드랍은 0.75배 (골드까지 절반이면 강화가 막혀 진행이 멈춘다).
  /// 처치당 골드 (스테이지 레벨마다).
  static const double killGold = 1.4;

  /// 스테이지 클리어 골드 (스테이지 레벨마다, 타락 보상 배율이 붙는다).
  static const double stageClearGold = 50;

  /// 처치당 강화석이 나올 확률 (타락 보상 배율이 붙는다).
  static const double stoneDropChance = 0.019;

  /// 보스가 주는 강화석. 타락 단계마다 하나씩 더.
  static const int bossStones = 3;

  // 장비 강화: 강화석과 골드를 쓰면 반드시 한 단계 오른다 (확률 없음).
  // 단계가 오를수록 재료가 가파르게 늘어, 예전 확률 강화의 기대 비용과 비슷하게 맞췄다.
  static const int maxEnhance = 30;

  /// 다음 단계 강화석 = enhanceStones + enhanceStonesPerStep × 단계
  /// + 단계² ÷ [enhanceStonesSquare] (내림).
  static const int enhanceStones = 1;
  static const int enhanceStonesPerStep = 1;
  static const int enhanceStonesSquare = 6;

  /// 다음 단계 골드 = enhanceGold × enhanceGoldGrowth^단계
  /// × enhanceRarityGrowth^등급 × 장비 레벨 배율.
  static const double enhanceGold = 50;
  static const double enhanceGoldGrowth = 1.16;
  static const double enhanceRarityGrowth = 1.5;

  /// 강화 1단계마다 모든 옵션 수치가 이 배율로 커진다 (복리: +20 은 약 6.7배, +30 은 약 17배).
  /// 적이 스테이지마다 지수로 강해지니, 재화로 사는 힘도 천장 없이 커지게 한다.
  static const double enhanceStatGrowth = 1.1;

  /// 이 강화 단계부터 초월할 수 있다.
  static const int transcendEnhance = 20;

  // 초월: +20 강화 이상 영웅 이상 장비에 초월 옵션을 하나씩 더한다.
  // 초월석과 골드를 쓰면 반드시 성공하고, 붙일 초월 옵션은 플레이어가 고른다 (확률 없음).
  /// 등급별 최대 초월 단계 (노말부터 고유).
  static const List<int> maxTranscend = [0, 0, 1, 2, 3, 3];

  /// 지금 초월 단계에서 다음 단계로 갈 때 드는 초월석.
  static const List<int> transcendStones = [2, 5, 12];

  /// 초월 골드 = transcendGold × transcendGoldGrowth^단계 × 장비 레벨 배율.
  static const double transcendGold = 6000;
  static const double transcendGoldGrowth = 3;

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
  static const int bagCapacity = 100;

  // 장비 드랍: 처치당 드랍 확률, 등급이 오를 때마다 드랍 가중치는 이 배율로 준다.
  static const double itemDropChance = 0.028;
  static const double rarityDropRatio = 0.25;

  /// 영웅 이상 장비는 드랍 가중치에 이 배율이 한 번 더 붙는다 (은총 카드 · 옵션 등급에는 없음).
  static const double highRarityDropScale = 0.5;

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

  /// 점화 · 냉각 · 감전 축적 증가 (쌓이는 양 +%).
  static const double rollAilmentBuildup = 0.15;
  static const double rollArmor = 5;
  static const double rollEvasion = 0.02;
  static const double rollEnergyShield = 8;
  static const double rollPhysicalReduction = 0.02;
  static const double rollResist = 0.04;
  static const double rollMoveSpeed = 0.03;
  static const double rollMagnetRange = 0.1;
  static const double rollXpGain = 0.05;

  // 신의 은총 (코드 이름 fate): 스테이지를 처음 클리어할 때마다 카드 몇 장 중 하나를 골라
  // 영구히 받는다. 스테이지마다 하나씩 끝없이 쌓이므로, 노말 한 장이 장비 옵션 한 줄
  // (roll* 값) 정도가 되게 잡았다 (런마다 사라지던 때의 약 40%).
  static const int fateChoices = 3;

  /// 한 번에 나오는 같은 종류 카드 수 상한. 보상 카드는 더 적다.
  static const int fateTypeLimit = 2;
  static const int fateRewardLimit = 1;

  /// 은총 한 번(스테이지 하나)마다 카드를 다시 뽑을 수 있는 횟수.
  static const int fateRerolls = 1;

  /// 카드 등급은 장비와 같은 6등급. 한 등급 오를 때마다 나올 가중치가 이 배율로 준다
  /// (장비보다 완만하다). 그 스테이지 타락 단계의 등급 운도 똑같이 붙는다.
  static const double fateRarityRatio = 0.4;

  /// 카드 최소 등급 위로 한 등급마다 수치가 이 배율로 는다.
  static const double fateRarityGrowth = 1.4;

  /// 카드 한 장이 저주로 나올 확률 (저주가 있는 종류에서만).
  static const double fateCurseChance = 0.1;

  // 은총 카드 수치 (노말 또는 카드 최소 등급 기준)
  static const double fateMaxHp = 8;
  static const double fateMoveSpeed = 0.03;
  static const double fateDamage = 0.04;
  static const double fateMagnetRange = 0.15;
  static const double fateArmor = 6;

  /// 신농의 약초: 스테이지를 클리어할 때마다 최대 체력의 이 비율을 회복한다.
  static const double fateHeal = 0.3;

  /// 조공명의 금화: 스테이지를 클리어할 때마다 스테이지 레벨마다 이만큼 잔불.
  static const double fateEmber = 6;
  static const double fateXpGain = 0.08;
  static const double fateEmberGain = 0.12;
  static const double fateDropGain = 0.12;

  /// 헤파이스토스의 망치: 출정할 때 기본 무기가 이만큼 레벨이 높다.
  static const int fateWeaponLevels = 1;
  static const double fateAttackSpeed = 0.05;
  static const double fateCritChance = 0.03;

  /// 다그다의 가마솥: 출정할 때 이만큼 레벨이 높다.
  static const int fateLevels = 1;
  static const double fateLifeSteal = 0.01;
  static const double fateLordDamage = 0.12;
  static const double fateLordMaxHp = 20;

  // 신의 은총 2차: 영역마다 3장 이상이 되도록 더한 카드. 노말 기준 수치.
  static const double fateHpRegen = 0.4;
  static const double fateEnergyShield = 8;
  static const double fateCritDamage = 0.1;
  static const double fateEvasion = 0.02;
  static const double fatePhysicalReduction = 0.025;

  /// 원소 은총 (레어 기준): 모든 공격에 무기 기본 피해의 이 비율만큼 그 속성 피해를 더한다.
  static const double fateElementDamage = 0.06;

  /// 원소 은총의 출혈 확률 (물리), 그리고 점화 · 냉각 · 감전 축적 증가.
  static const double fateElementAilment = 0.04;
  static const double fateElementBuildup = 0.12;

  /// 바람 은총은 상태이상 대신 이동 속도를 준다.
  static const double fateWindMoveSpeed = 0.02;

  // 저주: 고정 페널티와 등급만큼 커지는 보상을 함께 준다. 영구라 같은 저주는 한 번만 나오고,
  // 런마다 사라지던 때보다 페널티 · 보상을 모두 줄였다 (잔불 · 드랍 배율이 영구로 남는다).
  static const double curseEnemyHp = 1.2;
  static const double curseEmberGain = 0.5;
  static const double curseEnemyDamage = 1.2;
  static const double curseDropGain = 0.5;
  static const double curseMaxHp = -20;
  static const double curseDamage = 0.2;

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

  /// 은총 카드 등급 운. 타락 단계의 등급 운에 더해진다.
  static const double upgradeFateLuck = 0.1;

  /// 원소 · 상태이상 강화: 레벨마다 지금 수치(장비 · 은총 · 특성 합)를 이 비율만큼 키운다.
  /// 더하는 것이 아니라 곱하므로 원래 수치가 없으면 효과도 없다. 최대 레벨이면 1.5배.
  static const double upgradeAmplify = 0.05;
  static const double upgradeCritChance = 0.005;
  static const double upgradeCritDamage = 0.03;
  static const double upgradeResist = 0.01;

  // 무기 공통
  static const int weaponMaxLevel = 8;

  // 무기 각성: 최대 레벨 무기 + 짝이 되는 패시브가 있으면 레벨업 때 고를 수 있다.
  static const double awakenDamageMultiplier = 1.5;

  /// 거신의 대검: 범위 배율과 콤보 확률 증가.
  static const double titanArea = 1.3;
  static const double titanCombo = 0.25;

  /// 유성 잔불: 맞힌 자리에서 터져 주변에 원래 피해의 이 비율을 준다.
  static const double meteorRadius = 70;
  static const double meteorRatio = 0.6;

  /// 폭풍 석궁: 한 번에 쏘는 화살 수, 사이 각도(라디안), 추가 관통.
  static const int stormArrows = 3;
  static const double stormSpread = 0.15;
  static const int stormPierceBonus = 3;

  // 무기: 잔불 구체 (재의 마녀)
  /// 원소 폭주: [surgeLevel] 부터 [surgeEvery] 번째 시전은 구체 대신 4원소(화염 · 냉기 · 번개 · 바람)
  /// 레이저를 쏜다. 레이저는 구체 한 발의 [surgeDamage] 배 피해를 네 원소로 고루 나눠, 길이 [surgeLength]
  /// · 굵기 [surgeWidth] 줄 위의 적을 모두 꿰뚫는다. (예전 과열: 2배 화염구를 한 발 더 쏨)
  static const int surgeLevel = 4;
  static const int surgeEvery = 4;
  static const double surgeDamage = 4;
  static const double surgeLength = 520;
  static const double surgeWidth = 26;
  static const double surgeTime = 0.45;

  static const double emberOrbCooldown = 0.6;
  static const double emberOrbDamage = 12;
  static const double emberOrbRange = 420;
  static const double emberOrbSpeed = 520;
  static const double emberOrbLifetime = 1.2;
  static const double emberOrbRadius = 6;

  /// 구체를 여러 발 쏠 때 사이 각도(라디안).
  static const double emberOrbSpread = 0.2;

  // 무기: 강철 대검 (잿불 기사)
  // 쿨다운마다 익힌 기술을 차례로 하나씩 쓴다 (찌르기 → 휘두르기 → 내려찍기 → …).
  // 확률로 다음 기술을 곧바로 이어 쓰고 (콤보), 콤보가 2번 연달아 나면 맹공에 들어간다.
  static const double greatswordCooldown = 0.8;

  /// 대검의 무게: 기술마다 장비로 더해지는 피해까지 포함한 한 타 전체에 곱하는 배율.
  /// 타격 수가 적은 대검이 매 타격 고정 피해를 많이 받는 무기(구체 · 화살)에 밀리지 않게 한다.
  static const double thrustPower = 2.0;
  static const double swingPower = 1.5;
  static const double slamPower = 2.8;

  /// 이만큼 안에 적이 있어야 휘두른다.
  static const double greatswordReach = 135;

  /// 대검 그림의 한 픽셀 크기 (월드 단위).
  static const double greatswordPixel = 1.7;

  /// 찌르기: 앞으로 곧게 [thrustLength] 만큼, 폭 [thrustWidth] 안의 적을 모두 꿰뚫는다.
  static const double thrustDamage = 24;
  static const double thrustLength = 125;
  static const double thrustWidth = 30;

  /// 휘두르기: 앞쪽 [swingArc] (반각, 라디안) 부채꼴, 반지름 [swingRadius].
  static const int swingLevel = 2;
  static const double swingDamage = 19;
  static const double swingRadius = 105;
  static const double swingArc = 1.3;

  /// 내려찍기: 앞쪽 [slamOffset] 자리에 반지름 [slamRadius] 충격, 적을 밀어낸다.
  static const int slamLevel = 3;
  static const double slamDamage = 32;
  static const double slamOffset = 55;
  static const double slamRadius = 72;
  static const double slamKnockback = 240;

  /// 내려찍기 때 뛰어오르는 높이 (월드). 휘두르기와 한눈에 갈리게 몸째 솟았다 떨어진다.
  static const double slamLeap = 42;

  /// 콤보: 앞 기술이 끝나고 다음 기술이 나가기까지의 간격.
  static const double comboDelay = 0.2;

  /// 초월 투사체 옵션 1마다 대검 콤보 확률이 이만큼 는다.
  static const double comboPerProjectile = 0.1;

  /// 맹공: [onslaughtLevel] 레벨부터. 콤보가 [onslaughtStreak] 번 연달아 나면
  /// [onslaughtDuration] 초 동안 쿨다운이 [onslaughtCooldown] 배가 된다.
  static const int onslaughtLevel = 4;
  static const int onslaughtStreak = 2;
  static const double onslaughtDuration = 4;
  static const double onslaughtCooldown = 0.6;

  // 무기: 사냥 석궁 (불씨 사냥꾼)
  /// 연사: [volleyLevel] 부터 콤보 확률로 [volleyDelay] 초 뒤 한 번 더 쏜다.
  /// 헤드샷: [headshotLevel] 부터 사격마다 [headshotChance] 확률로 [headshotDamage] 배 피해에
  /// 끝없이 꿰뚫고 맞힌 적마다 반드시 출혈을 거는 화살. (예전 저격: 4번째 사격마다 2.5배 — 기대 피해는 비슷하다)
  /// 맹공: [hunterOnslaughtLevel] 부터 연사가 [onslaughtStreak] 번 연달아 나면 기사의 맹공과
  /// 같이 [onslaughtDuration] 초 동안 쿨다운이 [onslaughtCooldown] 배가 된다.
  static const int volleyLevel = 2;
  static const double volleyDelay = 0.12;
  static const int headshotLevel = 4;
  static const double headshotChance = 0.15;
  static const double headshotDamage = 3;
  static const int headshotPierce = 99;
  static const int hunterOnslaughtLevel = 6;

  static const double crossbowCooldown = 0.9;
  static const double crossbowDamage = 16;
  static const double crossbowRange = 520;
  static const double crossbowSpeed = 720;
  static const double crossbowLifetime = 1.0;

  /// 첫 적을 맞힌 뒤 추가로 꿰뚫는 수.
  static const int crossbowPierce = 3;

  // 무기: 대지 강타 (잿불 기사)
  static const double earthSlamCooldown = 2.2;
  static const double earthSlamDamage = 26;
  static const double earthSlamRadius = 95;
  static const double earthSlamKnockback = 280;

  /// 지진(각성): 여진이 퍼지기까지의 시간과 반지름 배율.
  static const double aftershockDelay = 0.35;
  static const double aftershockScale = 1.5;

  // 무기: 심판의 일격 (잿불 기사)
  static const double cleaveCooldown = 1.5;
  static const double cleaveDamage = 28;
  static const double cleaveRadius = 90;

  /// 참격 부채꼴 반각 (라디안).
  static const double cleaveArc = 1.05;

  // 무기: 운석 낙하 (재의 마녀)
  static const double meteorCooldown = 2.4;
  static const double meteorDamage = 30;
  static const double meteorBlastRadius = 55;
  static const double meteorFallTime = 0.45;
  static const double meteorTargetRange = 420;

  /// 유성우(각성): 떨어진 자리가 타오르는 시간과 0.5초마다 주는 피해 비율.
  static const double meteorBurnTime = 2;
  static const double meteorBurnRatio = 0.25;

  // 무기: 화염 회오리 (재의 마녀)
  static const double tornadoCooldown = 3;
  static const double tornadoDamage = 9;
  static const double tornadoRadius = 22;
  static const double tornadoSpeed = 90;
  static const double tornadoLifetime = 3;
  static const double tornadoHitInterval = 0.4;

  // 고유 스킬 (레벨업 카드로 얻는 직업 전용 무기).
  /// 전투 함성 (기사): 주변 적에게 피해를 주고 느리게 묶으며, 잠시 받는 피해가 줄어든다.
  static const double warCryCooldown = 5;
  static const double warCryDamage = 18;
  static const double warCryRadius = 120;
  static const double warCrySlow = 0.55;
  static const double warCrySlowTime = 1.4;
  static const double warCryGuard = 0.2;
  static const double warCryGuardTime = 3;

  /// 잔불 정령 (마녀): 몸 둘레를 도는 불덩이. 닿은 적을 [spiritHitInterval] 마다 태운다.
  static const double spiritCooldown = 0.5;
  static const double spiritDamage = 7;
  static const double spiritOrbit = 62;
  static const double spiritRadius = 9;
  static const double spiritTurnSpeed = 2.6;
  static const double spiritHitInterval = 0.45;

  /// 올가미 그물 (사냥꾼): 가까운 적 무리에 그물을 던져 묶어 두고 지속 피해를 준다.
  static const double netCooldown = 3.2;
  static const double netDamage = 16;
  static const double netRadius = 58;
  static const double netRange = 380;
  static const double netSlow = 0.7;
  static const double netTime = 2.2;
  static const double netFlightTime = 0.35;

  // 무기: 불씨 덫 (불씨 사냥꾼)
  static const double mineCooldown = 1.8;
  static const double mineDamage = 28;
  static const double mineRadius = 60;
  static const double mineTrigger = 24;
  static const double mineArmTime = 0.4;
  static const double mineLifetime = 12;
  static const int maxMines = 10;

  // 무기: 투척 단검 (불씨 사냥꾼)
  static const double knifeCooldown = 0.55;
  static const double knifeDamage = 7;
  static const double knifeSpeed = 620;
  static const double knifeLifetime = 0.7;
  static const double knifeSpread = 0.12;

  // 무기: 잿불 고리 (공용). 몸에 붙은 적만 태우던 좁은 고리(반지름 60, 초당 약 8)가 다른 무기보다
  // 확실히 약해서 넓히고 세게 했다: 초당 14, 반지름 80 (대지 강타 95 보다는 좁게).
  static const double auraDamage = 7;
  static const double auraRadius = 80;
  static const double auraTick = 0.5;

  /// 지옥불 고리(각성): 반지름 배율과 닿은 적에게 거는 둔화.
  static const double infernoAuraScale = 1.3;
  static const double infernoAuraSlow = 0.3;

  // 무기: 낙뢰 (공용)
  static const double thunderCooldown = 2.2;
  static const double thunderDamage = 24;
  static const double thunderRadius = 30;
  static const double thunderRange = 450;
  static const int thunderChain = 2;

  // 무기: 회전 차크람 (공용)
  static const double chakramCooldown = 2.5;
  static const double chakramDamage = 14;
  static const double chakramRadius = 13;
  static const double chakramSpeed = 380;
  static const double chakramReach = 260;
  static const double chakramHitInterval = 0.3;

  // 각성 연출: 각성하는 순간 플레이어 둘레로 퍼지는 빛.
  static const double awakenBurstRadius = 160;

  // 부술 수 있는 상자: 플레이어 둘레에 가끔 생기고, 무기로 부수면 보급품이 나온다.
  /// 첫 상자가 나오기까지와 그다음부터의 간격(초).
  static const double crateFirstDelay = 8;
  static const double crateInterval = 14;

  /// 동시에 있을 수 있는 상자 수. 이보다 멀어진 상자는 치운다.
  static const int maxCrates = 3;
  static const double crateDespawnDistance = 1400;

  /// 상자 대신 보물 상자가 나올 확률.
  static const double chestChance = 0.1;

  /// 상자 체력: 그 시점 졸개 체력의 배수. 보물 상자는 더 단단하다.
  static const double crateHpScale = 3;
  static const double chestHpScale = 6;
  static const double crateRadius = 13;

  /// 나무 상자에서 나오는 것의 가중치. 순서는 CrateDrop (물약 · 골드 · 강화석 · 자석 · 장비).
  static const List<int> crateDropWeights = [20, 50, 12, 8, 10];

  /// 회복 물약: 최대 체력의 이 비율을 채운다.
  static const double potionHeal = 0.1;

  /// 골드 주머니 (스테이지 레벨마다). 보물 상자는 [chestGoldScale] 배.
  static const double crateGold = 15;
  static const double chestGoldScale = 3;
}
