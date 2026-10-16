# CLAUDE.md

## Language standard

This project targets **COBOL-85 plus the 1989 amendment (Intrinsic Function Amendment, "COBOL-89")**.

- Write standard COBOL-85 only. Do not use COBOL 2002/2014 features (e.g. free-form-only source, `FUNCTION` calls beyond the 1989 intrinsic set, object-oriented COBOL, `EXIT PERFORM`/inline-only constructs that postdate 85, user-defined functions, `TYPEDEF`, `FLOAT-SHORT` etc.) or GnuCOBOL-specific extensions.
- Intrinsic functions are allowed only if they are in the 1989 amendment (e.g. `MOD`, `INTEGER`, `INTEGER-PART`, `MAX`, `MIN`, `LENGTH`, `RANDOM`, `CURRENT-DATE`, `NUMVAL`, `ABS`, `SQRT`, `REM`).
- Compile with `cobc -std=cobol85` where possible so the compiler flags non-conforming code. The Makefile currently uses `-ffold-copy=LOWER` only; add `-std=cobol85` when touching build flags, and fix any resulting warnings rather than relaxing the standard.
- Compiler is GnuCOBOL (`cobc`), built via `make`. Tests: `tests/smoke.sh`.
