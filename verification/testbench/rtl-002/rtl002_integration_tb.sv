// rtl002_integration_tb.sv -- REAL end-to-end round-trip test: a host-style
// register write through RTL-001's real address-decode path must actually
// change RTL-002's real behavior, and RTL-002's real internal state must
// actually reach back to a host register read through RTL-001. This is
// exactly the connection that was found disconnected earlier in this
// project's history (RTL-002 ran on a static placeholder, completely
// isolated from the host) and closed via reggen.py v3 + rtl002_field_map.json
// + real dfc_rtl001.sv/dfc_rtl024.sv wiring -- this file is the proof that
// fix actually works, not just that each side compiles.
//
// SCOPE: drives RTL-001's real DRI register interface (not internal
// peeking) exactly the way a real host would via the SPI bridge, and reads
// RTL-002's real, live internal state after each write to confirm the
// write actually took effect there -- and vice versa for status readback.
// This is NOT a full VP-MOD-002/VP-INF-001-003 suite; it specifically
// targets the RTL-001<->RTL-002 connection itself.
//
// CLOCKING-DISCIPLINE NOTE (same lesson as every other testbench in this
// project): every strobe is held for a full clock and deasserted with a
// #1 settle delay after the sampling edge, never in the same delta.

`timescale 1ns/1ps

module rtl002_integration_tb;

  import dfc_constants_pkg::*;
  import dfc_registers_pkg::*;

  logic core_clk_i = 0;
  logic core_rst_n_i;

  logic        dri_req_valid_i, dri_req_ready_o, dri_req_write_i;
  logic [31:0] dri_req_addr_i, dri_req_wdata_i;
  logic [3:0]  dri_req_wstrb_i;
  logic        dri_rsp_valid_o, dri_rsp_ready_i = 1'b1;
  logic [31:0] dri_rsp_rdata_o;
  logic [2:0]  dri_rsp_code_o;
  logic        dbg_regbank_write_en_o;

  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0] rtl002_control;
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]  rtl002_status;
  // RTL-003 is not part of this test's scope (it targets the RTL-001<->
  // RTL-002 connection specifically, see file header) -- tied to a
  // disclosed stub, same isolation choice already made for RTL-002 in
  // dri_transaction_tb.sv.
  logic [dfc_types_pkg::DFC_RTL003_CONTROL_WIDTH-1:0] rtl003_control_unused;
  logic [dfc_types_pkg::DFC_RTL003_STATUS_WIDTH-1:0]  rtl003_status_stub = '0;
  // RTL-004/RTL-005 are likewise out of this test's scope -- REAL, GENUINE
  // GAP FOUND AND FIXED during RTL-005's own integration session: these two
  // ports were missing from u_rtl001's instantiation entirely (not merely
  // stub-tied), left as floating/undriven inputs since RTL-004's own
  // integration session added them to dfc_rtl001.sv without updating this
  // file. Closed here, same disclosed-stub pattern as RTL-003 above.
  logic [dfc_types_pkg::DFC_RTL004_CONTROL_WIDTH-1:0] rtl004_control_unused;
  logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0]  rtl004_status_stub = '0;
  logic [dfc_types_pkg::DFC_RTL005_CONTROL_WIDTH-1:0] rtl005_control_unused;
  logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0]  rtl005_status_stub = '0;
  // RTL-006 likewise out of this test's scope -- same disclosed-stub
  // pattern, added during RTL-006's own integration session.
  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] rtl006_control_unused;
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  rtl006_status_stub = '0;
  // RTL-007 likewise out of this test's scope -- same disclosed-stub
  // pattern, added during RTL-007's own integration session.
  logic [dfc_types_pkg::DFC_RTL007_CONTROL_WIDTH-1:0] rtl007_control_unused;
  logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0]  rtl007_status_stub = '0;
  // RTL-008 likewise out of this test's scope -- same disclosed-stub
  // pattern, added during RTL-008's own integration session.
  logic [dfc_types_pkg::DFC_RTL008_CONTROL_WIDTH-1:0] rtl008_control_unused;
  logic [dfc_types_pkg::DFC_RTL008_STATUS_WIDTH-1:0]  rtl008_status_stub = '0;

  // Real signal (not a bare literal tie) so Part 4 below can withhold the
  // event handshake on purpose to force a genuine, real overflow condition
  // for the new EVENT_OVERFLOW clear-path test.
  logic rtl002_evt_ready = 1'b1;

  always #10 core_clk_i = ~core_clk_i;

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
    .rtl002_control_o       (rtl002_control),
    .rtl002_status_i        (rtl002_status),
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
    .status_o               (),
    .dbg_regbank_write_en_o (dbg_regbank_write_en_o)
  );

  dfc_rtl002 u_rtl002 (
    .core_clk_i           (core_clk_i),
    .core_rst_n_i         (core_rst_n_i),
    .module_reset_i       (1'b0),
    .control_i            (rtl002_control),
    .status_o             (rtl002_status),
    .timestamp_i          (64'h0),
    .evt_valid_o          (),
    .evt_ready_i          (rtl002_evt_ready),
    .evt_record_o         (),
    .irq_req_o            (),
    .module_ready_i       (24'h80F81F),  // all mandatory modules ready --
                                          // isolates this test to the
                                          // RTL-001<->RTL-002 connection
                                          // itself, not the stub-topology
                                          // FAULTED consequence already
                                          // covered by rtl024_skeleton_tb.sv
    .module_fault_i       (24'h0),
    .module_reset_o       (),
    .operating_state_o    (),
    .observational_mode_o (),
    // Real port this session -- tied inactive here since this test
    // targets the RTL-001<->RTL-002 register bus specifically, not
    // TEST_DEBUG entry/exit (RTL-002's own standalone testbench,
    // rtl002_state_tb.sv, covers that).
    .test_active_i        (1'b0),
    // Real ports this session, closing OPEN_ISSUES.md item 5 -- tied
    // inactive/stub here since this test targets the RTL-001<->RTL-002
    // register bus specifically, not these new gates.
    .global_irq_enable_o       (),
    .global_event_enable_o     (),
    .event_condition_enable_i  (64'h0),
    .irq_condition_enable_i    (64'h0),
    // Real ports added during RTL-006's own integration session -- tied
    // open/unused here since this test targets the RTL-001<->RTL-002
    // register bus specifically, not these new gates
    // (rtl006_integration_tb.sv covers their real forwarding).
    .module_enable_o                (),
    .effective_operational_enable_o ()
  );

  int errors = 0, checks = 0;
  task automatic check(string what, logic [31:0] got, logic [31:0] expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got 0x%08h, expected 0x%08h", what, got, expected);
    end else $display("PASS: %s -- 0x%08h", what, got);
  endtask
  task automatic check_bit(string what, logic got, logic expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got %b, expected %b", what, got, expected);
    end else $display("PASS: %s", what);
  endtask

  // ---- real host-style DRI transaction tasks (mirrors dri_transaction_tb.sv) ----
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

  // Protected registers (SYS_CONTROL bits 0-3, RESET_CONTROL fully) require
  // the real PROTECT_KEY two-key authorization sequence first (REG-002 SS4)
  // -- same real path a host must use, not a shortcut around it.
  task automatic authorize_protected_write();
    logic [2:0] auth_code;
    dri_write(DFC_ADDR_PROTECT_KEY, dfc_constants_pkg::DFC_PROTECT_KEY1, auth_code);
    dri_write(DFC_ADDR_PROTECT_KEY, dfc_constants_pkg::DFC_PROTECT_KEY2, auth_code);
  endtask

  logic [2:0]  code;
  logic [31:0] rdata;

  initial begin
    dri_req_valid_i = 1'b0;
    dri_req_write_i = 1'b0;
    dri_req_addr_i  = '0;
    dri_req_wdata_i = '0;
    dri_req_wstrb_i = '0;

    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    core_rst_n_i = 1'b1;
    @(posedge core_clk_i); #1;

    // ------------------------------------------------------------------
    // Part 1 (CONTROL direction): a real host write to SYS_CONTROL via
    // RTL-001's real DRI path must actually change RTL-002's real
    // effective_operational_enable -- this is the exact connection that
    // was previously completely disconnected (RTL-002 ran on a static
    // placeholder regardless of what the host wrote here).
    // ------------------------------------------------------------------

    // let RTL-002 leave STARTUP first (all mandatory modules ready, per
    // module_ready_i tie-off above) so effective_operational_enable can
    // actually assert once OPERATIONAL_ENABLE/OBSERVATIONAL_MODE are set.
    repeat (5) @(posedge core_clk_i);

    dri_read(DFC_ADDR_SYS_CONTROL, rdata, code);
    check("SYS_CONTROL reads its real REG-002 reset value before any write",
          rdata, 32'h0000000A);
    check_bit("SYS_STATUS.effective_operational_enable is 0 before the write",
              rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI],
              1'b0);

    // write OPERATIONAL_ENABLE=1, OBSERVATIONAL_MODE=0, keep GLOBAL_EVENT_ENABLE=1
    authorize_protected_write();
    dri_write(DFC_ADDR_SYS_CONTROL, 32'h0000_0009, code);
    check("SYS_CONTROL write accepted (RSP_OK)", {29'h0, code}, 32'h0);
    @(posedge core_clk_i); #1;  // observational_mode_q updates one cycle late in RTL-002

    check_bit({"RTL-002's real effective_operational_enable actually changed ",
              "because of the real host write through RTL-001 (was previously ",
              "impossible -- RTL-002 ran on a disconnected static placeholder)"},
              rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI],
              1'b1);

    dri_read(DFC_ADDR_SYS_CONTROL, rdata, code);
    check("SYS_CONTROL reads back the real value just written", rdata, 32'h0000_0009);

    // ------------------------------------------------------------------
    // Part 2 (STATUS direction): RTL-002's real, live internal state
    // (which is genuinely running and changing inside the design) must
    // reach a host read of SYS_STATUS/SUBSYS_READY/SUBSYS_FAULT through
    // RTL-001 -- previously these always read back zero regardless of
    // RTL-002's real internal state.
    // ------------------------------------------------------------------

    dri_read(DFC_ADDR_SYS_STATUS, rdata, code);
    check_bit({"host-readable SYS_STATUS.NORMAL reflects RTL-002's real, live ",
              "internal state (mandatory-init satisfied, no faults injected)"},
              rdata[3], 1'b1);

    dri_read(DFC_ADDR_SUBSYS_READY, rdata, code);
    check({"host-readable SUBSYS_READY mirrors the real module_ready_i this ",
          "test drove into RTL-002 (not a permanent stub zero)"},
          rdata, 32'h0080F81F);

    dri_read(DFC_ADDR_SUBSYS_FAULT, rdata, code);
    check("host-readable SUBSYS_FAULT mirrors the real module_fault_i (zero, none injected)",
          rdata, 32'h00000000);

    // ------------------------------------------------------------------
    // Part 3 (CONTROL direction, WO-CMD forwarding): a real MODULE_RESET
    // command written to RESET_CONTROL must actually reach RTL-002's real
    // reset-command sequencer as a genuine one-cycle pulse and drive a
    // real module_reset_o bit -- not the permanent-zero tie RESET_CONTROL
    // had before this session's fix.
    // ------------------------------------------------------------------
    authorize_protected_write();
    dri_write(DFC_ADDR_RESET_CONTROL, 32'h0000_0002, code);  // MODULE_RESET bit0 = RTL-001
    check("RESET_CONTROL write accepted (RSP_OK)", {29'h0, code}, 32'h0);
    @(posedge core_clk_i); #1;
    check_bit({"RTL-002's real reset_status.busy went high from a real, ",
              "forwarded RESET_CONTROL command (not a permanent zero-tie)"},
              rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__BUSY_HI],
              1'b1);

    dri_read(DFC_ADDR_RESET_STATUS, rdata, code);
    check_bit("host-readable RESET_STATUS.BUSY mirrors RTL-002's real busy state",
              rdata[0], 1'b1);

    // let Part 3's reset command run to completion (RC_ASSERT + RC_WAIT_READY,
    // well under RECOVERY_TIMEOUT_CYCLES since module_ready_i already
    // satisfies the target mask) before starting a clean Part 4.
    repeat (10) @(posedge core_clk_i); #1;

    // ------------------------------------------------------------------
    // Part 4 (CONTROL direction, W1C clear-request): closes OPEN_ISSUES.md
    // item 2 -- a real host write to RTL002_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
    // must actually clear RTL-002's real, previously-set sticky
    // event_overflow_q, not just report write_illegal_o=1 as it did before
    // this session's fix. Withholding the event handshake (evt_ready) is
    // used here specifically to force a real, genuine overflow condition to
    // clear -- not a fabricated/injected value.
    // ------------------------------------------------------------------
    rtl002_evt_ready = 1'b0;
    @(posedge core_clk_i); #1;

    check_bit("event_overflow_q starts clear before any overflow is forced",
              rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__EVENT_OVERFLOW_HI], 1'b0);

    // a second real MODULE_RESET command (same target as Part 3, already
    // within the mandatory-ready mask so it completes quickly) genuinely
    // emits two events close together (0x0004 requested, then complete) --
    // with the handshake withheld above, the second occupies an already-
    // occupied pending slot, a real, counted overflow.
    authorize_protected_write();
    dri_write(DFC_ADDR_RESET_CONTROL, 32'h0000_0002, code);
    check("second RESET_CONTROL write accepted (RSP_OK)", {29'h0, code}, 32'h0);

    // RESET_ASSERT_MIN_CYCLES(4) + 2 ready-streak cycles to COMPLETE, plus
    // margin -- wait past that so the real "complete" event has genuinely
    // landed on top of the still-pending "requested" event.
    repeat (12) @(posedge core_clk_i); #1;

    check_bit({"a real, genuine overflow condition (two real events, ",
              "handshake withheld) actually set RTL-002's sticky ",
              "event_overflow_q -- not a fabricated value"},
              rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__EVENT_OVERFLOW_HI], 1'b1);

    // the real host clear-request path (REG-0044, previously write_illegal_o=1
    // with no way to clear this evidence at all): a plain, unprotected write
    // of EVENT_OVERFLOW=1 must now actually clear the real sticky bit above.
    dri_write(DFC_ADDR_RTL002_EVT_OVERFLOW_STATUS, 32'h0000_0001, code);
    check("RTL002_EVT_OVERFLOW_STATUS clear write accepted (RSP_OK, was write_illegal_o=1 before this fix)",
          {29'h0, code}, 32'h0);
    @(posedge core_clk_i); #1;

    check_bit({"the real host write above actually cleared RTL-002's real, ",
              "previously-set event_overflow_q through the register ",
              "interface -- OPEN_ISSUES.md item 2, closed for real"},
              rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__EVENT_OVERFLOW_HI], 1'b0);

    rtl002_evt_ready = 1'b1;

    $display("");
    $display("rtl002_integration_tb: %0d checks, %0d failures", checks, errors);
    if (errors != 0) begin
      $display("TEST FAILED");
      $finish(1);
    end else begin
      $display("TEST PASSED");
      $finish(0);
    end
  end

endmodule : rtl002_integration_tb
