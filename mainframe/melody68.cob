      * ============================================================
      * MELODY68 - proof of concept for IBM OS ANS COBOL (COBOL-68)
      * Target: MVS 3.8j / TK4- compiler IKFCBL00 (COBOL F).
      * Picks a random scale and prints 8-16 random notes in the
      * same 4-char format as the GnuCOBOL generator (e.g. "C 4Q").
      * Restrictions: fixed format, upper case, no intrinsic
      * functions, no END-xxx terminators, no inline PERFORM, no
      * reference modification, no EVALUATE.
      * ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MELODY68.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      * --- 16-bit linear congruential generator -----------------
       77  WS-TIME             PIC 9(8).
       77  WS-SEED             PIC 9(5).
       77  WS-WORK             PIC 9(10).
       77  WS-QUOT             PIC 9(10).
       77  WS-RANGE            PIC 99.
       77  WS-PICK             PIC 99.
       77  WS-LEN              PIC 99.
       77  WS-IX               PIC 99.
       77  WS-SCX              PIC 9.
       77  WS-NX               PIC 9.
      * --- Scale table (4 scales, 7 two-char notes each) --------
       01  SCALE-DATA.
           05  FILLER          PIC X(16) VALUE 'C MAJOR'.
           05  FILLER          PIC 9     VALUE 7.
           05  FILLER          PIC X(14) VALUE 'C D E F G A B '.
           05  FILLER          PIC X(16) VALUE 'G MAJOR'.
           05  FILLER          PIC 9     VALUE 7.
           05  FILLER          PIC X(14) VALUE 'G A B C D E F#'.
           05  FILLER          PIC X(16) VALUE 'A NATURAL MINOR'.
           05  FILLER          PIC 9     VALUE 7.
           05  FILLER          PIC X(14) VALUE 'A B C D E F G '.
           05  FILLER          PIC X(16) VALUE 'C PENTATONIC'.
           05  FILLER          PIC 9     VALUE 5.
           05  FILLER          PIC X(14) VALUE 'C D E G A     '.
       01  SCALE-TABLE REDEFINES SCALE-DATA.
           05  WS-SC           OCCURS 4 TIMES.
               10  WS-SC-NAME  PIC X(16).
               10  WS-SC-CNT   PIC 9.
               10  WS-SC-N     OCCURS 7 TIMES.
                   15  WS-SC-CH  PIC X.
                   15  WS-SC-AC  PIC X.
      * --- Melody storage ---------------------------------------
       01  WS-MELODY.
           05  WS-M            OCCURS 16 TIMES.
               10  WS-M-CH     PIC X.
               10  WS-M-AC     PIC X.
               10  WS-M-OCT    PIC 9.
               10  WS-M-DUR    PIC X.
       01  WS-OUT.
           05  WS-O-CH         PIC X.
           05  WS-O-AC         PIC X.
           05  WS-O-OCT        PIC 9.
           05  WS-O-DUR        PIC X.
       PROCEDURE DIVISION.
       000-MAIN.
           PERFORM 100-SEED.
           MOVE 4 TO WS-RANGE.
           PERFORM 200-RANDOM.
           COMPUTE WS-SCX = WS-PICK + 1.
           MOVE 9 TO WS-RANGE.
           PERFORM 200-RANDOM.
           COMPUTE WS-LEN = WS-PICK + 8.
           PERFORM 300-ONE-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
           DISPLAY 'MELODY68 SCALE: ' WS-SC-NAME (WS-SCX).
           DISPLAY 'NOTES: ' WS-LEN.
           PERFORM 400-SHOW-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
           STOP RUN.
      * --- Seed from the clock (HHMMSS) ------------------------
       100-SEED.
           MOVE TIME-OF-DAY TO WS-TIME.
           COMPUTE WS-QUOT = WS-TIME / 65536.
           COMPUTE WS-SEED = WS-TIME - WS-QUOT * 65536.
      * --- Next LCG value, then WS-PICK in 0 .. WS-RANGE-1 ------
       200-RANDOM.
           COMPUTE WS-WORK = WS-SEED * 25173 + 13849.
           COMPUTE WS-QUOT = WS-WORK / 65536.
           COMPUTE WS-SEED = WS-WORK - WS-QUOT * 65536.
           COMPUTE WS-WORK = WS-SEED * WS-RANGE.
           COMPUTE WS-PICK = WS-WORK / 65536.
      * --- Build note WS-IX: pitch, octave 4/5, duration --------
       300-ONE-NOTE.
           MOVE WS-SC-CNT (WS-SCX) TO WS-RANGE.
           PERFORM 200-RANDOM.
           COMPUTE WS-NX = WS-PICK + 1.
           MOVE WS-SC-CH (WS-SCX, WS-NX) TO WS-M-CH (WS-IX).
           MOVE WS-SC-AC (WS-SCX, WS-NX) TO WS-M-AC (WS-IX).
           MOVE 2 TO WS-RANGE.
           PERFORM 200-RANDOM.
           COMPUTE WS-M-OCT (WS-IX) = WS-PICK + 4.
           MOVE 20 TO WS-RANGE.
           PERFORM 200-RANDOM.
           IF WS-PICK < 10 MOVE 'Q' TO WS-M-DUR (WS-IX)
           ELSE IF WS-PICK < 15 MOVE 'H' TO WS-M-DUR (WS-IX)
           ELSE IF WS-PICK < 18 MOVE 'E' TO WS-M-DUR (WS-IX)
           ELSE MOVE 'W' TO WS-M-DUR (WS-IX).
       400-SHOW-NOTE.
           MOVE WS-M (WS-IX) TO WS-OUT.
           DISPLAY WS-OUT.
