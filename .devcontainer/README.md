# claude-devcontainer

> **Note:** in `cobol-melody-gen` this folder is a plain directory (it was a
> git submodule of `Siimai/claude-devcontainer` before). The reuse and
> submodule instructions below describe that original, separate repo.

A reusable [Dev Container](https://containers.dev/) base for working with Claude
Code: Ubuntu 26.04 with git, Node, Python, audio/video tooling (ffmpeg, csound,
sox, SuperCollider), image/font tooling, Playwright + Chromium, Remotion, and
the Claude Code CLI itself. Claude's config lives on a named Docker volume so
it survives container rebuilds.

## Reusing it in another project (git submodule)

Add this repo as a submodule *at* the target project's `.devcontainer/` path
— `Dockerfile` and `devcontainer.json` land exactly where VS Code / the Dev
Containers CLI expect them, so no per-project config file is needed. Every
project that does this shares the literal same `devcontainer.json`, pinned to
whichever commit of this repo that project's submodule points at.

```bash
cd /path/to/your-project
git submodule add git@github.com:Siimai/claude-devcontainer.git .devcontainer
```

That's it — open the project in VS Code and "Reopen in Container" picks it
up automatically.

### Cloning a project that uses this submodule

```bash
git clone --recurse-submodules <project-url>
# or, if already cloned without that flag:
git submodule update --init --recursive
```

### Pulling in updates to the base image

```bash
cd .devcontainer
git pull origin main
cd ..
git add .devcontainer
git commit -m "Update claude-devcontainer base"
```

Since submodules pin an exact commit, updates are explicit per project
rather than silently changing everyone's container underneath them.

### Running Claude Code inside the container

**VS Code** — open the project, run *Dev Containers: Reopen in Container*
(Command Palette), then just run `claude` in the integrated terminal once
it's attached.

**Terminal only**, using the [Dev Containers
CLI](https://github.com/devcontainers/cli) (`npm install -g
@devcontainers/cli`):

```bash
cd /path/to/your-project
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . claude
```

`devcontainer up` builds the image on first run (cached on later runs — see
caching notes below) and starts the container; `exec` runs `claude` inside
it, attached to your current terminal.

First run in a given project will prompt you to log in — Claude's config is
stored on a volume keyed to that project's `devcontainerId`, so each project
gets its own isolated login/session rather than sharing one across
projects.

### Build caching across projects

Because the Dockerfile has no `COPY`/`ADD` of project files and no build
args, every project building from the same submodule commit produces
byte-identical layers. Docker's local build cache is keyed by layer
content, not by project — so only the *first* project you build this in
pays the full ~5-10 min install cost (apt, Playwright/Chromium, Remotion,
etc.); every other project on the same machine hits cache and finishes in
seconds, with layers shared on disk rather than duplicated. This only holds
as long as the projects' submodules point at the same commit — if one
project updates and another doesn't, their Dockerfiles diverge and cache
sharing stops at the first differing instruction.

## Testing this repo standalone

Because `devcontainer.json` here has no leading dot (so it lands correctly
as `<project>/.devcontainer/devcontainer.json` when submoduled), it isn't
auto-detected when opening *this* repo's own folder directly. To build and
try it in isolation, point the Dev Containers CLI at it explicitly:

```bash
devcontainer up --workspace-folder . --config devcontainer.json
```

or submodule it into a throwaway test project the same way any other
project would.
