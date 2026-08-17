# RTL-006 Module Specification — GPIO Controller

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-006 is the Dragon Core GPIO Controller: synchronizes/qualifies 8
external GPIO inputs, drives 8 GPIO outputs with output-enable gating, and
generates independently-masked rising/falling/either-edge/active-high/
active-low event and interrupt subconditions per channel. Owns REG-002's
GPIO block (0x0400–0x04FF, 14 registers).

Controlling documents: `ARCH-002` SS9 `ARCH-MON-001` (the entire
functional algorithm), Appendix F.1 `ARCH-RTL006-001`, Appendix F.3 index
5 (0–7 rising, 8–15 falling, 16–23 active-high level, 24–31 active-low
level, 32–39 either-edge, 40 event-slot overflow — a materially larger
condition-mask footprint than most modules, reflecting 8 channels × 5
subcondition types), VP-002 `VP-MOD-006`/`VP-INF-013`.

## 2. Ports (20 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[5]`), `control_i` (`dfc_rtl006_control_t`, 114
bits)/`status_o` (`dfc_rtl006_status_t`, 51 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 5),
`operating_state_i`, `observational_mode_i`, `module_enable_i`
(`RTL-002.module_enable_o[5]` — RTL-006 is one of the optional-mask
modules, per `SUBSYS_ENABLE`'s `0x7F07E0` configurable set), condition-
enable pair (index 5). RTL-006-specific: **`gpio_i[7:0]`** (raw external
input, synchronized via `ARCH-MON-001`), **`gpio_o[7:0]`/`gpio_oe_o[7:0]`**
(output data/enable, RTL-024-pad-safe-gated per `ARCH-CONN-012`),
**`irq_req_o`** (source index 2 into RTL-003).

## 3. Synchronization, qualification, and output contract (`ARCH-MON-001`)

- **Input path**: each GPIO input passes a **two-flop synchronizer**
  followed by an **8-bit millisecond stable-time counter**. Qualification
  value **zero** passes the second-stage synchronized value through
  without delay; a **nonzero** qualification value commits a change only
  after that many consecutive 1ms samples agree.
- **Output enable**: effective OE = `direction_bit AND module_enable AND
  effective_operational_enable AND NOT (reset OR test OR observation)`.
  Per `ARCH-RTL006-001`: **reset and disable force OE to zero *before***
  evaluating routes or output data — OE gating is unconditional and
  precedes any route/data logic, not a parallel/racing condition.
- **Subconditions**: rising, falling, either-edge, active-high level, and
  active-low level are **independently masked per channel** (this is the
  source of Appendix F.3's 40-bit condition allocation for this one
  module). Level-type requests remain active for as long as the qualified
  level matches; edge-type requests are single-cycle pulses on the
  qualified transition.

Per `ARCH-RTL006-001`: ready requires legal channel configuration; fault
is illegal configuration or an unrecoverable qualification-logic error.

## 4. Registers owned (REG-002 0x0400–0x04FF, 14 registers)

Direction/output-data/input-readback registers, `EFFECTIVE_OUTPUT` (RO,
confirmed real field per-channel — REG-002 now exposes the post-permit
output state directly), `QUALIFICATION_IN_PROGRESS` (RO, confirmed real
field — resolves this spec's previously-flagged gap), per-channel
qualification-time configuration, per-channel event/interrupt
subcondition enable masks (rising/falling/level-high/level-low/either-edge
— 5 sub-fields per channel, matching the F.3 allocation above), and
`RTL006_EVT_OVERFLOW_STATUS`. Offsets/fields are REG-002's authority;
implement against `dfc_registers_pkg.json` directly.

## 5. Verification obligations

- **`VP-MOD-006`**: synchronization, qualification, output gating, route
  combination, event/interrupt conditions, safe reset, disable, ready,
  fault, and validation satisfy `ARCH-RTL006-001` and `ARCH-VAL-006`.
- **`VP-INF-013`**: synchronization, qualification, input readback,
  direction/output gating, route combination, safe reset, and independent
  edge/level event and interrupt masks all match `ARCH-MON-001` exactly —
  given the 5-subcondition-per-channel surface, this case is large in
  practice; don't sample channels, exercise all 8 × 5 combinations.

## 6. Note on scope relative to other Infrastructure modules

Unlike RTL-003/004/005 (which are purely internal/logical), RTL-006 is the
first Infrastructure module with real external I/O (`gpio_i`/`gpio_o`/
`gpio_oe_o`, ultimately RTL-024's external pads) and the first with a
genuinely optional (host-disable-able) enable path. It is also, alongside
RTL-004, implementable and testable today without other Infrastructure
siblings existing, since its only cross-module dependencies
(`operating_state_i`, `module_enable_i`, condition masks) are already real
outputs of RTL-001/dfc_rtl001.sv or straightforward to stub honestly.
