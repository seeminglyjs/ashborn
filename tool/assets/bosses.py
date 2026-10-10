"""지역 보스 다섯을 처음부터 그린다 (원본 없이, Endesga 32 팔레트 색만).

python -I tool/assets/bosses.py assets/images/sprites [이름 ...]

- 결과: enemies/boss_<이름>.png, 48x48 프레임 4장을 가로로 붙인 시트. 모두 오른쪽을 본다.
  크기와 이름은 lib/data/monster_sprites.dart 의 MonsterSprite 와 같아야 한다 (아래 BOSSES).
- 졸개 스프라이트(16 · 23 · 36 높이)보다 큰 판에 그려 실루엣이 한눈에 다르다. 게임에서는
  Boss 가 [Balance.bossSpriteSize] 로 더 크게 그린다.
- 그리는 법은 new_monsters.py 의 Canvas 를 그대로 쓴다: 몸을 타원 · 캡슐 · 다각형 조각으로 쌓고
  묶음마다 왼쪽 위 빛으로 3에서 4단계 명암, 1px #181425 외곽선. 어두운 몸에 작고 밝게 빛나는
  자리(눈 · 용암 균열 · 불꽃 · 번개 · 심장 핏줄)를 둬 어두운 바닥에서도 눈에 띄게 한다.
- 움직임 4프레임: 걷는 보스는 디딤(낮게 눌림) · 지나침(솟음)을 번갈아 몸 전체에 무게를 싣고,
  떠 있는 보스는 위아래로 일렁이며 촉수 · 날개 · 향로가 늦게 따라온다.
- 시트에는 'ashborn' 텍스트 표시를 남겨 monster_polish2.py 가 다시 칠하지 않게 한다.
"""
import math
import os
import sys

from PIL import Image
from PIL.PngImagePlugin import PngInfo

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from new_monsters import Canvas, H, OUTLINE, add, lerp, ramp, texture  # noqa: E402

FRAMES = 4
SIZE = 48

WHITE = H('ffffff')
YELLOW = H('fee761')
GOLD = H('feae34')
EMBER = H('f77622')
RED = H('e43b44')
DEEP = H('181425')


# ── 공통 도구 ────────────────────────────────────────────────────────

class BossCanvas(Canvas):
    """큰 덩어리용 명암을 더한 도화지.

    48칸 판에서는 가장자리 한두 칸 띠만 칠하는 Canvas 명암이 납작해 보인다. [vol] 로 고른 묶음은
    덩어리 안에서 빛 쪽(왼쪽 위) 가장자리까지와 반대쪽(오른쪽 아래) 가장자리까지의 거리 비로
    단계를 나눈다: 오른쪽 아래로 갈수록 어둡고, 왼쪽 위 가장자리 한 줄은 가장 밝게.
    가장자리를 빙 둘러 어둡게 하지 않으니 베개 명암이 생기지 않는다."""

    def __init__(self, w, h):
        super().__init__(w, h)
        self.vol = {}       # 묶음 -> 단계 경계 (밝기 비율)

    def volume(self, name, cuts=(0.2, 0.48, 0.8)):
        self.vol[name] = cuts

    def _run(self, x, y, dx, dy, g):
        n = 0
        while True:
            o = self.cell.get((x + dx * (n + 1), y + dy * (n + 1)))
            if o is None or o[1] != g:
                return n
            n += 1

    def index(self, x, y, c):
        z, g, rp, fixed, _ = c
        cuts = self.vol.get(g)
        if cuts is None or (fixed is not None and not isinstance(fixed, tuple)):
            return super().index(x, y, c)
        n = len(rp)
        lit = sum(self._run(x, y, dx, dy, g) for dx, dy in ((1, 1), (0, 1), (1, 0)))
        dark = sum(self._run(x, y, dx, dy, g) for dx, dy in ((-1, -1), (0, -1), (-1, 0)))
        t = lit / max(1, lit + dark)
        i = sum(1 for k in cuts if t >= k)
        i = min(n - 2, i) if n >= 4 else min(n - 1, i)
        # 빛 받는 윗면 · 왼쪽 위 가장자리 한 줄.
        if self._run(x, y, 0, -1, g) == 0 or (self._run(x, y, -1, -1, g) == 0 and self._run(x, y, -1, 0, g) == 0):
            i = n - 1 if t > 0.3 else max(i, n - 2)
        if isinstance(fixed, tuple):
            i = max(0, min(n - 1, i + fixed[1]))
        return i


def line_pts(p0, p1):
    """두 점 사이의 픽셀 (브레젠험)."""
    x0, y0 = int(round(p0[0])), int(round(p0[1]))
    x1, y1 = int(round(p1[0])), int(round(p1[1]))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return out
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def polyline(pts):
    out = []
    for a, b in zip(pts, pts[1:]):
        for p in line_pts(a, b):
            if not out or out[-1] != p:
                out.append(p)
    return out


def is_body(img, x, y):
    """외곽선이 아닌 몸 픽셀인가."""
    if not (0 <= x < img.width and 0 <= y < img.height):
        return False
    r, g, b, a = img.getpixel((x, y))
    return a > 0 and (r, g, b) != OUTLINE


def paint(img, pts, color, body_only=True):
    """렌더한 그림 위에 빛나는 점을 찍는다 (외곽선 없이). [body_only] 면 몸 안에만."""
    for x, y in pts:
        x, y = int(x), int(y)
        if not (0 <= x < img.width and 0 <= y < img.height):
            continue
        if body_only and not is_body(img, x, y):
            continue
        img.putpixel((x, y), color + (255,))


