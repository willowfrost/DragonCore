# RTL-014 Module Specification — Interlock Engine

**Revision:** B (supersedes Rev A, 2026-10-02). Rev A's port list, register
count, and missing staging/commit/term-source detail were wrong or
incomplete against the owning documents (`OPEN_ISSUES.md` item 66). Rev B
corrects them to match ARCH-002 and REG-002 as revised during RTL-014's
implementation (items 67-68).
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002, and RTL-STD-002. It defines no behavior of its
own. Where it records an implementation interpretation that no owning
document fixes, it says so and points to the `OPEN_ISSUES.md` entry.
**Implementation:** `rtl/safety/src/dfc_rtl014.sv` (header carries the full
disclosed design); register forwarding `tools/reggen/rtl014_field_map.json`
(`reggen.py` v5).

## 1. Identity and role

`ARCH-MOD-014`: eight atomically committed four-term expressions,
guarded-action permission, violation evidence, and lane-2 safety requests.
Owns REG-002 SS26 Interlock Engine (0x3200-0x32FF, **16 registers**).
Mandatory class: Appendix D.1 bit 13 (ready from reset, no `module_enable_i`).
Safety-scope reset: `RTL-002.module_reset_o[13]`. No physical pin
(`OPEN_ISSUES.md` item 77).

Controlling contracts: ARCH-002 SS10.2 `ARCH-SAFE-003`, SS10.3
`ARCH-SAFE-006`, SS10.4 (the `LATCHED_REQUEST` precedent), Appendix F.1
`ARCH-RTL014-001`, F.3 RTL-014 row and preamble, F.4 `ARCH-VAL-014` plus
F.4's closing staged-object first-error paragraph. Allocations: Appendix
C.1/C.3, C.4 bit 15, C.5 index 13, C.6 bit 1, C.7 `0x0042`, C.8 bits 16-23.
REG-002 `REG-ENC-010`, `REG-GEN-015`, `REG-COH-001` to `-003`.

## 2. Ports (19, ARCH-002 Appendix A "RTL-014 - Interlock Engine")

The Appendix A table is the authority. Widths come from the generated
`dfc_types_pkg` `_WIDTH` constants (PROJECT_CONTINUITY Section 2
`pkg::type_t` rule).

| Group | Ports | Peer |
|---|---|---|
| Clock/reset | `core_clk_i`, `core_rst_n_i`, `module_reset_i` | RTL-024; RTL-002.module_reset_o[13] |
| Register bus | `control_i` (`dfc_rtl014_control_t`), `status_o` (`dfc_rtl014_status_t`) | RTL-001; RTL-002.module_ready_i/fault_i[13] |
| Event | `timestamp_i`, `evt_valid_o`, `evt_ready_i`, `evt_record_o` | RTL-004; RTL-005 slot 13 |
| Interrupt/fault | `irq_req_o`, `fault_req_o` | RTL-003.irq_source_i[15]; RTL-013.fault_source_i[1] |
| Terms | `interlock_terms_i[63:0]` | `dragon_core_top.internal_source_vector[63:0]` (§4) |
| Safety outputs | `interlock_satisfied_o[7:0]`, `interlock_inhibit_o[7:0]`, `response_req_o` (`dfc_safety_response_req_t`) | RTL-016 (interlock_satisfied_i, interlock_inhibit_i, response_req_i[2]) |
| Broadcasts | `operating_state_i`, `observational_mode_i` | RTL-002 |
| Condition masks | `event_condition_enable_i`, `irq_condition_enable_i` | RTL-001 (F.3 index 13; stubbed `64'h0`, item 6) |

## 3. Registers (REG-002 SS26, 16 registers)

The register tables are owned by REG-002 and are not restated here.
Readback classes, from `dfc_registers_pkg.json`:

- **`internal_reg`, stored in RTL-001:** `ILOCK_CONTROL`,
  `ILOCK_ENTRY_SELECT`, and the five staging registers (`ILOCK_STAGE_TERMS`,
  `_LOGIC`, `_GUARD`, `_ENABLE`, `_RESPONSE`).
- **`zero`:** `ILOCK_VALIDATE_COMMIT`.
- **`external`, supplied by RTL-014:** `ILOCK_STATUS`,
  `ILOCK_ACTIVE_RESULT`, `RTL014_EVT_OVERFLOW_STATUS`, and the five
  `ILOCK_ACTIVE_*` registers.
- **Protected:** `ILOCK_CONTROL` and `ILOCK_VALIDATE_COMMIT`.

**Staged bank (`OPEN_ISSUES.md` item 68).**
- *Requirement:* `REG-COH-001`, `REG-3228`, and VP-SAFE-016 require eight
  independent staged entries.
