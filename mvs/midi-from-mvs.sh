#!/bin/bash
# Fetch the last MIDI export (PF7 on the panel) from the mainframe and
# write it as a real .mid file. The panel keeps the export as hex text in
# <user>.MELODY.MIDI; this reads it over a TSO session (tso-list.py of the tk4 plugin, TK4_HOME).
# usage: midi-from-mvs.sh [OUTFILE]
# MIDIDS picks the data set: MIDI (default, the panel) or MIDIK (the KICKS
# transaction MELO): MIDIDS=MIDIK midi-from-mvs.sh
# Needs s3270 and python3. MFUSER / MFPASS / MFHOST come from the
# environment or mvs/.secrets/env. The user must not be logged on.
set -e
cd "$(dirname "$0")"
. .secrets/env 2>/dev/null || true
: "${MFUSER:?set MFUSER (or create mvs/.secrets/env)}"
: "${MFPASS:?set MFPASS (or create mvs/.secrets/env)}"
export MFUSER MFPASS MFHOST
OUT=${1:-../gnucobol/output/melody_$(date +%Y%m%d_%H%M%S).mid}
TK4_HOME=${TK4_HOME:-$HOME/claude-tk4}
RAW=$("$TK4_HOME/scripts/tso-list.py" "$MFUSER.MELODY.${MIDIDS:-MIDI}")
# keep only the hex records between the markers (last export in the data set)
HEX=$(printf '%s\n' "$RAW" | awk '
  /\*MIDI-BEGIN/ { buf=""; on=1; next }
  /\*MIDI-END/   { on=0; last=buf; next }
  on && /^ *[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]+ *$/ { gsub(/ /,""); buf = buf $0 }
  END { print last }')
[ -n "$HEX" ] || { echo "no MIDI export found - press PF7 on the panel first" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
printf '%s' "$HEX" | python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.stdin.read()))' > "$OUT"
echo "wrote $OUT ($(stat -c %s "$OUT") bytes)"
