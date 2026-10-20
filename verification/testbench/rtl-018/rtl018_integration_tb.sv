`timescale 1ns/1ps
// rtl018_integration_tb.sv -- dedicated testbench for RTL-018 (ARINC 429
// Transmit Interface), dfc_rtl018.sv, ARCH-RTL018-001.
//
// Instantiates dfc_rtl018 REAL against a REAL dfc_rtl024_shared_buffer
// (same "real client against the real service" discipline RTL-017's own
// testbench established, not a mock buffer model). CYCLES_PER_BIT_LOW/HIGH
// are overridden to small simulation-only values (dfc_rtl018.sv's own
// header discloses this as the intended use of those parameters) so a full
// 33-bit transmission plus gap completes in a tractable number of cycles.
//
// control_i/status_o are driven/read directly via the generated
// DFC_RTL018_CONTROL__*/DFC_RTL018_STATUS__* bit constants (no RTL-001
// regbank in this testbench -- same precedent as every other per-module
// testbench in this project).
//
// Clocking discipline matches every other testbench in this project: every
// strobe is held for a full clock and deasserted with a #1 settle delay
// after the sampling edge.

module rtl018_integration_tb;

  localparam int unsigned CPB_LOW  = 8;
  localparam int unsigned CPB_HIGH = 4;

  logic core_clk_i = 1'b0;
  logic core_rst_n_i;
  logic module_reset_i = 1'b0;

  always #10 core_clk_i = ~core_clk_i;

  initial begin
    #2000000;
    $display("TEST FAILED -- watchdog timeout, something never completed a handshake");
    $finish(1);
  end

  // ---- control_i / status_o ----
  logic [dfc_types_pkg::DFC_RTL018_CONTROL_WIDTH-1:0] control_i;
  wire  [dfc_types_pkg::DFC_RTL018_STATUS_WIDTH-1:0]  status_o;

  initial control_i = '0;

  task automatic pulse_ctrl_bit(int bit_hi);
    control_i[bit_hi] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[bit_hi] = 1'b0;
  endtask

  // Variable-bound part-selects (control_i[hi:lo]) are not legal Verilog --
  // confirmed via a real Icarus compile failure ("Part select expressions
  // must be constant integral values") -- so this assigns bit-by-bit using
  // single-bit variable indexing instead, which is legal.
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

  // ---- route-destination (RTL-021) ----
  logic        msg_valid_i = 1'b0;
  wire         msg_ready_o;
  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] msg_record_i = '0;

  // ---- physical TX pins ----
  wire [1:0]  arinc_tx_ctrl_o;
  logic       atx_adapter_error_i = 1'b0;

  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic observational_mode_i = 1'b0;
  wire  activity_o;
  logic module_enable_i = 1'b1;
  logic effective_operational_enable_i = 1'b1;

  // ---- shared-buffer client-0 interface, real service instantiated below ----
  wire        buf_req_valid, buf_req_ready;
  wire [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req;
  wire        buf_rsp_valid, buf_rsp_ready;
  wire [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp;

  dfc_rtl018 #(
    .CYCLES_PER_BIT_LOW  (CPB_LOW),
    .CYCLES_PER_BIT_HIGH (CPB_HIGH)
  ) dut (
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
    .msg_valid_i              (msg_valid_i),
    .msg_ready_o              (msg_ready_o),
    .msg_record_i             (msg_record_i),
    .arinc_tx_ctrl_o          (arinc_tx_ctrl_o),
    .atx_adapter_error_i      (atx_adapter_error_i),
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

  // Client 1-6 of the real shared buffer are permanently idle in this
  // testbench (only RTL-018/client 0 is under test -- the client-slot
  // NUMBER doesn't matter here, dfc_rtl018.sv's own addressing is purely
  // client-relative, same precedent as rtl017_integration_tb.sv).
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
  // ARCH-BUS-002 hard invariant monitor: `11` must NEVER be generated on
  // arinc_tx_ctrl_o, checked every single CORE_CLK cycle for the whole run.
  // ==========================================================================
  int errors = 0, checks = 0;
  always_ff @(posedge core_clk_i) begin
    if (core_rst_n_i && arinc_tx_ctrl_o == 2'b11) begin
      errors++;
      $display("FAIL: ARCH-BUS-002 invariant violated -- arinc_tx_ctrl_o == 2'b11");
    end
  end

  // ARCH-BUF-013 one-outstanding-discipline runtime monitor (same pattern
  // as rtl017_integration_tb.sv's own).
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

  function automatic logic [3:0] queue_level();
    queue_level = status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_QUEUE_LEVEL__LEVEL_HI:
                            dfc_types_pkg::DFC_RTL018_STATUS__ATX_QUEUE_LEVEL__LEVEL_LO];
  endfunction

  task automatic wait_queue_level(int unsigned level, int unsigned max_cycles);
    int unsigned n;
    n = 0;
    while (queue_level() != level[3:0] && n < max_cycles) begin
      @(posedge core_clk_i);
      n++;
    end
  endtask

  // Stages ATX_DATA_STAGE/ATX_META_STAGE only -- no pulse. Split out from
  // host_push() specifically so Case 8/9 can assert a route request
  // (msg_valid_i, a plain combinational level) and the host's own ATX_PUSH
  // pulse on the EXACT same CORE_CLK edge -- host_push()'s own
  // stage-then-settle-then-pulse structure (needed for ordinary use, where
  // nothing else is racing it) would otherwise put the pulse a full cycle
  // AFTER msg_valid_i first becomes visible, defeating a genuine
  // same-cycle race test.
  task automatic stage_push_fields(logic [31:0] word, logic override_valid, logic override_bit,
                                    logic [13:0] tag);
    set_field(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_DATA_STAGE__WORD_HI,
              dfc_types_pkg::DFC_RTL018_CONTROL__ATX_DATA_STAGE__WORD_LO, word);
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__PARITY_OVERRIDE_VALID_HI] = override_valid;
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__PARITY_BIT_HI] = override_bit;
    set_field(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__TAG_HI,
              dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__TAG_LO, tag);
  endtask

  // Stages ATX_DATA_STAGE/ATX_META_STAGE then pulses ATX_PUSH for one cycle.
  task automatic host_push(logic [31:0] word, logic override_valid, logic override_bit,
                            logic [13:0] tag);
    stage_push_fields(word, override_valid, override_bit, tag);
    @(posedge core_clk_i);
    #1;
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_PUSH__PUSH_HI);
  endtask

  // Waits for BUSY to assert (a dequeue/serialization started), then samples
  // arinc_tx_ctrl_o at the first cycle of each of the 33 bit-times (data
  // bits LSB-first, then parity) -- see dfc_rtl018.sv's own always_comb:
  // a logic-1 bit pulses 01/10 for the first half of its bit-time and is
  // 00 otherwise; a logic-0 bit is 00 for the WHOLE bit-time. Sampling at
  // cycle 0 of each bit-time (which is always inside the active half, since
  // CPB_LOW/CPB_HIGH are both >=2) reliably distinguishes the two.
  task automatic capture_tx_frame(output logic [31:0] word, output logic parity_bit,
                                   input int unsigned cpb, input int unsigned max_wait);
    int unsigned n;
    n = 0;
    while (!status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__BUSY_HI] && n < max_wait) begin
      @(posedge core_clk_i);
      n++;
    end
    for (int i = 0; i < 33; i++) begin
      if (i < 32) word[i] = (arinc_tx_ctrl_o != 2'b00);
      else        parity_bit = (arinc_tx_ctrl_o != 2'b00);
      repeat (cpb) @(posedge core_clk_i);
    end
  endtask

  initial begin
    core_rst_n_i = 1'b0;
    repeat (4) @(posedge core_clk_i);
    #1;
    core_rst_n_i = 1'b1;
    repeat (2) @(posedge core_clk_i);

    // ---------------------------------------------------------------------
    // Case 1: enable, auto-parity push/pop (single entry), confirm
    // transmitted bit pattern decodes back to the real word + real odd
    // parity -- the direct, black-box proof of finding 4's LSB-first
    // serializer and the parity-computation bug found and fixed while
    // writing this module (`~^ser_shift_q` at the parity bit-time used to
    // read a drained-to-zero register, not the real word).
    // ---------------------------------------------------------------------
    // ATX_CONTROL.ENABLE is a plain RW level, not a one-shot command -- set
    // and HOLD it (pulse_ctrl_bit would clear it again the very next cycle).
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__ENABLE_HI] = 1'b1;
    set_field(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_HI,
              dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_LO, 14'd4);
    @(posedge core_clk_i); #1;
    check_bit("Case1 ATX_STATUS.ENABLED after ENABLE", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__ENABLED_HI], 1'b1);
    check_bit("Case1 queue empty before any push", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__QUEUE_EMPTY_HI], 1'b1);

    host_push(32'h0000_0001, 1'b0, 1'b0, 14'h0);
    wait_queue_level(1, 50);
    check("Case1 queue level 1 after push", queue_level(), 64'd1);
    check_bit("Case1 QUEUE_EMPTY clears", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__QUEUE_EMPTY_HI], 1'b0);

    begin : case1_capture
      logic [31:0] rx_word;
      logic        rx_parity;
      capture_tx_frame(rx_word, rx_parity, CPB_LOW, 2000);
      check("Case1 decoded word == 0x00000001 (LSB-first)", rx_word, 64'h0000_0001);
      // 0x00000001 has exactly one set bit -> odd number of ones already ->
      // odd parity requires the parity bit itself to be 0.
      check_bit("Case1 decoded auto parity bit (odd, one data bit set -> parity 0)", rx_parity, 1'b0);
    end
    wait_queue_level(0, 2000);
    check_bit("Case1 COMPLETE sticky set after full serialization", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__COMPLETE_HI], 1'b1);
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__COMPLETE_HI);
    @(posedge core_clk_i); #1;
    check_bit("Case1 COMPLETE clears on W1C", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__COMPLETE_HI], 1'b0);

    // ---------------------------------------------------------------------
    // Case 2: a word with an EVEN number of set bits (0x00000003, two ones)
    // -- auto parity must now set the parity bit to 1 to keep the total odd.
    // ---------------------------------------------------------------------
    host_push(32'h0000_0003, 1'b0, 1'b0, 14'h0);
    begin : case2_capture
      logic [31:0] rx_word;
      logic        rx_parity;
      capture_tx_frame(rx_word, rx_parity, CPB_LOW, 2000);
      check("Case2 decoded word == 0x00000003", rx_word, 64'h0000_0003);
      check_bit("Case2 decoded auto parity bit (even ones -> parity 1)", rx_parity, 1'b1);
    end
    wait_queue_level(0, 2000);

    // ---------------------------------------------------------------------
    // Case 3: parity OVERRIDE legality. AUTO_PARITY=0 + override-valid=1 +
    // override-bit=1 on a word whose real auto parity would be 0
    // (0x00000001) -- the transmitted parity bit must be the OVERRIDE
    // value (1), not the auto-computed one (0), proving override actually
    // takes effect when legally staged (finding 6).
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__AUTO_PARITY_HI] = 1'b0;
    @(posedge core_clk_i); #1;
    host_push(32'h0000_0001, 1'b1, 1'b1, 14'h0);
    begin : case3_capture
      logic [31:0] rx_word;
      logic        rx_parity;
      capture_tx_frame(rx_word, rx_parity, CPB_LOW, 2000);
      check("Case3 decoded word == 0x00000001", rx_word, 64'h0000_0001);
      check_bit("Case3 override parity bit (1) wins over auto (0)", rx_parity, 1'b1);
    end
    wait_queue_level(0, 2000);

    // ---------------------------------------------------------------------
    // Case 4: override staged (override-valid=1, override-bit=0) while
    // AUTO_PARITY=1 -- ARCH-VAL-018 says override is only LEGAL when
    // AUTO_PARITY=0; dfc_rtl018.sv's own finding 6 disclosed choice is that
    // AUTO_PARITY always wins in this case, so the transmitted parity must
    // be the real auto-computed value (0 for 0x00000001), NOT the staged
    // override (0 happens to coincide here, so use a word where they'd
    // differ to make this a real, discriminating test: 0x00000003 has
    // auto-parity 1; staged override is 0 -- if auto wins, we see 1).
    // ---------------------------------------------------------------------
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__AUTO_PARITY_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    host_push(32'h0000_0003, 1'b1, 1'b0, 14'h0);
    begin : case4_capture
      logic [31:0] rx_word;
      logic        rx_parity;
      capture_tx_frame(rx_word, rx_parity, CPB_LOW, 2000);
      check("Case4 decoded word == 0x00000003", rx_word, 64'h0000_0003);
      check_bit("Case4 AUTO_PARITY=1 overrides a staged override (real auto value wins)", rx_parity, 1'b1);
    end
    wait_queue_level(0, 2000);

    // ---------------------------------------------------------------------
    // Case 5: interword-gap timing. Measured directly via the real internal
    // ser_state_q == SER_GAP dwell time (hierarchical reference to the DUT),
    // not by watching arinc_tx_ctrl_o stay 00 externally -- a real, found
    // discrepancy while writing this test: the pin stays 00 for GAP_BITS
    // cycles PLUS whatever extra cycles the arbiter then needs to fetch the
    // NEXT entry's two words from the shared buffer before its first real
    // bit can appear (a genuine, separate latency, not part of the
    // REG-1124-mandated gap itself) -- external-pin-only measurement
    // conflates the two and overcounts the real gap.
    // ---------------------------------------------------------------------
    begin : case5_gap
      int unsigned gap_cycles;
      int unsigned n;
      set_field(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_HI,
                dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_LO, 14'd6);
      @(posedge core_clk_i); #1;
      host_push(32'h0000_0001, 1'b0, 1'b0, 14'h0);
      host_push(32'h0000_0001, 1'b0, 1'b0, 14'h0);
      wait_queue_level(2, 50);
      n = 0;
      while (dut.ser_state_q != dut.SER_GAP && n < 2000) begin @(posedge core_clk_i); n++; end
      check_bit("Case5 reached SER_GAP before watchdog", (n < 2000), 1'b1);
      gap_cycles = 0;
      while (dut.ser_state_q == dut.SER_GAP && gap_cycles < 500) begin
        @(posedge core_clk_i);
        gap_cycles++;
      end
      check("Case5 internal SER_GAP dwell == GAP_BITS(6) * CPB_LOW", gap_cycles, 64'(6 * CPB_LOW));
      wait_queue_level(0, 2000);
    end
    set_field(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_HI,
              dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_LO, 14'd4);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 6: queue push/pop/overflow. Disable the TX engine's own dequeue
    // path by holding effective_operational_enable_i low so entries pile up
    // without draining, then fill the queue to exactly full (8 entries) and
    // confirm the 9th push is REJECTED with evidence, not silently dropped
    // or silently accepted.
    // ---------------------------------------------------------------------
    effective_operational_enable_i = 1'b0;
    @(posedge core_clk_i); #1;
    for (int i = 0; i < 8; i++) begin
      host_push(32'h0000_0010 + i[31:0], 1'b0, 1'b0, 14'h0);
      wait_queue_level(i + 1, 50);
    end
    check("Case6 queue reached exactly FULL (8)", queue_level(), 64'd8);
    check_bit("Case6 QUEUE_FULL asserted", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__QUEUE_FULL_HI], 1'b1);

    begin : case6_overflow
      logic [31:0] rejected_count_before;
      rejected_count_before = status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_REJECTED_PUSH_COUNT__COUNT_HI:
                                        dfc_types_pkg::DFC_RTL018_STATUS__ATX_REJECTED_PUSH_COUNT__COUNT_LO];
      host_push(32'hFFFF_FFFF, 1'b0, 1'b0, 14'h0);
      @(posedge core_clk_i); #1;
      check("Case6 queue level UNCHANGED after rejected push (still 8, not 9 or corrupted)", queue_level(), 64'd8);
      check_bit("Case6 ATX_STATUS.REJECTED sticky set", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__REJECTED_HI], 1'b1);
      check("Case6 ATX_REJECTED_PUSH_COUNT incremented by exactly 1",
            status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_REJECTED_PUSH_COUNT__COUNT_HI:
                     dfc_types_pkg::DFC_RTL018_STATUS__ATX_REJECTED_PUSH_COUNT__COUNT_LO],
            64'(rejected_count_before + 1));
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__REJECTED_HI);
    effective_operational_enable_i = 1'b1;
    @(posedge core_clk_i); #1;
    // Drain the full queue completely before the next case.
    wait_queue_level(0, 20000);
    check_bit("Case6 queue drains to fully empty after re-enabling TX", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__QUEUE_EMPTY_HI], 1'b1);

    // ---------------------------------------------------------------------
    // Case 7: UNDERRUN classification -- module enabled, queue genuinely
    // empty, TX engine idle: must set UNDERRUN evidence exactly once, not
    // once per CORE_CLK cycle it stays empty.
    // ---------------------------------------------------------------------
    begin : case7_underrun
      logic [31:0] underrun_count_before, underrun_count_after;
      underrun_count_before = status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_UNDERRUN_COUNT__COUNT_HI:
                                        dfc_types_pkg::DFC_RTL018_STATUS__ATX_UNDERRUN_COUNT__COUNT_LO];
      repeat (50) @(posedge core_clk_i);  // stay idle-empty for many cycles
      check_bit("Case7 ATX_STATUS.UNDERRUN sticky set", status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__UNDERRUN_HI], 1'b1);
      underrun_count_after = status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_UNDERRUN_COUNT__COUNT_HI:
                                       dfc_types_pkg::DFC_RTL018_STATUS__ATX_UNDERRUN_COUNT__COUNT_LO];
      check("Case7 ATX_UNDERRUN_COUNT incremented by exactly 1 across 50 idle-empty cycles (not one per cycle)",
            underrun_count_after, 64'(underrun_count_before + 1));
    end
    pulse_ctrl_bit(dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__UNDERRUN_HI);
    @(posedge core_clk_i); #1;

    // ---------------------------------------------------------------------
    // Case 8: host-vs-route last-free-slot tiebreaker (ARCH-RTL018-001),
    // CONFLICT case -- fill to exactly 7 (one free slot), then assert a
    // host push and a route push on the SAME cycle: host must win, the
    // route request must stay backpressured (msg_ready_o low) until the
    // host's entry is fully committed, and once the host's entry is
    // drained the route's own long-held request must THEN be accepted
    // (never dropped, never double-counted as lost).
    // ---------------------------------------------------------------------
    effective_operational_enable_i = 1'b0;  // pile up entries without draining
    @(posedge core_clk_i); #1;
    for (int i = 0; i < 7; i++) begin
      host_push(32'h0000_0020 + i[31:0], 1'b0, 1'b0, 14'h0);
      wait_queue_level(i + 1, 50);
    end
    check("Case8 queue at 7 (one free slot)", queue_level(), 64'd7);

    // Stage the host's push fields AHEAD of time (settled, no pulse yet),
    // then assert msg_valid_i and the ATX_PUSH pulse together in the same
    // simulation time step so both are visible to the arbiter on the
    // IDENTICAL CORE_CLK edge -- the real test of the tiebreaker, not a
    // sequential approximation of it.
    stage_push_fields(32'h0000_0099, 1'b0, 1'b0, 14'h0);
    @(posedge core_clk_i); #1;
    msg_record_i = '0;
    msg_record_i[dfc_types_pkg::DFC_MESSAGE_RECORD__PAYLOAD_LO +: 32] = 32'h0000_00AA;
    msg_valid_i = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_PUSH__PUSH_HI] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_PUSH__PUSH_HI] = 1'b0;
    check_bit("Case8 route NOT accepted while host push is being serviced (backpressured, not lost)", msg_ready_o, 1'b0);
    wait_queue_level(8, 50);
    check("Case8 host push won the last slot (queue now FULL at 8)", queue_level(), 64'd8);
    check_bit("Case8 route request still pending (msg_valid_i still asserted, testbench never retracted it)", msg_valid_i, 1'b1);

    // Drain one entry so a slot frees for the still-pending route request.
    effective_operational_enable_i = 1'b1;
    @(posedge core_clk_i); #1;
    wait_queue_level(7, 20000);
    begin : case8_route_wait
      int unsigned n;
      n = 0;
      while (!msg_ready_o && n < 2000) begin @(posedge core_clk_i); n++; end
      check_bit("Case8 route request eventually accepted once a slot freed (not lost)", msg_ready_o, 1'b1);
      @(posedge core_clk_i);
      #1;
      msg_valid_i = 1'b0;
    end
    wait_queue_level(8, 50);
    check("Case8 route-sourced entry actually queued (level back to 8)", queue_level(), 64'd8);
    wait_queue_level(0, 50000);

    // ---------------------------------------------------------------------
    // Case 9: host-vs-route, NON-CONFLICT case -- room for both (queue at
    // 0, 8 free slots). Both a host push and a route push asserted the
    // same cycle must BOTH eventually land (host first, by fixed priority,
    // then route one arbiter turn later) -- neither is rejected nor
    // dropped, confirming the tiebreaker is narrowly scoped to the
    // last-slot case only (ARCH-RTL018-001's own text), not a blanket
    // host-always-wins rule.
    // ---------------------------------------------------------------------
    effective_operational_enable_i = 1'b0;
    @(posedge core_clk_i); #1;
    stage_push_fields(32'h0000_0077, 1'b0, 1'b0, 14'h0);
    @(posedge core_clk_i); #1;
    msg_record_i = '0;
    msg_record_i[dfc_types_pkg::DFC_MESSAGE_RECORD__PAYLOAD_LO +: 32] = 32'h0000_00BB;
    msg_valid_i = 1'b1;
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_PUSH__PUSH_HI] = 1'b1;
    @(posedge core_clk_i);
    #1;
    control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_PUSH__PUSH_HI] = 1'b0;
    wait_queue_level(1, 50);
    begin : case9_route_wait
      int unsigned n;
      n = 0;
      while (!msg_ready_o && n < 2000) begin @(posedge core_clk_i); n++; end
      check_bit("Case9 route request accepted shortly after (no real conflict, not backpressured as 'lost')", msg_ready_o, 1'b1);
      @(posedge core_clk_i);
      #1;
      msg_valid_i = 1'b0;
    end
    wait_queue_level(2, 50);
    check("Case9 both host and route entries queued (level 2)", queue_level(), 64'd2);
    effective_operational_enable_i = 1'b1;
    @(posedge core_clk_i); #1;
    wait_queue_level(0, 50000);

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
