# Dragon Core

Dragon Core is Royal Cubit Aerospace's Revision A flight-core RTL product:
24 modules (RTL-001 through RTL-024) implementing a host-visible register
contract over SPI/DRI, timestamping, event logging, interrupt/fault
handling, sensor monitoring, safety interlocks, and databus routing. See
`docs/business/RCA-DFC-CHTR-002.md` SS4 and SS7 for the full mission and
scope statement.

## Specification baseline

Everything in this repository implements the `-002` baseline: the 8
documents under `docs/`. `-002` is the current and only baseline — there is
no prior revision to reconcile against. See `CLAUDE.md` for the full
ownership map and the working rules that follow from it.

## Repository layout

```
docs/                the 8 -002 specification documents, split by subject
include/             generated SystemVerilog packages (dfc_*_pkg.sv)
tools/pkggen/        extractors (registers/types/irq-fault) + package emitter
tools/reggen/        register-bank generator
rtl/                 RTL-001..024 source, domain-nested
scripts/             lint/sim/formal/gate scripts, coverage checker, git hooks
verification/        testbench, assertions, formal, regression, coverage
simulation/          simulator working directories (iverilog/modelsim/verilator/gtkwave)
synthesis/           yosys/openlane outputs and reports
fpga/                board-specific constraints (ECP5, VisionFive2)
firmware/, software/ later-phase deliverables, not yet started
```

## Building the generated packages

The six `dfc_*_pkg.sv` packages in `include/` and the RTL-001 register bank
in `rtl/infrastructure/generated/` are machine-generated from the `-002`
documents — never hand-edited. To regenerate from a clean checkout:

```bash
cd tools/pkggen
python3 extract_registers.py ../../docs/architecture/RCA-DFC-REG-002.md  dfc_registers_pkg.json
python3 extract_types.py     ../../docs/architecture/RCA-DFC-ARCH-002.md dfc_types_pkg.json
python3 extract_irqfault.py  ../../docs/architecture/RCA-DFC-ARCH-002.md dfc_irqfault.json

for pkg in version constants types events interrupt registers; do
  python3 pkggen.py dfc_${pkg}_pkg.json ../../include/dfc_${pkg}_pkg.sv
done

cd ../reggen
python3 reggen.py dfc_rtl001_regbank_slice.json ../pkggen/dfc_registers_pkg.json ../../rtl/infrastructure/generated
```

Each extractor fails loud (nonzero exit, nothing written) if the source
document's structure doesn't match what it expects, or if a structural
invariant (unique addresses, full bit-tiling, recognized access class,
etc.) doesn't hold. A clean run reproduces every generated file with no
manual intervention (`RTLSTD-ORG-010`).

## Verifying the generated output compiles

```bash
iverilog -g2012 -t null \
  include/dfc_constants_pkg.sv include/dfc_version_pkg.sv \
  include/dfc_types_pkg.sv include/dfc_events_pkg.sv \
  include/dfc_interrupt_pkg.sv include/dfc_registers_pkg.sv \
  rtl/infrastructure/generated/dfc_config_regbank_regs.sv
```

No `syntax error` or `error:` lines in the output means a clean compile.
`scripts/lint.sh` and `scripts/sim.sh` wrap this and related checks for
day-to-day use.

## Status

Phase 1 (all six packages + the RTL-001 register bank) is generated and
compile-verified against `-002`. RTL-001 and RTL-024 module specs, the
verification scaffolding, and the `.claude/` agent/skill definitions are
authored fresh against `-002` as a separate, later step — see
`OPEN_ISSUES.md` for anything still outstanding.
