# CLAUDE.md

## Language standard

This project targets **COBOL-85 plus the 1989 amendment (Intrinsic Function Amendment, "COBOL-89")**.

- Write standard COBOL-85 only. Do not use COBOL 2002/2014 features (e.g. free-form-only source, `FUNCTION` calls beyond the 1989 intrinsic set, object-oriented COBOL, `EXIT PERFORM`/inline-only constructs that postdate 85, user-defined functions, `TYPEDEF`, `FLOAT-SHORT` etc.) or GnuCOBOL-specific extensions.
- Intrinsic functions are allowed only if they are in the 1989 amendment (e.g. `MOD`, `INTEGER`, `INTEGER-PART`, `MAX`, `MIN`, `LENGTH`, `RANDOM`, `CURRENT-DATE`, `NUMVAL`, `ABS`, `SQRT`, `REM`).
- Compile with `cobc -std=cobol85` where possible so the compiler flags non-conforming code. The Makefile currently uses `-ffold-copy=LOWER` only; add `-std=cobol85` when touching build flags, and fix any resulting warnings rather than relaxing the standard.
- Compiler is GnuCOBOL (`cobc`), built via `make`. Tests: `tests/smoke.sh`.

## Mainframe (Hercules / TK4-)

A Hercules emulator running TK4- (MVS 3.8j) listens on `localhost:3270`. `s3270` is installed for scripted access, e.g. `s3270` with `Connect(localhost:3270)`.

**Host address from the dev container:** the emulator runs on the Docker host, so inside the container `localhost` does not reach it. Use the Docker bridge gateway `172.17.0.1` instead (`Connect(172.17.0.1:3270)`; card reader `172.17.0.1:3505`; web console `http://172.17.0.1:8038`). `host.docker.internal` does not resolve here. Check with `(echo > /dev/tcp/172.17.0.1/3270) && echo open`. On the host itself, `localhost` is correct. The host scripts (`upload.sh`, `midi-from-mvs.sh`) read the emulator host from `MFHOST` (default `localhost`), so run them as `MFHOST=172.17.0.1 mainframe/upload.sh ...` in the container. The container deliberately has no access to the host's `prt` files (it should work like a real mainframe user, over the network only), so a script can send a job but cannot show its output from the container. Read job output and data sets through a TSO session over `s3270` instead (`mainframe/tso-list.py` does that for one data set). The host-side files under `~/opt/tk4-_v1.00_current/` (including `prt/prt00e.txt`) are not visible from the container.

TSO accounts on this emulator: HERC01 and HERC02 (fully authorized; only HERC01 can update the RAKF users/profiles tables), HERC03 and HERC04 (regular users) and IBMUSER (recovery only). Their passwords are the TK4- defaults. They are kept out of git, in the local file `mainframe/.secrets/accounts.md`, which is imported here when it exists:

@mainframe/.secrets/accounts.md

The scripts read `MFUSER`, `MFPASS` and `MFHOST` from the environment, or from `mainframe/.secrets/env` (template: `mainframe/env.example`). Never write a password into a tracked file. Always send `LOGOFF` before disconnecting; otherwise the userid stays "IN USE" until cancelled from the MVS console (`/C U=<userid>`, web console at `http://localhost:8038`).

### Mainframe layout and tooling

Everything for the mainframe lives under `mainframe/` and is separate from the GnuCOBOL build.

