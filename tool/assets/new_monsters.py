"""새 몬스터 7종을 처음부터 그린다 (원본 없이, Endesga 32 팔레트 색만).

python -I tool/assets/new_monsters.py assets/images/sprites

- 결과: enemies/<이름>.png, 걷기(날기) 4프레임을 가로로 붙인 시트. 모두 오른쪽을 본다.
- 크기와 이름은 lib/data/monster_sprites.dart 의 MonsterSprite 와 같아야 한다 (아래 MONSTERS).
- 그리는 법: 몸을 타원 · 굵은 선(캡슐) · 다각형 조각으로 쌓고, 조각마다 왼쪽 위 빛으로
  3에서 4단계 명암을 칠한다 (어두운 단계는 차가운 색, 밝은 단계는 따뜻한 색인 재질 램프).
  앞 조각에 가려지는 뒤 조각 가장자리는 가장 어두운 색으로 그어 겹침을 읽히게 하고,
  바깥 둘레에는 1px #181425 외곽선을 두른다.
- 움직임: 큰 짐승은 몸이 발걸음에 실려 앞뒤로 기울고(무게 이동), 날짐승은 위 · 가운데 · 아래 ·
  가운데로 날개를 치며 내려칠 때 몸이 떠오른다. 식충 꽃은 몸을 뒤로 뺐다(예비 동작) 입을 크게
  벌리며 앞으로 덤빈다. 전갈은 꼬리를 들었다 찌른다.
- 시트에는 'ashborn' 텍스트 표시를 남겨 monster_polish2.py 가 다시 칠하지 않게 한다.
"""
import math
import os
import sys

from PIL import Image
from PIL.PngImagePlugin import PngInfo

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import PALETTE  # noqa: E402

FRAMES = 4
OUTLINE = (0x18, 0x14, 0x25)


def H(code):
    c = tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))
    assert c in PALETTE, code
    return c


def ramp(*codes):
    return [H(c) for c in codes]


