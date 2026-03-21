      *> ============================================================
      *> main.cob
      *> Program: MAIN  (executable entry point)
      *>
      *> Interactive terminal menu for the COBOL Melody Generator.
      *>
      *> Menu options:
      *>   1 – Select scale
      *>   2 – Generate melody
      *>   3 – View current melody
      *>   4 – Save melody to file
      *>   5 – Export as MIDI
      *>   6 – Exit
      *>
      *> Compile and run:
      *>   make        (builds all modules)
      *>   make run    (builds then launches)
      *> ============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. melmain.

       ENVIRONMENT DIVISION.

       DATA DIVISION.

       WORKING-STORAGE SECTION.
      *> Pull in all shared data structures from the copybook.
       COPY music_types.cpy.

      *> Local flag to control the main loop.
       01  WS-RUNNING             PIC X VALUE 'Y'.
           88  APP-RUNNING        VALUE 'Y'.
           88  APP-DONE           VALUE 'N'.
       77  WS-PAUSE-KEY           PIC X VALUE SPACE.

       PROCEDURE DIVISION.

      *> ============================================================
      *> 000-MAIN  –  Initialise, then loop until user exits.
      *> ============================================================
       000-MAIN.
           PERFORM 100-INIT
           PERFORM 200-MAIN-LOOP UNTIL APP-DONE
           STOP RUN.

      *> ============================================================
      *> 100-INIT  –  Load scales; set defaults.
      *> ============================================================
       100-INIT.
           CALL 'scales' USING WS-SCALE-TABLE
           MOVE 1   TO WS-SELECTED-SCALE
           MOVE 0   TO WS-MELODY-COUNT
           MOVE 'N' TO WS-HAS-MELODY
           MOVE SPACES TO WS-STATUS-MSG.

      *> ============================================================
      *> 200-MAIN-LOOP  –  Show menu, read choice, dispatch.
      *> ============================================================
       200-MAIN-LOOP.
           CALL 'SYSTEM' USING 'clear'   *> GnuCOBOL-only
           PERFORM 210-SHOW-STATUS
           PERFORM 220-SHOW-MENU
           PERFORM 230-READ-CHOICE
           PERFORM 240-DISPATCH.

      *> --- Show the status message (if any) then clear it ---------
       210-SHOW-STATUS.
           IF WS-STATUS-MSG NOT = SPACES
               DISPLAY SPACES
               DISPLAY '  >> ' FUNCTION TRIM(WS-STATUS-MSG)
               MOVE SPACES TO WS-STATUS-MSG
           END-IF.

      *> --- Print the main menu ------------------------------------
       220-SHOW-MENU.
           DISPLAY SPACES
           DISPLAY '  ============================================='
           DISPLAY '     COBOL MELODY GENERATOR'
           DISPLAY '  ============================================='
           DISPLAY '  Scale: ' WS-SC-NAME(WS-SELECTED-SCALE)
           DISPLAY '  -----'
           DISPLAY '  1  Select scale'
           DISPLAY '  2  Generate melody'
           IF HAS-MELODY
               DISPLAY '  3  View current melody'
               DISPLAY '  4  Save melody to file'
               DISPLAY '  5  Export as MIDI'
           ELSE
               DISPLAY '  3  View current melody   [generate first]'
               DISPLAY '  4  Save melody to file   [generate first]'
               DISPLAY '  5  Export as MIDI         [generate first]'
           END-IF
           DISPLAY '  6  Exit'
           DISPLAY '  ============================================='
           DISPLAY SPACES.

      *> --- Read and validate the menu choice ---------------------
       230-READ-CHOICE.
           MOVE SPACE TO WS-MENU-CHOICE
           DISPLAY '  Enter choice (1-6): ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE
           IF WS-MENU-CHOICE NOT = '1' AND
              WS-MENU-CHOICE NOT = '2' AND
              WS-MENU-CHOICE NOT = '3' AND
              WS-MENU-CHOICE NOT = '4' AND
              WS-MENU-CHOICE NOT = '5' AND
              WS-MENU-CHOICE NOT = '6'
               MOVE 'Invalid choice. Please enter 1 to 6.'
                   TO WS-STATUS-MSG
               MOVE SPACE TO WS-MENU-CHOICE
           END-IF.

      *> --- Route to the correct handler --------------------------
       240-DISPATCH.
           EVALUATE WS-MENU-CHOICE
               WHEN '1' PERFORM 300-SELECT-SCALE
               WHEN '2' PERFORM 310-GENERATE
               WHEN '3' PERFORM 320-VIEW
               WHEN '4' PERFORM 330-SAVE
               WHEN '5' PERFORM 360-MIDI-EXPORT
               WHEN '6' PERFORM 340-EXIT
           END-EVALUATE.

      *> ============================================================
      *> 300-SELECT-SCALE  –  Show scale list, accept 1-8.
      *> ============================================================
       300-SELECT-SCALE.
           DISPLAY SPACES
           DISPLAY '  -- Select a scale --'
           DISPLAY '  1  C Major'
           DISPLAY '  2  G Major'
           DISPLAY '  3  A Natural Minor'
           DISPLAY '  4  C Pentatonic'
           DISPLAY '  5  D Dorian'
           DISPLAY '  6  E Minor'
           DISPLAY '  7  A Minor Pentatonic'
           DISPLAY '  8  E Minor Pentatonic'
           DISPLAY SPACES
           DISPLAY '  Enter scale number (1-8): ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN '1' MOVE 1 TO WS-SELECTED-SCALE
               WHEN '2' MOVE 2 TO WS-SELECTED-SCALE
               WHEN '3' MOVE 3 TO WS-SELECTED-SCALE
               WHEN '4' MOVE 4 TO WS-SELECTED-SCALE
               WHEN '5' MOVE 5 TO WS-SELECTED-SCALE
               WHEN '6' MOVE 6 TO WS-SELECTED-SCALE
               WHEN '7' MOVE 7 TO WS-SELECTED-SCALE
               WHEN '8' MOVE 8 TO WS-SELECTED-SCALE
               WHEN OTHER
                   MOVE 'Invalid scale. Keeping current selection.'
                       TO WS-STATUS-MSG
                   EXIT PARAGRAPH
           END-EVALUATE

           STRING 'Scale set to: '
                  FUNCTION TRIM(WS-SC-NAME(WS-SELECTED-SCALE))
               DELIMITED SIZE
               INTO WS-STATUS-MSG.

      *> ============================================================
      *> 310-GENERATE  –  Call generator, mark melody as ready.
      *> ============================================================
       310-GENERATE.
           CALL 'generator' USING WS-SCALE-TABLE
                                  WS-MELODY
                                  WS-SELECTED-SCALE
           MOVE 'Y' TO WS-HAS-MELODY
           STRING 'Melody generated ('
                  WS-MELODY-LEN
                  ' notes). Choose 3 to view or 4 to save.'
               DELIMITED SIZE
               INTO WS-STATUS-MSG.

      *> ============================================================
      *> 320-VIEW  –  Display the melody in the terminal.
      *> ============================================================
       320-VIEW.
           IF NO-MELODY
               MOVE 'No melody yet. Use option 2 to generate one.'
                   TO WS-STATUS-MSG
               EXIT PARAGRAPH
           END-IF
           CALL 'export' USING WS-MELODY
                               WS-SCALE-TABLE
                               WS-SELECTED-SCALE
                               WS-MELODY-COUNT
                               'D'
                               WS-OUTPUT-FILE
                               WS-STATUS-MSG
                               WS-RETURN-CODE
           PERFORM 350-PAUSE.

      *> ============================================================
      *> 330-SAVE  –  Increment counter then write the file.
      *> ============================================================
       330-SAVE.
           IF NO-MELODY
               MOVE 'No melody yet. Use option 2 to generate one.'
                   TO WS-STATUS-MSG
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-MELODY-COUNT
           CALL 'export' USING WS-MELODY
                               WS-SCALE-TABLE
                               WS-SELECTED-SCALE
                               WS-MELODY-COUNT
                               'S'
                               WS-OUTPUT-FILE
                               WS-STATUS-MSG
                               WS-RETURN-CODE
           IF RC-ERROR
               SUBTRACT 1 FROM WS-MELODY-COUNT
           END-IF.

      *> ============================================================
      *> 350-PAUSE  –  Wait for ENTER before clearing the screen.
      *> ============================================================
       350-PAUSE.
           DISPLAY SPACES
           DISPLAY '  Press ENTER to return to menu...'
               WITH NO ADVANCING
           ACCEPT WS-PAUSE-KEY.

      *> ============================================================
      *> 360-MIDI-EXPORT  –  Export current melody as a MIDI file.
      *> ============================================================
       360-MIDI-EXPORT.
           IF NO-MELODY
               MOVE 'No melody yet. Use option 2 to generate one.'
                   TO WS-STATUS-MSG
               EXIT PARAGRAPH
           END-IF
           CALL 'midiexp' USING WS-MELODY
                                WS-SCALE-TABLE
                                WS-SELECTED-SCALE
                                WS-OUTPUT-FILE
                                WS-STATUS-MSG
                                WS-RETURN-CODE.

      *> ============================================================
      *> 340-EXIT  –  Say goodbye and stop the loop.
      *> ============================================================
       340-EXIT.
           DISPLAY SPACES
           DISPLAY '  Goodbye!'
           DISPLAY SPACES
           MOVE 'N' TO WS-RUNNING.

       END PROGRAM melmain.
