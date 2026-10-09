import 'dart:ui';

import '../../data/stages.dart';

/// `assets/images/sprites/scene/decor.png` 의 16x16 바닥 장식 순서.
/// `tool/assets/sprites.py` 의 DECOR 와 같아야 한다.
enum Decor {
  skull,
  bones,
  rubble,
  crack,
  ash,
  puddle,
  candles,
  stump,
  embers,
  blood,
  brokenSword,
  spikes,
  hole,
  grass,
  tallGrass,
  deadBush,
  witheredFlower,
  pew,
  lavaCrack,
}

/// 바닥에 선 큰 구조물. 한 타일을 딛고 위로 솟는다.
///
/// [flames] 는 원본 픽셀 좌표의 불꽃 자리 (불꽃 밑동 가운데 x, y, 크기 배율).
/// 불꽃은 바닥 그림에 굽지 않고 매 프레임 일렁이게 그린다.
enum Structure {
  pillar('column.png', bottomPad: 9),
  brokenPillar('column_broken.png'),
  deadTree('dead_tree.png'),
  charredTree('charred_tree.png'),
  // 가지 끝 좌표는 tool/assets/sprites.py 의 TREE_TIPS 와 같다.
  burningTree(
    'charred_tree.png',
    flames: [(4, 12, 0.7), (28, 10, 0.75), (10, 8, 0.6), (18, 5, 0.85)],
  ),
  brazier('brazier.png', bottomPad: 2, flames: [(8, 11, 0.8)]),
  flamePillar('column.png', bottomPad: 9, flames: [(8, 7, 1)]),
  fireVent('fire_vent.png', bottomPad: 3, flames: [(8, 10, 0.9)]);

  const Structure(this.file, {this.bottomPad = 0, this.flames = const []});

  final String file;

  /// 그림 아래쪽의 빈 줄 수. 그만큼 내려 그려 발이 타일 바닥에 닿게 한다.
  final int bottomPad;
  final List<(double, double, double)> flames;

  /// `assets/images/` 기준 경로.
  String get path => 'sprites/scene/$file';

  /// 물 위에 서도 어색하지 않은 것 (물에 잠긴 성당의 기둥).
  bool get standsInWater => this == pillar || this == brokenPillar;
}

/// 지역마다 다른 전투 맵의 겉모습: 바닥, 장식, 구조물, 물, 안개, 불티.
class RegionTheme {
  const RegionTheme({
    required this.floorSheet,
    required this.floorWeights,
    required this.decor,
    required this.structures,
    this.floorTint = const Color(0xFFFFFFFF),
    this.decorChance = 0.06,
    this.structureChance = 0.008,
    this.water,
    this.fog,
    this.fogAlpha = 0,
    this.embers = 0,
    this.heat,
  });

  /// `assets/images/` 기준 16x16 바닥 타일 8장.
  final String floorSheet;

  /// 바닥 타일 8장이 나올 가중치.
  final List<int> floorWeights;

  /// 바닥에 곱하는 색. 장식 · 구조물은 이보다 밝게 칠해 묻히지 않게 한다.
  final Color floorTint;

  final Map<Decor, int> decor;
  final Map<Structure, int> structures;

  /// 타일마다 장식 · 구조물이 놓일 확률.
  final double decorChance;
  final double structureChance;

  /// 물에 잠긴 땅의 문턱값 (0~1, 클수록 물이 적다). null 이면 물이 없다.
  final double? water;

  /// 떠다니는 안개 · 연기 색과 진하기.
  final Color? fog;
  final double fogAlpha;

  /// 화면에 떠오르는 불티 수.
  final int embers;

  /// 화면 가장자리를 물들이는 열기 색. null 이면 없다.
  final Color? heat;

  static const _stone = 'sprites/scene/tiles.png';

  /// 0x72 돌바닥: 대부분 민바닥이고 가끔 금 간 바닥.
  static const _stoneWeights = [86, 2, 2, 2, 2, 2, 2, 2];

  static RegionTheme of(Region region) => switch (region) {
    Region.ashPlains => plains,
    Region.sunkenCathedral => cathedral,
    Region.burningForest => forest,
    Region.rustedFortress => fortress,
    Region.undyingHeart => heart,
  };

  /// 잿빛 평원: 안개 낀 시든 풀밭.
  static const plains = RegionTheme(
    floorSheet: 'sprites/scene/floor_plains.png',
    floorWeights: [20, 20, 20, 20, 15, 6, 6, 4],
    floorTint: Color(0xFFB8B6AE),
    decorChance: 0.09,
    decor: {
      Decor.tallGrass: 5,
      Decor.deadBush: 3,
      Decor.witheredFlower: 2,
      Decor.grass: 4,
      Decor.bones: 1,
      Decor.skull: 1,
      Decor.rubble: 2,
    },
    structures: {Structure.deadTree: 4, Structure.brokenPillar: 1},
    fog: Color(0xFFCBCFD2),
    fogAlpha: 0.2,
  );

  /// 가라앉은 성당: 군데군데 물이 찬 돌바닥과 기둥.
  static const cathedral = RegionTheme(
    floorSheet: _stone,
    floorWeights: _stoneWeights,
    floorTint: Color(0xFF8495A8),
    decor: {
      Decor.candles: 3,
      Decor.pew: 3,
      Decor.rubble: 3,
      Decor.crack: 2,
      Decor.skull: 1,
    },
    structures: {Structure.pillar: 3, Structure.brokenPillar: 3},
    structureChance: 0.014,
    water: 0.58,
    fog: Color(0xFF8FB4D8),
    fogAlpha: 0.1,
  );

  /// 불타는 숲: 그을린 땅과 타오르는 나무.
  static const forest = RegionTheme(
    floorSheet: 'sprites/scene/floor_forest.png',
    floorWeights: [20, 20, 20, 20, 8, 6, 6, 4],
    floorTint: Color(0xFFC8B8B0),
    decor: {
      Decor.embers: 3,
      Decor.stump: 3,
      Decor.ash: 3,
      Decor.grass: 2,
      Decor.deadBush: 2,
    },
    structures: {Structure.burningTree: 4, Structure.charredTree: 3},
    structureChance: 0.014,
    fog: Color(0xFF3A302C),
    fogAlpha: 0.16,
    embers: 24,
  );

  /// 녹슨 요새: 지금 그대로.
  static const fortress = RegionTheme(
    floorSheet: _stone,
    floorWeights: _stoneWeights,
    floorTint: Color(0xFF958C70),
    decor: {
      Decor.brokenSword: 3,
      Decor.spikes: 2,
      Decor.rubble: 3,
      Decor.crack: 2,
      Decor.hole: 1,
      Decor.skull: 1,
    },
    structures: {Structure.pillar: 1, Structure.brokenPillar: 2},
    structureChance: 0.006,
  );

  /// 꺼지지 않는 심장: 곳곳에 불길이 이는 신전.
  static const heart = RegionTheme(
    floorSheet: 'sprites/scene/floor_temple.png',
    floorWeights: [26, 26, 22, 14, 5, 3, 2, 2],
    floorTint: Color(0xFFA89494),
    decor: {
      Decor.lavaCrack: 2,
      Decor.skull: 2,
      Decor.bones: 1,
      Decor.blood: 1,
      Decor.crack: 2,
    },
    structures: {
      Structure.brazier: 4,
      Structure.flamePillar: 2,
      Structure.fireVent: 3,
    },
    structureChance: 0.02,
    embers: 40,
    heat: Color(0x55FF3A1A),
  );
}