def glow_crack(img, pts, core=YELLOW, mid=GOLD, edge=EMBER):
    """용암 균열: 가운데 밝고 양 끝으로 식는 선. 아래 칸 하나를 어두운 불빛으로 받친다."""
    px = polyline(pts)
    n = len(px)
    for i, (x, y) in enumerate(px):
        t = abs(i - (n - 1) / 2) / max(1, (n - 1) / 2)
        color = core if t < 0.35 else mid if t < 0.75 else edge
        paint(img, [(x, y)], color)
        if t < 0.75 and is_body(img, x, y + 1) and (x, y + 1) not in px:
            paint(img, [(x, y + 1)], edge)


def flame_mask(tongues):
    """불꽃 혀 여러 개를 합친 마스크. 혀 = (밑 x, 밑 y, 높이, 반폭, 끝 흔들림)."""
    mask = set()
    for bx, by, h, w, sway in tongues:
        pts = [(bx - w, by), (bx - w * 0.55 + sway * 0.3, by - h * 0.45),
               (bx + sway, by - h), (bx + w * 0.45 + sway * 0.5, by - h * 0.5), (bx + w, by)]
        mask |= Canvas.poly_mask(pts)
        mask |= Canvas.ellipse_mask(bx, by - 0.5, w, w * 0.7)
    return mask


