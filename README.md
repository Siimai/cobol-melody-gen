# COBOL Melody Generator

An interactive melody generator for the **TK4- mainframe emulator**, running
MVS 3.8j. It is written in COBOL-68 and provides a 3270 full-screen panel,
melody saving, and MIDI export.

## Run on TK4-

You need a running TK4- Hercules system and a TSO account. The MVS version has
two front ends:

```text
MELPANEL      assembler-based full-screen panel
MELODY        line-mode menu
```

On first use, the app creates the user's melody data sets automatically.

An optional KICKS front end is also available. It requires KICKS to be
installed on TK4-. At the TSO `READY` prompt, start it with `MELOKICK`, then
press Enter at the startup messages, press CLEAR, and enter `MELO`.

## Install or update

The `mvs/` directory contains the mainframe source and host tools. To upload
the source and build it from a machine that can connect to TK4-, set the
emulator address and an account with access to `MELODY.*`, then run:

```bash
export MFHOST=localhost MFUSER=<admin-user> MFPASS=<password>
mvs/upload.sh --build
```

Use `MFHOST=172.17.0.1` when running inside the project's dev container.
Credentials can instead be placed in the git-ignored `mvs/.secrets/env`
(start from `mvs/env.example`). Do not commit credentials.

To build from TSO, run `MELBUILD`; use `MELBUILD WHAT(COBOL)`, `WHAT(ASM)`, or
`WHAT(CLIST)` to build one part. After changing source, it must be rebuilt
before users will run the update.

## MIDI export

Export MIDI from the panel with PF7. To retrieve the last export as a `.mid`
file, log off the user and run:

```bash
mvs/midi-from-mvs.sh [output-file]
```

This requires `s3270` and Python 3. By default, the file is written under
`gnucobol/output/`.

## Repository layout

- `mvs/melody/source/` — COBOL-68, assembler, CLIST, and build-job source
- `mvs/upload.sh` — upload source and optionally run the matching build
- `mvs/tso-list.py` — read a data set over TSO
- `mvs/midi-from-mvs.sh` — retrieve and convert MIDI export
- `gnucobol/` — separate GnuCOBOL version for macOS and Linux

The GnuCOBOL version is secondary to the TK4- version. Build it with
`make -C gnucobol`; run its smoke test with `bash gnucobol/tests/smoke.sh`.
