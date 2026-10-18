      * ============================================================
      * MELMID - Standard MIDI File of the MELODY full-screen panel.
      * Called by the assembler front end MELSCR (LOAD + CALL).
      * It builds the whole file as hex text; MELSCR writes the
      * text to DD MIDI between the *MIDI-BEGIN and *MIDI-END lines.
      * Target: MVS 3.8j / TK4- compiler IKFCBL00 (COBOL F), so
      * COBOL-68 only: no END-xxx, no EVALUATE, no intrinsics.
      *
      * MID-AREA is one 457-byte record, the same layout as the
      * work fields NMTM..NMHEX in MELSCR:
      *   in : M-TEMPO  3 digits, 0 or blank = 120
      *        M-COUNT  2 digits, number of notes (1 to 16)
      *        M-NOTES  16 notes of 4 chars: letter C-B, accidental
      *                 (# or blank), octave digit, duration (W H Q E)
      *   out: M-BYTES  3 digits, size of the MIDI file in bytes
      *        M-LINES  1 digit, hex lines to write (64 chars each,
      *                 32 bytes each)
      *        M-HEX    the file as hex text, blank filled
      *
      * File layout: header chunk (14 bytes), track chunk header
      * (8 bytes, the last one is the track length), tempo event
      * (7 bytes), then 9 bytes per note (note on, delta, note off),
      * then the end-of-track event (4 bytes).
      * ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MELMID.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       77  P                   PIC S9(4) COMP.
       77  I                   PIC S9(4) COMP.
       77  N                   PIC S9(4) COMP.
       77  BPM                 PIC 999.
       77  US                  PIC 9(8).
       77  QT                  PIC 9(8).
       77  W-BYTE              PIC 999.
       77  W-HI                PIC 99.
       77  W-LO                PIC 99.
       77  PITCH               PIC S999.
       77  W-OCT               PIC 9.
       77  D1                  PIC 999.
       77  D2                  PIC 999.
       01  HEX-DIGITS          PIC X(16) VALUE '0123456789ABCDEF'.
       01  HEX-T REDEFINES HEX-DIGITS.
           05  HEXD            PIC X OCCURS 16 TIMES.
       01  HEX-AREA.
           05  H-PRE           PIC X(42) VALUE
               '4D546864000000060000000101E04D54726B000000'.
           05  H-REST          PIC X(342).
       01  HEX-TAB REDEFINES HEX-AREA.
           05  HC              PIC X OCCURS 384 TIMES.
       LINKAGE SECTION.
       01  MID-AREA.
           05  M-TEMPO         PIC 999.
           05  M-COUNT         PIC 99.
           05  M-NOTES.
               10  M-NOTE OCCURS 16 TIMES.
                   15  N-LET   PIC X.
                   15  N-ACC   PIC X.
                   15  N-OCT   PIC X.
                   15  N-DUR   PIC X.
           05  M-BYTES         PIC 999.
           05  M-LINES         PIC 9.
           05  M-HEX           PIC X(384).
       PROCEDURE DIVISION USING MID-AREA.
       000-MAIN.
           PERFORM 100-START.
           PERFORM 200-TEMPO-EVENT.
           PERFORM 300-NOTE VARYING I FROM 1 BY 1 UNTIL I > N.
           PERFORM 400-FINISH.
           GOBACK.
      * --- Note count, tempo, and the fixed first 21 bytes ------
       100-START.
           MOVE SPACES TO H-REST.
           IF M-COUNT NUMERIC MOVE M-COUNT TO N
           ELSE MOVE 0 TO N.
           IF N > 16 MOVE 16 TO N.
           IF M-TEMPO NUMERIC MOVE M-TEMPO TO BPM
           ELSE MOVE 0 TO BPM.
           IF BPM = 0 MOVE 120 TO BPM.
           MOVE 43 TO P.
           COMPUTE W-BYTE = N * 9 + 11.
           PERFORM 900-PUT-BYTE.
      * --- Tempo event 00 FF 51 03 and microseconds per beat ----
       200-TEMPO-EVENT.
           MOVE 0 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 255 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 81 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 3 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           COMPUTE US = 60000000 / BPM.
           COMPUTE W-BYTE = US / 65536.
           PERFORM 900-PUT-BYTE.
           COMPUTE QT = US - W-BYTE * 65536.
           COMPUTE W-BYTE = QT / 256.
           PERFORM 900-PUT-BYTE.
           COMPUTE W-BYTE = QT - W-BYTE * 256.
           PERFORM 900-PUT-BYTE.
      * --- One note: on, delay, off -----------------------------
       300-NOTE.
           PERFORM 310-PITCH.
           PERFORM 320-DURATION.
           MOVE 0 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 144 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE PITCH TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 100 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE D1 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE D2 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 128 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE PITCH TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 0 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
      * --- Pitch: C4 = 60, 12 per octave, # adds one ------------
       310-PITCH.
           MOVE 60 TO PITCH.
           IF N-LET (I) = 'D' MOVE 62 TO PITCH.
           IF N-LET (I) = 'E' MOVE 64 TO PITCH.
           IF N-LET (I) = 'F' MOVE 65 TO PITCH.
           IF N-LET (I) = 'G' MOVE 67 TO PITCH.
           IF N-LET (I) = 'A' MOVE 69 TO PITCH.
           IF N-LET (I) = 'B' MOVE 71 TO PITCH.
           IF N-OCT (I) NUMERIC MOVE N-OCT (I) TO W-OCT
           ELSE MOVE 4 TO W-OCT.
           COMPUTE PITCH = PITCH + (W-OCT - 4) * 12.
           IF N-ACC (I) = '#' ADD 1 TO PITCH.
      * --- Duration as a two-byte delay; 480 ticks = a quarter --
       320-DURATION.
           MOVE 131 TO D1.
           MOVE 96 TO D2.
           IF N-DUR (I) = 'W' MOVE 143 TO D1
               MOVE 0 TO D2.
           IF N-DUR (I) = 'H' MOVE 135 TO D1
               MOVE 64 TO D2.
           IF N-DUR (I) = 'E' MOVE 129 TO D1
               MOVE 112 TO D2.
      * --- End of track, then the sizes -------------------------
       400-FINISH.
           MOVE 0 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 255 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 47 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           MOVE 0 TO W-BYTE.
           PERFORM 900-PUT-BYTE.
           COMPUTE M-BYTES = (P - 1) / 2.
           COMPUTE M-LINES = (M-BYTES + 31) / 32.
           MOVE HEX-AREA TO M-HEX.
      * --- Append W-BYTE (0-255) as two hex digits at HC (P) ----
       900-PUT-BYTE.
           COMPUTE W-HI = W-BYTE / 16.
           COMPUTE W-LO = W-BYTE - W-HI * 16.
           ADD 1 TO W-HI.
           ADD 1 TO W-LO.
           MOVE HEXD (W-HI) TO HC (P).
           ADD 1 TO P.
           MOVE HEXD (W-LO) TO HC (P).
           ADD 1 TO P.
