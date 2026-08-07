# RTL-001 Module Specification — Configuration Register Bank

**Revision:** B (authored fresh against the `-002` baseline; the `-001`-era
Rev A specification is not a content source, only a structural reference)
**Status:** Derived artifact per `RCA-DFC-CHTR-002` SS3.3. This document
implements the eight-document `-002` set; it does not define new behavior
(CHTR-DOC-006). Every normative claim below cites its owning document —
ARCH-002, REG-002, RTL-STD-002, or VP-002 — and this file must not be read
as an alternate source for any of them.

## 1. Identity and role

RTL-001 is the Dragon Core Configuration Register Bank: the **sole
host-visible DRI register endpoint and sole address decoder** in the
system (`ARCH-GEN-003`). No other module decodes a host address. It is a
**mandatory, host-ready-at-reset module** with no `module_reset_i` — it is
reset only by system/external reset (Appendix D.1, bit 0). It owns register
storage for the full REG-002 address space, distributing registered
control structures to, and collecting registered status structures from,
every other RTL-002 through RTL-024 module (`ARCH-CONN-003`).

Controlling documents: `RCA-DFC-REG-002` (sole owner of every register
fact this module implements), `RCA-DFC-ARCH-002` SS7.1–7.2 and Appendix
A/B/D/F.1 (DRI protocol, port catalog, packed control/status types,
readiness/reset scope, per-module derivation contract `ARCH-RTL001-001`).

## 2. Ports

