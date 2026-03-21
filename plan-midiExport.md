# Plan: MIDI Export — Pure COBOL Implementation

## Goal

Allow the user to save a generated melody as a standard MIDI file
(`.mid`) that can be opened in GarageBand, QuickTime Player, or any
DAW on macOS — implemented entirely in GnuCOBOL with no external
dependencies.

---

## MIDI file format primer (what COBOL must produce)

A minimal single-track MIDI file has two chunks:

```
┌────────────────────────────────────────┐
│ Header chunk  "MThd"  (always 14 bytes)│
│   chunk type    4D 54 68 64            │
│   chunk length  00 00 00 06            │
│   format        00 00  (type 0)        │
│   num tracks    00 01                  │
│   ticks/beat    01 E0  (= 480)         │
├────────────────────────────────────────┤
│ Track chunk   "MTrk"  (variable size)  │
│   chunk type    4D 54 72 6B            │
│   chunk length  XX XX XX XX  (computed)│
│   [events...]                          │
└────────────────────────────────────────┘
```

Each track event is:  `delta-time (VLQ)  +  event bytes`

Events we need:

| Event | Bytes | Purpose |
|-------|-------|---------|
| Tempo meta | `00 FF 51 03 07 A1 20` | 120 BPM = 500 000 µs/beat |
| Note On  | `00 90 pp 64` | delta=0, ch 0, pitch pp, vel 100 |
| Note Off | `dd dd 80 pp 00` | VLQ delta = note duration in ticks |
| End of track | `00 FF 2F 00` | required terminator |

---

## Key COBOL techniques for binary output

### 1. ORGANIZATION IS BINARY file

```cobol
SELECT MIDI-FILE
    ASSIGN TO DYNAMIC WS-MIDI-FNAME
    ORGANIZATION IS BINARY
    FILE STATUS IS WS-FS.
```

Each `WRITE` writes exactly as many bytes as the record named, with
no newlines or length prefixes — producing a clean binary stream.

### 2. Multiple record sizes under one FD

Multiple `01`-level items share the same FD buffer. WRITE uses the
size of the named record:

```cobol
FD  MIDI-FILE.
01  MIDI-14  PIC X(14).   *> for header chunk     → WRITE MIDI-14
01  MIDI-8   PIC X(8).    *> for track header      → WRITE MIDI-8
01  MIDI-7   PIC X(7).    *> for tempo event       → WRITE MIDI-7
01  MIDI-4   PIC X(4).    *> for Note On and EOT   → WRITE MIDI-4
01  MIDI-5   PIC X(5).    *> for Note Off          → WRITE MIDI-5
```

### 3. Numeric value → binary byte via FUNCTION CHAR

`FUNCTION CHAR(n + 1)` returns the character whose ASCII code is `n`.
This is the standard COBOL idiom for stuffing a computed integer into
a single binary byte:

```cobol
*> Store pitch value 69 (A4) as one byte:
MOVE FUNCTION CHAR(69 + 1) TO WS-NON-PITCH
```

### 4. Big-endian 4-byte integer for the track length field

Decompose the integer into four bytes manually:

```cobol
COMPUTE WS-BYTE4 = FUNCTION MOD(WS-LEN, 256)
COMPUTE WS-BYTE3 = FUNCTION MOD(WS-LEN / 256, 256)
COMPUTE WS-BYTE2 = FUNCTION MOD(WS-LEN / 65536, 256)
COMPUTE WS-BYTE1 = WS-LEN / 16777216

MOVE FUNCTION CHAR(WS-BYTE1 + 1) TO WS-TH-LEN(1:1)
MOVE FUNCTION CHAR(WS-BYTE2 + 1) TO WS-TH-LEN(2:1)
MOVE FUNCTION CHAR(WS-BYTE3 + 1) TO WS-TH-LEN(3:1)
MOVE FUNCTION CHAR(WS-BYTE4 + 1) TO WS-TH-LEN(4:1)
```

### 5. Variable-length quantity (VLQ) encoding for delta times

All our note durations in ticks are > 127, so they always occupy
exactly 2 VLQ bytes:

```
VLQ byte 1 = 0x80 OR  (ticks >> 7)    <- continuation bit set
VLQ byte 2 = 0x7F AND  ticks          <- no continuation bit
```

Pre-computed table for our four durations (480 ticks/beat):

| Code | Ticks | VLQ byte 1 | VLQ byte 2 |
|------|-------|-----------|-----------|
| W    | 1920  | 0x8F      | 0x00      |
| H    |  960  | 0x87      | 0x40      |
| Q    |  480  | 0x83      | 0x60      |
| E    |  240  | 0x81      | 0x70      |

---

## MIDI pitch mapping

```
Base pitches (octave 4):  C=60  D=62  E=64  F=65  G=67  A=69  B=71
Sharp accidental:         +1 semitone
Octave offset:            (octave - 4) x 12
```

