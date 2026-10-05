# RTL-016 Module Specification — Safety Output Controller

**Revision:** B (supersedes Rev A, 2026-10-04). Rev A's port count, several
SS10.4 equation terms, and the `dfc_rtl016_control_t`/`status_t` widths
were all wrong against the owning documents (`OPEN_ISSUES.md` items
90-94). Rev B corrects them, and records the real design decisions made
during implementation (items 95-98).
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002, and RTL-STD-002. It defines no behavior of its
own. Where it records an implementation interpretation that no owning
document fixes, it says so and points to the `OPEN_ISSUES.md` entry.
**Implementation:** `rtl/safety/src/dfc_rtl016.sv` (header carries the
full disclosed design); register forwarding
`tools/reggen/rtl016_field_map.json` (`reggen.py` v5, reusing RTL-014/015's
`indexed_registers` mechanism unchanged). This module has the **sole
ownership** of all four physical safety outputs — no other module,
including RTL-024's production-test path, may activate them
(`DFC-SEC-0006`, `RTLSTD-TEST-014`, `VP-SAFE-003`).

## 1. Identity and role

`ARCH-MOD-016`: aggregates authorized requests from all four safety lanes
(RTL-012 watchdog, RTL-013 fault manager, RTL-014 interlock ×8, RTL-015
lost-link ×8 — 32 mask positions total per Appendix C.8) into **4
independently-configured logical safety-output channels**, applying a
real nine-term `PERMIT[c]` gate, polarity, and latching before any channel
may become active. Owns REG-002's Safety Output block (0x3400-0x341C,
**8 registers**). The fifth and FINAL Safety-domain module — closes the
Safety domain (RTL-012 through RTL-016).

Controlling contracts: ARCH-002 SS10.2 `ARCH-SAFE-001`..`004` (lane/source
allocation), SS10.4 (the complete equation set), Appendix F.1
`ARCH-RTL016-001`, F.3 RTL-016 row, F.4 `ARCH-VAL-016`, Appendix C.6 bit 3,
C.7 event `0x0044`, C.8 (32-position authorization matrix).

## 2. Ports (22, ARCH-002 Appendix A "RTL-016 - Safety Output Controller")

