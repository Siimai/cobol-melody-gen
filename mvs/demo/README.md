# Demo video of the mainframe panel

`make-demo.sh` drives the real `MELPANEL` over `s3270`, stores every screen
as text and renders a ~42 second 1080p video from them, with a backing track from the
first second and the generated melody played back over the run screen. Nothing is mocked:
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
| `melody.py` | reads the melody (notes, tempo, scale) from the `run1` screen into `build/melody.json`; pitch and length follow the panel's MIDI export |
| `mix.py` | builds `build/soundtrack.wav` (stdlib synth): drums, bass and chords from 0:00, the melody on a bar line, fade-out |
| `index.html` | draws a frame for any time `t` (terminal, typing animation, captions, title cards, note highlight and PLAYBACK badge while the melody sounds); also decides when the melody starts |
| `render.js` | Playwright: screenshots `index.html` at 30 fps into `build/png/` and writes `build/timeline.json` (melody start, length) |
| `make-demo.sh` | runs record, melody, render, mix and encodes `build/melody68-demo.mp4` (video plus soundtrack) with ffmpeg |

`build/` is git-ignored.

## How the sound stays in sync

One clock: `index.html` puts the melody on the first bar line (tempo from the
panel, bars counted from 0:00) at least 0.8 s after the run screen appears,
and writes that time to `timeline.json`; `mix.py` reads it, so the picture,
the highlighted notes, the drums and the melody cannot drift apart. The chords
follow the scale the program used; under the melody each bar's chord is chosen
from the scale's triads to fit the notes. The backing track fades out over the
last 4.5 s while the melody's last notes ring.

The audio is a playback made on the host from the program's output: the
mainframe app itself does not play sound (see *What's not in v1*). The video
says so (a PLAYBACK badge while the melody sounds, and a footnote on the title
and end cards).

## No secrets in the video

- The password comes from the environment, is typed once and is not stored:
  the terminal does not echo it, so no captured screen contains it.
- Captions that quote the run (scale, notes, tempo, MIDI size, user ID) are
  read from the captured screens, so they always match what is shown.
- Check before publishing: search `build/frames.json` for the password.

If the session ends badly the user stays "IN USE" until it is cancelled from
the console (`/C U=<userid>`). The script tells you when that happens.

## Needs

`s3270`, `python3`, `node` with `playwright` and its Chromium, `ffmpeg`, and
the Fira Code and Inter fonts (all in the dev container).
