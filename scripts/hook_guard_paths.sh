#!/usr/bin/env bash
# PreToolUse guard. Reads the tool-call JSON on stdin, extracts the target path,
# and blocks writes to protected trees. Exit 2 (or emit a deny decision per your
# CC version's protocol) to block.
set -euo pipefail
PAYLOAD="$(cat)"
# crude path extraction; adapt to your CC hook payload shape
TARGET="$(printf '%s' "$PAYLOAD" | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*:"([^"]+)"/\1/')"
[ -n "${TARGET:-}" ] || exit 0

block() { echo "BLOCKED: $1" >&2; exit 2; }

case "$TARGET" in
  */spec/*)          block "/spec is frozen baseline — do not edit" ;;
  */rtl/generated/*) block "/rtl/generated is machine-generated — edit the generator input, not the output" ;;
esac

# Verifier-independence wall: if this session is the spec-verifier, deny /rtl/src.
if [ "${CLAUDE_AGENT_NAME:-}" = "spec-verifier" ]; then
  case "$TARGET" in
    */rtl/src/*) block "spec-verifier must stay blind to the implementation" ;;
  esac
fi
exit 0
