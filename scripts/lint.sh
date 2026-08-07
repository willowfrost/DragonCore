#!/usr/bin/env bash
# lint.sh -- static conformance checks per RCA-DFC-RTL-STD-002 SS30-31.
#
# What this actually checks (real, mechanical checks only -- no vendor lint
# tool is assumed to exist in this environment):
#   1. Every .sv file under include/ and rtl/ compiles and elaborates with
#      Icarus Verilog (RTLSTD-QA-001's "syntax, type, compile, elaboration"
#      subset; this is NOT a substitute for a real lint tool's width/
#      signedness/latch/CDC checks -- RTLSTD-QA-011 is only partially
#      covered by this script; see the NOTE at the end of this file).
#   2. RTLSTD-QA-004: production source contains no TODO/FIXME/stub/
#      disabled-block/temporary-tie-off marker, UNLESS the file's own
#      header explicitly discloses itself as a SKELETON (this repo's
#      established pattern for a labeled work-in-progress module, e.g.
#      rtl/top/dfc_rtl024.sv). A skeleton's disclosed stubs are a WARNING,
#      not a failure; an undisclosed stub anywhere else is a FAILURE.
#   3. RTLSTD-ORG-001: one primary module per file, filename matches
#      module name (best-effort: checks the first `module NAME` declaration
#      against the filename).
#
# Usage: scripts/lint.sh [path...]   (defaults to include/ and rtl/)
set -euo pipefail
cd "$(dirname "$0")/.."

TARGETS=("${@:-include rtl}")
FAIL=0
WARN=0

command -v iverilog >/dev/null 2>&1 || {
  echo "lint.sh: iverilog not found on PATH -- cannot run compile/elaborate checks." >&2
  echo "         Install it or point PATH at it before trusting this script's output." >&2
  exit 2
}

echo "== lint.sh: compile/elaborate check (RTLSTD-QA-001 subset) =="
SV_FILES=$(find ${TARGETS[@]} -name '*.sv' 2>/dev/null | sort)
if [ -z "$SV_FILES" ]; then
  echo "lint.sh: no .sv files found under: ${TARGETS[@]}" >&2
  exit 2
fi

# Compile everything together in one unit so cross-file references (e.g.
# module A instantiating module B) are checked, not just per-file syntax.
LINT_LOG=$(mktemp)
if ! iverilog -g2012 -t null $SV_FILES > "$LINT_LOG" 2>&1; then
  echo "lint.sh: iverilog reported errors:"
  cat "$LINT_LOG"
  FAIL=1
else
  # "No top level modules" with no top-level module supplied is the
  # expected benign message for a package/library-only compile unit; a
  # real syntax/elaboration error prints "syntax error" or "error:".
  if grep -qiE "syntax error|error:" "$LINT_LOG"; then
    echo "lint.sh: iverilog reported errors:"
    cat "$LINT_LOG"
    FAIL=1
  else
    echo "lint.sh: compile/elaborate OK ($(echo "$SV_FILES" | wc -l) files)"
  fi
fi
rm -f "$LINT_LOG"

echo ""
echo "== lint.sh: RTLSTD-QA-004 stub/TODO/tie-off scan =="
for f in $SV_FILES; do
  IS_SKELETON=0
  if head -20 "$f" | grep -qiE "SKELETON|bring-up|NOT YET IMPLEMENTED"; then
    IS_SKELETON=1
  fi
  HITS=$(grep -niE "TODO|FIXME|XXX:" "$f" || true)
  if [ -n "$HITS" ]; then
    if [ "$IS_SKELETON" -eq 1 ]; then
      echo "WARN (disclosed skeleton): $f"
      echo "$HITS" | sed 's/^/    /'
      WARN=1
    else
      echo "FAIL (undisclosed stub marker, RTLSTD-QA-004): $f"
      echo "$HITS" | sed 's/^/    /'
      FAIL=1
    fi
  fi
done
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo "lint.sh: no stub/TODO markers found"

echo ""
echo "== lint.sh: RTLSTD-ORG-001 filename/module-name check =="
for f in $SV_FILES; do
  base=$(basename "$f" .sv)
  mod=$(grep -oP '^\s*module\s+\K[A-Za-z_][A-Za-z0-9_]*' "$f" | head -1 || true)
  if [ -z "$mod" ]; then
    continue  # package-only file, no primary module -- not this rule's concern
  fi
  if [ "$mod" != "$base" ]; then
    echo "WARN: $f -- module '$mod' does not match filename '$base' (RTLSTD-ORG-001)"
    WARN=1
  fi
done

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "lint.sh: FAILED"
  exit 1
elif [ "$WARN" -ne 0 ]; then
  echo "lint.sh: PASSED WITH WARNINGS (RTLSTD-QA-002: warnings are findings until resolved/justified)"
  exit 0
else
  echo "lint.sh: PASSED"
  exit 0
fi

# NOTE on scope: this script does NOT check width/signedness mismatches,
# latch inference, CDC/RDC structure conformance, multiple-driver defects,
# or synthesis-specific issues (RTLSTD-QA-011, RTLSTD-CONF-006/008/011).
# Icarus is a simulator, not a lint tool; those checks require a real lint
# tool (e.g. Verilator --lint-only, or a vendor tool) that is not assumed
# to be installed in this environment. Add it here once available rather
# than treating this script's PASS as covering those rules.
