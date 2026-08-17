# hook_guard_paths.ps1 -- PreToolUse guard. Reads the tool-call JSON on
# stdin, extracts the target path, blocks writes to protected trees.
# Exit 2 to block (per Claude Code's hook protocol).
#
# PATH-CORRECTION NOTE: the prior hook_guard_paths.sh checked for
# "*/spec/*" and "*/rtl/generated/*" -- neither pattern matches this
# project's REAL tree (specs live under docs/, generated RTL lives under
# rtl/*/generated/ with an extra path segment, e.g.
# rtl/infrastructure/generated/). As written, that hook never actually
# fired for any real file in this repository -- confirmed by checking the
# glob against the real directory names, not by assuming it worked.
# Corrected below to match the actual tree.
$ErrorActionPreference = "Stop"

$PayloadRaw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($PayloadRaw)) { exit 0 }

# crude path extraction, same approach as the .sh version -- adapt if
# your Claude Code version's hook JSON shape differs
$Match = [regex]::Match($PayloadRaw, '"(file_path|path)"\s*:\s*"([^"]+)"')
if (-not $Match.Success) { exit 0 }
$Target = $Match.Groups[2].Value -replace '\\\\', '\'

function Block($reason) {
    Write-Error "BLOCKED: $reason"
    exit 2
}

# Frozen specification baseline -- docs/ (business/requirements/
# architecture/rtl_specs/verification/software), never hand-edited by an
# implementation session.
if ($Target -match '(^|[\\/])docs[\\/]') {
    Block "docs/ is the frozen specification baseline -- do not edit directly"
}

# Machine-generated RTL/packages -- rtl/*/generated/ (any domain, e.g.
# rtl/infrastructure/generated/, future rtl/monitoring/generated/, etc.)
# and include/ (the shared dfc_*_pkg.sv packages). Fix the generator or
# its input JSON, then regenerate -- never hand-patch the output.
if ($Target -match '(^|[\\/])rtl[\\/][^\\/]+[\\/]generated[\\/]' -or $Target -match '(^|[\\/])include[\\/]') {
    Block "this path is machine-generated -- edit the generator input, not the output"
}

# Verifier-independence wall: if this session is the spec-verifier agent,
# it must stay blind to hand-authored implementation (rtl/*/src/ and
# rtl/top/), so it can only ever check specs against generated output,
# never peek at how a module was actually implemented.
if ($env:CLAUDE_AGENT_NAME -eq "spec-verifier") {
    if ($Target -match '(^|[\\/])rtl[\\/][^\\/]+[\\/]src[\\/]' -or $Target -match '(^|[\\/])rtl[\\/]top[\\/]') {
        Block "spec-verifier must stay blind to the implementation"
    }
}

exit 0
