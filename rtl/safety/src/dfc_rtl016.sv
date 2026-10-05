// ============================================================================
// dfc_rtl016.sv -- RTL-016 Safety Output Controller (ARCH-MOD-016)
//
// Controlling spec: docs/rtl_specs/RTL-016_RevB.md (derived; Rev A's port
// count, several SS10.4 equation terms, and the dfc_rtl016_control_t/
// status_t widths were all wrong against the real -002 documents --
// OPEN_ISSUES.md items 90-97). Owning contracts: ARCH-002 SS10.2
// ARCH-SAFE-001..004 (lane/source allocation), SS10.4 (the complete
// REQUESTED/LATCHED_REQUEST/COMMANDED/PERMIT/EFFECTIVE equation set),
// Appendix F.1 ARCH-RTL016-001, F.3 RTL-016 row and preamble, F.4
// ARCH-VAL-016; Appendix C.6 bit 3, C.7 event 0x0044, C.8 (32-position
// authorization matrix); REG-002 SS28 (0x3400-0x341C, 8 registers);
// VP-002 VP-MOD-016/VP-SAFE-009..011/014/VP-SAFE-003.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous safety-scope reset (RTL-002.module_reset_o[15],
// ARCH-RST-006 safety-domain reset also targets this bit).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl016_field_map.json, reggen.py v5).
//
// Port list: the 22 ports of ARCH-002 Appendix A "RTL-016 - Safety Output
// Controller (22 ports)". Flat logic vectors sized by generated
// dfc_types_pkg _WIDTH constants; fields sliced by generated _HI/_LO
// constants (PROJECT_CONTINUITY.md Section 2 pkg::type_t rule).
//
// ---------------------------------------------------------------------------
// STRUCTURE (see OPEN_ISSUES.md items 90-97 for every disclosed decision):
//
//  1. REAL PORT COUNT IS 22, NOT ~16 (item 90). RevA's own SS2 named only
//     response_req_i/fault_inhibit_i/safety_out_o as "RTL-016-specific" --
//     standard group (13) plus those three reaches 16, not 22. The real
//     Appendix A rows add six more this module genuinely owns: irq_req_o
//     (RTL-003.irq_source_i[17]), fault_req_o (RTL-013.fault_source_i[3]),
//     interlock_satisfied_i[7:0] (RTL-014.interlock_satisfied_o),
//     interlock_inhibit_i[7:0] (RTL-014.interlock_inhibit_o, idle 1),
//     effective_operational_enable_i (RTL-002), and test_inhibit_i
//     (RTL-024 physical-test-authorization-OR-test-active, CDC-TEST-001,
//     idle 1 during reset). Built against the real 22-port list directly.
//
//  2. GLOBAL_INHIBIT IS ITS OWN FIELD, NOT !ENABLE (item 91). RevA's SS3
//     equation `GLOBAL_INHIBIT = !safety_control__enable` is wrong.
//     REG-002's real SAFETY_CONTROL (0x3400) has bit 0 ENABLE (reset 0)
//     and bit 3 GLOBAL_INHIBIT (reset 1) as two INDEPENDENT RW fields --
//     SAFETY_CONTROL.GLOBAL_INHIBIT's own write-validation text says so
//     explicitly ("does not alter controller enable"), and
//     SAFETY_CHANNEL_STATUS independently confirms it with two separate
//     readback bits (CONTROLLER_DISABLED bit 10, GLOBAL_INHIBIT bit 11,
//     both reset 1). PERMIT[c] uses both as separate AND terms below.
//
//  3. FAULT_INHIBIT IS GENUINELY PER-CHANNEL (item 92). RevA's SS3 prose
//     called it "RTL-013-wide, not per-channel-specific." The real
//     Appendix A row for fault_inhibit_i says "per-channel active-high
//     inhibit," sourced from RTL-013.safety_inhibit_o (a real 4-bit
//     port). dfc_rtl013.sv's own driving assignment --
//     `safety_inhibit_o = {4{ctl_enable && (|nonrecoverable_active17)}}`
//     -- confirms all four bits happen to carry the same value in THIS
//     build (RTL-013 has no real per-channel fault classification yet),
//     but the port itself is 4 bits wide and this module indexes it per
//     channel (fault_inhibit_i[c]), not as a single module-wide gate, so
//     a future RTL-013 revision with real per-channel fault scoping needs
//     no RTL-016 change.
//
//  4. TEST_DEBUG IS A GENUINELY SEPARATE TERM, NOT ALREADY INSIDE
//     test_inhibit_i (item 93). ARCH-002 SS10.4 defines TEST_INHIBIT as
//     the OR of (a) physical production-test authorization, (b) qualified
//     test-active, AND (c) TEST_DEBUG. But test_inhibit_i's own Appendix A
//     producer description is only "RTL-024 physical test authorization OR
//     test-active" -- terms (a) and (b), NOT (c). TEST_DEBUG
//     (dfc_operating_state_t 3'b111) is a distinct primary operating state
//     this module already receives via operating_state_i, orthogonal to
//     the registered test_active_i qualifier RTL-002 broadcasts
//     separately. This module therefore ORs operating_state_i==TEST_DEBUG
//     into test_inhibit_i itself to form the single TEST_INHIBIT term
//     PERMIT[c] uses -- algebraically identical to RevA's own two separate
//     `!test_inhibit & !TEST_DEBUG` AND terms (De Morgan: `!A & !B` ==
//     `!(A|B)`), so RevA's PERMIT *value* was actually right here even
//     though its stated reasoning ("already included") was not; the real
//     canonical PERMIT[c] (ARCH-002 line 349) has exactly ONE TEST_INHIBIT
//     term, not two, and TEST_INHIBIT is also reported as the single OR'd
//     value in SAFETY_CHANNEL_STATUS.TEST_INHIBIT (bit 7).
//
//  5. PERMIT[c] IS A REAL NINE-TERM AND, NOT RevA's EIGHT (item 94). RevA
//     omitted RESET_HELD[c] and conflated CONTROLLER_DISABLED into
//     GLOBAL_INHIBIT (item 2 above). The real equation (ARCH-002 line 349):
//     PERMIT[c] = !CHANNEL_DISABLED[c] & !CONTROLLER_DISABLED &
//     !GLOBAL_INHIBIT & !OPERATIONAL_INHIBIT & !OBSERVATIONAL_INHIBIT &
//     !TEST_INHIBIT & !INTERLOCK_INHIBIT[c] & !FAULT_INHIBIT[c] &
//     !RESET_HELD[c]. RESET_HELD is computed once (shared across channels,
//     no per-channel reset mechanism exists) as
//     `!core_rst_n_i | module_reset_i | (operating_state_i==RESET_ACTIVE)`
//     -- covering external reset, safety-domain/system reset (RTL-002
//     dispatches both to module_reset_o[15] per ARCH-RST-006), and
//     reset-release qualification (RTL-002's own operating_state_i delay).
//     In practice every other PERMIT term already independently reads its
//     own "blocked" reset value while truly in reset (channel_enable=0,
//     safety_control.enable=0, etc. -- the DRI bus cannot be written while
//     held in reset), so RESET_HELD is implemented faithfully per the
//     literal nine-term equation rather than omitted as redundant
//     (CHTR-DOC-006: don't skip a specified term because it looks provably
//     redundant under today's wiring).
//
//  6. INTERLOCK_INHIBIT[c] USES THE GUARD-INDEXED PORT, NOT THE ENTRY-
//     INDEXED ONE (item 95, the most structurally subtle finding this
//     session). dfc_rtl014.sv's own header comment (its SS5 "GUARDS") is
//     unambiguous: `interlock_inhibit_o = ~GUARD_ALLOWED` is indexed PER
//     GUARD (an 8-position space RTL-014's own per-entry 8-bit
//     guard_mask fields select into), while `interlock_satisfied_o[e] =
//     ENTRY_TRUE[e]` is indexed PER ENTRY (RTL-014's own 8 interlock
//     expressions) -- "the two ports would be redundant complements if
//     both were per guard" (RTL-014's own words). These are NOT the same
//     8-bit space. REG-002's real SAFETY_INTERLOCK_MASK
//     (0x3414).REQUIRED_INTERLOCKS is "Required interlock-permission mask
//     for SELECTED CHANNEL" -- a per-channel subset of the GUARD space,
//     confirming INTERLOCK_INHIBIT[c] = OR over g in
//     ctl_c_required_interlocks[c] of interlock_inhibit_i[g].
//     interlock_satisfied_i (entry-indexed) is consequently a real
//     Appendix A port this module receives with NO functional use in the
//     PERMIT equation and NO REG-002 status field anywhere to expose it
//     (SAFETY_CHANNEL_STATUS has no "satisfied" bit, only
//     INTERLOCK_INHIBIT) -- a disclosed, genuinely-unused real input,
//     consumed only by the unused-port sink, not a bug.
//
//  7. THE TWO-LAYER RESPONSE-AUTHORIZATION MODEL (item 96, resolved from
//     first principles -- neither RevA nor ARCH-002 SS10.4's prose spells
//     this out in full, though C.8 and REG-ENC-015 together fix it
//     exactly). Each lane's dfc_safety_response_req_t carries THREE
//     fields: valid, source_id (0-7, which of that lane's own sources is
//     currently winning), and response_mask (4 bits -- the PRODUCER's own
//     already-configured "which of RTL-016's 4 output channels do I want"
//     selection, e.g. RTL-014's own per-entry SAFETY_RESPONSE_MASK field).
//     SEPARATELY, THIS module's own SAFETY_RESPONSE_MASK register
//     (0x3410, selected-channel-indexed, 32 bits, legal bits only
//     C.8's 0/8/16-23/24-31) is channel c's AUTHORIZATION over the full
//     32-position (lane,source) space (`mask_bit = 8*lane + source_id`,
//     ARCH-002 SS10.2). AUTHORIZED_REQ[c] therefore requires BOTH: the
//     producer's own response_mask bit c set, AND this module's own
//     channel-c authorization bit (8*lane+source_id) set -- a genuine
//     two-key design (the source decides what it wants; this module's
//     own host-configured authorization independently decides whether
//     it is allowed), matching SS10.4's literal "whose response mask
//     contains c AND whose fixed authorization bit is set" wording.
//
//  8. LATCHED_REQUEST[c] CLEAR SEMANTICS (item 97, ARCH-002 SS10.4
//     literal text, more specific than and not identical to RTL-014/015's
//     own "disable releases" precedent -- items 68/89). The clear is
//     qualified "after every contributing request is inactive" for the
//     level-held causes (channel disable): while disabled AND
//     REQUESTED[c] is still live, the latch HOLDS (new evidence dominates
//     a level-held clear attempt, the same project-wide sticky
//     precedent) and only actually clears the cycle REQUESTED[c] drops.
//     "Re-enabling a channel begins with its latch clear" is a SEPARATE,
//     unconditional edge-triggered override applied exactly on the
//     disabled-to-enabled transition, regardless of any request still
//     live that cycle (a deliberate host action, and PERMIT[c] still
//     gates the actual output independently). core_rst_n_i/module_reset_i
//     clear the latch unconditionally via the ordinary reset branch, the
//     same as every other sticky/latch register in this project
//     (RTLSTD-RST-005/008) -- satisfying "safety-domain reset, system
//     reset, external reset" without needing a request-inactive
//     qualifier on the reset path itself.
//
//  9. SAFETY_STATUS.FAULTED[c] / fault_req_o (C.6 bit 3, item 4 precedent,
//     a cross-field validation RTL-001's own single-register write
//     checker cannot see). ARCH-VAL-016 requires "no nonzero response
//     mask for a disabled channel," but REG-002 gives SAFETY_CHANNEL_
//     CONTROL.ENABLE and SAFETY_RESPONSE_MASK as two independent,
//     immediately-effective registers with no COMMIT/staged step between
//     them -- disabling a channel must never be refusable for safety
//     reasons, so the live condition `!ctl_c_enable[c] &&
//     (ctl_c_response_mask[c] != 0)` is DETECTED, not write-rejected: it
//     drives SAFETY_STATUS.FAULTED[c] (live, RO) and the module's own
//     fault_req_o/status_o.fault, exactly the "defend against what RTL-001
//     doesn't yet reject" pattern every prior monitoring module uses. It
//     never affects PERMIT[c] beyond what CHANNEL_DISABLED[c] already
//     forces (a disabled channel's output is already inactive regardless
//     of its stale mask) -- this is a host-visibility defense, not an
//     additional safety interlock. fault_req_o/status_o.fault are NOT
//     gated by SAFETY_CONTROL.ENABLE (unlike RTL-015's own fault_req_o):
//     a self-contradictory channel configuration is worth reporting
//     whether or not the controller is currently enabled.
//
// 10. EVENTS/IRQ (C.7 0x0044, F.3 RTL-016 row: 0-3 request, 4-7
//     activation, 8-11 inhibited, 12-15 deactivated, 16-19 configuration
//     rejected, 20 overflow). SAFETY_CHANNEL_CONTROL has NO per-channel
//     EVENT_ENABLE/IRQ_ENABLE field (confirmed against REG-002's real
//     field table -- only ENABLE/ACTIVE_HIGH/LATCH_RESPONSE), so unlike
//     RTL-014/015 every per-channel condition is gated solely by the
//     MODULE-WIDE SAFETY_CONTROL.EVENT_ENABLE/IRQ_ENABLE (F.3 preamble:
//     "module/channel ... master gates" -- "channel" only applies where
//     such a field exists). Each of the five conditions is an edge
//     (comparing this cycle's live combinational value against last
//     cycle's own registered status bit, avoiding a second bank of
//     previous-value registers). Event arbitration priority (one shared
//     pending slot, same shape as every prior module):
//     config-rejected > inhibited > request > activation > deactivation,
//     lowest-channel-index first within a class (RTL-013/014 "most
//     safety-relevant first" precedent). event_data: [7:0] subtype,
//     [15:8] channel, [31:16] "requested/effective/inhibit summary" per
//     C.7's own row text -- packed here as the reporting channel's own
//     four live RO bits (commanded/effective/inhibited/faulted).
//     SAFETY_STATUS.EVENT[3:0] (W1C) is an independent per-channel sticky
//     "some condition fired" flag, set by any of the five conditions,
//     new evidence dominating a simultaneous host clear -- the same
//     "RO condition + W1C sticky in one aggregate register" shape every
//     prior safety-domain STATUS register uses.
//
// 11. SAFE OUTPUT REGISTRATION (RTLSTD-SAFE "same-edge guard rule"
//     precedent, RTL-014 item). effective_q[c] (used both for
//     EFFECTIVE_OUTPUT/SAFETY_STATUS.EFFECTIVE readback and as the
//     polarity source) and safety_out_q[c] (the polarized pad-facing
//     value) are registered from the SAME combinational COMMANDED[c]/
//     PERMIT[c] evaluation on the SAME edge -- no pipeline stage sits
//     between what the status registers report and what the real pad
//     drives. Reset forces safety_out_q to 4'b0000 directly (Appendix A
//     "reset inactive low"), not derived from the reset values of
//     ACTIVE_HIGH/EFFECTIVE separately, though those two reset values
//     (1 and 0) already algebraically produce the same inactive-low
//     result.
//
// operating_state_i is used for both TEST_DEBUG (item 4) and RESET_ACTIVE
// (item 5). observational_mode_i feeds OBSERVATIONAL_INHIBIT directly
// (SS10.4: `OBSERVATIONAL_INHIBIT = observational_mode`).
// ============================================================================

