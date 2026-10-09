import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/profile.dart';
import 'package:ashborn/data/save_snapshot.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/services/cloud_save.dart';
import 'package:ashborn/services/cloud_sync.dart';
import 'package:ashborn/ui/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

SaveSnapshot save(int minute, {int ember = 10}) => SaveSnapshot(
  savedAt: DateTime(2026, 1, 1, 0, minute),
  records: {
    Profile.inventoryKey: {
      'ember': ember,
      'bag': const [],
      'equipped': const {},
    },
    Profile.progressKey: {'bestCleared': 2},
  },
);

final fresh = SaveSnapshot(
  savedAt: DateTime.fromMillisecondsSinceEpoch(0),
  records: {
    Profile.inventoryKey: {'ember': 0, 'bag': const [], 'equipped': const {}},
    Profile.progressKey: {'bestCleared': -1},
  },
);

/// 진행한 기록이 있는 프로필 (잔불과 장비 하나, 스테이지 하나 클리어).
Future<Profile> played() async {
  final profile = await Profile.load();
  profile.inventory.addEmber(25);
  profile.inventory
      .gear(CharacterId.witch)
      .add(item(ItemType.ring, rarity: Rarity.hero));
  profile.progress.recordClear(Stage.first);
  await pumpEventQueue();
  return profile;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('세이브 한 벌', () {
    test('요약은 클리어 수 · 재화 · 장비 수를 읽고, 새 기록을 알아본다', () async {
      final profile = await played();
      final summary = profile.snapshot().summary;

      expect(summary.cleared, 1);
      expect(summary.ember, 25);
      expect(summary.items, 1);
      expect(summary.isFresh, isFalse);
      expect((await Profile.load()).snapshot().summary.isFresh, isFalse);
      SharedPreferences.setMockInitialValues({});
      expect((await Profile.load()).snapshot().summary.isFresh, isTrue);
    });

    test('기록이 바뀐 시각을 남기고 다음 실행에도 기억한다', () async {
      final profile = await Profile.load();
      expect(profile.modifiedAt, isNull);

      profile.inventory.addEmber(1);
      await pumpEventQueue();

      expect(profile.modifiedAt, isNotNull);
      final again = await Profile.load();
      expect(
        again.modifiedAt!.millisecondsSinceEpoch,
        profile.modifiedAt!.millisecondsSinceEpoch,
      );
    });

    test('설정은 클라우드 기록에 넣지 않는다', () async {
      final profile = await Profile.load();
      profile.settings.vibration = false;
      await pumpEventQueue();

      expect(profile.modifiedAt, isNull);
      expect(
        profile.snapshot().records.keys,
        unorderedEquals(Profile.syncedKeys),
      );
    });

    test('되돌리면 기기 기록이 세이브와 같아지고 설정은 그대로다', () async {
      final source = await played();
      final snapshot = source.snapshot();
      SharedPreferences.setMockInitialValues({});
      final device = await Profile.load();
      device.settings.vibration = false;
      await pumpEventQueue();

      final restored = await Profile.restore(snapshot);

      expect(restored.inventory.ember, 25);
      expect(
        restored.inventory.gear(CharacterId.witch).equipped[EquipSlot.ring1],
        isNotNull,
      );
      expect(restored.progress.bestCleared, Stage.first);
      expect(restored.settings.vibration, isFalse);
      expect(restored.modifiedAt, snapshot.savedAt);
    });

    test('JSON 으로 오가도 그대로다', () async {
      final snapshot = (await played()).snapshot();
      final back = SaveSnapshot.fromJson(snapshot.toJson());
      expect(back.savedAt, snapshot.savedAt);
      expect(back.summary.describe(), snapshot.summary.describe());
    });
  });

  group('어느 쪽으로 맞출지', () {
    test('클라우드가 비었으면 올리고, 기기가 새 기록이면 내려받는다', () {
      expect(decideSync(local: save(1), cloud: null), SyncAction.upload);
      expect(decideSync(local: save(1), cloud: fresh), SyncAction.upload);
      expect(decideSync(local: fresh, cloud: null), SyncAction.none);
      expect(decideSync(local: fresh, cloud: save(1)), SyncAction.download);
    });

    test('마지막으로 맞춘 뒤 한쪽만 바뀌었으면 그쪽을 따른다', () {
      final synced = DateTime(2026, 1, 1, 0, 5);
      expect(
        decideSync(local: save(9), cloud: save(5), lastSynced: synced),
        SyncAction.upload,
      );
      expect(
        decideSync(local: save(5), cloud: save(9), lastSynced: synced),
        SyncAction.download,
      );
      expect(
        decideSync(local: save(5), cloud: save(5), lastSynced: synced),
        SyncAction.none,
      );
    });

    test('둘 다 바뀌었거나 이 기기에서 처음 맞추면 플레이어가 고른다', () {
      expect(
        decideSync(
          local: save(8),
          cloud: save(9),
          lastSynced: DateTime(2026, 1, 1, 0, 5),
        ),
        SyncAction.choose,
      );
      expect(decideSync(local: save(8), cloud: save(9)), SyncAction.choose);
    });

    test('앱보다 새 형식의 클라우드 세이브는 건드리지 않는다', () {
      final future = SaveSnapshot(
        format: SaveSnapshot.currentFormat + 1,
        savedAt: DateTime(2027),
        records: save(1).records,
      );
      expect(decideSync(local: save(1), cloud: future), SyncAction.none);
    });
  });

  group('클라우드 동기화', () {
    late MemoryCloudSave backend;
    late Profile profile;
    late List<SaveSnapshot> restored;

    CloudSync sync() => CloudSync(
      backend: backend,
      profile: profile,
      uploadDelay: Duration.zero,
      onRestore: (s) async {
        restored.add(s);
        return profile = await Profile.restore(s);
      },
    );

    setUp(() {
      backend = MemoryCloudSave();
      restored = [];
    });

    test('연결되지 않은 빌드는 준비 중으로 보이고 아무것도 하지 않는다', () async {
      profile = await played();
      final cloud = CloudSync(
        backend: const UnconfiguredCloudSave(),
        profile: profile,
        onRestore: (_) => throw StateError('불리면 안 된다'),
      );
      await cloud.start();
      expect(cloud.status, CloudStatus.unavailable);
    });

    test('처음 로그인하면 기기 기록을 올린다', () async {
      profile = await played();
      final cloud = sync();

      await cloud.signIn();

      expect(cloud.status, CloudStatus.synced);
      expect(backend.saves['test']!.summary.ember, 25);
      expect(restored, isEmpty);
    });

    test('앱을 새로 깔고 로그인하면 계정 기록을 내려받아 바꿔 끼운다', () async {
      profile = await played();
      await sync().signIn();
      SharedPreferences.setMockInitialValues({});
      profile = await Profile.load();
      await backend.signOut();

      final cloud = sync();
      await cloud.signIn();

      expect(restored, hasLength(1));
      expect(profile.inventory.ember, 25);
      expect(cloud.status, CloudStatus.synced);
    });

    test('로그인한 뒤 기록이 바뀌면 알아서 올린다', () async {
      profile = await played();
      final cloud = sync();
      await cloud.signIn();

      profile.inventory.addEmber(5);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(backend.saves['test']!.summary.ember, 30);
      expect(cloud.status, CloudStatus.synced);
    });

    test('다른 기기에서 진행한 계정이면 고르게 하고, 고른 쪽으로 맞춘다', () async {
      backend.saves['test'] = save(30, ember: 999);
      profile = await played();
      final cloud = sync();

      await cloud.signIn();
      expect(cloud.status, CloudStatus.conflict);
      expect(cloud.conflict!.cloud.summary.ember, 999);

      await cloud.resolve(useCloud: false);
      expect(cloud.status, CloudStatus.synced);
      expect(backend.saves['test']!.summary.ember, 25);
      expect(restored, isEmpty);
    });

    test('충돌에서 계정 기록을 고르면 내려받는다', () async {
      backend.saves['test'] = save(30, ember: 999);
      profile = await played();
      final cloud = sync();
      await cloud.signIn();

      await cloud.resolve(useCloud: true);

      expect(profile.inventory.ember, 999);
      expect(cloud.status, CloudStatus.synced);
    });

    test('네트워크 오류는 알리고 다시 시도할 수 있다', () async {
      profile = await played();
      final cloud = sync();
      backend.failNext = true;

      await cloud.signIn();
      expect(cloud.status, CloudStatus.error);
      expect(cloud.error, contains('네트워크'));

      await cloud.sync();
      expect(cloud.status, CloudStatus.synced);
    });

    test('로그인을 취소하면 로그아웃 상태로 남는다', () async {
      profile = await played();
      backend.user = null;
      final cloud = sync();

      await cloud.signIn();

      expect(cloud.status, CloudStatus.signedOut);
    });
  });

  group('설정 화면', () {
    Future<void> open(WidgetTester tester, CloudSync cloud) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPanel(
            settings: profile_.settings,
            cloud: cloud,
            onClose: () {},
          ),
        ),
      );
    }

    testWidgets('연결 전에는 준비 중 안내와 꺼진 로그인 버튼이 보인다', (tester) async {
      profile_ = Profile();
      await open(
        tester,
        CloudSync(
          backend: const UnconfiguredCloudSave(),
          profile: profile_,
          onRestore: (_) => throw StateError('불리면 안 된다'),
        ),
      );

      expect(find.byKey(const Key('cloud-unavailable')), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('cloud-sign-in')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('로그인하면 마지막 저장 시각과 버튼이 보인다', (tester) async {
      profile_ = Profile();
      final cloud = CloudSync(
        backend: MemoryCloudSave(),
        profile: profile_,
        onRestore: (_) => throw StateError('불리면 안 된다'),
      );
      await open(tester, cloud);

      await tester.runAsync(cloud.signIn);
      await tester.pump();

      expect(find.byKey(const Key('cloud-synced')), findsOneWidget);
      expect(find.byKey(const Key('cloud-sign-out')), findsOneWidget);
    });
  });
}

late Profile profile_;
