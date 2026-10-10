"""AI 가 만든 픽셀 그림을 게임에 넣을 수 있게 다듬는다 (격자 · 배경 · 팔레트 · 잡티 · 외곽선).

python -I tool/assets/ai_cleanup.py <png 파일 또는 폴더> ... [--out 폴더] [--scale N] [--colors K]
                                    [--keep-bg] [--min-blob N] [--no-trim] [--preview 파일]

AI 픽셀 그림은 픽셀처럼 보여도 칸 크기가 들쭉날쭉하고, 경계가 번지고, 비슷한 색이 수십 개 섞여 있다.
한 장마다 다음을 한다.
1. 격자: Sprite Fusion Pixel Snapper (MIT, https://github.com/Hugo-Dz/spritefusion-pixel-snapper) 로
   숨은 격자를 찾아 한 칸을 한 픽셀로 줄인다. 확대 배율을 정확히 알면 --scale 로 넘긴다.
   그때는 Snapper 없이 칸마다 가장 많은 색을 고른다 (Snapper 는 배율을 줘도 격자를 스스로 고쳐 잡는다).
2. 배경: 가장자리에서 이어진 배경색 영역을 지운다. 이미 투명 배경이면 건너뛴다.
3. 팔레트: 모든 색을 Endesga 32 로 맞춘다 (palette.py 의 OKLab 거리).
   Snapper 의 --palette 는 RGB 거리라 배경 잡음이 푸른 점으로, 붉은 천이 갈색으로 튀어서 쓰지 않는다.
4. 잡티: 몸통에서 떨어진 작은 덩어리(--min-blob 픽셀 미만)를 지운다.
5. 외곽선: 바깥 테두리의 어두운 색을 기본 외곽선 #181425 로 통일한다.
6. 여백을 1픽셀만 남기고 잘라 낸다. 프레임 위치가 중요한 스프라이트 시트는 --no-trim.

결과는 --out (기본 build/ai_cleanup/) 에 같은 이름으로, 비교 이미지는 --preview
(기본 build/preview/ai_cleanup.png) 에 원본 | 결과(크게) | 결과(1배) 로 늘어놓는다. 반드시 열어 본다.

생성할 때 지킬 것: PNG 로 받는다 (JPEG 잡티는 격자 찾기를 망친다). 흐릿하게 뭉개진 결과는 버린다.
같은 스프라이트를 망가뜨려 시험해 보니, 칸 크기만 들쭉날쭉한 경우는 격자를 거의 다 맞췄고
(픽셀 일치 약 80에서 98%), 흐림 + JPEG 는 매번 실패했다.

Snapper 설치 (Rust 필요): cargo install spritefusion-pixel-snapper
찾는 순서: 환경 변수 PIXEL_SNAPPER → PATH → ~/.cargo/bin
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from collections import Counter, deque

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import nearest, oklab  # noqa: E402

OUTLINE = (0x18, 0x14, 0x25)
# 외곽선으로 바꿀 만큼 어두운 색 (OKLab 명도). 262b44 · 3e2731 · 193c3e 까지 들어간다.
DARK_L = 0.3
BG_TOL = 0.12  # 배경으로 볼 OKLab 거리
PREVIEW_BG = (46, 42, 40, 255)


def find_snapper():
    for cand in (os.environ.get('PIXEL_SNAPPER'), shutil.which('spritefusion-pixel-snapper'),
                 os.path.expanduser('~/.cargo/bin/spritefusion-pixel-snapper.exe'),
                 os.path.expanduser('~/.cargo/bin/spritefusion-pixel-snapper')):
        if cand and os.path.isfile(cand):
            return cand
    sys.exit('Pixel Snapper 를 찾지 못했다. cargo install spritefusion-pixel-snapper 로 설치하거나 '
             'PIXEL_SNAPPER 에 실행 파일 경로를 넣는다. 배율을 알면 --scale 로 Snapper 없이 돌릴 수 있다.')


def snap_grid(img, colors):
    """Snapper 로 격자를 찾아 한 칸을 한 픽셀로 줄인다. 팔레트는 여기서 맞추지 않는다."""
    exe = find_snapper()
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, 'in.png'), os.path.join(tmp, 'out.png')
        img.save(src)
        r = subprocess.run([exe, src, dst, str(colors)], capture_output=True, text=True)
        if r.returncode:
            raise RuntimeError(r.stderr.strip() or r.stdout.strip())
        return Image.open(dst).convert('RGBA')


def block_grid(img, scale):
    """배율 [scale] 을 알 때: 칸마다 가장 많이 나온 (팔레트로 맞춘) 색을 고른다."""
    w, h = img.width // scale, img.height // scale
    src = img.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = out.load()
    for by in range(h):
        for bx in range(w):
            votes = Counter()
            clear = 0
            for y in range(by * scale, (by + 1) * scale):
                for x in range(bx * scale, (bx + 1) * scale):
                    c = src[x, y]
                    if c[3] < 128:
                        clear += 1
                    else:
                        votes[nearest(c)] += 1
            if votes and sum(votes.values()) > clear:
                px[bx, by] = votes.most_common(1)[0][0] + (255,)
    return out


def _dist(a, b):
    return sum((p - q) ** 2 for p, q in zip(a, b)) ** 0.5


def remove_bg(img):
    """가장자리에서 가장 흔한 색을 배경으로 보고, 가장자리와 이어진 비슷한 색을 지운다."""
    img = img.copy()
    px = img.load()
    w, h = img.size
    border = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    opaque = [px[x, y][:3] for x, y in border if px[x, y][3] >= 128]
    if not opaque:
        return img
    ref = oklab(Counter(opaque).most_common(1)[0][0])
    seen = bytearray(w * h)
    q = deque(border)
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        c = px[x, y]
        if c[3] >= 128 and _dist(oklab(c[:3]), ref) > BG_TOL:
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def to_palette(img):
    img = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            px[x, y] = (0, 0, 0, 0) if c[3] < 128 else nearest(c) + (255,)
    return img


def drop_specks(img, min_blob):
    """8방향으로 이어진 불투명 덩어리 중 [min_blob] 픽셀보다 작은 것을 지운다."""
    if min_blob <= 1:
        return img
    img = img.copy()
    px = img.load()
    w, h = img.size
    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or px[sx, sy][3] == 0:
                continue
            blob, q = [], deque([(sx, sy)])
            seen[sy * w + sx] = 1
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny][3]:
                            seen[ny * w + nx] = 1
                            q.append((nx, ny))
            if len(blob) < min_blob:
                for x, y in blob:
                    px[x, y] = (0, 0, 0, 0)
    return img


def unify_outline(img):
    """투명한 곳과 맞닿은 바깥 테두리 중 어두운 색을 #181425 로 바꾼다."""
    img = img.copy()
    px = img.load()
    w, h = img.size

    def clear(x, y):
        return not (0 <= x < w and 0 <= y < h) or px[x, y][3] == 0

    edge = [(x, y) for y in range(h) for x in range(w)
            if px[x, y][3] and any(clear(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        if oklab(px[x, y][:3])[0] < DARK_L:
            px[x, y] = OUTLINE + (255,)
    return img


def trim(img, pad=1):
    box = img.getbbox()
    if not box:
        return img
    out = Image.new('RGBA', (box[2] - box[0] + pad * 2, box[3] - box[1] + pad * 2), (0, 0, 0, 0))
    out.paste(img.crop(box), (pad, pad))
    return out


def has_transparency(img):
    return img.getextrema()[3][0] < 128


def clean(img, scale=None, colors=24, keep_bg=False, min_blob=3, do_trim=True):
    img = img.convert('RGBA')
    transparent = has_transparency(img)
    small = block_grid(img, scale) if scale else snap_grid(img, colors)
    if not keep_bg and not transparent:
        small = remove_bg(small)
    small = to_palette(small)
    small = drop_specks(small, min_blob)
    small = unify_outline(small)
    return trim(small) if do_trim else small


def files(paths):
    for p in paths:
        if os.path.isdir(p):
            for name in sorted(os.listdir(p)):
                if name.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                    yield os.path.join(p, name)
        else:
            yield p


def preview(pairs, out):
    """원본 | 결과(크게) | 결과(1배) 를 한 줄씩."""
    rows = []
    for src, res in pairs:
        zoom = max(1, min(12, 240 // max(res.size)))
        big = res.resize((res.width * zoom, res.height * zoom), Image.NEAREST)
        h = big.height
        orig = src.convert('RGBA')
        orig = orig.resize((max(1, round(orig.width * h / orig.height)), h), Image.LANCZOS)
        rows.append((orig, big, res))
    width = max(o.width + b.width + r.width for o, b, r in rows) + 16 * 4
    height = sum(b.height for _, b, _ in rows) + 16 * (len(rows) + 1)
    sheet = Image.new('RGBA', (width, height), PREVIEW_BG)
    y = 16
    for o, b, r in rows:
        x = 16
        for im in (o, b, r):
            sheet.alpha_composite(im, (x, y))
            x += im.width + 16
        y += b.height + 16
    os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser(description='AI 픽셀 그림 후처리')
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--out', default='build/ai_cleanup')
    ap.add_argument('--scale', type=int, help='확대 배율을 정확히 알 때 (예: 8)')
    ap.add_argument('--colors', type=int, default=24, help='Snapper 가 격자를 찾을 때 쓰는 색 수')
    ap.add_argument('--keep-bg', action='store_true', help='배경을 지우지 않는다')
    ap.add_argument('--min-blob', type=int, default=3, help='이보다 작은 떨어진 덩어리를 지운다 (1 이면 안 지움)')
    ap.add_argument('--no-trim', action='store_true', help='여백을 자르지 않는다 (스프라이트 시트)')
    ap.add_argument('--preview', default='build/preview/ai_cleanup.png')
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    pairs = []
    for path in files(args.paths):
        if path.lower().endswith(('.jpg', '.jpeg')):
            print(f'주의: {path} 는 JPEG 다. 잡티 때문에 격자를 잘못 찾을 수 있다. PNG 로 받아 오자.')
        src = Image.open(path)
        res = clean(src, args.scale, args.colors, args.keep_bg, args.min_blob, not args.no_trim)
        name = os.path.splitext(os.path.basename(path))[0] + '.png'
        res.save(os.path.join(args.out, name))
        used = {c[:3] for _, c in res.getcolors(1 << 16) if c[3]}
        note = '  (색이 12개를 넘는다: 도트 규칙은 8에서 12개)' if len(used) > 12 else ''
        print(f'{name}: {src.width}x{src.height} → {res.width}x{res.height}, 색 {len(used)}개{note}')
        pairs.append((src, res))
    if pairs:
        preview(pairs, args.preview)
        print(f'비교 이미지: {args.preview}')


if __name__ == '__main__':
    main()
