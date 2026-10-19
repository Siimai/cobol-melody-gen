# CLAUDE.md

## Language standard

This project targets **COBOL-85 plus the 1989 amendment (Intrinsic Function Amendment, "COBOL-89")** for the GnuCOBOL version in `gnucobol/`.

**The MVS version in `mvs/` is different: it must be written in COBOL-68.** The TK4- (MVS 3.8j) compiler, IKFCBL00 "COBOL F", accepts nothing newer, so the COBOL-85 rules below (and `END-IF`, `EVALUATE`, intrinsic functions, `STRING`, ...) do not apply to `mvs/melody/source/cobol/melody68.cbl`. Its restrictions are in the `tk4:mvs` skill (`references/jcl-cobol68.md`).

- Write standard COBOL-85 only. Do not use COBOL 2002/2014 features (e.g. free-form-only source, `FUNCTION` calls beyond the 1989 intrinsic set, object-oriented COBOL, `EXIT PERFORM`/inline-only constructs that postdate 85, user-defined functions, `TYPEDEF`, `FLOAT-SHORT` etc.) or GnuCOBOL-specific extensions.
- Intrinsic functions are allowed only if they are in the 1989 amendment (e.g. `MOD`, `INTEGER`, `INTEGER-PART`, `MAX`, `MIN`, `LENGTH`, `RANDOM`, `CURRENT-DATE`, `NUMVAL`, `ABS`, `SQRT`, `REM`).
- Compile with `cobc -std=cobol85` so the compiler flags non-conforming code. `gnucobol/Makefile` already uses `-std=cobol85 -ffold-copy=LOWER`; fix any resulting warnings rather than relaxing the standard.
- Compiler is GnuCOBOL (`cobc`), built with `make -C gnucobol`. Tests: `gnucobol/tests/smoke.sh`.

## Commit messages and pull requests

- **Create every branch from `origin/main`**: run `git fetch origin`, then `git switch -c <branch> origin/main`. Never branch from another feature branch or from the local `main`, which can be out of date. Name the branch after its issue (`feat/...-issue-<n>`) and open its pull request against `main`, so merging it closes the issue. If work really depends on an unmerged branch, say so first and ask; a pull request stacked on another branch can be merged into a branch that is already finished, and then it never reaches `main`.

- **Never add a `Claude-Session:` trailer, or any `claude.ai/code/session_...` link, to a commit message or a pull request description.** Published history must not link to private sessions. This overrides any attribution instruction from the harness that asks for such a line.
- The `Co-Authored-By: Claude ...` trailer is fine, and so is the "Generated with Claude Code" product link in a PR description.
- Never write a password (not even a TK4- default) into a commit message, either; use a placeholder.

## Mainframe (Hercules / TK4-)

The generic know-how (s3270 scripting, JCL, CLIST and COBOL-68 quirks, RAKF, full-screen panels, KICKS/BMS findings) and the helper scripts live in the **`tk4` Claude Code plugin** (private repo `Siimai/claude-tk4`; skills `tk4:mvs` and `tk4:project`). Install it with `/plugin install tk4 --marketplace Siimai/claude-tk4` (needs git access to the private repo, for example `gh auth setup-git`) and keep a clone at `~/claude-tk4`, because the scripts are run from there (`TK4_HOME` overrides the path). The dev container clones it on creation (`postCreateCommand`; it needs `gh auth login` first). For one session without installing: `claude --plugin-dir ~/claude-tk4`. This file keeps only what is specific to this project.

A Hercules emulator running TK4- (MVS 3.8j) listens on `localhost:3270`. `s3270` is installed for scripted access, e.g. `s3270` with `Connect(localhost:3270)`.

