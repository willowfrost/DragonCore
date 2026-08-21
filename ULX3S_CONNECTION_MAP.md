# ULX3S Connection Map

Real, physical wiring reference for the ULX3S board as used by this
project's actual `fpga\ecp5\ulx3s_dfc.lpf` constraint file. Every entry
below is either transcribed directly from that real file, confirmed
against the real ULX3S schematic, or confirmed by the person's own direct
visual inspection of their physical board — never guessed or assumed. See
each section's own provenance note for exactly which applies.

This document answers one question: **for a given internal `gp<N>`
signal name (used throughout the `.lpf` file and this project's own
`ulx3s_dfc_top.sv`), which physical header, which numbered position on
that header, and which row, does it correspond to on the real board?**

---

## 1. SPI host interface + interrupt (J1 header, positions 0-4)

This is the only functional interface currently wired to physical pins in
this project. All five signals live on **connector J1**, at silkscreen
positions **0 through 4**, on the **outer row**.

| `gp<N>` | J1 position | Row | FPGA site (real `.lpf`) | Signal | Direction | Description |
|---|---|---|---|---|---|---|
| `gp0` | J1-0 | Outer (`+` / GP) | B11 | `spi_sclk_i` (SCLK) | Input | SPI serial clock, Mode 0 |
| `gp1` | J1-1 | Outer (`+` / GP) | A10 | `spi_cs_n_i` (CS_N) | Input | SPI chip-select, active low |
| `gp2` | J1-2 | Outer (`+` / GP) | A9 | `spi_mosi_i` (MOSI) | Input | SPI data, host → Dragon Core |
| `gp3` | J1-3 | Outer (`+` / GP) | B9 | `spi_miso_o` (MISO) | Tristate output | SPI data, Dragon Core → host; high-Z while CS_N inactive |
| `gp4` | J1-4 | Outer (`+` / GP) | A7 | `host_irq_n_o` | Output | Interrupt to host; active low; real aggregate from RTL-003 |

