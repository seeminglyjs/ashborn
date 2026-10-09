import 'dart:convert';

import '../data/save_snapshot.dart';

/// 클라우드에 로그인한 플레이어.
class CloudUser {
  const CloudUser({required this.id, required this.name});

  /// 계정마다 바뀌지 않는 값. 세이브 문서의 키로 쓴다.
  final String id;

  /// 설정 화면에 보여 줄 이름 (구글 계정 이름 · 이메일).
  final String name;
}

/// 세이브를 올리고 내려받는 곳. 앱은 이 인터페이스만 알고, 실제 저장소는 바꿔 끼운다.
///
/// 지금은 [UnconfiguredCloudSave] 를 쓴다. Firebase 를 연결할 때 이 인터페이스를
/// 구현하는 `FirebaseCloudSave` 를 만들어 `main.dart` 에서 바꿔 끼우면 된다:
/// - [signIn]: Google 로그인 → Firebase Auth (`google_sign_in` + `firebase_auth`)
/// - [download] · [upload]: Firestore `saves/{uid}` 문서 하나에 [SaveSnapshot.toJson] 을 통째로
/// - 보안 규칙: `allow read, write: if request.auth.uid == uid;`
abstract interface class CloudSaveBackend {
  /// 이 빌드에서 클라우드 저장을 쓸 수 있는가 (설정 파일 · 키가 들어 있는가).
  bool get configured;

  /// 앱을 켰을 때 이미 로그인돼 있던 계정. 없으면 null.
  Future<CloudUser?> currentUser();

  /// 로그인 창을 띄운다. 플레이어가 취소하면 null.
  Future<CloudUser?> signIn();

  Future<void> signOut();

  /// [user] 의 클라우드 세이브. 아직 없으면 null.
  Future<SaveSnapshot?> download(CloudUser user);

  Future<void> upload(CloudUser user, SaveSnapshot snapshot);
}

/// 아직 연결하지 않은 클라우드. 설정 화면에 "준비 중" 으로 보인다.
class UnconfiguredCloudSave implements CloudSaveBackend {
  const UnconfiguredCloudSave();

  @override
  bool get configured => false;

  @override
  Future<CloudUser?> currentUser() async => null;

  @override
  Future<CloudUser?> signIn() => throw StateError('클라우드 저장이 아직 연결되지 않았습니다');

  @override
  Future<void> signOut() async {}

  @override
  Future<SaveSnapshot?> download(CloudUser user) =>
      throw StateError('클라우드 저장이 아직 연결되지 않았습니다');

  @override
  Future<void> upload(CloudUser user, SaveSnapshot snapshot) =>
      throw StateError('클라우드 저장이 아직 연결되지 않았습니다');
}

/// 메모리에만 두는 클라우드. 테스트와, 실제 연결 전 화면 흐름을 확인할 때 쓴다.
class MemoryCloudSave implements CloudSaveBackend {
  MemoryCloudSave({this.user = const CloudUser(id: 'test', name: '테스트 계정')});

  /// [signIn] 이 돌려줄 계정. null 이면 플레이어가 로그인을 취소한 것으로 친다.
  CloudUser? user;
  CloudUser? _signedIn;
  final saves = <String, SaveSnapshot>{};

  /// 다음 요청을 실패시킨다 (네트워크 오류 흉내).
  bool failNext = false;

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw StateError('네트워크 오류');
    }
  }

  @override
  bool get configured => true;

  @override
  Future<CloudUser?> currentUser() async => _signedIn;

  @override
  Future<CloudUser?> signIn() async => _signedIn = user;

  @override
  Future<void> signOut() async => _signedIn = null;

  @override
  Future<SaveSnapshot?> download(CloudUser user) async {
    _maybeFail();
    return saves[user.id];
  }

  @override
  Future<void> upload(CloudUser user, SaveSnapshot snapshot) async {
    _maybeFail();
    // 실제 저장소처럼 JSON 으로 오가게 해 직렬화 실수도 잡는다.
    saves[user.id] = SaveSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
    );
  }
}
