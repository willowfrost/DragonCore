# RTL-016 Module Specification — Safety Output Controller

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, SRS-002, VP-002. This module has the **sole ownership**
of all four physical safety outputs — no other module, including RTL-024's
production-test path, may activate them (`DFC-SEC-0006`, `RTLSTD-TEST-014`,
`VP-SAFE-003`).

## 1. Identity and role

RTL-016 is the Dragon Core Safety Output Controller: aggregates
authorized requests from all four safety lanes (RTL-012 watchdog, RTL-013
fault manager, RTL-014 interlock ×8, RTL-015 lost-link ×8 — 32 mask
positions total per Appendix C.8) into **4 independently-configured
logical safety-output channels**, applying polarity, latching, and a
strict permission gate before any channel may become active. Owns
REG-002's Safety Output block (0x3400–0x34FF, 8 registers).

Controlling documents: `ARCH-002` SS10.4 (the complete functional
equation set below), Appendix F.1 `ARCH-RTL016-001`, Appendix C.8 (the
32-position authorization matrix), `SRS-002` `DFC-FUNC-0111`–`0116`,
VP-002 `VP-MOD-016`/`VP-SAFE-009`–`011`/`014`.

## 2. Ports (22 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[15]`), `control_i` (`dfc_rtl016_control_t`, 52
bits)/`status_o` (`dfc_rtl016_status_t`, 47 bits), `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 15),
`operating_state_i`, `observational_mode_i`, condition-enable pair.
RTL-016-specific: **`response_req_i[3:0]`** (one port per lane —
`response_req_i[0]` RTL-012, `[1]` RTL-013, `[2]` RTL-014, `[3]` RTL-015,
each `dfc_safety_response_req_t`), **`fault_inhibit_i[3:0]`** (from
RTL-013's `safety_inhibit_o`, per-channel), **`safety_out_o[3:0]`** — the
sole external safety-output ports (Appendix A "RTL-024" external
population, ultimately `safety_out_o` pads).

## 3. Authorization, polarity, latching, and permission contract (SS10.4)

Per channel `c`:

```
AUTHORIZED_REQ[c] = OR of every lane request whose response mask
                     contains c AND whose fixed authorization bit is
                     set in that channel's mask

REQUESTED[c] = AUTHORIZED_REQ[c]                        -- latch disabled
             = a retained latch set by AUTHORIZED_REQ[c] -- latch enabled
                 (clears only on: channel disable, safety-domain reset,
                  system reset, or external reset AFTER all requests are
                  inactive; re-enabling a channel begins with latch clear)

GLOBAL_INHIBIT   = !safety_control__enable
fault_inhibit[c] = asserted for EVERY channel whenever ANY active
                   nonrecoverable fault source is present (RTL-013-wide,
                   not per-channel-specific)
test_inhibit     = physical production-test authorization OR
                   qualified test-active

PERMIT[c] = channel_enable[c]
          & effective_operational_enable
          & !GLOBAL_INHIBIT
          & all_required_interlocks_satisfied
          & !fault_inhibit[c]
          & !observational_mode
          & !test_inhibit
          & !TEST_DEBUG

ACTIVE_CMD[c] = REQUESTED[c] & PERMIT[c]

safety_out[c] = ACTIVE_HIGH[c] ? ACTIVE_CMD[c] : !ACTIVE_CMD[c]
                 (during permitted operation; reset/unconfigured startup
                  use the Register Map reset polarity and inactive level)
