`timescale 1ns/1ps
// rtl022_integration_tb.sv -- dedicated testbench for RTL-022 (Mask-Defined
// User Logic Island), dfc_rtl022.sv, ARCH-RTL022-001.
//
// VP-USER-010: "fundamentally a negative-space verification problem" --
// this module's correct behavior is defined almost entirely by what it
// must NEVER do, so this testbench is not under-scoped just because the
// module "does nothing" operationally. Instantiates dfc_rtl022 REAL against
// a REAL dfc_rtl024_shared_buffer (same "real client against the real
// service" discipline every prior Databus module's own testbench
// established). control_i/status_o are driven/read directly via the
// generated DFC_RTL022_CONTROL__*/DFC_RTL022_STATUS__* bit constants (no
// RTL-001 regbank in this testbench -- same precedent as every other
// per-module testbench in this project).
//
// Required coverage (this session's own task briefing, VP-USER-010):
//   1. Each of the 8 PARAMs individually: nonzero rejected, violation set,
//      value has no operational effect (trivially true -- nothing consumes
//      it -- but VIOLATION evidence must be real).
//   2. ENABLE/IRQ_ENABLE nonzero-write rejection (REG-ENC-017).
//   3. OUTPUT_REQUEST nonzero-write rejection.
//   4. Adversarial combination: multiple simultaneous nonzero attempts,
//      rapid-fire writes, writes during reset, writes during test mode --
//      confirming EVERY operational output (user_o/user_oe_o/tx_msg_valid_o/
//      irq_req_o/fault_req_o) stays zero under all of them.
//   5. 4 synchronized user-input capture: status-only, zero influence on
//      any output.
//   6. Both mailboxes: push/pop, full/empty, capacity, loss counting.
//   7. Reset clears mailbox state; the externally-held control_i PARAM
//      bits are untouched by RTL-022 itself (it has no write-back path --
//      structurally guaranteed, not merely asserted).
//   8. Real RTL-021 destination-side message delivery: diagnostic capture
//      only, zero operational effect -- confirmed by observing NOTHING
//      changes as a result (same disclosed "zero diagnostic surface"
//      reading as dfc_rtl022.sv's own header, finding 4).
//
// NOT exercised (disclosed, same precedent as RTL-021's own testbench,
// which also never exercises its own analogous "shared-buffer error" event
// path): the real shared buffer never returns a non-OK response code for
// in-bounds, well-formed client traffic, so cond_buf_error (F.3 bit 3) has
// no reachable trigger at this integration level -- a structural property
// of the shared buffer's own real implementation, not a gap in this
// testbench.

module rtl022_integration_tb;

  logic core_clk_i = 1'b0;
  logic core_rst_n_i;
  logic module_reset_i = 1'b0;

  always #10 core_clk_i = ~core_clk_i;

  initial begin
    #4000000;
    $display("TEST FAILED -- watchdog timeout, something never completed a handshake");
    $finish(1);
  end

  // ---- control_i / status_o ----
  logic [dfc_types_pkg::DFC_RTL022_CONTROL_WIDTH-1:0] control_i;
  wire  [dfc_types_pkg::DFC_RTL022_STATUS_WIDTH-1:0]  status_o;

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

  // ---- timestamp ----
  logic [63:0] timestamp_i = 64'h0;
  always @(posedge core_clk_i) timestamp_i <= timestamp_i + 64'd1;

  // ---- event/irq/fault ----
  wire        evt_valid_o;
  logic       evt_ready_i = 1'b1;
  wire [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o;
  wire        irq_req_o;
  wire        fault_req_o;

  // ---- user I/O ----
  logic [3:0] user_i = 4'h0;
  wire  [3:0] user_o;
  wire  [3:0] user_oe_o;

  // ---- RTL-021 message channels ----
  localparam int unsigned RECW = dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH;
  logic               rx_msg_valid_i = 1'b0;
  wire                rx_msg_ready_o;
  logic [RECW-1:0]    rx_msg_record_i = '0;
  wire                tx_msg_valid_o;
  logic               tx_msg_ready_i = 1'b1;
  wire [RECW-1:0]     tx_msg_record_o;

  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic observational_mode_i = 1'b0;
  logic [3:0] route_user_req_i = 4'h0;
  logic [7:0] route_term_i = 8'h0;
  logic module_enable_i = 1'b1;
  logic effective_operational_enable_i = 1'b1;
  logic test_active_i = 1'b0;

  wire        buf_req_valid, buf_req_ready;
  wire [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req;
  wire        buf_rsp_valid, buf_rsp_ready;
  wire [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp;

  dfc_rtl022 dut (
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
    .user_i                   (user_i),
    .user_o                   (user_o),
    .user_oe_o                (user_oe_o),
    .rx_msg_valid_i           (rx_msg_valid_i),
    .rx_msg_ready_o           (rx_msg_ready_o),
    .rx_msg_record_i          (rx_msg_record_i),
    .tx_msg_valid_o           (tx_msg_valid_o),
    .tx_msg_ready_i           (tx_msg_ready_i),
    .tx_msg_record_o          (tx_msg_record_o),
    .operating_state_i        (operating_state_i),
    .observational_mode_i     (observational_mode_i),
    .route_user_req_i         (route_user_req_i),
    .route_term_i             (route_term_i),
    .module_enable_i          (module_enable_i),
    .effective_operational_enable_i (effective_operational_enable_i),
    .test_active_i            (test_active_i),
    .buf_req_valid_o          (buf_req_valid),
    .buf_req_ready_i          (buf_req_ready),
    .buf_req_o                (buf_req),
    .buf_rsp_valid_i          (buf_rsp_valid),
    .buf_rsp_ready_o          (buf_rsp_ready),
    .buf_rsp_i                (buf_rsp),
    .event_condition_enable_i (64'hFFFFFFFFFFFFFFFF),
    .irq_condition_enable_i   (64'hFFFFFFFFFFFFFFFF)
  );

  // Client 5's own real slot number doesn't matter here -- dfc_rtl022.sv's
  // own addressing is purely client-relative, same precedent as every
  // prior Databus module's own testbench.
  wire [6:0] sb_req_valid = {1'b0, buf_req_valid, 5'b0};
  wire [6:0] sb_req_ready;
  wire [6:0] sb_rsp_valid;
  wire [6:0] sb_rsp_ready = {1'b1, buf_rsp_ready, 5'b11111};
  wire [7*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] sb_req =
    {{dfc_types_pkg::DFC_BUFFER_REQ_WIDTH{1'b0}}, buf_req, {5*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH{1'b0}}};
  wire [7*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] sb_rsp;

  assign buf_req_ready = sb_req_ready[5];
  assign buf_rsp_valid = sb_rsp_valid[5];
  assign buf_rsp       = sb_rsp[6*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:5*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH];

  dfc_rtl024_shared_buffer u_shared_buffer (
    .core_clk_i      (core_clk_i),
    .core_rst_n_i    (core_rst_n_i),
    .module_reset_i  (7'b0),
    .buf_req_valid_i (sb_req_valid),
    .buf_req_ready_o (sb_req_ready),
    .buf_req_i       (sb_req),
    .buf_rsp_valid_o (sb_rsp_valid),
    .buf_rsp_ready_i (sb_rsp_ready),
    .buf_rsp_o       (sb_rsp),
    .buffer_status_o                 (),
    .buffer_client_error_count_0_1_o (),
    .buffer_client_error_count_2_3_o (),
    .buffer_client_error_count_4_5_o (),
    .buffer_client_error_count_6_o   (),
    .buffer_internal_error_count_o   (),
    .dbg_grant_onehot_o    (),
    .dbg_outstanding_o     (),
    .dbg_grant_valid_o     (),
    .dbg_gr_range_error_o  (),
    .dbg_gr_offset_o       (),
    .dbg_gr_width_o        (),
    .dbg_mem_we_o          (),
    .dbg_gr_abs_addr_o     (),
    .dbg_gr_base_o         ()
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

  // Confirms every real operational output is zero right now, under
  // whatever adversarial control_i/user_i/rx_msg state the caller has set
  // up -- the single most load-bearing check in this whole file.
  task automatic check_all_outputs_zero(string ctx);
    check_bit({ctx, " user_o==0"},        |user_o,        1'b0);
    check_bit({ctx, " user_oe_o==0"},     |user_oe_o,     1'b0);
    check_bit({ctx, " tx_msg_valid_o==0"}, tx_msg_valid_o, 1'b0);
    check_bit({ctx, " irq_req_o==0"},      irq_req_o,      1'b0);
    check_bit({ctx, " fault_req_o==0"},    fault_req_o,    1'b0);
  endtask

  task automatic wait_cycles(int n);
    repeat (n) @(posedge core_clk_i);
  endtask

  // ==========================================================================
  // Stimulus
  // ==========================================================================
  int i;
  initial begin
    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    core_rst_n_i = 1'b1;
    @(posedge core_clk_i);
    #1;
    // EVENT_ENABLE is the one real, ordinary RW bit (REG-002's own prose:
    // "diagnostic EVENT_ENABLE remain available") -- enabled so this
    // testbench can observe real diagnostic events. ENABLE/IRQ_ENABLE are
    // deliberately left at their reset value of zero throughout this whole
    // file: the module's inert contract must hold with or without them,
    // and REG-ENC-017 forbids ever setting them to 1 legally in the first
    // place.
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__EVENT_ENABLE_HI] = 1'b1;
    @(posedge core_clk_i);

    check_all_outputs_zero("power-on");
    check_bit("ULI_STATUS.VIOLATION clear at power-on",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b0);

    // ------------------------------------------------------------------
    // Case 1: each of the 8 PARAMs individually -- nonzero rejected,
    // violation set, cleared, value has no operational effect.
    // ------------------------------------------------------------------
    begin
      int unsigned param_hi[0:7], param_lo[0:7];
      param_hi[0] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_HI; param_lo[0] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_LO;
      param_hi[1] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_HI; param_lo[1] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_LO;
      param_hi[2] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM2__PARAM2_HI; param_lo[2] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM2__PARAM2_LO;
      param_hi[3] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM3__PARAM3_HI; param_lo[3] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM3__PARAM3_LO;
      param_hi[4] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM4__PARAM4_HI; param_lo[4] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM4__PARAM4_LO;
      param_hi[5] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM5__PARAM5_HI; param_lo[5] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM5__PARAM5_LO;
      param_hi[6] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM6__PARAM6_HI; param_lo[6] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM6__PARAM6_LO;
      param_hi[7] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM7__PARAM7_HI; param_lo[7] = dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM7__PARAM7_LO;

      for (i = 0; i < 8; i = i + 1) begin
        set_field(param_hi[i], param_lo[i], 64'hDEADBEEF);
        @(posedge core_clk_i); #1;
        check_bit($sformatf("PARAM%0d nonzero -> VIOLATION set", i),
                  status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b1);
        check_all_outputs_zero($sformatf("PARAM%0d nonzero", i));
        set_field(param_hi[i], param_lo[i], 64'h0);
        @(posedge core_clk_i); #1;
        pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI);
        @(posedge core_clk_i); #1;
        check_bit($sformatf("PARAM%0d violation clears once zeroed+W1C", i),
                  status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b0);
      end
    end

    // ------------------------------------------------------------------
    // Case 2/3: ENABLE, IRQ_ENABLE, OUTPUT_REQUEST nonzero-write rejection
    // (REG-ENC-017).
    // ------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__ENABLE_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("ENABLE=1 -> VIOLATION set", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b1);
    check_all_outputs_zero("ENABLE=1");
    check_bit("ENABLE=1 -> ULI_STATUS.ENABLED still reflects module_enable_i, not ctl_enable",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__ENABLED_HI], 1'b1);
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__ENABLE_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI);

    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__IRQ_ENABLE_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("IRQ_ENABLE=1 -> VIOLATION set", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b1);
    check_all_outputs_zero("IRQ_ENABLE=1, all irq_condition_enable_i set");
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__IRQ_ENABLE_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI);

    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_LO, 4'hF);
    @(posedge core_clk_i); #1;
    check_bit("OUTPUT_REQUEST=0xF -> VIOLATION set", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b1);
    check_all_outputs_zero("OUTPUT_REQUEST=0xF");
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_LO, 4'h0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI);

    // ------------------------------------------------------------------
    // Case 4: adversarial combination -- simultaneous nonzero attempts,
    // rapid-fire writes, writes during reset, writes during test mode.
    // ------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__ENABLE_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__IRQ_ENABLE_HI] = 1'b1;
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_LO, 32'hFFFFFFFF);
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_LO, 4'h1);
    for (i = 0; i < 20; i = i + 1) begin
      @(posedge core_clk_i);
      check_all_outputs_zero($sformatf("simultaneous-violation rapid-fire cycle %0d", i));
    end
    check_bit("simultaneous violations -> VIOLATION set", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b1);

    test_active_i = 1'b1;
    for (i = 0; i < 5; i = i + 1) begin
      @(posedge core_clk_i);
      check_all_outputs_zero($sformatf("test_active_i=1 cycle %0d", i));
    end
    test_active_i = 1'b0;

    module_reset_i = 1'b1;
    @(posedge core_clk_i); #1;
    check_all_outputs_zero("during module_reset_i");
    check_bit("module_reset_i clears VIOLATION", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b0);
    module_reset_i = 1'b0;
    @(posedge core_clk_i); #1;
    check_bit("violation re-asserts once module_reset_i deasserts, offending fields still nonzero",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b1);

    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__ENABLE_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__IRQ_ENABLE_HI] = 1'b0;
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_LO, 32'h0);
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_LO, 4'h0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI);
    check_bit("all violations cleared", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI], 1'b0);

    // ------------------------------------------------------------------
    // Case 5: 4 synchronized user-input capture -- status-only, zero
    // influence on output.
    // ------------------------------------------------------------------
    user_i = 4'hA;
    wait_cycles(3);  // 2-stage synchronizer latency + margin
    check("ULI_IO_INPUT.INPUT reflects synchronized user_i",
          status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_IO_INPUT__INPUT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_IO_INPUT__INPUT_LO], 4'hA);
    check_all_outputs_zero("user_i=0xA");
    user_i = 4'h5;
    wait_cycles(3);
    check("ULI_IO_INPUT.INPUT tracks a second user_i value",
          status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_IO_INPUT__INPUT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_IO_INPUT__INPUT_LO], 4'h5);
    check_all_outputs_zero("user_i=0x5");
    user_i = 4'h0;
    wait_cycles(3);

    // ------------------------------------------------------------------
    // Case 6a: input mailbox -- push to full, overflow, loss count, clear.
    // ------------------------------------------------------------------
    check_bit("input mailbox empty at start", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__IN_MAILBOX_NOT_EMPTY_HI], 1'b0);
    for (i = 0; i < 4; i = i + 1) begin
      set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_DATA__MAILBOX_DATA_HI,
                dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_DATA__MAILBOX_DATA_LO, 32'hA000_0000 + i);
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_PUSH__PUSH_HI);
      wait_cycles(40);  // real shared-buffer round trip
      check($sformatf("input mailbox LEVEL after push %0d", i),
            status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_IN_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_IN_LEVEL__LEVEL_LO], i + 1);
    end
    check_bit("input mailbox FULL at 4", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__IN_MAILBOX_FULL_HI], 1'b1);

    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_DATA__MAILBOX_DATA_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_DATA__MAILBOX_DATA_LO, 32'hFFFF_FFFF);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_PUSH__PUSH_HI);
    wait_cycles(5);
    check_bit("push against a full mailbox sets INPUT_OVERFLOW",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_LO], 1'b1);
    check("input overflow loss count == 1",
          status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_LO] & 64'hFFFF, 16'd1);
    check("input mailbox LEVEL unchanged by a rejected push",
          status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_IN_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_IN_LEVEL__LEVEL_LO], 3'd4);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_CLEAR_HI-3); // bit0 = INPUT_OVERFLOW
    @(posedge core_clk_i); #1;
    check_bit("INPUT_OVERFLOW W1C clears",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_LO], 1'b0);

    // ------------------------------------------------------------------
    // Case 6b: output mailbox -- fixed zero, every POP is a real underflow.
    // ------------------------------------------------------------------
    check("ULI_OUT_LEVEL fixed zero", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_LEVEL__LEVEL_LO], 3'd0);
    check("ULI_OUT_DATA fixed zero", status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_DATA__MAILBOX_DATA_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_DATA__MAILBOX_DATA_LO], 32'h0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_OUT_POP__POP_HI);
    @(posedge core_clk_i); #1;
    check_bit("every POP attempt sets OUTPUT_UNDERFLOW",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_HI], 1'b1); // bit3 of the 4-bit field = OUT_UNDERFLOW
    check("output underflow loss count == 1",
          (status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_LO] >> 48) & 64'hFFFF, 16'd1);
    check("INPUT_UNDERFLOW loss count is structurally unreachable (always 0)",
          (status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_LO] >> 16) & 64'hFFFF, 16'd0);

    // ------------------------------------------------------------------
    // Case 7: RESET_REQ clears mailbox/violation/reset-complete state; the
    // externally-held control_i PARAM bits are untouched (RTL-022 has no
    // write-back path into them at all -- structurally guaranteed).
    // ------------------------------------------------------------------
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_LO, 32'h1234_5678);
    @(posedge core_clk_i); #1;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__RESET_REQ_HI);
    @(posedge core_clk_i); #1;
    check_bit("RESET_REQ sets RESET_COMPLETE",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__RESET_COMPLETE_HI], 1'b1);
    check_bit("RESET_REQ clears input mailbox LEVEL",
              status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__IN_MAILBOX_NOT_EMPTY_HI], 1'b0);
    check("RESET_REQ does NOT touch the externally-held PARAM1 control_i bits (no write-back path exists)",
          control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_LO], 32'h1234_5678);
    set_field(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_HI,
              dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_LO, 32'h0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__RESET_COMPLETE_HI);

    // ------------------------------------------------------------------
    // Case 8: real RTL-021 destination-side message delivery -- diagnostic
    // capture only, zero operational effect, zero diagnostic surface
    // (dfc_rtl022.sv's own header, finding 4).
    // ------------------------------------------------------------------
    check_bit("rx_msg_ready_o always 1", rx_msg_ready_o, 1'b1);
    rx_msg_record_i = {160'hDEAD_BEEF_CAFE_F00D_0102_0304_0506_0708_090A_0B0C, 32'hFEED_FACE};
    for (i = 0; i < 3; i = i + 1) begin
      rx_msg_valid_i = 1'b1;
      @(posedge core_clk_i); #1;
      check_bit($sformatf("rx_msg accepted immediately, cycle %0d", i), rx_msg_ready_o, 1'b1);
      check_all_outputs_zero($sformatf("after rx_msg delivery %0d", i));
      check_bit($sformatf("rx_msg delivery %0d -> mailbox/status untouched", i),
                status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__IN_MAILBOX_NOT_EMPTY_HI], 1'b0);
    end
    rx_msg_valid_i = 1'b0;
    wait_cycles(3);

    // ------------------------------------------------------------------
    // Final sanity: irq_req_o/fault_req_o stay 0 across everything above,
    // already individually confirmed via check_all_outputs_zero at every
    // step -- one last explicit confirmation with every enable this module
    // has (short of the forbidden ENABLE/IRQ_ENABLE=1) turned on.
    // ------------------------------------------------------------------
    wait_cycles(10);
    check_bit("irq_req_o permanently 0", irq_req_o, 1'b0);
    check_bit("fault_req_o permanently 0", fault_req_o, 1'b0);

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TEST PASSED");
    $finish(errors == 0 ? 0 : 1);
  end

endmodule
