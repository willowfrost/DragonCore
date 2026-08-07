#!/usr/bin/env bash
# Stop hook. Block session end unless the gate is green.
set -uo pipefail
MOD="${ACTIVE_MODULE:-RTL-001}"
if scripts/gate.sh "$MOD"; then
  exit 0
else
  echo "Gate RED for $MOD — not done. Keep going: fix RTL or checkers until green." >&2
  exit 2   # non-zero = do not allow stop (confirm block-semantics for your CC version)
fi
