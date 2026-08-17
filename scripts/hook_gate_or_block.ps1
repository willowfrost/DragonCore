# hook_gate_or_block.ps1 -- Stop hook. Block session end unless the gate
# is green.
#
# SIMPLIFICATION NOTE: same as hook_lint_changed.ps1 -- module-ID
# filtering was never actually implemented by the underlying scripts;
# this now just runs the full gate.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot
& powershell -ExecutionPolicy Bypass -File "scripts\gate.ps1"
if ($LASTEXITCODE -eq 0) {
    exit 0
} else {
    Write-Error "Gate RED -- not done. Keep going: fix RTL or checkers until green."
    exit 2   # non-zero = do not allow stop (confirm block-semantics for your CC version)
}