- `melody/source/` mirrors the mainframe: the path is the dataset name and the file is the member, so `melody/source/cobol/melody68.cbl` is `MELODY.SOURCE.COBOL(MELODY68)`. The member name is the file name in upper case (the extension is only for editors). The libraries are `cobol` (COBOL-68 program), `asm` (full-screen panel `melscr.asm`), `clist` (`melody`, `melpanel`, `melsetup`) and `cntl` (build and install jobs). `MELODY.LOAD` and the per-user data sets are not in the repo.
- `upload.sh [--dry-run] [PATH...]` sends the tree (or only the given files or directories) to the mainframe with one throwaway job that it builds on the fly. Run it as `MFHOST=172.17.0.1 MFUSER=<admin user> MFPASS=<password> mainframe/upload.sh`; the user needs ALTER on `MELODY.*` (group ADMIN). No source is stored inside any JCL: the jobs in `melody/source/cntl` read it from the libraries (`COB.SYSIN DD DSN=MELODY.SOURCE.COBOL(MELODY68)`) and have a plain job card, so they are run on the mainframe with `SUBMIT 'MELODY.SOURCE.CNTL(SETUP)'` (TSO adds the user ID).
- `tso-list.py 'DATA.SET'` logs on to TSO with `s3270`, prints a data set and always logs off (it refuses to send a password when the user is already logged on). `midi-from-mvs.sh [OUTFILE]` uses it to turn the panel's last PF7 export (`<user>.MELODY.MIDI`, hex text between `*MIDI-BEGIN` and `*MIDI-END`) into a real `.mid` file; needs `s3270` and `python3`, and the user must not be logged on.
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
- A dataset that was only allocated (for example by `IEFBR14`) and never written returns one bogus record on its first read. Initialise datasets that a program reads before writing with `IEBGENER` from an empty `SYSUT1` (`melsetup.clist` does this with `OPENFILE`/`CLOSFILE`).
- A label on a macro call line is not defined by the macro. Put a `DS 0H` on its own line. Past 4K of code, load a second base register (`LA 9,4095(12)` / `LA 9,1(9)` / `USING name,12,9`) and keep loop counters off it.
- Input fields keep their old value when redrawn, so a shorter number typed over a longer one leaves remnants. Test with `EraseEOF` before typing, as a user would.
- MVS cannot hand a binary file to the host. Write binary data (for example MIDI) as hex text between marker records and convert it on the host (`mainframe/midi-from-mvs.sh`, `bytes.fromhex` in Python, because `xxd` is not installed in the container). Check the result against an independent encoder, not just the structure.
- Test every screen over `s3270`: read the screen after each key (`Ascii`), type with `String`/`Tab`/`Enter`/`PF(n)`, and always log off.

**Scripting TSO over `s3270` (lessons from the shared-library work)**
- The logon screen is VTAM, not TSO: press Enter, then send `L HERC02` (not just the userid), then the password at `ENTER CURRENT PASSWORD`. Do not use `Wait(InputField)`: it blocks forever and hangs the script.
- Never type blind. Read the screen before each step and branch on it. The prompts that break scripts are `***` paging, `ENTER NEW MEMBER OR HIT CARRIER RETURN TO REUSE MEMBER-` and the `EDIT`/`INPUT` modes. Do not run `HELP`: it opens a full-screen panel that swallows later commands, including `LOGOFF`.
- The cleanup must check the last screen line: `READY` then `LOGOFF`; `EDIT` then `END NOSAVE`; `INPUT` then a blank Enter. Typing `LOGOFF` into an editor leaves the userid "IN USE". Never run `pkill -f` on a script name from the same shell (it kills your own command).
- Do not log on as a user the human is using (HERC03 here). A killed or hung script leaves its userid "IN USE" until the human cancels it from the web console (`/C U=<userid>`), so use one session per script and keep scripts short.
- To read a long member, `LIST 'dsn(member)' NONUM` and press Enter at each `***`. Dedupe lines per screen. A second listing in the same session also picks up leftover lines from the first, so list one dataset per session before comparing. Compare as sets of (sequence number, text).
- `mainframe/tso-list.py` implements that reading rule: it stitches scrolled screens together by overlap (the screen scrolls, so each page starts with the tail of the previous one), drops the `***`/`READY` lines, and removes the one blank that `LIST` puts in front of every record. Records then match what the program wrote (the MIDI markers were ` *MIDI-BEGIN`, so a match pattern must allow the extra leading blank).

