"""캐릭터 · 몬스터 시트에 명암과 장비를 덧입힌다 (sprites.py · monsters.py 다음에 한 번 돌린다).

python -I tool/assets/sprites.py <0x72 frames> assets/images/sprites
python -I tool/assets/monsters.py assets/images/sprites
python -I tool/assets/polish.py assets/images/sprites

원본 0x72 그림은 색 단계가 적고 명암이 평평하다. 픽셀마다 다음을 한다.
- 색조 이동 명암: 어두운 쪽은 차가운 보랏빛으로, 밝은 쪽은 따뜻한 금빛으로 색조를 민다.
  회색(갑옷 · 뼈)도 그림자는 푸르스름하게, 빛은 누르스름하게 물들인다.
- 명암 대비를 조금 키운다.
- 빛은 왼쪽 위에서 온다: 윗면 · 왼면 테두리는 밝게, 아랫면은 어둡게 (부피감).
- 색 외곽선: 빛 받는 쪽 외곽선은 검정 대신 안쪽 색의 짙은 색으로 (단조로운 검은 테두리를 줄인다).
캐릭터는 그 전에 무기를 덧그린다: 기사는 등에 멘 대검, 마녀는 잔불 지팡이, 사냥꾼은 화살통.

두 번 돌리면 두 번 칠해지니, 늘 sprites.py · monsters.py 로 새로 만든 시트에 돌린다.
"""
import colorsys
import os
import sys

from PIL import Image

HERO_FRAME = (16, 28)
ENEMY_FRAMES = 4


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, s, v, a=255):
    r, g, b = colorsys.hsv_to_rgb(h % 1, max(0, min(1, s)), max(0, min(1, v)))
    return (round(r * 255), round(g * 255), round(b * 255), a)


def toward(h, target, amount):
    """색조 [h] (0..1) 를 [target] 쪽으로 [amount] 만큼 돌린다 (짧은 쪽으로)."""
    d = (target - h + 0.5) % 1 - 0.5
    return h + d * amount


COOL = 250 / 360
WARM = 45 / 360


def is_outline(c):
    return c[3] > 0 and hsv(c)[2] < 0.2


def polish_frame(img):
    w, h = img.size
    src = img.load()
    out = img.copy()
    px = out.load()

    def at(x, y):
        if 0 <= x < w and 0 <= y < h:
            return src[x, y]
        return (0, 0, 0, 0)

    def open_(x, y):
        c = at(x, y)
        return c[3] == 0 or is_outline(c)

    for y in range(h):
        for x in range(w):
            c = src[x, y]
            if c[3] == 0:
                continue
            hh, s, v = hsv(c)
            if is_outline(c):
                # 색 외곽선: 안쪽 칠이 아래 · 오른쪽에 있으면(빛 받는 윗면 · 왼면 테두리) 그 색의 짙은 색.
                for dx, dy in ((0, 1), (1, 0)):
                    n = at(x + dx, y + dy)
                    if n[3] and not is_outline(n):
                        nh, ns, nv = hsv(n)
                        px[x, y] = rgb(toward(nh, COOL, 0.25), min(1, ns * 0.9 + 0.2), 0.22, c[3])
                        break
                continue
            # 대비를 키운다.
            v = 0.5 + (v - 0.5) * 1.3
            if s < 0.1:
                # 무채색: 그림자는 푸르게, 빛은 누르스름하게.
                if v < 0.55:
                    hh, s = COOL * 0.92, 0.10 + (0.55 - v) * 0.25
                else:
                    hh, s = WARM, 0.04 + (v - 0.55) * 0.1
            else:
                if v < 0.55:
                    hh = toward(hh, COOL, (0.55 - v) * 0.45)
                    s = s * 1.08 + 0.04
                elif v > 0.65:
                    hh = toward(hh, WARM, (v - 0.65) * 0.5)
                    s *= 0.92
                else:
                    s *= 1.05
            # 왼쪽 위 빛: 윗면 · 왼면 테두리는 밝게, 아랫면 · 오른면은 어둡게.
            if open_(x, y - 1):
                v += 0.2
                s *= 0.8
            elif open_(x - 1, y):
                v += 0.1
            if open_(x, y + 1):
                v -= 0.16
                hh = toward(hh, COOL, 0.2)
            elif open_(x + 1, y):
                v -= 0.08
            px[x, y] = rgb(hh, s, v, c[3])
    return out


def bbox_top(img):
    w, h = img.size
    px = img.load()
    for y in range(h):
        if any(px[x, y][3] for x in range(w)):
            return y
    return 0


def put(px, w, h, x, y, color, behind=False):
    if not (0 <= x < w and 0 <= y < h):
        return
    if behind and px[x, y][3]:
        return
    px[x, y] = color


STEEL = (196, 204, 220, 255)
STEEL_D = (110, 118, 140, 255)
GOLD = (232, 184, 74, 255)
LEATHER = (110, 66, 40, 255)
INK = (26, 20, 24, 255)