def depth_map(mask):
    """마스크 안쪽 깊이 (가장자리 0, 한 칸 들어갈 때마다 1)."""
    depth = {}
    frontier = {p for p in mask if any((p[0] + dx, p[1] + dy) not in mask
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    d = 0
    left = set(mask)
    while frontier:
        for p in frontier:
            depth[p] = d
        left -= frontier
        frontier = {p for p in left if any((p[0] + dx, p[1] + dy) in depth
                                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
        d += 1
    return depth


FIRE = ramp('a22633', 'e43b44', 'f77622', 'feae34', 'fee761', 'ffffff')


def put_fire(c, mask, z, group, hot=0):
    """불꽃: 가장자리는 검붉게, 속으로 갈수록 노랗고 하얗게 (빛 방향 명암 대신 깊이로 칠한다)."""
    depth = depth_map(mask)
    for (x, y), d in depth.items():
        i = min(len(FIRE) - 1, d + 1 + hot)
        if d == 0 and hot <= 0:
            i = 1 if (x + y) % 3 else 0
        c._put({(x, y)}, FIRE, z, group, line=False, fixed=i)


def embers(img, seeds, f, colors=(GOLD, EMBER, RED)):
    """위로 떠오르며 식는 불티. seeds = (x, 시작 y, 속도) — 프레임마다 위로 오른다."""
    for k, (x, y, v) in enumerate(seeds):
        yy = y - f * v
        color = colors[min(len(colors) - 1, int((y - yy) / 4))]
        paint(img, [(x + (f + k) % 2, yy)], color, body_only=False)


# ── 1. 잿더미 거인 (잿빛 평원) ─────────────────────────────────────────
# 어깨가 산처럼 솟은 거구. 숯처럼 검푸른 몸에 용암 균열과 잿불 눈, 머리 위로 휜 뼈 뿔 한 쌍,
# 땅에 닿을 듯 늘어진 두 주먹. 비스듬히 앞(오른쪽)을 보며 한 발씩 들어 내리찍듯 걷는다.

ASH = ramp('262b44', '3a4466', '5a6988', '8b9bb4')
ASH_FAR = ramp('181425', '262b44', '3a4466', '5a6988')
BONE = ramp('733e39', 'b86f50', 'e4a672', 'ead4aa')


def ash_giant(f):
    c = BossCanvas(SIZE, SIZE)
    dy = [1, -1, 1, -1][f]          # 디딤(0 · 2)에 눌리고, 발을 들면(1 · 3) 솟는다.
    sx = [0, -1, 0, 1][f]           # 디딘 발 쪽으로 무게를 싣는다.
    near_foot = [(32, 46), (33, 42), (31, 46), (31, 46)][f]
    far_foot = [(13, 46), (14, 46), (14, 46), (12, 42)][f]
    near_fist = [(39, 35), (38, 33), (39, 35), (40, 36)][f]
    far_fist = [(7, 35), (6, 36), (7, 35), (8, 33)][f]

    def leg(hip, foot, rp, z, g):
        knee = add(lerp(hip, foot, 0.5), (0.8 if g == 'leg' else -0.8, -0.5))
        c.capsule([hip, knee, foot], [4.6, 3.8, 3.0], rp, z, group=g)
        c.ellipse(foot[0] + (1.2 if g == 'leg' else -0.6), foot[1] - 0.8, 4.2, 2.1, rp, z + 0.1, group=g)
        c.volume(g)

    def arm(shoulder, fist, rp, z, g):
        side = 1 if fist[0] > shoulder[0] else -1
        elbow = (shoulder[0] + side * 3.5, (shoulder[1] + fist[1]) / 2 - 1)
        c.capsule([shoulder, elbow, fist], [3.6, 4.4, 4.6], rp, z, group=g)
        c.ellipse(fist[0] + side * 0.5, fist[1] + 0.5, 4.8, 4.2, rp, z, group=g)
        c.volume(g)
        return elbow

    leg((17 + sx, 33 + dy), far_foot, ASH_FAR, 0.5, 'farLeg')
    arm((12 + sx, 19 + dy), far_fist, ASH_FAR, 1, 'farArm')

    # 몸: 솟은 두 어깨 · 가슴 · 배를 한 덩어리로 칠한다.
    c.volume('body', cuts=(0.18, 0.45, 0.82))
    c.ellipse(13 + sx, 17 + dy, 7, 6, ASH, 2, group='body')
    c.ellipse(32 + sx, 17 + dy, 7.5, 6.5, ASH, 2, group='body')
    c.ellipse(22 + sx, 22 + dy, 11, 9, ASH, 2, group='body')
    c.ellipse(22 + sx, 30 + dy, 8.5, 6, ASH, 2, group='body')
    # 어깨의 바위 돌기.
    for (x, y, r) in ((9, 12, 2.4), (14, 10, 2.6), (31, 10, 2.6), (36, 12, 2.2)):
        c.poly([(x - r + sx, y + 3 + dy), (x - 0.6 + sx, y - r + dy), (x + r + sx, y + 3 + dy)], ASH, 2,
               group='body')
    texture(c, 'body', lambda x, y: (x * 3 + y * 5) % 13 == 0)

    leg((27 + sx, 33 + dy), near_foot, ASH, 3, 'leg')

    # 머리: 두 어깨 사이에 파묻혀 앞으로 내민 턱, 위로 휜 뼈 뿔 한 쌍.
    hx, hy = 25 + sx, 12 + dy
    c.capsule([(hx - 3, hy - 2), (hx - 6, hy - 4), (hx - 8, hy - 7), (hx - 9, hy - 9), (hx - 11, hy - 10)],
              [1.9, 1.6, 1.2, 0.8, 0.4], BONE[:3], 3.9, group='farHorn')
    c.volume('head')
    c.ellipse(hx, hy, 5, 4.6, ASH_FAR, 4, group='head')
    c.ellipse(hx + 1.5, hy + 3.5, 4.6, 2.6, ASH_FAR, 4, group='head')
    c.capsule([(hx + 3, hy - 2), (hx + 7, hy - 3), (hx + 10, hy - 6), (hx + 11, hy - 9), (hx + 13, hy - 10)],
              [2.1, 1.8, 1.3, 0.8, 0.4], BONE, 4.5, group='horn')
    for tx in (hx - 1.5, hx + 4):
        c.poly([(tx - 1, hy + 4), (tx, hy + 1), (tx + 1, hy + 4)], BONE[2:], 4.6, group='tusk')

    # 가까운 팔: 굵은 아래팔과 큰 주먹 (몸 앞).
    elbow = arm((33 + sx, 20 + dy), near_fist, ASH, 6, 'arm')
    img = c.render()

    # 눈두덩 그늘 아래 잿불 눈 둘, 입 속 불빛.
    paint(img, [(hx + d, hy - 2) for d in range(-3, 5)], DEEP)
    for ex in (hx - 2, hx + 2):
        paint(img, [(ex, hy - 1), (ex + 1, hy - 1)], YELLOW, body_only=False)
        paint(img, [(ex, hy)], EMBER, body_only=False)
    paint(img, [(hx - 1, hy + 2), (hx, hy + 2), (hx + 1, hy + 2), (hx + 2, hy + 2)], EMBER)
    paint(img, [(hx, hy + 2), (hx + 1, hy + 2)], GOLD)
    # 용암 균열: 가슴뼈 · 어깨 · 배 · 아래팔, 주먹 마디.
    glow_crack(img, [(22 + sx, 18 + dy), (21 + sx, 22 + dy), (23 + sx, 26 + dy), (22 + sx, 31 + dy)])
    glow_crack(img, [(21 + sx, 22 + dy), (17 + sx, 24 + dy), (15 + sx, 28 + dy)])
    glow_crack(img, [(10 + sx, 15 + dy), (13 + sx, 18 + dy), (16 + sx, 18 + dy)])
    glow_crack(img, [(33 + sx, 16 + dy), (36 + sx, 19 + dy)])
    glow_crack(img, [lerp(elbow, near_fist, 0.1), lerp(elbow, near_fist, 0.55)])
    glow_crack(img, [(near_fist[0] - 3, near_fist[1] - 1), (near_fist[0], near_fist[1] + 1),
                     (near_fist[0] + 2, near_fist[1] + 3)])
    # 어깨에서 피어오르는 불티.
    embers(img, [(9, 8, 2), (15, 6, 3), (34, 7, 2), (38, 10, 2)], f)
    return img


# ── 2. 가라앉은 사제 (가라앉은 성당) ───────────────────────────────────
# 물에 잠긴 성당의 사제가 떠다닌다. 두건 속 해골 얼굴에 시린 눈빛, 등 뒤의 부서진 후광,
# 창백한 촉수가 된 옷자락, 갈고리 지팡이에 매단 향로에서 차가운 빛이 흔들린다.

ROBE = ramp('262b44', '3a4466', '124e89', '0099db')
ROBE_FAR = ramp('181425', '262b44', '3a4466')
STOLE = ramp('733e39', 'b86f50', 'e4a672')
HALO = ramp('3a4466', '5a6988', '8b9bb4', 'c0cbdc')
TENT = ramp('262b44', '5a6988', '8b9bb4', 'c0cbdc')
WOOD = ramp('3e2731', '733e39', 'b86f50')
CYAN = H('2ce8f5')
PALE = H('c0cbdc')


def drowned_priest(f):
    c = BossCanvas(SIZE, SIZE)
    dy = [0, -1, -2, -1][f]
    lag = [1, 0, -1, 0][f]          # 촉수 · 향로가 몸보다 한 박자 늦게 따라온다.
    hx, hy = 23, 12 + dy

    # 후광: 머리 뒤 부서진 고리와 가시.
    ring = Canvas.ellipse_mask(hx - 1, hy, 10.5, 10.5) - Canvas.ellipse_mask(hx - 1, hy, 8.6, 8.6)
    ring = {p for p in ring if p[1] < hy + 3 and not (hx - 4 < p[0] < hx - 1 and p[1] < hy - 6)}
    c._put(ring, HALO, 0, 'halo')
    for a in (-2.6, -2.0, -1.2, -0.5, 0.1):
        x0, y0 = hx - 1 + math.cos(a) * 10, hy + math.sin(a) * 10
        x1, y1 = hx - 1 + math.cos(a) * 13.5, hy + math.sin(a) * 13.5
        c.capsule([(x0, y0), (x1, y1)], [1.0, 0.3], HALO, 0, group='halo')

    # 먼 소매: 등 뒤로 늘어뜨린 팔과 뼈 손.
    c.capsule([(18, 18 + dy), (13, 25 + dy), (11, 30 + dy)], [2.4, 2.6, 3.0], ROBE_FAR, 1, group='farSleeve')

    # 촉수: 옷자락 아래로 늘어져 물결치고 끝이 말린다.
    for k, (x, ln, ph) in enumerate(((14, 9, 0.0), (19, 11, 1.4), (25, 12, 2.6), (30, 9, 0.8))):
        pts, radii = [], []
        for i in range(8):
            t = i / 7
            wob = math.sin(ph + t * 3.4 + f * math.pi / 2) * (0.5 + 2.2 * t)
            pts.append((x + wob - t * 2 + lag * t, 33 + dy + t * ln))
            radii.append(2.4 - 1.9 * t)
        end = pts[-1]
        curl = 1 if k % 2 else -1
        pts.append((end[0] + curl * 1.5, end[1] + 0.5))
        pts.append((end[0] + curl * 2, end[1] - 1))
        radii += [0.5, 0.4]
        c.capsule(pts, radii, TENT, 2 + k * 0.01, group='tent%d' % k)

    # 사제복: 어깨에서 넓게 퍼지는 자락, 끝이 해져 갈라진다.
    c.volume('robe', cuts=(0.18, 0.42, 0.85))
    hem = 35 + dy
    c.poly([(18, 16 + dy), (28, 16 + dy), (32, 25 + dy), (34, hem), (31, hem - 2), (28, hem + 1), (25, hem - 1),
            (21, hem + 1), (18, hem - 1), (14, hem + 0.5), (12, hem - 2), (15, 25 + dy)], ROBE, 3, group='robe')
    # 두건: 둥근 머리에 뒤로 처진 고깔.
    c.ellipse(hx, hy, 6.5, 7, ROBE, 3, group='robe')
    c.poly([(hx - 5, hy - 3), (hx - 10, hy + 4), (hx - 4, hy + 6)], ROBE, 3, group='robe')
    # 영대: 앞자락에 늘어진 빛바랜 금실 띠.
    c.recolor('robe', lambda x, y, rp: STOLE if 27 <= x <= 28 and y > 18 + dy + (x - 27) else rp)
    texture(c, 'robe', lambda x, y: x < 25 and (x + y) % 5 == 0 and y > 22 + dy)
    # 얼굴 구멍.
    c._put(Canvas.ellipse_mask(hx + 3, hy + 1, 3.2, 4), [DEEP], 4, 'face', line=False, fixed=0)

    # 지팡이: 썩은 나무 갈고리 + 매달린 향로.
    sx = 38
    c.capsule([(sx, 6 + dy), (sx, 44 + dy)], [0.9, 0.9], WOOD, 5, group='staff')
    c.capsule([(sx, 7 + dy), (sx + 1, 3 + dy), (sx + 4, 2 + dy), (sx + 6, 4 + dy), (sx + 6, 6 + dy)],
              [1.0, 1.0, 1.0, 0.9, 0.7], WOOD, 5, group='staff')
    cx, cy = sx + 6 + lag, 12 + dy
    c.ellipse(cx, cy, 2.8, 2.4, HALO, 6, group='censer')
    c.poly([(cx - 1.5, cy - 2), (cx, cy - 4), (cx + 1.5, cy - 2)], HALO, 6, group='censer')
    # 가까운 소매가 지팡이를 쥔다.
    c.capsule([(25, 18 + dy), (31, 23 + dy), (sx - 1, 22 + dy)], [2.6, 2.6, 2.4], ROBE, 7, group='sleeve')
    img = c.render()

    # 해골 얼굴: 눈빛 둘, 이 몇 개.
    paint(img, [(hx + 2, hy), (hx + 4, hy)], CYAN, body_only=False)
    paint(img, [(hx + 4, hy - 1)], WHITE, body_only=False)
    paint(img, [(hx + 2, hy + 3), (hx + 4, hy + 3), (hx + 5, hy + 2)], PALE, body_only=False)
    paint(img, [(sx + 1, 21 + dy), (sx + 1, 23 + dy)], PALE)     # 뼈 손가락
    paint(img, [(10, 31 + dy), (11, 32 + dy), (12, 31 + dy)], PALE, body_only=False)
    # 향로 빛과 사슬.
    paint(img, polyline([(sx + 6, 7 + dy), (cx, cy - 4)]), HALO[1], body_only=False)
    paint(img, [(cx, cy), (cx - 1, cy), (cx, cy + 1)], CYAN, body_only=False)
    paint(img, [(cx - 1, cy - 1)], WHITE, body_only=False)
    for k, (ox, oy) in enumerate(((-1, 4), (1, 6), (0, 8))):
        if (k + f) % 2 == 0:
            paint(img, [(cx + ox, cy + oy - f % 2)], CYAN if k else WHITE, body_only=False)
    # 위로 오르는 물방울.
    for k, (x, y) in enumerate(((8, 30), (33, 18), (5, 20))):
        yy = y - (f * 3 + k * 5) % 12
        paint(img, [(x, yy)], PALE if k % 2 else HALO[1], body_only=False)
    return img


# ── 3. 불타는 수호목 (불타는 숲) ──────────────────────────────────────
# 불붙은 숲을 지키던 고목. 굵은 몸통에 화로처럼 빛나는 가슴 구멍, 머리 위 가지마다 타오르는
# 불꽃 갈기, 불길에 휩싸인 가지 주먹. 뿌리 다리로 무겁게 걷는다.

BARK = ramp('3e2731', '733e39', 'b86f50', 'c28569')
BARK_FAR = ramp('181425', '3e2731', '733e39')
CHAR = ramp('181425', '3e2731', '733e39', 'b86f50')


def burning_treant(f):
    c = BossCanvas(SIZE, SIZE)
    dy = [1, 0, 1, 0][f]
    sway = [1, 0, -1, 0][f]
    near_foot, far_foot = [((32, 46), (13, 46)), ((26, 44), (19, 46)),
                           ((16, 46), (29, 46)), ((21, 46), (25, 44))][f]
    near_hand = [(38, 34), (39, 31), (40, 28), (39, 31)][f]

    def root_leg(hip, foot, rp, z, g):
        knee = add(lerp(hip, foot, 0.5), (0.5, 0))
        c.capsule([hip, knee, foot], [4.0, 3.2, 2.4], rp, z, group=g)
        for ox, oy in ((-3.2, 0.3), (3.4, 0.2), (0.4, 0.6)):
            c.capsule([foot, add(foot, (ox, oy))], [1.3, 0.6], rp, z, group=g)
        c.volume(g)

    # 먼 가지 팔 (뒤): 위로 치켜든 가지 끝에도 불이 붙었다.
    c.capsule([(16, 20 + dy), (10, 25 + dy), (7, 31 + dy)], [2.8, 2.4, 2.0], BARK_FAR, 0, group='farArm')
    for ox, oy in ((-2, 3), (0, 4), (2, 3)):
        c.capsule([(7, 31 + dy), (7 + ox, 31 + oy + dy)], [1.0, 0.5], BARK_FAR, 0, group='farArm')
    root_leg((18, 38 + dy), far_foot, BARK_FAR, 0.5, 'farLeg')

    # 머리 위 불꽃 갈기 (몸통 뒤).
    blaze = flame_mask([(13, 13 + dy, 10 + f % 2 * 2, 3, -2 + sway), (19, 10 + dy, 9 - f % 2, 3.2, sway),
                        (25, 10 + dy, 8 + (f + 1) % 2 * 2, 3, 1 + sway), (30, 13 + dy, 7 + f % 2, 2.6, 2 + sway),
                        (9, 18 + dy, 6 + (f + 1) % 2, 2.2, -2 + sway)])
    put_fire(c, blaze, 1, 'blaze')

    # 몸통: 아래로 넓게 퍼진 고목, 꼭대기는 검게 그을렸다.
    c.volume('bark', cuts=(0.2, 0.45, 0.82))
    c.poly([(13, 40 + dy), (15, 30 + dy), (14, 20 + dy), (17, 13 + dy), (23, 11 + dy), (29, 13 + dy),
            (33, 20 + dy), (32, 30 + dy), (34, 40 + dy)], BARK, 2, group='bark')
    for x0, x1 in ((15, 20), (22, 27)):
        c.poly([(x0, 12 + dy), (x0 + 1, 6 + dy), (x1, 12 + dy)], BARK, 2, group='bark')
    c.recolor('bark', lambda x, y, rp: CHAR if y < 15 + dy + (x % 3) else rp)
    texture(c, 'bark', lambda x, y: x % 4 == 1 and (y + x) % 7 != 0 and y > 16 + dy)
    root_leg((27, 38 + dy), near_foot, BARK, 3, 'leg')

    # 가슴 화로: 갈라진 구멍 안에서 이글거리는 불씨 덩어리.
    core = Canvas.ellipse_mask(24, 28 + dy, 3.6, 4.6) | Canvas.poly_mask(
        [(22, 25 + dy), (24, 20 + dy), (26, 25 + dy)])
    put_fire(c, core, 4, 'core', hot=1 + f % 2)

    # 가까운 가지 팔과 불붙은 주먹.
    c.volume('arm')
    c.capsule([(29, 24 + dy), (34, 27 + dy), near_hand], [3.2, 2.8, 2.6], BARK, 5, group='arm')
    hx, hy = near_hand
    for ox, oy in ((3, -2), (3.5, 1), (1.5, 3)):
        c.capsule([near_hand, (hx + ox, hy + oy)], [1.4, 0.6], BARK, 5, group='arm')
    fist = flame_mask([(hx + 1, hy - 1, 8 + f % 2 * 2, 2.8, -1 - sway), (hx + 4, hy, 6, 2.2, sway)])
    put_fire(c, fist - c.capsule_mask([(29, 24 + dy), (34, 27 + dy), near_hand], [3.2, 2.8, 2.6]), 6, 'fist')
    img = c.render()

    # 얼굴: 움푹 팬 눈과 입 속 불빛.
    for ex in (26, 30):
        paint(img, [(ex - 1, 16 + dy), (ex, 16 + dy), (ex + 1, 16 + dy), (ex, 15 + dy)], DEEP)
        paint(img, [(ex, 17 + dy), (ex - 1, 17 + dy)], DEEP)
        paint(img, [(ex, 16 + dy)], YELLOW, body_only=False)
        paint(img, [(ex - 1, 16 + dy)], GOLD, body_only=False)
    mouth = [(25, 20), (26, 21), (27, 20), (28, 21), (29, 20), (30, 21), (31, 20)]
    paint(img, [(x, y + dy) for x, y in mouth] + [(x, y + 1 + dy) for x, y in mouth[1:-1]], DEEP)
    paint(img, [(x, 21 + dy) for x in range(27, 30)], EMBER, body_only=False)
    paint(img, [(28, 21 + dy)], GOLD, body_only=False)
    # 줄기를 타고 내려가는 불 균열.
    glow_crack(img, [(19, 18 + dy), (18, 24 + dy), (20, 30 + dy), (18, 36 + dy)])
    glow_crack(img, [(29, 32 + dy), (28, 37 + dy)])
    embers(img, [(16, 2, 2), (24, 3, 3), (11, 6, 2), (30, 5, 2), (20, 1, 1)], f)
    return img


# ── 4. 녹슨 기사단장 (녹슨 요새) ──────────────────────────────────────
# 녹슨 판금을 두른 거구의 기사. 크게 솟은 어깨받이, 눈구멍에서 번쩍이는 번개빛, 해진 망토,
# 몸보다 긴 대검을 앞으로 비스듬히 치켜들었고 칼날을 따라 번개가 튄다.

STEEL = ramp('262b44', '3a4466', '5a6988', '8b9bb4')
STEEL_FAR = ramp('181425', '262b44', '3a4466')
RUST = ramp('3e2731', '733e39', 'b86f50', 'c28569')
BLADE = ramp('3a4466', '8b9bb4', 'c0cbdc', 'ffffff')
CAPE = ramp('181425', '3e2731', '68386c', 'b55088')
PLUME = ramp('a22633', 'e43b44', 'f6757a')
TRIM = H('e4a672')


def _hash(x, y):
    n = (x * 374761393 + y * 668265263) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return (n & 0xffff) / 0xffff


def noise(x, y, cell=4):
    """칸 [cell] 크기의 값 잡음 (0에서 1). 얼룩이 둥글게 뭉친다."""
    gx, gy = x / cell, y / cell
    x0, y0 = int(gx), int(gy)
    tx, ty = gx - x0, gy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = _hash(x0, y0) * (1 - tx) + _hash(x0 + 1, y0) * tx
    b = _hash(x0, y0 + 1) * (1 - tx) + _hash(x0 + 1, y0 + 1) * tx
    return a * (1 - ty) + b * ty


def rusty(x, y, rp):
    """판금 위 녹 얼룩: 값 잡음으로 둥글게 뭉친 반점."""
    return RUST if noise(x, y, 3) > 0.7 else rp


def rust_knight(f):
    c = BossCanvas(SIZE, SIZE)
    dy = [1, 0, 1, 0][f]
    wave = [0, 1, 2, 1][f]
    near_foot, far_foot = [((30, 46), (13, 46)), ((25, 44), (18, 46)),
                           ((15, 46), (28, 46)), ((20, 46), (25, 44))][f]
    tilt = [0.0, -0.04, 0.0, 0.04][f]

    # 망토: 어깨에서 뒤로 휘날리고 끝이 해졌다.
    c.group('cape', shadow=2)
    hem = [(3 - wave, 41), (6, 37), (8 - wave * 0.5, 43), (11, 39), (13, 44), (16, 40)]
    c.poly([(20, 14 + dy), (14, 15 + dy), (7 - wave * 0.5, 26 + dy)] + [(x, y + dy) for x, y in hem] +
           [(20, 36 + dy)], CAPE, 0, group='cape')
    texture(c, 'cape', lambda x, y: x % 3 == 0 and y > 22 + dy)

    def leg(hip, foot, rp, z, g):
        knee = add(lerp(hip, foot, 0.5), (1.4, -0.4))
        c.capsule([hip, knee, foot], [3.4, 2.8, 2.6], rp, z, group=g)
        c.ellipse(foot[0] + 1.6, foot[1] - 0.8, 3.8, 1.8, rp, z + 0.1, group=g)
        c.ellipse(knee[0] + 0.6, knee[1], 2.5, 2.3, rp, z + 0.2, group=g + 'Knee')
        c.volume(g)

    leg((19, 34 + dy), far_foot, STEEL_FAR, 1, 'farLeg')
    c.ellipse(16, 17 + dy, 5, 4, STEEL_FAR, 1.5, group='farPauldron')
    # 칼자루 쪽으로 뻗은 먼 팔 (몸 뒤).
    grip = (34, 30 + dy)
    c.capsule([(18, 21 + dy), (24, 29 + dy), grip], [2.4, 2.4, 2.2], STEEL_FAR, 1.8, group='farArm')

    # 몸통: 가슴판과 허리 비늘판.
    c.volume('armor', cuts=(0.18, 0.45, 0.8))
    c.ellipse(22, 24 + dy, 8, 8.5, STEEL, 2, group='armor')
    c.poly([(14, 29 + dy), (29, 29 + dy), (31, 37 + dy), (13, 37 + dy)], STEEL, 2, group='armor')
    texture(c, 'armor', lambda x, y: y in (31 + dy, 34 + dy) or (x == 23 and 17 + dy < y < 29 + dy))
    c.recolor('armor', rusty)
    leg((25, 34 + dy), near_foot, STEEL, 3, 'leg')

    # 투구: 큰 통투구, 뒤로 흘러내리는 붉은 깃털 장식.
    hx, hy = 24, 11 + dy
    c.capsule([(hx - 1, hy - 5), (hx - 5, hy - 7), (hx - 10, hy - 5), (hx - 13, hy - 1 + wave * 0.5)],
              [1.8, 2.1, 1.7, 0.8], PLUME, 4, group='plume')
    c.volume('helm')
    c.ellipse(hx, hy, 5, 5.5, STEEL, 5, group='helm')
    c.poly([(hx - 4, hy + 2), (hx + 5, hy + 1), (hx + 5, hy + 6), (hx - 3, hy + 6)], STEEL, 5, group='helm')
    # 가까운 어깨받이: 겹친 판 둘, 위로 솟은 가시.
    c.volume('pauldron')
    c.ellipse(28, 17 + dy, 7, 5, STEEL, 6, group='pauldron')
    c.recolor('pauldron', rusty)
    c.volume('pauldron2')
    c.ellipse(29, 21 + dy, 5.5, 3.2, STEEL, 6.1, group='pauldron2')
    c.poly([(27, 13 + dy), (30, 7 + dy), (30.5, 13 + dy)], STEEL, 6.2, group='spike')
    c.poly([(31, 14 + dy), (35.5, 10 + dy), (34, 16 + dy)], STEEL, 6.2, group='spike')

    # 대검: 칼자루는 앞에서 두 손으로 쥐고, 칼날은 앞 위로 비스듬히.
    ang = -1.12 + tilt
    ux, uy = math.cos(ang), math.sin(ang)
    base = (grip[0] + ux * 2.5, grip[1] + uy * 2.5)
    tip = (grip[0] + ux * 27, grip[1] + uy * 27)
    c.capsule([(grip[0] - ux * 3.5, grip[1] - uy * 3.5), base], [1.0, 1.0], WOOD, 7, group='hilt')
    c.capsule([(base[0] - uy * 4, base[1] + ux * 4), (base[0] + uy * 4, base[1] - ux * 4)], [1.1, 1.1],
              RUST, 8, group='guard')
    c.capsule([base, lerp(base, tip, 0.8), tip], [2.3, 1.9, 0.4], BLADE, 8, group='blade')
    # 가까운 팔: 어깨에서 팔꿈치로 내려와 앞으로 꺾여 칼자루를 감싼다.
    c.volume('arm')
    c.capsule([(29, 22 + dy), (28, 28 + dy), (grip[0] + 0.5, grip[1] - 0.5)], [2.8, 2.6, 2.6], STEEL, 9,
              group='arm')
    c.ellipse(grip[0] + 1, grip[1] - 0.5, 2.8, 2.5, STEEL, 9.1, group='gauntlet')
    img = c.render()

    # 눈구멍의 번개빛.
    paint(img, [(hx + d, hy) for d in range(0, 6)] + [(hx + 3, hy + 1), (hx + 3, hy + 2)], DEEP)
    paint(img, [(hx + d, hy) for d in range(2, 5)], YELLOW, body_only=False)
    paint(img, [(hx + 4, hy)], WHITE, body_only=False)
    paint(img, [(hx + 3, hy + 1)], GOLD, body_only=False)
    # 어깨받이 아래 가장자리의 바랜 금 테.
    for x in range(23, 35):
        for y in range(18 + dy, 24 + dy):
            if is_body(img, x, y) and not is_body(img, x, y + 1) and abs(x - 28) < 6:
                paint(img, [(x, y - 1)], TRIM)
                break
    # 칼날을 타고 오르는 번개: 프레임마다 다른 지그재그.
    zig = []
    for k in range(7):
        t = 0.15 + k * 0.13
        p = lerp(base, tip, t)
        side = (1 if (k + f) % 2 else -1) * (1.5 + (k * 7 + f * 3) % 3 * 0.6)
        zig.append((p[0] - uy * side, p[1] + ux * side))
    paint(img, polyline(zig), YELLOW, body_only=False)
    for k, (x, y) in enumerate(zig):
        if (k + f) % 3 == 0:
            paint(img, [(x, y)], WHITE, body_only=False)
    # 튀는 불꽃 두셋.
    for k in range(3):
        p = lerp(base, tip, 0.3 + ((f * 5 + k * 3) % 7) / 10)
        off = 4 + (f + k) % 3
        paint(img, [(p[0] + off * (1 if k % 2 else -1) * 0.7, p[1] - off * 0.5)], YELLOW if k else WHITE,
              body_only=False)
    return img


# ── 5. 꺼지지 않는 심장 (꺼지지 않는 심장) ─────────────────────────────
# 멈추지 않고 뛰는 거대한 악마 심장. 가운데 노란 외눈, 위로 솟은 굵은 혈관, 박쥐 날개,
# 아래로 늘어진 핏줄 촉수. 수축(작고 단단) · 이완(크게 부풂)을 되풀이하며 핏줄이 번쩍인다.

FLESH = ramp('3e2731', 'a22633', 'e43b44', 'f6757a')
FLESH_DARK = ramp('181425', '3e2731', 'a22633')
VESSEL = ramp('3e2731', '68386c', 'b55088')
WING = ramp('262b44', '3e2731', '68386c', 'b55088')
WBONE = ramp('181425', '3e2731', '733e39', 'c28569')
SCLERA = ramp('f77622', 'feae34', 'fee761')
HOT = H('ff0044')


def undying_heart(f):
    c = BossCanvas(SIZE, SIZE)
    dy = [0, -1, -2, -1][f]
    beat = [1.0, 0.9, 1.1, 1.0][f]      # 수축 → 크게 이완 → 돌아옴.
    flap = [0, -7, 5, -2][f]             # 날개: 가운데 → 위 → 아래 → 가운데.
    cx, cy = 24, 25 + dy

    def wing(root, side, z):
        tipx = root[0] + side * 20
        tipy = root[1] - 12 + flap
        elbow = (root[0] + side * 9, root[1] - 10 + flap * 0.5)
        fingers = [(root[0] + side * 17, root[1] + 1 + flap * 0.6),
                   (root[0] + side * 12, root[1] + 6 + flap * 0.3),
                   (root[0] + side * 6, root[1] + 7)]
        pts = [root, elbow, (tipx, tipy)]
        prev = (tipx, tipy)
        for fx_, fy_ in fingers:
            mid = lerp(prev, (fx_, fy_), 0.5)
            pts += [(mid[0] - side * 1.2, mid[1] - 2.2), (fx_, fy_)]
            prev = (fx_, fy_)
        c.poly(pts + [(root[0], root[1] + 4)], WING, z, group='wing%d' % side)
        c.capsule([root, elbow, (tipx, tipy)], [1.5, 1.1, 0.5], WBONE, z + 0.1, group='wbone%d' % side)
        for fx_, fy_ in fingers:
            c.capsule([elbow, (fx_, fy_)], [0.7, 0.4], WBONE[:3], z + 0.1, group='wbone%d' % side)
        c.poly([(elbow[0] - 1, elbow[1]), (elbow[0] + side * 1, elbow[1] - 4), (elbow[0] + 1, elbow[1])],
               WBONE, z + 0.2, group='claw%d' % side)

    wing((cx - 6, cy - 5), -1, 0)
    wing((cx + 5, cy - 5), 1, 0)

    # 위로 솟은 굵은 혈관 둘 (대동맥처럼 끝이 뚫렸다).
    tubes = (([(cx - 3, cy - 6), (cx - 4, cy - 12), (cx - 4, cy - 16)], 2.6),
             ([(cx + 4, cy - 6), (cx + 5.5, cy - 10), (cx + 6, cy - 13)], 2.1))
    for k, (pts, r) in enumerate(tubes):
        c.capsule(pts, [r] * len(pts), VESSEL, 1, group='vessel%d' % k)
        c.volume('vessel%d' % k)

    # 핏줄 촉수: 아래로 늘어져 흔들린다.
    for k, (x, ln, ph) in enumerate(((cx - 5, 10, 0.4), (cx, 12, 1.6), (cx + 5, 9, 2.8))):
        pts, radii = [], []
        for i in range(6):
            t = i / 5
            wob = math.sin(ph + t * 3 + f * math.pi / 2) * (0.5 + 2 * t)
            pts.append((x + wob, cy + 7 + t * ln))
            radii.append(1.9 - 1.4 * t)
        c.capsule(pts, radii, FLESH_DARK, 1.5, group='tendril%d' % k)

    # 심장: 위 두 덩이와 아래로 모이는 끝. 뛸 때마다 크기가 바뀐다.
    c.volume('heart', cuts=(0.15, 0.4, 0.8))
    c.ellipse(cx - 4 * beat, cy - 2, 7.5 * beat, 7 * beat, FLESH, 2, group='heart')
    c.ellipse(cx + 4 * beat, cy - 1, 7 * beat, 6.5 * beat, FLESH, 2, group='heart')
    c.poly([(cx - 10.5 * beat, cy + 1), (cx + 10.5 * beat, cy + 1), (cx + 1, cy + 11 * beat)], FLESH, 2,
           group='heart')
    texture(c, 'heart', lambda x, y: (x * 2 + y * 3) % 11 == 0)

    # 외눈: 노란 흰자에 세로로 찢어진 눈동자, 오른쪽(앞)을 노린다.
    ex, ey = cx + 2, cy + 1
    c._put(Canvas.ellipse_mask(ex, ey, 4.6 * beat, 3.6 * beat), FLESH_DARK, 3, 'lid', line=False, fixed=0)
    eye = Canvas.ellipse_mask(ex, ey, 3.5 * beat, 2.6 * beat)
    depth = depth_map(eye)
    for (x, y), d in depth.items():
        c._put({(x, y)}, SCLERA, 4, 'eye', line=False, fixed=min(2, d + (1 if y < ey else 0)))
    img = c.render()

    px = int(ex + 1)
    paint(img, [(px, int(ey) - 1), (px, int(ey)), (px, int(ey) + 1)], DEEP, body_only=False)
    paint(img, [(px - 2, int(ey) - 1)], WHITE, body_only=False)
    # 혈관 끝의 뚫린 구멍에서 끓는 핏빛.
    for (pts, r) in tubes:
        ox, oy = pts[-1]
        rim = Canvas.ellipse_mask(ox, oy - 0.5, r + 0.3, r * 0.6 + 0.3)
        hole = Canvas.ellipse_mask(ox, oy - 0.5, r - 0.7, r * 0.6 - 0.4)
        paint(img, rim - hole, VESSEL[2], body_only=False)
        paint(img, hole, RED, body_only=False)
        paint(img, [(int(ox), int(oy) - 1)], HOT, body_only=False)
    # 박동하는 핏줄: 크게 뛸 때 번쩍인다.
    veins = [[(cx - 9, cy - 4), (cx - 7, cy + 1), (cx - 4, cy + 4), (cx - 1, cy + 8)],
             [(cx + 9, cy - 5), (cx + 8, cy), (cx + 6, cy + 5)],
             [(cx - 4, cy - 8), (cx - 3, cy - 4)]]
    for v in veins:
        paint(img, polyline(v), HOT if f == 2 else FLESH[1])
    # 떨어지는 핏방울.
    for k, (x, y0) in enumerate(((cx - 5, 38), (cx + 5, 36))):
        y = y0 + dy + (f + k * 2) % 4 * 2
        paint(img, [(x + k, y)], RED if (f + k) % 2 else FLESH[1], body_only=False)
    return img


BOSSES = {
    'boss_ash_giant': ash_giant,
    'boss_drowned_priest': drowned_priest,
    'boss_burning_treant': burning_treant,
    'boss_rust_knight': rust_knight,
    'boss_undying_heart': undying_heart,
}


def main(out):
    enemies = os.path.join(out, 'enemies')
    os.makedirs(enemies, exist_ok=True)
    only = sys.argv[2:]
    for name, draw in BOSSES.items():
        if only and name not in only:
            continue
        sheet = Image.new('RGBA', (SIZE * FRAMES, SIZE))
        for f in range(FRAMES):
            img = draw(f)
            assert img.size == (SIZE, SIZE), (name, img.size)
            sheet.paste(img, (f * SIZE, 0))
        info = PngInfo()
        info.add_text('ashborn', 'bosses')
        sheet.save(os.path.join(enemies, f'{name}.png'), pnginfo=info, optimize=True)
        print(name, sheet.size)


if __name__ == '__main__':
    main(sys.argv[1])
