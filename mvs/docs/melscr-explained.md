# MELSCR assembler walkthrough

This guide follows [`melscr.asm`](../melody/source/asm/melscr.asm) from top to bottom. It explains the executable statements in source order, including the effect of each macro invocation, and then describes every working-storage field, literal/table entry, and DCB. Blank lines and comment-only lines in the source are organizational; the source comments at each paragraph heading summarize the paragraph's purpose.

## Conventions and register roles

The program is HLASM for the MVS 3.8j/TK4 environment. Registers are written as `R0` through `R15` in this guide. In this source, `R12` and `R9` address the code, `R13` addresses the dynamically allocated `WORK` area, `R6` points into the outgoing 3270 data stream, `R10` holds a paragraph return address, and `R11` is used by nested helper calls. Other registers are temporary and their exact meanings are stated by each paragraph.

Frequently used instruction forms:

- `LA` computes an address or small constant; it does not fetch the contents at that address.
- `L`, `LH`, and `IC` load a fullword, halfword, or one byte; `ST` and `STC` store a fullword or byte.
- `MVC` copies bytes; `CLC` compares byte strings; `CLI` compares one byte with an immediate value.
- `BAL r,target` branches to `target`, saving the next instruction address in register `r`; `BR r` branches to the address in `r`.
- `B`, `BE`, `BNE`, `BNZ`, `BZ`, `BL`, and `BH` branch unconditionally or according to the condition code set by the preceding instruction.
- `DS` reserves storage, `DC` defines initialized constants, `EQU` defines an assembly-time value, and `DSECT` describes storage layout without allocating it.
- The assembler macros `PTXT`, `PFLD`, and `SBAM` expand inline; their bodies are explained below, so each use of them has the effect described here plus the arguments shown at that call.

## Assembler options and macros

`PRINT NOGEN` suppresses expanded macro listings in the assembler output. The macros still expand and execute normally.

### `SBAM &R,&C`

- `LA 2,(&R-1)*80+&C-1` computes the 0-based 3270 screen-buffer address for row `&R`, column `&C`, assuming 80 columns.
- `BAL 11,PUTSBA` appends a 3270 Set Buffer Address order for that address; `PUTSBA` returns through `R11`.
- `MEND` ends this macro definition.

### `PTXT &R,&C,&ATTR,&TXT`

- `LCLA &L` creates a local assembler-time arithmetic variable.
- `&L SETA K'&TXT-2` sets the number of text bytes, subtracting the two quote characters from the quoted macro argument's length.
- `SBAM &R,&C-1` positions the stream one column before the visible text, allowing the field-attribute order to occupy the preceding cell.
- `MVI 0(6),X'1D'` places a 3270 Start Field order at the current output pointer.
- `MVI 1(6),&ATTR` supplies the field attribute (for example, protected normal or protected bright).
- `MVC 2(&L,6),=C&TXT` copies the literal text into the outgoing stream.
- `LA 6,2+&L.(6)` advances `R6` past the field order, attribute, and text so the next stream element can be appended.
- `MEND` ends the macro definition.

### `PFLD &R,&C,&LEN,&VAR`

- `SBAM &R,&C-1` positions before the input field's first visible character.
- `MVI 0(6),X'1D'` starts a 3270 field.
- `MVI 1(6),X'C8'` makes it an unprotected, bright input field.
- `MVC 2(&LEN,6),&VAR` initializes the displayed input bytes from the program's working field.
- `LA 6,2+&LEN.(6)` advances past the field start and initial contents.
- The next `MVI 0(6),X'1D'` and `MVI 1(6),X'60'` start a protected field immediately after the input area; this closes/terminates the unprotected field.
- `LA 6,2(6)` advances past that terminating field order and attribute.
- `MEND` ends the macro definition.

## Working storage layout: `WORK DSECT`

`WORK DSECT` begins a map of the area obtained with `GETMAIN`. Every field below is relative to `R13` after `USING WORK,13` is established. The `DS` statements reserve space in sequence; none initializes that space.

| Field | Definition | Use |
|---|---|---|
| `SAVE` | `DS 18F` | 18-fullword save area used by the standard linkage convention. |
| `INLEN` | `DS F` | Number of bytes returned by `TGET`. |
| `RETC` | `DS F` | Return code to place in the caller's save area before returning. |
| `UL` | `DS F` | Length of the userid copied from the PARM, bounded to eight. |
| `ROWC` | `DS F` | Current screen row in output loops. |
| `COLP` | `DS F` | Current screen column in the melody display loop. |
| `POLLC` | `DS F` | Remaining one-second result-poll attempts. |
| `SAVCNT` | `DS F` | Number of saved-melody records counted before appending. |
| `NCNT` | `DS F` | Number of notes to export to MIDI. |
| `BPM` | `DS F` | Tempo in beats per minute during MIDI conversion. |
| `PCH` | `DS F` | Temporarily preserves a MIDI pitch across helper calls. |
| `MLEN` | `DS F` | Number of MIDI bytes generated. |
| `NSAV` | `DS F` | Number of saved records currently held in `SAVEDT`. |
| `LNK1` | `DS F` | Saves `R10` when a paragraph makes nested calls using `R10`. |
| `EODRET` | `DS A` | Address of the current end-of-data continuation routine. |
| `TMPD` | `DS D` | Eight-byte packed/zoned conversion scratch area. |
| `AID` | `DS X` | Attention identifier byte returned by `TGET` (Enter or a PF key). |
| `MODE` | `DS C` | Start/wait mode from PARM: `S` or `W`. |
| `VIEW` | `DS C` | Screen state: melody/main view `M` or saved-list view `L`. |
| `VALOK` | `DS C` | Validation result, `Y` only when input passes. |
| `HAVRES` | `DS C` | `Y` when a melody result is loaded into the result fields. |
| `EODF` | `DS C` | End-of-data flag storage; initialized in `RESTORE`. |
| `CURSC` | `DS C` | One-byte scale number derived from the currently shown melody. |
| `SCV` | `DS CL1` | One-character scale input. |
| `NTV` | `DS CL2` | Two-character note-count input. |
| `TMV` | `DS CL3` | Three-character tempo input. |
| `LDV` | `DS CL3` | Three-character saved-melody number input. |
| `NORMV` | `DS CL3` | Three-digit, zero-filled normalized numeric value. |
| `TM3` | `DS CL3` | Validated tempo formatted as three digits for SYSIN. |
| `NN` | `DS CL2` | Validated note count formatted as two digits. |
| `SC1` | `DS CL1` | Validated scale formatted as one digit. |
| `CURLEN` | `DS CL2` | Note count extracted from the current result. |
| `CURTM` | `DS CL3` | Tempo extracted from the current result. |
| `UID` | `DS CL8` | Space-padded userid supplied in PARM. |
| `MSG` | `DS CL70` | Status/error message displayed on the panel. |
| `TL` | `DS CL44` | One formatted saved-melody list row. |
| `RES1`, `RES2` | `DS CL80` each | First and second output records from the generator. |
| `RESN` | `DS CL72` | Up to 18 four-character note descriptions. |
| `REC` | `DS CL80` | Work record for fixed 80-byte sequential files and generated JCL. |
| `SAVEDT` | `DS CL800` | Space for ten 80-byte saved-melody records. |
| `MBUF` | `DS XL200` | Binary buffer for the generated Standard MIDI File. |
| `REV` | `DS XL256` | Reverse 3270 address translation table indexed by encoded byte. |
| `INBUF` | `DS XL256` | Buffer for the `TGET` attention byte and modified-field input. |
| `BUF` | `DS XL1400` | Outgoing 3270 screen data stream. |
| `WORKLEN` | `EQU *-WORK` | Total bytes described by `WORK`; passed to `GETMAIN` and `FREEMAIN`. |

