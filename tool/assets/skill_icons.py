"""레벨업 카드에 쓰는 기술(무기) · 패시브 아이콘 (16x16) 을 그린다.

python -I tool/assets/skill_icons.py [assets/images/sprites]

- items/skills.png   : 기술 15장 (240x16). 순서는 Dart 의 WeaponId enum 과 같다.
- items/passives.png : 패시브 11장 (176x16). 순서는 Dart 의 PassiveId enum 과 같다.

색은 Endesga 32 (palette.py) 만 쓴다. 빛은 왼쪽 위, 외곽선은 #181425.
그림은 글자 격자(16줄 x 16글자) 또는 좌표 계산으로 만든다. '.' 은 빈칸이고,
칠한 칸 둘레의 빈칸은 자동으로 외곽선이 된다. '#' 은 외곽선 색을 직접 칠한다 (균열 · 눈 구멍).
"""
import math
import os
import sys

# -I 는 스크립트 폴더를 sys.path 에 넣지 않는다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from palette import PALETTE  # noqa: E402

N = 16

# 글자 → Endesga 32 색.
COLORS = {
    '#': '181425',  # 외곽선
    'W': 'ffffff',
    'w': 'c0cbdc',  # 밝은 쇠
    'L': '8b9bb4',  # 쇠
    'M': '5a6988',  # 어두운 쇠
    'D': '3a4466',
    'd': '262b44',
    'f': 'fee761',  # 불: 하양 → 노랑 → 금 → 주황 → 빨강 → 검붉음
    'Y': 'feae34',
    'O': 'f77622',
    'R': 'e43b44',
    'r': 'be4a2f',
    'X': 'a22633',
    'e': 'd77643',
    'T': 'e4a672',  # 밧줄 · 가죽 밝은 면
    't': 'c28569',
    'B': 'b86f50',  # 나무 · 가죽
    'b': '733e39',
    'k': '3e2731',
    'S': 'ead4aa',  # 뼈 · 종이
    's': 'e8b796',  # 살
    'G': '63c74d',  # 잎
    'g': '3e8948',
    'h': '265c42',
    'C': '2ce8f5',  # 번개 · 유리
    'c': '0099db',
    'U': '124e89',
    'P': 'b55088',
    'p': '68386c',
    'Q': 'f6757a',
    'K': 'ff0044',
}
RGB = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in COLORS.items()}
assert all(c in PALETTE for c in RGB.values())
OUTLINE = RGB['#']


# ---------------------------------------------------------------- 도구

def grid(rows=None):
    if rows is None:
        return [['.'] * N for _ in range(N)]
    assert len(rows) == N, len(rows)
    for r in rows:
        assert len(r) == N, (len(r), r)
    return [list(r) for r in rows]


def put(g, x, y, c):
    if 0 <= x < N and 0 <= y < N:
        g[y][x] = c


def stamp(g, ox, oy, rows):
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c != '.':
                put(g, ox + x, oy + y, c)


