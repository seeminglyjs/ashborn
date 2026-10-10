"""Ashborn 효과음을 합성한다 (sfxr 식 칩튠 합성).

    python -I tool/sound/sfx.py [출력 폴더] [이름 ...]

- 기본 출력은 assets/audio/sfx. 이름을 주면 그 소리만 다시 만든다.
- 44.1kHz 16비트 모노 WAV. 파일 이름은 lib/services/audio.dart 의 Sfx 와 같아야 한다.
- 녹음 · 외부 음원을 쓰지 않고 이 스크립트가 직접 만들므로 라이선스 걱정이 없다.
- 소리마다 시드가 고정이라 같은 코드는 늘 같은 파일을 만든다. 소리를 고치려면 아래 함수의 수치를 바꾼다.
- 같은 소리가 몇 번이고 겹치는 게임이라 타격 · 줍기처럼 자주 나는 소리는 짧고 부드럽게,
  보스 · 전리품처럼 드문 보상일수록 길고 화려하게 만든다.
"""

import os
import sys
import wave
import zlib

import numpy as np

RATE = 44100
_rng = np.random.default_rng(7)

_NOTES = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
          "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def note(name):
    """'A4' → 440Hz. 반음은 '#' 으로 쓴다."""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((_NOTES[pitch] + (octave - 4) * 12) / 12)


def samples(dur):
    return int(RATE * dur)


def sweep(f0, f1, dur, vibrato=0.0, rate=0.0):
    """f0 에서 f1 로 지수 곡선을 따라 움직이는 샘플별 주파수. [vibrato] 는 비율 (0.05 = ±5%)."""
    n = samples(dur)
    freq = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    if vibrato:
        freq = freq * (1 + vibrato * np.sin(2 * np.pi * rate * np.arange(n) / RATE))
    return freq


def tone(freq, dur=None, kind="square", duty=0.5):
    """[freq] 는 상수 또는 샘플별 배열."""
    if np.isscalar(freq):
        freq = np.full(samples(dur), float(freq))
    phase = np.cumsum(freq) / RATE
    p = phase % 1
    if kind == "square":
        return np.where(p < duty, 1.0, -1.0)
    if kind == "saw":
        return 2 * p - 1
    if kind == "tri":
        return 1 - 4 * np.abs(p - 0.5)
    return np.sin(2 * np.pi * phase)


def noise(freq, dur=None):
    """sfxr 식 잡음: 반 주기마다 새 값을 뽑아 붙든다. 주파수가 낮을수록 거칠고 둔하다."""
    if np.isscalar(freq):
        freq = np.full(samples(dur), float(freq))
    idx = np.floor(np.cumsum(freq) / RATE * 2).astype(int)
    return _rng.uniform(-1, 1, idx[-1] + 1)[idx]


def env(dur, attack=0.002, hold=0.0, curve=2.0):
    """짧게 올라갔다가 [hold] 동안 버티고 (1-x)^curve 로 사라지는 음량 곡선."""
    n = samples(dur)
    a, h = samples(attack), samples(hold)
    out = np.empty(n)
    out[:a] = np.linspace(0, 1, a, endpoint=False)
    out[a:a + h] = 1
    rest = n - a - h
    out[a + h:] = (1 - np.linspace(0, 1, rest)) ** curve
    return out


def tremolo(n, rate, depth):
    return 1 - depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * np.arange(n) / RATE))


def lowpass(x, cutoff):
    """한 극 저역 통과. 사각파의 날카로운 끝을 깎는다."""
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(x)
    y = 0.0
    for i, v in enumerate(x):
        y += a * (v - y)
        out[i] = y
    return out


def echo(x, delay=0.09, feedback=0.35, taps=4):
    """메아리 몇 번. 드문 큰 소리에 공간감을 준다."""
    d = samples(delay)
    out = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k:d * k + len(x)] += x * feedback ** k
    return out


def mix(dur, *parts):
    """(시작 초, 신호) 들을 [dur] 길이 버퍼에 겹친다. 넘치는 꼬리는 자른다."""
    out = np.zeros(samples(dur))
    for at, sig in parts:
        s = samples(at)
        end = min(len(out), s + len(sig))
        out[s:end] += sig[:end - s]
    return out