## Entry point and event loop

### `MELSCR CSECT` through `PARMX`

- `MELSCR CSECT` starts the executable control section.
- `STM 14,12,12(13)` saves registers 14 through 12 in the caller's save area.
- `LR 12,15` copies the entry address into the primary code base register.
- `LA 9,4095(12)` and `LA 9,1(9)` establish the second code base just beyond the first 4K region.
- `USING MELSCR,12,9` tells the assembler that `R12` and `R9` can address this section.
- `LR 2,1` preserves the address of the parameter-list pointer.
- `GETMAIN R,LV=WORKLEN` obtains the working area.
- `ST 13,4(1)` saves the caller's prior `R13` in the new area's linkage slot.
- `ST 1,8(13)` links the new area back to the caller's save area.
- `LR 13,1` makes the new area the current save/work area.
- `USING WORK,13` establishes the `WORK` DSECT base.
- `MVI MODE,C'S'` defaults to start mode.
- `MVC UID,=CL8' '` clears the userid to eight spaces.
- `MVC UL,=F'1'` defaults its length to one.
- `L 3,0(2)` follows the saved parameter-list pointer to the PARM address.
- `LH 4,0(3)` gets the halfword PARM length.
- `LTR 4,4` sets condition codes from that length; `BZ PARMX` skips parsing if it is zero.
- `MVC MODE,2(3)` takes the first PARM character as the mode.
- `SH 4,=H'2'` removes the mode and comma from the length, leaving userid length.
- `BNP PARMX` skips userid copying if the remaining length is not positive.
- `C 4,=F'8'` compares the userid length with the eight-byte destination; `BNH PARM1` keeps lengths at most eight.
- `LA 4,8` caps longer userid strings at eight.
- `PARM1 ST 4,UL` records the selected length.
- `BCTR 4,0` changes the length to the zero-based count required by an execute-form MVC.
- `EX 4,MVCPARM` copies that many userid bytes using the template instruction at `MVCPARM`.
- `PARMX BAL 10,INIT` builds runtime tables and initializes screen state.
- `CLI MODE,C'W'` checks wait mode; `BNE LOOP` enters the normal event loop for start mode.
- `BAL 10,RESTORE` recovers the submitted input values when returning from the CLIST in wait mode.
- `MVC MSG,MSGWAIT` prepares the waiting status text.
- `BAL 10,BUILD` and `BAL 10,SEND` draw the waiting panel before polling.
- `MVC POLLC,=F'20'` sets a maximum of 20 attempts.

### Wait loop `WL` and `WDONE`

- `WL STIMER WAIT,BINTVL=WAITV` waits one second, using the `WAITV` constant.
- `BAL 11,READOUT` tries to read a complete melody result; `R15` reports success or not-ready.
- `LTR 15,15` tests that result; `BZ WDONE` exits polling when it is ready.
- `L 2,POLLC`, `BCTR 2,0`, and `ST 2,POLLC` decrement the remaining attempt count.
- `LTR 2,2` and `BNZ WL` repeat while attempts remain.
- `MVC MSG,MSGTMO` displays the timeout message once all attempts are exhausted.
- `B LOOP` resumes interactive processing after timeout.
- `WDONE MVC MSG,MSGDONE` displays the completion status when the result is ready.

### Main `LOOP` dispatch

- `LOOP BAL 10,BUILD` builds the current main or saved-list screen.
- `BAL 10,SEND` writes it with `TPUT`.
- `BAL 10,RECV` waits for a key and reads modified fields.
- The following `CLI AID,...` / `BE ...` pairs dispatch PF3 (`X'F3'`), PF5 (`X'F5'`), PF6 (`X'F6'`), PF7 (`X'F7'`), and Enter (`X'7D'`). Each `CLI` compares the AID byte; `BE` branches when it matches.
- If the AID is not Enter, `BNE LOOP` redraws the screen and waits again.
- `BAL 10,PARSE` copies any changed fields from the terminal buffer into the working fields.
- `CLI VIEW,C'L'` and `BE ENTL` route Enter from the list view to the saved-item loader.
- `BAL 10,VALID` checks the main-view inputs; `CLI VALOK,C'Y'` and `BNE LOOP` keep the panel open if invalid.
- `BAL 10,SUBPREP` writes the JCL and running marker when inputs are valid.
- `MVC RETC,=F'4'` sets the special return code that tells `MELPANEL` to submit the generated job.
- `B FINISH` leaves the interactive program after preparing the job.
- `ENTL BAL 10,LOADIT` loads the requested saved melody; `B LOOP` redraws.

### PF-key handlers and return

- `PF3 CLI VIEW,C'L'` tests whether PF3 was pressed on the saved list. If not, `BNE EXIT` exits the panel.
- On the list, `MVI VIEW,C'M'` switches back to the main view, `MVC MSG,MSG0` restores the initial prompt, and `B LOOP` redraws.
- `PF5 CLI VIEW,C'L'` ignores save while the list is open (`BE LOOP`). Otherwise `BAL 10,PARSE` captures edits, `BAL 10,SAVEIT` saves the displayed result, and `B LOOP` redraws.
- `PF7` uses the same list-view guard; on the main view it parses edits, calls `MIDIEXP`, and returns to the loop.
- `PF6 BAL 10,PARSE` captures fields, `BAL 10,LISTIT` reads the saved entries, `MVI VIEW,C'L'` selects list view, and `B LOOP` draws it.
- `EXIT BAL 10,ENDSCR` erases the panel and returns to line mode; `MVC RETC,=F'0'` selects a normal return.
- `FINISH L 2,RETC` loads the return code; `L 3,4(13)` retrieves the caller save-area pointer; `LR 1,13` remembers the allocated area address.
- `FREEMAIN R,LV=WORKLEN,A=(1)` releases the work area.
- `LR 13,3` restores the caller's `R13`.
- `ST 2,16(13)` stores the return code in the caller's save area.
- `LM 14,12,12(13)` restores saved registers, and `BR 14` returns to the caller.
- `MVCPARM MVC UID(1),4(3)` is the execute-form copy template: the `EX` instruction modifies its length field and copies userid bytes beginning after the mode and comma.