module dfc_rtl016 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[15]

  input  logic [dfc_types_pkg::DFC_RTL016_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL016_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,          // RTL-003.irq_source_i[17]
  output logic         fault_req_o,        // RTL-013.fault_source_i[3]

  input  logic [31:0]  response_req_i,     // 4 lanes x dfc_safety_response_req_t(8b):
                                            // [0]=RTL-012 [1]=RTL-013 [2]=RTL-014 [3]=RTL-015
  input  logic [7:0]   interlock_satisfied_i,  // RTL-014.interlock_satisfied_o (entry-indexed;
                                                // genuinely unused, item 95 -- unused-port sink
  input  logic [7:0]   interlock_inhibit_i,    // RTL-014.interlock_inhibit_o (guard-indexed)
  output logic [3:0]   safety_out_o,           // sole external safety-output ports

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  input  logic         effective_operational_enable_i,
  input  logic [3:0]   fault_inhibit_i,        // RTL-013.safety_inhibit_o, per-channel
  input  logic         test_inhibit_i,         // RTL-024 test authorization OR test-active

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 15
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 15
);

  localparam int unsigned NC = 4;

  // ---- control_i field extraction: module-wide fields ----
  wire       ctl_enable         = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CONTROL__ENABLE_HI];
  wire       ctl_event_enable   = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CONTROL__EVENT_ENABLE_HI];
  wire       ctl_irq_enable     = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CONTROL__IRQ_ENABLE_HI];
  wire       ctl_global_inhibit = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CONTROL__GLOBAL_INHIBIT_HI];
  wire [3:0] ctl_clr_status_event = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_STATUS__EVENT_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_STATUS__EVENT_LO];
  wire [1:0] ctl_channel_select   = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_SELECT__CHANNEL_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_SELECT__CHANNEL_LO];
  wire       ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__RTL016_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  // Selected-channel view fields (pre-existing struct members, see header
  // item 1/90) -- forwarded but functionally unused by this module (item 73
  // precedent): the complete per-channel array below is used instead.
  wire [42:0] ctl_selected_view = {
    control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_INTERLOCK_MASK__REQUIRED_INTERLOCKS_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_CONTROL__ENABLE_LO]};

  // ---- per-channel config bank (reggen.py v5 indexed_registers forwarding) ----
  logic [3:0]  ctl_c_enable;
  logic [3:0]  ctl_c_active_high;
  logic [3:0]  ctl_c_latch_response;
  logic [31:0] ctl_c_response_mask      [0:3];
  logic [7:0]  ctl_c_required_interlocks [0:3];

  always_comb begin
    ctl_c_enable[0]              = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__ENABLE_HI];
    ctl_c_active_high[0]         = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__ACTIVE_HIGH_HI];
    ctl_c_latch_response[0]      = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__LATCH_RESPONSE_HI];
    ctl_c_response_mask[0]       = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__RESPONSE_SOURCE_MASK_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__RESPONSE_SOURCE_MASK_LO];
    ctl_c_required_interlocks[0] = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__REQUIRED_INTERLOCKS_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C0__REQUIRED_INTERLOCKS_LO];

    ctl_c_enable[1]              = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__ENABLE_HI];
    ctl_c_active_high[1]         = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__ACTIVE_HIGH_HI];
    ctl_c_latch_response[1]      = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__LATCH_RESPONSE_HI];
    ctl_c_response_mask[1]       = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__RESPONSE_SOURCE_MASK_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__RESPONSE_SOURCE_MASK_LO];
    ctl_c_required_interlocks[1] = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__REQUIRED_INTERLOCKS_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C1__REQUIRED_INTERLOCKS_LO];

    ctl_c_enable[2]              = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__ENABLE_HI];
    ctl_c_active_high[2]         = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__ACTIVE_HIGH_HI];
    ctl_c_latch_response[2]      = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__LATCH_RESPONSE_HI];
    ctl_c_response_mask[2]       = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__RESPONSE_SOURCE_MASK_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__RESPONSE_SOURCE_MASK_LO];
    ctl_c_required_interlocks[2] = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__REQUIRED_INTERLOCKS_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C2__REQUIRED_INTERLOCKS_LO];

    ctl_c_enable[3]              = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__ENABLE_HI];
    ctl_c_active_high[3]         = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__ACTIVE_HIGH_HI];
    ctl_c_latch_response[3]      = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__LATCH_RESPONSE_HI];
    ctl_c_response_mask[3]       = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__RESPONSE_SOURCE_MASK_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__RESPONSE_SOURCE_MASK_LO];
    ctl_c_required_interlocks[3] = control_i[dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__REQUIRED_INTERLOCKS_HI:dfc_types_pkg::DFC_RTL016_CONTROL__SAFETY_CHANNEL_C3__REQUIRED_INTERLOCKS_LO];
  end

  // ==========================================================================
  // Lane request extraction (header item 7). Lane L occupies
  // response_req_i[8*L +: 8]; field order within each lane matches
  // dfc_safety_response_req_t (VALID bit7, SOURCE_ID bits6:4, RESPONSE_MASK
  // bits3:0). Lane order fixed by ARCH-SAFE-001..004 / this module's own
  // Appendix A row: 0=RTL-012 1=RTL-013 2=RTL-014 3=RTL-015.
  // ==========================================================================
  logic [3:0] lane_valid;
  logic [2:0] lane_source [0:3];
  logic [3:0] lane_mask   [0:3];
  always_comb begin
    for (int l = 0; l < 4; l++) begin
      lane_valid[l]  = response_req_i[8*l + dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI];
      lane_source[l] = response_req_i[8*l + dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_HI -: 3];
      lane_mask[l]   = response_req_i[8*l + dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_HI -: 4];
    end
  end

  // ==========================================================================
  // AUTHORIZED_REQ[c] / REQUESTED[c] (header item 7): two-key authorization
  // -- the producer's own response_mask bit c AND this module's own
  // per-channel 32-bit authorization mask bit (8*lane+source_id).
  // ==========================================================================
  logic [3:0] authorized_req;
  always_comb begin
    for (int c = 0; c < NC; c++) begin
      authorized_req[c] = 1'b0;
      for (int l = 0; l < 4; l++) begin
        if (lane_valid[l] && lane_mask[l][c] &&
            ctl_c_response_mask[c][8*l + lane_source[l]]) begin
          authorized_req[c] = 1'b1;
        end
      end
    end
  end

  // ==========================================================================
  // LATCHED_REQUEST[c] (header item 8).
  // ==========================================================================
  logic [3:0] latched_request_q;
  logic [3:0] channel_enable_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      latched_request_q     <= 4'b0000;
      channel_enable_prev_q <= 4'b0000;
    end else if (module_reset_i) begin
      latched_request_q     <= 4'b0000;
      channel_enable_prev_q <= 4'b0000;
    end else begin
      channel_enable_prev_q <= ctl_c_enable;
      for (int c = 0; c < NC; c++) begin
        if (!ctl_c_latch_response[c]) begin
          latched_request_q[c] <= 1'b0;
        end else if (ctl_c_enable[c] && !channel_enable_prev_q[c]) begin
          latched_request_q[c] <= 1'b0;  // re-enabling begins with latch clear
        end else if (authorized_req[c]) begin
          latched_request_q[c] <= 1'b1;  // new evidence sets/holds
        end else if (!ctl_c_enable[c] && !authorized_req[c]) begin
          latched_request_q[c] <= 1'b0;  // disabled AND request now inactive
        end
        // else: hold current value
      end
    end
  end

  wire [3:0] commanded_comb = authorized_req | latched_request_q;

  // ==========================================================================
  // Inhibit causes (header items 2-6) and PERMIT[c] (header item 5).
  // ==========================================================================
  wire test_inhibit_combined = test_inhibit_i || (operating_state_i == dfc_types_pkg::TEST_DEBUG);
  wire reset_held = !core_rst_n_i || module_reset_i || (operating_state_i == dfc_types_pkg::RESET_ACTIVE);

  logic [3:0] interlock_inhibit_per_channel;
  always_comb begin
    for (int c = 0; c < NC; c++) begin
      interlock_inhibit_per_channel[c] = |(interlock_inhibit_i & ctl_c_required_interlocks[c]);
    end
  end

  logic [3:0] permit_comb;
  always_comb begin
    for (int c = 0; c < NC; c++) begin
      permit_comb[c] = ctl_c_enable[c]                       // !CHANNEL_DISABLED[c]
                      && ctl_enable                            // !CONTROLLER_DISABLED
                      && !ctl_global_inhibit                   // !GLOBAL_INHIBIT
                      && effective_operational_enable_i        // !OPERATIONAL_INHIBIT
                      && !observational_mode_i                 // !OBSERVATIONAL_INHIBIT
                      && !test_inhibit_combined                // !TEST_INHIBIT
                      && !interlock_inhibit_per_channel[c]     // !INTERLOCK_INHIBIT[c]
                      && !fault_inhibit_i[c]                   // !FAULT_INHIBIT[c]
                      && !reset_held;                          // !RESET_HELD[c]
    end
  end

  wire [3:0] effective_comb = commanded_comb & permit_comb;

  // ==========================================================================
  // Disabled-channel-with-stale-mask live configuration fault (header item 9).
  // ==========================================================================
  logic [3:0] faulted_comb;
  always_comb begin
    for (int c = 0; c < NC; c++) begin
      faulted_comb[c] = !ctl_c_enable[c] && (ctl_c_response_mask[c] != 32'h0);
    end
  end
  wire local_fault = |faulted_comb;
  assign fault_req_o = local_fault;

  logic [3:0] inhibited_comb;
  always_comb begin
    for (int c = 0; c < NC; c++) inhibited_comb[c] = commanded_comb[c] && !permit_comb[c];
  end

  // ==========================================================================
  // Registered status/output bank (header item 11, same-edge guard rule).
  // ==========================================================================
  logic [3:0] commanded_q, effective_q, inhibited_q, faulted_q;
  logic [3:0] safety_out_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      commanded_q  <= 4'b0000;
      effective_q  <= 4'b0000;
      inhibited_q  <= 4'b0000;
      faulted_q    <= 4'b0000;
      safety_out_q <= 4'b0000;
    end else if (module_reset_i) begin
      commanded_q  <= 4'b0000;
      effective_q  <= 4'b0000;
      inhibited_q  <= 4'b0000;
      faulted_q    <= 4'b0000;
      safety_out_q <= 4'b0000;
    end else begin
      commanded_q <= commanded_comb;
      effective_q <= effective_comb;
      inhibited_q <= inhibited_comb;
      faulted_q   <= faulted_comb;
      for (int c = 0; c < NC; c++) begin
        safety_out_q[c] <= ctl_c_active_high[c] ? effective_comb[c] : !effective_comb[c];
      end
    end
  end
  assign safety_out_o = safety_out_q;

  // ==========================================================================
  // Events / IRQ (C.7 0x0044, F.3 index 15, header item 10). Edge-detected
  // against last cycle's own registered status bits.
  // ==========================================================================
  wire [3:0] cond_request      = commanded_comb & ~commanded_q;
  wire [3:0] cond_activation   = effective_comb & ~effective_q;
  wire [3:0] cond_inhibited    = inhibited_comb & ~inhibited_q;
  wire [3:0] cond_deactivation = ~effective_comb & effective_q;
  wire [3:0] cond_config_rej   = faulted_comb & ~faulted_q;

  wire [3:0] ev_request      = cond_request      & {4{ctl_event_enable}} & event_condition_enable_i[3:0];
  wire [3:0] ev_activation    = cond_activation   & {4{ctl_event_enable}} & event_condition_enable_i[7:4];
  wire [3:0] ev_inhibited     = cond_inhibited    & {4{ctl_event_enable}} & event_condition_enable_i[11:8];
  wire [3:0] ev_deactivation  = cond_deactivation & {4{ctl_event_enable}} & event_condition_enable_i[15:12];
  wire [3:0] ev_config_rej    = cond_config_rej   & {4{ctl_event_enable}} & event_condition_enable_i[19:16];

  wire [3:0] iq_request      = cond_request      & {4{ctl_irq_enable}} & irq_condition_enable_i[3:0];
  wire [3:0] iq_activation    = cond_activation   & {4{ctl_irq_enable}} & irq_condition_enable_i[7:4];
  wire [3:0] iq_inhibited     = cond_inhibited    & {4{ctl_irq_enable}} & irq_condition_enable_i[11:8];
  wire [3:0] iq_deactivation  = cond_deactivation & {4{ctl_irq_enable}} & irq_condition_enable_i[15:12];
  wire [3:0] iq_config_rej    = cond_config_rej   & {4{ctl_irq_enable}} & irq_condition_enable_i[19:16];

  assign irq_req_o = (|iq_request) | (|iq_activation) | (|iq_inhibited) |
                      (|iq_deactivation) | (|iq_config_rej);

  // Per-channel sticky "some event fired" flag (SAFETY_STATUS.EVENT),
  // independent of the single-slot event FIFO below -- new evidence
  // dominates a simultaneous host W1C clear.
  logic [3:0] event_sticky_q;
  wire  [3:0] any_event_this_cycle = cond_request | cond_activation | cond_inhibited |
                                      cond_deactivation | cond_config_rej;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      event_sticky_q <= 4'b0000;
    end else if (module_reset_i) begin
      event_sticky_q <= 4'b0000;
    end else begin
      for (int c = 0; c < NC; c++) begin
        if (any_event_this_cycle[c])      event_sticky_q[c] <= 1'b1;
        else if (ctl_clr_status_event[c]) event_sticky_q[c] <= 1'b0;
      end
    end
  end

  localparam logic [15:0] EVT_ID_SAFETY_OUTPUT      = 16'h0044;
  localparam logic [7:0]  EVT_SUBTYPE_REQUEST        = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_ACTIVATION     = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_INHIBITED      = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_DEACTIVATION   = 8'd3;
  localparam logic [7:0]  EVT_SUBTYPE_CONFIG_REJ     = 8'd4;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL016    = 8'd15;  // ARCH-002 C.5 index 15

  logic [1:0] cfgrej_idx, inh_idx, req_idx, act_idx, deact_idx;
  always_comb begin
    casez (ev_config_rej)
      4'b???1: cfgrej_idx = 2'd0; 4'b??10: cfgrej_idx = 2'd1;
      4'b?100: cfgrej_idx = 2'd2; 4'b1000: cfgrej_idx = 2'd3; default: cfgrej_idx = 2'd0;
    endcase
    casez (ev_inhibited)
      4'b???1: inh_idx = 2'd0; 4'b??10: inh_idx = 2'd1;
      4'b?100: inh_idx = 2'd2; 4'b1000: inh_idx = 2'd3; default: inh_idx = 2'd0;
    endcase
    casez (ev_request)
      4'b???1: req_idx = 2'd0; 4'b??10: req_idx = 2'd1;
      4'b?100: req_idx = 2'd2; 4'b1000: req_idx = 2'd3; default: req_idx = 2'd0;
    endcase
    casez (ev_activation)
      4'b???1: act_idx = 2'd0; 4'b??10: act_idx = 2'd1;
      4'b?100: act_idx = 2'd2; 4'b1000: act_idx = 2'd3; default: act_idx = 2'd0;
    endcase
    casez (ev_deactivation)
      4'b???1: deact_idx = 2'd0; 4'b??10: deact_idx = 2'd1;
      4'b?100: deact_idx = 2'd2; 4'b1000: deact_idx = 2'd3; default: deact_idx = 2'd0;
    endcase
  end

  wire [2:0] n_cfgrej = $countones(ev_config_rej);
  wire [2:0] n_inh    = $countones(ev_inhibited);
  wire [2:0] n_req    = $countones(ev_request);
  wire [2:0] n_act     = $countones(ev_activation);
  wire [2:0] n_deact   = $countones(ev_deactivation);
  wire [4:0] n_total  = n_cfgrej + n_inh + n_req + n_act + n_deact;

  // Priority when multiple classes qualify the same cycle: config-rejected
  // (most safety-relevant) > inhibited > request > activation >
  // deactivation (RTL-013/014/015 "most safety-relevant first" precedent).
  logic [7:0] evt_subtype_comb;
  logic [1:0] evt_channel_comb;
  logic       evt_candidate_valid;
  always_comb begin
    evt_subtype_comb    = EVT_SUBTYPE_REQUEST;
    evt_channel_comb    = 2'd0;
    evt_candidate_valid = (n_total != 5'd0);
    if (ev_config_rej != 4'h0) begin
      evt_subtype_comb = EVT_SUBTYPE_CONFIG_REJ;
      evt_channel_comb = cfgrej_idx;
    end else if (ev_inhibited != 4'h0) begin
      evt_subtype_comb = EVT_SUBTYPE_INHIBITED;
      evt_channel_comb = inh_idx;
    end else if (ev_request != 4'h0) begin
      evt_subtype_comb = EVT_SUBTYPE_REQUEST;
      evt_channel_comb = req_idx;
    end else if (ev_activation != 4'h0) begin
      evt_subtype_comb = EVT_SUBTYPE_ACTIVATION;
      evt_channel_comb = act_idx;
    end else if (ev_deactivation != 4'h0) begin
      evt_subtype_comb = EVT_SUBTYPE_DEACTIVATION;
      evt_channel_comb = deact_idx;
    end
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO]   = EVT_ID_SAFETY_OUTPUT;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL016;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]     = evt_subtype_comb;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO + 8 +: 8] = {6'h00, evt_channel_comb};
    // event_data[31:16]: "requested/effective/inhibit summary" (C.7) --
    // the reporting channel's own four live RO status bits.
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO + 16 +: 16] =
      {12'h000, commanded_comb[evt_channel_comb], effective_comb[evt_channel_comb],
       inhibited_comb[evt_channel_comb], faulted_comb[evt_channel_comb]};
  end

  logic                                              evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  evt_record_q;
  logic                                              event_overflow_q;
  logic [15:0]                                       event_drop_count_q;

  wire        slot_free = !evt_pending_q || evt_ready_i;
  wire [4:0]  drops_now = !evt_candidate_valid ? 5'd0 : (slot_free ? (n_total - 5'd1) : n_total);
  wire        overflow_sets_this_cycle = (drops_now != 5'd0);
  wire [16:0] drop_sum = {1'b0, event_drop_count_q} + {12'h000, drops_now};

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
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // SAFETY_CHANNEL_STATUS selected-channel detailed view (registered mux,
  // same "selected-entry readback" pattern as RTL-014's ACTIVE_RESULT /
  // RTL-015's LLINK_ELAPSED_US, item 67 precedent).
  // ==========================================================================
  logic [12:0] channel_status_sel_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      channel_status_sel_q <= 13'b1110011001100;
    end else if (module_reset_i) begin
      channel_status_sel_q <= 13'b1110011001100;
    end else begin
      channel_status_sel_q[0]  <= authorized_req[ctl_channel_select];            // COMMAND_REQUEST
      channel_status_sel_q[1]  <= effective_comb[ctl_channel_select];            // EFFECTIVE_OUTPUT
      channel_status_sel_q[2]  <= !ctl_c_enable[ctl_channel_select];             // DISABLED
      channel_status_sel_q[3]  <= observational_mode_i;                         // OBSERVATIONAL_INHIBIT
      channel_status_sel_q[4]  <= interlock_inhibit_per_channel[ctl_channel_select]; // INTERLOCK_INHIBIT
      channel_status_sel_q[5]  <= fault_inhibit_i[ctl_channel_select];           // FAULT_INHIBIT
      channel_status_sel_q[6]  <= reset_held;                                   // RESET_ACTIVE
      channel_status_sel_q[7]  <= test_inhibit_combined;                        // TEST_INHIBIT
      channel_status_sel_q[8]  <= latched_request_q[ctl_channel_select];        // LATCHED_REQUEST
      channel_status_sel_q[9]  <= commanded_comb[ctl_channel_select];           // COMMANDED
      channel_status_sel_q[10] <= !ctl_enable;                                  // CONTROLLER_DISABLED
      channel_status_sel_q[11] <= ctl_global_inhibit;                           // GLOBAL_INHIBIT
      channel_status_sel_q[12] <= !effective_operational_enable_i;              // OPERATIONAL_INHIBIT
    end
  end

  logic ready_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       ready_q <= 1'b0;
    else if (module_reset_i) ready_q <= 1'b0;
    else                     ready_q <= 1'b1;
  end

  // ==========================================================================
  // status_o packing (dfc_rtl016_status_t, 52 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL016_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__READY_HI]          = ready_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__FAULT_HI]          = local_fault;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__COMMANDED_HI:dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__COMMANDED_LO] = commanded_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__EFFECTIVE_HI:dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__EFFECTIVE_LO] = effective_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__INHIBITED_HI:dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__INHIBITED_LO] = inhibited_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__FAULTED_HI:dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__FAULTED_LO]     = faulted_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__EVENT_HI:dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_STATUS__EVENT_LO]         = event_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__COMMAND_REQUEST_HI]         = channel_status_sel_q[0];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__EFFECTIVE_OUTPUT_HI]        = channel_status_sel_q[1];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__DISABLED_HI]                = channel_status_sel_q[2];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__OBSERVATIONAL_INHIBIT_HI]   = channel_status_sel_q[3];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__INTERLOCK_INHIBIT_HI]       = channel_status_sel_q[4];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__FAULT_INHIBIT_HI]           = channel_status_sel_q[5];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__RESET_ACTIVE_HI]            = channel_status_sel_q[6];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__TEST_INHIBIT_HI]            = channel_status_sel_q[7];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__LATCHED_REQUEST_HI]         = channel_status_sel_q[8];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__COMMANDED_HI]               = channel_status_sel_q[9];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__CONTROLLER_DISABLED_HI]     = channel_status_sel_q[10];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__GLOBAL_INHIBIT_HI]          = channel_status_sel_q[11];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__SAFETY_CHANNEL_STATUS__OPERATIONAL_INHIBIT_HI]     = channel_status_sel_q[12];
    status_comb[dfc_types_pkg::DFC_RTL016_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL016_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end
  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): see header items 1/6 ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^ctl_selected_view) ^ (^interlock_satisfied_i);

endmodule : dfc_rtl016
