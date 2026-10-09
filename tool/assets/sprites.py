"""0x72 DungeonTileset II 프레임으로 스프라이트 시트를 만든다 (CC-0).

python -I tool/assets/sprites.py <압축 푼 0x72_DungeonTilesetII_v1.7/frames> assets/images/sprites

- 캐릭터: 16x28 프레임 9장(대기 4 · 달리기 4 · 피격 1)을 가로로 붙인 <캐릭터>.png.
  원본은 밝은 색이라 일러스트의 어두운 판타지 톤에 맞게 색 범위별로 다시 칠한다.
- 적 · 보스: 걷기(또는 하나뿐인) 애니메이션 4장을 가로로 붙인 enemies/<이름>.png.
  어떤 지역에 어떤 적을 쓸지는 lib/data/stages.dart 의 Region 이 정한다.
- 화면 배경: 바닥 · 벽 · 장식 16x16 타일을 가로로 붙인 scene/tiles.png 와 기둥 scene/column.png.
  순서는 lib/ui/widgets/dungeon_backdrop.dart 의 DungeonTile 과 같아야 한다.
- 공개 예정 캐릭터: 아직 쓰지 않은 영웅의 대기 4장 upcoming/<이름>.png (실루엣으로만 그린다).
- 화톳불: 원본에 없어 이 스크립트가 직접 그린다 (scene/campfire.png, 16x24 프레임 6장).
"""
import colorsys
import os
import sys

from PIL import Image

# 캐릭터 → (원본 이름, [(색상 범위 시작°, 끝°, 새 색상°, 채도 배율, 명도 배율)])
HEROES = {
    # 잿불 기사: 청록 갑옷 → 어두운 강철, 주황 깃털은 그대로 (잿불).
    'knight': ('knight_m', [(150, 235, 215, 0.12, 0.72)]),
    # 재의 마녀: 파란 · 보라 로브와 모자 → 검붉은 로브.
    'witch': ('wizzard_f', [(200, 290, 352, 0.8, 0.6)]),
    # 불씨 사냥꾼: 초록 옷 → 짙은 가죽색.
    'hunter': ('elf_f', [(70, 170, 28, 0.55, 0.62)]),
}

ORDER = [f'idle_anim_f{i}' for i in range(4)] + \
    [f'run_anim_f{i}' for i in range(4)] + ['hit_anim_f0']


def recolor(img, rules):
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = h * 360
            # 외곽선처럼 어둡거나 무채색인 픽셀은 건드리지 않는다.
            if s < 0.2 or v < 0.15:
                continue
            for start, end, hue, sat, val in rules:
                if start <= deg <= end:
                    nr, ng, nb = colorsys.hsv_to_rgb(hue / 360, s * sat, v * val)
                    px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
                    break
    return img


# 적 · 보스 시트 이름 → 원본 프레임 접두어. 원본 그대로 쓴다.
MONSTERS = {
    'tiny_zombie': 'tiny_zombie_run_anim',
    'skelet': 'skelet_run_anim',
    'imp': 'imp_run_anim',
    'orc_warrior': 'orc_warrior_run_anim',
    'chort': 'chort_run_anim',
    'big_zombie': 'big_zombie_run_anim',
    'necromancer': 'necromancer_anim',
    'ogre': 'ogre_run_anim',
    'masked_orc': 'masked_orc_run_anim',
    'big_demon': 'big_demon_run_anim',
}


# 배경 타일 순서. DungeonTile 과 같다.
TILES = [f'floor_{i}' for i in range(1, 9)] + [
    'wall_top_mid', 'wall_mid', 'wall_banner_red', 'wall_banner_blue',
    'wall_hole_1', 'skull',
]

UPCOMING = ['lizard_m', 'dwarf_m', 'knight_f']


