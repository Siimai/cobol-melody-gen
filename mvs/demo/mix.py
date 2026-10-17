#!/usr/bin/env python3
"""Mix the soundtrack: drums, bass and chords from 0:00, the melody on a bar line.

usage: mix.py        (reads build/melody.json and build/timeline.json,
                      writes build/soundtrack.wav, as long as the video)

timeline.json comes from render.js: the video layout decides where the melody
starts (melodyStart, always on a bar line of the backing track) and how long
the video is, so the picture and the sound share one clock. Everything is
synthesised with the standard library; the noise is seeded, so the result is
the same on every run.

Arrangement (bar = 4 beats at the panel's tempo, key and mode of its scale):
  - kick on 1 and 3, snare on 2 and 4, eighth-note hats; the first bar has no
    kick or snare; a snare fill and a crash lead into the melody
  - a sustained chord pad, off-beat chord plucks and a root bass
  - before and after the melody the chords loop through a stock progression
    (i-VI-III-VII in minor, I-V-vi-IV in major); in the bars under the
    melody each chord is picked from the scale's triads to fit the notes
  - a cosine fade-out over the last FADE_OUT seconds
"""
import json
import math
import os
import random
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
SR = 44100
FADE_IN, FADE_OUT = 1.0, 4.5
MODES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10],
         "dorian": [0, 2, 3, 5, 7, 9, 10]}
LOOPS = {"major": [0, 4, 5, 3], "minor": [0, 5, 2, 6], "dorian": [0, 3, 0, 6]}
G = {"melody": 0.85, "pad": 0.075, "pluck": 0.07, "bass": 0.30,
     "kick": 0.60, "snare": 0.30, "hat": 0.075, "crash": 0.13}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


# ---- voices: each returns a list of samples, cached by its arguments ------
_cache = {}


def cached(fn):
    def wrap(*a):
        k = (fn.__name__,) + a
        if k not in _cache:
            _cache[k] = fn(*a)
        return _cache[k]
    return wrap


@cached
def pluck(midi, dur):
    """Melody / chord pluck: a few partials, fast attack, exponential decay."""
    f, tau = hz(midi), 0.35 + 0.5 * min(dur, 1.6)
    parts = ((1.0, 1.0), (2.0, 0.32), (3.0, 0.14), (4.0, 0.06), (5.01, 0.03))
    out = []
    for i in range(int((dur + 0.7) * SR)):
        t = i / SR
        env = min(1.0, t / 0.006) * math.exp(-t / tau)
        if t > dur:
            env *= math.exp(-(t - dur) / 0.10)
        out.append(env * sum(a * math.sin(2 * math.pi * f * h * t) *
                             math.exp(-t * (h - 1) * 1.6) for h, a in parts))
    return out


@cached
def pad(midi, dur):
    """Soft sustained tone: two slightly detuned voices, slow attack/release."""
    f = hz(midi)
    out = []
    for i in range(int((dur + 0.4) * SR)):
        t = i / SR
        env = min(1.0, t / 0.18)
        if t > dur:
            env *= math.exp(-(t - dur) / 0.12)
        out.append(env * (math.sin(2 * math.pi * f * t) +
                          0.7 * math.sin(2 * math.pi * f * 1.004 * t) +
                          0.25 * math.sin(2 * math.pi * f * 2 * t)))
    return out


@cached
def bass(midi, dur):
    f = hz(midi)
    out = []
    for i in range(int((dur + 0.15) * SR)):
        t = i / SR
        env = min(1.0, t / 0.01) * math.exp(-t / 0.55)
        if t > dur:
            env *= math.exp(-(t - dur) / 0.05)
        out.append(env * (math.sin(2 * math.pi * f * t) +
                          0.35 * math.sin(2 * math.pi * f * 2 * t)))
    return out


@cached
def kick():
    out, ph = [], 0.0
    for i in range(int(0.38 * SR)):
        t = i / SR
        ph += 2 * math.pi * (46 + 95 * math.exp(-t * 32)) / SR
        out.append(math.sin(ph) * math.exp(-t * 9) * min(1.0, t / 0.002))
    return out


