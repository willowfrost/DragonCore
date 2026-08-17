# hook_lint_changed.ps1 -- PostToolUse. Lint after any edit. Non-blocking-
# friendly: prints failures so the model sees them next turn.
#
# SIMPLIFICATION NOTE: the prior version passed $env:ACTIVE_MODULE (e.g.
# "RTL-001") to lint.sh as a filter argument -- lint.sh/lint.ps1 never
# actually implemented per-module filtering, so that argument did nothing
# useful. Runs the full lint check every time instead, matching gate.ps1's
# same full-repo redesign.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot
& powershell -ExecutionPolicy Bypass -File "scripts\lint.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "LINT FAILED -- fix before continuing."
}
