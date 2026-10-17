#!/bin/bash
# usage: mfsubmit.sh JOBFILE [WAIT_SECONDS]
# Substitutes @USER@/@PASS@ (user and password from MFUSER/MFPASS or
# mainframe/.secrets/env), sends the job to the Hercules card reader and
# prints the new part of the printer file.
set -e
. "$(dirname "$0")/.secrets/env" 2>/dev/null || true
USER_=${MFUSER:-HERC03}; PASS_=${MFPASS:?set MFPASS or create mainframe/.secrets/env}
PRT=${PRT:-$HOME/opt/tk4-_v1.00_current/prt/prt00e.txt}
START=$(stat -c %s "$PRT")
sed -e "s/@USER@/$USER_/g" -e "s/@PASS@/$PASS_/g" "$1" | nc -q1 localhost 3505
sleep "${2:-10}"
tail -c +$((START + 1)) "$PRT"
