      *> ============================================================
      *> export.cob
      *> Subprogram: EXPORT
      *>
      *> Two responsibilities:
      *>   1. DISPLAY  – print the current melody to the terminal
      *>   2. SAVE     – write the melody to a plain-text file under
      *>                 the output/ directory
      *>
      *> CALL 'export' USING LS-MELODY
      *>                     LS-SCALE-TABLE
      *>                     LS-SELECTED-SCALE
      *>                     LS-MELODY-COUNT
      *>                     LS-ACTION
      *>                     LS-OUTPUT-FILE
      *>                     LS-STATUS-MSG
      *>                     LS-RETURN-CODE
      *>
      *> LS-ACTION values:
      *>   'D' – Display to terminal only
      *>   'S' – Save to file only
      *>   'B' – Both display and save
      *>
      *> On SAVE:
      *>   File is written to output/melody_NNN.txt where NNN
      *>   comes from LS-MELODY-COUNT (zero-padded to 3 digits).
      *>   LS-OUTPUT-FILE is populated with the path used.
      *>   LS-STATUS-MSG  is set to a human-readable result.
      *>   LS-RETURN-CODE is 0 on success, 1 on I/O error.
      *>
      *> Note format (4 chars): CHAR + ACCID + OCTAVE + DUR
      *>   e.g.  C 4Q  F#4H  A 3E  B 5W
      *> Notes are printed 8 per line for readability.
      *> ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. export.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MELODY-FILE
               ASSIGN TO DYNAMIC WS-OUT-FNAME       *> GnuCOBOL-only
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  MELODY-FILE.
       01  MELODY-FILE-REC        PIC X(80).

       WORKING-STORAGE SECTION.
       01  WS-OUT-FNAME           PIC X(80)  VALUE SPACES.
       01  WS-FS                  PIC XX     VALUE SPACES.
       01  WS-LOOP                PIC 99     VALUE 0.
       01  WS-COL                 PIC 9      VALUE 0.
       01  WS-COUNT-FMT           PIC ZZ9    VALUE 0.
       01  WS-NOTE-DISP           PIC X(4)   VALUE SPACES.
       01  WS-LINE-BUF            PIC X(80)  VALUE SPACES.
       01  WS-LINE-POS            PIC 99     VALUE 1.
       01  WS-LEN-FMT             PIC Z9     VALUE 0.
       01  WS-CURR-DT             PIC X(21)  VALUE SPACES.
       01  WS-TS.
           05  WS-TS-DATE         PIC X(8)   VALUE SPACES.
           05  FILLER             PIC X      VALUE '_'.
           05  WS-TS-TIME         PIC X(6)   VALUE SPACES.

      *> Line buffer for building 8-note display lines
       01  WS-NOTE-LINE.
           05  WS-NL-NOTE         OCCURS 8 TIMES.
               10  WS-NL-N        PIC X(4).
               10  FILLER         PIC X VALUE SPACE.

       LINKAGE SECTION.
      *> --- Melody ---
       01  LS-MELODY.
           05  LS-MELODY-LEN      PIC 99.
           05  LS-NOTES           OCCURS 64 TIMES.
               10  LS-N-CHAR      PIC X.
               10  LS-N-ACCID     PIC X.
               10  LS-N-OCTAVE    PIC 9.
               10  LS-N-DUR       PIC X.

      *> --- Scale table ---
       01  LS-SCALE-TABLE.
           05  LS-SC-COUNT        PIC 9.
           05  LS-SCALE           OCCURS 8 TIMES.
               10  LS-SC-NAME     PIC X(16).
               10  LS-SC-NOTE-CNT PIC 9.
               10  LS-SC-NOTES    OCCURS 7 TIMES.
                   15  LS-SCN-CH  PIC X.
                   15  LS-SCN-ACC PIC X.

      *> --- Scalars ---
       77  LS-SELECTED-SCALE      PIC 9.
       77  LS-MELODY-COUNT        PIC 9(3).
       77  LS-ACTION              PIC X.
       77  LS-OUTPUT-FILE         PIC X(80).
       77  LS-STATUS-MSG          PIC X(60).
       77  LS-RETURN-CODE         PIC 9.

       PROCEDURE DIVISION USING LS-MELODY
                                 LS-SCALE-TABLE
                                 LS-SELECTED-SCALE
                                 LS-MELODY-COUNT
                                 LS-ACTION
                                 LS-OUTPUT-FILE
                                 LS-STATUS-MSG
                                 LS-RETURN-CODE.

       000-MAIN.
           MOVE 0 TO LS-RETURN-CODE

           EVALUATE LS-ACTION
               WHEN 'D'
                   PERFORM 100-DISPLAY-MELODY
               WHEN 'S'
                   PERFORM 200-SAVE-MELODY
               WHEN 'B'
                   PERFORM 100-DISPLAY-MELODY
                   PERFORM 200-SAVE-MELODY
               WHEN OTHER
                   MOVE 'Unknown export action.' TO LS-STATUS-MSG
                   MOVE 1 TO LS-RETURN-CODE
           END-EVALUATE

           GOBACK.

      *> ============================================================
      *> 100-DISPLAY-MELODY
      *> Print the melody to the terminal, 8 notes per line.
      *> ============================================================
       100-DISPLAY-MELODY.
           DISPLAY SPACES
           MOVE LS-MELODY-LEN TO WS-LEN-FMT
           DISPLAY '  Scale  : '
               FUNCTION TRIM(LS-SC-NAME(LS-SELECTED-SCALE))
           DISPLAY '  Notes  : ' WS-LEN-FMT
           DISPLAY '  -----------------------------------------------'

           MOVE 1 TO WS-COL
           PERFORM VARYING WS-LOOP FROM 1 BY 1
               UNTIL WS-LOOP > LS-MELODY-LEN

               STRING LS-N-CHAR  (WS-LOOP)
                      LS-N-ACCID (WS-LOOP)
                      LS-N-OCTAVE(WS-LOOP)
                      LS-N-DUR   (WS-LOOP)
                   DELIMITED SIZE
                   INTO WS-NOTE-DISP

               MOVE WS-NOTE-DISP TO WS-NL-N(WS-COL)

               IF WS-COL = 8 OR WS-LOOP = LS-MELODY-LEN
                   DISPLAY '  ' WS-NOTE-LINE
                   MOVE SPACES TO WS-NOTE-LINE
                   MOVE 1 TO WS-COL
               ELSE
                   ADD 1 TO WS-COL
               END-IF

           END-PERFORM

           DISPLAY '  -----------------------------------------------'
           DISPLAY SPACES.

      *> ============================================================
      *> 200-SAVE-MELODY
      *> Write the melody to output/melody_YYYYMMDD_HHMMSS.txt.
      *> The timestamp ensures each save gets a unique file even
      *> across program restarts.
      *> ============================================================
       200-SAVE-MELODY.
      *>  Build timestamp: YYYYMMDD_HHMMSS from CURRENT-DATE
      *>  CURRENT-DATE layout: YYYYMMDDHHMMSS... (positions 1-14)
           MOVE FUNCTION CURRENT-DATE TO WS-CURR-DT
           MOVE WS-CURR-DT(1:8)  TO WS-TS-DATE
           MOVE WS-CURR-DT(9:6)  TO WS-TS-TIME

           MOVE SPACES TO WS-OUT-FNAME
           STRING 'output/melody_'
                  WS-TS
                  '.txt'
               DELIMITED SIZE
               INTO WS-OUT-FNAME

           MOVE WS-OUT-FNAME TO LS-OUTPUT-FILE

           OPEN OUTPUT MELODY-FILE
           IF WS-FS NOT = '00'
               STRING 'ERROR: cannot open ' WS-OUT-FNAME
                   DELIMITED SIZE
                   INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
               EXIT PARAGRAPH
           END-IF

      *>  Header line
           MOVE LS-MELODY-LEN TO WS-LEN-FMT
           MOVE SPACES TO MELODY-FILE-REC
           STRING 'Scale: '
                  FUNCTION TRIM(LS-SC-NAME(LS-SELECTED-SCALE))
                  '  Notes: ' WS-LEN-FMT
               DELIMITED SIZE
               INTO MELODY-FILE-REC
           WRITE MELODY-FILE-REC
           PERFORM 290-CHECK-WRITE-STATUS

           MOVE '------------------------------------------------'
               TO MELODY-FILE-REC
           WRITE MELODY-FILE-REC
           PERFORM 290-CHECK-WRITE-STATUS

      *>  Notes — 8 per line, same logic as display
           MOVE 1      TO WS-COL
           MOVE SPACES TO WS-NOTE-LINE
           PERFORM VARYING WS-LOOP FROM 1 BY 1
               UNTIL WS-LOOP > LS-MELODY-LEN

               STRING LS-N-CHAR  (WS-LOOP)
                      LS-N-ACCID (WS-LOOP)
                      LS-N-OCTAVE(WS-LOOP)
                      LS-N-DUR   (WS-LOOP)
                   DELIMITED SIZE
                   INTO WS-NOTE-DISP

               MOVE WS-NOTE-DISP TO WS-NL-N(WS-COL)

               IF WS-COL = 8 OR WS-LOOP = LS-MELODY-LEN
                   MOVE SPACES TO MELODY-FILE-REC
                   MOVE WS-NOTE-LINE TO MELODY-FILE-REC
                   WRITE MELODY-FILE-REC
                   PERFORM 290-CHECK-WRITE-STATUS
                   MOVE SPACES TO WS-NOTE-LINE
                   MOVE 1 TO WS-COL
               ELSE
                   ADD 1 TO WS-COL
               END-IF

           END-PERFORM

           CLOSE MELODY-FILE

           IF WS-FS NOT = '00'
               STRING 'ERROR: close failed for ' WS-OUT-FNAME
                   DELIMITED SIZE
                   INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
           ELSE
               STRING 'Saved to ' WS-OUT-FNAME
                   DELIMITED SIZE
                   INTO LS-STATUS-MSG
           END-IF.

      *> ============================================================
      *> 290-CHECK-WRITE-STATUS
      *> Check WS-FS after a WRITE; set LS-STATUS-MSG and
      *> LS-RETURN-CODE to 1 on any I/O error.
      *> ============================================================
       290-CHECK-WRITE-STATUS.
           IF WS-FS NOT = '00'
               STRING 'ERROR: write failed for ' WS-OUT-FNAME
                   DELIMITED SIZE
                   INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
           END-IF.

       END PROGRAM export.
