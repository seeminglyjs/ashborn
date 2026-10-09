"""캠페인 CSV 들을 읽어 플레이 시간별로 깬 스테이지 수를 보여 준다.

python3 tool/balance_sim/summarize.py /tmp/sim/*.csv
같은 이름(시드만 다른) 파일끼리 평균을 낸다: 파일 이름이 NAME_sN.csv 꼴이면 NAME 으로 묶는다.
"""
import csv
import re
import sys
from collections import defaultdict

MARKS = [30, 60, 120, 240, 360, 480]


def cleared_by(rows, minutes):
    best = 0
    for r in rows:
        if float(r['minutes']) <= minutes:
            best = max(best, int(r['frontier']))
    return best


groups = defaultdict(list)
for path in sys.argv[1:]:
    rows = list(csv.DictReader(open(path)))
    if not rows:
        continue
    name = re.sub(r'_s\d+$', '', path.rsplit('/', 1)[-1].removesuffix('.csv'))
    groups[name].append(rows)

for name, runs in sorted(groups.items()):
    end = min(float(rs[-1]['minutes']) for rs in runs)
    cells = []
    for m in MARKS:
        if m > end + 1:
            break
        avg = sum(cleared_by(rs, m) for rs in runs) / len(runs)
        cells.append(f'{m // 60}h:{avg:.1f}' if m >= 60 else f'{m}m:{avg:.1f}')
    stones = sum(int(r['stones']) for rs in runs for r in rs) / len(runs)
    print(f'{name:28} seeds {len(runs)}  깬 스테이지 ' + '  '.join(cells)
          + f'  | 번 강화석 {stones:.0f}')
