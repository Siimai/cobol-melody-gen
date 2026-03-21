## Plan: COBOL Melody App

Create a small learning-oriented COBOL application for macOS that runs as an interactive terminal menu, generates simple melodies from a limited set of scales/keys, and saves human-readable note sequences to disk. Use GnuCOBOL as the assumed toolchain, keep the first version intentionally narrow, and structure the project so later additions like ABC export or note editing can be added without rewriting the core flow.

**Steps**
1. Phase 1: Initialize the project structure and local development assumptions.
   - Define the project layout for source, data, output, and documentation.
   - Standardize on GnuCOBOL installed via Homebrew for local setup.
   - Add a minimal build/run workflow so the app can be compiled and executed consistently.
2. Phase 2: Establish the shared music model. *depends on 1*
   - Define fixed-size COBOL data structures for notes, melody length, selected scale/key, and application state.
   - Predefine a small starter music scope: a few scales and keys only.
   - Keep note output human-readable, such as note name + octave + duration.
3. Phase 3: Build the interactive menu shell. *depends on 2*
   - Implement a main loop with menu choices for generate melody, view current melody, save melody, and exit.
   - Add robust input validation and re-prompt behavior for invalid menu entries.
   - Keep manual note editing out of scope for v1.
4. Phase 4: Implement melody generation logic. *depends on 2; parallel with 3 after data model is stable*
   - Generate melodies using simple constrained randomness within the selected scale.
   - Apply basic length and rhythm rules so output stays readable and musical enough for a demo.
   - Prefer deterministic generation support if practical, but do not block v1 on seed handling.
5. Phase 5: Implement display and file export. *depends on 3 and 4*
   - Render the generated melody back to the terminal in a compact readable format.
   - Save the melody to a text file under an output directory using predictable naming.
   - Return clear status messages for file-write success and failure.
6. Phase 6: Add sample data, docs, and test coverage. *depends on 5*
   - Document macOS setup, build, run, and project scope in a README.
   - Add a few manual verification cases and any lightweight automated checks available in the chosen build flow.
   - Include sample expected outputs so the generation/export path is easy to verify.

**Relevant files**
- /Users/siimai/development/cobol/README.md — setup, build, run, and first-version scope
- /Users/siimai/development/cobol/.gitignore — ignore build artifacts and generated output as appropriate
- /Users/siimai/development/cobol/Makefile or /Users/siimai/development/cobol/build.sh — compile and run workflow for GnuCOBOL
- /Users/siimai/development/cobol/src/main.cob — entry point and menu loop
- /Users/siimai/development/cobol/src/music_types.cpy — shared note and melody definitions
- /Users/siimai/development/cobol/src/scales.cob — predefined keys/scales and lookup logic
- /Users/siimai/development/cobol/src/generator.cob — constrained melody-generation routines
- /Users/siimai/development/cobol/src/export.cob — terminal formatting and text-file output
- /Users/siimai/development/cobol/output/ — generated melody files
- /Users/siimai/development/cobol/tests/ — manual test notes or simple regression checks

**Verification**
1. Install or confirm GnuCOBOL on macOS and verify the compiler is available from the terminal.
2. Build the app from the project root using the documented build command.
3. Run the app and verify the menu loop accepts valid choices and rejects invalid input cleanly.
4. Generate melodies across each supported scale/key option and confirm all notes stay within the selected scale set.
5. Save at least one generated melody and confirm the output file is created with the expected plain-text note sequence format.
6. Re-run generation multiple times to confirm the app remains stable with repeated menu use.

**Decisions**
- Included: interactive terminal UI, melody generation, terminal display, plain-text file export, macOS local setup.
- Excluded from v1: MIDI/audio playback, ABC/MusicXML export, manual note editing, broad music-theory coverage, advanced composition rules.
- Recommended scope: learning/demo quality over production completeness.
- Recommended toolchain: GnuCOBOL via Homebrew on macOS.

**Further Considerations**
1. Seeded randomness can be added early if reproducible demos matter; otherwise keep v1 fully random to reduce setup complexity.
2. If the user later wants playable output, ABC export is the next logical step before MIDI.
3. If the user later wants richer music logic, extend the shared data model first rather than embedding rules directly into the menu flow.