**Editing members in line mode (`EDIT`)**
- For an unnumbered edit (`DATA NONUM`), `INPUT` always appends at the end of the data, whatever `FIND` did before. Edit with `CNTL OLD` instead: lines are numbered (100, 200, ...). Insert with `INPUT 1850 10`, type the line, then a blank Enter. `DELETE n` removes a line.
- Saving over an existing PDS member prompts for the member name. Answer with Enter to reuse the member.
- Work on a scratch copy: `EDIT 'orig' CNTL OLD`, `SAVE 'scratch'`, `END NOSAVE`, then edit the scratch dataset, check it and copy it over the live member. Always keep `.BAK` copies of the originals. Do not trust a check that only matches the lines you typed. Compare the whole member with the backup.

**RAKF (users and profiles)**
- The tables are `SYS1.SECURE.CNTL(USERS)` and `(PROFILES)` and only HERC01 (group `RAKFADM`) can update them. They only take effect after the console commands `/S RAKFUSER` and `/S RAKFPROF`, which only the human can send from the web console. Read the console reply: `USER TABLE UPDATED` / `RAKF PROFILES UPDATED` is success. A failed `RAKFUSER` leaves the old user table in place.
- `USERS` must be sorted by user ID and then by group, or `RAKFUSER` abends with `INPUT DATA INVALID OR OUT OF SEQ`. For a user with two groups, `MELODY` goes before `USER`. Fixed columns: user 1-8, group 10-17, password 19-26, oper flag 28. An 8-character password therefore takes one space before the flag.
- `PROFILES` columns: class 1-8, profile 9-52, id 53-60, access from 61. The entries are sorted too (`MELODY.*` goes between `IPCS` and `RPF`). A specific profile replaces the `DATASET *` default, so repeat the `ADMIN ALTER` line, otherwise the administrators lose their access.
- `DATASET MELODY.*` also covers three-level names such as `MELODY.SOURCE.COBOL` (tested). Replacing members of a PDS needs UPDATE, creating a dataset needs ALTER.
- The shared MELODY libraries are `MELODY.SOURCE.COBOL(MELODY68)` and `MELODY.SOURCE.ASM(MELSCR)`, uploaded by `mainframe/upload.sh`. The group `MELODY` has UPDATE, `ADMIN` has ALTER and everyone else can read. The owner user's password is kept out of git in `mainframe/.secrets/`.

