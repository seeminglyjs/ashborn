"""0x72 DungeonTileset II 프레임으로 스프라이트 시트를 만든다 (CC-0).

python -I tool/assets/sprites.py <압축 푼 0x72_DungeonTilesetII_v1.7/frames> assets/images/sprites

- 캐릭터: 16x28 프레임 9장(대기 4 · 달리기 4 · 피격 1)을 가로로 붙인 <캐릭터>.png.
  원본은 밝은 색이라 일러스트의 어두운 판타지 톤에 맞게 색 범위별로 다시 칠한다.
- 적 · 보스: 걷기(또는 하나뿐인) 애니메이션 4장을 가로로 붙인 enemies/<이름>.png.
  어떤 지역에 어떤 적을 쓸지는 lib/data/stages.dart 의 Region 이 정한다.
"""
import colorsys
import os
import sys

from PIL import Image

# 캐릭터 → (원본 이름, [(색상 범위 시작°, 끝°, 새 색상°, 채도 배율, 명도 배율)])
HEROES = {
    # 잿불 기사: 청록 갑옷 → 어두운 강철, 주황 깃털은 그대로 (잿불).
    'knight': ('knight_m', [(150, 235, 215, 0.12, 0.72)]),
    # 재의 마녀: 파란 · 보라 로브와 모자 → 검붉은 로브.
    'witch': ('wizzard_f', [(200, 290, 352, 0.8, 0.6)]),
    # 불씨 사냥꾼: 초록 옷 → 짙은 가죽색.
    'hunter': ('elf_f', [(70, 170, 28, 0.55, 0.62)]),
}

ORDER = [f'idle_anim_f{i}' for i in range(4)] + \
    [f'run_anim_f{i}' for i in range(4)] + ['hit_anim_f0']


def recolor(img, rules):
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = h * 360
            # 외곽선처럼 어둡거나 무채색인 픽셀은 건드리지 않는다.
            if s < 0.2 or v < 0.15:
                continue
            for start, end, hue, sat, val in rules:
                if start <= deg <= end:
                    nr, ng, nb = colorsys.hsv_to_rgb(hue / 360, s * sat, v * val)
                    px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
                    break
    return img


# 적 · 보스 시트 이름 → 원본 프레임 접두어. 원본 그대로 쓴다.
MONSTERS = {
    'tiny_zombie': 'tiny_zombie_run_anim',
    'skelet': 'skelet_run_anim',
    'imp': 'imp_run_anim',
    'orc_warrior': 'orc_warrior_run_anim',
    'chort': 'chort_run_anim',
    'big_zombie': 'big_zombie_run_anim',
    'necromancer': 'necromancer_anim',
    'ogre': 'ogre_run_anim',
    'masked_orc': 'masked_orc_run_anim',
    'big_demon': 'big_demon_run_anim',
}


def sheet(frames):
    w, h = frames[0].size
    assert all(f.size == (w, h) for f in frames)
    out = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def main(src, out):
    for name, (base, rules) in HEROES.items():
        frames = [
            recolor(Image.open(f'{src}/{base}_{o}.png').convert('RGBA'), rules)
            for o in ORDER
        ]
        img = sheet(frames)
        img.save(f'{out}/{name}.png', optimize=True)
        print(name, base, img.size)
    os.makedirs(f'{out}/enemies', exist_ok=True)
    for name, base in MONSTERS.items():
        img = sheet([
            Image.open(f'{src}/{base}_f{i}.png').convert('RGBA') for i in range(4)
        ])
        img.save(f'{out}/enemies/{name}.png', optimize=True)
        print(name, img.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
