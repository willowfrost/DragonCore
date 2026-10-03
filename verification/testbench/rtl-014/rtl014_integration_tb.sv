// rtl014_integration_tb.sv -- REAL end-to-end round-trip test for RTL-014
// (Interlock Engine): real host writes through RTL-001's real DRI path
// (including reggen.py v5's selector-indexed eight-entry staging bank) must
// change RTL-014's real behavior, and RTL-014's real evaluation/evidence
// must reach back to host reads -- same template as rtl002 through
// rtl013_integration_tb.sv.
//
// REAL TERM PRODUCER, not a forced value: the eight interlock term sources
// used here are C.1 IDs 1-8 (qualified GPIO 0-7), produced by a real
// dfc_rtl006 instance whose real gpio_i pins this testbench drives. With
// GPIO qualification at its reset value (0 ms) RTL-006 passes the
// synchronized pin straight to its qualified status, exactly as in the
// integrated build. C.1 IDs 0 (constant false) and 37 (constant true) are
// also exercised. The term vector is assembled and REGISTERED here exactly
// as dfc_rtl024.sv's internal_source_vector_q does (bits this file does not
// model are zero).
//
// REAL FAULT CONSUMER: a real dfc_rtl013 instance receives RTL-014's real
// fault_req_o on fault_source_i[1] (ARCH-002 Appendix A / C.6), proving the
// fault path end to end through a real host read of FAULT_LATCHED_SOURCE.
//
// Coverage map (VP-MOD-014 / VP-SAFE-006 / VP-SAFE-007 / VP-SAFE-016):
//   Part 1  reset state, ready, guard reset values
//   Part 2  protection on ILOCK_CONTROL / ILOCK_VALIDATE_COMMIT
//   Part 3  selector-indexed staging (REG-COH-001, REG-3228 staged readback)
//   Part 4  commit + active readback of every member + no grace period
//   Part 5  all four operators and per-term inversion via real GPIO terms
//   Part 6  same-edge guard rule, checked on every clock edge (VP-SAFE-007)
//   Part 7  whole-bank atomicity, first-error ordering, every illegal class
//   Part 8  sticky evidence: clear ineffective while active
//   Part 9  LATCH_VIOLATION policy
//   Part 10 simultaneous violations -> lane-2 source priority
//   Part 11 ILOCK_CONTROL.ENABLE=0 releases everything
//   Part 12 fault_req_o -> real RTL-013 fault_source_i[1]
//   Part 13 event 0x0042 + EVENT_OVERFLOW host read-and-clear round trip
//   Part 14 module reset clears the active bank to disabled
//
// CLOCKING-DISCIPLINE NOTE (same lesson as every testbench in this project):
// stimulus changes are applied #1 after a sampling edge, never in the same
// delta.

