//MELKMAP  JOB (1),'MELODY',CLASS=A,MSGCLASS=A
//* Builds the BMS mapset MELMAP for the KICKS transaction MELO:
//* the COBOL copybook (symbolic map) and the map load module.
//* KIKMAPS is the KICKS map proc (User's Guide, Programming). Its
//* defaults were customized when KICKS was installed, so only the
//* map name is given.  Run it as a user who may write to the KICKS
//* libraries (HERC02), before MELKCOB.
//* Run it with  SUBMIT 'MELODY.SOURCE.CNTL(MELKMAP)'
//* Assumes the map source is read from COPY.SYSUT1 like the COBOL
//* source of K2KCOBCL; confirm on the first run.
//MAP      EXEC KIKMAPS,MAPNAME=MELMAP
//COPY.SYSUT1 DD DSN=MELODY.SOURCE.BMS(MELMAP),DISP=SHR
//
