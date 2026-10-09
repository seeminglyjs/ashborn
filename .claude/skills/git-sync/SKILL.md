---
name: git-sync
description: 사용자가 "깃동기화"(깃 동기화 해 줘)라고 하면 쓴다. 원격(origin)과 로컬 브랜치를 모두 최신 커밋 상태로 맞춘다 — fetch · prune 후 뒤처진 쪽을 fast-forward 하고, 앞선 로컬 커밋은 push 하며, 작업 브랜치는 최신 main 으로 올린다. 강제 push · 리셋 없이 안전한 이동만 한다.
---

# 깃동기화

목표: 로컬과 `origin` 이 같은 최신 커밋을 가리키게 한다. 따로 묻지 않고 끝까지 진행하되,
**작업이 사라질 수 있는 동작(강제 push, `reset --hard`, 브랜치 삭제, 커밋 안 된 변경 버리기)은 절대 하지 않는다.**
그런 상황을 만나면 그 브랜치는 건드리지 않고 보고에 적는다.

## 1. 원격 갱신과 현재 상태 확인

```bash
git fetch --all --prune
git status -sb
git branch -vv
git branch -r
```

- 커밋 안 된 변경(`git status --porcelain` 이 비어 있지 않음)이 있으면 **현재 브랜치는 이동하지 않는다.**
  다른 브랜치 처리와 보고는 계속한다. stash 하거나 버리지 않는다.

## 2. 로컬 브랜치마다 같은 이름의 원격 브랜치와 비교

설정된 upstream 이 아니라 **같은 이름의 `origin/<브랜치>`** 와 비교한다
(작업 브랜치가 `origin/main` 을 upstream 으로 잡고 있는 경우가 있다).

```bash
git rev-list --left-right --count <브랜치>...origin/<브랜치>   # 왼쪽 = 로컬만 있는 커밋, 오른쪽 = 원격만 있는 커밋
```

| 상태 | 처리 |
|---|---|
| 0 / 0 | 이미 같음 |
| 0 / N (뒤처짐) | fast-forward. 현재 브랜치면 `git merge --ff-only origin/<브랜치>`, 아니면 `git fetch origin <브랜치>:<브랜치>` |
| N / 0 (앞섬) | `git push origin <브랜치>` |
| N / M (갈라짐) | 건드리지 않고 보고 |
| 원격에 같은 이름 없음 | 건드리지 않고 보고 (원격에서 지워진 브랜치일 수 있음) |

`main` 은 항상 `origin/main` 으로 fast-forward 한다. 로컬 `main` 에만 있는 커밋이 있으면 멈추고 보고한다.

## 3. 작업 브랜치를 최신 main 으로

작업 브랜치(지금은 `feat/next`)는 CLAUDE.md 의 "깃에올려" 5번 규칙대로 최신 `main` 에서 다시 시작해야 한다.

```bash
git rev-list --left-right --count feat/next...origin/main
```

- 로컬에만 있는 커밋이 0 이면 (= 이미 main 에 병합됨) `origin/main` 으로 fast-forward 하고
  `git push origin feat/next` 로 원격 작업 브랜치도 같은 커밋으로 맞춘다.
- 로컬에만 있는 커밋이 있으면 아직 안 올린 작업이다. main 으로 옮기지 말고 2번 규칙(push 등)만 적용한 뒤 보고한다.

## 4. 최종 확인과 보고

```bash
git fetch --all --prune
git branch -vv
```

한국어로 짧게 보고한다:
- 브랜치별로 무엇을 했는지 (fast-forward 몇 커밋 · push · 그대로 · 건드리지 않음과 이유)
- 현재 브랜치와 그 커밋
- 로컬에 없는 원격 브랜치, 이미 main 에 병합돼 정리해도 될 것 같은 브랜치는 **목록만** 알린다 (삭제는 사용자가 요청할 때만)
