# Task: Run the Dragon Core ECP5 skeleton bring-up build

## Context

This repo (`DragonCore`) targets a ULX3S board (Lattice ECP5,
LFE5U-85F-6BG381C). Synthesis was verified previously; a real timing bug
found via place-and-route (SPI response builder computing ~70 bytes of
CRC combinationally in one cycle) has since been fixed in
`rtl/top/dfc_rtl024_spi_bridge.sv` -- confirmed via simulation (35/35
checks across all test suites) and a real synthesis cell-count reduction
consistent with the fix, but NOT yet re-verified for actual timing
closure, since that requires a full place-and-route run.

## What to run

Everything -- toolchain check, synthesis, place-and-route, bitstream
packing, and exact output-file placement -- is handled by one script.
Do not run yosys/nextpnr-ecp5/ecppack manually or choose your own working
directory; the script's paths are fixed on purpose so build artifacts
always land in the same place regardless of who or what runs it.

**This environment does not have bash** (confirmed directly: `bash
--version` returns "not recognized" in this project's Windows setup).
Use the PowerShell version, not the `.sh` one:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_ecp5.ps1
```

Run this from the repository root. If any prerequisite tool is missing,
the script will say so and exit; install per its own error message.

NOTE: this PowerShell script has not yet been run successfully end-to-end
-- it was written to mirror the already-verified bash version's logic
exactly, but treat this first real run as its actual verification. If it
errors in a way that looks like a PowerShell-specific mistake (quoting,
path separator, cmdlet syntax) rather than a real build problem, report
the exact error rather than working around it manually -- same rule as
always: no ad hoc commands, no picking your own directory.

## What to report back

- Whether the script completed all three stages (synthesis, place-and-
  route, bitstream packing) or stopped early -- if it stopped, quote its
  exact error message and which stage failed.
- The synthesis cell count and any warnings.
- **The actual `Max frequency for clock '$glbnet$core_clk'` line from the
  place-and-route log** -- this is the one number that matters most right
  now, since it tells us whether the recent SPI-bridge timing fix
  actually closed timing at the required 50 MHz.
- Confirm `output/bitstreams/ulx3s_dfc.bit` exists and its file size.

## Do NOT do without explicit confirmation from me first

- Do not run `openFPGALoader` or any other command that actually flashes
  the physical board. Stop after the script produces `ulx3s_dfc.bit` and
  ask before programming real hardware.
- Do not modify `scripts/build_ecp5.ps1` (or `scripts/build_ecp5.sh`), any
  file under `rtl/`, `include/`, or `fpga/ecp5/` to "fix" a build problem.
  If something doesn't build, report the exact error and which file/line
  it's in, and wait for direction.
