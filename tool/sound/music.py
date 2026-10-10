"""Ashborn 배경음을 작곡 · 합성한다 (칩튠 트래커 식).

    python -I tool/sound/music.py [출력 폴더] [이름 ...]

- 기본 출력은 assets/audio/music. 이름을 주면 그 곡만 다시 만든다.
- 44.1kHz 모노 OGG Vorbis (soundfile 패키지가 필요하다: pip install soundfile).
  --wav 를 붙이면 귀로 비교하기 쉬운 WAV 도 함께 build/music 에 남긴다.
- 파일 이름은 lib/services/audio.dart 의 Bgm 과 같아야 한다.
- 곡마다 이음매 없이 반복된다: 끝에서 넘친 잔향을 곡 처음에 다시 겹친다.
- 녹음 · 외부 음원 없이 이 스크립트가 직접 만들므로 라이선스 걱정이 없다.

악보 적는 법
- 화음은 마디마다 하나: 'Am', 'F', 'Bb', 'B', 'F#dim' (m 단조, dim 감, 7 속칠).
- 선율은 마디마다 문자열 하나: 'A4:2 C5:2 r:4 ...' — 음 이름(반음은 #, b):길이(16분음표 수).
  한 마디 길이는 16 이어야 한다. r 은 쉼표. None 마디는 선율 없이 넘어간다.
- 드럼은 16칸 문자열: k 킥, s 스네어, h 닫힌 하이햇, o 열린 하이햇, t 팀파니, . 빈칸.
"""

import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx  # noqa: E402  (합성 도구를 같이 쓴다)
from sfx import RATE, noise, samples, sweep, tone  # noqa: E402

STEPS = 16  # 한 마디의 16분음표 수