Per `RTLSTD-MOD-002`/`RTLSTD-MOD-003`/`RTLSTD-MOD-004`, grouped exactly as
the Architecture formal port catalog (ARCH-002 "RTL-001 - Configuration
Register Bank", 74 ports) defines them. This spec does not repeat every
row — the catalog is normative — but the groups are:

- **Clock/reset:** `core_clk_i`, `core_rst_n_i` (asynchronous assert,
  synchronized release; RDC-001).
- **DRI request/response** (`ARCH-DRI-001` through `ARCH-DRI-009`):
  `dri_req_valid_i`, `dri_req_ready_o`, `dri_req_write_i`, `dri_req_addr_i`,
  `dri_req_wdata_i`, `dri_req_wstrb_i`, `dri_rsp_valid_o`,
  `dri_rsp_ready_i`, `dri_rsp_rdata_o`, `dri_rsp_code_o`.
- **Per-module control/status** (23 pairs, RTL-002 through RTL-024):
  `rtl0NN_control_o` (`dfc_rtlNNN_control_t`, widths per `dfc_types_pkg`)
  and `rtl0NN_status_i` (`dfc_rtlNNN_status_t`). Each status input also
  feeds RTL-002's `module_ready_i[N]`/`module_fault_i[N]` aggregation per
  the catalog's Consumer column — RTL-001 does not aggregate readiness
  itself.
- **Interrupt/event/routing:** `irq_req_o`, `timestamp_i`, `evt_valid_o`/
  `evt_ready_i`/`evt_record_o`, `route_tx_msg_*`/`route_rx_msg_*`
  (valid/ready atomic message transfer, `dfc_message_record_t`).
- **Own status/broadcast:** `status_o` (`dfc_rtl001_status_t`, 19 bits —
  `ready`, `fault`, `event_overflow`, `event_drop_count[15:0]`),
  `operating_state_i`, `observational_mode_i`.
- **Condition masks:** `event_condition_enable_o`, `irq_condition_enable_o`
  (each `logic [23:0][63:0]`, 1536 bits — per-RTL-index subcondition mask
  storage; see SS5 below).

Port names/directions/widths/types must match the catalog exactly
(`RTLSTD-MOD-004`); if they diverge, the catalog is correct and this file
or the RTL is wrong.

## 3. DRI protocol implementation

RTL-001 implements `ARCH-DRI-001` through `ARCH-DRI-009` exactly:

- Request transfers on the CORE_CLK edge where `dri_req_valid` and
  `dri_req_ready` are both high; VALID and all request fields are stable
  while stalled (`ARCH-DRI-001`, `RTLSTD-DRI-002`).
- `dri_req_wstrb` must be `4'b1111`; any other value is `ACCESS_ERROR`
  (`ARCH-DRI-005`) — RTL-001 accepts only full-word writes (`REG-GEN-002`).
- Exactly one response per accepted request (`ARCH-DRI-006`,
  `RTLSTD-DRI-004`); response fields stable while stalled.
- `dri_rsp_code` is one of `000 OK`, `001 DECODE_ERROR`, `010 ACCESS_ERROR`,
  `011 PROTECTED_ERROR`, `100 ENDPOINT_ERROR`, `101 TIMEOUT`, `110 BUSY`,
  `111` reserved (`ARCH-DRI-008`).
- **Response deadline:** RTL-001 returns a response within 8 CORE_CLK
  cycles of acceptance (`ARCH-DRI-009`), and commits a write side effect
  only in the same cycle it commits the corresponding OK response
  (`ARCH-REG-002`, `RTLSTD-DRI-012`).
- Decode is the single accepted-request object per `ARCH-DRI-011`; a
  timed-out request produces exactly one terminal timeout result, never a
  second response or a late untracked write (`ARCH-DRI-014`).

## 4. Validation order and register-contract implementation

`ARCH-REG-001` fixes the first-error validation order RTL-001 must
implement: **alignment, mapped address (decode), access class, reserved
bits, legal value (range/encoding), protection state, staging/resource
state (busy), endpoint readiness** — matching REG-002's own statement of
this order in SS5 ("first-error validation order"). The first failure in
that order determines the response code and first-error evidence
(`CONFIG_ERROR_STATUS`/`CONFIG_ERROR_ADDR`/`CONFIG_ERROR_DATA`, REG-002
0x0038–0x0040).

Per `RTLSTD-REG-001` through `RTLSTD-REG-017`: register decode, field
extraction, access enforcement, reset values, and masks come from
`dfc_registers_pkg` (generated by `tools/pkggen/extract_registers.py`) —
never hand-derived. Specifically:

- **W1C fields** (131 across the map): bitwise clear-on-write-one; new
  same-cycle hardware evidence dominates a simultaneous host clear
  (`RTLSTD-REG-008`, `RTLSTD-REG-017`, `REG-GEN-008`).
- **COUNTER-CLR fields** (11): all-ones write → one clear pulse; all-zero →
  no effect; any other value → `ACCESS_ERROR`; never a bitwise mask
  (`RTLSTD-REG-016`).
- **WO-CMD fields** (37): one bounded one-cycle command per accepted
  nonzero write; no repeated action while stalled (`RTLSTD-REG-009`).
- **CONST/CONST1 fields** (9+3): fixed value; any write is `ACCESS_ERROR`.
- Every register's per-field access/reset — including the readback
  classification (`internal_reg`/`const`/`zero`/`external`/`internal_w1c`/
  `internal_capture`) that determines whether RTL-001 physically stores a
  field or passes through another module's `status_i` — is in
  `dfc_registers_pkg.json`'s `registers[].readback`. RTL-001's regbank
  (`rtl/infrastructure/generated/dfc_config_regbank_regs.sv`) is generated
  directly from that classification; do not hand-author storage for a
  register the classification marks `external`.

## 5. Condition masks (event/interrupt subcondition gating)

Per Appendix F.3: RTL-001 stores one 64-bit event-condition mask and one
64-bit interrupt-condition mask **per RTL index** (24 indices ×
2 × 64 bits = the 1536-bit `event_condition_enable_o`/
`irq_condition_enable_o` ports). A listed bit independently enables that
subcondition; unlisted bits are reserved zero and a write setting one is
rejected. Existing per-module `EVENT_ENABLE`/`IRQ_ENABLE` fields remain
master gates — effective qualification is `master_enable AND
condition_mask_bit`. Safety-mandatory events and the `0x007E`/`0x007F`
overflow events bypass ordinary gating entirely (Appendix F.3). Host
access to a given index's mask is via `CONDITION_MASK_SELECT.RTL_INDEX`
(0–23) plus `EVENT_CONDITION_MASK_LO/HI` and `IRQ_CONDITION_MASK_LO/HI`
(REG-002 0x004C–0x005C); only condition bits Appendix F.3 lists for the
selected module may be set (`REG-ENC-002`).

## 6. Protection and authorization

Per REG-002 SS4 (`dfc_constants_pkg`: `DFC_PROTECT_KEY1`=`0x52434131`,
`DFC_PROTECT_KEY2`=`0x4452474E`, `DFC_PROTECT_TIMEOUT_CYCLES`=50,000):
two consecutive accepted writes to `PROTECT_KEY.KEY` in that exact order,
followed by exactly one protected write within 50,000 CORE_CLK cycles.
Authorization clears on reset, successful protected write, bad key,
malformed access, CRC failure, timeout, pre-acceptance abort, or
unauthorized protected access (`ARCH-REG-004`, `RTLSTD-REG-007`). These are
deterministic hardware authorization constants, not cryptographic secrets
— never re-derive or hand-copy them; import from `dfc_constants_pkg`
(`RTLSTD-RST-009`'s prohibition on hand-copied constants applies equally
here).

## 7. Reset

RTL-001 has no `module_reset_i` (Appendix D.1 bit 0) — it resets only with
system/external reset. `ARCH-RTL001-001`: reset cancels any in-flight DRI
or proxy command before any side effect commits; reset dominates an
in-flight commit. Every state-holding object resets to its REG-002-defined
value, imported from `dfc_registers_pkg`'s generated `DFC_RESET_*`
parameters (`RTLSTD-RST-005`, `RTLSTD-RST-009`). `REG-GEN-011`:
configuration stored in RTL-001 is volatile across a *module* reset scope
but survives unless the reset scope explicitly includes RTL-001 — since
RTL-001 has no module-reset input, this distinction is moot for RTL-001
itself and matters only for how other modules' resets must *not* clear
RTL-001-owned storage.

## 8. Verification obligations

This module's RTL must satisfy, at minimum, VP-002's SPI/DRI and
register-contract case families:

- **`VP-HOST-001` through `VP-HOST-018`** (SS12): SPI framing, opcode/CRC
  handling, response construction, abort/truncation evidence, multiword
  stop-on-first-error, DRI stability/uniqueness, same-cycle write-commit
  discipline, and cross-environment (sim/FPGA/HIL/ASIC) equivalence.
- **`VP-REG-001` through `VP-REG-018`** (SS13): every offset/field/access
  class exercised — not sampled — including W1C priority, COUNTER-CLR
  semantics, staging/commit atomicity, snapshot/pop coherence, protection
  authorization lifecycle, and generated-artifact fidelity (`VP-REG-018`
  is the direct verification counterpart to this repo's extractor
  fail-loud checks).
- Register/DRI assertions per `RTLSTD-REG-015` and `RTLSTD-DRI-009`.

Anything these cases reveal as unresolvable against the `-002` text — not
just a coding mistake — belongs in `OPEN_ISSUES.md`, flagged for
`spec-verifier`, not resolved by assumption in this file or in RTL.
