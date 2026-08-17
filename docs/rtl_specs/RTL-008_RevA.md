# RTL-008 Module Specification — Engine RPM Monitor

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-008 is functionally identical to RTL-007 (same `ARCH-MON-002`/`003`/
`005` algorithm), applied to a separate engine edge input with its own
range/configuration and **completely independent state** — deliberately,
per `ARCH-RTL008-001`: "separate state prevents rotor/engine coupling."
This spec does not repeat RTL-007's algorithm text (`CHTR-DOC-003`); it
records only what differs. Owns REG-002's Engine RPM block (0x2100–0x21FF,
11 registers).

Controlling documents: same as RTL-007 (`ARCH-MON-002`/`003`/`005`), plus
`ARCH-RTL008-001` (Appendix F.1) and `VP-MOD-008`.

## 2. Ports

Identical structure to RTL-007: `module_reset_i`
(`RTL-002.module_reset_o[7]`), `control_i` (`dfc_rtl008_control_t`, 135
bits)/`status_o` (`dfc_rtl008_status_t`, 73 bits), `irq_req_o` (RTL-003
index 9), `fault_req_o`, condition-enable pair (index 7), and the
module-specific **`engine_i`** edge input (separate physical pin from
`rotor_i`, separate synchronizer instance — no shared hardware with
RTL-007).

## 3. Confirmed field-level differences from RTL-007 (Appendix B.5)

`dfc_rtl008_control_t`: same field structure as RTL-007's, with different
reset defaults reflecting engine's higher nominal range —
`thresh_high` resets to **20,000** (vs. rotor's 1,000), `pulses_per_rev`
resets to **1** (same as rotor). All other resets (`rising_edge`=1,
`timeout_us`=100,000, `edge_filter`=0, `hysteresis`=0) match RTL-007
exactly. `dfc_rtl008_status_t` is bit-for-bit structurally identical to
`dfc_rtl007_status_t` (73 bits, same field set) — confirming the
"identical algorithm, separate instance" relationship exactly.

## 4. What genuinely differs (per `ARCH-RTL008-001`)

**Only the configured range/thresholds and the physical input pin.** The
edge-qualification, mode-selection, RPM arithmetic, and threshold/timeout
mechanics are the *same equations* as RTL-007's SS4 — implement from the
same verified logic, parameterized by this module's own register values,
not by copying RTL-007's RTL and hand-tweaking constants (which would
violate `RTLSTD-PRIN-010`'s prohibition on establishing product
functionality by example/template copying — the shared *algorithm* is
Architecture-owned; each module's *instance* of it is independent per
`RTLSTD-PRIN-011`'s strict module-isolation rule).

## 5. Registers owned (REG-002 0x2100–0x21FF, 11 registers)

Same register *shape* as RTL-007 (enable/edge-select, threshold-low/high,
hysteresis, PPR, timeout, edge-filter, RPM/period readback, status,
`RTL008_EVT_OVERFLOW_STATUS`) at the 0x2100 base instead of 0x2000.
Implement against `dfc_registers_pkg.json`'s RTL-008-owned entries.

## 6. Verification obligations

- **`VP-MOD-008`**: edge qualification, high-rate mode, arithmetic,
  rounding, saturation, timeout, thresholds, hysteresis, **independence**
  (from RTL-007), evidence, reset, and validation satisfy
  `ARCH-RTL008-001`/`ARCH-VAL-008`.
- The independence requirement is directly testable: driving `rotor_i`
  and `engine_i` with different edge patterns simultaneously and
  confirming neither module's state reflects the other's input is a
  cheap, high-value regression case worth automating early.
