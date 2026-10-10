---
name: pixel-art
description: Ashborn 의 도트(픽셀) 그림을 새로 그리거나 고칠 때 쓴다 — 캐릭터 · 몬스터 스프라이트, 무기 · 투사체 픽셀 아트(weapon_art.dart), 상태이상 · 타격 이펙트, 스프라이트 생성 스크립트(tool/assets). 고정 팔레트 · 빛 방향 · 명암 규칙을 지키고, 반드시 PNG 로 찍어 눈으로 확인하며 고친다.
---

# 도트 작업

목표: 따로 그린 그림끼리도 한 게임처럼 보이고, 작은 크기에서도 무엇인지 읽히게 한다.

**먼저 `art_refs/README.md` 를 읽는다.** 사용자가 보낸 참고 그림 목록과, 거기서 정한 영웅 · 몬스터 ·
이펙트 · 아이콘 규격이 있다. 새 참고 그림을 받으면 그 폴더에 넣고 목록 · 규격을 고친다 (그림은 커밋하지 않는다).
**그린 것을 직접 보지 않고 "좋아졌다"고 말하지 않는다.** 모든 작업은 아래 확인 루프를 거친다.

## 1. 시작 전: 비교 기준 남기기

고치기 전 그림을 스크래치 폴더에 복사해 둔다 (전후 비교용).

```bash
cp -r assets/images/sprites <스크래치>/before
```

## 2. 규칙

**팔레트** — 새로 그리는 그림은 Endesga 32 (Lospec 공개 팔레트) 색만 쓴다.
- 코드 그림(weapon_art.dart 의 `PixelArt`)은 `Pal` 의 색만 쓴다. 필요한 색이 없으면 Endesga 32 에서 골라 `Pal` 에 더한다.
- 파이썬 그림은 `tool/assets/palette.py` 의 `PALETTE` · `nearest` 를 쓴다. `python -I tool/assets/palette.py <png>` 로 팔레트 밖 색을 센다.
- 0x72 원본에서 만든 기존 스프라이트는 팔레트로 강제로 맞추지 않는다. 해 보니 지역 변종끼리 구분이 사라지고
  슬라임처럼 부드러운 명암이 갈라졌다. 기존 스프라이트는 `polish.py` 의 명암 규칙으로만 다듬는다.

**빛과 명암**
- 빛은 왼쪽 위에서 온다. 윗면 · 왼면은 밝게, 아랫면 · 오른면은 어둡게.
- 한 재질은 3에서 4단계 명암. 어두운 단계는 차가운 쪽(파랑 · 보라)으로, 밝은 단계는 따뜻한 쪽(노랑)으로 색조를 민다.
  같은 색조에서 명도만 바꾸면 흐릿하고 단조롭다.
- 베개 명암(가장자리를 빙 둘러 어둡게)은 쓰지 않는다. 빛 방향 기준으로만 칠한다.