## Initialization: `INIT`

- `SR 3,3` clears the index used to visit all 64 encoded 3270 addresses.
- `INIT1 SR 4,4` clears the temporary byte value on each pass.
- `IC 4,TAB(3)` loads the encoded terminal address byte corresponding to index `R3`.
- `STC 3,REV(4)` stores the original six-bit index in the reverse table at that encoded-byte position.
- `LA 3,1(3)` advances to the next address; `C 3,=F'64'` compares it with 64; `BL INIT1` repeats until all entries are mapped.
- `MVC MSG,MSG0` loads the default status prompt.
- `MVI SCV,C' '` blanks the scale field; the following `MVC NTV,...`, `MVC TMV,...`, and `MVC LDV,...` blank the note, tempo, and saved-number fields.
- `MVI HAVRES,C'N'` states there is no displayed result; `MVI VALOK,C'N'` clears validation; `MVI VIEW,C'M'` selects the main view.
- `BR 10` returns to the caller.

## Main panel construction: `BUILD`

- `CLI VIEW,C'L'` checks list view; `BE BUILDL` hands off to the list-screen builder.
- `LA 6,BUF` points `R6` at the beginning of the outgoing 3270 stream.
- `MVI 0(6),X'F5'` begins an Erase/Write command; `MVI 1(6),X'C3'` sets the write-control character to reset modified-data tags and restore keyboard input.
- `LA 6,2(6)` moves past those two command bytes.
- `MVC 0(7,6),ERASE` copies the seven-byte SBA/Repeat-to-Address sequence that blanks the entire screen; `LA 6,7(6)` advances past it.

Each `PTXT` below writes one protected screen field at the given row and column. The attribute is `X'E8'` for protected bright text and `X'60'` for protected normal text.

| Source macro call | Text placed |
|---|---|
| `PTXT 1,3,X'E8',...` | Bright title: `MELODY68 - COBOL-68 MELODY GENERATOR`. |
| `PTXT 2,3,X'60',...` | MVS/TK4 and COBOL environment subtitle. |
| `PTXT 4,3,X'E8',...` | Bright `SCALES` heading. |
| `PTXT 5,5,X'60',...` | Scale 1, C major. |
| `PTXT 6,5,X'60',...` | Scale 2, G major. |
| `PTXT 7,5,X'60',...` | Scale 3, A natural minor. |
| `PTXT 8,5,X'60',...` | Scale 4, C pentatonic. |
| `PTXT 5,32,X'60',...` | Scale 5, D dorian. |
| `PTXT 6,32,X'60',...` | Scale 6, E minor. |
| `PTXT 7,32,X'60',...` | Scale 7, A minor pentatonic. |
| `PTXT 8,32,X'60',...` | Scale 8, E minor pentatonic. |
| `PTXT 9,5,X'60',...` | Scale 0, random. |
| `PTXT 11,3,X'60',...` | `SCALE ===>` label. |
| `PFLD 11,15,1,SCV` | One-byte scale input field. |
| `PTXT 11,20,X'60',...` | Scale valid range and random/blank hint. |
| `PTXT 12,3,X'60',...` | `NOTES ===>` label. |
| `PFLD 12,15,2,NTV` | Two-byte note-count input field. |
| `PTXT 12,20,X'60',...` | Note-count range and random/blank hint. |
| `PTXT 13,3,X'60',...` | `TEMPO ===>` label. |
| `PFLD 13,15,3,TMV` | Three-byte tempo input field. |
| `PTXT 13,20,X'60',...` | Tempo range and blank-default hint. |

- `CLI HAVRES,C'Y'` checks for a displayed melody; `BNE NORES` skips its result area when absent.
- `PTXT 15,3,X'E8',...` writes the bright `MELODY` heading.
- `SBAM 15,10` positions the stream for the first result record; the following `MVI`s start a protected normal field, `MVC 2(32,6),RES1+1` displays 32 characters from the first result record, and `LA 6,34(6)` advances past order, attribute, and text.
- `SBAM 15,52` positions for the second result field; its `MVI`s start another protected normal field, `MVC 2(24,6),RES2+1` copies 24 result characters, and `LA 6,26(6)` advances the stream.
- `MVC ROWC,=F'15'` starts note display on row 15; `LA 8,RESN` points to the first note; `LA 7,3` sets three output rows.
- `RROW LA 5,6` sets six notes per row; `MVC COLP,=F'3'` starts at column 3.
- `RCOL L 2,ROWC` loads the row; `MH 2,=H'80'` converts it to a row offset; `A 2,COLP` adds the current column; `BAL 11,PUTSBA` emits the screen address.
- `MVI 0(6),X'1D'` and `MVI 1(6),X'E8'` start a protected-bright field; `MVC 2(4,6),0(8)` copies one four-character note; `LA 6,6(6)` advances past the field order, attribute, and note.
- `LA 8,4(8)` advances to the next note; `L 2,COLP`, `LA 2,8(2)`, and `ST 2,COLP` move eight columns to the next note slot; `BCT 5,RCOL` repeats six times.
- After a row, `L 2,ROWC`, `LA 2,1(2)`, and `ST 2,ROWC` increment the row; `BCT 7,RROW` repeats for three rows.
- `NORES DS 0H` marks the join point after the optional melody output without reserving bytes.
- `SBAM 22,1` addresses the status row; the two `MVI`s create a bright protected field, `MVC 2(70,6),MSG` displays the status, and `LA 6,72(6)` advances past it.
- The two `PTXT` calls at row 24 display the command legends for Enter/PF5/PF6 and PF7/PF3.
- `SBAM 11,15` positions the cursor at the scale input; `MVI 0(6),X'13'` emits Insert Cursor; `LA 6,1(6)` advances one byte; `BR 10` returns.

## Saved-list screen: `BUILDL`