def ping(freq, dur, kind="tri", attack=0.002, curve=2.5, duty=0.5):
    return tone(freq, dur, kind, duty) * env(dur, attack, curve=curve)


def arp(notes, step, dur, kind="square", duty=0.5, curve=2.0, last=None):
    """[notes] 를 [step] 초 간격으로 차례로 울린다. [last] 를 주면 마지막 음만 그만큼 길게."""
    parts = []
    for i, name in enumerate(notes):
        length = last if (last and i == len(notes) - 1) else step * 1.6
        parts.append((i * step, ping(note(name), length, kind, curve=curve, duty=duty)))
    return mix(dur, *parts)


# ---- 전투 -------------------------------------------------------------------


def hit():
    d = 0.06
    body = tone(sweep(520, 180, d), kind="square") * env(d, 0.001, curve=2)
    click = mix(d, (0, noise(3000, 0.025) * env(0.025, 0.001) * 0.5))
    return lowpass(body * 0.6 + click, 3500)


def crit():
    d = 0.12
    body = tone(sweep(1100, 380, d), kind="square", duty=0.25) * env(d, 0.001, curve=2)
    spark = mix(d, (0, noise(6000, 0.04) * env(0.04, 0.001) * 0.6),
                (0.005, ping(1760, 0.1, "tri", curve=3) * 0.5))
    return lowpass(body * 0.6 + spark, 6000)


def kill():
    d = 0.17
    puff = noise(sweep(4000, 500, d)) * env(d, 0.001, curve=2.5)
    thump = tone(sweep(180, 50, d), kind="square") * env(d, 0.001, curve=3) * 0.5
    return lowpass(puff + thump, 3000)


def hurt():
    d = 0.26
    body = tone(sweep(340, 110, d, vibrato=0.08, rate=30), kind="saw") * env(d, 0.002, curve=1.5)
    crack = mix(d, (0, noise(2000, 0.08) * env(0.08, 0.001) * 0.7))
    return lowpass(body + crack, 2500)


def block():
    d = 0.22
    e = env(d, 0.001, curve=3)
    return (tone(1900, d, "tri") + tone(2850, d, "sine") * 0.5 + tone(4100, d, "sine") * 0.25) * e


def boss_appear():
    d = 1.7
    n = samples(d)
    drone = (tone(sweep(55, 49, d), kind="saw") + tone(sweep(82.4, 73.4, d), kind="saw") * 0.7)
    drone = lowpass(drone * tremolo(n, 6, 0.5) * env(d, 0.25, hold=0.6, curve=1.5), 700)
    swell = lowpass(noise(sweep(300, 3000, d)), 2000) * np.linspace(0, 1, n) ** 2 * env(d, 0.01, hold=1.2, curve=1)
    sting = mix(d, (0, ping(note("D#3"), 1.2, "square", attack=0.01, curve=1.5, duty=0.3) * 0.35))
    return drone + swell * 0.35 + lowpass(sting, 1200)


def boss_down():
    d = 1.4
    boom = noise(sweep(2500, 120, d)) * env(d, 0.002, curve=2.2)
    drop = tone(sweep(120, 30, d), kind="sine") * env(d, 0.002, curve=1.8)
    return lowpass(echo(boom * 0.9 + drop, 0.11, 0.3, 3)[:samples(d)], 2600)


# ---- 줍기 · 보상 -------------------------------------------------------------


def shard():
    d = 0.07
    f = sweep(1320, 1480, d)
    return (tone(f, kind="sine") + tone(f, kind="tri") * 0.4) * env(d, 0.001, curve=2)


def coin():
    d = 0.3
    f = np.where(np.arange(samples(d)) < samples(0.06), note("B5"), note("E6"))
    return lowpass(tone(f, kind="square") * env(d, 0.002, hold=0.05, curve=1.5), 5000)


