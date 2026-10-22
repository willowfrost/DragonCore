// ============================================================================
// dfc_rtl023.sv -- RTL-023 User-Configurable Routing Logic (ARCH-RTL023-001)
//
// THE LAST OF ALL 24 MODULES. Controlling spec: docs/rtl_specs/RTL-023_RevA.md
// (derived; its own SS2 claims "19 ports" -- CONFIRMED CORRECT this time by
// direct Appendix A row count (19), breaking the run of six consecutive
// stale port-count findings (RTL-017 through RTL-022). RevA's own prose AND
// REG-002's own Section 30 block header BOTH say "11 registers" -- a new
// variant of the usual discrepancy: unlike RTL-018's case (module spec
// stale, REG-002 header correct), here BOTH stated counts agree with each
// other and are BOTH wrong against the real table, confirmed by direct row
// count (12: UROUTE_CONTROL through UROUTE_ACTIVE_CONTROL). Implemented
// against the real 19-port/12-register set. Owning contracts: ARCH-002 SS13.2
// (ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023, the fixed authorization/
// exclusivity/wired-OR/mode/disable/command-priority contract), Appendix A
// (19-port catalog), Appendix B (dfc_rtl023_control_t 35 bits / dfc_rtl023_
// status_t 79 bits), Appendix C.1/C.2 (fixed source/destination catalog),
// Appendix C.4/C.5/C.6 (irq slot 19/evt slot 22/fault slot 16), Appendix F.3
// (condition-mask allocation, cleanly consistent with C.7's own 0x0051 cause
// list this time -- no F.3-vs-C.7 mismatch to resolve, unlike RTL-022's own
// session); REG-002 Section 30 (0x4100-0x412C, 12 registers); VP-002
// VP-USER-005 through VP-USER-010.
//
// MASTER SHARED-RESOURCE-INDEX TABLE CHECKED BEFORE WIRING (OPEN_ISSUES.md
// item 140, mandatory per this session's own task briefing): irq_source_i[19],
// fault_source_i[16], evt_valid_i/evt_record_i[22] all cross-checked against
// the master table (item 140's own text: "19=RTL-023(not real yet)" on the
// irq vector, "13-16=RTL-020..023" i.e. 16=RTL-023 on the fault vector,
// "19-22=RTL-020..023" i.e. 22=RTL-023 on the evt vector) -- all three match
// ARCH-002's own claimed indices exactly, the SECOND consecutive clean
// result (RTL-022's own session was the first; RTL-017 through RTL-021 each
// found one real conflict). No activity_o port exists anywhere in RTL-023's
// own real 19-port Appendix A catalog -- confirmed directly, not assumed --
// so no activity_i master-table entry applies here at all.
//
// ARCH-002-INTERNAL GAPS FIXED THIS SESSION (same gap CLASS already fixed
// for RTL-002 through RTL-022, the 15th/16th real instances): (a)
// dfc_rtl023_control_t had no clear-forwarding field for RTL023_EVT_OVERFLOW_
// STATUS.EVENT_OVERFLOW (REG-4128 bit 0, a real W1C field) -- fixed: ARCH-002
// grew the struct 34->35 bits, appending rtl023_evt_overflow_status__
// event_overflow at the new highest bit (34), appended at the end exactly as
// every prior analogous fix (items 148/161) was appended, not inserted in
// REG-002 address order. (b) dfc_rtl023_status_t had NO field anywhere for
// UROUTE_ACTIVE_CONTROL's own real REG-002-specified readback (REG-412C,
// "Reads the committed value for the selected entry" -- ENABLE/INVERT/MODE)
// -- fixed: ARCH-002 grew the struct 75->79 bits, appending uroute_active_
// control__enable/__invert/__mode (4 bits) at the new highest bits (75-78).
// Both fixes regenerated via extract_types.py/pkggen.py with an isolated,
// confirmed diff; reggen.py then produced "real cross-module forwarding
// wired for RTL-023: 9 control regs, 6 status regs" with no assertion
// failures.
//
// ---------------------------------------------------------------------------
// THE FIXED AUTHORIZATION MATRIX (SS13.2, implemented literally, three
// distinct overlapping-but-not-identical rules, NOT collapsed into one range
// check):
//   - Source 1-31 -> dest 1-8: authorized.
//   - Source 1-31 -> dest 21-24: authorized.
//   - Source 1-16 ONLY (narrower) -> dest 13-20: authorized; 17-31 rejected
//     for this destination range specifically even though legal for the
//     other two.
//   - Dest 9-12: rejected for EVERY source, unconditionally (RTL-022's own
//     now-confirmed-inert contract -- RTL-022 has nothing live to route to,
//     verified directly against RTL-022's own real dfc_rtl022.sv rather than
//     treated as an independent rule to invent). This is the ONE
//     destination-only, source-independent rejection reason, hence its own
//     dedicated FORBIDDEN_DEST sticky bit -- every other rejection reason
//     below is the generic COMMIT_REJECTED.
//   - Source 0: legal to stage, illegal to enable (REG-002's own "0-31 or
//     37" raw legal-value range already permits writing it; ARCH-002's own
//     text is the ENABLE-time restriction).
//   - Source 37 (constant-one): authorized ONLY for level-mode (MODE=0)
//     destinations 21-24 -- restricted in BOTH destination range and mode,
//     since an edge mode on a signal that structurally never transitions is
//     meaningless.
//   - Destination 0 ("no action"): by the same disabled-only symmetry as
//     source 0 (REG-002's own raw legal range for DEST_ID is "0-24",
//     covering 0; ARCH-002's own matrix text names no authorized pair for
//     dest 0 at all) -- a disclosed interpretation choice, not explicitly
//     spelled out either way in the prose: legal to stage, illegal to
//     enable, enforced here as a generic COMMIT_REJECTED (not FORBIDDEN_DEST,
//     since dest 0 is not itself "forbidden" the way 9-12 structurally are --
//     it is simply never a named authorized pair for any enabled source).
//   - Every other pair (including any raw-illegal SOURCE_ID/DEST_ID value a
//     host might write despite REG-002's own "legal range" text, since
//     RTL-001 itself performs no per-field range check -- the same
//     already-disclosed, pre-existing, project-wide gap named in every
//     prior module's own header): generic COMMIT_REJECTED.
//
//   Destinations 1-12 are architecturally exclusive (a commit creating a
//   SECOND enabled entry for the same exclusive destination is rejected
//   whole-bank, CONFLICT, not resolved by priority); 13-24 are wired-OR.
//   Enforcing exclusivity ONLY at commit time (ARCH-VAL-023: validated
//   across the complete staged bank) lets the runtime destination
//   computation use the IDENTICAL plain OR-reduce-across-contributing-
//   entries formula for every destination 1-24 uniformly -- exclusivity and
//   wired-OR are the same runtime mechanism, differing only in how strict
//   the commit-time admission check is (at most one enabled contributor vs.
//   any number). Destinations 9-12 structurally never have a contributor
//   (commit-time rejected, see above).
//
//   VALIDATE_COMMIT has priority over DISABLE_ENTRY individually; if BOTH
//   are commanded in the same operation, the whole thing is rejected BUSY
//   (generic COMMIT_REJECTED) with no active change -- a real, distinct
//   three-way outcome, NOT the simpler "mutual exclusion -> silently do
//   neither" pattern RTL-021's own ROUTE_VALIDATE_COMMIT/DISABLE_ENTRY pair
//   uses for the analogous same-cycle case (confirmed by direct comparison:
//   RTL-021's own do_validate_commit/do_disable_entry wires go false for
//   both when both pulse, setting NO evidence of any kind) -- RTL-023's own
//   SS13.2 text is explicit that this case gets its own named outcome
//   ("rejected BUSY"), so it is implemented here as a real, distinct branch
//   that sets COMMIT_REJECTED sticky and increments VIOLATION_COUNT, not
//   silently copied from RTL-021's own different, narrower contract.
//
//   EDGE-HISTORY-CONTINUES-WHILE-GATED (ARCH-RTL023-001, VP-USER-009): each
//   entry's own prior-source-state register updates EVERY cycle that
//   entry's own committed ENABLE bit is set, regardless of module-level
//   output gating (ctl_enable/effective_operational_enable_i) -- gating
//   masks only the OUTPUT (route_dest_o), never the edge-history tracking
//   itself, specifically to prevent a stale edge firing a spurious pulse on
//   re-enable.
// ---------------------------------------------------------------------------
//
// DESIGN, DISCLOSED (ARCH-002/REG-002 describe externally observable
// behavior and the routing contract; the internal entry-bank/authorization/
// event-cause engine below is this module's own real implementation, built
// from first principles against that contract, with every interpretation
// choice called out):
//
//  1. ROUTE TABLE STORAGE: ONE WORKING STAGED FIELD SET (UROUTE_STAGE_*,
//     stored and continuously forwarded by RTL-001 itself as plain
//     internal_reg registers), committed into ONE of SIXTEEN internal
//     entries selected by UROUTE_ENTRY_SELECT.ENTRY only on an accepted
//     VALIDATE_COMMIT pulse -- the identical pattern RTL-021's own 16-entry
//     route table already established (confirmed precedent, not
//     reinvented). ENTRY_SELECT is dual-purpose (REG-002's own text:
//     "Selects route entry 0-15") -- it ALSO selects which entry
//     UROUTE_ACTIVE_SOURCE/UROUTE_ACTIVE_DEST/UROUTE_ENTRY_STATUS/
//     UROUTE_ACTIVE_CONTROL read back, both handled generically below via a
//     single plain array-index mux.
//
//  2. PER-ENTRY ERROR EVIDENCE (UROUTE_ENTRY_STATUS.ERROR): set whenever a
//     VALIDATE_COMMIT targeting that entry (via ENTRY_SELECT) is rejected
//     for any reason; cleared automatically the next time a commit
//     targeting that same entry SUCCEEDS. A disclosed interpretation: REG-
//     002 describes this field only as "Selected route active/valid/error"
//     with no further detail, and this reading (a per-entry "did my last
//     edit attempt succeed" diagnostic) is the only one consistent with
//     ENTRY_STATUS being entry-indexed rather than a single module-wide
//     flag (UROUTE_STATUS.COMMIT_REJECTED already owns that role).
//
//  3. fault_req_o IS REAL, NOT A DISCLOSED STUB (unlike RTL-021's and
//     RTL-022's own permanently-zero fault_req_o): C.6's own fault-source
//     matrix allocates RTL-023 a real, non-reserved class (0x03,
//     recoverable=true), distinct from RTL-021/022's own explicitly
//     "disclosed stub, no real internal condition possible" reasoning.
//     Implemented as the OR-reduction of all 16 entries' own ERROR evidence
//     (finding 2) -- a real, reachable, recoverable condition (an
//     outstanding rejected-commit-attempt residue on at least one entry),
//     cleared the instant every one of those entries either clears its own
//     error (W1C) or is successfully re-committed.
//
//  4. DESTINATIONS 21-24 ("RTL-023 internal event/interrupt request
//     channels", Appendix C.2) are NOT separate internal-only signals --
//     they are the SAME per-destination OR-reduce result every other
//     destination uses, additionally consumed internally: destinations
//     21-22's combined (OR'd) result, RISING-EDGE-detected (to avoid
//     flooding the single event-pending slot every cycle a level-mode
//     route stays high), drives the "activity" event cause (F.3 bit 2 /
//     C.7 subtype 2) when ctl_event_enable and its own condition-enable bit
//     allow it -- a user-configured "tell me when this condition becomes
//     true" event source. Destinations 23-24's combined (OR'd) result
//     drives irq_req_o directly as a live level (gated only by
//     ctl_irq_enable, no additional F.3 condition-mask bit -- F.3's own
//     RTL-023 allocation is exactly 6 bits (0 commit, 1 reject, 2 activity,
//     3 conflict, 4 forbidden destination, 5 event-slot overflow), with no
//     seventh bit for an "interrupt-request channel" condition, so the
//     user's own act of routing a signal to destination 23/24 is itself the
//     enable mechanism, same precedent as a live safety/status level
//     elsewhere in this project). A disclosed interpretation: ARCH-002
//     names these channels but does not spell out the exact evt/irq
//     generation mechanics beyond their own destination-catalog
//     description.
// ---------------------------------------------------------------------------

