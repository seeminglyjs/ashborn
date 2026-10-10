"""적 시트를 어두운 바닥 위에서 더 잘 읽히게 다듬는다 (polish.py 다음, 마지막 단계).

python -I tool/assets/monster_polish2.py assets/images/sprites

순서: sprites.py → monsters.py → polish.py → new_monsters.py → monster_polish2.py.
원본 0x72 그림은 몸통 일부가 바닥(#2e2a28)만큼 어두워서 게임에서는 몸이 끊겨 보였다
(초르트 · 큰 악마의 몸통, 큰 좀비의 바지 등). 프레임마다 다음을 한다.

1. 두꺼운 어둠 띄우기: 3x3 이 모두 어두운 덩어리(=선이 아니라 면)는 같은 색조로 밝혀
   바닥과 떨어지게 한다. 무채색이면 차가운 남색으로. 덩어리 안에서도 왼쪽 위는 밝게,
   오른쪽 아래는 어둡게. 1px 선(눈 · 입 · 갑옷 이음매)은 그대로 둔다.
2. 바깥 외곽선: 투명한 곳과 맞닿은 어두운 픽셀은 모두 #181425 로 통일하고, 외곽선 없이
   투명한 곳과 맞닿은 칠은 바깥 빈칸에 #181425 를 더한다 (프레임 끝이면 그 픽셀을 외곽선으로).
3. 테두리 빛: 외곽선 바로 안쪽 윗면 · 왼면은 따뜻하게 밝히고, 아랫면 · 오른면은 차갑게 어둡게.
   채도도 조금 올린다 (작게 보여도 색이 산다).
4. 눈: 눈구멍이 어두운 해골 · 좀비 · 가면 오크는 눈구멍 안에 빛나는 눈(밝은 1px + 아래 어두운 1px)을
   넣는다. 흰 눈 · 노란 눈이 이미 있는 시트는 그대로 둔다. 첫 프레임 좌표를 적어 두고, 다른 프레임은 머리 모양을 맞춰 찾아 따라간다.

여러 번 돌려도 같다: 다 다듬은 PNG 에는 'ashborn' 텍스트 표시를 남기고, 표시가 있으면 건너뛴다.
new_monsters.py 가 새로 그린 시트에도 표시를 남기므로 그 시트는 건드리지 않는다.
(monsters.py 로 변종을 다시 만들면 변종 시트는 표시가 없는 새 파일이 되어 다시 다듬어진다.)
"""
import colorsys
import os
import sys

from PIL import Image
from PIL.PngImagePlugin import PngInfo

FRAMES = 4
MARK_KEY = 'ashborn'
MARK = 'polish2'
OUTLINE = (0x18, 0x14, 0x25, 255)

COOL = 235 / 360
WARM = 42 / 360


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, s, v, a=255):
    r, g, b = colorsys.hsv_to_rgb(h % 1, max(0, min(1, s)), max(0, min(1, v)))
    return (round(r * 255), round(g * 255), round(b * 255), a)


def toward(h, target, amount):
    d = (target - h + 0.5) % 1 - 0.5
    return h + d * amount


def dark(c):
    return c[3] > 0 and max(c[:3]) < 72


# ── 눈 ─────────────────────────────────────────────────────────────────
# 원본 시트 이름 → 첫 프레임에서 빛나는 눈 픽셀. 변종은 원본 좌표를 같이 쓴다.
EYES = {
    'skelet': [(7, 4)],  # 오른쪽 눈구멍은 외곽선에 붙어 있어 빛을 넣으면 귀처럼 보인다.
    'tiny_zombie': [(7, 8), (11, 8)],
    'masked_orc': [(9, 10), (13, 10)],
}
# 시트 → (원본, 눈 색, 눈 가운데 더 밝은 색)
EYE_COLOR = {
    'skelet': ('skelet', (0xf7, 0x76, 0x22), (0xfe, 0xe7, 0x61)),
    'skelet_drowned': ('skelet', (0x2c, 0xe8, 0xf5), (0xff, 0xff, 0xff)),
    'skelet_rust': ('skelet', (0xfe, 0xae, 0x34), (0xfe, 0xe7, 0x61)),
    'tiny_zombie': ('tiny_zombie', (0x63, 0xc7, 0x4d), (0xfe, 0xe7, 0x61)),
    'tiny_zombie_drowned': ('tiny_zombie', (0x2c, 0xe8, 0xf5), (0xff, 0xff, 0xff)),
    'masked_orc': ('masked_orc', (0xe4, 0x3b, 0x44), (0xf6, 0x75, 0x7a)),
    'masked_orc_tide': ('masked_orc', (0x2c, 0xe8, 0xf5), (0xff, 0xff, 0xff)),
}


def track(f0, fi, pts, r=3):
    """[pts] 둘레 창을 f0 에서 떼어 fi 에서 가장 비슷한 자리를 찾아 (dx, dy) 를 돌려준다."""
    w, h = f0.size
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    box = [(x, y) for y in range(max(0, min(ys) - 3), min(h, max(ys) + 4))
           for x in range(max(0, min(xs) - 3), min(w, max(xs) + 4))]
    a, b = f0.load(), fi.load()
    best, at = None, (0, 0)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            cost = 0
            for x, y in box:
                p = a[x, y]
                qx, qy = x + dx, y + dy
                q = b[qx, qy] if 0 <= qx < w and 0 <= qy < h else (0, 0, 0, 0)
                if (p[3] > 0) != (q[3] > 0):
                    cost += 300
                elif p[3]:
                    cost += sum(abs(i - j) for i, j in zip(p[:3], q[:3]))
            cost += (abs(dx) + abs(dy)) * 5
            if best is None or cost < best:
                best, at = cost, (dx, dy)
    return at