class Canvas:
    """z 버퍼에 조각을 쌓는 작은 도화지.

    조각은 모양(마스크)만 정하고, 명암은 다 쌓은 뒤 묶음(group)마다 실루엣을 기준으로 칠한다:
    빛(왼쪽 위) 쪽 가장자리는 밝게, 반대쪽 [shadow] 칸 띠는 한 단계 어둡게, 맨 아래 가장자리는
    가장 어둡게. 같은 묶음의 조각끼리는 한 덩어리로 칠해져 이음매가 생기지 않는다."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.cell = {}      # (x, y) -> [z, 묶음, 램프, 고정 단계 또는 None, 겹침 선]
        self.style = {}     # 묶음 -> (그림자 띠 두께, 밝은 띠 두께)
        self.parts = 0

    def group(self, name, shadow=1, light=1):
        self.style[name] = (shadow, light)

    def _put(self, mask, rp, z, group, line=True, fixed=None):
        self.parts += 1
        group = group if group is not None else 'part%d' % self.parts
        for x, y in mask:
            if not (0 <= x < self.w and 0 <= y < self.h):
                continue
            old = self.cell.get((x, y))
            if old is None or z >= old[0]:
                self.cell[(x, y)] = [z, group, rp, fixed, line]
        return group

    # ── 모양 ──────────────────────────────────────────────────────────
    @staticmethod
    def ellipse_mask(cx, cy, rx, ry, angle=0.0):
        ca, sa = math.cos(angle), math.sin(angle)
        r = int(max(rx, ry)) + 2
        out = set()
        for y in range(int(cy) - r, int(cy) + r + 1):
            for x in range(int(cx) - r, int(cx) + r + 1):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                u = (dx * ca + dy * sa) / rx
                v = (-dx * sa + dy * ca) / ry
                if u * u + v * v <= 1:
                    out.add((x, y))
        return out

    def ellipse(self, cx, cy, rx, ry, rp, z, angle=0.0, group=None, line=True):
        return self._put(self.ellipse_mask(cx, cy, rx, ry, angle), rp, z, group, line)

    @staticmethod
    def capsule_mask(pts, radii):
        out = set()
        for k in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[k], pts[k + 1]
            r0, r1 = radii[k], radii[k + 1]
            lx, ly = x1 - x0, y1 - y0
            ll = lx * lx + ly * ly or 1e-6
            rmax = max(r0, r1) + 1
            for y in range(int(min(y0, y1) - rmax), int(max(y0, y1) + rmax) + 1):
                for x in range(int(min(x0, x1) - rmax), int(max(x0, x1) + rmax) + 1):
                    px_, py_ = x + 0.5, y + 0.5
                    t = max(0.0, min(1.0, ((px_ - x0) * lx + (py_ - y0) * ly) / ll))
                    if math.hypot(px_ - x0 - lx * t, py_ - y0 - ly * t) <= r0 + (r1 - r0) * t:
                        out.add((x, y))
        return out

    def capsule(self, pts, radii, rp, z, group=None, line=True):
        """[pts] 를 잇는 굵은 선. [radii] 는 점마다 반지름 (사이는 보간)."""
        return self._put(self.capsule_mask(pts, radii), rp, z, group, line)

    @staticmethod
    def poly_mask(pts):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return {(x, y) for y in range(int(min(ys)) - 1, int(max(ys)) + 2)
                for x in range(int(min(xs)) - 1, int(max(xs)) + 2) if _inside(x + 0.5, y + 0.5, pts)}

    def poly(self, pts, rp, z, group=None, line=True):
        return self._put(self.poly_mask(pts), rp, z, group, line)

    def dot(self, x, y, color, z=99):
        return self._put({(int(x), int(y))}, [color], z, '-dot', False, 0)

    def erase(self, pixels):
        for p in pixels:
            self.cell.pop(p, None)

    def recolor(self, group, fn):
        """묶음 [group] 의 픽셀 램프를 fn(x, y, 램프) -> 램프 로 바꾼다 (배 비늘 같은 무늬)."""
        for (x, y), c in self.cell.items():
            if c[1] == group:
                c[2] = fn(x, y, c[2])

    def shade(self, x, y, offset=0):
        """(x, y) 를 한 단계 어둡게(음수) · 밝게(양수) 고정한다 (마디 · 무늬)."""
        c = self.cell.get((x, y))
        if c:
            c[3] = ('rel', offset)

    # ── 마무리 ────────────────────────────────────────────────────────
    def index(self, x, y, c):
        z, g, rp, fixed, _ = c
        n = len(rp)
        if fixed is not None and not isinstance(fixed, tuple):
            return fixed
        shadow, light = self.style.get(g, (1, 1))

        def out(px, py):
            o = self.cell.get((px, py))
            return o is None or o[1] != g

        m = max(0, n - 2)
        i = m
        top = out(x, y - 1)
        if top or any(out(x - d, y - d) for d in range(1, light + 1)) and out(x - 1, y):
            i = n - 1
        elif out(x, y + 1) and n >= 4:
            i = 0
        elif out(x, y + 1) or out(x + 1, y) or any(out(x + d, y + d) for d in range(1, shadow + 1)):
            i = max(0, m - 1)
        if isinstance(fixed, tuple):
            i = max(0, min(n - 1, i + fixed[1]))
        return i

    def render(self):
        img = Image.new('RGBA', (self.w, self.h))
        px = img.load()
        for (x, y), c in self.cell.items():
            z, g, rp, fixed, line = c
            color = rp[self.index(x, y, c)]
            if line:
                # 앞 묶음에 가려지는 가장자리: 가장 어두운 색으로 겹침 선.
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    o = self.cell.get((x + dx, y + dy))
                    if o and o[0] > z and o[1] != g and o[1] != '-dot':
                        color = rp[0]
                        break
            px[x, y] = color + (255,)
        # 바깥 외곽선.
        for y in range(self.h):
            for x in range(self.w):
                if (x, y) in self.cell:
                    continue
                if any((x + dx, y + dy) in self.cell for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    px[x, y] = OUTLINE + (255,)
        return img


def _inside(x, y, pts):
    hit = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def add(p, d):
    return (p[0] + d[0], p[1] + d[1])


# ── 공통 색 ──────────────────────────────────────────────────────────

MOUTH = H('3e2731')
TOOTH = H('ead4aa')
YELLOW = H('fee761')
EMBER = H('f77622')
RED_EYE = H('e43b44')


def texture(c, group, pattern, offset=-1):
    """묶음 안쪽(가장자리 아닌) 픽셀 중 pattern(x, y) 가 참인 곳을 한 단계 어둡게."""
    for (x, y), cell in list(c.cell.items()):
        if cell[1] != group or not pattern(x, y):
            continue
        if all(c.cell.get((x + dx, y + dy), [0, None])[1] == group for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            c.shade(x, y, offset)


# ── 1. 썩은 까마귀 (잿빛 평원, 16x16, 떼로 나는 날짐승) ─────────────────

CROW = ramp('262b44', '3a4466', '5a6988')
CROW_FAR = ramp('181425', '262b44', '3a4466')
SHEEN = H('8b9bb4')
BEAK = ramp('b86f50', 'e4a672', 'ead4aa')


def feather_wing(c, root_front, root_back, tip, rp, z, group, notches=3):
    """앞 가장자리는 곧게, 뒤 가장자리는 깃털 끝이 톱니로 갈라진 날개."""
    pts = [root_front, tip]
    dx, dy = root_back[0] - tip[0], root_back[1] - tip[1]
    ln = math.hypot(dx, dy) or 1
    # 뒤 가장자리의 바깥쪽 (날개 앞 가장자리 반대쪽).
    nx, ny = -dy / ln, dx / ln
    mx = (root_front[0] + tip[0]) / 2 - (root_back[0] + tip[0]) / 2
    my = (root_front[1] + tip[1]) / 2 - (root_back[1] + tip[1]) / 2
    if nx * mx + ny * my > 0:
        nx, ny = -nx, -ny
    for k in range(1, notches + 1):
        t = k / (notches + 1)
        p = lerp(tip, root_back, t - 0.5 / (notches + 1))
        pts.append((p[0] + nx * 1.4, p[1] + ny * 1.4))
        pts.append(lerp(tip, root_back, t))
    pts.append(root_back)
    return c.poly(pts, rp, z, group=group)


def carrion_crow(f):
    c = Canvas(16, 16)
    # 위 · 가운데 · 아래 · 가운데. 내려칠 때 몸이 떠오르고 꼬리가 펼쳐진다.
    dy = [1, 0, -1, 0][f]
    tip = [(6, -0.5), (0, 4.5), (3, 15.6), (0.5, 1.5)][f]
    c.group('body', shadow=1)
    feather_wing(c, (10, 8 + dy), (7, 9.5 + dy), add(tip, (3, -0.5)), CROW_FAR, 0, 'far', notches=2)
    spread = [0, 0.5, 1, 0.5][f]
    c.poly([(5.5, 9 + dy), (0.6, 8 - spread + dy), (0, 10 + dy), (1, 12.4 + spread + dy), (5.5, 11.5 + dy)],
           CROW, 1, group='tail')
    c.ellipse(7.8, 10 + dy, 4.2, 2.6, CROW, 2, angle=-0.2, group='body')
    c.ellipse(11.6, 7.4 + dy, 2.5, 2.4, CROW, 2, group='body')
    c.poly([(13.4, 6.0 + dy), (16, 7.8 + dy), (15.0, 8.6 + dy), (13.4, 8.8 + dy)], BEAK, 4, group='beak')
    c.dot(12, 6 + dy, RED_EYE)
    c.dot(11, 5 + dy, SHEEN)          # 머리 윤기
    c.dot(8, 12 + dy, BEAK[0])
    c.dot(10, 12 + dy, BEAK[0])
    feather_wing(c, (10.5, 8.5 + dy), (5.5, 10 + dy), tip, CROW, 5, 'near', notches=3)
    return c.render()


# ── 2. 잿빛 숫양 (잿빛 평원, 32x36, 머리를 숙이고 돌진) ──────────────────

WOOL = ramp('3a4466', '5a6988', '8b9bb4', 'c0cbdc')
FACE = ramp('3e2731', '733e39', 'b86f50')
HORN = ramp('733e39', 'b86f50', 'e4a672', 'ead4aa')
HOOF = ramp('181425', '262b44')


def ash_ram(f):
    c = Canvas(32, 36)
    # 질주: 뻗기(몸이 낮고 길게, 앞으로 기운다) · 모으기(몸이 높고 짧게)를 번갈아.
    stretch = f % 2 == 0
    dy = 1 if stretch else -1
    lean = 0.04 if stretch else -0.03
    bx, by = 14, 22 + dy
    rx, ry = (10.2, 6.0) if stretch else (9.4, 6.6)
    feet = [
        {'bf': (6, 34), 'bn': (3, 34), 'ff': (23, 34), 'fn': (26, 33)},
        {'bf': (10, 32), 'bn': (8, 34), 'ff': (19, 34), 'fn': (21, 32)},
        {'bf': (3, 34), 'bn': (6, 34), 'ff': (26, 33), 'fn': (23, 34)},
        {'bf': (8, 34), 'bn': (10, 32), 'ff': (21, 32), 'fn': (19, 34)},
    ][f]
    hips = {'bf': (9.5, 25.5 + dy), 'bn': (8, 26 + dy), 'ff': (20.5, 25.5 + dy), 'fn': (19, 26 + dy)}

    def leg(k, rp, z):
        h, foot = hips[k], feet[k]
        knee = add(lerp(h, foot, 0.5), (1.2 if k[0] == 'b' else -0.8, 0))
        c.capsule([h, knee, foot], [1.8, 1.2, 1.0], rp, z, group='leg' + k)
        c.capsule([add(foot, (-0.2, -0.4)), add(foot, (1.0, -0.3))], [0.9, 0.8], HOOF, z + 0.1, group='hoof' + k)

    leg('bf', FACE[:2], 1)
    leg('ff', FACE[:2], 1)
    c.group('wool', shadow=2, light=1)
    c.ellipse(3.6 - (0.6 if stretch else 0), 19.5 + dy, 2.2, 2.0, WOOL, 3, group='wool')   # 꼬리
    c.ellipse(bx, by + 1, rx, ry - 1, WOOL, 4, angle=lean, group='wool')
    # 털 구름: 크기가 다른 둥근 뭉치를 겹쳐 등선을 울퉁불퉁하게 (가운데가 솟은 등).
    sq = 0 if stretch else -0.6
    for ox, oy, r in ((-8, 0.5, 3.6), (-4.5, -2.5, 4.0), (0, -3.6, 4.2), (4.5, -3.0, 4.0), (8, -0.5, 3.4)):
        c.ellipse(bx + ox * (1.04 if stretch else 0.96), by + oy + sq, r, r - 0.4, WOOL, 4, group='wool')
    # 배 아래로 처진 털 술.
    for x in range(6, 22, 3):
        bot = by + ry * math.sqrt(max(0, 1 - ((x - bx) / rx) ** 2))
        c.poly([(x, bot - 1.8), (x + 2.8, bot - 1.8), (x + 1.0 + (0.5 if stretch else -0.5), bot + 2.4)],
               WOOL, 4, group='wool')
    # 털 결: 작은 곱슬 무늬.
    texture(c, 'wool', lambda x, y: (y % 3 == 0 and (x + y // 3 * 2) % 4 == 0) or
            (y % 3 == 1 and (x + y // 3 * 2) % 4 == 1))
    leg('bn', FACE, 6)
    leg('fn', FACE, 6)
    # 머리: 숙여서 앞으로 들이민다 (뻗을 때 더 낮게).
    hx, hy = 25 + (1 if stretch else 0), 22.5 + dy + (1 if stretch else 0)
    c.ellipse(hx - 2.6, hy - 2.4, 3.2, 3.0, WOOL, 7, group='mane')
    c.group('head', shadow=1)
    c.ellipse(hx + 0.5, hy, 3.4, 3.0, FACE, 8, angle=0.4, group='head')
    c.ellipse(hx + 3.6, hy + 2.0, 2.3, 1.8, FACE, 8, angle=0.5, group='head')
    c.dot(hx + 5.2, hy + 2.2, FACE[0], 9)                # 콧구멍
    c.dot(hx + 2, hy - 0.6, EMBER, 12)                   # 잿불 눈
    # 말린 뿔: 머리 꼭대기에서 뒤로, 아래로, 다시 앞으로 감긴다.
    cx, cy = hx - 2.4, hy - 0.6
    pts, radii = [], []
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        a = -math.pi / 2 - t * math.tau * 0.92
        r = 4.3 - 2.6 * t
        pts.append((cx + r * math.cos(a) * 1.05, cy + r * math.sin(a)))
        radii.append(1.7 - 0.9 * t)
    c.group('horn', shadow=1)
    c.capsule(pts, radii, HORN, 11, group='horn')
    # 뿔 마디: 일정한 간격의 홈.
    texture(c, 'horn', lambda x, y: int((math.atan2(y + 0.5 - cy, x + 0.5 - cx) + math.pi) / (math.pi / 6)) % 2 == 0)
    return c.render()


# ── 3. 늪 악어 (가라앉은 성당, 32x23, 네 발로 기어 온다) ─────────────────

CROC = ramp('193c3e', '265c42', '3e8948', '63c74d')
CROC_FAR = ramp('193c3e', '265c42', '3e8948')
BELLY = ramp('733e39', 'b86f50', 'e4a672', 'ead4aa')


def bog_croc(f):
    c = Canvas(32, 23)
    # 대각선 다리 짝이 함께 움직이고, 몸은 발걸음마다 출렁, 꼬리 끝은 흔들린다. 턱은 딱딱 벌어진다.
    dy = [0, -1, 0, -1][f]
    sway = [0, 1, 0, -1][f]
    jaw = [0.3, 1.2, 0.3, 2.2][f]
    reach = [2, 0, -2, 0][f]
    tx, ty = 15, 15.6 + dy
    # 대각선 짝: (가까운 앞 + 먼 뒤), (가까운 뒤 + 먼 앞).
    near = {'front': ((20, 18 + dy), (21 + reach, 21 - (1 if f == 1 else 0))),
            'back': ((9.5, 18 + dy), (8 - reach, 21 - (1 if f == 3 else 0)))}
    far = {'front': ((21.5, 17 + dy), (22.5 - reach, 21 - (1 if f == 3 else 0))),
           'back': ((11, 17 + dy), (12 + reach, 21 - (1 if f == 1 else 0)))}
    for k, (hip, foot) in far.items():
        elbow = add(lerp(hip, foot, 0.5), (0.5, -0.2))
        c.capsule([hip, elbow, foot], [1.5, 1.2, 1.0], CROC_FAR, 1, group='far' + k)
    c.group('body', shadow=2)
    tail = [(8, 15.5 + dy), (4.8, 15.6 + dy + sway * 0.4), (2.6, 14.6 + dy + sway * 0.8), (1.4, 12.8 + dy + sway)]
    c.capsule(tail, [3.0, 2.2, 1.4, 0.7], CROC, 3, group='body')
    c.ellipse(tx, ty, 9.4, 3.8, CROC, 3, group='body')
    hx, hy = 24, 14.6 + dy * 0.5
    c.ellipse(hx, hy, 4.0, 2.8, CROC, 3, group='body')
    c.capsule([(hx + 1, hy - 0.4), (29.8, hy + 0.1)], [1.9, 1.3], CROC, 3, group='body')        # 위턱
    c.ellipse(hx + 0.6, hy - 2.4, 1.6, 1.4, CROC, 3, group='body')                               # 눈 혹
    # 배: 몸통 아래쪽은 옅은 배 비늘.
    c.recolor('body', lambda x, y, rp: BELLY if 8 <= x <= 22 and y + 0.5 > ty + 1.0 else rp)
    # 등 무늬: 어두운 가로 띠 (비늘 판).
    texture(c, 'body', lambda x, y: x % 3 == 0 and y + 0.5 < ty - 0.5 and x < 23)
    c.capsule([(hx + 1, hy + 2.0), (29.2, hy + 1.6 + jaw)], [1.2, 0.9], BELLY, 4, group='jaw')   # 아래턱
    for x in range(int(hx) + 2, 29):
        if jaw > 1:
            c.dot(x, hy + 1.6 + jaw * (x - hx - 1) / 7, MOUTH, 5)
        if x % 2 == 0:
            c.dot(x, hy + 1.2, TOOTH, 6)
    c.dot(hx + 1, hy - 3, YELLOW)
    c.dot(hx, hy - 3, MOUTH)
    c.dot(29, hy - 1.2, CROC[0])
    # 등 돌기: 위 가장자리를 따라 두 칸마다 솟은 비늘.
    for x in range(3, 22, 2):
        col = [y for (px_, y), cell in c.cell.items() if px_ == x and cell[1] == 'body']
        if col:
            c.dot(x, min(col) - 1, CROC[1], 2)
    for k, (hip, foot) in near.items():
        elbow = add(lerp(hip, foot, 0.5), (0.5, 0.3))
        c.capsule([hip, elbow, foot], [1.8, 1.4, 1.1], CROC, 8, group='near' + k)
        c.dot(foot[0] + 1.2, foot[1], TOOTH)   # 발톱
    return c.render()


# ── 4. 잉걸 아가리 (불타는 숲, 16x23, 제자리에서 쏘는 식충 꽃) ──────────

BULB = ramp('3e2731', 'a22633', 'e43b44', 'f6757a')
LEAF = ramp('193c3e', '265c42', '3e8948', '63c74d')
LEAF_FAR = ramp('193c3e', '265c42', '3e8948')
THROAT = ramp('3e2731', 'f77622', 'feae34')


def ember_maw(f):
    c = Canvas(16, 23)
    # 기본 · 뒤로 빼며 다물기(예비 동작) · 앞으로 덤비며 크게 벌리기 · 돌아오기.
    sx, sy, opening, kx, ky = [(0, 0, 40, 1.0, 1.0), (-1, 1, 10, 1.08, 0.92),
                               (1, -1, 85, 0.94, 1.06), (0, 0, 50, 1.0, 1.0)][f]
    c.ellipse(9.5, 19.4, 3.4, 1.5, LEAF_FAR, 0, angle=-0.7 + sx * 0.1, group='leafb')
    c.ellipse(4.0, 20.4, 4.0, 1.6, LEAF, 1, angle=-0.35 - sx * 0.06, group='leafl')
    c.ellipse(12.2, 20.6, 3.6, 1.5, LEAF, 1, angle=0.4 - sx * 0.06, group='leafr')
    bx, by = 7.4 + sx, 8.4 + sy
    c.capsule([(8, 21), (7.0 - sx * 0.4, 17), (bx - 0.6, 13 + sy)], [1.5, 1.2, 1.3], LEAF, 2, group='stem')
    c.ellipse(10.0, 15.6 + sy * 0.5, 2.1, 0.9, LEAF, 3, angle=-0.5, group='stemleaf')
    rx, ry = 5.6 * kx, 5.8 * ky
    c.group('head', shadow=2)
    c.ellipse(bx, by, rx, ry, BULB, 5, group='head')
    # 점박이 무늬: 위쪽의 밝은 점.
    for ox, oy in ((-2, -3), (0, -4), (-4, -1), (1, -2), (-2, 0), (-3, 2)):
        c.shade(int(bx + ox), int(by + oy), 1)
    # 아가리: 오른쪽으로 벌어진 쐐기. 가장자리 쪽은 비워서 실루엣에 턱이 보이게 하고,
    # 안쪽은 어두운 입 속과 목구멍의 잉걸.
    half = math.radians(opening) / 2
    ax_, ay_ = bx - 0.5, by + 0.6       # 경첩
    gone, inside = [], []
    for (x, y), cell in list(c.cell.items()):
        if cell[1] != 'head':
            continue
        dx, dy = x + 0.5 - ax_, y + 0.5 - ay_
        a = math.atan2(dy, dx)
        if abs(a) <= half and dx > 0:
            far = math.hypot((x + 0.5 - bx) / rx, (y + 0.5 - by) / ry)
            (gone if far > 0.78 and opening > 20 else inside).append((x, y, dx))
    c.erase([(x, y) for x, y, _ in gone])
    for x, y, dx in inside:
        c.dot(x, y, THROAT[0], 7)
        if dx < 2.5 and opening > 20:
            c.dot(x, y, THROAT[2] if dx < 1.5 else THROAT[1], 8)
    if opening <= 20:
        # 다문 입: 경첩에서 앞으로 어두운 입술 선.
        for x in range(int(ax_) + 1, int(bx + rx)):
            if (x, int(ay_)) in c.cell:
                c.dot(x, ay_, THROAT[0], 7)
    # 이빨: 입술 가장자리(쐐기 바로 바깥)를 따라 하나 건너 하나.
    hole = {(x, y) for x, y, _ in gone + inside}
    for (x, y), cell in list(c.cell.items()):
        if cell[1] != 'head' or x + 0.5 - ax_ < 1.5:
            continue
        if ((x, y + 1) in hole or (x, y - 1) in hole) and x % 2 == 0:
            c.dot(x, y, TOOTH, 9)
    return c.render()


# ── 5. 불꽃 새끼용 (불타는 숲, 16x23, 날개 치며 날아온다) ─────────────────

DRAKE = ramp('a22633', 'be4a2f', 'd77643', 'f77622')
DRAKE_BELLY = ramp('f77622', 'feae34', 'fee761')
MEMBRANE = ramp('3e2731', '68386c', 'a22633')
MEMBRANE_FAR = ramp('181425', '3e2731', '68386c')
BONE = H('d77643')


def bat_wing(c, shoulder, tips, rp, z, group, bone=None):
    """막 날개: 어깨에서 손가락 뼈 끝들까지, 뼈 사이 막은 안쪽으로 오목하게."""
    pts = [shoulder]
    for k, t in enumerate(tips):
        pts.append(t)
        if k + 1 < len(tips):
            pts.append(lerp(lerp(t, tips[k + 1], 0.5), shoulder, 0.3))
    pts.append(add(shoulder, (-2.5, 1)))
    c.poly(pts, rp, z, group=group)
    if bone:
        c.capsule([shoulder, tips[0]], [0.55, 0.45], [bone], z + 0.5, group=group + 'bone', line=False)


def ember_drake(f):
    c = Canvas(16, 23)
    dy = [1, 0, -1, 0][f]
    lift = [0.0, 0.5, 1.5, 0.5][f]   # 내려칠 때 고개를 든다
    wing_tips = [
        [(10, 0.5), (5.5, 0.5), (1.5, 3.5)],
        [(1, 6.5), (0, 10), (1.5, 13)],
        [(5, 21.5), (2.5, 20.5), (0.5, 17)],
        [(1.5, 3.5), (0, 7), (1, 10.5)],
    ][f]
    shoulder = (8.5, 11.5 + dy)
    bat_wing(c, add(shoulder, (1.5, -0.8)), [add(t, (2.5, -1)) for t in wing_tips], MEMBRANE_FAR, 0, 'farwing')
    swing = [0, 1, 0, -1][f]
    c.group('body', shadow=1)
    c.capsule([(5, 14 + dy), (2.6, 15.6 + dy), (1.4, 18 + dy + swing * 0.5), (2.6 + swing * 0.5, 20.2 + dy)],
              [1.8, 1.3, 0.9, 0.6], DRAKE, 1, group='body')
    c.poly([(2 + swing * 0.5, 19.8 + dy), (4.8 + swing * 0.5, 20.6 + dy), (2.4 + swing * 0.5, 22.6 + dy)],
           DRAKE_BELLY, 2, group='tailtip')
    c.ellipse(7.6, 13.4 + dy, 3.8, 2.8, DRAKE, 3, angle=-0.35, group='body')
    hx, hy = 12.2, 8.6 + dy - lift
    c.capsule([(9.4, 12 + dy), (11.4, hy + 1.5)], [1.7, 1.3], DRAKE, 3, group='body')
    c.ellipse(hx, hy, 2.3, 1.9, DRAKE, 3, group='body')
    c.capsule([(hx + 0.8, hy + 0.4), (15.3, hy + 1.0)], [1.2, 0.9], DRAKE, 3, group='body')
    # 배: 목에서 배까지 이어지는 노란 비늘.
    c.recolor('body', lambda x, y, rp: DRAKE_BELLY if 6 <= x <= 11 and y + 0.5 > 13.6 + dy - (x - 6) * 0.5
              and y + 0.5 < 17 + dy else rp)
    c.capsule([(7, 15.6 + dy), (7.6, 17.4 + dy)], [1.0, 0.7], DRAKE, 4, group='leg')
    c.dot(8, 18 + dy, TOOTH)
    c.capsule([(hx - 1, hy - 1.2), (hx - 2.8, hy - 3.2)], [0.8, 0.4], [TOOTH], 6, group='horn', line=False)
    c.dot(hx + 0.6, hy - 0.6, YELLOW)
    c.dot(15, hy + 1.6, MOUTH)
    bat_wing(c, shoulder, wing_tips, MEMBRANE, 8, 'wing', bone=BONE)
    return c.render()


# ── 6. 녹슨 전갈 (녹슨 요새, 16x16, 꼬리를 들었다 찌른다) ─────────────────

BRONZE = ramp('3e2731', '733e39', 'b86f50', 'e4a672')
BRONZE_FAR = ramp('3e2731', '733e39', 'b86f50')
RUST = H('be4a2f')
VENOM = ramp('f77622', 'feae34')


def rust_scorpion(f):
    c = Canvas(16, 16)
    dy = [0, -0.5, 0, 0.5][f]
    # 꼬리 (뿌리 → 끝): 쉬기 · 들기(예비) · 찌르기 · 돌아오기.
    tail = [
        [(4.5, 10.2), (2.4, 7.4), (2.8, 4.4), (5, 2.6), (7.8, 2.7)],
        [(4.5, 10.2), (2.0, 7.2), (2.2, 4.0), (4.2, 2.0), (7.0, 1.8)],
        [(4.5, 10.2), (2.8, 7.4), (4.0, 4.8), (6.4, 3.5), (9.0, 4.1)],
        [(4.5, 10.2), (2.3, 7.3), (2.6, 4.3), (4.8, 2.4), (7.5, 2.4)],
    ][f]
    tail = [(x, y + dy) for x, y in tail]
    step = [0, 1, 0, -1][f]
    for k, x in enumerate((6.5, 9, 11.5)):
        o = step if k % 2 == 0 else -step
        c.capsule([(x, 11.4 + dy), (x + 1 + o * 0.5, 12.8), (x + 1.6 + o, 14.5)], [0.6, 0.55, 0.5], BRONZE_FAR, 0,
                  group='farleg')
    c.group('body', shadow=1)
    c.ellipse(8.0, 10.8 + dy, 4.6, 2.2, BRONZE, 2, group='body')
    c.ellipse(11.8, 11.0 + dy, 2.4, 1.9, BRONZE, 2, group='body')
    # 몸 마디 홈.
    for x in (6, 8, 10):
        for y in range(16):
            if c.cell.get((x, y), [0, ''])[1] == 'body' and c.cell.get((x, y - 1), [0, ''])[1] == 'body':
                c.shade(x, y, -1)
    c.group('tail', shadow=1)
    c.capsule(tail, [1.8, 1.5, 1.3, 1.15, 1.0], BRONZE, 3, group='tail')
    # 꼬리 마디 홈: 마디 사이마다 한 픽셀 어둡게.
    for k in range(1, len(tail) - 1):
        x, y = tail[k]
        c.shade(int(x + 0.5), int(y), -1)
    ex, ey = tail[-1]
    c.capsule([(ex + 0.4, ey), (ex + 2.0, ey + 0.8), (ex + 2.4, ey + 2.4)], [0.9, 0.7, 0.45], VENOM, 4, group='sting')
    for x, y in ((7, 9), (10, 10)):
        c.dot(x, y + dy, RUST, 4)
    # 집게: 팔 + 벌렸다 닫는 집게발.
    c.capsule([(13, 11.6 + dy), (14.2, 10.0 + dy)], [0.9, 0.8], BRONZE, 5, group='arm')
    c.ellipse(14.2, 8.6 + dy, 1.8, 1.6, BRONZE, 6, group='claw')
    if f in (0, 2):
        c.erase([(15, int(8.6 + dy)), (14, int(8.6 + dy))])
    for k, x in enumerate((5.5, 8, 10.5)):
        o = -step if k % 2 == 0 else step
        c.capsule([(x, 12.0 + dy), (x + 0.9 + o * 0.5, 13.2), (x + 1.0 + o, 14.6)], [0.7, 0.6, 0.5], BRONZE[:3], 7,
                  group='leg')
    c.dot(13, 10 + dy, YELLOW)
    return c.render()


# ── 7. 화염 도마뱀 전사 (꺼지지 않는 심장, 16x23, 굽은 칼을 든 도마뱀 인간) ──

LIZARD = ramp('3e2731', 'a22633', 'be4a2f', 'd77643')
LIZARD_FAR = ramp('3e2731', '733e39', 'a22633')
LIZ_BELLY = ramp('b86f50', 'e4a672')
CREST = ramp('f77622', 'feae34')
BLADE = ramp('5a6988', 'c0cbdc', 'ffffff')


def flame_lizard(f):
    c = Canvas(16, 23)
    dy = [0, -1, 0, -1][f]
    # 발: (가까운 발, 먼 발). 0 = 가까운 발 앞, 2 = 먼 발 앞, 1 · 3 = 지나치기 (몸이 솟는다).
    near_foot, far_foot = [((10, 21), (4.5, 21)), ((7.5, 20), (7, 21)),
                           ((4.5, 21), (10, 21)), ((7.5, 21), (8, 20))][f]
    hip_n, hip_f = (7.6, 15.6 + dy), (6.8, 15.4 + dy)
    swing = [1, 0, -1, 0][f]

    def leg(hip, foot, rp, z, g):
        knee = add(lerp(hip, foot, 0.45), (1.3, -0.3))
        c.capsule([hip, knee, foot], [1.7, 1.0, 0.8], rp, z, group=g)
        c.capsule([foot, add(foot, (1.6, 0))], [0.7, 0.6], rp, z, group=g)

    leg(hip_f, far_foot, LIZARD_FAR, 0, 'farleg')
    c.capsule([(6.6, 11 + dy), (5.4 - swing, 14 + dy)], [1.1, 0.9], LIZARD_FAR, 0, group='fararm')
    c.group('body', shadow=1)
    c.capsule([(5.6, 15 + dy), (3, 17.4 + dy), (1.2 + swing * 0.5, 20.2)], [1.9, 1.2, 0.6], LIZARD, 1, group='body')
    c.ellipse(7.5, 12.3 + dy, 2.9, 4.1, LIZARD, 1, angle=0.2, group='body')
    hx, hy = 8.8, 6.6 + dy
    c.ellipse(hx, hy, 2.6, 2.1, LIZARD, 1, group='body')
    c.capsule([(hx + 1, hy + 0.3), (13.2, hy + 0.9)], [1.4, 1.0], LIZARD, 1, group='body')
    # 배: 몸통 앞쪽 옅은 비늘 판, 가로 홈.
    c.recolor('body', lambda x, y, rp: LIZ_BELLY if 9 <= y - dy <= 15 and x + 0.5 > 8.6 + (y - 12 - dy) * 0.2
              else rp)
    leg(hip_n, near_foot, LIZARD, 4, 'leg')
    c.dot(hx + 1, hy - 1, YELLOW)
    c.dot(12, hy + 1.6, MOUTH)
    # 볏: 머리 뒤에서 목덜미로 이어지는 가시 셋.
    for (ax, ay), (tx, ty) in (((7.8, hy - 1.6), (6.2, hy - 4.8)), ((6.8, hy - 0.6), (4.2, hy - 2.6)),
                               ((6.4, hy + 1.2), (4.0, hy + 0.8))):
        c.poly([(ax - 0.9, ay + 0.6), (tx, ty), (ax + 1.0, ay - 0.2)], CREST, 6, group='crest')
    hand = (11.2, 13.4 + dy - swing * 0.5)
    c.capsule([(8.4, 10.6 + dy), hand], [1.2, 0.9], LIZARD, 8, group='arm')
    up = swing * 0.8
    blade = [add(hand, (0.6, -0.4)), add(hand, (2.0, -1.8 - up * 0.5)), add(hand, (3.2, -3.8 - up)),
             add(hand, (3.6, -6.0 - up))]
    c.capsule(blade, [0.6, 0.9, 0.8, 0.4], BLADE, 9, group='blade')
    c.dot(hand[0], hand[1], CREST[1])   # 칼자루 금박
    return c.render()


MONSTERS = {
    'carrion_crow': ((16, 16), carrion_crow),
    'ash_ram': ((32, 36), ash_ram),
    'bog_croc': ((32, 23), bog_croc),
    'ember_maw': ((16, 23), ember_maw),
    'ember_drake': ((16, 23), ember_drake),
    'rust_scorpion': ((16, 16), rust_scorpion),
    'flame_lizard': ((16, 23), flame_lizard),
}


def main(out):
    enemies = os.path.join(out, 'enemies')
    os.makedirs(enemies, exist_ok=True)
    only = sys.argv[2:]
    for name, ((w, h), draw) in MONSTERS.items():
        if only and name not in only:
            continue
        sheet = Image.new('RGBA', (w * FRAMES, h))
        for f in range(FRAMES):
            img = draw(f)
            assert img.size == (w, h), (name, img.size)
            sheet.paste(img, (f * w, 0))
        info = PngInfo()
        info.add_text('ashborn', 'new_monsters')
        sheet.save(os.path.join(enemies, f'{name}.png'), pnginfo=info, optimize=True)
        print(name, sheet.size)


if __name__ == '__main__':
    main(sys.argv[1])
