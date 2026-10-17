---
description: "Project-wide repository and GitHub details. Always active for all files and conversations."
applyTo: "**"
---

# Repository Information

- **Owner:** `Siimai`
- **Repository:** `cobol-melody-gen`
- **URL:** https://github.com/Siimai/cobol-melody-gen
- **Remote:** `https://github.com/Siimai/cobol-melody-gen.git`

Use these details for all GitHub interactions (listing issues, creating pull requests, pushing branches, etc.) without needing to look them up.

## Planning Workflow

Plan files in `plans/` are **local drafts only** — they are git-ignored and never committed.

1. **Draft in `plans/`** — create a markdown file (e.g., `plans/my-feature.md`) to capture the proposed approach, sub-tasks, and any before/after details.
   - All file references in plan files must use **relative paths** (e.g., `gnucobol/src/main.cob`, `gnucobol/output/`). Never use absolute paths (e.g., `/Users/name/project/src/main.cob`).
2. **Iterate locally** — refine the plan until it is ready for implementation.
3. **Promote to a GitHub issue** — once the plan is approved, create a GitHub issue via the GitHub tool using the plan content as the issue body. The issue becomes the single source of truth; the local file can be deleted.
4. **Do not commit plan files** — `plans/` is in `.gitignore`. Only the resulting GitHub issue is tracked.

## Issue Workflow

Follow this process for every GitHub issue:

1. **Read the issue** — fetch it with the GitHub tool to understand all requirements before touching any code.

2. **Read the COBOL instructions** — load `.github/instructions/cobol.instructions.md` so all edits conform to the IBM Enterprise COBOL coding standards.

3. **Create a feature branch** — name it `fix/<short-slug>-issue-<number>` (e.g., `fix/ibm-cobol-compat-issue-1`).

4. **Implement all fixes** — apply every change described in the issue, in one focused commit. Do not include unrelated edits (e.g., instruction files that happened to be dirty).

5. **Verify the build passes** — run `make -C gnucobol` and confirm it exits with code 0 before committing. Fix any build errors first, then commit.

5a. **Update README.md** — for every user-visible change, update the relevant section before committing:
   - New or removed menu options → update the menu screenshot in the **Run** section.
   - New scales → add rows to the **Supported scales** table.
   - MIDI/export behaviour changes → update the **MIDI** subsection under *Saved files*.
   - Features moved from planned to complete → remove them from **"What's not in v1"**.
   - Binary path or build output changes → update the **Run** section.

6. **Commit with a descriptive message** — format:
   ```
   fix: <short summary> (closes #<number>)

   <bullet per sub-item explaining what changed and why>
   ```
   Never amend or rebase commits that have already been pushed. If a follow-up fix is needed, create a new commit with a clear message describing what was corrected.

7. **Push the branch** — `git push origin <branch-name>`.

8. **Open a pull request** via the GitHub tool:
   - `base`: `main`
   - `head`: the feature branch
   - `title`: `fix: <summary> (#<number>)`
   - `body`: list every sub-item fixed with a short explanation, grouped by ID/category.

8a. **Gate on manual testing** — STOP after opening the PR. Tell the user:
   - The branch is built, tests pass, and the PR is open.
   - Invite them to run `make -C gnucobol run` and test manually.
   - Ask explicitly: **"Ready to merge, or would you like to skip manual testing and merge now?"**
   - Do NOT proceed to merge until the user gives the go-ahead. Wait for their response.

9. **Merge via squash** — once the user approves, merge using `merge_method: squash`. This keeps `main` history clean with one commit per issue. Delete the feature branch after merging.
