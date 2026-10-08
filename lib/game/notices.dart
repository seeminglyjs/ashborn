import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/balance.dart';

/// 화면 구석에 잠깐 뜨는 알림 한 줄.
class Notice {
  Notice(this.text, this.color);

  final String text;
  final Color color;
  double life = Balance.noticeDuration;
}

/// 최근 알림 목록. 같은 문구가 이미 떠 있으면 새로 쌓지 않고 시간만 늘린다.
class Notices extends ValueNotifier<List<Notice>> {
  Notices() : super(const []);

  void add(String text, Color color) {
    final same = value.where((n) => n.text == text).firstOrNull;
    if (same != null) {
      same.life = Balance.noticeDuration;
      return;
    }
    final next = [...value, Notice(text, color)];
    value = next.sublist(
      (next.length - Balance.maxNotices).clamp(0, next.length),
    );
  }

  void tick(double dt) {
    if (value.isEmpty) return;
    for (final notice in value) {
      notice.life -= dt;
    }
    if (value.any((n) => n.life <= 0)) {
      value = value.where((n) => n.life > 0).toList();
    }
  }

  void clear() => value = const [];
}