- The initial `LA 6,BUF`, `MVI` command/WCC bytes, `LA 6,2(6)`, `MVC 0(7,6),ERASE`, and `LA 6,7(6)` perform the same screen initialization as `BUILD`.
- The first `PTXT` draws the saved-melodies title; the second draws the column headings.
- `L 7,NSAV` loads the number of list entries; `LTR 7,7` tests for zero; `BNZ BL1` starts listing if any exist.
- With no entries, `PTXT 5,3,...` displays the empty-list message and `B BL9` skips the row loop.
- `BL1 MVC ROWC,=F'4'` chooses the first list row; `LA 8,SAVEDT` points at the first saved record.
- `BL2 MVC TL,BLANKS` clears the formatted row; `MVI TL,C'#'` writes the number marker; `MVC TL+1(3),0(8)` copies the three-digit record ID.
- `SR 2,2` clears a register; `IC 2,3(8)` loads the scale byte; `N 2,=F'15'` masks it to a nibble; `BZ BL3` skips name lookup for scale zero.
- `BCTR 2,0`, `MH 2,=H'16'`, and `LA 3,SCNAMES(2)` turn a 1-based scale number into a byte offset in the 16-byte name table; `MVC TL+6(16),0(3)` copies the name.
- `BL3 MVC TL+24(3),4(8)` copies the three-byte tempo; `MVC TL+27(4),=C' BPM'` adds the unit; `MVC TL+34(2),7(8)` copies the two-byte note count; `MVC TL+36(6),=C' NOTES'` adds its label.
- `L 2,ROWC`, `MH 2,=H'80'`, and `AH 2,=H'1'` calculate the screen address for the row; `BAL 11,PUTSBA` emits it.
- The `MVI` pair starts a protected normal field; `MVC 2(44,6),TL` displays the formatted row; `LA 6,46(6)` advances the output pointer.
- The `L`/`LA`/`ST` sequence increments `ROWC`; `LA 8,80(8)` advances to the next 80-byte record; `BCT 7,BL2` repeats for all records.
- `BL9 DS 0H` joins empty and nonempty list cases.
- `PTXT 16,3,...` draws the load prompt; `PFLD 16,15,3,LDV` draws its three-byte input field.
- `SBAM 22,1`, the field `MVI`s, `MVC 2(70,6),MSG`, and `LA 6,72(6)` output the status message.
- The row-24 `PTXT` shows Enter=Load and PF3=Back.
- `SBAM 16,15` puts the cursor in the load field; `MVI 0(6),X'13'` emits the cursor order; `LA 6,1(6)` advances and `BR 10` returns.

## 3270 and input helpers

### `PUTSBA`

- `MVI 0(6),X'11'` starts a 3270 Set Buffer Address order.
- `LR 3,2` copies the 0-based buffer address.
- `SRL 3,6` extracts the high six address bits; `IC 4,TAB(3)` translates them to the terminal's encoded address byte; `STC 4,1(6)` writes that byte.
- `N 2,=F'63'` masks the low six address bits; `IC 4,TAB(2)` translates them; `STC 4,2(6)` writes the low address byte.
- `LA 6,3(6)` advances past the SBA order and its two address bytes; `BR 11` returns.

### `SEND`

- `LA 2,BUF` sets the output-stream address.
- `LR 3,6` gets the end pointer; `SR 3,2` converts it to stream length.
- `TPUT (2),(3),FULLSCR` sends that buffer as a full-screen 3270 write; `BR 10` returns.

### `RECV`

- `MVI INBUF,X'00'` clears the first byte before input.
- `TGET INBUF,256,ASIS` receives the AID and modified data without translating the bytes.
- `ST 1,INLEN` saves the byte count returned in `R1`.
- `MVC AID,INBUF` saves the first byte as the attention identifier; `BR 10` returns.

### `PARSE` and `CPYFLD`

- `L 7,INLEN` loads the input length; `LA 7,INBUF(7)` computes the end pointer; `LA 5,INBUF+3` starts scanning after the AID and initial address bytes.
- `PLOOP CR 5,7` compares current and end pointers; `BNLR 10` returns when scanning is complete.
- `CLI 0(5),X'11'` checks for an SBA order; `BNE PNEXT` skips ordinary input bytes.
- The four `SR`/`IC`/`IC REV` instructions decode the two address bytes using `REV`; `SLL 3,6` positions the high six bits, and `AR 3,4` combines the low bits.
- `LA 5,3(5)` moves past the SBA order and both address bytes.
- `C 3,=A(SCPOS)` checks the scale-field address; if matched, `MVI SCV,C' '` clears the destination, `LA 8,SCV` sets the copy target, `LA 2,1` sets field width, and `BAL 11,CPYFLD` copies the modified character. `B PLOOP` resumes scanning.
- `P2` checks the note address; on match it blanks `NTV`, points `R8` at it, sets width two, calls `CPYFLD`, then resumes.
- `P3` checks the tempo address; on match it blanks `TMV`, points `R8` at it, sets width three, copies, then resumes.
- `P4` checks the saved-number address; if it does not match, `B PLOOP` continues. If it matches, it blanks `LDV`, sets its target and width three, copies, and resumes.
- `PNEXT LA 5,1(5)` skips one non-SBA byte; `B PLOOP` continues scanning.
- `CPYFLD LTR 2,2` tests remaining field width; `BZR 11` returns for zero width.
- `CR 5,7` and `BNLR 11` stop at the input end; `CLI 0(5),X'11'` / `BER 11` stop at the next SBA order; `CLI 0(5),X'00'` / `BER 11` stop at a null.
- `MVC 0(1,8),0(5)` copies one typed byte; `LA 8,1(8)` advances the destination; `LA 5,1(5)` advances the input; `BCT 2,CPYFLD` repeats for the field width; `BR 11` returns.

## Numeric normalization: `NORM3`

`NORM3` receives a three-character field at `R5`, stores normalized digits in `NORMV`, and returns status in `R15`.

- `MVC NORMV,=C'000'` starts with a zero-filled result.
- `LA 4,3` starts with a maximum width of three.
- The `CLI`/`BNE`/`BCTR` sequence checks trailing, middle, then leading spaces and reduces the number of significant characters. If all are blank, `SR 15,15` returns success and `BR 11` exits.
- `NM1 LR 2,5` points `R2` at the input; `LR 7,4` sets a loop count to its significant length.
- `NM2` compares each byte against `'0'` and `'9'`. `BL NMBAD` and `BH NMBAD` reject non-digits; `LA 2,1(2)` advances; `BCT 7,NM2` checks every significant character.
- `LA 3,NORMV+3` points one past the normalized destination; `SR 3,4` backs up by the field width; `BCTR 4,0` converts width to an execute-form length.
- `EX 4,MVCNM` copies the significant digits into the rightmost part of `NORMV`; `SR 15,15` sets success; `BR 11` returns.
- `NMBAD LA 15,4` returns a nonzero invalid-number status; `BR 11` returns.
- `MVCNM MVC 0(1,3),0(5)` is the one-byte template modified by `EX` to copy multiple bytes.

