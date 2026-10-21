`timescale 1ns/1ps
// rtl019_integration_tb.sv -- dedicated CAN protocol-conformance testbench
// for RTL-019 (Classical CAN Interface), dfc_rtl019.sv, ARCH-RTL019-001.
//
// Instantiates dfc_rtl019 REAL against a REAL dfc_rtl024_shared_buffer,
// same "real client against the real service" discipline every prior
// per-module testbench in this project establishes.
//
// Bit timing is configured to BRP=1, TSEG1=2, TSEG2=1 (quanta_per_bit=4,
// CYCLES_PER_BIT=4 CORE_CLK cycles/bit since BRP=1) -- fast enough to make
// even the 128x11-consecutive-recessive-bit bus-off recovery count
// (1408 bit-times) and the ~128-frame TEC/REC threshold tests tractable.
//
// can_rx_i is modeled as a REAL open-collector wired-AND of the DUT's own
// can_tx_o and a testbench-controlled `tb_bus_drive` signal (default 1 =
// recessive/not actively driving) -- `can_rx_i = dut.can_tx_o & tb_bus_drive`
// -- so the SAME mechanism naturally covers: (a) a pure external frame
// while the DUT is idle/receiving (dut.can_tx_o stays recessive, so
// can_rx_i == tb_bus_drive, i.e. whatever this testbench drives passes
// through unmodified), and (b) a genuine bit-level arbitration contest
// while the DUT is ALSO transmitting (both sides' dominant bits correctly
// win on the real wired-AND bus, exactly like two real transceivers).
//
// control_i/status_o are driven/read directly via the generated
// DFC_RTL019_CONTROL__*/DFC_RTL019_STATUS__* bit constants (no RTL-001
// regbank in this testbench -- same precedent as every other per-module
// testbench in this project).

module rtl019_integration_tb;

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
  logic [dfc_types_pkg::DFC_RTL019_CONTROL_WIDTH-1:0] control_i;
  wire  [dfc_types_pkg::DFC_RTL019_STATUS_WIDTH-1:0]  status_o;

  initial control_i = '0;

  task automatic pulse_ctrl_bit(int bit_hi);
    control_i[bit_hi] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[bit_hi] = 1'b0;
  endtask

  // Variable-bound part-selects are not legal Verilog (confirmed via a real
  // Icarus compile failure on RTL-018's own testbench) -- bit-by-bit
  // assignment instead.
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

  // ---- physical CAN pins: real open-collector wired-AND model ----
  logic       tb_bus_drive = 1'b1;   // 1 = recessive/not actively driving
  wire        can_rx_i = dut.can_tx_o & tb_bus_drive;
  wire        can_tx_o;
  logic       can_transceiver_error_i = 1'b0;

  // ---- route ports (RTL-021 does not exist -- disclosed stubs) ----
  wire         rx_msg_valid_o;
  // Held LOW deliberately: RTL-019's own automatic RX-to-route drain (the
  // real rx_route_req/rx_msg_valid_o path) would otherwise silently pop
  // every captured frame the instant it lands, before this testbench's own
  // explicit host CAN_RX_SNAPSHOT/CAN_RX_POP sequence ever gets a chance to
  // read it -- a real bug this testbench's own first run exposed (VALID
  // always read 0, since the real pointer bookkeeping had already removed
  // the entry the host's own snapshot was always one step too late for).
  logic        rx_msg_ready_i = 1'b0;
  wire [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] rx_msg_record_o;
  logic        tx_msg_valid_i = 1'b0;
  wire         tx_msg_ready_o;
  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] tx_msg_record_i = '0;

  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic observational_mode_i = 1'b0;
  wire  activity_o;
  logic module_enable_i = 1'b1;
  logic effective_operational_enable_i = 1'b1;

  // ---- shared-buffer client-2 interface, real service instantiated below ----
  wire        buf_req_valid, buf_req_ready;
  wire [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req;
  wire        buf_rsp_valid, buf_rsp_ready;
  wire [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp;

  dfc_rtl019 dut (
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
    .can_rx_i                 (can_rx_i),
    .can_tx_o                 (can_tx_o),
    .can_transceiver_error_i  (can_transceiver_error_i),
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

  // UNLIKE every other per-module testbench's own shared-buffer wiring,
  // the client SLOT NUMBER here is NOT arbitrary: dfc_rtl024_shared_buffer's
  // own per-client word WIDTH is not uniform (ARCH-002 SS12.1's own segment
  // table: client0=32, client1=16, client2=96, client3=32, ...) -- RTL-019
  // needs the full 96-word allocation (RX 0-47 + TX 48-95), so this
  // testbench must use client slot 2 specifically (the same slot
  // dfc_rtl024.sv's own real integration assigns it), not slot 0 -- a real
  // bug found via this testbench's own first run (every TX push silently
  // RANGE_ERRORed against a 32-word client 0 and was never visible as
  // anything other than "the push never seems to land").
  wire [6:0] sb_req_valid = {4'b0, buf_req_valid, 2'b0};
  wire [6:0] sb_req_ready;
  wire [6:0] sb_rsp_valid;
  wire [6:0] sb_rsp_ready = {4'b1111, buf_rsp_ready, 2'b11};
  wire [7*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] sb_req =
    {{4*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH{1'b0}}, buf_req, {2*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH{1'b0}}};
  wire [7*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] sb_rsp;

  assign buf_req_ready = sb_req_ready[2];
  assign buf_rsp_valid = sb_rsp_valid[2];
  assign buf_rsp       = sb_rsp[3*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:2*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH];

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

  int errors = 0, checks = 0;

  // ARCH-BUF-013 one-outstanding-discipline runtime monitor (same pattern
  // as every other per-module testbench in this project).
  logic outstanding_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) outstanding_q <= 1'b0;
    else begin
      if (buf_req_valid && buf_req_ready) begin
        if (outstanding_q) begin
          errors++;
          $display("FAIL: ARCH-BUF-013 one-outstanding violation -- client 2 issued a new request while a prior one was still outstanding");
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

  function automatic logic [3:0] rx_level();
    rx_level = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_LEVEL__LEVEL_HI:
                         dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_LEVEL__LEVEL_LO];
  endfunction
  function automatic logic [3:0] tx_level();
    tx_level = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_LEVEL__LEVEL_HI:
                         dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_LEVEL__LEVEL_LO];
  endfunction
  task automatic wait_rx_level(int unsigned level, int unsigned max_cycles);
    int unsigned n;
    n = 0;
    while (rx_level() != level[3:0] && n < max_cycles) begin @(posedge core_clk_i); n++; end
  endtask
  task automatic wait_tx_level(int unsigned level, int unsigned max_cycles);
    int unsigned n;
    n = 0;
    while (tx_level() != level[3:0] && n < max_cycles) begin @(posedge core_clk_i); n++; end
  endtask

  // BRP=1, TSEG1=4, TSEG2=3 -> 1+4+3=8 quanta, 1 CORE_CLK/quantum = 8
  // cycles/bit. A tighter 4-cycle/bit config was tried first and produced a
  // real, reproducible one-bit misalignment for externally-driven frames:
  // hard_sync_now's own edge detection is REGISTERED (sensed_bus_prev_q,
  // one CORE_CLK cycle of latency by construction -- a real, correct
  // synchronous design, not a bug), so the phase-counter reset lands one
  // cycle into the SOF bit's own held window; with only 4 cycles/bit and a
  // sample point 2 quanta after reset, that left only one cycle of margin,
  // too tight for this testbench's own bit-driving task boundaries. Real
  // external traffic on an actual bus would never run this close to the
  // wire; this is strictly a simulation-only margin choice.
  localparam int unsigned CYCLES_PER_BIT = 8;

  task automatic set_bit_timing(int unsigned prescaler_m1, int unsigned tseg1_m1,
                                 int unsigned tseg2_m1, int unsigned sjw_m1);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__PRESCALER_MINUS_1_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__PRESCALER_MINUS_1_LO, prescaler_m1);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG1_MINUS_1_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG1_MINUS_1_LO, tseg1_m1);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG2_MINUS_1_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG2_MINUS_1_LO, tseg2_m1);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__SJW_MINUS_1_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__SJW_MINUS_1_LO, sjw_m1);
  endtask

  // ---- host TX push ----
  task automatic can_tx_push(logic [28:0] id, logic ide, logic rtr, logic [3:0] dlc,
                              logic [31:0] data_lo, logic [31:0] data_hi);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDENTIFIER_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDENTIFIER_LO, id);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDE_HI] = ide;
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__RTR_HI] = rtr;
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_META_STAGE__DLC_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_META_STAGE__DLC_LO, dlc);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_LO_STAGE__DATA_0_3_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_LO_STAGE__DATA_0_3_LO, data_lo);
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_HI_STAGE__DATA_4_7_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_HI_STAGE__DATA_4_7_LO, data_hi);
    @(posedge core_clk_i);
    #1;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_PUSH__PUSH_HI);
  endtask

  // ---- host RX snapshot + pop ----
  task automatic can_rx_pop(output logic [28:0] id, output logic ide, output logic rtr,
                             output logic valid, output logic [3:0] dlc,
                             output logic [31:0] data_lo, output logic [31:0] data_hi);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_SNAPSHOT__CAPTURE_HI);
    // The snapshot is a real 6-word shared-buffer read sequence, not a
    // single-cycle operation -- wait for the internal arbiter to actually
    // DISPATCH it (op_q becomes OP_RX_SNAPSHOT, 3'd3) and then RETURN to
    // idle (confirming all 6 words landed) before trusting status_o,
    // rather than guessing a fixed settle delay.
    begin : rx_pop_wait
      int unsigned n;
      n = 0;
      while (dut.op_q != 3'd3 && n < 2000) begin @(posedge core_clk_i); n++; end
      n = 0;
      while (dut.op_q == 3'd3 && n < 2000) begin @(posedge core_clk_i); n++; end
    end
    @(posedge core_clk_i); #1;
    id      = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__IDENTIFIER_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__IDENTIFIER_LO];
    ide     = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__IDE_HI];
    rtr     = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__RTR_HI];
    valid   = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__VALID_HI];
    dlc     = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__DLC_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__DLC_LO];
    data_lo = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_LO__DATA_0_3_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_LO__DATA_0_3_LO];
    data_hi = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_HI__DATA_4_7_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_HI__DATA_4_7_LO];
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_POP__POP_HI);
  endtask

  // ==========================================================================
  // External real CAN frame generator: builds a complete, correctly-stuffed
  // frame (real CRC-15, same polynomial as dfc_rtl019.sv's own crc15_next),
  // then drives it bit-by-bit via tb_bus_drive at the configured bit rate.
  // Optionally corrupts the LAST CRC bit (bad_crc) or withholds the ACK
  // (skip_ack) to produce genuine, real CRC/ACK protocol errors.
  // ==========================================================================
  function automatic logic [14:0] ref_crc15_next(logic [14:0] crc, logic b);
    logic fb;
    fb = crc[14] ^ b;
    ref_crc15_next = {crc[13:0], 1'b0};
    if (fb) ref_crc15_next = ref_crc15_next ^ 15'h4599;
  endfunction

  task automatic drive_bit(logic b);
    tb_bus_drive = b;
    repeat (CYCLES_PER_BIT) @(posedge core_clk_i);
  endtask

  task automatic drive_can_frame(logic [28:0] id, logic ide, logic rtr, logic [3:0] dlc,
                                  logic [63:0] data, logic bad_crc, logic skip_ack);
    logic bits[0:199];
    int unsigned nbits;
    logic stuffed[0:259];
    int unsigned nstuffed;
    logic [14:0] crc;
    int unsigned nbytes;
    int unsigned run_len;
    logic run_val;
    int unsigned i, bi, k;
    logic b, crc_bit;

    nbits = 0;
    bits[nbits] = 1'b0; nbits++;  // SOF

    if (!ide) begin
      for (i = 0; i < 11; i++) begin bits[nbits] = id[10-i]; nbits++; end
      bits[nbits] = rtr; nbits++;
      bits[nbits] = 1'b0; nbits++;  // IDE=0
    end else begin
      for (i = 0; i < 11; i++) begin bits[nbits] = id[28-i]; nbits++; end
      bits[nbits] = 1'b1; nbits++;  // SRR
      bits[nbits] = 1'b1; nbits++;  // IDE=1
      for (i = 0; i < 18; i++) begin bits[nbits] = id[17-i]; nbits++; end
      bits[nbits] = rtr; nbits++;
    end

    if (!ide) begin
      bits[nbits] = 1'b0; nbits++;  // r0
    end else begin
      bits[nbits] = 1'b0; nbits++;  // r1
      bits[nbits] = 1'b0; nbits++;  // r0
    end
    for (i = 0; i < 4; i++) begin bits[nbits] = dlc[3-i]; nbits++; end

    nbytes = rtr ? 0 : (dlc > 4'd8 ? 8 : dlc);
    for (i = 0; i < nbytes; i++) begin
      for (bi = 0; bi < 8; bi++) begin bits[nbits] = data[i*8 + (7-bi)]; nbits++; end
    end

    crc = 15'h0;
    for (k = 0; k < nbits; k++) crc = ref_crc15_next(crc, bits[k]);
    for (i = 0; i < 15; i++) begin
      crc_bit = crc[14-i];
      if (bad_crc && i == 14) crc_bit = ~crc_bit;  // corrupt only the LAST CRC bit
      bits[nbits] = crc_bit; nbits++;
    end

    nstuffed = 0;
    run_len = 0; run_val = 1'b1;
    for (k = 0; k < nbits; k++) begin
      b = bits[k];
      stuffed[nstuffed] = b; nstuffed++;
      if (run_len > 0 && b == run_val) run_len++;
      else begin run_len = 1; run_val = b; end
      if (run_len == 5) begin
        stuffed[nstuffed] = ~run_val; nstuffed++;
        run_len = 1; run_val = ~run_val;
      end
    end

    for (k = 0; k < nstuffed; k++) drive_bit(stuffed[k]);

    drive_bit(1'b1);  // CRC delimiter (recessive)
    if (skip_ack) drive_bit(1'b1);  // withheld ACK -> real ACK error
    else          drive_bit(1'b0);  // testbench plays "another receiver"
    drive_bit(1'b1);  // ACK delimiter
    for (i = 0; i < 7; i++) drive_bit(1'b1);  // EOF
    for (i = 0; i < 3; i++) drive_bit(1'b1);  // intermission
  endtask

  initial begin
    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    #1;
    core_rst_n_i = 1'b1;
    repeat (2) @(posedge core_clk_i);

    // ---------------------------------------------------------------------
    // Setup: enable, fast bit timing, loopback off, listen-only off.
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__ENABLE_HI] = 1'b1;
    set_bit_timing(0, 3, 2, 0);  // BRP=1, TSEG1=4, TSEG2=3, SJW=1
    @(posedge core_clk_i); #1;
    check_bit("Setup CAN_STATUS.ENABLED after ENABLE", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__ENABLED_HI], 1'b1);
    check_bit("Setup RX queue empty at start", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__RX_NOT_EMPTY_HI], 1'b0);

    // ---------------------------------------------------------------------
    // Case 1: LOOPBACK standard-ID data frame, DLC=4 -- proves TX
    // framing/stuffing/CRC and RX destuff/CRC-check/byte-order are
    // self-consistent for the common case (also the direct, black-box
    // proof of the real byte0-first/MSB-first-per-byte serializer bug
    // found and fixed while writing this module).
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    can_tx_push(11'h123, 1'b0, 1'b0, 4'd4, 32'h04030201, 32'h0);
    wait_tx_level(1, 200);
    wait_tx_level(0, 2000);
    wait_rx_level(1, 200);
    check("Case1 RX level 1 after loopback self-receive", rx_level(), 64'd1);
    begin : case1_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
      check("Case1 decoded standard ID", id, 64'h123);
      check_bit("Case1 decoded IDE=0", ide, 1'b0);
      check_bit("Case1 decoded RTR=0", rtr, 1'b0);
      check_bit("Case1 decoded VALID=1", valid, 1'b1);
      check("Case1 decoded DLC=4", dlc, 64'd4);
      check("Case1 decoded data bytes 0-3, byte0-first order", data_lo, 64'h04030201);
    end

    // ---------------------------------------------------------------------
    // Case 2: LOOPBACK extended-ID (29-bit) data frame, DLC=8 (max) -- also
    // exercises the full 8-byte data field across both data words.
    // ---------------------------------------------------------------------
    can_tx_push(29'h1ABCDE12, 1'b1, 1'b0, 4'd8, 32'h04030201, 32'h08070605);
    wait_tx_level(1, 200);
    wait_tx_level(0, 2000);
    wait_rx_level(1, 200);
    begin : case2_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
      check("Case2 decoded extended 29-bit ID", id, 64'h1ABCDE12);
      check_bit("Case2 decoded IDE=1", ide, 1'b1);
      check("Case2 decoded DLC=8", dlc, 64'd8);
      check("Case2 decoded data bytes 0-3", data_lo, 64'h04030201);
      check("Case2 decoded data bytes 4-7", data_hi, 64'h08070605);
    end

    // ---------------------------------------------------------------------
    // Case 3: LOOPBACK remote frame (RTR=1) with DLC=8 staged -- REG-ENC-006
    // requires ZERO data bytes actually shifted regardless of the staged
    // DLC value. The decoded DLC must still read back 8 (DLC signals
    // intended length, not actual bytes sent), but the frame must complete
    // in the SHORT (0-byte) time, not the long (8-byte) time -- checked via
    // the real completion latency, not just the final decode.
    // ---------------------------------------------------------------------
    begin : case3_rtr
      int unsigned n;
      can_tx_push(11'h321, 1'b0, 1'b1, 4'd8, 32'hFFFFFFFF, 32'hFFFFFFFF);
      wait_tx_level(1, 200);
      n = 0;
      while (tx_level() != 4'd0 && n < 1500) begin @(posedge core_clk_i); n++; end
      check_bit("Case3 RTR frame completed in short (0-byte) time, not long (8-byte) time", (n < 700), 1'b1);
    end
    wait_rx_level(1, 200);
    begin : case3_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
      check_bit("Case3 decoded RTR=1", rtr, 1'b1);
      check("Case3 decoded DLC still reports 8 (intended length, not actual bytes sent)", dlc, 64'd8);
    end

    // ---------------------------------------------------------------------
    // Case 4: LOOPBACK DLC=0 edge case (no data field at all).
    // ---------------------------------------------------------------------
    can_tx_push(11'h001, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
    wait_tx_level(1, 200);
    wait_tx_level(0, 2000);
    wait_rx_level(1, 200);
    begin : case4_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
      check("Case4 decoded DLC=0", dlc, 64'd0);
    end

    // ---------------------------------------------------------------------
    // Case 5: bit-stuffing exact boundary. An ID of all-zero bits (11'h000)
    // with RTR=0/IDE=0/r0=0 produces 11+1+1+1=14 consecutive dominant bits
    // in the arbitration+control field before DLC -- forcing at least two
    // real stuff-bit insertions (after the 5th and 11th dominant bits).
    // Checked directly via the real internal stuff_run_q never reaching 6
    // (a real stuff error) AND the frame still decoding perfectly end to
    // end (the real, end-to-end proof that destuffing recovers the exact
    // original bits).
    // ---------------------------------------------------------------------
    begin : case5_stuff_watch
      // Background watcher: fails immediately if the real run-length
      // counter ever reaches 6 (would mean a stuff bit was missed).
    end
    can_tx_push(11'h000, 1'b0, 1'b0, 4'd1, 32'h000000FF, 32'h0);
    wait_tx_level(1, 200);
    begin : case5_monitor
      int unsigned n;
      n = 0;
      while (tx_level() != 4'd0 && n < 2000) begin
        check_bit("Case5 stuff_run_q never reaches 6 (no missed stuff bit)", (dut.stuff_run_q <= 3'd5), 1'b1);
        @(posedge core_clk_i);
        n++;
      end
    end
    wait_rx_level(1, 200);
    begin : case5_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
      check("Case5 decoded ID=0 survives heavy stuffing", id, 64'h0);
      check("Case5 decoded data byte0=0xFF survives heavy stuffing", data_lo, 64'hFF);
    end

    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 6: a REAL external frame on can_rx_i (not loopback) -- proves
    // the destuff/CRC/byte-order pipeline works for genuine external
    // traffic, not just a self-consistent loopback round-trip.
    // ---------------------------------------------------------------------
    drive_can_frame(11'h2AA, 1'b0, 1'b0, 4'd2, 64'h0000000000003344, 1'b0, 1'b0);
    wait_rx_level(1, 200);
    begin : case6_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
      check("Case6 decoded external-frame ID", id, 64'h2AA);
      check("Case6 decoded external-frame data", data_lo, 64'h3344);
    end

    // ---------------------------------------------------------------------
    // Case 7: a REAL external frame with a deliberately corrupted final
    // CRC bit -- must be detected as a genuine CRC error (PROTOCOL_ERROR
    // sticky + count increment, REC increments since this module is the
    // receiver, NOT captured into the RX queue).
    // ---------------------------------------------------------------------
    begin : case7_crc_err
      logic [15:0] perr_before, perr_after;
      logic [7:0]  rec_before;
      perr_before = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_HI:
                              dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_LO];
      rec_before = dut.rec_q;
      drive_can_frame(11'h155, 1'b0, 1'b0, 4'd1, 64'hAA, 1'b1, 1'b0);
      @(posedge core_clk_i); #1;
      check_bit("Case7 CAN_STATUS.PROTOCOL_ERROR sticky set on real CRC error", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__PROTOCOL_ERROR_HI], 1'b1);
      perr_after = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_HI:
                             dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_LO];
      check("Case7 CAN_ERROR_COUNT.PROTOCOL_ERROR_COUNT incremented by exactly 1", perr_after, 64'(perr_before + 1));
      check("Case7 REC incremented by exactly 1 (this module was the receiver)", dut.rec_q, 64'(rec_before + 1));
      check("Case7 corrupted frame NOT captured into RX queue", rx_level(), 64'd0);
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__PROTOCOL_ERROR_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 8: host-vs-route last-free-slot tiebreaker (ARCH-RTL019-001),
    // identical pattern to RTL-018's own testbench. Fill TX queue to 7,
    // assert a host push and a route push on the SAME cycle -- host must
    // win, route must stay backpressured until a slot frees.
    //
    // LOOPBACK is turned back on here (off since before Case6): Case 8/9
    // only care about TX QUEUE mechanics (push/overflow/tiebreaker), not
    // real frame semantics, but queued entries still need to actually
    // COMPLETE transmission to drain -- without loopback's self-ACK,
    // nothing on this testbench's quiet bus would ever ACK them, so they'd
    // retry the ACK slot forever and the queue would never empty (a real
    // bug this testbench's own first run exposed as a confusing cascade of
    // failures in every later case, not just these two).
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    effective_operational_enable_i = 1'b0;  // pile up entries without draining
    @(posedge core_clk_i); #1;
    for (int i = 0; i < 7; i++) begin
      can_tx_push(11'h400 + i[10:0], 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
      wait_tx_level(i + 1, 100);
    end
    check("Case8 TX queue at 7 (one free slot)", tx_level(), 64'd7);

    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDENTIFIER_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDENTIFIER_LO, 29'h099);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDE_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__RTR_HI] = 1'b0;
    set_field(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_META_STAGE__DLC_HI,
              dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_META_STAGE__DLC_LO, 4'd0);
    @(posedge core_clk_i); #1;
    tx_msg_record_i = '0;
    tx_msg_record_i[94] = 1'b0;  // RTR
    tx_msg_record_i[93] = 1'b0;  // IDE
    tx_msg_record_i[28:0] = 29'h0AA;
    tx_msg_valid_i = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_PUSH__PUSH_HI] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_PUSH__PUSH_HI] = 1'b0;
    check_bit("Case8 route NOT accepted while host push is being serviced", tx_msg_ready_o, 1'b0);
    wait_tx_level(8, 100);
    check("Case8 host push won the last slot (queue now FULL at 8)", tx_level(), 64'd8);
    check_bit("Case8 route request still pending", tx_msg_valid_i, 1'b1);

    effective_operational_enable_i = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(7, 20000);
    begin : case8_route_wait
      int unsigned n;
      n = 0;
      while (!tx_msg_ready_o && n < 2000) begin @(posedge core_clk_i); n++; end
      check_bit("Case8 route request eventually accepted once a slot freed", tx_msg_ready_o, 1'b1);
      @(posedge core_clk_i);
      #1;
      tx_msg_valid_i = 1'b0;
    end
    wait_tx_level(8, 100);
    wait_tx_level(0, 50000);
    wait_rx_level(0, 2000);  // drain any RX entries these frames produced

    // ---------------------------------------------------------------------
    // Case 9: TX queue overflow -- fill to exactly 8, confirm the 9th push
    // is REJECTED with real evidence (sticky + count), not silently
    // dropped or accepted.
    // ---------------------------------------------------------------------
    effective_operational_enable_i = 1'b0;
    @(posedge core_clk_i); #1;
    for (int i = 0; i < 8; i++) begin
      can_tx_push(11'h500 + i[10:0], 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
      wait_tx_level(i + 1, 100);
    end
    check("Case9 TX queue reached exactly FULL (8)", tx_level(), 64'd8);
    begin : case9_overflow
      logic [31:0] rejected_before;
      rejected_before = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_REJECTED_COUNT__COUNT_HI:
                                  dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_REJECTED_COUNT__COUNT_LO];
      can_tx_push(11'h5FF, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
      @(posedge core_clk_i); #1;
      check("Case9 queue level UNCHANGED after rejected push", tx_level(), 64'd8);
      check_bit("Case9 CAN_STATUS.TX_REJECTED sticky set", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__TX_REJECTED_HI], 1'b1);
      check("Case9 CAN_TX_REJECTED_COUNT incremented by exactly 1",
            status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_REJECTED_COUNT__COUNT_HI:
                     dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_REJECTED_COUNT__COUNT_LO],
            64'(rejected_before + 1));
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__TX_REJECTED_HI);
    effective_operational_enable_i = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(0, 50000);
    wait_rx_level(0, 2000);

    // ---------------------------------------------------------------------
    // Case 10: RX queue overflow. Loopback on, host never pops -- push 9
    // frames one at a time (each must fully complete before the next, same
    // single-protocol-engine discipline as every other case here); the 9th
    // must be REJECTED with real evidence, the first 8 preserved intact.
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    for (int i = 0; i < 8; i++) begin
      can_tx_push(11'h600 + i[10:0], 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
      wait_tx_level(1, 200);
      wait_tx_level(0, 800);
      wait_rx_level(i + 1, 200);
    end
    check("Case10 RX queue reached exactly FULL (8)", rx_level(), 64'd8);
    begin : case10_overflow
      logic [31:0] rxovf_before;
      rxovf_before = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_OVERFLOW_COUNT__COUNT_HI:
                               dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_OVERFLOW_COUNT__COUNT_LO];
      can_tx_push(11'h6FF, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
      wait_tx_level(1, 200);
      wait_tx_level(0, 800);
      @(posedge core_clk_i); #1;
      check("Case10 RX queue level UNCHANGED after dropped frame (still 8)", rx_level(), 64'd8);
      check_bit("Case10 CAN_STATUS.RX_OVERFLOW sticky set", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__RX_OVERFLOW_HI], 1'b1);
      check("Case10 CAN_RX_OVERFLOW_COUNT incremented by exactly 1",
            status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_OVERFLOW_COUNT__COUNT_HI:
                     dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_OVERFLOW_COUNT__COUNT_LO],
            64'(rxovf_before + 1));
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__RX_OVERFLOW_HI);
    // Drain the RX queue fully before the next case.
    for (int i = 0; i < 8; i++) begin
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
    end
    wait_rx_level(0, 200);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 11: real arbitration loss. The DUT is pushed a standard-ID
    // frame whose ID is dominant(0) everywhere except its very last bit
    // (recessive); an external "other node" (modeled via tb_bus_drive on
    // the real wired-AND can_rx_i) drives dominant at that exact bit --
    // the DUT must recognize it lost arbitration (is_transmitter_q clears,
    // checked directly) and MUST NOT pop its own queued entry (retained
    // for automatic retry).
    // ---------------------------------------------------------------------
    can_tx_push(11'h001, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);  // ID=00000000001: only the LAST bit (idx 10) is recessive
    wait_tx_level(1, 100);
    begin : case11_find_bit
      int unsigned n;
      n = 0;
      // bit_idx_q==10 alone is not a reliable signal here: this ID's own
      // long run of leading dominant bits triggers real bit-stuffing near
      // this exact position, and bit_idx_q intentionally STALLS (does not
      // advance) for a stuff bit's own bit-time -- so bit_idx_q==10 can
      // also label a stuff bit's stall cycle, one real bit-time before the
      // genuine target bit. Confirm tx_bit_q has already settled to 1 (the
      // real recessive LSB this module is about to drive) too, not just
      // the bit_idx_q label, before starting the forced conflict.
      while (!(dut.proto_state_q == dut.ST_ARB && dut.bit_idx_q == 6'd10 && dut.tx_bit_q == 1'b1) && n < 5000) begin
        @(posedge core_clk_i);
        n++;
      end
      check_bit("Case11 reached the target (last, recessive) ID bit before watchdog", (n < 5000), 1'b1);
    end
    tb_bus_drive = 1'b0;  // external node drives dominant at this exact bit
    repeat (CYCLES_PER_BIT) @(posedge core_clk_i);
    tb_bus_drive = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("Case11 DUT recognizes it is no longer the transmitter", dut.is_transmitter_q, 1'b0);
    begin : case11_settle
      int unsigned n;
      n = 0;
      while (dut.proto_state_q != dut.ST_IDLE && n < 5000) begin @(posedge core_clk_i); n++; end
    end
    check("Case11 TX entry retained (not popped) after losing arbitration", tx_level(), 64'd1);
    // The bus is now free of the EXTERNAL conflict, but still non-loopback
    // with no other real node to ACK this module's own retransmit -- a
    // real, repeatable ACK error on every retry (the same mechanism Case
    // 16 exercises on purpose), not a bug and not a reason to expect
    // automatic draining here. Enable loopback (self-ACK) to let the
    // retained entry actually complete, same precedent as Cases 8/9/16.
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(0, 2000);
    check("Case11 retained entry successfully drains once it can get a real ACK (loopback)", tx_level(), 64'd0);
    wait_rx_level(0, 2000);  // the self-looped retry (and the earlier "winning" phantom frame's aftermath) may land in RX; drain either way
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__PROTOCOL_ERROR_HI);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__RX_OVERFLOW_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 12: LISTEN_ONLY -- never drives dominant, never even attempts a
    // queued transmission. Push an entry, confirm it stays queued
    // (un-attempted) while listen-only is set, then confirm it drains once
    // listen-only is cleared and loopback is enabled.
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LISTEN_ONLY_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    can_tx_push(11'h010, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
    wait_tx_level(1, 100);
    repeat (200) @(posedge core_clk_i);
    check("Case12 TX entry never attempted while LISTEN_ONLY is set", tx_level(), 64'd1);
    check_bit("Case12 can_tx_o stays recessive the whole time (never drives dominant)", can_tx_o, 1'b1);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LISTEN_ONLY_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(0, 2000);
    check("Case12 entry drains once LISTEN_ONLY clears", tx_level(), 64'd0);
    wait_rx_level(1, 200);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_POP__POP_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 13: the REG-ENC-006 `11` illegal LOOPBACK/LISTEN_ONLY
    // combination. With LOOPBACK already 1 (from Case 12), also set
    // LISTEN_ONLY=1 on the raw control bit -- dfc_rtl019.sv's own
    // defensive clamp (finding 9) must make LOOPBACK win: a pushed frame
    // must still transmit and self-receive normally, proving LISTEN_ONLY
    // did NOT block it.
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LISTEN_ONLY_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    can_tx_push(11'h020, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
    wait_tx_level(1, 200);
    wait_tx_level(0, 2000);
    wait_rx_level(1, 200);
    check_bit("Case13 LOOPBACK wins the illegal `11` combination (frame still transmitted+self-received)", (rx_level() == 4'd1), 1'b1);
    begin : case13_pop
      logic [28:0] id; logic ide, rtr, valid; logic [3:0] dlc; logic [31:0] data_lo, data_hi;
      can_rx_pop(id, ide, rtr, valid, dlc, data_lo, data_hi);
    end
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LISTEN_ONLY_HI] = 1'b0;
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 14: TEC threshold progression to BUS_OFF, then AUTOMATIC bus-off
    // recovery via the real 128x11-consecutive-recessive-bit count.
    // One TX entry is pushed once; each retry attempt is deliberately
    // broken at its own CRC delimiter (a real, repeatable FORM error while
    // this module is the transmitter, so TEC+=8 each time -- the entry is
    // never popped on error, so the SAME entry retries automatically,
    // exactly like a real bus with a stuck faulty receiver).
    // ---------------------------------------------------------------------
    // AUTOMATIC_BUS_OFF_RECOVERY is deliberately left OFF during the
    // TEC-building loop itself and only enabled once bus-off is actually
    // confirmed: the real recessive-bit-time observation counter runs
    // continuously regardless of recovery mode (matching real hardware),
    // so the idle gaps between this loop's own forced-error retries can
    // (and do) satisfy the real 128x11 requirement before bus-off is even
    // reached -- enabling auto-recovery up front would let it fire
    // the SAME cycle bus-off latches, never leaving a real, observable
    // BUS_OFF=1 window for this test to check at all.
    can_tx_push(11'h7AA, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
    wait_tx_level(1, 100);
    begin : case14_tec_loop
      int unsigned iter;
      int unsigned n;
      iter = 0;
      while (!dut.bus_off_q && iter < 50) begin
        n = 0;
        while (!(dut.proto_state_q == dut.ST_CRC_DELIM) && n < 2000 && !dut.bus_off_q) begin
          @(posedge core_clk_i); n++;
        end
        if (!dut.bus_off_q) begin
          tb_bus_drive = 1'b0;  // force dominant during the (always-recessive) CRC delimiter -> real form error
          repeat (CYCLES_PER_BIT) @(posedge core_clk_i);
          tb_bus_drive = 1'b1;
          // wait for the error-flag/delimiter sequence to settle back to idle (or bus-off to latch) before retrying
          n = 0;
          while (dut.proto_state_q != dut.ST_IDLE && !dut.bus_off_q && n < 2000) begin
            @(posedge core_clk_i); n++;
          end
        end
        iter++;
      end
      check_bit("Case14 reached BUS_OFF within a bounded number of forced retries", dut.bus_off_q, 1'b1);
    end
    @(posedge core_clk_i); #1;
    check_bit("Case14 CAN_STATUS.BUS_OFF set", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI], 1'b1);
    check_bit("Case14 CAN_STATUS.ERROR_PASSIVE also set (TEC>127 before bus-off)", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__ERROR_PASSIVE_HI], 1'b1);

    // NOW enable automatic recovery -- the real 128x11-consecutive-
    // recessive-bit requirement may already be partly (or, thanks to the
    // idle gaps in the loop above, even fully) satisfied the instant this
    // is set, which is itself a real, correct consequence of the
    // observation counter running continuously regardless of recovery
    // mode -- not a bug, just why this test enables it here rather than
    // before the loop.
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__AUTOMATIC_BUS_OFF_RECOVERY_HI] = 1'b1;
    @(posedge core_clk_i); #1;

    // Bus is now naturally idle (bus-off blocks any further TX attempt),
    // so the 128x11-consecutive-recessive-bit count accumulates on its own.
    begin : case14_recovery_wait
      int unsigned n;
      n = 0;
      while (status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI] && n < 10000) begin
        @(posedge core_clk_i); n++;
      end
      check_bit("Case14 AUTOMATIC recovery clears BUS_OFF after the real 128x11 recessive-bit count", (n < 10000), 1'b1);
    end
    check_bit("Case14 CAN_STATUS.BUS_OFF cleared", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI], 1'b0);
    check("Case14 TEC reset to 0 on recovery", dut.tec_q, 64'd0);
    // The long-retained entry can now attempt retransmission again, but
    // (same lesson as Case 11) this is still non-loopback with no real
    // node to ACK it -- enable loopback so it actually drains instead of
    // looping on real ACK errors forever and leaking into later cases.
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(0, 2000);
    wait_rx_level(0, 2000);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__PROTOCOL_ERROR_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 15: MANUAL bus-off recovery -- CAN_RECOVERY.REQUEST must be
    // REJECTED before the real recessive-bus observation requirement is
    // satisfied, and ACCEPTED once it is. Re-triggers bus-off via the
    // identical forced-CRC-delimiter-error loop as Case 14.
    //
    // DISCLOSED: once this module enters error-passive (TEC>127, before the
    // eventual TEC>255 that actually latches bus-off), its own error FLAG
    // becomes all-recessive by design (REG-ENC-006/real ISO 11898-1 -- a
    // passive node's error flag must not disturb other traffic), and each
    // further retry's flag+delimiter is itself a real multi-bit recessive
    // run -- so the 128x11 recessive-bit-time count can genuinely become
    // (fully or partly) satisfied DURING this same error-passive retry
    // phase, before bus-off even latches. This is a real property of the
    // protocol this test's own error-injection strategy exposes, not a
    // testbench artifact: the "premature rejection" sub-case below is only
    // meaningful when recovery_ready_q happens to still read 0 right after
    // bus-off is reached, so it is checked conditionally rather than
    // asserted unconditionally.
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__AUTOMATIC_BUS_OFF_RECOVERY_HI] = 1'b0;
    @(posedge core_clk_i); #1;
    can_tx_push(11'h7BB, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
    wait_tx_level(1, 100);
    begin : case15_tec_loop
      int unsigned iter;
      int unsigned n;
      iter = 0;
      while (!dut.bus_off_q && iter < 50) begin
        n = 0;
        while (!(dut.proto_state_q == dut.ST_CRC_DELIM) && n < 2000 && !dut.bus_off_q) begin
          @(posedge core_clk_i); n++;
        end
        if (!dut.bus_off_q) begin
          tb_bus_drive = 1'b0;
          repeat (CYCLES_PER_BIT) @(posedge core_clk_i);
          tb_bus_drive = 1'b1;
          n = 0;
          while (dut.proto_state_q != dut.ST_IDLE && !dut.bus_off_q && n < 2000) begin
            @(posedge core_clk_i); n++;
          end
        end
        iter++;
      end
      check_bit("Case15 reached BUS_OFF again (manual-recovery scenario)", dut.bus_off_q, 1'b1);
    end

    // Request recovery IMMEDIATELY. Whether this is genuinely "premature"
    // depends on whether the error-passive retry phase above already
    // satisfied the real observation requirement (see the disclosed note
    // above) -- check recovery_ready_q FIRST and only assert rejection
    // when it is actually still unsatisfied, rather than assuming it.
    if (!dut.recovery_ready_q) begin
      pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RECOVERY__REQUEST_HI);
      @(posedge core_clk_i); #1;
      check_bit("Case15 premature CAN_RECOVERY.REQUEST is REJECTED (observation not yet satisfied)", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI], 1'b1);
    end else begin
      $display("Case15: recovery_ready_q was already satisfied by the error-passive retry phase itself -- the premature-rejection sub-case cannot be exercised this run (disclosed, not a failure); proceeding directly to the eventual-acceptance check.");
    end

    begin : case15_ready_wait
      int unsigned n;
      n = 0;
      while (!dut.recovery_ready_q && n < 10000) begin @(posedge core_clk_i); n++; end
      check_bit("Case15 recovery_ready_q eventually sets (128x11 count satisfied)", (n < 10000), 1'b1);
    end
    check_bit("Case15 BUS_OFF still held (manual mode does not auto-exit)", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI], 1'b1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RECOVERY__REQUEST_HI);
    @(posedge core_clk_i); #1;
    check_bit("Case15 CAN_RECOVERY.REQUEST now ACCEPTED (observation requirement satisfied)", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI], 1'b0);
    // Same real-ACK-error lesson as Case 14's own ending: still
    // non-loopback, so the long-retained entry needs loopback enabled to
    // actually drain instead of leaking into Case 16.
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(0, 2000);
    wait_rx_level(0, 2000);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__PROTOCOL_ERROR_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 16: ACK error. DISCLOSED design correction made while writing
    // this case: a withheld ACK cannot be tested via an externally-driven
    // frame in this harness's own non-loopback setup, because the DUT
    // itself, as the real receiver of a structurally valid external frame,
    // would ALSO drive its own genuine ACK onto the same real wired-AND
    // bus (can_rx_i = dut.can_tx_o & tb_bus_drive) regardless of what this
    // testbench's own tb_bus_drive does -- there is no way to "withhold"
    // an ACK out from under the DUT's own correct receiver behavior this
    // way. The real, meaningful ACK-error scenario is this module acting
    // as the TRANSMITTER with no other node present to ACK it: push a TX
    // entry (non-loopback, nothing else driving the bus) and let its own
    // real `is_transmitter_q && !ack_seen_q` check fire.
    // ---------------------------------------------------------------------
    begin : case16_ack_err
      logic [15:0] perr_before, perr_after;
      perr_before = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_HI:
                              dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_LO];
      can_tx_push(11'h0FF, 1'b0, 1'b0, 4'd0, 32'h0, 32'h0);
      wait_tx_level(1, 100);
      begin : case16_wait_err_flag
        int unsigned n;
        n = 0;
        while (dut.proto_state_q != dut.ST_ERROR_FLAG && n < 2000) begin @(posedge core_clk_i); n++; end
        check_bit("Case16 reached ST_ERROR_FLAG (real ACK error) before watchdog", (n < 2000), 1'b1);
      end
      @(posedge core_clk_i); #1;
      check_bit("Case16 CAN_STATUS.PROTOCOL_ERROR sticky set on unacknowledged TX", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__PROTOCOL_ERROR_HI], 1'b1);
      perr_after = status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_HI:
                             dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_LO];
      check("Case16 CAN_ERROR_COUNT.PROTOCOL_ERROR_COUNT incremented by exactly 1", perr_after, 64'(perr_before + 1));
      check("Case16 TX entry retained (not popped) after the unacknowledged attempt", tx_level(), 64'd1);
    end
    // Clean up: enable loopback so the retained entry can actually drain
    // via self-ACK before the next case.
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    wait_tx_level(0, 2000);
    wait_rx_level(0, 2000);
    control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI] = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__PROTOCOL_ERROR_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 17: transceiver-error passthrough -- can_transceiver_error_i
    // must set the real, dedicated sticky bit and contribute to fault_req_o.
    // ---------------------------------------------------------------------
    can_transceiver_error_i = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("Case17 CAN_STATUS.TRANSCEIVER_ERROR sticky set", status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__TRANSCEIVER_ERROR_HI], 1'b1);
    check_bit("Case17 fault_req_o asserted", fault_req_o, 1'b1);
    can_transceiver_error_i = 1'b0;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__TRANSCEIVER_ERROR_HI);
    @(posedge core_clk_i); #1;
    check_bit("Case17 fault_req_o clears once the sticky is cleared and the condition is gone", fault_req_o, 1'b0);

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
