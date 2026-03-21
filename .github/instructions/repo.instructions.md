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

## Issue Workflow

Follow this process for every GitHub issue:

1. **Read the issue** — fetch it with the GitHub tool to understand all requirements before touching any code.

2. **Read the COBOL instructions** — load `.github/instructions/cobol.instructions.md` so all edits conform to the IBM Enterprise COBOL coding standards.

3. **Create a feature branch** — name it `fix/<short-slug>-issue-<number>` (e.g., `fix/ibm-cobol-compat-issue-1`).

4. **Implement all fixes** — apply every change described in the issue, in one focused commit. Do not include unrelated edits (e.g., instruction files that happened to be dirty).

5. **Commit with a descriptive message** — format:
   ```
   fix: <short summary> (closes #<number>)

   <bullet per sub-item explaining what changed and why>
   ```

6. **Push the branch** — `git push origin <branch-name>`.

7. **Open a pull request** via the GitHub tool:
   - `base`: `main`
   - `head`: the feature branch
   - `title`: `fix: <summary> (#<number>)`
   - `body`: list every sub-item fixed with a short explanation, grouped by ID/category.
