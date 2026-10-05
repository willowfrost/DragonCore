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
own real checks — e.g. `can_tx_o` recessive-high, `uart_tx_o` idle-high —
all real, correct stub values), but none of it is wired to a physical
board pin, because the modules that would actually drive or consume each
signal (RTL-017 through RTL-021) don't exist yet.

The established plan (confirmed in `PROJECT_CONTINUITY.md`) is to assign
real physical pins for each interface **only once the module that owns
it is real and verified** — not before. When that happens, add a new
section to this document the same way Section 1 was built: transcribe
the real `.lpf` addition, confirm the J1/J2 position against the real
board, and cite the source for each fact rather than assume it.

Positions still open on the GPIO headers for this purpose, as of the end
of Section 10: **`gn15`-`gn21` (7 positions, orphaned differential
counterparts of RTL-011's own single-ended `gp15`-`gp21`, confirmed free
the same way `gn8`/`gn9`/`gn10`/`gn14` were before Section 10 used them)
plus J1-11 through J1-13 (3 true differential pairs, WiFi-shared)** — see
Section 6 below for where the last single-ended-only position (`gp27`/
J2-27) went, Section 7 for where the first differential-capable position
(`gp8`/J1-8) went, Section 8 for where the next two differential-capable
positions (`gp9`/J1-9, `gp10`/J1-10) went, Section 9 for where the entire
remaining unshared differential-capable range (`gp14`-`gp21`/J2-14 through
J2-21, 8 positions) went, and **Section 10 for where the first four
orphaned `gn<N>` pins (`gn8`/`gn9`/`gn10`/`gn14`) went** — RTL-016's own 4
safety-output channels. `gn15`-`gn21` (the differential counterparts of
RTL-011's own `gp15`-`gp21`) remain implicitly unavailable for a true LVDS
pair, since each `gp<N>` is committed to an ordinary single-ended signal —
see Section 9's own note — but, per the same precedent Section 10 just
used, each remains individually available as its own single-ended pin.
**J1-11 through J1-13 are shared with the onboard WiFi module** in the
real board file's own comments (`wifi_gpio26`/`wifi_gpio33`/
`wifi_gpio35`) — confirmed directly, and the only positions left that are
both unused AND still capable of a true, unshared differential pair: any
future module needing a physical pin should prefer the remaining orphaned
`gn15`-`gn21` pins first (same "prefer unshared" precedent as ever), and
only reach into the WiFi-shared range once those 7 are also exhausted.
Flagged explicitly here, not discovered silently later (see Section 10's
own note on this same tightening budget).
**Corrected, complete picture of the real electrical distinction (an
earlier draft of this section was incomplete — verified directly against
ULX3S's own official manual, not just the schematic excerpt used
before):**
- **J1-5 through J1-7 and J2-22 through J2-27 are single-ended-ONLY**
  (9 positions total; 8 committed to RTL-006's GPIO channels per Section 5,
  the 9th and last — `gp27` — committed to RTL-007's `rotor_i` per
  Section 6). **This single-ended-only range is now fully exhausted** —
  any future module needing a pin (RTL-008 onward) must use the
  differential-capable range below.
- **J1-8 through J1-13 and J2-14 through J2-21 are differential-capable**
  (14 positions; 1 -- `gp8`/J1-8 -- now committed to RTL-008's `engine_i`
  per Section 7, 13 remaining) — but per ULX3S's own manual, "differential
  pairs can be used also as single-ended pins," so these remain a real
  fallback now that the single-ended-only positions above are exhausted,
  not a hard no-go — just the less-preferred choice that is now the ONLY
  choice for every remaining ordinary single-ended interface.

Logical signals awaiting a physical assignment:
`arinc_rx_i`/
`arinc_tx_ctrl_o`/`arinc_rx_adapter_error_i`/`arinc_tx_adapter_error_i`
(RTL-017/018), `can_rx_i`/`can_tx_o`/`can_transceiver_error_i` (RTL-019),
`uart_rx_i`/`uart_tx_o` (RTL-020),
`user_i`/`o`/`oe[3:0]` (out of scope --
RTL-022/023 dropped from this build per the demo-scope decision, see
`PROJECT_CONTINUITY.md` Section 5). `gpio_i`/`gpio_o`/`gpio_oe_o`
(RTL-006), `rotor_i` (RTL-007), `engine_i` (RTL-008), `pulse_i[1:0]`
(RTL-009), `health_i[7:0]` (RTL-011), and `safety_out_o[3:0]` (RTL-016)
are no longer in this list — see Sections 5, 6, 7, 8, 9, and 10, their
physical assignments are now real.

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

