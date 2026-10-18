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
| `SFUNC`..`SRES2` | `DS` block | `MELSAV` parameter area (`SAV-AREA`): function, return code, ID, scale, tempo, length, notes, record, list row and two result lines. |
| `NMTM`..`NMHEX` | `DS` block | `MELMID` parameter area (`MID-AREA`): tempo, note count, notes, file size, line count and the hex text. |
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
- `BL2 MVC SREC,0(8)` and `CALLSAV R` let `MELSAV` format one list row (`#nnn`, scale name, tempo, note count); `MVC TL,SLINE` takes the 44-byte row.
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

## Input validation: `VALID` and `MELVAL`

Validation lives in the COBOL-68 subprogram `MELVAL` ([`melval.cbl`](../melody/source/cobol/melval.cbl)), so the rules read as COBOL. `VALID` only calls it.

- `INIT` does `LOAD EP=MELVAL`; `FINISH` does `DELETE EP=MELVAL`.
- `WORK` holds `SCV, NTV, TMV, VRC, SC1, NN, TM3` contiguously. That block is the 13-byte `VAL-AREA` passed as the single parameter (in: scale, notes, tempo; out: return code, scale digit, note count, tempo).
- `VALID` sets the last-parameter bit in `VPLIST`, points `R1` at it and `BALR 14,15` to `MELVAL`.
- `VRC` is `0` for success (`VALOK`=`Y`, `MSGSUB` shown) or `1`, `2`, `3` for a bad scale, notes or tempo (`MSGB1`, `MSGB2`, `MSGB3`).
- Rules: scale blank or 0-8; notes blank, 0, or 8-16 (`8` and `08` both fine); tempo blank, 0, or 40-240. Blank scale/notes/tempo mean random/default.
- `MELVAL` ends with `GOBACK`; COBOL F rejects `EXIT PROGRAM`.

## Saved melodies: `MELSAV`

Saved-melody rules live in the COBOL-68 subprogram `MELSAV` ([`melsav.cbl`](../melody/source/cobol/melsav.cbl)). `MELSCR` keeps the file I/O (`DD SAVED`), the 10-record window `SAVEDT` and the screen; `MELSAV` only builds and takes apart records in memory.

- `INIT` does `LOAD EP=MELSAV` (address in `MELSEP`); `FINISH` does `DELETE EP=MELSAV`.
- `WORK` holds `SFUNC, SRC, SNUM, SSC, STM, SLEN, SNOTES, SREC, SLINE, SRES1, SRES2` contiguously: the 359-byte `SAV-AREA`.
- The `CALLSAV` macro sets `SFUNC`, builds the one-entry parameter list with the last-parameter bit, and does `BALR 14,15`. Registers 2-13 survive the call.
- Functions: `N` normalize a typed ID (`SRC` 0 ok, 1 not numeric); `C` read scale/tempo/length from the shown result; `B` build a save record; `R` format a list row; `D` open a record into the result lines.
- The scale names are a table in `MELSAV` only. `MELSAV` ends with `GOBACK`.

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

- `MVC SRES1,RES1` and `MVC SRES2,RES2` hand the shown result to `MELSAV`; `CALLSAV C` returns the scale digit (`SSC`, 0 if unknown), tempo (`STM`) and note count (`SLEN`).
- `MVC CURSC,SSC`, `MVC CURLEN,SLEN` and `MVC CURTM,STM` keep them for `SAVEIT` and `MIDIEXP`; `BR 11` returns.

### `SAVEIT`

- `ST 10,LNK1` saves the caller link.
- `CLI HAVRES,C'Y'` checks that a melody is displayed; `BNE SVNONE` reports when there is nothing to save.
- `BAL 11,CURINFO` extracts scale, tempo, and note count.
- `MVC SAVCNT,=F'0'` initializes the saved-record count; `LA 3,SVCNTD` / `ST 3,EODRET` arrange for end-of-file to continue at `SVCNTD`.
- `OPEN (SAVI,INPUT)` opens saved records. `SVCNT GET SAVI` reads one; `L 2,SAVCNT`, `LA 2,1(2)`, and `ST 2,SAVCNT` increment the count; `B SVCNT` repeats until EOD.
- `SVCNTD CLOSE (SAVI)` closes the input file; `OPEN (SAVO,OUTPUT)` opens the output file.
- `L 2,SAVCNT` loads the old count; `LA 2,1(2)` chooses the next ID; `CVD 2,TMPD` converts it to packed decimal; `UNPK SNUM,TMPD+6(2)` places three display digits in `SNUM`; `OI SNUM+2,X'F0'` sets the final zoned-decimal sign nibble to a display digit.
- `MVC SNOTES,RESN` copies the 16 four-byte note descriptions; `CALLSAV B` lets `MELSAV` build the 80-byte record from `SNUM`, `SSC`, `STM`, `SLEN` and `SNOTES` (the last three were set by `CURINFO`); `MVC REC,SREC` and `PUT SAVO,REC` write it.
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

