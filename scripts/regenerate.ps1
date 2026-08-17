# regenerate.ps1 -- dependency-staleness check and auto-regeneration.
#
# Confirmed via a real run (not assumed) that this problem is real, not
# hypothetical: the extractors were tested against this project's actual
# current REG-002.md and found REG-002 had grown from 314 to 353
# registers (a real, deliberate baseline addition -- packed 16-bit
# counter-pair registers, REG-ENC-021) since the currently-committed
# dfc_registers_pkg.sv/dfc_config_regbank_regs.sv were last generated.
# Nothing in the prior build pipeline would have caught this
# automatically -- this script exists so that gap can't recur silently.
#
# What this does: hashes each source specification document
# (REG-002.md, ARCH-002.md) and compares against a stored hash from the
# last successful extraction. If the source changed (or no stored hash
# exists yet), reruns the full extract -> pkggen/reggen chain for
# whatever that source feeds, then updates the stored hash. If the
# source hasn't changed, does nothing -- this is meant to be run as a
# cheap, mandatory first step of every build, not something remembered
# and run manually.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\regenerate.ps1
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$PythonCmd = $null
foreach ($candidate in @("python", "python3")) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found -and $found.Source -notmatch "WindowsApps") {
        $PythonCmd = $candidate
        break
    }
}
if (-not $PythonCmd) {
    Write-Error "regenerate.ps1: no real Python interpreter found (checked 'python' and 'python3')."
    exit 2
}

$HashDir = "tools\.srchash"
New-Item -ItemType Directory -Force -Path $HashDir | Out-Null

function Get-FileHashHex($path) {
    (Get-FileHash -Path $path -Algorithm SHA256).Hash
}

function Find-SpecDoc($filename) {
    # Searches under docs\ rather than assuming a specific subfolder --
    # this script's author was not certain of the exact real subfolder
    # path for REG-002.md/ARCH-002.md at the time of writing and did not
    # want a wrong guess to cause an immediate, confusing "file not
    # found" on first run. If this project's docs\ tree has more than one
    # file with this exact name (unlikely, but possible), this will error
    # below rather than silently pick one -- fix by hardcoding the real
    # path directly once confirmed.
    $matches = Get-ChildItem -Path "docs" -Recurse -Filter $filename -ErrorAction SilentlyContinue
    if ($matches.Count -eq 0) {
        Write-Error "regenerate.ps1: could not find $filename anywhere under docs\ -- check the real path and hardcode it directly in this script if search is unreliable."
        exit 2
    }
    if ($matches.Count -gt 1) {
        Write-Error "regenerate.ps1: found more than one $filename under docs\ ($($matches.Count) matches) -- ambiguous, hardcode the exact real path instead of relying on search."
        exit 2
    }
    return $matches[0].FullName
}

$RegDoc = Find-SpecDoc "RCA-DFC-REG-002.md"
$ArchDoc = Find-SpecDoc "RCA-DFC-ARCH-002.md"

function Test-Stale($sourceDoc, $hashMarker) {
    $currentHash = Get-FileHashHex $sourceDoc
    $markerPath = Join-Path $HashDir $hashMarker
    if (-not (Test-Path $markerPath)) {
        return @{ Stale = $true; Hash = $currentHash }
    }
    $storedHash = Get-Content $markerPath -Raw
    return @{ Stale = ($storedHash.Trim() -ne $currentHash); Hash = $currentHash }
}

function Set-Hash($hashMarker, $hash) {
    Set-Content -Path (Join-Path $HashDir $hashMarker) -Value $hash -NoNewline
}

$AnyRegenerated = $false

# ---- REG-002.md -> dfc_registers_pkg.json -> dfc_registers_pkg.sv,
#      dfc_rtl001_regbank_slice.json -> dfc_config_regbank_regs.sv ----
$RegCheck = Test-Stale $RegDoc "REG-002.hash"
if ($RegCheck.Stale) {
    Write-Host "regenerate.ps1: REG-002.md changed (or first run) -- regenerating registers"
    & $PythonCmd "tools\pkggen\extract_registers.py" $RegDoc "tools\pkggen\dfc_registers_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_registers.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_registers_pkg.json" "include\dfc_registers_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (registers) failed"; exit 1 }
    if (Test-Path "tools\reggen\dfc_rtl001_regbank_slice.json") {
        & $PythonCmd "tools\reggen\reggen.py" "tools\reggen\dfc_rtl001_regbank_slice.json" "tools\pkggen\dfc_registers_pkg.json" "rtl\infrastructure\generated"
        if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: reggen.py failed"; exit 1 }
    }
    Set-Hash "REG-002.hash" $RegCheck.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: REG-002.md unchanged -- skipping register regeneration"
}

