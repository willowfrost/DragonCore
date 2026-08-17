# RTL-010 Module Specification — Sensor Monitor Interface

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-010 accepts **host-written or routed-message-updated** signed sensor
values on two channels, with signed threshold/hysteresis comparison, an
age/staleness model, and atomic value/valid/source/sequence commit. This
is the first Monitoring module whose input is not a physical edge pin —
its "sensor" values arrive via register write or the databus routing
engine (RTL-021), not a dedicated wire. Owns REG-002's Sensor Monitor
block (0x2300–0x23FF, 25 registers — the largest Monitoring-domain
register footprint, reflecting two full independent channels plus routing
metadata).

Controlling documents: `ARCH-002` SS9 `ARCH-MON-006`/`007`, Appendix F.1
`ARCH-RTL010-001`, Appendix F.3 index 9 (0–3 sensor 0
low/high/stale/invalid, and by the documented pattern 4–7 sensor 1 same
order, 8 event-slot overflow), VP-002 `VP-MOD-010`/`VP-MON-006`/`VP-MON-007`.

## 2. Ports (16 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[9]`), `control_i` (`dfc_rtl010_control_t`, 345
bits)/`status_o` (`dfc_rtl010_status_t`, 225 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 9), `irq_req_o`
(RTL-003 index 11), `fault_req_o` (RTL-013 fault-source bit 9),
`operating_state_i`, `observational_mode_i`, `module_enable_i`
(optional-mask), condition-enable pair. **No dedicated physical sensor
input port** — sensor values arrive exclusively through `control_i`
(host writes) and the routed-update path Appendix F.3/`ARCH-MON-007`
describe; RTL-010 has no `CDC`-relevant external pin at all.

## 3. Signed comparison and update-arbitration contract

- **`ARCH-MON-006`**: value, low threshold, high threshold, and hysteresis
  are **signed 32-bit two's-complement**. Valid-low enters at `value <
  low`, exits at `value >= low + hyst`; valid-high enters at `value >
  high`, exits at `value <= high - hyst`; **signed** bound arithmetic
  saturates (distinct from RTL-007/008/009's unsigned saturation — a
  signed saturating add/subtract, not an unsigned clamp).
- **`ARCH-MON-007`** (update arbitration and age/stale): a host or routed
  commit **atomically** replaces value, valid, 7-bit source, 24-bit
  sequence, and resets age to 0. **Host has same-cycle priority** over a
  routed update (matching `ARCH-REG-005`'s general host-wins rule). Age
  increments every 1ms tick and **saturates**. Nonzero `MAX_AGE` asserts
  `stale` when `age > MAX_AGE`; **zero disables staleness checking**
  entirely (not "stale after 0ms" — a common misreading to guard against).
  Low, high, stale, and invalid are **four independent** event/interrupt
  mask bits `[0]`–`[3]` — not a single combined "out of range" bit.

Per `ARCH-RTL010-001`: evaluation order is **host commit precedes routed
commit, then age tick, then threshold evaluation, then evidence clear** —
a fixed pipeline order every cycle, not an arbitrary/interleaved one.

## 4. Registers owned (REG-002 0x2300–0x23FF, 25 registers)

Per-channel value/threshold-low/threshold-high/hysteresis (all signed
32-bit), source/sequence/age readback, event/IRQ config
(`SENSORn_EVENT_IRQ_CFG`, confirmed 4-bit `EVENT_ENABLE`/4-bit
`IRQ_ENABLE` split per channel — matching the four independent evidence
bits above), status, meta, and `RTL010_EVT_OVERFLOW_STATUS`. Implement
against `dfc_registers_pkg.json`'s RTL-010-owned entries; note the signed
interpretation must be preserved exactly through register read/write
(`VP-REG-014`'s cross-cutting requirement applies directly here).

## 5. Verification obligations

- **`VP-MOD-010`**: signed thresholds/hysteresis, atomic
  value/valid/source/sequence update, host priority, age/stale,
  independent evidence masks, reset, ready, fault, and validation satisfy
  `ARCH-RTL010-001`/`ARCH-VAL-010`.
- **`VP-MON-006`**: sampled-sensor value/low/high/hysteresis comparisons
  exercise the **complete signed representation** — negative, zero,
  positive, minimum, maximum, and saturated-bound cases. This is not
  optional coverage; `ARCH-MON-006`'s signed-saturation behavior has real
  edge cases at `INT32_MIN`/`INT32_MAX` that unsigned-arithmetic intuition
  gets wrong.
- **`VP-MON-007`**: a host or routed update atomically replaces
  value/valid/source/sequence/age; **host wins a same-cycle conflict and
  no mixed record is ever observable** — this is exactly the kind of
  atomicity claim that needs a dedicated simultaneous-write testbench
  case, not incidental coverage from ordinary tests.
