"""소리 기록(tool/sound/mix_test.dart)을 실제 소리 파일로 섞어 "플레이 중에 들리는 소리"를 만들고 잰다.

    python -I tool/sound/mix.py <기록.jsonl> [--out build/sound] [--from 초] [--to 초]

- <이름>.ogg: 섞은 결과. 직접 들어 보는 용도.
- 화면 출력:
  - 전체 · 전투 구간의 크기 (K 가중 RMS, dBFS) 와 최고점, 클리핑 (|x| > 1) 비율
  - 효과음별 울린 수 · 분당 수 · 믹스에서 차지하는 에너지 비율 (무엇이 소리를 덮는가)
  - 배경음 대 효과음 크기 차 (전투 중, 1초 창 기준 중앙값)
  - 가장 시끄러운 1초 창들과 그때 울린 소리
- 레벨업 · 클리어 화면처럼 게임이 멈춘 순간은 기록에 시간이 흐르지 않으므로,
  배경음이 줄어드는 순간마다 [PAUSE] 초씩 시간을 벌려 사람이 고르는 시간을 흉내 낸다.
- 엔진(SoLoud)은 섞은 결과를 [-1, 1] 로 자르므로 1 을 넘으면 깨져 들린다.
"""

import argparse
import collections
import json
import os
import sys

import numpy as np
import soundfile

RATE = 44100
PAUSE = 1.2


def load(path, cache={}):
    if path not in cache:
        x, rate = soundfile.read(path, dtype="float64", always_2d=False)
        if x.ndim > 1:
            x = x.mean(axis=1)
        assert rate == RATE, (path, rate)
        cache[path] = x
    return cache[path]


def resample(x, speed):
    if abs(speed - 1) < 1e-6:
        return x
    n = int(len(x) / speed)
    return np.interp(np.arange(n) * speed, np.arange(len(x)), x)