---

## 6. Rotor RPM Monitor (RTL-007) — J2 gp27, 1 channel

RTL-007 is the first module in the Monitoring domain with a real, physical
interface — a single asynchronous tachometer/RPM pulse input
(`rotor_i`), one physical pin.

| Signal | `gp<N>` | J1/J2 position | Row | FPGA site (real `.lpf`) | Direction |
|---|---|---|---|---|---|
| `rotor_i` | `gp27` | J2-27 | Outer (`+` / GP) | D13 | Input |

**Choice rationale:** per Section 4's own note, positions **J1-5 through
J1-7 and J2-22 through J2-27 are single-ended-only** (9 positions total).
RTL-006's GPIO channels used the first 8 (`gp5`/`gp6`/`gp7`/`gp22`-`gp26`,
Section 5), leaving `gp27` (J2-27) as the one remaining open
single-ended-only position — confirmed directly against
`ULX3S_CONNECTION_MAP.md`'s own Section 4 before choosing it, per this
project's standing rule to exhaust the single-ended-only range before
reaching into the differential-capable range. A single pulse input fits
this one remaining position exactly. **This exhausts the single-ended-only
positions entirely** — RTL-008 (Engine RPM Monitor, the next module
needing a physical pin, per `PROJECT_CONTINUITY.md`'s own build order) will
have to use the differential-capable range (J1-8–13 / J2-14–21) instead,
per Section 4's own updated note above.

The corresponding `gn27` inner-row pin is, as with every other position in
this project's real interfaces, a genuinely independent single-ended pin
this design does not use — not "the wasted other half" of a differential
pair (positions 22-27 are single-ended-only per the real schematic, same
as Section 1's `gn0`-`gn4` and Section 5's `gn5`-`gn7`/`gn22`-`gn26`).

`rotor_i` is a plain single-ended input (no tristate/output logic needed,
unlike Section 1's SPI MISO or Section 5's bidirectional GPIO channels) —
`ulx3s_dfc_top.sv` reads the pad directly into `dfc_rtl024.sv`'s own
`rotor_i` port, which `dfc_rtl007.sv` then synchronizes with its own
two-flop CDC-PULSE synchronizer (RTLSTD-CDC-008) before any use.

**Provenance:** the `gp27` → FPGA site mapping (D13) is fetched directly
from the real board constraint file (`emard/ulx3s`,
`doc/constraints/ulx3s_v20.lpf` — the same source Sections 1 and 5's own
mappings were fetched from), confirmed via a direct `curl`+`grep` of the
raw file content against the exact `LOCATE COMP "gp27"` line, not recalled
from memory or accepted from a single summarizing pass. The `gp27` →
"J2, position 27" correspondence follows the same silkscreen-position
convention already established and confirmed in Section 1.

---

## 7. Engine RPM Monitor (RTL-008) — J1 gp8, 1 channel

RTL-008 is the second module in the Monitoring domain with a real,
physical interface — a single asynchronous tachometer/RPM pulse input
(`engine_i`), one physical pin, functionally identical in kind to
Section 6's `rotor_i` but on completely independent hardware (its own
pad, its own CDC synchronizer instance, its own register block).

| Signal | `gp<N>` | J1/J2 position | Row | FPGA site (real `.lpf`) | Direction |
|---|---|---|---|---|---|
| `engine_i` | `gp8` | J1-8 | Outer (`+` / GP) | A4 | Input |

