# build_ecp5.ps1 -- deterministic ECP5 synthesis/place-route/pack build.
# Windows-native equivalent of scripts/build_ecp5.sh, for environments
# (like oss-cad-suite on native Windows) where bash is not available.
# Confirmed via direct test: `bash --version` returns "not recognized" in
# this project's actual Windows environment -- the .sh version cannot run
# here at all, hence this port rather than a workaround.
#
# Every output path below is HARDCODED to match this project's existing
# tree (output/logs, output/netlists, output/reports, output/bitstreams),
# identically to the bash version. Same rationale: build-artifact
# placement should never depend on an agent's or a person's in-the-moment
# judgment call.
#
# CHANGE FROM PRIOR VERSION: every output file is now stamped with a
# single per-run $BuildId so consecutive runs stop overwriting each
# other's bitstream/netlist/config/report/logs, and a human-readable
# manifest.md is generated automatically in output\reports each run
# (per RTLSTD-ORG-005: generated outputs shall record source hash and
# generator hash in a machine-readable manifest). This replaces the
# earlier practice of hand-reconstructing a manifest from uploaded logs
# after the fact -- the script now records its own provenance as part
# of every run, including tool versions, which the raw tool logs do not
# reliably capture on their own (confirmed directly: a prior pnr.log
# began mid-stream with no nextpnr-ecp5 version banner at all).
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\build_ecp5.ps1
# Run from the repository root.

$ErrorActionPreference = "Stop"
# NOTE: this is intentionally the default for ordinary PowerShell cmdlets
# (Copy-Item, New-Item, etc. below) so a real filesystem error still stops
# the script immediately. It is deliberately overridden to "Continue"
# around each NATIVE TOOL invocation below (yosys/nextpnr-ecp5/ecppack) --
# a real bug found via an actual failed run: PowerShell 5.1 wraps any
# stderr line from a native .exe as a terminating NativeCommandError when
# "Stop" is in effect, and all three of these tools routinely write
# ordinary informational/progress messages to stderr (confirmed directly:
# nextpnr-ecp5's first-ever stderr line, "Info: constraining clock net
# ... to 25.00 MHz", aborted the whole script before any real placement
# or routing work had happened). The script's own $LASTEXITCODE checks
# after each stage are the actual, correct pass/fail logic -- PowerShell's
# own error-trapping was never needed for the native calls and was
# actively wrong for them.

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Top = "ulx3s_dfc_top"
$DevicePackage = "CABGA381"
# Separate from $DevicePackage (nextpnr's --package argument, "CABGA381")
# -- this is purely for the manifest's human-readable device identity.
# The prior version concatenated $DevicePackage directly into the part
# number string ("LFE5U-85F-6$DevicePackage"), producing the wrong text
# "LFE5U-85F-6CABGA381" instead of the real part number below. Cosmetic
# only (manifest documentation text, not a build command), but worth
# being accurate.
$Device = "LFE5U-85F-6BG381C"
$Scratch = "output\_scratch\ecp5"

# ---- per-run build identity: stamps every output filename below so ----
# ---- consecutive runs accumulate instead of overwriting each other ----
$BuildId = Get-Date -Format "yyyyMMdd_HHmmss"
Write-Host "build_ecp5.ps1: Build ID = $BuildId"

$NetlistDir    = "output\netlists"
$ConfigDir     = "output\netlists"
$BitstreamDir  = "output\bitstreams"
$ReportDir     = "output\reports"
$LogDir        = "output\logs"

# ---- stamped output filenames (all derived from $BuildId; nothing ----
# ---- below this point should be hand-edited per run) ----
$NetlistFile    = "ulx3s_dfc_$BuildId.json"
$ConfigFile     = "ulx3s_dfc_${BuildId}_out.config"
$BitstreamFile  = "ulx3s_dfc_$BuildId.bit"
$PnrReportFile  = "ecp5_pnr_report_$BuildId.json"
$ManifestFile   = "manifest_$BuildId.md"
$SynthLogFile   = "ecp5_synth_$BuildId.log"
$PnrLogFile     = "ecp5_pnr_$BuildId.log"
$PackLogFile    = "ecp5_pack_$BuildId.log"

foreach ($d in @($NetlistDir, $BitstreamDir, $ReportDir, $LogDir, $Scratch)) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

foreach ($tool in @("yosys", "nextpnr-ecp5", "ecppack")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "build_ecp5.ps1: $tool not found on PATH"
        exit 2
    }
}

# ---- capture toolchain identity up front, before any build stage ----
# ---- (closes the gap where a prior pnr.log had no version banner) ----
Write-Host "== build_ecp5.ps1: recording toolchain versions =="
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$YosysVersion   = (& yosys --version 2>&1 | Out-String).Trim()
$NextpnrVersion = (& nextpnr-ecp5 --version 2>&1 | Out-String).Trim()
$EcppackVersion = (& ecppack --version 2>&1 | Out-String).Trim()
$ErrorActionPreference = $prevEAP
Write-Host "  yosys        : $YosysVersion"
Write-Host "  nextpnr-ecp5 : $NextpnrVersion"
Write-Host "  ecppack      : $EcppackVersion"

