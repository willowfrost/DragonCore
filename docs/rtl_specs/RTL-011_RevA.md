# RTL-011 Module Specification — System Health Monitor

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-011 synchronizes, qualifies, and monitors **8 discrete external health
inputs**, each independently configurable for polarity, with sticky
active-capture, one-cycle recovery pulses, per-channel qualification
timeout detection, and an aggregate fault output. Owns REG-002's System
Health block (0x2400–0x24FF, 13 registers).

Controlling documents: `ARCH-002` SS9 `ARCH-MON-008` (the entire
functional algorithm), Appendix F.1 `ARCH-RTL011-001`, VP-002
`VP-MOD-011`.

## 2. Ports (17 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[10]`), `control_i` (`dfc_rtl011_control_t`, 113
bits)/`status_o` (`dfc_rtl011_status_t`, 67 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 10), `irq_req_o`
(RTL-003 index 12), `fault_req_o` (RTL-013 fault-source bit 4),
`operating_state_i`, `observational_mode_i`, `module_enable_i`
(optional-mask), condition-enable pair. RTL-011-specific:
**`health_i[7:0]`** (8 external discrete inputs, `CDC-HEALTH`-synchronized
before any use).

## 3. Synchronization, polarity, and sticky/recovery contract (`ARCH-MON-008`)

- Each health input uses a **two-flop synchronizer**, a **polarity
  transform**, and **stable-time qualification** (same qualification-timer
  discipline as RTL-006's GPIO path, applied here per-channel to a
  monitoring rather than I/O role).
- `active = qualified XOR !ACTIVE_HIGH` — i.e. the qualified,
  synchronized input, exclusive-ORed with the *inverse* of the configured
  polarity bit. Get the polarity direction right: `ACTIVE_HIGH=1` means
  the qualified value *is* `active` directly (XOR with 0); `ACTIVE_HIGH=0`
  inverts it.
- **`sticky` captures `active`** — once set, sticky remains until an
  explicit host clear (standard W1C discipline, not itself re-derived
  here).
- **`recovered` pulses for exactly one cycle** when a previously-active
  channel transitions to inactive — a pulse, not a level; a channel that
  never went active produces no recovery pulse when it "becomes inactive"
  (it was already inactive).
- **Aggregate fault** = OR of active channels **with fault-enable** — a
  channel excluded from fault-enable can be active/sticky without
  contributing to the aggregate `fault_req_o`.
- **Qualification failure** is asserted **only** when a configured finite
  qualification timer *saturates without achieving stability* — i.e. this
  is a distinct evidence bit from ordinary active/sticky, reserved for a
  channel whose input never settles long enough to qualify at all.

Per `ARCH-RTL011-001`: **new active dominates a simultaneous clear**;
**recovery is exactly one cycle and does not clear sticky** (recovery and
sticky-clear are two separate, independently-timed events — a host must
issue an explicit sticky-clear even after observing recovery).

## 4. Registers owned (REG-002 0x2400–0x24FF, 13 registers)

Per-channel polarity/qualification-time/fault-enable configuration,
active/sticky/recovered readback and sticky-clear commands,
`QUALIFICATION_FAILURE` (W1C, confirmed real field, per-channel retained
qualification-attempt-failure evidence — resolves this spec's previously-
flagged gap), aggregate fault status, and `RTL011_EVT_OVERFLOW_STATUS`.
Implement against `dfc_registers_pkg.json`'s RTL-011-owned entries.

## 5. Verification obligations

- **`VP-MOD-011`**: synchronization, polarity, qualification,
  active/sticky/recovered masks, aggregate fault, evidence, **clear
  priority**, reset, ready, and validation satisfy `ARCH-RTL011-001`/
  `ARCH-VAL-011`.
- The recovery-does-not-clear-sticky rule (SS3 above) is exactly the kind
  of one-line contract detail that's easy to implement wrong (conflating
  "recovered" with "cleared") and easy to miss in ordinary testing — it
  deserves its own dedicated case: force active → sticky sets → force
  inactive → confirm `recovered` pulses once AND `sticky` remains set
  until an explicit clear.
