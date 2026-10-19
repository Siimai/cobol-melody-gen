#!/bin/bash
# usage: upload.sh [--dry-run] [--build] [--run JOB.jcl] [PATH...]
# MELODY settings for the generic upload.sh of the tk4 plugin
# (https://github.com/Siimai/claude-tk4, default location ~/claude-tk4, or TK4_HOME).
# Paths are relative to this directory:
#   melody/source/cobol/melody68.cbl -> MELODY.SOURCE.COBOL(MELODY68)
# With no PATH, melody/source is uploaded. --build runs the jobs from
# melody/source/cntl that .mfbuild maps to the uploaded libraries.
# MFUSER / MFPASS / MFHOST: environment or .secrets/env (see env.example).
cd "$(dirname "$0")"
TK4_HOME=${TK4_HOME:-$HOME/claude-tk4}
[ -x "$TK4_HOME/scripts/upload.sh" ] || { echo "tk4 plugin not found at $TK4_HOME (set TK4_HOME)" >&2; exit 1; }
export MFBASE=. MFDSNPREFIX= MFJOBNAME=MELUPLD MFCNTL=melody/source/cntl
OPTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|--build) OPTS+=("$1"); shift;;
    --run) OPTS+=("$1" "$2"); shift 2;;
    *) break;;
  esac
done
[ $# -gt 0 ] || set -- melody/source
exec "$TK4_HOME/scripts/upload.sh" "${OPTS[@]}" "$@"