module dfc_rtl023 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[22]

  input  logic [dfc_types_pkg::DFC_RTL023_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL023_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[19]
  output logic         fault_req_o,          // RTL-013.fault_source_i[16] -- real, finding 3

  input  logic [63:0]  route_source_i,
  output logic [31:0]  route_dest_o,         // bit N = destination N's own gated result; bit0/25-31 always 0

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  input  logic         module_enable_i,      // RTL-002.module_enable_o[22]
  input  logic         effective_operational_enable_i,

  input  logic [63:0] event_condition_enable_i,
  input  logic [63:0] irq_condition_enable_i
);

  // operating_state_i/observational_mode_i: real Appendix A inputs with no
  // per-operating-state behavior specified for RTL-023 anywhere in the
  // -002 set -- a disclosed, genuinely-unused pair, same precedent as every
  // prior Databus/User-Logic module.
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i;

  localparam int unsigned NENT = 16;

  function automatic logic dest_in_range(input logic [7:0] d, input logic [7:0] lo, input logic [7:0] hi);
    dest_in_range = (d >= lo) && (d <= hi);
  endfunction

  function automatic logic dest_structurally_forbidden(input logic [7:0] d);
    dest_structurally_forbidden = dest_in_range(d, 8'd9, 8'd12);
  endfunction

  function automatic logic source_bit_f(input logic [7:0] sid, input logic [63:0] srcvec);
    if (sid == 8'd0) source_bit_f = 1'b0;
    else if (sid == 8'd37) source_bit_f = 1'b1;
    else source_bit_f = srcvec[sid[5:0]];
  endfunction

  function automatic logic entry_result_f(input logic effective, input logic prior_effective, input logic [1:0] mode);
    case (mode)
      2'd0: entry_result_f = effective;
      2'd1: entry_result_f = effective && !prior_effective;
      2'd2: entry_result_f = !effective && prior_effective;
      2'd3: entry_result_f = effective != prior_effective;
      default: entry_result_f = 1'b0;
    endcase
  endfunction

  function automatic logic [15:0] sat16_incr(input logic [15:0] v);
    sat16_incr = (v == 16'hFFFF) ? v : v + 16'd1;
  endfunction

  // ==========================================================================
  // Control-field unpack.
  // ==========================================================================
  wire ctl_enable       = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_CONTROL__ENABLE_HI];
  wire ctl_event_enable = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_CONTROL__EVENT_ENABLE_HI];
  wire ctl_irq_enable   = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_CONTROL__IRQ_ENABLE_HI];

  wire ctl_clr_commit_complete = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__COMMIT_COMPLETE_HI];
  wire ctl_clr_commit_rejected = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__COMMIT_REJECTED_HI];
  wire ctl_clr_forbidden_dest  = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__FORBIDDEN_DEST_HI];
  wire ctl_clr_conflict        = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__CONFLICT_HI];

  wire [3:0] entry_select = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_HI:dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_LO];
  wire [7:0] staged_source_id = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_SOURCE__SOURCE_ID_HI:dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_SOURCE__SOURCE_ID_LO];
  wire [7:0] staged_dest_id   = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_DEST__DEST_ID_HI:dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_DEST__DEST_ID_LO];
  wire       staged_enable    = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__ENABLE_HI];
  wire       staged_invert    = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__INVERT_HI];
  wire [1:0] staged_mode      = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__MODE_HI:dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__MODE_LO];

  wire validate_commit_pulse = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__VALIDATE_COMMIT_HI];
  wire disable_entry_pulse   = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__DISABLE_ENTRY_HI];
  wire both_commanded    = validate_commit_pulse && disable_entry_pulse;
  wire do_validate_commit = validate_commit_pulse && !disable_entry_pulse;
  wire do_disable_entry   = disable_entry_pulse   && !validate_commit_pulse;

  wire ctl_clr_entry_error    = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_STATUS__ERROR_HI];
  wire ctl_clr_event_overflow = control_i[dfc_types_pkg::DFC_RTL023_CONTROL__RTL023_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  // ==========================================================================
  // Sixteen committed entries.
  // ==========================================================================
  logic        entry_enable_q [0:NENT-1];
  logic [7:0]  entry_source_id_q [0:NENT-1];
  logic [7:0]  entry_dest_id_q [0:NENT-1];
  logic        entry_invert_q [0:NENT-1];
  logic [1:0]  entry_mode_q [0:NENT-1];
  logic        entry_error_q [0:NENT-1];
  logic [15:0] entry_activity_count_q [0:NENT-1];
  logic        prior_effective_q [0:NENT-1];
  // FIXED (real, confirmed bug, found via this module's own testbench, not
  // by inspection): a pulse-mode entry's own edge result cannot be a PURE
  // combinational function of entry_effective_comb[e] and
  // prior_effective_q[e] -- prior_effective_q[e] updates on the SAME clock
  // edge that changes entry_effective_comb[e], so by the time anything
  // downstream (route_dest_o itself, or an external observer) samples the
  // combinational result AFTER that edge has fully settled, prior has
  // ALREADY caught up to match the new effective value, and the "edge"
  // condition reads back false -- the pulse exists for zero simulated
  // time, never actually observable. Fixed: pulse-mode entries get a REAL
  // registered one-cycle pulse (entry_pulse_q), computed synchronously in
  // the SAME always_ff as prior_effective_q's own update, using NBA's own
  // same-process old-value-read semantics (the pulse computation reads
  // prior_effective_q's PRE-edge value in the same statement that updates
  // it) -- this is the only mode class affected; level mode (0) needs no
  // such fix, since it never depends on prior_effective_q at all.
  logic        entry_pulse_q [0:NENT-1];

  // ==========================================================================
  // Commit-time combinational validation (ARCH-VAL-023: validated across the
  // complete staged bank).
  // ==========================================================================
  logic commit_forbidden_dest;
  logic commit_generic_ok;
  always_comb begin
    commit_forbidden_dest = 1'b0;
    if (!staged_enable) begin
      commit_generic_ok = (staged_source_id <= 8'd31 || staged_source_id == 8'd37) && (staged_dest_id <= 8'd24);
    end else if (!(staged_source_id <= 8'd31 || staged_source_id == 8'd37) || (staged_dest_id > 8'd24) || (staged_source_id == 8'd0)) begin
      commit_generic_ok = 1'b0;
    end else if (dest_structurally_forbidden(staged_dest_id)) begin
      commit_generic_ok = 1'b0;
      commit_forbidden_dest = 1'b1;
    end else if (staged_source_id == 8'd37) begin
      commit_generic_ok = dest_in_range(staged_dest_id, 8'd21, 8'd24) && (staged_mode == 2'd0);
    end else if (dest_in_range(staged_dest_id, 8'd1, 8'd8) || dest_in_range(staged_dest_id, 8'd21, 8'd24)) begin
      commit_generic_ok = 1'b1;
    end else if (dest_in_range(staged_dest_id, 8'd13, 8'd20)) begin
      commit_generic_ok = (staged_source_id <= 8'd16);
    end else begin
      commit_generic_ok = 1'b0; // dest==0 while enabled: disclosed, see header finding
    end
  end

  // Same loop-wrapped-in-if shape as route_dest_comb's own fix above --
  // folded proactively here too (the loop runs unconditionally; the gate
  // moves into the inner match condition) rather than waiting to hit the
  // identical latch-inference false positive a second time in the same
  // module.
  logic commit_conflict;
  logic commit_conflict_applies;
  integer ec;
  always_comb begin
    commit_conflict = 1'b0;
    commit_conflict_applies = commit_generic_ok && staged_enable && dest_in_range(staged_dest_id, 8'd1, 8'd12);
    for (ec = 0; ec < NENT; ec = ec + 1) begin
      if (commit_conflict_applies && (ec != int'(entry_select)) && entry_enable_q[ec] && (entry_dest_id_q[ec] == staged_dest_id))
        commit_conflict = 1'b1;
    end
  end

  wire commit_ok = commit_generic_ok && !commit_conflict;

  // ==========================================================================
  // Per-entry combinational routing result (declared via generate, read by
  // the always_ff below -- declared ahead of it per this project's own
  // Icarus declare-before-use discipline).
  // ==========================================================================
  logic [0:NENT-1] entry_raw_bit_comb;
  logic [0:NENT-1] entry_effective_comb;
  logic [0:NENT-1] entry_result_comb;
  genvar ge;
  generate
    for (ge = 0; ge < NENT; ge = ge + 1) begin : g_entry_comb
      assign entry_raw_bit_comb[ge]  = source_bit_f(entry_source_id_q[ge], route_source_i);
      assign entry_effective_comb[ge] = entry_raw_bit_comb[ge] ^ entry_invert_q[ge];
      // Level mode (0) is pure combinational passthrough (no prior
      // dependency, no race); pulse modes (1-3) use the REAL registered
      // entry_pulse_q (finding above) -- never the combinational
      // entry_result_f/prior_effective_q comparison, which can never
      // actually be observed as asserted.
      assign entry_result_comb[ge] = (entry_mode_q[ge] == 2'd0) ? entry_effective_comb[ge] : entry_pulse_q[ge];
    end
  endgenerate

  wire route_active_enable = ctl_enable && effective_operational_enable_i;

  // ---- Destination OR-reduce, bit N = destination N (1-24; 0/25-31 always
  // zero). Exclusive (1-12) vs. wired-OR (13-24) differ only in commit-time
  // admission strictness (header finding) -- the runtime formula is
  // identical for every destination. ----
  // FIXED (real, confirmed bug, found via a real build_ecp5.ps1 run, not by
  // inspection -- the identical latch-inference false-positive class
  // RTL-021's own session already found and fixed, item 159): a `for` loop
  // whose entire body, including its own loop-index variable's own
  // assignment, is reachable only through an outer `if` conditional can
  // trigger Yosys's own latch-inference check on the loop index itself
  // (`ERROR: Latch inferred for signal 'dd[0]' from always_comb process`).
  // Fixed the identical way: the loop itself runs unconditionally every
  // time, with the gating condition folded into the loop body's own match
  // condition instead of wrapped around the loop.
  logic [31:0] route_dest_comb;
  integer dd, de;
  always_comb begin
    route_dest_comb = 32'h0;
    for (dd = 1; dd <= 24; dd = dd + 1) begin
      for (de = 0; de < NENT; de = de + 1) begin
        if (route_active_enable && entry_enable_q[de] && (entry_dest_id_q[de] == dd[7:0]) && entry_result_comb[de])
          route_dest_comb[dd] = 1'b1;
      end
    end
  end
  assign route_dest_o = route_dest_comb;

  // ==========================================================================
  // Global status stickies/counters.
  // ==========================================================================
  logic commit_complete_sticky_q, commit_rejected_sticky_q, forbidden_dest_sticky_q, conflict_sticky_q;
  logic [15:0] violation_count_q;
  logic event_overflow_sticky_q;
  logic [15:0] event_drop_count_q;

  integer ri;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      for (ri = 0; ri < NENT; ri = ri + 1) begin
        entry_enable_q[ri] <= 1'b0; entry_source_id_q[ri] <= 8'h0; entry_dest_id_q[ri] <= 8'h0;
        entry_invert_q[ri] <= 1'b0; entry_mode_q[ri] <= 2'd0; entry_error_q[ri] <= 1'b0;
        entry_activity_count_q[ri] <= 16'h0; prior_effective_q[ri] <= 1'b0; entry_pulse_q[ri] <= 1'b0;
      end
      commit_complete_sticky_q <= 1'b0; commit_rejected_sticky_q <= 1'b0;
      forbidden_dest_sticky_q <= 1'b0; conflict_sticky_q <= 1'b0;
      violation_count_q <= 16'h0;
      event_overflow_sticky_q <= 1'b0; event_drop_count_q <= 16'h0;
    end else if (module_reset_i) begin
      for (ri = 0; ri < NENT; ri = ri + 1) begin
        entry_enable_q[ri] <= 1'b0; entry_error_q[ri] <= 1'b0;
        entry_activity_count_q[ri] <= 16'h0; prior_effective_q[ri] <= 1'b0; entry_pulse_q[ri] <= 1'b0;
      end
      commit_complete_sticky_q <= 1'b0; commit_rejected_sticky_q <= 1'b0;
      forbidden_dest_sticky_q <= 1'b0; conflict_sticky_q <= 1'b0;
      violation_count_q <= 16'h0;
      event_overflow_sticky_q <= 1'b0; event_drop_count_q <= 16'h0;
    end else begin
      // ---- W1C clears (new evidence dominates, project-wide precedent --
      // the commit/disable block below runs AFTER these in program order,
      // so its own non-blocking "set" assignments win via last-write
      // semantics whenever a clear and new evidence coincide). ----
      if (ctl_clr_commit_complete) commit_complete_sticky_q <= 1'b0;
      if (ctl_clr_commit_rejected) commit_rejected_sticky_q <= 1'b0;
      if (ctl_clr_forbidden_dest)  forbidden_dest_sticky_q  <= 1'b0;
      if (ctl_clr_conflict)        conflict_sticky_q        <= 1'b0;
      if (ctl_clr_entry_error)     entry_error_q[entry_select] <= 1'b0;
      if (ctl_clr_event_overflow)  event_overflow_sticky_q  <= 1'b0;

      // ---- per-entry activity count (finding header: saturating,
      // increments once per gated-active cycle). ----
      for (ri = 0; ri < NENT; ri = ri + 1) begin
        if (route_active_enable && entry_enable_q[ri] && entry_result_comb[ri])
          entry_activity_count_q[ri] <= sat16_incr(entry_activity_count_q[ri]);
      end

      // ---- edge history: updates every cycle an entry is committed-
      // enabled, REGARDLESS of module-level output gating (ARCH-RTL023-001,
      // VP-USER-009). entry_pulse_q is computed HERE, synchronously, using
      // this SAME non-blocking-assignment statement's own old (pre-edge)
      // read of prior_effective_q[ri] -- the real fix for the registered-
      // pulse-vs-combinational-race finding above. ----
      for (ri = 0; ri < NENT; ri = ri + 1) begin
        if (entry_enable_q[ri]) begin
          case (entry_mode_q[ri])
            2'd1: entry_pulse_q[ri] <= entry_effective_comb[ri] && !prior_effective_q[ri];
            2'd2: entry_pulse_q[ri] <= !entry_effective_comb[ri] && prior_effective_q[ri];
            2'd3: entry_pulse_q[ri] <= entry_effective_comb[ri] != prior_effective_q[ri];
            default: entry_pulse_q[ri] <= 1'b0;
          endcase
          prior_effective_q[ri] <= entry_effective_comb[ri];
        end else begin
          entry_pulse_q[ri] <= 1'b0;
        end
      end

      // ---- commit / disable (VALIDATE_COMMIT priority over DISABLE_ENTRY
      // individually; both together -> REJECTED BUSY, no active change,
      // finding header). ----
      if (both_commanded) begin
        commit_rejected_sticky_q <= 1'b1;
        violation_count_q <= sat16_incr(violation_count_q);
      end else if (do_validate_commit) begin
        if (commit_forbidden_dest) begin
          forbidden_dest_sticky_q <= 1'b1;
          violation_count_q <= sat16_incr(violation_count_q);
          entry_error_q[entry_select] <= 1'b1;
        end else if (!commit_generic_ok) begin
          commit_rejected_sticky_q <= 1'b1;
          violation_count_q <= sat16_incr(violation_count_q);
          entry_error_q[entry_select] <= 1'b1;
        end else if (commit_conflict) begin
          conflict_sticky_q <= 1'b1;
          violation_count_q <= sat16_incr(violation_count_q);
          entry_error_q[entry_select] <= 1'b1;
        end else begin
          entry_enable_q[entry_select]    <= staged_enable;
          entry_source_id_q[entry_select] <= staged_source_id;
          entry_dest_id_q[entry_select]   <= staged_dest_id;
          entry_invert_q[entry_select]    <= staged_invert;
          entry_mode_q[entry_select]      <= staged_mode;
          entry_error_q[entry_select]     <= 1'b0;
          commit_complete_sticky_q <= 1'b1;
        end
      end else if (do_disable_entry) begin
        entry_enable_q[entry_select] <= 1'b0;
        commit_complete_sticky_q <= 1'b1;
      end
    end
  end

  wire dest2122_activity = route_dest_comb[21] || route_dest_comb[22];
  wire dest2324_irq      = route_dest_comb[23] || route_dest_comb[24];

  logic dest2122_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) dest2122_prev_q <= 1'b0;
    else if (module_reset_i) dest2122_prev_q <= 1'b0;
    else dest2122_prev_q <= dest2122_activity;
  end
  wire cond_activity_raw = dest2122_activity && !dest2122_prev_q;

  // ==========================================================================
  // Event/IRQ generation. Cause encoding matches F.3's own 6-entry list AND
  // C.7's own 0x0051 subtype list identically this session (no
  // inconsistency to resolve, unlike RTL-022's own session): 0=commit,
  // 1=reject, 2=activity, 3=conflict, 4=forbidden destination,
  // 5=event-slot overflow (generic, drains the pending slot, never its own
  // typed record). event_id=0x0051 (C.7), evt slot 22 (master table,
  // header finding).
  // ==========================================================================
  wire commit_generic_reject = do_validate_commit && !commit_forbidden_dest && !commit_generic_ok;

  wire cond_commit    = do_validate_commit && !commit_forbidden_dest && commit_generic_ok && !commit_conflict && event_condition_enable_i[0];
  wire cond_reject    = (commit_generic_reject || both_commanded) && event_condition_enable_i[1];
  wire cond_activity  = cond_activity_raw && event_condition_enable_i[2];
  wire cond_conflict  = do_validate_commit && !commit_forbidden_dest && commit_generic_ok && commit_conflict && event_condition_enable_i[3];
  wire cond_forbidden = do_validate_commit && commit_forbidden_dest && event_condition_enable_i[4];
  wire any_cond = ctl_event_enable &&
                  (cond_commit || cond_reject || cond_activity || cond_conflict || cond_forbidden);

  logic        evt_pending_q;
  logic [3:0]  evt_cause_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  wire         slot_free_evt = !evt_pending_q || evt_ready_i;

  // C.7's own 0x0051 detail field is "entry and destination" -- packed as
  // [7:0] subtype (the cause itself), [15:8] entry_select, [23:16] the
  // destination relevant to this event (staged_dest_id for commit/reject/
  // conflict/forbidden; whichever of 21/22 is live for activity), [31:24]
  // reserved zero.
  wire [7:0] evt_relevant_dest = cond_activity ? (route_dest_comb[21] ? 8'd21 : 8'd22) : staged_dest_id;
  wire [3:0] evt_cause_next = cond_commit    ? 4'd0 :
                              cond_reject    ? 4'd1 :
                              cond_activity  ? 4'd2 :
                              cond_conflict  ? 4'd3 :
                              cond_forbidden ? 4'd4 : 4'd5;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_cause_q <= 4'd0; evt_record_q <= '0;
    end else if (module_reset_i) begin
      evt_pending_q <= 1'b0;
    end else begin
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;
      if (any_cond) begin
        if (slot_free_evt) begin
          evt_pending_q <= 1'b1;
          evt_cause_q <= evt_cause_next;
          evt_record_q <= {
            8'h00, evt_relevant_dest, {4'h0, entry_select}, {4'h0, evt_cause_next}, // [127:96] event_data
            8'h00,          // [95:88] flags
            8'd22,          // [87:80] source_id = evt bus slot 22
            16'h0051,       // [79:64] event_id (C.7 0x0051)
            timestamp_i     // [63:0] timestamp
          };
        end else begin
          event_overflow_sticky_q <= 1'b1;
          event_drop_count_q <= sat16_incr(event_drop_count_q);
        end
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;
  assign irq_req_o = (evt_pending_q && ctl_irq_enable && irq_condition_enable_i[evt_cause_q]) ||
                     (route_active_enable && dest2324_irq && ctl_irq_enable);
  assign fault_req_o = |{entry_error_q[0], entry_error_q[1], entry_error_q[2], entry_error_q[3],
                         entry_error_q[4], entry_error_q[5], entry_error_q[6], entry_error_q[7],
                         entry_error_q[8], entry_error_q[9], entry_error_q[10], entry_error_q[11],
                         entry_error_q[12], entry_error_q[13], entry_error_q[14], entry_error_q[15]};

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  wire any_entry_enabled = |{entry_enable_q[0], entry_enable_q[1], entry_enable_q[2], entry_enable_q[3],
                             entry_enable_q[4], entry_enable_q[5], entry_enable_q[6], entry_enable_q[7],
                             entry_enable_q[8], entry_enable_q[9], entry_enable_q[10], entry_enable_q[11],
                             entry_enable_q[12], entry_enable_q[13], entry_enable_q[14], entry_enable_q[15]};

  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__READY_HI]          = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__FAULT_HI]          = fault_req_o;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__EVENT_OVERFLOW_HI] = event_overflow_sticky_q;

  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__ACTIVE_HI]          = route_active_enable && any_entry_enabled;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__COMMIT_COMPLETE_HI] = commit_complete_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__COMMIT_REJECTED_HI] = commit_rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__FORBIDDEN_DEST_HI]  = forbidden_dest_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__CONFLICT_HI]        = conflict_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__VIOLATION_COUNT_HI:dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__VIOLATION_COUNT_LO] = violation_count_q;

  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_SOURCE__SOURCE_ID_HI:dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_SOURCE__SOURCE_ID_LO] = entry_source_id_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_DEST__DEST_ID_HI:dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_DEST__DEST_ID_LO] = entry_dest_id_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__ACTIVE_HI] = route_active_enable && entry_enable_q[entry_select] && entry_result_comb[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__VALID_HI]  = entry_enable_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__ERROR_HI]  = entry_error_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__ACTIVITY_COUNT_HI:dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__ACTIVITY_COUNT_LO] = entry_activity_count_q[entry_select];

  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL023_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;

  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_CONTROL__ENABLE_HI] = entry_enable_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_CONTROL__INVERT_HI] = entry_invert_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_CONTROL__MODE_HI:dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_CONTROL__MODE_LO] = entry_mode_q[entry_select];

endmodule
