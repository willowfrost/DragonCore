# RTL-015 Module Specification — Lost-Link Supervisor

**Revision:** B (supersedes Rev A, 2026-10-03). Rev A's "per-monitor
activity-ID select" claim and its restated activity-ID list were both
wrong against the owning documents (`OPEN_ISSUES.md` items 81/83). Rev B
corrects them, and records the real design decisions made during
implementation (items 82/84-89).
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002, and RTL-STD-002. It defines no behavior of its
own. Where it records an implementation interpretation that no owning
document fixes, it says so and points to the `OPEN_ISSUES.md` entry.
**Implementation:** `rtl/safety/src/dfc_rtl015.sv` (header carries the full
disclosed design); register forwarding `tools/reggen/rtl015_field_map.json`
(`reggen.py` v5, reusing RTL-014's `indexed_registers` mechanism unchanged).

## 1. Identity and role

`ARCH-MOD-015`: eight independent activity monitors with qualification,
absence timeout, recovery, bounded test injection, and lane-3 safety
requests. Owns REG-002 SS27 Lost-Link Supervisor (0x3300-0x33FF,
**10 registers** -- Rev A's own count was correct here, unlike RTL-014's
Rev A). Mandatory class: Appendix D.1 bit 14 (ready from reset, no
`module_enable_i`). Safety-scope reset: `RTL-002.module_reset_o[14]`. No
physical pin (`OPEN_ISSUES.md` item 77's RTL-014 precedent, confirmed the
same way for RTL-015: none of the 17 Appendix A ports is an external pad).

Controlling contracts: ARCH-002 SS10.3 `ARCH-SAFE-007`/`ARCH-SAFE-008`,
Appendix F.1 `ARCH-RTL015-001`, F.3 RTL-015 row, F.4 `ARCH-VAL-015`.
Allocations: Appendix C.1 (activity producers), C.4 bit 16, C.5 index 14,
C.6 bit 2, C.7 `0x0043`, C.8 bits 24-31.

## 2. Ports (17, ARCH-002 Appendix A "RTL-015 - Lost-Link Supervisor")

| Group | Ports | Peer |
|---|---|---|
| Clock/reset | `core_clk_i`, `core_rst_n_i`, `module_reset_i` | RTL-024; RTL-002.module_reset_o[14] |
| Register bus | `control_i` (`dfc_rtl015_control_t`), `status_o` (`dfc_rtl015_status_t`) | RTL-001; RTL-002.module_ready_i/fault_i[14] |
| Event | `timestamp_i`, `evt_valid_o`, `evt_ready_i`, `evt_record_o` | RTL-004; RTL-005 slot 14 |
| Interrupt/fault | `irq_req_o`, `fault_req_o` | RTL-003.irq_source_i[16]; RTL-013.fault_source_i[2] |
| Activity | `activity_i[7:0]` | "RTL-024 activity vector" (§4) |
| Safety output | `response_req_o` (`dfc_safety_response_req_t`) | RTL-016.response_req_i[3] |
| Broadcasts | `operating_state_i`, `observational_mode_i` | RTL-002 |
| Condition masks | `event_condition_enable_i`, `irq_condition_enable_i` | RTL-001 (F.3 index 14; stubbed `64'h0`, item 6) |

## 3. Monitor <-> activity-ID mapping (`OPEN_ISSUES.md` item 81)

**Fixed 1:1, not host-configurable.** Monitor `m` always watches
`activity_i[m]`. `LLINK_MONITOR_SELECT` (REG-3308) selects which monitor's
*configuration and readback* you are addressing — the same selector role
as RTL-014's `ILOCK_ENTRY_SELECT` — never an activity source. Confirmed by
direct inspection of REG-002's own `LLINK_MONITOR_CONTROL` field table
(REG-330C), which has no activity-ID field at all. Rev A's "per-monitor
activity-ID select" claim is wrong.

**Activity-ID order** (`ARCH-SAFE-007`, restated verbatim in RTL-015's own
`activity_i` Appendix A row): 0 accepted host command, 1 ARINC RX word,
2 CAN RX frame, 3 UART RX byte, 4 any qualified GPIO transition, 5 any
qualified health transition, 6 synchronized user diagnostic transition,
7 accepted external watchdog-service pulse. IDs 8-15 are reserved and
structurally unreachable (no field anywhere accepts one).

**Producer resolution** (`OPEN_ISSUES.md` item 83): five other Appendix A
rows (in RTL-012/017/019/020/021's own port catalogs) name conflicting bit
assignments for `activity_i`, and one of them (RTL-021) is not a legal
activity ID at all. Resolved in favor of RTL-015's own port-catalog row.

**Real producers in this build:** [4] GPIO transition and [5] health
transition are edge-detected in `dfc_rtl024.sv` from RTL-006's/RTL-011's
already-real qualified-level status (no module exposes a dedicated pulse
port for this); [7] is RTL-012's real `service_activity_o` (previously
unconsumed since RTL-012's own session). Disclosed stubs: [0] (no real
Appendix A port exists anywhere for "accepted host command" — item 84,
future ARCH-002 work), [1]/[2]/[3] (RTL-017/019/020 not built), [6]
(RTL-022 permanently out of scope).

## 4. Registers (REG-002 SS27, 10 registers)

- **`internal_reg`, stored in RTL-001:** `LLINK_CONTROL`,
  `LLINK_MONITOR_SELECT`, and the four selector-indexed per-monitor
  registers (`LLINK_MONITOR_CONTROL`, `LLINK_QUALIFY_US`,
  `LLINK_TIMEOUT_US`, `LLINK_RECOVERY_US` — each ×8, item 82).
- **`zero`:** `LLINK_ACTIVITY_INJECT`.
- **`external`, supplied by RTL-015:** `LLINK_STATUS`, `LLINK_ELAPSED_US`,
  `RTL015_EVT_OVERFLOW_STATUS`.
- **Protected:** `LLINK_CONTROL` and `LLINK_MONITOR_CONTROL`.

**Per-monitor config bank (item 82).** All 8 monitors run simultaneously
and continuously, so a single selected-only view in `control_i` cannot
carry their configuration — the same problem RTL-014's staged bank solved
(item 68), reusing the identical `reggen.py` v5 mechanism with zero new
generator work. `dfc_rtl015_control_t` grew 128→961 bits: 8×104 bits per
monitor (enable/event/irq/fault/mask[4]/qualify_us[32]/timeout_us[32]/
recovery_us[32]) plus the 14th EVENT_OVERFLOW-clear-field instance.

**`LLINK_ELAPSED_US`** is intentionally a single selected-monitor readback
(RTL-015 maintains 8 real internal counters always; the host selects which
one to read). `dfc_rtl015_status_t` needed no growth for this — unlike
RTL-014's `ILOCK_ACTIVE_*` registers, this one was already complete.

## 5. Activity, timeout, recovery, and injection contract

- **Algorithm** (item 85, disclosed — no bit-exact algorithm is given):
  `elapsed_us_q[m]` resets on every effective activity pulse and declares
  LOST the tick it first reaches `TIMEOUT_US[m]`;
  `recovery_progress_q[m]` accumulates only while `elapsed_us_q[m]` stays
  within `QUALIFY_US[m]` and only while the monitor is genuinely LOST
  (item 88's fix), clearing LOST the tick it first reaches
  `RECOVERY_US[m]`. `QUALIFY_US[m]==0` disables the gap check.
  `ARCH-VAL-015`'s "QUALIFY_US < TIMEOUT_US" makes the set/clear
  conditions mutually exclusive by construction.
- **Configuration rejection:** `TIMEOUT_US==0`, `RECOVERY_US==0`, or
  `QUALIFY_US>=TIMEOUT_US` is a live condition → `status_o.fault` (item 4
  precedent, no REG-002 field exists for a per-monitor reject latch).
- **Per-monitor `ENABLE`** (item 89): gates the monitor's own timers
  (held at zero while disabled) and releases an already-latched
  `LOST_ACTIVE[m]` the same cycle it is cleared — the same "disable
  releases" precedent RTL-014 established for its own module-wide
  `ENABLE=0`.
- **Injection** (`ARCH-SAFE-008`, item 86):
  `LLINK_ACTIVITY_INJECT.HEARTBEAT` targets the currently selected
  monitor, accepted only in `TEST_DEBUG`. Value 1 ORs into the natural
  activity path (no tag needed — same observable effect as real
  activity). Value 2 ORs into the LOST-set trigger, natural-dominates when
  both fire the same cycle, and is reported as event subtype 3
  ("injection") in place of subtype 0 ("lost") for that transition. Value
  3 (reserved) has no effect.
- **Safety outputs:** `fault_req_o` (C.6 bit 2, class 0x03, recoverable) =
  OR of every `FAULT_ENABLE`-gated LOST monitor, gated by
  `LLINK_CONTROL.ENABLE`. `response_req_o` (lane 3): lowest LOST monitor
  with a nonzero response mask wins (same rule as RTL-014's lane 2, item
  72 precedent).
- **Events/IRQ** (C.7 `0x0043`, F.3 RTL-015 row): subtypes 0 lost, 1
  recovered, 2 configuration rejected, 3 injection. `source_id` uses the
  bare-index convention of all 13 prior producers (item 87, the project-
  wide question from item 74, not resolved here).

## 6. Verification obligations and evidence

| Case | Evidence | Status |
|---|---|---|
| `VP-MOD-015` | `rtl015_integration_tb.sv` (40 checks) | T-SIM met; F-PROP not met (same gap as RTL-014 item 78) |
| `VP-SAFE-008` | Parts 6-10: timeout, qualify-gated recovery, injection (natural-dominates, test-inactive rejection, tagged-distinguishable), config rejection | met (T-SIM) |
| Fixed mapping | Part 1 and the module header's own item-81 resolution | met |
| Whole system | `rtl024_skeleton_tb.sv` RTL-015 section: real SPI config and a real external `gpio_i[3]` pad driving the registered activity vector to RTL-015 and to RTL-013 fault bit 2 | met |

Open, not met: activity ID 0 has no real producer to test (item 84);
VP-SAFE-008's reserved-ID coverage is structurally unreachable rather than
register-checked (item 81); the event `source_id` convention question
(item 87, project-wide, item 74).