---

## Track length formula

With all notes sequential (no chords), each note contributes exactly:

```
Note On:  1 byte (delta 0x00) + 3 bytes (status + pitch + velocity) = 4 bytes
Note Off: 2 bytes (VLQ delta) + 3 bytes (status + pitch + velocity) = 5 bytes
Per note total: 9 bytes

Track data total:
  7   (tempo event)
+ Nx9 (note events)
+ 4   (end of track)
= Nx9 + 11
```

This value is computed at runtime and written big-endian into the
track header before any note data.

---

## Implementation phases

### Phase M1 — New subprogram `src/midiexp.cob`

Signature:

```cobol
CALL 'midiexp' USING WS-MELODY
                     WS-SCALE-TABLE
                     WS-SELECTED-SCALE
                     WS-OUTPUT-FILE
                     WS-STATUS-MSG
                     WS-RETURN-CODE
```

Internal paragraphs:

| Paragraph | Responsibility |
|-----------|---------------|
| `000-MAIN` | Orchestrate the write sequence |
| `100-BUILD-FILENAME` | Produce `output/melody_YYYYMMDD_HHMMSS.mid` |
| `200-COMPUTE-TRACK-LEN` | N x 9 + 11, decompose to 4 big-endian bytes |
| `300-WRITE-HEADER` | MOVE and WRITE the 14-byte header chunk |
| `400-WRITE-TRACK-HEADER` | Fill WS-TH-LEN bytes, WRITE 8-byte track header |
| `500-WRITE-TEMPO` | WRITE the 7-byte tempo event |
| `600-WRITE-NOTES` | Loop: compute pitch + VLQ, WRITE Note On + Note Off |
| `700-WRITE-EOT` | WRITE the 4-byte end-of-track meta event |
| `800-MAP-PITCH` | Evaluate note char/accidental/octave to MIDI pitch |
| `810-MAP-VLQ` | Evaluate duration code to two VLQ bytes |

**Files created:** `src/midiexp.cob`

---

### Phase M2 — New menu option in `src/main.cob`

- Shift Exit from **5** to **6**.
- Add option **5 - Export as MIDI**.
- Guard: melody must exist (same pattern as options 3 and 4).
- New paragraph `350-MIDI-EXPORT`:
  - `CALL 'midiexp' USING ...`
  - On success: set status message with the `.mid` file path.
  - On error: display error, do not increment counter.
- Update `230-READ-CHOICE` to also accept `'6'`.
- Update `240-DISPATCH` to route `'6'` to `340-EXIT`.
- Update menu display.

**Files changed:** `src/main.cob`

---

### Phase M3 — Makefile update

Add `midiexp` as a compiled shared object:

```makefile
$(BIN): src/main.cob src/scales.cob src/generator.cob \
        src/export.cob src/midiexp.cob
    $(COBC) -m -I $(COBCOPY) src/midiexp.cob -o midiexp
    ...existing lines...
```

**Files changed:** `Makefile`

---

### Phase M4 — Documentation and smoke test update

- Update `README.md`: new menu option, how to open `.mid` on macOS.
- Update `tests/smoke.sh`: drive option `'5'` in scripted session,
  assert a `.mid` file is created in `output/`.

**Files changed:** `README.md`, `tests/smoke.sh`

---

## Relevant files (full list after implementation)

| File | Role |
|------|------|
| `src/midiexp.cob` | New — pure COBOL binary MIDI writer |
| `src/main.cob` | Add menu option 5, call midiexp, update dispatch |
| `Makefile` | Add midiexp compile step |
| `README.md` | Updated docs |
| `tests/smoke.sh` | Extended scripted session |

No new runtime dependencies. No external tools required.

---

## Verification checklist

1. `make` builds cleanly including `midiexp.so`.
2. Generate a melody, choose option 5 — a `.mid` file appears in
   `output/` with a timestamp filename.
3. Open the `.mid` in QuickTime Player (`open output/melody_*.mid`)
   and confirm it plays the correct number of notes.
4. Test G Major scale: F# notes must sound one semitone higher than F.
5. Test all four duration codes appear and sound at correct relative lengths.
6. Re-run from a fresh session — no previous `.mid` file is overwritten.
7. Smoke test passes end-to-end.

---

## What is NOT in this plan (future work)

- Velocity / dynamics (all notes at fixed velocity 100)
- Tempo selection from the menu (hardcoded 120 BPM)
- Multi-track or chord support
- REST / silence notes
- Time signature metadata in the MIDI header
- Flat accidentals (not present in current scales)

```
melody-gen (COBOL)
     │
     │  writes  output/melody_TIMESTAMP.csv   (new intermediate format)
     ▼
midi_convert.py  (Python 3)
     │
     │  reads CSV, writes output/melody_TIMESTAMP.mid
     ▼
GarageBand / QuickTime / any MIDI player
```