def k_weight(x):
    """ITU-R BS.1770 의 K 가중을 주파수 영역에서 흉내 낸다 (100Hz 아래를 줄이고 2kHz 위를 +4dB)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    hp = (f / 100) ** 2 / (1 + (f / 100) ** 2)
    shelf = 1 + (10 ** (4 / 20) - 1) / (1 + (2000 / np.maximum(f, 1)) ** 2)
    return np.fft.irfft(spec * hp * shelf, len(x))


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def windows(x, size):
    n = len(x) // size
    return x[: n * size].reshape(n, size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline")
    ap.add_argument("--out", default=os.path.join("build", "sound"))
    ap.add_argument("--from", dest="start", type=float, default=0)
    ap.add_argument("--to", dest="end", type=float, default=None)
    args = ap.parse_args()

    events = [json.loads(line) for line in open(args.timeline, encoding="utf-8")]

    # 멈춘 순간마다 시간을 벌린다.
    shift, last_vol = 0.0, None
    for e in events:
        if e["kind"] == "musicVol":
            if last_vol is not None and e["vol"] < last_vol * 0.9:
                shift += PAUSE
            last_vol = e["vol"]
        elif e["kind"] == "music":
            last_vol = e["vol"]
        e["t"] += shift
    end = args.end if args.end is not None else events[-1]["t"] + 3
    events = [e for e in events if args.start <= e["t"] < end]
    length = int((end - args.start) * RATE)

    sfx = np.zeros(length)
    per_sound = collections.defaultdict(lambda: np.zeros(length))
    counts = collections.Counter()

    # 배경음: 곡마다 (시작, 음량 변화 목록) 을 모아 반복 재생하며 음량 곡선을 입힌다.
    music = np.zeros(length)
    tracks = []  # [asset, start_sample, [(sample, target_vol, fade_samples)], stop_sample]
    current = None
    for e in events:
        at = int((e["t"] - args.start) * RATE)
        if e["kind"] == "sfx":
            x = resample(load(e["asset"]), e["speed"]) * e["vol"]
            n = min(len(x), length - at)
            if n <= 0:
                continue
            per_sound[e["name"]][at:at + n] += x[:n]
            counts[e["name"]] += 1
        elif e["kind"] == "music":
            fade = int(e["fade"] * RATE)
            if current is not None:
                current[2].append((at, 0.0, fade))
                current[3] = at + fade
            current = None
            if e["asset"]:
                current = [e["asset"], at, [(at, e["vol"], fade)], length]
                tracks.append(current)
        elif e["kind"] == "musicVol" and current is not None:
            current[2].append((at, e["vol"], max(1, int(e["fade"] * RATE))))

    for asset, start, ramps, stop in tracks:
        song = load(asset)
        span = max(0, min(stop, length) - start)
        if span == 0:
            continue
        loop = np.resize(song, span)
        gain = np.zeros(span)
        level = 0.0
        points = sorted(ramps)
        for i, (at, target, fade) in enumerate(points):
            s = at - start
            nxt = points[i + 1][0] - start if i + 1 < len(points) else span
            ramp_end = min(s + fade, nxt, span)
            if s >= span:
                break
            gain[s:ramp_end] = np.linspace(level, target, fade, endpoint=False)[: ramp_end - s]
            gain[ramp_end:nxt] = target
            level = target
        music[start:start + span] += loop * gain

    for x in per_sound.values():
        sfx += x
    mix = sfx + music

    os.makedirs(args.out, exist_ok=True)
    name = os.path.splitext(os.path.basename(args.timeline))[0]
    with soundfile.SoundFile(os.path.join(args.out, f"{name}.ogg"), "w", RATE, 1,
                             format="OGG", subtype="VORBIS") as f:
        clipped = np.clip(mix, -1, 1)
        for i in range(0, len(clipped), 8192):
            f.write(clipped[i:i + 8192])

    # ---- 재기 ----
    second = RATE
    kmix, ksfx, kmusic = k_weight(mix), k_weight(sfx), k_weight(music)
    rms = lambda w: np.sqrt(np.mean(w ** 2, axis=1))
    mix_s, sfx_s, music_s = rms(windows(kmix, second)), rms(windows(ksfx, second)), rms(windows(kmusic, second))
    playing = music_s > 1e-4

    print(f"길이 {length / RATE:.0f}s, 효과음 {sum(counts.values())}번")
    print(f"전체 크기 {db(np.sqrt(np.mean(kmix ** 2))):6.1f} dBFS   최고점 {np.max(np.abs(mix)):.2f}   "
          f"클리핑 {np.mean(np.abs(mix) > 1) * 100:.3f}% 샘플")
    print(f"1초 창 크기: 중앙값 {db(np.median(mix_s)):.1f}  상위 5% {db(np.percentile(mix_s, 95)):.1f}  "
          f"최고 {db(mix_s.max()):.1f} dBFS")
    both = playing & (sfx_s > 1e-4)
    if both.any():
        gap = [db(s) - db(m) for s, m in zip(sfx_s[both], music_s[both])]
        print(f"효과음 - 배경음 (배경음이 나오는 1초 창 중앙값) {np.median(gap):+.1f} dB   "
              f"배경음 {db(np.median(music_s[playing])):.1f} / 효과음 {db(np.median(sfx_s[both])):.1f} dBFS")

    total = sum(float(np.sum(k_weight(x) ** 2)) for x in per_sound.values()) or 1
    minutes = length / RATE / 60
    print("\n효과음        횟수   분당   에너지   1회 크기(dBFS)")
    rows = []
    for key, x in per_sound.items():
        energy = float(np.sum(k_weight(x) ** 2))
        rows.append((energy, key))
    for energy, key in sorted(rows, reverse=True):
        per_hit = np.sqrt(energy / counts[key] / RATE)  # 1초에 펼친 1회분의 RMS
        print(f"{key:12s} {counts[key]:5d} {counts[key] / minutes:6.1f} {energy / total * 100:6.1f}%   {db(per_hit):6.1f}")

    print("\n가장 시끄러운 1초 창")
    for i in np.argsort(mix_s)[::-1][:6]:
        t0 = args.start + i
        names = collections.Counter(e["name"] for e in events
                                    if e["kind"] == "sfx" and t0 <= e["t"] < t0 + 1)
        top = ", ".join(f"{k}×{v}" for k, v in names.most_common(5))
        print(f"  {t0:6.0f}s  {db(mix_s[i]):6.1f} dBFS  최고점 {np.max(np.abs(mix[i * second:(i + 1) * second])):.2f}  {top}")
    print(f"\n→ {os.path.join(args.out, name + '.ogg')}")


if __name__ == "__main__":
    sys.exit(main())
