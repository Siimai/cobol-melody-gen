      *> ============================================================
      *> scales.cob
      *> Subprogram: SCALES
      *>
      *> Populates the caller's scale table with 4 predefined
      *> diatonic/pentatonic scales.  Called once during app init.
      *>
      *> CALL 'scales' USING WS-SCALE-TABLE
      *>
      *> Scales provided:
      *>   1 – C Major        C D E F  G A B   (7 notes)
      *>   2 – G Major        G A B C  D E F#  (7 notes)
      *>   3 – A Natural Min  A B C D  E F G   (7 notes)
      *>   4 – C Pentatonic   C D E G  A       (5 notes)
      *> ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. scales.

       ENVIRONMENT DIVISION.

       DATA DIVISION.

       WORKING-STORAGE SECTION.
      *> Local subscript helpers — not shared with caller.
       01  WS-S                   PIC 9 VALUE 0.
       01  WS-N                   PIC 9 VALUE 0.

       LINKAGE SECTION.
      *> Must mirror the WS-SCALE-TABLE structure in music_types.cpy.
      *> INDEXED BY is intentionally omitted; subscripts are used instead.
       01  LS-SCALE-TABLE.
           05  LS-SC-COUNT        PIC 9.
           05  LS-SCALE           OCCURS 4 TIMES.
               10  LS-SC-NAME     PIC X(16).
               10  LS-SC-NOTE-CNT PIC 9.
               10  LS-SC-NOTES    OCCURS 7 TIMES.
                   15  LS-SCN-CH  PIC X.
                   15  LS-SCN-ACC PIC X.

       PROCEDURE DIVISION USING LS-SCALE-TABLE.

       000-MAIN.
           MOVE 4 TO LS-SC-COUNT

           PERFORM 100-LOAD-C-MAJOR
           PERFORM 200-LOAD-G-MAJOR
           PERFORM 300-LOAD-A-MINOR
           PERFORM 400-LOAD-C-PENTA

           EXIT PROGRAM.

      *> ----------------------------------------------------------
      *> Scale 1: C Major  – C D E F G A B
      *> ----------------------------------------------------------
       100-LOAD-C-MAJOR.
           MOVE 1 TO WS-S
           MOVE 'C Major         ' TO LS-SC-NAME(WS-S)
           MOVE 7                  TO LS-SC-NOTE-CNT(WS-S)

           MOVE 'C' TO LS-SCN-CH(WS-S, 1)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 1)
           MOVE 'D' TO LS-SCN-CH(WS-S, 2)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 2)
           MOVE 'E' TO LS-SCN-CH(WS-S, 3)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 3)
           MOVE 'F' TO LS-SCN-CH(WS-S, 4)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 4)
           MOVE 'G' TO LS-SCN-CH(WS-S, 5)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 5)
           MOVE 'A' TO LS-SCN-CH(WS-S, 6)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 6)
           MOVE 'B' TO LS-SCN-CH(WS-S, 7)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 7).

      *> ----------------------------------------------------------
      *> Scale 2: G Major  – G A B C D E F#
      *> ----------------------------------------------------------
       200-LOAD-G-MAJOR.
           MOVE 2 TO WS-S
           MOVE 'G Major         ' TO LS-SC-NAME(WS-S)
           MOVE 7                  TO LS-SC-NOTE-CNT(WS-S)

           MOVE 'G' TO LS-SCN-CH(WS-S, 1)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 1)
           MOVE 'A' TO LS-SCN-CH(WS-S, 2)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 2)
           MOVE 'B' TO LS-SCN-CH(WS-S, 3)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 3)
           MOVE 'C' TO LS-SCN-CH(WS-S, 4)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 4)
           MOVE 'D' TO LS-SCN-CH(WS-S, 5)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 5)
           MOVE 'E' TO LS-SCN-CH(WS-S, 6)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 6)
           MOVE 'F' TO LS-SCN-CH(WS-S, 7)
           MOVE '#' TO LS-SCN-ACC(WS-S, 7).

      *> ----------------------------------------------------------
      *> Scale 3: A Natural Minor  – A B C D E F G
      *> ----------------------------------------------------------
       300-LOAD-A-MINOR.
           MOVE 3 TO WS-S
           MOVE 'A Natural Minor ' TO LS-SC-NAME(WS-S)
           MOVE 7                  TO LS-SC-NOTE-CNT(WS-S)

           MOVE 'A' TO LS-SCN-CH(WS-S, 1)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 1)
           MOVE 'B' TO LS-SCN-CH(WS-S, 2)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 2)
           MOVE 'C' TO LS-SCN-CH(WS-S, 3)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 3)
           MOVE 'D' TO LS-SCN-CH(WS-S, 4)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 4)
           MOVE 'E' TO LS-SCN-CH(WS-S, 5)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 5)
           MOVE 'F' TO LS-SCN-CH(WS-S, 6)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 6)
           MOVE 'G' TO LS-SCN-CH(WS-S, 7)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 7).

      *> ----------------------------------------------------------
      *> Scale 4: C Pentatonic  – C D E G A  (5 notes)
      *> Slots 6-7 are intentionally left blank.
      *> ----------------------------------------------------------
       400-LOAD-C-PENTA.
           MOVE 4 TO WS-S
           MOVE 'C Pentatonic    ' TO LS-SC-NAME(WS-S)
           MOVE 5                  TO LS-SC-NOTE-CNT(WS-S)

           MOVE 'C' TO LS-SCN-CH(WS-S, 1)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 1)
           MOVE 'D' TO LS-SCN-CH(WS-S, 2)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 2)
           MOVE 'E' TO LS-SCN-CH(WS-S, 3)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 3)
           MOVE 'G' TO LS-SCN-CH(WS-S, 4)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 4)
           MOVE 'A' TO LS-SCN-CH(WS-S, 5)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 5)

           MOVE ' ' TO LS-SCN-CH(WS-S, 6)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 6)
           MOVE ' ' TO LS-SCN-CH(WS-S, 7)
           MOVE ' ' TO LS-SCN-ACC(WS-S, 7).

       END PROGRAM scales.