def gem():
    d = 0.4
    return mix(d,
               (0, ping(note("G6"), 0.2, "tri")),
               (0.05, ping(note("C7"), 0.35, "tri", curve=2)),
               (0.05, ping(note("G7"), 0.3, "sine", curve=3) * 0.3))


def heal():
    return arp(["C5", "E5", "G5", "C6"], 0.06, 0.5, kind="tri", curve=1.8, last=0.3) * 0.9


def magnet():
    d = 0.45
    f = sweep(220, 1400, d, vibrato=0.05, rate=18)
    return lowpass(tone(f, kind="square", duty=0.25) * env(d, 0.08, curve=1.5), 3000)


def crate():
    d = 0.24
    snap = lambda: noise(sweep(1600, 400, 0.05)) * env(0.05, 0.001, curve=2)
    body = tone(sweep(140, 90, 0.15), kind="tri") * env(0.15, 0.001, curve=2) * 0.6
    return lowpass(mix(d, (0, snap()), (0.035, snap() * 0.7), (0.08, snap() * 0.5), (0, body)), 3500)


def equip():
    d = 0.16
    return mix(d,
               (0, noise(5000, 0.02) * env(0.02, 0.001) * 0.4),
               (0, ping(note("E5"), 0.06, "tri")),
               (0.05, ping(note("A5"), 0.11, "tri")))


def loot_normal():
    d = 0.18
    return tone(sweep(880, 700, d), kind="tri") * env(d, 0.001, curve=2.5) * 0.8


def loot_rare():
    d = 0.5
    return mix(d,
               (0, ping(note("A5"), 0.3, "tri", curve=2)),
               (0.08, ping(note("E6"), 0.42, "tri", curve=2)),
               (0.08, ping(note("E6"), 0.42, "sine", curve=2.5) * 0.4))


def loot_hero():
    d = 0.8
    chime = arp(["E5", "A5", "C#6", "E6"], 0.06, d, kind="tri", curve=2, last=0.55)
    shimmer = tone(note("E7"), d, "sine") * tremolo(samples(d), 14, 0.8) * env(d, 0.15, curve=2) * 0.15
    return chime + shimmer


def loot_legend():
    d = 1.3
    boom = mix(d, (0, tone(sweep(110, 55, 0.4), kind="sine") * env(0.4, 0.002, curve=2)))
    fanfare = lowpass(arp(["A5", "C#6", "E6", "A6"], 0.07, d, kind="square", duty=0.25,
                          curve=1.8, last=0.8), 4500) * 0.55
    chord = (tone(note("A6"), d, "sine") + tone(note("E7"), d, "sine") * 0.6)
    chord = chord * tremolo(samples(d), 9, 0.6) * env(d, 0.3, curve=1.5) * 0.18
    return boom + fanfare + chord


def loot_epic():
    """에픽 · 고유. 가장 드문 보상이라 가장 크고 길다."""
    d = 1.7
    boom = mix(d, (0, tone(sweep(140, 40, 0.6), kind="sine") * env(0.6, 0.002, curve=1.8)),
               (0, noise(sweep(3000, 200, 0.5)) * env(0.5, 0.002, curve=2.5) * 0.4))
    rise = mix(d, (0.05, tone(sweep(300, 1800, 0.25), kind="sine") * env(0.25, 0.2, curve=0.5) * 0.25))
    fanfare = arp(["D5", "F5", "A5", "D6", "F6", "A6"], 0.065, 1.2, kind="square", duty=0.25,
                  curve=1.8, last=0.7)
    fanfare = mix(d, (0.2, lowpass(echo(fanfare, 0.1, 0.3, 3), 4500) * 0.5))
    chord = (tone(note("D7"), d, "sine") + tone(note("A6"), d, "sine")) * tremolo(samples(d), 11, 0.7)
    chord = chord * env(d, 0.5, curve=1.4) * 0.15
    return boom + rise + fanfare + chord


# ---- 진행 · 화면 --------------------------------------------------------------


def level_up():
    d = 0.7
    a = arp(["C5", "E5", "G5"], 0.07, d, kind="square", duty=0.25, curve=1.8)
    top = tone(sweep(note("C6"), note("C6"), 0.45, vibrato=0.015, rate=7), kind="square", duty=0.25)
    a = a + mix(d, (0.21, top * env(0.45, 0.005, hold=0.1, curve=1.6)))
    return lowpass(a, 5000)


