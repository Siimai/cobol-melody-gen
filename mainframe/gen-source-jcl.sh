#!/bin/bash
# usage: gen-source-jcl.sh > jcl/install-source.jcl
# Embeds melody68.cob and asm/melscr.asm into a job that stores them as
# members of the shared MELODY.SOURCE.COBOL and MELODY.SOURCE.ASM
# libraries. @USER@ must be allowed to create MELODY.* datasets (see RAKF). Rerun after changing either source.
cd "$(dirname "$0")"
cat <<'JCL'
//@USER@Q  JOB (1),'SOURCE',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ALLOC    EXEC PGM=IEFBR14
//COBOLLIB DD DSN=MELODY.SOURCE.COBOL,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(5,5,5)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
//ASMLIB   DD DSN=MELODY.SOURCE.ASM,DISP=(MOD,CATLG),UNIT=SYSDA,
//            SPACE=(TRK,(15,5,5)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
//COBOL    EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.COBOL(MELODY68),DISP=OLD
//SYSUT1   DD DATA,DLM=ZZ
JCL
cat melody68.cob
echo 'ZZ'
cat <<'JCL'
//ASM      EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=MELODY.SOURCE.ASM(MELSCR),DISP=OLD
//SYSUT1   DD DATA,DLM=ZZ
JCL
cat asm/melscr.asm
echo 'ZZ'
echo '//'