## Input validation: `VALID` and `MELVAL`

Validation lives in the COBOL-68 subprogram `MELVAL` ([`melval.cbl`](../melody/source/cobol/melval.cbl)), so the rules read as COBOL. `VALID` only calls it.

- `INIT` does `LOAD EP=MELVAL`; `FINISH` does `DELETE EP=MELVAL`.
- `WORK` holds `SCV, NTV, TMV, VRC, SC1, NN, TM3` contiguously. That block is the 13-byte `VAL-AREA` passed as the single parameter (in: scale, notes, tempo; out: return code, scale digit, note count, tempo).
- `VALID` sets the last-parameter bit in `VPLIST`, points `R1` at it and `BALR 14,15` to `MELVAL`.
- `VRC` is `0` for success (`VALOK`=`Y`, `MSGSUB` shown) or `1`, `2`, `3` for a bad scale, notes or tempo (`MSGB1`, `MSGB2`, `MSGB3`).
- Rules: scale blank or 0-8; notes blank, 0, or 8-16 (`8` and `08` both fine); tempo blank, 0, or 40-240. Blank scale/notes/tempo mean random/default.
- `MELVAL` ends with `GOBACK`; COBOL F rejects `EXIT PROGRAM`.
- `NORM3` stays in assembler for `LOADIT`.

## Userid copying and JCL creation

### `INSUID`

- `L 4,UL` loads userid length; `BCTR 4,0` forms the zero-based MVC length.
- `EX 4,MVCUID` copies the userid into the destination pointed to by `R3`.
- `A 3,UL` advances the destination pointer past the userid; `BR 11` returns.
- `MVCUID MVC 0(1,3),UID` is the execute-form one-byte copy template.

### `SUBPREP`

- `ST 10,LNK1` preserves the paragraph return link.
- `OPEN (RJO,OUTPUT)` opens the run-JCL output file.
- `MVC REC,BLANKS` clears the record; `MVC REC(2),=C'//'` begins the first JCL record.
- `LA 3,REC+2` sets the insertion point; `BAL 11,INSUID` writes the userid; `MVI 0(3),C'R'` adds `R` to form the job name.
- `MVC 1(23,3),=C' JOB (1),MELODY,CLASS=A'` appends job accounting, programmer, and class operands; `PUT RJO,REC` writes the card.
- The next `MVC REC,BLANKS`, `MVC REC(L'T2),T2`, and `PUT` writes the `EXEC PGM=MELODY68` step.
- The next record is initialized from `T3`; `LA 3,REC+L'T3` finds the dataset insertion position; `MVC 0(20,3),=C'MELODY.LOAD,DISP=SHR'` supplies the shared load library; `PUT` writes it.
- The next record is initialized from `T4`; `LA 3,REC+L'T4` finds the output dataset position; `BAL 11,INSUID` writes the userid prefix; `MVC 0(20,3),=C'.MELODY.OUT,DISP=SHR'` completes the per-user output DSN; `PUT` writes it.
- The next record copies `T5` and writes the SYSIN DD card.
- The SYSIN data record is blanked, then `MVC REC(1),SC1`, `MVC REC+1(2),NN`, and `MVC REC+3(3),TM3` place the validated scale, note count, and tempo in columns 1-6; `PUT` writes it.
- The next blanked record gets `/*` and is written to terminate SYSIN data; another blanked record gets `//` and is written as the JCL terminator.
- `CLOSE (RJO)` closes the generated JCL file.
- `OPEN (OUO,OUTPUT)` opens the result marker file; `MVC REC,BLANKS` clears its record; `MVC REC(8),=C' RUNNING'` writes the marker; `PUT OUO,REC` writes it; `CLOSE (OUO)` closes the file.
- `L 10,LNK1` restores the caller link; `BR 10` returns.

## Restore and generator-result reading

### `RESTORE`

- `ST 10,LNK1` preserves the caller link.
- `MVI EODF,C'N'` clears the end-of-data flag storage.
- `LA 3,RSDONE` and `ST 3,EODRET` select `RSDONE` as the end-of-data continuation.
- `OPEN (RJI,INPUT)` opens the generated JCL for reading.
- `LA 7,6` sets a count; `RS1 GET RJI` reads six records, and `BCT 7,RS1` loops through them to reach the SYSIN data record.
- `MVC SCV,0(1)`, `MVC NTV,1(1)`, and `MVC TMV,3(1)` restore scale, notes, and tempo from that record.
- `BAL 11,STRIP0` converts default values back to the screen's blank/short display format.
- `RSDONE CLOSE (RJI)` closes the file on normal or end-of-data continuation; `L 10,LNK1` and `BR 10` return.

### `STRIP0`

- `CLI SCV,C'0'` tests scale zero; `BNE ST1` leaves nonzero scales unchanged; `MVI SCV,C' '` displays zero as blank.
- `ST1 CLC NTV,=C'00'` tests for zero notes; `BNE ST2` skips conversion otherwise; `MVC NTV,=C'  '` displays zero as blank.
- `ST2 CLI NTV,C'0'` tests whether a one-digit count is zero-padded; `BNE ST3` skips if not; `MVC NTV(1),NTV+1` shifts the digit left; `MVI NTV+1,C' '` clears the second position.
- `ST3 CLC TMV,=C'000'` tests zero tempo; `BNE ST4` skips otherwise; `MVC TMV,=C'   '` displays the default as blank.
- `ST4 BR 11` returns.

### `READOUT`

- `MVI HAVRES,C'N'` clears the result-present flag.
- `LA 3,RDNO` and `ST 3,EODRET` make `RDNO` the not-ready/end-of-file continuation.
- `OPEN (OUI,INPUT)` opens the result file; `GET OUI` reads its first record.
- `LR 3,1` saves the record pointer; `CLC 1(8,3),=C'MELODY68'` checks the identifying text; `BNE RDNO` rejects a non-result marker such as `RUNNING`.
- `MVC RES1,0(3)` copies the first result record; the next `GET OUI` reads the second; `MVC RES2,0(1)` copies it.
- `MVC RESN,BLANKS` clears the note-description area.
- `LA 3,RDDONE` / `ST 3,EODRET` set the continuation used if note input ends early.
- `LA 8,RESN` points to the result area; `LA 7,18` sets the expected count; `RDL GET OUI` reads each note record, `MVC 0(4,8),1(1)` copies its four-character note, `LA 8,4(8)` advances, and `BCT 7,RDL` repeats 18 times.
- `RDDONE MVI HAVRES,C'Y'` marks a complete result; `CLOSE (OUI)` closes the file; `SR 15,15` returns success; `BR 11` returns.
- `RDNO CLOSE (OUI)` closes on the not-ready path; `LA 15,4` returns the nonzero status; `BR 11` returns.

