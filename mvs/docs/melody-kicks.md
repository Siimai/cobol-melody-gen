# MELO: melody generator as a KICKS transaction (issue #24)

A CICS-style front end for the same melody engine as the assembler panel, with the same functions:
run, save, list and load, MIDI export. Built and tested on the system as HERC04 (a regular user).

Sources are the KICKS User's Guide and general CICS knowledge only (see CLAUDE.md).

## Use

Start it at `READY` with `MELOKICK`, press Enter at the start-up messages, press CLEAR, then type
`MELO`. `KSSF` shuts KICKS down.

| Key | Does |
|---|---|
| Enter | run a melody. Scale 0-8, length 8-16 eighth notes and tempo 40-240 follow the panel's rules (`MELVAL`): blank or 0 means random (tempo: 120), a bad value shows an error and changes nothing |
| PF5 | save the shown melody: appended with the next number to the VSAM file |
| PF6 | list the last 10 saved melodies; type a number and press Enter to load it, PF3 goes back |
| PF7 | MIDI file as hex text to the destination `MIDI`, see "MIDI" below |
| PF3 | leave (from the list: back to the melody) |
| CLEAR | start again |

The last scale, length and tempo are kept in the COMMAREA: a field you leave alone keeps its value,
Enter with no change makes a new melody with the same settings, and erasing a field (EraseEOF) makes
it random again.

The notes are shown on a treble staff (see "Staff" below).

## Screen (issue #43)

```
            1         2         3         4         5         6         7         8
   12345678901234567890123456789012345678901234567890123456789012345678901234567890
01  MELO - MELODY GENERATOR (KICKS)
02  INPUT                                   |  RESULT
03  ----------------------------------------+------------------------------------
04   SCALE  (1-8, BLANK = RANDOM)    [2  ]  |  SCALE  : G MAJOR
05   EIGHTHS (8-16, BLANK = RANDOM) [16 ]  |  LENGTH :  16 EIGHTHS,  9 NOTES
06   TEMPO  (040-240, BLANK = 120)   [120]  |  TEMPO  : 120 BPM
07
08
09    ||         ||            -A==========-
...                                           the staff, rows 8-21
22  DONE - CHANGE INPUT, ENTER = RUN, PF5 = SAVE
23  ENTER=RUN   PF5=SAVE   PF6=LIST   PF7=MIDI
24  PF3=EXIT   CLEAR=NEW
```

- The input fields are underlined and green, so you can see where to type. Prompts are turquoise, the
  title and results yellow.
- `INPUT` is what was typed (blank = random or default); `RESULT` is what the run used, also when an
  input is blank: the scale name, the length in eighths with the number of notes, and the tempo.
- The status line (row 22) is red with the bell for errors (`INVALID ...`, `NO SUCH SAVED MELODY`,
  `NOTHING TO SAVE`, `... FAILED`) and green for success (`DONE`, `SAVED`, `LOADED`, `MIDI EXPORTED`).
- The cursor starts on the first input of each screen (the load number on the list).
- The text is the same with or without colour. Not tried on a monochrome terminal.

## Staff (issue #43, replaces the piano roll of #35)

After a melody is run or loaded, the notes are drawn on a treble staff, rows 8 (B5) to 21 (C4), one row
for each pitch:

```
09    ||         ||            -A==========-
10    ||         ||
11   -||---#-----||----------F=-------------|-------------------------|
12    ||         ||        E=               |                         |
13   -||---------||-------------------------|-------------------------|
14    ||       4 || C====                   |                         |
15   -||-------/-||-------------------------|-------------------------|
16    ||       4 ||                         |                         |
17   (&)---------||-------------------------|G====--------------------|
18    ||         ||                         |                         |
19   -||---------||-------------------------|------E=-----------------|
20    ||         ||                                   D=
21                                                   -C==========-
```

- The length is counted in eighth notes (8 to 16 = 1 to 2 bars of 4/4). One eighth is 3 columns, the
  notes start in column 18, the middle bar line is after 8 eighths (column 42) and the last one after 16
  (column 67).
- A note is its letter, then `=` for as long as it lasts: `E=` an eighth, `C====` a quarter,
  `A==========` a half (4 eighths), and a whole note is 8 eighths wide. A note that crosses the
  middle bar line draws over it. Notes A5 and C4 sit on a short ledger line (`-` either side).
