#!/usr/bin/env bash
# sim.sh -- compile and run every testbench under verification/testbench/
# with Icarus Verilog, aggregate pass/fail, exit nonzero on any failure.
#
# Each testbench directory (verification/testbench/<module>/) is compiled
# against include/*.sv, rtl/infrastructure/generated/*.sv, and any
# rtl/**/*.sv it needs. Compile order follows RTLSTD-ORG-009 (packages
# before consumers, explicit and deterministic) by always feeding
# dfc_constants_pkg.sv and dfc_registers_pkg.sv first.
#
# This script does NOT compute coverage (see check_coverage.py) and does
# NOT run formal properties (see formal.sh). It runs dynamic simulation
# testbenches only.
#
# Usage: scripts/sim.sh [testbench.sv ...]
#   No args: discovers and runs every verification/testbench/**/*.sv file
#            whose name ends in _tb.sv.
#   With args: runs exactly the given testbench files.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v iverilog >/dev/null 2>&1 || {
  echo "sim.sh: iverilog not found on PATH." >&2
  exit 2
}
command -v vvp >/dev/null 2>&1 || {
  echo "sim.sh: vvp not found on PATH." >&2
  exit 2
}

PKG_FILES=$(find include -name '*.sv' 2>/dev/null | sort)
RTL_FILES=$(find rtl -name '*.sv' 2>/dev/null | sort)

if [ $# -gt 0 ]; then
  TBS="$@"
else
  TBS=$(find verification/testbench -name '*_tb.sv' 2>/dev/null | sort)
fi

if [ -z "$TBS" ]; then
  echo "sim.sh: no testbenches found under verification/testbench/" >&2
  exit 2
fi

TOTAL=0
FAILED=0
FAILED_LIST=()

for tb in $TBS; do
  TOTAL=$((TOTAL+1))
  echo "== sim.sh: $tb =="
  OUT=$(mktemp)
  BIN=$(mktemp)
  if ! iverilog -g2012 -o "$BIN" $PKG_FILES $RTL_FILES "$tb" > "$OUT" 2>&1; then
    echo "  COMPILE FAILED:"
    sed 's/^/    /' "$OUT"
    FAILED=$((FAILED+1))
    FAILED_LIST+=("$tb (compile)")
    rm -f "$OUT" "$BIN"
    continue
  fi
  # Icarus's iverilog itself prints benign informational lines (e.g. "sorry:
  # Case unique/unique0 qualities are ignored") to stdout during vvp's own
  # compile step in some versions; only fail on an explicit runtime error.
  RUN_OUT=$(mktemp)
  if ! vvp "$BIN" > "$RUN_OUT" 2>&1; then
    echo "  SIMULATION CRASHED:"
    sed 's/^/    /' "$RUN_OUT"
    FAILED=$((FAILED+1))
    FAILED_LIST+=("$tb (crash)")
  else
    cat "$RUN_OUT" | sed 's/^/  /'
    # vvp does not propagate $finish()'s argument as a process exit code
    # (confirmed empirically -- it always exits 0), so pass/fail is
    # determined from the testbench's own final marker line. Every
    # testbench in this repo prints exactly one of these two forms.
    if grep -qE "FAILED$|^FAIL:|TEST FAILED" "$RUN_OUT"; then
      FAILED=$((FAILED+1))
      FAILED_LIST+=("$tb (test failure)")
    elif ! grep -qE "PASSED" "$RUN_OUT"; then
      echo "  WARNING: no PASSED/FAILED marker found -- cannot confirm result"
      FAILED=$((FAILED+1))
      FAILED_LIST+=("$tb (no result marker)")
    fi
  fi
  rm -f "$OUT" "$BIN" "$RUN_OUT"
  echo ""
done

echo "=================================================="
echo "sim.sh: $TOTAL testbench(es) run, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  echo "Failed:"
  for f in "${FAILED_LIST[@]}"; do echo "  - $f"; done
  exit 1
fi
echo "sim.sh: ALL PASSED"
exit 0
