import 'monster_sprites.dart';

/// 졸개가 움직이고 공격하는 방식.
enum EnemyBehavior {
  /// 곧장 다가와 몸으로 부딪힌다.
  chase('돌격'),

  /// 빠르고 약하다. 몇 마리씩 몰려와 좌우로 흔들리며 다가온다.
  swarm('떼'),

  /// 느리고 크고 단단하다. 다른 졸개에게 밀리지 않는다.
  brute('거구'),

  /// 멈춰서 힘을 모은 뒤 노린 방향으로 곧게 돌진한다.
  charger('돌진'),

  /// 거리를 두고 탄을 쏜다.
  shooter('사격'),

  /// 거리를 두고 플레이어 발밑에 예고 장판을 깐다. 잠시 뒤 터진다.
  caster('주술'),

  /// 가까이 오면 멈춰서 깜빡이다 터진다.
  bomber('자폭'),

  /// 쓰러지면 작은 둘로 갈라진다.
  splitter('분열'),

  /// 지그재그로 날아들고 반쯤 비친다.
  phantom('망령');

  const EnemyBehavior(this.label);

  final String label;
}

/// 지역마다 나오는 졸개 종류. 지역은 이 중 여섯 종류를 쓴다 ([Region.roster]).
///
/// 체력 · 속도 · 피해는 그 지역 기본 졸개 대비 배율이고, [size] 는 충돌 반지름 배율.
/// [xp] 는 쓰러질 때 떨어지는 재의 결정 수.
enum EnemyKind {
  // 잿빛 평원
  ashWalker('잿빛 망자', MonsterSprite.tinyZombie, EnemyBehavior.chase),
  ashBat(
    '잿빛 박쥐',
    MonsterSprite.batAsh,
    EnemyBehavior.swarm,
    hp: 0.45,
    speed: 1.5,
    damage: 0.6,
    size: 0.8,
  ),
  ashSlime(
    '재 슬라임',
    MonsterSprite.slimeAsh,
    EnemyBehavior.splitter,
    hp: 1.3,
    speed: 0.8,
  ),
  boneThrower(
    '해골 투석꾼',
    MonsterSprite.skelet,
    EnemyBehavior.shooter,
    hp: 0.8,
    speed: 0.9,
  ),
  ashRaider(
    '잿빛 약탈자',
    MonsterSprite.orcAsh,
    EnemyBehavior.charger,
    hp: 1.3,
    damage: 1.3,
    size: 1.1,
  ),
  ashOgre(
    '잿더미 거한',
    MonsterSprite.ogreAsh,
    EnemyBehavior.brute,
    hp: 4,
    speed: 0.6,
    damage: 1.6,
    size: 1.6,
    xp: 3,
  ),

  // 가라앉은 성당
  drownedSkeleton('익사한 해골', MonsterSprite.skeletDrowned, EnemyBehavior.chase),
  frostWisp(
    '서리 혼불',
    MonsterSprite.wispFrost,
    EnemyBehavior.phantom,
    hp: 0.7,
    speed: 1.2,
  ),
  paleChanter(
    '창백한 성가대',
    MonsterSprite.necromancerPale,
    EnemyBehavior.caster,
    hp: 0.9,
    speed: 0.8,
  ),
  frostSlime(
    '서리 슬라임',
    MonsterSprite.slimeFrost,
    EnemyBehavior.splitter,
    hp: 1.3,
    speed: 0.8,
  ),
  bloatedDrowned(
    '부푼 익사체',
    MonsterSprite.tinyZombieDrowned,
    EnemyBehavior.bomber,
    hp: 0.7,
    speed: 1.25,
  ),
  tideWarden(
    '조수의 파수꾼',
    MonsterSprite.maskedOrcTide,
    EnemyBehavior.brute,
    hp: 4,
    speed: 0.65,
    damage: 1.5,
    size: 1.4,
    xp: 3,
  ),