- *Storage:* RTL-001 holds them. Each staging register is selector-indexed
  ×8 by `ILOCK_ENTRY_SELECT.ENTRY`, using `reggen.py` v5
  `indexed_registers`. A host write lands only in the selected entry, and a
  host read returns the selected entry's staged value.
- *Forwarding:* the complete bank reaches RTL-014 in `control_i`
  (ARCH-002 members `ilock_stage_e<0..7>__*`).

**Active readback.** The five `ILOCK_ACTIVE_*` registers report the entry
`ILOCK_ENTRY_SELECT` names (`REG-GEN-015`). They come from
`dfc_rtl014_status_t` bits 107:53 (item 67). FIRST_ERROR_ENTRY/CODE are
bits 114:108.

## 4. Term sources (Appendix C.1 / C.3)

**Producer.** `interlock_terms_i` is the C.1 internal signal-source vector,
built and **registered** in RTL-024 (`internal_source_vector_q`, item 76).

**Legal term IDs** (C.3, `REG-ENC-010`): 0-31 and 37. These are illegal:
- 32: RTL-014's own aggregate violation (self-reference).
- 33-36: RTL-022 user logic.
- 38-255: reserved.

**Bits in this build that are not live producers:**
- Bit 30 (any lost link) is a stub 0 until RTL-015 exists.
- Bits 33-36 are permanently 0, because RTL-022 is out of scope.

## 5. Commit, evaluation, and output contract

Every rule below is stated in its owning contract. This section records how
each one is met; it does not restate the rules.

- **Commit** (`ARCH-SAFE-006`, `ARCH-RTL014-001`, `ARCH-VAL-014`, F.4).
  - The whole bank is validated, in entry order then field order.
  - The first error anywhere rejects the entire bank, and both the prior
    active bank and the complete staged bank are preserved (`REG-COH-003`).
  - Success replaces all eight entries on one edge.
  - Field order and error codes are owned by `ARCH-VAL-014`.
  - The first error is retained in `ILOCK_STATUS.FIRST_ERROR_ENTRY`/
    `FIRST_ERROR_CODE` (REG-3204) until COMMIT_REJECTED is cleared
    (REG-COH-003).
  - The one-cycle commit pipeline is disclosed in item 69.
- **Evaluation and violation** follow `ARCH-SAFE-006`.
  - `ILOCK_CONTROL.ENABLE` gates every entry (item 70).
  - Reset clears every active entry to disabled.
- **Same-edge guard rule** (`ARCH-SAFE-006` final clause, VP-SAFE-007).
  - The violation, guard, inhibit, satisfied, response, and fault outputs
    are all registered from one evaluation, on one edge.
  - No pipeline stage sits between the active bank and those registers, so
    a freshly committed bank can assert on the next edge.
- **Guards** (DFC-FUNC-0107).
  - `interlock_inhibit_o` is indexed per guard.
  - `interlock_satisfied_o` is indexed per entry. This is an
    interpretation, recorded in item 71.
- **`LATCH_VIOLATION`:** item 70, using the SS10.4 precedent.
- **Lane 2** (`ARCH-SAFE-003`, C.8 bits 16-23).
  - `source_id` is the entry index, structurally limited to 0-7
    (RTLSTD-SAFE-014).
  - The lowest-entry priority rule and the zero-mask rule are recorded in
    item 72.
- **Fault** (C.6 bit 1, class 0x04, recoverable): `fault_req_o` is the live
  violation. `status_o.fault` has no detectable local source (item 73).
- **Events and IRQ** (C.7 `0x0042`, F.3 index 13).
  - Enable layering follows OPEN_ISSUES item 39; priority and drop
    accounting are in item 75.
  - The `source_id` convention is an open project-wide question (item 74).

## 6. Verification obligations and evidence

| Case | Evidence | Status |
|---|---|---|
| `VP-MOD-014` | `rtl014_integration_tb.sv` (105 checks) | T-SIM met; F-PROP not met (item 78) |
| `VP-SAFE-006` | Parts 3, 4, 7: every illegal class, atomicity, first error by entry and by field, new-bank timing | met (T-SIM) |
| `VP-SAFE-007` | Part 6: every-edge monitor, with a confirmed negative control | T-SIM met; F-PROP not met (item 78) |
| `VP-SAFE-016` | Parts 3 and 4: per-entry staging and active readback of every member | met (T-SIM) |
| Whole system | `rtl024_skeleton_tb.sv` RTL-014 section: real SPI commit and a real `gpio_i` pad driving the registered source vector to RTL-014 and to RTL-013 fault bit 1 | met |

Open, not met, and not RTL-014-specific: ARCH-VAL-014's "zero reserved
bits" clause depends on RTL-001 per-field reserved-bit validation, which
does not exist for any module yet (project-wide `OPEN_ISSUES.md` item 4).
