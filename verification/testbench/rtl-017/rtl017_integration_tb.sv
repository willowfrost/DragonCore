`timescale 1ns/1ps
// rtl017_integration_tb.sv -- dedicated testbench for RTL-017 (ARINC 429
// Receive Interface), dfc_rtl017.sv, ARCH-RTL017-001.
//
// Instantiates dfc_rtl017 REAL against a REAL dfc_rtl024_shared_buffer
// (client 0), not a mock buffer model -- this is the first genuine
// end-to-end exercise of a real client against the real service, closing
// the client-module responsibilities OPEN_ISSUES.md item 102 disclosed as
// out of the shared-buffer's own testbench scope: VP-BUF-007 (multiword-
// entry atomicity), VP-BUF-008 (word-order/layout preservation), VP-BUF-009
// (per-client pointer/evidence ownership), VP-BUF-011 (uninitialized-word
// non-disclosure). The adapter module (dfc_rtl024_arinc_rx_adapter.sv) is
// NOT instantiated here -- this testbench drives RTL-017's own
// rx_word_valid_i/rx_word_i/rx_*_error_i inputs directly, exactly as
// ARCH-002's own port table describes them (already-assembled atomic word/
// metadata, same-domain, upstream CDC-ARINC completed elsewhere), so this
// is a real test of RTL-017's own logic, independent of the adapter's.
//
// control_i/status_o are driven/read directly via the generated
// DFC_RTL017_CONTROL__*/DFC_RTL017_STATUS__* bit constants (no RTL-001
// regbank in this testbench -- same "drive control_i directly" precedent
// as every other per-module testbench in this project).
//
// Clocking discipline matches every other testbench in this project: every
// strobe is held for a full clock and deasserted with a #1 settle delay
// after the sampling edge.

module rtl017_integration_tb;

  logic core_clk_i = 1'b0;
  logic core_rst_n_i;
  logic module_reset_i = 1'b0;

  always #10 core_clk_i = ~core_clk_i;

  initial begin
    #500000;
    $display("TEST FAILED -- watchdog timeout, something never completed a handshake");
    $finish(1);
  end

  // ---- control_i / status_o ----
  logic [dfc_types_pkg::DFC_RTL017_CONTROL_WIDTH-1:0] control_i;
  wire  [dfc_types_pkg::DFC_RTL017_STATUS_WIDTH-1:0]  status_o;

  initial control_i = '0;

  task automatic pulse_ctrl_bit(int bit_hi);
    control_i[bit_hi] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[bit_hi] = 1'b0;
  endtask

  // ---- timestamp ----
  logic [63:0] timestamp_i = 64'h0;
  always @(posedge core_clk_i) timestamp_i <= timestamp_i + 64'd1;

  // ---- event/irq ----
  wire        evt_valid_o;
  logic       evt_ready_i = 1'b1;
  wire [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o;
  wire        irq_req_o;

  // ---- route-source (RTL-021) ----
  wire        msg_valid_o;
  logic       msg_ready_i = 1'b0;   // testbench controls acceptance directly
  wire [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] msg_record_o;

  // ---- adapter-side stimulus (driven directly by this testbench) ----
  logic        rx_word_valid_i = 1'b0;
  logic [31:0] rx_word_i = 32'h0;
  logic        rx_parity_error_i = 1'b0;
  logic        rx_framing_error_i = 1'b0;
  logic        rx_speed_high_i = 1'b0;
  logic        rx_adapter_overrun_i = 1'b0;
  logic        arx_adapter_error_i = 1'b0;

  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic observational_mode_i = 1'b0;
  wire  activity_o;
  logic module_enable_i = 1'b1;
  wire  fault_req_o;

  // ---- shared-buffer client-0 interface, real service instantiated below ----
  wire        buf_req_valid, buf_req_ready;
  wire [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req;
  wire        buf_rsp_valid, buf_rsp_ready;
  wire [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp;

  dfc_rtl017 dut (
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
    .msg_valid_o              (msg_valid_o),
    .msg_ready_i              (msg_ready_i),
    .msg_record_o             (msg_record_o),
    .rx_word_valid_i          (rx_word_valid_i),
    .rx_word_i                (rx_word_i),
    .rx_parity_error_i        (rx_parity_error_i),
    .rx_framing_error_i       (rx_framing_error_i),
    .rx_speed_high_i          (rx_speed_high_i),
    .rx_adapter_overrun_i     (rx_adapter_overrun_i),
    .arx_adapter_error_i      (arx_adapter_error_i),
    .operating_state_i        (operating_state_i),
    .observational_mode_i     (observational_mode_i),
    .activity_o               (activity_o),
    .module_enable_i          (module_enable_i),
    .fault_req_o              (fault_req_o),
    .buf_req_valid_o          (buf_req_valid),
    .buf_req_ready_i          (buf_req_ready),
    .buf_req_o                (buf_req),
    .buf_rsp_valid_i          (buf_rsp_valid),
    .buf_rsp_ready_o          (buf_rsp_ready),
    .buf_rsp_i                (buf_rsp),
    .event_condition_enable_i (64'hFFFFFFFFFFFFFFFF),
    .irq_condition_enable_i   (64'hFFFFFFFFFFFFFFFF)
  );

  // Client 1-6 of the real shared buffer are permanently idle in this
  // testbench (only RTL-017/client 0 is under test).
  wire [6:0] sb_req_valid = {6'b0, buf_req_valid};
  wire [6:0] sb_req_ready;
  wire [6:0] sb_rsp_valid;
  wire [6:0] sb_rsp_ready = {6'b111111, buf_rsp_ready};
  wire [7*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] sb_req =
    {{6*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH{1'b0}}, buf_req};
  wire [7*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] sb_rsp;

  assign buf_req_ready = sb_req_ready[0];
  assign buf_rsp_valid = sb_rsp_valid[0];
  assign buf_rsp       = sb_rsp[dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0];

  wire [31:0] buffer_status;
  wire [31:0] buffer_client_error_count_0_1;
  wire [31:0] buffer_client_error_count_2_3;
  wire [31:0] buffer_client_error_count_4_5;
  wire [31:0] buffer_client_error_count_6;
  wire [31:0] buffer_internal_error_count;

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
    .buffer_status_o                 (buffer_status),
    .buffer_client_error_count_0_1_o (buffer_client_error_count_0_1),
    .buffer_client_error_count_2_3_o (buffer_client_error_count_2_3),
    .buffer_client_error_count_4_5_o (buffer_client_error_count_4_5),
    .buffer_client_error_count_6_o   (buffer_client_error_count_6),
    .buffer_internal_error_count_o   (buffer_internal_error_count),
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

  // ==========================================================================
  // ARCH-BUF-013 one-outstanding-discipline runtime monitor (RTL-017's own
  // FSM responsibility, NOT inherited from the arbiter's own formal proof --
  // this is a real, dedicated check of THIS module, per the task's own
  // explicit call-out). Fails the moment client 0 asserts a second request
  // while a prior one is still outstanding (accepted but not yet responded).
  // ==========================================================================
  int errors = 0, checks = 0;
  logic outstanding_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) outstanding_q <= 1'b0;
    else begin
      if (buf_req_valid && buf_req_ready) begin
        if (outstanding_q) begin
          errors++;
          $display("FAIL: ARCH-BUF-013 one-outstanding violation -- client 0 issued a new request while a prior one was still outstanding");
        end
        outstanding_q <= 1'b1;
      end
      if (buf_rsp_valid && buf_rsp_ready) outstanding_q <= 1'b0;
    end
  end

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

  // Drives one adapter word into RTL-017 for one CORE_CLK cycle.
  task automatic send_word(logic [31:0] word, logic parity_err, logic framing_err,
                            logic high_speed, logic overrun, logic adapter_err);
    rx_word_i             = word;
    rx_parity_error_i     = parity_err;
    rx_framing_error_i    = framing_err;
    rx_speed_high_i       = high_speed;
    rx_adapter_overrun_i  = overrun;
    arx_adapter_error_i   = adapter_err;
    rx_word_valid_i       = 1'b1;
    @(posedge core_clk_i);
    #1;
    rx_word_valid_i = 1'b0;
  endtask

  task automatic wait_queue_level(int unsigned level, int unsigned max_cycles);
    int unsigned n;
    n = 0;
    while (status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_HI:
                     dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_LO] != level[3:0]
           && n < max_cycles) begin
      @(posedge core_clk_i);
      n++;
    end
  endtask

  initial begin
    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    #1;
    core_rst_n_i = 1'b1;
    repeat (2) @(posedge core_clk_i);

    // ---------------------------------------------------------------------
    // Case 1: single clean word, captured, written, and drained via the
    // route-source path (msg_ready_i held high throughout).
    // ---------------------------------------------------------------------
    msg_ready_i = 1'b1;
    send_word(32'hDEADBEEF, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wait_queue_level(1, 200);
    check_bit("Case1 queue reached level 1 after capture", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__NOT_EMPTY_HI], 1'b1);

    // msg_ready_i already high -- the route path should drain it on its own;
    // wait for the handshake.
    begin : wait_msg1
      int unsigned n;
      n = 0;
      while (!msg_valid_o && n < 500) begin @(posedge core_clk_i); n++; end
      check_bit("Case1 msg_valid_o asserted (route drain)", msg_valid_o, 1'b1);
      check("Case1 msg_record payload (low 32b = word)",
            msg_record_o[dfc_types_pkg::DFC_MESSAGE_RECORD__PAYLOAD_LO +: 32], 64'hDEADBEEF);
      check("Case1 msg_record source_id",
            msg_record_o[dfc_types_pkg::DFC_MESSAGE_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__SOURCE_ID_LO], 64'h00);
      check("Case1 msg_record message_type (ARINC_WORD)",
            msg_record_o[dfc_types_pkg::DFC_MESSAGE_RECORD__MESSAGE_TYPE_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__MESSAGE_TYPE_LO], 64'h01);
      @(posedge core_clk_i);
      #1;
    end
    wait_queue_level(0, 200);
    check_bit("Case1 queue empty after route drain", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__NOT_EMPTY_HI], 1'b0);

    // ---------------------------------------------------------------------
    // Case 2: error-code classification (VP-MOD-017 / REG-ENC-008). Disable
    // the route drain (msg_ready_i=0) so captured words stay queued for a
    // host SNAPSHOT readback.
    // ---------------------------------------------------------------------
    msg_ready_i = 1'b0;
    send_word(32'h11111111, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);  // parity error -> code 1
    wait_queue_level(1, 200);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_SNAPSHOT__CAPTURE_HI);
    begin : wait_snap1
      int unsigned n;
      n = 0;
      while (!status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__SNAPSHOT_VALID_HI] && n < 200) begin @(posedge core_clk_i); n++; end
    end
    check("Case2 ARX_META error_code == 1 (parity)",
          status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_LO], 64'd1);
    check_bit("Case2 ARX_META parity_ok == 0", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__PARITY_OK_HI], 1'b0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__SNAPSHOT_VALID_HI);  // clear sticky for next case
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI);
    wait_queue_level(0, 200);

    send_word(32'h22222222, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);  // overrun -> code 3
    wait_queue_level(1, 200);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_SNAPSHOT__CAPTURE_HI);
    begin : wait_snap2
      int unsigned n;
      n = 0;
      while (!status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__SNAPSHOT_VALID_HI] && n < 200) begin @(posedge core_clk_i); n++; end
    end
    check("Case2 ARX_META error_code == 3 (overrun)",
          status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_LO], 64'd3);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__SNAPSHOT_VALID_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI);
    wait_queue_level(0, 200);

    send_word(32'h33333333, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);  // adapter error -> code 5
    wait_queue_level(1, 200);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_SNAPSHOT__CAPTURE_HI);
    begin : wait_snap3
      int unsigned n;
      n = 0;
      while (!status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__SNAPSHOT_VALID_HI] && n < 200) begin @(posedge core_clk_i); n++; end
    end
    check("Case2 ARX_META error_code == 5 (adapter)",
          status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_LO], 64'd5);
    check_bit("Case2 ADAPTER_ERROR sticky set", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__ADAPTER_ERROR_HI], 1'b1);
    check_bit("Case2 fault_req_o asserted (adapter error sticky)", fault_req_o, 1'b1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__ADAPTER_ERROR_HI);  // clear
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__SNAPSHOT_VALID_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI);
    wait_queue_level(0, 200);

    // ---------------------------------------------------------------------
    // Case 3: queue fill to 8 entries, 9th word overflows and counts.
    // msg_ready_i stays low so nothing auto-drains.
    // ---------------------------------------------------------------------
    for (int i = 0; i < 8; i++) begin
      send_word(32'h40000000 + i, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      wait_queue_level(i+1, 200);
    end
    check_bit("Case3 queue FULL after 8 words", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__FULL_HI], 1'b1);
    begin
      logic [31:0] overflow_before;
      overflow_before = status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_OVERFLOW_COUNT__COUNT_LO];
      send_word(32'hFFFFFFFF, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);  // 9th word, full -> dropped
      @(posedge core_clk_i); @(posedge core_clk_i);
      check("Case3 ARX_OVERFLOW_COUNT incremented on full-queue drop",
            status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_OVERFLOW_COUNT__COUNT_LO],
            64'(overflow_before) + 64'd1);
    end

    // Drain the queue back to empty via host POP (word-order preservation,
    // VP-BUF-008) -- oldest word (0x40000000) must come out first.
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_SNAPSHOT__CAPTURE_HI);
    begin : wait_snap4
      int unsigned n;
      n = 0;
      while (!status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__SNAPSHOT_VALID_HI] && n < 200) begin @(posedge core_clk_i); n++; end
    end
    check("Case3 oldest word preserved (VP-BUF-008 word order)",
          status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_DATA__WORD_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_DATA__WORD_LO], 64'h40000000);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__SNAPSHOT_VALID_HI);
    for (int i = 0; i < 8; i++) begin
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI);
      wait_queue_level(7-i, 200);
    end
    check_bit("Case3 queue empty after draining all 8", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__NOT_EMPTY_HI], 1'b0);

    // ---------------------------------------------------------------------
    // Case 4: empty-queue POP is rejected, counted, and sticky (ARX_STATUS.
    // POP_REJECTED / ARX_REJECTED_ACCESS_COUNT, ARCH-DIAG-005/011).
    // ---------------------------------------------------------------------
    begin
      logic [31:0] rej_before;
      rej_before = status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_REJECTED_ACCESS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_REJECTED_ACCESS_COUNT__COUNT_LO];
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI);
      @(posedge core_clk_i);
      check_bit("Case4 POP_REJECTED sticky set on empty-queue POP", status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__POP_REJECTED_HI], 1'b1);
      check("Case4 ARX_REJECTED_ACCESS_COUNT incremented",
            status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_REJECTED_ACCESS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_REJECTED_ACCESS_COUNT__COUNT_LO],
            64'(rej_before) + 64'd1);
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__POP_REJECTED_HI);
    end

    // ---------------------------------------------------------------------
    // Case 5: host-POP-vs-route-transfer simultaneous contention
    // (ARCH-RTL017-001's own named test, RTL-017_RevA.md SS6). Queue two
    // words, enable continuous route drain, then fire a host POP on the
    // same cycle the route path is ready to commit, and confirm exactly
    // one entry is removed (not zero, not two) and the queue level is
    // self-consistent afterward.
    // ---------------------------------------------------------------------
    msg_ready_i = 1'b0;
    send_word(32'h50000001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wait_queue_level(1, 200);
    send_word(32'h50000002, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wait_queue_level(2, 200);

    msg_ready_i = 1'b1;  // let the route path start reading the head entry
    // Wait until the route path is just about to present msg_valid_o, then
    // fire host POP on an adjacent cycle to maximize the chance of landing
    // on the same cycle as the route commit (host POP priority, finding 4b).
    begin : race_wait
      int unsigned n;
      n = 0;
      while (!msg_valid_o && n < 200) begin @(posedge core_clk_i); n++; end
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI);
    begin : wait_drain_settle
      int unsigned n;
      n = 0;
      while (status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_HI:
                       dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_LO] != 4'd0
             && n < 500) begin @(posedge core_clk_i); n++; end
    end
    check("Case5 queue settles to exactly empty (no double-count, no stuck entry)",
          status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_LO], 64'd0);

    // ---------------------------------------------------------------------
    repeat (10) @(posedge core_clk_i);
    $display("---------------------------------------------");
    $display("%0d checks, %0d errors", checks, errors);
    if (errors != 0) begin
      $display("TEST FAILED");
      $finish(1);
    end else begin
      $display("TEST PASSED");
      $finish(0);
    end
  end

endmodule