## Current-result metadata and saved melodies

### `CURINFO`

- `MVC CURLEN,RES2+8` extracts the note count; `MVC CURTM,RES2+19` extracts the tempo.
- `LA 3,SCNAMES`, `LA 2,1`, and `LA 7,8` initialize a scan over eight scale names.
- `CI1 CLC RES1+17(16),0(3)` compares the result's scale name with the current table entry; `BE CI2` stops on a match.
- `LA 3,16(3)` advances to the next name; `LA 2,1(2)` advances its scale number; `BCT 7,CI1` repeats for all eight entries.
- If no name matches, `SR 2,2` sets the scale number to zero.
- `CI2 LA 2,240(2)` adds 240 so scale 0-8 fits in a byte with a zoned-decimal sign nibble; `STC 2,CURSC` stores the byte; `BR 11` returns.

### `SAVEIT`

- `ST 10,LNK1` saves the caller link.
- `CLI HAVRES,C'Y'` checks that a melody is displayed; `BNE SVNONE` reports when there is nothing to save.
- `BAL 11,CURINFO` extracts scale, tempo, and note count.
- `MVC SAVCNT,=F'0'` initializes the saved-record count; `LA 3,SVCNTD` / `ST 3,EODRET` arrange for end-of-file to continue at `SVCNTD`.
- `OPEN (SAVI,INPUT)` opens saved records. `SVCNT GET SAVI` reads one; `L 2,SAVCNT`, `LA 2,1(2)`, and `ST 2,SAVCNT` increment the count; `B SVCNT` repeats until EOD.
- `SVCNTD CLOSE (SAVI)` closes the input file; `OPEN (SAVO,OUTPUT)` opens the output file.
- `MVC REC,BLANKS` clears a record; `L 2,SAVCNT` loads the old count; `LA 2,1(2)` chooses the next ID; `CVD 2,TMPD` converts it to packed decimal; `UNPK REC(3),TMPD+6(2)` places three display digits in the record; `OI REC+2,X'F0'` sets the final zoned-decimal sign nibble to a display digit.
- `MVC REC+3(1),CURSC` stores scale; `MVC REC+4(3),CURTM` stores tempo; `MVC REC+7(2),CURLEN` stores note count; `MVC REC+9(64),RESN` stores 16 four-byte note descriptions; `PUT SAVO,REC` writes the record.
- `CLOSE (SAVO)` closes output; `MVC MSG,MSGSAV` sets the saved message; `MVC MSG+10(3),REC` inserts the generated ID; `B SVEND` skips the no-result path.
- `SVNONE MVC MSG,MSGNOS` displays the no-melody message.
- `SVEND L 10,LNK1` restores the link; `BR 10` returns.

### `LISTIT`

- `ST 10,LNK1` saves the caller link; `MVC NSAV,=F'0'` clears the number of retained records.
- `LA 3,LSDONE` / `ST 3,EODRET` set end-of-file continuation; `OPEN (SAVI,INPUT)` opens the saved file.
- `LS1 GET SAVI` reads a record; `L 2,NSAV` loads the number retained; `C 2,=F'10'` compares to capacity; `BL LS3` skips shifting while fewer than ten records are held.
- Once full, `LA 4,SAVEDT` points to the first slot; `LA 5,9` sets nine moves; `LS2 MVC 0(80,4),80(4)` shifts each later record one slot toward the front; `LA 4,80(4)` advances the target; `BCT 5,LS2` repeats nine times.
- `LA 2,9` and `ST 2,NSAV` set the count to nine before adding the newly read record.
- `LS3 MH 2,=H'80'` calculates the destination offset; `LA 3,SAVEDT(2)` points to the free slot; `MVC 0(80,3),0(1)` copies the current record.
- `L 2,NSAV`, `LA 2,1(2)`, and `ST 2,NSAV` increment retained count; `B LS1` reads the next record.
- `LSDONE CLOSE (SAVI)` closes at end-of-file; `MVC MSG,MSGLST` prompts for an ID; `MVC LDV,=C'   '` clears the load field; `L 10,LNK1` and `BR 10` return.

### `LOADIT`

- `ST 10,LNK1` preserves the link; `LA 5,LDV` points to the requested ID; `BAL 11,NORM3` validates and normalizes it; `LTR 15,15` / `BNZ LDBAD` rejects nonnumeric input.
- `L 7,NSAV` gets the available entry count; `LTR 7,7` / `BZ LDBAD` rejects an empty list; `LA 8,SAVEDT` starts searching.
- `LD1 CLC 0(3,8),NORMV` compares the saved three-digit ID; `BE LDOK` selects a match; `LA 8,80(8)` advances one record; `BCT 7,LD1` searches the remaining records.
- `LDBAD MVC MSG,MSGNOL` reports an unknown ID; `B LDEND` skips loading.
- `LDOK MVC RES1,BLANKS` clears the first displayed result; `MVC RES1(17),=C' MELODY68 SCALE: '` writes its prefix.
- `SR 2,2`, `IC 2,3(8)`, and `N 2,=F'15'` extract the stored scale; `BZ LD2` skips name insertion for scale zero.
- `BCTR 2,0`, `MH 2,=H'16'`, and `LA 3,SCNAMES(2)` locate the scale name; `MVC RES1+17(16),0(3)` copies it.
- `LD2 MVC RES2,BLANKS` clears the second result; `MVC RES2(22),=C' NOTES: nn  TEMPO: ttt'` writes its label; `MVC RES2+8(2),7(8)` inserts count; `MVC RES2+19(3),4(8)` inserts tempo.
- `MVC RESN,BLANKS` clears note storage; `MVC RESN(64),9(8)` copies the saved notes.
- `MVC SCV,3(8)`, `MVC NTV,7(8)`, and `MVC TMV,4(8)` populate the screen input fields from the record; `BAL 11,STRIP0` converts defaults to their display form.
- `MVI HAVRES,C'Y'` marks a result available; `MVI VIEW,C'M'` switches to the main panel; `MVC MSG,MSGLD` loads the loaded-message template; `MVC MSG+8(3),0(8)` inserts the saved ID.
- `LDEND L 10,LNK1` restores the caller link; `BR 10` returns.

## MIDI generation helpers

### `PUTB`

- `STC 2,0(8)` appends the low byte of `R2` at the MIDI buffer pointer in `R8`.
- `LA 8,1(8)` advances the pointer; `BR 11` returns.

### `PITCHF`

This converts a four-character note description at `R5` into a MIDI pitch in `R2`.

