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
# What this does: hashes each source specification document (REG-002.md,
# ARCH-002.md) TOGETHER WITH every generator script that consumes it, and
# compares the combined hash against a stored marker from the last
# successful extraction. If EITHER the source document OR any of its
# generator scripts changed (or no stored marker exists yet), reruns the
# full extract -> pkggen/reggen chain for whatever that source feeds, then
# updates the stored marker. If nothing changed, does nothing -- this is
# meant to be run as a cheap, mandatory first step of every build, not
# something remembered and run manually.
#
# UPDATED: originally hashed only the source .md document, never the
# generator script itself -- confirmed as a second, real staleness gap
# (not hypothetical) once extract_types.py/pkggen.py were patched to add
# dfc_operating_state_t enum support and per-field bit-position constants:
# ARCH-002.md itself hadn't changed a single byte, so the old check would
# have reported "unchanged, skipping" and silently left the stale,
# generator-mismatched dfc_types_pkg.sv in place. Every staleness check
# below now includes its generator script(s) in the hashed input set.
#
# UPDATED AGAIN: reggen.py's own invocation (below) was never updated when
# reggen.py became v3 (real cross-module control/status forwarding via a
# hand-verified field-map file, added alongside RTL-001<->RTL-002's real
# register bus). Confirmed as a real, live bug, not hypothetical: this
# script was still calling reggen.py with its old 3-argument legacy form,
# which reggen.py v3 silently accepts but treats as "no field-map, no real
# forwarding" -- meaning the very next time this block went stale for any
# reason, it would have regenerated dfc_config_regbank_regs.sv WITHOUT the
# real rtl002_control_o/rtl002_status_i ports, silently reverting real,
# already-verified integration work. Fixed by passing the real 5-argument
# form (adding tools\pkggen\dfc_types_pkg.json and a per-module
# tools\reggen\rtl<NNN>_field_map.json) whenever a field-map file exists for
# a module, and by moving the ARCH-002-types block ahead of the REG-002
# block in this file's own execution order, since reggen.py v3 needs
# dfc_types_pkg.json to already exist -- a real first-run ordering bug the
# old block order would have hit on a completely fresh checkout.
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

# FIXED (real, confirmed gap, not hypothetical): Test-Stale originally hashed
# only the source .md document, never the generator SCRIPT that turns it
# into a package. This meant a generator fix -- e.g. extract_types.py
# gaining SS4.1 enum-table support, or pkggen.py gaining bit-position
# constant emission, both real changes made to this project's actual
# generators without ARCH-002.md/REG-002.md themselves changing a single
# byte -- would report "unchanged, skipping" and silently leave the STALE,
# generator-mismatched package in place. Confirmed concretely: this
# project's own stored hash marker for ARCH-002-types.hash already existed
# from a prior successful run (unrelated document content, unchanged),
# so simply dropping in a patched extract_types.py/pkggen.py would have
# hit exactly this gap on the very next run. Test-Stale now takes an ARRAY
# of input paths (the source document(s) AND every generator script that
# consumes them) and is stale if ANY of them changed -- closing this class
# of gap the same way this whole script already closed the analogous
# REG-002.md/ARCH-002.md-vs-committed-package gap.
function Test-Stale($inputPaths, $hashMarker) {
    $currentHash = ($inputPaths | ForEach-Object { Get-FileHashHex $_ }) -join "|"
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

# ---- ARCH-002.md -> dfc_types_pkg.json -> dfc_types_pkg.sv ----
# MOVED ahead of the REG-002 block below: reggen.py v3 (real cross-module
# control/status forwarding, added when RTL-001<->RTL-002's real register
# bus was built) needs tools\pkggen\dfc_types_pkg.json to exist BEFORE it
# runs -- confirmed as a real first-run ordering bug, not hypothetical:
# with the ORIGINAL script order (REG-002 block first), a fresh checkout
# with no dfc_types_pkg.json on disk yet would have reggen.py crash on a
# missing file the very first time this script ever ran end-to-end.
$TypesCheck = Test-Stale @($ArchDoc, "tools\pkggen\extract_types.py", "tools\pkggen\pkggen.py") "ARCH-002-types.hash"
if ($TypesCheck.Stale) {
    Write-Host "regenerate.ps1: ARCH-002.md or its generators changed (or first run) -- regenerating types"
    & $PythonCmd "tools\pkggen\extract_types.py" $ArchDoc "tools\pkggen\dfc_types_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_types.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_types_pkg.json" "include\dfc_types_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (types) failed"; exit 1 }
    Set-Hash "ARCH-002-types.hash" $TypesCheck.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: ARCH-002.md and its generators unchanged (types) -- skipping"
}
if (-not (Test-Path "tools\pkggen\dfc_types_pkg.json")) {
    Write-Error "regenerate.ps1: tools\pkggen\dfc_types_pkg.json still doesn't exist after the types step above -- reggen.py's real cross-module forwarding (below) cannot run without it. Check extract_types.py/pkggen.py output for a silent failure."
    exit 1
}

