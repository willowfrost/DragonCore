# RTL-013 Module Specification — Fault Manager

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-013 is the Dragon Core Fault Manager: the **sole consumer** of the
fixed 32-bit fault-source matrix (Appendix C.6 — 17 assigned bits 0–16,
15 reserved 17–31, closing the project's originally-flagged Gap 3),
classifying each source's recoverability, selecting a primary source, and
requesting **lane 1** of the safety-response matrix on any nonrecoverable
evidence. Owns REG-002's Fault Manager block (0x3100–0x31FF, 9 registers).

Controlling documents: `ARCH-002` SS10.1, Appendix C.6 (the fault-source
matrix — already mechanically extracted into `dfc_interrupt_pkg` by
`tools/pkggen/extract_irqfault.py`; this module's implementation should
consume that generated data, not re-derive the matrix), Appendix F.1
`ARCH-RTL013-001`, VP-002 `VP-MOD-013`/`VP-SAFE-005`.

## 2. Ports (per Architecture catalog, confirmed fragments)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[12]`), `control_i`/`status_o`, `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 12),
`operating_state_i`, `observational_mode_i`, condition-enable pair.
RTL-013-specific: **`fault_source_i[31:0]`** (the fixed Appendix C.6
matrix — one dedicated port per assigned bit 0–16, each a specific
module's `fault_req_o`; bit 10 is `RTL-017.fault_req_o` per the confirmed
matrix; constant-zero tied for bits 17–31), **`degraded_req_o`** (into
`RTL-002.degraded_req_i`), **`faulted_req_o`** (into
`RTL-002.faulted_req_i`), **`response_req_o`** (`dfc_safety_response_req_t`,
lane 1, source ID fixed at 0), **`safety_inhibit_o[3:0]`** (all four bits
tied equal to the OR of active nonrecoverable fault sources — feeds
RTL-016's `fault_inhibit_i` directly, per SS10.4's equation below).

## 3. Fault classification contract (`ARCH-002` SS10.1)

For each source bit `i`:

```
ACTIVE[i]        = current qualified source (from fault_source_i[i])
STICKY[i]_next   = ACTIVE[i] | (STICKY[i] & !CLEAR[i])
```

**Clear is effective only when `ACTIVE[i]` is zero** — a host clear
attempt against a still-active source is silently ineffective (this is
the "new active dominates clear" rule stated in `ARCH-RTL013-001`, applied
per-bit).

- **Primary source** = the lowest-numbered *active* bit, or (if none
  active) the lowest-numbered *sticky* bit.
- **Fixed recoverability mask is `0x00017FEF`**; bits outside 0–16 are
  zero and rejected in any configuration mask a host attempts to write.
  Decode this mask directly — bit `i` of `0x00017FEF` set means source `i`
  is recoverable; clear means nonrecoverable. (Verify this against the
  actual mask value before implementing: `0x00017FEF` = binary
  `1_0111_1111_1110_1111` across bits 16..0 — confirm each bit's
  recoverability against Appendix C.6's own per-source class column
  rather than trusting a manual bit-count here.)
- **Nonrecoverable** active-or-sticky evidence requests **FAULTED**;
  **recoverable** active evidence requests **DEGRADED**. Fault class,
  event, interrupt, and safety-response outputs all **preserve the source
  bit identity** — never collapse to a generic "a fault happened" signal.

Per `ARCH-RTL013-001`: **active source identity is retained in event
data** (the emitted `dfc_event_record_t` must carry which source, not just
that a fault occurred).

## 4. Registers owned (REG-002 0x3100–0x31FF, 9 registers)

Fault-class configuration, `FAULT_ACTIVE_SOURCE` (RO, confirmed real
register at `0x3114`), `FAULT_LATCHED_SOURCE` (W1C, confirmed at `0x3118`),
primary-source readback, degraded/faulted request status, response-mask
authorization (bit 8 only, per `REG-ENC-015`/Appendix C.8's "lane 1 source
0"), and `RTL013_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-013-owned entries.

## 5. Verification obligations

- **`VP-MOD-013`**: fixed allocation, class, recoverability, active/latched
  state, primary selection, degraded/fault state, response, evidence,
  injection, clear/reset priority, and validation satisfy
  `ARCH-RTL013-001`/`ARCH-VAL-013`.
- **`VP-SAFE-005`**: all 17 fixed fault sources, all 15 reserved sources,
  class values, recoverability, active/latched masks, primary selection,
  degraded/fault state, response request, clear, and reassertion behavior
  match SS10.1 and Appendix C.6 **exactly** — this is 17 distinct sources
  each needing their own recoverability-class-specific test, not a
  generalized "faults work" case.

## 6. Known dependency gap

`fault_source_i[31:0]`'s 17 real producers don't exist yet (only RTL-001
is real, and RTL-001 isn't one of the 17 assigned fault sources per the
matrix — check `dfc_interrupt_pkg`'s extracted data for which module owns
each bit before assuming). A first implementation is testable against the
recoverability-mask/primary-selection/lane-1-response logic using forced
`fault_source_i` values, not real fault conditions. Disclose per the
established pattern.
