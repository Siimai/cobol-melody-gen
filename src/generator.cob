      *> ============================================================
      *> generator.cob
      *> Subprogram: GENERATOR
      *>
      *> Fills the caller's melody array with randomly generated notes
      *> from the selected scale.  Uses FUNCTION RANDOM seeded from
      *> the system clock so each run produces a different result.
      *>
      *> CALL 'generator' USING LS-SCALE-TABLE
      *>                        LS-MELODY
      *>                        LS-SELECTED-SCALE
      *>
      *> On return, LS-MELODY is populated and LS-MELODY-LEN is set.
      *>
      *> Melody length : 8–16 notes (random)
      *> Octave        : 4 or 5 (random, equal weight)
      *> Duration mix  : Q 50% | H 25% | E 15% | W 10%
      *> ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. generator.

       ENVIRONMENT DIVISION.

       DATA DIVISION.

       WORKING-STORAGE SECTION.
       01  WS-CURR-DATE         PIC X(21).
       01  WS-SEED              PIC 9(6)   VALUE 0.
       01  WS-IGNORE            PIC 9V9(9) VALUE 0.
       01  WS-RND               PIC 9V9(9) VALUE 0.
       01  WS-MELODY-LEN-NEW    PIC 99     VALUE 0.
       01  WS-SCALE-IDX         PIC 9      VALUE 0.
       01  WS-NOTE-MAX          PIC 9      VALUE 0.
       01  WS-NOTE-PICK         PIC 99     VALUE 0.
       01  WS-OCT-PICK          PIC 9      VALUE 0.
       01  WS-DUR-PICK          PIC 99     VALUE 0.
       01  WS-DUR-CODE          PIC X      VALUE SPACE.
       01  WS-LOOP-IDX          PIC 99     VALUE 0.

       LINKAGE SECTION.
      *> --- Scale table (mirrors WS-SCALE-TABLE in music_types.cpy) -
       01  LS-SCALE-TABLE.
           05  LS-SC-COUNT        PIC 9.
           05  LS-SCALE           OCCURS 4 TIMES.
               10  LS-SC-NAME     PIC X(16).
               10  LS-SC-NOTE-CNT PIC 9.
               10  LS-SC-NOTES    OCCURS 7 TIMES.
                   15  LS-SCN-CH  PIC X.
                   15  LS-SCN-ACC PIC X.

      *> --- Melody (mirrors WS-MELODY in music_types.cpy) -----------
       01  LS-MELODY.
           05  LS-MELODY-LEN      PIC 99.
           05  LS-NOTES           OCCURS 64 TIMES.
               10  LS-N-CHAR      PIC X.
               10  LS-N-ACCID     PIC X.
               10  LS-N-OCTAVE    PIC 9.
               10  LS-N-DUR       PIC X.

      *> --- Selected scale index (1–4) ------------------------------
       77  LS-SELECTED-SCALE      PIC 9.

       PROCEDURE DIVISION USING LS-SCALE-TABLE
                                 LS-MELODY
                                 LS-SELECTED-SCALE.

       000-MAIN.
           PERFORM 100-SEED-RANDOM
           PERFORM 200-PICK-LENGTH
           PERFORM 300-GENERATE-NOTES
           EXIT PROGRAM.

      *> ----------------------------------------------------------
      *> Seed FUNCTION RANDOM from the current time (HHMMSS).
      *> ----------------------------------------------------------
       100-SEED-RANDOM.
           MOVE FUNCTION CURRENT-DATE TO WS-CURR-DATE
           COMPUTE WS-SEED   = FUNCTION NUMVAL(WS-CURR-DATE(9:6))
           COMPUTE WS-IGNORE = FUNCTION RANDOM(WS-SEED).

      *> ----------------------------------------------------------
      *> Pick a melody length between 8 and 16 notes.
      *>   RANDOM returns [0, 1); * 9 gives [0, 9); +8 gives [8,16].
      *> ----------------------------------------------------------
       200-PICK-LENGTH.
           COMPUTE WS-RND           = FUNCTION RANDOM * 9
           COMPUTE WS-MELODY-LEN-NEW = 8 + WS-RND
           MOVE WS-MELODY-LEN-NEW TO LS-MELODY-LEN.

      *> ----------------------------------------------------------
      *> Generate one note per slot up to LS-MELODY-LEN.
      *> ----------------------------------------------------------
       300-GENERATE-NOTES.
           MOVE LS-SELECTED-SCALE TO WS-SCALE-IDX
           MOVE LS-SC-NOTE-CNT(WS-SCALE-IDX) TO WS-NOTE-MAX

           PERFORM VARYING WS-LOOP-IDX FROM 1 BY 1
               UNTIL WS-LOOP-IDX > LS-MELODY-LEN

               PERFORM 310-PICK-NOTE
               PERFORM 320-PICK-OCTAVE
               PERFORM 330-PICK-DURATION

               MOVE LS-SCN-CH (WS-SCALE-IDX, WS-NOTE-PICK)
                   TO LS-N-CHAR  (WS-LOOP-IDX)
               MOVE LS-SCN-ACC(WS-SCALE-IDX, WS-NOTE-PICK)
                   TO LS-N-ACCID (WS-LOOP-IDX)
               MOVE WS-OCT-PICK TO LS-N-OCTAVE(WS-LOOP-IDX)
               MOVE WS-DUR-CODE TO LS-N-DUR   (WS-LOOP-IDX)

           END-PERFORM.

      *> --- Randomly pick a note index within the scale -----------
       310-PICK-NOTE.
           COMPUTE WS-RND       = FUNCTION RANDOM * WS-NOTE-MAX
           COMPUTE WS-NOTE-PICK = 1 + WS-RND.

      *> --- Octave: 4 or 5 (equal weight) -------------------------
       320-PICK-OCTAVE.
           COMPUTE WS-RND      = FUNCTION RANDOM * 2
           COMPUTE WS-OCT-PICK = 4 + WS-RND.

      *> --- Duration: Q 50% | H 25% | E 15% | W 10% --------------
      *>   Bucket over 20 values:
      *>     0–9  (10/20) → Q quarter
      *>    10–14 ( 5/20) → H half
      *>    15–17 ( 3/20) → E eighth
      *>    18–19 ( 2/20) → W whole
      *> ---------------------------------------------------------
       330-PICK-DURATION.
           COMPUTE WS-RND      = FUNCTION RANDOM * 20
           COMPUTE WS-DUR-PICK = WS-RND

           EVALUATE TRUE
               WHEN WS-DUR-PICK < 10
                   MOVE 'Q' TO WS-DUR-CODE
               WHEN WS-DUR-PICK < 15
                   MOVE 'H' TO WS-DUR-CODE
               WHEN WS-DUR-PICK < 18
                   MOVE 'E' TO WS-DUR-CODE
               WHEN OTHER
                   MOVE 'W' TO WS-DUR-CODE
           END-EVALUATE.

       END PROGRAM generator.
