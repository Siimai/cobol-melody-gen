# IBM COBOL Compatibility Fix Plan

Audit of `src/` against `.github/instructions/cobol.instructions.md`.
Each deviation lists the file, the rule violated, and the exact fix required.

---

## DEV-01 — `EXIT PROGRAM` instead of `GOBACK` in all subprograms

**Rule:** _End every subprogram with `GOBACK` (not `STOP RUN`)._

`EXIT PROGRAM` and `GOBACK` are both valid in IBM Enterprise COBOL, but the
instructions mandate `GOBACK`. `GOBACK` is more explicit about returning to the
caller and is the IBM-preferred form for nested/called programs.

| File | Location | Current | Fix |
|------|----------|---------|-----|
| `generator.cob` | `000-MAIN` (last stmt) | `EXIT PROGRAM.` | `GOBACK.` |
| `scales.cob` | `000-MAIN` (last stmt) | `EXIT PROGRAM.` | `GOBACK.` |
| `export.cob` | `000-MAIN` (last stmt) | `EXIT PROGRAM.` | `GOBACK.` |
| `midiexp.cob` | `000-MAIN` — early-exit after failed `OPEN` | `EXIT PROGRAM` | `GOBACK` |
| `midiexp.cob` | `000-MAIN` — last stmt | `EXIT PROGRAM.` | `GOBACK.` |

**Changes per file:**

### `generator.cob`
```cobol
      *  Before:
           EXIT PROGRAM.

      *  After:
           GOBACK.
```

### `scales.cob`
```cobol
      *  Before:
           EXIT PROGRAM.

      *  After:
           GOBACK.
```

### `export.cob`
```cobol
      *  Before:
           EXIT PROGRAM.

      *  After:
           GOBACK.
```

### `midiexp.cob` (two occurrences)
```cobol
      *  Before (early exit in 000-MAIN):
               MOVE 1 TO LS-RETURN-CODE
               EXIT PROGRAM
           END-IF

      *  After:
               MOVE 1 TO LS-RETURN-CODE
               GOBACK
           END-IF

      *  Before (final statement in 000-MAIN):
           EXIT PROGRAM.

      *  After:
           GOBACK.
```

---

## DEV-02 — `INDEXED BY` in `music_types.cpy` (avoid `USAGE IS INDEX`)

**Rule:** _Avoid `USAGE IS INDEX` in new items; use `PIC 9` counters instead for portability._

`music_types.cpy` defines three `OCCURS` tables with `INDEXED BY` clauses.
The index items (`WS-NI`, `WS-SC-IDX`, `WS-SCN-IDX`) are **never referenced**
anywhere in the code — all PERFORM loops use integer subscripts such as
`WS-LOOP-IDX` and `WS-SCALE-IDX`. Index data items have a special internal
format on z/OS that is incompatible with plain arithmetic and DISPLAY usage.
They should be removed.

**File:** `src/music_types.cpy`

```cobol
*  Before:
       05  WS-NOTES              OCCURS 64 TIMES
                                 INDEXED BY WS-NI.

       05  WS-SCALE              OCCURS 4 TIMES
                                 INDEXED BY WS-SC-IDX.

           10  WS-SC-NOTES       OCCURS 7 TIMES
                                 INDEXED BY WS-SCN-IDX.

*  After (remove all three INDEXED BY clauses):
       05  WS-NOTES              OCCURS 64 TIMES.

       05  WS-SCALE              OCCURS 4 TIMES.

           10  WS-SC-NOTES       OCCURS 7 TIMES.
```

---

## DEV-03 — `CALL 'SYSTEM'` missing `*> GnuCOBOL-only` comment

**Rule:** _Avoid `CALL 'SYSTEM'` for production z/OS code; add a comment where it appears._

**File:** `src/main.cob`, paragraph `200-MAIN-LOOP`

```cobol
*  Before:
       200-MAIN-LOOP.
           CALL 'SYSTEM' USING 'clear'

*  After:
       200-MAIN-LOOP.
           CALL 'SYSTEM' USING 'clear'    *> GnuCOBOL-only
```

On IBM z/OS this CALL should be replaced with a WTO or ISPF screen clear;
for portability the comment marks it as a local-only construct.

---

## DEV-04 — `ASSIGN TO DYNAMIC` and `ORGANIZATION IS BINARY SEQUENTIAL` are GnuCOBOL-only

**Rule:** _Flag any GnuCOBOL-isms with a `*> GnuCOBOL-only` comment._

`ASSIGN TO DYNAMIC <identifier>` (dynamic file assignment) is a GnuCOBOL /
Micro Focus extension. IBM Enterprise COBOL requires a literal ddname or
environment-variable reference in `ASSIGN TO`. Similarly, `ORGANIZATION IS
BINARY SEQUENTIAL` is GnuCOBOL-specific; IBM uses `ORGANIZATION IS SEQUENTIAL`
with `RECFM=U` or a pipeline for true binary output.

### `export.cob` — `FILE-CONTROL`

```cobol
*  Before:
           SELECT MELODY-FILE
               ASSIGN TO DYNAMIC WS-OUT-FNAME
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

*  After:
           SELECT MELODY-FILE
               ASSIGN TO DYNAMIC WS-OUT-FNAME  *> GnuCOBOL-only
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
```

### `midiexp.cob` — `FILE-CONTROL`

```cobol
*  Before:
           SELECT MIDI-FILE
               ASSIGN TO DYNAMIC WS-MIDI-FNAME
               ORGANIZATION IS BINARY SEQUENTIAL
               FILE STATUS IS WS-FS.

*  After:
           SELECT MIDI-FILE
               ASSIGN TO DYNAMIC WS-MIDI-FNAME       *> GnuCOBOL-only
               ORGANIZATION IS BINARY SEQUENTIAL      *> GnuCOBOL-only
               FILE STATUS IS WS-FS.
```

