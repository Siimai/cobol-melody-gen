      * ============================================================
      * MELVAL - input rules of the MELODY full-screen panel.
      * Called by the assembler front end MELSCR (LOAD + CALL).
      * Target: MVS 3.8j / TK4- compiler IKFCBL00 (COBOL F), so
      * COBOL-68 only: no END-xxx, no EVALUATE, no intrinsics.
      *
      * VAL-AREA is one 13-byte record, the same layout as the
      * work fields SCV..TM3 in MELSCR:
      *   in : V-SCALE  1 char, blank or 0-8 (0/blank = random)
      *        V-NOTES  2 chars, blank, 0 or 8-16 (0/blank = random)
      *        V-TEMPO  3 chars, blank, 0 or 40-240 (0/blank = 120)
      *   out: V-RC     0 = ok, 1 = bad scale, 2 = bad notes,
      *                 3 = bad tempo
      *        V-SC, V-NN, V-TM  the values as digits for the job
      *                 card (1, 2 and 3 digits, zero filled);
      *                 set only when V-RC is 0
      * ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MELVAL.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-NOTES.
           05  WS-N1           PIC X.
           05  WS-N2           PIC X.
       01  WS-TEMPO-X.
           05  WS-T1           PIC X.
           05  WS-T2           PIC X.
           05  WS-T3           PIC X.
       01  WS-NORM.
           05  WS-NO1          PIC X.
           05  WS-NO2          PIC X.
           05  WS-NO3          PIC X.
       01  WS-NORM-N REDEFINES WS-NORM PIC 999.
       LINKAGE SECTION.
       01  VAL-AREA.
           05  V-SCALE         PIC X.
           05  V-NOTES         PIC XX.
           05  V-TEMPO         PIC XXX.
           05  V-RC            PIC X.
           05  V-SC            PIC X.
           05  V-NN.
               10  V-NN1       PIC X.
               10  V-NN2       PIC X.
           05  V-TM            PIC XXX.
       PROCEDURE DIVISION USING VAL-AREA.
       000-MAIN.
           MOVE '0' TO V-RC.
           PERFORM 100-CHECK-SCALE.
           IF V-RC = '0' PERFORM 200-CHECK-NOTES.
           IF V-RC = '0' PERFORM 300-CHECK-TEMPO.
           IF V-RC = '0' PERFORM 400-SET-OUTPUT.
           GOBACK.
      * --- Scale: blank, or one digit 0 to 8 --------------------
       100-CHECK-SCALE.
           IF V-SCALE = SPACE NEXT SENTENCE
           ELSE IF V-SCALE < '0' MOVE '1' TO V-RC
           ELSE IF V-SCALE > '8' MOVE '1' TO V-RC.
      * --- Notes: typed as 8 or 08 both work; 10 to 16 ----------
       200-CHECK-NOTES.
           MOVE V-NOTES TO WS-NOTES.
           IF WS-N1 = SPACE MOVE WS-N2 TO WS-N1
               MOVE SPACE TO WS-N2.
           IF WS-N1 = SPACE NEXT SENTENCE
           ELSE IF WS-N1 NOT NUMERIC MOVE '2' TO V-RC
           ELSE IF WS-N2 = SPACE PERFORM 210-ONE-DIGIT
           ELSE PERFORM 220-TWO-DIGITS.
       210-ONE-DIGIT.
           IF WS-N1 = '0' NEXT SENTENCE
           ELSE IF WS-N1 < '8' MOVE '2' TO V-RC.
       220-TWO-DIGITS.
           IF WS-N2 NOT NUMERIC MOVE '2' TO V-RC
           ELSE IF WS-N1 NOT = '1' MOVE '2' TO V-RC
           ELSE IF WS-N2 > '6' MOVE '2' TO V-RC.
      * --- Tempo: digits typed from the left, 1 to 3 of them ----
      * --- WS-NORM gets them right-justified and zero filled ----
       300-CHECK-TEMPO.
           MOVE V-TEMPO TO WS-TEMPO-X.
           MOVE '000' TO WS-NORM.
           IF WS-T3 NOT = SPACE PERFORM 310-THREE-DIGITS
           ELSE IF WS-T2 NOT = SPACE PERFORM 320-TWO-DIGITS
           ELSE IF WS-T1 NOT = SPACE PERFORM 330-ONE-DIGIT.
           IF V-RC = '0' PERFORM 340-CHECK-RANGE.
       310-THREE-DIGITS.
           IF WS-TEMPO-X NUMERIC MOVE WS-TEMPO-X TO WS-NORM
           ELSE MOVE '3' TO V-RC.
       320-TWO-DIGITS.
           IF WS-T1 NUMERIC AND WS-T2 NUMERIC
               MOVE WS-T1 TO WS-NO2
               MOVE WS-T2 TO WS-NO3
           ELSE MOVE '3' TO V-RC.
       330-ONE-DIGIT.
           IF WS-T1 NUMERIC MOVE WS-T1 TO WS-NO3
           ELSE MOVE '3' TO V-RC.
       340-CHECK-RANGE.
           IF WS-NORM-N = 0 NEXT SENTENCE
           ELSE IF WS-NORM-N < 40 MOVE '3' TO V-RC
           ELSE IF WS-NORM-N > 240 MOVE '3' TO V-RC.
      * --- Everything passed: digits for the SYSIN card ---------
       400-SET-OUTPUT.
           MOVE WS-NORM TO V-TM.
           MOVE '00' TO V-NN.
           IF WS-N1 NOT = SPACE MOVE WS-N1 TO V-NN2.
           IF WS-N2 NOT = SPACE MOVE WS-N1 TO V-NN1
               MOVE WS-N2 TO V-NN2.
           IF V-SCALE = SPACE MOVE '0' TO V-SC
           ELSE MOVE V-SCALE TO V-SC.