**Choice rationale:** per Section 4's own note, the 9 single-ended-only
positions (J1-5 through J1-7, J2-22 through J2-27) were fully exhausted by
RTL-006 (8 channels, Section 5) and RTL-007 (1 channel, `gp27`, Section 6).
**RTL-008 is therefore the first module in this project genuinely assigned
from the differential-capable range (J1-8 through J1-13, J2-14 through
J2-21)** — not a hard restriction, per ULX3S's own manual: "differential
pairs can be used also as single-ended pins," and this is exactly that
case (one single-ended tachometer input, no differential signal involved,
identical electrical usage to every other single-ended input already wired
in this project). `gp8` (J1-8) is the first position in position order
within that range, following the same "exhaust in position order" choice
rationale already used for Sections 5 and 6. `gp9`/`gp10` (J1-9/J1-10)
remain open and carry no wifi-sharing comment either, confirmed directly
against the real board file; `gp11`-`gp13` (J1-11 through J1-13) are
shared with the onboard WiFi module in the real board file's own comments
(`wifi_gpio26`/`wifi_gpio33`/`wifi_gpio35`) and are not a preferred choice
for a future module needing an unshared pin, though not used here.

**This is the first pin this project has assigned from the
differential-capable range.** Per Section 4's own corrected note (and
ULX3S's own official manual), `gp8`/`gn8` are physically paired for true
LVDS differential signaling — assigning `gp8` alone to an ordinary
single-ended signal means **`gn8` (SITE A5) is now implicitly unavailable
for a true differential pair with `gp8`** if this project ever needs real
LVDS signaling from this specific position later. `gn8` itself remains a
physically real, unused pin (not committed to anything) — the constraint
only affects its ability to be paired with `gp8` as a matched differential
signal; `gn8` could still be assigned as an independent single-ended pin
of its own, the same way `gn0`-`gn4`/`gn5`-`gn7`/`gn22`-`gn26`/`gn27` are
in every earlier section, just never as `gp8`'s differential partner.

