#!/usr/bin/env python3
"""Read the melody shown on the recorded panel into build/melody.json.

usage: melody.py           (reads build/frames.json)

The notes come from the screen of the 'run1' frame, so the sound is the
melody the program generated. Pitch and length follow what the panel writes
into the MIDI export (melmid.cbl): note letter and octave digit
give the pitch (C4 = 60, so octave 5 is 12 higher, '#' adds one), W/H/Q/E are
4/2/1/0.5 beats, and the tempo is the BPM shown on the panel (120 if blank).
The scale name gives the key and mode that mix.py builds the chords from.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
SEMI = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
BEATS = {"W": 4.0, "H": 2.0, "Q": 1.0, "E": 0.5}
# the panel's scales -> (tonic pitch class, parent mode for the chords)
SCALES = {
    "C MAJOR": (0, "major"), "G MAJOR": (7, "major"),
    "A NATURAL MINOR": (9, "minor"), "E MINOR": (4, "minor"),
    "C PENTATONIC": (0, "major"), "D DORIAN": (2, "dorian"),
    "A MIN PENTATONIC": (9, "minor"), "E MIN PENTATONIC": (4, "minor"),
}


def main():
    frames = json.load(open(os.path.join(BUILD, "frames.json")))["frames"]
    run = next((f for f in frames if f["tag"] == "run1"), None)
    if run is None:
        sys.exit("no 'run1' frame in build/frames.json (run record.py first)")
    rows = run["rows"]
    m = re.search(r"SCALE:\s*(.+?)\s+NOTES:\s*(\d+)\s+TEMPO:\s*(\d+)", rows[14])
    if not m:
        sys.exit("no melody header on the run1 screen")
    scale, count, bpm = m.group(1), int(m.group(2)), int(m.group(3)) or 120
    if scale not in SCALES:
        sys.exit("unknown scale %r" % scale)
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
    tonic, mode = SCALES[scale]
    with open(os.path.join(BUILD, "melody.json"), "w") as f:
        json.dump({"bpm": bpm, "length": round(t, 4), "scale": scale,
                   "tonic": tonic, "mode": mode, "notes": notes}, f)
    print("%d notes, %d BPM, %s, %.1f s" % (len(notes), bpm, scale, t))


if __name__ == "__main__":
    main()
