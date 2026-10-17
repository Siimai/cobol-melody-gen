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

The repository holds two versions of the melody generator:

| Folder | What it is |
|--------|------------|
| `gnucobol/` | the original GnuCOBOL version for macOS / Linux (everything up to the *Smoke test* section below) |
| `mvs/` | the COBOL-68 port for MVS 3.8j on a TK4- Hercules mainframe (see *Mainframe version*) |

```
cobol/
├── README.md
├── CLAUDE.md                 instructions for Claude Code
├── .github/                  PR template and coding instructions
├── .devcontainer/            dev container (Dockerfile, devcontainer.json)
├── gnucobol/                 GnuCOBOL version
│   ├── Makefile              build, run, clean, install-deps targets
│   ├── src/
│   │   ├── music_types.cpy   shared data structures (copybook)
│   │   ├── scales.cob        scale definitions subprogram
│   │   ├── generator.cob     melody generation subprogram
│   │   ├── export.cob        display & file-save subprogram
│   │   ├── midiexp.cob       binary MIDI export subprogram
│   │   └── main.cob          interactive menu entry point
│   ├── output/               generated melody and MIDI files land here
│   └── tests/
│       └── smoke.sh          automated smoke test
└── mvs/                      MVS 3.8j version
    ├── melody/source/        mirrors the mainframe datasets
    ├── upload.sh             upload (and optionally build) from the host
    ├── tso-list.py           read a data set over a TSO session (s3270)
    └── midi-from-mvs.sh      turn the panel's MIDI export into a .mid file
```

**The GnuCOBOL commands below are run from the `gnucobol/` folder**
(`cd gnucobol`), or from anywhere with `make -C gnucobol <target>`.

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
COB_LIBRARY_PATH=./build ./build/melody-gen
```

You will see a menu like:

```
  =============================================
     COBOL MELODY GENERATOR
  =============================================
  Scale: C Major
  Tempo:  120 BPM
  -----
  1  Select scale
  2  Generate melody
  3  View current melody
  4  Save melody to file
  5  Export as MIDI
  6  Set tempo
  7  Exit
  =============================================

  Enter choice (1-7):
