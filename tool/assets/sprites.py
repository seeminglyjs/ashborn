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
- 전투 맵: 바닥 장식 16x16 scene/decor.png, 부서진 기둥 scene/column_broken.png,
  부술 수 있는 나무 상자 scene/crate.png (16x24) 와 보물 상자 scene/chest.png.
- 아이템: 장비 부위 아이콘 items/gear.png 와 소모품 items/pickups.png (16x16).
  원본에 없는 갑옷 · 장신구는 이 스크립트에 글자 그림으로 직접 그린다.
"""
import colorsys
import math
import os
import random
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


def campfire(frames=6, w=16, h=24, logs=True):
    """장작 위에서 일렁이는 불꽃. 프레임마다 폭과 끝이 조금씩 흔들린다.
    [logs] 가 False 면 불꽃만 그린다 (전투 맵의 불타는 나무 · 화로 · 불기둥)."""
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
        if not logs:
            out.append(img)
            continue
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


# ── 직접 그리는 16x16 픽셀 그림 ────────────────────────────────────────
# 글자 하나가 픽셀 하나. '.' 은 투명이고, 외곽선은 [pixel_art] 가 자동으로 두른다.
PALETTE = {
    '#': (0x1A, 0x14, 0x14),  # 외곽선 · 금
    'W': (0xF4, 0xF0, 0xE6),  # 하이라이트
    'L': (0xC9, 0xC6, 0xC2),  # 밝은 쇠
    'M': (0x8E, 0x8A, 0x88),  # 쇠
    'D': (0x55, 0x51, 0x52),  # 어두운 쇠
    'Y': (0xF2, 0xC1, 0x4E),  # 금
    'y': (0xB0, 0x7A, 0x24),  # 어두운 금
    'B': (0x8A, 0x5A, 0x34),  # 가죽 · 나무
    'b': (0x5A, 0x38, 0x22),  # 어두운 가죽
    'R': (0xD8, 0x3A, 0x2E),  # 빨강
    'r': (0x8B, 0x1E, 0x18),  # 어두운 빨강
    'C': (0x6F, 0xD8, 0xF0),  # 강화석
    'c': (0x2F, 0x86, 0xB8),  # 어두운 강화석
    'G': (0x4F, 0xE0, 0xA8),  # 초록 보석
    'g': (0x1F, 0x8A, 0x63),
    'P': (0xC0, 0x6C, 0xF0),  # 보라 보석
    'p': (0x6E, 0x34, 0x9A),
    'O': (0xDE, 0xD5, 0xC4),  # 뼈
    'o': (0x9C, 0x92, 0x82),
    'S': (0x7C, 0x76, 0x72),  # 돌
    's': (0x4C, 0x47, 0x45),
    'A': (0x6A, 0x63, 0x60),  # 재
    'a': (0x45, 0x40, 0x3E),
    'F': (0xFF, 0x9A, 0x3D),  # 불씨
    'f': (0xFF, 0xE0, 0x8A),
    'K': (0x26, 0x1E, 0x1C),  # 금 간 바닥
    'U': (0x3E, 0x6E, 0x96),  # 물웅덩이
    'u': (0x6C, 0xA4, 0xC8),
    'X': (0x6E, 0x14, 0x1C),  # 핏자국
    'x': (0x9C, 0x22, 0x2C),
    'N': (0x9A, 0x4E, 0x2A),  # 녹
    'n': (0x6A, 0x30, 0x1A),
}
OUTLINE = PALETTE['#']


def pixel_art(rows, outline=True, alpha=255):
    """[rows] (16줄 x 16글자) 를 그림으로. [outline] 이면 칠한 픽셀 둘레 빈칸을 외곽선으로 채운다."""
    h, w = len(rows), len(rows[0])
    assert all(len(r) == w for r in rows), rows
    img = Image.new('RGBA', (w, h))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                px[x, y] = PALETTE[ch] + (alpha,)
    if outline:
        filled = {(x, y) for y in range(h) for x in range(w) if px[x, y][3]}
        for y in range(h):
            for x in range(w):
                if (x, y) in filled:
                    continue
                if any((x + dx, y + dy) in filled
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    px[x, y] = OUTLINE + (255,)
    return img


def sword():
    """한손장비: 오른쪽 위로 뻗은 검. 대각선이라 좌표로 그린다."""
    grid = [['.'] * 16 for _ in range(16)]
    for y in range(1, 10):
        x = 14 - y
        grid[y][x] = 'W'
        grid[y][x + 1] = 'L' if y > 1 else 'W'
        if y > 2:
            grid[y][x + 2] = 'M' if x + 2 < 15 else '.'
    for x, y in ((2, 8), (3, 9), (4, 10), (5, 11), (6, 12), (3, 8), (6, 11)):
        grid[y][x] = 'Y'
    grid[12][6] = 'y'
    for x, y in ((3, 11), (2, 12)):
        grid[y][x] = 'B'
    grid[13][1] = 'Y'
    return pixel_art([''.join(r) for r in grid])


# 장비 아이콘. 순서는 ItemType (lib/data/equipment.dart) 과 같다.
GEAR = {
    'head': [
        '................',
        '.......RR.......',
        '......RrrR......',
        '......MMMM......',
        '....MLLLLMMD....',
        '...MLWLLLLMMD...',
        '...MLLLLLLMMD...',
        '...MMMMMMMMMD...',
        '...DDDDDDDDDD...',
        '...MLMMMMMMMD...',
        '...MLMMMMMMMD...',
        '...MMDMMDMMDD...',
        '....MMMMMMMD....',
        '.....DDDDDD.....',
        '................',
        '................',
    ],
    'boots': [
        '................',
        '................',
        '...BBBBb........',
        '...BBBBb........',
        '...BWBBb........',
        '...YYYYy........',
        '...BBBBb........',
        '...BBBBb........',
        '...BBBBbb.......',
        '...BBBBBBBBbb...',
        '...BWBBBBBBBbb..',
        '...BBBBBBBBBBb..',
        '...bbbbbbbbbbb..',
        '...DDDDDDDDDDD..',
        '................',
        '................',
    ],
    'twoHand': [
        '................',
        '...M...YY...M...',
        '..MLM..BB..MLM..',
        '.MLLLMMBBMMLLLM.',
        '.MLWLLLBBLLLWLM.',
        '.MLWLLLBBLLLWLM.',
        '.MLLLMMBBMMLLLM.',
        '..MLM..BB..MLM..',
        '...M...BB...M...',
        '.......BB.......',
        '.......bB.......',
        '.......BB.......',
        '.......Bb.......',
        '.......BB.......',
        '.......YY.......',
        '................',
    ],
    'oneHand': None,  # [sword]
    'gloves': [
        '................',
        '................',
        '.....M.M.M......',
        '....MLMLMLM.....',
        '....MLMLMLM.....',
        '....MLMLMLM.....',
        '..M.MLLLLLM.....',
        '..MLMLLLLLM.....',
        '...MLLWLLLM.....',
        '....MLLLLLM.....',
        '....MLLLLDM.....',
        '....YYYYYYY.....',
        '....BBBBBBB.....',
        '....bbbbbbb.....',
        '................',
        '................',
    ],
    'necklace': [
        '................',
        '..Y.........Y...',
        '..y.........y...',
        '...Y.......Y....',
        '...y.......y....',
        '....Y.....Y.....',
        '.....y...y......',
        '......YyY.......',
        '......RRR.......',
        '.....RWRRR......',
        '.....RRRRr......',
        '.....rRRrr......',
        '......rrr.......',
        '.......r........',
        '................',
        '................',
    ],
    'ring': [
        '................',
        '................',
        '......gGg.......',
        '.....gGWGg......',
        '......gGg.......',
        '.....YYYYY......',
        '....YW...yY.....',
        '...YY.....yy....',
        '...Y.......y....',
        '...Y.......y....',
        '...Y.......y....',
        '...yY.....yy....',
        '....yy...yy.....',
        '.....yyyyy......',
        '................',
        '................',
    ],
    'belt': [
        '................',
        '................',
        '................',
        '................',
        '.....YYYYY......',
        '.BBBBY...YBBBBB.',
        '.BWBBY.y.YBBDBB.',
        '.BBBBY.y.YBBBBB.',
        '.bbbbY...Ybbbbb.',
        '.....YYYYY......',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
    ],
    'earring': [
        '................',
        '................',
        '.......YY.......',
        '......Y..Y......',
        '......y..y......',
        '.......yy.......',
        '.......Y........',
        '.......y........',
        '......PPP.......',
        '.....PWPPP......',
        '.....PPPPp......',
        '.....pPPpp......',
        '......ppp.......',
        '.......p........',
        '................',
        '................',
    ],
}

# 바닥에 떨어지는 소모품. 순서는 PickupKind (lib/components/pickups/supply.dart) 과 같다.
# potion 은 0x72 flask_big_red 를 쓴다.
PICKUPS = {
    'potion': None,
    'gold': [
        '................',
        '................',
        '................',
        '................',
        '.......YYYY.....',
        '......YWYYYy....',
        '......yYYYyy....',
        '.......yyyy.....',
        '...YYYY.YYYY....',
        '..YWYYYyWYYYy...',
        '..yYYYyyYYYyy...',
        '...yyyy.yyyy....',
        '................',
        '................',
        '................',
        '................',
    ],
    'stone': [
        '................',
        '.......W........',
        '......WCC.......',
        '.....WCCCc......',
        '....WCCCCcc.....',
        '....WCCCCcc.....',
        '....CCWCCcc.....',
        '....CCCCccc.....',
        '.....CCCcc......',
        '......Ccc.......',
        '.......c........',
        '................',
        '................',
        '................',
        '................',
        '................',
    ],
    'magnet': [
        '................',
        '................',
        '..LLL.....LLL...',
        '..WLL.....WLL...',
        '..RRr.....RRr...',
        '..RRr.....RRr...',
        '..RRr.....RRr...',
        '..RRRr...rRRr...',
        '...RRRrrrRRr....',
        '....RRRRRRr.....',
        '.....rrrrr......',
        '................',
        '................',
        '................',
        '................',
        '................',
    ],
}

# 바닥 장식. 순서는 Decor (lib/game/world/dungeon_floor.dart) 와 같다.
# 문자열 대신 이름이면 0x72 원본 프레임을 그대로 쓴다. (그림, 외곽선)
DECOR = {
    'skull': 'skull',
    'bones': ([
        '................',
        '................',
        '.....O..........',
        '....OOo.........',
        '.....OOo........',
        '......Oo........',
        '................',
        '................',
        '...o.......o....',
        '..OOo.....OOo...',
        '...OOOOOOOOOo...',
        '..OOo.....OOo...',
        '...o.......o....',
        '................',
        '................',
        '................',
    ], True),
    'rubble': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '......SS........',
        '.....SSSs.......',
        '.....sSss...S...',
        '..Ss.......SSs..',
        '.SSss.....Sss...',
        '..sss...........',
        '................',
        '................',
        '................',
    ], True),
    'crack': ([
        '................',
        '................',
        '.......K........',
        '......K.........',
        '......KK........',
        '.......K........',
        '........K.......',
        '.......KK.......',
        '......K..K......',
        '.....K....KK....',
        '....K.......K...',
        '...K............',
        '................',
        '................',
        '................',
        '................',
    ], False),
    'ash': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '......AAAA......',
        '....AAAAAAAa....',
        '...AAAAAAAAaa...',
        '..aAAAAAAAAAaa..',
        '...aaaaaaaaaa...',
        '................',
        '................',
        '................',
    ], False),
    'puddle': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '.....UUUUU......',
        '...UUUuuUUUU....',
        '..UUuuUUUUUUU...',
        '..UUUUUUUUuUUU..',
        '...UUUUUUUUUU...',
        '.....UUUUUU.....',
        '................',
        '................',
        '................',
        '................',
        '................',
    ], False),
    'candles': ([
        '................',
        '................',
        '....f...........',
        '....F......f....',
        '....W......F....',
        '....O......W....',
        '....O..f...O....',
        '....O..F...O....',
        '....O..W...O....',
        '....O..O...O....',
        '....o..O...o....',
        '...ooo.o..ooo...',
        '.......oo.......',
        '................',
        '................',
        '................',
    ], True),
    'stump': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '.....BBBBBB.....',
        '....BbBBBBbB....',
        '....BBbbbbBB....',
        '....bBBBBBBb....',
        '....bbbbbbbb....',
        '....bbbbbbbb....',
        '...bbbb..bbbb...',
        '..bb........bb..',
        '................',
        '................',
        '................',
    ], True),
    'embers': ([
        '................',
        '................',
        '................',
        '.........F......',
        '................',
        '....F...........',
        '................',
        '.......aaa......',
        '.....aaFaaa.....',
        '....aaFfFaaa....',
        '....aaaFaaaa....',
        '.....aaaaaa.....',
        '...........F....',
        '................',
        '................',
        '................',
    ], False),
    'blood': ([
        '................',
        '................',
        '................',
        '.........X......',
        '................',
        '......XXX.......',
        '....XXxxXXX.....',
        '...XXxXXXXXX....',
        '...XXXXXXxXX..X.',
        '....XXXXXXX.....',
        '.......XX.......',
        '..X.............',
        '................',
        '................',
        '................',
        '................',
    ], False),
    'broken_sword': ([
        '................',
        '................',
        '.......M........',
        '.......LN.......',
        '.......LM.......',
        '.......NM.......',
        '.......Ln.......',
        '.....NnNNnN.....',
        '.......Bb.......',
        '.......Bb.......',
        '.......Yy.......',
        '.....s.SS.s.....',
        '......sSSs......',
        '................',
        '................',
        '................',
    ], True),
    'spikes': 'floor_spikes_anim_f3',
    'hole': 'hole',
    'grass': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '.....a....a.....',
        '..a..A...aA.....',
        '...A.Aa..A...a..',
        '...AaA.A.A..A...',
        '....AA.AAA.Aa...',
        '.....aaaaaaa....',
        '................',
        '................',
        '................',
    ], False),
    # ── 지역 장식 (평원 · 성당 · 심장) ──
    'tall_grass': ([
        '................',
        '................',
        '................',
        '.......y........',
        '....y..y...y....',
        '....y..yy..y....',
        '.....y.y..y..y..',
        '..y..y.y..y.y...',
        '...y.yyy.yy.y...',
        '...yy.yy.y.y....',
        '....yyyyyyy.....',
        '.....bbbbb......',
        '................',
        '................',
        '................',
        '................',
    ], True),
    'dead_bush': ([
        '................',
        '................',
        '................',
        '................',
        '...b.....b......',
        '....b...b...b...',
        '..b..b.b...b....',
        '...b..bb..b..b..',
        '....b.bb.b..b...',
        '.....bbbbb.b....',
        '......bbbb......',
        '.......bb.......',
        '......BbbB......',
        '................',
        '................',
        '................',
    ], True),
    'withered_flower': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '.....nn.........',
        '....nNNn....o...',
        '.....nn....oOo..',
        '......y.....o...',
        '......y....y....',
        '.......y..y.....',
        '.......y.y......',
        '........y.......',
        '................',
        '................',
        '................',
    ], True),
    'pew': ([
        '................',
        '................',
        '................',
        '................',
        '................',
        '..BBBBBBB.......',
        '..BbbbbbbB.B....',
        '..B.......BB....',
        '..BBBBBBBBBBB...',
        '..bbbbbbbbbbb...',
        '..b.........b...',
        '..b.........b...',
        '................',
        '................',
        '................',
        '................',
    ], True),
    'lava_crack': ([
        '................',
        '................',
        '................',
        '.....r..........',
        '.....rF.........',
        '......Fr........',
        '......rFr...r...',
        '.......rF..rF...',
        '......rFfFFFr...',
        '.....rF..rr.....',
        '....rFr.........',
        '....r...........',
        '................',
        '................',
        '................',
        '................',
    ], False),
}


def broken_column(src):
    """원본 기둥(16x48)의 아랫부분에 깨진 윗단을 판 것. 깨진 면은 밝은 돌색."""
    img = Image.open(f'{src}/column.png').convert('RGBA')
    bottom = img.getbbox()[3]
    img = img.crop((0, bottom - 30, 16, bottom))
    px = img.load()
    # 열마다 깎아 낼 깊이. 들쭉날쭉하게.
    for x, depth in enumerate([6, 5, 4, 3, 2, 3, 4, 6, 7, 5, 3, 2, 2, 4, 6, 7]):
        for y in range(depth):
            px[x, y] = (0, 0, 0, 0)
        if px[x, depth][3]:
            px[x, depth] = (0xB8, 0xA8, 0x9C, 255)
            if px[x, depth + 1][3]:
                px[x, depth + 1] = (0x8A, 0x7C, 0x72, 255)
    return img


def fit16(img):
    """16x16 칸 가운데 아래에 맞춘다."""
    out = Image.new('RGBA', (16, 16))
    out.paste(img, ((16 - img.width) // 2, 16 - img.height))
    return out


# ── 지역별 바닥 타일 · 큰 구조물 ─────────────────────────────────────────
# 잿빛 평원 · 불타는 숲 · 꺼지지 않는 심장은 0x72 돌바닥 대신 직접 만든 바닥을 깐다.
# 16x16 8장. 가장자리에 무늬가 걸리지 않게 점 · 얼룩만 찍어 이어 붙여도 이음매가 없다.
# 순서와 쓰임새(평범한 바닥이 앞쪽)는 lib/game/world/region_theme.dart 의 floorWeights 와 맞춘다.


def _blotches(px, rnd, color, count, size=(1, 3)):
    for _ in range(count):
        x, y = rnd.randrange(16), rnd.randrange(16)
        for _ in range(rnd.randint(*size)):
            px[x % 16, y % 16] = color + (255,)
            x += rnd.choice((-1, 0, 1))
            y += rnd.choice((-1, 0, 1))


def plains_floor():
    """시든 풀밭. 0~4 풀, 5~6 맨흙이 드러난 풀, 7 자갈."""
    base = (0x44, 0x45, 0x33)
    dark, light = (0x3A, 0x3B, 0x2C), (0x50, 0x50, 0x3A)
    blade, straw = (0x66, 0x64, 0x44), (0x7C, 0x6E, 0x48)
    dirt, dirt_dark = (0x4E, 0x42, 0x33), (0x40, 0x36, 0x2A)
    pebble, pebble_dark = (0x76, 0x72, 0x6A), (0x52, 0x4E, 0x48)
    out = []
    for i in range(8):
        rnd = random.Random(100 + i)
        img = Image.new('RGBA', (16, 16), base + (255,))
        px = img.load()
        _blotches(px, rnd, dark, 10)
        _blotches(px, rnd, light, 8)
        if i in (5, 6):
            _blotches(px, rnd, dirt, 7, (3, 6))
            _blotches(px, rnd, dirt_dark, 4)
        if i == 7:
            for _ in range(3):
                x, y = rnd.randrange(16), rnd.randrange(16)
                px[x, y] = pebble + (255,)
                px[(x + 1) % 16, y] = pebble + (255,)
                px[x, (y + 1) % 16] = pebble_dark + (255,)
        # 짧은 풀잎: 밑동은 어둡고 끝은 밝다.
        for _ in range(7 if i < 5 else 3):
            x, y = rnd.randrange(16), rnd.randrange(16)
            px[x, y] = blade + (255,)
            px[x, (y - 1) % 16] = (straw if rnd.random() < 0.4 else blade) + (255,)
        out.append(img)
    return out


def forest_floor():
    """그을린 숲 바닥. 0~3 흙과 낙엽, 4~5 숯이 된 자리, 6 재, 7 잔불이 남은 숯."""
    base = (0x33, 0x25, 0x1C)
    dark, light = (0x29, 0x1D, 0x16), (0x3E, 0x2D, 0x22)
    leaf, leaf_dark = (0x7A, 0x3E, 0x1C), (0x5A, 0x2E, 0x18)
    char, char_hi = (0x1B, 0x15, 0x13), (0x26, 0x1F, 0x1C)
    ash, ember = (0x5C, 0x56, 0x50), (0xFF, 0x7A, 0x2A)
    out = []
    for i in range(8):
        rnd = random.Random(200 + i)
        img = Image.new('RGBA', (16, 16), base + (255,))
        px = img.load()
        _blotches(px, rnd, dark, 10)
        _blotches(px, rnd, light, 6)
        if i >= 4:
            _blotches(px, rnd, char, 8, (3, 7))
            _blotches(px, rnd, char_hi, 4)
        if i == 6:
            _blotches(px, rnd, ash, 6, (2, 4))
        if i == 7:
            for _ in range(3):
                px[rnd.randrange(16), rnd.randrange(16)] = ember + (255,)
        for _ in range(5 if i < 4 else 2):
            x, y = rnd.randrange(16), rnd.randrange(16)
            px[x, y] = leaf + (255,)
            px[(x + 1) % 16, y] = leaf_dark + (255,)
        out.append(img)
    return out


def temple_floor():
    """검붉은 신전 석판. 0~3 석판, 4 금 간 석판, 5 용암이 비치는 균열, 6 불의 문양, 7 작은 석판 넷."""
    grout = (0x1A, 0x0C, 0x0E)
    slab, slab_dark, slab_hi = (0x45, 0x24, 0x26), (0x3B, 0x1E, 0x21), (0x55, 0x30, 0x30)
    crack = (0x24, 0x10, 0x12)
    lava, lava_dark = (0xFF, 0x7A, 0x2A), (0xC2, 0x3A, 0x1A)
    rune = (0x9A, 0x5A, 0x28)
    out = []
    for i in range(8):
        rnd = random.Random(300 + i)
        img = Image.new('RGBA', (16, 16), slab + (255,))
        px = img.load()
        _blotches(px, rnd, slab_dark, 8)
        _blotches(px, rnd, slab_hi, 3, (1, 2))
        lines = [0] if i != 7 else [0, 8]
        for g in lines:
            for t in range(16):
                px[g, t] = grout + (255,)
                px[t, g] = grout + (255,)
        if i in (4, 5):
            x, y = 4, 3
            for _ in range(12):
                px[x, y] = (lava if i == 5 else crack) + (255,)
                if i == 5:
                    for dx, dy in ((1, 0), (-1, 0)):
                        if px[x + dx, y + dy][:3] != lava:
                            px[x + dx, y + dy] = lava_dark + (255,)
                x = min(13, max(2, x + rnd.choice((-1, 0, 1))))
                y = min(14, y + 1)
        if i == 6:
            for a in range(24):
                import math
                t = a / 24 * math.tau
                px[round(8 + 4.5 * math.cos(t)), round(8 + 4.5 * math.sin(t))] = rune + (255,)
            for x, y in ((8, 6), (7, 7), (8, 7), (9, 7), (7, 8), (8, 8), (9, 8), (8, 9)):
                px[x, y] = lava_dark + (255,)
        out.append(img)
    return out


def _thick_line(px, a, b, color, r=0.0):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
    for i in range(n + 1):
        t = i / n
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if dx * dx + dy * dy <= r * r + 0.01:
                    x, y = round(cx + dx), round(cy + dy)
                    if 0 <= x < px.width and 0 <= y < px.height:
                        px.img[x, y] = color + (255,)


class _Px:
    def __init__(self, img):
        self.img = img.load()
        self.width, self.height = img.size


# 나무 모양 (32x40). 가지 끝 좌표는 불타는 나무의 불꽃 자리이고
# lib/game/world/region_theme.dart 의 Structure.burningTree 와 같아야 한다.
TREE_TRUNK = [((16, 39), (16, 22), 2.2), ((16, 22), (15, 12), 1.4)]
TREE_BRANCHES = [
    ((16, 26), (7, 17)), ((7, 17), (4, 11)), ((16, 23), (25, 15)),
    ((25, 15), (28, 9)), ((15, 15), (10, 7)), ((15, 12), (18, 4)),
    ((21, 19), (24, 22)),
]
TREE_TIPS = [(4, 11), (28, 9), (10, 7), (18, 4)]


def tree(bark, bark_dark, bark_hi, embers=None):
    img = Image.new('RGBA', (32, 40))
    px = _Px(img)
    for a, b, r in TREE_TRUNK:
        _thick_line(px, a, b, bark, r)
    for i, (a, b) in enumerate(TREE_BRANCHES):
        # 줄기에서 갈라지는 첫 마디는 굵고 끝 가지는 가늘다.
        _thick_line(px, a, b, bark, 1.0 if a[0] in (15, 16) else 0.5)
    raw = img.load()
    # 줄기 왼쪽은 밝게, 오른쪽은 어둡게.
    for y in range(40):
        row = [x for x in range(32) if raw[x, y][3]]
        if len(row) >= 3 and y > 20:
            raw[row[0], y] = bark_hi + (255,)
            raw[row[-1], y] = bark_dark + (255,)
    # 뿌리
    for x, y in ((12, 39), (13, 38), (20, 39), (19, 38)):
        raw[x, y] = bark_dark + (255,)
    if embers:
        rnd = random.Random(7)
        cells = [(x, y) for y in range(18, 39) for x in range(32) if raw[x, y][3]]
        for x, y in rnd.sample(cells, 9):
            raw[x, y] = embers + (255,)
    return _outlined(img)


def _outlined(img):
    px = img.load()
    w, h = img.size
    filled = {(x, y) for y in range(h) for x in range(w) if px[x, y][3]}
    for y in range(h):
        for x in range(w):
            if (x, y) not in filled and any(
                    (x + dx, y + dy) in filled
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE + (255,)
    return img


def dead_tree():
    return tree((0x6A, 0x5A, 0x4A), (0x4A, 0x3E, 0x33), (0x86, 0x74, 0x60))


def charred_tree():
    return tree((0x2E, 0x26, 0x23), (0x1E, 0x18, 0x17), (0x44, 0x38, 0x33),
                embers=(0xFF, 0x7A, 0x2A))


# 화로 (16x24). 불꽃은 그릇 위 (8, 9) 에 선다.
BRAZIER = [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.....FfFfF......',
    '..YYFFFFFFFFYY..',
    '..yDDDDDDDDDDy..',
    '...DMMMMMMMMD...',
    '....DMMMMMMD....',
    '.....DDDDDD.....',
    '.......DD.......',
    '.......MD.......',
    '.......MD.......',
    '.......MD.......',
    '......DMDD......',
    '.....DMMMDD.....',
    '....DDDDDDDD....',
    '................',
    '................',
]

# 바닥 불구멍 (16x16). 문양 가운데서 불꽃이 솟는다.
FIRE_VENT = [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '......yyyy......',
    '....yyrrrryy....',
    '...yrrFFFFrry...',
    '...yrFfffFFry...',
    '...yrrFFFFrry...',
    '....yyrrrryy....',
    '......yyyy......',
    '................',
    '................',
    '................',
]


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
    sheet([Image.open(f'{src}/crate.png').convert('RGBA')]).save(
        f'{out}/scene/crate.png', optimize=True)
    Image.open(f'{src}/chest_full_open_anim_f0.png').convert('RGBA').save(
        f'{out}/scene/chest.png', optimize=True)
    broken_column(src).save(f'{out}/scene/column_broken.png', optimize=True)
    decor = []
    for name, art in DECOR.items():
        if isinstance(art, str):
            decor.append(Image.open(f'{src}/{art}.png').convert('RGBA'))
        else:
            rows, outline = art
            decor.append(pixel_art(rows, outline=outline))
    sheet(decor).save(f'{out}/scene/decor.png', optimize=True)
    sheet(plains_floor()).save(f'{out}/scene/floor_plains.png', optimize=True)
    sheet(forest_floor()).save(f'{out}/scene/floor_forest.png', optimize=True)
    sheet(temple_floor()).save(f'{out}/scene/floor_temple.png', optimize=True)
    dead_tree().save(f'{out}/scene/dead_tree.png', optimize=True)
    charred_tree().save(f'{out}/scene/charred_tree.png', optimize=True)
    pixel_art(BRAZIER).save(f'{out}/scene/brazier.png', optimize=True)
    pixel_art(FIRE_VENT, outline=False).save(
        f'{out}/scene/fire_vent.png', optimize=True)
    sheet(campfire(logs=False)).save(f'{out}/scene/flame.png', optimize=True)
    os.makedirs(f'{out}/items', exist_ok=True)
    sheet([sword() if art is None else pixel_art(art) for art in GEAR.values()]
          ).save(f'{out}/items/gear.png', optimize=True)
    sheet([
        fit16(Image.open(f'{src}/flask_big_red.png').convert('RGBA'))
        if art is None else pixel_art(art)
        for art in PICKUPS.values()
    ]).save(f'{out}/items/pickups.png', optimize=True)
    print('scene · upcoming · items done')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
