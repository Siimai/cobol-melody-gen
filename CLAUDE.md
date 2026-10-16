# CLAUDE.md

## Language standard

This project targets **COBOL-85 plus the 1989 amendment (Intrinsic Function Amendment, "COBOL-89")**.

- Write standard COBOL-85 only. Do not use COBOL 2002/2014 features (e.g. free-form-only source, `FUNCTION` calls beyond the 1989 intrinsic set, object-oriented COBOL, `EXIT PERFORM`/inline-only constructs that postdate 85, user-defined functions, `TYPEDEF`, `FLOAT-SHORT` etc.) or GnuCOBOL-specific extensions.
- Intrinsic functions are allowed only if they are in the 1989 amendment (e.g. `MOD`, `INTEGER`, `INTEGER-PART`, `MAX`, `MIN`, `LENGTH`, `RANDOM`, `CURRENT-DATE`, `NUMVAL`, `ABS`, `SQRT`, `REM`).
- Compile with `cobc -std=cobol85` where possible so the compiler flags non-conforming code. The Makefile currently uses `-ffold-copy=LOWER` only; add `-std=cobol85` when touching build flags, and fix any resulting warnings rather than relaxing the standard.
- Compiler is GnuCOBOL (`cobc`), built via `make`. Tests: `tests/smoke.sh`.

## Mainframe (Hercules / TK4-)

A Hercules emulator running TK4- (MVS 3.8j) listens on `localhost:3270`. `s3270` is installed for scripted access, e.g. `s3270` with `Connect(localhost:3270)`.

Default TK4- TSO accounts (local emulator only, not real credentials):

| User    | Password | Notes                  |
|---------|----------|------------------------|
| HERC01  | <admin-pw>   | Fully authorized, full access to RAKF users/profiles tables |
| HERC02  | <admin-pw>   | Fully authorized, no access to RAKF users/profiles tables   |
| HERC03  | <user-pw>   | Regular user                                                |
| HERC04  | <user-pw>   | Regular user                                                |
| IBMUSER | <ibmuser-pw>  | Fully authorized, no RAKF access; recovery use only         |

These come from the TK4- documentation. Verified against this instance: HERC01/<admin-pw> and HERC02/<admin-pw> log on to TSO. HERC03 and HERC04 also log on. IBMUSER is untested. Always send `LOGOFF` before disconnecting; otherwise the userid stays "IN USE" until cancelled from the MVS console (`/C U=<userid>`, web console at `http://localhost:8038`).

### Mainframe layout and tooling

Everything for the mainframe lives under `mainframe/` and is separate from the GnuCOBOL build.

- `melody68.cob` is the COBOL-68 program, `melody.clist` the line-mode menu, `asm/melscr.asm` the full-screen panel, `melpanel.clist` the panel wrapper.
- `jcl/*.jcl` are job templates with `@USER@` / `@PASS@` placeholders. `mfsubmit.sh JOBFILE [WAIT]` fills them in (`MFUSER` / `MFPASS`, default HERC03) and sends the job to the card reader on port 3505. It then prints the new output from `~/opt/tk4-_v1.00_current/prt/prt00e.txt`.
- `jcl/melscr.jcl` and `jcl/install*.jcl` embed copies of their source. Regenerate them after changing the source, or they drift apart.
- Never commit real credentials. Use the placeholders.

### Best practices learned

**Sessions**
- Always log off. Use a `try/finally` that backs out with PF3 and sends `LOGOFF`, then confirm it in `log/hardcopy.log` (`IS PURGED`). Do not trust a screen scrape, because leftover text fools it.
- Check for `IN USE` before sending a password. A rejected logon otherwise swallows the password as a command.
- Test with a user the human is not using (HERC02 or HERC04), and tell them when a test session is left stuck.
- After the logon banner, press Enter twice, then PF3 out of the TSO applications menu to reach `READY`. `TSOAPPLS` brings the menu back.
- `s3270` over a pipe needs the response read after each action (read until `ok`/`error`). Do not fire commands blindly with `sleep`.

**Datasets and security (RAKF)**
- A regular user may only create datasets under their own userid. The log shows denials as `RAKF000A`.
- Jobs from the card reader run as anonymous `PROD`. To touch a user's datasets add `USER=...,PASSWORD=...` on the job card, split over two lines.
- Jobs submitted with TSO `SUBMIT` run as the submitter (the exit adds `USER=` for you). It truncates the original job card to about 50 characters, so keep it short. `NOTIFY=` on a long card gets cut off.
- `HERC03` is a regular user; `HERC02` is fully authorized. A jobname used with `OUTPUT`/`STATUS` must start with the userid.

