      * ============================================================
      * MELOKIK - KICKS transaction MELO (command-level COBOL).
      * Pseudo-conversational front end for the melody generator,
      * with the same functions as the assembler panel (MELPNL):
      *   Enter  run a melody (rules from MELVAL)
      *   PF5    save it in the VSAM file MELSAVE (KSDS, key = 3
      *          digit number; record layout from MELSAV)
      *   PF6    list the last 10 saved melodies, type a number and
      *          Enter to load one
      *   PF7    MIDI file as hex text (MELMID) to the transient
      *          data destination MIDI, between *MIDI-BEGIN and
      *          *MIDI-END, for mvs/midi-from-mvs.sh
      *   PF3    leave (from the list: back to the melody)
      *   CLEAR  start again
      * The scale table and the 16-bit LCG are the same as in
      * MELODY68. The program ends after every screen; the state
      * (last input, shown melody, view) is passed in the COMMAREA.
      * MELVAL, MELSAV and MELMID are linked in from MELODY.LOAD.
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
       77  WS-JX               PIC 99.
       77  WS-KX               PIC 99.
       77  WS-SCX              PIC 9.
       77  WS-NX               PIC 9.
       77  WS-TEMPO            PIC 999.
       77  WS-RESP             PIC S9(8) COMP.
       77  WS-L80              PIC S9(4) COMP VALUE 80.
       77  WS-L3               PIC S9(4) COMP VALUE 3.
       77  WS-EOF              PIC X.
       77  NSAV                PIC S9(4) COMP.
       77  MAXNUM              PIC 999.
       77  WS-BR               PIC X.
       77  WS-MKIND            PIC X VALUE SPACE.
       77  WS-SCN              PIC 9.
       77  WS-NR               PIC 99.
       77  WS-OC               PIC 9.
       77  WS-TI               PIC 99.
       77  WS-SEMI             PIC 99.
       77  WS-KEYV             PIC 999.
       77  WS-KMIN             PIC 999.
       77  WS-KMAX             PIC 999.
       77  WS-NDR              PIC 99.
       77  WS-NDR2             PIC 99.
       77  WS-MODE             PIC X.
       77  WS-TAKE             PIC X.
       77  WS-FOUND            PIC X.
       77  WS-SI               PIC 99.
       77  WS-SJ               PIC 99.
       77  WS-SK               PIC 99.
       77  WS-TMPK             PIC 999.
       77  WS-ND               PIC 9.
       77  WS-TMPL             PIC X(4).
       77  WS-FR1              PIC 999 VALUE 0.
       77  WS-FR2              PIC 999 VALUE 0.
      * --- Key codes (the EBCDIC characters of the AID bytes) ---
       77  WS-PF3              PIC X VALUE '3'.
       77  WS-PF5              PIC X VALUE '5'.
       77  WS-PF6              PIC X VALUE '6'.
       77  WS-PF7              PIC X VALUE '7'.
       77  WS-CLEAR            PIC X VALUE '_'.
       01  WS-NUM3-G.
           05  WS-NUM3         PIC 999.
       01  WS-NUM3-X REDEFINES WS-NUM3-G.
           05  WS-NUM3-C       PIC XXX.
      * --- 3270 colour codes (the low byte of a halfword): X'F1'
      * --- blue, F2 red, F3 pink, F4 green, F5 turquoise, F6 yellow
       01  WS-COLORS.
           05  WS-BLU-N        PIC S9(4) COMP VALUE 241.
           05  WS-RED-N        PIC S9(4) COMP VALUE 242.
           05  WS-PNK-N        PIC S9(4) COMP VALUE 243.
           05  WS-GRN-N        PIC S9(4) COMP VALUE 244.
           05  WS-TRQ-N        PIC S9(4) COMP VALUE 245.
           05  WS-YEL-N        PIC S9(4) COMP VALUE 246.
       01  WS-COLOR-R REDEFINES WS-COLORS.
           05  FILLER          PIC X.
           05  WS-BLU          PIC X.
           05  FILLER          PIC X.
           05  WS-RED          PIC X.
           05  FILLER          PIC X.
           05  WS-PNK          PIC X.
           05  FILLER          PIC X.
           05  WS-GRN          PIC X.
           05  FILLER          PIC X.
           05  WS-TRQ          PIC X.
           05  FILLER          PIC X.
           05  WS-YEL          PIC X.
      * --- X'80' = the user erased the field with EraseEOF ------
       01  WS-ERA-G.
           05  WS-ERA-N        PIC S9(4) COMP VALUE 128.
       01  WS-ERA-R REDEFINES WS-ERA-G.
           05  FILLER          PIC X.
           05  WS-ERA-C        PIC X.
      * --- State kept in the COMMAREA between the screens -------
       01  WS-COMM.
           05  WS-C-SCALE      PIC X     VALUE SPACE.
           05  WS-C-LEN        PIC XX    VALUE SPACES.
           05  WS-C-TEMPO      PIC XXX   VALUE SPACES.
           05  CA-HAV          PIC X     VALUE 'N'.
           05  CA-VIEW         PIC X     VALUE 'M'.
           05  CA-SC           PIC 9     VALUE 0.
           05  CA-CNT          PIC 99    VALUE 0.
           05  CA-TM           PIC 999   VALUE 0.
           05  CA-NOTES.
               10  CA-N        OCCURS 16 TIMES.
                   15  CA-N-CH   PIC X.
                   15  CA-N-AC   PIC X.
                   15  CA-N-OCT  PIC 9.
                   15  CA-N-DUR  PIC X.
       01  WS-BYE              PIC X(28)
               VALUE 'MELO ENDED. HAVE A NICE DAY.'.
      * --- Status line text ------------------------------------
       01  WS-MSG              PIC X(70) VALUE SPACES.
       01  MSG-SAVED.
           05  FILLER          PIC X(10) VALUE 'SAVED AS #'.
           05  MS-NUM          PIC XXX.
           05  FILLER          PIC X(57) VALUE SPACES.
       01  MSG-LOADED.
           05  FILLER          PIC X(8) VALUE 'LOADED #'.
           05  ML-NUM          PIC XXX.
           05  FILLER          PIC X(59) VALUE SPACES.
       01  MSG-FAIL.
           05  FILLER          PIC X(26)
               VALUE 'MIDI EXPORT FAILED - RESP '.
           05  MF-R1           PIC 999.
           05  FILLER          PIC X(7) VALUE ' RESP2 '.
           05  MF-R2           PIC 999.
           05  FILLER          PIC X(31) VALUE SPACES.
       01  MSG-MIDI.
           05  FILLER          PIC X(16) VALUE 'MIDI EXPORTED - '.
           05  MM-BYTES        PIC XXX.
           05  FILLER          PIC X(30)
               VALUE ' BYTES - DATA SET MELODY.MIDIK'.
           05  FILLER          PIC X(21) VALUE SPACES.
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
      * --- Piano roll work areas -------------------------------
      * --- pitch rows the scale offers (octaves 4 and 5), sorted from
      * --- the highest down; key = octave * 12 + semitone ---------
       01  WS-CAND.
           05  WS-CD           OCCURS 14 TIMES.
               10  WS-CD-KEY   PIC 999.
               10  WS-CD-LBL   PIC X(4).
      * --- the rows that are drawn (at most 12) --------------------
       01  WS-DISP.
           05  WS-DR           OCCURS 12 TIMES.
               10  WS-DR-KEY   PIC 999.
               10  WS-DR-LBL   PIC X(4).
      * --- pitch key of each note of the melody -------------------
       01  WS-NK.
           05  WS-NKEY         PIC 999 OCCURS 16 TIMES.
       01  WS-LBLW.
           05  WS-LB-CH        PIC X.
           05  WS-LB-AC        PIC X.
           05  WS-LB-OC        PIC 9.
           05  FILLER          PIC X VALUE SPACE.
       01  WS-NG.
           05  WS-NG1          PIC X.
           05  WS-NG2          PIC X.
           05  WS-NG3          PIC X.
       01  WS-CELL.
           05  WS-CELL1        PIC X.
           05  WS-CELL2        PIC X.
      * --- Areas of the subprograms (same layout as in MELPNL) ---
       01  VAL-AREA.
           05  V-SCALE         PIC X.
           05  V-NOTES         PIC XX.
           05  V-TEMPO         PIC XXX.
           05  V-RC            PIC X.
           05  V-SC            PIC X.
           05  V-NN            PIC XX.
           05  V-TM            PIC XXX.
       01  SAV-AREA.
           05  S-FUNC          PIC X.
           05  S-RC            PIC X.
           05  S-NUM           PIC XXX.
           05  S-SC            PIC X.
           05  S-TM            PIC XXX.
           05  S-LEN           PIC XX.
           05  S-NOTES         PIC X(64).
           05  S-REC           PIC X(80).
           05  S-LINE          PIC X(44).
           05  S-RES1          PIC X(80).
           05  S-RES2          PIC X(80).
       01  MID-AREA.
           05  M-TEMPO         PIC XXX.
           05  M-COUNT         PIC XX.
           05  M-NOTES         PIC X(64).
           05  M-BYTES         PIC XXX.
           05  M-LINES         PIC 9.
           05  M-HEX.
               10  M-HEX-LINE  PIC X(64) OCCURS 6 TIMES.
       01  MID-REC             PIC X(80).
       01  MID-HEX REDEFINES MID-REC.
           05  FILLER          PIC X.
           05  MR-HEX          PIC X(64).
           05  FILLER          PIC X(15).
      * --- VSAM record and the list of the last 10 --------------
       01  WS-KEY              PIC XXX.
       01  WS-REC              PIC X(80).
       01  WS-REC-K REDEFINES WS-REC.
           05  WS-REC-NUM      PIC XXX.
           05  FILLER          PIC X(77).
       01  SAVEDT.
           05  SD-ENT          PIC X(80) OCCURS 10 TIMES.
       01  WS-ROWS.
           05  WS-ROW          PIC X(44) OCCURS 10 TIMES.
      * --- Symbolic maps (generated from MELMAP by the map proc) --
           COPY MELMAP.
      * --- The piano roll record (map MELMP3) with subscripts: a
      * --- number row, then 12 rows of a label and 16 cells; every
      * --- field is L(2) A(1) C P H V (4) and the data ------------
       01  ROLL-O REDEFINES MELMP1I.
           05  FILLER          PIC X(12).
           05  FILLER          PIC X(8).
           05  FILLER          PIC XX.
           05  FILLER          PIC X.
           05  FILLER          PIC X.
           05  FILLER          PIC X(3).
           05  RL-NUM.
               10  RL-NG       PIC XXX OCCURS 16 TIMES.
           05  RL-ROW          OCCURS 12 TIMES.
               10  FILLER      PIC XX.
               10  RL-LA       PIC X.
               10  RL-LC       PIC X.
               10  FILLER      PIC X(3).
               10  RL-LBL      PIC X(4).
               10  RL-CELL     OCCURS 16 TIMES.
                   15  FILLER  PIC XX.
                   15  RL-CA   PIC X.
                   15  RL-CC   PIC X.
                   15  FILLER  PIC X(3).
                   15  RL-CD   PIC XX.
       LINKAGE SECTION.
       01  DFHCOMMAREA         PIC X(78).
       PROCEDURE DIVISION.
       000-MAIN.
           IF EIBCALEN = 0 PERFORM 100-NEW
           ELSE PERFORM 200-NEXT.
           EXEC CICS RETURN TRANSID('MELO')
               COMMAREA(WS-COMM) LENGTH(78)
           END-EXEC.
      * --- First call and CLEAR: an empty form -------------------
       100-NEW.
           MOVE SPACES TO WS-COMM.
           MOVE 'N' TO CA-HAV.
           MOVE 'M' TO CA-VIEW.
           MOVE 0 TO CA-SC.
           MOVE 0 TO CA-CNT.
           MOVE 0 TO CA-TM.
           MOVE
           'ENTER SCALE 0-8, NOTES AND TEMPO, THEN PRESS ENTER'
               TO WS-MSG.
           PERFORM 500-SHOW-MAIN.
      * --- Later calls: act on the key --------------------------
       200-NEXT.
           MOVE DFHCOMMAREA TO WS-COMM.
           MOVE SPACES TO WS-MSG.
           MOVE SPACE TO WS-MKIND.
           IF EIBAID = WS-PF3 PERFORM 210-PF3
           ELSE IF EIBAID = WS-CLEAR PERFORM 100-NEW
           ELSE IF EIBAID = WS-PF5 PERFORM 220-PF5
           ELSE IF EIBAID = WS-PF6 PERFORM 810-LIST
           ELSE IF EIBAID = WS-PF7 PERFORM 230-PF7
           ELSE PERFORM 240-ENTER.
       210-PF3.
           IF CA-VIEW = 'L' PERFORM 215-BACK
           ELSE PERFORM 900-LEAVE.
       215-BACK.
           MOVE 'M' TO CA-VIEW.
           MOVE 'ENTER SCALE 0-8, NOTES AND TEMPO, THEN PRESS ENTER'
               TO WS-MSG.
           PERFORM 500-SHOW-MAIN.
       220-PF5.
           IF CA-VIEW = 'L' PERFORM 812-REDRAW
           ELSE PERFORM 800-SAVE.
       230-PF7.
           IF CA-VIEW = 'L' PERFORM 812-REDRAW
           ELSE PERFORM 830-MIDI.
       240-ENTER.
           IF CA-VIEW = 'L' PERFORM 820-LOAD
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
      * --- Check the input (MELVAL), then run -------------------
       300-GENERATE.
           MOVE WS-C-SCALE TO V-SCALE.
           MOVE WS-C-LEN TO V-NOTES.
           MOVE WS-C-TEMPO TO V-TEMPO.
           CALL 'MELVAL' USING VAL-AREA.
           IF V-RC = '0' PERFORM 310-RUN
           ELSE PERFORM 305-BAD.
       305-BAD.
           MOVE 'R' TO WS-MKIND.
           IF V-RC = '1'
               MOVE 'INVALID SCALE - USE 0 TO 8, OR LEAVE BLANK'
                   TO WS-MSG
           ELSE IF V-RC = '2'
               MOVE 'INVALID NOTES - USE 8 TO 16, OR 0 FOR RANDOM'
                   TO WS-MSG
           ELSE
               MOVE 'INVALID TEMPO - USE 40 TO 240, OR LEAVE BLANK'
                   TO WS-MSG.
           PERFORM 500-SHOW-MAIN.
       310-RUN.
           PERFORM 311-SEED.
           MOVE V-SC TO WS-SCX.
           IF WS-SCX < 1 PERFORM 330-PICK-SCALE
           ELSE IF WS-SCX > 8 PERFORM 330-PICK-SCALE.
           MOVE V-NN TO WS-LEN.
           IF WS-LEN < 8 PERFORM 340-PICK-LEN
           ELSE IF WS-LEN > 16 PERFORM 340-PICK-LEN.
           MOVE V-TM TO WS-TEMPO.
           IF WS-TEMPO < 40 MOVE 120 TO WS-TEMPO
           ELSE IF WS-TEMPO > 240 MOVE 120 TO WS-TEMPO.
           MOVE SPACES TO CA-NOTES.
           PERFORM 400-ONE-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
           MOVE WS-SCX TO CA-SC.
           MOVE WS-LEN TO CA-CNT.
           MOVE WS-TEMPO TO CA-TM.
           MOVE 'Y' TO CA-HAV.
           MOVE 'G' TO WS-MKIND.
           MOVE 'DONE - CHANGE INPUT, ENTER = RUN, PF5 = SAVE'
               TO WS-MSG.
           PERFORM 500-SHOW-MAIN.
      * --- Seed from ASKTIME: milliseconds, low 16 bits ---------
       311-SEED.
           EXEC CICS ASKTIME ABSTIME(WS-ABS) END-EXEC.
           MOVE WS-ABS TO WS-TIME.
           COMPUTE WS-QUOT = WS-TIME / 65536.
           COMPUTE WS-SEED = WS-TIME - WS-QUOT * 65536.
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
           MOVE WS-SC-CH (WS-SCX, WS-NX) TO CA-N-CH (WS-IX).
           MOVE WS-SC-AC (WS-SCX, WS-NX) TO CA-N-AC (WS-IX).
           MOVE 2 TO WS-RANGE.
           PERFORM 450-RANDOM.
           COMPUTE CA-N-OCT (WS-IX) = WS-PICK + 4.
           MOVE 20 TO WS-RANGE.
           PERFORM 450-RANDOM.
           IF WS-PICK < 10 MOVE 'Q' TO CA-N-DUR (WS-IX)
           ELSE IF WS-PICK < 15 MOVE 'H' TO CA-N-DUR (WS-IX)
           ELSE IF WS-PICK < 18 MOVE 'E' TO CA-N-DUR (WS-IX)
           ELSE MOVE 'W' TO CA-N-DUR (WS-IX).
      * --- Next LCG value, then WS-PICK in 0 .. WS-RANGE-1 ------
       450-RANDOM.
           COMPUTE WS-WORK = WS-SEED * 25173 + 13849.
           COMPUTE WS-QUOT = WS-WORK / 65536.
           COMPUTE WS-SEED = WS-WORK - WS-QUOT * 65536.
           COMPUTE WS-WORK = WS-SEED * WS-RANGE.
           COMPUTE WS-PICK = WS-WORK / 65536.
      * --- The melody form: input fields as used, the melody ----
       500-SHOW-MAIN.
           MOVE LOW-VALUES TO MELMP1O.
           MOVE WS-C-SCALE TO SCALEO.
           MOVE WS-C-LEN TO NLENO.
           MOVE WS-C-TEMPO TO TEMPOO.
           IF WS-C-SCALE NUMERIC PERFORM 505-SCALE-NAME.
           IF CA-HAV = 'Y' PERFORM 510-FILL-MELODY.
           MOVE WS-MSG TO MSGO.
           IF WS-MKIND = 'R' MOVE WS-RED TO MSGC.
           IF WS-MKIND = 'G' MOVE WS-GRN TO MSGC.
           IF WS-MKIND = 'R' PERFORM 508-SEND-ALARM
           ELSE PERFORM 509-SEND.
           IF CA-HAV = 'Y' PERFORM 550-ROLL.
       505-SCALE-NAME.
           IF WS-C-SCALE > '0' IF WS-C-SCALE < '9'
               MOVE WS-C-SCALE TO WS-SCN
               MOVE WS-SC-NAME (WS-SCN) TO SCNAMEO.
       508-SEND-ALARM.
           EXEC CICS SEND MAP('MELMP1') MAPSET('MELMAP')
               FROM(MELMP1O) ERASE ALARM FREEKB FRSET
           END-EXEC.
       509-SEND.
           EXEC CICS SEND MAP('MELMP1') MAPSET('MELMAP')
               FROM(MELMP1O) ERASE FREEKB FRSET
           END-EXEC.
       510-FILL-MELODY.
           IF CA-SC > 0 MOVE WS-SC-NAME (CA-SC) TO SNAMEO.
           MOVE CA-CNT TO NCOUNTO.
           MOVE CA-TM TO NTEMPOO.
      * --- The piano roll: one row for each pitch from the highest
      * --- note down to the lowest, one column for each note, the
      * --- duration letter in the cell, coloured by duration ------
       550-ROLL.
           PERFORM 551-CANDIDATES.
           PERFORM 553-SORT.
           PERFORM 555-RANGE.
           PERFORM 557-SELECT.
           PERFORM 560-BUILD.
           EXEC CICS SEND MAP('MELMP3') MAPSET('MELMAP')
               FROM(MELMP3O) FREEKB FRSET
           END-EXEC.
       551-CANDIDATES.
           MOVE 0 TO WS-NR.
           PERFORM 552-OCT VARYING WS-OC FROM 4 BY 1 UNTIL WS-OC > 5.
       552-OCT.
           PERFORM 552A-TONE VARYING WS-TI FROM 1 BY 1
               UNTIL WS-TI > WS-SC-CNT (CA-SC).
       552A-TONE.
           MOVE WS-SC-CH (CA-SC, WS-TI) TO WS-LB-CH.
           MOVE WS-SC-AC (CA-SC, WS-TI) TO WS-LB-AC.
           MOVE WS-OC TO WS-LB-OC.
           PERFORM 570-SEMI.
           COMPUTE WS-KEYV = WS-OC * 12 + WS-SEMI.
           ADD 1 TO WS-NR.
           MOVE WS-KEYV TO WS-CD-KEY (WS-NR).
           MOVE WS-LBLW TO WS-CD-LBL (WS-NR).
       553-SORT.
           PERFORM 554-PASS VARYING WS-SI FROM 1 BY 1
               UNTIL WS-SI > WS-NR.
       554-PASS.
           PERFORM 554A-CMP VARYING WS-SJ FROM 1 BY 1
               UNTIL WS-SJ NOT < WS-NR.
       554A-CMP.
           COMPUTE WS-SK = WS-SJ + 1.
           IF WS-CD-KEY (WS-SJ) < WS-CD-KEY (WS-SK)
               PERFORM 554B-SWAP.
       554B-SWAP.
           MOVE WS-CD-KEY (WS-SJ) TO WS-TMPK.
           MOVE WS-CD-LBL (WS-SJ) TO WS-TMPL.
           MOVE WS-CD-KEY (WS-SK) TO WS-CD-KEY (WS-SJ).
           MOVE WS-CD-LBL (WS-SK) TO WS-CD-LBL (WS-SJ).
           MOVE WS-TMPK TO WS-CD-KEY (WS-SK).
           MOVE WS-TMPL TO WS-CD-LBL (WS-SK).
      * --- lowest and highest key of the melody -----------------
       555-RANGE.
           MOVE 999 TO WS-KMIN.
           MOVE 0 TO WS-KMAX.
           PERFORM 556-NOTEKEY VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > CA-CNT.
       556-NOTEKEY.
           MOVE CA-N-CH (WS-IX) TO WS-LB-CH.
           MOVE CA-N-AC (WS-IX) TO WS-LB-AC.
           PERFORM 570-SEMI.
           COMPUTE WS-KEYV = CA-N-OCT (WS-IX) * 12 + WS-SEMI.
           MOVE WS-KEYV TO WS-NKEY (WS-IX).
           IF WS-KEYV < WS-KMIN MOVE WS-KEYV TO WS-KMIN.
           IF WS-KEYV > WS-KMAX MOVE WS-KEYV TO WS-KMAX.
      * --- every scale pitch between the lowest and highest note;
      * --- if that is more than 12 rows, only the pitches in use --
       557-SELECT.
           MOVE 0 TO WS-NDR.
           PERFORM 558-COUNT VARYING WS-JX FROM 1 BY 1
               UNTIL WS-JX > WS-NR.
           IF WS-NDR > 12 MOVE 'U' TO WS-MODE
           ELSE MOVE 'R' TO WS-MODE.
           MOVE 0 TO WS-NDR2.
           PERFORM 559-TAKE VARYING WS-JX FROM 1 BY 1
               UNTIL WS-JX > WS-NR.
       558-COUNT.
           IF WS-CD-KEY (WS-JX) NOT > WS-KMAX
               IF WS-CD-KEY (WS-JX) NOT < WS-KMIN ADD 1 TO WS-NDR.
       559-TAKE.
           IF WS-CD-KEY (WS-JX) NOT > WS-KMAX
               IF WS-CD-KEY (WS-JX) NOT < WS-KMIN PERFORM 559A-ADD.
       559A-ADD.
           MOVE 'N' TO WS-TAKE.
           IF WS-MODE = 'R' MOVE 'Y' TO WS-TAKE
           ELSE PERFORM 559B-USED VARYING WS-KX FROM 1 BY 1
               UNTIL WS-KX > CA-CNT.
           IF WS-TAKE = 'Y'
               IF WS-NDR2 < 12 PERFORM 559C-ROW.
       559B-USED.
           IF WS-NKEY (WS-KX) = WS-CD-KEY (WS-JX)
               MOVE 'Y' TO WS-TAKE.
       559C-ROW.
           ADD 1 TO WS-NDR2.
           MOVE WS-CD-KEY (WS-JX) TO WS-DR-KEY (WS-NDR2).
           MOVE WS-CD-LBL (WS-JX) TO WS-DR-LBL (WS-NDR2).
      * --- Fill the record of map MELMP3 ------------------------
       560-BUILD.
           MOVE LOW-VALUES TO MELMP3O.
           PERFORM 561-NUMS VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > CA-CNT.
           PERFORM 562-ROW VARYING WS-JX FROM 1 BY 1
               UNTIL WS-JX > WS-NDR2.
           PERFORM 564-PLACE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > CA-CNT.
       561-NUMS.
           MOVE SPACES TO WS-NG.
           IF WS-IX < 10 PERFORM 561A-ONE
           ELSE PERFORM 561B-TWO.
           MOVE WS-NG TO RL-NG (WS-IX).
       561A-ONE.
           MOVE WS-IX TO WS-ND.
           MOVE WS-ND TO WS-NG1.
       561B-TWO.
           COMPUTE WS-ND = WS-IX - 10.
           MOVE '1' TO WS-NG1.
           MOVE WS-ND TO WS-NG2.
       562-ROW.
           MOVE WS-DR-LBL (WS-JX) TO RL-LBL (WS-JX).
           PERFORM 563-DOT VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > CA-CNT.
       563-DOT.
           MOVE '. ' TO RL-CD (WS-JX, WS-IX).
       564-PLACE.
           MOVE 'N' TO WS-FOUND.
           PERFORM 565-MATCH VARYING WS-JX FROM 1 BY 1
               UNTIL WS-JX > WS-NDR2 OR WS-FOUND = 'Y'.
       565-MATCH.
           IF WS-DR-KEY (WS-JX) = WS-NKEY (WS-IX)
               PERFORM 566-CELL.
       566-CELL.
           MOVE 'Y' TO WS-FOUND.
           MOVE CA-N-DUR (WS-IX) TO WS-CELL1.
           MOVE SPACE TO WS-CELL2.
           MOVE WS-CELL TO RL-CD (WS-JX, WS-IX).
           IF CA-N-DUR (WS-IX) = 'W'
               MOVE WS-PNK TO RL-CC (WS-JX, WS-IX)
           ELSE IF CA-N-DUR (WS-IX) = 'H'
               MOVE WS-YEL TO RL-CC (WS-JX, WS-IX)
           ELSE IF CA-N-DUR (WS-IX) = 'Q'
               MOVE WS-GRN TO RL-CC (WS-JX, WS-IX)
           ELSE MOVE WS-TRQ TO RL-CC (WS-JX, WS-IX).
      * --- semitone above C of WS-LB-CH / WS-LB-AC --------------
       570-SEMI.
           IF WS-LB-CH = 'C' MOVE 0 TO WS-SEMI
           ELSE IF WS-LB-CH = 'D' MOVE 2 TO WS-SEMI
           ELSE IF WS-LB-CH = 'E' MOVE 4 TO WS-SEMI
           ELSE IF WS-LB-CH = 'F' MOVE 5 TO WS-SEMI
           ELSE IF WS-LB-CH = 'G' MOVE 7 TO WS-SEMI
           ELSE IF WS-LB-CH = 'A' MOVE 9 TO WS-SEMI
           ELSE MOVE 11 TO WS-SEMI.
           IF WS-LB-AC = '#' ADD 1 TO WS-SEMI.
      * --- The list form ----------------------------------------
       590-SHOW-LIST.
           MOVE LOW-VALUES TO MELMP2O.
           MOVE WS-ROW (1) TO ROW01O.
           MOVE WS-ROW (2) TO ROW02O.
           MOVE WS-ROW (3) TO ROW03O.
           MOVE WS-ROW (4) TO ROW04O.
           MOVE WS-ROW (5) TO ROW05O.
           MOVE WS-ROW (6) TO ROW06O.
           MOVE WS-ROW (7) TO ROW07O.
           MOVE WS-ROW (8) TO ROW08O.
           MOVE WS-ROW (9) TO ROW09O.
           MOVE WS-ROW (10) TO ROW10O.
           MOVE WS-MSG TO MSG2O.
           IF WS-MKIND = 'R' MOVE WS-RED TO MSG2C.
           IF WS-MKIND = 'G' MOVE WS-GRN TO MSG2C.
           IF WS-MKIND = 'R' PERFORM 598-LIST-ALARM
           ELSE PERFORM 599-LIST-SEND.
       598-LIST-ALARM.
           EXEC CICS SEND MAP('MELMP2') MAPSET('MELMAP')
               FROM(MELMP2O) ERASE ALARM FREEKB FRSET
           END-EXEC.
       599-LIST-SEND.
           EXEC CICS SEND MAP('MELMP2') MAPSET('MELMAP')
               FROM(MELMP2O) ERASE FREEKB FRSET
           END-EXEC.
       900-LEAVE.
           EXEC CICS SEND TEXT FROM(WS-BYE) LENGTH(28) ERASE FREEKB
           END-EXEC.
           EXEC CICS RETURN END-EXEC.
      * --- Read the whole saved file: highest number (MAXNUM) and
      * --- the last 10 records (SD-ENT, NSAV of them) -----------
       840-SCAN.
           MOVE 0 TO NSAV.
           MOVE 0 TO MAXNUM.
           MOVE 'N' TO WS-EOF.
           MOVE 'N' TO WS-BR.
           MOVE '000' TO WS-KEY.
           EXEC CICS STARTBR DATASET('MELSAVE') RIDFLD(WS-KEY)
               KEYLENGTH(WS-L3) GTEQ RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP = DFHRESP(NORMAL) MOVE 'Y' TO WS-BR
           ELSE MOVE 'Y' TO WS-EOF.
           PERFORM 845-READ UNTIL WS-EOF = 'Y'.
           IF WS-BR = 'Y' PERFORM 849-END-BROWSE.
       845-READ.
           MOVE 80 TO WS-L80.
           MOVE 3 TO WS-L3.
           EXEC CICS READNEXT DATASET('MELSAVE') INTO(WS-REC)
               LENGTH(WS-L80) RIDFLD(WS-KEY) KEYLENGTH(WS-L3)
               RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP = DFHRESP(NORMAL) PERFORM 846-STORE
           ELSE MOVE 'Y' TO WS-EOF.
       846-STORE.
           MOVE WS-REC-NUM TO WS-NUM3-C.
           IF WS-NUM3 > MAXNUM MOVE WS-NUM3 TO MAXNUM.
           IF NSAV = 10 PERFORM 847-SHIFT VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > 9.
           IF NSAV = 10 MOVE 9 TO NSAV.
           ADD 1 TO NSAV.
           MOVE WS-REC TO SD-ENT (NSAV).
       847-SHIFT.
           COMPUTE WS-JX = WS-IX + 1.
           MOVE SD-ENT (WS-JX) TO SD-ENT (WS-IX).
       849-END-BROWSE.
           EXEC CICS ENDBR DATASET('MELSAVE') RESP(WS-RESP)
           END-EXEC.
      * --- PF5: append the shown melody to the file -------------
       800-SAVE.
           IF CA-HAV NOT = 'Y'
               MOVE 'NOTHING TO SAVE - RUN A MELODY FIRST' TO WS-MSG
               MOVE 'R' TO WS-MKIND
               PERFORM 500-SHOW-MAIN
           ELSE PERFORM 801-SAVE-IT.
       801-SAVE-IT.
           PERFORM 840-SCAN.
           ADD 1 TO MAXNUM.
           MOVE MAXNUM TO WS-NUM3.
           MOVE 'B' TO S-FUNC.
           MOVE WS-NUM3-C TO S-NUM.
           MOVE CA-SC TO S-SC.
           MOVE CA-TM TO S-TM.
           MOVE CA-CNT TO S-LEN.
           MOVE CA-NOTES TO S-NOTES.
           CALL 'MELSAV' USING SAV-AREA.
           MOVE S-REC TO WS-REC.
           MOVE S-NUM TO WS-KEY.
           MOVE 80 TO WS-L80.
           MOVE 3 TO WS-L3.
           EXEC CICS WRITE DATASET('MELSAVE') FROM(WS-REC)
               LENGTH(WS-L80) RIDFLD(WS-KEY) KEYLENGTH(WS-L3)
               RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE S-NUM TO MS-NUM
               MOVE 'G' TO WS-MKIND
               MOVE MSG-SAVED TO WS-MSG
           ELSE MOVE 'R' TO WS-MKIND
               MOVE 'SAVE FAILED - SEE THE SAVE FILE MELSAVE'
               TO WS-MSG.
           PERFORM 500-SHOW-MAIN.
      * --- PF6: the list of the last 10 saved melodies ----------
       810-LIST.
           PERFORM 811-BUILD-ROWS.
           MOVE 'L' TO CA-VIEW.
           MOVE 'TYPE A NUMBER AND PRESS ENTER TO LOAD IT' TO WS-MSG.
           PERFORM 590-SHOW-LIST.
       811-BUILD-ROWS.
           PERFORM 840-SCAN.
           PERFORM 813-ROW VARYING WS-IX FROM 1 BY 1 UNTIL WS-IX > 10.
       812-REDRAW.
           PERFORM 811-BUILD-ROWS.
           PERFORM 590-SHOW-LIST.
       813-ROW.
           MOVE SPACES TO WS-ROW (WS-IX).
           IF WS-IX NOT > NSAV PERFORM 814-ROW-TEXT.
       814-ROW-TEXT.
           MOVE 'R' TO S-FUNC.
           MOVE SD-ENT (WS-IX) TO S-REC.
           CALL 'MELSAV' USING SAV-AREA.
           MOVE S-LINE TO WS-ROW (WS-IX).
      * --- Enter on the list: show the saved melody typed in LD --
       820-LOAD.
           EXEC CICS RECEIVE MAP('MELMP2') MAPSET('MELMAP')
               RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP = DFHRESP(MAPFAIL) PERFORM 825-BAD
           ELSE IF LDL = 0 PERFORM 825-BAD
           ELSE PERFORM 821-LOAD-IT.
       821-LOAD-IT.
           MOVE 'N' TO S-FUNC.
           MOVE LDI TO S-NUM.
           CALL 'MELSAV' USING SAV-AREA.
           IF S-RC NOT = '0' PERFORM 825-BAD
           ELSE PERFORM 822-READ-IT.
       822-READ-IT.
           MOVE S-NUM TO WS-KEY.
           MOVE 80 TO WS-L80.
           MOVE 3 TO WS-L3.
           EXEC CICS READ DATASET('MELSAVE') INTO(WS-REC)
               LENGTH(WS-L80) RIDFLD(WS-KEY) KEYLENGTH(WS-L3)
               RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP = DFHRESP(NORMAL) PERFORM 823-SHOW-IT
           ELSE PERFORM 825-BAD.
       823-SHOW-IT.
           MOVE 'D' TO S-FUNC.
           MOVE WS-REC TO S-REC.
           CALL 'MELSAV' USING SAV-AREA.
           MOVE S-SC TO CA-SC.
           MOVE S-LEN TO CA-CNT.
           MOVE S-TM TO CA-TM.
           MOVE S-NOTES TO CA-NOTES.
           MOVE S-SC TO WS-C-SCALE.
           MOVE S-LEN TO WS-C-LEN.
           MOVE S-TM TO WS-C-TEMPO.
           MOVE 'Y' TO CA-HAV.
           MOVE 'M' TO CA-VIEW.
           MOVE S-NUM TO ML-NUM.
           MOVE 'G' TO WS-MKIND.
           MOVE MSG-LOADED TO WS-MSG.
           PERFORM 500-SHOW-MAIN.
       825-BAD.
           MOVE 'R' TO WS-MKIND.
           MOVE 'NO SUCH SAVED MELODY' TO WS-MSG.
           PERFORM 811-BUILD-ROWS.
           PERFORM 590-SHOW-LIST.
      * --- PF7: MELMID builds the MIDI file as hex text; write it
      * --- to the destination MIDI between *MIDI-BEGIN and
      * --- *MIDI-END, 64 hex characters a line -------------------
       830-MIDI.
           IF CA-HAV NOT = 'Y'
               MOVE 'NOTHING TO EXPORT - RUN A MELODY FIRST' TO WS-MSG
               MOVE 'R' TO WS-MKIND
               PERFORM 500-SHOW-MAIN
           ELSE PERFORM 831-EXPORT.
       831-EXPORT.
           MOVE 0 TO WS-FR1.
           MOVE 0 TO WS-FR2.
           MOVE CA-TM TO M-TEMPO.
           MOVE CA-CNT TO M-COUNT.
           MOVE CA-NOTES TO M-NOTES.
           CALL 'MELMID' USING MID-AREA.
           MOVE SPACES TO MID-REC.
           MOVE ' *MIDI-BEGIN' TO MID-REC.
           PERFORM 835-PUT.
           PERFORM 832-LINE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > M-LINES.
           MOVE SPACES TO MID-REC.
           MOVE ' *MIDI-END' TO MID-REC.
           PERFORM 835-PUT.
           IF WS-FR1 = 0
               MOVE M-BYTES TO MM-BYTES
               MOVE 'G' TO WS-MKIND
               MOVE MSG-MIDI TO WS-MSG
           ELSE PERFORM 836-FAIL-MSG.
           PERFORM 500-SHOW-MAIN.
       832-LINE.
           MOVE SPACES TO MID-REC.
           MOVE M-HEX-LINE (WS-IX) TO MR-HEX.
           PERFORM 835-PUT.
       835-PUT.
           MOVE 80 TO WS-L80.
           EXEC CICS WRITEQ TD QUEUE('MIDI') FROM(MID-REC)
               LENGTH(WS-L80) RESP(WS-RESP)
           END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL) IF WS-FR1 = 0
               MOVE WS-RESP TO WS-FR1
               MOVE EIBRESP2 TO WS-FR2.
       836-FAIL-MSG.
           MOVE 'R' TO WS-MKIND.
           MOVE WS-FR1 TO MF-R1.
           MOVE WS-FR2 TO MF-R2.
           MOVE MSG-FAIL TO WS-MSG.