`timescale 1ns/1ps

module rtl014_integration_tb;

  import dfc_constants_pkg::*;
  import dfc_registers_pkg::*;

  logic core_clk_i = 0;
  logic core_rst_n_i;
  always #10 core_clk_i = ~core_clk_i;  // 50 MHz nominal (ARCH-CLK-001)

  logic        dri_req_valid_i, dri_req_ready_o, dri_req_write_i;
  logic [31:0] dri_req_addr_i, dri_req_wdata_i;
  logic [3:0]  dri_req_wstrb_i;
  logic        dri_rsp_valid_o, dri_rsp_ready_i = 1'b1;
  logic [31:0] dri_rsp_rdata_o;
  logic [2:0]  dri_rsp_code_o;
  logic        dbg_regbank_write_en_o;

  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] rtl006_control;
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  rtl006_status;
  logic [dfc_types_pkg::DFC_RTL013_CONTROL_WIDTH-1:0] rtl013_control;
  logic [dfc_types_pkg::DFC_RTL013_STATUS_WIDTH-1:0]  rtl013_status;
  logic [dfc_types_pkg::DFC_RTL014_CONTROL_WIDTH-1:0] rtl014_control;
  logic [dfc_types_pkg::DFC_RTL014_STATUS_WIDTH-1:0]  rtl014_status;

  // Out-of-scope siblings: disclosed stubs (same isolation choice as every
  // prior module-specific integration testbench).
  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0] rtl002_control_unused;
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]  rtl002_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL003_CONTROL_WIDTH-1:0] rtl003_control_unused;
  logic [dfc_types_pkg::DFC_RTL003_STATUS_WIDTH-1:0]  rtl003_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL004_CONTROL_WIDTH-1:0] rtl004_control_unused;
  logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0]  rtl004_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL005_CONTROL_WIDTH-1:0] rtl005_control_unused;
  logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0]  rtl005_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL007_CONTROL_WIDTH-1:0] rtl007_control_unused;
  logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0]  rtl007_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL008_CONTROL_WIDTH-1:0] rtl008_control_unused;
  logic [dfc_types_pkg::DFC_RTL008_STATUS_WIDTH-1:0]  rtl008_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL009_CONTROL_WIDTH-1:0] rtl009_control_unused;
  logic [dfc_types_pkg::DFC_RTL009_STATUS_WIDTH-1:0]  rtl009_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL010_CONTROL_WIDTH-1:0] rtl010_control_unused;
  logic [dfc_types_pkg::DFC_RTL010_STATUS_WIDTH-1:0]  rtl010_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL011_CONTROL_WIDTH-1:0] rtl011_control_unused;
  logic [dfc_types_pkg::DFC_RTL011_STATUS_WIDTH-1:0]  rtl011_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL012_CONTROL_WIDTH-1:0] rtl012_control_unused;
  logic [dfc_types_pkg::DFC_RTL012_STATUS_WIDTH-1:0]  rtl012_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL001_STATUS_WIDTH-1:0]  rtl001_status_unused;

  dfc_rtl001 u_rtl001 (
    .core_clk_i             (core_clk_i),
    .core_rst_n_i           (core_rst_n_i),
    .dri_req_valid_i        (dri_req_valid_i),
    .dri_req_ready_o        (dri_req_ready_o),
    .dri_req_write_i        (dri_req_write_i),
    .dri_req_addr_i         (dri_req_addr_i),
    .dri_req_wdata_i        (dri_req_wdata_i),
    .dri_req_wstrb_i        (dri_req_wstrb_i),
    .dri_rsp_valid_o        (dri_rsp_valid_o),
    .dri_rsp_ready_i        (dri_rsp_ready_i),
    .dri_rsp_rdata_o        (dri_rsp_rdata_o),
    .dri_rsp_code_o         (dri_rsp_code_o),
    .rtl002_control_o       (rtl002_control_unused),
    .rtl002_status_i        (rtl002_status_stub),
    .rtl003_control_o       (rtl003_control_unused),
    .rtl003_status_i        (rtl003_status_stub),
    .rtl004_control_o       (rtl004_control_unused),
    .rtl004_status_i        (rtl004_status_stub),
    .rtl005_control_o       (rtl005_control_unused),
    .rtl005_status_i        (rtl005_status_stub),
    .rtl006_control_o       (rtl006_control),
    .rtl006_status_i        (rtl006_status),
    .rtl007_control_o       (rtl007_control_unused),
    .rtl007_status_i        (rtl007_status_stub),
    .rtl008_control_o       (rtl008_control_unused),
    .rtl008_status_i        (rtl008_status_stub),
    .rtl009_control_o       (rtl009_control_unused),
    .rtl009_status_i        (rtl009_status_stub),
    .rtl010_control_o       (rtl010_control_unused),
    .rtl010_status_i        (rtl010_status_stub),
    .rtl011_control_o       (rtl011_control_unused),
    .rtl011_status_i        (rtl011_status_stub),
    .rtl012_control_o       (rtl012_control_unused),
    .rtl012_status_i        (rtl012_status_stub),
    .rtl013_control_o       (rtl013_control),
    .rtl013_status_i        (rtl013_status),
    .rtl014_control_o       (rtl014_control),
    .rtl014_status_i        (rtl014_status),
    .status_o               (rtl001_status_unused),
    .dbg_regbank_write_en_o (dbg_regbank_write_en_o)
  );

  logic [63:0] tb_timestamp = 64'h0;
  always @(posedge core_clk_i) tb_timestamp <= tb_timestamp + 64'd1;

  // ---- real term producer: RTL-006 (GPIO) ----
  logic [7:0] tb_gpio_i = 8'h00;
  logic [7:0] rtl006_gpio_o, rtl006_gpio_oe;
  logic       rtl006_evt_valid, rtl006_irq_req;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl006_evt_record;

  dfc_rtl006 u_rtl006 (
    .core_clk_i                     (core_clk_i),
    .core_rst_n_i                   (core_rst_n_i),
    .module_reset_i                 (1'b0),
    .control_i                      (rtl006_control),
    .status_o                       (rtl006_status),
    .timestamp_i                    (tb_timestamp),
    .evt_valid_o                    (rtl006_evt_valid),
    .evt_ready_i                    (1'b1),
    .evt_record_o                   (rtl006_evt_record),
    .irq_req_o                      (rtl006_irq_req),
    .gpio_i                         (tb_gpio_i),
    .gpio_o                         (rtl006_gpio_o),
    .gpio_oe_o                      (rtl006_gpio_oe),
    .operating_state_i              (dfc_types_pkg::NORMAL),
    .observational_mode_i           (1'b0),
    .route_gpio_req_i               (8'h0),
    .module_enable_i                (1'b1),
    .effective_operational_enable_i (1'b1),
    .event_condition_enable_i       (64'h0),
    .irq_condition_enable_i         (64'h0)
  );

  // ---- term vector, assembled and registered as dfc_rtl024.sv does ----
  logic [63:0] tb_source_vector_comb, tb_source_vector_q;
  always_comb begin
    tb_source_vector_comb = 64'h0;
    tb_source_vector_comb[8:1] = rtl006_status[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_QUAL_IN__QUAL_INPUT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_QUAL_IN__QUAL_INPUT_LO];
    tb_source_vector_comb[37]  = 1'b1;
  end
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) tb_source_vector_q <= 64'h0;
    else               tb_source_vector_q <= tb_source_vector_comb;
  end

  // ---- DUT ----
  logic tb_module_reset = 1'b0;
  logic tb_evt_ready    = 1'b1;
  logic rtl014_evt_valid, rtl014_irq_req, rtl014_fault_req;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl014_evt_record;
  logic [7:0] rtl014_satisfied, rtl014_inhibit;
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] rtl014_response;

  dfc_rtl014 u_rtl014 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n_i),
    .module_reset_i           (tb_module_reset),
    .control_i                (rtl014_control),
    .status_o                 (rtl014_status),
    .timestamp_i              (tb_timestamp),
    .evt_valid_o              (rtl014_evt_valid),
    .evt_ready_i              (tb_evt_ready),
    .evt_record_o             (rtl014_evt_record),
    .irq_req_o                (rtl014_irq_req),
    .fault_req_o              (rtl014_fault_req),
    .interlock_terms_i        (tb_source_vector_q),
    .interlock_satisfied_o    (rtl014_satisfied),
    .interlock_inhibit_o      (rtl014_inhibit),
    .response_req_o           (rtl014_response),
    .operating_state_i        (dfc_types_pkg::NORMAL),
    .observational_mode_i     (1'b0),
    .event_condition_enable_i (64'hFFFF_FFFF_FFFF_FFFF),
    .irq_condition_enable_i   (64'hFFFF_FFFF_FFFF_FFFF)
  );

  // ---- real fault consumer: RTL-013, RTL-014 on fault_source_i[1] ----
  logic rtl013_evt_valid, rtl013_irq_req, rtl013_degraded_req, rtl013_faulted_req;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl013_evt_record;
  dfc_rtl013 u_rtl013 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n_i),
    .module_reset_i           (1'b0),
    .control_i                (rtl013_control),
    .status_o                 (rtl013_status),
    .timestamp_i              (tb_timestamp),
    .evt_valid_o              (rtl013_evt_valid),
    .evt_ready_i              (1'b1),
    .evt_record_o             (rtl013_evt_record),
    .irq_req_o                (rtl013_irq_req),
    .fault_source_i           ({30'h0, rtl014_fault_req, 1'b0}),
    .degraded_req_o           (rtl013_degraded_req),
    .faulted_req_o            (rtl013_faulted_req),
    .operating_state_i        (dfc_types_pkg::NORMAL),
    .observational_mode_i     (1'b0),
    .response_req_o           (),
    .safety_inhibit_o         (),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ---- white-box observation (verification only) ----
  wire [7:0] viol_active   = rtl014_status[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__VIOLATION_ACTIVE_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_STATUS__VIOLATION_ACTIVE_LO];
  wire [7:0] guard_allowed = rtl014_status[dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESULT__GUARD_ALLOWED_HI:dfc_types_pkg::DFC_RTL014_STATUS__ILOCK_ACTIVE_RESULT__GUARD_ALLOWED_LO];
  wire       resp_valid    = rtl014_response[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI];
  wire [2:0] resp_source   = rtl014_response[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_LO];
  wire [3:0] resp_mask     = rtl014_response[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_LO];

  // VP-SAFE-007 same-edge monitor, armed while entry 0 is the only enabled
  // entry with guard mask 0x01 and latch off: on EVERY edge, guard 0's
  // permission (allowed / not inhibited) must be the exact complement of
  // entry 0's violation_active. Any cycle where they disagree is the
  // prohibited one-cycle window.
  logic tb_same_edge_armed = 1'b0;
  int   same_edge_mismatches = 0;
  int   same_edge_transitions = 0;
  logic prev_viol0 = 1'b0;
  always @(posedge core_clk_i) begin
    #1;
    if (tb_same_edge_armed) begin
      if ((guard_allowed[0] !== ~viol_active[0]) || (rtl014_inhibit[0] !== viol_active[0]) ||
          (resp_valid !== viol_active[0]))
        same_edge_mismatches++;
      if (viol_active[0] !== prev_viol0) same_edge_transitions++;
    end
    prev_viol0 = viol_active[0];
  end

  // Accepted-event capture (verification aid).
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] last_evt = '0;
  int evt_count = 0;
  always @(posedge core_clk_i) begin
    if (rtl014_evt_valid && tb_evt_ready) begin
      last_evt <= rtl014_evt_record;
      evt_count <= evt_count + 1;
    end
  end
  wire [15:0] last_evt_id      = last_evt[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO];
  wire [31:0] last_evt_data    = last_evt[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO];

  int errors = 0, checks = 0;
  task automatic check(string what, logic [31:0] got, logic [31:0] expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got 0x%08h, expected 0x%08h", what, got, expected);
    end else $display("PASS: %s -- 0x%08h", what, got);
    $fflush();
  endtask
  task automatic check_bit(string what, logic got, logic expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got %b, expected %b", what, got, expected);
    end else $display("PASS: %s", what);
    $fflush();
  endtask

  task automatic dri_write(input logic [31:0] addr, input logic [31:0] data,
                            output logic [2:0] code);
    dri_req_addr_i  = addr;
    dri_req_wdata_i = data;
    dri_req_wstrb_i = 4'hF;
    dri_req_write_i = 1'b1;
    dri_req_valid_i = 1'b1;
    @(posedge core_clk_i);
    while (!dri_req_ready_o) @(posedge core_clk_i);
    #1;
    dri_req_valid_i = 1'b0;
    @(posedge core_clk_i); #1;
    code = dri_rsp_code_o;
  endtask

  task automatic dri_read(input logic [31:0] addr, output logic [31:0] data,
                           output logic [2:0] code);
    dri_req_addr_i  = addr;
    dri_req_write_i = 1'b0;
    dri_req_wstrb_i = 4'h0;
    dri_req_valid_i = 1'b1;
    @(posedge core_clk_i);
    while (!dri_req_ready_o) @(posedge core_clk_i);
    #1;
    dri_req_valid_i = 1'b0;
    @(posedge core_clk_i); #1;
    data = dri_rsp_rdata_o;
    code = dri_rsp_code_o;
  endtask

  task automatic wait_cycles(input int n);
    repeat (n) @(posedge core_clk_i);
    #1;
  endtask

  task automatic protected_write(input logic [31:0] addr, input logic [31:0] data,
                                  output logic [2:0] code);
    logic [2:0] c;
    dri_write(DFC_ADDR_PROTECT_KEY, DFC_PROTECT_KEY1, c);
    dri_write(DFC_ADDR_PROTECT_KEY, DFC_PROTECT_KEY2, c);
    dri_write(addr, data, code);
  endtask

  logic [2:0]  code;
  logic [31:0] rdata;
  logic [7:0]  bad_id;
  logic [2:0]  op_v;

  // Stage one complete entry (selector first, then every stage register).
  task automatic stage_entry(input int e, input logic [31:0] terms,
                             input logic [3:0] inv, input logic [2:0] op,
                             input logic [7:0] guard, input logic [3:0] en_bits,
                             input logic [3:0] resp);
    logic [2:0] c;
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, e, c);
    dri_write(DFC_ADDR_ILOCK_STAGE_TERMS, terms, c);
    dri_write(DFC_ADDR_ILOCK_STAGE_LOGIC, {25'h0, op, inv}, c);
    dri_write(DFC_ADDR_ILOCK_STAGE_GUARD, {24'h0, guard}, c);
    dri_write(DFC_ADDR_ILOCK_STAGE_ENABLE, {28'h0, en_bits}, c);
    dri_write(DFC_ADDR_ILOCK_STAGE_RESPONSE, {28'h0, resp}, c);
  endtask

  task automatic stage_all_disabled();
    for (int e = 0; e < 8; e++) stage_entry(e, 32'h0, 4'h0, 3'd0, 8'h00, 4'h0, 4'h0);
  endtask

  task automatic commit_all(output logic [2:0] code);
    protected_write(DFC_ADDR_ILOCK_VALIDATE_COMMIT, 32'h1, code);
    wait_cycles(4);
  endtask

  task automatic clear_commit_flags();
    logic [2:0] c;
    dri_write(DFC_ADDR_ILOCK_STATUS, 32'h0003_0000, c);
  endtask

  task automatic set_gpio(input logic [7:0] v);
    tb_gpio_i = v;
    wait_cycles(8);   // sync (2) + qual (1) + vector register (1) + eval (1), with margin
  endtask

  // Record the cycle at which the active bank and the violation flag change,
  // for the "no grace period" check (ARCH-RTL014-001).
  // Both observations sample registered values at the same point of the
  // same edge, so "violation register set one edge after the active-bank
  // register changed" reads as a difference of exactly 1.
  int cycle = 0;
  int active_change_cycle = -1, viol_change_cycle = -1;
  logic tb_track_grace = 1'b0;
  logic [7:0] prev_viol_track = 8'h00;
  logic [8*55-1:0] prev_active_track = '0;
  always @(posedge core_clk_i) begin
    cycle <= cycle + 1;
    if (tb_track_grace) begin
      if ((u_rtl014.active_q != prev_active_track) && active_change_cycle < 0) active_change_cycle <= cycle;
      if (viol_active[0] && !prev_viol_track[0] && viol_change_cycle < 0) viol_change_cycle <= cycle;
    end
    prev_viol_track   <= viol_active;
    prev_active_track <= u_rtl014.active_q;
  end

  initial begin
    dri_req_valid_i = 1'b0;
    dri_req_write_i = 1'b0;
    dri_req_addr_i  = '0;
    dri_req_wdata_i = '0;
    dri_req_wstrb_i = '0;
    core_rst_n_i = 0;
    repeat (2) @(posedge core_clk_i);
    #1;

    // ==========================================================================
    // Part 1: reset state (ARCH-RTL014-001, Appendix A reset values, D.1).
    // ==========================================================================
    check("interlock_inhibit_o is all ones during reset (Appendix A reset 1)", {24'h0, rtl014_inhibit}, 32'h0000_00FF);
    check("interlock_satisfied_o is zero during reset", {24'h0, rtl014_satisfied}, 32'h0);
    check_bit("response_req_o.valid is zero during reset", resp_valid, 1'b0);
    core_rst_n_i = 1;
    wait_cycles(4);
    check_bit("status_o.ready asserts after reset release with no enable write (mandatory)",
              rtl014_status[dfc_types_pkg::DFC_RTL014_STATUS__READY_HI], 1'b1);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check("ILOCK_STATUS reads all clear after reset", rdata, 32'h0);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_RESULT, rdata, code);
    check("ILOCK_ACTIVE_RESULT: no entry true, every guard allowed (no enabled entry)", rdata, 32'h0000_FF00);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd3, code);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_ENABLE, rdata, code);
    check("reset clears every active entry to disabled (entry 3 ACTIVE_ENABLE)", rdata, 32'h0);

    // ==========================================================================
    // Part 2: protection (REG-3200/REG-321C Protection: Yes).
    // ==========================================================================
    dri_write(DFC_ADDR_ILOCK_CONTROL, 32'h1, code);
    check("ILOCK_CONTROL write without PROTECT_KEY rejected (PROTECTED_ERROR)", {29'h0, code}, 32'h3);
    dri_write(DFC_ADDR_ILOCK_VALIDATE_COMMIT, 32'h1, code);
    check("COMMIT_ALL without PROTECT_KEY rejected (PROTECTED_ERROR)", {29'h0, code}, 32'h3);
    wait_cycles(4);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check("a protection-rejected COMMIT_ALL produces no commit result", rdata[17:16], 2'b00);
    protected_write(DFC_ADDR_ILOCK_CONTROL, 32'h0000_0007, code);  // ENABLE, EVENT_ENABLE, IRQ_ENABLE
    check("ILOCK_CONTROL protected write with valid auth -> OK", {29'h0, code}, 32'h0);
    dri_write(DFC_ADDR_ILOCK_ACTIVE_TERMS, 32'h1, code);
    check("pure-RO ILOCK_ACTIVE_TERMS write rejected (ACCESS_ERROR)", {29'h0, code}, 32'h2);

    // ==========================================================================
    // Part 3: selector-indexed staging (REG-COH-001, REG-3228, VP-SAFE-016).
    // ==========================================================================
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd2, code);
    dri_write(DFC_ADDR_ILOCK_STAGE_TERMS, 32'h0102_0304, code);
    dri_write(DFC_ADDR_ILOCK_STAGE_RESPONSE, 32'h5, code);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd5, code);
    dri_write(DFC_ADDR_ILOCK_STAGE_TERMS, 32'h0506_0708, code);
    dri_write(DFC_ADDR_ILOCK_STAGE_RESPONSE, 32'hA, code);
    dri_read(DFC_ADDR_ILOCK_STAGE_TERMS, rdata, code);
    check("STAGE_TERMS reads entry 5's own staged value", rdata, 32'h0506_0708);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd2, code);
    dri_read(DFC_ADDR_ILOCK_STAGE_TERMS, rdata, code);
    check("selector change did not disturb entry 2's staged terms (REG-COH-001)", rdata, 32'h0102_0304);
    dri_read(DFC_ADDR_ILOCK_STAGE_RESPONSE, rdata, code);
    check("STAGE_RESPONSE reads the selected entry's staged mask (REG-3228)", rdata, 32'h5);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd5, code);
    dri_read(DFC_ADDR_ILOCK_STAGE_RESPONSE, rdata, code);
    check("entry 5 keeps its own distinct staged response mask", rdata, 32'hA);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_TERMS, rdata, code);
    check("staged writes alone do not alter the active bank (RTLSTD-REG-010)", rdata, 32'h0);

    // ==========================================================================
    // Part 4: commit, full active readback, no grace period.
    // Entry 0: terms GPIO0..3 (IDs 1,2,3,4), AND, no inversion, guard 0x01,
    // enable+event+irq (0b1101), response mask 0x3. Every other entry
    // disabled. GPIO all low => the expression is false the moment it is
    // committed.
    // ==========================================================================
    stage_all_disabled();
    stage_entry(0, 32'h0403_0201, 4'h0, 3'd0, 8'h01, 4'b1101, 4'h3);
    tb_track_grace = 1'b1;
    commit_all(code);
    check("COMMIT_ALL protected write -> OK", {29'h0, code}, 32'h0);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("ILOCK_STATUS.COMMIT_COMPLETE sets on a legal bank", rdata[16], 1'b1);
    check_bit("ILOCK_STATUS.COMMIT_REJECTED stays clear", rdata[17], 1'b0);
    check_bit("violation on the freshly committed bank is active", rdata[0], 1'b1);
    check("violation asserted on the very next edge after the bank replacement (no grace period)",
          viol_change_cycle - active_change_cycle, 32'd1);
    tb_track_grace = 1'b0;
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd0, code);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_TERMS, rdata, code);
    check("ILOCK_ACTIVE_TERMS reads entry 0's committed term IDs", rdata, 32'h0403_0201);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_LOGIC, rdata, code);
    check("ILOCK_ACTIVE_LOGIC reads entry 0's committed operator/inversion", rdata, 32'h0);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_GUARD, rdata, code);
    check("ILOCK_ACTIVE_GUARD reads entry 0's committed guard mask", rdata, 32'h01);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_ENABLE, rdata, code);
    check("ILOCK_ACTIVE_ENABLE reads entry 0's committed enable/policy bits", rdata, 32'hD);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_RESPONSE, rdata, code);
    check("ILOCK_ACTIVE_RESPONSE reads entry 0's committed response mask (VP-SAFE-016)", rdata, 32'h3);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_RESULT, rdata, code);
    check("GUARD_ALLOWED drops guard 0 only; ENTRY_TRUE clear", rdata, 32'h0000_FE00);
    check("interlock_inhibit_o inhibits exactly guard 0", {24'h0, rtl014_inhibit}, 32'h01);
    check_bit("lane-2 response_req_o.valid asserts", resp_valid, 1'b1);
    check("lane-2 response_req_o.source_id = entry 0", {29'h0, resp_source}, 32'd0);
    check("lane-2 response_req_o.response_mask = entry 0's mask", {28'h0, resp_mask}, 32'h3);
    check_bit("irq_req_o asserts for an IRQ-enabled live violation", rtl014_irq_req, 1'b1);

    // ==========================================================================
    // Part 5 + Part 6: operators and inversion through real GPIO terms, with
    // the same-edge monitor armed for the whole sweep.
    // ==========================================================================
    tb_same_edge_armed = 1'b1;
    set_gpio(8'h07);
    check_bit("AND: 0111 is false -> violation", viol_active[0], 1'b1);
    set_gpio(8'h0F);
    check_bit("AND: 1111 is true -> no violation", viol_active[0], 1'b0);
    check("ENTRY_TRUE / interlock_satisfied_o[0] set when the expression holds", {24'h0, rtl014_satisfied}, 32'h01);
    check("guard 0 allowed again (inhibit clear)", {24'h0, rtl014_inhibit}, 32'h00);

    stage_entry(0, 32'h0403_0201, 4'h0, 3'd1, 8'h01, 4'b1101, 4'h3);  // OR
    commit_all(code);
    set_gpio(8'h00);
    check_bit("OR: 0000 is false -> violation", viol_active[0], 1'b1);
    set_gpio(8'h08);
    check_bit("OR: 1000 is true -> no violation", viol_active[0], 1'b0);

    stage_entry(0, 32'h0403_0201, 4'h0, 3'd2, 8'h01, 4'b1101, 4'h3);  // 3-of-4
    commit_all(code);
    set_gpio(8'h03);
    check_bit("3-of-4: 0011 is false -> violation", viol_active[0], 1'b1);
    set_gpio(8'h0B);
    check_bit("3-of-4: 1011 is true -> no violation", viol_active[0], 1'b0);

    stage_entry(0, 32'h0403_0201, 4'h0, 3'd3, 8'h01, 4'b1101, 4'h3);  // (t0&t1)|(t2&t3)
    commit_all(code);
    set_gpio(8'h05);
    check_bit("(t0&t1)|(t2&t3): 0101 is false -> violation", viol_active[0], 1'b1);
    set_gpio(8'h0C);
    check_bit("(t0&t1)|(t2&t3): 1100 is true -> no violation", viol_active[0], 1'b0);
    set_gpio(8'h03);
    check_bit("(t0&t1)|(t2&t3): 0011 is true -> no violation", viol_active[0], 1'b0);

    stage_entry(0, 32'h0403_0201, 4'b0001, 3'd0, 8'h01, 4'b1101, 4'h3);  // AND, t0 inverted
    commit_all(code);
    set_gpio(8'h0E);
    check_bit("inversion: AND(!t0,t1,t2,t3) with 1110 is true", viol_active[0], 1'b0);
    set_gpio(8'h0F);
    check_bit("inversion: AND(!t0,t1,t2,t3) with 1111 is false -> violation", viol_active[0], 1'b1);

    stage_entry(0, 32'h2525_2525, 4'h0, 3'd0, 8'h01, 4'b1101, 4'h3);  // ID 37 x4 (constant true)
    commit_all(code);
    check_bit("constant-true term (ID 37): AND is true", viol_active[0], 1'b0);
    stage_entry(0, 32'h2525_2500, 4'h0, 3'd0, 8'h01, 4'b1101, 4'h3);  // ID 0 (constant false) in t0
    commit_all(code);
    check_bit("constant-false term (ID 0): AND is false -> violation", viol_active[0], 1'b1);

    tb_same_edge_armed = 1'b0;
    check("VP-SAFE-007: zero cycles where guard 0 / response disagreed with violation_active",
          same_edge_mismatches, 32'd0);
    check_bit("VP-SAFE-007 monitor genuinely observed violation transitions", (same_edge_transitions >= 10), 1'b1);

    // ==========================================================================
    // Part 7: whole-bank atomicity, first error, every illegal class.
    // Baseline active bank: entry 0 as committed above, entry 3 = AND of
    // four constant-true terms, guard 0x08.
    // ==========================================================================
    stage_entry(3, 32'h2525_2525, 4'h0, 3'd0, 8'h08, 4'b0001, 4'h0);
    commit_all(code);
    clear_commit_flags();
    // Entries 0-6 legal (entry 6 newly enabled), entry 7 TERM0 = 32 (illegal).
    stage_entry(6, 32'h0101_0101, 4'h0, 3'd1, 8'h40, 4'b0001, 4'h1);
    stage_entry(7, 32'h0000_0020, 4'h0, 3'd0, 8'h00, 4'b0000, 4'h0);
    commit_all(code);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("entry 7 illegal: COMMIT_REJECTED sets", rdata[17], 1'b1);
    check_bit("entry 7 illegal: COMMIT_COMPLETE does not set", rdata[16], 1'b0);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd6, code);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_ENABLE, rdata, code);
    check("whole-bank reject: legal entry 6 was NOT committed", rdata, 32'h0);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd3, code);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_TERMS, rdata, code);
    check("whole-bank reject: prior active entry 3 preserved", rdata, 32'h2525_2525);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd7, code);
    dri_read(DFC_ADDR_ILOCK_STAGE_TERMS, rdata, code);
    check("whole-bank reject: staged bank preserved (REG-COH-003)", rdata, 32'h0000_0020);
    check("reject event 0x0042 subtype 3 / entry 7 / code 1 (TERM0)", {last_evt_id, last_evt_data[15:0]}, {16'h0042, 16'h0703});
    check("reject event detail carries error code 1", {16'h0, last_evt_data[31:16]}, 32'd1);

    // First error in ENTRY order: entry 2 OPERATOR=5 and entry 5 TERM1=40.
    clear_commit_flags();
    stage_entry(7, 32'h0, 4'h0, 3'd0, 8'h00, 4'b0000, 4'h0);       // repair entry 7
    stage_entry(2, 32'h0, 4'h0, 3'd5, 8'h00, 4'b0000, 4'h0);
    stage_entry(5, 32'h0000_2800, 4'h0, 3'd0, 8'h00, 4'b0000, 4'h0);
    commit_all(code);
    check("first error is the LOWEST entry (2, operator code 5), not entry 5",
          {last_evt_data[31:16], last_evt_data[15:0]}, {16'd5, 16'h0203});
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check("host-readable ILOCK_STATUS.FIRST_ERROR_ENTRY/CODE = entry 2 / code 5 (REG-COH-003)",
          {25'h0, rdata[24:21], rdata[20:18]}, {25'h0, 4'd5, 3'd2});
    // First error in FIELD order within one entry: TERM2 illegal AND zero guard while enabled.
    stage_entry(2, 32'h0024_0000, 4'h0, 3'd0, 8'h00, 4'b0001, 4'h0);  // TERM2 = 36
    stage_entry(5, 32'h0, 4'h0, 3'd0, 8'h00, 4'b0000, 4'h0);
    commit_all(code);
    check("first error is the earliest FIELD (TERM2, code 3) before the guard cross-check",
          {last_evt_data[31:16], last_evt_data[15:0]}, {16'd3, 16'h0203});
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check("FIRST_ERROR is RETAINED across a second rejection while COMMIT_REJECTED is set (still entry 2 / code 5)",
          {25'h0, rdata[24:21], rdata[20:18]}, {25'h0, 4'd5, 3'd2});
    clear_commit_flags();
    wait_cycles(2);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check("clearing COMMIT_REJECTED clears FIRST_ERROR_ENTRY/CODE", {25'h0, rdata[24:21], rdata[20:18]}, 32'h0);
    commit_all(code);   // same illegal bank again
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check("next rejection after the clear captures the new first error (entry 2 / TERM2 code 3)",
          {25'h0, rdata[24:21], rdata[20:18]}, {25'h0, 4'd3, 3'd2});

    // Each illegal class rejects; each legal boundary accepts.
    stage_entry(2, 32'h0, 4'h0, 3'd0, 8'h00, 4'b0000, 4'h0);
    for (int k = 0; k < 6; k++) begin
      case (k)
        0: bad_id = 8'd32;   // self-reference
        1: bad_id = 8'd33;   // user-logic feedback
        2: bad_id = 8'd36;
        3: bad_id = 8'd38;   // reserved
        4: bad_id = 8'd63;
        default: bad_id = 8'd255;
      endcase
      clear_commit_flags();
      stage_entry(4, {24'h0, bad_id}, 4'h0, 3'd0, 8'h00, 4'b0000, 4'h0);
      commit_all(code);
      dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
      check_bit($sformatf("term ID %0d rejected at COMMIT_ALL", bad_id), rdata[17:16] == 2'b10, 1'b1);
    end
    for (int k = 4; k < 8; k++) begin
      clear_commit_flags();
      op_v = k;
      stage_entry(4, 32'h0, 4'h0, op_v, 8'h00, 4'b0000, 4'h0);
      commit_all(code);
      dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
      check_bit($sformatf("operator %0d rejected at COMMIT_ALL", k), rdata[17:16] == 2'b10, 1'b1);
    end
    clear_commit_flags();
    stage_entry(4, 32'h0, 4'h0, 3'd0, 8'h00, 4'b0001, 4'h0);
    commit_all(code);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("enabled entry with zero guard mask rejected (REG-ENC-010)", rdata[17:16] == 2'b10, 1'b1);
    clear_commit_flags();
    stage_entry(4, 32'h251F_0100, 4'hF, 3'd3, 8'h00, 4'b0000, 4'hF);  // IDs 0,1,31,37; disabled, zero guard
    commit_all(code);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("boundary IDs 0/1/31/37, operator 3, disabled zero-guard entry all accepted", rdata[17:16] == 2'b01, 1'b1);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd6, code);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_ENABLE, rdata, code);
    check("successful commit replaced the WHOLE bank (entry 6 now active)", rdata, 32'h1);
    check_bit("accept event 0x0042 subtype 2 recorded", (last_evt_id == 16'h0042) && (last_evt_data[7:0] == 8'd2), 1'b1);

    // ==========================================================================
    // Part 8: sticky evidence. Recommit a clean bank: entry 0 = AND of
    // GPIO0..3, guard 0x01, latch off.
    // ==========================================================================
    stage_all_disabled();
    stage_entry(0, 32'h0403_0201, 4'h0, 3'd0, 8'h01, 4'b1101, 4'h3);
    commit_all(code);
    set_gpio(8'h00);                                   // violation live
    dri_write(DFC_ADDR_ILOCK_STATUS, 32'h0000_0100, code);  // clear sticky bit 0
    wait_cycles(2);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("VIOLATION_STICKY clear is ineffective while the violation is live", rdata[8], 1'b1);
    set_gpio(8'h0F);                                   // violation clears
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("VIOLATION_ACTIVE clears with the live condition", rdata[0], 1'b0);
    check_bit("VIOLATION_STICKY retains the evidence", rdata[8], 1'b1);
    dri_write(DFC_ADDR_ILOCK_STATUS, 32'h0000_0100, code);
    wait_cycles(2);
    dri_read(DFC_ADDR_ILOCK_STATUS, rdata, code);
    check_bit("VIOLATION_STICKY clears once the violation is inactive", rdata[8], 1'b0);

    // ==========================================================================
    // Part 9: LATCH_VIOLATION policy (header item 4).
    // ==========================================================================
    stage_entry(0, 32'h0403_0201, 4'h0, 3'd0, 8'h01, 4'b1111, 4'h3);  // latch on
    commit_all(code);
    set_gpio(8'h00);
    set_gpio(8'h0F);                                   // condition gone again
    check_bit("latched: guard 0 stays inhibited after the live violation clears", rtl014_inhibit[0], 1'b1);
    check_bit("latched: lane-2 request stays asserted", resp_valid, 1'b1);
    check_bit("latched: VIOLATION_ACTIVE itself reports the live (clear) condition", viol_active[0], 1'b0);
    dri_write(DFC_ADDR_ILOCK_STATUS, 32'h0000_0100, code);
    wait_cycles(3);
    check_bit("latched: host sticky clear releases guard 0", rtl014_inhibit[0], 1'b0);
    check_bit("latched: host sticky clear releases the lane-2 request", resp_valid, 1'b0);

    // ==========================================================================
    // Part 10: simultaneous violations -> lane-2 source priority.
    // Entries 1 (mask 0 -> requests nothing), 3 (mask 0x4), 5 (mask 0x2),
    // all AND of GPIO4..7 with per-entry EVENT_ENABLE on; entry 0 disabled.
    // ==========================================================================
    stage_all_disabled();
    stage_entry(1, 32'h0807_0605, 4'h0, 3'd0, 8'h02, 4'b0101, 4'h0);
    stage_entry(3, 32'h0807_0605, 4'h0, 3'd0, 8'h08, 4'b0101, 4'h4);
    stage_entry(5, 32'h0807_0605, 4'h0, 3'd0, 8'h20, 4'b0101, 4'h2);
    commit_all(code);
    set_gpio(8'h00);
    check("three simultaneous violations (entries 1/3/5)", {24'h0, viol_active}, 32'h0000_002A);
    check("each violated entry inhibits only its own guard", {24'h0, rtl014_inhibit}, 32'h0000_002A);
    check("lane-2 source = lowest violated entry WITH a nonzero mask (3, not 1)", {29'h0, resp_source}, 32'd3);
    check("lane-2 mask = entry 3's mask", {28'h0, resp_mask}, 32'h4);
    check_bit("lane-2 source_id is structurally within 0-7 (RTLSTD-SAFE-014)", resp_source <= 3'd7, 1'b1);

    // ==========================================================================
    // Part 11: ILOCK_CONTROL.ENABLE=0 releases every violation and guard.
    // ==========================================================================
    protected_write(DFC_ADDR_ILOCK_CONTROL, 32'h0000_0006, code);  // ENABLE=0
    wait_cycles(3);
    check("ENABLE=0: no live violation", {24'h0, viol_active}, 32'h0);
    check("ENABLE=0: every guard allowed", {24'h0, rtl014_inhibit}, 32'h0);
    check_bit("ENABLE=0: no lane-2 request", resp_valid, 1'b0);
    protected_write(DFC_ADDR_ILOCK_CONTROL, 32'h0000_0007, code);  // ENABLE=1
    wait_cycles(3);
    check("ENABLE=1 again: violations re-qualify immediately", {24'h0, viol_active}, 32'h0000_002A);

    // ==========================================================================
    // Part 12: fault_req_o -> real RTL-013 fault_source_i[1] (C.6).
    // ==========================================================================
    protected_write(DFC_ADDR_FAULT_CONTROL, 32'h0000_0001, code);
    wait_cycles(3);
    check_bit("fault_req_o asserts with a live violation", rtl014_fault_req, 1'b1);
    dri_read(DFC_ADDR_FAULT_ACTIVE_SOURCE, rdata, code);
    check_bit("real RTL-013 sees fault source 1 (Interlock violation) ACTIVE", rdata[1], 1'b1);
    dri_read(DFC_ADDR_FAULT_CLASS, rdata, code);
    check("real RTL-013 classifies it as class 0x04 (safety supervision)", rdata[7:0], 8'h04);
    check_bit("RTL-013 faulted_req_o stays low for this recoverable source", rtl013_faulted_req, 1'b0);

    // ==========================================================================
    // Part 13: event 0x0042 + EVENT_OVERFLOW round trip.
    // ==========================================================================
    set_gpio(8'hF0);   // all three violations recover in the same cycle
    check("recovery event 0x0042 subtype 1 recorded for the lowest entry (1)",
          {last_evt_id, last_evt_data[15:0]}, {16'h0042, 16'h0101});
    tb_evt_ready = 1'b0;
    set_gpio(8'h00);   // three simultaneous violation candidates, slot blocked after the first
    set_gpio(8'hF0);
    dri_read(DFC_ADDR_RTL014_EVT_OVERFLOW_STATUS, rdata, code);
    check_bit("RTL014_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW sets on real dropped candidates", rdata[0], 1'b1);
    check_bit("RTL014_EVT_OVERFLOW_STATUS.DROP_COUNT counts the real losses", rdata[23:8] >= 16'd2, 1'b1);
    tb_evt_ready = 1'b1;
    wait_cycles(4);
    dri_write(DFC_ADDR_RTL014_EVT_OVERFLOW_STATUS, 32'h1, code);
    wait_cycles(2);
    dri_read(DFC_ADDR_RTL014_EVT_OVERFLOW_STATUS, rdata, code);
    check_bit("host clear of EVENT_OVERFLOW works (13th EVENT_OVERFLOW-clear instance)", rdata[0], 1'b0);

    // ==========================================================================
    // Part 14: module reset clears the active bank to disabled.
    // ==========================================================================
    @(posedge core_clk_i); #1;
    tb_module_reset = 1'b1;
    @(posedge core_clk_i); #1;
    tb_module_reset = 1'b0;
    wait_cycles(3);
    dri_write(DFC_ADDR_ILOCK_ENTRY_SELECT, 32'd3, code);
    dri_read(DFC_ADDR_ILOCK_ACTIVE_ENABLE, rdata, code);
    check("module reset cleared active entry 3 to disabled", rdata, 32'h0);
    set_gpio(8'h00);
    check("after module reset no entry can violate", {24'h0, viol_active}, 32'h0);

    $display("");
    $display("rtl014_integration_tb: %0d checks, %0d failures", checks, errors);
    if (errors == 0) $display("INTEGRATION TEST PASSED");
    else             $display("INTEGRATION TEST FAILED");
    $finish;
  end

endmodule