- `ST 10,LNK1` preserves the link; `MVC SNUM,LDV` and `CALLSAV N` ask `MELSAV` to normalize the typed ID; `CLI SRC,C'0'` / `BNE LDBAD` rejects a nonnumeric one.
- `L 7,NSAV` gets the available entry count; `LTR 7,7` / `BZ LDBAD` rejects an empty list; `LA 8,SAVEDT` starts searching.
- `LD1 CLC 0(3,8),SNUM` compares the saved three-digit ID; `BE LDOK` selects a match; `LA 8,80(8)` advances one record; `BCT 7,LD1` searches the remaining records.
- `LDBAD MVC MSG,MSGNOL` reports an unknown ID; `B LDEND` skips loading.
- `LDOK MVC SREC,0(8)` and `CALLSAV D` let `MELSAV` take the record apart. It returns the scale digit, tempo, note count, notes and the two result lines (`SRES1`, `SRES2`).
- `MVC RES1,SRES1`, `MVC RES2,SRES2` and `MVC RESN(64),SNOTES` show them as the current melody; `MVC SCV,SSC`, `MVC NTV,SLEN` and `MVC TMV,STM` fill the screen input fields; `BAL 11,STRIP0` converts defaults to their display form.
- `MVI HAVRES,C'Y'` marks a result available; `MVI VIEW,C'M'` switches to the main panel; `MVC MSG,MSGLD` loads the loaded-message template; `MVC MSG+8(3),SNUM` inserts the saved ID.
- `LDEND L 10,LNK1` restores the caller link; `BR 10` returns.

## MIDI export: `MIDIEXP` and `MELMID`

The Standard MIDI File is built by the COBOL-68 subprogram `MELMID` ([`melmid.cbl`](../melody/source/cobol/melmid.cbl)). It returns the whole file as hex text, so no binary bytes are handled in assembler. `MIDIEXP` only passes the data in and writes the records.

- `INIT` does `LOAD EP=MELMID` (address in `MELMEP`); `FINISH` does `DELETE EP=MELMID`.
- `WORK` holds `NMTM, NMCNT, NMNOTES, NMBYTES, NMLINES, NMHEX` contiguously: the 457-byte `MID-AREA` (in: tempo, note count, notes; out: file size, number of lines, hex text).
- `CLI HAVRES,C'Y'` / `BNE MXNONE` reports when there is nothing to export; `BAL 11,CURINFO` gets the tempo and note count of the shown melody.
- `MVC NMTM,CURTM`, `MVC NMCNT,CURLEN` and `MVC NMNOTES,RESN` fill the input; the call sets the last-parameter bit in `VPLIST`, loads `R1` and does `BALR 14,15`.
- `OPEN (MIDO,OUTPUT)` opens `DD MIDI`; the first record is ` *MIDI-BEGIN`.
- `PACK TMPD,NMLINES` / `CVB 7,TMPD` give the line count. `HX1` writes each 64-character slice of `NMHEX` after one blank (`MVC REC+1(64),0(8)`, `LA 8,64(8)`, `BCT 7,HX1`).
- The last record is ` *MIDI-END`; `CLOSE (MIDO)`; `MVC MSG,MSGMX` and `MVC MSG+16(3),NMBYTES` put the byte count in the message.
- `MXNONE MVC MSG,MSGNOM` shows the nothing-to-export message; `MXEND L 10,LNK1` / `BR 10` returns.

`MELMID` writes the file in this order: header chunk (format 0, one track, 480 ticks per quarter note); track header with the length `9 * notes + 11`; tempo event (`60000000 / BPM` microseconds, 0 or blank = 120); for each note a note-on (velocity 100), a two-byte delay (W 1920, H 960, Q 480, E 240 ticks, anything else Q) and a note-off; end of track. Pitch is C4 = 60, 12 per octave, `#` adds one. Output is limited to 16 notes (177 bytes, six hex lines).

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
| `MSGLD DC CL70'LOADED #nnn'` | Loaded-ID message template. |
| `ENDMSG DC C'MELSCR ENDED'` | Text displayed after clearing the panel. |
| `ERASE DC X'1140403C404000'` | Seven-byte 3270 stream fragment: SBA to address zero, Repeat-to-Address, screen-end address, and null fill byte. |
| `SCPOS EQU (11-1)*80+15-1` | Zero-based screen buffer address of the scale field. |
| `NTPOS EQU (12-1)*80+15-1` | Address of the note field. |
| `TMPOS EQU (13-1)*80+15-1` | Address of the tempo field. |
| `LDPOS EQU (16-1)*80+15-1` | Address of the saved-ID field. |
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