Python ships with macOS and the `midiutil` package (one `pip install`)
can produce a valid MIDI file in ~20 lines.

---

## Intermediate CSV format

COBOL writes one note per line:

```
NOTE,CHAR,ACCIDENTAL,OCTAVE,DURATION,TEMPO,SCALE
NOTE,C, ,4,Q,120,C Major
NOTE,G,#,4,H,120,C Major
NOTE,A, ,5,E,120,C Major
...
```

| Column | Values |
|--------|--------|
| `CHAR` | A–G |
| `ACCIDENTAL` | `#` or space |
| `OCTAVE` | 4 or 5 |
| `DURATION` | W H Q E |
| `TEMPO` | BPM — hardcoded 120 for v1 |
| `SCALE` | Informational only |

This format is human-readable, easy to generate from COBOL `STRING`
statements, and trivial to parse in Python.

---

## MIDI pitch mapping

Each note maps to a MIDI pitch number:

```
C=60, D=62, E=64, F=65, G=67, A=69, B=71   (octave 4, all naturals)
Sharp: +1 semitone
Octave offset: (octave - 4) × 12
```

Duration codes map to quarter-note fractions (at 120 BPM, 1 quarter = 0.5 s):

| Code | Name | MIDI duration (quarter notes) |
|------|------|-------------------------------|
| W | Whole | 4 |
| H | Half | 2 |
| Q | Quarter | 1 |
| E | Eighth | 0.5 |

---

## Implementation phases

### Phase M1 — New MIDI menu option in `main.cob`

- Add option **5 – Export as MIDI** to the menu (shift Exit to 6).
- Guard: melody must exist (same as View/Save).
- Call `export` with a new action code `'M'`.
- After export returns successfully, shell out:
  `CALL 'SYSTEM' USING 'python3 midi_convert.py <csvpath> <midpath>'`
- Display the MIDI file path in the status message.

**Files changed:** `src/main.cob`

---

### Phase M2 — CSV export action in `export.cob`

Add a new `200-SAVE-CSV` paragraph, triggered by `LS-ACTION = 'M'`:

- Build filename `output/melody_TIMESTAMP.csv` (same timestamp logic
  as the existing `.txt` save).
- Write one header comment line, then one `NOTE,...` line per melody
  note using `STRING`.
- Populate `LS-OUTPUT-FILE` with the CSV path (Python script reads
  this path from `LS-STATUS-MSG` or a fixed naming convention).
- Return `LS-RETURN-CODE` 0 on success, 1 on I/O error.

**Files changed:** `src/export.cob`

---

### Phase M3 — Python MIDI converter `midi_convert.py`

New file at the project root. Accepts two positional arguments:
`<input.csv>` and `<output.mid>`.

```
Usage: python3 midi_convert.py output/melody_X.csv output/melody_X.mid
```

Steps inside the script:

1. Parse each `NOTE,...` line from the CSV.
2. Resolve MIDI pitch: base pitch (C4=60) + accidental offset + octave
   offset.
3. Map duration code to quarter-note float.
4. Append each note to a `MIDIFile` track (using `midiutil`).
5. Write the `.mid` file.

Install dependency (one-time):

```bash
pip3 install midiutil
```

**Files created:** `midi_convert.py`

---

### Phase M4 — Makefile: `install-deps` update

Extend the `install-deps` target to also check for `midiutil`:

```makefile
python3 -c "import midiutil" 2>/dev/null \
    || pip3 install midiutil
```

**Files changed:** `Makefile`

---

### Phase M5 — Documentation & smoke test updates

- Update `README.md`: new menu option, MIDI dependency, example output.
- Update `tests/smoke.sh`: exercise the new option `'5'` in the
  scripted session and assert a `.mid` file is created.

**Files changed:** `README.md`, `tests/smoke.sh`

---

## Relevant files (full list after implementation)

| File | Role |
|------|------|
| `src/main.cob` | Add menu option 5, SYSTEM call to Python |
| `src/export.cob` | New `200-SAVE-CSV` paragraph, action `'M'` |
| `midi_convert.py` | Python bridge: CSV → MIDI |
| `Makefile` | `install-deps` extended for `midiutil` |
| `README.md` | Updated setup and usage docs |
| `tests/smoke.sh` | Extended scripted session |

---

## Verification checklist

1. `make install-deps` installs `midiutil` without errors.
2. Generate a melody, choose option 5 — a `.csv` and a `.mid` file both
   appear in `output/`.
3. Open the `.mid` in QuickTime Player or GarageBand and confirm it
   plays the correct number of notes.
4. Test all four scales; verify sharps (G Major's F#) produce pitch 66
   (F4 + 1) not 65.
5. Smoke test passes end-to-end.

---

## What is NOT in this plan (future work)

- Velocity / dynamics (all notes currently at fixed velocity 100)
- Multi-track or chord support
- Tempo selection from the menu
- REST notes (silence)
- Time signature metadata in the MIDI file