  // 불타는 숲
  fireImp('불꽃 임프', MonsterSprite.imp, EnemyBehavior.chase, speed: 1.1),
  emberBat(
    '불티 박쥐',
    MonsterSprite.batEmber,
    EnemyBehavior.swarm,
    hp: 0.45,
    speed: 1.55,
    damage: 0.6,
    size: 0.8,
  ),
  flameWisp(
    '화염 정령',
    MonsterSprite.wispEmber,
    EnemyBehavior.bomber,
    hp: 0.7,
    speed: 1.3,
  ),
  emberShaman(
    '불씨 주술사',
    MonsterSprite.necromancerEmber,
    EnemyBehavior.shooter,
    hp: 0.8,
    speed: 0.9,
  ),
  charredHulk(
    '숯덩이 거인',
    MonsterSprite.bigZombieChar,
    EnemyBehavior.brute,
    hp: 4,
    speed: 0.6,
    damage: 1.6,
    size: 1.6,
    xp: 3,
  ),
  lavaSlime(
    '용암 슬라임',
    MonsterSprite.slimeLava,
    EnemyBehavior.splitter,
    hp: 1.3,
    speed: 0.85,
  ),

  // 녹슨 요새
  orcSoldier('오크 병사', MonsterSprite.orcWarrior, EnemyBehavior.chase),
  orcLancer(
    '오크 창기병',
    MonsterSprite.orcLancer,
    EnemyBehavior.charger,
    hp: 1.3,
    damage: 1.3,
    size: 1.1,
  ),
  rustArcher(
    '녹슨 석궁병',
    MonsterSprite.skeletRust,
    EnemyBehavior.shooter,
    hp: 0.8,
    speed: 0.9,
  ),
  sparkWisp(
    '불똥 혼불',
    MonsterSprite.wispSpark,
    EnemyBehavior.phantom,
    hp: 0.7,
    speed: 1.2,
  ),
  powderGoblin(
    '화약 고블린',
    MonsterSprite.impGoblin,
    EnemyBehavior.bomber,
    hp: 0.7,
    speed: 1.3,
  ),
  rustOgre(
    '녹슨 거한',
    MonsterSprite.ogreRust,
    EnemyBehavior.brute,
    hp: 4,
    speed: 0.6,
    damage: 1.6,
    size: 1.6,
    xp: 3,
  ),

  // 꺼지지 않는 심장
  chort('초트', MonsterSprite.chort, EnemyBehavior.chase),
  bloodBat(
    '피박쥐',
    MonsterSprite.batBlood,
    EnemyBehavior.swarm,
    hp: 0.45,
    speed: 1.55,
    damage: 0.6,
    size: 0.8,
  ),
  bloodSlime(
    '피 슬라임',
    MonsterSprite.slimeBlood,
    EnemyBehavior.splitter,
    hp: 1.3,
    speed: 0.85,
  ),
  bloodPriest(
    '피의 사제',
    MonsterSprite.necromancerBlood,
    EnemyBehavior.caster,
    hp: 0.9,
    speed: 0.8,
  ),
  voidRunner(
    '공허 돌격귀',
    MonsterSprite.chortVoid,
    EnemyBehavior.charger,
    hp: 1.3,
    damage: 1.3,
    size: 1.1,
  ),
  fleshHulk(
    '살덩이 거구',
    MonsterSprite.bigZombieFlesh,
    EnemyBehavior.brute,
    hp: 4,
    speed: 0.6,
    damage: 1.6,
    size: 1.6,
    xp: 3,
  );

  const EnemyKind(
    this.label,
    this.sprite,
    this.behavior, {
    this.hp = 1,
    this.speed = 1,
    this.damage = 1,
    this.size = 1,
    this.xp = 1,
  });

  final String label;
  final MonsterSprite sprite;
  final EnemyBehavior behavior;
  final double hp;
  final double speed;
  final double damage;
  final double size;
  final int xp;

  /// 웨이브에서 이 종류가 뽑힐 가중치.
  int get weight => switch (behavior) {
    EnemyBehavior.chase => 10,
    EnemyBehavior.swarm => 5,
    EnemyBehavior.splitter => 5,
    EnemyBehavior.phantom => 5,
    EnemyBehavior.charger => 4,
    EnemyBehavior.bomber => 4,
    EnemyBehavior.shooter => 4,
    EnemyBehavior.caster => 3,
    EnemyBehavior.brute => 3,
  };
}