_PITCH = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'A4' → 69. 'Bb3', 'F#5' 처럼 반음을 붙인다."""
    pitch = _PITCH[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        pitch += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return pitch + (int(rest) + 1) * 12


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


_QUALITY = {"": [0, 4, 7], "m": [0, 3, 7], "dim": [0, 3, 6], "7": [0, 4, 7, 10],
            "m7": [0, 3, 7, 10]}


def chord(name, octave):
    """'Am' → [A, C, E] (근음이 [octave] 옥타브)."""
    root = name[0] + (name[1] if len(name) > 1 and name[1] in "#b" else "")
    quality = name[len(root):]
    base = midi(f"{root}{octave}")
    return [base + i for i in _QUALITY[quality]]


# ---- 음량 곡선 · 악기 -----------------------------------------------------------


def adsr(dur, attack, decay, sustain, release):
    """[dur] 동안 누르고 있다가 [release] 동안 사라진다. 길이는 dur + release."""
    n = samples(dur + release)
    held = samples(dur)
    a = max(1, min(samples(attack), held))
    d = max(1, samples(decay))
    out = np.full(n, sustain, dtype=float)
    out[:a] = np.linspace(0, 1, a, endpoint=False)
    end = min(held, a + d)
    out[a:end] = np.linspace(1, sustain, d)[: end - a]
    level = out[held - 1] if held > 0 else 0
    out[held:] = level * (1 - np.linspace(0, 1, n - held)) ** 2
    return out


def _vibrato(n, depth, rate=5.5, delay=0.15):
    t = np.arange(n) / RATE
    amount = depth * np.clip((t - delay) / 0.25, 0, 1)
    return 1 + amount * np.sin(2 * np.pi * rate * t)


def lead_square(freq, dur, duty=0.25):
    e = adsr(dur, 0.006, 0.1, 0.7, 0.07)
    return tone(freq * _vibrato(len(e), 0.012), kind="square", duty=duty) * e


def lead_soft(freq, dur):
    """세모파에 사각파를 조금 섞은 부드러운 피리 소리."""
    e = adsr(dur, 0.03, 0.15, 0.75, 0.15)
    f = freq * _vibrato(len(e), 0.015, rate=5, delay=0.2)
    return (tone(f, kind="tri") + tone(f, kind="square", duty=0.5) * 0.15) * e


def pluck(freq, dur, decay=0.35):
    n = samples(dur + 0.25)
    t = np.arange(n) / RATE
    e = np.exp(-t / decay) * np.minimum(1, t / 0.003)
    e[samples(dur):] *= np.linspace(1, 0, n - samples(dur))
    return (tone(np.full(n, freq), kind="tri") + tone(np.full(n, freq * 2), kind="sine") * 0.25) * e


def bass_tri(freq, dur):
    e = adsr(dur, 0.004, 0.12, 0.8, 0.05)
    f = np.full(len(e), freq)
    return (tone(f, kind="tri") + tone(f, kind="square", duty=0.5) * 0.12) * e


def bass_soft(freq, dur):
    e = adsr(dur, 0.08, 0.3, 0.7, 0.4)
    f = np.full(len(e), freq)
    return (tone(f, kind="sine") + tone(f, kind="tri") * 0.4) * e


def arp_blip(freq, dur):
    e = adsr(dur, 0.002, dur * 0.8, 0.3, 0.02)
    return tone(np.full(len(e), freq), kind="square", duty=0.125) * e


def pad_saw(freq, dur):
    e = adsr(dur, 0.35, 0.5, 0.75, 0.6)
    n = len(e)
    return (tone(np.full(n, freq * 1.004), kind="saw") + tone(np.full(n, freq * 0.996), kind="saw")) * e * 0.5


def kick(_freq=None, _dur=None):
    d = 0.16
    return tone(sweep(150, 42, d), kind="sine") * sfx.env(d, 0.001, curve=2) + \
        noise(3000, d) * sfx.env(d, 0.001, curve=12) * 0.3


def snare(_freq=None, _dur=None):
    d = 0.15
    return noise(7000, d) * sfx.env(d, 0.001, curve=2.5) * 0.8 + \
        tone(sweep(220, 160, d), kind="tri") * sfx.env(d, 0.001, curve=4) * 0.5


def hat(_freq=None, _dur=None, length=0.035):
    return noise(16000, length) * sfx.env(length, 0.001, curve=2)


def open_hat(_freq=None, _dur=None):
    return hat(length=0.13) * 0.8


def timpani(_freq=None, _dur=None):
    d = 1.2
    root = hz(midi("D2"))
    return sfx.mix(d, (0, tone(sweep(root * 1.05, root, d), kind="sine") * sfx.env(d, 0.004, curve=2.5)),
                   (0, noise(1200, 0.2) * sfx.env(0.2, 0.002, curve=3) * 0.25))


DRUMS = {"k": (kick, 1.0), "s": (snare, 0.7), "h": (hat, 0.3), "o": (open_hat, 0.3), "t": (timpani, 1.0)}


# ---- 악보 → 음표 -------------------------------------------------------------------


def melody(bars):
    """마디별 선율 문자열 → (시작 칸, 길이 칸, 미디 번호) 목록."""
    events = []
    for b, bar in enumerate(bars):
        if bar is None:
            continue
        at = 0
        for token in bar.split():
            name, length = token.split(":")
            length = int(length)
            if name != "r":
                events.append((b * STEPS + at, length, midi(name)))
            at += length
        assert at == STEPS, f"{b + 1}번째 마디 길이가 {at} 이다: {bar}"
    return events


def bass_line(chords, octave, style):
    events = []
    for b, name in enumerate(chords):
        root = chord(name, octave)[0]
        fifth = root + 7
        at = b * STEPS
        if style == "whole":
            events.append((at, STEPS, root))
        elif style == "pluck":
            events += [(at, 6, root), (at + 8, 4, fifth), (at + 12, 4, root + 12)]
        elif style == "octaves":
            events += [(at + i * 2, 1.7, root + (12 if i % 2 else 0)) for i in range(8)]
        elif style == "chug":
            events += [(at + i, 0.85, root + (12 if i in (6, 14) else 0)) for i in range(STEPS)]
    return events


def arpeggio(chords, octave, style):
    events = []
    for b, name in enumerate(chords):
        tones = chord(name, octave)
        at = b * STEPS
        if style == "cycle":
            # 32분음표로 화음 음을 빠르게 돌린다. 칩튠의 화음 표현.
            ring = tones + [tones[0] + 12]
            events += [(at + i * 0.5, 0.45, ring[i % len(ring)]) for i in range(STEPS * 2)]
        elif style == "broken":
            # 8분음표로 오르내리는 분산화음.
            ring = tones + [tones[0] + 12, tones[1] + 12]
            order = [0, 1, 2, 3, 4, 3, 2, 1]
            events += [(at + i * 2, 3, ring[order[i]]) for i in range(8)]
    return events


def pad(chords, octave):
    return [(b * STEPS, STEPS, m) for b, name in enumerate(chords) for m in chord(name, octave)]


def drums(bars):
    """마디별 16칸 문자열 → (시작 칸, 악기 글자) 목록."""
    events = []
    for b, bar in enumerate(bars):
        if bar is None:
            continue
        assert len(bar) == STEPS, bar
        events += [(b * STEPS + i, c) for i, c in enumerate(bar) if c != "."]
    return events


# ---- 섞기 ---------------------------------------------------------------------------


class Song:
    def __init__(self, bpm, bars):
        self.step = 60 / bpm / 4
        self.length = samples(self.step * STEPS * bars)
        self.tail = samples(4.0)
        self.mixed = np.zeros(self.length + self.tail)

    def _at(self, step):
        return int(round(step * self.step * RATE))

    def _bus(self):
        return np.zeros_like(self.mixed)

    def _place(self, bus, at, sig):
        end = min(len(bus), at + len(sig))
        bus[at:end] += sig[: end - at]

    def notes(self, events, instrument, volume, cutoff=None, echo=None, swing=0.0):
        bus = self._bus()
        rng = np.random.default_rng(len(events))
        for start, length, m in events:
            vel = 1 - rng.uniform(0, 0.12)  # 사람이 친 것처럼 세기를 조금씩 흔든다.
            if swing and int(start) % 2 == 1:
                start += swing
            self._place(bus, self._at(start), instrument(hz(m), length * self.step) * vel)
        self._finish(bus, volume, cutoff, echo)

    def drums(self, events, volume, cutoff=None):
        bus = self._bus()
        for start, c in events:
            hit, gain = DRUMS[c]
            self._place(bus, self._at(start), hit() * gain)
        self._finish(bus, volume, cutoff, None)

    def _finish(self, bus, volume, cutoff, echo):
        if cutoff:
            bus = sfx.lowpass(bus, cutoff)
        if echo:
            delay, feedback = echo
            d = self._at(delay)
            out = bus.copy()
            for k in range(1, 4):
                out[d * k:] += bus[: len(bus) - d * k] * feedback ** k
            bus = out
        self.mixed += bus * volume

    def render(self):
        x = self.mixed[: self.length].copy()
        # 끝에서 넘친 잔향을 처음에 겹쳐 반복할 때 이음매가 들리지 않게 한다.
        tail = self.mixed[self.length:]
        x[: len(tail)] += tail[: len(x)]
        x -= np.mean(x)
        x = np.tanh(x / np.max(np.abs(x)) * 1.2)  # 살짝 눌러 큰 소리끼리 부딪쳐도 깨지지 않게.
        return x / np.max(np.abs(x)) * 0.8


# ---- 곡 ---------------------------------------------------------------------------


def title():
    """타이틀: 재 속에서 깨어나는 느낌. 느리고 신비로운 레 단조."""
    prog = "Dm Bb F C Dm Bb Gm A".split() * 2
    s = Song(bpm=76, bars=len(prog))
    s.notes(pad(prog, 3), pad_saw, 0.16, cutoff=900)
    s.notes(bass_line(prog, 2, "whole"), bass_soft, 0.45)
    s.notes(arpeggio(prog, 4, "broken"), pluck, 0.22, echo=(3, 0.35))
    counter = [None] * 4 + ["r:8 A5:8", "F5:16", "G5:8 Bb5:8", "A5:16"] + [None] * 8
    s.notes(melody(counter), lead_soft, 0.16, cutoff=2500, echo=(3, 0.4))
    tune = [None] * 8 + [
        "A4:6 D5:2 F5:4 E5:4",
        "D5:8 F5:4 G5:4",
        "A5:6 G5:2 F5:4 C5:4",
        "E5:12 r:4",
        "F5:6 E5:2 D5:4 A4:4",
        "Bb4:8 D5:4 F5:4",
        "G5:6 F5:2 E5:4 D5:4",
        "C#5:12 r:4",
    ]
    s.notes(melody(tune), lead_soft, 0.32, cutoff=3000, echo=(3, 0.35))
    s.drums(drums(["t..............."] + [None] * 7 + ["t..............."] + [None] * 7), 0.35, cutoff=1500)
    return s.render()


def hearth():
    """화톳불(캐릭터 선택): 출정 전 쉬는 곳. 따뜻하고 잔잔하다."""
    prog = "Am F C G Am F G E F G Em Am Dm G C E".split()
    s = Song(bpm=92, bars=len(prog))
    s.notes(pad(prog, 3), pad_saw, 0.08, cutoff=700)
    s.notes(bass_line(prog, 2, "pluck"), bass_tri, 0.35, cutoff=1200)
    s.notes(arpeggio(prog, 4, "broken"), pluck, 0.2, swing=0.12)
    tune = [
        "E5:4 A5:4 G5:4 E5:4",
        "F5:6 E5:2 C5:8",
        "E5:4 G5:4 C6:4 B5:4",
        "D6:8 B5:4 G5:4",
        "A5:6 G5:2 E5:4 C5:4",
        "D5:4 F5:4 A5:4 G5:4",
        "G5:6 F5:2 D5:4 B4:4",
        "G#4:8 B4:4 E5:4",
        "C5:4 F5:4 A5:6 G5:2",
        "G5:8 D5:4 B4:4",
        "E5:4 G5:4 B5:6 A5:2",
        "A5:12 r:4",
        "F5:4 A5:4 D6:6 C6:2",
        "B5:8 G5:4 D5:4",
        "E5:4 G5:4 C6:4 E6:4",
        "D6:4 B5:4 G#5:4 E5:4",
    ]
    s.notes(melody(tune), lead_soft, 0.26, cutoff=2600, echo=(3, 0.25))
    beat = "k.h...h.k.h...h."
    s.drums(drums([beat] * len(prog)), 0.18, cutoff=5000)
    return s.render()


def battle():
    """전투: 웨이브를 버틴다. 빠르고 몰아붙이는 라 단조."""
    a = "Am Am F G Am Am F E".split()
    d = "Dm Dm Am Am F G E E".split()
    prog = a * 3 + d
    s = Song(bpm=138, bars=len(prog))
    s.notes(pad(prog, 3), pad_saw, 0.07, cutoff=1000)
    s.notes(bass_line(prog, 2, "octaves"), bass_tri, 0.4, cutoff=1500)
    s.notes(arpeggio(prog, 4, "cycle"), arp_blip, 0.07, cutoff=3500)
    tune = [None] * 8 + [
        # B: 첫 선율
        "A4:2 C5:2 E5:4 A5:4 G5:2 E5:2",
        "G5:4 E5:4 D5:2 E5:2 C5:4",
        "F5:4 A5:4 C6:4 A5:4",
        "B5:6 A5:2 G5:4 D5:4",
        "E5:2 A5:2 C6:4 B5:2 A5:2 G5:4",
        "A5:4 E5:4 G5:2 F5:2 E5:4",
        "F5:4 E5:2 D5:2 C5:4 D5:4",
        "E5:8 G#5:4 B5:4",
        # C: 한 옥타브 위에서 길게
        "E6:8 D6:4 C6:4",
        "B5:4 C6:4 A5:8",
        "C6:6 B5:2 A5:4 F5:4",
        "G5:4 A5:4 B5:4 D6:4",
        "E6:6 D6:2 C6:4 E6:4",
        "A6:8 G6:4 E6:4",
        "F6:4 E6:4 D6:4 C6:4",
        "B5:8 G#5:4 E5:4",
        # D: 다리
        "D5:4 F5:4 A5:8",
        "G5:4 F5:4 E5:4 D5:4",
        "C5:4 E5:4 A5:8",
        "B5:4 A5:4 G5:4 E5:4",
        "A5:8 C6:8",
        "B5:8 D6:8",
        "E6:8 D6:4 B5:4",
        "G#5:4 B5:4 E6:4 D6:2 B5:2",
    ]
    s.notes(melody(tune), lead_square, 0.24, cutoff=4000, echo=(3, 0.25))
    beat = "k.h.s.h.k.k.s.ho"
    fill = "k.h.s.h.k.s.ssss"
    groove = ([beat] * 7 + [fill]) * 4
    s.drums(drums(groove), 0.42, cutoff=9000)
    return s.render()


def boss():
    """보스: 프리지안 단조로 반음씩 조여 오는 긴장."""
    intro = "Em F Em F".split()
    body = "Em F Em F C B C B Em F G F Am Bb B B".split()
    prog = intro + body
    s = Song(bpm=156, bars=len(prog))
    s.notes(pad(prog, 3), pad_saw, 0.12, cutoff=900)
    s.notes(bass_line(prog, 1, "chug"), bass_tri, 0.42, cutoff=1100)
    s.notes(arpeggio(prog, 4, "cycle"), arp_blip, 0.06, cutoff=3000)
    tune = [None] * 4 + [
        "E5:4 G5:4 F5:4 E5:4",
        "F5:2 E5:2 F5:4 A5:4 G5:4",
        "B5:6 A5:2 G5:4 E5:4",
        "F5:8 C6:8",
        "C6:4 B5:4 G5:4 E5:4",
        "D#5:8 F#5:4 B5:4",
        "E6:4 D6:4 C6:4 G5:4",
        "B5:12 F#5:2 D#5:2",
        "E6:4 B5:4 G5:4 E5:4",
        "F5:4 A5:4 C6:4 F6:4",
        "G6:6 F6:2 D6:4 B5:4",
        "A5:8 F5:4 C5:4",
        "A5:4 C6:4 E6:4 C6:4",
        "D6:4 Bb5:4 F5:4 D5:4",
        "D#6:8 B5:4 F#5:4",
        "B5:8 A5:4 F#5:4",
    ]
    s.notes(melody(tune), lambda f, d: lead_square(f, d, duty=0.5), 0.2, cutoff=3800, echo=(2, 0.2))
    beat = "k.hks.hkk.hks.hh"
    fill = "k.hks.hkk.s.ssss"
    groove = [beat] * 3 + [fill] + ([beat] * 7 + [fill]) * 2
    s.drums(drums(groove), 0.45, cutoff=9000)
    return s.render()


SONGS = {f.__name__: f for f in [title, hearth, battle, boss]}


def main():
    args = [a for a in sys.argv[1:] if a != "--wav"]
    keep_wav = "--wav" in sys.argv
    out = args[0] if args else os.path.join("assets", "audio", "music")
    names = args[1:] or list(SONGS)
    os.makedirs(out, exist_ok=True)
    import soundfile  # 곡을 만들 때만 필요하다.

    for name in names:
        sfx._rng = np.random.default_rng(zlib.crc32(name.encode()))
        x = SONGS[name]()
        # 한 번에 통째로 쓰면 libsndfile 의 Vorbis 인코더가 스택을 넘쳐 죽는다. 조금씩 나눠 쓴다.
        with soundfile.SoundFile(os.path.join(out, f"{name}.ogg"), "w", RATE, 1,
                                 format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(x), 8192):
                f.write(x[i:i + 8192])
        if keep_wav:
            os.makedirs(os.path.join("build", "music"), exist_ok=True)
            sfx.write(os.path.join("build", "music", f"{name}.wav"), x)
        size = os.path.getsize(os.path.join(out, f"{name}.ogg")) / 1024
        print(f"{name:8s} {len(x) / RATE:5.1f}s  {size:6.0f}KB")


if __name__ == "__main__":
    main()
