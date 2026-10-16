#!/bin/bash
# Wrap melody68.cob in COBUCG JCL and send it to the Hercules card reader.
# usage: submit.sh [SCALE 0-8] [LENGTH 8-16] [TEMPO 40-240]  (0 = random/default)
set -e
cd "$(dirname "$0")"
SCALE=${1:-0}; LEN=${2:-0}; TEMPO=${3:-0}
PRT=${PRT:-$HOME/opt/tk4-_v1.00_current/prt/prt00e.txt}
START=$(stat -c %s "$PRT")
{
  echo "//MELODY68 JOB (1),'MELODY',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1)"
  echo "//STEP1    EXEC COBUCG"
  echo "//COB.SYSIN DD *"
  cat melody68.cob
  echo "/*"
  echo "//GO.SYSOUT DD SYSOUT=A"
  echo "//GO.SYSIN DD *"
  printf '%d%02d%03d\n' "$SCALE" "$LEN" "$TEMPO"
  echo "/*"
  echo "//"
} | nc -q1 localhost 3505
sleep 8
tail -c +$((START + 1)) "$PRT"
