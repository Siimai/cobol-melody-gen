#!/usr/bin/env python3
"""Turn the melody shown on the recorded panel into audio and a note timeline.

usage: melody.py           (reads build/frames.json, writes build/melody.json
                            and build/melody.wav)

The notes are read from the screen of the 'run1' frame, so the sound is the
melody the program generated. Pitch and length follow what the panel writes
into the MIDI export (melscr.asm: PITCHF, VQT): note letter and octave digit
give the pitch (C4 = 60, so octave 5 is 12 higher, '#' adds one), W/H/Q/E are
4/2/1/0.5 beats, and the tempo is the BPM shown on the panel (120 if blank).
No third-party libraries: the tone is made with the standard library.
"""
import json
import math
import os
import re
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
SR = 44100
SEMI = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
BEATS = {"W": 4.0, "H": 2.0, "Q": 1.0, "E": 0.5}
TAIL = 1.6          # seconds of ring-out after the last note


def read_notes(frame):
    rows = frame["rows"]
    m = re.search(r"NOTES:\s*(\d+)\s+TEMPO:\s*(\d+)", rows[14])
    if not m:
        sys.exit("no melody header on the run1 screen")
    count, bpm = int(m.group(1)), int(m.group(2)) or 120
    notes, t = [], 0.0
    for r in range(15, 21):
        for k in re.finditer(r"[A-G][ #]\d[WHQE]", rows[r]):
            tok = k.group(0)
            midi = 60 + SEMI[tok[0]] + (int(tok[2]) - 4) * 12 + (tok[1] == "#")
            dur = BEATS[tok[3]] * 60.0 / bpm
            notes.append({"row": r, "col": k.start(), "midi": midi,
                          "start": round(t, 4), "dur": round(dur, 4)})
            t += dur
    if len(notes) != count:
        sys.exit("read %d notes but the panel says %d" % (len(notes), count))
    return bpm, notes, t


def synth(notes, length):
    n = int((length + TAIL) * SR)
    out = [0.0] * n
    parts = ((1.0, 1.0), (2.0, 0.32), (3.0, 0.14), (4.0, 0.06), (5.01, 0.03))
    for nt in notes:
        f = 440.0 * 2 ** ((nt["midi"] - 69) / 12.0)
        i0, dur = int(nt["start"] * SR), nt["dur"]
        tau = 0.35 + 0.5 * min(dur, 1.6)
        for i in range(int((dur + 0.7) * SR)):
            if i0 + i >= n:
                break
            t = i / SR
            env = min(1.0, t / 0.006) * math.exp(-t / tau)
            if t > dur:
                env *= math.exp(-(t - dur) / 0.10)
            s = 0.0
            for h, a in parts:
                s += a * math.sin(2 * math.pi * f * h * t) * math.exp(-t * (h - 1) * 1.6)
            out[i0 + i] += s * env
    d = int(0.30 * SR)                      # soft echo for some air
    for i in range(d, n):
        out[i] += 0.26 * out[i - d]
    peak = max(abs(x) for x in out) or 1.0
    k = 0.8 / peak
    fade = int(0.4 * SR)
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    return [x * k for x in out]


def main():
    frames = json.load(open(os.path.join(BUILD, "frames.json")))["frames"]
    run = next((f for f in frames if f["tag"] == "run1"), None)
    if run is None:
        sys.exit("no 'run1' frame in build/frames.json (run record.py first)")
    bpm, notes, length = read_notes(run)
    with open(os.path.join(BUILD, "melody.json"), "w") as f:
        json.dump({"bpm": bpm, "length": round(length, 4), "tail": TAIL,
                   "notes": notes}, f)
    pcm = synth(notes, length)
    with wave.open(os.path.join(BUILD, "melody.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in pcm))
    print("%d notes, %d BPM, %.1f s" % (len(notes), bpm, length + TAIL))


if __name__ == "__main__":
    main()