```

---

## Supported scales

| # | Scale | Notes |
|---|-------|-------|
| 1 | C Major | C D E F G A B |
| 2 | G Major | G A B C D E F# |
| 3 | A Natural Minor | A B C D E F G |
| 4 | C Pentatonic | C D E G A |
| 5 | D Dorian | D E F G A B C |
| 6 | E Minor | E F# G A B C D |
| 7 | A Minor Pentatonic | A C D E G |
| 8 | E Minor Pentatonic | E G A B D |

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
standard Type 0 MIDI file (480 ticks/beat) written entirely in GnuCOBOL
with no external dependencies. Tempo is user-selectable via option 6
(80 / 100 / 120 / 140 / 160 BPM; default 120 BPM).

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

## Mainframe version (TK4- / MVS 3.8j)

`mvs/` holds a COBOL-68 port that runs on a Hercules emulator
running TK4- (MVS 3.8j), with a TSO line-mode menu and a full-screen 3270
panel (assembler). It has the same 8 scales, a tempo setting, save/load of
melodies and MIDI export.

### Layout: the repo mirrors the mainframe

The path under `mvs/melody/source/` is the dataset name and the file
name is the member (upper case, extension ignored):

| Repo file | Mainframe member | Holds |
|-----------|------------------|-------|
| `cobol/melody68.cbl` | `MELODY.SOURCE.COBOL(MELODY68)` | the COBOL-68 program |
| `asm/melscr.asm` | `MELODY.SOURCE.ASM(MELSCR)` | the 3270 panel |
| `clist/melody.clist`, `melpanel.clist`, `melsetup.clist`, `melbuild.clist` | `MELODY.SOURCE.CLIST(...)` | menu, panel starter, first-run setup, build command |
| `cntl/setup.jcl`, `melscr.jcl`, `cmdproc.jcl` | `MELODY.SOURCE.CNTL(...)` | build jobs (they read the source from the libraries) |

The compiled programs go to `MELODY.LOAD`. Nothing is stored in the repo
for it, and no source is copied inside any JCL.

### Language: the mainframe program is COBOL-68

TK4- ships the IBM OS compiler IKFCBL00 ("COBOL F"), which implements the
1968 ANS COBOL standard. `mvs/melody/source/cobol/melody68.cbl` therefore
has to stay COBOL-68, unlike the GnuCOBOL version (COBOL-85 plus the 1989
amendment). The main restrictions:

- fixed format, upper case, columns 8-72, period-terminated sentences
- no `END-IF`/`END-PERFORM` terminators, no `EVALUATE`, no inline `PERFORM`
  (use `PERFORM paragraph` and nested `IF ... ELSE`)
- no intrinsic functions: the time comes from the `TIME-OF-DAY` register and
  the random numbers from a hand-written generator
- no `STRING`, `INSPECT` or reference modification; `77` items before `01`
  items; a `VALUE` literal may not be longer than its `PIC`

GnuCOBOL cannot check these rules. A compile error shows up only in the
printed output of the `SETUP` job (the host's `prt00e.txt`), and the symptom
from a container is that `MELODY68` is missing or stale in `MELODY.LOAD`.
The full list is in `CLAUDE.md`.

### Prerequisites

- A running TK4- Hercules (3270 on port 3270, card reader on port 3505) and
  `nc` on the machine you upload from.
- A user with ALTER on `MELODY.*` (group `ADMIN`, for example HERC02) for
  the install. Passwords are never stored in the repo: copy
  `mvs/env.example` to `mvs/.secrets/env` (git-ignored), and `MFHOST` set to the emulator host (`localhost` on the
  host itself, `172.17.0.1` inside the dev container).
- Regular users need UPDATE on `MELODY.*` only if they should rebuild:
  they must be in the RAKF group `MELODY`. The one-time RAKF setup is
  described in `CLAUDE.md`.

### Compile from the host

```bash
export MFHOST=172.17.0.1 MFUSER=<admin user> MFPASS=<password>   # or put them in mvs/.secrets/env
mvs/upload.sh --build            # upload everything and build it
mvs/upload.sh --build melody/source/asm   # just the panel (paths are relative to mvs/)
mvs/upload.sh                    # upload only, no build
mvs/upload.sh --dry-run --build  # print what it would send
```

`--build` runs the matching job on the mainframe once the upload is done:
COBOL changed runs `SETUP`, assembler changed runs `MELSCR`, a CLIST
changed runs `CMDPROC` (which copies the CLISTs into `SYS2.CMDPROC` so
every user can type their name). The jobs run asynchronously and take
10-20 seconds.

### Compile on the mainframe

Log on to TSO (3270 to `localhost:3270`, then `L <userid>`) and type at
`READY`:

```
MELBUILD                    all three build jobs, in order
MELBUILD WHAT(COBOL)        compile MELODY68 into MELODY.LOAD
MELBUILD WHAT(ASM)          assemble the panel into MELODY.LOAD
MELBUILD WHAT(CLIST)        copy the CLISTs into SYS2.CMDPROC
```

or submit a single job yourself:

```
SUBMIT 'MELODY.SOURCE.CNTL(SETUP)'
SUBMIT 'MELODY.SOURCE.CNTL(MELSCR)'
SUBMIT 'MELODY.SOURCE.CNTL(CMDPROC)'
```

`SETUP` creates `MELODY.LOAD`, so run it before `MELSCR` on a fresh
system. The user needs UPDATE on `MELODY.*`, and `CMDPROC` also needs ALTER
on `SYS2.*` (group `ADMIN`).

| You changed | Upload it, then run |
|-------------|---------------------|
| the COBOL | `SETUP` (`MELBUILD WHAT(COBOL)`) |
| the assembler | `MELSCR` (`MELBUILD WHAT(ASM)`) |
| a CLIST | `CMDPROC` (`MELBUILD WHAT(CLIST)`) |
| a job in `cntl/` | nothing; it is read when you submit it |

Without the build step the change is in the library but users keep running
the old compiled program.

### Run

Every user types at `READY`:

```
MELPANEL      full-screen panel: ENTER = run, PF5 = save, PF6 = list,
              PF7 = export MIDI, PF3 = exit
MELODY        line-mode menu
```

On first use the CLIST creates the user's own data sets
(`<userid>.MELODY.RUNJCL`, `.OUT`, `.SAVED`, `.MIDI`), so no per-user
install is needed. Fetch the last MIDI export (PF7) as a real file with
`mvs/midi-from-mvs.sh [OUTFILE]` (default `gnucobol/output/`). It reads `<user>.MELODY.MIDI` over a
TSO session, so it needs `s3270` and `python3`, and the user must not be
logged on at the time.

### Checking the result

Job output is printed to the emulator's printer and is not readable from a
container. Check a build by listing the library from TSO, for example
`LISTDS 'MELODY.LOAD' MEMBERS` (it should show `MELODY68` and `MELSCR`), or
by running `MELPANEL` once.

---

## What's not in v1

- Audio playback from within the app
- ABC / MusicXML export
- Manual note editing
- Seeded (reproducible) random generation
- Velocity / dynamics (all MIDI notes use fixed velocity 100)
- Flat accidentals (not present in the built-in scales)
- ABC / MusicXML export
- Audio playback from within the app
- Manual note editing