- The start of each row (clef, key signature, time signature, double bar line) is the field `HDnn`, bright
  white, from the table `HDR-DATA` in the program. The key signature is one `#` on the F5 line for the
  scales that have F# (G major, E minor, E minor pentatonic) and nothing for the others; a note in the
  key is drawn without its accidental (an F# in G major is `F=`).
- The music of each row is one field `STnn` of 50 characters, built by the program a character at a time
  (`ST-CH`), staff lines `-` and notes in the same colour. A field is one attribute, so a note has no
  colour of its own: the length of the `=` bar shows the duration (the piano roll of #35 coloured the cells by duration).
- The generator draws notes until the length is exactly full (a shorter duration when the next one does
  not fit), so there are at most 16 notes, the size of the saved record. A melody saved earlier with
  more than 16 eighths can be loaded; the status line says that only the first 16 eighths are shown.
- The main map `MELMP1` is sent first, then the staff map `MELMP3` on top of it (no `ERASE`), so the
  screen is built from two sends. `MELMP3` has a one-character unprotected field `SCUR` at the SCALE input
  with `IC`, which puts the cursor back there. The program fills the staff through an overlay
  (`ROLL-O REDEFINES MELMP1I`): 12 + 8 + 14 x (7 + 14 + 7 + 50) = 1112 bytes, which must have exactly
  the length of the generated `MELMP3O`, so change both together.

## Files

Same layout as the rest of the project: the path under `mvs/` is the data set, the file is the member,
and `upload.sh` sends it (the `bms` library is created on the first upload).

| Repo file | Data set | What |
|---|---|---|
| `melody/source/bms/melmap.bms` | `MELODY.SOURCE.BMS(MELMAP)` | BMS mapset `MELMAP`: map `MELMP1` (the melody), `MELMP2` (the saved list) and `MELMP3` (the staff) |
| `melody/source/cobol/melokik.cbl` | `MELODY.SOURCE.COBOL(MELOKIK)` | command-level COBOL-68 program for transaction `MELO` |
| `melody/source/asm/melppt.asm` | `MELODY.SOURCE.ASM(MELPPT)` | program table, suffix `ML` |
| `melody/source/asm/melpct.asm` | `MELODY.SOURCE.ASM(MELPCT)` | transaction table |
| `melody/source/asm/melfct.asm` | `MELODY.SOURCE.ASM(MELFCT)` | file table: DD `MELSAVE` |
| `melody/source/asm/meldct.asm` | `MELODY.SOURCE.ASM(MELDCT)` | destination table: queue `MIDI`, DD `MELMIDI` |
| `melody/source/clist/melokick.clist` | `MELODY.SOURCE.CLIST(MELOKICK)` | start-up CLIST, installed into `SYS2.CMDPROC` by `CMDPROC` |

`MELOKIK` calls the panel's subprograms `MELVAL` (input rules), `MELSAV` (saved-melody records) and
`MELMID` (MIDI file), linked in from `MELODY.LOAD`, so both front ends share one copy of the rules.

## Storage and start-up

`MELOKICK` runs `%MELSETUP`, then creates what is missing for the user and allocates it:

- `<user>.MELODY.SAVEV`: VSAM KSDS, key = 3 digit number, 80-byte records in the `MELSAV` layout. DD
  `MELSAVE` (FCT entry). It is separate from the panel's `<user>.MELODY.SAVED`. A regular user can define
  it: `CYLINDERS(1 1) VOLUMES(PUB000) UNIQUE` (the shared VSAM space on `PUB000` is full, so each cluster
  gets its own data space).
- `<user>.MELODY.MIDIK`: sequential, `RECFM=F`, `LRECL=80`, `BLKSIZE=80`, allocated `OLD`. DD `MELMIDI`
  (DCT destination `MIDI`, extrapartition output).

Then it starts `KICKS PPT(ML) PCT(ML) FCT(ML) DCT(ML)`: the tables are a private suffix `ML`, and plain
`KICKS` loads the supplied suffix `1$`.

## MIDI

PF7 writes ` *MIDI-BEGIN`, the hex lines and ` *MIDI-END` to the destination, the same text as the panel.
The data goes to the data set when KICKS shuts down (`KSSF`). Several exports in one session are appended;
the converter uses the last. Turn it into a file with:

    MIDIDS=MIDIK MFUSER=<user> MFPASS=<password> mvs/midi-from-mvs.sh out.mid

(`MIDIDS` defaults to `MIDI`, the panel's data set.) A file made this way was decoded and compared with
the notes on the screen: header, one track, tempo, 9 bytes per note, end of track, all matching.

## Differences from the assembler panel

- Terminal I/O is `EXEC CICS SEND/RECEIVE MAP` and a BMS map instead of hand-built 3270 data streams.
  Pseudo-conversational: the program ends after each screen (`RETURN TRANSID`), and the state travels
  in the COMMAREA.
- The seed comes from `ASKTIME` instead of `TIME-OF-DAY`. The melody is made inside the transaction,
  not by a batch job, so there is no wait for a result.
- Saved melodies are in VSAM (`SAVEV`), not the sequential `SAVED`, and MIDI goes to a transient data
  destination into `MIDIK`. The list shows the last 10 like the panel, but a number is read from the file
  directly, so any saved number can be loaded.

## Build jobs

Run with `SUBMIT 'MELODY.SOURCE.CNTL(<member>)'` as a user who can write to the KICKS libraries
(HERC01 or HERC02), in this order. `KIKPROC` only once.

| Member | Does |
|---|---|
| `KIKPROC` | copies the procs `K2KCOBCL` and `KIKMAPS` into `SYS2.PROCLIB` (see findings) |
| `MELKMAP` | `KIKMAPS` proc: symbolic map (COBOL copybook) and map module for `MELMAP` |
| `MELKCOB` | `K2KCOBCL` proc: preprocess, compile and link `MELOKIK` with `KIKCOBGL`, `MELVAL`, `MELSAV`, `MELMID` |
| `MELKTBL` | assembles the four tables into `KIKPPTML`, `KIKPCTML`, `KIKFCTML`, `KIKDCTML` |
| `CMDPROC` | installs the CLISTs, including `MELOKICK`, into `SYS2.CMDPROC` |

`MELKCOB` needs `SETUP` to have built `MELVAL`, `MELSAV` and `MELMID` in `MELODY.LOAD`. `upload.sh --build`
does not run these jobs yet.

## Findings

Things that were not in the guide, or that went wrong:

- `SEND MAP ... MAPONLY` is listed in the guide, but the preprocessor rejects it (`malformed argument
  MAPONLY`), with or without `FROM`. The program sends the map from an output area of LOW-VALUES.
- A BMS source line needs its continuation character in column 72, and the generator checks that an
  `INITIAL` text fits its `LENGTH`.
- The KICKS procs are not on the JES2 proc path, and a `//PROC00 DD` in the job does not help.
  `KIKPROC` copies them into `SYS2.PROCLIB`.
- `ASMFCL` adds `SYS1.MACLIB` (block size 19040) behind the KICKS macro library (3120). The assembler
  then fails with a "wrong length record" error on macros that need it (the FCT). `DCB=BLKSIZE=19040`
  on the `SYSLIB` DD fixes it.
- In a proc call, overriding DDs must come before any DD that is added to the step. An added
  `LKED.LOADLIB` before the `LKED.SYSIN` override made the system drop the override silently, so the
  link edit had no `INCLUDE` and no `NAME` card.
- COBOL F: `77` items must come before the first `01`; a subscript cannot contain arithmetic
  (`TAB (I + 1)`); a `VALUE` literal must fit its `PIC`.
- Writing the melody to a TS queue after the `SEND MAP` made the next key arrive as a bare terminal
  input (abend `APCT`). The queue was dropped; saving is done in VSAM.
- An extrapartition output destination did not open (`NOTOPEN`, RESP2 60) on the panel's `FB`/800 data
  set. `RECFM=F` with `BLKSIZE` = record length (as in the guide's batch example) opens, and `OLD` is
  needed for repeat sessions.
- A `DEFINE CLUSTER` without `UNIQUE` fails with "insufficient suballocation data space".
- Job output cannot be read from the container except over TSO, and only for job names that start with
  the user ID. See issue #30.

- Colour and underline come from `EXTATT=YES` on the mapset and `COLOR=` / `HILIGHT=` on the fields. The
  program colours the status line by moving a colour code into the field's `C` item of the symbolic map
  (`MSGC`, `MSG2C`).
- `SEND MAP ... ALARM` locks the keyboard unless the command also says `FREEKB`: the map's
  `CTRL=(FREEKB,FRSET)` is not applied once the command has options of its own. All sends of MELO now
  give `FREEKB FRSET` themselves.

- The `CURSOR(data-value)` option of `SEND MAP` is accepted by the preprocessor but did not move the
  cursor on the second send (it stayed at row 1, column 1, which is protected, so the keyboard locked on
  the first typed character; the program said `CURSOR(191)`, the data position of SCALE). An `IC` field in
  the map that is sent last works.
- A key press needs the cursor on an unprotected field. A test script that types on such a screen locks
  the keyboard (`s3270` `Reset` clears it); the user ID then stays IN USE if the script cannot log off.
- The map job (`MELKMAP`) and the compile job (`MELKCOB`) must not run at the same time: the compile
  reads the copybook that the map job writes, and the two jobs overlapped here (there is more than one
  initiator). With the old copybook the compile ended with `IKF2118I-C` (the overlay was longer than the
  record). Submit the compile when the map job has ended.
- Held job output (`MSGCLASS=H`) is deleted by the first `OUTPUT ... PRINT(*)`, `KEEP` or not. Read it once
  and save what is needed, for example by writing the lines to a file while paging.

## Open points

- The tables hold only the system entries the guide names for KSGM, KSSF and K999, plus ours. Other
  system transactions (KSMT, KEDF, ...) are not defined. The guide also calls the same programs
  `KSGMPRG`/`KSGMMAP`/`KSSFPRG` in one place and `KSGMPGM`/`KSGMAPL`/`KSSFPGM` in another; the tables use
  the second spelling.
- The guide names no AID-key copybook, so the program defines the key codes itself (the EBCDIC
  characters of the AID bytes X'F3', X'F5', X'F6', X'F7', X'6D'). Other keys act like Enter.
- Tested as HERC01, HERC02 and HERC04; the user's data sets are created on the first start.
- The staff is built from fixed fields of one colour each, so the notes cannot be coloured by duration.
