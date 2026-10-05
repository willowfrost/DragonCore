// rtl016_integration_tb.sv -- REAL end-to-end round-trip test for RTL-016
// (Safety Output Controller): real host writes through RTL-001's real DRI
// path (including reggen.py v5's selector-indexed four-channel bank,
// reused unchanged from RTL-014/015's own sessions) must change RTL-016's
// real behavior, and RTL-016's real authorization/permission evaluation
// must reach back to host reads and the real safety_out_o pad -- same
// template as rtl002 through rtl015_integration_tb.sv.
//
// REAL PRODUCER, not forced values: lane 0 (RTL-012 watchdog) is a real
// dfc_rtl012 instance whose real WDOG_WINDOW_OPEN_US/WDOG_TIMEOUT_US/
// WDOG_CONTROL this testbench configures over the real DRI path to force a
// genuine timeout -> response_req_o. Lanes 1/2/3 (RTL-013/014/015) are
// driven directly as dfc_safety_response_req_t-shaped stimulus -- the real
// cross-module wiring for lane 2 (RTL-014) is already exhaustively proven
// in rtl024_skeleton_tb.sv's own whole-system RTL-016 section; this file's
// job is RTL-016's OWN internal authorization/permission/latch/event
// logic, not re-proving every lane's real wiring a second time (same
// "module test proves its own logic, whole-system test proves the wiring"
// split used throughout this project).
//
// Coverage map (VP-MOD-016 / VP-SAFE-009..011/014, VP-SAFE-003):
//   Part 1  reset state, ready, no outputs active
//   Part 2  protection on SAFETY_CONTROL / SAFETY_CHANNEL_CONTROL /
//           SAFETY_RESPONSE_MASK / SAFETY_INTERLOCK_MASK
//   Part 3  selector-indexed four-channel config bank (REG-COH-001)
//   Part 4  real RTL-012 (lane 0) request -> two-key authorization (item
//           96) -> full PERMIT -> EFFECTIVE -> real safety_out_o, ACTIVE_HIGH
//   Part 5  ACTIVE_HIGH=0 polarity (inactive-high pad)
//   Part 6  two-key authorization negative test (item 96)
//   Part 7  GLOBAL_INHIBIT (item 91, independent of ENABLE)
//   Part 8  CONTROLLER_DISABLED (SAFETY_CONTROL.ENABLE)
//   Part 9  CHANNEL_DISABLED, per-channel independence
//   Part 10 OBSERVATIONAL_INHIBIT
//   Part 11 TEST_INHIBIT: test_inhibit_i AND TEST_DEBUG, each independently
//           (item 93 -- this module ORs them into one combined term)
//   Part 12 INTERLOCK_INHIBIT[c] via required_interlocks + guard-indexed
//           interlock_inhibit_i (item 95); interlock_satisfied_i proven
//           genuinely unused
//   Part 13 FAULT_INHIBIT[c], genuinely per-channel (item 92)
//   Part 14 LATCH_RESPONSE policy (item 97): set/hold/clear-after-inactive/
//           re-enable-clears
//   Part 15 disabled-channel-with-stale-mask live FAULTED[c]/fault_req_o
//           (item 94/9)
//   Part 16 multiple authorized requests OR together, one cannot cancel
//           another (ARCH-RTL016-001)
//   Part 17 event 0x0044 + EVENT_OVERFLOW host read-and-clear round trip
//   Part 18 module reset clears every channel
//
// CLOCKING-DISCIPLINE NOTE (same lesson as every testbench in this
// project): stimulus changes are applied #1 after a sampling edge, never
// in the same delta. $fflush used throughout per item 63's lesson.

