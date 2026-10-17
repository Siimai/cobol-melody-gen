#!/bin/bash
# usage: gen-cntl-jcl.sh > jcl/install-cntl.jcl
# Embeds the CLISTs and the job templates into a job that stores them as
# members of the shared MELODY.SOURCE.CLIST and MELODY.SOURCE.CNTL libraries.
# @USER@ must be allowed to create MELODY.* datasets (see RAKF). Rerun after
# changing any of the files. install-source.jcl and install-cntl.jcl are not
# stored (they embed other files and would embed themselves).
# The stream delimiter is QQ because the templates contain ZZ themselves.
cd "$(dirname "$0")"
copy() {  # dataset member file
  cat <<JCL
//$2 EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=A
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=$1($2),DISP=OLD
//SYSUT1   DD DATA,DLM=QQ
JCL
  cat "$3"
  echo 'QQ'
}
cat <<'JCL'
//@USER@C  JOB (1),'CNTL',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//         USER=@USER@,PASSWORD=@PASS@
//ALLOC    EXEC PGM=IEFBR14
//CLISTLIB DD DSN=MELODY.SOURCE.CLIST,DISP=(MOD,CATLG),UNIT=SYSDA,
//        SPACE=(TRK,(3,3,5)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
//CNTLLIB  DD DSN=MELODY.SOURCE.CNTL,DISP=(MOD,CATLG),UNIT=SYSDA,
//        SPACE=(TRK,(25,5,10)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)
JCL
copy MELODY.SOURCE.CLIST MELODY   melody.clist
copy MELODY.SOURCE.CLIST MELPANEL melpanel.clist
copy MELODY.SOURCE.CLIST MELSETUP melsetup.clist
copy MELODY.SOURCE.CNTL  INITSAVE jcl/init-saved.jcl
copy MELODY.SOURCE.CNTL  INSTPANL jcl/install-panel.jcl
copy MELODY.SOURCE.CNTL  INSTALL  jcl/install.jcl
copy MELODY.SOURCE.CNTL  MELSCR   jcl/melscr.jcl
copy MELODY.SOURCE.CNTL  SETUP    jcl/setup.jcl
copy MELODY.SOURCE.CNTL  SHOWMIDI jcl/show-midi.jcl
echo '//'