**The corresponding inner row (`-` / GN) at these same five positions
(`gn0` through `gn4`) is unused by this design** — those physical pins
are not driven or read by anything in this project. **Important: for
positions 0-7 (which includes all five positions this project uses),
`gp`/`gn` are two genuinely independent single-ended signals, not a true
LVDS differential pair** — confirmed from the real ULX3S schematic
("GP,GN 0-7 single-ended connected to Bank0"; true differential pairing
only begins at position 8, "GP,GN 8-13 differential bidirectional
connected to BANK7"). Practical consequence: `gn0` through `gn4` are
honestly-available standalone single-ended I/O pins for potential future
use, not the "wasted other half" of a differential pair the way `gn8`
and above would be if their `gp` counterpart were in use.

**Provenance:** the `gp<N>` → FPGA site mapping (B11, A10, A9, B9, A7) and
the `gp<N>` → signal assignment (SCLK/CS_N/MOSI/MISO/host_irq_n) are both
transcribed directly from the project's real `ulx3s_dfc.lpf`. The
`gp<N>` → "J1, position N" correspondence is confirmed from the real
ULX3S schematic (the silkscreen-printed position number is shared by each
`gp[N]`/`gn[N]` differential pair, with the FPGA-site-level P/N split
handled internally). **The outer-row-is-`+`/GP fact is confirmed by the
person's own direct visual inspection of their physical board** — an
earlier draft of this document incorrectly guessed the opposite (inner
row = `+`) from schematic text alone; that was wrong and has been
corrected here based on the real board, not reasoning from a generic
reference document.

---

## 2. System clock — not part of J1/J2 at all

| Signal | FPGA site | Description |
|---|---|---|
| `clk_25mhz` | G2 | Onboard 25 MHz crystal oscillator, built into the board itself |

This is a **dedicated clock pin, physically separate from the J1/J2 GPIO
headers** — it requires no external wiring at all. This project's PLL
(`fpga\ecp5\dfc_ecp5_pll.v`) multiplies this 25 MHz reference up to the
real 50 MHz `CORE_CLK` that all RTL modules actually run on.

**Provenance:** transcribed directly from the real `.lpf` file.

---

## 3. Debug LEDs

| Signal | FPGA site | Currently driven by |
|---|---|---|
| `led[0]` | B2 | Real — PLL lock indicator |
| `led[1]` | C2 | Real — POR/reset indicator |
| `led[2]` | C1 | Tied zero (disclosed stub — unused) |
| `led[3]` | D2 | Tied zero (disclosed stub — unused) |
| `led[4]` | D1 | Tied zero (disclosed stub — unused) |
| `led[5]` | E2 | Tied zero (disclosed stub — unused) |
| `led[6]` | E1 | Tied zero (disclosed stub — unused) |
| `led[7]` | H3 | Tied zero (disclosed stub — unused) |

**Provenance:** transcribed directly from the real `.lpf` file; the
real-vs-stub status of each is per that file's own header comment.

---

## 4. Not yet assigned — reserved for future modules

**Nothing below has a physical pin constraint in the real `.lpf` file
yet.** Every one of these logical signals already exists as real,
verified RTL on `dfc_rtl024.sv` (confirmed via `rtl024_skeleton_tb.sv`'s
own real checks — e.g. `can_tx_o` recessive-high, `uart_tx_o` idle-high,
`safety_out_o` inactive — all real, correct stub values), but none of it
is wired to a physical board pin, because the modules that would actually
drive or consume each signal (RTL-007 through RTL-021) don't exist yet.

The established plan (confirmed in `PROJECT_CONTINUITY.md`) is to assign
real physical pins for each interface **only once the module that owns
it is real and verified** — not before. When that happens, add a new
section to this document the same way Section 1 was built: transcribe
the real `.lpf` addition, confirm the J1/J2 position against the real
board, and cite the source for each fact rather than assume it.

Positions still open on the GPIO headers for this purpose: **`gp27`
(J2-27)** — the one remaining single-ended-only position, see Section 5
below for where the other 8 went — and **J1-8 through J1-13** plus
**J2-14 through J2-21** (outer and inner rows both, differential-capable).
None of these are committed to any specific future signal yet; do not
treat any position number here as a preassigned plan. **Corrected,
complete picture of the real electrical distinction (an earlier draft of
this section was incomplete — verified directly against ULX3S's own
official manual, not just the schematic excerpt used before):**
- **J1-5 through J1-7 and J2-22 through J2-27 are single-ended-ONLY**
  (9 positions total; 8 now committed to RTL-006's GPIO channels per
  Section 5, `gp27` still open) — the natural first choice for any future
  ordinary single-ended interface (every remaining module's real spec --
  ARINC, CAN, UART, monitoring inputs — uses ordinary single-ended
  signals, none need differential).
- **J1-8 through J1-13 and J2-14 through J2-21 are differential-capable**
  (14 positions) — but per ULX3S's own manual, "differential pairs can be
  used also as single-ended pins," so these remain a real fallback if the
  single-ended-only positions above are ever exhausted, not a hard
  no-go — just the less-preferred choice when a genuinely single-ended
  position is available instead.

Logical signals awaiting a physical assignment: `rotor_i` (RTL-007),
`engine_i` (RTL-008), `pulse_i[1:0]` (RTL-009), `arinc_rx_i`/
`arinc_tx_ctrl_o`/`arinc_rx_adapter_error_i`/`arinc_tx_adapter_error_i`
(RTL-017/018), `can_rx_i`/`can_tx_o`/`can_transceiver_error_i` (RTL-019),
`uart_rx_i`/`uart_tx_o` (RTL-020), `health_i[7:0]` (RTL-011),
`safety_out_o[3:0]` (RTL-016), `user_i`/`o`/`oe[3:0]` (out of scope --
RTL-022/023 dropped from this build per the demo-scope decision, see
`PROJECT_CONTINUITY.md` Section 5). `gpio_i`/`gpio_o`/`gpio_oe_o`
(RTL-006) is no longer in this list — see Section 5, its physical
assignment is now real.

---

## 5. GPIO Controller (RTL-006) — J1 gp5-gp7 + J2 gp22-gp26, 8 channels

RTL-006 is the first module in this build with a real, physical,
bidirectional aircraft-facing interface — 8 independently synchronized/
qualified GPIO channels (`gpio_i[7:0]`/`gpio_o[7:0]`/`gpio_oe_o[7:0]`),
one physical pin per channel.

| `gpio` channel | `gp<N>` | J1/J2 position | Row | FPGA site (real `.lpf`) | Direction |
|---|---|---|---|---|---|
| 0 | `gp5` | J1-5 | Outer (`+` / GP) | C8 | Bidirectional (tristate) |
| 1 | `gp6` | J1-6 | Outer (`+` / GP) | C6 | Bidirectional (tristate) |
| 2 | `gp7` | J1-7 | Outer (`+` / GP) | A6 | Bidirectional (tristate) |
| 3 | `gp22` | J2-22 | Outer (`+` / GP) | B15 | Bidirectional (tristate) |
| 4 | `gp23` | J2-23 | Outer (`+` / GP) | B17 | Bidirectional (tristate) |
| 5 | `gp24` | J2-24 | Outer (`+` / GP) | C16 | Bidirectional (tristate) |
| 6 | `gp25` | J2-25 | Outer (`+` / GP) | D14 | Bidirectional (tristate) |
| 7 | `gp26` | J2-26 | Outer (`+` / GP) | B13 | Bidirectional (tristate) |

**Choice rationale:** per Section 4's own note (confirmed against ULX3S's
own official manual, not a schematic excerpt), positions **J1-5 through
J1-7 and J2-22 through J2-27 are single-ended-only** (9 positions) —
exhausted first, per this project's own standing rule, before ever
reaching into the differential-capable range (J1-8–13, J2-14–21). This
module needs exactly 8 of those 9 positions; the first 8 in position
order (`gp5`/`gp6`/`gp7`/`gp22`/`gp23`/`gp24`/`gp25`/`gp26`) were used,
leaving **`gp27` (J2-27) as the one remaining open single-ended-only
position** for a future module. The corresponding `gn5`-`gn7`/`gn22`-`gn26`
inner-row pins are, as with Section 1's `gn0`-`gn4`, genuinely independent
single-ended pins this design does not use — not "the wasted other half"
of a differential pair.

**Each `gp<N>` is a real, bidirectional ECP5 tristate**, not two separate
input/output pins: `ulx3s_dfc_top.sv` reads the pad continuously into
`gpio_i[N]` and drives the pad from `gpio_o[N]` only while
`gpio_oe_o[N]` is asserted (high-Z otherwise) — the identical idiom
already used for `gp3` (SPI MISO) in Section 1.

**Provenance:** the `gp<N>` → FPGA site mapping (C8, C6, A6, B15, B17, C16,
D14, B13) is fetched directly from the real board constraint file
(`emard/ulx3s`, `doc/constraints/ulx3s_v20.lpf`, v2.x.x/v3.0.x — the same
source Section 1's SPI mapping was fetched from), confirmed via a direct
`curl`+`grep` of the raw file content against the exact `LOCATE COMP
"gp<N>"` lines, not recalled from memory or accepted from a single
summarizing pass. The `gp<N>` → "J1/J2, position N" correspondence follows
the same silkscreen-position convention already established and confirmed
in Section 1.
