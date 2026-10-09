/// 0x72 DungeonTileset II (CC-0) 에서 가져온 적 · 보스 스프라이트 시트와 그 변종.
/// 걷기 애니메이션 [frameCount] 장을 가로로 붙였고, `tool/assets/sprites.py` 가 만든다.
/// 원본은 모두 오른쪽을 보고 있다.
enum MonsterSprite {
  tinyZombie('tiny_zombie', 16, 16),
  skelet('skelet', 16, 16),
  imp('imp', 16, 16),
  orcWarrior('orc_warrior', 16, 23),
  chort('chort', 16, 23),
  bigZombie('big_zombie', 32, 36),
  necromancer('necromancer', 16, 23),
  ogre('ogre', 32, 36),
  maskedOrc('masked_orc', 16, 23),
  bigDemon('big_demon', 32, 36),

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
  wispSpark('wisp_spark', 16, 16);

  const MonsterSprite(this.file, this.width, this.height);

  static const int frameCount = 4;

  final String file;

  /// 프레임 한 장의 픽셀 크기.
  final double width;
  final double height;

  /// `assets/images/` 기준 경로.
  String get path => 'sprites/enemies/$file.png';
}
