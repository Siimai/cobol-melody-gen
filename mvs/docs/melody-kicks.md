# MELO: melody generator as a KICKS transaction (issue #24)

A CICS-style front end for the same melody engine as the assembler panel. Status: **draft,
nothing has been built or run on the system yet.**

Sources are the KICKS User's Guide and general CICS knowledge only (see CLAUDE.md).

| Repo file | Data set |
|---|---|
| `melody/source/bms/melmap.bms` | `MELODY.SOURCE.BMS(MELMAP)`: BMS mapset `MELMAP`, map `MELMP1` |
| `melody/source/cobol/melokik.cbl` | `MELODY.SOURCE.COBOL(MELOKIK)`: command-level COBOL-68 program for transaction `MELO` |
| `melody/source/asm/melppt.asm` | `MELODY.SOURCE.ASM(MELPPT)`: program table, suffix `ML` (assemble, then start KICKS with `PPT(ML)`) |
| `melody/source/asm/melpct.asm` | `MELODY.SOURCE.ASM(MELPCT)`: transaction table, suffix `ML` (`PCT(ML)`) |

Same layout as the rest of the project: the path is the data set, the file is the member, and
`upload.sh` sends it (the `bms` library is created on the first upload).

Behaviour: the first call shows the empty form. Enter generates a melody (blank or invalid input
means random scale or length, tempo 120, as in `melody68.cbl`) and shows 4 notes per line in the
`C 4Q` format. The result is kept in temporary storage queue `MELO<terminal id>` (item 1 = header,
items 2.. = notes). PF3 ends, CLEAR redraws.
The last scale, length and tempo are kept in the COMMAREA: a field you leave alone keeps its value, Enter with no
change makes a new melody with the same settings, and erasing a field (EraseEOF) makes it random again.

## Differences from the assembler panel

- The terminal I/O is `EXEC CICS SEND/RECEIVE MAP` and a BMS map instead of hand-built 3270 data
  streams. Pseudo-conversational: the program ends after each screen (`RETURN TRANSID`).
- The seed comes from `ASKTIME` instead of `TIME-OF-DAY`.
- The result is in a TS queue, not in a `<user>.MELODY.SAVED` data set. No MIDI export or save/load yet.

## Findings from the first build

- `SEND MAP ... MAPONLY` is listed in the guide, but the preprocessor rejects it (`malformed argument
  MAPONLY`), with or without `FROM`. The program sends the map from an output area of LOW-VALUES instead.
- A BMS source line needs its continuation character in column 72, and the generator checks that an
  `INITIAL` text fits its `LENGTH`.
- The KICKS procs are not on the JES2 proc path, and a `//PROC00 DD` in the job does not help.
  `KIKPROC` copies `K2KCOBCL` and `KIKMAPS` into `SYS2.PROCLIB` (run it once).

## Open points

- The tables hold only the system entries the guide names for KSGM, KSSF and K999, plus ours. Other
  system transactions (KSMT, KEDF, ...) are not defined. The guide also calls the same program
  `KSGMPRG`/`KSGMMAP`/`KSSFPRG` in one place and `KSGMPGM`/`KSGMAPL`/`KSSFPGM` in another; the
  tables use the second spelling.
- The docs do not name an AID-key copybook, so the program defines PF3 and CLEAR itself
  (`'3'` and `'_'` are the EBCDIC characters for the AID bytes X'F3' and X'6D';
  confirm on the system).
- `DFHMSD TYPE=&SYSPARM` depends on how the map proc generates the copybook and the map module.
- Symbolic field names (`SCALEL`, `SCALEI`, ...) follow standard BMS `TIOAPFX=YES`.
- How to compile with `K2KCOBCL` and `KIKMAPS`, and where the load modules go (`KIKRPL`).
- RAKF access for HERC04 to the KICKS load libraries.

## Build jobs

Run on the mainframe with `SUBMIT 'MELODY.SOURCE.CNTL(<member>)'` as a user who can write to the
KICKS libraries (HERC02), in this order:

| Member | Does |
|---|---|
| `MELKMAP` | `KIKMAPS` proc: symbolic map (COBOL copybook) and map module for `MELMAP` |
| `MELKCOB` | `K2KCOBCL` proc: preprocess, compile and link `MELOKIK` with `KIKCOBGL` |
| `MELKTBL` | assembles `MELPPT` and `MELPCT` into `KIKPPTML` and `KIKPCTML` |

Then start KICKS with `MELOKICK` and type `MELO` as HERC04. `MELOKICK` is a one-line CLIST
(`melody/source/clist/melokick.clist`, installed into `SYS2.CMDPROC` by the `CMDPROC` job) that runs
`KICKS PPT(ML) PCT(ML)`: the tables are a private suffix `ML`, and plain `KICKS` loads the supplied
suffix `1$`. The jobs follow the
User's Guide only. Unconfirmed: `MELKMAP` reads its source from `COPY.SYSUT1`, and `MELKTBL` needs the
KICKS macro library and the right `SKIKLOAD` data set (names in the job comments). `upload.sh --build`
does not run them yet.
