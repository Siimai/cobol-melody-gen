# Demo video of the mainframe panel

`make-demo.sh` drives the real `MELPANEL` over `s3270`, stores every screen
as text and renders a ~40 second 1080p video from them. Nothing is mocked:
the video shows what the emulator returned.

```sh
MFHOST=172.17.0.1 MFUSER=HERC04 MFPASS=<password> mvs/demo/make-demo.sh
```

| Variable | Meaning |
|----------|---------|
| `MFUSER` | TSO user to log on as. Must be in the environment (not defaulted), and should be a user the human is not using |
| `MFPASS` | its password (environment, or `mvs/.secrets/env`) |
| `MFHOST` | emulator host (`localhost`, or `172.17.0.1` in the dev container) |

Other modes: `--render-only` (reuse `build/frames.json`) and
`--preview 5,20,31` (PNG stills in `build/preview/`, for checking the layout).

## What is in here

| File | Role |
|------|------|
| `record.py` | logs on, runs the panel (scale 3, 12 notes, tempo 100), PF5/PF7/PF6, always logs off; writes `build/frames.json` |
| `index.html` | draws a frame for any time `t` (terminal, typing animation, captions, title cards) |
| `render.js` | Playwright: screenshots `index.html` at 30 fps into `build/png/` |
| `make-demo.sh` | runs the three steps and encodes `build/melody68-demo.mp4` with ffmpeg |

`build/` is git-ignored.

## No secrets in the video

- The password comes from the environment, is typed once and is not stored:
  the terminal does not echo it, so no captured screen contains it.
- The two e-mail addresses in the TK4- banner are blanked when drawing.
- Captions that quote the run (scale, notes, tempo, MIDI size, user ID) are
  read from the captured screens, so they always match what is shown.
- Check before publishing: search `build/frames.json` for the password.

If the session ends badly the user stays "IN USE" until it is cancelled from
the console (`/C U=<userid>`). The script tells you when that happens.

## Needs

`s3270`, `python3`, `node` with `playwright` and its Chromium, `ffmpeg`, and
the Fira Code and Inter fonts (all in the dev container).
