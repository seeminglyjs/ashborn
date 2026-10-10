"""세 영웅(잿불 기사 · 재의 마녀 · 잿불 사냥꾼) 스프라이트 시트를 처음부터 그린다.

python -I tool/assets/heroes.py [assets/images/sprites]

시트마다 24x28 프레임 11장 (264x28): 0-3 대기, 4-7 달리기, 8 피격, 9 공격 예비, 10 공격. 오른쪽을 보고, 발은 맨 아래 줄(27)에
닿는다 (왼쪽은 게임이 뒤집어 그린다). 몸은 x 4-15 쯤에 두고, 오른쪽 빈칸으로 무기를 내민다.

예전 영웅은 0x72 원본 위에 polish.py 가 장비를 덧그린 것이었는데, 머리가 큰 2등신이라 무기가 몸에 묻혀
읽히지 않았다(기사의 깃털은 덩어리, 등의 대검은 가는 띠, 투구 · 휘장은 상자로 보였다). 그래서 세 영웅 모두
원본 없이 여기서 같은 비율로 그린다.
- 비율: 키 약 18칸 (머리 5 · 몸통 6 · 다리 6), 다리를 벌린 자세에 살짝 앞으로 기운다.
- 무기는 몸 밖으로 내밀어 따로 읽히게: 기사는 가슴 높이로 앞으로 뻗은 긴 검, 사냥꾼은 시위를 당긴
  큰 활과 화살, 마녀는 끝에 잔불이 타는 지팡이.
- 색은 Endesga 32 (palette.py) 에서만, 재질마다 2-3단계. 빛은 왼쪽 위, 그늘은 차가운 쪽으로. 외곽선 #181425.

그리는 방법: 부위(뒤에 멘 것 · 다리 · 몸통 · 머리 · 머리 장식 · 무기 든 팔)를 글자 격자로 적고
프레임마다 위아래로 옮겨 겹친다. 격자의 글자 하나가 한 칸, '.' 은 투명. 다리는 숫자 틀(1-6)을 영웅마다
다른 색으로 바꿔 같은 걸음새를 쓴다.

돌리는 순서: sprites.py → monsters.py → polish.py → heroes.py.
polish.py 는 영웅 시트를 건드리지 않는다 (이 스크립트가 완성된 시트를 쓴다). sprites.py 를 다시 돌려
영웅 시트가 0x72 그림으로 덮였다면 이 스크립트를 마지막에 다시 돌린다.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import PALETTE  # noqa: E402

FW, FH = 24, 28

# 글자 → 색. 모두 Endesga 32.
INK = {
    'o': '181425',  # 외곽선
    'H': 'ffffff',  # 강철 반짝임 · 칼날
    'W': 'c0cbdc',  # 강철 밝은 면
    'S': '8b9bb4',  # 강철 중간
    'D': '5a6988',  # 강철 그늘
    'K': '3a4466',  # 강철 깊은 그늘
    'N': '262b44',  # 가장 짙은 남색 (두건 속 · 옷 그늘)
    'y': 'feae34',  # 금 · 불씨 심
    'r': 'f77622',  # 주황 (금 그늘 · 잔불)
    'R': 'e43b44',  # 붉은 깃털 · 깃
    'M': 'a22633',  # 붉은 그늘
    't': 'e4a672',  # 밝은 나무 · 화살대
    'T': 'b86f50',  # 나무 · 머리칼 밝은 면
    'L': '733e39',  # 가죽 · 머리칼
    'B': '3e2731',  # 짙은 가죽
    'c': 'ead4aa',  # 활시위 · 깃
    's': 'e8b796',  # 피부
    'k': 'c28569',  # 피부 그늘
    'g': '63c74d',  # 밝은 초록
    'G': '3e8948',  # 초록
    'J': '265c42',  # 짙은 초록
    'p': 'b55088',  # 밝은 보라
    'P': '68386c',  # 보라
}
COLORS = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for k, v in INK.items()}
assert all(c[:3] in PALETTE for c in COLORS.values())


def part(rows):
    """{y: 줄} 격자. 줄의 글자 위치가 곧 x (0 부터)."""
    return rows


def stamp(img, rows, dx=0, dy=0, recolor=None):
    px = img.load()
    for y, row in rows.items():
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            if recolor:
                ch = recolor.get(ch, ch)
            X, Y = x + dx, y + dy
            if 0 <= X < FW and 0 <= Y < FH:
                px[X, Y] = COLORS[ch]


# 다리 틀: 1·2 앞다리 밝은 면 · 그늘, 3·4 뒷다리, 5·6 장화. 맨 윗줄(20)은 평소 엉덩이에 가려지고
# 윗몸이 뜰 때만 보인다.
LEGS = {
    'stance': part({   # 앞다리는 앞으로, 뒷다리는 뒤로 벌려 버틴다
        20: '......o34oo12o',
        21: '......o34oo12o',
        22: '.....o34o..o12o',
        23: '.....o34o..o12o',
        24: '....o34o....o12o',
        25: '....o34o....o12o',
        26: '...o6666o...o5566o',
        27: '...oooooo...oooooo',
    }),
    'stride': part({   # 달리기 디딤: 앞다리를 내딛고 뒷다리는 발끝으로 땅을 차고 나간다.
        20: '......o34oo12o',   # 대기 자세처럼 두 발을 다 땅에 붙이고 벌리면 걷지 않고
        21: '......o34oo12o',   # 다리를 벌린 채 통통 튀는 것처럼 보인다 (뒷발을 띄운다).
        22: '.....o34o.o12o',
        23: '.....o34o..o12o',
        24: '....o34o...o12o',
        25: '....o66o...o12o',
        26: '....ooo....o5566o',
        27: '...........oooooo',
    }),
    'stride2': part({  # 다리를 바꿔 디딤
        20: '......o12oo34o',
        21: '......o12oo34o',
        22: '.....o12o.o34o',
        23: '.....o12o..o34o',
        24: '....o12o...o34o',
        25: '....o56o...o34o',
        26: '....ooo....o6666o',
        27: '...........oooooo',
    }),
    # 지나침: 디딤발은 몸 아래로 와서 곧게 서고, 든 발은 무릎을 굽혀 몸 아래에서 낮게 지나간다.
    # 디딤발이 앞(디딤) → 몸 아래(지나침) → 뒤(다음 디딤에서 차고 나감)로 땅을 밀며 옮겨 가야 걷는다.
    # 디딤발을 늘 앞에 두고 뒷발만 뒤로 높이 차올리면 한 발로 깽깽이 뛰는 것처럼 보였다.
    'pass': part({     # 앞다리(밝은)로 몸 아래를 딛고, 뒷다리는 굽혀 들어 지나간다
        20: '......o34oo12o',
        21: '......o34oo12o',
        22: '......o34o12o',
        23: '.....o34oo12o',
        24: '....o66o.o12o',
        25: '....oooo.o12o',
        26: '.........o5566o',
        27: '.........oooooo',
    }),
    'pass2': part({    # 뒷다리로 몸 아래를 딛고, 앞다리(밝은)를 굽혀 들어 지나간다
        20: '......o12oo34o',
        21: '......o12oo34o',
        22: '......o12o34o',
        23: '.....o12oo34o',
        24: '....o55o.o34o',
        25: '....oooo.o34o',
        26: '.........o6666o',
        27: '.........oooooo',
    }),
}

# 프레임 순서: 대기 4장 (숨쉬기로 윗몸 1칸, 장식 나풀거림) · 달리기 4장 (디딤-지나침, 지나칠 때 1칸 뜸).
# 달리기 디딤은 대기의 벌린 자세가 아니라 앞발만 땅에 닿은 좁은 보폭이다.
POSES = [
    dict(legs='stance', dy=0, flap='a', arm=0),
    dict(legs='stance', dy=0, flap='b', arm=1),
    dict(legs='stance', dy=1, flap='b', arm=1),
    dict(legs='stance', dy=1, flap='a', arm=0),
    dict(legs='stride', dy=0, flap='b', arm=0),
    dict(legs='pass', dy=-1, flap='a', arm=-1),
    dict(legs='stride2', dy=0, flap='b', arm=0),
    dict(legs='pass2', dy=-1, flap='a', arm=-1),
]

# 피격 번쩍임: 한 단계씩 밝힌다.
FLASH = {
    'N': 'K', 'K': 'D', 'D': 'S', 'S': 'W', 'W': 'H',
    'J': 'G', 'G': 'g', 'B': 'L', 'L': 'T', 'T': 't', 'P': 'p', 'k': 's',
}


# ---------------------------------------------------------------- 잿불 기사
# 남빛 판금 갑옷, 둥근 투구와 가로 눈구멍, 뒤로 날리는 붉은 깃털, 가슴 높이로 앞으로 뻗은 긴 검.

KNIGHT_LEGS = {'1': 'S', '2': 'D', '3': 'D', '4': 'K', '5': 'D', '6': 'K'}

KNIGHT_PLUME = {
    'a': part({
        4: '.........ooo',
        5: '.......ooyyRo',
        6: '......oyrRRMo',
        7: '.....oyrRMoo',
        8: '.....oRMo',
        9: '......oo',
    }),
    'b': part({
        4: '.........ooo',
        5: '......oooyyRo',
        6: '.....oyyrRRMo',
        7: '....oRRRMMoo',
        8: '.....ooMo',
        9: '.......o',
    }),
}

KNIGHT_HELM = part({
    8: '.........oooo',
    9: '........oWWWSo',
    10: '.......oWHWSSDo',
    11: '.......oWSSoooo',
    12: '.......oSSSSSKo',
    13: '........oDDDKo',
    14: '.........oooo',
})

KNIGHT_TORSO = part({
    14: '......oooooooo',
    15: '......oWWWSSDo',
    16: '......oWWSSSDo',
    17: '......oWSSSDKo',
    18: '......oSSSSDKo',
    19: '......oyyyyrro',
    20: '......oDSRMDKo',
})

# 어깨받이 · 앞으로 뻗은 팔 · 건틀릿 주먹 · 금빛 코등이 · 흰 칼날 (끝이 위로 비스듬히 뾰족).
KNIGHT_ARM = part({
    14: '..........ooo...o',
    15: '.........oWWSoooyoooooo',
    16: '.........oSSDSWWyHHHHHWo',
    17: '.........oDDKDSDrSSSSSo',
    18: '..........oooooorooooo',
    19: '................o',
})


def knight(pose):
    img = Image.new('RGBA', (FW, FH))
    dy = pose['dy']
    stamp(img, KNIGHT_PLUME[pose['flap']], 0, dy)
    stamp(img, LEGS[pose['legs']], recolor=KNIGHT_LEGS)
    stamp(img, KNIGHT_TORSO, 0, dy)
    stamp(img, KNIGHT_HELM, 0, dy)
    stamp(img, KNIGHT_ARM, 0, dy + pose['arm'])
    return img


def knight_hit():
    """뒤로 젖혀 물러난다: 투구가 뒤로 넘어가고 검이 들리며, 강철이 번쩍인다."""
    img = Image.new('RGBA', (FW, FH))
    stamp(img, KNIGHT_PLUME['b'], -2, -1)
    stamp(img, LEGS['stance'], recolor=KNIGHT_LEGS)
    stamp(img, KNIGHT_TORSO, -1, 0, FLASH)
    stamp(img, KNIGHT_HELM, -2, -1, FLASH)
    stamp(img, KNIGHT_ARM, -2, -2, FLASH)
    return img


# 공격 자세 (칼은 게임이 SwordStrike 로 따로 그리므로 여기서는 빈손으로 쥔 주먹만).
# 예비 동작: 몸을 뒤로 젖히고 팔을 등 뒤 허리께로 당긴다.
KNIGHT_ARM_BACK = part({
    13: '.........ooo',
    14: '........oWWSo',
    15: '........oWSSDo',
    16: '......ooSDDKo',
    17: '....ooSDDooo',
    18: '...oySDoo',
    19: '...orDo',
    20: '....oo',
})
# 내지름: 몸을 앞으로 싣고 팔을 쭉 뻗는다. 주먹 끝(금빛 코등이)에 칼이 붙는다.
KNIGHT_ARM_OUT = part({
    14: '.........ooo',
    15: '........oWWSooooooo',
    16: '........oSSDSSWSDySo',
    17: '........oDDKDDDDKrDo',
    18: '.........oooooooooo',
})


def knight_windup():
    img = Image.new('RGBA', (FW, FH))
    stamp(img, KNIGHT_PLUME['b'], -1, 0)
    stamp(img, LEGS['stance'], recolor=KNIGHT_LEGS)
    stamp(img, KNIGHT_TORSO, -1, 0)
    stamp(img, KNIGHT_HELM, -1, 0)
    stamp(img, KNIGHT_ARM_BACK, -1, 0)
    return img


def knight_strike():
    img = Image.new('RGBA', (FW, FH))
    stamp(img, KNIGHT_PLUME['a'], 1, 1)
    stamp(img, LEGS['stride'], recolor=KNIGHT_LEGS)
    stamp(img, KNIGHT_TORSO, 1, 1)
    stamp(img, KNIGHT_HELM, 2, 1)
    stamp(img, KNIGHT_ARM_OUT, 1, 1)
    return img

# ---------------------------------------------------------------- 잿불 사냥꾼
# 초록 튜닉, 갈색 머리, 등에 화살통, 시위를 당긴 큰 나무 활과 화살.

HUNTER_LEGS = {'1': 'G', '2': 'J', '3': 'J', '4': 'B', '5': 'L', '6': 'B'}

HUNTER_QUIVER = part({
    9: '....ooo',
    10: '...ocWco',
    11: '...oRcRo',
    12: '...oTTTo',
    13: '...oLLTo',
    14: '...oBLLo',
    15: '...oBLLo',
    16: '...oBLLo',
    17: '...oBLLo',
    18: '....oBo',
})

HUNTER_HEAD = {
    'a': part({
        8: '.........oooo',
        9: '........oTTTLo',
        10: '.......oTTLLLLo',
        11: '......oLLLLsoso',
        12: '......oBLsssko',
        13: '.......oBkkko',
        14: '........oooo',
    }),
    'b': part({
        8: '.........oooo',
        9: '........oTTTLo',
        10: '.......oTTLLLLo',
        11: '.......oLLLsoso',
        12: '......oLBsssko',
        13: '......oBokkko',
        14: '.......o.ooo',
    }),
}

HUNTER_TORSO = part({
    14: '......oooooooo',
    15: '......oggGGGJo',
    16: '......ogGGGLJo',
    17: '......oGGGLGJo',
    18: '......oGGLGJJo',
    19: '......oLLLTLBo',
    20: '......oGGGGJJo',
})

# 활: 끝(15,7)·(15,25) 에서 배가 x18 까지 불룩. 시위는 당기는 손(11,15)으로 모인다.
BOW_WOOD = [(15, 7), (16, 8), (16, 9), (17, 10), (17, 11)] + [(18, y) for y in range(12, 21)] + [
    (17, 21), (17, 22), (16, 23), (16, 24), (15, 25)]
BOW_STRING = [(15, 8), (15, 9), (14, 10), (14, 11), (13, 12), (13, 13), (12, 14),
              (12, 16), (12, 17), (13, 18), (13, 19), (14, 20), (14, 21), (15, 22), (15, 23), (15, 24)]


def outline_around(img, pts):
    """[pts] 둘레의 빈칸에 외곽선을 친다."""
    px = img.load()
    own = set(pts)
    for x, y in pts:
        for ax, ay in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (ax, ay) in own or not (0 <= ax < FW and 0 <= ay < FH):
                continue
            if px[ax, ay][3] == 0:
                px[ax, ay] = COLORS['o']


def hunter_bow(img, dy, flash=False, released=False):
    """[released] 면 쏜 직후: 시위가 곧게 펴지고 화살이 없다."""
    px = img.load()
    c = (lambda ch: COLORS[FLASH.get(ch, ch)]) if flash else (lambda ch: COLORS[ch])
    wood = [(x, y + dy) for x, y in BOW_WOOD]
    string = [(15, y) for y in range(8, 25)] if released else BOW_STRING
    for x, y in string:
        px[x, y + dy] = c('c')
    for x, y in wood:
        px[x, y] = c('B' if 15 <= y - dy <= 17 else ('T' if y - dy < 16 else 'L'))
    outline_around(img, wood)
    if released:
        return
    # 화살: 깃(왼쪽) · 대 · 강철 촉. 당기는 손 위로 지나간다.
    y = 15 + dy
    for x in range(12, 20):
        px[x, y] = c('c')
    px[11, y] = c('R')
    px[11, y - 1] = c('R')
    px[20, y] = c('W')
    px[21, y] = c('W')
    for x, yy in ((20, y - 1), (21, y - 1), (22, y), (20, y + 1), (21, y + 1), (10, y), (10, y - 1),
                  (11, y - 2)):
        if px[x, yy][3] == 0:
            px[x, yy] = COLORS['o']


# 활을 쥔 앞팔 (가는 초록 소매, 화살 바로 아래) · 활 손잡이를 감싼 손 · 시위를 당긴 뒷손.
HUNTER_ARM = part({
    15: '..........ooooooo',
    16: '.........oGGGGGGGo',
    17: '..........ooooooo',
})
HUNTER_GRIP = part({
    15: '.................ooo',
    16: '................osko',
    17: '.................ooo',
})
HUNTER_DRAW_HAND = part({
    14: '.........ooo',
    15: '........oskko',
    16: '.........ooo',
})


def hunter(pose, hit=False):
    img = Image.new('RGBA', (FW, FH))
    dy, fl = pose['dy'], (FLASH if hit else None)
    hx = -1 if hit else 0
    stamp(img, HUNTER_QUIVER, hx, dy, fl)
    stamp(img, LEGS[pose['legs']], recolor=HUNTER_LEGS)
    stamp(img, HUNTER_TORSO, hx, dy, fl)
    stamp(img, HUNTER_HEAD[pose['flap']], hx * 2, dy - hit, fl)
    stamp(img, HUNTER_ARM, hx, dy + pose['arm'], fl)
    hunter_bow(img, dy + pose['arm'] - hit, flash=hit)
    stamp(img, HUNTER_GRIP, 0, dy + pose['arm'] - hit, fl)
    stamp(img, HUNTER_DRAW_HAND, hx, dy + pose['arm'], fl)
    return img



def hunter_reload():
    """쏜 뒤 다시 메기기: 웅크려 화살을 시위에 건다."""
    img = Image.new('RGBA', (FW, FH))
    dy = 1
    stamp(img, HUNTER_QUIVER, 0, dy)
    stamp(img, LEGS['stance'], recolor=HUNTER_LEGS)
    stamp(img, HUNTER_TORSO, 0, dy)
    stamp(img, HUNTER_HEAD['a'], 0, dy)
    stamp(img, HUNTER_ARM, 0, dy)
    hunter_bow(img, dy)
    stamp(img, HUNTER_GRIP, 0, dy)
    stamp(img, HUNTER_DRAW_HAND, -1, dy)
    return img


def hunter_release():
    """쏜 순간: 시위가 펴지고 놓은 손이 앞으로 튕기며, 몸은 반동으로 뒤로 밀리고 활이 들린다."""
    img = Image.new('RGBA', (FW, FH))
    dx, dy = -1, -1
    stamp(img, HUNTER_QUIVER, dx, 0)
    stamp(img, LEGS['stance'], recolor=HUNTER_LEGS)
    stamp(img, HUNTER_TORSO, dx, 0)
    stamp(img, HUNTER_HEAD['b'], dx * 2, 0)
    stamp(img, HUNTER_ARM, dx, dy)
    hunter_bow(img, dy, released=True)
    stamp(img, HUNTER_GRIP, 0, dy)
    stamp(img, HUNTER_DRAW_HAND, dx + 2, dy)
    return img

# ---------------------------------------------------------------- 재의 마녀
# 보라 두건 로브 (얼굴은 그늘 속, 눈 두 점만 빛난다), 살짝 굽은 등, 바닥까지 퍼지는 자락,
# 금빛 여밈, 앞에 짚은 지팡이 끝의 잔불.

WITCH_FEET = {'1': 'B', '2': 'B', '3': 'B', '4': 'B', '5': 'L', '6': 'B'}

WITCH_HOOD = {
    'a': part({
        7: '..........ooo',
        8: '........oopppo',
        9: '......oopppppPo',
        10: '.....opppPPpppPo',
        11: '....oPPPPPPpNNNo',
        12: '.....oPPPPPpNyNyo',
        13: '......oPPPPpNNNo',
        14: '......oPPPPpppo',
    }),
    'b': part({
        7: '..........ooo',
        8: '........oopppo',
        9: '......oopppppPo',
        10: '.....opppPPpppPo',
        11: '...ooPPPPPPpNNNo',
        12: '..oPPPPPPPPpNyNyo',
        13: '...ooooPPPPpNNNo',
        14: '......oPPPPpppo',
    }),
}

WITCH_ROBE = {
    'a': part({
        14: '......oPPPPPPyo',
        15: '.....opPPPPPPNo',
        16: '.....opPPPPPPNo',
        17: '....opPPPPPPPNo',
        18: '....opPPPPPPPNo',
        19: '....opPPPPPPPNo',
        20: '...opPPPPPPPPNo',
        21: '...opPPPPPPPPNNo',
        22: '...opPPPPPPPPNNo',
        23: '..opPPPPPPPPPNNo',
        24: '..opPPPPPPPPPNNNo',
        25: '.opPPPPPPPPPPNNNo',
        26: '.oNNPNNPNNPNNNNNo',
        27: '.ooooooooooooooo',
    }),
    'b': part({   # 달릴 때 자락이 뒤로 휩쓸린다
        14: '......oPPPPPPyo',
        15: '.....opPPPPPPNo',
        16: '.....opPPPPPPNo',
        17: '....opPPPPPPPNo',
        18: '....opPPPPPPPNo',
        19: '...opPPPPPPPPNo',
        20: '...opPPPPPPPPNo',
        21: '..opPPPPPPPPNNo',
        22: '..opPPPPPPPPNNo',
        23: '.opPPPPPPPPPNNo',
        24: 'opPPPPPPPPPNNNo',
        25: 'oNNPNNPNNPNNNo',
        26: '.ooooooooooooo',
    }),
}

# 소매와 지팡이를 쥔 손, 나무 지팡이, 끝의 잔불 (프레임마다 밝은 심이 옮겨 다닌다).
WITCH_ARM = part({
    16: '...........oooo',
    17: '..........oPPPPoo',
    18: '..........oNNNNsso',
    19: '...........ooooooo',
})

EMBER = {
    'a': part({
        5: '...............ooo',
        6: '..............oryro',
        7: '..............orRro',
        8: '...............oRo',
    }),
    'b': part({
        4: '................o',
        5: '...............oyo',
        6: '..............oryRo',
        7: '..............orrRo',
        8: '...............oRo',
    }),
}


def witch_staff(img, dy, flash=False):
    rows = {y: '...............oTo' if y < 17 else '...............oLo' for y in range(9, 27)}
    rows[27] = '...............ooo'
    stamp(img, rows, 0, 0 if dy <= 0 else 0)


def witch(pose, hit=False):
    img = Image.new('RGBA', (FW, FH))
    dy, fl = pose['dy'], (FLASH if hit else None)
    run = pose['legs'] != 'stance'
    hx = -1 if hit else 0
    witch_staff(img, dy)
    stamp(img, EMBER[pose['flap']], 0, pose['arm'] if not hit else -1)
    if run:
        stamp(img, LEGS[pose['legs']], recolor=WITCH_FEET)
    stamp(img, WITCH_ROBE['b' if run else 'a'], hx, dy if run else 0, fl)
    stamp(img, WITCH_HOOD[pose['flap']], hx * 2, dy - hit, fl)
    stamp(img, WITCH_ARM, hx, dy + pose['arm'], fl)
    return img



# 시전 순간 지팡이 끝에서 크게 터지는 잔불 (하얀 심 · 사방 섬광).
EMBER_FLARE = part({
    2: '...............oro',
    3: '..............ooyoo',
    4: '.............ooyHyoo',
    5: '............orryHyrro',
    6: '.............oorRroo',
    7: '..............ooRoo',
    8: '...............ooo',
})


def witch_cast(dx, staff_dy, ember):
    """지팡이를 [staff_dy] 만큼 들고 몸을 [dx] 로 기울인 시전 자세."""
    img = Image.new('RGBA', (FW, FH))
    sx = 1 if dx > 0 else 0
    rows = {y: '...............oTo' if y < 17 else '...............oLo' for y in range(9, 27)}
    rows[27] = '...............ooo'
    stamp(img, rows, sx, staff_dy)
    stamp(img, ember, sx, staff_dy)
    stamp(img, WITCH_ROBE['a'], 0, 0)
    stamp(img, WITCH_HOOD['b' if dx > 0 else 'a'], dx, 0)
    stamp(img, WITCH_ARM, dx, staff_dy)
    return img

# ---------------------------------------------------------------- 시트

def sheet(draw, hit, windup, strike):
    frames = [draw(p) for p in POSES] + [hit(), windup(), strike()]
    out = Image.new('RGBA', (FW * len(frames), FH), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * FW, 0))
    return out


HEROES = {
    'knight': lambda: sheet(knight, knight_hit, knight_windup, knight_strike),
    'witch': lambda: sheet(
        witch,
        lambda: witch(dict(POSES[0], legs='stance', flap='b', arm=0), hit=True),
        lambda: witch_cast(-1, -2, EMBER['b']),
        lambda: witch_cast(1, -1, EMBER_FLARE),
    ),
    'hunter': lambda: sheet(
        hunter,
        lambda: hunter(dict(POSES[0], flap='b', arm=0), hit=True),
        hunter_reload,
        hunter_release,
    ),
}


def main(root):
    for name, build in HEROES.items():
        path = os.path.join(root, f'{name}.png')
        img = build()
        img.save(path)
        print(path, img.size)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join('assets', 'images', 'sprites'))
