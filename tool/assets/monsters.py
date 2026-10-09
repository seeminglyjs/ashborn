"""지역 졸개 시트를 늘린다: 새로 그린 몬스터(슬라임 · 박쥐 · 정령)와 기존 시트의 재채색 변종.

python -I tool/assets/monsters.py assets/images/sprites

- 원본 0x72 프레임 없이, 이미 만든 enemies/<이름>.png (sprites.py 결과) 를 읽어 다시 칠한다.
- 새 몬스터는 16x16 프레임 4장을 이 스크립트가 직접 그린다 (CC-0 원본에 없음).
- 이름과 크기는 lib/data/monster_sprites.dart 의 MonsterSprite 와 같아야 한다.
"""
import colorsys
import math
import random
import sys

from PIL import Image

OUTLINE = (0x1A, 0x14, 0x14)


def sheet(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def outlined(img):
    """칠한 픽셀 둘레 빈칸을 외곽선으로 채운다."""
    px = img.load()
    w, h = img.size
    filled = {(x, y) for y in range(h) for x in range(w) if px[x, y][3]}
    for y in range(h):
        for x in range(w):
            if (x, y) in filled:
                continue
            if any((x + dx, y + dy) in filled
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE + (255,)
    return img


def shade(color, k):
    return tuple(max(0, min(255, round(c * k))) for c in color)


# ── 새로 그리는 몬스터 ────────────────────────────────────────────────

def slime(body):
    """출렁이며 기어 오는 슬라임. 프레임마다 납작해졌다 솟는다."""
    frames = []
    for f, squash in enumerate((1.0, 0.86, 0.74, 0.88)):
        img = Image.new('RGBA', (16, 16))
        px = img.load()
        h = 10 * squash
        half = 6.2 / math.sqrt(squash)
        top = 15 - h
        for y in range(16):
            for x in range(16):
                dx = (x + 0.5 - 8) / half
                dy = (y + 0.5 - (15 - h / 2)) / (h / 2)
                # 밑은 평평하고 위는 둥근 방울.
                if dy > 0:
                    dy *= 0.35
                if dx * dx + dy * dy > 1 or y >= 15 or y < top:
                    continue
                t = (y - top) / max(h, 1)
                c = shade(body, 1.25 - 0.55 * t)
                px[x, y] = c + (230,)
        # 반짝이는 하이라이트와 두 눈.
        hy = int(top + h * 0.25)
        px[5, hy] = (255, 255, 255, 255)
        px[6, hy] = shade(body, 1.6) + (255,)
        ey = int(top + h * 0.5)
        for ex in (6, 9):
            px[ex, ey] = OUTLINE + (255,)
            px[ex, ey - 1] = OUTLINE + (255,)
        frames.append(outlined(img))
    return frames


BAT_BODY = [
    '................',
    '................',
    '................',
    '......#..#......',
    '......####......',
    '.....##EE##.....',
    '.....#BBBB#.....',
    '......BBBB......',
    '.......BB.......',
    '................',
]

# 날개 끝 높이: 위로 · 가운데 · 아래로 · 가운데.
BAT_WINGS = [(-4, 0), (0, 1), (3, 2), (0, 1)]


def bat(body, eye):
    """날개를 퍼덕이는 박쥐."""
    frames = []
    for lift, droop in BAT_WINGS:
        img = Image.new('RGBA', (16, 16))
        px = img.load()
        oy = 3 - droop
        for y, row in enumerate(BAT_BODY):
            for x, ch in enumerate(row):
                if ch == '#':
                    px[x, y + oy] = shade(body, 0.7) + (255,)
                elif ch == 'B':
                    px[x, y + oy] = body + (255,)
                elif ch == 'E':
                    px[x, y + oy] = eye + (255,)
        # 날개: 몸통 옆에서 바깥으로 뻗는 막.
        for side in (-1, 1):
            for i in range(6):
                x = 8 + side * (2 + i) - (1 if side < 0 else 0)
                tip = 6 + oy + round(lift * i / 5)
                for y in range(tip, 9 + oy - i // 3):
                    if 0 <= x < 16 and 0 <= y < 16:
                        k = 0.55 if y > tip else 0.85
                        px[x, y] = shade(body, k) + (255,)
        frames.append(outlined(img))
    return frames


def wisp(core, mid, edge):
    """일렁이는 불꽃 정령. 밑이 가늘고 머리가 둥근 혼불에 두 눈."""
    frames = []
    for f in range(4):
        rnd = random.Random(f * 31)
        img = Image.new('RGBA', (16, 16))
        px = img.load()
        sway = math.sin(f / 4 * math.tau) * 1.2
        for y in range(1, 16):
            t = (y - 1) / 14                  # 0 = 꼭대기, 1 = 꼬리
            # 머리는 둥글고 꼬리로 갈수록 가늘어진다.
            if t < 0.55:
                half = 5.5 * math.sqrt(max(0, 1 - ((t - 0.4) / 0.4) ** 2))
            else:
                half = 4.8 * (1 - (t - 0.55) / 0.45) ** 1.3
            half += rnd.uniform(-0.4, 0.4)
            cx = 8 + sway * t
            for x in range(16):
                d = abs(x + 0.5 - cx) / max(half, 0.01)
                if d > 1:
                    continue
                c = core if d < 0.4 and t < 0.6 else mid if d < 0.75 else edge
                px[x, y] = c + (235,)
        for ex in (6, 9):
            px[ex, 6] = OUTLINE + (255,)
            px[ex, 7] = OUTLINE + (255,)
        frames.append(outlined(img))
    return frames


# ── 기존 시트 다시 칠하기 ─────────────────────────────────────────────

def variant(img, hue=None, sat=1.0, val=1.0, tint=None, amount=0.0):
    """외곽선(아주 어두운 픽셀)은 두고 나머지를 다시 칠한다.
    [hue] 가 있으면 채도 있는 픽셀의 색상을 그 각도로 바꾸고, [tint] 는 밝기를 살린 채
    그 색을 [amount] 만큼 섞는다 (해골처럼 무채색인 그림에 색을 입힐 때)."""
    img = img.copy()
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v < 0.15:
                continue
            if hue is not None and s >= 0.2:
                h = hue / 360
            s = min(1, s * sat)
            v = min(1, v * val)
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            if tint is not None:
                tr, tg, tb = (c / 255 for c in tint)
                nr = nr * (1 - amount) + v * tr * amount
                ng = ng * (1 - amount) + v * tg * amount
                nb = nb * (1 - amount) + v * tb * amount
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return img


# 이름 → (원본 시트, 다시 칠하는 인자)
VARIANTS = {
    'orc_ash': ('orc_warrior', dict(sat=0.15, val=0.85)),
    'ogre_ash': ('ogre', dict(sat=0.2, val=0.8, tint=(0xC8, 0xC0, 0xB0), amount=0.3)),
    'skelet_drowned': ('skelet', dict(tint=(0x6F, 0xC8, 0xD8), amount=0.55)),
    'tiny_zombie_drowned': ('tiny_zombie', dict(tint=(0x5E, 0xA8, 0xD8), amount=0.6)),
    'masked_orc_tide': ('masked_orc', dict(hue=210, sat=0.9)),
    'necromancer_pale': ('necromancer', dict(tint=(0xB8, 0xD8, 0xFF), amount=0.5, val=1.1)),
    'necromancer_ember': ('necromancer', dict(hue=18, sat=1.3, tint=(0xFF, 0x80, 0x40), amount=0.35)),
    'big_zombie_char': ('big_zombie', dict(sat=0.3, val=0.75, tint=(0xFF, 0x70, 0x30), amount=0.3)),
    'orc_lancer': ('orc_warrior', dict(hue=45, sat=0.7, val=0.95)),
    'skelet_rust': ('skelet', dict(tint=(0xD8, 0x9A, 0x48), amount=0.5)),
    'imp_goblin': ('imp', dict(hue=95, sat=0.8)),
    'ogre_rust': ('ogre', dict(hue=30, sat=0.75, val=0.9)),
    'necromancer_blood': ('necromancer', dict(hue=345, sat=1.2, tint=(0xD0, 0x30, 0x50), amount=0.4)),
    'chort_void': ('chort', dict(hue=275, sat=0.9)),
    'big_zombie_flesh': ('big_zombie', dict(hue=350, sat=1.1, val=0.95)),
}

# 새로 그리는 몬스터: 이름 → 프레임
DRAWN = {
    'slime_ash': lambda: slime((0x8E, 0x95, 0x6A)),
    'slime_frost': lambda: slime((0x5E, 0xA8, 0xD8)),
    'slime_lava': lambda: slime((0xE8, 0x6A, 0x2A)),
    'slime_blood': lambda: slime((0xB0, 0x2A, 0x3E)),
    'bat_ash': lambda: bat((0x6E, 0x62, 0x5E), (0xFF, 0xD0, 0x60)),
    'bat_ember': lambda: bat((0xA8, 0x3A, 0x22), (0xFF, 0xE0, 0x8A)),
    'bat_blood': lambda: bat((0x7A, 0x1E, 0x32), (0xFF, 0x60, 0x60)),
    'wisp_frost': lambda: wisp((0xE8, 0xF8, 0xFF), (0x8F, 0xD3, 0xFF), (0x3E, 0x7E, 0xC8)),
    'wisp_ember': lambda: wisp((0xFF, 0xF1, 0xB8), (0xFF, 0x9A, 0x3D), (0xD6, 0x45, 0x1E)),
    'wisp_spark': lambda: wisp((0xFF, 0xFF, 0xE0), (0xFF, 0xE4, 0x5C), (0xC8, 0x9A, 0x1E)),
}


def main(out):
    enemies = f'{out}/enemies'
    for name, (base, args) in VARIANTS.items():
        img = variant(Image.open(f'{enemies}/{base}.png').convert('RGBA'), **args)
        img.save(f'{enemies}/{name}.png', optimize=True)
        print(name, img.size)
    for name, draw in DRAWN.items():
        img = sheet(draw())
        img.save(f'{enemies}/{name}.png', optimize=True)
        print(name, img.size)


if __name__ == '__main__':
    main(sys.argv[1])
