# Dev container

Built on the `mainframe` variant of
[Siimai/claude-devcontainer](https://github.com/Siimai/claude-devcontainer)
(`ghcr.io/siimai/claude-devcontainer/mainframe`, pinned to a commit in the
`Dockerfile`). That image has git, Python, Node, `gh`, Claude Code, GnuCOBOL +
`make`, `s3270` and netcat. This project only adds what the demo video
(`mvs/demo`) needs: ffmpeg, the Fira Code and Inter fonts, and Playwright with
Chromium.

- The image is private while the package is: run
  `gh auth token | docker login ghcr.io -u <user> --password-stdin` once on the
  host (the token needs `read:packages`).
- Claude's config (`claude-config`) and the `gh` login (`gh-config`) are named
  volumes, so they survive rebuilds. Run `gh auth login` once after the first
  build; every start then runs `gh auth setup-git`, so git (and
  `/plugin install tk4`) can reach the private repos.
- The TK4- printer directory `$HOME/opt/tk4-_v1.00_current/prt` on the host is
  mounted read-only at `/mnt/tk4-prt`. The host path must exist, or the
  container does not start.
- The emulator runs on the Docker host: use `172.17.0.1`, not `localhost`.

To move to a newer base, change the `sha-...` tag in the `Dockerfile`.