def render(g):
    img = Image.new('RGBA', (N, N))
    px = img.load()
    for y in range(N):
        for x in range(N):
            if g[y][x] != '.':
                px[x, y] = RGB[g[y][x]] + (255,)
    filled = {(x, y) for y in range(N) for x in range(N) if px[x, y][3]}
    for y in range(N):
        for x in range(N):
            if (x, y) in filled:
                continue
            if any((x + dx, y + dy) in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE + (255,)
    return img


def sheet(frames):
    out = Image.new('RGBA', (N * len(frames), N))
    for i, f in enumerate(frames):
        out.paste(f, (i * N, 0))
    return out


# ---------------------------------------------------------------- 기술

def greatsword():
    """강철 대검: 일반 장검보다 날이 두 배 넓고 가드가 길다."""
    return grid([
        '................',
        '.............Ww.',
        '............WwLM',
        '...........WwLMD',
        '..........WwLMD.',
        '...eY....WwLMD..',
        '....eY..WwLMD...',
        '.....eYWwLMD....',
        '......eYLMD.....',
        '......BeY.......',
        '.....Bb.eY......',
        '....Bb..........',
        '...Bb...........',
        '..Yb............',
        '.Ye.............',
        '................',
    ])


def earth_slam():
    """대지 강타: 망치 머리가 땅을 내려찍고, 금이 가며 돌 조각이 튄다."""
    return grid([
        '................',
        '.......Bb.......',
        '.......Bb.......',
        '...WwwwBbwwwL...',
        '...wLLLLLLLLM...',
        '...wLLLLLLLLM...',
        '...LMMMMMMMMM...',
        '....MMMMMMMM....',
        '......fYYf......',
        '.T..YfWWfY...T..',
        '.TTTTT#WW#TTTTT.',
        '.BBBB#BBBB#BBBB.',
        '.BBB#BBBBBB#BBb.',
        '.BB#BBBBBBBB#bb.',
        '..bbbbbbbbbbbb..',
        '................',
    ])


def cleave():
    """초승달 참격: 바깥 날이 가장 밝고 안쪽으로 식는다. 끝은 가늘게."""
    g = grid()
    cx, cy = 5.0, 7.5
    for y in range(N):
        for x in range(N):
            d1 = math.hypot(x - cx, y - cy)
            d2 = math.hypot(x - (cx - 3.2), y - cy)
            if d1 <= 7.6 and d2 > 6.4 and 1 <= x <= 14 and 1 <= y <= 14:
                edge = 7.6 - d1
                c = 'W' if edge < 0.9 else 'f' if edge < 1.9 else 'Y' if edge < 2.9 else 'O'
                put(g, x, y, c)
    return g


def war_cry():
    """전투 함성: 입을 벌린 투구 + 양옆으로 퍼지는 금빛 함성 선."""
    return grid([
        '................',
        '................',
        '......WwwL......',
        '.....WwwLLL.....',
        '.Y..WwwLLLLM..Y.',
        '..Y.wwLLLLLM.Y..',
        '....fYYYYYYO....',
        '....w##LL##M....',
        '.ff.wLL##LLM.ff.',
        '....wL####LM....',
        '..Y.LL####MM.Y..',
        '.Y...M####M...Y.',
        '......MMMM......',
        '................',
        '................',
        '................',
    ])


def ember_orb():
    """잔불 구체: 하얀 속의 둥근 불덩이가 오른쪽으로 날며 꼬리를 끈다 (수평)."""
    return grid([
        '................',
        '................',
        '................',
        '..........R.....',
        '......RROOYYO...',
        '..R.RROOYYffYO..',
        '.RRROOOYYfWWfYO.',
        '.XRRROOYYfWWfYO.',
        '..XRROOYYffffYR.',
        '.....XRROOYYYOR.',
        '...R....XRROOR..',
        '................',
        '................',
        '................',
        '................',
        '................',
    ])


def meteor():
    """운석 낙하: 아래 오른쪽으로 떨어지는 바위, 위 왼쪽으로 끄는 불꼬리 (대각선)."""
    g = grid()
    rx, ry = 10.2, 10.2
    for y in range(N):
        for x in range(N):
            u = ((rx - x) + (ry - y)) / math.sqrt(2)  # 꼬리 축을 따라 바위에서 멀어진 거리
            v = ((x - rx) - (y - ry)) / math.sqrt(2)  # 축에서 벗어난 거리
            if 0 < u < 12.5:
                t = u / 12.5
                w = 3.0 * (1 - t) + 0.4 + 0.5 * math.sin(u * 1.7) * t
                if abs(v) <= w:
                    heat = (1 - t) * (1 - abs(v) / max(w, 0.01) * 0.8)
                    c = ('f' if heat > 0.62 else 'Y' if heat > 0.45 else 'O' if heat > 0.28
                         else 'R' if heat > 0.12 else 'X')
                    put(g, x, y, c)
    for y in range(N):
        for x in range(N):
            if math.hypot(x - rx, y - ry) <= 3.3:
                lit = (rx - x) + (ry - y)
                put(g, x, y, 'T' if lit > 2.6 else 'B' if lit > 0.5 else 'b' if lit > -2.0 else 'k')
    for x, y in ((10, 10), (11, 11), (9, 11), (12, 9)):
        put(g, x, y, 'O')
    put(g, 11, 10, 'Y')
    return g


def fire_tornado():
    """화염 회오리: 아래 좁고 위로 넓은 깔때기. 두 줄씩 고리가 좌우로 엇갈려 감아 오른다."""
    g = grid()
    rings = [(1, 0, 6.0), (3, 1, 5.0), (5, 0, 4.0), (7, -1, 3.0), (9, 0, 2.0), (11, 1, 1.0)]
    for top, off, hw in rings:
        cx = 7.5 + off
        for dy in (0, 1):
            y = top + dy
            w = hw - dy * 0.5
            for x in range(N):
                if abs(x - cx) <= w:
                    t = (x - cx + w) / (2 * w + 0.01)  # 0 왼쪽(밝음) → 1 오른쪽(어두움)
                    if dy == 0:
                        c = 'f' if t < 0.3 else 'Y' if t < 0.65 else 'O' if t < 0.9 else 'R'
                    else:
                        c = 'Y' if t < 0.25 else 'O' if t < 0.6 else 'R' if t < 0.9 else 'X'
                    put(g, x, y, c)
    for x, c in zip(range(5, 11), 'ROYYOR'):
        put(g, x, 13, c)
    for x, y, c in ((3, 13, 'R'), (12, 13, 'R'), (4, 12, 'O'), (11, 12, 'O'), (2, 11, 'X'),
                    (13, 11, 'X'), (3, 0, 'R'), (12, 0, 'R'), (7, 0, 'O')):
        put(g, x, y, c)
    return g


def ember_spirits():
    """잔불 정령: 눈 달린 작은 불꽃 둘이 서로를 돈다 (점선 궤도)."""
    sp = [
        '..R...',
        '..OR..',
        '.OYOR.',
        'OYffOR',
        'O#fY#R',
        'OYffOR',
        '.OOOR.',
    ]
    g = grid()
    stamp(g, 1, 1, sp)
    stamp(g, 9, 8, sp)
    for x, y in ((10, 2), (12, 3), (13, 5), (2, 10), (3, 12), (5, 13)):
        put(g, x, y, 'Y')
    return g


def fire_crossbow():
    """사냥 석궁: 위에서 본 석궁, 화살촉에 불."""
    return grid([
        '.......O........',
        '......OfO.......',
        '......WLLL......',
        '....TTTBBttt....',
        '..TTBBBBBBBBtt..',
        '.TB...SBBS...bt.',
        '.T...S.BB.S...t.',
        '..S.S..Bb..S.S..',
        '...S...Bb...S...',
        '......LBbL......',
        '.......Bb.......',
        '.......Bb.......',
        '......BBbb......',
        '......Bbbb......',
        '.......bb.......',
        '................',
    ])


def ember_mine():
    """불씨 덫: 땅에 묻는 둥근 쇠 지뢰. 틈으로 불씨가 비치고 위 심지에 불이 붙었다."""
    return grid([
        '................',
        '........R.......',
        '.......RO.......',
        '.......OY.......',
        '.......fY.......',
        '......wLLM......',
        '....wLLLLMMD....',
        '...wLwLLLLMMD...',
        '..wLLLLLLLMMDD..',
        '..LRRORYfYORRd..',
        '.LwMMMMMMMMMDDd.',
        '..DDDDDDDDDDdd..',
        '.L.L........d.d.',
        '................',
        '................',
        '................',
    ])


def throwing_knives():
    """투척 단검: 손잡이를 모아 부채꼴로 편 단검 셋."""
    g = grid()
    px, py = 7.5, 14.0
    for ang in (-32, 32, 0):
        a = math.radians(ang)
        dx, dy = math.sin(a), -math.cos(a)
        nx, ny = math.cos(a), math.sin(a)
        for i in range(0, 26):
            r = i * 0.5
            cx, cy = px + dx * r, py + dy * r
            if r < 3.5:
                put(g, round(cx - 0.5), round(cy - 0.5), 'R' if i % 2 else 'X')
            elif r < 4.5:
                for k in (-1.5, -0.5, 0.5, 1.5):
                    put(g, round(cx + nx * k - 0.5), round(cy + ny * k - 0.5), 'Y')
            elif r < 12.5:
                put(g, round(cx - 0.5 - nx * 0.5), round(cy - 0.5 - ny * 0.5), 'W')
                put(g, round(cx - 0.5 + nx * 0.5), round(cy - 0.5 + ny * 0.5), 'L')
    return g


def snare_net():
    """올가미 그물: 둥글게 펼친 밧줄 격자, 매듭은 어둡게, 네 귀퉁이에 돌 추."""
    g = grid()
    for y in range(N):
        for x in range(N):
            d = math.hypot(x - 7.5, y - 7.5)
            if d > 6.2:
                continue
            a, b = x % 3 == 1, y % 3 == 1
            if d > 5.3:
                put(g, x, y, 'T' if x + y < 15 else 't')
            elif a and b:
                put(g, x, y, 'B')
            elif a or b:
                put(g, x, y, 'T' if x + y < 15 else 't')
    for x, y in ((1, 1), (13, 1), (1, 13), (13, 13)):
        stamp(g, x, y, ['wL', 'LM'])
    return g


def ash_aura():
    """잿불 고리: 비스듬히 본 불 고리, 위로 불꽃 혀가 솟는다. 가운데는 비었다."""
    g = grid()
    cx, cy, rx, ry = 7.5, 9.5, 6.4, 3.6
    for y in range(N):
        for x in range(N):
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            if 0.66 <= d <= 1.05:
                front = y > cy
                put(g, x, y, ('f' if d < 0.85 else 'Y') if front else ('O' if d < 0.85 else 'R'))
    tongues = {1: 2, 2: 4, 3: 2, 5: 3, 7: 5, 8: 3, 10: 4, 12: 2, 13: 3, 14: 1}
    for x, h in tongues.items():
        top = next((y for y in range(N) if g[y][x] != '.'), None)
        if top is None:
            continue
        for k in range(1, h + 1):
            put(g, x, top - k, 'R' if k == h else 'O' if k > h / 2 else 'Y')
    return g


def thunder():
    """낙뢰: 굵은 지그재그 번개."""
    return grid([
        '................',
        '........WWff....',
        '.......WffY.....',
        '......WffY......',
        '.....WffY.......',
        '....WfffffffY...',
        '.......WffYY....',
        '......WffY......',
        '.....WfY........',
        '....WfY.........',
        '...WY...........',
        '..W.............',
        '................',
        '................',
        '................',
        '................',
    ])


def chakram():
    """회전 차크람: 쇠 고리 + 시계 방향으로 휜 날 4개 + 금 손잡이."""
    g = grid()
    cx = cy = 7.5
    for y in range(N):
        for x in range(N):
            d = math.hypot(x - cx, y - cy)
            if 2.6 <= d <= 5.0:
                a = math.atan2(y - cy, x - cx)
                lit = -math.cos(a + math.radians(45))  # 왼쪽 위가 밝다
                c = 'W' if lit > 0.6 else 'w' if lit > 0.0 else 'L' if lit > -0.6 else 'M'
                put(g, x, y, c)
    blade = [(7, 2), (8, 2), (9, 2), (10, 2), (10, 1), (11, 1), (12, 1)]
    for turn, c in enumerate('wLMw'):
        for x, y in blade:
            for _ in range(turn):
                x, y = 15 - y, x  # 가운데를 축으로 90도 돌린다
            put(g, x, y, c)
    for x, y in ((3, 7), (3, 8), (12, 7), (12, 8)):
        put(g, x, y, 'Y')
    return g


SKILLS = [greatsword, earth_slam, cleave, war_cry, ember_orb, meteor, fire_tornado,
          ember_spirits, fire_crossbow, ember_mine, throwing_knives, snare_net, ash_aura,
          thunder, chakram]


# ---------------------------------------------------------------- 패시브

def vitality():
    """단련된 육체: 하트."""
    return grid([
        '................',
        '................',
        '...QQR....RRR...',
        '..QWQRR..RRRRX..',
        '..QWRRRRRRRRRX..',
        '..QRRRRRRRRRRX..',
        '..RRRRRRRRRRXX..',
        '...RRRRRRRRRX...',
        '....RRRRRRRX....',
        '.....RRRRXX.....',
        '......RRXX......',
        '.......XX.......',
        '................',
        '................',
        '................',
        '................',
    ])


def swiftness():
    """재바람: 발목에 날개 달린 장화 + 뒤로 남는 바람 선."""
    return grid([
        '................',
        '................',
        '.WWW...TTTT.....',
        '..WWWw.TBBb.....',
        '.WWWWwwTBBb.....',
        '..wwwwwTBBb.....',
        '...LLLwTBBb.....',
        '.....LMTBBb.....',
        '.......TBBBb....',
        '.ww....TBBBBBb..',
        '.......TBBBBBBb.',
        '..www..bbbbbbbb.',
        '.......kkkkkkkk.',
        '................',
        '................',
        '................',
    ])


def magnetism():
    """불씨 끌림: 말굽 자석이 불씨를 끌어당긴다."""
    return grid([
        '................',
        '...........fY...',
        '..........fWYO..',
        '..Y..Y....YYOR..',
        '...........OR...',
        '.wwL..wwL.......',
        '.wwL..wwL.......',
        '.QRX..QRX.......',
        '.QRX..QRX.......',
        '.QRX..QRX.......',
        '.QRRX.RRX.......',
        '.QRRRRRRX.......',
        '..RRRRRX........',
        '...XXXX.........',
        '................',
        '................',
    ])


def fury():
    """타오르는 의지: 불길에 싸인 주먹."""
    return grid([
        '................',
        '....R....R......',
        '...RO...RO..R...',
        '...OY.R.OYR.OR..',
        '..ROYROROYOROY..',
        '..OYYYOYYYOYYO..',
        '...SsbSsbSsbSt..',
        '...ssbssbssbst..',
        '...ttbttbttbtb..',
        '..SSSSSSSsttttb.',
        '..sssssssbtttbb.',
        '...ttttttttttb..',
        '....tttttttbb...',
        '.....LLLLLLM....',
        '.....MMMMMMM....',
        '................',
    ])


def haste():
    """날랜 손: 모래가 흐르는 모래시계 (재사용 대기)."""
    return grid([
        '................',
        '..fYYYYYYYYYYO..',
        '..eeeeeeeeeeee..',
        '..B.wDDDDDDd.b..',
        '..B.wDDDDDDd.b..',
        '..B..wYYYYd..b..',
        '..B...wYYd...b..',
        '..B....Yd....b..',
        '..B...wYDd...b..',
        '..B..wDYDDd..b..',
        '..B.wDDYDDDd.b..',
        '..B.wDYYYYDd.b..',
        '..B.wYYYYYYd.b..',
        '..fYYYYYYYYYYO..',
        '..eeeeeeeeeeee..',
        '................',
    ])


def keen_eye():
    """매의 눈: 호박색 눈 + 위아래 조준 눈금."""
    return grid([
        '.......R........',
        '.......R........',
        '................',
        '................',
        '.....wwwwww.....',
        '...wwwYYYYwwL...',
        '..wwwYOkkOYwwL..',
        '.wwwwOkWkkOwwLL.',
        '..wwwYOkkOYwLL..',
        '...wwwYYYYwLL...',
        '.....LLLLLL.....',
        '................',
        '................',
        '.......R........',
        '.......R........',
        '................',
    ])


def brutality():
    """처형자의 낙인: 붉은 눈의 해골."""
    return grid([
        '................',
        '................',
        '.....SSSSST.....',
        '....SSSSSSTT....',
        '...SSSSSSSSTt...',
        '...SSSSSSSTTt...',
        '...SkkkSkkkTt...',
        '...SkRkSkRkTt...',
        '...SSkSSSkTTt...',
        '....SSSkSTTt....',
        '.....STTTTt.....',
        '.....SkSkSt.....',
        '.....TTTTTt.....',
        '................',
        '................',
        '................',
    ])


def iron_skin():
    """잿빛 갑주: 가운데 능선이 선 쇠 방패."""
    return grid([
        '................',
        '..WwwwwwwwwwwL..',
        '..wLLLLwMLLLLM..',
        '..wLLLLwMLLLLM..',
        '..wLLLLwMLLLLM..',
        '..wLLLLwMLLLLM..',
        '..wLLLLwMLLLLM..',
        '..wLLLLwMLLLLM..',
        '...wLLLwMLLLM...',
        '...wLLLwMLLLM...',
        '....wLLwMLLM....',
        '.....wLwMLM.....',
        '......wwMM......',
        '.......wM.......',
        '................',
        '................',
    ])


def regrowth():
    """재생의 불씨: 초록 잎 + 밑동의 작은 불씨."""
    g = grid()
    p0, p1 = (2.5, 11.5), (13.0, 1.5)
    mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    nx, ny = 1 / math.sqrt(2), 1 / math.sqrt(2)
    half_len, half_w = math.dist(p0, p1) / 2, 3.0
    r = (half_len ** 2 + half_w ** 2) / (2 * half_w)
    off = r - half_w
    for y in range(N):
        for x in range(N):
            if (math.hypot(x - (mx + nx * off), y - (my + ny * off)) <= r and
                    math.hypot(x - (mx - nx * off), y - (my - ny * off)) <= r):
                side = (x - mx) * nx + (y - my) * ny
                put(g, x, y, 'G' if side < -0.5 else 'g' if side > 0.5 else 'S')
    for x, y in ((2, 12), (1, 13), (1, 14)):
        put(g, x, y, 'g')
    stamp(g, 10, 9, ['..R.', '.RO.', '.OYR', 'OYfO', 'RYWY', '.OYO'])
    return g


def wisdom():
    """배움의 재: 펼친 책 위로 깨달음의 불티가 오른다."""
    return grid([
        '................',
        '.......f........',
        '....Y.......Y...',
        '........C.......',
        '................',
        '..SSSS....SSSS..',
        '.SSSSSSttSSSSSs.',
        '.SttttStSttttSs.',
        '.SSSSSStSSSSSSs.',
        '.SttttStSttttSs.',
        '.SSSSSStSSSSSSs.',
        '.UUUUUUtUUUUUUU.',
        '..UUUUUbUUUUUU..',
        '................',
        '................',
        '................',
    ])


def spread():
    """번지는 불길: 가운데 불꽃에서 네 방향으로 퍼지는 화살표."""
    return grid([
        '................',
        '.YYO........OYY.',
        '.YO..........OY.',
        '.O.O........O.O.',
        '....O......O....',
        '.......R........',
        '......ROR.......',
        '......OYO.......',
        '.....OYfYO......',
        '.....OfWfO......',
        '......OYO.......',
        '....O......O....',
        '.O.O........O.O.',
        '.YO..........OY.',
        '.YYO........OYY.',
        '................',
    ])


PASSIVES = [vitality, swiftness, magnetism, fury, haste, keen_eye, brutality, iron_skin,
            regrowth, wisdom, spread]


def write(out):
    os.makedirs(f'{out}/items', exist_ok=True)
    sheet([render(f()) for f in SKILLS]).save(f'{out}/items/skills.png', optimize=True)
    sheet([render(f()) for f in PASSIVES]).save(f'{out}/items/passives.png', optimize=True)


if __name__ == '__main__':
    write(sys.argv[1] if len(sys.argv) > 1 else 'assets/images/sprites')
    print('items/skills.png, items/passives.png done')