- `LA 3,PLET` points to note letters; `LA 4,PVAL` points to their MIDI base pitches; `LA 1,7` sets the search length.
- `PH1 CLC 0(1,3),0(5)` compares the current note letter with the input letter; `BE PH2` stops on a match.
- `LA 3,1(3)` and `LA 4,1(4)` advance letter and pitch pointers; `BCT 1,PH1` searches all seven letters.
- If no letter matched, `LA 4,PVAL` falls back to C's base pitch.
- `PH2 SR 2,2` clears the output; `IC 2,0(4)` loads the base pitch.
- `SR 0,0` clears `R0`; `IC 0,2(5)` loads the encoded octave; `N 0,=F'15'` keeps its low nibble.
- `SH 0,=H'4'` adjusts the encoded octave convention; `MH 0,=H'12'` converts octave to semitones; `AR 2,0` adds those semitones to the base pitch.
- `CLI 1(5),C'#'` checks the accidental; `BNE PH3` skips non-sharps; `LA 2,1(2)` raises pitch by one for a sharp.
- `PH3 BR 11` returns the pitch.

### `MIDIEXP`

- `ST 10,LNK1` saves the caller link; `CLI HAVRES,C'Y'` checks for a displayed melody; `BNE MXNONE` reports no melody if absent.
- `BAL 11,CURINFO` obtains the melody's note count, tempo, and scale metadata.
- `PACK TMPD,CURLEN` and `CVB 2,TMPD` convert note count to binary; `ST 2,NCNT` saves it.
- `PACK TMPD,CURTM` and `CVB 2,TMPD` convert tempo; `LTR 2,2` / `BNZ MX0` keep a nonzero tempo; `LA 2,120` supplies the default 120 BPM otherwise; `MX0 ST 2,BPM` stores tempo.
- `LA 8,MBUF` points to the MIDI buffer; `MVC 0(14,8),MTHD` writes the 14-byte `MThd` header; `LA 8,14(8)` advances.
- `MVC 0(4,8),MTRK` writes the `MTrk` chunk ID; `MVC 4(3,8),=X'000000'` reserves three bytes for track length.
- `L 2,NCNT`, `MH 2,=H'9'`, and `AH 2,=H'11'` calculate track length for each note plus fixed events; `STC 2,7(8)` stores its low byte in the chunk header.
- `LA 8,8(8)` advances to the track events; `MVC 0(4,8),=X'00FF5103'` writes zero delta-time and the Set Tempo meta-event prefix; `LA 8,4(8)` advances past it.
- `L 3,=F'60000000'` loads the million-microseconds-per-minute scale factor; `SR 2,2` clears the high half of the dividend; `D 2,BPM` divides the 64-bit value in `R2:R3` by tempo. The quotient is returned in `R2` and the remainder in `R3`.
- As written, `LR 2,3`, `SRL 2,16`, and `BAL 11,PUTB` copy and append the remainder in `R3` as the first tempo byte. The following `LR 2,3`, `SRL 2,8`, and `BAL` again copy that same remainder for the second byte; the final `LR 2,3` and `BAL` append it a third time. These instructions do not use the quotient in `R2`.
- `L 7,NCNT` sets the note loop count; `LA 5,RESN` points at note descriptions.
- `MXN SR 2,2` emits a zero delta-time before each note-on; `LA 2,144` and `BAL 11,PUTB` emit MIDI status `0x90` (channel 1 note-on).
- `BAL 11,PITCHF` computes the note; `ST 2,PCH` preserves pitch; `BAL 11,PUTB` writes it; `LA 2,100` and `BAL` write velocity 100.
- `LA 3,DURT` points to the duration-letter table; `LA 4,VQT` points to matching variable-length quarter-tick values; `LA 1,4` sets the four-entry search count.
- `DL1 CLC 0(1,3),3(5)` compares each duration code with the note's fourth character; `BE DL2` stops on a match; `LA 3,1(3)` advances duration pointer; `LA 4,2(4)` advances two bytes in the corresponding tick encoding; `BCT 1,DL1` searches all four.
- If no duration matches, `LA 4,VQT+4` chooses the fallback duration entry.
- `DL2 SR 2,2` clears a register; `IC 2,0(4)` loads the first encoded delta byte; `BAL 11,PUTB` appends it; the next `SR`/`IC 2,1(4)`/`BAL` appends the second.
- `LA 2,128` and `BAL` emit status `0x80` (channel 1 note-off); `L 2,PCH` and `BAL` append the pitch; `SR 2,2` and `BAL` append zero release velocity.
- `LA 5,4(5)` advances to the next four-character note; `BCT 7,MXN` repeats for every note.
- `MVC 0(4,8),=X'00FF2F00'` writes the end-of-track meta-event; `LA 8,4(8)` advances past it.
- `LA 2,MBUF`, `SR 8,2`, and `ST 8,MLEN` calculate/store the number of bytes produced.
- `OPEN (MIDO,OUTPUT)` opens the text-form MIDI output dataset.
- `MVC REC,BLANKS` clears a record; `MVC REC(12),=C' *MIDI-BEGIN'` writes the begin marker; `PUT MIDO,REC` writes it.
- `LA 8,MBUF` resets the byte pointer; `L 7,MLEN` loads remaining binary length.
- `HX1 LTR 7,7` tests remaining bytes; `BZ HXDONE` ends conversion when zero.
- `LA 3,32` chooses a maximum of 32 bytes per text record; `CR 7,3` compares remaining bytes; `BNL HX2` uses 32 when enough remain; `LR 3,7` uses the shorter remainder otherwise.
- `HX2 MVC REC,BLANKS` clears a line; `LA 4,REC+1` points to its hex payload, leaving a leading blank; `LR 5,3` sets bytes to encode; `SR 7,3` subtracts them from the remaining count.
- `HX3 SR 2,2` clears the byte register; `IC 2,0(8)` loads a MIDI byte; `LR 1,2` preserves it; `SRL 1,4` extracts its high nibble; `IC 0,HEXT(1)` looks up the hex character; `STC 0,0(4)` writes it.
- `N 2,=F'15'` extracts the low nibble; `IC 0,HEXT(2)` looks up its character; `STC 0,1(4)` writes it.
- `LA 4,2(4)` advances two output characters; `LA 8,1(8)` advances one binary byte; `BCT 5,HX3` encodes the selected chunk.
- `PUT MIDO,REC` writes the hex line; `B HX1` processes the next chunk.
- `HXDONE MVC REC,BLANKS` clears the final record; `MVC REC(10),=C' *MIDI-END'` places the end marker; `PUT MIDO,REC` writes it; `CLOSE (MIDO)` closes the file.
- `MVC MSG,MSGMX` loads the success message; `L 2,MLEN` gets byte count; `CVD 2,TMPD` converts it to display decimal; `UNPK MSG+16(3),TMPD+6(2)` inserts three digits; `OI MSG+18,X'F0'` makes the final digit printable.
- `B MXEND` skips the no-result branch.
- `MXNONE MVC MSG,MSGNOM` displays the no-melody message.
- `MXEND L 10,LNK1` restores the link; `BR 10` returns.