Rev A's own SS2 named only `response_req_i`/`fault_inhibit_i`/
`safety_out_o` as "RTL-016-specific" — standard group (13) plus those
three reaches 16, not 22 (item 90). The real Appendix A rows add six more:
`irq_req_o` (→ `RTL-003.irq_source_i[17]`), `fault_req_o` (→
`RTL-013.fault_source_i[3]`), `interlock_satisfied_i[7:0]` (←
`RTL-014.interlock_satisfied_o`, entry-indexed, genuinely unused — item
95), `interlock_inhibit_i[7:0]` (← `RTL-014.interlock_inhibit_o`,
guard-indexed, idle 1), `effective_operational_enable_i` (← `RTL-002`),
and `test_inhibit_i` (← "RTL-024 physical test authorization OR
test-active", `CDC-TEST-001`, idle 1 during reset).

| Group | Ports | Peer |
|---|---|---|
| Clock/reset | `core_clk_i`, `core_rst_n_i`, `module_reset_i` | RTL-024; RTL-002.module_reset_o[15] |
| Register bus | `control_i` (`dfc_rtl016_control_t`), `status_o` (`dfc_rtl016_status_t`) | RTL-001; RTL-002.module_ready_i/fault_i[15] |
| Event | `timestamp_i`, `evt_valid_o`, `evt_ready_i`, `evt_record_o` | RTL-004; RTL-005 slot 15 |
| Interrupt/fault | `irq_req_o`, `fault_req_o` | RTL-003.irq_source_i[17]; RTL-013.fault_source_i[3] |
| Response lanes | `response_req_i[3:0]` (`dfc_safety_response_req_t`×4) | RTL-012/013/014/015.response_req_o |
| Interlock | `interlock_satisfied_i[7:0]`, `interlock_inhibit_i[7:0]` | RTL-014 |
| Fault inhibit | `fault_inhibit_i[3:0]` | RTL-013.safety_inhibit_o |
| Test inhibit | `test_inhibit_i` | RTL-024 |
| Safety output | `safety_out_o[3:0]` | RTL-024 pad (sole external port) |
| Broadcasts | `operating_state_i`, `observational_mode_i`, `effective_operational_enable_i` | RTL-002 |
| Condition masks | `event_condition_enable_i`, `irq_condition_enable_i` | RTL-001 (F.3 index 15; stubbed `64'h0`, item 6) |

## 3. Nine disclosed resolutions (`OPEN_ISSUES.md` items 90-98)

1. **Real 22-port list** (item 90) — see Section 2.
2. **`GLOBAL_INHIBIT` is its own independent RW field, not `!ENABLE`**
   (item 91). REG-002's real `SAFETY_CONTROL` (0x3400) has bit 0 `ENABLE`
   (reset 0) and bit 3 `GLOBAL_INHIBIT` (reset 1) as two independent
   fields; `SAFETY_CHANNEL_STATUS` confirms with two separate readback
   bits (`CONTROLLER_DISABLED` bit 10, `GLOBAL_INHIBIT` bit 11).
3. **`FAULT_INHIBIT` is genuinely per-channel** (item 92). The real
   Appendix A row says "per-channel active-high inhibit," sourced from
   RTL-013's real 4-bit `safety_inhibit_o` — confirmed all four bits
   currently carry the same value (`dfc_rtl013.sv`'s own
   `{4{ctl_enable && (|nonrecoverable_active17)}}`), but the port itself
   is 4 bits wide and this module indexes it per channel.
4. **`TEST_DEBUG` is a real, separate term this module ORs in itself**
   (item 93). `test_inhibit_i`'s own producer description is only
   "physical test authorization OR test-active" — ARCH-002's real
   `TEST_INHIBIT` definition adds `TEST_DEBUG` (`operating_state_i`) as a
   third term. Algebraically equivalent to Rev A's own two separate
   `!test_inhibit & !TEST_DEBUG` AND terms (De Morgan), but Rev A's stated
   reasoning ("already included") was wrong.
5. **`PERMIT[c]` is a real nine-term AND, not Rev A's eight** (item 94):
   `!CHANNEL_DISABLED[c] & !CONTROLLER_DISABLED & !GLOBAL_INHIBIT &
   !OPERATIONAL_INHIBIT & !OBSERVATIONAL_INHIBIT & !TEST_INHIBIT &
   !INTERLOCK_INHIBIT[c] & !FAULT_INHIBIT[c] & !RESET_HELD[c]`. Rev A
   omitted `RESET_HELD[c]` and conflated `CONTROLLER_DISABLED` into
   `GLOBAL_INHIBIT`.
6. **`INTERLOCK_INHIBIT[c]` uses the GUARD-indexed `interlock_inhibit_i`,
   not the ENTRY-indexed `interlock_satisfied_i`** (item 95, the most
   structurally subtle finding). `dfc_rtl014.sv`'s own header: `GUARD_
   ALLOWED[g]` = no effective-violated entry has bit `g` in its guard
   mask; `interlock_inhibit_o = ~GUARD_ALLOWED` (per guard), while
   `interlock_satisfied_o[e] = ENTRY_TRUE[e]` (per entry) — NOT the same
   8-bit space. `SAFETY_INTERLOCK_MASK.REQUIRED_INTERLOCKS` is a per-
   channel subset of the guard space: `INTERLOCK_INHIBIT[c] = OR over g
   in required_interlocks[c] of interlock_inhibit_i[g]`.
   `interlock_satisfied_i` has no functional use and no REG-002 status
   field — a disclosed, genuinely unused real input.
7. **Two-key response authorization** (item 96): a request reaches
   channel `c` only when BOTH the producer's own 4-bit `response_mask`
   field has bit `c` set AND this module's own 32-bit per-channel
   `SAFETY_RESPONSE_MASK` has bit `8*lane+source_id` set. Two
   independently-configured permission layers.
8. **`LATCHED_REQUEST[c]` clear semantics** (item 97): while latch policy
   is enabled, `!ctl_c_enable[c] && !REQUESTED[c]` clears it (new evidence
   dominates a level-held clear attempt while disabled, same project-wide
   sticky precedent); re-enabling the channel (rising edge of
   `ctl_c_enable[c]`) clears it unconditionally, a separate edge-triggered
   override; `core_rst_n_i`/`module_reset_i` clear it unconditionally via
   the ordinary reset branch (same as every other sticky register).
9. **`SAFETY_STATUS.FAULTED[c]`/`fault_req_o` live cross-field defense**
   (item 94/9): `!ctl_c_enable[c] && (ctl_c_response_mask[c] != 0)` is
   DETECTED live (RTL-001's single-register validation cannot see this
   cross-register condition), not write-rejected — disabling a channel
   must never be refusable for safety reasons. Not gated by
   `SAFETY_CONTROL.ENABLE` (unlike RTL-015's own `fault_req_o`): a
   self-contradictory channel configuration is worth reporting regardless
   of controller enable.

## 4. Registers (REG-002 0x3400-0x341C, 8 registers)

- **`internal_reg`, stored in RTL-001:** `SAFETY_CONTROL`,
  `SAFETY_CHANNEL_SELECT`, and the three selector-indexed per-channel
  registers (`SAFETY_CHANNEL_CONTROL`, `SAFETY_RESPONSE_MASK`,
  `SAFETY_INTERLOCK_MASK` — each ×4, item 90's struct growth).
- **`external`, supplied by RTL-016:** `SAFETY_STATUS`,
  `SAFETY_CHANNEL_STATUS`, `RTL016_EVT_OVERFLOW_STATUS` (already present
  in REG-002's own real field table — unlike every module from RTL-002
  through RTL-015, this was NOT a gap to add).
- **Protected:** `SAFETY_CONTROL`, `SAFETY_CHANNEL_CONTROL`,
  `SAFETY_RESPONSE_MASK`, `SAFETY_INTERLOCK_MASK`.

**Per-channel config bank (item 90).** All 4 channels evaluate `PERMIT[c]`
simultaneously and continuously, so a single selected-only view cannot
carry their configuration — the same problem items 68/82 already solved
for RTL-014/015, reusing the identical `reggen.py` v5 mechanism with zero
new generator work. `dfc_rtl016_control_t` grew 53→226 bits: 4×43 bits per
channel (enable/active_high/latch_response/response_source_mask[32]/
required_interlocks[8]) plus the 15th EVENT_OVERFLOW-clear-field instance
(a real gap found while writing this field map — Rev A's own struct
omitted it entirely).

**`SAFETY_CHANNEL_STATUS`** is intentionally a single selected-channel
readback (RTL-016 maintains all 4 channels' full state always; the host
selects which to read) — `dfc_rtl016_status_t` needed **no growth**, since
`SAFETY_STATUS`'s own `COMMANDED`/`EFFECTIVE`/`INHIBITED`/`FAULTED`/
`EVENT` fields are already complete 4-bit-per-channel aggregates.

## 5. Authorization, polarity, latching, and permission contract (SS10.4)

```
AUTHORIZED_REQ[c] = OR over lane L of:
  response_req_i[L].valid
  & response_req_i[L].response_mask[c]
  & SAFETY_RESPONSE_MASK[c][8*L + response_req_i[L].source_id]   -- item 96

REQUESTED[c] = AUTHORIZED_REQ[c]
LATCHED_REQUEST[c] -- item 97 (see Section 3.8)
COMMANDED[c] = REQUESTED[c] | LATCHED_REQUEST[c]

CHANNEL_DISABLED[c]    = !channel_enable[c]
CONTROLLER_DISABLED    = !safety_control__enable
GLOBAL_INHIBIT         = safety_control__global_inhibit            -- item 91
OPERATIONAL_INHIBIT    = !effective_operational_enable
OBSERVATIONAL_INHIBIT  = observational_mode
TEST_INHIBIT           = test_inhibit_i | (operating_state==TEST_DEBUG)  -- item 93
INTERLOCK_INHIBIT[c]   = |(interlock_inhibit_i & required_interlocks[c])  -- item 95
FAULT_INHIBIT[c]       = fault_inhibit_i[c]                         -- item 92
RESET_HELD             = !core_rst_n_i | module_reset_i | (operating_state==RESET_ACTIVE)

PERMIT[c] = !CHANNEL_DISABLED[c] & !CONTROLLER_DISABLED & !GLOBAL_INHIBIT
          & !OPERATIONAL_INHIBIT & !OBSERVATIONAL_INHIBIT & !TEST_INHIBIT
          & !INTERLOCK_INHIBIT[c] & !FAULT_INHIBIT[c] & !RESET_HELD   -- item 94

EFFECTIVE[c] = COMMANDED[c] & PERMIT[c]
safety_out[c] = ACTIVE_HIGH[c] ? EFFECTIVE[c] : !EFFECTIVE[c]
```

Registered from the same combinational evaluation on the same edge (no
pipeline stage between `SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT` and the
real pad), same "same-edge guard rule" precedent RTL-014 established.
Reset forces `safety_out_o` to `4'b0000` directly, matching Appendix A's
"reset inactive low."

**No test indication is permitted on a safety-output pad** — absolute.
**Multiple authorized requests OR together — one source cannot cancel
another** (`ARCH-RTL016-001`).

## 6. Physical interface

`safety_out_o[3:0]` = `gn8`/`gn9`/`gn10`/`gn14` (ULX3S_CONNECTION_MAP.md
Section 10) — four real "orphaned" `gn<N>` pins (differential
counterparts of already single-ended-committed `gp<N>` positions),
preserving the WiFi-shared `gp11`-`gp13` range for RTL-017/019/020.

## 7. Verification obligations and evidence

| Case | Evidence | Status |
|---|---|---|
| `VP-MOD-016` | `rtl016_integration_tb.sv` (71 checks) | T-SIM met; F-PROP not met (same gap as RTL-014/015) |
| `VP-SAFE-009` | Part 6 (two-key authorization, positive and negative) | met (T-SIM) |
| `VP-SAFE-010` | Part 16 (multiple lanes OR, one cannot cancel another) | met (T-SIM) |
| `VP-SAFE-011` | Parts 4-5, 7-14 (polarity, latch, every PERMIT term independently) | met (T-SIM) |
| `VP-SAFE-014` | Not met — requires the real FPGA/HIL boundary, not just T-SIM | open |
| `VP-SAFE-003` | Not a dedicated fuzz sweep — `test_inhibit_i`/`TEST_DEBUG` blocking proven directly (Part 11) | partially met |
| Whole system | `rtl024_skeleton_tb.sv` RTL-016 section: real RTL-014 entry-0 request through real two-key authorization; real OPERATIONAL_INHIBIT block (item 98) | met |

Open, not met: `VP-SAFE-014`'s real FPGA/HIL digital-boundary re-run;
`VP-SAFE-003`'s full production-test command-space fuzz sweep (RTL-024's
own test controller does not exist yet).
