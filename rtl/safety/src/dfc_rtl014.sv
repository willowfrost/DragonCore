// ============================================================================
// dfc_rtl014.sv -- RTL-014 Interlock Engine (ARCH-MOD-014)
//
// Controlling spec: docs/rtl_specs/RTL-014_RevB.md (derived), owning
// contracts ARCH-002 SS10.2 ARCH-SAFE-003 (lane 2, source IDs 0-7,
// authorization bits 16-23), SS10.3 ARCH-SAFE-006, Appendix F.1
// ARCH-RTL014-001, F.3 RTL-014 row, F.4 ARCH-VAL-014 (+ F.4's closing
// staged-object first-error paragraph), Appendix C.1/C.3 (term sources/
// whitelist), C.4 bit 15, C.5 index 13, C.6 bit 1, C.7 event 0x0042;
// REG-002 SS26 (0x3200-0x323C, 16 registers); VP-002 VP-MOD-014,
// VP-SAFE-006/007/016.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous safety-scope reset (RTL-002.module_reset_o[13]).
// Register ownership: none decoded here (RTLSTD-REG-001) -- every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl014_field_map.json, reggen.py v5).
//
// Port list: the 19 ports of ARCH-002 Appendix A "RTL-014 - Interlock Engine
// (19 ports)" -- NOT the superseded RTL-014_RevA.md SS2 prose list, which omitted
// interlock_terms_i/interlock_satisfied_o/interlock_inhibit_o/irq_req_o/
// fault_req_o (OPEN_ISSUES.md item 66). Flat logic vectors sized by generated
// dfc_types_pkg _WIDTH constants; fields sliced by generated _HI/_LO
// constants (PROJECT_CONTINUITY.md Section 2 pkg::type_t rule).
//
// ---------------------------------------------------------------------------
// STRUCTURE (see OPEN_ISSUES.md items 66-75 for every disclosed decision):
//
//  1. STAGED BANK. The eight staged entries live in RTL-001 (selector-indexed
//     storage, reggen.py v5 -- REG-COH-001/REG-GEN-015) and arrive here as
//     the complete 8 x 55-bit bank in control_i (ilock_stage_e<i>__*). The
//     selected-entry stage members (ilock_stage_terms__* etc.) are forwarded
//     too but unused here (host readback of staged values is RTL-001's own
//     store) -- consumed by the unused-port sink below.
//
//  2. COMMIT (ARCH-SAFE-006, ARCH-RTL014-001, F.4). A COMMIT_ALL pulse and
//     the staged bank are BOTH registered one cycle (commit_d1_q/staged_q)
//     so the whole-bank validation reads local registers, never RTL-001's
//     distant stores combinationally (timing; same "capture this cycle,
//     commit the next" technique as OPEN_ISSUES items 41/57/65). Because the
//     pulse and the bank are delayed identically, the validated bank is
//     exactly the bank present in the COMMIT_ALL cycle (RTLSTD-SEQ-010). All
//     eight entries are validated in parallel; the FIRST error in entry
//     order, then field order, is selected by a casez priority encoder
//     (documented below, RTLSTD-COMB-006) -- never a loop-carried found
//     flag (OPEN_ISSUES items 17/65). Any error anywhere rejects the WHOLE
//     bank: the prior active bank is preserved and nothing is replaced
//     (REG-COH-003). Success replaces all eight entries in one edge.
//
//     Per-entry field order (= REG-002 register order, consistent with F.4
//     "range, then cross-field relation"): TERM0, TERM1, TERM2, TERM3 legal
//     per C.3 (0-31 or 37); OPERATOR 0-3; then cross-field "enabled entry
//     requires nonzero guard mask" (REG-ENC-010). SAFETY_RESPONSE_MASK is a
//     four-bit field whose every value is legal (REG-3228). Reserved register
//     bits never reach this module (RTL-001 has no per-field reserved
//     validation yet, OPEN_ISSUES item 4), so ARCH-VAL-014's "zero reserved
//     bits" clause is not checkable here -- disclosed, item 69. Field order
//     and error codes are now owned by ARCH-VAL-014 (1-4 TERM0-3 illegal,
//     5 OPERATOR illegal, 6 enabled entry with zero guard mask). The first
//     error of the earliest rejection is retained in ILOCK_STATUS.
//     FIRST_ERROR_ENTRY/FIRST_ERROR_CODE (REG-3204, REG-COH-003) until
//     COMMIT_REJECTED is cleared; a rejection landing the same cycle as that
//     clear wins (F.4 "dominates simultaneous result clear").
//
//  3. EVALUATION (ARCH-SAFE-006). interlock_terms_i is RTL-024's REGISTERED
//     internal_source_vector_q (C.1). Each active term ID (validated, so
//     always 0-31 or 37) indexes that vector, is optionally inverted, and
//     combines by the entry's operator. violation_now[e] =
//     ILOCK_CONTROL.ENABLE & entry_enable[e] & !expression[e].
//
//     SAME-EDGE GUARD RULE ("Guard permission changes inactive in the same
//     edge that violation qualifies"; VP-SAFE-007 "no prohibited one-cycle
//     output window"): violation_active, GUARD_ALLOWED, interlock_inhibit_o,
//     interlock_satisfied_o, response_req_o and fault_req_o are ALL
//     registered from the SAME combinational evaluation on the SAME edge.
//     No guard output is ever derived from an already-registered violation.
//     No pipeline stage sits between the active bank and these registers,
//     so a violation on a freshly committed bank asserts on the very next
//     edge (ARCH-RTL014-001 -- no grace period).
//
//  4. LATCH_VIOLATION (item 70). Effective violation =
//     ILOCK_CONTROL.ENABLE & entry_enable & (violation_now | (LATCH_VIOLATION
//     & VIOLATION_STICKY)). With latch policy off, guards/response follow the
//     live condition only (level); with it on, they stay inhibited/requested
//     until the host clears the entry's sticky bit, and a clear is
//     ineffective while the violation is still live (new evidence dominates,
//     REG-3204/DFC-SAFE-0009). Precedent: ARCH-002 SS10.4 LATCHED_REQUEST and
//     OPEN_ISSUES item 62 (active vs sticky scope chosen explicitly).
//
//  5. GUARDS (DFC-FUNC-0107). GUARD_ALLOWED[g] = no effective-violated entry
//     has bit g in its guard mask. interlock_inhibit_o = ~GUARD_ALLOWED (per
//     guard); interlock_satisfied_o[e] = ENTRY_TRUE[e] = ILOCK_CONTROL.ENABLE
//     & entry_enable[e] & expression[e] (per entry -- item 71: the two ports
//     would be redundant complements if both were per guard). Reset/module
//     reset: inhibit all ones (Appendix A reset 1), allowed/satisfied zero.
//
//  6. LANE 2 RESPONSE (ARCH-SAFE-003, C.8 16-23). One 8-bit
//     dfc_safety_response_req_t per cycle: valid when any effective-violated
//     entry has a nonzero response mask; source_id = the LOWEST such entry
//     (same rule as RTL-013 primary-source selection -- item 72); response
//     mask = that entry's mask. A zero mask requests nothing (item 72).
//     source_id is structurally 0-7 (3 bits), so no reserved lane-2 ID can
//     ever be asserted (RTLSTD-SAFE-014).
//
//  7. FAULT (C.6 bit 1, class 0x04, recoverable): fault_req_o = any LIVE
//     violation (C.6 "active condition plus RTL-013 sticky evidence").
//     status_o.fault: no local fault source is detectable (the active bank
//     can only ever hold validated values) -- held 0, disclosed item 73.
//     status_o.ready: 1 from the cycle after reset release (mandatory,
//     D.1 bit 13).
//
//  8. EVENTS/IRQ (C.7 0x0042, F.3 RTL-014 row, F.3 preamble, item 39
//     precedent). Subtypes: 0 violation (rising), 1 satisfied/recovered
//     (falling), 2 commit accepted, 3 commit rejected. The active entry's own
//     EVENT_ENABLE/IRQ_ENABLE is the per-channel master that REPLACES
//     ILOCK_CONTROL.EVENT_ENABLE/IRQ_ENABLE for F.3 bits 0-15; the module
//     enables gate bits 16-18. Violation IRQs are level (C.4 "qualified
//     source level"); recovery/commit IRQs are one-cycle (RTL-003 latches).
//     One shared pending slot: rejected > accepted > lowest-entry violation
//     > lowest-entry recovery; every losing or blocked candidate is counted
//     in event_drop_count/event_overflow (RTL-009/010 precedent, RTLSTD-
//     EVID-008). event_data: [7:0] subtype, [15:8] entry, [31:16] error code
//     for a rejected commit, else 0 (item 69). source_id = C.5 index 13,
//     matching the convention of every shipped producer (item 74 records the
//     C.5 "Source ID" column discrepancy project-wide).
//     event_condition_enable_i/irq_condition_enable_i are tied 64'h0 in
//     dfc_rtl024.sv (OPEN_ISSUES item 6), so no event/IRQ fires in the
//     integrated build yet -- disclosed, not a defect here.
//
//  9. ACTIVE READBACK (REG-322C..323C, REG-GEN-015): the active entry named
//     by ILOCK_ENTRY_SELECT is muxed and REGISTERED onto status_o (one cycle
//     after a select/commit change; the DRI path cannot read faster).
//
// operating_state_i / observational_mode_i have no equation in RTL-014's
// owning contracts (safety-output observational gating belongs to RTL-016,
// REG-GEN-012) -- consumed by the unused-port sink.
// ============================================================================

