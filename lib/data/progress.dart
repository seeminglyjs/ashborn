import 'package:flutter/foundation.dart';

import 'characters.dart';
import 'fates.dart';
import 'inventory.dart';
import 'stages.dart';

/// 진행도: 스테이지, 해금한 캐릭터, 받은 신의 은총. 모든 캐릭터가 함께 쓴다.
class Progress extends ChangeNotifier {
  Progress([
    this._bestCleared = -1,
    Set<CharacterId>? characters,
    Map<int, Fate>? graces,
    this._offer,
  ]) : _characters = {...?characters},
       _graces = {...?graces};

  /// 은총(`graces` · `graceOffer`)은 나중에 더한 필드라 없으면 빈 것으로 읽는다. 그래서 키를
  /// 올리지 않았고, 예전 세이브는 이미 클리어한 스테이지마다 받을 은총이 하나씩 쌓인 채로 시작한다.
  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    json['bestCleared'] as int,
    {
      for (final name in json['characters'] as List? ?? const [])
        ?CharacterId.values.asNameMap()[name],
    },
    {
      for (final MapEntry(:key, :value)
          in (json['graces'] as Map? ?? const {}).entries)
        ?int.tryParse('$key'): ?Fate.fromJson(value),
    },
    GraceOffer.fromJson(json['graceOffer']),
  );

  int _bestCleared;

  /// 골드로 해금한 캐릭터.
  final Set<CharacterId> _characters;

  /// 스테이지 번호 → 그 스테이지를 처음 클리어하고 받은 은총.
  final Map<int, Fate> _graces;

  /// 아직 고르지 않은 은총의 카드 패. 고를 때까지 같은 패가 남아, 나갔다 들어와도 바뀌지 않는다.
  GraceOffer? _offer;

  /// 가장 멀리 클리어한 스테이지. 아직 없으면 null.
  Stage? get bestCleared => _bestCleared < 0 ? null : Stage(_bestCleared);

  /// 출정할 때 고를 수 있는 가장 높은 타락 단계: 클리어한(마지막 지역까지 깬) 단계의 다음.
  /// 예전 기록(스테이지를 이어서 가던 때)도 깬 스테이지로 그대로 계산된다.
  int get unlockedCorruption => (_bestCleared + 1) ~/ Region.values.length;

  /// 타락 [corruption] 단계를 클리어했는가 (그 단계 마지막 지역 보스를 잡았다).
  bool conquered(int corruption) =>
      _bestCleared >= Stage.start(corruption + 1).index - 1;

  /// 가장 멀리 깬 스테이지 다음 (진행도 표시 · 시뮬레이터 기록용).
  Stage get frontier => Stage(_bestCleared + 1);

  void recordClear(Stage stage) {
    if (stage.index <= _bestCleared) return;
    _bestCleared = stage.index;
    notifyListeners();
  }

  /// 받은 은총 (스테이지 순서). 영구히 모든 런에 붙는다.
  List<Fate> get graces => [
    for (final stage in _graces.keys.toList()..sort()) _graces[stage]!,
  ];

  /// 받은 은총과 그 은총을 준 스테이지 (스테이지 순서).
  List<(Stage, Fate)> get graceRecords => [
    for (final stage in _graces.keys.toList()..sort())
      (Stage(stage), _graces[stage]!),
  ];

  bool hasGrace(Stage stage) => _graces.containsKey(stage.index);

  /// 클리어했지만 아직 은총을 고르지 않은 스테이지 (앞에서부터).
  List<Stage> get pendingGraces => [
    for (var i = 0; i <= _bestCleared; i++)
      if (!_graces.containsKey(i)) Stage(i),
  ];

  /// [stage] 의 고를 카드 패. 아직 없으면 null — 부르는 쪽이 [offerGrace] 로 만든다.
  GraceOffer? offerFor(Stage stage) =>
      _offer?.stage == stage.index ? _offer : null;

  /// [stage] 의 카드 패를 [hand] 로, 다시 뽑기 [rerolls] 번과 함께 남긴다.
  /// 다른 스테이지의 패가 남아 있었으면 바꾼다 (그 스테이지는 다음에 새 패를 받는다).
  void offerGrace(Stage stage, List<Fate> hand, {required int rerolls}) {
    _offer = GraceOffer(stage.index, hand, rerolls);
    notifyListeners();
  }

  /// [stage] 의 패를 [hand] 로 다시 뽑는다. 남은 횟수가 없으면 false.
  bool rerollGrace(Stage stage, List<Fate> hand) {
    final offer = offerFor(stage);
    if (offer == null || offer.rerolls <= 0) return false;
    _offer = GraceOffer(stage.index, hand, offer.rerolls - 1);
    notifyListeners();
    return true;
  }

  /// [stage] 의 은총으로 [fate] 를 받는다. 한 스테이지에 하나뿐이라 이미 받았으면 false.
  bool takeGrace(Stage stage, Fate fate) {
    if (hasGrace(stage) || stage.index > _bestCleared) return false;
    _graces[stage.index] = fate;
    if (_offer?.stage == stage.index) _offer = null;
    notifyListeners();
    return true;
  }

  /// 무료이거나 해금한 캐릭터.
  bool owns(CharacterDef character) =>
      character.price == 0 || _characters.contains(character.id);

  bool canUnlock(CharacterDef character, Inventory inventory) =>
      !owns(character) && inventory.gold >= character.price;

  /// [inventory] 의 골드로 [character] 를 해금한다.
  void unlock(CharacterDef character, Inventory inventory) {
    assert(canUnlock(character, inventory), '골드가 모자라거나 이미 해금했다');
    inventory.spendGold(character.price);
    _characters.add(character.id);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'bestCleared': _bestCleared,
    'characters': [for (final id in _characters) id.name],
    'graces': {
      for (final MapEntry(:key, :value) in _graces.entries)
        '$key': value.toJson(),
    },
    'graceOffer': ?_offer?.toJson(),
  };
}

/// 아직 고르지 않은 은총 한 번의 카드 패와 남은 다시 뽑기 횟수.
class GraceOffer {
  const GraceOffer(this.stage, this.hand, this.rerolls);

  /// 이 패를 준 스테이지 번호.
  final int stage;
  final List<Fate> hand;
  final int rerolls;

  static GraceOffer? fromJson(Object? json) {
    if (json is! Map) return null;
    final stage = json['stage'];
    final hand = [
      for (final f in json['hand'] as List? ?? const []) ?Fate.fromJson(f),
    ];
    if (stage is! int || hand.isEmpty) return null;
    return GraceOffer(stage, hand, json['rerolls'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'hand': [for (final f in hand) f.toJson()],
    'rerolls': rerolls,
  };
}