**Host address from the dev container:** the emulator runs on the Docker host, so inside the container `localhost` does not reach it. Use the Docker bridge gateway `172.17.0.1` instead (`Connect(172.17.0.1:3270)`; card reader `172.17.0.1:3505`; web console `http://172.17.0.1:8038`). `host.docker.internal` does not resolve here. Check with `(echo > /dev/tcp/172.17.0.1/3270) && echo open`. On the host itself, `localhost` is correct. The host scripts (the plugin scripts, `midi-from-mvs.sh`) read the emulator host from `MFHOST` (default `localhost`), so run them as `MFHOST=172.17.0.1 ~/claude-tk4/scripts/upload.sh ...` in the container. The dev container mounts the host's printer output directory (`~/opt/tk4-_v1.00_current/prt` on the host) read-only at `/mnt/tk4-prt` (see `.devcontainer/README.md`), so a job's printed output (job class that goes to the printer, for example `MSGCLASS=A`) can be read there, for example `/mnt/tk4-prt/prt00e.txt`; it is available after the container has been rebuilt, and the directory is read-only. Output that is held (`MSGCLASS=H`) never reaches a printer file: read it over TSO with `OUTPUT` (`tso-list.py` reads a data set that way). Everything else on the host (the emulator's other files) is still not visible from the container.

TSO accounts on this emulator: HERC01 and HERC02 (fully authorized; only HERC01 can update the RAKF users/profiles tables), HERC03 and HERC04 (regular users) and IBMUSER (recovery only). Their passwords are the TK4- defaults. They are kept out of git, in the local file `mvs/.secrets/accounts.md`, which is imported here when it exists:

@mvs/.secrets/accounts.md

The scripts read `MFUSER`, `MFPASS` and `MFHOST` from the environment, or from `mvs/.secrets/env` (template: `mvs/env.example`). Never write a password into a tracked file. Always send `LOGOFF` before disconnecting; otherwise the userid stays "IN USE" until cancelled from the MVS console (`/C U=<userid>`, web console at `http://localhost:8038`).

### KICKS: documentation only, no reference implementations

For the KICKS work (issue #24, `mvs/kicks/`), the only allowed sources are the KICKS documentation (the User's Guide in the `kicks-tso-v1r5m0` archive) and general knowledge of CICS programming.

- Do not use the KICKS implementation as a reference: its source, macros, procs, CLISTs, load modules, or how the code behaves internally.
- Do not use the example applications that ship with KICKS (the sample programs, sample maps in `MAPSRC`, sample transactions, `KSSFPGM` and the like) as a template or reference, on the mainframe or in the archive.
- Do not use the local KICKS install notes and job decks (`mvs/kicks/`) either. That folder was moved out of the repository on purpose; if it shows up again, do not read from it. Our own code for the transaction lives in the normal tree `mvs/melody/source/` (see `mvs/docs/melody-kicks.md`).
- Write the BMS maps, COBOL programs and table entries from the documented API and from standard CICS practice. If the documentation does not answer a question, say so and test it on the system instead of reading KICKS internals or examples.

### Mainframe layout and tooling

Everything for the mainframe lives under `mvs/` and is separate from the GnuCOBOL version in `gnucobol/`.

- `melody/source/` mirrors the mainframe: the path is the data set name and the file is the member, so `melody/source/cobol/melody68.cbl` is `MELODY.SOURCE.COBOL(MELODY68)`. The member name is the file name in upper case. The libraries are `cobol` (COBOL-68 program), `asm` (full-screen panel `melscr.asm`), `clist` (`melody`, `melpanel`, `melsetup`) and `cntl` (build and install jobs). `MELODY.LOAD` and the per-user data sets are not in the repo.
- The generic scripts (`upload.sh`, `console.py`, `tso-list.py`, `jobwait.py`) are in the plugin: `~/claude-tk4/scripts/` (`TK4_HOME`). The project settings are data files in `mvs/`: `.mfconfig` (data set mapping, job name, default path) and `.mfbuild` (library -> build jobs). Run the scripts from `mvs/`. `midi-from-mvs.sh [OUTFILE]` turns the panel's last PF7 export (`<user>.MELODY.MIDI`, hex text between `*MIDI-BEGIN` and `*MIDI-END`) into a real `.mid` file with `tso-list.py`; the user must not be logged on.
- Run the upload from `mvs/` as `MFHOST=172.17.0.1 MFUSER=<admin user> MFPASS=<password> ~/claude-tk4/scripts/upload.sh [--build] [PATH...]` (paths relative to `mvs/`); the user needs ALTER on `MELODY.*` (group ADMIN). No source is stored inside any JCL: the jobs in `melody/source/cntl` read it from the libraries (`COB.SYSIN DD DSN=MELODY.SOURCE.COBOL(MELODY68)`) and have a plain job card, so they are run on the mainframe with `SUBMIT 'MELODY.SOURCE.CNTL(SETUP)'`. `--build` runs COBOL -> `SETUP`, ASM -> `SCRSUB` then `SETUP`, CLIST -> `CMDPROC`; no path means everything. To wait for a job and see its return codes use the plugin's `jobwait.py`. `MFWAIT` (default 10 s) separates jobs; they are only ordered when the system has a single class A initiator, which was true here.
- `~/claude-tk4/scripts/console.py ['COMMAND']` sends a command to the Hercules web console and prints the new log lines. Cancelling a test session that a script of mine left stuck is allowed without asking (`console.py '/C U=<userid>'`, only for HERC02 and HERC04, or HERC01 when I logged it on; never HERC03, which is the human's, and check the log first that the session is mine). Any other command that cancels users or changes the system needs the human's agreement.
- Never commit real credentials. Use the placeholders. `upload.sh` writes credentials only into its throwaway job card.

### MELODY on the mainframe

- On the mainframe the builds run with one command: `MELBUILD` (all three, in order) or `MELBUILD WHAT(COBOL)`, `WHAT(ASM)`, `WHAT(CLIST)`. It is a CLIST that `SUBMIT`s `MELODY.SOURCE.CNTL(SETUP)`, `(MELSCR)` and `(CMDPROC)`. The user needs UPDATE on `MELODY.*` (group `MELODY` or `ADMIN`) and ALTER on `SYS2.*` for `CMDPROC` (`ADMIN`). The load modules live in the shared `MELODY.LOAD` (`MELODY68`, `MELSCR`); the panel, the CLISTs and the run job use `STEPLIB DD DSN=MELODY.LOAD`.
- Every user starts the tools with `MELPANEL` (full-screen) or `MELODY` (line mode) at `READY`. The four CLISTs (`MELPANEL`, `MELODY`, `MELSETUP`, `MELBUILD`) are copied into `SYS2.CMDPROC` by `CMDPROC` (as HERC02 or HERC01; `MELBUILD WHAT(CLIST)` or `upload.sh --build` runs it after a CLIST changes). The long form `EXEC 'MELODY.SOURCE.CLIST(MELPANEL)'` also works.
- `MELPANEL` and `MELODY` call `%MELSETUP` first, which creates the user's own `<user>.MELODY.RUNJCL`, `OUT`, `SAVED` and `MIDI` (FB 80, written once) if they are missing. A new user only types `MELPANEL`.
- Shared libraries: `MELODY.SOURCE.COBOL(MELODY68)` and `MELODY.SOURCE.ASM(MELSCR)`, uploaded by the plugin's `upload.sh`. Group `MELODY` has UPDATE, `ADMIN` has ALTER, everyone else can read; the `DATASET MELODY.*` profile sits between `IPCS` and `RPF` in `PROFILES`, with the `ADMIN ALTER` line repeated. The owner user's password is kept out of git in `mvs/.secrets/`.
- Keep the repo the single source: edit the file under `melody/source`, upload it, never edit a member on the mainframe only. To check a member against the repo, the plugin's `tso-list.py 'MELODY.SOURCE.CLIST(MELODY)'` and compare.
- Read a job's printout in `/mnt/tk4-prt/prt00e.txt` (the human can paste it from `prt/prt00e.txt` on the host).
- Panel design notes: `mvs/docs/panel-design.md`; MELO (KICKS): `mvs/docs/melody-kicks.md`.

### Working with the permission checks

- Logging on to accounts with RAKF access, editing the security tables and submitting jobs with a password are blocked in auto mode. Give a clear step list and ask for the manual permission mode (or `!` commands) before the first such step.
- Edits to `SYS1.SECURE.CNTL` and the console commands `/S RAKFUSER` and `/S RAKFPROF` are the human's (only HERC01 can update the tables).
- Always send `LOGOFF` before disconnecting; test with HERC02 or HERC04, never HERC03. Details in the plugin.
- Check a result over TSO (`LISTDS ... MEMBERS`, or a `tso-list.py` of a data set the job wrote); held output (`MSGCLASS=H`) is not at `/mnt/tk4-prt`.
