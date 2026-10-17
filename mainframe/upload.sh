#!/bin/bash
# usage: upload.sh [--dry-run] [--build] [PATH...]
# Uploads the source tree under melody/source to the mainframe. The path
# is the dataset name and the file is the member:
#   melody/source/cobol/melody68.cbl -> MELODY.SOURCE.COBOL(MELODY68)
# The member name is the file name in upper case; the extension is ignored.
# With no PATH, every file is uploaded; otherwise only the given files or
# directories. One throwaway job is built, sent to the card reader and
# never stored (no source is kept inside any JCL in the repo).
# MFUSER / MFPASS: a user with ALTER on MELODY.* (group ADMIN).
# MFHOST: card reader host (default localhost; 172.17.0.1 in the container).
# --build then runs the matching build job from melody/source/cntl on the
# mainframe: COBOL -> setup.jcl, ASM -> melscr.jcl, CLIST -> cmdproc.jcl. The
# jobs are the repo files; USER= and PASSWORD= are added to their job card
# only when they are sent. MFWAIT seconds (default 10) pass between jobs so
# that each finishes before the next starts.
# --dry-run prints the job (password masked) and sends nothing.
set -e
cd "$(dirname "$0")"
DRY=0; BUILD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift;;
    --build) BUILD=1; shift;;
    *) break;;
  esac
done
MFHOST=${MFHOST:-localhost}
if [ $DRY = 0 ]; then
  : "${MFUSER:?set MFUSER to a user with ALTER on MELODY.*}"
  : "${MFPASS:?set MFPASS}"
fi

if [ $# -eq 0 ]; then set -- melody/source; fi
FILES=$(find "$@" -type f | sort)
[ -n "$FILES" ] || { echo "no files to upload" >&2; exit 1; }

dsn_of() {  # melody/source/cobol/x.cbl -> MELODY.SOURCE.COBOL
  dirname "$1" | tr 'a-z/' 'A-Z.'
}
member_of() {  # melody/source/cobol/x.cbl -> X
  b=$(basename "$1"); b=${b%.*}; echo "$b" | tr 'a-z' 'A-Z'
}

# checks: names, 80 columns, no tabs, no QQ delimiter clash
for f in $FILES; do
  case "$f" in melody/source/*/*) ;; *) echo "$f is not under melody/source/<library>/" >&2; exit 1;; esac
  m=$(member_of "$f")
  echo "$m" | grep -Eq '^[A-Z@#$][A-Z0-9@#$]{0,7}$' || { echo "$f: bad member name $m" >&2; exit 1; }
  if awk 'length($0)>80{exit 1}' "$f"; then :; else echo "$f has a line over 80 columns" >&2; exit 1; fi
  if grep -q "$(printf '\t')" "$f"; then echo "$f contains a tab" >&2; exit 1; fi
  if grep -q '^QQ' "$f"; then echo "$f has a line starting with QQ (stream delimiter)" >&2; exit 1; fi
done

LIBS=$(for f in $FILES; do dsn_of "$f"; done | sort -u)

job() {
  echo "//MELUPLD  JOB (1),'UPLOAD',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),"
  if [ $DRY = 1 ]; then echo "//         USER=<MFUSER>,PASSWORD=<MFPASS>"
  else echo "//         USER=$MFUSER,PASSWORD=$MFPASS"; fi
  echo "//ALLOC    EXEC PGM=IEFBR14"
  n=0
  for d in $LIBS; do
    n=$((n+1))
    echo "//L$n       DD DSN=$d,DISP=(MOD,CATLG),UNIT=SYSDA,"
    echo "//         SPACE=(TRK,(15,10,15)),DCB=(RECFM=FB,LRECL=80,BLKSIZE=3120)"
  done
  n=0
  for f in $FILES; do
    n=$((n+1))
    echo "//M$n       EXEC PGM=IEBGENER"
    echo "//SYSPRINT DD SYSOUT=A"
    echo "//SYSIN    DD DUMMY"
    echo "//SYSUT2   DD DSN=$(dsn_of "$f")($(member_of "$f")),DISP=OLD"
    echo "//SYSUT1   DD DATA,DLM=QQ"
    cat "$f"
    echo "QQ"
  done
  echo "//"
}

COUNT=$(echo "$FILES" | wc -l)
if [ $DRY = 1 ]; then
  job
else
  job | nc -q1 "$MFHOST" 3505
  echo "sent $COUNT members to $(echo "$LIBS" | wc -l) libraries as $MFUSER:" >&2
fi
for f in $FILES; do echo "  $(dsn_of "$f")($(member_of "$f"))"; done >&2

if [ $BUILD = 1 ]; then
  JOBS=""
  for want in "COBOL setup" "ASM melscr" "CLIST cmdproc"; do
    lib=MELODY.SOURCE.${want%% *}
    if echo "$LIBS" | grep -qx "$lib"; then JOBS="$JOBS ${want##* }"; fi
  done
  for j in $JOBS; do
    jf=melody/source/cntl/$j.jcl
    if [ $DRY = 1 ]; then echo "would run MELODY.SOURCE.CNTL($(echo $j | tr a-z A-Z)) ($jf)" >&2; continue; fi
    sleep "${MFWAIT:-10}"
    { head -1 "$jf" | sed 's/$/,/'
      echo "//         USER=$MFUSER,PASSWORD=$MFPASS"
      tail -n +2 "$jf"; } | nc -q1 "$MFHOST" 3505
    echo "sent build job $j as $MFUSER" >&2
  done
  [ -n "$JOBS" ] || echo "nothing to build for these files" >&2
fi
