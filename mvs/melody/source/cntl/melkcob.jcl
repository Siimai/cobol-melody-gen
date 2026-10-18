//MELKCOB  JOB (1),'MELODY',CLASS=A,MSGCLASS=A
//* Compiles the KICKS transaction program MELOKIK: command-level
//* preprocessor, COBOL F (twice, see the User's Guide) and link edit
//* with the KICKS COBOL stub KIKCOBGL and the panel subprograms
//* MELVAL, MELSAV and MELMID from MELODY.LOAD (job SETUP builds
//* them).  Needs the copybook that MELKMAP creates (MELMAP).
//* Run it with  SUBMIT 'MELODY.SOURCE.CNTL(MELKCOB)'
//COMP     EXEC PROC=K2KCOBCL
//COPY.SYSUT1 DD DSN=MELODY.SOURCE.COBOL(MELOKIK),DISP=SHR
//LKED.SYSIN DD *
 INCLUDE SKIKLOAD(KIKCOBGL)
 INCLUDE LOADLIB(MELVAL,MELSAV,MELMID)
 ENTRY MELOKIK
 NAME MELOKIK(R)
/*
//LKED.LOADLIB DD DSN=MELODY.LOAD,DISP=SHR
//
