# Task: Re-verify ECP5 timing closure against the current 353-register baseline

## Context

This repo (`DragonCore`) targets a ULX3S board (Lattice ECP5,
LFE5U-85F-6BG381C). RTL-001 and the SPI-to-DRI bridge are both real,
fully implemented, and have **already been confirmed** via real
synthesis, place-and-route, and timing closure at **62.08 MHz** against a
50 MHz requirement (with real margin, not a marginal pass).

**Why this needs re-running now, specifically:** since that 62.08 MHz
result was measured, `REG-002.md` grew from 314 to 353 registers (a real,
deliberate baseline addition — packed 16-bit counter-pair diagnostic
registers). `rtl/infrastructure/generated/dfc_config_regbank_regs.sv` has
since been regenerated to match this larger register map — more decode
logic than what the last confirmed timing number was measured against.
The last real synthesis/timing result is therefore stale relative to
what's actually committed now. This run is to confirm the design still
closes timing at the new size, not to re-investigate whether the SPI
bridge fix itself worked (that part is settled).

## What to run

Everything — dependency-staleness check/regeneration, toolchain check,
synthesis, place-and-route, bitstream packing, and exact output-file
placement — is handled by one script. Do not run
regenerate.ps1/yosys/nextpnr-ecp5/ecppack manually or choose your own
working directory; the script's paths are fixed on purpose so build
artifacts always land in the same place regardless of who or what runs
it.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_ecp5.ps1
```

Run this from the repository root. `build_ecp5.ps1` now automatically
calls `scripts\regenerate.ps1` as its own mandatory first step — it will
report whether `REG-002.md`/`ARCH-002.md` changed since the last
generation and regenerate accordingly before synthesis begins. This is
real, confirmed working end-to-end, not aspirational.

If any prerequisite tool is missing, the script will say so and exit;
install per its own error message.

## Output file naming — read this before reporting results

Every output file is timestamped (`yyyyMMdd_HHmmss`, one shared ID per
run) so consecutive runs never overwrite each other. **Do not look for
a plain `ulx3s_dfc.bit` or `ulx3s_dfc.json` — those exact names no
longer exist.** Instead:

| Output | Real filename pattern |
|---|---|
| Netlist | `output\netlists\ulx3s_dfc_<timestamp>.json` |
| P&R config | `output\netlists\ulx3s_dfc_<timestamp>_out.config` |
| P&R report | `output\reports\ecp5_pnr_report_<timestamp>.json` |
| Bitstream | `output\bitstreams\ulx3s_dfc_<timestamp>.bit` |
| Build manifest | `output\reports\manifest_<timestamp>.md` |
| Logs | `output\logs\ecp5_{synth,pnr,pack}_<timestamp>.log` |

Report the actual filenames the script printed at the end of its run —
don't assume or guess the timestamp.

## What to report back

- Whether `regenerate.ps1` (the automatic first step) reported anything
  as changed/regenerated, or reported everything unchanged.
- Whether the script completed all three build stages (synthesis,
  place-and-route, bitstream packing) or stopped early — if it stopped,
  quote its exact error message and which stage failed.
- The synthesis cell count and any warnings.
- **The actual `Max frequency for clock '$glbnet$core_clk'` line from the
  place-and-route log** — this is the one number that matters most right
  now: does the design still close timing at 50 MHz now that the
  register bank has grown to 353 registers?
- Confirm the bitstream file exists (using its real, timestamped name —
  see table above) and its file size.

## Do NOT do without explicit confirmation from me first

- Do not run `openFPGALoader` or any other command that actually flashes
  the physical board. Stop after the script produces the bitstream and
  ask before programming real hardware.
- Do not modify `scripts\build_ecp5.ps1`, `scripts\regenerate.ps1`, any
  file under `rtl\`, `include\`, or `fpga\ecp5\` to "fix" a build
  problem. If something doesn't build, report the exact error and which
  file/line it's in, and wait for direction.