def campfire(frames=6, w=16, h=24):
    """장작 위에서 일렁이는 불꽃. 프레임마다 폭과 끝이 조금씩 흔들린다."""
    import math
    import random
    dark, red, orange, yellow, core = (
        (0x8B, 0x1E, 0x12), (0xD6, 0x45, 0x1E), (0xFF, 0x8A, 0x3D),
        (0xFF, 0xC8, 0x4D), (0xFF, 0xF1, 0xB8))
    log, log_hi, log_dark = (0x5A, 0x3A, 0x22), (0x7E, 0x55, 0x32), (0x2E, 0x1D, 0x12)
    stone, stone_dark = (0x6B, 0x63, 0x5E), (0x3A, 0x34, 0x31)
    out = []
    for f in range(frames):
        rnd = random.Random(f * 7919)
        img = Image.new('RGBA', (w, h))
        px = img.load()
        sway = math.sin(f / frames * math.tau) * 1.3
        top, base = 2 + (f % 3 == 1), 20
        for y in range(top, base + 1):
            t = (y - top) / (base - top)          # 0 = 끝, 1 = 밑동
            # 밑이 넓고 끝이 뾰족한 불꽃. 줄마다 폭이 조금씩 흔들린다.
            half = 5.4 * t ** 0.85 * (1.2 - 0.45 * t) + rnd.uniform(-0.5, 0.5)
            cx = 8 + sway * (1 - t) ** 1.5
            for x in range(w):
                d = abs(x + 0.5 - cx) / max(half, 0.01)
                if d > 1:
                    continue
                if d < 0.3 and t > 0.55:
                    c = core
                elif d < 0.55 and t > 0.3:
                    c = yellow
                elif d < 0.85:
                    c = orange if t > 0.12 else red
                else:
                    c = red if t > 0.25 else dark
                px[x, y] = c + (255,)
        # 튀는 불티
        for _ in range(2):
            x, y = rnd.randint(3, 12), rnd.randint(0, 6)
            px[x, y] = yellow + (255,)
        # 엇갈린 장작 두 개 (불꽃 밑동을 가린다)
        for i in range(14):
            for x, y in ((1 + i, 23 - i // 5), (14 - i, 23 - i // 5)):
                px[x, y - 1] = log_hi + (255,)
                px[x, y] = log + (255,)
        for x, y in ((1, 23), (14, 23), (1, 22), (14, 22)):
            px[x, y] = log_dark + (255,)
        # 둘러싼 돌
        for x in (0, 15):
            px[x, 23] = stone + (255,)
            px[x, 22] = stone_dark + (255,)
        out.append(img)
    return out


def sheet(frames):
    w, h = frames[0].size
    assert all(f.size == (w, h) for f in frames)
    out = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def main(src, out):
    for name, (base, rules) in HEROES.items():
        frames = [
            recolor(Image.open(f'{src}/{base}_{o}.png').convert('RGBA'), rules)
            for o in ORDER
        ]
        img = sheet(frames)
        img.save(f'{out}/{name}.png', optimize=True)
        print(name, base, img.size)
    os.makedirs(f'{out}/enemies', exist_ok=True)
    for name, base in MONSTERS.items():
        img = sheet([
            Image.open(f'{src}/{base}_f{i}.png').convert('RGBA') for i in range(4)
        ])
        img.save(f'{out}/enemies/{name}.png', optimize=True)
        print(name, img.size)
    os.makedirs(f'{out}/scene', exist_ok=True)
    sheet([Image.open(f'{src}/{t}.png').convert('RGBA') for t in TILES]).save(
        f'{out}/scene/tiles.png', optimize=True)
    Image.open(f'{src}/column.png').convert('RGBA').save(
        f'{out}/scene/column.png', optimize=True)
    sheet(campfire()).save(f'{out}/scene/campfire.png', optimize=True)
    os.makedirs(f'{out}/upcoming', exist_ok=True)
    for name in UPCOMING:
        sheet([
            Image.open(f'{src}/{name}_idle_anim_f{i}.png').convert('RGBA')
            for i in range(4)
        ]).save(f'{out}/upcoming/{name}.png', optimize=True)
    print('scene · upcoming done')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