---

## DEV-05 — `WRITE` statements not followed by `FILE STATUS` checks

**Rule:** _Check `FILE STATUS` codes after every I/O operation._

Currently only `OPEN` and `CLOSE` are verified; individual `WRITE` calls are
silently ignored when they fail.

### `export.cob` — `200-SAVE-MELODY`

Three `WRITE MELODY-FILE-REC` statements lack status checks. Add a helper
paragraph `290-CHECK-WRITE-STATUS` and `PERFORM` it after every write:

```cobol
*  Add helper paragraph:
       290-CHECK-WRITE-STATUS.
           IF WS-FS NOT = '00'
               STRING 'ERROR: write failed (' WS-FS ') '
                      WS-OUT-FNAME
                   DELIMITED SIZE
                   INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
               CLOSE MELODY-FILE
               EXIT PARAGRAPH
           END-IF.

*  Then after every WRITE in 200-SAVE-MELODY:
           WRITE MELODY-FILE-REC
           PERFORM 290-CHECK-WRITE-STATUS
```

Apply to all three `WRITE MELODY-FILE-REC` calls in `200-SAVE-MELODY`.

### `midiexp.cob` — `900-WRITE-BYTE`

```cobol
*  Before:
       900-WRITE-BYTE.
           MOVE FUNCTION CHAR(WS-OUT-VAL + 1) TO MIDI-BYTE
           WRITE MIDI-BYTE.

*  After:
       900-WRITE-BYTE.
           MOVE FUNCTION CHAR(WS-OUT-VAL + 1) TO MIDI-BYTE
           WRITE MIDI-BYTE
           IF WS-FS NOT = '00'
               STRING 'ERROR: MIDI write failed (' WS-FS ')'
                   DELIMITED SIZE INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
           END-IF.
```

Note: because `900-WRITE-BYTE` is called from within a `PERFORM VARYING` loop,
an error mid-loop will set `LS-RETURN-CODE` but the loop will continue writing.
A follow-on improvement (out of scope here) would be to add an `IF RC-ERROR
EXIT PERFORM` guard inside `600-WRITE-NOTES`.

---

## DEV-06 — `COMPUTE` statements missing `ON SIZE ERROR`

**Rule:** _Always specify `ON SIZE ERROR` or `ROUNDED` where overflow is possible._

### `generator.cob`

| Statement | Risk | Fix |
|-----------|------|-----|
| `COMPUTE WS-SEED = FUNCTION NUMVAL(WS-CURR-DATE(9:6))` | Time HHMMSS max 235959 fits in `PIC 9(6)` — low but non-zero risk | Add `ON SIZE ERROR MOVE 010000 TO WS-SEED` |
| `COMPUTE WS-MELODY-LEN-NEW = 8 + WS-RND` | `PIC 99` holds 0–99; max value is 17 — safe, but add `ON SIZE ERROR` for portability | Add `ON SIZE ERROR MOVE 16 TO WS-MELODY-LEN-NEW` |
| `COMPUTE WS-NOTE-PICK = 1 + WS-RND` | `PIC 99` holds 0–99; max value 8 — safe | Add `ON SIZE ERROR MOVE 1 TO WS-NOTE-PICK` |
| `COMPUTE WS-OCT-PICK = 4 + WS-RND` | Max value 6, fits in `PIC 9` — overflow technically possible at 10+ | Add `ON SIZE ERROR MOVE 5 TO WS-OCT-PICK` |
| `COMPUTE WS-DUR-PICK = WS-RND` | `PIC 99` max 19 — safe | Add `ON SIZE ERROR MOVE 0 TO WS-DUR-PICK` |

Example fix pattern:
```cobol
*  Before:
           COMPUTE WS-SEED = FUNCTION NUMVAL(WS-CURR-DATE(9:6))

*  After:
           COMPUTE WS-SEED = FUNCTION NUMVAL(WS-CURR-DATE(9:6))
               ON SIZE ERROR MOVE 010000 TO WS-SEED
           END-COMPUTE
```

### `midiexp.cob`

| Statement | Risk | Fix |
|-----------|------|-----|
| `COMPUTE WS-PITCH = WS-BASE-PITCH + ((LS-N-OCTAVE(WS-LOOP) - 4) * 12)` | `PIC 9(3)` holds 0–999; max MIDI pitch = 127 — safe, but bad octave data could overflow | Add `ON SIZE ERROR MOVE 60 TO WS-PITCH` |
| `COMPUTE WS-TRACK-LEN = (LS-MELODY-LEN * 9) + 11` | Max = (64 × 9) + 11 = 587, fits in `PIC 9(6)` — safe | Add `ON SIZE ERROR` for completeness |

---

## Priority Order

| Priority | DEV | Effort | Reason |
|----------|-----|--------|--------|
| High | DEV-01 | Low | Explicit instruction, one-word change per site |
| High | DEV-03 | Low | Explicit instruction, one-line comment |
| High | DEV-04 | Low | Explicit instruction, one-line comments each |
| Medium | DEV-02 | Low | Unused index items; removing improves z/OS portability |
| Medium | DEV-05 | Medium | Correctness — write errors currently go undetected |
| Low | DEV-06 | Medium | Defensive — values are bounded but instructions mandate it |

---

## Files Affected Summary

| File | DEVs |
|------|------|
| `src/music_types.cpy` | DEV-02 |
| `src/main.cob` | DEV-03 |
| `src/generator.cob` | DEV-01, DEV-06 |
| `src/scales.cob` | DEV-01 |
| `src/export.cob` | DEV-01, DEV-04, DEV-05 |
| `src/midiexp.cob` | DEV-01, DEV-04, DEV-05, DEV-06 |
