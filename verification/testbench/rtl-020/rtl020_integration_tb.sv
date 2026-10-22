`timescale 1ns/1ps
// rtl020_integration_tb.sv -- dedicated testbench for RTL-020 (UART
// Interface), dfc_rtl020.sv, ARCH-RTL020-001.
//
// Instantiates dfc_rtl020 REAL against a REAL dfc_rtl024_shared_buffer
// (same "real client against the real service" discipline every prior
// Databus module's own testbench established). UART_BAUD_DIV.DIVISOR is
// driven to small simulation-only values via control_i (the real,
// host-visible register, not a module parameter -- RTL-020 has no
// CYCLES_PER_BIT-style override parameter since DIVISOR is a real runtime
// register, unlike ARINC's fixed Mark-33-DITS rates) so a full ~11-bit
// frame completes in a tractable number of cycles.
//
// control_i/status_o are driven/read directly via the generated
// DFC_RTL020_CONTROL__*/DFC_RTL020_STATUS__* bit constants (no RTL-001
// regbank in this testbench -- same precedent as every other per-module
// testbench in this project).

module rtl020_integration_tb;

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
  logic [dfc_types_pkg::DFC_RTL020_CONTROL_WIDTH-1:0] control_i;
  wire  [dfc_types_pkg::DFC_RTL020_STATUS_WIDTH-1:0]  status_o;

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

  // ---- event/irq ----
  wire        evt_valid_o;
  logic       evt_ready_i = 1'b1;
  wire [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o;
  wire        irq_req_o;
  wire        fault_req_o;

  // ---- physical UART pins ----
  logic uart_rx_i = 1'b1; // idle high
  wire  uart_tx_o;

  // ---- route ports (RTL-021), real in THIS testbench (no RTL-024
  // integration stub tie-off here -- finding 13's own self-referential
  // routing case needs these actually driven/observed) ----
  wire        rx_msg_valid_o;
  logic       rx_msg_ready_i = 1'b0;
  wire [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] rx_msg_record_o;
  logic       tx_msg_valid_i = 1'b0;
  wire        tx_msg_ready_o;
  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] tx_msg_record_i = '0;

  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic observational_mode_i = 1'b0;
  wire  activity_o;
  logic module_enable_i = 1'b1;
  logic effective_operational_enable_i = 1'b1;

  wire        buf_req_valid, buf_req_ready;
  wire [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req;
  wire        buf_rsp_valid, buf_rsp_ready;
  wire [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp;

  dfc_rtl020 dut (
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
    .uart_rx_i                (uart_rx_i),
    .uart_tx_o                (uart_tx_o),
    .rx_msg_valid_o           (rx_msg_valid_o),
    .rx_msg_ready_i           (rx_msg_ready_i),
    .rx_msg_record_o          (rx_msg_record_o),
    .tx_msg_valid_i           (tx_msg_valid_i),
    .tx_msg_ready_o           (tx_msg_ready_o),
    .tx_msg_record_i          (tx_msg_record_i),
    .operating_state_i        (operating_state_i),
    .observational_mode_i     (observational_mode_i),
    .activity_o               (activity_o),
    .module_enable_i          (module_enable_i),
    .effective_operational_enable_i (effective_operational_enable_i),
    .buf_req_valid_o          (buf_req_valid),
    .buf_req_ready_i          (buf_req_ready),
    .buf_req_o                (buf_req),
    .buf_rsp_valid_i          (buf_rsp_valid),
    .buf_rsp_ready_o          (buf_rsp_ready),
    .buf_rsp_i                (buf_rsp),
    .event_condition_enable_i (64'hFFFFFFFFFFFFFFFF),
    .irq_condition_enable_i   (64'hFFFFFFFFFFFFFFFF)
  );

  // Client 3's own real slot number doesn't matter here -- dfc_rtl020.sv's
  // own addressing is purely client-relative, same precedent as every
  // prior Databus module's own testbench.
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

  // ==========================================================================
  // Real DIVISOR used for the whole run -- deliberately small (simulation-
  // only) so an ~11-bit frame completes in a tractable number of cycles,
  // the same "parameterize/override real timing for sim" technique as
  // every prior serial module's own testbench, here via the real,
  // host-visible DIVISOR register itself (RTL-020 has no module parameter
  // for this -- DIVISOR is a real runtime register, unlike ARINC's fixed
  // rates).
  // ==========================================================================
  localparam int unsigned DIV = 40;

  // ==========================================================================
  // Serial RX driver: bit-bangs one byte onto uart_rx_i at the real,
  // configured DIVISOR (CORE_CLK cycles/bit), LSB-first, with explicit
  // control over parity-bit value and stop-bit value so framing/parity/
  // break cases can each be driven exactly, not just the legal case.
  // ==========================================================================
  task automatic drive_rx_frame(
    input logic [7:0] data,
    input bit          send_parity,
    input logic         parity_bit_val,
    input logic         stop_bit_val,
    input bit          two_stop
  );
    int unsigned i;
    // Every transition is settled #1 AFTER a clock edge, never driven
    // "bare" right after @(posedge) -- a real race was found and fixed
    // here: driving uart_rx_i with a plain blocking assignment at the
    // exact same simulation instant as a posedge (the previous task's own
    // final @(posedge)) left the DUT's own always_ff block racing against
    // this testbench process for which value (old or new) it observed
    // AT that edge, intermittently/silently losing the falling-edge
    // detection entirely depending on simulator-internal process
    // ordering -- the same "#1 settle delay after the sampling edge"
    // discipline this project's own testbenches already use elsewhere
    // (dfc_rtl018.sv's own testbench header comment), just not yet
    // applied to a serial bit-banger task before this file existed.
    @(posedge core_clk_i); #1; uart_rx_i = 1'b0; // start bit
    repeat (DIV - 1) @(posedge core_clk_i);
    for (i = 0; i < 8; i++) begin
      @(posedge core_clk_i); #1; uart_rx_i = data[i];
      repeat (DIV - 1) @(posedge core_clk_i);
    end
    if (send_parity) begin
      @(posedge core_clk_i); #1; uart_rx_i = parity_bit_val;
      repeat (DIV - 1) @(posedge core_clk_i);
    end
    @(posedge core_clk_i); #1; uart_rx_i = stop_bit_val;
    repeat (DIV - 1) @(posedge core_clk_i);
    if (two_stop) begin
      @(posedge core_clk_i); #1; uart_rx_i = 1'b1; // second stop bit's own value is not separately validated (finding 9)
      repeat (DIV - 1) @(posedge core_clk_i);
    end
    @(posedge core_clk_i); #1; uart_rx_i = 1'b1; // idle
    repeat (DIV - 1) @(posedge core_clk_i);
  endtask

  task automatic drive_rx_break();
    int unsigned i;
    @(posedge core_clk_i); #1; uart_rx_i = 1'b0;
    repeat (DIV * 10 - 1) @(posedge core_clk_i); // start + 8 data + stop, all held low
    @(posedge core_clk_i); #1; uart_rx_i = 1'b1;
    repeat (DIV - 1) @(posedge core_clk_i);
  endtask

  function automatic logic [4:0] rx_level();
    rx_level = status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_LEVEL__LEVEL_HI:
                         dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_LEVEL__LEVEL_LO];
  endfunction
  function automatic logic [4:0] tx_level();
    tx_level = status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_LEVEL__LEVEL_HI:
                         dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_LEVEL__LEVEL_LO];
  endfunction

  task automatic wait_rx_level(int unsigned level, int unsigned max_cycles);
    int unsigned n;
    n = 0;
    while (rx_level() != level[4:0] && n < max_cycles) begin
      @(posedge core_clk_i);
      n++;
    end
  endtask

  task automatic wait_tx_level(int unsigned level, int unsigned max_cycles);
    int unsigned n;
    n = 0;
    while (tx_level() != level[4:0] && n < max_cycles) begin
      @(posedge core_clk_i);
      n++;
    end
  endtask

  // Captures one TX frame's worth of bit samples (one sample per bit time,
  // mid-bit) into a dynamic array, for direct waveform verification.
  task automatic capture_tx_frame(output logic bits[], input int unsigned n_bits);
    int unsigned i;
    bits = new[n_bits];
    // wait for the start bit to actually begin (uart_tx_o falls from idle)
    while (uart_tx_o !== 1'b0) @(posedge core_clk_i);
    for (i = 0; i < n_bits; i++) begin
      repeat (DIV/2) @(posedge core_clk_i);
      bits[i] = uart_tx_o;
      repeat (DIV - DIV/2) @(posedge core_clk_i);
    end
  endtask

  initial begin
    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    core_rst_n_i = 1'b1;
    repeat (4) @(posedge core_clk_i);

    // ---- Case 1: enable, no parity, 1 stop bit, real small DIVISOR ----
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_BAUD_DIV__DIVISOR_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_BAUD_DIV__DIVISOR_LO, DIV);
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__ENABLE_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__EVENT_ENABLE_HI] = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__IRQ_ENABLE_HI] = 1'b1;
    repeat (4) @(posedge core_clk_i);
    check_bit("Case1 UART_STATUS.ENABLED reflects real ENABLE", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__ENABLED_HI], 1'b1);

    // ---- Case 2: real TX byte, verify the real serial waveform
    // (start=0, 8 data bits LSB-first, stop=1) -- byte-valid atomicity
    // and the real 16-phase divider are exercised together here since
    // the serializer itself uses the same real DIVISOR timing. ----
    begin
      logic bits[];
      logic [7:0] expected_byte;
      expected_byte = 8'hA5;
      set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
                dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'hA5);
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
      wait_tx_level(1, 200);
      check("Case2 TX_LEVEL reaches 1 after PUSH", tx_level(), 5'd1);
      capture_tx_frame(bits, 10);
      check_bit("Case2 start bit is 0", bits[0], 1'b0);
      for (int b = 0; b < 8; b++)
        check_bit($sformatf("Case2 data bit %0d == 0x%0h bit %0d", b, 8'hA5, b), bits[1+b], expected_byte[b]);
      check_bit("Case2 stop bit is 1", bits[9], 1'b1);
      wait_tx_level(0, 600);
      check_bit("Case2 UART_STATUS.COMPLETE sticky set after real serialization", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_BUSY_HI], 1'b0);
    end

    // ---- Case 3: real RX byte (no parity), correct framing -- byte+flags
    // becomes valid atomically, DATA/ERROR_FLAGS/sequence all real ----
    drive_rx_frame(8'h3C, 1'b0, 1'b0, 1'b1, 1'b0);
    wait_rx_level(1, 600);
    check("Case3 RX_LEVEL reaches 1 after a real framed byte", rx_level(), 5'd1);
    check("Case3 UART_RX_DATA.DATA is the real received byte", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__DATA_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__DATA_LO], 8'h3C);
    check("Case3 UART_RX_DATA.ERROR_FLAGS is clean (no real error)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__ERROR_FLAGS_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__ERROR_FLAGS_LO], 8'h00);
    check_bit("Case3 UART_RX_DATA.VALID genuinely asserts", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__VALID_HI], 1'b1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);
    check("Case3 RX_LEVEL returns to 0 after POP", rx_level(), 5'd0);

    // ---- Case 4: even parity, correct and incorrect ----
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO] = 2'b01;
    // 8'h0F has four 1-bits -> even parity bit = XOR-reduce = 0
    drive_rx_frame(8'h0F, 1'b1, 1'b0, 1'b1, 1'b0);
    wait_rx_level(1, 600);
    check_bit("Case4 correct EVEN parity -> no PARITY_ERROR", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__PARITY_ERROR_HI], 1'b0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);
    // same byte, WRONG parity bit (1 instead of 0)
    drive_rx_frame(8'h0F, 1'b1, 1'b1, 1'b1, 1'b0);
    wait_rx_level(1, 600);
    check_bit("Case4 incorrect EVEN parity -> real PARITY_ERROR sticky", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__PARITY_ERROR_HI], 1'b1);
    check_bit("Case4 byte+flags still queued atomically despite parity error (ARCH-RTL020-001)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__VALID_HI], 1'b1);
    check("Case4 UART_RX_DATA.ERROR_FLAGS bit1 (parity) set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__ERROR_FLAGS_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__ERROR_FLAGS_LO] & 8'h02, 8'h02);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__PARITY_ERROR_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);

    // ---- Case 5: odd parity, correct ----
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO] = 2'b10;
    // 8'h0F: XOR-reduce=0, ODD parity bit = ~XOR-reduce = 1
    drive_rx_frame(8'h0F, 1'b1, 1'b1, 1'b1, 1'b0);
    wait_rx_level(1, 600);
    check_bit("Case5 correct ODD parity -> no PARITY_ERROR", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__PARITY_ERROR_HI], 1'b0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);

    // ---- Case 6: PARITY==2'b11 defensive clamp (REG-ENC-007: "parity 3
    // is rejected") -- behaves identically to PARITY==0 (no parity bit
    // sampled/expected at all). ----
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO] = 2'b11;
    drive_rx_frame(8'h55, 1'b0, 1'b0, 1'b1, 1'b0); // no parity bit sent, just data+stop
    wait_rx_level(1, 600);
    check("Case6 PARITY=3 clamps to 'none' -- byte received cleanly with no parity bit expected", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__DATA_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__DATA_LO], 8'h55);
    check_bit("Case6 PARITY=3 clamp -> no spurious PARITY_ERROR", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__PARITY_ERROR_HI], 1'b0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO] = 2'b00;

    // ---- Case 7: real FRAMING_ERROR (stop bit sampled 0), byte still
    // queued atomically (ARCH-RTL020-001) ----
    drive_rx_frame(8'h77, 1'b0, 1'b0, 1'b0, 1'b0); // stop bit driven low
    wait_rx_level(1, 600);
    check_bit("Case7 real FRAMING_ERROR sticky set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__FRAMING_ERROR_HI], 1'b1);
    check_bit("Case7 byte+flags still queued atomically despite framing error", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__VALID_HI], 1'b1);
    // (cumulative: Case4's own incorrect-parity frame already incremented
    // this same aggregate counter by 1, so the real running total here is
    // 2, not 1 -- UART_ERROR_COUNT is a deliberately aggregate, running
    // counter (finding 11), not reset between cases. Cleared explicitly
    // right after this check so later cases start from a clean baseline.)
    check("Case7 UART_ERROR_COUNT incremented by the real framing error (cumulative with Case4's)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_ERROR_COUNT__COUNT_LO], 32'd2);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__FRAMING_ERROR_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);
    check("Case7 cleanup: RX queue genuinely drained before Case8 begins", rx_level(), 5'd0);
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_LO, 32'hFFFFFFFF);
    @(posedge core_clk_i); #1;
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_LO, 32'h0);

    // ---- Case 7b: REAL BUG REGRESSION (OPEN_ISSUES.md item 172) --
    // simultaneous framing+parity errors on ONE byte must count as TWO
    // aggregate errors, not one. The original bug (error_count_q's own
    // increment split across two independent always_ff processes, with
    // the SAME-process framing/parity branches each computing "+1" off
    // the same stale old value) silently dropped one of the two
    // same-cycle increments -- this exact scenario is the direct proof
    // that bug is gone. ----
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO] = 2'b01; // even parity required
    // 8'h0F has four 1-bits -> correct EVEN parity bit is 0; drive 1
    // (wrong, real PARITY_ERROR) AND stop bit 0 (real FRAMING_ERROR) on
    // the very same byte.
    drive_rx_frame(8'h0F, 1'b1, 1'b1, 1'b0, 1'b0);
    wait_rx_level(1, 600);
    check_bit("Case7b simultaneous-error byte: real FRAMING_ERROR sticky set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__FRAMING_ERROR_HI], 1'b1);
    check_bit("Case7b simultaneous-error byte: real PARITY_ERROR sticky set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__PARITY_ERROR_HI], 1'b1);
    check("Case7b UART_ERROR_COUNT incremented by 2 for one byte with BOTH framing+parity errors simultaneously (the real multi-driver/undercount bug this session fixed -- OPEN_ISSUES.md item 172 -- previously only counted 1)",
          status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_ERROR_COUNT__COUNT_LO], 32'd2);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__FRAMING_ERROR_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__PARITY_ERROR_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_LO, 32'hFFFFFFFF);
    @(posedge core_clk_i); #1;
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_LO, 32'h0);
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO] = 2'b00;

    // ---- Case 8: real BREAK_DETECTED (entire frame held low) --
    // OVERRIDES framing/parity reporting, and (this module's own disclosed
    // choice) no byte is queued for a break. ----
    drive_rx_break();
    repeat (20) @(posedge core_clk_i);
    check_bit("Case8 real BREAK_DETECTED sticky set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__BREAK_DETECTED_HI], 1'b1);
    check_bit("Case8 FRAMING_ERROR NOT also set (break overrides, disclosed priority)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__FRAMING_ERROR_HI], 1'b0);
    check("Case8 no byte queued for a break (disclosed choice)", rx_level(), 5'd0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__BREAK_DETECTED_HI);

    // ---- Case 9: TWO_STOP_BITS -- TX waveform includes 2 real stop bits;
    // RX with a real second stop bit (first stop bit still correct) does
    // not misclassify. ----
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__TWO_STOP_BITS_HI] = 1'b1;
    begin
      logic bits[];
      set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
                dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'h01);
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
      wait_tx_level(1, 200);
      capture_tx_frame(bits, 11);
      check_bit("Case9 TWO_STOP_BITS: first stop bit is 1", bits[9], 1'b1);
      check_bit("Case9 TWO_STOP_BITS: second stop bit is also 1", bits[10], 1'b1);
      wait_tx_level(0, 600);
    end
    drive_rx_frame(8'h22, 1'b0, 1'b0, 1'b1, 1'b1);
    wait_rx_level(1, 600);
    check_bit("Case9 TWO_STOP_BITS RX: real first-stop-bit-good frame has no framing error", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__FRAMING_ERROR_HI], 1'b0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    wait_rx_level(0, 600);
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__TWO_STOP_BITS_HI] = 1'b0;

    // ---- Case 10: real RX overflow -- fill the 16-deep RX queue, then
    // drive one more real byte; the extra byte is dropped, not queued,
    // and UART_RX_OVERFLOW_COUNT/RX_OVERFLOW increment. ----
    for (int n = 0; n < 16; n++) begin
      drive_rx_frame(8'(n), 1'b0, 1'b0, 1'b1, 1'b0);
    end
    wait_rx_level(16, 2000);
    check("Case10 RX queue genuinely full at 16", rx_level(), 5'd16);
    drive_rx_frame(8'hFF, 1'b0, 1'b0, 1'b1, 1'b0);
    repeat (20) @(posedge core_clk_i);
    check("Case10 RX queue stays at 16 (extra byte genuinely dropped)", rx_level(), 5'd16);
    check_bit("Case10 real RX_OVERFLOW sticky set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__RX_OVERFLOW_HI], 1'b1);
    check("Case10 UART_RX_OVERFLOW_COUNT incremented", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_OVERFLOW_COUNT__COUNT_LO], 32'd1);
    for (int n = 0; n < 16; n++) begin
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
      wait_rx_level(15-n, 600);
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__RX_OVERFLOW_HI);

    // ---- Case 11: real RX underflow -- POP on an empty queue ----
    check("Case11 RX queue genuinely empty before the POP", rx_level(), 5'd0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI);
    repeat (5) @(posedge core_clk_i);
    check_bit("Case11 real RX_UNDERFLOW sticky set", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__RX_UNDERFLOW_HI], 1'b1);
    check("Case11 UART_RX_UNDERFLOW_COUNT incremented", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_UNDERFLOW_COUNT__COUNT_LO], 32'd1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__RX_UNDERFLOW_HI);

    // ---- Case 12: real TX underflow -- TX engine idle-while-empty.
    // Cleared to a known baseline first: the TX queue has already gone
    // idle-empty-enabled twice incidentally before this point (once right
    // after Case1's own ENABLE with an empty queue, once after Case9's TX
    // byte completed) -- each a real, distinct occurrence, not a bug, but
    // this case specifically wants to isolate "exactly one NEW occurrence"
    // from here. ----
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_UNDERFLOW_COUNT__COUNT_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_UNDERFLOW_COUNT__COUNT_LO, 32'hFFFFFFFF);
    @(posedge core_clk_i); #1;
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_UNDERFLOW_COUNT__COUNT_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_UNDERFLOW_COUNT__COUNT_LO, 32'h0);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__TX_UNDERFLOW_HI);
    // toggle the queue non-empty-then-empty-again so the pending latch
    // re-arms and this case's own occurrence is genuinely counted fresh
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'h00);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
    wait_tx_level(1, 200);
    wait_tx_level(0, 600);
    repeat (5) @(posedge core_clk_i);
    check_bit("Case12 real TX_UNDERFLOW sticky set (TX idle, queue empty, enabled)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_UNDERFLOW_HI], 1'b1);
    check("Case12 UART_TX_UNDERFLOW_COUNT incremented exactly once (not per-cycle)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_UNDERFLOW_COUNT__COUNT_LO], 32'd1);
    repeat (200) @(posedge core_clk_i);
    check("Case12 UART_TX_UNDERFLOW_COUNT still exactly 1 after a long idle-empty spell", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_UNDERFLOW_COUNT__COUNT_LO], 32'd1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__TX_UNDERFLOW_HI);

    // ---- Case 13: real TX_REJECTED -- PUSH while disabled ----
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__ENABLE_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
    repeat (5) @(posedge core_clk_i);
    check_bit("Case13 real TX_REJECTED sticky set (PUSH while disabled)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_REJECTED_HI], 1'b1);
    check("Case13 UART_TX_REJECTED_COUNT incremented", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_REJECTED_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_REJECTED_COUNT__COUNT_LO], 32'd1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__TX_REJECTED_HI);
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__ENABLE_HI] = 1'b1;
    repeat (4) @(posedge core_clk_i);

    // ---- Case 14: host-push-vs-route-input last-free-slot tiebreaker
    // (ARCH-RTL020-001). Fill the TX queue to 15 (one free slot), then
    // assert a host PUSH and a route tx_msg_valid_i on the same cycle:
    // host must win, route stays genuinely backpressured (tx_msg_ready_o
    // low), not counted as lost. ----
    for (int n = 0; n < 15; n++) begin
      set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
                dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'(n));
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
      wait_tx_level(n+1, 600);
    end
    check("Case14 TX queue at 15 (one free slot)", tx_level(), 5'd15);
    tx_msg_record_i = {64'h0, 64'h0, 8'h00, 8'hEE, 56'h0}; // payload[71:64]=0xEE (route data byte)
    tx_msg_valid_i = 1'b1;
    set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
              dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'hDD);
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI] = 1'b0;
    check_bit("Case14 host wins the last-slot tiebreaker -- route stays backpressured this same cycle", tx_msg_ready_o, 1'b0);
    wait_tx_level(16, 600);
    check("Case14 TX queue now full (host's byte landed)", tx_level(), 5'd16);
    check_bit("Case14 route request still pending, not dropped/lost", tx_msg_valid_i, 1'b1);
    // drain one TX entry to free a slot, confirm route now gets serviced
    // -- a full byte serialization (~11 bits * DIV cycles/bit) takes far
    // longer than 16 cycles, the real bug this loop bound originally had.
    for (int n = 0; n < DIV * 15; n++) begin
      @(posedge core_clk_i);
      if (tx_msg_ready_o) break;
    end
    check_bit("Case14 route request genuinely accepted once a real slot freed up (not lost)", tx_msg_ready_o, 1'b1);
    tx_msg_valid_i = 1'b0;
    // drain the rest of the TX queue
    for (int n = 0; n < 16; n++) begin
      if (tx_level() == 5'd0) break;
      repeat (DIV * 12) @(posedge core_clk_i);
    end
    check("Case14 TX queue fully drained", tx_level(), 5'd0);

    // ---- Case 15: disable-vs-reset distinction (ARCH-RTL020-001's own
    // explicit text) -- its own dedicated case, not incidental reset
    // coverage. ----
    begin
      // (a) DISABLE mid-transmission: completes the current byte, then
      // idles high -- does NOT abort.
      set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
                dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'hFF);
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
      wait_tx_level(1, 200);
      // wait until mid-frame (well past the start bit, before the stop bit)
      repeat (DIV * 4) @(posedge core_clk_i);
      control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__ENABLE_HI] = 1'b0; // disable, NOT reset
      wait_tx_level(0, 600);
      check_bit("Case15a DISABLE mid-byte: the in-flight byte genuinely completed (graceful)", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_BUSY_HI], 1'b0);
      check_bit("Case15a uart_tx_o genuinely idles high after the completed byte", uart_tx_o, 1'b1);
      control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__ENABLE_HI] = 1'b1;
      repeat (4) @(posedge core_clk_i);

      // (b) RESET mid-transmission: aborts immediately, does not wait for
      // the frame to finish.
      set_field(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI,
                dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO, 8'h00); // all-0 data bits -> line stays low if NOT aborted
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI);
      wait_tx_level(1, 200);
      repeat (DIV * 2) @(posedge core_clk_i); // mid-frame, well before the real stop bit
      module_reset_i = 1'b1;
      @(posedge core_clk_i);
      #1;
      check_bit("Case15b RESET mid-byte: uart_tx_o genuinely forced high immediately, not left low mid-frame", uart_tx_o, 1'b1);
      check_bit("Case15b RESET mid-byte: TX engine genuinely back to idle, not still busy", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_BUSY_HI], 1'b0);
      module_reset_i = 1'b0;
      repeat (4) @(posedge core_clk_i);
      check("Case15b RESET genuinely discarded the in-flight byte (TX queue empty, not completed)", tx_level(), 5'd0);
    end

    // ---- Case 16: self-referential routing (ARCH-MSG-003: UART RX and
    // UART TX share module ID 0x02) -- the RX-side source port and the
    // TX-side destination port, confirmed as two ordinary, independent
    // paths, both real. ----
    drive_rx_frame(8'h5A, 1'b0, 1'b0, 1'b1, 1'b0);
    wait_rx_level(1, 600);
    check_bit("Case16 rx_msg_valid_o genuinely asserts once a real byte is head", rx_msg_valid_o, 1'b1);
    check("Case16 rx_msg_record_o.source_id == 0x02 (ARCH-MSG-003)", rx_msg_record_o[31:24], 8'h02);
    check("Case16 rx_msg_record_o.message_type == 0x04 (UART_BYTE)", rx_msg_record_o[23:16], 8'h04);
    check("Case16 rx_msg_record_o.payload_length == 1", rx_msg_record_o[15:12], 4'd1);
    check("Case16 rx_msg_record_o payload carries the real byte", rx_msg_record_o[71:64], 8'h5A);
    rx_msg_ready_i = 1'b1;
    @(posedge core_clk_i);
    #1;
    rx_msg_ready_i = 1'b0;
    wait_rx_level(0, 600);
    check("Case16 route-drain genuinely advanced the real RX queue (pure pointer bookkeeping, finding 3/4)", rx_level(), 5'd0);
    check_bit("Case16 UART_RX_DATA.VALID genuinely clears once the queue is empty", status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__VALID_HI], 1'b0);

    if (errors == 0) begin
      $display("%0d checks, 0 errors", checks);
      $display("TEST PASSED");
    end else begin
      $display("%0d checks, %0d errors", checks, errors);
      $display("TEST FAILED");
    end
    $finish;
  end

endmodule : rtl020_integration_tb
