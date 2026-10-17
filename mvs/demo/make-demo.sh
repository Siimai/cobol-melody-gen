#!/bin/sh
# Record the MELPANEL session and turn it into build/melody68-demo.mp4.
#
#   MFUSER=HERC04 MFPASS=<password> MFHOST=172.17.0.1 mvs/demo/make-demo.sh
#   mvs/demo/make-demo.sh --render-only        reuse build/frames.json
#   mvs/demo/make-demo.sh --preview 5,20,31    PNG stills in build/preview/
#
# MFUSER must be given in the environment on purpose: mvs/.secrets/env would
# default to the human's own user. MFPASS and MFHOST may also come from
# mvs/.secrets/env. Needs s3270, python3, node with playwright (NODE_PATH),
# ffmpeg, and the Fira Code and Inter fonts (the dev container has them).
set -e
cd "$(dirname "$0")"
MODE=all
case "$1" in
  --render-only) MODE=render; shift;;
  --preview) MODE=preview; PREVIEW="${2:?--preview needs times, e.g. 5,20}"; shift 2;;
esac
if [ $MODE = all ]; then
  : "${MFUSER:?set MFUSER to a user the human is not using (HERC04)}"
  . ../.secrets/env 2>/dev/null || true
  : "${MFPASS:?set MFPASS}"
  export MFHOST MFUSER MFPASS
  python3 -I record.py
fi
if [ $MODE = preview ]; then
  node render.js "$PREVIEW"
  exit
fi
rm -rf build/png
node render.js
ffmpeg -y -loglevel error -framerate 30 -i build/png/f%05d.png \
  -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart \
  build/melody68-demo.mp4
echo "wrote $(pwd)/build/melody68-demo.mp4"