**TSO and JCL quirks of MVS 3.8j**
- `ALLOCATE` has no `DSORG`, `RECFM`, `LRECL` or `BLKSIZE`. Use `ATTRIB name RECFM(F B) LRECL(80) BLKSIZE(3120)` and `ALLOC DATASET(...) USING(name)`. Use `DATASET(`, not `DA(`, and an alphabetic attribute-list name. In practice allocate datasets with an `IEFBR14` job and JCL `DCB=` instead.
- `&SYSUID` is empty in batch TMP, so test CLISTs interactively or hard-code the user. CLIST `READ` does not take answers from `SYSTSIN` in batch. End a variable with a period when it sits next to other text (`&SYSUID.R`, `&SYSUID..MELODY`).
- `/*` starts a CLIST comment, so build it from `&STR(/)` plus `*`. Use `DD DATA,DLM=ZZ` when in-stream data contains `//` or `/*`.
- JCL lines must stay within column 72, and a continued job card needs the comma at the end of the first line.
- Console messages from JES2 (`$HASP165` NOTIFY) are not shown while a CLIST waits at `READ`. Poll for a result instead of waiting for a message.
- `P` in `QUEUE` prints and purges the job output. Use `OUTPUT jobname CLASS(x) PRINT(*) KEEP` to read it without losing it. Output on a printed class goes to `prt/prt00e.txt`, which is the easiest place to read it from the host.

**COBOL on the mainframe is COBOL-68 (IKFCBL00, COBOL F)**
- Fixed format, upper case, columns 8-72. No intrinsic functions, no `END-xxx`, no inline `PERFORM`, no `EVALUATE`, no reference modification, no `STRING`/`INSPECT`. Use period-terminated sentences, `PERFORM paragraph`, nested `IF ... ELSE`.
- `77` items must come before `01` items. `VALUE` literals must not exceed their `PIC`.
- Time comes from the `TIME-OF-DAY` special register (`ACCEPT ... FROM TIME` is not defined). Random numbers come from a hand-written 16-bit LCG with `COMPUTE` truncation.
- A one-card `ACCEPT` reads `SYSIN`, so parameterise the program through a card.
- Compile once with `COBUCL` into `<user>.MELODY.LOAD` and run with `EXEC PGM=` and `STEPLIB`. Write program output to a dataset (`SYSOUT DD DSN=...,DISP=SHR`), not to a held spool class, then read it from TSO or the host.

**Full-screen (ISPF-style) panels — build every screen this way**
- There is no ISPF dialog manager. Write the front end in assembler (`IFOX00`, proc `ASMFCL`) with `TPUT (a),(l),FULLSCR` to draw and `TGET buf,len,ASIS` to read. COBOL stays the engine and the panel is only the front end.
- Draw the whole screen in one data stream: command `X'F5'`, WCC `X'C3'`, then `SBA 0` + `RA` to address 0 with `X'00'` to blank the screen (the erase command alone left old text), then the fields. Redraw the entire screen after every input, which gives in-place updates instead of scrolling.
- Use a 6-bit address table for `SBA`, a reverse table to decode inbound addresses, `SF` with attribute `X'60'` (protected), `X'E8'` (protected bright), `X'C8'` (unprotected bright), and end each input field with a protected `SF`. Place the cursor with `IC` on the first field. Handle the AID byte (`X'7D'` Enter, `X'F3'` PF3, anything else just redraws).
- Only modified fields come back, as `SBA` + data. Match them by buffer address and keep the previous value for fields that were not sent.
- Keep a status line (row 22) for messages and a key legend (row 24). Validate on Enter and show errors there, in place.
- Under a 4K base-register limit, keep working storage in a `GETMAIN` area addressed through R13 (`DSECT`), with save-area chaining. Do not put a macro call on a labelled line (the label is not defined), and use `&L.(6)` not `&L(6)` inside macros.
- Slow work (job submit) is done by a wrapper CLIST: the panel returns RC 4, the CLIST `SUBMIT`s, then calls the panel in a wait mode that polls the result dataset once a second (`STIMER WAIT,BINTVL`) and shows it on the same screen.
- A dataset that was only allocated (for example by `IEFBR14`) and never written returns one bogus record on its first read. Initialise datasets that a program reads before writing with `IEBGENER` from an empty `SYSUT1` (see `jcl/init-saved.jcl`; rerunning it deletes the data).
- A label on a macro call line is not defined by the macro. Put a `DS 0H` on its own line. Past 4K of code, load a second base register (`LA 9,4095(12)` / `LA 9,1(9)` / `USING name,12,9`) and keep loop counters off it.
- Input fields keep their old value when redrawn, so a shorter number typed over a longer one leaves remnants. Test with `EraseEOF` before typing, as a user would.
- Test every screen over `s3270`: read the screen after each key (`Ascii`), type with `String`/`Tab`/`Enter`/`PF(n)`, and always log off.
