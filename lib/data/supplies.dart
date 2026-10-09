/// 상자에서 나오는 소모품. 순서는 `assets/images/sprites/items/pickups.png` 프레임과 같다.
enum Supply {
  potion('회복 물약'),
  gold('골드 주머니'),
  stone('강화석'),
  magnet('자석');

  const Supply(this.label);

  final String label;
}

/// 나무 상자 하나를 부쉈을 때 나오는 것. 가중치는 `Balance.crateDropWeights` 의 같은 순서.
enum CrateDrop {
  potion(Supply.potion),
  gold(Supply.gold),
  stone(Supply.stone),
  magnet(Supply.magnet),
  item(null);

  const CrateDrop(this.supply);

  /// 장비면 null.
  final Supply? supply;

  String get label => supply?.label ?? '장비';
}
