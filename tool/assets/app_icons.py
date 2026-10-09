"""앱 아이콘을 원본 로고 하나로 모든 플랫폼 크기에 맞춰 만든다.

python -I tool/assets/app_icons.py art/logo/app_icon.png

- Android: mipmap-*/ic_launcher.png (예전 방식) + 적응형 아이콘
  (mipmap-*/ic_launcher_foreground.png, mipmap-anydpi-v26/ic_launcher.xml, 바탕은 검정).
- iOS: AppIcon.appiconset 의 Contents.json 에 적힌 크기 전부 (알파 없는 RGB).
- Windows: windows/runner/resources/app_icon.ico.

로고는 검은 바탕이라 바탕색도 검정으로 맞춘다.
"""
import json
import os
import sys

from PIL import Image

BACKGROUND = (0, 0, 0)

# 예전 방식 아이콘은 로고를 꽉 채우고, 적응형 전경은 기기 마스크에 잘리지 않도록
# 안전 영역(108dp 중 지름 66dp) 안에 들어가게 줄인다.
LEGACY_FILL = 0.84
ADAPTIVE_FILL = 0.6
IOS_FILL = 0.8

ANDROID = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
RES = 'android/app/src/main/res'
IOS = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'


def emblem(img):
    """검은 여백을 잘라 문양만 정사각형으로 남긴다."""
    mask = img.convert('L').point(lambda v: 255 if v > 24 else 0)
    left, top, right, bottom = mask.getbbox()
    side = max(right - left, bottom - top)
    cx, cy = (left + right) // 2, (top + bottom) // 2
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    return img.crop(box)


def placed(logo, size, fill, background):
    """[size] 정사각형 가운데에 로고를 [fill] 비율로 놓는다."""
    canvas = Image.new('RGBA', (size, size), background)
    inner = max(1, round(size * fill))
    scaled = logo.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    canvas.paste(scaled, (offset, offset), scaled)
    return canvas


def main(src):
    logo = emblem(Image.open(src).convert('RGBA'))

    for density, scale in ANDROID.items():
        folder = f'{RES}/mipmap-{density}'
        os.makedirs(folder, exist_ok=True)
        placed(logo, round(48 * scale), LEGACY_FILL, BACKGROUND + (255,)).convert(
            'RGB').save(f'{folder}/ic_launcher.png', optimize=True)
        placed(logo, round(108 * scale), ADAPTIVE_FILL, (0, 0, 0, 0)).save(
            f'{folder}/ic_launcher_foreground.png', optimize=True)

    os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
    with open(f'{RES}/mipmap-anydpi-v26/ic_launcher.xml', 'w', encoding='utf-8') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n')
    with open(f'{RES}/values/ic_launcher_background.xml', 'w', encoding='utf-8') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#000000</color>\n'
            '</resources>\n')

    contents = json.load(open(f'{IOS}/Contents.json', encoding='utf-8'))
    for image in contents['images']:
        points = float(image['size'].split('x')[0])
        px = round(points * int(image['scale'].rstrip('x')))
        placed(logo, px, IOS_FILL, BACKGROUND + (255,)).convert('RGB').save(
            f"{IOS}/{image['filename']}", optimize=True)

    placed(logo, 256, LEGACY_FILL, BACKGROUND + (255,)).save(
        'windows/runner/resources/app_icon.ico',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128),
               (256, 256)])
    print('icons done')


if __name__ == '__main__':
    main(sys.argv[1])
