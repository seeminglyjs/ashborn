"""장비 부위 · 직업 무기 아이콘만 다시 만든다 (0x72 원본이 없어도 된다).

python -I tool/assets/gear_icons.py assets/images/sprites

- items/gear.png · items/gear_unique.png: 장비 부위 16x16 프레임. 순서는 ItemType
  (lib/data/equipment.dart) 과 같다.
- items/weapons.png · items/weapons_unique.png: 직업 무기 16x16 프레임 12장
  (기사 4 · 마녀 4 · 사냥꾼 4). 순서는 Dart 의 무기 종류 enum 과 같다.

그림(GEAR · WEAPONS 글자 격자)과 쓰는 함수는 sprites.py 에 있고, sprites.py 의 main 도
같은 write_gear_icons 를 불러 둘이 늘 같은 결과를 낸다.
"""
import os
import sys

# -I 는 스크립트 폴더를 sys.path 에 넣지 않는다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sprites import write_gear_icons  # noqa: E402

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/images/sprites'
    write_gear_icons(out)
    print('items/gear · gear_unique · weapons · weapons_unique done')
