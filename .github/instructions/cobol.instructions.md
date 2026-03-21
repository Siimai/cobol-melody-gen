---
description: "Use when writing, editing, or reviewing COBOL source files. Enforces IBM Enterprise COBOL for z/OS compatibility, fixed-column format, and project conventions."
applyTo: ["**/*.cob", "**/*.cpy"]
---

# IBM Enterprise COBOL Guidelines

## Compatibility Target

Write all COBOL code to be compatible with **IBM Enterprise COBOL for z/OS** (version 5.x and later). Avoid GnuCOBOL-specific extensions unless there is no IBM equivalent.

## Column Format

Use standard fixed-column format strictly:

| Columns | Area              |
|---------|-------------------|
| 1–6     | Sequence numbers (leave blank or numeric) |
| 7       | Indicator (`*` for comment line, `-` for continuation, `/` for page eject) |
| 8–11    | Area A (division/section/paragraph headers, level-01/77/88 data items, FD entries) |
| 12–72   | Area B (statements, subordinate data items) |
| 73–80   | Identification (leave blank) |

- Indent Area B code consistently (4-space increments within Area B).
- Never place code beyond column 72.

## Comments

- Use `*` in column 7 for full-line comments (universally compatible with all IBM COBOL versions).
- Use `*>` only for inline/end-of-line comments (supported from IBM Enterprise COBOL v5+).
- Use comment blocks with `*> ===...===` banners to delimit sections and paragraphs, matching existing style.

## Data Division

- Use level numbers `01`, `05`, `10`, `15`, `20` etc. in multiples of 5 for clarity.
- Use `PIC` (not `PICTURE`) for brevity.
- Use `COMP` (BINARY) or `COMP-3` (packed-decimal) for numeric items that require efficient arithmetic; use `PIC 9(n)` for display numerics only where readability matters.
- Avoid `USAGE IS INDEX` in new items; use `PIC 9` counters instead for portability.
- `88` condition-name values must be defined immediately subordinate to their parent item.
- Place all shared structures in copybooks (`.cpy`), not duplicated across programs.

## Procedure Division

- Use paragraph-based (not section-based) structure — every callable unit is a paragraph.
- Paragraph names follow the pattern `NNN-SHORT-DESCRIPTION` (e.g., `100-INIT`, `200-MAIN-LOOP`).
- Always terminate the Procedure Division with `STOP RUN` (in main) or `GOBACK` (in subprograms).
- Prefer `PERFORM paragraph-name` over `GO TO`; never use `GO TO` for forward control flow.
- Use scope terminators (`END-IF`, `END-PERFORM`, `END-EVALUATE`, `END-READ`, `END-CALL`, etc.) for all inline statements.
- Use `EVALUATE TRUE` for multi-condition branching (equivalent to switch/case).

## Arithmetic

- Use `COMPUTE` for expressions; use `ADD`/`SUBTRACT`/`MULTIPLY`/`DIVIDE` only for simple single-operation statements.
- Always specify `ON SIZE ERROR` or `ROUNDED` where overflow is possible.
- Use `FUNCTION` intrinsic functions available in IBM Enterprise COBOL:  
  `FUNCTION RANDOM`, `FUNCTION CURRENT-DATE`, `FUNCTION INTEGER-OF-DATE`, `FUNCTION MOD`, `FUNCTION LENGTH`, etc.

## String Handling

- Use `MOVE SPACES TO` to initialize alphanumeric fields.
- Use `STRING ... DELIMITED SIZE INTO ...` for concatenation; validate with `ON OVERFLOW`.
- Use `INSPECT ... TALLYING` or `INSPECT ... REPLACING` rather than manual substring loops.

## File I/O

- Define files in `FILE-CONTROL` using `ASSIGN TO` with a meaningful ddname-style name.
- Use `OPEN`, `READ ... AT END`, `WRITE`, `CLOSE` with explicit scope terminators.
- Check `FILE STATUS` codes after every I/O operation.

## CALLs and Subprograms

- Use `CALL 'literal-name' USING ...` with uppercase or lowercase program names consistently (the existing code uses lowercase).
- Subprograms must define `LINKAGE SECTION` data items mirroring the caller's `USING` list exactly.
- End every subprogram with `GOBACK` (not `STOP RUN`).
- Avoid `CALL 'SYSTEM'` for production z/OS code; note it is used here for local development/GnuCOBOL only — add a comment where it appears.

## Copybooks

- Copybook members use `.cpy` extension and live in `src/`.
- `COPY` statements should appear at the top of the relevant section, before any locally defined items.
- Do not include a period inside a copybook that would terminate an enclosing statement.

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Program-ID | lowercase, no hyphens | `generator` |
| Working-storage | `WS-` prefix, uppercase, hyphens | `WS-MELODY-COUNT` |
| Linkage | `LS-` prefix | `LS-SCALE-TABLE` |
| File-section | `FS-` prefix | `FS-OUTPUT-REC` |
| Paragraphs | `NNN-VERB-NOUN` | `300-WRITE-OUTPUT` |
| Condition names (88) | `ALL-CAPS`, descriptive | `APP-RUNNING` |

## Build

```bash
make        # compile all modules
make run    # compile and run
```

Compiler: GnuCOBOL (`cobc`) is used locally; write source to be portable to IBM Enterprise COBOL. Flag any GnuCOBOL-isms with a `*> GnuCOBOL-only` comment.
