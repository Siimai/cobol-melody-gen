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
   - All file references in plan files must use **relative paths** (e.g., `src/main.cob`, `output/`). Never use absolute paths (e.g., `/Users/name/project/src/main.cob`).
2. **Iterate locally** — refine the plan until it is ready for implementation.
3. **Promote to a GitHub issue** — once the plan is approved, create a GitHub issue via the GitHub tool using the plan content as the issue body. The issue becomes the single source of truth; the local file can be deleted.
4. **Do not commit plan files** — `plans/` is in `.gitignore`. Only the resulting GitHub issue is tracked.

## Issue Workflow

Follow this process for every GitHub issue:

1. **Read the issue** — fetch it with the GitHub tool to understand all requirements before touching any code.

2. **Read the COBOL instructions** — load `.github/instructions/cobol.instructions.md` so all edits conform to the IBM Enterprise COBOL coding standards.

3. **Create a feature branch** — name it `fix/<short-slug>-issue-<number>` (e.g., `fix/ibm-cobol-compat-issue-1`).

4. **Implement all fixes** — apply every change described in the issue, in one focused commit. Do not include unrelated edits (e.g., instruction files that happened to be dirty).

5. **Verify the build passes** — run `make` and confirm it exits with code 0 before committing. Fix any build errors first, then commit.

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

9. **Merge via squash** — once the PR is approved, merge it using `merge_method: squash`. This keeps `main` history clean with one commit per issue. Delete the feature branch after merging.
