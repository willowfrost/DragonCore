# sim.ps1 -- compile and run every testbench under verification/testbench/
# with Icarus Verilog, aggregate pass/fail, exit nonzero on any failure.
# PowerShell port of sim.sh -- .sh retired per project decision.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\sim.ps1 [tb.sv ...]
#   No args: discovers every verification/testbench/**/*_tb.sv.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

foreach ($tool in @("iverilog", "vvp")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "sim.ps1: $tool not found on PATH."
        exit 2
    }
}

$PkgFiles = Get-ChildItem -Path "include" -Recurse -Filter "*.sv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$RtlFiles = Get-ChildItem -Path "rtl" -Recurse -Filter "*.sv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

if ($args.Count -gt 0) {
    $Tbs = $args
} else {
    $Tbs = Get-ChildItem -Path "verification\testbench" -Recurse -Filter "*_tb.sv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
}

if (-not $Tbs -or $Tbs.Count -eq 0) {
    Write-Error "sim.ps1: no testbenches found under verification\testbench\"
    exit 2
}

$Total = 0
$Failed = 0
$FailedList = @()

foreach ($tb in $Tbs) {
    $Total++
    Write-Host "== sim.ps1: $tb =="
    $Bin = [System.IO.Path]::GetTempFileName()
    $CompileLog = [System.IO.Path]::GetTempFileName()

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    # cmd /c redirection, not PowerShell's own *> -- see lint.ps1's header
    # note for why: $ErrorActionPreference="Continue" alone does not
    # reliably suppress NativeCommandError when the tool genuinely errors.
    $QuotedSrc = (($PkgFiles + $RtlFiles + $tb) | ForEach-Object { '"' + $_ + '"' }) -join ' '
    cmd /c "iverilog -g2012 -o `"$Bin`" $QuotedSrc > `"$CompileLog`" 2>&1"
    $CompileExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($CompileExit -ne 0) {
        Write-Host "  COMPILE FAILED:"
        Get-Content $CompileLog | ForEach-Object { Write-Host "    $_" }
        $Failed++
        $FailedList += "$tb (compile)"
        Remove-Item $Bin, $CompileLog -ErrorAction SilentlyContinue
        continue
    }

    $RunLog = [System.IO.Path]::GetTempFileName()
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    cmd /c "vvp `"$Bin`" > `"$RunLog`" 2>&1"
    $RunExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    $RunOutput = Get-Content $RunLog -Raw
    if ($RunExit -ne 0) {
        Write-Host "  SIMULATION CRASHED:"
        Write-Host $RunOutput
        $Failed++
        $FailedList += "$tb (crash)"
    } else {
        Write-Host $RunOutput
        # vvp does not propagate $finish()'s argument as a process exit
        # code (confirmed empirically -- always exits 0), so pass/fail
        # comes from the testbench's own final marker line.
        if ($RunOutput -match "FAILED$|^FAIL:|TEST FAILED") {
            $Failed++
            $FailedList += "$tb (test failure)"
        } elseif ($RunOutput -notmatch "PASSED") {
            Write-Host "  WARNING: no PASSED/FAILED marker found -- cannot confirm result"
            $Failed++
            $FailedList += "$tb (no result marker)"
        }
    }
    Remove-Item $Bin, $CompileLog, $RunLog -ErrorAction SilentlyContinue
    Write-Host ""
}

Write-Host "=================================================="
Write-Host "sim.ps1: $Total testbench(es) run, $Failed failed"
if ($Failed -gt 0) {
    Write-Host "Failed:"
    foreach ($f in $FailedList) { Write-Host "  - $f" }
    exit 1
}
Write-Host "sim.ps1: ALL PASSED"
exit 0