@cached
def snare(seed):
    r = random.Random(seed)
    out = []
    for i in range(int(0.28 * SR)):
        t = i / SR
        out.append((r.uniform(-1, 1) * math.exp(-t * 20) * 0.8 +
                    math.sin(2 * math.pi * 188 * t) * math.exp(-t * 30) * 0.6))
    return out


@cached
def hat(seed):
    r = random.Random(seed)
    prev, out = 0.0, []
    for i in range(int(0.07 * SR)):
        x = r.uniform(-1, 1)
        out.append((x - prev) * math.exp(-i / SR * 75))   # crude high-pass
        prev = x
    return out


@cached
def crash():
    r = random.Random(7)
    prev, out = 0.0, []
    for i in range(int(2.4 * SR)):
        x = r.uniform(-1, 1)
        out.append((x - prev) * math.exp(-i / SR * 2.4))
        prev = x
    return out


# ---- harmony ---------------------------------------------------------------
def triads(tonic, mode):
    """[(degree, [pitch classes])] for the major/minor triads of the scale."""
    sc = [(tonic + i) % 12 for i in MODES[mode]]
    out = []
    for d in range(7):
        tri = [sc[d], sc[(d + 2) % 7], sc[(d + 4) % 7]]
        if (tri[2] - tri[0]) % 12 == 7:           # skip diminished triads
            out.append((d, tri))
    return out


def pick_chords(mel, nbars, barlen, tris):
    """One degree per bar under the melody, scored by how well the notes fit."""
    by_deg = dict(tris)
    loop = LOOPS[mel["mode"]]
    chosen = []
    for j in range(nbars):
        lo, hi = j * barlen, (j + 1) * barlen
        best, best_s = None, -1e9
        for d, tri in tris:
            s = 0.0
            for n in mel["notes"]:
                ov = min(hi, n["start"] + n["dur"]) - max(lo, n["start"])
                if ov <= 0:
                    continue
                pc = n["midi"] % 12
                if pc in tri:
                    s += ov
                elif any((pc - c) % 12 == 1 for c in tri):
                    s -= ov                        # a semitone above a chord tone: clash
            if d == loop[j % 4]:
                s += 0.15 * barlen                 # keep the stock progression when it fits
            if chosen and d == chosen[-1]:
                s -= 0.3 * barlen                  # keep the harmony moving
            if s > best_s:
                best, best_s = d, s
        chosen.append(best)
    chosen[0] = 0                                  # come in on the tonic
    chosen[-1] = 0                                 # and land on it
    return chosen, by_deg


def voicing(pcs, prev):
    """Triad around middle C, the inversion closest to the previous chord."""
    best = None
    for inv in range(3):
        rot = pcs[inv:] + pcs[:inv]
        notes, m = [], 50
        for pc in rot:
            while m % 12 != pc:
                m += 1
            notes.append(m)
            m += 1
        c = sum(notes) / 3.0
        score = abs(c - (prev if prev else 60))
        if best is None or score < best[0]:
            best = (score, notes, c)
    return best[1], best[2]


# ---- mixing ----------------------------------------------------------------
class Buf:
    def __init__(self, n):
        self.n, self.b = n, [0.0] * n

    def add(self, t0, samples, gain):
        i0 = int(round(t0 * SR))
        if i0 < 0 or i0 >= self.n:
            return
        end = min(len(samples), self.n - i0)
        b = self.b
        for i in range(end):
            b[i0 + i] += samples[i] * gain


def rms_db(x):
    s = sum(v * v for v in x) / max(1, len(x))
    return 10 * math.log10(s + 1e-12)


