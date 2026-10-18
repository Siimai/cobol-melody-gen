*  SCRSUB - 3270 screen subroutine for the MELODY panel (MELPNL).
*  The COBOL-68 driver MELPNL calls it as  CALL 'SCRSUB' USING
*  SCR-AREA.  SCRSUB only talks to the terminal: it draws the panel
*  with TPUT FULLSCR, reads the keys and input fields with TGET ASIS
*  and hands them back in the area.  All the rules and all the file
*  I/O are in COBOL.  SCR-FUNC (first byte of the area) says what to do:
*    S  draw the screen described by the area, wait for a key, and
*       return the key in SCR-AID and the edited input fields
*    D  draw the screen and return at once (no key is read)
*    W  wait one second (used while the batch job runs)
*    E  erase the screen and return to line mode
*  SCR-AID: E enter, 3 PF3, 5 PF5, 6 PF6, 7 PF7, O any other key.
*  The area is copied into a work area on entry and back on exit, so
*  the field names below are the same as in the COBOL record.
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
ROWC     DS    F
COLP     DS    F
CALLA    DS    A
AREA     DS    0C
FUNC     DS    C
AID      DS    C
VIEW     DS    C
HAVRES   DS    C
SCV      DS    CL1
NTV      DS    CL2
TMV      DS    CL3
LDV      DS    CL3
MSG      DS    CL70
RES1     DS    CL80
RES2     DS    CL80
RESN     DS    CL72
ROWS     DS    10CL44
AREALEN  EQU   *-AREA
REV      DS    XL256
INBUF    DS    XL256
BUF      DS    XL1400
WORKLEN  EQU   *-WORK
SCRSUB   CSECT
         STM   14,12,12(13)
         LR    12,15
         LA    9,4095(12)
         LA    9,1(9)
         USING SCRSUB,12,9
         L     2,0(1)               CALLER'S AREA
         GETMAIN R,LV=WORKLEN
         ST    13,4(1)
         ST    1,8(13)
         LR    13,1
         USING WORK,13
         ST    2,CALLA
         LA    0,AREA
         LA    1,AREALEN
         LA    3,AREALEN
         MVCL  0,2                  AREA IN
         BAL   10,INIT
         CLI   FUNC,C'E'
         BE    DOEND
         CLI   FUNC,C'W'
         BE    DOWAIT
         BAL   10,BUILD
         BAL   10,SEND
         CLI   FUNC,C'D'
         BE    BACK
         BAL   10,RECV
         BAL   10,PARSE
         B     BACK
DOWAIT   STIMER WAIT,BINTVL=WAITV
         B     BACK
DOEND    BAL   10,ENDSCR
BACK     L     0,CALLA
         LA    1,AREALEN
         LA    2,AREA
         LA    3,AREALEN
         MVCL  0,2                  AREA OUT
         L     3,4(13)
         LR    1,13
         FREEMAIN R,LV=WORKLEN,A=(1)
         LR    13,3
         SR    15,15
         ST    15,16(13)
         LM    14,12,12(13)
         BR    14
*
*  INIT - reverse table for decoding 3270 buffer addresses
INIT     SR    3,3
INIT1    SR    4,4
         IC    4,TAB(3)
         STC   3,REV(4)
         LA    3,1(3)
         C     3,=F'64'
         BL    INIT1
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
*  BUILDL - the saved-melodies list screen; ROWS holds up to 10 lines
BUILDL   LA    6,BUF
         MVI   0(6),X'F5'
         MVI   1(6),X'C3'
         LA    6,2(6)
         MVC   0(7,6),ERASE
         LA    6,7(6)
         PTXT  1,3,X'E8','MELODY68  -  SAVED MELODIES (LAST 10)'
         PTXT  3,3,X'60','ID    SCALE              TEMPO       NOTES'
         CLI   ROWS,C' '
         BNE   BL1
         PTXT  5,3,X'60','NO SAVED MELODIES YET'
         B     BL9
BL1      MVC   ROWC,=F'4'
         LA    8,ROWS
         LA    7,10
BL2      CLI   0(8),C' '
         BE    BL3
         L     2,ROWC
         MH    2,=H'80'
         AH    2,=H'1'
         BAL   11,PUTSBA
         MVI   0(6),X'1D'
         MVI   1(6),X'60'
         MVC   2(44,6),0(8)
         LA    6,46(6)
BL3      L     2,ROWC
         LA    2,1(2)
         ST    2,ROWC
         LA    8,44(8)
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
*  RECV - read the AID and modified fields; AID gets a letter code
RECV     MVI   INBUF,X'00'
         TGET  INBUF,256,ASIS
         ST    1,INLEN
         MVI   AID,C'O'
         LA    2,AIDTAB
RC1      CLI   0(2),X'FF'
         BER   10
         CLC   0(1,2),INBUF
         BE    RC2
         LA    2,2(2)
         B     RC1
RC2      MVC   AID,1(2)
         BR    10
AIDTAB   DC    X'7DC5F3F3F5F5F6F6F7F7FF'
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
ENDMSG   DC    C'MELSCR ENDED'
ERASE    DC    X'1140403C404000'
SCPOS    EQU   (11-1)*80+15-1
NTPOS    EQU   (12-1)*80+15-1
TMPOS    EQU   (13-1)*80+15-1
LDPOS    EQU   (16-1)*80+15-1
TAB      DC    X'40C1C2C3C4C5C6C7C8C94A4B4C4D4E4F'
         DC    X'50D1D2D3D4D5D6D7D8D95A5B5C5D5E5F'
         DC    X'6061E2E3E4E5E6E7E8E96A6B6C6D6E6F'
         DC    X'F0F1F2F3F4F5F6F7F8F97A7B7C7D7E7F'
         LTORG
         END   SCRSUB