**Installing templates into shared libraries**
- JCL operands must end by column 71. Column 72 is the continuation indicator, so a continuation line that reaches column 72 gives `IEF618I OPERAND FIELD DOES NOT TERMINATE IN COMMA OR BLANK` and `IEF621I EXPECTED CONTINUATION NOT RECEIVED`, and the whole job is `NOT RUN - JCL ERROR`. Keep continuation indents short.
- Read the failing job's printout (the human can paste it from `prt/prt00e.txt`): the `STMT NO. MESSAGE` block names the statement. Bisect with a header-only job before guessing.
- A job that embeds other files (`DD DATA,DLM=..`) must substitute `@USER@`/`@PASS@` only on its own job card. A global `sed` once rewrote the embedded templates too and stored a real userid and password in a library everyone can read. `upload.sh` avoids this: it writes the credentials only into its throwaway job card, and its stream delimiter is `QQ` (it refuses a file with a line starting `QQ`, a tab or a line over 80 columns).
- Change a file, then `mainframe/upload.sh --build <file>` from the host: it uploads, then runs the matching build job on the mainframe (COBOL -> `SETUP`, ASM -> `MELSCR`, CLIST -> `CMDPROC`; no path means everything). The build jobs are the repo files from `melody/source/cntl`; the script adds `USER=`/`PASSWORD=` to their job card only when it sends them, and waits `MFWAIT` seconds (default 10) between jobs. Without `--build` it only uploads.
- On the mainframe the same builds run with one command: `MELBUILD` (all three, in order) or `MELBUILD WHAT(COBOL)`, `WHAT(ASM)`, `WHAT(CLIST)`. It is a CLIST that `SUBMIT`s `MELODY.SOURCE.CNTL(SETUP)`, `(MELSCR)` and `(CMDPROC)`. The user needs UPDATE on `MELODY.*` (group `MELODY` or `ADMIN`) and ALTER on `SYS2.*` for `CMDPROC` (`ADMIN`). The build jobs themselves can also be submitted one by one with `SUBMIT 'MELODY.SOURCE.CNTL(<member>)'`. The load modules live in the shared `MELODY.LOAD` (`MELODY68`, `MELSCR`). The panel, the CLISTs and the run job use `STEPLIB DD DSN=MELODY.LOAD`. The jobs are not guaranteed to run one after another unless the system has a single class A initiator, which was true here.
- Every user starts the tools with `MELPANEL` (full-screen) or `MELODY` (line mode) at `READY`. The four CLISTs (`MELPANEL`, `MELODY`, `MELSETUP`, `MELBUILD`) are copied into `SYS2.CMDPROC` by `CMDPROC` (as HERC02 or HERC01; `MELBUILD WHAT(CLIST)` or `upload.sh --build` runs it after a CLIST changes). `SYS2.CMDPROC` is on every user's `SYSPROC` path after `<user>.CMDPROC` and `SYS1.CMDPROC`, so a user's own member of the same name would shadow it. The long form `EXEC 'MELODY.SOURCE.CLIST(MELPANEL)'` also works.
- `MELPANEL` and `MELODY` call `%MELSETUP` first, which creates the user's own `<user>.MELODY.RUNJCL`, `OUT`, `SAVED` and `MIDI` (FB 80, written once, so no bogus first record) if they are missing. A new user only types `MELPANEL`.
- Keep the repo as the single source: edit the file under `melody/source`, upload it, never edit a member on the mainframe only. To check a member against the repo, `LIST 'MELODY.SOURCE.CLIST(MELODY)' NONUM` over `s3270` and compare.

**CLIST quirks learned on MVS 3.8j (from `melsetup.clist`)**
- There is no `GOSUB`. Use a counter and `GOTO` labels. Call another CLIST from `SYSPROC` with `%NAME`.
- Source lines are 80-column records. A longer line is silently cut, so continue it with a trailing `+` (the next line's leading blanks are dropped).
- `ALLOC ... SHR` on a missing dataset prints `NOT IN CATALOG`, then prompts. `CONTROL NOPROMPT` stops the prompt, and `&LASTCC` is non-zero, so test it to see whether a dataset exists. The error text still shows, which is acceptable on the first run only.
- `SPACE` needs a comma inside a CLIST: `SPACE(&SP,&SP)`. Typed at the terminal, `SPACE(1 1)` also works.
- `ATTRIB name RECFM(F B) LRECL(80) BLKSIZE(800)` plus `ALLOC ... NEW CATALOG TRACKS SPACE(a,b) USING(name)` creates a dataset. `OPENFILE f OUTPUT` followed by `CLOSFILE f` (CLIST statements: they only work inside a CLIST, not typed at READY) writes it once, giving `DSORG PS` and no bogus first record. This replaces the `IEFBR14` plus `IEBGENER` jobs.
- When testing a CLIST that you install with a job, check that the member really changed. A failed install job leaves the old member and the old behaviour.

**Working with the permission checks**
- Logging on to accounts with RAKF access, editing the security tables and submitting jobs with a password are blocked in auto mode. Give a clear step list and ask for the manual permission mode (or `!` commands) before the first such step.
- Jobs that run on the mainframe print their output to the emulator's printer, which a container cannot read. Check a result over TSO (`LISTDS ... MEMBERS`, or `LIST` of a data set the job wrote).