## End-of-data and screen shutdown

### EODAD routines

For each DCB with an `EODAD`, MVS branches here when no more records are available.

- `RJEOD L 15,EODRET` loads the selected continuation address; `BR 15` branches there.
- `OUEOD` performs the same indirect continuation for the output-result DCB.
- `SVEOD` performs the same indirect continuation for the saved-melody DCB.

### `ENDSCR`

- `MVC BUF(2),=X'F5C3'` begins an Erase/Write with its write-control byte.
- `MVC BUF+2(7),ERASE` appends the screen-clearing SBA/Repeat-to-Address sequence.
- `LA 2,BUF` sets the buffer address; `LA 3,9` sets the stream length.
- `TPUT (2),(3),FULLSCR` erases the panel; `TPUT ENDMSG,L'ENDMSG` displays the short exit message.
- `BR 10` returns.

## Constants, tables, and file control blocks

Every label in this section defines data or assembly-time values used by the preceding routines.

| Label/source definition | Meaning |
|---|---|
| `WAITV DC F'100'` | One-second interval for `STIMER`, in hundredths of a second. |
| `BLANKS DC CL80' '` | An 80-space record used to initialize output records. |
| `T2 DC C'//RUN ...'` | JCL text for the `MELODY68` execution step. |
| `T3 DC C'//STEPLIB DD DSN='` | Prefix for the load-library DD card. |
| `T4 DC C'//SYSOUT DD DSN='` | Prefix for the per-user result DD card. |
| `T5 DC C'//SYSIN DD *'` | Prefix for inline generator parameters. |
| `MSG0` | Initial instruction/status prompt. |
| `MSGSUB` | Status shown while the generated job is being submitted. |
| `MSGWAIT` | Status shown during result polling. |
| `MSGDONE` | Status shown after a result becomes available. |
| `MSGTMO` | Status shown if the result is not ready after 20 polls. |
| `MSGB1`, `MSGB2`, `MSGB3` | Scale, note-count, and tempo validation errors. |
| `MSGSAV` | Saved-ID message template. |
| `MSGNOS` | No-current-melody save message. |
| `MSGLST` | Prompt displayed on the saved-list screen. |
| `MSGNOL` | Invalid/missing saved-ID message. |
| `MSGMX` | MIDI export success template, including a three-digit byte-count insertion point. |
| `MSGNOM` | No-current-melody export message. |
| `HEXT DC C'0123456789ABCDEF'` | Lookup table mapping values 0-15 to uppercase hexadecimal characters. |
| `PLET DC C'CDEFGAB'` | Natural note letters in the same order as the pitch table. |
| `PVAL DC AL1(60,62,64,65,67,69,71)` | One-byte MIDI base pitch for each letter C through B. |
| `DURT DC C'WHQE'` | Duration symbols searched by `MIDIEXP`: whole, half, quarter, and eighth. |
| `VQT DC X'8F00874083608170'` | Two-byte variable-length delta-time encodings corresponding to `DURT`. |
| `MTHD DC X'4D5468640000000600000001'` | First 12 bytes of the Standard MIDI `MThd` header: chunk ID, length, format, and one track. |
| Following `DC X'01E0'` | Two-byte division/resolution value, 480 ticks per quarter note; this completes the 14-byte header copied from `MTHD`. |
| `MTRK DC X'4D54726B'` | ASCII `MTrk` track-chunk identifier. |
| `MSGLD DC CL70'LOADED #nnn'` | Loaded-ID message template. |
| `ENDMSG DC C'MELSCR ENDED'` | Text displayed after clearing the panel. |
| `ERASE DC X'1140403C404000'` | Seven-byte 3270 stream fragment: SBA to address zero, Repeat-to-Address, screen-end address, and null fill byte. |
| `SCPOS EQU (11-1)*80+15-1` | Zero-based screen buffer address of the scale field. |
| `NTPOS EQU (12-1)*80+15-1` | Address of the note field. |
| `TMPOS EQU (13-1)*80+15-1` | Address of the tempo field. |
| `LDPOS EQU (16-1)*80+15-1` | Address of the saved-ID field. |
| First `SCNAMES DC CL16'C MAJOR'` | 16-byte padded name for scale 1. |
| Subsequent seven `DC CL16` entries | Padded names for scales 2 through 8, in order: G major, A natural minor, C pentatonic, D dorian, E minor, A minor pentatonic, E minor pentatonic. Each row occupies 16 bytes, which is why scale lookup multiplies the index by 16. |
| Four `TAB DC X'...'` statements | 64-byte 3270 6-bit-to-terminal address translation table. `INIT` reverses it into `REV`; `PUTSBA` uses it to encode screen addresses. |

### DCBs

- `RJO DCB ...` defines output access to DD `RUNJCL`. `DSORG=PS` selects a sequential data set, `MACRF=PM` uses move-mode output, and `RECFM=FB,LRECL=80,BLKSIZE=800` specifies fixed 80-byte records in 800-byte blocks. The trailing `X` continues the DCB operands on the next source line.
- The continuation `BLKSIZE=800` completes `RJO`'s DCB definition.
- `RJI DCB ...` defines move-mode input for the same `RUNJCL` DD and the same sequential fixed-block format; `EODAD=RJEOD` routes end-of-file to the indirect continuation routine.
- Its continued `BLKSIZE=800` completes the input DCB.
- `OUO DCB ...` defines move-mode output to DD `OUT`, using the same sequential FB 80 / 800-byte block format.
- Its continued `BLKSIZE=800` completes the definition.
- `OUI DCB ...` defines move-mode input from `OUT`; `EODAD=OUEOD` handles end-of-file.
- Its continued `BLKSIZE=800` completes the definition.
- `SAVO DCB ...` defines output to the saved-melody DD `SAVED`, in fixed 80-byte records.
- Its continued `BLKSIZE=800` completes the definition.
- `MIDO DCB ...` defines output to DD `MIDI`, also fixed 80-byte records; each record carries a marker or up to 32 MIDI bytes rendered as 64 hex characters.
- Its continued `BLKSIZE=800` completes the definition.
- `SAVI DCB ...` defines input from `SAVED`; `EODAD=SVEOD` ends the record-reading loops.
- Its continued `BLKSIZE=800` completes the definition.
- `LTORG` emits any pending literal constants at this point in the control section.
- `END MELSCR` ends the assembly and identifies `MELSCR` as the entry point.
