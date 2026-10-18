# MELODY panel design

The full-screen panel is a COBOL-68 program. The only assembler left is
a small screen subroutine.

| Part | Language | Job |
|------|----------|-----|
| [`melpnl.cbl`](../melody/source/cobol/melpnl.cbl) | COBOL-68 | The driver (`MELPNL`): PARM parsing, event loop, messages, files `RUNJCL`, `OUT`, `SAVED`, `MIDI` |
| [`melval.cbl`](../melody/source/cobol/melval.cbl) | COBOL-68 | Input rules (scale, notes, tempo) |
| [`melsav.cbl`](../melody/source/cobol/melsav.cbl) | COBOL-68 | Save / list / load records |
| [`melmid.cbl`](../melody/source/cobol/melmid.cbl) | COBOL-68 | MIDI file as hex text |
| [`scrsub.asm`](../melody/source/asm/scrsub.asm) | HLASM | `SCRSUB`: draws the 3270 screen, reads the keys and fields |

`SETUP` compiles `MELPNL` and links it with `SCRSUB`, `MELVAL`, `MELSAV`
and `MELMID` into one load module, `MELODY.LOAD(MELSCR)`. `MELPANEL`
(CLIST) still calls that name.

## The screen area

`MELPNL` and `SCRSUB` share one 755-byte record, `SCR-AREA` in the COBOL
and the `WORK` DSECT in the assembler. Keep the two identical.

| Field | Bytes | Meaning |
|-------|-------|---------|
| FUNC | 1 | what `SCRSUB` should do (below) |
| AID | 1 | key pressed: `E` Enter, `3` `5` `6` `7` PF keys, `O` other |
| VIEW | 1 | `M` main view, `L` list view |
| HAV | 1 | `Y` if a melody is shown |
| SC, NT, TM | 1, 2, 3 | scale, notes, tempo fields |
| LD | 3 | load number (list view) |
| MSG | 70 | status line |
| RES1, RES2, RESN | 80, 80, 72 | melody header, melody text rows, note data |
| ROWS | 440 | ten saved-melody rows of 44 bytes |

`FUNC` codes: `S` draw, wait for a key, parse the input; `D` draw only;
`W` wait one second; `E` erase the screen.

## How a screen works

1. `MELPNL` fills the area and calls `SCRSUB` with `S`.
2. `SCRSUB` builds one 3270 data stream (erase to blank, then the
   fields) and sends it with `TPUT ... FULLSCR`.
3. It reads the reply with `TGET ... ASIS`, decodes the AID and the
   modified fields by buffer address, and copies them into the area.
   Fields that were not sent keep their old value.
4. `MELPNL` applies the rules: validate (`MELVAL`), save/list/load
   (`MELSAV`), MIDI (`MELMID`), then draws the next screen.

Running a melody: `MELPNL` writes the job to `RUNJCL` and ends with
return code 4. The CLIST `SUBMIT`s it and calls `MELSCR` again with the
`W` mode, which polls the `OUT` data set once a second and shows the
result on the same screen.

## Why this split

Only the terminal needs assembler (`TPUT`/`TGET` with full-screen data
streams). Everything that has a rule or a file is in COBOL, so you can
read and change it without knowing the 3270 data stream.