def knight_gear(img, frame):
    """등에 멘 대검: 왼쪽 어깨 위로 손잡이, 몸 뒤로 비스듬히 칼날.
    몸통 앞에는 잿불빛 휘장 (가운데 세로 띠와 금빛 테)."""
    w, h = img.size
    px = img.load()
    top = bbox_top(img)
    # 휘장: 투구 아래 몸통(밝은 회색) 가운데 세로 띠. 갑옷 픽셀 위에만 칠한다.
    for y in range(top + 11, top + 17):
        for x in range(6, 10):
            c = px[x, y]
            if c[3] and not is_outline(c):
                edge = x in (6, 9)
                px[x, y] = GOLD if edge and y == top + 11 else (
                    (120, 28, 30, 255) if edge else (176, 44, 40, 255))
    # 칼날: (4, top+3) 에서 (0, top+17) 로 비스듬히. 몸 뒤라서 빈칸에만 그린다.
    for i in range(15):
        x = 4 - round(i * 4 / 14)
        y = top + 3 + i
        put(px, w, h, x, y, STEEL, behind=True)
        put(px, w, h, x - 1, y, STEEL_D, behind=True)
    put(px, w, h, 0, top + 18, STEEL_D, behind=True)
    # 날 옆 외곽선.
    for i in range(15):
        x = 4 - round(i * 4 / 14)
        put(px, w, h, x - 2, top + 3 + i, INK, behind=True)
    # 코등이 (어깨 높이) 와 손잡이. 몸 뒤라 빈칸에만 보인다.
    for x in range(1, 6):
        put(px, w, h, x, top + 2, GOLD, behind=True)
    put(px, w, h, 0, top + 2, INK, behind=True)
    put(px, w, h, 5, top + 1, LEATHER, behind=True)


def witch_gear(img, frame):
    """앞손에 든 잔불 지팡이: 오른쪽에 세운 막대와 깜빡이는 불씨."""
    w, h = img.size
    px = img.load()
    top = bbox_top(img)
    x = 14
    for y in range(top + 5, h - 1):
        put(px, w, h, x, y, LEATHER if y % 3 else (150, 98, 60, 255))
        put(px, w, h, x + 1, y, INK, behind=True)
    put(px, w, h, x, h - 1, INK)
    # 불씨: 프레임마다 밝은 점이 옮겨 다니며 일렁인다.
    glow = [(255, 226, 122, 255), (255, 138, 42, 255), (216, 54, 30, 255)]
    core = [(0, 0), (1, 0), (0, 1), (1, 1)][frame % 4]
    for dy in range(3):
        for dx in range(3):
            c = glow[1] if (dx, dy) != (1, 1) else glow[0]
            if (dx, dy) in ((0, 0), (2, 0), (0, 2), (2, 2)):
                c = glow[2]
            put(px, w, h, x - 1 + dx, top + 2 + dy, c)
    put(px, w, h, x - 1 + core[0], top + 2 + core[1], glow[0])
    for dx, dy in ((-2, 1), (2, 1), (0, -1), (0, 3)):
        put(px, w, h, x - 1 + 1 + dx, top + 2 + 1 + dy, INK, behind=True)


def hunter_gear(img, frame):
    """앞손에 든 석궁: 오른쪽에 세운 활대와 앞으로 뻗은 개머리, 강철 촉."""
    w, h = img.size
    px = img.load()
    top = bbox_top(img)
    wood = (150, 98, 60, 255)
    y0 = top + 11
    # 활대: 오른쪽 끝에 세로로, 위아래로 휘었다.
    for dy in range(-3, 4):
        put(px, w, h, 15 if abs(dy) < 3 else 14, y0 + dy, wood if abs(dy) < 2 else LEATHER)
    # 개머리와 화살.
    for x in range(11, 15):
        put(px, w, h, x, y0, LEATHER)
    put(px, w, h, 15, y0, STEEL)
    for x in range(11, 15):
        put(px, w, h, x, y0 + 1, INK, behind=True)


GEAR = {'knight': knight_gear, 'witch': witch_gear, 'hunter': hunter_gear}


def frames_of(sheet, fw):
    return [sheet.crop((i * fw, 0, i * fw + fw, sheet.height)) for i in range(sheet.width // fw)]


def join(frames):
    fw, fh = frames[0].size
    out = Image.new('RGBA', (fw * len(frames), fh))
    for i, f in enumerate(frames):
        out.paste(f, (i * fw, 0))
    return out


def main(root):
    for name, gear in GEAR.items():
        path = os.path.join(root, f'{name}.png')
        sheet = Image.open(path).convert('RGBA')
        frames = frames_of(sheet, HERO_FRAME[0])
        done = []
        for i, f in enumerate(frames):
            gear(f, i)
            done.append(polish_frame(f))
        join(done).save(path)
        print(name, sheet.size)
    enemies = os.path.join(root, 'enemies')
    for file in sorted(os.listdir(enemies)):
        if not file.endswith('.png'):
            continue
        path = os.path.join(enemies, file)
        sheet = Image.open(path).convert('RGBA')
        fw = sheet.width // ENEMY_FRAMES
        join([polish_frame(f) for f in frames_of(sheet, fw)]).save(path)
    print('enemies done')


if __name__ == '__main__':
    main(sys.argv[1])
