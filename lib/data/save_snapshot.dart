import 'profile.dart';

/// 세이브 한 벌: 클라우드에 올리고 내려받는 단위.
///
/// [records] 는 기기 저장 키([Profile.syncedKeys])마다 그 기록의 JSON 이다.
/// 설정(소리 · 진동 등)은 기기마다 다를 수 있어 넣지 않는다.
class SaveSnapshot {
  SaveSnapshot({
    required this.records,
    required this.savedAt,
    this.format = currentFormat,
  });

  factory SaveSnapshot.fromJson(Map<String, dynamic> json) => SaveSnapshot(
    format: json['format'] as int,
    savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
    records: {
      for (final MapEntry(:key, :value)
          in (json['records'] as Map<String, dynamic>).entries)
        key: value as Map<String, dynamic>,
    },
  );

  /// 형식이 바뀌면 올린다. 앱보다 새 형식의 클라우드 세이브는 불러오지 않는다.
  static const currentFormat = 1;

  final int format;

  /// 마지막으로 기록이 바뀐 시각.
  final DateTime savedAt;
  final Map<String, Map<String, dynamic>> records;

  late final summary = SaveSummary.of(records);

  Map<String, dynamic> toJson() => {
    'format': format,
    'savedAt': savedAt.millisecondsSinceEpoch,
    'records': records,
  };
}

/// 충돌 화면에 보여 줄 세이브 요약. 기록을 읽지 못하면 0 으로 둔다.
class SaveSummary {
  const SaveSummary({
    required this.cleared,
    required this.ember,
    required this.gold,
    required this.stones,
    required this.items,
  });

  factory SaveSummary.of(Map<String, Map<String, dynamic>> records) {
    final inventory = records[Profile.inventoryKey] ?? const {};
    final progress = records[Profile.progressKey] ?? const {};
    int number(Map<String, dynamic> json, String key) =>
        (json[key] as num?)?.toInt() ?? 0;
    final equipped = inventory['equipped'] as Map? ?? const {};
    return SaveSummary(
      cleared: number(progress, 'bestCleared') + (progress.isEmpty ? 0 : 1),
      ember: number(inventory, 'ember'),
      gold: number(inventory, 'gold'),
      stones: number(inventory, 'stones'),
      items:
          (inventory['bag'] as List? ?? const []).length +
          equipped.values.fold(0, (sum, slots) => sum + (slots as Map).length),
    );
  }

  /// 클리어한 스테이지 수.
  final int cleared;
  final int ember;
  final int gold;
  final int stones;

  /// 가방과 장착 칸의 장비 수.
  final int items;

  /// 아직 아무것도 하지 않은 새 기록 (앱을 새로 깐 직후).
  bool get isFresh =>
      cleared == 0 && ember == 0 && gold == 0 && stones == 0 && items == 0;

  String describe() =>
      '스테이지 $cleared개 클리어 · 잔불 $ember · 골드 $gold · 강화석 $stones · 장비 $items개';
}

/// 기기 기록과 클라우드 기록을 맞출 방법.
enum SyncAction {
  /// 이미 같다.
  none,

  /// 기기 기록을 클라우드에 올린다.
  upload,

  /// 클라우드 기록을 기기로 내려받는다.
  download,

  /// 양쪽 다 바뀌어 플레이어가 골라야 한다.
  choose,
}

/// 마지막으로 맞춘 시각 [lastSynced] 이후 어느 쪽이 바뀌었는지 보고 정한다.
///
/// - 클라우드에 기록이 없거나 새 기록이면 올린다.
/// - 기기 기록이 새 기록이면 (앱을 새로 깐 경우) 내려받는다.
/// - 한쪽만 바뀌었으면 바뀐 쪽을 따른다. 둘 다 바뀌었거나, 이 기기에서 처음 맞추는데
///   양쪽 다 진행한 기록이 있으면 플레이어가 고른다.
SyncAction decideSync({
  required SaveSnapshot local,
  required SaveSnapshot? cloud,
  DateTime? lastSynced,
}) {
  if (cloud == null || cloud.summary.isFresh) {
    return local.summary.isFresh ? SyncAction.none : SyncAction.upload;
  }
  if (cloud.format > SaveSnapshot.currentFormat) return SyncAction.none;
  if (local.summary.isFresh) return SyncAction.download;
  if (cloud.savedAt == local.savedAt) return SyncAction.none;
  if (lastSynced == null) return SyncAction.choose;
  final localChanged = local.savedAt.isAfter(lastSynced);
  final cloudChanged = cloud.savedAt.isAfter(lastSynced);
  return switch ((localChanged, cloudChanged)) {
    (true, false) => SyncAction.upload,
    (false, true) => SyncAction.download,
    (false, false) => SyncAction.none,
    (true, true) => SyncAction.choose,
  };
}
