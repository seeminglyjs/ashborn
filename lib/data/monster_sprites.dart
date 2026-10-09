/// 0x72 DungeonTileset II (CC-0) 에서 가져온 적 · 보스 스프라이트 시트.
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
  bigDemon('big_demon', 32, 36);

  const MonsterSprite(this.file, this.width, this.height);

  static const int frameCount = 4;

  final String file;

  /// 프레임 한 장의 픽셀 크기.
  final double width;
  final double height;

  /// `assets/images/` 기준 경로.
  String get path => 'sprites/enemies/$file.png';
}
