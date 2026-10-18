      * ============================================================
      * MELSAV - saved-melody rules of the MELODY full-screen panel.
      * Called by the COBOL panel driver MELPNL.
      * MELPNL does the file I/O (DD SAVED); SCRSUB the screen;
      * this program only builds and takes apart the records.
      * Target: MVS 3.8j / TK4- compiler IKFCBL00 (COBOL F), so
      * COBOL-68 only: no END-xxx, no EVALUATE, no intrinsics.
      *
      * SAV-AREA is one 359-byte record, the same layout as the
      * work fields of the same name in MELPNL.  S-FUNC picks the job:
      *   N  normalize a typed number: S-NUM (1-3 digits typed from
      *      the left, or blank) -> 3 digits, zero filled.
      *      S-RC 0 = ok, 1 = not numeric
      *   C  read the shown melody: S-RES1, S-RES2 -> S-SC (scale
      *      digit, 0 if unknown), S-TM, S-LEN
      *   B  build a save record: S-NUM, S-SC, S-TM, S-LEN,
      *      S-NOTES -> S-REC
      *   R  one line of the saved list: S-REC -> S-LINE
      *   D  open a saved melody: S-REC -> S-NUM, S-SC, S-TM,
      *      S-LEN, S-NOTES and the two result lines S-RES1, S-RES2
      * Record layout (80 bytes): number 1-3, scale digit 4,
      * tempo 5-7, note count 8-9, notes 10-73, 74-80 blank.
      * ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MELSAV.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       77  IDX                 PIC S9(4) COMP.
       01  SCALE-VALUES.
           05  FILLER          PIC X(16) VALUE 'C MAJOR'.
           05  FILLER          PIC X(16) VALUE 'G MAJOR'.
           05  FILLER          PIC X(16) VALUE 'A NATURAL MINOR'.
           05  FILLER          PIC X(16) VALUE 'C PENTATONIC'.
           05  FILLER          PIC X(16) VALUE 'D DORIAN'.
           05  FILLER          PIC X(16) VALUE 'E MINOR'.
           05  FILLER          PIC X(16) VALUE 'A MIN PENTATONIC'.
           05  FILLER          PIC X(16) VALUE 'E MIN PENTATONIC'.
       01  SCALE-TABLE REDEFINES SCALE-VALUES.
           05  SCALE-NAME      PIC X(16) OCCURS 8 TIMES.
       01  WS-TEMPO-X.
           05  WS-T1           PIC X.
           05  WS-T2           PIC X.
           05  WS-T3           PIC X.
       01  WS-NORM.
           05  WS-NO1          PIC X.
           05  WS-NO2          PIC X.
           05  WS-NO3          PIC X.
       01  WS-SC-X             PIC X.
       01  WS-SC-N REDEFINES WS-SC-X PIC 9.
       LINKAGE SECTION.
       01  SAV-AREA.
           05  S-FUNC          PIC X.
           05  S-RC            PIC X.
           05  S-NUM           PIC XXX.
           05  S-SC            PIC X.
           05  S-SC-N REDEFINES S-SC PIC 9.
           05  S-TM            PIC XXX.
           05  S-LEN           PIC XX.
           05  S-NOTES         PIC X(64).
           05  S-REC.
               10  R-NUM       PIC XXX.
               10  R-SC        PIC X.
               10  R-TM        PIC XXX.
               10  R-LEN       PIC XX.
               10  R-NOTES     PIC X(64).
               10  R-FILL      PIC X(7).
           05  S-LINE.
               10  L-HASH      PIC X.
               10  L-NUM       PIC XXX.
               10  L-F1        PIC XX.
               10  L-NAME      PIC X(16).
               10  L-F2        PIC XX.
               10  L-TM        PIC XXX.
               10  L-BPM       PIC X(4).
               10  L-F3        PIC XXX.
               10  L-LEN       PIC XX.
               10  L-NOTES     PIC X(6).
               10  L-F4        PIC XX.
           05  S-RES1.
               10  A-HEAD      PIC X(17).
               10  A-NAME      PIC X(16).
               10  A-REST      PIC X(47).
           05  S-RES2.
               10  B-NOTES     PIC X(8).
               10  B-LEN       PIC XX.
               10  B-TEMPO     PIC X(9).
               10  B-TM        PIC XXX.
               10  B-REST      PIC X(58).
       PROCEDURE DIVISION USING SAV-AREA.
       000-MAIN.
           MOVE '0' TO S-RC.
           IF S-FUNC = 'N' PERFORM 100-NUMBER
           ELSE IF S-FUNC = 'C' PERFORM 200-CURRENT
           ELSE IF S-FUNC = 'B' PERFORM 300-BUILD
           ELSE IF S-FUNC = 'R' PERFORM 400-LIST-LINE
           ELSE IF S-FUNC = 'D' PERFORM 500-OPEN
           ELSE MOVE '1' TO S-RC.
           GOBACK.
      * --- N: digits typed from the left, 1 to 3 of them --------
       100-NUMBER.
           MOVE S-NUM TO WS-TEMPO-X.
           MOVE '000' TO WS-NORM.
           IF WS-T3 NOT = SPACE PERFORM 110-THREE
           ELSE IF WS-T2 NOT = SPACE PERFORM 120-TWO
           ELSE IF WS-T1 NOT = SPACE PERFORM 130-ONE.
           IF S-RC = '0' MOVE WS-NORM TO S-NUM.
       110-THREE.
           IF WS-TEMPO-X NUMERIC MOVE WS-TEMPO-X TO WS-NORM
           ELSE MOVE '1' TO S-RC.
       120-TWO.
           IF WS-T1 NUMERIC AND WS-T2 NUMERIC
               MOVE WS-T1 TO WS-NO2
               MOVE WS-T2 TO WS-NO3
           ELSE MOVE '1' TO S-RC.
       130-ONE.
           IF WS-T1 NUMERIC MOVE WS-T1 TO WS-NO3
           ELSE MOVE '1' TO S-RC.
      * --- C: scale digit, tempo and length of the shown melody -
       200-CURRENT.
           MOVE '0' TO S-SC.
           PERFORM 210-FIND-SCALE VARYING IDX FROM 1 BY 1
               UNTIL IDX > 8.
           MOVE B-LEN TO S-LEN.
           MOVE B-TM TO S-TM.
       210-FIND-SCALE.
           IF A-NAME = SCALE-NAME (IDX) MOVE IDX TO S-SC-N.
      * --- B: the record that goes to DD SAVED ------------------
       300-BUILD.
           MOVE SPACES TO S-REC.
           MOVE S-NUM TO R-NUM.
           MOVE S-SC TO R-SC.
           MOVE S-TM TO R-TM.
           MOVE S-LEN TO R-LEN.
           MOVE S-NOTES TO R-NOTES.
      * --- R: ID, scale, tempo and note count for the list ------
       400-LIST-LINE.
           MOVE SPACES TO S-LINE.
           MOVE '#' TO L-HASH.
           MOVE R-NUM TO L-NUM.
           PERFORM 600-SCALE-OF-RECORD.
           IF WS-SC-N > 0 MOVE SCALE-NAME (WS-SC-N) TO L-NAME.
           MOVE R-TM TO L-TM.
           MOVE ' BPM' TO L-BPM.
           MOVE R-LEN TO L-LEN.
           MOVE ' NOTES' TO L-NOTES.
      * --- D: take a saved record apart and rebuild the result --
       500-OPEN.
           MOVE R-NUM TO S-NUM.
           MOVE R-SC TO S-SC.
           MOVE R-TM TO S-TM.
           MOVE R-LEN TO S-LEN.
           MOVE R-NOTES TO S-NOTES.
           MOVE SPACES TO S-RES1.
           MOVE ' MELODY68 SCALE: ' TO A-HEAD.
           PERFORM 600-SCALE-OF-RECORD.
           IF WS-SC-N > 0 MOVE SCALE-NAME (WS-SC-N) TO A-NAME.
           MOVE SPACES TO S-RES2.
           MOVE ' NOTES: ' TO B-NOTES.
           MOVE R-LEN TO B-LEN.
           MOVE '  TEMPO: ' TO B-TEMPO.
           MOVE R-TM TO B-TM.
      * --- WS-SC-N is 1 to 8 for a known scale, else 0 ----------
       600-SCALE-OF-RECORD.
           MOVE '0' TO WS-SC-X.
           IF R-SC NUMERIC MOVE R-SC TO WS-SC-X.
           IF WS-SC-N > 8 MOVE '0' TO WS-SC-X.
