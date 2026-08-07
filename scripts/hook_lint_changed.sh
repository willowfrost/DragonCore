#!/usr/bin/env bash
# PostToolUse. Lint the active module after any edit. Non-blocking-friendly:
# prints failures so the model sees them next turn.
set -uo pipefail
MOD="${ACTIVE_MODULE:-RTL-001}"
scripts/lint.sh "$MOD" || echo "LINT FAILED for $MOD — fix before continuing."
