#!/usr/bin/env bash
# formal.sh -- run every SymbiYosys (sby) formal task under
# verification/formal/**/*.sby.
#
# HONESTY NOTE: no formal toolchain (yosys/sby) was available in the
# environment this repository's tooling was authored in. This script is
# written correctly against sby's real CLI and exit-code contract, but has
# NOT itself been run against a working sby install -- unlike lint.sh and
# sim.sh, which were both exercised against real files with real tools
# before being delivered. Run it yourself once sby is installed and treat
# the first real run as this script's actual verification, not this
# comment.
#
# Usage: scripts/formal.sh [task.sby ...]
#   No args: discovers and runs every verification/formal/**/*.sby file.
#   With args: runs exactly the given .sby files.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v sby >/dev/null 2>&1; then
  echo "formal.sh: sby (SymbiYosys) not found on PATH." >&2
  echo "           No formal verification was run. This is not a pass --" >&2
  echo "           it is an unrun check. Install yosys+sby before trusting" >&2
  echo "           any formal claim about this repository." >&2
  exit 2
fi

if [ $# -gt 0 ]; then
  TASKS="$@"
else
  TASKS=$(find verification/formal -name '*.sby' 2>/dev/null | sort)
fi

if [ -z "$TASKS" ]; then
  echo "formal.sh: no .sby task files found under verification/formal/" >&2
  exit 2
fi

TOTAL=0
FAILED=0
FAILED_LIST=()

for task in $TASKS; do
  dir=$(dirname "$task")
  name=$(basename "$task" .sby)
  echo "== formal.sh: $task =="
  # Run every [tasks] section defined in the .sby file (e.g. bmc, prove),
  # not just the default, since a task file may define more than one and
  # RTL-STD-002 SS29 expects both BMC depth coverage and inductive proof
  # where applicable.
  TASK_NAMES=$(grep -A100 '^\[tasks\]' "$task" 2>/dev/null | \
               awk '/^\[/{if(NR>1)exit} /^[a-zA-Z]/{print $1}' || true)
  if [ -z "$TASK_NAMES" ]; then
    TASK_NAMES="default"
  fi
  for tn in $TASK_NAMES; do
    TOTAL=$((TOTAL+1))
    echo "  -- task: $tn --"
    if (cd "$dir" && sby -f "$(basename "$task")" "$tn"); then
      echo "  PASS: $task [$tn]"
    else
      echo "  FAIL: $task [$tn]"
      FAILED=$((FAILED+1))
      FAILED_LIST+=("$task [$tn]")
    fi
  done
  echo ""
done

echo "=================================================="
echo "formal.sh: $TOTAL task(s) run, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  echo "Failed:"
  for f in "${FAILED_LIST[@]}"; do echo "  - $f"; done
  exit 1
fi
echo "formal.sh: ALL PASSED"
exit 0