def main():
    mel = json.load(open(os.path.join(BUILD, "melody.json")))
    tl = json.load(open(os.path.join(BUILD, "timeline.json")))
    bpm, total, m0 = mel["bpm"], tl["total"], tl["melodyStart"]
    beat = 60.0 / bpm
    barlen = 4 * beat
    step = beat / 4
    nbars = int(math.ceil(total / barlen)) + 1
    mbar = int(round(m0 / barlen))
    if abs(m0 - mbar * barlen) > 1e-6:
        sys.exit("melodyStart %.4f is not on a bar line (%.4f s bars)" % (m0, barlen))
    mlen = int(math.ceil(mel["length"] / barlen - 1e-9))
    tris = triads(mel["tonic"], mel["mode"])
    by_deg = dict(tris)
    loop = LOOPS[mel["mode"]]
    under, _ = pick_chords(mel, mlen, barlen, tris)
    print("chords under the melody (scale degrees):", under)

    N = int((total + 0.5) * SR)
    bk, mb = Buf(N), Buf(N)
    prev = None
    for bar in range(nbars):
        t0 = bar * barlen
        if mbar <= bar < mbar + mlen:
            deg = under[bar - mbar]
        elif bar < mbar:
            deg = loop[bar % 4]
        else:
            deg = loop[(bar - mbar - mlen) % 4]
        pcs = by_deg[deg]
        notes, prev = voicing(pcs, prev)
        for n in notes:                                    # pad and plucks
            bk.add(t0, pad(n, barlen - 0.1), G["pad"])
            for s in (0, 6, 10):
                bk.add(t0 + s * step, pluck(n, beat * 0.8), G["pluck"] * (1.0 if s == 0 else 0.8))
        root = 33 + (pcs[0] - 33) % 12
        for s, d in ((0, 1.5), (8, 1.5), (10, 0.5)):       # bass
            bk.add(t0 + s * step, bass(root, d * beat), G["bass"])
        for s in range(0, 16, 2):                          # hats
            bk.add(t0 + s * step, hat(bar * 16 + s), G["hat"] * (1.0 if s % 4 == 0 else 0.7))
        if bar >= 1:
            for s in (0, 8) + ((10,) if bar % 2 else ()):  # kick
                bk.add(t0 + s * step, kick(), G["kick"])
            for s in (4, 12):                              # snare
                bk.add(t0 + s * step, snare(bar * 16 + s), G["snare"])
        if bar == mbar - 1:                                # fill into the melody
            for k, s in enumerate((13, 14, 15)):
                bk.add(t0 + s * step, snare(900 + k), G["snare"] * (0.5 + 0.25 * k))
        if bar == mbar:
            bk.add(t0, crash(), G["crash"])

    for n in mel["notes"]:                                 # the melody
        mb.add(m0 + n["start"], pluck(n["midi"], n["dur"]), G["melody"])
    d = int(0.30 * SR)                                     # soft echo on the melody
    for i in range(d, N):
        mb.b[i] += 0.26 * mb.b[i - d]

    out = [a + b for a, b in zip(bk.b, mb.b)]
    n_out = int(total * SR)
    out = out[:n_out]
    i0, i1 = int(m0 * SR), min(n_out, int((m0 + mel["length"]) * SR))
    print("level while the melody plays: melody %.1f dB, backing %.1f dB"
          % (rms_db(mb.b[i0:i1]), rms_db(bk.b[i0:i1])))
    for i in range(int(FADE_IN * SR)):                     # fades
        out[i] *= 0.5 - 0.5 * math.cos(math.pi * i / (FADE_IN * SR))
    f0 = int((total - FADE_OUT) * SR)
    for i in range(f0, n_out):
        out[i] *= 0.5 + 0.5 * math.cos(math.pi * (i - f0) / (n_out - f0))
    print("peak before the limiter %.2f" % (max(abs(x) for x in out) or 1.0))
    out = [math.tanh(0.7 * x) * 0.95 for x in out]      # soft limiter, peaks stay below 0.95
    k = 1.0
    with wave.open(os.path.join(BUILD, "soundtrack.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x * k * 32767)) for x in out))
    print("wrote soundtrack.wav, %.1f s, melody at %.1f s (bar %d)" % (total, m0, mbar))


if __name__ == "__main__":
    main()
