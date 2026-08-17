# RTL-012 Module Specification — Watchdog Manager

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002. This module is the first Safety-domain module —
`RTLSTD-PRIN-006`'s set-dominates-clear discipline and exact boundary
behavior matter more here than in Infrastructure/Monitoring.

## 1. Identity and role

RTL-012 is the Dragon Core Watchdog Manager: a protected service-window
timer with key checking, requesting **lane 0** of the safety-response
authorization matrix on timeout. Owns REG-002's Watchdog block
(0x3000–0x30FF, 8 registers).

Controlling documents: `ARCH-002` SS10.3 `ARCH-SAFE-005`, SS10.2 (lane-0
mapping), Appendix F.1 `ARCH-RTL012-001`, Appendix C.8 (`RTL-012 lane 0,
source 0` = the sole legal watchdog authorization bit), VP-002
`VP-MOD-012`/`VP-SAFE-004`.

## 2. Ports (17 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[11]`), `control_i` (`dfc_rtl012_control_t`, 110
bits)/`status_o` (`dfc_rtl012_status_t`, 58 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 11),
`operating_state_i`, `observational_mode_i`, condition-enable pair.
RTL-012-specific: **`response_req_o`** (`dfc_safety_response_req_t`, 8
bits — lane 0 into RTL-016, source ID fixed at 0).

## 3. Service-window and key contract (`ARCH-SAFE-005`)

- **Accepted service key is exactly `0xA5C35A3C`.** Any other value is
  INVALID — there is no partial-credit or near-miss acceptance.
- Service **before** `MIN_WINDOW` is EARLY; service **after**
  `MAX_WINDOW` is LATE. Per `ARCH-RTL012-001`: **"exactly-on-boundary
  service is legal at MIN and legal through MAX-1"** — i.e. the legal
  window is `[MIN_WINDOW, MAX_WINDOW)`, half-open. Service at exactly
  `MIN_WINDOW` is legal; service at exactly `MAX_WINDOW` is LATE, not
  legal. Get this boundary exactly right — it's the single most
  consequential off-by-one in this module.
- An **enabled** counter begins at zero, increments in microseconds,
  **times out when elapsed first equals `MAX_WINDOW`** without valid
  service, and **restarts at zero only on valid in-window service** (an
  EARLY, LATE, or INVALID service attempt does *not* restart the timer).
- **Recovery requires exactly one valid in-window service** after the
  source condition (timeout) clears — a single good service, not a
  configurable count.
- Per `ARCH-RTL012-001`: reset/disable clears both the timer and any
  pending safety request. **Timeout detection precedes same-cycle late
  service** — if a LATE service and the timeout boundary land on the
  same cycle, the timeout has already been declared; the late service
  does not retroactively prevent it.

## 4. Registers owned (REG-002 0x3000–0x30FF, 8 registers)

`WDOG_CONTROL` (protected: `ENABLE`, `WINDOW_ENABLE`, `EVENT_ENABLE`,
`IRQ_ENABLE`, `FAULT_ENABLE`, `SAFETY_RESPONSE_MASK` 4-bit — confirmed:
per `REG-ENC-015`, only bit 0 of the full 32-bit `SAFETY_RESPONSE_MASK`
concept is legal for RTL-012 specifically, matching Appendix C.8's "lane 0
source 0" sole legal position), `WDOG_WINDOW_OPEN_US` (=`MIN_WINDOW`),
`WDOG_TIMEOUT_US` (=`MAX_WINDOW`), `WDOG_SERVICE` (WO-CMD, the key write),
`WDOG_STATUS`, `WDOG_ELAPSED_US`, `WDOG_RECOVERY`, and
`RTL012_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-012-owned entries.

## 5. Verification obligations

- **`VP-MOD-012`**: enable, key, **exact window boundaries**, timeout,
  recovery, evidence, safety request, disable/reset priority, ready,
  fault, and validation satisfy `ARCH-RTL012-001`/`ARCH-VAL-012`.
- **`VP-SAFE-004`**: service at each key/window boundary — EARLY exactly
  at `MIN_WINDOW - 1`, legal exactly at `MIN_WINDOW`, legal at
  `MAX_WINDOW - 1`, LATE exactly at `MAX_WINDOW` — plus invalid key,
  missing service, timeout, recovery, disable, reset, and the
  **simultaneous timeout/service** race explicitly named in
  `ARCH-RTL012-001`. Every one of these boundary values needs its own
  test vector; this is not a module where "typical inputs" coverage is
  adequate given the half-open-interval subtlety above.
