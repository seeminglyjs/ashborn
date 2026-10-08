/// 패시브와 장비가 올려 주는 능력치.
enum StatType {
  maxHp('최대 체력'),
  moveSpeed('이동 속도', percent: true),
  magnetRange('획득 범위', percent: true);

  const StatType(this.label, {this.percent = false});

  final String label;

  /// true 면 값이 비율(0.1 = 10%)이다.
  final bool percent;

  String format(double value) => percent
      ? '$label +${(value * 100).round()}%'
      : '$label +${value.round()}';
}