def eyes(frames, name):
    if name in EYE_COLOR:
        base, glow, core = EYE_COLOR[name]
        pts = EYES[base]
        f0 = frames[0].copy()
        for i, f in enumerate(frames):
            dx, dy = (0, 0) if i == 0 else track(f0, f, pts)
            px = f.load()
            for k, (x, y) in enumerate(pts):
                x, y = x + dx, y + dy
                if 0 <= x < f.width and 0 <= y < f.height and px[x, y][3]:
                    px[x, y] = (core if k == 0 else glow) + (255,)
                    # 눈 아래 한 칸은 어두운 눈빛 (2px 눈).
                    if y + 1 < f.height and dark(px[x, y + 1]):
                        px[x, y + 1] = rgb(*hsv(glow)[:2], hsv(glow)[2] * 0.6)


# ── 다듬기 ─────────────────────────────────────────────────────────────

def polish_frame(img):
    w, h = img.size
    src = img.copy()
    s = src.load()

    def at(x, y):
        return s[x, y] if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)

    def empty(x, y):
        return at(x, y)[3] == 0

    n4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
    ring = {(x, y) for y in range(h) for x in range(w)
            if s[x, y][3] and any(empty(x + dx, y + dy) for dx, dy in n4)}

    # 1. 두꺼운 어둠 띄우기.
    thick = {(x, y) for y in range(h) for x in range(w)
             if dark(s[x, y]) and all(dark(at(x + dx, y + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
    lift = set(thick)
    for x, y in thick:
        for dx, dy in n4:
            p = (x + dx, y + dy)
            if p in lift or p in ring or not dark(at(*p)):
                continue
            # 밝은 칠과 맞닿은 어두운 선(턱 그림자 · 이음매)은 남긴다.
            if any(at(p[0] + ex, p[1] + ey)[3] and not dark(at(p[0] + ex, p[1] + ey)) for ex, ey in n4):
                continue
            lift.add(p)
    out = src.copy()
    px = out.load()
    for x, y in lift:
        hh, ss, vv = hsv(s[x, y])
        if ss < 0.3 or vv < 0.1:
            hh, ss = COOL, 0.38
        else:
            hh, ss = toward(hh, COOL, 0.15), min(0.75, ss * 0.85)
        up = (x, y - 1) not in lift
        left = (x - 1, y) not in lift
        down = (x, y + 1) not in lift
        right = (x + 1, y) not in lift
        v = 0.36
        if up:
            v, hh = 0.48, toward(hh, WARM, 0.12)
        elif left:
            v = 0.42
        if down:
            v, hh = 0.28, toward(hh, COOL, 0.2)
        elif right:
            v = 0.31
        px[x, y] = rgb(hh, ss, v)

    # 2. 바깥 외곽선.
    base = out.copy()
    b = base.load()
    for x, y in ring:
        if dark(b[x, y]):
            px[x, y] = OUTLINE
            continue
        edge = False
        for dx, dy in n4:
            qx, qy = x + dx, y + dy
            if 0 <= qx < w and 0 <= qy < h:
                if b[qx, qy][3] == 0:
                    px[qx, qy] = OUTLINE
            else:
                edge = True
        if edge:
            px[x, y] = OUTLINE

    # 3. 테두리 빛 · 채도.
    cur = out.copy()
    c = cur.load()

    def outside(x, y):
        q = c[x, y] if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
        return q[3] == 0 or q[:3] == OUTLINE[:3]

    for y in range(h):
        for x in range(w):
            q = c[x, y]
            if q[3] == 0 or q[:3] == OUTLINE[:3] or dark(q) or (x, y) in lift:
                continue
            hh, ss, vv = hsv(q)
            if ss > 0.15:
                ss = min(1, ss * 1.12)
            if outside(x, y - 1) or outside(x - 1, y):
                vv = vv + 0.07 * (1 - vv) + 0.04
                hh = toward(hh, WARM, 0.12) if ss > 0.1 else hh
                if ss < 0.1:
                    hh, ss = WARM, max(ss, 0.06)
            elif outside(x, y + 1) or outside(x + 1, y):
                vv *= 0.86
                hh = toward(hh, COOL, 0.18)
                if ss < 0.1:
                    hh, ss = COOL, max(ss, 0.12)
            px[x, y] = rgb(hh, ss, vv, q[3])
    return out


def marked(path):
    try:
        return Image.open(path).text.get(MARK_KEY) is not None
    except Exception:
        return False


def save(img, path, mark=MARK):
    info = PngInfo()
    info.add_text(MARK_KEY, mark)
    img.save(path, pnginfo=info, optimize=True)


def main(root):
    enemies = os.path.join(root, 'enemies')
    for file in sorted(os.listdir(enemies)):
        if not file.endswith('.png'):
            continue
        path = os.path.join(enemies, file)
        if marked(path):
            print('skip', file)
            continue
        name = file[:-4]
        sheet = Image.open(path).convert('RGBA')
        fw = sheet.width // FRAMES
        frames = [sheet.crop((i * fw, 0, i * fw + fw, sheet.height)) for i in range(FRAMES)]
        done = [polish_frame(f) for f in frames]
        eyes(done, name)
        out = Image.new('RGBA', sheet.size)
        for i, f in enumerate(done):
            out.paste(f, (i * fw, 0))
        save(out, path)
        print(name, sheet.size)


if __name__ == '__main__':
    main(sys.argv[1])