`engine_i` is a plain single-ended input (no tristate/output logic
needed, same idiom as Section 6's `rotor_i`) — `ulx3s_dfc_top.sv` reads
the pad directly into `dfc_rtl024.sv`'s own `engine_i` port, which
`dfc_rtl008.sv` then synchronizes with its own, independent two-flop
CDC-PULSE synchronizer (RTLSTD-CDC-008) before any use — entirely separate
hardware from `dfc_rtl007.sv`'s own synchronizer on `rotor_i`, per
ARCH-RTL008-001's own "separate state prevents rotor/engine coupling"
requirement.

**Provenance:** the `gp8`/`gn8` → FPGA site mapping (A4/A5) is fetched
directly from the real board constraint file (`emard/ulx3s`,
`doc/constraints/ulx3s_v20.lpf` — the same source every earlier section's
own mappings were fetched from), confirmed via a direct `curl`+`grep` of
the raw file content against the exact `LOCATE COMP "gp8"`/`"gn8"` lines
(and the surrounding `gp9`-`gp13`/`gn9`-`gn13` lines, to directly confirm
which nearby positions carry a wifi-sharing comment and which don't), not
recalled from memory or accepted from a single summarizing pass. The
`gp8` → "J1, position 8" correspondence follows the same silkscreen-
position convention already established and confirmed in Section 1.

---

## 8. Pulse/Frequency Measurement (RTL-009) — J1 gp9/gp10, 2 channels

RTL-009 is the third module in the Monitoring domain with a real, physical
interface — two independent frequency-measurement pulse inputs sharing one
logical 2-bit `pulse_i[1:0]` port (per ARCH-002's own port catalog: "both
channels share this one 2-bit port ... there is no separate physical pin
per channel"), each requiring its own real physical pin.

| Signal | `gp<N>` | J1/J2 position | Row | FPGA site (real `.lpf`) | Direction |
|---|---|---|---|---|---|
| `pulse_i[0]` (channel 0) | `gp9` | J1-9 | Outer (`+` / GP) | A2 | Input |
| `pulse_i[1]` (channel 1) | `gp10` | J1-10 | Outer (`+` / GP) | C4 | Input |

**Choice rationale:** per Section 4's own note, the single-ended-only range
was fully exhausted by RTL-006/007 (Sections 5/6); RTL-008 (Section 7) was
the first module assigned from the differential-capable range (J1-8 through
J1-13, J2-14 through J2-21), taking `gp8`/J1-8, the first position in
position order. RTL-009 needs two more positions for its two channels;
`gp9`/J1-9 and `gp10`/J1-10 are the next two positions in position order
within that same range, continuing the project's own "exhaust in position
order" choice rationale already used for Sections 5, 6, and 7. `gp11`
through `gp13` (J1-11 through J1-13) are shared with the onboard WiFi
module in the real board file's own comments (`wifi_gpio26`/`wifi_gpio33`/
`wifi_gpio35`), confirmed directly against the real board file — not a
preferred choice for a future module needing an unshared pin, so this
module's two channels are placed at `gp9`/`gp10` rather than spilling into
the WiFi-shared range, leaving `gp11`-`gp13` plus `gp14`-`gp21` (J2) as the
11 positions still open (Section 4).

Both `pulse_i[0]`/`pulse_i[1]` are plain single-ended inputs (no tristate/
output logic needed, same idiom as Section 6/7's `rotor_i`/`engine_i`) —
`ulx3s_dfc_top.sv` reads the two pads directly into `dfc_rtl024.sv`'s own
`pulse_i[1:0]` port, which `dfc_rtl009.sv` then synchronizes with its own
two independent two-flop CDC-PULSE synchronizer instances (RTLSTD-CDC-008,
one per channel) before any use — entirely separate hardware from
`dfc_rtl007.sv`'s/`dfc_rtl008.sv`'s own synchronizers on `rotor_i`/
`engine_i`.

**This is the second and third pins this project has assigned from the
differential-capable range** (after `gp8`/RTL-008 in Section 7). Per
Section 4's own corrected note (and ULX3S's own official manual), `gp9`/
`gn9` and `gp10`/`gn10` are each physically paired for true LVDS
differential signaling — assigning `gp9`/`gp10` alone to ordinary
single-ended signals means **`gn9` (SITE B1) and `gn10` (SITE B4) are now
implicitly unavailable for a true differential pair with `gp9`/`gp10`
respectively** if this project ever needs real LVDS signaling from either
specific position later. `gn9`/`gn10` themselves remain physically real,
unused pins (not committed to anything) — the constraint only affects their
ability to be paired with `gp9`/`gp10` as matched differential signals;
either could still be assigned as an independent single-ended pin of its
own, the same way `gn8` (Section 7) and every earlier section's own
unused inner-row pins are.

**Provenance:** the `gp9`/`gn9`/`gp10`/`gn10` → FPGA site mapping
(A2/B1/C4/B4) is fetched directly from the real board constraint file
(`emard/ulx3s`, `doc/constraints/ulx3s_v20.lpf` — the same source every
earlier section's own mappings were fetched from), confirmed via a direct
`curl`+`grep` of the raw file content against the exact `LOCATE COMP
"gp9"`/`"gn9"`/`"gp10"`/`"gn10"` lines (and the surrounding
`gp11`-`gp13`/`gn11`-`gn13` lines, to directly confirm which nearby
positions carry the wifi-sharing comment and which don't), not recalled
from memory or accepted from a single summarizing pass. The `gp9`/`gp10` →
"J1, position 9"/"J1, position 10" correspondence follows the same
silkscreen-position convention already established and confirmed in
Section 1.

---

## 9. System Health Monitor (RTL-011) — J2 gp14-gp21, 8 channels

RTL-011 is the fifth module in the Monitoring domain with a real, physical
interface — 8 independent, synchronized/qualified/polarity-adjusted
external health-discrete inputs (`health_i[7:0]`), each requiring its own
real physical pin (confirmed directly against ARCH-002's own 17-port
catalog and the CDC-HEALTH table entry before writing `dfc_rtl011.sv` — the
producer is `RTL-024.health_in_o` but the real two-flop synchronizer is
owned by RTL-011 itself, the same "module owns its own synchronizer on the
raw pad" precedent already established by `gpio_i`/`rotor_i`/`engine_i`/
`pulse_i` in Sections 5-8, not a "pre-synchronized by RTL-024" case).

| `health_i` channel | `gp<N>` | J1/J2 position | Row | FPGA site (real `.lpf`) | Direction |
|---|---|---|---|---|---|
| 0 | `gp14` | J2-14 | Outer (`+` / GP) | U18 | Input |
| 1 | `gp15` | J2-15 | Outer (`+` / GP) | N17 | Input |
| 2 | `gp16` | J2-16 | Outer (`+` / GP) | N16 | Input |
| 3 | `gp17` | J2-17 | Outer (`+` / GP) | L16 | Input |
| 4 | `gp18` | J2-18 | Outer (`+` / GP) | H18 | Input |
| 5 | `gp19` | J2-19 | Outer (`+` / GP) | F17 | Input |
| 6 | `gp20` | J2-20 | Outer (`+` / GP) | D18 | Input |
| 7 | `gp21` | J2-21 | Outer (`+` / GP) | C18 | Input |

**Choice rationale, and an explicit flag, not a silent choice:** per
Section 4's own note, the differential-capable range still open before this
module was **J1-11 through J1-13 (WiFi-shared) plus J2-14 through J2-21
(unshared)** — 11 positions total. RTL-011 needs exactly 8. Rather than
"exhaust in strict position order" (which would reach into the WiFi-shared
J1-11-13 first, since they're numerically earlier), this module's 8
channels are placed at `gp14`-`gp21` — the entire unshared J2-14-through-21
range — following the same "prefer unshared over shared" precedent
Section 8 already established for RTL-009 (`gp9`/`gp10` chosen over
spilling into `gp11`-`gp13`). **This is a materially bigger consequence
than any prior single choice in this table: it consumes the ENTIRE
remaining unshared differential-capable range in one module.** After
RTL-011, `gp11`-`gp13` (WiFi-shared) are the ONLY differential-capable
positions left at all — any future module needing a physical pin no longer
has an unshared option to prefer; it must use one of these 3 WiFi-shared
positions. This is flagged here explicitly, exactly as the task that
produced this section required, even though the choice itself (using the
unshared range fully before ever touching the WiFi-shared one) is correct
and consistent with every prior section's own stated preference.

All 8 are plain single-ended inputs (no tristate/output logic needed, same
idiom as Sections 6/7/8's `rotor_i`/`engine_i`/`pulse_i[1:0]`) —
`ulx3s_dfc_top.sv` reads the eight pads directly into `dfc_rtl024.sv`'s own
`health_i[7:0]` port, which `dfc_rtl011.sv` then synchronizes with its own
8 independent two-flop CDC-HEALTH synchronizer instances (one per channel)
before any use — entirely separate hardware from every other monitoring
module's own synchronizers.

**This is the fourth through eleventh pins this project has assigned from
the differential-capable range** (after `gp8`/RTL-008 in Section 7 and
`gp9`/`gp10`/RTL-009 in Section 8). Per Section 4's own corrected note (and
ULX3S's own official manual), `gp14`-`gp21` are each physically paired with
their own `gn14`-`gn21` counterpart for true LVDS differential signaling —
assigning `gp14`-`gp21` alone to ordinary single-ended signals means
**`gn14`-`gn21` (SITEs U17/P16/M17/L17/H17/G18/E17/D17) are now implicitly
unavailable for a true differential pair** with their respective `gp<N>`,
same disclosed consequence as every earlier differential-capable
assignment in this project. `gn14`-`gn21` themselves remain physically
real, unused pins (not committed to anything) — the constraint only
affects their ability to be paired with their own `gp<N>` as a matched
differential signal; any could still be assigned as an independent
single-ended pin of its own, the same way `gn8`/`gn9`/`gn10` are in
Sections 7/8.

**Provenance:** the `gp14`-`gp21` → FPGA site mapping
(U18/N17/N16/L16/H18/F17/D18/C18) is fetched directly from the real board
constraint file (`emard/ulx3s`, `doc/constraints/ulx3s_v20.lpf` — the same
source every earlier section's own mappings were fetched from), confirmed
via a direct `curl`+`grep` of the raw file content against the exact
`LOCATE COMP "gp14"` through `"gp21"` lines (and their `gn14`-`gn21`
counterparts, to directly confirm none carry a wifi-sharing comment, unlike
`gp11`-`gp13`), not recalled from memory or accepted from a single
summarizing pass. The `gp14`-`gp21` → "J2, position 14" through "J2,
position 21" correspondence follows the same silkscreen-position convention
already established and confirmed in Section 1.

---

## 10. Safety Output Controller (RTL-016) — J1 gn8/gn9/gn10, J2 gn14, 4 channels

RTL-016 is the fifth and FINAL Safety-domain module with a real, physical
interface — 4 independent logical safety-output pads (`safety_out_o[3:0]`),
the sole external output this module owns (`ulx3s_dfc_top.sv`'s own
`dragon_core_top` instantiation previously left `safety_out_o` entirely
unconnected, `()`, since no pin existed for it yet).

| `safety_out_o` channel | Pin | J1/J2 position | FPGA site (real `.lpf`) | Direction |
|---|---|---|---|---|
| 0 | `gn8`  | J1-8 (`gn` conductor) | A5  | Output |
| 1 | `gn9`  | J1-9 (`gn` conductor) | B1  | Output |
| 2 | `gn10` | J1-10 (`gn` conductor) | B4  | Output |
| 3 | `gn14` | J2-14 (`gn` conductor) | U17 | Output |

**Choice rationale, and an explicit flag, not a silent choice:** per
Section 4's own running accounting, the only positions open for a NEW
differential-CAPABLE PAIR were `gp11`-`gp13`/`gn11`-`gn13` (WiFi-shared,
the sole remainder after Section 9 exhausted the unshared range). RTL-016
needs 4 real output pins, but **does not need a true differential pair at
all** — each channel is an ordinary single-ended logic-level output. This
project's own running record of "orphaned" `gn<N>` pins (the differential
counterpart of a `gp<N>` already committed to an ordinary single-ended
signal, hence genuinely free for independent use — Sections 7/8/9's own
notes on `gn8`/`gn9`/`gn10`/`gn14`-`gn21`) gave **11 such real, physically
free pins without touching the WiFi-shared range at all.** RTL-016 uses
the four LOWEST-numbered of these — `gn8`, `gn9`, `gn10`, `gn14` — the
same "prefer the earliest available option" precedent every earlier
section in this table has used, leaving `gn15`-`gn21` (7 pins) plus the
still-untouched WiFi-shared `gp11`-`gp13`/`gn11`-`gn13` (3 true pairs) for
whichever module needs a pin next.

**This flags a genuine, tightening project-wide constraint, not discovered
silently later:** RTL-017 (ARINC RX), RTL-018 (ARINC TX), RTL-019 (CAN),
and RTL-020 (UART) each still need one or more real pins of their own
(`arinc_rx_i`, `can_rx_i`/`can_tx_o`, `uart_rx_i`/`uart_tx_o`, at minimum —
`arinc_tx_ctrl_o` is 2 bits). After RTL-016, the only pins left for them
are: `gn15`-`gn21` (7 single-ended-only-now positions, their own `gp15`-
`gp21` partners already committed to RTL-011), and the 3 WiFi-shared true
pairs `gp11`-`gp13`/`gn11`-`gn13` (6 individual conductors, or 3 true
differential pairs). This is enough for the four remaining Databus-domain
modules' currently-known needs, but there is no further "free" margin
beyond this — any later module needing a pin this accounting did not
already name will have to use one of the WiFi-shared positions. Flagged
here explicitly, as the task that produced this section required.

Each of the four is a pure output (no tristate, no pull resistor needed —
`IOBUF PORT ... PULLMODE=NONE`, the same convention this project's own
Debug LED section already uses for a pure ECP5-driven output, not the
`PULLMODE=UP` convention every input pin in this table uses).
`ulx3s_dfc_top.sv` drives the four pads directly from `dragon_core_top`'s
own real `safety_out_o[3:0]` port — no additional pad-safe gate is layered
at the top level, since `dfc_rtl016.sv` itself already implements the
complete `PERMIT[c]` gate (reset/test/inhibit/disable all dominate,
ARCH-RTL016-001) before the signal ever reaches this boundary, the same
"module's own real gating is already complete" precedent Section 5's own
GPIO note established.

**Provenance:** the `gn8`/`gn9`/`gn10`/`gn14` FPGA site mapping
(A5/B1/B4/U17) is fetched directly from the real board constraint file
(`emard/ulx3s`, `doc/constraints/ulx3s_v20.lpf` -- the same source every
earlier section's own mappings were fetched from), confirmed via a direct
`curl`+`grep` of the raw file content against the exact `LOCATE COMP
"gn8"`/`"gn9"`/`"gn10"`/`"gn14"` lines, re-verifying they carry no
wifi-sharing comment (unlike `gn11`-`gn13`'s own `wifi_gpio25`/
`wifi_gpio32`/`wifi_gpio34` comments), not recalled from memory or
accepted from a single summarizing pass. The J1/J2 position label for each
`gn<N>` follows the same convention as every earlier section: the position
number of its paired `gp<N>` silkscreen position, since `gn<N>` is the
second conductor at that same physical header position.