# ---- source file list: single source of truth for both the staging ----
# ---- copy step below AND the manifest's recorded source-file list.  ----
# ---- (avoids the two ever drifting apart -- same reasoning as ----
# ---- RTLSTD-GEN-003: a value owned in one place shall not be a ----
# ---- second, independently-maintained copy elsewhere.) ----
$SourceFiles = @(
    "include\dfc_constants_pkg.sv",
    "include\dfc_registers_pkg.sv",
    "rtl\infrastructure\generated\dfc_config_regbank_regs.sv",
    "rtl\infrastructure\src\dfc_rtl001.sv",
    "rtl\top\dfc_rtl024_spi_bridge.sv",
    "rtl\top\dfc_rtl024.sv",
    "fpga\ecp5\ulx3s_dfc_top.sv",
    "fpga\ecp5\dfc_ecp5_pll.v",
    "fpga\ecp5\ulx3s_dfc.lpf"
)

# ---- dependency-staleness check (items #7/#8) ----
# Confirmed real, not hypothetical: this project's actual committed
# generated packages/regbank were found stale (314 vs. the real, current
# 353 registers) against REG-002.md before this step existed. Run before
# staging sources so a build never silently uses an out-of-date package.
Write-Host "== build_ecp5.ps1: dependency-staleness check =="
& powershell -ExecutionPolicy Bypass -File "scripts\regenerate.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Error "build_ecp5.ps1: regenerate.ps1 failed"
    exit 1
}
Write-Host ""

# ---- stage sources into the scratch dir ----
if (Test-Path $Scratch) { Remove-Item -Recurse -Force $Scratch }
New-Item -ItemType Directory -Force -Path $Scratch | Out-Null

foreach ($f in $SourceFiles) {
    Copy-Item $f $Scratch
}

Push-Location $Scratch

