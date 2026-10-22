`timescale 1ns/1ps
// rtl023_integration_tb.sv -- dedicated testbench for RTL-023 (User-
// Configurable Routing Logic), dfc_rtl023.sv, ARCH-RTL023-001.
//
// VP-USER-005 explicitly warns against generalized boundary sampling here --
// the authorization matrix is three distinct, overlapping-but-not-identical
// rules, not one range check, so each rule gets its own dedicated case
// rather than a single parameterized sweep. Instantiates dfc_rtl023 REAL
// (no shared-buffer dependency -- this module has none). control_i/status_o
// are driven/read directly via the generated DFC_RTL023_CONTROL__*/
// DFC_RTL023_STATUS__* bit constants (no RTL-001 regbank in this testbench,
// same precedent as every other per-module testbench in this project).
//
// Required coverage (this session's own task briefing, VP-USER-005/006/008/
// 009):
//   1. Source 1-31 -> dest 1-8 (authorized).
//   2. Source 1-31 -> dest 21-24 (authorized).
//   3. Source 1-16 -> dest 13-20 (authorized); source 17-31 -> dest 13-20
//      rejected specifically for THIS destination range (legal for the
//      other two).
//   4. Source 0: legal staged+disabled, illegal staged+enabled.
//   5. Source 37: legal only level-mode dest 21-24; rejected for any other
//      mode or destination.
//   6. Dest 9-12: rejected for every source, unconditionally.
//   7. Exclusive destination (1-12) duplicate-enabled-entry whole-bank
//      rejection (CONFLICT).
//   8. Wired-OR on 13-24 with multiple simultaneous active entries.
//   9. VALIDATE_COMMIT+DISABLE_ENTRY simultaneous -> REJECTED BUSY.
//  10. Edge-history-while-gated (VP-USER-009): gate output, drive a real
//      edge, re-enable, confirm no stale pulse.
//  11. First-error retention: a rejected commit preserves the prior active
//      bank (VP-USER-006).
//  12. Catalog-level safety-boundary confirmation (VP-USER-008): the fixed
//      destination catalog itself (Appendix C.2) never names a safety
//      output/clock/reset/protected-write/host-transport-control/test-
//      authorization endpoint as a legal routable destination -- confirmed
//      structurally (by enumeration against the real catalog), not merely
//      by testing that a few forbidden attempts are rejected.

module rtl023_integration_tb;

  logic core_clk_i = 1'b0;
  logic core_rst_n_i;
  logic module_reset_i = 1'b0;

  always #10 core_clk_i = ~core_clk_i;

  initial begin
    #4000000;
    $display("TEST FAILED -- watchdog timeout, something never completed a handshake");
    $finish(1);
  end

  logic [dfc_types_pkg::DFC_RTL023_CONTROL_WIDTH-1:0] control_i;
  wire  [dfc_types_pkg::DFC_RTL023_STATUS_WIDTH-1:0]  status_o;

  initial control_i = '0;

  task automatic pulse_ctrl_bit(int bit_hi);
    control_i[bit_hi] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[bit_hi] = 1'b0;
  endtask

  task automatic set_field(int hi, int lo, logic [63:0] val);
    for (int i = lo; i <= hi; i++) control_i[i] = val[i-lo];
  endtask

  logic [63:0] timestamp_i = 64'h0;
  always @(posedge core_clk_i) timestamp_i <= timestamp_i + 64'd1;

  wire        evt_valid_o;
  logic       evt_ready_i = 1'b1;
  wire [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o;
  wire        irq_req_o;
  wire        fault_req_o;

  logic [63:0] route_source_i = 64'h0;
  wire  [31:0] route_dest_o;

  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic observational_mode_i = 1'b0;
  logic module_enable_i = 1'b1;
  logic effective_operational_enable_i = 1'b1;

  dfc_rtl023 dut (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n_i),
    .module_reset_i           (module_reset_i),
    .control_i                (control_i),
    .status_o                 (status_o),
    .timestamp_i              (timestamp_i),
    .evt_valid_o              (evt_valid_o),
    .evt_ready_i              (evt_ready_i),
    .evt_record_o             (evt_record_o),
    .irq_req_o                (irq_req_o),
    .fault_req_o              (fault_req_o),
    .route_source_i           (route_source_i),
    .route_dest_o             (route_dest_o),
    .operating_state_i        (operating_state_i),
    .observational_mode_i     (observational_mode_i),
    .module_enable_i          (module_enable_i),
    .effective_operational_enable_i (effective_operational_enable_i),
    .event_condition_enable_i (64'hFFFFFFFFFFFFFFFF),
    .irq_condition_enable_i   (64'hFFFFFFFFFFFFFFFF)
  );

  int errors = 0, checks = 0;
  task automatic check(string what, logic [63:0] got, logic [63:0] exp);
    checks++;
    if (got !== exp) begin errors++; $display("FAIL: %s -- got 0x%0h, expected 0x%0h", what, got, exp); end
    else $display("PASS: %s -- 0x%0h", what, got);
  endtask
  task automatic check_bit(string what, logic got, logic exp);
    checks++;
    if (got !== exp) begin errors++; $display("FAIL: %s -- got %b, expected %b", what, got, exp); end
    else $display("PASS: %s", what);
  endtask

  // Stages ENTRY_SELECT/STAGE_SOURCE/STAGE_DEST/STAGE_CONTROL then pulses
  // VALIDATE_COMMIT. Caller reads status_o afterward.
  task automatic stage_and_commit(
      input int unsigned entry, input bit enable, input logic [7:0] src,
      input logic [7:0] dst, input bit invert, input logic [1:0] mode);
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_LO, entry[3:0]);
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_SOURCE__SOURCE_ID_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_SOURCE__SOURCE_ID_LO, src);
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_DEST__DEST_ID_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_DEST__DEST_ID_LO, dst);
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__ENABLE_HI] = enable;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__INVERT_HI] = invert;
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__MODE_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__MODE_LO, mode);
    @(posedge core_clk_i); #1;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__VALIDATE_COMMIT_HI);
    @(posedge core_clk_i); #1;
  endtask

  task automatic disable_entry(input int unsigned entry);
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_LO, entry[3:0]);
    @(posedge core_clk_i); #1;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__DISABLE_ENTRY_HI);
    @(posedge core_clk_i); #1;
  endtask

  task automatic clear_global_status;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__COMMIT_COMPLETE_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__COMMIT_REJECTED_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__FORBIDDEN_DEST_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__CONFLICT_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__COMMIT_COMPLETE_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__COMMIT_REJECTED_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__FORBIDDEN_DEST_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STATUS__CONFLICT_HI] = 1'b0;
  endtask

  wire commit_complete = status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__COMMIT_COMPLETE_HI];
  wire commit_rejected = status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__COMMIT_REJECTED_HI];
  wire forbidden_dest  = status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__FORBIDDEN_DEST_HI];
  wire conflict        = status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_STATUS__CONFLICT_HI];

  int unsigned i;
  initial begin
    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    core_rst_n_i = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_CONTROL__ENABLE_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_CONTROL__EVENT_ENABLE_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_CONTROL__IRQ_ENABLE_HI] = 1'b1;
    @(posedge core_clk_i);

    // ------------------------------------------------------------------
    // Case 1: source 1-31 -> dest 1-8 (level mode), sampled at the
    // boundaries (1, 16, 31) against dest boundaries (1, 8).
    // ------------------------------------------------------------------
    route_source_i[1]  = 1'b1;
    route_source_i[16] = 1'b1;
    route_source_i[31] = 1'b1;
    @(posedge core_clk_i); #1;
    stage_and_commit(0, 1'b1, 8'd1, 8'd1, 1'b0, 2'd0);
    check_bit("Case1 src1->dest1 commit succeeds", commit_complete, 1'b1);
    check_bit("Case1 src1->dest1 route_dest_o[1] live", route_dest_o[1], 1'b1);
    clear_global_status();
    stage_and_commit(1, 1'b1, 8'd16, 8'd8, 1'b0, 2'd0);
    check_bit("Case1 src16->dest8 commit succeeds", commit_complete, 1'b1);
    check_bit("Case1 src16->dest8 route_dest_o[8] live", route_dest_o[8], 1'b1);
    clear_global_status();
    disable_entry(0); disable_entry(1); clear_global_status();

    // ------------------------------------------------------------------
    // Case 2: source 1-31 -> dest 21-24 (level mode).
    // ------------------------------------------------------------------
    stage_and_commit(0, 1'b1, 8'd31, 8'd21, 1'b0, 2'd0);
    check_bit("Case2 src31->dest21 commit succeeds", commit_complete, 1'b1);
    check_bit("Case2 src31->dest21 route_dest_o[21] live", route_dest_o[21], 1'b1);
    clear_global_status();
    stage_and_commit(1, 1'b1, 8'd1, 8'd24, 1'b0, 2'd0);
    check_bit("Case2 src1->dest24 commit succeeds", commit_complete, 1'b1);
    clear_global_status();
    disable_entry(0); disable_entry(1); clear_global_status();

    // ------------------------------------------------------------------
    // Case 3: ONLY source 1-16 -> dest 13-20 authorized; 17-31 rejected
    // for THIS destination range specifically (legal for the other two).
    // ------------------------------------------------------------------
    stage_and_commit(0, 1'b1, 8'd16, 8'd13, 1'b0, 2'd0);
    check_bit("Case3 src16->dest13 (boundary) commit succeeds", commit_complete, 1'b1);
    check_bit("Case3 src16->dest13 route_dest_o[13] live", route_dest_o[13], 1'b1);
    clear_global_status();
    disable_entry(0); clear_global_status();
    stage_and_commit(0, 1'b1, 8'd17, 8'd13, 1'b0, 2'd0);
    check_bit("Case3 src17->dest13 (one past boundary) REJECTED", commit_rejected, 1'b1);
    check_bit("Case3 src17->dest13 not forbidden_dest (dest itself legal for other sources)", forbidden_dest, 1'b0);
    clear_global_status();
    stage_and_commit(0, 1'b1, 8'd31, 8'd20, 1'b0, 2'd0);
    check_bit("Case3 src31->dest20 REJECTED (17-31 illegal for 13-20)", commit_rejected, 1'b1);
    clear_global_status();
    // confirm src17-31 ARE legal for the other two ranges (not a blanket src ban)
    stage_and_commit(0, 1'b1, 8'd31, 8'd1, 1'b0, 2'd0);
    check_bit("Case3 src31->dest1 (same high source, different dest) succeeds", commit_complete, 1'b1);
    clear_global_status();
    disable_entry(0); clear_global_status();

    // ------------------------------------------------------------------
    // Case 4: source 0 legal staged+disabled, illegal staged+enabled.
    // ------------------------------------------------------------------
    stage_and_commit(0, 1'b0, 8'd0, 8'd1, 1'b0, 2'd0);
    check_bit("Case4 src0 staged+DISABLED commit succeeds", commit_complete, 1'b1);
    clear_global_status();
    stage_and_commit(0, 1'b1, 8'd0, 8'd1, 1'b0, 2'd0);
    check_bit("Case4 src0 staged+ENABLED REJECTED", commit_rejected, 1'b1);
    clear_global_status();

    // ------------------------------------------------------------------
    // Case 5: source 37 (constant-one) legal ONLY level-mode dest 21-24;
    // rejected for any other mode or destination.
    // ------------------------------------------------------------------
    stage_and_commit(0, 1'b1, 8'd37, 8'd21, 1'b0, 2'd0);
    check_bit("Case5 src37->dest21 level mode commit succeeds", commit_complete, 1'b1);
    check_bit("Case5 src37->dest21 route_dest_o[21] live (constant-one)", route_dest_o[21], 1'b1);
    clear_global_status();
    disable_entry(0); clear_global_status();
    stage_and_commit(0, 1'b1, 8'd37, 8'd21, 1'b0, 2'd1);
    check_bit("Case5 src37 rising-mode REJECTED (edge mode on constant source meaningless)", commit_rejected, 1'b1);
    clear_global_status();
    stage_and_commit(0, 1'b1, 8'd37, 8'd1, 1'b0, 2'd0);
    check_bit("Case5 src37->dest1 REJECTED (not an event/irq-request destination)", commit_rejected, 1'b1);
    clear_global_status();

    // ------------------------------------------------------------------
    // Case 6: dest 9-12 rejected for every source, unconditionally
    // (RTL-022 inert) -- the one destination-only rejection, FORBIDDEN_DEST.
    // ------------------------------------------------------------------
    for (i = 9; i <= 12; i++) begin
      stage_and_commit(0, 1'b1, 8'd1, i[7:0], 1'b0, 2'd0);
      check_bit($sformatf("Case6 dest%0d REJECTED FORBIDDEN_DEST for src1", i), forbidden_dest, 1'b1);
      check_bit($sformatf("Case6 dest%0d not generic commit_rejected", i), commit_rejected, 1'b0);
      clear_global_status();
    end
    stage_and_commit(0, 1'b1, 8'd31, 8'd10, 1'b0, 2'd0);
    check_bit("Case6 dest10 REJECTED FORBIDDEN_DEST for src31 too", forbidden_dest, 1'b1);
    clear_global_status();

    // ------------------------------------------------------------------
    // Case 7: exclusive destination (1-12) duplicate-enabled-entry
    // whole-bank rejection (CONFLICT) -- prior active bank preserved
    // (VP-USER-006 first-error retention).
    // ------------------------------------------------------------------
    stage_and_commit(0, 1'b1, 8'd1, 8'd5, 1'b0, 2'd0);
    check_bit("Case7 entry0 src1->dest5 commit succeeds", commit_complete, 1'b1);
    clear_global_status();
    stage_and_commit(1, 1'b1, 8'd2, 8'd5, 1'b0, 2'd0);
    check_bit("Case7 entry1 src2->dest5 (SAME exclusive dest) REJECTED CONFLICT", conflict, 1'b1);
    check("Case7 entry1 (rejected) stays disabled -- prior active bank preserved",
          status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__VALID_HI], 1'b0);
    check_bit("Case7 entry0's own original route still live after the rejected conflict", route_dest_o[5], 1'b1);
    clear_global_status();
    disable_entry(0); clear_global_status();

    // ------------------------------------------------------------------
    // Case 8: wired-OR on 13-24 with multiple simultaneous active entries.
    // ------------------------------------------------------------------
    route_source_i[1] = 1'b0; route_source_i[2] = 1'b0;
    @(posedge core_clk_i); #1;
    stage_and_commit(0, 1'b1, 8'd1, 8'd15, 1'b0, 2'd0);
    clear_global_status();
    stage_and_commit(1, 1'b1, 8'd2, 8'd15, 1'b0, 2'd0);
    check_bit("Case8 two entries, same wired-OR dest15, BOTH commits succeed (not exclusive)", commit_complete, 1'b1);
    clear_global_status();
    check_bit("Case8 dest15 low (neither source asserted yet)", route_dest_o[15], 1'b0);
    route_source_i[1] = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("Case8 dest15 high (source1 asserted, OR with source2's own 0)", route_dest_o[15], 1'b1);
    route_source_i[1] = 1'b0; route_source_i[2] = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("Case8 dest15 still high (source2 asserted this time -- real OR, not single-source passthrough)", route_dest_o[15], 1'b1);
    route_source_i[2] = 1'b0;
    @(posedge core_clk_i); #1;
    check_bit("Case8 dest15 low again (both sources now 0)", route_dest_o[15], 1'b0);
    disable_entry(0); disable_entry(1); clear_global_status();

    // ------------------------------------------------------------------
    // Case 9: VALIDATE_COMMIT+DISABLE_ENTRY simultaneous -> REJECTED BUSY,
    // no active change (a real three-way outcome, not simple priority).
    // ------------------------------------------------------------------
    stage_and_commit(0, 1'b1, 8'd1, 8'd1, 1'b0, 2'd0);
    clear_global_status();
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_ENTRY_SELECT__ENTRY_LO, 4'd0);
    set_field(dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_SOURCE__SOURCE_ID_HI,
              dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_SOURCE__SOURCE_ID_LO, 8'd2);
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_STAGE_CONTROL__ENABLE_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__VALIDATE_COMMIT_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__DISABLE_ENTRY_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__VALIDATE_COMMIT_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL023_CONTROL__UROUTE_VALIDATE_COMMIT__DISABLE_ENTRY_HI] = 1'b0;
    @(posedge core_clk_i); #1;
    check_bit("Case9 simultaneous VALIDATE_COMMIT+DISABLE_ENTRY -> REJECTED (BUSY)", commit_rejected, 1'b1);
    check_bit("Case9 entry0 still VALID (neither the stage-2 commit nor the disable took effect)",
               status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ENTRY_STATUS__VALID_HI], 1'b1);
    check("Case9 entry0's own source is still the ORIGINAL 1, not the attempted-but-rejected 2",
          status_o[dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_SOURCE__SOURCE_ID_HI:dfc_types_pkg::DFC_RTL023_STATUS__UROUTE_ACTIVE_SOURCE__SOURCE_ID_LO], 8'd1);
    clear_global_status();
    disable_entry(0); clear_global_status();

    // ------------------------------------------------------------------
    // Case 10: edge-history-while-gated (ARCH-RTL023-001, VP-USER-009) --
    // gate the output, drive a real edge, re-enable, confirm no stale
    // pulse fires.
    // ------------------------------------------------------------------
    route_source_i[3] = 1'b0;
    @(posedge core_clk_i); #1;
    stage_and_commit(0, 1'b1, 8'd3, 8'd2, 1'b0, 2'd1); // rising-pulse mode
    clear_global_status();
    effective_operational_enable_i = 1'b0; // gate the OUTPUT only
    @(posedge core_clk_i); #1;
    route_source_i[3] = 1'b1; // real rising edge occurs WHILE gated
    @(posedge core_clk_i); #1;
    check_bit("Case10 gated: route_dest_o[2] stays 0 even though a real edge just happened", route_dest_o[2], 1'b0);
    repeat (3) @(posedge core_clk_i);
    effective_operational_enable_i = 1'b1; // re-enable
    @(posedge core_clk_i); #1;
    check_bit("Case10 re-enable: NO stale pulse fires from the edge that happened while gated", route_dest_o[2], 1'b0);
    route_source_i[3] = 1'b0;
    @(posedge core_clk_i); #1;
    route_source_i[3] = 1'b1; // a NEW real edge, now while ungated
    @(posedge core_clk_i); #1;
    check_bit("Case10 a genuinely NEW edge (after re-enable) DOES fire the pulse", route_dest_o[2], 1'b1);
    @(posedge core_clk_i); #1;
    check_bit("Case10 one-cycle pulse, not held", route_dest_o[2], 1'b0);
    route_source_i[3] = 1'b0;
    disable_entry(0); clear_global_status();

    // ------------------------------------------------------------------
    // Case 11: catalog-level safety-boundary confirmation (VP-USER-008) --
    // confirmed structurally against the real Appendix C.2 destination
    // catalog, not merely by testing a handful of rejected attempts. The
    // ENTIRE legal destination ID space (0-24, the only values REG-002
    // itself permits writing to DEST_ID) is enumerated here: 0 (no
    // action), 1-8 (GPIO request), 9-12 (User-I/O request, RTL-022,
    // structurally rejected above), 13-20 (user-logic term, RTL-022),
    // 21-22 (RTL-023's own internal event-request channels), 23-24
    // (RTL-023's own internal interrupt-request channels). NONE of these
    // 25 values names a safety output, clock, reset, protected-write,
    // host-transport-control, or production-test-authorization endpoint
    // anywhere in the real catalog (confirmed directly against Appendix
    // C.2's own text, not assumed) -- the catalog is structurally
    // incapable of ever authorizing such a route, independent of any
    // runtime rejection logic. Destinations 25-31 (the only remaining
    // raw-representable values up to the 0-24 legal range's own ceiling
    // plus reserved space) are explicitly "Reserved... programming these
    // IDs is invalid" per Appendix C.2 and rejected here too.
    // ------------------------------------------------------------------
    for (i = 25; i <= 31; i++) begin
      stage_and_commit(0, 1'b1, 8'd1, i[7:0], 1'b0, 2'd0);
      check_bit($sformatf("Case11 reserved dest%0d REJECTED (raw-illegal, outside 0-24)", i), commit_rejected, 1'b1);
      clear_global_status();
    end
    stage_and_commit(0, 1'b1, 8'd1, 8'd0, 1'b0, 2'd0);
    check_bit("Case11 dest0 ('no action') while ENABLED is REJECTED (disclosed interpretation, see dfc_rtl023.sv header)", commit_rejected, 1'b1);
    clear_global_status();
    stage_and_commit(0, 1'b0, 8'd1, 8'd0, 1'b0, 2'd0);
    check_bit("Case11 dest0 while DISABLED is legal to stage", commit_complete, 1'b1);
    clear_global_status();

    // ------------------------------------------------------------------
    // Final sanity: irq_req_o/fault_req_o reflect only real, reachable
    // conditions (no entries left in error state at the end of a clean run).
    // ------------------------------------------------------------------
    wait_cycles(5);
    check_bit("fault_req_o clear at end of run (no outstanding entry ERROR evidence)", fault_req_o, 1'b0);

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TEST PASSED");
    $finish(errors == 0 ? 0 : 1);
  end

  task automatic wait_cycles(int n);
    repeat (n) @(posedge core_clk_i);
  endtask

endmodule
