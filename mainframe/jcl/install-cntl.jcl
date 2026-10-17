//@USER@C  JOB (1),'CNTL',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ALLOC    EXEC PGM=IEFBR14
//CLISTLIB DD DSN=MELODY.SOURCE.CLIST,DISP=(MOD,CATLG),UNIT=SYSDA,
//        SPACE=(TRK,(3,3,5)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
//CNTLLIB  DD DSN=MELODY.SOURCE.CNTL,DISP=(MOD,CATLG),UNIT=SYSDA,
//        SPACE=(TRK,(25,5,10)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
//MELODY EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CLIST(MELODY),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
PROC 0
CONTROL NOFLUSH
SET &SL = &STR(/)
MENU: WRITE
WRITE  =============================================
WRITE    MELODY68 - COBOL-68 MELODY GENERATOR
WRITE    MVS 3.8J / IBM OS ANS COBOL
WRITE  =============================================
WRITE    SCALE   1  C MAJOR
WRITE            2  G MAJOR
WRITE            3  A NATURAL MINOR
WRITE            4  C PENTATONIC
WRITE            5  D DORIAN
WRITE            6  E MINOR
WRITE            7  A MIN PENTATONIC
WRITE            8  E MIN PENTATONIC
WRITE            0  RANDOM
WRITE            X  EXIT
WRITE
WRITE  ENTER SCALE ===>
READ &SC
SET &CHK = &SC.Z
IF &CHK = XZ THEN GOTO DONE
IF &CHK = Z THEN SET &SC = 0
IF &LENGTH(&SC) > 1 THEN GOTO MENU
IF &SC > 8 THEN GOTO MENU
WRITE  NUMBER OF NOTES (8-16, 0 = RANDOM) ===>
READ &LN
IF &LENGTH(&LN) = 0 THEN SET &LN = 0
IF &LENGTH(&LN) = 1 THEN SET &LN = &STR(0&LN)
ALLOC FILE(RUNJCL) DATASET('&SYSUID..MELODY.RUNJCL') SHR REUSE
OPENFILE RUNJCL OUTPUT
SET &RUNJCL = &STR(//&SYSUID.R JOB (1),MELODY,NOTIFY=&SYSUID.,CLASS=A)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//RUN      EXEC PGM=MELODY68)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//STEPLIB  DD DSN=MELODY.LOAD,DISP=SHR)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//SYSOUT   DD DSN=&SYSUID..MELODY.OUT,DISP=OLD)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//SYSIN    DD *)
PUTFILE RUNJCL
SET &RUNJCL = &STR(&SC&LN.000)
PUTFILE RUNJCL
SET &RUNJCL = &SL.*
PUTFILE RUNJCL
SET &RUNJCL = &STR(//)
PUTFILE RUNJCL
CLOSFILE RUNJCL
FREE FILE(RUNJCL)
SUBMIT '&SYSUID..MELODY.RUNJCL'
WRITE  PRESS ENTER TO SHOW THE RESULT ===>
READ &WAIT
LIST '&SYSUID..MELODY.OUT'
GOTO MENU
DONE: WRITE  GOODBYE
EXIT
QQ
//MELPANEL EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CLIST(MELPANEL),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
PROC 0
CONTROL NOFLUSH
ALLOC FILE(RUNJCL) DATASET('&SYSUID..MELODY.RUNJCL') SHR REUSE
ALLOC FILE(OUT) DATASET('&SYSUID..MELODY.OUT') SHR REUSE
ALLOC FILE(SAVED) DATASET('&SYSUID..MELODY.SAVED') MOD REUSE
ALLOC FILE(MIDI) DATASET('&SYSUID..MELODY.MIDI') SHR REUSE
SET &MODE = S
AGAIN: CALL 'MELODY.LOAD(MELSCR)' '&MODE.,&SYSUID'
SET &RC = &LASTCC
IF &RC = 4 THEN DO
  SUBMIT '&SYSUID..MELODY.RUNJCL'
  SET &MODE = W
  GOTO AGAIN
END
FREE FILE(RUNJCL OUT SAVED MIDI)
QQ
//INITSAVE EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CNTL(INITSAVE),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
//@USER@V  JOB (1),'INITSAVED',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//* ONE-TIME: creates and empties <user>.MELODY.SAVED.  RERUNNING IT
//* DELETES ALL SAVED MELODIES.  A dataset that was only allocated
//* and never written returns a bogus record, so it is written once.
//DEL      EXEC PGM=IEFBR14
//SAVED    DD DSN=@USER@.MELODY.SAVED,DISP=(MOD,DELETE),UNIT=SYSDA,
//            SPACE=(TRK,(1,1))
//ALLOC    EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT1   DD DUMMY,DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//SYSUT2   DD DSN=@USER@.MELODY.SAVED,DISP=(NEW,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(5,5)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//
QQ
//INSTPANL EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CNTL(INSTPANL),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
//@USER@N  JOB (1),'INSTALL',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ALLOC    EXEC PGM=IEFBR14
//PANEL    DD DSN=@USER@.MELODY.PANEL,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(1,1)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//MIDI     DD DSN=@USER@.MELODY.MIDI,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(1,1)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//COPY     EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=@USER@.MELODY.PANEL,DISP=OLD
//SYSUT1   DD DATA,DLM=ZZ
PROC 0
CONTROL NOFLUSH
ALLOC FILE(RUNJCL) DATASET('&SYSUID..MELODY.RUNJCL') SHR REUSE
ALLOC FILE(OUT) DATASET('&SYSUID..MELODY.OUT') SHR REUSE
ALLOC FILE(SAVED) DATASET('&SYSUID..MELODY.SAVED') MOD REUSE
ALLOC FILE(MIDI) DATASET('&SYSUID..MELODY.MIDI') SHR REUSE
SET &MODE = S
AGAIN: CALL 'MELODY.LOAD(MELSCR)' '&MODE.,&SYSUID'
SET &RC = &LASTCC
IF &RC = 4 THEN DO
  SUBMIT '&SYSUID..MELODY.RUNJCL'
  SET &MODE = W
  GOTO AGAIN
END
FREE FILE(RUNJCL OUT SAVED MIDI)
ZZ
//
QQ
//INSTALL EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CNTL(INSTALL),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
//@USER@I  JOB (1),'INSTALL',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ALLOC    EXEC PGM=IEFBR14
//RUNJCL   DD DSN=@USER@.MELODY.RUNJCL,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(1,1)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//CLIST    DD DSN=@USER@.MELODY.CLIST,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(1,1)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//OUT      DD DSN=@USER@.MELODY.OUT,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(1,1)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//COPY     EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=@USER@.MELODY.CLIST,DISP=OLD
//SYSUT1   DD DATA,DLM=ZZ
PROC 0
CONTROL NOFLUSH
SET &SL = &STR(/)
MENU: WRITE
WRITE  =============================================
WRITE    MELODY68 - COBOL-68 MELODY GENERATOR
WRITE    MVS 3.8J / IBM OS ANS COBOL
WRITE  =============================================
WRITE    SCALE   1  C MAJOR
WRITE            2  G MAJOR
WRITE            3  A NATURAL MINOR
WRITE            4  C PENTATONIC
WRITE            5  D DORIAN
WRITE            6  E MINOR
WRITE            7  A MIN PENTATONIC
WRITE            8  E MIN PENTATONIC
WRITE            0  RANDOM
WRITE            X  EXIT
WRITE
WRITE  ENTER SCALE ===>
READ &SC
SET &CHK = &SC.Z
IF &CHK = XZ THEN GOTO DONE
IF &CHK = Z THEN SET &SC = 0
IF &LENGTH(&SC) > 1 THEN GOTO MENU
IF &SC > 8 THEN GOTO MENU
WRITE  NUMBER OF NOTES (8-16, 0 = RANDOM) ===>
READ &LN
IF &LENGTH(&LN) = 0 THEN SET &LN = 0
IF &LENGTH(&LN) = 1 THEN SET &LN = &STR(0&LN)
ALLOC FILE(RUNJCL) DATASET('&SYSUID..MELODY.RUNJCL') SHR REUSE
OPENFILE RUNJCL OUTPUT
SET &RUNJCL = &STR(//&SYSUID.R JOB (1),MELODY,NOTIFY=&SYSUID.,CLASS=A)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//RUN      EXEC PGM=MELODY68)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//STEPLIB  DD DSN=MELODY.LOAD,DISP=SHR)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//SYSOUT   DD DSN=&SYSUID..MELODY.OUT,DISP=OLD)
PUTFILE RUNJCL
SET &RUNJCL = &STR(//SYSIN    DD *)
PUTFILE RUNJCL
SET &RUNJCL = &STR(&SC&LN.000)
PUTFILE RUNJCL
SET &RUNJCL = &SL.*
PUTFILE RUNJCL
SET &RUNJCL = &STR(//)
PUTFILE RUNJCL
CLOSFILE RUNJCL
FREE FILE(RUNJCL)
SUBMIT '&SYSUID..MELODY.RUNJCL'
WRITE  PRESS ENTER TO SHOW THE RESULT ===>
READ &WAIT
LIST '&SYSUID..MELODY.OUT'
GOTO MENU
DONE: WRITE  GOODBYE
EXIT
ZZ
//
QQ
//MELSCR EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CNTL(MELSCR),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
//@USER@L  JOB (1),'MELSCR',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ASM      EXEC ASMFCL
//ASM.SYSIN DD *
*  MELSCR - full-screen front end for the MELODY68 generator.
*  Draws a 3270 panel with TPUT FULLSCR, reads the input fields with
*  TGET ASIS, validates them and redraws in place.  On ENTER it writes
*  the run job to DD RUNJCL and a RUNNING marker to DD OUT, then ends
*  with return code 4 so the MELPANEL CLIST can SUBMIT the job and
*  call us again with mode W, which waits for the result and shows it.
*  PF5 saves the shown melody to DD SAVED, PF6 lists the saved ones
*  and ENTER on that list loads one by number.  PF7 writes the shown
*  melody as a Standard MIDI File, in hex text, to DD MIDI.
*  PARM: 'm,userid'  m = S (start) or W (wait for result)
*  Registers: 12+9 code bases, 13 work area (WORK), 6 build pointer,
*  10/11 links.
         PRINT NOGEN
         MACRO
         SBAM  &R,&C
         LA    2,(&R-1)*80+&C-1
         BAL   11,PUTSBA
         MEND
         MACRO
         PTXT  &R,&C,&ATTR,&TXT
         LCLA  &L
&L       SETA  K'&TXT-2
         SBAM  &R,&C-1
         MVI   0(6),X'1D'
         MVI   1(6),&ATTR
         MVC   2(&L,6),=C&TXT
         LA    6,2+&L.(6)
         MEND
         MACRO
         PFLD  &R,&C,&LEN,&VAR
         SBAM  &R,&C-1
         MVI   0(6),X'1D'
         MVI   1(6),X'C8'
         MVC   2(&LEN,6),&VAR
         LA    6,2+&LEN.(6)
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         LA    6,2(6)
         MEND
WORK     DSECT
SAVE     DS    18F
INLEN    DS    F
RETC     DS    F
UL       DS    F
ROWC     DS    F
COLP     DS    F
POLLC    DS    F
SAVCNT   DS    F
NCNT     DS    F
BPM      DS    F
PCH      DS    F
MLEN     DS    F
NSAV     DS    F
LNK1     DS    F
EODRET   DS    A
TMPD     DS    D
AID      DS    X
MODE     DS    C
VIEW     DS    C
VALOK    DS    C
HAVRES   DS    C
EODF     DS    C
N1       DS    C
N2       DS    C
CURSC    DS    C
SCV      DS    CL1
NTV      DS    CL2
TMV      DS    CL3
LDV      DS    CL3
NORMV    DS    CL3
TM3      DS    CL3
NN       DS    CL2
SC1      DS    CL1
CURLEN   DS    CL2
CURTM    DS    CL3
UID      DS    CL8
MSG      DS    CL70
TL       DS    CL44
RES1     DS    CL80
RES2     DS    CL80
RESN     DS    CL72
REC      DS    CL80
SAVEDT   DS    CL800
MBUF     DS    XL200
REV      DS    XL256
INBUF    DS    XL256
BUF      DS    XL1400
WORKLEN  EQU   *-WORK
MELSCR   CSECT
         STM   14,12,12(13)
         LR    12,15
         LA    9,4095(12)
         LA    9,1(9)
         USING MELSCR,12,9
         LR    2,1                  KEEP PARM POINTER
         GETMAIN R,LV=WORKLEN
         ST    13,4(1)
         ST    1,8(13)
         LR    13,1
         USING WORK,13
         MVI   MODE,C'S'
         MVC   UID,=CL8' '
         MVC   UL,=F'1'
         L     3,0(2)               PARM: HALFWORD LENGTH + TEXT
         LH    4,0(3)
         LTR   4,4
         BZ    PARMX
         MVC   MODE,2(3)
         SH    4,=H'2'
         BNP   PARMX
         C     4,=F'8'
         BNH   PARM1
         LA    4,8
PARM1    ST    4,UL
         BCTR  4,0
         EX    4,MVCPARM
PARMX    BAL   10,INIT
         CLI   MODE,C'W'
         BNE   LOOP
         BAL   10,RESTORE
         MVC   MSG,MSGWAIT
         BAL   10,BUILD
         BAL   10,SEND
         MVC   POLLC,=F'20'
WL       STIMER WAIT,BINTVL=WAITV
         BAL   11,READOUT
         LTR   15,15
         BZ    WDONE
         L     2,POLLC
         BCTR  2,0
         ST    2,POLLC
         LTR   2,2
         BNZ   WL
         MVC   MSG,MSGTMO
         B     LOOP
WDONE    MVC   MSG,MSGDONE
LOOP     BAL   10,BUILD
         BAL   10,SEND
         BAL   10,RECV
         CLI   AID,X'F3'            PF3 = BACK / EXIT
         BE    PF3
         CLI   AID,X'F5'            PF5 = SAVE
         BE    PF5
         CLI   AID,X'F6'            PF6 = SAVED LIST
         BE    PF6
         CLI   AID,X'F7'            PF7 = MIDI EXPORT
         BE    PF7
         CLI   AID,X'7D'            ENTER = RUN / LOAD
         BNE   LOOP
         BAL   10,PARSE
         CLI   VIEW,C'L'
         BE    ENTL
         BAL   10,VALID
         CLI   VALOK,C'Y'
         BNE   LOOP
         BAL   10,SUBPREP
         MVC   RETC,=F'4'
         B     FINISH
ENTL     BAL   10,LOADIT
         B     LOOP
PF3      CLI   VIEW,C'L'
         BNE   EXIT
         MVI   VIEW,C'M'
         MVC   MSG,MSG0
         B     LOOP
PF5      CLI   VIEW,C'L'
         BE    LOOP
         BAL   10,PARSE
         BAL   10,SAVEIT
         B     LOOP
PF7      CLI   VIEW,C'L'
         BE    LOOP
         BAL   10,PARSE
         BAL   10,MIDIEXP
         B     LOOP
PF6      BAL   10,PARSE
         BAL   10,LISTIT
         MVI   VIEW,C'L'
         B     LOOP
EXIT     BAL   10,ENDSCR
         MVC   RETC,=F'0'
FINISH   L     2,RETC
         L     3,4(13)
         LR    1,13
         FREEMAIN R,LV=WORKLEN,A=(1)
         LR    13,3
         ST    2,16(13)
         LM    14,12,12(13)
         BR    14
MVCPARM  MVC   UID(1),4(3)
*
*  INIT - reverse table for decoding 3270 buffer addresses
INIT     SR    3,3
INIT1    SR    4,4
         IC    4,TAB(3)
         STC   3,REV(4)
         LA    3,1(3)
         C     3,=F'64'
         BL    INIT1
         MVC   MSG,MSG0
         MVI   SCV,C' '
         MVC   NTV,=C'  '
         MVC   TMV,=C'   '
         MVC   LDV,=C'   '
         MVI   HAVRES,C'N'
         MVI   VALOK,C'N'
         MVI   VIEW,C'M'
         BR    10
*
*  BUILD - assemble the 3270 data stream in BUF, R6 = end
BUILD    CLI   VIEW,C'L'
         BE    BUILDL
         LA    6,BUF
         MVI   0(6),X'F5'           ERASE/WRITE
         MVI   1(6),X'C3'           WCC: RESET MDT, RESTORE KBD
         LA    6,2(6)
         MVC   0(7,6),ERASE         SBA 0, RA TO 0 WITH NULLS
         LA    6,7(6)
         PTXT  1,3,X'E8','MELODY68  -  COBOL-68 MELODY GENERATOR'
         PTXT  2,3,X'60','MVS 3.8J / TK4-   IBM OS ANS COBOL'
         PTXT  4,3,X'E8','SCALES'
         PTXT  5,5,X'60','1  C MAJOR'
         PTXT  6,5,X'60','2  G MAJOR'
         PTXT  7,5,X'60','3  A NATURAL MINOR'
         PTXT  8,5,X'60','4  C PENTATONIC'
         PTXT  5,32,X'60','5  D DORIAN'
         PTXT  6,32,X'60','6  E MINOR'
         PTXT  7,32,X'60','7  A MIN PENTATONIC'
         PTXT  8,32,X'60','8  E MIN PENTATONIC'
         PTXT  9,5,X'60','0  RANDOM'
         PTXT  11,3,X'60','SCALE  ===>'
         PFLD  11,15,1,SCV
         PTXT  11,20,X'60','(0-8, 0 OR BLANK = RANDOM)'
         PTXT  12,3,X'60','NOTES  ===>'
         PFLD  12,15,2,NTV
         PTXT  12,20,X'60','(8-16, 0 OR BLANK = RANDOM)'
         PTXT  13,3,X'60','TEMPO  ===>'
         PFLD  13,15,3,TMV
         PTXT  13,20,X'60','(40-240 BPM, BLANK = 120)'
         CLI   HAVRES,C'Y'
         BNE   NORES
         PTXT  15,3,X'E8','MELODY'
         SBAM  15,10
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         MVC   2(32,6),RES1+1
         LA    6,34(6)
         SBAM  15,52
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         MVC   2(24,6),RES2+1
         LA    6,26(6)
         MVC   ROWC,=F'15'
         LA    8,RESN
         LA    7,3
RROW     LA    5,6
         MVC   COLP,=F'3'
RCOL     L     2,ROWC
         MH    2,=H'80'
         A     2,COLP
         BAL   11,PUTSBA
         MVI   0(6),X'1D'
         MVI   1(6),X'E8'
         MVC   2(4,6),0(8)
         LA    6,6(6)
         LA    8,4(8)
         L     2,COLP
         LA    2,8(2)
         ST    2,COLP
         BCT   5,RCOL
         L     2,ROWC
         LA    2,1(2)
         ST    2,ROWC
         BCT   7,RROW
NORES    DS    0H
         SBAM  22,1
         MVI   0(6),X'1D'
         MVI   1(6),X'E8'
         MVC   2(70,6),MSG
         LA    6,72(6)
         PTXT  24,3,X'60','ENTER=RUN PF5=SAVE PF6=LIST'
         PTXT  24,32,X'60','PF7=MIDI PF3=EXIT'
         SBAM  11,15
         MVI   0(6),X'13'           INSERT CURSOR
         LA    6,1(6)
         BR    10
*
*  BUILDL - the saved-melodies list screen
BUILDL   LA    6,BUF
         MVI   0(6),X'F5'
         MVI   1(6),X'C3'
         LA    6,2(6)
         MVC   0(7,6),ERASE
         LA    6,7(6)
         PTXT  1,3,X'E8','MELODY68  -  SAVED MELODIES (LAST 10)'
         PTXT  3,3,X'60','ID    SCALE              TEMPO       NOTES'
         L     7,NSAV
         LTR   7,7
         BNZ   BL1
         PTXT  5,3,X'60','NO SAVED MELODIES YET'
         B     BL9
BL1      MVC   ROWC,=F'4'
         LA    8,SAVEDT
BL2      MVC   TL,BLANKS
         MVI   TL,C'#'
         MVC   TL+1(3),0(8)
         SR    2,2
         IC    2,3(8)
         N     2,=F'15'
         BZ    BL3
         BCTR  2,0
         MH    2,=H'16'
         LA    3,SCNAMES(2)
         MVC   TL+6(16),0(3)
BL3      MVC   TL+24(3),4(8)
         MVC   TL+27(4),=C' BPM'
         MVC   TL+34(2),7(8)
         MVC   TL+36(6),=C' NOTES'
         L     2,ROWC
         MH    2,=H'80'
         AH    2,=H'1'
         BAL   11,PUTSBA
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         MVC   2(44,6),TL
         LA    6,46(6)
         L     2,ROWC
         LA    2,1(2)
         ST    2,ROWC
         LA    8,80(8)
         BCT   7,BL2
BL9      DS    0H
         PTXT  16,3,X'60','LOAD # ===>'
         PFLD  16,15,3,LDV
         SBAM  22,1
         MVI   0(6),X'1D'
         MVI   1(6),X'E8'
         MVC   2(70,6),MSG
         LA    6,72(6)
         PTXT  24,3,X'60','ENTER=LOAD  PF3=BACK'
         SBAM  16,15
         MVI   0(6),X'13'
         LA    6,1(6)
         BR    10
*
*  PUTSBA - append SBA order for buffer position in R2
PUTSBA   MVI   0(6),X'11'
         LR    3,2
         SRL   3,6
         IC    4,TAB(3)
         STC   4,1(6)
         N     2,=F'63'
         IC    4,TAB(2)
         STC   4,2(6)
         LA    6,3(6)
         BR    11
*
*  SEND - write the screen
SEND     LA    2,BUF
         LR    3,6
         SR    3,2
         TPUT  (2),(3),FULLSCR
         BR    10
*
*  RECV - read the AID and modified fields
RECV     MVI   INBUF,X'00'
         TGET  INBUF,256,ASIS
         ST    1,INLEN
         MVC   AID,INBUF
         BR    10
*
*  PARSE - pick the modified fields out of the inbound stream
PARSE    L     7,INLEN
         LA    7,INBUF(7)
         LA    5,INBUF+3
PLOOP    CR    5,7
         BNLR  10
         CLI   0(5),X'11'
         BNE   PNEXT
         SR    3,3
         IC    3,1(5)
         IC    3,REV(3)
         SLL   3,6
         SR    4,4
         IC    4,2(5)
         IC    4,REV(4)
         AR    3,4
         LA    5,3(5)
         C     3,=A(SCPOS)
         BNE   P2
         MVI   SCV,C' '
         LA    8,SCV
         LA    2,1
         BAL   11,CPYFLD
         B     PLOOP
P2       C     3,=A(NTPOS)
         BNE   P3
         MVC   NTV,=C'  '
         LA    8,NTV
         LA    2,2
         BAL   11,CPYFLD
         B     PLOOP
P3       C     3,=A(TMPOS)
         BNE   P4
         MVC   TMV,=C'   '
         LA    8,TMV
         LA    2,3
         BAL   11,CPYFLD
         B     PLOOP
P4       C     3,=A(LDPOS)
         BNE   PLOOP
         MVC   LDV,=C'   '
         LA    8,LDV
         LA    2,3
         BAL   11,CPYFLD
         B     PLOOP
PNEXT    LA    5,1(5)
         B     PLOOP
CPYFLD   LTR   2,2
         BZR   11
         CR    5,7
         BNLR  11
         CLI   0(5),X'11'
         BER   11
         CLI   0(5),X'00'
         BER   11
         MVC   0(1,8),0(5)
         LA    8,1(8)
         LA    5,1(5)
         BCT   2,CPYFLD
         BR    11
*
*  NORM3 - R5 = 3-char numeric field -> NORMV right-justified, zero
*  filled; R15 = 0 if blank or all digits, 4 if not numeric
NORM3    MVC   NORMV,=C'000'
         LA    4,3
         CLI   2(5),C' '
         BNE   NM1
         BCTR  4,0
         CLI   1(5),C' '
         BNE   NM1
         BCTR  4,0
         CLI   0(5),C' '
         BNE   NM1
         SR    15,15
         BR    11
NM1      LR    2,5
         LR    7,4
NM2      CLI   0(2),C'0'
         BL    NMBAD
         CLI   0(2),C'9'
         BH    NMBAD
         LA    2,1(2)
         BCT   7,NM2
         LA    3,NORMV+3
         SR    3,4
         BCTR  4,0
         EX    4,MVCNM
         SR    15,15
         BR    11
NMBAD    LA    15,4
         BR    11
MVCNM    MVC   0(1,3),0(5)
*
*  VALID - check scale 0-8, notes 0 or 8-16, tempo 0 or 40-240
VALID    ST    10,LNK1
         MVI   VALOK,C'N'
         CLI   SCV,C' '
         BE    V1
         CLI   SCV,C'0'
         BL    VBAD1
         CLI   SCV,C'8'
         BH    VBAD1
V1       MVC   N1,NTV
         MVC   N2,NTV+1
         CLI   N1,C' '
         BNE   V2
         MVC   N1,N2
         MVI   N2,C' '
V2       CLI   N1,C' '
         BE    VT
         CLI   N1,C'0'
         BL    VBAD2
         CLI   N1,C'9'
         BH    VBAD2
         CLI   N2,C' '
         BNE   V3
         CLI   N1,C'0'
         BE    VT
         CLI   N1,C'8'
         BL    VBAD2
         B     VT
V3       CLI   N2,C'0'
         BL    VBAD2
         CLI   N2,C'9'
         BH    VBAD2
         CLI   N1,C'1'
         BNE   VBAD2
         CLI   N2,C'6'
         BH    VBAD2
VT       LA    5,TMV
         BAL   11,NORM3
         LTR   15,15
         BNZ   VBAD3
         PACK  TMPD,NORMV
         CVB   2,TMPD
         LTR   2,2
         BZ    VOK
         C     2,=F'40'
         BL    VBAD3
         C     2,=F'240'
         BH    VBAD3
VOK      MVC   TM3,NORMV
         CLI   N1,C' '
         BNE   VO1
         MVC   NN,=C'00'
         B     VO3
VO1      CLI   N2,C' '
         BNE   VO2
         MVI   NN,C'0'
         MVC   NN+1(1),N1
         B     VO3
VO2      MVC   NN(1),N1
         MVC   NN+1(1),N2
VO3      MVC   SC1,SCV
         CLI   SCV,C' '
         BNE   VO4
         MVI   SC1,C'0'
VO4      MVI   VALOK,C'Y'
         MVC   MSG,MSGSUB
         B     VEND
VBAD1    MVC   MSG,MSGB1
         B     VEND
VBAD2    MVC   MSG,MSGB2
         B     VEND
VBAD3    MVC   MSG,MSGB3
VEND     L     10,LNK1
         BR    10
*
*  INSUID - copy the userid to R3 and advance R3
INSUID   L     4,UL
         BCTR  4,0
         EX    4,MVCUID
         A     3,UL
         BR    11
MVCUID   MVC   0(1,3),UID
*
*  SUBPREP - write the run job to RUNJCL and RUNNING to OUT
SUBPREP  ST    10,LNK1
         OPEN  (RJO,OUTPUT)
         MVC   REC,BLANKS
         MVC   REC(2),=C'//'
         LA    3,REC+2
         BAL   11,INSUID
         MVI   0(3),C'R'
         MVC   1(23,3),=C' JOB (1),MELODY,CLASS=A'
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(L'T2),T2
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(L'T3),T3
         LA    3,REC+L'T3
         MVC   0(20,3),=C'MELODY.LOAD,DISP=SHR'
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(L'T4),T4
         LA    3,REC+L'T4
         BAL   11,INSUID
         MVC   0(20,3),=C'.MELODY.OUT,DISP=SHR'
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(L'T5),T5
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(1),SC1
         MVC   REC+1(2),NN
         MVC   REC+3(3),TM3
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(2),=C'/*'
         PUT   RJO,REC
         MVC   REC,BLANKS
         MVC   REC(2),=C'//'
         PUT   RJO,REC
         CLOSE (RJO)
         OPEN  (OUO,OUTPUT)
         MVC   REC,BLANKS
         MVC   REC(8),=C' RUNNING'
         PUT   OUO,REC
         CLOSE (OUO)
         L     10,LNK1
         BR    10
*
*  RESTORE - re-read the scale/notes/tempo card from RUNJCL (mode W)
RESTORE  ST    10,LNK1
         MVI   EODF,C'N'
         LA    3,RSDONE
         ST    3,EODRET
         OPEN  (RJI,INPUT)
         LA    7,6
RS1      GET   RJI
         BCT   7,RS1
         MVC   SCV,0(1)
         MVC   NTV,1(1)
         MVC   TMV,3(1)
         BAL   11,STRIP0
RSDONE   CLOSE (RJI)
         L     10,LNK1
         BR    10
*
*  STRIP0 - show 0 as blank and 08 as 8 in the input fields
STRIP0   CLI   SCV,C'0'
         BNE   ST1
         MVI   SCV,C' '
ST1      CLC   NTV,=C'00'
         BNE   ST2
         MVC   NTV,=C'  '
ST2      CLI   NTV,C'0'
         BNE   ST3
         MVC   NTV(1),NTV+1
         MVI   NTV+1,C' '
ST3      CLC   TMV,=C'000'
         BNE   ST4
         MVC   TMV,=C'   '
ST4      BR    11
*
*  READOUT - R15 = 0 if OUT now holds the melody, else 4
READOUT  MVI   HAVRES,C'N'
         LA    3,RDNO
         ST    3,EODRET
         OPEN  (OUI,INPUT)
         GET   OUI
         LR    3,1
         CLC   1(8,3),=C'MELODY68'
         BNE   RDNO
         MVC   RES1,0(3)
         GET   OUI
         MVC   RES2,0(1)
         MVC   RESN,BLANKS
         LA    3,RDDONE
         ST    3,EODRET
         LA    8,RESN
         LA    7,18
RDL      GET   OUI
         MVC   0(4,8),1(1)
         LA    8,4(8)
         BCT   7,RDL
RDDONE   MVI   HAVRES,C'Y'
         CLOSE (OUI)
         SR    15,15
         BR    11
RDNO     CLOSE (OUI)
         LA    15,4
         BR    11
*
*  CURINFO - scale digit, length and tempo of the shown melody
CURINFO  MVC   CURLEN,RES2+8
         MVC   CURTM,RES2+19
         LA    3,SCNAMES
         LA    2,1
         LA    7,8
CI1      CLC   RES1+17(16),0(3)
         BE    CI2
         LA    3,16(3)
         LA    2,1(2)
         BCT   7,CI1
         SR    2,2
CI2      LA    2,240(2)
         STC   2,CURSC
         BR    11
*
*  SAVEIT - append the shown melody to DD SAVED
SAVEIT   ST    10,LNK1
         CLI   HAVRES,C'Y'
         BNE   SVNONE
         BAL   11,CURINFO
         MVC   SAVCNT,=F'0'
         LA    3,SVCNTD
         ST    3,EODRET
         OPEN  (SAVI,INPUT)
SVCNT    GET   SAVI
         L     2,SAVCNT
         LA    2,1(2)
         ST    2,SAVCNT
         B     SVCNT
SVCNTD   CLOSE (SAVI)
         OPEN  (SAVO,OUTPUT)
         MVC   REC,BLANKS
         L     2,SAVCNT
         LA    2,1(2)
         CVD   2,TMPD
         UNPK  REC(3),TMPD+6(2)
         OI    REC+2,X'F0'
         MVC   REC+3(1),CURSC
         MVC   REC+4(3),CURTM
         MVC   REC+7(2),CURLEN
         MVC   REC+9(64),RESN
         PUT   SAVO,REC
         CLOSE (SAVO)
         MVC   MSG,MSGSAV
         MVC   MSG+10(3),REC
         B     SVEND
SVNONE   MVC   MSG,MSGNOS
SVEND    L     10,LNK1
         BR    10
*
*  LISTIT - read DD SAVED, keep the last 10 records in SAVEDT
LISTIT   ST    10,LNK1
         MVC   NSAV,=F'0'
         LA    3,LSDONE
         ST    3,EODRET
         OPEN  (SAVI,INPUT)
LS1      GET   SAVI
         L     2,NSAV
         C     2,=F'10'
         BL    LS3
         LA    4,SAVEDT
         LA    5,9
LS2      MVC   0(80,4),80(4)
         LA    4,80(4)
         BCT   5,LS2
         LA    2,9
         ST    2,NSAV
LS3      MH    2,=H'80'
         LA    3,SAVEDT(2)
         MVC   0(80,3),0(1)
         L     2,NSAV
         LA    2,1(2)
         ST    2,NSAV
         B     LS1
LSDONE   CLOSE (SAVI)
         MVC   MSG,MSGLST
         MVC   LDV,=C'   '
         L     10,LNK1
         BR    10
*
*  LOADIT - show the saved melody whose number is in LDV
LOADIT   ST    10,LNK1
         LA    5,LDV
         BAL   11,NORM3
         LTR   15,15
         BNZ   LDBAD
         L     7,NSAV
         LTR   7,7
         BZ    LDBAD
         LA    8,SAVEDT
LD1      CLC   0(3,8),NORMV
         BE    LDOK
         LA    8,80(8)
         BCT   7,LD1
LDBAD    MVC   MSG,MSGNOL
         B     LDEND
LDOK     MVC   RES1,BLANKS
         MVC   RES1(17),=C' MELODY68 SCALE: '
         SR    2,2
         IC    2,3(8)
         N     2,=F'15'
         BZ    LD2
         BCTR  2,0
         MH    2,=H'16'
         LA    3,SCNAMES(2)
         MVC   RES1+17(16),0(3)
LD2      MVC   RES2,BLANKS
         MVC   RES2(22),=C' NOTES: nn  TEMPO: ttt'
         MVC   RES2+8(2),7(8)
         MVC   RES2+19(3),4(8)
         MVC   RESN,BLANKS
         MVC   RESN(64),9(8)
         MVC   SCV,3(8)
         MVC   NTV,7(8)
         MVC   TMV,4(8)
         BAL   11,STRIP0
         MVI   HAVRES,C'Y'
         MVI   VIEW,C'M'
         MVC   MSG,MSGLD
         MVC   MSG+8(3),0(8)
LDEND    L     10,LNK1
         BR    10
*
*  PUTB - append the byte in R2 to the MIDI buffer (R8)
PUTB     STC   2,0(8)
         LA    8,1(8)
         BR    11
*
*  PITCHF - R5 -> note (char, accid, octave, dur); R2 = MIDI pitch
PITCHF   LA    3,PLET
         LA    4,PVAL
         LA    1,7
PH1      CLC   0(1,3),0(5)
         BE    PH2
         LA    3,1(3)
         LA    4,1(4)
         BCT   1,PH1
         LA    4,PVAL
PH2      SR    2,2
         IC    2,0(4)
         SR    0,0
         IC    0,2(5)
         N     0,=F'15'
         SH    0,=H'4'
         MH    0,=H'12'
         AR    2,0
         CLI   1(5),C'#'
         BNE   PH3
         LA    2,1(2)
PH3      BR    11
*
*  MIDIEXP - build the Standard MIDI File in MBUF, write it as hex
*  text records to DD MIDI between *MIDI-BEGIN and *MIDI-END
MIDIEXP  ST    10,LNK1
         CLI   HAVRES,C'Y'
         BNE   MXNONE
         BAL   11,CURINFO
         PACK  TMPD,CURLEN
         CVB   2,TMPD
         ST    2,NCNT
         PACK  TMPD,CURTM
         CVB   2,TMPD
         LTR   2,2
         BNZ   MX0
         LA    2,120
MX0      ST    2,BPM
         LA    8,MBUF
         MVC   0(14,8),MTHD
         LA    8,14(8)
         MVC   0(4,8),MTRK
         MVC   4(3,8),=X'000000'
         L     2,NCNT
         MH    2,=H'9'
         AH    2,=H'11'
         STC   2,7(8)
         LA    8,8(8)
         MVC   0(4,8),=X'00FF5103'
         LA    8,4(8)
         L     3,=F'60000000'
         SR    2,2
         D     2,BPM
         LR    2,3
         SRL   2,16
         BAL   11,PUTB
         LR    2,3
         SRL   2,8
         BAL   11,PUTB
         LR    2,3
         BAL   11,PUTB
         L     7,NCNT
         LA    5,RESN
MXN      SR    2,2
         BAL   11,PUTB
         LA    2,144
         BAL   11,PUTB
         BAL   11,PITCHF
         ST    2,PCH
         BAL   11,PUTB
         LA    2,100
         BAL   11,PUTB
         LA    3,DURT
         LA    4,VQT
         LA    1,4
DL1      CLC   0(1,3),3(5)
         BE    DL2
         LA    3,1(3)
         LA    4,2(4)
         BCT   1,DL1
         LA    4,VQT+4
DL2      SR    2,2
         IC    2,0(4)
         BAL   11,PUTB
         SR    2,2
         IC    2,1(4)
         BAL   11,PUTB
         LA    2,128
         BAL   11,PUTB
         L     2,PCH
         BAL   11,PUTB
         SR    2,2
         BAL   11,PUTB
         LA    5,4(5)
         BCT   7,MXN
         MVC   0(4,8),=X'00FF2F00'
         LA    8,4(8)
         LA    2,MBUF
         SR    8,2
         ST    8,MLEN
         OPEN  (MIDO,OUTPUT)
         MVC   REC,BLANKS
         MVC   REC(12),=C' *MIDI-BEGIN'
         PUT   MIDO,REC
         LA    8,MBUF
         L     7,MLEN
HX1      LTR   7,7
         BZ    HXDONE
         LA    3,32
         CR    7,3
         BNL   HX2
         LR    3,7
HX2      MVC   REC,BLANKS
         LA    4,REC+1
         LR    5,3
         SR    7,3
HX3      SR    2,2
         IC    2,0(8)
         LR    1,2
         SRL   1,4
         IC    0,HEXT(1)
         STC   0,0(4)
         N     2,=F'15'
         IC    0,HEXT(2)
         STC   0,1(4)
         LA    4,2(4)
         LA    8,1(8)
         BCT   5,HX3
         PUT   MIDO,REC
         B     HX1
HXDONE   MVC   REC,BLANKS
         MVC   REC(10),=C' *MIDI-END'
         PUT   MIDO,REC
         CLOSE (MIDO)
         MVC   MSG,MSGMX
         L     2,MLEN
         CVD   2,TMPD
         UNPK  MSG+16(3),TMPD+6(2)
         OI    MSG+18,X'F0'
         B     MXEND
MXNONE   MVC   MSG,MSGNOM
MXEND    L     10,LNK1
         BR    10
*
*  EODAD routines: continue at the address in EODRET
RJEOD    L     15,EODRET
         BR    15
OUEOD    L     15,EODRET
         BR    15
SVEOD    L     15,EODRET
         BR    15
*
*  ENDSCR - erase the panel and return to line mode
ENDSCR   MVC   BUF(2),=X'F5C3'
         MVC   BUF+2(7),ERASE
         LA    2,BUF
         LA    3,9
         TPUT  (2),(3),FULLSCR
         TPUT  ENDMSG,L'ENDMSG
         BR    10
*
WAITV    DC    F'100'
BLANKS   DC    CL80' '
T2       DC    C'//RUN      EXEC PGM=MELODY68'
T3       DC    C'//STEPLIB  DD DSN='
T4       DC    C'//SYSOUT   DD DSN='
T5       DC    C'//SYSIN    DD *'
MSG0     DC    CL70'ENTER SCALE 0-8, NOTES AND TEMPO, THEN PRESS ENTER'
MSGSUB   DC    CL70'SUBMITTING JOB ...'
MSGWAIT  DC    CL70'JOB SUBMITTED - WAITING FOR THE RESULT ...'
MSGDONE  DC    CL70'DONE - CHANGE INPUT, ENTER = RUN, PF5 = SAVE'
MSGTMO   DC    CL70'NO RESULT AFTER 20 SECONDS - ENTER = RUN AGAIN'
MSGB1    DC    CL70'INVALID SCALE - USE 0 TO 8, OR LEAVE BLANK'
MSGB2    DC    CL70'INVALID NOTES - USE 8 TO 16, OR 0 FOR RANDOM'
MSGB3    DC    CL70'INVALID TEMPO - USE 40 TO 240, OR LEAVE BLANK'
MSGSAV   DC    CL70'SAVED AS #nnn'
MSGNOS   DC    CL70'NOTHING TO SAVE - RUN A MELODY FIRST'
MSGLST   DC    CL70'TYPE A NUMBER AND PRESS ENTER TO LOAD IT'
MSGNOL   DC    CL70'NO SUCH SAVED MELODY'
MSGMX    DC    CL70'MIDI EXPORTED - nnn BYTES - DATA SET MELODY.MIDI'
MSGNOM   DC    CL70'NOTHING TO EXPORT - RUN A MELODY FIRST'
HEXT     DC    C'0123456789ABCDEF'
PLET     DC    C'CDEFGAB'
PVAL     DC    AL1(60,62,64,65,67,69,71)
DURT     DC    C'WHQE'
VQT      DC    X'8F00874083608170'
MTHD     DC    X'4D5468640000000600000001'
         DC    X'01E0'
MTRK     DC    X'4D54726B'
MSGLD    DC    CL70'LOADED #nnn'
ENDMSG   DC    C'MELSCR ENDED'
ERASE    DC    X'1140403C404000'
SCPOS    EQU   (11-1)*80+15-1
NTPOS    EQU   (12-1)*80+15-1
TMPOS    EQU   (13-1)*80+15-1
LDPOS    EQU   (16-1)*80+15-1
SCNAMES  DC    CL16'C MAJOR'
         DC    CL16'G MAJOR'
         DC    CL16'A NATURAL MINOR'
         DC    CL16'C PENTATONIC'
         DC    CL16'D DORIAN'
         DC    CL16'E MINOR'
         DC    CL16'A MIN PENTATONIC'
         DC    CL16'E MIN PENTATONIC'
TAB      DC    X'40C1C2C3C4C5C6C7C8C94A4B4C4D4E4F'
         DC    X'50D1D2D3D4D5D6D7D8D95A5B5C5D5E5F'
         DC    X'6061E2E3E4E5E6E7E8E96A6B6C6D6E6F'
         DC    X'F0F1F2F3F4F5F6F7F8F97A7B7C7D7E7F'
RJO      DCB   DDNAME=RUNJCL,DSORG=PS,MACRF=PM,RECFM=FB,LRECL=80,      X
               BLKSIZE=800
RJI      DCB   DDNAME=RUNJCL,DSORG=PS,MACRF=GL,RECFM=FB,LRECL=80,      X
               BLKSIZE=800,EODAD=RJEOD
OUO      DCB   DDNAME=OUT,DSORG=PS,MACRF=PM,RECFM=FB,LRECL=80,         X
               BLKSIZE=800
OUI      DCB   DDNAME=OUT,DSORG=PS,MACRF=GL,RECFM=FB,LRECL=80,         X
               BLKSIZE=800,EODAD=OUEOD
SAVO     DCB   DDNAME=SAVED,DSORG=PS,MACRF=PM,RECFM=FB,LRECL=80,       X
               BLKSIZE=800
MIDO     DCB   DDNAME=MIDI,DSORG=PS,MACRF=PM,RECFM=FB,LRECL=80,        X
               BLKSIZE=800
SAVI     DCB   DDNAME=SAVED,DSORG=PS,MACRF=GL,RECFM=FB,LRECL=80,       X
               BLKSIZE=800,EODAD=SVEOD
         LTORG
         END   MELSCR
/*
//LKED.SYSLMOD DD DSN=MELODY.LOAD(MELSCR),DISP=SHR
//
QQ
//SETUP EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CNTL(SETUP),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
//@USER@S  JOB (1),'SETUP',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ALLOC    EXEC PGM=IEFBR14
//LOAD     DD DSN=MELODY.LOAD,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(5,5,5)),DCB=(RECFM=U,BLKSIZE=6144)
//COMP     EXEC COBUCL
//COB.SYSIN DD *
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
       77  WS-TEMPO            PIC 999.
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
      * --- Melody storage ---------------------------------------
       01  WS-MELODY.
           05  WS-M            OCCURS 16 TIMES.
               10  WS-M-CH     PIC X.
               10  WS-M-AC     PIC X.
               10  WS-M-OCT    PIC 9.
               10  WS-M-DUR    PIC X.
      * --- Input card: col 1 scale (0=random), col 2-3 length,
      * --- col 4-6 tempo in BPM (40-240, else 120) ---------------
       01  WS-IN.
           05  WS-IN-SCALE     PIC 9.
           05  WS-IN-LEN       PIC 99.
           05  WS-IN-TEMPO     PIC 999.
           05  FILLER          PIC X(74).
       01  WS-OUT.
           05  WS-O-CH         PIC X.
           05  WS-O-AC         PIC X.
           05  WS-O-OCT        PIC 9.
           05  WS-O-DUR        PIC X.
       PROCEDURE DIVISION.
       000-MAIN.
           PERFORM 100-SEED.
           ACCEPT WS-IN.
           MOVE WS-IN-SCALE TO WS-SCX.
           IF WS-SCX < 1 PERFORM 150-PICK-SCALE
           ELSE IF WS-SCX > 8 PERFORM 150-PICK-SCALE.
           MOVE WS-IN-LEN TO WS-LEN.
           IF WS-LEN < 8 PERFORM 160-PICK-LEN
           ELSE IF WS-LEN > 16 PERFORM 160-PICK-LEN.
           MOVE WS-IN-TEMPO TO WS-TEMPO.
           IF WS-TEMPO < 40 MOVE 120 TO WS-TEMPO
           ELSE IF WS-TEMPO > 240 MOVE 120 TO WS-TEMPO.
           PERFORM 300-ONE-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
           DISPLAY 'MELODY68 SCALE: ' WS-SC-NAME (WS-SCX).
           DISPLAY 'NOTES: ' WS-LEN '  TEMPO: ' WS-TEMPO.
           PERFORM 400-SHOW-NOTE VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-LEN.
           STOP RUN.
      * --- Seed from the clock (HHMMSS) ------------------------
       100-SEED.
           MOVE TIME-OF-DAY TO WS-TIME.
           COMPUTE WS-QUOT = WS-TIME / 65536.
           COMPUTE WS-SEED = WS-TIME - WS-QUOT * 65536.
       150-PICK-SCALE.
           MOVE 8 TO WS-RANGE.
           PERFORM 200-RANDOM.
           COMPUTE WS-SCX = WS-PICK + 1.
       160-PICK-LEN.
           MOVE 9 TO WS-RANGE.
           PERFORM 200-RANDOM.
           COMPUTE WS-LEN = WS-PICK + 8.
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
/*
//LKED.SYSLMOD DD DSN=MELODY.LOAD(MELODY68),DISP=SHR
//
QQ
//SHOWMIDI EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.CNTL(SHOWMIDI),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
//@USER@M  JOB (1),'SHOWMIDI',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//SHOW     EXEC PGM=IEBGENER
//SYSPRINT DD DUMMY
//SYSIN    DD DUMMY
//SYSUT1   DD DSN=@USER@.MELODY.MIDI,DISP=SHR
//SYSUT2   DD SYSOUT=A
//
QQ
//
