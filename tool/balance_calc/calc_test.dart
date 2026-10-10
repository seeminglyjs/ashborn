// 밸런스 계산기: 게임을 돌리지 않고 공식으로 스테이지 벽과 진행 속도를 몇 초 만에 본다.
// 일반 `flutter test` 에는 포함되지 않는다 (tool/ 아래).
//
// flutter test tool/balance_calc/calc_test.dart
// flutter test tool/balance_calc/calc_test.dart --dart-define=MASTERY=5 --dart-define=STAGES=50
//
// - MASTERY: 직업 패시브 레벨 (세 패시브 모두 같은 레벨로 친다, 기본 0).
// - STAGES: 볼 스테이지 수 (기본 40).
// 결과는 화면과 build/balance_calc.txt 에 남는다.
//
// 보는 법
// 1. 스테이지 표: 졸개 · 보스 체력, 한 번 깰 때 처치 수와 강화석 · 골드, 캐릭터마다 보스를 제한 시간
//    안에 잡으려면 장비 10칸을 몇 강까지 올려야 하는지 (벽). 벽이 갑자기 뛰는 곳이 막히는 곳이다.
// 2. 진행 예측: 벽을 넘을 재화를 모으며 갈 때, 플레이 시간마다 깬 스테이지 수.
//    시뮬레이터 결과(아래 [_sim])와 나란히 보여 준다. 크게 어긋나면 model.dart 의 Calibration 을 맞춘다.
//
// 계산기는 빠른 걸러내기용이다. 큰 변경은 마지막에 시뮬레이터(tool/balance_sim)로 확인한다.
import 'dart:io';

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/stages.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model.dart';

const _mastery = int.fromEnvironment('MASTERY');
const _stages = int.fromEnvironment('STAGES', defaultValue: 40);

/// 마지막 시뮬레이터 측정 (2026-10-10, 시드 2 평균, 기사는 대검의 무게 반영 후): 4시간에 깬 스테이지.
/// 시뮬레이터는 런이 끝날 때만 최전선을 기록하고 런 하나가 한 시간을 넘기도 해서,
/// 짧은 시간 칸은 실제보다 낮게 나온다. 그래서 4시간 칸만 비교한다.
/// 시뮬레이터를 다시 돌리면 여기를 고친다.
const _sim = {
  CharacterId.knight: {240: 30.5},
  CharacterId.witch: {240: 34.0},
  CharacterId.hunter: {240: 32.5},
};

const _marks = [30, 60, 120, 240, 480];

void main() {
  test('밸런스 계산', () {
    final out = StringBuffer();
    void line(String s) {
      out.writeln(s);
      // ignore: avoid_print
      print(s);
    }

    final weapons = {
      for (final c in Roster.all) c.id: WeaponModel(c, mastery: _mastery),
    };

    line(
      '== 스테이지 (직업 패시브 Lv $_mastery, 장비 등급 ${Calibration.rarityMax}, 1스테이지부터 이어서 온 런) ==',
    );
    line(
      '${'스테이지'.padRight(14)} 졸개체력      보스체력     보스피해  처치   강화석   골드    '
      '필요 강화 (기사 / 마녀 / 사냥꾼)',
    );
    for (var i = 0; i < _stages; i++) {
      final stage = Stage(i);
      final m = StageModel(stage);
      final need = [
        for (final c in Roster.all)
          _enhance(requiredEnhance(weapons[c.id]!, stage)),
      ];
      line(
        '${'${stage.level} ${stage.name}'.padRight(14)} '
        '${_n(m.minionHpStart).padLeft(5)}→${_n(m.minionHpEnd).padRight(6)} '
        '${_n(m.bossHp).padLeft(9)} ${_n(m.bossDamage).padLeft(8)} '
        '${m.kills.round().toString().padLeft(5)} '
        '${m.stones.toStringAsFixed(1).padLeft(6)} '
        '${_n(m.gold).padLeft(7)}    ${need.join(' / ')}',
      );
    }

    line('');
    line('== 진행 예측: 플레이 시간별 깬 스테이지 (괄호는 시뮬레이터) ==');
    for (final c in Roster.all) {
      final reached = progression(weapons[c.id]!, stages: _stages);
      final cells = [
        for (final mark in _marks)
          '${mark >= 60 ? '${mark ~/ 60}h' : '${mark}m'}: '
              '${reached.where((t) => t <= mark).length}'
              '${_simAt(c.id, mark)}',
      ];
      line('${c.name.padRight(8)} ${cells.join('   ')}');
    }

    line('');
    line('== 강화 경제: 장비 10칸을 한 단계 올리는 재화가 스테이지 몇 번 깬 수입인가 ==');
    line('(장비 레벨 = 그 스테이지 레벨, 등급 ${Calibration.rarityMax.round()})');
    line(
      '강화 단계   ${[for (final s in _econStages) '스테이지 ${s.toString().padLeft(2)}'].join('   ')}',
    );
    for (final e in [0, 5, 10, 15, 20, 25, 29]) {
      final cells = [
        for (final s in _econStages) _clears(e, Stage(s - 1)).padLeft(11),
      ];
      line(
        '+${e.toString().padLeft(2)} → +${(e + 1).toString().padLeft(2)}  ${cells.join('  ')}',
      );
    }
    line('(값: 강화석 기준 판 수 / 골드 기준 판 수. 큰 쪽이 실제로 막는 재화)');

    line('');
    line('== 기준 장비에서의 보스 상대 초당 피해 (스테이지 20 장비 +15, 런에서 19스테이지를 깬 뒤) ==');
    for (final c in Roster.all) {
      final gear = GearPower(
        level: 20,
        enhance: 15,
        rarity: Calibration.rarityMax,
      );
      final w = weapons[c.id]!;
      final cycle = w.cycle(1);
      line(
        '${c.name.padRight(8)} DPS ${_n(w.bossDps(gear, depth: 19))}  '
        '(한 번에 ${cycle.hits.toStringAsFixed(2)}타 × 기본 ${cycle.base.toStringAsFixed(1)}, '
        '${cycle.interval.toStringAsFixed(2)}초마다, 더해지는 피해 ${_n(gear.addedDamage)})',
      );
    }
    line('');
    line(
      '보스 제한 시간 ${Balance.bossTimeLimit.round()}초 · 강화 최대 +${Balance.maxEnhance} · '
      '"막힘" = 최대 강화로도 제한 시간 안에 못 잡음',
    );

    File('build/balance_calc.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(out.toString());
  });
}

const _econStages = [5, 10, 20, 30];

/// 장비 10칸을 +[e] 에서 한 단계 올리는 데 드는 강화석 · 골드가 [stage] 를 몇 번 깬 수입인지.
String _clears(int e, Stage stage) {
  final item = Item(
    type: ItemType.ring,
    rarity: Rarity.values[Calibration.rarityMax.round()],
    stats: const [],
    level: stage.level,
  )..enhance = e;
  final m = StageModel(stage);
  final stones = item.enhanceStones * 10 / m.stones;
  final gold = item.enhanceGold * 10 / m.gold;
  return '${stones.toStringAsFixed(1)} / ${gold.toStringAsFixed(1)}';
}

String _simAt(CharacterId id, int mark) {
  final s = _sim[id]?[mark];
  return s == null ? '' : ' ($s)';
}

String _enhance(int? e) => e == null ? '막힘' : '+$e'.padLeft(3);

/// 큰 수를 짧게 (1.2만, 3.4억).
String _n(double v) {
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
  if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}만';
  return v.round().toString();
}
