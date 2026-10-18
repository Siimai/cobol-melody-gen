      * ============================================================
      * MELOKIK - KICKS transaction MELO (command-level COBOL).
      * Pseudo-conversational front end for the melody generator.
      * The scale table, notes and 16-bit LCG are the same as in
      * MELODY68 (assembler panel version); only the terminal I/O
      * is different: SEND MAP / RECEIVE MAP instead of ACCEPT and
      * DISPLAY, ASKTIME for the seed, and the result is kept in the
      * temporary storage queue MELO<terminal id>.
      * Target compiler is COBOL F (COBOL-68): period-terminated
      * sentences, PERFORM paragraph, no END-xxx, no intrinsics.
      * ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MELOKIK.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       77  WS-ABS              PIC S9(15) COMP-3.
       77  WS-TIME             PIC 9(15).
       77  WS-SEED             PIC 9(5).
       77  WS-WORK             PIC 9(10).
       77  WS-QUOT             PIC 9(15).
       77  WS-RANGE            PIC 99.
       77  WS-PICK             PIC 99.
       77  WS-LEN              PIC 99.
       77  WS-IX               PIC 99.
       77  WS-SCX              PIC 9.
       77  WS-NX               PIC 9.
       77  WS-TEMPO            PIC 999.
       77  WS-IN-SCALE         PIC 9.
       77  WS-IN-LEN           PIC 99.
       77  WS-IN-TEMPO         PIC 999.
       77  WS-RESP             PIC S9(8) COMP.
       77  WS-L4               PIC S9(4) COMP VALUE 4.
       77  WS-L24              PIC S9(4) COMP VALUE 24.
       77  WS-L1               PIC S9(4) COMP VALUE 1.
       77  WS-ITEM             PIC S9(4) COMP.
      * --- Key codes (standard 3270 AID bytes) ------------------
       77  WS-PF3              PIC X VALUE '3'.
       77  WS-CLEAR            PIC X VALUE '_'.
      * --- Last input, kept in the COMMAREA between the screens --
       01  WS-COMM.
           05  WS-C-SCALE      PIC X     VALUE SPACE.
           05  WS-C-LEN        PIC XX    VALUE SPACES.
           05  WS-C-TEMPO      PIC XXX   VALUE SPACES.
      * --- X'80' = the user erased the field with EraseEOF ------
       01  WS-ERA-G.
           05  WS-ERA-N        PIC S9(4) COMP VALUE 128.
       01  WS-ERA-R REDEFINES WS-ERA-G.
           05  FILLER          PIC X.
           05  WS-ERA-C        PIC X.
       01  WS-QNAME.
           05  FILLER          PIC X(4) VALUE 'MELO'.
           05  WS-QTERM        PIC X(4).
       01  WS-BYE              PIC X(28)
               VALUE 'MELO ENDED. HAVE A NICE DAY.'.
       01  WS-MSG.
           05  FILLER          PIC X(24)
               VALUE 'MELODY KEPT IN TS QUEUE '.
           05  WS-MSG-Q        PIC X(8).
       01  WS-HDR.
           05  WS-H-SCALE      PIC X(16).
           05  WS-H-LEN        PIC 99.
           05  WS-H-TEMPO      PIC 999.
           05  FILLER          PIC X(3) VALUE SPACES.
      * --- Scale table (8 scales, 7 two-char notes each) --------
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
           05  FILLER          PIC X(16) VALUE 'D DORIAN'.
           05  FILLER          PIC 9     VALUE 7.
           05  FILLER          PIC X(14) VALUE 'D E F G A B C '.
           05  FILLER          PIC X(16) VALUE 'E MINOR'.
           05  FILLER          PIC 9     VALUE 7.
           05  FILLER          PIC X(14) VALUE 'E F#G A B C D '.
           05  FILLER          PIC X(16) VALUE 'A MIN PENTATONIC'.
           05  FILLER          PIC 9     VALUE 5.
           05  FILLER          PIC X(14) VALUE 'A C D E G     '.
           05  FILLER          PIC X(16) VALUE 'E MIN PENTATONIC'.
           05  FILLER          PIC 9     VALUE 5.
           05  FILLER          PIC X(14) VALUE 'E G A B D     '.
       01  SCALE-TABLE REDEFINES SCALE-DATA.
           05  WS-SC           OCCURS 8 TIMES.
               10  WS-SC-NAME  PIC X(16).
               10  WS-SC-CNT   PIC 9.
               10  WS-SC-N     OCCURS 7 TIMES.
                   15  WS-SC-CH  PIC X.
                   15  WS-SC-AC  PIC X.
      * --- Melody: 16 notes of 4 chars + 1 blank, shown 4 a line --
       01  WS-MELODY.
           05  WS-M            OCCURS 16 TIMES.
               10  WS-M-CH     PIC X.
               10  WS-M-AC     PIC X.
               10  WS-M-OCT    PIC 9.
               10  WS-M-DUR    PIC X.
               10  FILLER      PIC X.
       01  WS-LINES REDEFINES WS-MELODY.
           05  WS-LINE         PIC X(20) OCCURS 4 TIMES.
      * --- Symbolic map (generated from MELMAP by the map proc) --
           COPY MELMAP.
       LINKAGE SECTION.
       01  DFHCOMMAREA         PIC X(6).
       PROCEDURE DIVISION.
       000-MAIN.
           IF EIBCALEN = 0 PERFORM 100-FIRST
           ELSE PERFORM 200-NEXT.
           EXEC CICS RETURN TRANSID('MELO')
               COMMAREA(WS-COMM) LENGTH(6)
           END-EXEC.
      * --- First call: show the empty form ----------------------
       100-FIRST.
           MOVE SPACES TO WS-COMM.
           MOVE LOW-VALUES TO MELMP1O.
           EXEC CICS SEND MAP('MELMP1') MAPSET('MELMAP')
               FROM(MELMP1O) ERASE
           END-EXEC.
      * --- Later calls: PF3 leaves, CLEAR redraws, Enter works --
       200-NEXT.
           MOVE DFHCOMMAREA TO WS-COMM.
           IF EIBAID = WS-PF3 PERFORM 900-LEAVE
           ELSE IF EIBAID = WS-CLEAR PERFORM 100-FIRST
           ELSE PERFORM 250-WORK.
       250-WORK.
           EXEC CICS RECEIVE MAP('MELMP1') MAPSET('MELMAP')
               RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP = DFHRESP(MAPFAIL) PERFORM 300-GENERATE
           ELSE PERFORM 260-TAKE-INPUT.
      * --- A field that was sent replaces the remembered value, an
      * --- erased one blanks it, an untouched one keeps it --------
       260-TAKE-INPUT.
           IF SCALEL > 0 MOVE SCALEI TO WS-C-SCALE
           ELSE IF SCALEF = WS-ERA-C MOVE SPACE TO WS-C-SCALE.
           IF NLENL > 0 MOVE NLENI TO WS-C-LEN
           ELSE IF NLENF = WS-ERA-C MOVE SPACES TO WS-C-LEN.
           IF TEMPOL > 0 MOVE TEMPOI TO WS-C-TEMPO
           ELSE IF TEMPOF = WS-ERA-C MOVE SPACES TO WS-C-TEMPO.
           PERFORM 300-GENERATE.
       300-GENERATE.
           PERFORM 310-SEED.
           PERFORM 320-READ-INPUT.
           PERFORM 400-ONE-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
           PERFORM 500-SHOW.
           PERFORM 600-KEEP.
      * --- Seed from ASKTIME: milliseconds, low 16 bits ---------
       310-SEED.
           EXEC CICS ASKTIME ABSTIME(WS-ABS) END-EXEC.
           MOVE WS-ABS TO WS-TIME.
           COMPUTE WS-QUOT = WS-TIME / 65536.
           COMPUTE WS-SEED = WS-TIME - WS-QUOT * 65536.
      * --- Same defaults as MELODY68: 0 = random, 120 BPM -------
       320-READ-INPUT.
           MOVE 0 TO WS-IN-SCALE.
           IF WS-C-SCALE NUMERIC MOVE WS-C-SCALE TO WS-IN-SCALE.
           MOVE 0 TO WS-IN-LEN.
           IF WS-C-LEN NUMERIC MOVE WS-C-LEN TO WS-IN-LEN.
           MOVE 0 TO WS-IN-TEMPO.
           IF WS-C-TEMPO NUMERIC MOVE WS-C-TEMPO TO WS-IN-TEMPO.
           MOVE WS-IN-SCALE TO WS-SCX.
           IF WS-SCX < 1 PERFORM 330-PICK-SCALE
           ELSE IF WS-SCX > 8 PERFORM 330-PICK-SCALE.
           MOVE WS-IN-LEN TO WS-LEN.
           IF WS-LEN < 8 PERFORM 340-PICK-LEN
           ELSE IF WS-LEN > 16 PERFORM 340-PICK-LEN.
           MOVE WS-IN-TEMPO TO WS-TEMPO.
           IF WS-TEMPO < 40 MOVE 120 TO WS-TEMPO
           ELSE IF WS-TEMPO > 240 MOVE 120 TO WS-TEMPO.
           MOVE SPACES TO WS-MELODY.
       330-PICK-SCALE.
           MOVE 8 TO WS-RANGE.
           PERFORM 450-RANDOM.
           COMPUTE WS-SCX = WS-PICK + 1.
       340-PICK-LEN.
           MOVE 9 TO WS-RANGE.
           PERFORM 450-RANDOM.
           COMPUTE WS-LEN = WS-PICK + 8.
      * --- Build note WS-IX: pitch, octave 4/5, duration --------
       400-ONE-NOTE.
           MOVE WS-SC-CNT (WS-SCX) TO WS-RANGE.
           PERFORM 450-RANDOM.
           COMPUTE WS-NX = WS-PICK + 1.
           MOVE WS-SC-CH (WS-SCX, WS-NX) TO WS-M-CH (WS-IX).
           MOVE WS-SC-AC (WS-SCX, WS-NX) TO WS-M-AC (WS-IX).
           MOVE 2 TO WS-RANGE.
           PERFORM 450-RANDOM.
           COMPUTE WS-M-OCT (WS-IX) = WS-PICK + 4.
           MOVE 20 TO WS-RANGE.
           PERFORM 450-RANDOM.
           IF WS-PICK < 10 MOVE 'Q' TO WS-M-DUR (WS-IX)
           ELSE IF WS-PICK < 15 MOVE 'H' TO WS-M-DUR (WS-IX)
           ELSE IF WS-PICK < 18 MOVE 'E' TO WS-M-DUR (WS-IX)
           ELSE MOVE 'W' TO WS-M-DUR (WS-IX).
      * --- Next LCG value, then WS-PICK in 0 .. WS-RANGE-1 ------
       450-RANDOM.
           COMPUTE WS-WORK = WS-SEED * 25173 + 13849.
           COMPUTE WS-QUOT = WS-WORK / 65536.
           COMPUTE WS-SEED = WS-WORK - WS-QUOT * 65536.
           COMPUTE WS-WORK = WS-SEED * WS-RANGE.
           COMPUTE WS-PICK = WS-WORK / 65536.
      * --- Send the result on the same form ---------------------
       500-SHOW.
           MOVE LOW-VALUES TO MELMP1O.
           MOVE WS-C-SCALE TO SCALEO.
           MOVE WS-C-LEN TO NLENO.
           MOVE WS-C-TEMPO TO TEMPOO.
           MOVE WS-SC-NAME (WS-SCX) TO SNAMEO.
           MOVE WS-LEN TO NCOUNTO.
           MOVE WS-TEMPO TO NTEMPOO.
           MOVE WS-LINE (1) TO NOTES1O.
           MOVE WS-LINE (2) TO NOTES2O.
           MOVE WS-LINE (3) TO NOTES3O.
           MOVE WS-LINE (4) TO NOTES4O.
           MOVE EIBTRMID TO WS-QTERM.
           MOVE WS-QNAME TO WS-MSG-Q.
           MOVE WS-MSG TO MSGO.
           EXEC CICS SEND MAP('MELMP1') MAPSET('MELMAP')
               FROM(MELMP1O) DATAONLY
           END-EXEC.
      * --- Keep it: item 1 = header, items 2.. = notes ----------
       600-KEEP.
           EXEC CICS DELETEQ TS QUEUE(WS-QNAME) RESP(WS-RESP)
           END-EXEC.
           MOVE WS-SC-NAME (WS-SCX) TO WS-H-SCALE.
           MOVE WS-LEN TO WS-H-LEN.
           MOVE WS-TEMPO TO WS-H-TEMPO.
           EXEC CICS WRITEQ TS QUEUE(WS-QNAME) FROM(WS-HDR)
               LENGTH(WS-L24) NOSUSPEND
           END-EXEC.
           PERFORM 650-KEEP-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
       650-KEEP-NOTE.
           EXEC CICS WRITEQ TS QUEUE(WS-QNAME) FROM(WS-M (WS-IX))
               LENGTH(WS-L4) NOSUSPEND
           END-EXEC.
       900-LEAVE.
           EXEC CICS SEND TEXT FROM(WS-BYE) LENGTH(28) ERASE FREEKB
           END-EXEC.
           EXEC CICS RETURN END-EXEC.
