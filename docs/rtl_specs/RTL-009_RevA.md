# RTL-009 Module Specification — Pulse/Frequency Measurement

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-009 measures frequency on **two fully independent channels** in
unsigned Q17.15 fixed-point hertz, sharing the same `ARCH-MON-002`
edge-qualification/mode-selection logic as RTL-007/008 but with
`ARCH-MON-004`'s distinct Q17.15 arithmetic in place of RPM arithmetic.
Owns REG-002's Pulse/Frequency block (0x2200–0x22FF, 19 registers).

Controlling documents: `ARCH-002` SS9 `ARCH-MON-002`/`004`/`005`,
Appendix F.1 `ARCH-RTL009-001` ("each channel independently applies
`ARCH-MON-002`, `004`, and `005`; same-cycle accepted edges update both
channel states independently"), Appendix F.3 index 8 (bits 0–5 channel 0
low/high/timeout/updated/recovery/saturation, bits 8–13 channel 1 same
order, bit 16 event-slot overflow), VP-002 `VP-MOD-009`/`VP-MON-003`/
`VP-MON-004`.

## 2. Ports (17 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[8]`), `control_i` (`dfc_rtl009_control_t`, 334
bits)/`status_o` (`dfc_rtl009_status_t`, 159 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 8), `irq_req_o`
(RTL-003 index 10), `fault_req_o` (RTL-013 fault-source bit 8),
`operating_state_i`, `observational_mode_i`, `module_enable_i`
(optional-mask), condition-enable pair. RTL-009-specific:
**`pulse_i[1:0]`** — **both channels share this one 2-bit port**
(`CDC-PULSE`-synchronized), channel 0 = bit 0, channel 1 = bit 1; there is
no separate physical pin per channel.

## 3. Confirmed packed fields (Appendix B.5) — two identical channel blocks

`dfc_rtl009_control_t` (334 bits) is **two structurally identical
135-bit-equivalent channel blocks concatenated**, plus two shared
hysteresis fields at the top: channel 0 occupies bits 0–134
(`enable`/`rising_edge`(reset 1)/`event_enable`/`irq_enable`, clear-masks
for `timeout`/`range_error`/`updated`, `thresh_low_q17_15` (32-bit, reset
`0x00004000` = 0.5Hz in Q17.15), `thresh_high_q17_15` (32-bit, reset
`0xC3500000`), `timeout_us` (32-bit, reset 2,500,000), `edge_filter`
(32-bit, reset 0)); channel 1 occupies bits 135–269, byte-identical
structure; bits 270–333 hold `pulse0_hysteresis_q17_15` and
`pulse1_hysteresis_q17_15` (32-bit each, reset 0) as a **shared trailing
pair**, not interleaved per-channel — implement exactly this bit layout,
not a "logical" per-channel grouping that happens to produce the same
total width.

`dfc_rtl009_status_t` (159 bits): `ready`/`fault`/`event_overflow`, then
two identical per-channel blocks (`valid`/`low`/`high`/`timeout`/
`range_error`/`updated`, `freq_q17_15` readback, `period_ticks`
readback), then `event_drop_count`.

## 4. Q17.15 arithmetic (`ARCH-MON-004`) — the one thing genuinely
different from RTL-007/008

```
FREQ_Q17_15 = round_nearest((50,000,000 << 15) / period_ticks)          -- period mode
FREQ_Q17_15 = round_nearest((edge_count × 50,000,000 << 15) / 100,000)  -- count mode
```

**Ties round upward.** A ≥64-bit intermediate is required; the **32-bit**
result saturates (wider than RTL-007/008's 16-bit RPM result, since Q17.15
carries 15 fractional bits — a 0.5Hz-100kHz range in Q17.15 needs the full
32 bits, not a coincidental oversizing).

Edge qualification (`ARCH-MON-002`) and timeout/threshold (`ARCH-MON-005`)
are the *same* equations as RTL-007/008's SS4 — this spec does not repeat
them (`CHTR-DOC-003`); implement from the shared algorithm text, applied
independently per channel per `ARCH-RTL009-001`.

## 5. Registers owned (REG-002 0x2200–0x22FF, 19 registers)

Per-channel control/status/freq/period/thresholds(Q17.15)/timeout/
edge-filter/hysteresis(Q17.15), plus one shared
`RTL009_EVT_OVERFLOW_STATUS` at `0x2250`. Note the layout is **not**
contiguous per channel — `PULSE1_HYSTERESIS_Q17_15` sits at `0x2254`,
*after* the shared overflow register, not adjacent to `PULSE1_CONTROL`'s
block; implement against REG-002's actual offsets, not an assumed
symmetric layout.

## 6. Verification obligations

- **`VP-MOD-009`**: both channels independently satisfy edge
  qualification, Q17.15 arithmetic, rounding, saturation, timeout,
  thresholds, hysteresis, **simultaneous edges**, evidence, reset, and
  `ARCH-VAL-009`.
- **`VP-MON-003`**/**`004`**: both channels independently satisfy the full
  algorithm set; concurrent channels at all SRS range/timing boundaries
  remain **independent** — same "don't let one channel's test data leak
  into the other's expected result" discipline as RTL-007/008's
  independence case, but sharper here since both channels share one
  physical input port (`pulse_i[1:0]`) and one register file.