# ---- REG-002.md -> dfc_registers_pkg.json -> dfc_registers_pkg.sv,
#      dfc_rtl001_regbank_slice.json (+ dfc_types_pkg.json +
#      rtl<NNN>_field_map.json) -> dfc_config_regbank_regs.sv ----
# Field-map files themselves are now part of this check's hashed input set --
# a real, confirmed gap otherwise: editing tools\reggen\rtl003_field_map.json
# alone (REG-002.md/ARCH-002.md/reggen.py all unchanged) would report
# "unchanged, skipping" and silently leave the stale, field-map-mismatched
# dfc_config_regbank_regs.sv in place, the same class of gap this script's
# own header already documents fixing for the generator scripts themselves.
$FieldMapHashInputs = @($RegDoc, "tools\pkggen\extract_registers.py",
                       "tools\pkggen\pkggen.py", "tools\reggen\reggen.py")
$FieldMapHashInputs += (Get-ChildItem -Path "tools\reggen" -Filter "rtl*_field_map.json" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.FullName })
$RegCheck = Test-Stale $FieldMapHashInputs "REG-002.hash"
if ($RegCheck.Stale) {
    Write-Host "regenerate.ps1: REG-002.md or its generators changed (or first run) -- regenerating registers"
    & $PythonCmd "tools\pkggen\extract_registers.py" $RegDoc "tools\pkggen\dfc_registers_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_registers.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_registers_pkg.json" "include\dfc_registers_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (registers) failed"; exit 1 }
    if (Test-Path "tools\reggen\dfc_rtl001_regbank_slice.json") {
        # FIXED (real, confirmed bug, not hypothetical): this invocation was
        # never updated when reggen.py became v3 (real cross-module
        # control/status forwarding via a hand-verified field-map file,
        # added when RTL-001<->RTL-002's real register bus was built). It
        # was still calling reggen.py with the OLD 3-argument legacy form
        # (slice.json, registers.json, out_dir) -- which reggen.py v3 still
        # accepts, but silently falls back to NO cross-module forwarding at
        # all (fieldmap=None) in that mode. Since reggen.py's own file
        # content is already part of this check's hashed inputs above, the
        # very next time ANYTHING made this block stale, this stale
        # invocation would have regenerated dfc_config_regbank_regs.sv
        # WITHOUT the real rtl002_control_o/rtl002_status_i ports --
        # silently reverting all of that session's real integration work
        # and breaking dfc_rtl001.sv's real port connections to it. Now
        # passes the full 5-argument form whenever a field-map file exists
        # for a given module; add one `& $PythonCmd ... reggen.py ...` line
        # per module here as each one gets its own real cross-module
        # forwarding wired up (see tools\reggen\ in the continuity notes
        # for which modules currently have one).
        # reggen.py v4 accepts one OR MORE field-map files in a single run
        # (needed now that RTL-003 needs the same real cross-module
        # forwarding treatment as RTL-002, through the same generated
        # regbank file) -- collect whichever tools\reggen\rtl<NNN>_field_map.json
        # files actually exist, in module-number order, rather than hardcode
        # a fixed pair; add a new module's field-map file here and it picks
        # up automatically the next time this script regenerates.
        $FieldMapFiles = Get-ChildItem -Path "tools\reggen" -Filter "rtl*_field_map.json" -ErrorAction SilentlyContinue | Sort-Object Name
        if ($FieldMapFiles.Count -gt 0) {
            $FieldMapArgs = $FieldMapFiles | ForEach-Object { $_.FullName }
            & $PythonCmd "tools\reggen\reggen.py" "tools\reggen\dfc_rtl001_regbank_slice.json" "tools\pkggen\dfc_registers_pkg.json" "tools\pkggen\dfc_types_pkg.json" @FieldMapArgs "rtl\infrastructure\generated"
        } else {
            Write-Host "regenerate.ps1: no tools\reggen\rtl*_field_map.json found -- falling back to reggen.py's legacy 3-argument form (NO real cross-module forwarding will be generated). This is only correct if no such file is genuinely meant to exist yet."
            & $PythonCmd "tools\reggen\reggen.py" "tools\reggen\dfc_rtl001_regbank_slice.json" "tools\pkggen\dfc_registers_pkg.json" "rtl\infrastructure\generated"
        }
        if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: reggen.py failed"; exit 1 }
    }
    Set-Hash "REG-002.hash" $RegCheck.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: REG-002.md and its generators unchanged -- skipping register regeneration"
}