def select():
    d = 0.17
    return lowpass(mix(d, (0, ping(note("E6"), 0.06, "square", curve=2)),
                       (0.05, ping(note("B6"), 0.12, "square", curve=2))), 4500) * 0.8


def tap():
    d = 0.035
    return lowpass(tone(sweep(900, 700, d), kind="square") * env(d, 0.001, curve=2), 4000)


def stage_clear():
    d = 1.6
    lead = arp(["G4", "C5", "E5", "G5"], 0.09, d, kind="square", curve=1.6)
    top = tone(sweep(note("C6"), note("C6"), 0.9, vibrato=0.012, rate=6), kind="square")
    lead = lead + mix(d, (0.36, top * env(0.9, 0.005, hold=0.3, curve=1.5)))
    bass = mix(d, (0.36, ping(note("C4"), 0.9, "tri", curve=1.5)))
    return lowpass(lead * 0.7 + bass * 0.8, 4500)


def game_over():
    d = 1.9
    melody = mix(d,
                 (0, ping(note("G4"), 0.3, "saw", curve=1.5)),
                 (0.25, ping(note("D#4"), 0.3, "saw", curve=1.5)),
                 (0.5, tone(sweep(note("C4"), note("C4"), 1.3, vibrato=0.02, rate=4), kind="saw")
                  * env(1.3, 0.01, hold=0.3, curve=1.4)))
    drone = tone(note("C2"), d, "tri") * env(d, 0.3, hold=0.6, curve=1.5) * 0.5
    return lowpass(melody * 0.8 + drone, 1500)


def enhance():
    d = 0.65
    anvil = (tone(1250, 0.3, "tri") + tone(3200, 0.3, "sine") * 0.4 + tone(4700, 0.3, "sine") * 0.2)
    anvil = anvil * env(0.3, 0.001, curve=3)
    return mix(d,
               (0, anvil),
               (0, noise(6000, 0.02) * env(0.02, 0.001) * 0.5),
               (0.12, ping(note("E6"), 0.2, "tri") * 0.6),
               (0.2, ping(note("B6"), 0.45, "tri", curve=2) * 0.6))


def transcend():
    d = 1.1
    rise = tone(sweep(400, 1600, 0.3), kind="sine") * env(0.3, 0.25, curve=0.6) * 0.5
    sparkle = arp(["C6", "E6", "G6", "C7"], 0.06, 0.9, kind="tri", curve=2, last=0.6)
    shimmer = tone(note("G7"), d, "sine") * tremolo(samples(d), 13, 0.8) * env(d, 0.3, curve=1.8) * 0.15
    return mix(d, (0, rise), (0.25, sparkle), (0, shimmer))


SOUNDS = {f.__name__: f for f in [
    hit, crit, kill, hurt, block, boss_appear, boss_down,
    shard, coin, gem, heal, magnet, crate, equip,
    loot_normal, loot_rare, loot_hero, loot_legend, loot_epic,
    level_up, select, tap, stage_clear, game_over, enhance, transcend,
]}

# 소리끼리 체감 크기를 맞추는 최고 음량. 게임 안 볼륨은 Sfx 쪽에서 한 번 더 곱한다.
PEAK = 0.89


def finish(x):
    x = x - np.mean(x)
    fade = min(len(x), samples(0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / np.max(np.abs(x)) * PEAK


def write(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "audio", "sfx")
    names = sys.argv[2:] or list(SOUNDS)
    os.makedirs(out, exist_ok=True)
    global _rng
    for name in names:
        # 소리마다 따로 시드를 둬서 하나만 다시 만들어도 나머지가 바뀌지 않는다.
        _rng = np.random.default_rng(zlib.crc32(name.encode()))
        x = finish(SOUNDS[name]())
        write(os.path.join(out, f"{name}.wav"), x)
        print(f"{name:12s} {len(x) / RATE:5.2f}s")


if __name__ == "__main__":
    main()
