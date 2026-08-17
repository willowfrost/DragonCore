# lint.ps1 -- static conformance checks per RCA-DFC-RTL-STD-002 SS30-31.
# PowerShell port of lint.sh -- .sh versions are retired per project
# decision (Windows is the sole active development platform; bash is
# confirmed unavailable in a plain terminal here). Recreate a .sh version
# only if development ever actually moves to Linux -- do not maintain
# both in parallel indefinitely.
#
# What this checks (mechanical only -- no vendor lint tool assumed):
#   1. Every .sv file under include/ and rtl/ compiles/elaborates with
#      Icarus Verilog.
#   2. RTLSTD-QA-004: no undisclosed TODO/FIXME/stub marker (a file whose
#      own header says SKELETON/bring-up/NOT YET IMPLEMENTED gets a
#      warning instead of a failure for the same marker).
#   3. RTLSTD-ORG-001: filename matches its primary module name.
#   4. RTLSTD-LANG-008: no wildcard package imports (`import pkg::*;`)
#      anywhere under include/ or rtl/. This check exists specifically
#      because this exact pattern has been reintroduced multiple times
#      across this project's history -- by a generator regressing, and
#      by ordinary hand-authored SystemVerilog convention (a wildcard
#      import is completely normal SV style; it's only wrong here because
#      Yosys's frontend cannot parse it, confirmed on two versions). This
#      check exists so it's caught at lint time regardless of *how* it
#      gets reintroduced, rather than being rediscovered at synthesis time
#      each time, as happened repeatedly before this check existed.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\lint.ps1 [paths...]
#   No args: checks include/ and rtl/.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Targets = if ($args.Count -gt 0) { $args } else { @("include", "rtl") }
$Fail = 0
$Warn = 0

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    Write-Error "lint.ps1: iverilog not found on PATH -- cannot run compile/elaborate checks."
    exit 2
}

Write-Host "== lint.ps1: compile/elaborate check (RTLSTD-QA-001 subset) =="
$SvFiles = @()
foreach ($t in $Targets) {
    if (Test-Path $t) {
        $SvFiles += Get-ChildItem -Path $t -Recurse -Filter "*.sv" -File | Select-Object -ExpandProperty FullName
    }
}
if ($SvFiles.Count -eq 0) {
    Write-Error "lint.ps1: no .sv files found under: $($Targets -join ', ')"
    exit 2
}

$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$LintLog = [System.IO.Path]::GetTempFileName()
# NOTE (found via a real failed run, not assumed): $ErrorActionPreference =
# "Continue" alone does NOT reliably suppress PowerShell's NativeCommandError
# wrapping when the invoked tool exits with a genuine nonzero/error status --
# it only worked for benign, exit-0 informational stderr lines (confirmed
# separately in build_ecp5.ps1). Routing through cmd /c instead avoids
# PowerShell's own stream-object wrapping entirely, since cmd.exe performs
# the redirection at the OS/shell level rather than via PowerShell's
# stream records. This is the standard, documented workaround for this
# exact PowerShell 5.1 behavior with native executables.
$QuotedFiles = ($SvFiles | ForEach-Object { '"' + $_ + '"' }) -join ' '
cmd /c "iverilog -g2012 -t null $QuotedFiles > `"$LintLog`" 2>&1"
$IVerilogExit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP

$LintLogContent = Get-Content $LintLog -Raw
if ($IVerilogExit -ne 0 -or ($LintLogContent -match "(?i)syntax error|error:")) {
    Write-Host "lint.ps1: iverilog reported errors:"
    Write-Host $LintLogContent
    $Fail = 1
} else {
    Write-Host "lint.ps1: compile/elaborate OK ($($SvFiles.Count) files)"
}
Remove-Item $LintLog -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "== lint.ps1: RTLSTD-LANG-008 wildcard-import scan =="
$WildcardHits = @()
foreach ($f in $SvFiles) {
    $matches = Select-String -Path $f -Pattern '^\s*import\s+\S+::\*\s*;'
    if ($matches) {
        $WildcardHits += $f
        Write-Host "FAIL (RTLSTD-LANG-008, wildcard import -- fails real Yosys synthesis): $f"
        foreach ($m in $matches) { Write-Host "    line $($m.LineNumber): $($m.Line.Trim())" }
        $Fail = 1
    }
}
if ($WildcardHits.Count -eq 0) {
    Write-Host "lint.ps1: no wildcard package imports found"
}

Write-Host ""
Write-Host "== lint.ps1: RTLSTD-QA-004 stub/TODO/tie-off scan =="
$AnyStubHits = $false
foreach ($f in $SvFiles) {
    $header = (Get-Content $f -TotalCount 20) -join "`n"
    $isSkeleton = $header -match "(?i)SKELETON|bring-up|NOT YET IMPLEMENTED"
    $hits = Select-String -Path $f -Pattern "(?i)TODO|FIXME|XXX:"
    if ($hits) {
        $AnyStubHits = $true
        if ($isSkeleton) {
            Write-Host "WARN (disclosed skeleton): $f"
            foreach ($h in $hits) { Write-Host "    $($h.Line.Trim())" }
            $Warn = 1
        } else {
            Write-Host "FAIL (undisclosed stub marker, RTLSTD-QA-004): $f"
            foreach ($h in $hits) { Write-Host "    $($h.Line.Trim())" }
            $Fail = 1
        }
    }
}
if (-not $AnyStubHits) { Write-Host "lint.ps1: no stub/TODO markers found" }

Write-Host ""
Write-Host "== lint.ps1: RTLSTD-ORG-001 filename/module-name check =="
foreach ($f in $SvFiles) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f)
    $modMatch = Select-String -Path $f -Pattern '^\s*module\s+([A-Za-z_][A-Za-z0-9_]*)' | Select-Object -First 1
    if (-not $modMatch) { continue }  # package-only file
    $mod = $modMatch.Matches[0].Groups[1].Value
    if ($mod -ne $base) {
        Write-Host "WARN: $f -- module '$mod' does not match filename '$base' (RTLSTD-ORG-001)"
        $Warn = 1
    }
}

Write-Host ""
if ($Fail -ne 0) {
    Write-Host "lint.ps1: FAILED"
    exit 1
} elseif ($Warn -ne 0) {
    Write-Host "lint.ps1: PASSED WITH WARNINGS (RTLSTD-QA-002: warnings are findings until resolved/justified)"
    exit 0
} else {
    Write-Host "lint.ps1: PASSED"
    exit 0
}
