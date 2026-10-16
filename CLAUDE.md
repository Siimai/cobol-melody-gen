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

These come from the TK4- documentation. Verified against this instance: HERC01/<admin-pw> and HERC02/<admin-pw> log on to TSO. The others are untested. Always send `LOGOFF` before disconnecting; otherwise the userid stays "IN USE" until cancelled from the MVS console (`/C U=<userid>`, web console at `http://localhost:8038`).
