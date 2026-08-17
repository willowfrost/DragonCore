# Dragon Core skeleton HIL bring-up -- ULX3S build instructions

Confirmed working in this session:
- `yosys -s synth.ys` -- clean synthesis, 0 problems, 38,134 cells for the
  real LFE5U-85F-6BG381C.
- `nextpnr-ecp5 --85k --package CABGA381 ...` -- placement succeeds
  (confirms the design fits the device). Full routing convergence needs
  more wall-clock time than a single sandboxed command here allowed --
  run it on your own machine, where there's no such ceiling.

## Prerequisites (same as this session used)
```
sudo apt-get install -y yosys nextpnr-ecp5 nextpnr-ecp5-chipdb fpga-trellis fpga-trellis-database
```

## Files needed alongside this bundle
Copy these from your DragonCore repo into the same build directory:
- include/dfc_constants_pkg.sv
- include/dfc_registers_pkg.sv
- rtl/infrastructure/generated/dfc_config_regbank_regs.sv
- rtl/infrastructure/src/dfc_rtl001.sv
- rtl/top/dfc_rtl024_spi_bridge.sv
- rtl/top/dfc_rtl024.sv

Plus, from this bundle: dfc_ecp5_pll.v, ulx3s_dfc_top.sv, ulx3s_dfc.lpf

## Build steps

```bash
# 1. Synthesis (fast, ~1 min)
yosys -p "
read_verilog -sv dfc_constants_pkg.sv;
read_verilog -sv dfc_registers_pkg.sv;
read_verilog -sv dfc_config_regbank_regs.sv;
read_verilog -sv dfc_rtl001.sv;
read_verilog -sv dfc_rtl024_spi_bridge.sv;
read_verilog -sv dfc_rtl024.sv;
read_verilog dfc_ecp5_pll.v;
read_verilog -sv ulx3s_dfc_top.sv;
synth_ecp5 -top ulx3s_dfc_top -json ulx3s_dfc.json
"

# 2. Place and route (this is the step that needs real time -- expect
#    several minutes on real hardware, not the ~5 min ceiling this
#    sandbox enforced per command)
nextpnr-ecp5 --85k --package CABGA381 \
  --json ulx3s_dfc.json --lpf ulx3s_dfc.lpf \
  --textcfg ulx3s_dfc_out.config

# 3. Bitstream packing
ecppack ulx3s_dfc_out.config ulx3s_dfc.bit

# 4. Program the board (requires openFPGALoader or ujprog -- neither
#    was available/testable in this sandbox; install per your OS)
openFPGALoader -b ulx3s ulx3s_dfc.bit
```

## What to expect once programmed

- LED0 lights when the PLL locks (near-instant after power-up).
- LED1 lights ~16 core_clk cycles after LED0 (the POR release pulse).
- Once both are lit, the board is alive and clocked at the correct 50 MHz
  (via the real 25->50 MHz PLL), and Dragon Core's reset sequence has
  completed. At that point RTL-001 + the SPI bridge are live and
  reachable via the SPI pins below.

## SPI pin mapping (J1 header, confirmed against the real board schematic)

| Signal | Board pin (individual GPIO) |
|---|---|
| SCLK (in) | gp0 |
| CS_N (in) | gp1 |
| MOSI (in) | gp2 |
| MISO (tristate out) | gp3 |
| host_irq_n (out) | gp4 |

This is the exact protocol dfc_rtl024_spi_bridge.sv implements and
spi_bridge_tb.sv verified end-to-end in simulation (13/13 checks): frame
format, CRC-16/CCITT-FALSE, opcode/status codes per DFC-INTF-0011..0036.
Whatever drives these pins from the VisionFive2 side (Dragon Console /
SW-007) must match that exact contract.

## Known limitation carried from this design's own disclosures

dfc_rtl024.sv's own header lists RTL-002 through RTL-023 as labeled stubs.
Everything reachable via the SPI bridge today routes only to the real
RTL-001 (register bank + DRI). Reads/writes to any other module's address
range will correctly DECODE_ERROR (nothing is there yet), not silently
succeed.
