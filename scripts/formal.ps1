# formal.ps1 -- run every SymbiYosys (sby) formal task under
# verification/formal/**/*.sby. PowerShell port of formal.sh.
#
# HONESTY NOTE: same as the .sh version -- no formal toolchain (sby) has
# been available in any environment this project's tooling was authored
# or tested in. This script is written correctly against sby's documented
# CLI/exit-code contract but has NOT itself been run against a working
# sby install. Treat the first real run as this script's actual
# verification.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\formal.ps1 [task.sby ...]
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if (-not (Get-Command sby -ErrorAction SilentlyContinue)) {
    Write-Host "formal.ps1: sby (SymbiYosys) not found on PATH." -ForegroundColor Yellow
    Write-Host "            No formal verification was run. This is not a pass --"
    Write-Host "            it is an unrun check. Install yosys+sby before trusting"
    Write-Host "            any formal claim about this repository."
    exit 2
}

if ($args.Count -gt 0) {
    $Tasks = $args
} else {
    # Exclude sby's own generated working directories (<basename>_<taskname>/,
    # e.g. dri_one_outstanding_bmc/, dri_one_outstanding_prove/) -- confirmed
    # via a real run that a naive recursive search finds sby's own internal
    # config.sby inside these and tries to run it as a separate top-level
    # task, which always fails ("Task name 'default' didn't match any lines
    # in [tasks]") since that's not what those files are. Same four standard
    # SymbiYosys mode-suffix directories already excluded in .gitignore.
    $Tasks = Get-ChildItem -Path "verification\formal" -Recurse -Filter "*.sby" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(_bmc|_prove|_cover|_live)[\\/]' } |
        Select-Object -ExpandProperty FullName
}

if (-not $Tasks -or $Tasks.Count -eq 0) {
    Write-Error "formal.ps1: no .sby task files found under verification\formal\"
    exit 2
}

$Total = 0
$Failed = 0
$FailedList = @()

foreach ($task in $Tasks) {
    $dir = Split-Path -Parent $task
    $base = [System.IO.Path]::GetFileName($task)
    Write-Host "== formal.ps1: $task =="

    $TaskNames = @()
    $inTasksSection = $false
    foreach ($line in (Get-Content $task)) {
        if ($line -match '^\[tasks\]') { $inTasksSection = $true; continue }
        if ($inTasksSection -and $line -match '^\[') { break }
        if ($inTasksSection -and $line -match '^[a-zA-Z]') {
            $TaskNames += ($line -split '\s+')[0]
        }
    }
    if ($TaskNames.Count -eq 0) { $TaskNames = @("default") }

    foreach ($tn in $TaskNames) {
        $Total++
        Write-Host "  -- task: $tn --"
        Push-Location $dir
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        # cmd /c redirection, not a bare `& sby` call -- see lint.ps1's
        # header note: $ErrorActionPreference="Continue" alone does not
        # reliably suppress NativeCommandError when the tool genuinely
        # errors. Output is captured then displayed immediately after
        # (not real-time), trading that for reliable error handling.
        $SbyLog = [System.IO.Path]::GetTempFileName()
        cmd /c "sby -f `"$base`" $tn > `"$SbyLog`" 2>&1"
        $sbyExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP
        Get-Content $SbyLog | ForEach-Object { Write-Host "    $_" }
        Remove-Item $SbyLog -ErrorAction SilentlyContinue
        Pop-Location
        if ($sbyExit -eq 0) {
            Write-Host "  PASS: $task [$tn]"
        } else {
            Write-Host "  FAIL: $task [$tn]"
            $Failed++
            $FailedList += "$task [$tn]"
        }
    }
    Write-Host ""
}

Write-Host "=================================================="
Write-Host "formal.ps1: $Total task(s) run, $Failed failed"
if ($Failed -gt 0) {
    Write-Host "Failed:"
    foreach ($f in $FailedList) { Write-Host "  - $f" }
    exit 1
}
Write-Host "formal.ps1: ALL PASSED"
exit 0
