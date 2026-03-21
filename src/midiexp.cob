      *> ============================================================
      *> midiexp.cob
      *> Subprogram: MIDIEXP
      *>
      *> Exports the current melody to a standard MIDI file (.mid).
      *>
      *> CALL 'midiexp' USING LS-MELODY
      *>                      LS-SCALE-TABLE
      *>                      LS-SELECTED-SCALE
      *>                      LS-OUTPUT-FILE
      *>                      LS-STATUS-MSG
      *>                      LS-RETURN-CODE
      *>
      *> On success:
      *>   LS-OUTPUT-FILE is set to the path written.
      *>   LS-STATUS-MSG  is set to a confirmation message.
      *>   LS-RETURN-CODE is 0.
      *> On error:
      *>   LS-STATUS-MSG  is set to the error description.
      *>   LS-RETURN-CODE is 1.
      *>
      *> File format: Standard MIDI Type 0, 480 ticks/beat, 120 BPM.
      *> Duration codes: W=Whole(1920) H=Half(960) Q=Quarter(480) E=Eighth(240)
      *>
      *> Binary strategy: a single PIC X FD record is used so that every
      *> WRITE emits exactly one byte with no length-prefix overhead.
      *> 900-WRITE-BYTE converts WS-OUT-VAL (0-255) via FUNCTION CHAR.
      *> ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. midiexp.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MIDI-FILE
               ASSIGN TO DYNAMIC WS-MIDI-FNAME
               ORGANIZATION IS BINARY SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
      *> Single fixed-length record → no record-length prefix overhead.
       FD  MIDI-FILE.
       01  MIDI-BYTE          PIC X.

       WORKING-STORAGE SECTION.
       01  WS-MIDI-FNAME      PIC X(80)  VALUE SPACES.
       01  WS-FS              PIC XX     VALUE SPACES.
       01  WS-CURR-DT         PIC X(21)  VALUE SPACES.
       01  WS-TS.
           05  WS-TS-DATE     PIC X(8)   VALUE SPACES.
           05  FILLER         PIC X      VALUE '_'.
           05  WS-TS-TIME     PIC X(6)   VALUE SPACES.
      *> Track data length and big-endian byte decomposition
       01  WS-TRACK-LEN       PIC 9(6)   VALUE 0.
       01  WS-BYTE1           PIC 9(3)   VALUE 0.
       01  WS-BYTE2           PIC 9(3)   VALUE 0.
       01  WS-BYTE3           PIC 9(3)   VALUE 0.
       01  WS-BYTE4           PIC 9(3)   VALUE 0.
      *> Note-loop working variables
       01  WS-LOOP            PIC 99     VALUE 0.
       01  WS-PITCH           PIC 9(3)   VALUE 0.
       01  WS-BASE-PITCH      PIC 9(3)   VALUE 0.
       01  WS-VLQ1            PIC 9(3)   VALUE 0.
       01  WS-VLQ2            PIC 9(3)   VALUE 0.
      *> Byte value for 900-WRITE-BYTE (0-255)
       01  WS-OUT-VAL         PIC 9(3)   VALUE 0.

       LINKAGE SECTION.
       01  LS-MELODY.
           05  LS-MELODY-LEN      PIC 99.
           05  LS-NOTES           OCCURS 64 TIMES.
               10  LS-N-CHAR      PIC X.
               10  LS-N-ACCID     PIC X.
               10  LS-N-OCTAVE    PIC 9.
               10  LS-N-DUR       PIC X.

       01  LS-SCALE-TABLE.
           05  LS-SC-COUNT        PIC 9.
           05  LS-SCALE           OCCURS 4 TIMES.
               10  LS-SC-NAME     PIC X(16).
               10  LS-SC-NOTE-CNT PIC 9.
               10  LS-SC-NOTES    OCCURS 7 TIMES.
                   15  LS-SCN-CH  PIC X.
                   15  LS-SCN-ACC PIC X.

       77  LS-SELECTED-SCALE      PIC 9.
       77  LS-OUTPUT-FILE         PIC X(80).
       77  LS-STATUS-MSG          PIC X(60).
       77  LS-RETURN-CODE         PIC 9.

       PROCEDURE DIVISION USING LS-MELODY
                                 LS-SCALE-TABLE
                                 LS-SELECTED-SCALE
                                 LS-OUTPUT-FILE
                                 LS-STATUS-MSG
                                 LS-RETURN-CODE.

      *> ============================================================
      *> 000-MAIN  –  Orchestrate the write sequence.
      *> ============================================================
       000-MAIN.
           MOVE 0 TO LS-RETURN-CODE
           PERFORM 100-BUILD-FILENAME
           PERFORM 200-COMPUTE-TRACK-LEN

           OPEN OUTPUT MIDI-FILE
           IF WS-FS NOT = '00'
               STRING 'ERROR: cannot open ' WS-MIDI-FNAME
                   DELIMITED SIZE INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
               EXIT PROGRAM
           END-IF

           PERFORM 300-WRITE-HEADER
           PERFORM 400-WRITE-TRACK-HEADER
           PERFORM 500-WRITE-TEMPO
           PERFORM 600-WRITE-NOTES
           PERFORM 700-WRITE-EOT

           CLOSE MIDI-FILE
           IF WS-FS NOT = '00'
               STRING 'ERROR: close failed for ' WS-MIDI-FNAME
                   DELIMITED SIZE INTO LS-STATUS-MSG
               MOVE 1 TO LS-RETURN-CODE
           ELSE
               STRING 'MIDI saved to ' WS-MIDI-FNAME
                   DELIMITED SIZE INTO LS-STATUS-MSG
           END-IF

           EXIT PROGRAM.

      *> ============================================================
      *> 100-BUILD-FILENAME
      *> Produce output/melody_YYYYMMDD_HHMMSS.mid
      *> ============================================================
       100-BUILD-FILENAME.
           MOVE FUNCTION CURRENT-DATE TO WS-CURR-DT
           MOVE WS-CURR-DT(1:8)       TO WS-TS-DATE
           MOVE WS-CURR-DT(9:6)       TO WS-TS-TIME
           MOVE SPACES TO WS-MIDI-FNAME
           STRING 'output/melody_'
                  WS-TS
                  '.mid'
               DELIMITED SIZE INTO WS-MIDI-FNAME
           MOVE WS-MIDI-FNAME TO LS-OUTPUT-FILE.

      *> ============================================================
      *> 200-COMPUTE-TRACK-LEN
      *> Track data = (N * 9) + 11 bytes.
      *>   Each note: 4 (Note On) + 5 (Note Off) = 9 bytes
      *>   Fixed overhead: 7 (tempo) + 4 (EOT) = 11 bytes
      *> Decompose big-endian into WS-BYTE1 (MSB) .. WS-BYTE4 (LSB).
      *> ============================================================
       200-COMPUTE-TRACK-LEN.
           COMPUTE WS-TRACK-LEN = (LS-MELODY-LEN * 9) + 11
           COMPUTE WS-BYTE4 =
               FUNCTION MOD(WS-TRACK-LEN, 256)
           COMPUTE WS-BYTE3 =
               FUNCTION MOD(WS-TRACK-LEN / 256, 256)
           COMPUTE WS-BYTE2 =
               FUNCTION MOD(WS-TRACK-LEN / 65536, 256)
           COMPUTE WS-BYTE1 = WS-TRACK-LEN / 16777216.

      *> ============================================================
      *> 300-WRITE-HEADER
      *> MThd chunk (14 bytes):
      *>   4D 54 68 64  00 00 00 06  00 00  00 01  01 E0
      *>   "MThd"       length=6     fmt=0  trk=1  480ppq
      *> ============================================================
       300-WRITE-HEADER.
      *>  "MThd"
           MOVE 77  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 84  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 104 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 100 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
      *>  Chunk length = 6
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 6   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
      *>  Format type 0
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
      *>  Number of tracks = 1
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 1   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
      *>  Ticks/beat = 480 (0x01E0)
           MOVE 1   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 224 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE.

      *> ============================================================
      *> 400-WRITE-TRACK-HEADER
      *> MTrk chunk header (8 bytes):
      *>   4D 54 72 6B  + 4-byte big-endian track data length
      *> ============================================================
       400-WRITE-TRACK-HEADER.
      *>  "MTrk"
           MOVE 77  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 84  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 114 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 107 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
      *>  Track data length (big-endian, computed in 200)
           MOVE WS-BYTE1 TO WS-OUT-VAL   PERFORM 900-WRITE-BYTE
           MOVE WS-BYTE2 TO WS-OUT-VAL   PERFORM 900-WRITE-BYTE
           MOVE WS-BYTE3 TO WS-OUT-VAL   PERFORM 900-WRITE-BYTE
           MOVE WS-BYTE4 TO WS-OUT-VAL   PERFORM 900-WRITE-BYTE.

      *> ============================================================
      *> 500-WRITE-TEMPO
      *> Tempo meta event (7 bytes): 00 FF 51 03 07 A1 20
      *> 120 BPM = 500 000 µs/beat = 0x07A120
      *> ============================================================
       500-WRITE-TEMPO.
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 255 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 81  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 3   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 7   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 161 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 32  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE.

      *> ============================================================
      *> 600-WRITE-NOTES
      *> For each note: map pitch and VLQ, then write:
      *>   Note On  (4 bytes): 00 90 pp 64
      *>   Note Off (5 bytes): vlq1 vlq2 80 pp 00
      *> ============================================================
       600-WRITE-NOTES.
           PERFORM VARYING WS-LOOP FROM 1 BY 1
               UNTIL WS-LOOP > LS-MELODY-LEN

               PERFORM 800-MAP-PITCH
               PERFORM 810-MAP-VLQ

      *>         Note On: delta=0, ch=0, pitch, vel=100
               MOVE 0        TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE 144      TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE WS-PITCH TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE 100      TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE

      *>         Note Off: VLQ delta, ch=0, pitch, vel=0
               MOVE WS-VLQ1  TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE WS-VLQ2  TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE 128      TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE WS-PITCH TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE
               MOVE 0        TO WS-OUT-VAL  PERFORM 900-WRITE-BYTE

           END-PERFORM.

      *> ============================================================
      *> 700-WRITE-EOT
      *> End-of-track meta event (4 bytes): 00 FF 2F 00
      *> ============================================================
       700-WRITE-EOT.
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 255 TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 47  TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE
           MOVE 0   TO WS-OUT-VAL     PERFORM 900-WRITE-BYTE.

      *> ============================================================
      *> 800-MAP-PITCH
      *> Map note char + accidental + octave to MIDI pitch (0-127).
      *>   Base pitches (octave 4): C=60 D=62 E=64 F=65 G=67 A=69 B=71
      *>   Sharp (#): +1 semitone
      *>   Octave offset: (octave - 4) * 12
      *> ============================================================
       800-MAP-PITCH.
           EVALUATE LS-N-CHAR(WS-LOOP)
               WHEN 'C'    MOVE 60 TO WS-BASE-PITCH
               WHEN 'D'    MOVE 62 TO WS-BASE-PITCH
               WHEN 'E'    MOVE 64 TO WS-BASE-PITCH
               WHEN 'F'    MOVE 65 TO WS-BASE-PITCH
               WHEN 'G'    MOVE 67 TO WS-BASE-PITCH
               WHEN 'A'    MOVE 69 TO WS-BASE-PITCH
               WHEN 'B'    MOVE 71 TO WS-BASE-PITCH
               WHEN OTHER  MOVE 60 TO WS-BASE-PITCH
           END-EVALUATE
           COMPUTE WS-PITCH = WS-BASE-PITCH
                            + ((LS-N-OCTAVE(WS-LOOP) - 4) * 12)
           IF LS-N-ACCID(WS-LOOP) = '#'
               ADD 1 TO WS-PITCH
           END-IF.

      *> ============================================================
      *> 810-MAP-VLQ
      *> Map duration code to two VLQ bytes (480 ticks/beat).
      *>   W = 1920 ticks → 8F 00  (143,   0)
      *>   H =  960 ticks → 87 40  (135,  64)
      *>   Q =  480 ticks → 83 60  (131,  96)
      *>   E =  240 ticks → 81 70  (129, 112)
      *> ============================================================
       810-MAP-VLQ.
           EVALUATE LS-N-DUR(WS-LOOP)
               WHEN 'W'
                   MOVE 143 TO WS-VLQ1
                   MOVE 0   TO WS-VLQ2
               WHEN 'H'
                   MOVE 135 TO WS-VLQ1
                   MOVE 64  TO WS-VLQ2
               WHEN 'Q'
                   MOVE 131 TO WS-VLQ1
                   MOVE 96  TO WS-VLQ2
               WHEN 'E'
                   MOVE 129 TO WS-VLQ1
                   MOVE 112 TO WS-VLQ2
               WHEN OTHER
                   MOVE 131 TO WS-VLQ1
                   MOVE 96  TO WS-VLQ2
           END-EVALUATE.

      *> ============================================================
      *> 900-WRITE-BYTE
      *> Convert WS-OUT-VAL (0-255) to a single binary byte and write.
      *> FUNCTION CHAR(n+1) gives the character whose ordinal is n.
      *> ============================================================
       900-WRITE-BYTE.
           MOVE FUNCTION CHAR(WS-OUT-VAL + 1) TO MIDI-BYTE
           WRITE MIDI-BYTE.

       END PROGRAM midiexp.
