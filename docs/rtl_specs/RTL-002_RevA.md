# RTL-002 Module Specification — System Control Logic

**Revision:** A (authored fresh against the `-002` baseline; structural reference
only from any `-001`-era material, never content)
**Status:** Derived artifact per `RCA-DFC-CHTR-002` SS3.3 (CHTR-DOC-006: no
new behavior defined here). Every normative claim cites ARCH-002, REG-002,
SRS-002, or VP-002.

## 1. Identity and role

RTL-002 is the Dragon Core System Control Logic: the **sole producer of
`dfc_operating_state_t`** (ARCH-002 SS4.1) and the **sole source of module
reset requests** (`module_reset_o[23:0]`) to every other module. It
aggregates readiness (`module_ready_i[23:0]`) and fault (`module_fault_i[23:0]`)
from all 24 modules (itself included, via its own `status_o.ready`/`.fault`
looped back through RTL-001's ownership of the port catalog — RTL-002 does
not read its own output directly) and derives from them the single
operating-state encoding every other module gates on.

Controlling documents: `RCA-DFC-SRS-002` SS4.1/5.1 (externally observable
operating states, functional requirements `DFC-FUNC-0001`–`0018`),
`RCA-DFC-ARCH-002` SS4 (`ARCH-STATE-001`–`007`, `ARCH-START-001`–`006`,
`ARCH-RST-004`/`005`), REG-002's Identification/System Control block
(0x0000–0x005C, registers RTL-002 owns or co-owns), and Appendix F's
`ARCH-RTL002-001` derivation contract.

## 2. Ports (24 total, per the Architecture formal port catalog)

- **Clock/reset:** `core_clk_i`, `core_rst_n_i` (asynchronous assert,
  synchronized release after 4 valid edges, `RDC-001`); `module_reset_i`
  (RTL-002's own local-reset input, `module_reset_o[1]` looped back — bit 1
  of its own fan-out).
- **Control/status:** `control_i` (`dfc_rtl002_control_t`, 57 bits),
  `status_o` (`dfc_rtl002_status_t`, 109 bits, includes RTL-002's own
  `ready`/`fault` evidence).
- **Time/event/interrupt:** `timestamp_i`, `evt_valid_o`/`evt_ready_i`/
  `evt_record_o`, `irq_req_o` (source index 0 into RTL-003's 32-position
  vector).
- **Module fan-in/fan-out** (the reason RTL-002 exists):
  - `module_ready_i[23:0]` — `RTL-(i+1).status_o.ready` for i=0..23
  - `module_fault_i[23:0]` — `RTL-(i+1).status_o.fault` for i=0..23
  - `module_reset_o[23:0]` — qualified per-module reset requests
    (`ARCH-RST-004`); **bits 0 (RTL-001) and 23 (RTL-024) have no child
    local-reset consumer** — bit 0 is serviced by system reset
    (`ARCH-RST-005`) and bit 23 by RTL-024's own integration reset control
  - `operating_state_o` (`dfc_operating_state_t`, 3 bits) — broadcast to
    every other module's `operating_state_i`
  - `observational_mode_o` (1 bit) — broadcast to every other module's
    `observational_mode_i`

Per `RTLSTD-MOD-004`, every name/direction/width/type above must match the
Architecture catalog exactly; this spec summarizes, the catalog governs.

## 3. Primary operating-state model (ARCH-002 SS4.1)

RTL-002 is the **sole producer** of `dfc_operating_state_t`:

| State | Encoding | Entry/exit |
|---|---:|---|
| RESET_ACTIVE | `3'b000` | Active while synchronized core reset is asserted or release is unqualified; exits to STARTUP on the first CORE_CLK edge after qualified release |
| STARTUP | `3'b001` | Initializes/evaluates readiness; exits to NORMAL on mandatory-init completion, FAULTED on mandatory failure, DEGRADED on an enabled-optional-only failure |
| NORMAL | `3'b011` | Active when init is complete and no degraded/fault/test condition has priority |
| DEGRADED | `3'b100` | Active for ≥1 enabled optional-function fault; exits only after all causes clear **and** `DEGRADED_ACK` is accepted for the current episode |
| FAULTED | `3'b101` | Active after a mandatory/nonrecoverable fault; **latched** until system or external reset |
| TEST_DEBUG | `3'b111` | Active only when init complete, qualified test-active true, and no reset/fault/startup/degraded condition has priority |
| Reserved | `3'b010`, `3'b110` | Never generated; every consumer treats either as FAULTED for output gating and asserts illegal-state evidence |

**Priority (highest to lowest): RESET_ACTIVE, FAULTED, STARTUP, DEGRADED,
TEST_DEBUG, NORMAL** (`ARCH-STATE-001`–`007`, `DFC-FUNC-0006`). A
higher-priority active condition determines the reported state regardless
of what a lower-priority condition would otherwise indicate.

**Orthogonal qualifiers** (registered, independent of the primary
encoding, per `DFC-FUNC-0007`): `HOST_READY`, `INIT_COMPLETE`,
`INIT_FAILED`, `OBSERVATIONAL_MODE`, `EFFECTIVE_OPERATIONAL_ENABLE`. The
last is computed exactly as:

```
EFFECTIVE_OPERATIONAL_ENABLE =
  OPERATIONAL_ENABLE & INIT_COMPLETE & !INIT_FAILED &
  ((STATE == NORMAL) | (STATE == DEGRADED)) &
  !OBSERVATIONAL_MODE & !TEST_DEBUG
```

(`ARCH-STATE` prose, `DFC-FUNC-0008`) — never re-derive this differently;
import the equation as written.

## 4. Startup and readiness (ARCH-002 SS4.2)

- `ARCH-START-001`: `core_rst_n` release is synchronized after 4
  consecutive valid CORE_CLK edges (RTL-024 generates this per
  `ARCH-RST-001`; RTL-002 consumes the released signal).
- `ARCH-START-002`: on the first released edge, RTL-002 enters STARTUP;
  initialization qualification begins the *following* edge.
- `ARCH-START-003`: RTL-001 and the RTL-024 host bridge assert host-ready
  only once their own reset state, status collection, mailboxes, and DRI
  endpoint are empty/coherent — RTL-002 does not assert `HOST_READY`
  independently of that condition.
- `ARCH-START-004`: a mandatory module is ready when its `ready` output is
  high; startup completes when all mandatory-ready bits are high **or**
  the SRS timeout expires (`DFC-PERF-0002`: mandatory init terminates by
  499,000 CORE_CLK cycles, asserting `INIT_COMPLETE` or `INIT_FAILED`;
  `INIT_FAILED` causes FAULTED). `DFC-PERF-0001`: `HOST_READY` asserts no
  later than 1,024 CORE_CLK cycles after reset release when host-interface
  infrastructure is operational.
- `ARCH-START-005`: SPI commands arriving before host-ready are fully
  framed and answered BUSY, with no DRI request or target side effect —
  this is the SPI bridge's obligation (`dfc_rtl024_spi_bridge.sv`'s current
  disclosed BUSY-status gap is exactly this path, not yet implemented
  there; RTL-002's role is only to gate `HOST_READY` correctly upstream).
- `ARCH-START-006`: no startup step uses executable software, host-supplied
  data, or staggered per-module reset release.

## 5. Module enable, reset fan-out, and readiness aggregation

- **`SUBSYS_ENABLE`** (REG-002 0x001C, owner RTL-001/RTL-002): 24-bit
  enable bitmap. Fixed mandatory mask `0x80F81F` is always enabled;
  **only** the optional mask `0x7F07E0` is host-configurable. A disabled
  optional module is excluded from degraded-state determination
  (`DFC-FUNC-0010`).
- **`SUBSYS_READY`** (0x0020, RTL-002-owned) / **`SUBSYS_FAULT`** (0x0024,
  RTL-002-owned): host-visible mirrors of `module_ready_i[23:0]` /
  `module_fault_i[23:0]`.
