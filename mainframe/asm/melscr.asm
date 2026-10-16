*  MELSCR - full-screen front end for the MELODY68 generator.
*  Draws a 3270 panel with TPUT FULLSCR, reads the input fields with
*  TGET ASIS, validates them and redraws in place.  On ENTER it writes
*  the run job to DD RUNJCL and a RUNNING marker to DD OUT, then ends
*  with return code 4 so the MELPANEL CLIST can SUBMIT the job and
*  call us again with mode W, which waits for the result and shows it.
*  PARM: 'm,userid'  m = S (start) or W (wait for result)
*  Registers: 12 code base, 13 work area (WORK), 6 build pointer,
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
EODRET   DS    A
AID      DS    X
MODE     DS    C
VALOK    DS    C
HAVRES   DS    C
EODF     DS    C
N1       DS    C
N2       DS    C
SCV      DS    CL1
NTV      DS    CL2
NN       DS    CL2
SC1      DS    CL1
UID      DS    CL8
MSG      DS    CL70
RES1     DS    CL80
RES2     DS    CL80
RESN     DS    CL72
REC      DS    CL80
REV      DS    XL256
INBUF    DS    XL256
BUF      DS    XL1400
WORKLEN  EQU   *-WORK
MELSCR   CSECT
         STM   14,12,12(13)
         LR    12,15
         USING MELSCR,12
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
         LA    9,20
WL       STIMER WAIT,BINTVL=WAITV
         BAL   11,READOUT
         LTR   15,15
         BZ    WDONE
         BCT   9,WL
         MVC   MSG,MSGTMO
         B     LOOP
WDONE    MVC   MSG,MSGDONE
LOOP     BAL   10,BUILD
         BAL   10,SEND
         BAL   10,RECV
         CLI   AID,X'F3'            PF3 = EXIT
         BE    EXIT
         CLI   AID,X'7D'            ENTER = CHECK AND RUN
         BNE   LOOP
         BAL   10,PARSE
         BAL   10,VALID
         CLI   VALOK,C'Y'
         BNE   LOOP
         BAL   10,SUBPREP
         MVC   RETC,=F'4'
         B     FINISH
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
         MVI   HAVRES,C'N'
         MVI   VALOK,C'N'
         BR    10
*
*  BUILD - assemble the 3270 data stream in BUF, R6 = end
BUILD    LA    6,BUF
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
         PTXT  9,5,X'60','0  RANDOM'
         PTXT  12,3,X'60','SCALE  ===>'
         PFLD  12,15,1,SCV
         PTXT  13,3,X'60','NOTES  ===>'
         PFLD  13,15,2,NTV
         PTXT  13,20,X'60','(8-16, 0 OR BLANK = RANDOM)'
         CLI   HAVRES,C'Y'
         BNE   NORES
         PTXT  15,3,X'E8','MELODY'
         SBAM  15,10
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         MVC   2(40,6),RES1+1
         LA    6,42(6)
         SBAM  15,52
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         MVC   2(12,6),RES2+1
         LA    6,14(6)
         MVC   ROWC,=F'15'
         LA    8,RESN
         LA    9,3
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
         BCT   9,RROW
NORES    DS    0H
         SBAM  22,1
         MVI   0(6),X'1D'
         MVI   1(6),X'E8'
         MVC   2(70,6),MSG
         LA    6,72(6)
         PTXT  24,3,X'60','ENTER=RUN   PF3=EXIT'
         SBAM  12,15
         MVI   0(6),X'13'           INSERT CURSOR
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
         LA    9,1
         BAL   11,CPYFLD
         B     PLOOP
P2       C     3,=A(NTPOS)
         BNE   PLOOP
         MVC   NTV,=C'  '
         LA    8,NTV
         LA    9,2
         BAL   11,CPYFLD
         B     PLOOP
PNEXT    LA    5,1(5)
         B     PLOOP
CPYFLD   LTR   9,9
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
         BCT   9,CPYFLD
         BR    11
*
*  VALID - check scale 0-4 and notes 0 or 8-16, set message and VALOK
VALID    MVI   VALOK,C'N'
         CLI   SCV,C' '
         BE    V1
         CLI   SCV,C'0'
         BL    VBAD1
         CLI   SCV,C'4'
         BH    VBAD1
V1       MVC   N1,NTV
         MVC   N2,NTV+1
         CLI   N1,C' '
         BNE   V2
         MVC   N1,N2
         MVI   N2,C' '
V2       CLI   N1,C' '
         BE    VOK
         CLI   N1,C'0'
         BL    VBAD2
         CLI   N1,C'9'
         BH    VBAD2
         CLI   N2,C' '
         BNE   V3
         CLI   N1,C'0'
         BE    VOK
         CLI   N1,C'8'
         BL    VBAD2
         B     VOK
V3       CLI   N2,C'0'
         BL    VBAD2
         CLI   N2,C'9'
         BH    VBAD2
         CLI   N1,C'1'
         BNE   VBAD2
         CLI   N2,C'6'
         BH    VBAD2
VOK      CLI   N1,C' '
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
         BR    10
VBAD1    MVC   MSG,MSGB1
         BR    10
VBAD2    MVC   MSG,MSGB2
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
SUBPREP  ST    10,SAVE+8
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
         BAL   11,INSUID
         MVC   0(21,3),=C'.MELODY.LOAD,DISP=SHR'
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
         L     10,SAVE+8
         BR    10
*
*  RESTORE - re-read the scale/notes card from RUNJCL (mode W)
RESTORE  ST    10,SAVE+8
         MVI   EODF,C'N'
         LA    3,RSDONE
         ST    3,EODRET
         OPEN  (RJI,INPUT)
         LA    9,6
RS1      GET   RJI
         BCT   9,RS1
         MVC   SCV,0(1)
         MVC   NTV,1(1)
         CLI   SCV,C'0'
         BNE   RS2
         MVI   SCV,C' '
RS2      CLC   NTV,=C'00'
         BNE   RSDONE
         MVC   NTV,=C'  '
RSDONE   CLOSE (RJI)
         L     10,SAVE+8
         BR    10
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
         LA    9,18
RDL      GET   OUI
         MVC   0(4,8),1(1)
         LA    8,4(8)
         BCT   9,RDL
RDDONE   MVI   HAVRES,C'Y'
         CLOSE (OUI)
         SR    15,15
         BR    11
RDNO     CLOSE (OUI)
         LA    15,4
         BR    11
*
*  EODAD routines: continue at the address in EODRET
RJEOD    L     15,EODRET
         BR    15
OUEOD    L     15,EODRET
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
MSG0     DC    CL70'ENTER SCALE 0-4 AND NOTES 8-16, THEN PRESS ENTER'
MSGSUB   DC    CL70'SUBMITTING JOB ...'
MSGWAIT  DC    CL70'JOB SUBMITTED - WAITING FOR THE RESULT ...'
MSGDONE  DC    CL70'DONE - CHANGE INPUT, ENTER = RUN AGAIN'
MSGTMO   DC    CL70'NO RESULT AFTER 20 SECONDS - ENTER = RUN AGAIN'
MSGB1    DC    CL70'INVALID SCALE - USE 0 TO 4, OR LEAVE BLANK'
MSGB2    DC    CL70'INVALID NOTES - USE 8 TO 16, OR 0 FOR RANDOM'
ENDMSG   DC    C'MELSCR ENDED'
ERASE    DC    X'1140403C404000'
SCPOS    EQU   (12-1)*80+15-1
NTPOS    EQU   (13-1)*80+15-1
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
         LTORG
         END   MELSCR
