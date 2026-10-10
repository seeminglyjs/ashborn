/// 타락 단계의 특수 규칙. 정해진 단계([from])부터 붙고, 그 위 단계에도 계속 남는다.
///
/// 타락은 런을 시작할 때 고르는 난이도다. 단계마다 적 체력 · 피해와 보상이 함께 오르고,
/// 몇 단계마다 이런 규칙이 하나씩 더해져 숫자만 커지는 것이 아니라 싸우는 방식이 달라진다.
enum CorruptionRule {
  elite(1, '정예 출현', '가끔 크고 단단한 정예 적이 나온다. 잡으면 강화석 확정, 장비가 잘 떨어진다'),
  bossRegen(2, '보스 재생', '보스가 잠시 맞지 않으면 체력을 회복한다'),
  deathBlast(4, '잿불 유해', '쓰러진 적 일부가 잠시 뒤 그 자리에서 터진다'),
  frenzy(6, '무리 습격', '적이 더 많이, 더 빠르게 몰려온다'),
  earlyEnrage(8, '이른 격노', '보스가 체력 75%에서 격노한다');

  const CorruptionRule(this.from, this.label, this.description);

  /// 이 규칙이 붙기 시작하는 타락 단계.
  final int from;
  final String label;
  final String description;

  /// 타락 [corruption] 단계에 붙는 규칙 (붙는 순서대로).
  static List<CorruptionRule> at(int corruption) => [
    for (final rule in values)
      if (corruption >= rule.from) rule,
  ];
}