`timescale 1ns/1ps

module rtl016_integration_tb;

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

  logic [dfc_types_pkg::DFC_RTL012_CONTROL_WIDTH-1:0] rtl012_control;
  logic [dfc_types_pkg::DFC_RTL012_STATUS_WIDTH-1:0]  rtl012_status;
  logic [dfc_types_pkg::DFC_RTL016_CONTROL_WIDTH-1:0] rtl016_control;
  logic [dfc_types_pkg::DFC_RTL016_STATUS_WIDTH-1:0]  rtl016_status;

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
  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] rtl006_control_unused;
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  rtl006_status_stub = '0;
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
  logic [dfc_types_pkg::DFC_RTL013_CONTROL_WIDTH-1:0] rtl013_control_unused;
  logic [dfc_types_pkg::DFC_RTL013_STATUS_WIDTH-1:0]  rtl013_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL014_CONTROL_WIDTH-1:0] rtl014_control_unused;
  logic [dfc_types_pkg::DFC_RTL014_STATUS_WIDTH-1:0]  rtl014_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL015_CONTROL_WIDTH-1:0] rtl015_control_unused;
  logic [dfc_types_pkg::DFC_RTL015_STATUS_WIDTH-1:0]  rtl015_status_stub = '0;
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
    .rtl006_control_o       (rtl006_control_unused),
    .rtl006_status_i        (rtl006_status_stub),
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
    .rtl012_control_o       (rtl012_control),
    .rtl012_status_i        (rtl012_status),
    .rtl013_control_o       (rtl013_control_unused),
    .rtl013_status_i        (rtl013_status_stub),
    .rtl014_control_o       (rtl014_control_unused),
    .rtl014_status_i        (rtl014_status_stub),
    .rtl015_control_o       (rtl015_control_unused),
    .rtl015_status_i        (rtl015_status_stub),
    .rtl016_control_o       (rtl016_control),
    .rtl016_status_i        (rtl016_status),
    .status_o               (rtl001_status_unused),
    .dbg_regbank_write_en_o (dbg_regbank_write_en_o)
  );

  logic [63:0] tb_timestamp = 64'h0;
  always @(posedge core_clk_i) tb_timestamp <= tb_timestamp + 64'd1;

  // ---- real producer: RTL-012 (watchdog, lane 0) ----
  logic rtl012_evt_valid, rtl012_irq_req, rtl012_fault_req, rtl012_service_activity;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl012_evt_record;
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] rtl012_response;

  dfc_rtl012 u_rtl012 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n_i),
    .module_reset_i           (1'b0),
    .control_i                (rtl012_control),
    .status_o                 (rtl012_status),
    .timestamp_i              (tb_timestamp),
    .evt_valid_o              (rtl012_evt_valid),
    .evt_ready_i              (1'b1),
    .evt_record_o             (rtl012_evt_record),
    .irq_req_o                (rtl012_irq_req),
    .fault_req_o              (rtl012_fault_req),
    .response_req_o           (rtl012_response),
    .operating_state_i        (dfc_types_pkg::NORMAL),
    .observational_mode_i     (1'b0),
    .service_activity_o       (rtl012_service_activity),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ---- directly-driven lanes 1/2/3 (RTL-013/014/015 boundary stimulus):
  // real cross-module wiring for lane 2 already proven whole-system in
  // rtl024_skeleton_tb.sv; this file needs clean, independently-
  // controllable request sources to exercise RTL-016's own authorization/
  // permission/latch logic precisely. ----
  logic tb_lane1_valid = 1'b0;
  logic [2:0] tb_lane1_source = 3'd0;
  logic [3:0] tb_lane1_mask = 4'h0;
  logic tb_lane2_valid = 1'b0;
  logic [2:0] tb_lane2_source = 3'd0;
  logic [3:0] tb_lane2_mask = 4'h0;
  logic tb_lane3_valid = 1'b0;
  logic [2:0] tb_lane3_source = 3'd0;
  logic [3:0] tb_lane3_mask = 4'h0;

  wire [7:0] tb_lane1 = {tb_lane1_valid, tb_lane1_source, tb_lane1_mask};
  wire [7:0] tb_lane2 = {tb_lane2_valid, tb_lane2_source, tb_lane2_mask};
  wire [7:0] tb_lane3 = {tb_lane3_valid, tb_lane3_source, tb_lane3_mask};

  // ---- DUT ----
  logic tb_module_reset = 1'b0;
  logic tb_evt_ready = 1'b1;
  logic rtl016_evt_valid, rtl016_irq_req, rtl016_fault_req;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl016_evt_record;
  logic [3:0] tb_safety_out;
  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] tb_operating_state = dfc_types_pkg::NORMAL;
  logic tb_observational_mode = 1'b0;
  logic tb_effective_operational_enable = 1'b1;
  logic [3:0] tb_fault_inhibit = 4'h0;
  logic tb_test_inhibit = 1'b0;
  logic [7:0] tb_interlock_satisfied = 8'hFF;
  logic [7:0] tb_interlock_inhibit = 8'h00;

  dfc_rtl016 u_rtl016 (
    .core_clk_i                      (core_clk_i),
    .core_rst_n_i                    (core_rst_n_i),
    .module_reset_i                  (tb_module_reset),
    .control_i                       (rtl016_control),
    .status_o                        (rtl016_status),
    .timestamp_i                     (tb_timestamp),
    .evt_valid_o                     (rtl016_evt_valid),
    .evt_ready_i                     (tb_evt_ready),
    .evt_record_o                    (rtl016_evt_record),
    .irq_req_o                       (rtl016_irq_req),
    .fault_req_o                     (rtl016_fault_req),
    .response_req_i                  ({tb_lane3, tb_lane2, tb_lane1, rtl012_response}),
    .interlock_satisfied_i           (tb_interlock_satisfied),
    .interlock_inhibit_i             (tb_interlock_inhibit),
    .safety_out_o                    (tb_safety_out),
    .operating_state_i               (tb_operating_state),
    .observational_mode_i            (tb_observational_mode),
    .effective_operational_enable_i  (tb_effective_operational_enable),
    .fault_inhibit_i                 (tb_fault_inhibit),
    .test_inhibit_i                  (tb_test_inhibit),
    .event_condition_enable_i        (64'hFFFF_FFFF_FFFF_FFFF),
    .irq_condition_enable_i          (64'hFFFF_FFFF_FFFF_FFFF)
  );

  // Accepted-event capture (verification aid).
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] last_evt = '0;
  int evt_count = 0;
  always @(posedge core_clk_i) begin
    if (rtl016_evt_valid && tb_evt_ready) begin
      last_evt <= rtl016_evt_record;
      evt_count <= evt_count + 1;
    end
  end
  wire [15:0] last_evt_id   = last_evt[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO];
  wire [31:0] last_evt_data = last_evt[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO];

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

  // Select channel c, write its full config in one go (SAFETY_CHANNEL_
  // CONTROL / SAFETY_RESPONSE_MASK / SAFETY_INTERLOCK_MASK are all
  // Protection: Yes).
  task automatic configure_channel(input int c, input logic en, input logic active_high,
                                    input logic latch, input logic [31:0] resp_mask_v,
                                    input logic [7:0] req_interlocks);
    logic [2:0] cc;
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, c, cc);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, {29'h0, latch, active_high, en}, cc);
    protected_write(DFC_ADDR_SAFETY_RESPONSE_MASK, resp_mask_v, cc);
    protected_write(DFC_ADDR_SAFETY_INTERLOCK_MASK, {24'h0, req_interlocks}, cc);
  endtask

  task automatic set_lane0_response_mask(input logic [3:0] mask_v);
    logic [2:0] c;
    // WDOG_CONTROL: bit0 ENABLE, bit1 WINDOW_ENABLE(disclosed-unused),
    // bit2 EVENT_ENABLE, bit3 IRQ_ENABLE, bit4 FAULT_ENABLE,
    // bits8:5 SAFETY_RESPONSE_MASK.
    protected_write(DFC_ADDR_WDOG_CONTROL, {23'h0, mask_v, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1}, c);
  endtask

  logic [2:0]  code;
  logic [31:0] rdata;

  initial begin
    dri_req_valid_i = 1'b0;
    dri_req_write_i = 1'b0;
    dri_req_addr_i  = '0;
    dri_req_wdata_i = '0;
    dri_req_wstrb_i = '0;
    core_rst_n_i = 0;
    repeat (2) @(posedge core_clk_i);
    #1;
    core_rst_n_i = 1;
    wait_cycles(4);

    // ==========================================================================
    // Part 1: reset state, ready, no outputs active.
    // ==========================================================================
    check_bit("status_o.ready asserts after reset release with no enable write (mandatory)",
              rtl016_status[dfc_types_pkg::DFC_RTL016_STATUS__READY_HI], 1'b1);
    dri_read(DFC_ADDR_SAFETY_STATUS, rdata, code);
    check("SAFETY_STATUS reads all clear after reset", rdata, 32'h0);
    check("safety_out_o inactive at reset", tb_safety_out, 4'h0);

    // ==========================================================================
    // Part 2: protection (REG-3400/340C/3410/3414 Protection: Yes).
    // ==========================================================================
    dri_write(DFC_ADDR_SAFETY_CONTROL, 32'h1, code);
    check("SAFETY_CONTROL write without PROTECT_KEY rejected (PROTECTED_ERROR)", {29'h0, code}, 32'h3);
    dri_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h1, code);
    check("SAFETY_CHANNEL_CONTROL write without PROTECT_KEY rejected (PROTECTED_ERROR)", {29'h0, code}, 32'h3);
    dri_write(DFC_ADDR_SAFETY_RESPONSE_MASK, 32'h1, code);
    check("SAFETY_RESPONSE_MASK write without PROTECT_KEY rejected (PROTECTED_ERROR)", {29'h0, code}, 32'h3);
    dri_write(DFC_ADDR_SAFETY_INTERLOCK_MASK, 32'h1, code);
    check("SAFETY_INTERLOCK_MASK write without PROTECT_KEY rejected (PROTECTED_ERROR)", {29'h0, code}, 32'h3);

    // Global enable, event enable (needed for Part 17 later), cleared inhibit.
    protected_write(DFC_ADDR_SAFETY_CONTROL, 32'h0000_0003, code);  // ENABLE=1, EVENT_ENABLE=1, GLOBAL_INHIBIT=0
    check("SAFETY_CONTROL protected write (ENABLE=1, EVENT_ENABLE=1) accepted", {29'h0, code}, 32'h0);

    // ==========================================================================
    // Part 3: selector-indexed four-channel config bank (REG-COH-001) --
    // configure channel 0 and channel 1 distinctly, confirm independent
    // storage (same mechanism, zero new generator work, as items 68/82).
    // ==========================================================================
    configure_channel(0, 1'b1, 1'b1, 1'b0, 32'h0000_0001, 8'h00);  // ch0: authorize lane0 (bit0)
    configure_channel(1, 1'b1, 1'b0, 1'b0, 32'h0000_0100, 8'h00);  // ch1: authorize bit 8 (lane1/RTL-013)
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 0, code);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_CONTROL, rdata, code);
    check("SAFETY_CHANNEL_CONTROL channel 0 reads back distinctly (ACTIVE_HIGH=1)", rdata, 32'h0000_0003);
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 1, code);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_CONTROL, rdata, code);
    check("SAFETY_CHANNEL_CONTROL channel 1 reads back distinctly (ACTIVE_HIGH=0)", rdata, 32'h0000_0001);

    // ==========================================================================
    // Part 4: real RTL-012 (lane 0) request -> two-key authorization (item
    // 96) -> full PERMIT -> EFFECTIVE -> real safety_out_o, ACTIVE_HIGH.
    // ==========================================================================
    dri_write(DFC_ADDR_WDOG_WINDOW_OPEN_US, 32'd5, code);
    dri_write(DFC_ADDR_WDOG_TIMEOUT_US, 32'd10, code);
    set_lane0_response_mask(4'h1);  // RTL-012's own response_mask targets channel 0
    wait_cycles(1200);  // >> 10us real timeout (50 CORE_CLK ticks/us)
    check_bit("real RTL-012 response_req_o.valid asserts after a genuine timeout",
              rtl012_response[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI], 1'b1);

    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 0, code);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.COMMAND_REQUEST asserts (channel 0, real two-key auth)", rdata[0], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT asserts (every PERMIT term clear)", rdata[1], 1'b1);
    check("the real external safety_out_o[0] pad genuinely asserts ACTIVE_HIGH", tb_safety_out[0], 1'b1);

    // ==========================================================================
    // Part 5: ACTIVE_HIGH=0 polarity -- channel 1 authorized the same real
    // request path is NOT live yet (channel 1 authorizes bit 8, lane 1,
    // not yet driven); drive tb_lane1 directly for this specific check.
    // ==========================================================================
    tb_lane1_valid = 1'b1; tb_lane1_source = 3'd0; tb_lane1_mask = 4'h2;  // targets channel 1
    #1;
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 1, code);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT asserts (channel 1)", rdata[1], 1'b1);
    check("the real external safety_out_o[1] pad stays LOW while EFFECTIVE (ACTIVE_HIGH=0 -> inactive-high pad)",
          tb_safety_out[1], 1'b0);
    tb_lane1_valid = 1'b0;
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT clears once the request drops (no latch)", rdata[1], 1'b0);
    check("the real external safety_out_o[1] pad returns HIGH once inactive (ACTIVE_HIGH=0 idle-high)",
          tb_safety_out[1], 1'b1);

    // ==========================================================================
    // Part 6: two-key authorization negative test (item 96) -- lane 1
    // requests channel 1 (its own response_mask bit set), but channel 1's
    // own 32-bit authorization only has bit 8 set (source 0); a DIFFERENT
    // source_id on lane 1 must NOT be authorized even though the producer
    // itself wants channel 1.
    // ==========================================================================
    tb_lane1_valid = 1'b1; tb_lane1_source = 3'd1; tb_lane1_mask = 4'h2;  // source 1, not source 0
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.COMMAND_REQUEST stays clear: producer wants it, but this module's own authorization bit (8*1+1=9) is not set",
          rdata[0], 1'b0);
    tb_lane1_valid = 1'b0;
    #1;

    // ==========================================================================
    // Part 7: GLOBAL_INHIBIT (item 91 -- independent of SAFETY_CONTROL.ENABLE).
    // ==========================================================================
    protected_write(DFC_ADDR_SAFETY_CONTROL, 32'h0000_000B, code);  // ENABLE=1, GLOBAL_INHIBIT=1
    check("SAFETY_CONTROL protected write (GLOBAL_INHIBIT=1, ENABLE still 1) accepted", {29'h0, code}, 32'h0);
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 0, code);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.GLOBAL_INHIBIT asserts", rdata[11], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.CONTROLLER_DISABLED stays clear (independent fields, item 91)", rdata[10], 1'b0);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by GLOBAL_INHIBIT alone", rdata[1], 1'b0);
    check("the real external safety_out_o[0] pad correctly goes inactive", tb_safety_out[0], 1'b0);
    protected_write(DFC_ADDR_SAFETY_CONTROL, 32'h0000_0003, code);  // restore GLOBAL_INHIBIT=0

    // ==========================================================================
    // Part 8: CONTROLLER_DISABLED (SAFETY_CONTROL.ENABLE=0).
    // ==========================================================================
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 EFFECTIVE_OUTPUT re-asserts once GLOBAL_INHIBIT clears", rdata[1], 1'b1);
    protected_write(DFC_ADDR_SAFETY_CONTROL, 32'h0000_0002, code);  // ENABLE=0
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.CONTROLLER_DISABLED asserts", rdata[10], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by CONTROLLER_DISABLED", rdata[1], 1'b0);
    protected_write(DFC_ADDR_SAFETY_CONTROL, 32'h0000_0003, code);  // ENABLE=1
    #1;

    // ==========================================================================
    // Part 9: CHANNEL_DISABLED, per-channel independence.
    // ==========================================================================
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0002, code);  // channel 0 ENABLE=0
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.DISABLED asserts (channel 0)", rdata[2], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by CHANNEL_DISABLED", rdata[1], 1'b0);
    check("the real external safety_out_o[0] pad correctly goes inactive", tb_safety_out[0], 1'b0);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0003, code);  // re-enable, ACTIVE_HIGH=1
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 EFFECTIVE_OUTPUT re-asserts once re-enabled (request still live)", rdata[1], 1'b1);

    // ==========================================================================
    // Part 10: OBSERVATIONAL_INHIBIT.
    // ==========================================================================
    tb_observational_mode = 1'b1;
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.OBSERVATIONAL_INHIBIT asserts", rdata[3], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by OBSERVATIONAL_INHIBIT", rdata[1], 1'b0);
    tb_observational_mode = 1'b0;
    #1;

    // ==========================================================================
    // Part 11: TEST_INHIBIT -- test_inhibit_i and TEST_DEBUG, independently
    // (item 93: this module ORs both into a single combined term).
    // ==========================================================================
    tb_test_inhibit = 1'b1;
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.TEST_INHIBIT asserts via test_inhibit_i alone", rdata[7], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by test_inhibit_i", rdata[1], 1'b0);
    tb_test_inhibit = 1'b0;
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 EFFECTIVE_OUTPUT re-asserts once test_inhibit_i clears", rdata[1], 1'b1);
    tb_operating_state = dfc_types_pkg::TEST_DEBUG;
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.TEST_INHIBIT asserts via TEST_DEBUG alone (item 93)", rdata[7], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by TEST_DEBUG", rdata[1], 1'b0);
    tb_operating_state = dfc_types_pkg::NORMAL;
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 EFFECTIVE_OUTPUT re-asserts once back in NORMAL", rdata[1], 1'b1);

    // ==========================================================================
    // Part 12: INTERLOCK_INHIBIT[c] (item 95 -- guard-indexed
    // interlock_inhibit_i, NOT entry-indexed interlock_satisfied_i).
    // ==========================================================================
    protected_write(DFC_ADDR_SAFETY_INTERLOCK_MASK, 32'h0000_0004, code);  // require guard 2
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.INTERLOCK_INHIBIT stays clear (guard 2 currently allowed)", rdata[4], 1'b0);
    tb_interlock_inhibit[2] = 1'b1;  // guard 2 now inhibited
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.INTERLOCK_INHIBIT asserts once required guard 2 is inhibited", rdata[4], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by INTERLOCK_INHIBIT", rdata[1], 1'b0);
    tb_interlock_satisfied = 8'h00;  // toggle the genuinely-unused entry-indexed port
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("interlock_satisfied_i has NO effect on INTERLOCK_INHIBIT (item 95 -- genuinely unused input)", rdata[4], 1'b1);
    tb_interlock_satisfied = 8'hFF;
    tb_interlock_inhibit[2] = 1'b0;
    protected_write(DFC_ADDR_SAFETY_INTERLOCK_MASK, 32'h0000_0000, code);
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 EFFECTIVE_OUTPUT re-asserts once the interlock requirement clears", rdata[1], 1'b1);

    // ==========================================================================
    // Part 13: FAULT_INHIBIT[c], genuinely per-channel (item 92).
    // ==========================================================================
    tb_fault_inhibit = 4'b0001;  // channel 0 only
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("host-readable SAFETY_CHANNEL_STATUS.FAULT_INHIBIT asserts (channel 0)", rdata[5], 1'b1);
    check("host-readable SAFETY_CHANNEL_STATUS.EFFECTIVE_OUTPUT blocked by FAULT_INHIBIT", rdata[1], 1'b0);
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 1, code);
    dri_read(DFC_ADDR_SAFETY_STATUS, rdata, code);
    check("other channels' FAULT_INHIBIT (SAFETY_STATUS.INHIBITED) unaffected by channel 0's own fault_inhibit_i bit",
          rdata[9], 1'b0);
    tb_fault_inhibit = 4'h0;
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 0, code);
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 EFFECTIVE_OUTPUT re-asserts once fault_inhibit_i clears", rdata[1], 1'b1);

    // ==========================================================================
    // Part 14: LATCH_RESPONSE policy (item 97).
    // ==========================================================================
    set_lane0_response_mask(4'h0);  // stop RTL-012's own real request first
    wait_cycles(5);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0007, code);  // ENABLE=1, ACTIVE_HIGH=1, LATCH_RESPONSE=1
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 COMMAND_REQUEST clear once RTL-012's real request stopped", rdata[0], 1'b0);
    check("channel 0 LATCHED_REQUEST clear (latch just enabled, nothing live yet)", rdata[8], 1'b0);
    set_lane0_response_mask(4'h1);
    wait_cycles(10);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 LATCHED_REQUEST sets on a genuine new request", rdata[8], 1'b1);
    set_lane0_response_mask(4'h0);
    wait_cycles(5);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 LATCHED_REQUEST holds once the live request drops (COMMANDED still latched)", rdata[8], 1'b1);
    check("channel 0 COMMANDED still asserts via the latch", rdata[9], 1'b1);
    check("channel 0 EFFECTIVE_OUTPUT still asserts via the latch", rdata[1], 1'b1);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0006, code);  // ENABLE=0 (request already inactive)
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 LATCHED_REQUEST clears on disable once the request is already inactive", rdata[8], 1'b0);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0007, code);  // re-enable, latch still on
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 LATCHED_REQUEST begins clear on re-enable", rdata[8], 1'b0);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0003, code);  // latch off again for later parts

    // ==========================================================================
    // Part 15: disabled-channel-with-stale-mask live FAULTED[c]/fault_req_o
    // (item 94/9 -- the cross-field defense RTL-001's own single-register
    // validation cannot see).
    // ==========================================================================
    check_bit("fault_req_o clear before any invalid configuration", rtl016_fault_req, 1'b0);
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 1, code);
    protected_write(DFC_ADDR_SAFETY_CHANNEL_CONTROL, 32'h0000_0000, code);  // channel 1 disabled
    // channel 1's own stored response mask is already 0x0100 from Part 3 --
    // genuinely nonzero while now disabled.
    #1;
    dri_read(DFC_ADDR_SAFETY_STATUS, rdata, code);
    check("host-readable SAFETY_STATUS.FAULTED[1] asserts: channel 1 is disabled with a stale nonzero response mask",
          rdata[13], 1'b1);
    check_bit("fault_req_o genuinely asserts from the live cross-field detection", rtl016_fault_req, 1'b1);
    check_bit("status_o.fault mirrors the same live condition", rtl016_status[dfc_types_pkg::DFC_RTL016_STATUS__FAULT_HI], 1'b1);
    protected_write(DFC_ADDR_SAFETY_RESPONSE_MASK, 32'h0000_0000, code);  // host clears the stale mask
    #1;
    dri_read(DFC_ADDR_SAFETY_STATUS, rdata, code);
    check("host-readable SAFETY_STATUS.FAULTED[1] clears once the host clears the stale mask", rdata[13], 1'b0);
    check_bit("fault_req_o clears once every channel's configuration is valid again", rtl016_fault_req, 1'b0);
    dri_write(DFC_ADDR_SAFETY_CHANNEL_SELECT, 0, code);

    // ==========================================================================
    // Part 16: multiple authorized requests OR together, one cannot cancel
    // another (ARCH-RTL016-001).
    // ==========================================================================
    protected_write(DFC_ADDR_SAFETY_RESPONSE_MASK, 32'h0000_0101, code);  // authorize lane0 bit0 AND lane1 bit8(source0)
    set_lane0_response_mask(4'h1);
    tb_lane1_valid = 1'b1; tb_lane1_source = 3'd0; tb_lane1_mask = 4'h1;
    wait_cycles(10);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 COMMAND_REQUEST asserts with BOTH lane 0 and lane 1 authorized and active", rdata[0], 1'b1);
    tb_lane1_valid = 1'b0;  // lane 1 drops
    #1;
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 COMMAND_REQUEST still asserts: lane 0 alone keeps it requested (one source cannot cancel another)",
          rdata[0], 1'b1);
    set_lane0_response_mask(4'h0);
    wait_cycles(5);
    dri_read(DFC_ADDR_SAFETY_CHANNEL_STATUS, rdata, code);
    check("channel 0 COMMAND_REQUEST finally clears once BOTH sources are inactive", rdata[0], 1'b0);
    protected_write(DFC_ADDR_SAFETY_RESPONSE_MASK, 32'h0000_0001, code);  // restore for later parts

    // ==========================================================================
    // Part 17: event 0x0044 + EVENT_OVERFLOW host read-and-clear round trip.
    // ==========================================================================
    set_lane0_response_mask(4'h1);
    wait_cycles(10);
    check("RTL-016's real event genuinely reached this testbench's capture (0x0044 Safety output)",
          last_evt_id, 16'h0044);
    set_lane0_response_mask(4'h0);
    wait_cycles(5);

    // Real overflow: several genuine request/activation/deactivation
    // transitions on channel 0 while the single event slot is held
    // occupied (evt_ready_i withheld) -- same "two real events, handshake
    // withheld" technique every prior module's own overflow test uses.
    tb_evt_ready = 1'b0;
    set_lane0_response_mask(4'h1);
    wait_cycles(10);
    set_lane0_response_mask(4'h0);
    wait_cycles(10);
    set_lane0_response_mask(4'h1);
    wait_cycles(10);
    set_lane0_response_mask(4'h0);
    wait_cycles(10);
    tb_evt_ready = 1'b1;
    #1;
    dri_read(DFC_ADDR_RTL016_EVT_OVERFLOW_STATUS, rdata, code);
    check_bit("a real overflow condition set RTL-016's sticky EVENT_OVERFLOW", rdata[0], 1'b1);
    dri_write(DFC_ADDR_RTL016_EVT_OVERFLOW_STATUS, 32'h0000_0001, code);  // W1C
    check("RTL016_EVT_OVERFLOW_STATUS clear write accepted", {29'h0, code}, 32'h0);
    dri_read(DFC_ADDR_RTL016_EVT_OVERFLOW_STATUS, rdata, code);
    check_bit("the real host write actually cleared RTL-016's real EVENT_OVERFLOW", rdata[0], 1'b0);
    set_lane0_response_mask(4'h0);
    wait_cycles(5);

    // ==========================================================================
    // Part 18: module reset clears every channel.
    // ==========================================================================
    tb_module_reset = 1'b1;
    @(posedge core_clk_i); #1;
    tb_module_reset = 1'b0;
    #1;
    dri_read(DFC_ADDR_SAFETY_STATUS, rdata, code);
    check("SAFETY_STATUS reads all clear after module reset", rdata, 32'h0);
    // module_reset_i clears only RTL-016's own internal evaluation state
    // (safety_out_q, latched_request_q, etc.) -- NOT the host configuration
    // RTL-001 itself stores (SAFETY_CHANNEL_CONTROL etc. have no
    // module-reset scope of their own, same precedent as RTL-014/015's own
    // per-entry/per-monitor config surviving their own module_reset_i).
    // Channel 1's own surviving ACTIVE_HIGH=0 configuration (set in Part 3,
    // never re-enabled since Part 15's deliberate disable) correctly idles
    // HIGH, not LOW -- confirmed real, not a defect: every OTHER channel
    // (0, 2, 3) idles low per their own surviving/default configuration.
    check("safety_out_o reflects each channel's own surviving idle polarity after module reset (ch1=idle-high, others idle-low)",
          tb_safety_out, 4'h2);

    $display("rtl016_integration_tb: %0d checks, %0d failures", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $fflush();
    $finish;
  end

endmodule : rtl016_integration_tb