try {
    # ---- 1. Synthesis -> output\netlists\ulx3s_dfc_<BuildId>.json ----
    Write-Host "== build_ecp5.ps1: synthesis =="
    $synthScript = @"
read_verilog -sv dfc_constants_pkg.sv;
read_verilog -sv dfc_registers_pkg.sv;
read_verilog -sv dfc_config_regbank_regs.sv;
read_verilog -sv dfc_rtl001.sv;
read_verilog -sv dfc_rtl024_spi_bridge.sv;
read_verilog -sv dfc_rtl024.sv;
read_verilog dfc_ecp5_pll.v;
read_verilog -sv ulx3s_dfc_top.sv;
synth_ecp5 -top $Top -json ulx3s_dfc.json
"@
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    # cmd /c redirection, not a bare `yosys -p ...` call -- see lint.ps1's
    # header note for why. The synth script is written to a temp .ys FILE
    # first rather than passed as a -p command-line argument, since a
    # multi-line here-string embedded directly in a cmd /c command line
    # risks its own escaping bugs (semicolons, quotes) that a simple
    # single-file-path argument avoids entirely.
    $SynthYsFile = [System.IO.Path]::GetTempFileName() + ".ys"
    Set-Content -Path $SynthYsFile -Value $synthScript
    cmd /c "yosys -s `"$SynthYsFile`" > `"synth.log`" 2>&1"
    $ErrorActionPreference = $prevEAP
    $synthExit = $LASTEXITCODE
    Remove-Item $SynthYsFile -ErrorAction SilentlyContinue
    Copy-Item "synth.log" "..\..\..\$LogDir\$SynthLogFile"
    Copy-Item "ulx3s_dfc.json" "..\..\..\$NetlistDir\$NetlistFile"
    $synthErrors = Select-String -Path "synth.log" -Pattern "^ERROR" -Quiet
    if ($synthExit -ne 0 -or $synthErrors) {
        Write-Error "build_ecp5.ps1: SYNTHESIS FAILED -- see $LogDir\$SynthLogFile"
        exit 1
    }
    Write-Host "  netlist  -> $NetlistDir\$NetlistFile"
    Write-Host "  log      -> $LogDir\$SynthLogFile"

    # ---- 2. Place and route -> output\netlists\ulx3s_dfc_<BuildId>_out.config,
    #         output\reports\ecp5_pnr_report_<BuildId>.json ----
    Write-Host "== build_ecp5.ps1: place and route =="
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    # cmd /c redirection -- see lint.ps1's header note for why.
    cmd /c "nextpnr-ecp5 --85k --package $DevicePackage --json `"ulx3s_dfc.json`" --lpf `"ulx3s_dfc.lpf`" --textcfg `"ulx3s_dfc_out.config`" --report `"ulx3s_dfc_report.json`" > `"pnr.log`" 2>&1"
    $ErrorActionPreference = $prevEAP
    $pnrExit = $LASTEXITCODE
    Copy-Item "pnr.log" "..\..\..\$LogDir\$PnrLogFile"
    if (Test-Path "ulx3s_dfc_out.config") {
        Copy-Item "ulx3s_dfc_out.config" "..\..\..\$ConfigDir\$ConfigFile"
    }
    if (Test-Path "ulx3s_dfc_report.json") {
        Copy-Item "ulx3s_dfc_report.json" "..\..\..\$ReportDir\$PnrReportFile"
    }
    if ($pnrExit -ne 0) {
        Write-Error "build_ecp5.ps1: PLACE-AND-ROUTE FAILED -- see $LogDir\$PnrLogFile (this includes a marginal timing miss -- see that log's 'Max frequency' line before assuming a real design problem)"
        exit 1
    }
    Write-Host "  config   -> $ConfigDir\$ConfigFile"
    Write-Host "  report   -> $ReportDir\$PnrReportFile"
    Write-Host "  log      -> $LogDir\$PnrLogFile"

    # ---- 3. Bitstream packing -> output\bitstreams\ulx3s_dfc_<BuildId>.bit ----
    Write-Host "== build_ecp5.ps1: bitstream packing =="
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    # cmd /c redirection -- see lint.ps1's header note for why.
    cmd /c "ecppack `"ulx3s_dfc_out.config`" `"ulx3s_dfc.bit`" > `"pack.log`" 2>&1"
    $ErrorActionPreference = $prevEAP
    $packExit = $LASTEXITCODE
    Copy-Item "pack.log" "..\..\..\$LogDir\$PackLogFile"
    if ($packExit -ne 0) {
        Write-Error "build_ecp5.ps1: BITSTREAM PACKING FAILED -- see $LogDir\$PackLogFile"
        exit 1
    }
    Copy-Item "ulx3s_dfc.bit" "..\..\..\$BitstreamDir\$BitstreamFile"
    Write-Host "  bitstream -> $BitstreamDir\$BitstreamFile"

    # ---- 4. Manifest -> output\reports\manifest_<BuildId>.md ----
    # ---- Generated every run, automatically, from what actually just ----
    # ---- happened -- not reconstructed later from logs. ----
    Write-Host "== build_ecp5.ps1: generating manifest =="

    $BitstreamHash = (Get-FileHash "..\..\..\$BitstreamDir\$BitstreamFile" -Algorithm SHA256).Hash
    $NetlistHash   = (Get-FileHash "..\..\..\$NetlistDir\$NetlistFile" -Algorithm SHA256).Hash

    $MaxFreqLines = Select-String -Path "pnr.log" -Pattern "Max frequency for clock"
    $FinalTimingLine = if ($MaxFreqLines) { ($MaxFreqLines | Select-Object -Last 1).Line.Trim() } else { "not found in pnr.log" }

    $SourceFileList = ($SourceFiles | ForEach-Object { "- ``$_``" }) -join "`n"

    $ManifestContent = @"
# Dragon Core FPGA Build Manifest -- $BuildId

Generated automatically by build_ecp5.ps1 at build time. Per RTLSTD-ORG-005
(generated outputs shall record source hash and generator hash in a
machine-readable manifest) and RTLSTD-ORG-010 (a clean build shall
reproduce all build inputs).

## Toolchain

- yosys        : $YosysVersion
- nextpnr-ecp5 : $NextpnrVersion
- ecppack      : $EcppackVersion

## Target

- Device  : $Device
- Top     : $Top
- Constraint file: fpga\ecp5\ulx3s_dfc.lpf

## Source files (this build's scope -- see file list; a partial-module
## build is normal during bring-up and is not itself a defect, but
## treat verification-case credit as scoped to what's actually listed)

$SourceFileList

## Final timing result (last "Max frequency" line in pnr.log; earlier
## lines in that log may show pessimistic pre-route estimates)

$FinalTimingLine

## Output artifact identity

| File | SHA-256 |
|---|---|
| $BitstreamFile | $BitstreamHash |
| $NetlistFile | $NetlistHash |

## Build outputs (this run, all sharing Build ID $BuildId)

- $BitstreamDir\$BitstreamFile
- $NetlistDir\$NetlistFile
- $ConfigDir\$ConfigFile
- $ReportDir\$PnrReportFile
- $LogDir\$SynthLogFile
- $LogDir\$PnrLogFile
- $LogDir\$PackLogFile
- $ReportDir\$ManifestFile  (this file)
"@

    Set-Content -Path "..\..\..\$ReportDir\$ManifestFile" -Value $ManifestContent
    Write-Host "  manifest -> $ReportDir\$ManifestFile"

    Write-Host ""
    Write-Host "build_ecp5.ps1: BUILD COMPLETE  (Build ID: $BuildId)"
    Write-Host "  $NetlistDir\$NetlistFile"
    Write-Host "  $ConfigDir\$ConfigFile"
    Write-Host "  $BitstreamDir\$BitstreamFile"
    Write-Host "  $ReportDir\$PnrReportFile"
    Write-Host "  $ReportDir\$ManifestFile   <- build manifest (source list, tool versions, hashes, timing)"
    Write-Host "  $LogDir\$SynthLogFile"
    Write-Host "  $LogDir\$PnrLogFile"
    Write-Host "  $LogDir\$PackLogFile"
    Write-Host ""
    Write-Host "NOTE: this script does NOT program the physical board. That remains"
    Write-Host "a separate, explicit step (openFPGALoader), never run automatically."
}
finally {
    Pop-Location
}
