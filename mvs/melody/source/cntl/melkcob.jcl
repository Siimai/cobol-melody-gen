//MELKCOB  JOB (1),'MELODY',CLASS=A,MSGCLASS=A
//* Compiles the KICKS transaction program MELOKIK: command-level
//* preprocessor, COBOL F (twice, see the User's Guide) and link edit
//* with the KICKS COBOL stub KIKCOBGL.  Needs the copybook that
//* MELKMAP creates (MELMAP).
//* Run it with  SUBMIT 'MELODY.SOURCE.CNTL(MELKCOB)'
//COMP     EXEC PROC=K2KCOBCL
//COPY.SYSUT1 DD DSN=MELODY.SOURCE.COBOL(MELOKIK),DISP=SHR
//LKED.SYSIN DD *
 INCLUDE SKIKLOAD(KIKCOBGL)
 ENTRY MELOKIK
 NAME MELOKIK(R)
/*
//
