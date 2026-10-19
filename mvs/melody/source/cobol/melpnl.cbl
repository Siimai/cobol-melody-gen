      * ============================================================
      * MELPNL - the MELODY panel program (driver) for MVS 3.8j.
      * Start it from TSO with the MELPANEL CLIST:
      *   CALL 'MELODY.LOAD(MELSCR)' 'm,userid'
      * m = S  start: show the panel and handle the keys
      * m = W  wait: the batch job was submitted, wait for its
      *        result in DD OUT and show it
      * Return code 4 means "submit the job in DD RUNJCL, then call
      * me again with W"; 0 means the user left the panel.
      *
      * This program owns the program flow and all the files:
      *   RUNJCL  the run job and the input card (we write it)
      *   OUT     result of the batch job MELODY68 (we read it)
      *   SAVED   saved melodies, one 80-byte record each
      *   MIDI    last MIDI export, as hex text
      * It calls four subprograms:
      *   SCRSUB  assembler, only the 3270 screen (TPUT and TGET)
      *   MELVAL  checks scale, notes and tempo
      *   MELSAV  saved-melody records and the scale names
      *   MELMID  builds the Standard MIDI File as hex text
      * Target: IKFCBL00 (COBOL F), so COBOL-68 only: no END-xxx,
      * no inline PERFORM, no reference modification, no intrinsic
      * functions.  Link-edit with SCRSUB, MELVAL, MELSAV and MELMID.
      * ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MELPNL.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-360.
       OBJECT-COMPUTER. IBM-360.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT RJ-FILE ASSIGN TO UT-S-RUNJCL.
           SELECT OUT-FILE ASSIGN TO UT-S-OUT.
           SELECT SAV-FILE ASSIGN TO UT-S-SAVED.
           SELECT MID-FILE ASSIGN TO UT-S-MIDI.
       DATA DIVISION.
       FILE SECTION.
       FD  RJ-FILE
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 10 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORDS ARE RJ-REC, RJ-CARD.
       01  RJ-REC              PIC X(80).
       01  RJ-CARD.
           05  RC-SC           PIC X.
           05  RC-NT           PIC XX.
           05  RC-TM           PIC XXX.
           05  FILLER          PIC X(74).
       FD  OUT-FILE
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 10 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORDS ARE OUT-REC, OUT-HDR, OUT-NOTE.
       01  OUT-REC             PIC X(80).
       01  OUT-HDR.
           05  FILLER          PIC X.
           05  OH-ID           PIC X(8).
           05  FILLER          PIC X(71).
       01  OUT-NOTE.
           05  FILLER          PIC X.
           05  ON-NOTE         PIC X(4).
           05  FILLER          PIC X(75).
       FD  SAV-FILE
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 10 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS SAV-REC.
       01  SAV-REC             PIC X(80).
       FD  MID-FILE
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 10 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORDS ARE MID-REC, MID-HEX.
       01  MID-REC             PIC X(80).
       01  MID-HEX.
           05  FILLER          PIC X.
           05  MR-HEX          PIC X(64).
           05  FILLER          PIC X(15).
       WORKING-STORAGE SECTION.
       77  I                   PIC S9(4) COMP.
       77  K                   PIC S9(4) COMP.
       77  I1                  PIC S9(4) COMP.
       77  ULEN                PIC S9(4) COMP.
       77  PLEN                PIC S9(4) COMP.
       77  POS                 PIC S9(4) COMP.
       77  POLLS               PIC S9(4) COMP.
       77  NSAV                PIC S9(4) COMP.
       77  RD-RC               PIC 9.
       77  MODE-C              PIC X.
       77  EOF-FLAG            PIC X.
       77  DONE-FLAG           PIC X.
       77  VALOK               PIC X.
       77  FOUND               PIC X.
       77  CURSC               PIC X.
       77  CURLEN              PIC XX.
       77  CURTM               PIC XXX.
       01  UID                 PIC X(8).
       01  UID-TAB REDEFINES UID.
           05  UID-C           PIC X OCCURS 8 TIMES.
       01  PIECE               PIC X(40).
       01  PIECE-TAB REDEFINES PIECE.
           05  PIECE-C         PIC X OCCURS 40 TIMES.
       01  WS-REC              PIC X(80).
       01  WS-REC-TAB REDEFINES WS-REC.
           05  WS-REC-C        PIC X OCCURS 80 TIMES.
      * --- the screen subroutine area (same layout as in SCRSUB) --
       01  SCR-AREA.
           05  SCR-FUNC        PIC X.
           05  SCR-AID         PIC X.
           05  SCR-VIEW        PIC X.
           05  SCR-HAV         PIC X.
           05  SCR-SC          PIC X.
           05  SCR-NT.
               10  SCR-NT1     PIC X.
               10  SCR-NT2     PIC X.
           05  SCR-TM          PIC XXX.
           05  SCR-LD          PIC XXX.
           05  SCR-MSG         PIC X(70).
           05  SCR-RES1        PIC X(80).
           05  SCR-RES2        PIC X(80).
           05  SCR-RESN.
               10  SCR-RN      PIC X(4) OCCURS 18 TIMES.
           05  SCR-ROW         PIC X(44) OCCURS 10 TIMES.
      * --- MELVAL, MELSAV and MELMID areas ------------------------
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
      * --- the saved list, last 10 records ------------------------
       01  SAVEDT.
           05  SD-ENT          OCCURS 10 TIMES.
               10  SD-NUM      PIC XXX.
               10  FILLER      PIC X(77).
       01  SAVCNT-G.
           05  SAVCNT      PIC 999.
       01  SAVCNT-X REDEFINES SAVCNT-G.
           05  SAVCNT-C    PIC XXX.
      * --- messages with a number in them -------------------------
       01  MSG-SAVED.
           05  FILLER          PIC X(10) VALUE 'SAVED AS #'.
           05  MS-NUM          PIC XXX.
           05  FILLER          PIC X(57) VALUE SPACES.
       01  MSG-LOADED.
           05  FILLER          PIC X(8) VALUE 'LOADED #'.
           05  ML-NUM          PIC XXX.
           05  FILLER          PIC X(59) VALUE SPACES.
       01  MSG-MIDI.
           05  FILLER          PIC X(16) VALUE 'MIDI EXPORTED - '.
           05  MM-BYTES        PIC XXX.
           05  FILLER          PIC X(29)
               VALUE ' BYTES - DATA SET MELODY.MIDI'.
           05  FILLER          PIC X(22) VALUE SPACES.
       LINKAGE SECTION.
       01  PARM-AREA.
           05  PARM-LEN        PIC S9(4) COMP.
           05  PARM-MODE       PIC X.
           05  FILLER          PIC X.
           05  PARM-UID.
               10  PARM-UID-C  PIC X OCCURS 8 TIMES.
       PROCEDURE DIVISION USING PARM-AREA.
      * ------------------------------------------------------------
      * Start: read the parameter, set up the screen area
      * ------------------------------------------------------------
       000-MAIN.
           MOVE 'S' TO MODE-C.
           MOVE SPACES TO UID.
           MOVE 0 TO ULEN.
           IF PARM-LEN > 0 MOVE PARM-MODE TO MODE-C.
           IF PARM-LEN > 2 PERFORM 010-GET-UID.
           MOVE SPACES TO SCR-AREA.
           MOVE 'M' TO SCR-VIEW.
           MOVE 'N' TO SCR-HAV.
           MOVE 0 TO NSAV.
           MOVE
           'ENTER SCALE 0-8, NOTES AND TEMPO, THEN PRESS ENTER'
               TO SCR-MSG.
           IF MODE-C = 'W' GO TO 100-WAIT-MODE.
           GO TO 200-LOOP.
       010-GET-UID.
           COMPUTE ULEN = PARM-LEN - 2.
           IF ULEN > 8 MOVE 8 TO ULEN.
           PERFORM 011-COPY-UID VARYING I FROM 1 BY 1
               UNTIL I > ULEN.
       011-COPY-UID.
           MOVE PARM-UID-C (I) TO UID-C (I).
      * ------------------------------------------------------------
      * Mode W: show the input, poll DD OUT once a second
      * ------------------------------------------------------------
       100-WAIT-MODE.
           PERFORM 600-RESTORE THRU 600-EXIT.
           MOVE 'JOB SUBMITTED - WAITING FOR THE RESULT ...'
               TO SCR-MSG.
           MOVE 'D' TO SCR-FUNC.
           CALL 'SCRSUB' USING SCR-AREA.
           MOVE 20 TO POLLS.
           MOVE 'N' TO DONE-FLAG.
           PERFORM 110-POLL UNTIL DONE-FLAG = 'Y' OR POLLS = 0.
           IF DONE-FLAG = 'Y'
               MOVE 'DONE - CHANGE INPUT, ENTER = RUN, PF5 = SAVE'
                   TO SCR-MSG
           ELSE
               MOVE 'NO RESULT AFTER 20 SECONDS - ENTER = RUN AGAIN'
                   TO SCR-MSG.
           GO TO 200-LOOP.
       110-POLL.
           MOVE 'W' TO SCR-FUNC.
           CALL 'SCRSUB' USING SCR-AREA.
           PERFORM 700-READOUT THRU 700-EXIT.
           IF RD-RC = 0 MOVE 'Y' TO DONE-FLAG
           ELSE SUBTRACT 1 FROM POLLS.
      * ------------------------------------------------------------
      * The event loop: show the screen, act on the key
      * ------------------------------------------------------------
       200-LOOP.
           MOVE 'S' TO SCR-FUNC.
           CALL 'SCRSUB' USING SCR-AREA.
           IF SCR-AID = '3' GO TO 210-PF3.
           IF SCR-AID = '5' GO TO 220-PF5.
           IF SCR-AID = '6' GO TO 230-PF6.
           IF SCR-AID = '7' GO TO 240-PF7.
           IF SCR-AID NOT = 'E' GO TO 200-LOOP.
           IF SCR-VIEW = 'L' GO TO 250-ENTER-LIST.
           PERFORM 300-VALIDATE THRU 300-EXIT.
           IF VALOK NOT = 'Y' GO TO 200-LOOP.
           PERFORM 500-SUBPREP THRU 500-EXIT.
           MOVE 4 TO RETURN-CODE.
           GO TO 900-FINISH.
       210-PF3.
           IF SCR-VIEW NOT = 'L' GO TO 290-EXIT.
           MOVE 'M' TO SCR-VIEW.
           MOVE
           'ENTER SCALE 0-8, NOTES AND TEMPO, THEN PRESS ENTER'
               TO SCR-MSG.
           GO TO 200-LOOP.
       220-PF5.
           IF SCR-VIEW = 'L' GO TO 200-LOOP.
           PERFORM 800-SAVEIT THRU 800-EXIT.
           GO TO 200-LOOP.
       230-PF6.
           PERFORM 810-LISTIT THRU 810-EXIT.
           MOVE 'L' TO SCR-VIEW.
           GO TO 200-LOOP.
       240-PF7.
           IF SCR-VIEW = 'L' GO TO 200-LOOP.
           PERFORM 830-MIDIEXP THRU 830-EXIT.
           GO TO 200-LOOP.
       250-ENTER-LIST.
           PERFORM 820-LOADIT THRU 820-EXIT.
           GO TO 200-LOOP.
       290-EXIT.
           MOVE 'E' TO SCR-FUNC.
           CALL 'SCRSUB' USING SCR-AREA.
           MOVE 0 TO RETURN-CODE.
       900-FINISH.
           STOP RUN.
      * ------------------------------------------------------------
      * Check scale, notes and tempo (MELVAL has the rules)
      * ------------------------------------------------------------
       300-VALIDATE.
           MOVE 'N' TO VALOK.
           MOVE SCR-SC TO V-SCALE.
           MOVE SCR-NT TO V-NOTES.
           MOVE SCR-TM TO V-TEMPO.
           CALL 'MELVAL' USING VAL-AREA.
           IF V-RC = '0' GO TO 310-OK.
           IF V-RC = '1'
               MOVE 'INVALID SCALE - USE 0 TO 8, OR LEAVE BLANK'
                   TO SCR-MSG
               GO TO 300-EXIT.
           IF V-RC = '2'
               MOVE 'INVALID NOTES - USE 8 TO 16, OR 0 FOR RANDOM'
                   TO SCR-MSG
               GO TO 300-EXIT.
           MOVE 'INVALID TEMPO - USE 40 TO 240, OR LEAVE BLANK'
               TO SCR-MSG.
           GO TO 300-EXIT.
       310-OK.
           MOVE 'Y' TO VALOK.
           MOVE 'SUBMITTING JOB ...' TO SCR-MSG.
       300-EXIT.
           EXIT.
      * ------------------------------------------------------------
      * Append PIECE (without its trailing blanks) to WS-REC at POS
      * ------------------------------------------------------------
       400-ADD-PIECE.
           MOVE 40 TO PLEN.
           PERFORM 410-TRIM UNTIL PLEN = 0
               OR PIECE-C (PLEN) NOT = SPACE.
           PERFORM 420-COPY-CHAR VARYING K FROM 1 BY 1
               UNTIL K > PLEN.
       410-TRIM.
           SUBTRACT 1 FROM PLEN.
       420-COPY-CHAR.
           MOVE PIECE-C (K) TO WS-REC-C (POS).
           ADD 1 TO POS.
      * ------------------------------------------------------------
      * Write the run job to RUNJCL and RUNNING to OUT
      * ------------------------------------------------------------
       500-SUBPREP.
           OPEN OUTPUT RJ-FILE.
           MOVE SPACES TO WS-REC.
           MOVE 1 TO POS.
           MOVE '//' TO PIECE.
           PERFORM 400-ADD-PIECE.
           MOVE UID TO PIECE.
           PERFORM 400-ADD-PIECE.
           MOVE 'R JOB (1),MELODY,CLASS=A' TO PIECE.
           PERFORM 400-ADD-PIECE.
           MOVE WS-REC TO RJ-REC.
           WRITE RJ-REC.
           MOVE '//RUN      EXEC PGM=MELODY68' TO RJ-REC.
           WRITE RJ-REC.
           MOVE '//STEPLIB  DD DSN=MELODY.LOAD,DISP=SHR' TO RJ-REC.
           WRITE RJ-REC.
           MOVE SPACES TO WS-REC.
           MOVE 1 TO POS.
           MOVE '//SYSOUT   DD DSN=' TO PIECE.
           PERFORM 400-ADD-PIECE.
           MOVE UID TO PIECE.
           PERFORM 400-ADD-PIECE.
           MOVE '.MELODY.OUT,DISP=SHR' TO PIECE.
           PERFORM 400-ADD-PIECE.
           MOVE WS-REC TO RJ-REC.
           WRITE RJ-REC.
           MOVE '//SYSIN    DD *' TO RJ-REC.
           WRITE RJ-REC.
           MOVE SPACES TO RJ-REC.
           MOVE V-SC TO RC-SC.
           MOVE V-NN TO RC-NT.
           MOVE V-TM TO RC-TM.
           WRITE RJ-REC.
           MOVE '/*' TO RJ-REC.
           WRITE RJ-REC.
           MOVE '//' TO RJ-REC.
           WRITE RJ-REC.
           CLOSE RJ-FILE.
           OPEN OUTPUT OUT-FILE.
           MOVE ' RUNNING' TO OUT-REC.
           WRITE OUT-REC.
           CLOSE OUT-FILE.
       500-EXIT.
           EXIT.
      * ------------------------------------------------------------
      * Mode W: read the input card back from RUNJCL (6th record)
      * ------------------------------------------------------------
       600-RESTORE.
           MOVE 'N' TO EOF-FLAG.
           MOVE 0 TO K.
           OPEN INPUT RJ-FILE.
           PERFORM 610-READ-CARD UNTIL K = 6 OR EOF-FLAG = 'Y'.
           IF EOF-FLAG = 'Y' GO TO 600-CLOSE.
           MOVE RC-SC TO SCR-SC.
           MOVE RC-NT TO SCR-NT.
           MOVE RC-TM TO SCR-TM.
           PERFORM 650-STRIP0.
       600-CLOSE.
           CLOSE RJ-FILE.
       600-EXIT.
           EXIT.
       610-READ-CARD.
           READ RJ-FILE AT END MOVE 'Y' TO EOF-FLAG.
           ADD 1 TO K.
      * Show 0 as blank and 08 as 8 in the input fields
       650-STRIP0.
           IF SCR-SC = '0' MOVE SPACE TO SCR-SC.
           IF SCR-NT = '00' MOVE SPACES TO SCR-NT.
           IF SCR-NT1 = '0'
               MOVE SCR-NT2 TO SCR-NT1
               MOVE SPACE TO SCR-NT2.
           IF SCR-TM = '000' MOVE SPACES TO SCR-TM.
      * ------------------------------------------------------------
      * RD-RC = 0 if OUT now holds the melody, else 4
      * ------------------------------------------------------------
       700-READOUT.
           MOVE 'N' TO SCR-HAV.
           MOVE 4 TO RD-RC.
           MOVE 'N' TO EOF-FLAG.
           OPEN INPUT OUT-FILE.
           READ OUT-FILE AT END MOVE 'Y' TO EOF-FLAG.
           IF EOF-FLAG = 'Y' GO TO 700-CLOSE.
           IF OH-ID NOT = 'MELODY68' GO TO 700-CLOSE.
           MOVE OUT-REC TO SCR-RES1.
           READ OUT-FILE AT END MOVE 'Y' TO EOF-FLAG.
           IF EOF-FLAG = 'Y' GO TO 700-CLOSE.
           MOVE OUT-REC TO SCR-RES2.
           MOVE SPACES TO SCR-RESN.
           MOVE 1 TO K.
           PERFORM 710-NOTE UNTIL K > 18 OR EOF-FLAG = 'Y'.
           MOVE 'Y' TO SCR-HAV.
           MOVE 0 TO RD-RC.
       700-CLOSE.
           CLOSE OUT-FILE.
       700-EXIT.
           EXIT.
       710-NOTE.
           READ OUT-FILE AT END MOVE 'Y' TO EOF-FLAG.
           IF EOF-FLAG = 'N'
               MOVE ON-NOTE TO SCR-RN (K)
               ADD 1 TO K.
      * ------------------------------------------------------------
      * Scale digit, length and tempo of the shown melody
      * ------------------------------------------------------------
       750-CURINFO.
           MOVE 'C' TO S-FUNC.
           MOVE SCR-RES1 TO S-RES1.
           MOVE SCR-RES2 TO S-RES2.
           CALL 'MELSAV' USING SAV-AREA.
           MOVE S-SC TO CURSC.
           MOVE S-LEN TO CURLEN.
           MOVE S-TM TO CURTM.
      * ------------------------------------------------------------
      * PF5: append the shown melody to DD SAVED
      * ------------------------------------------------------------
       800-SAVEIT.
           IF SCR-HAV NOT = 'Y'
               MOVE 'NOTHING TO SAVE - RUN A MELODY FIRST'
                   TO SCR-MSG
               GO TO 800-EXIT.
           PERFORM 750-CURINFO.
           MOVE 0 TO SAVCNT.
           MOVE 'N' TO EOF-FLAG.
           OPEN INPUT SAV-FILE.
           PERFORM 801-COUNT UNTIL EOF-FLAG = 'Y'.
           CLOSE SAV-FILE.
           ADD 1 TO SAVCNT.
           MOVE 'B' TO S-FUNC.
           MOVE SAVCNT-C TO S-NUM.
           MOVE CURSC TO S-SC.
           MOVE CURTM TO S-TM.
           MOVE CURLEN TO S-LEN.
           MOVE SCR-RESN TO S-NOTES.
           CALL 'MELSAV' USING SAV-AREA.
           OPEN OUTPUT SAV-FILE.
           MOVE S-REC TO SAV-REC.
           WRITE SAV-REC.
           CLOSE SAV-FILE.
           MOVE SAVCNT-C TO MS-NUM.
           MOVE MSG-SAVED TO SCR-MSG.
       800-EXIT.
           EXIT.
       801-COUNT.
           READ SAV-FILE AT END MOVE 'Y' TO EOF-FLAG.
           IF EOF-FLAG = 'N' ADD 1 TO SAVCNT.
      * ------------------------------------------------------------
      * PF6: read DD SAVED, keep the last 10 records for the list
      * ------------------------------------------------------------
       810-LISTIT.
           MOVE 0 TO NSAV.
           MOVE 'N' TO EOF-FLAG.
           OPEN INPUT SAV-FILE.
           PERFORM 811-KEEP UNTIL EOF-FLAG = 'Y'.
           CLOSE SAV-FILE.
           PERFORM 813-ROW VARYING I FROM 1 BY 1 UNTIL I > 10.
           MOVE 'TYPE A NUMBER AND PRESS ENTER TO LOAD IT'
               TO SCR-MSG.
           MOVE SPACES TO SCR-LD.
       810-EXIT.
           EXIT.
       811-KEEP.
           READ SAV-FILE AT END MOVE 'Y' TO EOF-FLAG.
           IF EOF-FLAG = 'N' PERFORM 814-STORE.
       814-STORE.
           IF NSAV = 10 PERFORM 812-SHIFT VARYING I FROM 1 BY 1
               UNTIL I > 9.
           IF NSAV = 10 MOVE 9 TO NSAV.
           ADD 1 TO NSAV.
           MOVE SAV-REC TO SD-ENT (NSAV).
       812-SHIFT.
           COMPUTE I1 = I + 1.
           MOVE SD-ENT (I1) TO SD-ENT (I).
       813-ROW.
           MOVE SPACES TO SCR-ROW (I).
           IF I NOT > NSAV
               MOVE 'R' TO S-FUNC
               MOVE SD-ENT (I) TO S-REC
               CALL 'MELSAV' USING SAV-AREA
               MOVE S-LINE TO SCR-ROW (I).
      * ------------------------------------------------------------
      * ENTER on the list: show the saved melody typed in SCR-LD
      * ------------------------------------------------------------
       820-LOADIT.
           MOVE 'N' TO S-FUNC.
           MOVE SCR-LD TO S-NUM.
           CALL 'MELSAV' USING SAV-AREA.
           IF S-RC NOT = '0' GO TO 825-BAD.
           MOVE 'N' TO FOUND.
           PERFORM 821-FIND VARYING I FROM 1 BY 1
               UNTIL I > NSAV OR FOUND = 'Y'.
           IF FOUND NOT = 'Y' GO TO 825-BAD.
           MOVE 'D' TO S-FUNC.
           MOVE SD-ENT (K) TO S-REC.
           CALL 'MELSAV' USING SAV-AREA.
           MOVE S-RES1 TO SCR-RES1.
           MOVE S-RES2 TO SCR-RES2.
           MOVE SPACES TO SCR-RESN.
           MOVE S-NOTES TO SCR-RESN.
           MOVE S-SC TO SCR-SC.
           MOVE S-LEN TO SCR-NT.
           MOVE S-TM TO SCR-TM.
           PERFORM 650-STRIP0.
           MOVE 'Y' TO SCR-HAV.
           MOVE 'M' TO SCR-VIEW.
           MOVE S-NUM TO ML-NUM.
           MOVE MSG-LOADED TO SCR-MSG.
           GO TO 820-EXIT.
       825-BAD.
           MOVE 'NO SUCH SAVED MELODY' TO SCR-MSG.
       820-EXIT.
           EXIT.
       821-FIND.
           IF SD-NUM (I) = S-NUM MOVE 'Y' TO FOUND
               MOVE I TO K.
      * ------------------------------------------------------------
      * PF7: MELMID builds the MIDI file as hex text; write it to
      * DD MIDI between *MIDI-BEGIN and *MIDI-END, 64 hex chars a line
      * ------------------------------------------------------------
       830-MIDIEXP.
           IF SCR-HAV NOT = 'Y'
               MOVE 'NOTHING TO EXPORT - RUN A MELODY FIRST'
                   TO SCR-MSG
               GO TO 830-EXIT.
           PERFORM 750-CURINFO.
           MOVE CURTM TO M-TEMPO.
           MOVE CURLEN TO M-COUNT.
           MOVE SCR-RESN TO M-NOTES.
           CALL 'MELMID' USING MID-AREA.
           OPEN OUTPUT MID-FILE.
           MOVE SPACES TO MID-REC.
           MOVE ' *MIDI-BEGIN' TO MID-REC.
           WRITE MID-REC.
           PERFORM 831-LINE VARYING I FROM 1 BY 1
               UNTIL I > M-LINES.
           MOVE SPACES TO MID-REC.
           MOVE ' *MIDI-END' TO MID-REC.
           WRITE MID-REC.
           CLOSE MID-FILE.
           MOVE M-BYTES TO MM-BYTES.
           MOVE MSG-MIDI TO SCR-MSG.
       830-EXIT.
           EXIT.
       831-LINE.
           MOVE SPACES TO MID-REC.
           MOVE M-HEX-LINE (I) TO MR-HEX.
           WRITE MID-REC.
