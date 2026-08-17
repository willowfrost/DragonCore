# RTL-015 Module Specification — Lost-Link Supervisor

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-015 monitors **8 independent activity sources** for prolonged absence
of activity ("lost link"), with per-monitor qualification, timeout,
recovery, and a bounded test-injection path — requesting **lane 3** of the
safety-response matrix on loss. Owns REG-002's Lost-Link block
(0x3300–0x33FF, 10 registers).

Controlling documents: `ARCH-002` SS10.3 `ARCH-SAFE-007`/`008`, Appendix
F.1 `ARCH-RTL015-001`, Appendix C.8 (lane 3, source IDs 0–7, authorization
bits 24–31), VP-002 `VP-MOD-015`/`VP-SAFE-008`.

## 2. Ports (17 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[14]`), `control_i` (`dfc_rtl015_control_t`, 128
bits)/`status_o` (`dfc_rtl015_status_t`, 75 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 14),
`operating_state_i`, `observational_mode_i`, condition-enable pair.
RTL-015-specific: **`activity_i[7:0]`** (one bit per monitor, confirmed
exact source order below), **`response_req_o`** (`dfc_safety_response_req_t`,
lane 3, source ID selects which of the 8 monitors).

## 3. Activity mapping, timing, and injection contract

**`ARCH-SAFE-007`** — the 8 monitors select from a **fixed activity ID
list** (confirmed exact order): **0** host-accepted command, **1** ARINC
RX word, **2** CAN RX frame, **3** UART RX byte, **4** GPIO any qualified
transition, **5** health any qualified transition, **6** user diagnostic
input transition, **7** external watchdog-service pulse. **IDs 8–15 are
reserved.**

- Activity must **persist through `QUALIFY_US`** when that value is
  nonzero (zero disables qualification, same "zero disables the check"
  pattern as RTL-010's `MAX_AGE`).
- **Loss asserts when the absence counter first equals `TIMEOUT_US`.**
- **Recovery requires continuous qualified activity for `RECOVERY_US`** —
  not one pulse; sustained activity for the full recovery interval.

**`ARCH-SAFE-008`** (test injection) — `LLINK_ACTIVITY_INJECT[0]` injects
one activity pulse into the selected monitor; `[1]` injects loss evidence
for that monitor. **Either command is accepted only in qualified
test-active state**, is **tagged injected** (distinguishable from natural
evidence), **cannot suppress natural activity/loss**, and uses a
**separate OR input** to the evidence path (injection adds to, never
replaces, the natural signal).

Per `ARCH-RTL015-001`: **natural loss has priority over injected
evidence**; **clear never suppresses an active loss** — a host clear
attempt while the source condition is still genuinely active is
ineffective, same discipline as RTL-013's active-dominates-clear rule.

## 4. Registers owned (REG-002 0x3300–0x33FF, 10 registers)

Per-monitor activity-ID select, `QUALIFY_US`/`TIMEOUT_US`/`RECOVERY_US`
configuration, active/sticky/recovered status, elapsed-time readback,
`LLINK_ACTIVITY_INJECT` command (test-active-gated), safety-response
authorization (source IDs 0–7 within lane 3's bits 24–31), and
`RTL015_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-015-owned entries.

## 5. Verification obligations

- **`VP-MOD-015`**: all activity mappings, qualification, absence timeout,
  recovery, evidence, response sources, injection restrictions,
  natural/injected priority, reset, and validation satisfy
  `ARCH-RTL015-001`/`ARCH-VAL-015`.
- **`VP-SAFE-008`**: every activity identifier (0–7) and every reserved
  identifier (8–15), qualification interval, timeout boundary, recovery
  interval, disable, reset, and the **simultaneous natural/injected
  condition** all match `ARCH-SAFE-007`/`008` — the natural-priority and
  clear-never-suppresses-active-loss rules each need a dedicated
  simultaneous-condition test, not incidental coverage.
