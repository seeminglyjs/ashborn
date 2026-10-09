import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile.dart';
import '../data/save_snapshot.dart';
import 'cloud_save.dart';

/// 클라우드 저장 상태.
enum CloudStatus {
  /// 이 빌드에는 클라우드 저장이 연결되지 않았다.
  unavailable,
  signedOut,
  syncing,
  synced,

  /// 기기 기록과 클라우드 기록이 둘 다 바뀌어 플레이어가 골라야 한다 ([conflict]).
  conflict,
  error,
}

/// 기기 기록과 클라우드 기록이 엇갈렸을 때 양쪽.
typedef SaveConflict = ({SaveSnapshot local, SaveSnapshot cloud});

/// 로그인한 계정의 클라우드 세이브와 기기 기록을 맞춘다.
///
/// - 로그인하거나 앱을 켜면 [decideSync] 로 올릴지 · 내려받을지 · 물어볼지 정한다.
/// - 그 뒤로는 기록이 바뀔 때마다 [uploadDelay] 만큼 모았다가 올린다.
/// - 내려받을 때는 [onRestore] 가 기기 기록을 덮어쓰고 새 [Profile] 로 바꿔 끼운다.
class CloudSync extends ChangeNotifier {
  CloudSync({
    required this.backend,
    required Profile profile,
    required this.onRestore,
    this.uploadDelay = const Duration(seconds: 5),
  }) {
    _profile = profile..changes.addListener(_onLocalChange);
  }

  /// 마지막으로 맞춘 시각 (밀리초) 을 남겨 두는 키.
  static const lastSyncedKey = 'cloud.lastSynced';

  final CloudSaveBackend backend;

  /// 클라우드 기록을 기기에 덮어쓰고, 새로 불러온 [Profile] 을 돌려준다.
  final Future<Profile> Function(SaveSnapshot snapshot) onRestore;
  final Duration uploadDelay;

  late Profile _profile;
  Timer? _pending;

  CloudStatus _status = CloudStatus.signedOut;
  CloudStatus get status =>
      backend.configured ? _status : CloudStatus.unavailable;

  CloudUser? _user;
  CloudUser? get user => _user;

  SaveConflict? _conflict;
  SaveConflict? get conflict => _conflict;

  /// 마지막 오류 메시지.
  String? _error;
  String? get error => _error;

  DateTime? _lastSynced;
  DateTime? get lastSynced => _lastSynced;

  /// 앱을 켤 때 한 번: 이미 로그인돼 있으면 바로 맞춘다.
  Future<void> start() async {
    if (!backend.configured) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(lastSyncedKey);
    _lastSynced = saved == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(saved);
    _user = await backend.currentUser();
    if (_user == null) return notifyListeners();
    await sync();
  }

  Future<void> signIn() async {
    if (!backend.configured) return;
    _set(CloudStatus.syncing);
    try {
      _user = await backend.signIn();
    } on Object catch (e) {
      return _fail(e);
    }
    if (_user == null) return _set(CloudStatus.signedOut);
    await sync();
  }

  Future<void> signOut() async {
    _pending?.cancel();
    await backend.signOut();
    _user = null;
    _conflict = null;
    _set(CloudStatus.signedOut);
  }

  /// 기기와 클라우드를 맞춘다.
  Future<void> sync() async {
    final user = _user;
    if (user == null) return;
    _pending?.cancel();
    _set(CloudStatus.syncing);
    try {
      final local = _profile.snapshot();
      final cloud = await backend.download(user);
      switch (decideSync(local: local, cloud: cloud, lastSynced: _lastSynced)) {
        case SyncAction.none:
          await _markSynced(local.savedAt);
        case SyncAction.upload:
          await _upload(user, local);
        case SyncAction.download:
          await _restore(cloud!);
        case SyncAction.choose:
          _conflict = (local: local, cloud: cloud!);
          _set(CloudStatus.conflict);
      }
    } on Object catch (e) {
      _fail(e);
    }
  }

  /// 충돌 때 플레이어가 고른 쪽으로 맞춘다.
  Future<void> resolve({required bool useCloud}) async {
    final conflict = _conflict;
    final user = _user;
    if (conflict == null || user == null) return;
    _conflict = null;
    _set(CloudStatus.syncing);
    try {
      if (useCloud) {
        await _restore(conflict.cloud);
      } else {
        await _upload(user, _profile.snapshot());
      }
    } on Object catch (e) {
      _fail(e);
    }
  }

  void _onLocalChange() {
    if (_user == null || _status == CloudStatus.conflict) return;
    _pending?.cancel();
    _pending = Timer(uploadDelay, () async {
      final user = _user;
      if (user == null || _status == CloudStatus.conflict) return;
      try {
        await _upload(user, _profile.snapshot());
      } on Object catch (e) {
        _fail(e);
      }
    });
  }

  Future<void> _upload(CloudUser user, SaveSnapshot snapshot) async {
    await backend.upload(user, snapshot);
    await _markSynced(snapshot.savedAt);
  }

  Future<void> _restore(SaveSnapshot snapshot) async {
    _profile.changes.removeListener(_onLocalChange);
    _profile = await onRestore(snapshot);
    _profile.changes.addListener(_onLocalChange);
    await _markSynced(snapshot.savedAt);
  }

  Future<void> _markSynced(DateTime at) async {
    _lastSynced = at;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastSyncedKey, at.millisecondsSinceEpoch);
    _error = null;
    _set(CloudStatus.synced);
  }

  void _fail(Object error) {
    _error = '$error';
    _set(CloudStatus.error);
  }

  void _set(CloudStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _pending?.cancel();
    _profile.changes.removeListener(_onLocalChange);
    super.dispose();
  }
}