# ---- ARCH-002.md -> dfc_types_pkg.json -> dfc_types_pkg.sv ----
$TypesCheck = Test-Stale $ArchDoc "ARCH-002-types.hash"
if ($TypesCheck.Stale) {
    Write-Host "regenerate.ps1: ARCH-002.md changed (or first run) -- regenerating types"
    & $PythonCmd "tools\pkggen\extract_types.py" $ArchDoc "tools\pkggen\dfc_types_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_types.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_types_pkg.json" "include\dfc_types_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (types) failed"; exit 1 }
    Set-Hash "ARCH-002-types.hash" $TypesCheck.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: ARCH-002.md unchanged (types) -- skipping"
}

# ---- ARCH-002.md -> dfc_irqfault.json -> split -> dfc_events_pkg.json /
#      dfc_interrupt_pkg.json -> dfc_events_pkg.sv / dfc_interrupt_pkg.sv ----
$IrqCheck = Test-Stale $ArchDoc "ARCH-002-irqfault.hash"
if ($IrqCheck.Stale) {
    Write-Host "regenerate.ps1: ARCH-002.md changed (or first run) -- regenerating irq/event/fault"
    & $PythonCmd "tools\pkggen\extract_irqfault.py" $ArchDoc "tools\pkggen\dfc_irqfault.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_irqfault.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\split_irqfault.py" "tools\pkggen\dfc_irqfault.json" "tools\pkggen\dfc_events_pkg.json" "tools\pkggen\dfc_interrupt_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: split_irqfault.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_events_pkg.json" "include\dfc_events_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (events) failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_interrupt_pkg.json" "include\dfc_interrupt_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (interrupt) failed"; exit 1 }
    Set-Hash "ARCH-002-irqfault.hash" $IrqCheck.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: ARCH-002.md unchanged (irq/event/fault) -- skipping"
}

# ---- dfc_registers_pkg.json -> dfc_version_pkg.json -> dfc_version_pkg.sv ----
# Depends on the REGISTERS extraction above, not on hashing REG-002.md a
# second time -- if REG-002.md changed, the registers step above already
# regenerated dfc_registers_pkg.json; this step re-derives version_pkg
# from whatever that file now contains, every time the registers step ran.
if ($RegCheck.Stale) {
    Write-Host "regenerate.ps1: regenerating version constants from updated register data"
    & $PythonCmd "tools\pkggen\extract_version.py" "tools\pkggen\dfc_registers_pkg.json" "tools\pkggen\dfc_version_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_version.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_version_pkg.json" "include\dfc_version_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (version) failed"; exit 1 }
    $AnyRegenerated = $true
}

# ---- REG-002.md + ARCH-002.md -> dfc_constants_pkg.json -> dfc_constants_pkg.sv ----
$ConstCheck1 = Test-Stale $RegDoc "REG-002-constants.hash"
$ConstCheck2 = Test-Stale $ArchDoc "ARCH-002-constants.hash"
if ($ConstCheck1.Stale -or $ConstCheck2.Stale) {
    Write-Host "regenerate.ps1: REG-002.md or ARCH-002.md changed (or first run) -- regenerating constants"
    & $PythonCmd "tools\pkggen\extract_constants.py" $RegDoc $ArchDoc "tools\pkggen\dfc_constants_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_constants.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_constants_pkg.json" "include\dfc_constants_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (constants) failed"; exit 1 }
    Set-Hash "REG-002-constants.hash" $ConstCheck1.Hash
    Set-Hash "ARCH-002-constants.hash" $ConstCheck2.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: REG-002.md/ARCH-002.md unchanged (constants) -- skipping"
}

if ($AnyRegenerated) {
    Write-Host ""
    Write-Host "regenerate.ps1: one or more packages were regenerated."
    Write-Host "  Run scripts\gate.ps1 now to confirm nothing regressed before trusting"
    Write-Host "  any subsequent build -- a regenerated package/regbank is unverified"
    Write-Host "  until the full lint/sim/formal/coverage chain has run against it."
}

exit 0