**외곽선**
- 기본 외곽선은 `Pal.outline` (#181425). 순검정은 쓰지 않는다.
- 빛 받는 쪽 외곽선은 안쪽 색의 짙은 색으로 바꿔도 된다 (색 외곽선, polish.py 가 하는 일).

**모양**
- 실루엣이 먼저다: 한 가지 색으로 칠해도 무엇인지 알아봐야 한다.
- 선은 픽셀 계단 폭을 일정하게 (1-1-1 또는 2-2-2). 중간에 한 칸만 튀는 계단(재기)을 만들지 않는다.
- 게임 바닥이 어둡다 (#2e2a28 근처). 캐릭터 · 적 · 투사체는 바닥보다 확실히 밝거나 채도가 높아야 한다.
- 한 스프라이트에 색은 8에서 12개 안쪽.

**움직임 · 이펙트**
- 애니메이션은 4프레임 기준. 늘었다 줄었다(squash · stretch)와 예비 동작(내려찍기 전에 들어 올리기)을 넣는다.
- 적 위 이펙트는 컴포넌트를 늘리지 말고 시간으로 위치를 계산해 작은 사각형으로 그린다
  (`ailment_fx.dart` 참고). 입자 크기는 몸 크기에 비례시켜 작은 졸개에서도 보이게 한다.

## 3. 어디에 무엇이 있나

| 그림 | 위치 |
|:---|:---|
| 캐릭터 스프라이트 | `tool/assets/heroes.py` 가 0x72 없이 처음부터 그린다 (24x28 프레임, `heroFrame`) |
| 몬스터 스프라이트 | `tool/assets/sprites.py` → `monsters.py` → `polish.py` 순서로 원본에서 만든다 (README 의 에셋 절) |
| 장비 아이콘 | `tool/assets/gear_icons.py` (부위 `gear.png`, 직업 무기 `weapons.png`, 각 고유판) |
| 내 공격 도트 이펙트 | `lib/components/effects/pixel_fx.dart` (`PixelFx` · `PixelCanvas` · `FxTones`), 땅 이펙트 `ground_fx.dart` |
| 적 공격 빨간 테두리 | `lib/components/enemies/hazards.dart` (`enemyOutline` · `dangerStroke` · `HostileBurst`) |
| 0x72 원본 | 저장소에 없다. 0x72.itch.io 에서 DungeonTilesetII (CC-0) 를 받아 압축을 푼다 |
| 무기 · 투사체 픽셀 아트 | `lib/components/weapons/weapon_art.dart` (`PixelArt` 글자 격자 + `Pal`) |
| 대검 기술 연출 | `lib/components/weapons/greatsword.dart` 의 `SwordStrike` |
| 상태이상 연출 | `lib/components/enemies/ailment_fx.dart` |
| 몬스터 걷기 연출 | `lib/components/enemies/enemy.dart` 의 `_bounce` |
| AI 생성 그림 후처리 | `tool/assets/ai_cleanup.py` (아래 6절) |

스프라이트 스크립트는 같은 결과를 다시 만든다. `polish.py` 는 두 번 돌리면 두 번 칠해지니,
늘 `sprites.py` · `monsters.py` 로 새로 만든 시트에 한 번만 돌린다.

## 4. 확인 루프 (반드시)

1. 스프라이트 시트: 크게 늘어놓고, 고치기 전과 위아래로 비교한다.
   ```bash
   python -I tool/preview/sheet.py --frames --before <스크래치>/before assets/images/sprites --out build/preview/sheet.png
   ```
2. 코드 그림 · 게임 장면: 무기 그림(픽셀 격자 포함), 대검 기술 프레임, 상태이상, 전투, 숙련 화면을 PNG 로 찍는다.
   ```bash
   flutter test tool/preview/scene_test.dart
   ```
   새 무기 · 이펙트를 만들면 이 파일에 장면을 하나 더한다.
3. `Read` 로 PNG 를 열어 본다. 크게 본 그림과 실제 크기(1배) 둘 다 본다. 작게 봐서 안 읽히면 다시 그린다.
4. 한 번 이상 고쳐 다시 찍는다. 첫 결과를 그대로 내지 않는다.
5. 보고할 때는 전후 비교 이미지를 근거로 무엇이 좋아졌고 무엇이 아직 아쉬운지 함께 말한다.

`build/preview/` 는 커밋하지 않는다.

## 5. 사용자가 직접 손볼 때 (무료 도구)

- 무료 도트 편집기: LibreSprite, Pixelorama. PNG 로 저장해 `assets/images/sprites/` 에 넣으면 이 스킬의 확인 루프로 바로 본다.
- 팔레트는 Lospec 에서 Endesga 32 를 받아 편집기에 불러오면 같은 색을 쓴다.

## 6. AI 로 만든 그림 다듬기

AI 픽셀 그림은 칸 크기가 들쭉날쭉하고 색이 수십 개라 그대로 넣으면 기존 그림과 따로 논다. 반드시 후처리를 거친다.

```bash
python -I tool/assets/ai_cleanup.py <png 또는 폴더> [--scale 8] [--no-trim]
```

- 격자(Pixel Snapper) → 배경 제거 → Endesga 32 → 떨어진 잡티 제거 → 외곽선 `#181425` 통일 → 여백 자르기 순서다.
  결과는 `build/ai_cleanup/`, 비교 이미지는 `build/preview/ai_cleanup.png`. 4절 확인 루프대로 열어 본다.
- 확대 배율을 정확히 알면 `--scale` 을 준다 (그쪽이 더 정확하다). 스프라이트 시트는 `--no-trim`.
- 받아 올 때: PNG 만, 흐릿하게 뭉개진 결과는 버린다. JPEG · 흐림은 격자 찾기가 매번 실패했다.
- 특정 작가 화풍을 흉내 낸 모델 · LoRA 결과물은 쓰지 않는다 (유료 판매 · 스킨 계획과 충돌). 쓴 도구와 라이선스는 README 에셋 절에 적는다.
- Snapper 설치: `cargo install spritefusion-pixel-snapper` (Rust 필요, MIT 라이선스).