module dfc_rtl014 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[13]

  input  logic [dfc_types_pkg::DFC_RTL014_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL014_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,          // RTL-003.irq_source_i[15]
  output logic         fault_req_o,        // RTL-013.fault_source_i[1]

  input  logic [63:0]  interlock_terms_i,  // dragon_core_top.internal_source_vector[63:0]
  output logic [7:0]   interlock_satisfied_o,  // RTL-016.interlock_satisfied_i
  output logic [7:0]   interlock_inhibit_o,    // RTL-016.interlock_inhibit_i
  output logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_req_o,
                                            // RTL-016.response_req_i[2]

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 13
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 13
);

  // ---- local packing of one entry (internal layout only, not a normative
  // encoding: 55 bits = the ARCH-002 per-entry member set) ----
  localparam int unsigned NE     = 8;
  localparam int unsigned EW     = 55;
  localparam int unsigned F_T0   = 0;
  localparam int unsigned F_T1   = 8;
  localparam int unsigned F_T2   = 16;
  localparam int unsigned F_T3   = 24;
  localparam int unsigned F_INV  = 32;   // 4
  localparam int unsigned F_OP   = 36;   // 3
  localparam int unsigned F_GRD  = 39;   // 8
  localparam int unsigned F_EN   = 47;
  localparam int unsigned F_LAT  = 48;
  localparam int unsigned F_EVE  = 49;
  localparam int unsigned F_IRQE = 50;
  localparam int unsigned F_RSP  = 51;   // 4

  // ---- control_i field extraction ----
  wire       ctl_enable       = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_CONTROL__ENABLE_HI];
  wire       ctl_event_enable = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_CONTROL__EVENT_ENABLE_HI];
  wire       ctl_irq_enable   = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_CONTROL__IRQ_ENABLE_HI];
  wire [7:0] ctl_clr_violation_sticky = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STATUS__VIOLATION_STICKY_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STATUS__VIOLATION_STICKY_LO];
  wire       ctl_clr_commit_complete  = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STATUS__COMMIT_COMPLETE_HI];
  wire       ctl_clr_commit_rejected  = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STATUS__COMMIT_REJECTED_HI];
  wire [2:0] ctl_entry_select = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_ENTRY_SELECT__ENTRY_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_ENTRY_SELECT__ENTRY_LO];
  wire       ctl_commit_all   = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_VALIDATE_COMMIT__COMMIT_ALL_HI];
  wire       ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__RTL014_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  // Selected-entry stage view (unused here -- see header item 1).
  wire [51:0] ctl_selected_stage_view = {
    control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_TERMS__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_TERMS__TERM0_LO],
    control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_LOGIC__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_LOGIC__INVERT_MASK_LO],
    control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_GUARD__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_GUARD__GUARD_MASK_LO],
    control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_ENABLE__IRQ_ENABLE_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_ENABLE__ENABLE_LO],
    control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_RESPONSE__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_RESPONSE__SAFETY_RESPONSE_MASK_LO]};

  // ---- complete staged bank, one 55-bit slot per entry ----
  wire [NE*EW-1:0] staged_bus;
  assign staged_bus[0*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM0_LO];
  assign staged_bus[0*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM1_LO];
  assign staged_bus[0*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM2_LO];
  assign staged_bus[0*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__TERM3_LO];
  assign staged_bus[0*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__INVERT_MASK_LO];
  assign staged_bus[0*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__OPERATOR_LO];
  assign staged_bus[0*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__GUARD_MASK_LO];
  assign staged_bus[0*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__ENABLE_HI];
  assign staged_bus[0*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__LATCH_VIOLATION_HI];
  assign staged_bus[0*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__EVENT_ENABLE_HI];
  assign staged_bus[0*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__IRQ_ENABLE_HI];
  assign staged_bus[0*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E0__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[1*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM0_LO];
  assign staged_bus[1*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM1_LO];
  assign staged_bus[1*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM2_LO];
  assign staged_bus[1*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__TERM3_LO];
  assign staged_bus[1*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__INVERT_MASK_LO];
  assign staged_bus[1*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__OPERATOR_LO];
  assign staged_bus[1*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__GUARD_MASK_LO];
  assign staged_bus[1*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__ENABLE_HI];
  assign staged_bus[1*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__LATCH_VIOLATION_HI];
  assign staged_bus[1*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__EVENT_ENABLE_HI];
  assign staged_bus[1*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__IRQ_ENABLE_HI];
  assign staged_bus[1*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E1__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[2*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM0_LO];
  assign staged_bus[2*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM1_LO];
  assign staged_bus[2*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM2_LO];
  assign staged_bus[2*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__TERM3_LO];
  assign staged_bus[2*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__INVERT_MASK_LO];
  assign staged_bus[2*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__OPERATOR_LO];
  assign staged_bus[2*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__GUARD_MASK_LO];
  assign staged_bus[2*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__ENABLE_HI];
  assign staged_bus[2*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__LATCH_VIOLATION_HI];
  assign staged_bus[2*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__EVENT_ENABLE_HI];
  assign staged_bus[2*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__IRQ_ENABLE_HI];
  assign staged_bus[2*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E2__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[3*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM0_LO];
  assign staged_bus[3*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM1_LO];
  assign staged_bus[3*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM2_LO];
  assign staged_bus[3*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__TERM3_LO];
  assign staged_bus[3*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__INVERT_MASK_LO];
  assign staged_bus[3*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__OPERATOR_LO];
  assign staged_bus[3*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__GUARD_MASK_LO];
  assign staged_bus[3*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__ENABLE_HI];
  assign staged_bus[3*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__LATCH_VIOLATION_HI];
  assign staged_bus[3*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__EVENT_ENABLE_HI];
  assign staged_bus[3*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__IRQ_ENABLE_HI];
  assign staged_bus[3*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E3__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[4*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM0_LO];
  assign staged_bus[4*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM1_LO];
  assign staged_bus[4*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM2_LO];
  assign staged_bus[4*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__TERM3_LO];
  assign staged_bus[4*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__INVERT_MASK_LO];
  assign staged_bus[4*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__OPERATOR_LO];
  assign staged_bus[4*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__GUARD_MASK_LO];
  assign staged_bus[4*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__ENABLE_HI];
  assign staged_bus[4*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__LATCH_VIOLATION_HI];
  assign staged_bus[4*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__EVENT_ENABLE_HI];
  assign staged_bus[4*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__IRQ_ENABLE_HI];
  assign staged_bus[4*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E4__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[5*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM0_LO];
  assign staged_bus[5*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM1_LO];
  assign staged_bus[5*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM2_LO];
  assign staged_bus[5*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__TERM3_LO];
  assign staged_bus[5*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__INVERT_MASK_LO];
  assign staged_bus[5*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__OPERATOR_LO];
  assign staged_bus[5*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__GUARD_MASK_LO];
  assign staged_bus[5*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__ENABLE_HI];
  assign staged_bus[5*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__LATCH_VIOLATION_HI];
  assign staged_bus[5*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__EVENT_ENABLE_HI];
  assign staged_bus[5*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__IRQ_ENABLE_HI];
  assign staged_bus[5*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E5__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[6*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM0_LO];
  assign staged_bus[6*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM1_LO];
  assign staged_bus[6*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM2_LO];
  assign staged_bus[6*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__TERM3_LO];
  assign staged_bus[6*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__INVERT_MASK_LO];
  assign staged_bus[6*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__OPERATOR_LO];
  assign staged_bus[6*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__GUARD_MASK_LO];
  assign staged_bus[6*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__ENABLE_HI];
  assign staged_bus[6*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__LATCH_VIOLATION_HI];
  assign staged_bus[6*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__EVENT_ENABLE_HI];
  assign staged_bus[6*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__IRQ_ENABLE_HI];
  assign staged_bus[6*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E6__SAFETY_RESPONSE_MASK_LO];
  assign staged_bus[7*EW+F_T0 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM0_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM0_LO];
  assign staged_bus[7*EW+F_T1 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM1_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM1_LO];
  assign staged_bus[7*EW+F_T2 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM2_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM2_LO];
  assign staged_bus[7*EW+F_T3 +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM3_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__TERM3_LO];
  assign staged_bus[7*EW+F_INV +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__INVERT_MASK_LO];
  assign staged_bus[7*EW+F_OP +: 3] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__OPERATOR_LO];
  assign staged_bus[7*EW+F_GRD +: 8] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__GUARD_MASK_LO];
  assign staged_bus[7*EW+F_EN +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__ENABLE_HI];
  assign staged_bus[7*EW+F_LAT +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__LATCH_VIOLATION_HI];
  assign staged_bus[7*EW+F_EVE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__EVENT_ENABLE_HI];
  assign staged_bus[7*EW+F_IRQE +: 1] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__IRQ_ENABLE_HI];
  assign staged_bus[7*EW+F_RSP +: 4] = control_i[dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_CONTROL__ILOCK_STAGE_E7__SAFETY_RESPONSE_MASK_LO];

  // ==========================================================================
  // Commit pipeline: staged bank + COMMIT_ALL pulse captured together.
  // ==========================================================================
  logic [NE*EW-1:0] staged_q;
  logic             commit_d1_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      staged_q    <= '0;
      commit_d1_q <= 1'b0;
    end else if (module_reset_i) begin
      staged_q    <= '0;
      commit_d1_q <= 1'b0;
    end else begin
      staged_q    <= staged_bus;
      commit_d1_q <= ctl_commit_all;
    end
  end

  // ---- whole-bank validation (ARCH-VAL-014), all entries in parallel ----
  // Term legality per Appendix C.3 / REG-ENC-010: 0-31 or 37.
  logic [3:0] term_ok [0:NE-1];
  always_comb begin
    for (int e = 0; e < NE; e++) begin
      for (int k = 0; k < 4; k++) begin
        term_ok[e][k] = (staged_q[e*EW + 8*k +: 8] <= 8'd31) || (staged_q[e*EW + 8*k +: 8] == 8'd37);
      end
    end
  end

  logic [3:0] entry_code [0:NE-1];
  logic [NE-1:0] entry_bad;
  always_comb begin
    for (int e = 0; e < NE; e++) begin
      entry_code[e] = 4'd0;
      if      (!term_ok[e][0])                                              entry_code[e] = 4'd1;
      else if (!term_ok[e][1])                                              entry_code[e] = 4'd2;
      else if (!term_ok[e][2])                                              entry_code[e] = 4'd3;
      else if (!term_ok[e][3])                                              entry_code[e] = 4'd4;
      else if (staged_q[e*EW+F_OP +: 3] > 3'd3)                             entry_code[e] = 4'd5;
      else if (staged_q[e*EW+F_EN] && (staged_q[e*EW+F_GRD +: 8] == 8'h00)) entry_code[e] = 4'd6;
      entry_bad[e] = (entry_code[e] != 4'd0);
    end
  end

  // First error in ENTRY order: one casez pattern per entry position
  // (bit 0 = entry 0 highest priority), each an independent comparison.
  logic [2:0] first_bad_entry;
  always_comb begin
    casez (entry_bad)
      8'b???????1: first_bad_entry = 3'd0;
      8'b??????10: first_bad_entry = 3'd1;
      8'b?????100: first_bad_entry = 3'd2;
      8'b????1000: first_bad_entry = 3'd3;
      8'b???10000: first_bad_entry = 3'd4;
      8'b??100000: first_bad_entry = 3'd5;
      8'b?1000000: first_bad_entry = 3'd6;
      8'b10000000: first_bad_entry = 3'd7;
      default:     first_bad_entry = 3'd0;   // no error (bank_ok)
    endcase
  end
  wire [3:0] first_bad_code = entry_code[first_bad_entry];
  wire       bank_ok        = (entry_bad == 8'h00);
  wire       commit_accept  = commit_d1_q && bank_ok;
  wire       commit_reject  = commit_d1_q && !bank_ok;

  // ==========================================================================
  // Active bank -- reset clears every entry to disabled (ARCH-RTL014-001).
  // ==========================================================================
  logic [NE*EW-1:0] active_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      active_q <= '0;
    end else if (module_reset_i) begin
      active_q <= '0;
    end else if (commit_accept) begin
      active_q <= staged_q;   // all eight entries, one edge; a reject leaves it untouched
    end
  end

  // ==========================================================================
  // Evaluation (ARCH-SAFE-006) -- combinational from active_q and the
  // registered term vector; every consumer below registers on one edge.
  // ==========================================================================
  logic [NE-1:0] viol_sticky_q;
  logic [NE-1:0] viol_active_q;

  logic [NE-1:0] expr_true;
  logic [NE-1:0] act_en, act_latch, act_evt_en, act_irq_en;
  logic [7:0]    act_guard [0:NE-1];
  logic [3:0]    act_resp  [0:NE-1];
  logic [3:0]    tv        [0:NE-1];   // selected, inverted term values
  always_comb begin
    for (int e = 0; e < NE; e++) begin
      for (int k = 0; k < 4; k++) begin
        // validated active IDs are 0-31 or 37, so ID[5:0] indexes C.1 exactly
        tv[e][k] = interlock_terms_i[active_q[e*EW + 8*k +: 6]] ^ active_q[e*EW + F_INV + k];
      end
      case (active_q[e*EW+F_OP +: 3])
        3'd0:    expr_true[e] = &tv[e];                                // AND
        3'd1:    expr_true[e] = |tv[e];                                // OR
        3'd2:    expr_true[e] = (tv[e][0]&tv[e][1]&tv[e][2]) | (tv[e][0]&tv[e][1]&tv[e][3]) |
                                (tv[e][0]&tv[e][2]&tv[e][3]) | (tv[e][1]&tv[e][2]&tv[e][3]);  // 3-of-4
        3'd3:    expr_true[e] = (tv[e][0]&tv[e][1]) | (tv[e][2]&tv[e][3]);
        default: expr_true[e] = 1'b0;   // unreachable (validated); fail safe = violation
      endcase
      act_en[e]     = active_q[e*EW+F_EN];
      act_latch[e]  = active_q[e*EW+F_LAT];
      act_evt_en[e] = active_q[e*EW+F_EVE];
      act_irq_en[e] = active_q[e*EW+F_IRQE];
      act_guard[e]  = active_q[e*EW+F_GRD +: 8];
      act_resp[e]   = active_q[e*EW+F_RSP +: 4];
    end
  end

  wire [NE-1:0] viol_now   = {NE{ctl_enable}} & act_en & ~expr_true;
  wire [NE-1:0] entry_true = {NE{ctl_enable}} & act_en &  expr_true;
  wire [NE-1:0] eff_viol   = {NE{ctl_enable}} & act_en & (viol_now | (act_latch & viol_sticky_q));

  logic [7:0] guard_allowed_comb;
  logic [NE-1:0] guard_hit [0:7];
  always_comb begin
    for (int g = 0; g < 8; g++) begin
      for (int e = 0; e < NE; e++) guard_hit[g][e] = eff_viol[e] & act_guard[e][g];
      guard_allowed_comb[g] = (guard_hit[g] == 8'h00);
    end
  end

  // Lane-2 request: lowest effective-violated entry with a nonzero mask.
  logic [NE-1:0] resp_eligible;
  always_comb begin
    for (int e = 0; e < NE; e++) resp_eligible[e] = eff_viol[e] && (act_resp[e] != 4'h0);
  end
  logic [2:0] resp_entry;
  always_comb begin
    casez (resp_eligible)
      8'b???????1: resp_entry = 3'd0;
      8'b??????10: resp_entry = 3'd1;
      8'b?????100: resp_entry = 3'd2;
      8'b????1000: resp_entry = 3'd3;
      8'b???10000: resp_entry = 3'd4;
      8'b??100000: resp_entry = 3'd5;
      8'b?1000000: resp_entry = 3'd6;
      8'b10000000: resp_entry = 3'd7;
      default:     resp_entry = 3'd0;
    endcase
  end
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_comb;
  always_comb begin
    response_comb = '0;
    if (resp_eligible != 8'h00) begin
      response_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_LO] = act_resp[resp_entry];
      response_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_LO] = resp_entry;
      response_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI] = 1'b1;
    end
  end

  // ==========================================================================
  // Same-edge registered outputs + sticky evidence.
  // ==========================================================================
  logic [NE-1:0] entry_true_q;
  logic [7:0]    guard_allowed_q;
  logic [7:0]    inhibit_q;
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_q;
  logic          fault_q;
  logic          commit_complete_q;
  logic          commit_rejected_q;
  logic [2:0]    first_err_entry_q;
  logic [3:0]    first_err_code_q;
  logic          ready_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      viol_active_q     <= '0;
      viol_sticky_q     <= '0;
      entry_true_q      <= '0;
      guard_allowed_q   <= 8'h00;
      inhibit_q         <= 8'hFF;
      response_q        <= '0;
      fault_q           <= 1'b0;
      commit_complete_q <= 1'b0;
      commit_rejected_q <= 1'b0;
      first_err_entry_q <= 3'd0;
      first_err_code_q  <= 4'd0;
      ready_q           <= 1'b0;
    end else if (module_reset_i) begin
      viol_active_q     <= '0;
      viol_sticky_q     <= '0;
      entry_true_q      <= '0;
      guard_allowed_q   <= 8'h00;
      inhibit_q         <= 8'hFF;
      response_q        <= '0;
      fault_q           <= 1'b0;
      commit_complete_q <= 1'b0;
      commit_rejected_q <= 1'b0;
      first_err_entry_q <= 3'd0;
      first_err_code_q  <= 4'd0;
      ready_q           <= 1'b0;
    end else begin
      viol_active_q   <= viol_now;
      viol_sticky_q   <= viol_now | (viol_sticky_q & ~ctl_clr_violation_sticky);  // new evidence dominates clear
      entry_true_q    <= entry_true;
      guard_allowed_q <= guard_allowed_comb;
      inhibit_q       <= ~guard_allowed_comb;
      response_q      <= response_comb;
      fault_q         <= |viol_now;
      ready_q         <= 1'b1;

      if (commit_accept)                commit_complete_q <= 1'b1;
      else if (ctl_clr_commit_complete) commit_complete_q <= 1'b0;
      if (commit_reject)                commit_rejected_q <= 1'b1;
      else if (ctl_clr_commit_rejected) commit_rejected_q <= 1'b0;

      // First-error retention (REG-COH-003): capture only the earliest
      // rejection since COMMIT_REJECTED was last clear; a same-cycle clear
      // does not block a new capture.
      if (commit_reject && (!commit_rejected_q || ctl_clr_commit_rejected)) begin
        first_err_entry_q <= first_bad_entry;
        first_err_code_q  <= first_bad_code;
      end else if (ctl_clr_commit_rejected) begin
        first_err_entry_q <= 3'd0;
        first_err_code_q  <= 4'd0;
      end
    end
  end

  assign interlock_satisfied_o = entry_true_q;
  assign interlock_inhibit_o   = inhibit_q;
  assign response_req_o        = response_q;
  assign fault_req_o           = fault_q;

  // ==========================================================================
  // Events / IRQ (C.7 0x0042, F.3 index 13).
  // ==========================================================================
  wire [NE-1:0] viol_rise = viol_now & ~viol_active_q;
  wire [NE-1:0] viol_fall = ~viol_now & viol_active_q;

  wire [NE-1:0] c_viol = viol_rise & act_evt_en & event_condition_enable_i[7:0];
  wire [NE-1:0] c_rec  = viol_fall & act_evt_en & event_condition_enable_i[15:8];
  wire          c_acc  = commit_accept & ctl_event_enable & event_condition_enable_i[16];
  wire          c_rej  = commit_reject & ctl_event_enable & event_condition_enable_i[17];

  localparam logic [15:0] EVT_ID_INTERLOCK       = 16'h0042;
  localparam logic [7:0]  EVT_SUBTYPE_VIOLATION  = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERED  = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_ACCEPTED   = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_REJECTED   = 8'd3;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL014 = 8'd13;  // ARCH-002 C.5 index 13 (see item 74)

  wire [17:0] cand_vec = {c_rej, c_acc, c_viol, c_rec};
  wire [4:0]  n_cand   = $countones(cand_vec);
  wire        evt_candidate_valid = (cand_vec != 18'h0);

  // Lowest-index encoders (same documented casez shape as above).
  wire [7:0] ev_pick_vec = (c_viol != 8'h00) ? c_viol : c_rec;
  logic [2:0] ev_pick_entry;
  always_comb begin
    casez (ev_pick_vec)
      8'b???????1: ev_pick_entry = 3'd0;
      8'b??????10: ev_pick_entry = 3'd1;
      8'b?????100: ev_pick_entry = 3'd2;
      8'b????1000: ev_pick_entry = 3'd3;
      8'b???10000: ev_pick_entry = 3'd4;
      8'b??100000: ev_pick_entry = 3'd5;
      8'b?1000000: ev_pick_entry = 3'd6;
      8'b10000000: ev_pick_entry = 3'd7;
      default:     ev_pick_entry = 3'd0;
    endcase
  end

  logic [7:0]  evt_subtype_comb;
  logic [2:0]  evt_entry_comb;
  logic [15:0] evt_detail_comb;
  always_comb begin
    evt_subtype_comb = EVT_SUBTYPE_VIOLATION;
    evt_entry_comb   = 3'd0;
    evt_detail_comb  = 16'h0000;
    if (c_rej) begin
      evt_subtype_comb = EVT_SUBTYPE_REJECTED;
      evt_entry_comb   = first_bad_entry;
      evt_detail_comb  = {12'h000, first_bad_code};
    end else if (c_acc) begin
      evt_subtype_comb = EVT_SUBTYPE_ACCEPTED;
    end else if (c_viol != 8'h00) begin
      evt_subtype_comb = EVT_SUBTYPE_VIOLATION;
      evt_entry_comb   = ev_pick_entry;
    end else if (c_rec != 8'h00) begin
      evt_subtype_comb = EVT_SUBTYPE_RECOVERED;
      evt_entry_comb   = ev_pick_entry;
    end
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO]   = EVT_ID_INTERLOCK;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL014;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]      = evt_subtype_comb;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO + 8 +: 8]  = {5'h00, evt_entry_comb};
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO + 16 +: 16] = evt_detail_comb;
  end

  logic                                             evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic                                             event_overflow_q;
  logic [15:0]                                      event_drop_count_q;

  wire        slot_free  = !evt_pending_q || evt_ready_i;
  // Candidates that do not land this cycle: all of them when the slot is
  // blocked, every loser of the priority pick otherwise.
  wire [4:0]  drops_now  = !evt_candidate_valid ? 5'd0 : (slot_free ? (n_cand - 5'd1) : n_cand);
  wire        overflow_sets_this_cycle = (drops_now != 5'd0);
  wire [16:0] drop_sum   = {1'b0, event_drop_count_q} + {12'h000, drops_now};

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q      <= 1'b0;
      evt_record_q       <= '0;
      event_overflow_q   <= 1'b0;
      event_drop_count_q <= 16'd0;
    end else if (module_reset_i) begin
      evt_pending_q      <= 1'b0;
      evt_record_q       <= '0;
      event_overflow_q   <= 1'b0;
      event_drop_count_q <= 16'd0;
    end else begin
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;
      if (evt_candidate_valid && slot_free) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate;
      end
      if (overflow_sets_this_cycle) begin
        event_overflow_q   <= 1'b1;
        event_drop_count_q <= drop_sum[16] ? 16'hFFFF : drop_sum[15:0];
      end else if (ctl_clear_event_overflow) begin
        event_overflow_q <= 1'b0;           // REG-3224: new evidence dominates clear
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  assign irq_req_o =
      (|(viol_now  & act_irq_en & irq_condition_enable_i[7:0])) |
      (|(viol_fall & act_irq_en & irq_condition_enable_i[15:8])) |
      (ctl_irq_enable & ((commit_accept & irq_condition_enable_i[16]) |
                         (commit_reject & irq_condition_enable_i[17]) |
                         (overflow_sets_this_cycle & irq_condition_enable_i[18])));

  // ==========================================================================
  // Selected active-entry readback (registered) + status_o packing.
  // ==========================================================================
  logic [EW-1:0] rb_sel_comb;
  always_comb begin
    case (ctl_entry_select)
      3'd0: rb_sel_comb = active_q[0*EW +: EW];
      3'd1: rb_sel_comb = active_q[1*EW +: EW];
      3'd2: rb_sel_comb = active_q[2*EW +: EW];
      3'd3: rb_sel_comb = active_q[3*EW +: EW];
      3'd4: rb_sel_comb = active_q[4*EW +: EW];
      3'd5: rb_sel_comb = active_q[5*EW +: EW];
      3'd6: rb_sel_comb = active_q[6*EW +: EW];
      default: rb_sel_comb = active_q[7*EW +: EW];
    endcase
  end
  logic [EW-1:0] rb_sel_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       rb_sel_q <= '0;
    else if (module_reset_i) rb_sel_q <= '0;
    else                     rb_sel_q <= rb_sel_comb;
  end

  logic [dfc_types_pkg::DFC_RTL014_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__READY_HI]          = ready_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__FAULT_HI]          = 1'b0;   // item 73
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__VIOLATION_ACTIVE_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__VIOLATION_ACTIVE_LO] = viol_active_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__VIOLATION_STICKY_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__VIOLATION_STICKY_LO] = viol_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__COMMIT_COMPLETE_HI] = commit_complete_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__COMMIT_REJECTED_HI] = commit_rejected_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESULT__ENTRY_TRUE_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESULT__ENTRY_TRUE_LO]       = entry_true_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESULT__GUARD_ALLOWED_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESULT__GUARD_ALLOWED_LO] = guard_allowed_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL014_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM0_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM0_LO] = rb_sel_q[F_T0 +: 8];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM1_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM1_LO] = rb_sel_q[F_T1 +: 8];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM2_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM2_LO] = rb_sel_q[F_T2 +: 8];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM3_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_TERMS__TERM3_LO] = rb_sel_q[F_T3 +: 8];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_LOGIC__INVERT_MASK_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_LOGIC__INVERT_MASK_LO] = rb_sel_q[F_INV +: 4];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_LOGIC__OPERATOR_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_LOGIC__OPERATOR_LO]       = rb_sel_q[F_OP +: 3];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_GUARD__GUARD_MASK_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_GUARD__GUARD_MASK_LO]     = rb_sel_q[F_GRD +: 8];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_ENABLE__ENABLE_HI]          = rb_sel_q[F_EN];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_ENABLE__LATCH_VIOLATION_HI] = rb_sel_q[F_LAT];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_ENABLE__EVENT_ENABLE_HI]    = rb_sel_q[F_EVE];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_ENABLE__IRQ_ENABLE_HI]      = rb_sel_q[F_IRQE];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESPONSE__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESPONSE__SAFETY_RESPONSE_MASK_LO] = rb_sel_q[F_RSP +: 4];
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__FIRST_ERROR_ENTRY_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__FIRST_ERROR_ENTRY_LO] = first_err_entry_q;
    status_comb[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__FIRST_ERROR_CODE_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__FIRST_ERROR_CODE_LO]   = first_err_code_q;
  end
  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): see header ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i ^ (^ctl_selected_stage_view);

endmodule : dfc_rtl014
