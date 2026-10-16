#!/bin/bash
# Fetch the last MIDI export (PF7 on the panel) from the mainframe and
# write it as a real .mid file.
# usage: midi-from-mvs.sh [OUTFILE]      (user: MFUSER/MFPASS, default HERC03)
set -e
cd "$(dirname "$0")"
OUT=${1:-../output/melody_$(date +%Y%m%d_%H%M%S).mid}
RAW=$(./mfsubmit.sh jcl/show-midi.jcl "${WAIT:-8}")
# keep only the hex records between the markers (last export in the output)
HEX=$(printf '%s\n' "$RAW" | awk '
  /\*MIDI-BEGIN/ { buf=""; on=1; next }
  /\*MIDI-END/   { on=0; last=buf; next }
  on && /^ ?[0-9A-F]+ *$/ { gsub(/ /,""); buf = buf $0 }
  END { print last }')
[ -n "$HEX" ] || { echo "no MIDI export found - press PF7 on the panel first" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
printf '%s' "$HEX" | xxd -r -p > "$OUT"
echo "wrote $OUT ($(stat -c %s "$OUT") bytes)"
