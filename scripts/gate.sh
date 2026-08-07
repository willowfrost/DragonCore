#!/usr/bin/env bash
# THE ARBITER. Nothing is "done" until this returns 0.
# Wired to the Claude Code Stop hook so a session cannot end on red.
# Usage: scripts/gate.sh RTL-001
set -euo pipefail
MOD="${1:?usage: gate.sh <module-id>}"

echo "############ GATE: $MOD ############"
scripts/lint.sh   "$MOD"
scripts/sim.sh    "$MOD"
scripts/formal.sh "$MOD"

# Coverage closure: require every allocated requirement to have been exercised.
# (Icarus emits per-TB logs; this checks each VP-CASE in the matrix produced a
#  pass line. Replace with your coverage-merge step if you add one.)
echo "== coverage closure vs requirement matrix =="
python3 scripts/check_coverage.py "$MOD"

echo "############ GATE PASSED: $MOD ############"