# ---- ARCH-002.md -> dfc_irqfault.json -> split -> dfc_events_pkg.json /
#      dfc_interrupt_pkg.json -> dfc_events_pkg.sv / dfc_interrupt_pkg.sv ----
$IrqCheck = Test-Stale @($ArchDoc, "tools\pkggen\extract_irqfault.py",
                         "tools\pkggen\split_irqfault.py", "tools\pkggen\pkggen.py") "ARCH-002-irqfault.hash"
if ($IrqCheck.Stale) {
    Write-Host "regenerate.ps1: ARCH-002.md or its generators changed (or first run) -- regenerating irq/event/fault"
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
    Write-Host "regenerate.ps1: ARCH-002.md and its generators unchanged (irq/event/fault) -- skipping"
}

# ---- REG-002.md -> dfc_registers_pkg.json -> dfc_version_pkg.json ->
#      dfc_version_pkg.sv ----
# Now has its OWN real staleness check (REG-002.md + extract_version.py +
# pkggen.py), rather than silently piggybacking on $RegCheck.Stale alone --
# that piggyback meant a pkggen.py-only or extract_version.py-only change,
# with REG-002.md itself unchanged, would never have triggered this step at
# all. Still re-derives from whatever dfc_registers_pkg.json currently
# contains (regenerated fresh above if $RegCheck was stale, otherwise the
# already-current committed one), consistent with the original design.
$VersionCheck = Test-Stale @($RegDoc, "tools\pkggen\extract_version.py", "tools\pkggen\pkggen.py") "REG-002-version.hash"
if ($RegCheck.Stale -or $VersionCheck.Stale) {
    Write-Host "regenerate.ps1: regenerating version constants (register data, extractor, or pkggen.py changed)"
    & $PythonCmd "tools\pkggen\extract_version.py" "tools\pkggen\dfc_registers_pkg.json" "tools\pkggen\dfc_version_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_version.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_version_pkg.json" "include\dfc_version_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (version) failed"; exit 1 }
    Set-Hash "REG-002-version.hash" $VersionCheck.Hash
    $AnyRegenerated = $true
}

# ---- REG-002.md + ARCH-002.md -> dfc_constants_pkg.json -> dfc_constants_pkg.sv ----
$ConstCheck = Test-Stale @($RegDoc, $ArchDoc, "tools\pkggen\extract_constants.py", "tools\pkggen\pkggen.py") "REG-ARCH-constants.hash"
if ($ConstCheck.Stale) {
    Write-Host "regenerate.ps1: REG-002.md, ARCH-002.md, or their generators changed (or first run) -- regenerating constants"
    & $PythonCmd "tools\pkggen\extract_constants.py" $RegDoc $ArchDoc "tools\pkggen\dfc_constants_pkg.json"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: extract_constants.py failed"; exit 1 }
    & $PythonCmd "tools\pkggen\pkggen.py" "tools\pkggen\dfc_constants_pkg.json" "include\dfc_constants_pkg.sv"
    if ($LASTEXITCODE -ne 0) { Write-Error "regenerate.ps1: pkggen.py (constants) failed"; exit 1 }
    Set-Hash "REG-ARCH-constants.hash" $ConstCheck.Hash
    $AnyRegenerated = $true
} else {
    Write-Host "regenerate.ps1: REG-002.md/ARCH-002.md and their generators unchanged (constants) -- skipping"
}

if ($AnyRegenerated) {
    Write-Host ""
    Write-Host "regenerate.ps1: one or more packages were regenerated."
    Write-Host "  Run scripts\gate.ps1 now to confirm nothing regressed before trusting"
    Write-Host "  any subsequent build -- a regenerated package/regbank is unverified"
    Write-Host "  until the full lint/sim/formal/coverage chain has run against it."
}

exit 0
