# RTL-007 Module Specification — Rotor RPM Monitor

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-007 measures rotor RPM from a single edge input, in either period mode
(low RPM) or count mode (high RPM), with automatic hysteretic mode
switching, configurable thresholds/hysteresis/timeout, and fault-request
output. Owns REG-002's Rotor RPM block (0x2000–0x20FF, 11 registers).

Controlling documents: `ARCH-002` SS9 `ARCH-MON-002`/`003`/`005` (edge
qualification, RPM arithmetic, threshold/timeout — shared verbatim with
RTL-008/009), Appendix F.1 `ARCH-RTL007-001`, Appendix F.3 index 6 (0 low,
1 high, 2 timeout, 3 updated, 4 recovery, 5 saturation/range, 6
event-slot-overflow), VP-002 `VP-MOD-007`/`VP-MON-001`/`VP-MON-002`.

## 2. Ports (per Architecture catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[6]`), `control_i` (`dfc_rtl007_control_t`, 135
bits)/`status_o` (`dfc_rtl007_status_t`, 73 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 6), `irq_req_o`
(RTL-003 index 8), `fault_req_o` (RTL-013 fault-source-matrix bit),
`operating_state_i`, `observational_mode_i`, `module_enable_i`
(optional-mask module), condition-enable pair. RTL-007-specific:
**`rotor_i`** (single asynchronous external edge input, `CDC`-synchronized
before any use per `RTLSTD-CDC-008`).

## 3. Packed control/status fields (confirmed, ARCH-002 Appendix B.5)

`dfc_rtl007_control_t` (135 bits): `enable`, `rising_edge` (reset **1**),
`event_enable`, `irq_enable`, clear-mask bits for
`timeout`/`range_error`/`updated`, `thresh_low`/`thresh_high` (16-bit,
reset 0/1000), `pulses_per_rev` (16-bit, reset 1), `timeout_us` (32-bit,
reset 100,000), `edge_filter.min_edge_cycles` (32-bit, reset 0),
`hysteresis` (16-bit, reset 0).

`dfc_rtl007_status_t` (73 bits): `ready`/`fault`/`event_overflow`,
`rotor_status` bits `valid`/`low`/`high`/`timeout`/`range_error`/`updated`,
`rotor_rpm` (16-bit saturating readback), `rotor_period_ticks` (32-bit),
`event_drop_count` (16-bit saturating).

## 4. Edge, measurement, and threshold contract (`ARCH-MON-002/003/005`)

- **`ARCH-MON-002`** (edge qualification/mode selection, shared by
  RTL-007/008/009): a selected edge is accepted only after
  `MIN_EDGE_CYCLES` since the preceding accepted edge. **Period mode**
  after 2 consecutive periods ≥1,000 cycles; **count mode** after 2
  consecutive periods <1,000 cycles; **return to period mode** after 2
  consecutive periods >1,250 cycles (hysteretic band prevents chatter at
  the boundary). Count-mode gate is 100,000 cycles.
- **`ARCH-MON-003`** (RPM arithmetic): period mode —
  `RPM = round_nearest((60 × 50,000,000) / (period_ticks × PPR))`; count
  mode — `round_nearest((edge_count × 50,000,000 × 60) / (100,000 × PPR))`.
  **Ties round upward.** A ≥64-bit unsigned intermediate is required; the
  16-bit result **saturates** (never wraps).
- **`ARCH-MON-005`** (timeout/threshold): no-edge elapsed time is a
  saturating microsecond counter; reaching the configured nonzero timeout
  clears `valid` and sets `timeout`. **Low** enters at value `< LOW`, exits
  at `>= LOW + HYST`; **High** enters at `> HIGH`, exits at `<= HIGH -
  HYST`; unsigned arithmetic saturates at its numeric limits. A newly
  committed measurement is compared **in its own commit cycle** (not
  deferred).

Per `ARCH-RTL007-001`: reset clears history/valid; a newly committed
measurement precedes threshold-event evaluation (i.e. the fresh value is
what gets compared, not the stale prior one).

## 5. Registers owned (REG-002 0x2000–0x20FF, 11 registers)

Enable/edge-select/mask control, threshold-low/high, hysteresis, PPR,
timeout, edge-filter, RPM/period readback, status, and
`RTL007_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-007-owned entries directly.

## 6. Verification obligations

- **`VP-MOD-007`**: edge qualification, mode selection, arithmetic,
  rounding, saturation, timeout, thresholds, hysteresis, evidence, reset,
  and validation satisfy `ARCH-RTL007-001`/`ARCH-VAL-007`.
- **`VP-MON-001`**: period-mode/count-mode equations, rounding,
  saturation, PPR, mode-transition hysteresis, and numeric limits match
  `ARCH-MON-002`–`005` exactly — this is an arithmetic-correctness case
  (`A-CALC`), test at the exact boundary values, not just typical inputs.
- **`VP-MON-002`**: SRS minimum/nominal/maximum/transition/noise-filter/
  missing-edge/timeout boundaries meet accuracy/update requirements.
