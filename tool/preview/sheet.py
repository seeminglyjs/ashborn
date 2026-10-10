"""스프라이트 시트를 크게 늘어놓은 한 장짜리 PNG 를 만든다 (도트 작업 확인용).

python -I tool/preview/sheet.py [--frames] [--before 폴더] [--out 파일] <png 파일 또는 폴더> ...

- 기본은 시트마다 첫 프레임만, --frames 면 모든 프레임을 늘어놓는다.
- --before 를 주면 같은 상대 경로의 예전 그림을 위 줄에, 지금 그림을 아래 줄에 놓아 비교한다
  (예: 스크립트를 고치기 전 assets 를 복사해 두고 --before 로 넘긴다).
- 캐릭터 시트(knight · witch · hunter)는 24x28 프레임 11장, enemies/ 는 4장으로 잘라 본다.
- 배경은 게임 바닥과 비슷한 어두운 색. 작은 그림일수록 크게 키운다 (짧은 변이 140px 쯤).
- 결과 기본 위치는 build/preview/sheet.png. 이 파일을 열어 눈으로 확인한다.
"""
import argparse
import os

from PIL import Image

BG = (46, 42, 40, 255)
GAP = 8
WIDTH = 1200


def frame_width(path, img):
    name = os.path.basename(path)
    parent = os.path.basename(os.path.dirname(path))
    if name in ('knight.png', 'witch.png', 'hunter.png'):
        return 24
    if parent == 'enemies':
        return img.width // 4
    return img.width


def tiles_of(path, all_frames):
    img = Image.open(path).convert('RGBA')
    fw = frame_width(path, img)
    count = img.width // fw if all_frames else 1
    scale = max(1, round(140 / max(fw, img.height)))
    return [
        img.crop((i * fw, 0, i * fw + fw, img.height)).resize(
            (fw * scale, img.height * scale), Image.NEAREST)
        for i in range(count)
    ]


def layout(tiles):
    x = y = row = 0
    spots = []
    for t in tiles:
        if x and x + t.width > WIDTH:
            x, y, row = 0, y + row + GAP, 0
        spots.append((x, y))
        x += t.width + GAP
        row = max(row, t.height)
    sheet = Image.new('RGBA', (WIDTH, y + row), BG)
    for t, p in zip(tiles, spots):
        sheet.alpha_composite(t, p)
    return sheet


def files(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                yield from (os.path.join(root, n) for n in sorted(names) if n.endswith('.png'))
        else:
            yield p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--frames', action='store_true')
    ap.add_argument('--before')
    ap.add_argument('--out', default='build/preview/sheet.png')
    args = ap.parse_args()
    paths = list(files(args.paths))
    now = layout([t for p in paths for t in tiles_of(p, args.frames)])
    if args.before:
        base = os.path.commonpath([os.path.abspath(p) for p in args.paths])
        if os.path.isfile(base):
            base = os.path.dirname(base)
        old = []
        for p in paths:
            q = os.path.join(args.before, os.path.relpath(os.path.abspath(p), base))
            old += tiles_of(q if os.path.exists(q) else p, args.frames)
        before = layout(old)
        out = Image.new('RGBA', (WIDTH, before.height + now.height + 12), (0, 0, 0, 255))
        out.alpha_composite(before, (0, 0))
        out.alpha_composite(now, (0, before.height + 12))
        now = out
    os.makedirs(os.path.dirname(args.out) or '.', exist_ok=True)
    now.save(args.out)
    print(args.out, now.size)


if __name__ == '__main__':
    main()
