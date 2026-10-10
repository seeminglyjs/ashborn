"""scene_test 의 '플레이어 움직임' 프레임을 GIF 와 띠 그림으로 묶는다 (움직임 연출 확인용).

flutter test tool/preview/scene_test.dart --plain-name 움직임
python -I tool/preview/motion.py [--frames build/preview/motion] [--before 폴더] [--out build/preview]

- 화면 가운데(플레이어 주변)를 잘라 낸다 (기기 배율 3 으로 찍은 그대로).
- motion.gif: 30fps 그대로. motion_strip.png: 2프레임마다 한 칸씩, 장면(서기 · 달리기 · 돌기 · 멈춤 · 피격)별로 한 줄.
- --before 를 주면 예전 프레임을 왼쪽, 지금 프레임을 오른쪽에 나란히 놓은 GIF 도 만든다 (motion_compare.gif).
"""
import argparse
import os

from PIL import Image, ImageDraw

CROP = 220  # 플레이어 주변을 자를 한 변 (기기 픽셀, 배율 3 기준)
ZOOM = 2
LIFT = 10  # 발 아래 먼지까지 보이도록 살짝 올려 자른다
# 장면 경계 (프레임 수, scene_test 의 run() 순서와 같다).
SCENES = [('idle', 54), ('run', 30), ('turn', 18), ('stop', 24), ('hit', 21)]


def load(folder):
    names = sorted(n for n in os.listdir(folder) if n.startswith('f_') and n.endswith('.png'))
    frames = []
    for n in names:
        im = Image.open(os.path.join(folder, n)).convert('RGB')
        cx, cy = im.width // 2, im.height // 2
        box = (cx - CROP // 2, cy - CROP // 2 - LIFT, cx + CROP // 2, cy + CROP // 2 - LIFT)
        frames.append(im.crop(box).resize((CROP * ZOOM, CROP * ZOOM), Image.NEAREST))
    return frames


def gif(frames, path):
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=33, loop=0)


def strip(frames, path):
    cell = CROP * ZOOM // 2
    cols = max(n for _, n in SCENES) // 2
    sheet = Image.new('RGB', (cols * (cell + 4) + 60, len(SCENES) * (cell + 4)), (20, 18, 18))
    draw = ImageDraw.Draw(sheet)
    start = 0
    for row, (name, count) in enumerate(SCENES):
        draw.text((4, row * (cell + 4) + 4), name, fill=(220, 220, 220))
        for i in range(0, count, 2):
            if start + i >= len(frames):
                break
            im = frames[start + i].resize((cell, cell), Image.NEAREST)
            sheet.paste(im, (60 + i // 2 * (cell + 4), row * (cell + 4)))
        start += count
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', default='build/preview/motion')
    ap.add_argument('--before')
    ap.add_argument('--out', default='build/preview')
    args = ap.parse_args()
    now = load(args.frames)
    gif(now, os.path.join(args.out, 'motion.gif'))
    strip(now, os.path.join(args.out, 'motion_strip.png'))
    print(f'{len(now)} 프레임 → {args.out}/motion.gif, motion_strip.png')
    if args.before:
        old = load(args.before)
        pairs = []
        for a, b in zip(old, now):
            both = Image.new('RGB', (a.width * 2 + 8, a.height), (20, 18, 18))
            both.paste(a, (0, 0))
            both.paste(b, (a.width + 8, 0))
            pairs.append(both)
        gif(pairs, os.path.join(args.out, 'motion_compare.gif'))
        strip(old, os.path.join(args.out, 'motion_strip_before.png'))
        print(f'비교: {args.out}/motion_compare.gif (왼쪽 예전, 오른쪽 지금)')


if __name__ == '__main__':
    main()
