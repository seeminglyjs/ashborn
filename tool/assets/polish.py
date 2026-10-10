"""몬스터 시트에 명암을 덧입힌다 (sprites.py · monsters.py 다음에 한 번 돌린다).

python -I tool/assets/sprites.py <0x72 frames> assets/images/sprites
python -I tool/assets/monsters.py assets/images/sprites
python -I tool/assets/polish.py assets/images/sprites
python -I tool/assets/heroes.py assets/images/sprites

원본 0x72 그림은 색 단계가 적고 명암이 평평하다. 픽셀마다 다음을 한다.
- 색조 이동 명암: 어두운 쪽은 차가운 보랏빛으로, 밝은 쪽은 따뜻한 금빛으로 색조를 민다.
  회색(갑옷 · 뼈)도 그림자는 푸르스름하게, 빛은 누르스름하게 물들인다.
- 명암 대비를 조금 키운다.
- 빛은 왼쪽 위에서 온다: 윗면 · 왼면 테두리는 밝게, 아랫면은 어둡게 (부피감).
- 색 외곽선: 빛 받는 쪽 외곽선은 검정 대신 안쪽 색의 짙은 색으로 (단조로운 검은 테두리를 줄인다).
영웅(기사 · 마녀 · 사냥꾼) 시트는 건드리지 않는다. heroes.py 가 원본 없이 완성된 시트를 그린다.

두 번 돌리면 두 번 칠해지니, 늘 sprites.py · monsters.py 로 새로 만든 시트에 돌린다.
"""
import colorsys
import os
import sys

from PIL import Image

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


def frames_of(sheet, fw):
    return [sheet.crop((i * fw, 0, i * fw + fw, sheet.height)) for i in range(sheet.width // fw)]


def join(frames):
    fw, fh = frames[0].size
    out = Image.new('RGBA', (fw * len(frames), fh))
    for i, f in enumerate(frames):
        out.paste(f, (i * fw, 0))
    return out


def main(root):
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