- **`RESET_CONTROL`** (0x0028) / **`RESET_STATUS`** (0x002C): protected
  command register accepting zero (no action) or exactly one of
  SYSTEM_RESET, one MODULE_RESET bit (RTL-001 through RTL-024), or
  SAFETY_DOMAIN_RESET (`REG-ENC-019`) — multiple simultaneous scopes reject
  atomically. Per `ARCH-RST-004`: a module-reset request is asserted ≥4
  CORE_CLK cycles, clears state per Appendix F, and requires **two
  consecutive ready cycles** before RTL-002 reports completion.
  `DFC-FUNC-0012`/`0013`: an accepted controlled reset reports busy state,
  terminal completion/rejection, last scope, and last result; a request
  arriving while another is busy is **rejected, never queued or
  preempted**. `DFC-FUNC-0014`: a new terminal reset result dominates a
  simultaneous request to clear prior evidence.
  `ARCH-RST-005` (system reset): resets RTL-002 through RTL-024 and clears
  RTL-001 configuration one CORE_CLK after completion is recorded.
  `ARCH-RST-006` (safety-domain reset): resets RTL-012 through RTL-016 and
  forces every safety output inactive, touching nothing else.
- **`ARCH-RTL002-001`** (Appendix F.1, RTL-002's own derivation contract):
  state-transition priority is SS4.1 above; a controlled-reset request
  while busy rejects the new request; a terminal reset result dominates a
  simultaneous result-clear; **ready** is host-path-initialized AND
  state-logic-initialized; **fault** is illegal state OR reset timeout OR
  a mandatory startup/loss fault.

## 6. SYS_CONTROL / SYS_STATUS (REG-002 0x0014/0x0018)

`SYS_CONTROL` fields (RW unless noted): `OPERATIONAL_ENABLE` (reset 0),
`OBSERVATIONAL_MODE` (reset **1** — the device powers up in observational
mode by design), `GLOBAL_IRQ_ENABLE` (reset 0), `GLOBAL_EVENT_ENABLE`
(reset **1**), `DEGRADED_ACK` (WO-CMD, one pulse per accepted write, no
undefined-encoding/reserved-bit tolerance). `SYS_STATUS` fields (RO):
includes `INIT_COMPLETE`, `INIT_FAILED`, `EFFECTIVE_OPERATIONAL_ENABLE`
(RO, confirmed real field — REG-002 now exposes SS3's equation directly,
resolving the gap this spec previously flagged), and the primary-state/
startup summary; reset value `0x00000041` reflects the power-up
orthogonal-state defaults above.

## 7. Verification obligations

Minimum required VP-002 case families:

- **`VP-MOD-002`**: startup, primary/orthogonal states, mandatory/optional
  readiness, enable distribution, controlled reset, degraded
  acknowledgement, timeout, illegal-state handling, and priority all
  satisfy `ARCH-RTL002-001` and `ARCH-VAL-002`.
- **`VP-INF-001`**: operating-state reset/startup/normal/degraded/faulted/
  test behavior follows `ARCH-STATE-001`–`007` exactly, including reserved-
  state handling.
- **`VP-INF-002`**: `HOST_READY`/init/observation/effective-enable
  qualifiers satisfy their equations independently of the primary
  encoding.
- **`VP-INF-003`**: mandatory/optional readiness, startup timeout, degraded
  acknowledgement, fault latching, and reset-command priority produce the
  required state and evidence.

## 8. Known gap carried from RTL-001/RTL-024's own disclosures

RTL-002's `module_ready_i`/`module_fault_i` inputs are only as meaningful
as their 24 producers. With RTL-003 through RTL-023 not yet implemented,
any RTL-002 implementation built today can only be exercised against
RTL-001's real `status_o` (bit 0) and stub/tied values for the rest —
identical in spirit to `dfc_rtl024.sv`'s own labeled-stub disclosure.
Log this in `OPEN_ISSUES.md` when RTL-002 implementation begins, not as a
silent limitation.