```

**Reset, startup, `INIT_FAILED`, global inhibit, observation, TEST_DEBUG,
any production-test authorization, channel disable, interlock inhibit,
and fault inhibit all dominate every request** — this is an 8-way AND of
permission conditions; any single one being false forces the channel
inactive regardless of how many lanes are requesting it.

**No test indication is permitted on a safety-output pad** — this is
absolute, not conditional on test mode being "safe" in some other sense.

Per `ARCH-RTL016-001`: **multiple authorized requests OR together — one
source cannot cancel another** (i.e. there is no "highest priority wins"
arbitration among lanes for the same channel; any active authorized
source keeps the channel requested regardless of others clearing).

## 4. Registers owned (REG-002 0x3400–0x34FF, 8 registers)

`SAFETY_CONTROL` (global enable), `SAFETY_CHANNEL_SELECT`,
per-channel `SAFETY_CHANNEL_CONTROL` (enable/polarity/latch-policy),
`SAFETY_RESPONSE_MASK` (32-bit authorization, legal bits per
`REG-ENC-015`: **only bits 0, 8, and 16–31** — `0xFFFF0101` — bits 1–7 and
9–15 reject the entire write; **a disabled channel requires a zero
response mask**, so disabling a channel and leaving a stale nonzero mask
is itself an invalid state, not merely inert), `SAFETY_INTERLOCK_MASK`,
`SAFETY_CHANNEL_STATUS` (`0x3418`, confirmed real fields — this register
was substantively expanded from 8 to **13** fields, fully resolving this
spec's previously-flagged `DFC-FUNC-0113` gap):
`COMMAND_REQUEST`(0)/`EFFECTIVE_OUTPUT`(1)/`DISABLED`(2)/
`OBSERVATIONAL_INHIBIT`(3)/`INTERLOCK_INHIBIT`(4)/`FAULT_INHIBIT`(5)/
`RESET_ACTIVE`(6)/`TEST_INHIBIT`(7) — the original 8 — **plus**
`LATCHED_REQUEST`(8, "retained latched-request state"),
`COMMANDED`(9, "requested OR latched-request state before permit
gating" — SS3's `REQUESTED[c]`, now correctly distinguished from
`COMMAND_REQUEST`), `CONTROLLER_DISABLED`(10),
`GLOBAL_INHIBIT`(11, SS3's `GLOBAL_INHIBIT` equation, now directly
host-visible), and `OPERATIONAL_INHIBIT`(12). The four originally-
undifferentiated "inhibit" causes are now four distinct, independently
readable bits, and the requested/latched/commanded ambiguity this spec
previously flagged is fully resolved. Implement each internal signal
against its now-confirmed dedicated field — no internal-signal-without-
readback gap remains for this register. `DFC-FUNC-0114`: no host-visible
register directly commands a safety output active — every register here
configures *permission and authorization*, never a direct output-force
path. Implement against `dfc_registers_pkg.json`'s RTL-016-owned entries.

## 5. Verification obligations

- **`VP-MOD-016`**: legal source authorization, request ORing, polarity,
  latching, recovery, clear, inhibit, test/reset/disable priority, **sole
  output ownership**, ready, fault, and validation satisfy
  `ARCH-RTL016-001`/`ARCH-VAL-016`.
- **`VP-SAFE-009`**: every legal producer/source mapping reaches *only*
  its assigned mask position; every reserved position is tied inactive
  and rejected in configuration — exhaustive per-position, not sampled.
- **`VP-SAFE-010`**: for each channel, authorized active requests OR by
  response bit; simultaneous requests cannot cancel one another.
- **`VP-SAFE-011`**: active polarity, request latching, recovery, host
  clear, channel disable, inhibit, and new-request priority match SS10.4
  and `ARCH-RTL016-001` exactly.
- **`VP-SAFE-014`**: logical safety-output timing, polarity, reset
  inactivity, request response, inhibit, and fault combinations match
  simulation at the actual FPGA/HIL/ASIC digital boundary using
  externally safe fixtures — this is the one Safety-domain case that must
  be re-run per platform, not just in `T-SIM`.
- **`VP-SAFE-003`** (cross-cutting, but binds directly here): no
  production-test command, loopback, injection, or diagnostic state can
  activate a safety output under any condition — worth a dedicated
  fuzz-style sweep across the full production-test command space against
  this module specifically, given it's the one place a mistake here has
  the highest consequence in the whole design.
