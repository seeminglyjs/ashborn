/// 적 · 보스 스프라이트 시트. 걷기 애니메이션 [frameCount] 장을 가로로 붙였고, 모두 오른쪽을 본다.
/// 앞쪽은 0x72 DungeonTileset II (CC-0) 원본과 그 변종 (`tool/assets/sprites.py` · `monsters.py`),
/// 뒤쪽은 Endesga 32 로 처음부터 그린 것 (`new_monsters.py` · `bosses.py`).
///
/// 0x72 원본 big_zombie · necromancer · ogre · masked_orc · big_demon 시트도 assets 에 있지만
/// 게임에서 직접 쓰지 않는다. `monsters.py` 가 지역 변종을 만드는 원본이다.
enum MonsterSprite {
  tinyZombie('tiny_zombie', 16, 16),
  skelet('skelet', 16, 16),
  imp('imp', 16, 16),
  orcWarrior('orc_warrior', 16, 23),
  chort('chort', 16, 23),

  // 아래는 `tool/assets/monsters.py` 가 만든 재채색 변종과 새로 그린 몬스터.
  orcAsh('orc_ash', 16, 23),
  ogreAsh('ogre_ash', 32, 36),
  skeletDrowned('skelet_drowned', 16, 16),
  tinyZombieDrowned('tiny_zombie_drowned', 16, 16),
  maskedOrcTide('masked_orc_tide', 16, 23),
  necromancerPale('necromancer_pale', 16, 23),
  necromancerEmber('necromancer_ember', 16, 23),
  bigZombieChar('big_zombie_char', 32, 36),
  orcLancer('orc_lancer', 16, 23),
  skeletRust('skelet_rust', 16, 16),
  impGoblin('imp_goblin', 16, 16),
  ogreRust('ogre_rust', 32, 36),
  necromancerBlood('necromancer_blood', 16, 23),
  chortVoid('chort_void', 16, 23),
  bigZombieFlesh('big_zombie_flesh', 32, 36),
  slimeAsh('slime_ash', 16, 16),
  slimeFrost('slime_frost', 16, 16),
  slimeLava('slime_lava', 16, 16),
  slimeBlood('slime_blood', 16, 16),
  batAsh('bat_ash', 16, 16),
  batEmber('bat_ember', 16, 16),
  batBlood('bat_blood', 16, 16),
  wispFrost('wisp_frost', 16, 16),
  wispEmber('wisp_ember', 16, 16),
  wispSpark('wisp_spark', 16, 16),

  // `tool/assets/new_monsters.py` 가 Endesga 32 로 처음부터 그린 몬스터.
  carrionCrow('carrion_crow', 16, 16),
  ashRam('ash_ram', 32, 36),
  bogCroc('bog_croc', 32, 23),
  emberMaw('ember_maw', 16, 23),
  emberDrake('ember_drake', 16, 23),
  rustScorpion('rust_scorpion', 16, 16),
  flameLizard('flame_lizard', 16, 23),

  // `tool/assets/bosses.py` 가 처음부터 그린 지역 보스. 졸개보다 큰 48x48 판.
  bossAshGiant('boss_ash_giant', 48, 48),
  bossDrownedPriest('boss_drowned_priest', 48, 48),
  bossBurningTreant('boss_burning_treant', 48, 48),
  bossRustKnight('boss_rust_knight', 48, 48),
  bossUndyingHeart('boss_undying_heart', 48, 48);

  const MonsterSprite(this.file, this.width, this.height);

  static const int frameCount = 4;

  final String file;

  /// 프레임 한 장의 픽셀 크기.
  final double width;
  final double height;

  /// `assets/images/` 기준 경로.
  String get path => 'sprites/enemies/$file.png';
}
