      *> ============================================================
      *> music_types.cpy
      *> Shared working-storage definitions for the COBOL Melody
      *> Generator.  COPY this file into WORKING-STORAGE SECTION.
      *>
      *> Note output format (4 chars per note):
      *>   WS-N-CHAR + WS-N-ACCID + WS-N-OCTAVE + WS-N-DUR
      *>   e.g.  "C 4Q"  = C natural, octave 4, quarter note
      *>         "F#4H"  = F sharp,   octave 4, half note
      *>         "A 3E"  = A natural, octave 3, eighth note
      *>
      *> Duration codes: W=Whole  H=Half  Q=Quarter  E=Eighth
      *> ============================================================

      *> --- Melody storage (up to 64 notes) -----------------------
       01  WS-MELODY.
           05  WS-MELODY-LEN         PIC 99 VALUE 0.
           05  WS-NOTES              OCCURS 64 TIMES.
               10  WS-N-CHAR         PIC X.
               10  WS-N-ACCID        PIC X.
               10  WS-N-OCTAVE       PIC 9.
               10  WS-N-DUR          PIC X.

      *> --- Scale table (8 predefined scales) ---------------------
      *>   Each scale holds up to 7 notes (diatonic).
      *>   Pentatonic scales use 5 notes; remaining slots are blank.
       01  WS-SCALE-TABLE.
           05  WS-SC-COUNT           PIC 9 VALUE 8.
           05  WS-SCALE              OCCURS 8 TIMES.
               10  WS-SC-NAME        PIC X(16).
               10  WS-SC-NOTE-CNT    PIC 9.
               10  WS-SC-NOTES       OCCURS 7 TIMES.
                   15  WS-SCN-CHAR   PIC X.
                   15  WS-SCN-ACCID  PIC X.

      *> --- Application state ------------------------------------
       01  WS-APP-STATE.
           05  WS-SELECTED-SCALE     PIC 9   VALUE 1.
           05  WS-MELODY-COUNT       PIC 9(3) VALUE 0.
           05  WS-HAS-MELODY         PIC X   VALUE 'N'.
               88  HAS-MELODY        VALUE 'Y'.
               88  NO-MELODY         VALUE 'N'.
           05  WS-OUTPUT-FILE        PIC X(80).
           05  WS-STATUS-MSG         PIC X(60).
           05  WS-MENU-CHOICE        PIC X   VALUE SPACE.
           05  WS-RETURN-CODE        PIC 9   VALUE 0.
               88  RC-OK             VALUE 0.
               88  RC-ERROR          VALUE 1.

      *> --- Shared temporaries -----------------------------------
       77  WS-IDX-A                  PIC 99  VALUE 0.
       77  WS-IDX-B                  PIC 99  VALUE 0.
       77  WS-RANDOM-VAL             PIC 9(6) VALUE 0.
       77  WS-FILE-STATUS            PIC XX  VALUE SPACES.
       77  WS-DISPLAY-NOTE           PIC X(4) VALUE SPACES.
