# COBOL Melody Generator

A learning-oriented interactive COBOL application for macOS that generates
simple melodies from a small set of musical scales and saves them as
plain-text note sequences.

---

## Requirements

| Tool | Version | Install |
|------|---------|---------|
| GnuCOBOL | ≥ 3.1 | `brew install gnu-cobol` |
| GNU Make | any | pre-installed on macOS via Xcode CLT |

Verify your setup:

```bash
cobc --version   # should print GnuCOBOL 3.x
make --version
```

If `cobc` is not found, run:

```bash
make install-deps
```

---

## Project structure

```
cobol/
├── Makefile                  build, run, clean, install-deps targets
├── .gitignore
├── README.md
├── src/
│   ├── music_types.cpy       shared data structures (copybook)
│   ├── scales.cob            scale definitions subprogram
│   ├── generator.cob         melody generation subprogram
│   ├── export.cob            display & file-save subprogram
│   ├── midiexp.cob           binary MIDI export subprogram
│   └── main.cob              interactive menu entry point
├── output/                   generated melody and MIDI files land here
└── tests/
    └── smoke.sh              automated smoke test
```

---

## Build

```bash
make            # compile all modules → produces ./melody-gen binary
```

The Makefile compiles `scales.cob`, `generator.cob`, `export.cob`, and
`midiexp.cob` as shared objects (`.so`), then links `main.cob` as the
executable.

---

## Run

```bash
make run        # build (if needed) then launch the app
# or, after building:
./melody-gen
```

You will see a menu like:

```
  =============================================
     COBOL MELODY GENERATOR
  =============================================
  Scale: C Major
  -----
  1  Select scale
  2  Generate melody
  3  View current melody
  4  Save melody to file
  5  Export as MIDI
  6  Exit
  =============================================

  Enter choice (1-6):
```

---

## Supported scales

| # | Scale | Notes |
|---|-------|-------|
| 1 | C Major | C D E F G A B |
| 2 | G Major | G A B C D E F# |
| 3 | A Natural Minor | A B C D E F G |
| 4 | C Pentatonic | C D E G A |

---

## Note format

Each note is represented as 4 characters: `CHAR + ACCIDENTAL + OCTAVE + DURATION`

| Field | Values | Example |
|-------|--------|---------|
| Char | A–G | `C` |
| Accidental | `#` or space | ` ` (natural) |
| Octave | 4 or 5 | `4` |
| Duration | W H Q E | `Q` (quarter) |

Example melody line: `C 4Q  G 4H  E 5Q  D 4E  A 4Q  G 5Q  C 4H  E 4Q`

Duration codes: **W** = whole, **H** = half, **Q** = quarter, **E** = eighth

---

## Saved files

### Plain-text (option 4)

Melodies are saved to `output/melody_YYYYMMDD_HHMMSS.txt`. Each file
contains a header line with the scale name and note count, followed by
the note sequence 8 notes per line:

```
Scale: C Major          Notes: 12
------------------------------------------------
C 4Q  G 4H  E 5Q  D 4E  A 4Q  G 5Q  C 4H  E 4Q
A 4Q  D 5E  G 4Q  C 4W
```

### MIDI (option 5)

Melodies are exported to `output/melody_YYYYMMDD_HHMMSS.mid` — a
standard Type 0 MIDI file (480 ticks/beat, 120 BPM) written entirely
in GnuCOBOL with no external dependencies.

Open a generated file on macOS:

```bash
open output/melody_*.mid        # opens in QuickTime Player or GarageBand
```

Or drag any `.mid` file directly into GarageBand or Logic Pro.

---

## Clean

```bash
make clean      # removes ./melody-gen, *.so, *.o
```

---

## Smoke test

```bash
bash tests/smoke.sh
```

Exercises the full build→generate→save pipeline non-interactively and
reports PASS/FAIL for each check.

---

## What's not in v1

- Audio playback from within the app
- ABC / MusicXML export
- Manual note editing
- Broad key/scale coverage beyond the 4 built-in scales
- Seeded (reproducible) random generation
- Velocity / dynamics (all MIDI notes use fixed velocity 100)
- Tempo selection (hardcoded 120 BPM in MIDI export)
- Flat accidentals (not present in the built-in scales)
