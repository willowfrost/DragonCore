# gate.ps1 -- THE ARBITER. Nothing is "done" until this returns 0.
# PowerShell port + redesign of gate.sh.
#
# REDESIGN NOTE: the prior gate.sh passed a module-ID argument (e.g.
# "RTL-001") to lint.sh/sim.sh/check_coverage.py, on the assumption each
# accepted a per-module filter. None of them actually do: lint.sh/lint.ps1
# take directory PATHS, sim.sh/sim.ps1 take testbench FILE paths, and
# check_coverage.py's argparse defines no positional argument at all.
# gate.sh would therefore fail or misbehave the first time it was
# actually run -- confirmed by reading its logic against the real scripts
# rather than assuming it worked because it looked plausible.
#
# Fix: run every check against the FULL repo, every time. This also
# better matches the project's current state -- with only RTL-001 and the
# SPI bridge implemented (everything else is spec-only or a labeled
# stub), there is no meaningful "lint only module X" boundary yet. If
# per-module filtering becomes genuinely useful once more modules are
# real, add an explicit -Module parameter to lint.ps1/sim.ps1 at that
# point rather than assuming an unbuilt capability exists.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\gate.ps1
#
# UPDATED: now runs scripts\regenerate.ps1 as its mandatory first step
# (items #7/#8 of the project's own punch list -- a build should not
# depend on a person remembering to manually rerun the extractors after
# editing a specification document). Confirmed this gap was real, not
# hypothetical: the extractors were tested against this project's actual
# current REG-002.md and found the committed generated files were stale
# (314 vs. the real, current 353 registers) before this step existed.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "############ GATE ############"

Write-Host "== regenerate.ps1: dependency-staleness check =="
& powershell -ExecutionPolicy Bypass -File "scripts\regenerate.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "gate.ps1: regenerate.ps1 failed"; exit 1 }
Write-Host ""

& powershell -ExecutionPolicy Bypass -File "scripts\lint.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "gate.ps1: lint.ps1 failed"; exit 1 }

& powershell -ExecutionPolicy Bypass -File "scripts\sim.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "gate.ps1: sim.ps1 failed"; exit 1 }

# formal.ps1 exits 2 (not 1) when sby is genuinely unavailable -- that is
# an unrun check, not a failed one (see formal.ps1's own header). Gate
# treats exit 2 as a WARNING, not a gate failure, since no formal
# toolchain has been available in any environment this project has run
# in yet; treat exit 1 (an actual formal FAILURE) as a real gate failure.
& powershell -ExecutionPolicy Bypass -File "scripts\formal.ps1"
$FormalExit = $LASTEXITCODE
if ($FormalExit -eq 1) {
    Write-Error "gate.ps1: formal.ps1 reported a real failure"
    exit 1
} elseif ($FormalExit -eq 2) {
    Write-Host "gate.ps1: WARNING -- formal.ps1 could not run (no sby on PATH); not a gate failure"
}

Write-Host "== coverage closure vs requirement matrix =="
# FIXED: was hardcoded to `python3` -- confirmed via a real run that this
# fails on Windows with a misleading Microsoft-Store-redirect message
# rather than a normal "not found" error (a known Windows App Execution
# Alias artifact: `python3.exe`/`python.exe` are pre-registered stub
# redirects to the Store when no real Python is found under that EXACT
# name). Official Windows Python installs register `python`, not
# `python3` -- that convention is Linux/Mac-specific. Check for either
# real interpreter explicitly, matching the same honest tool-availability
# discipline used throughout this project's other scripts, rather than
# assume one specific binary name is correct.
$PythonCmd = $null
foreach ($candidate in @("python", "python3")) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found -and $found.Source -notmatch "WindowsApps") {
        $PythonCmd = $candidate
        break
    }
}
if (-not $PythonCmd) {
    Write-Error "gate.ps1: no real Python interpreter found (checked 'python' and 'python3' -- only a Microsoft Store redirect stub was found, if anything). Install Python and ensure it's on PATH before trusting this gate's coverage check."
    exit 2
}
& $PythonCmd "scripts\check_coverage.py"
if ($LASTEXITCODE -ne 0) { Write-Error "gate.ps1: check_coverage.py failed"; exit 1 }

Write-Host "############ GATE PASSED ############"
exit 0
