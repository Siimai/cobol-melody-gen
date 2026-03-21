#!/usr/bin/env bash
# tests/smoke.sh
#
# Non-interactive smoke test for the COBOL Melody Generator.
#
# Checks:
#   1. cobc (GnuCOBOL) is available
#   2. make build succeeds
#   3. melody-gen binary exists and is executable
#   4. App produces output when driven with a scripted session
#   5. An output file is created with expected content shape
#
# Run from the project root:
#   bash tests/smoke.sh
# ------------------------------------------------------------

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0

ok()   { echo "  [PASS] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo ""
echo "========================================="
echo "  COBOL Melody Generator – Smoke Test"
echo "========================================="

# ----- 1. Toolchain ------------------------------------------
echo ""
echo "1. Checking GnuCOBOL toolchain..."
if command -v cobc &>/dev/null; then
    VERSION=$(cobc --version 2>&1 | head -1)
    ok "cobc found: $VERSION"
else
    fail "cobc not found. Run: make install-deps"
fi

# ----- 2. Build ----------------------------------------------
echo ""
echo "2. Building the project..."
if make --silent 2>&1; then
    ok "make succeeded"
else
    fail "make failed – check compiler output above"
fi

# ----- 3. Binary exists --------------------------------------
echo ""
echo "3. Checking binary..."
if [[ -x "$ROOT/melody-gen" ]]; then
    ok "melody-gen binary is present and executable"
else
    fail "melody-gen binary not found or not executable"
fi

# ----- 4. Scripted session -----------------------------------
# Drive the app through the menu via piped input:
#   1 → select scale (prompt), 1 → C Major
#   2 → generate melody
#   3 → view melody, <enter> → satisfy the pause
#   4 → save melody (text)
#   5 → export as MIDI
#   6 → exit
echo ""
echo "4. Running scripted session (generate → view → save → MIDI → exit)..."
SESSION_OUT=$(printf '1\n1\n2\n3\n\n4\n5\n6\n' | "$ROOT/melody-gen" 2>&1 || true)

if echo "$SESSION_OUT" | grep -q "COBOL MELODY GENERATOR"; then
    ok "Menu banner displayed"
else
    fail "Menu banner not found in output"
fi

if echo "$SESSION_OUT" | grep -q "Scale:"; then
    ok "Scale line displayed"
else
    fail "Scale line not found in output"
fi

if echo "$SESSION_OUT" | grep -q "Saved to"; then
    ok "Save confirmation message displayed"
else
    fail "Save confirmation not found in output"
fi

if echo "$SESSION_OUT" | grep -q "MIDI saved to"; then
    ok "MIDI export confirmation message displayed"
else
    fail "MIDI export confirmation not found in output"
fi

if echo "$SESSION_OUT" | grep -q "Goodbye"; then
    ok "Goodbye message on exit"
else
    fail "Goodbye message not found"
fi

# ----- 5. MIDI output file -----------------------------------
echo ""
echo "5. Checking MIDI output file..."
MIDIFILE=$(ls -1t "$ROOT/output"/melody_*.mid 2>/dev/null | head -1 || true)
if [[ -n "$MIDIFILE" ]]; then
    ok "MIDI file created: ${MIDIFILE##$ROOT/}"

    # A valid MIDI file always starts with the 'MThd' magic bytes
    MAGIC=$(head -c 4 "$MIDIFILE" 2>/dev/null || true)
    if [[ "$MAGIC" == "MThd" ]]; then
        ok "MIDI file has valid MThd header"
    else
        fail "MIDI file missing MThd header (got: $MAGIC)"
    fi

    MIDI_SIZE=$(wc -c < "$MIDIFILE" | tr -d ' ')
    if [[ "$MIDI_SIZE" -ge 30 ]]; then
        ok "MIDI file has plausible size (${MIDI_SIZE} bytes)"
    else
        fail "MIDI file is suspiciously small (${MIDI_SIZE} bytes)"
    fi
else
    fail "No output/melody_*.mid file found after MIDI export"
fi

# ----- 6. Text output file -----------------------------------
echo ""
echo "6. Checking text output file..."
OUTFILE=$(ls -1t "$ROOT/output"/melody_*.txt 2>/dev/null | head -1 || true)
if [[ -n "$OUTFILE" ]]; then
    ok "Output file created: ${OUTFILE##$ROOT/}"

    if grep -q "Scale:" "$OUTFILE"; then
        ok "Output file contains Scale header"
    else
        fail "Output file missing Scale header"
    fi

    NOTE_LINES=$(grep -cE '[A-G][# ][45][WHEQ]' "$OUTFILE" || true)
    if [[ "$NOTE_LINES" -ge 1 ]]; then
        ok "Output file contains note data ($NOTE_LINES line(s))"
    else
        fail "Output file appears to have no note data"
    fi
else
    fail "No output/melody_*.txt file found after save"
fi

# ----- Summary -----------------------------------------------
echo ""
echo "========================================="
TOTAL=$((PASS + FAIL))
echo "  Results: $PASS/$TOTAL passed"
if [[ "$FAIL" -eq 0 ]]; then
    echo "  ALL CHECKS PASSED"
    echo "========================================="
    exit 0
else
    echo "  $FAIL CHECK(S) FAILED"
    echo "========================================="
    exit 1
fi
