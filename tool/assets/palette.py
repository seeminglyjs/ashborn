"""게임 전체가 함께 쓰는 고정 팔레트와, 색을 그 팔레트로 맞추는 함수.

python -I tool/assets/palette.py <png 파일 또는 폴더> ...   # 팔레트 밖 색이 몇 개인지 센다

팔레트는 Lospec 의 Endesga 32 (무료로 쓸 수 있는 공개 팔레트, https://lospec.com/palette-list/endesga-32).
색 수를 묶어 두면 따로 그린 그림끼리도 한 게임처럼 보인다. 새로 그리는 그림(무기 픽셀 아트,
몬스터 변종, 이펙트 색)은 이 팔레트 색만 쓴다.

가까운 색은 사람 눈 기준(OKLab 거리)으로 찾는다. RGB 거리로 고르면 어두운 색이 엉뚱한
색조로 튄다.
"""
import math
import os
import sys

from PIL import Image

ENDESGA_32 = [
    'be4a2f', 'd77643', 'ead4aa', 'e4a672', 'b86f50', '733e39', '3e2731', 'a22633',
    'e43b44', 'f77622', 'feae34', 'fee761', '63c74d', '3e8948', '265c42', '193c3e',
    '124e89', '0099db', '2ce8f5', 'ffffff', 'c0cbdc', '8b9bb4', '5a6988', '3a4466',
    '262b44', '181425', 'ff0044', '68386c', 'b55088', 'f6757a', 'e8b796', 'c28569',
]

PALETTE = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in ENDESGA_32]


def _linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def oklab(rgb):
    r, g, b = (_linear(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s))
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


_LAB = [oklab(c) for c in PALETTE]
_cache = {}


def nearest(rgb):
    """[rgb] 에 가장 가까운 팔레트 색."""
    rgb = tuple(rgb[:3])
    hit = _cache.get(rgb)
    if hit is None:
        lab = oklab(rgb)
        i = min(range(len(PALETTE)), key=lambda k: sum((a - b) ** 2 for a, b in zip(lab, _LAB[k])))
        hit = _cache[rgb] = PALETTE[i]
    return hit


def snap(img):
    """[img] 의 불투명 픽셀을 모두 팔레트 색으로 맞춘다 (투명도는 그대로)."""
    img = img.convert('RGBA')
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = nearest((r, g, b)) + (a,)
    return img


def off_palette(img):
    """팔레트 밖 색의 수."""
    colors = {c[:3] for c in img.convert('RGBA').getdata() if c[3]}
    return len(colors - set(PALETTE))


def _files(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                yield from (os.path.join(root, n) for n in sorted(names) if n.endswith('.png'))
        else:
            yield p


if __name__ == '__main__':
    for path in _files(sys.argv[1:]):
        print(f'{off_palette(Image.open(path)):4d}  {path}')
