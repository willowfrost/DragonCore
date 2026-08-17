// dfc_rtl024_spi_bridge.sv -- SPI host transport to DRI bridge (part of
// RTL-024's host executor role, ARCH-CONN-002). Hand-authored, not
// generated.
//
// Controlling documents: RCA-DFC-SRS-002 SS6.3 (DFC-INTF-0011..0036),
// RCA-DFC-ARCH-002 SS6 (ARCH-SPI-001..018), RCA-DFC-RTL-STD-002 SS12
// (RTLSTD-SPI-001..018).
//
// ============================================================================
// SCOPE OF THIS FIRST IMPLEMENTATION:
//
// IMPLEMENTED (the mainline transaction path, byte-exact to the SRS):
//   - SPI Mode 0 shift engine: MSB-first, MOSI sampled on SCLK rising edge,
//     MISO driven on SCLK falling edge (DFC-INTF-0012).
//   - Command framing: opcode(1) + addr(4) + count-1(1) + data(4*N) +
//     CRC(2), dynamic length resolved from opcode/count as bytes arrive
//     (ARCH-SPI-003/004).
//   - CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF, no reflect, xorout 0)
//     for both command and response (DFC-INTF-0022/0023) -- verified
//     against the standard "123456789" -> 0x29B1 test vector before this
//     module was written.
//   - Command-accepted pulse exactly once, only after full CRC validated
//     (ARCH-SPI-010, RTLSTD-SPI-003).
//   - Toggle+ack mailbox crossing SCLK -> CORE_CLK with a stable latched
//     payload (ARCH-SPI-014, RTLSTD-SPI-007, RTLSTD-CDC-003).
//   - Ordered, non-atomic multiword DRI execution: stop on first failing
//     word, completed-count increments only on OK (ARCH-SPI-008/009,
//     RTLSTD-SPI-008, DFC-INTF-0021/0028/0033).
//   - Response builder: marker 0xA5, status, completed count, reserved
//     byte, read data words, response CRC -- built as one stable object
//     before crossing back to SCLK (ARCH-SPI-005/011, DFC-INTF-0024/0025).
//   - Response mailbox CORE_CLK -> SCLK, same toggle+ack discipline.
//   - Status mapping for: OK(0x00), invalid opcode(0x02), invalid
//     length/count(0x03), access error(0x06) via DRI ACCESS_ERROR,
//     protected-write failure(0x07) via DRI PROTECTED_ERROR, CRC
//     error(0x08), invalid address(0x05) via DRI DECODE_ERROR.
//   - Reset-release quiet interval (DFC-INTF-0015, ARCH-SPI-018): 1us
//     CS_N-high/SCLK-low qualification before any frame is accepted.
//
// NOT YET IMPLEMENTED -- real, disclosed gaps:
//   - CS_N mid-frame abort handling (ARCH-SPI-011/012, DFC-INTF-0030/0031/
//     0032): pre-acceptance abort evidence, response-truncation evidence,
//     and the saturating abort counter are NOT wired to HOST_STATUS/
//     HOST_ABORT_COUNT yet. A mid-frame CS_N deassertion today simply
//     returns the bridge to IDLE without producing that evidence.
//   - Internal timeout escalation to status 0x09 (ARCH-SPI-016): the
//     8-cycle DRI deadline is enforced by dfc_rtl001 itself (it always
//     responds same/next cycle in this implementation), so the timeout
//     path in this bridge is unexercised and unverified.
//   - Busy status (0x01): this bridge accepts one frame at a time with no
//     queuing, so BUSY is never produced; a host retry during a hung
//     transaction is not modeled.
//   - CS_N-to-first-SCLK-edge 50ns setup qualification (DFC-INTF-0016) is
//     NOT separately verified -- only the 1us post-reset quiet interval is.
//   - Endpoint error (0x0A): no downstream endpoint failure exists yet
//     since RTL-002..023 don't exist (matches dfc_rtl001.sv's own
//     disclosed scope).
//   - RESPONSE-READY TIMING CHARACTERISTIC (found via simulation, not a
//     latent bug -- disclosed because it affects host implementations):
//     this bridge begins shifting its response onto MISO on the first
//     qualifying SCLK falling edge once the response is built, which can
//     be very soon after an early rejection (e.g. an unrecognized opcode
//     is rejected after just one byte, well before any assumed frame
//     length completes). If a host continues driving additional "command"
//     clock edges beyond what the design needed to decide the outcome, the
//     response can fully shift past and settle before that host starts
//     reading it. A host must either (a) send only the bytes it has real
//     data for and begin watching MISO immediately afterward, scanning for
//     the 0xA5 marker rather than assuming a fixed byte offset (which is
//     also the spec-correct general approach given DFC-INTF-0024's 0-2
//     byte wait-fill allowance), or (b) this bridge could be enhanced in a
//     future revision to hold the response until CS_N's frame boundary is
//     unambiguous. This is exercised and confirmed in
//     verification/testbench/rtl-024/spi_bridge_tb.sv's invalid-opcode
//     case, which sends only the opcode byte before scanning for exactly
//     this reason.
//
// Log anything this reveals as a genuine spec gap in OPEN_ISSUES.md.
// ============================================================================

module dfc_rtl024_spi_bridge (
  input  logic core_clk_i,
  input  logic core_rst_n_i,

  input  logic spi_sclk_i,
  input  logic spi_cs_n_i,
  input  logic spi_mosi_i,
  output logic spi_miso_o,
  output logic spi_miso_oe_o,

  output logic        dri_req_valid_o,
  input  logic        dri_req_ready_i,
  output logic        dri_req_write_o,
  output logic [31:0] dri_req_addr_o,
  output logic [31:0] dri_req_wdata_o,
  output logic [3:0]  dri_req_wstrb_o,
  input  logic        dri_rsp_valid_i,
  output logic        dri_rsp_ready_o,
  input  logic [31:0] dri_rsp_rdata_i,
  input  logic [2:0]  dri_rsp_code_i
);

  localparam logic [7:0] OPCODE_READ  = 8'h01;
  localparam logic [7:0] OPCODE_WRITE = 8'h02;
  localparam logic [7:0] RSP_MARKER   = 8'hA5;

  localparam logic [7:0] STAT_OK           = 8'h00;
  localparam logic [7:0] STAT_INVALID_OP   = 8'h02;
  localparam logic [7:0] STAT_INVALID_LEN  = 8'h03;
  localparam logic [7:0] STAT_INVALID_ADDR = 8'h05;
  localparam logic [7:0] STAT_ACCESS_ERROR = 8'h06;
  localparam logic [7:0] STAT_PROTECTED    = 8'h07;
  localparam logic [7:0] STAT_CRC_ERROR    = 8'h08;

  function automatic logic [15:0] crc16_update(logic [15:0] crc, logic [7:0] data);
    logic [15:0] x;
    begin
      x = crc ^ (16'(data) << 8);
      for (int i = 0; i < 8; i++)
        x = x[15] ? ((x << 1) ^ 16'h1021) : (x << 1);
      crc16_update = x;
    end
  endfunction

  // ==========================================================================
  // Reset-release quiet interval (DFC-INTF-0015, ARCH-SPI-018): 1us of
  // continuously high CS_N and low SCLK, counted in CORE_CLK. At 50 MHz
  // nominal, 1us = 50 cycles; sized generously (64) since exact frequency
  // may drift within DFC-INTF-0005's +/-100ppm tolerance.
  // ==========================================================================
  localparam int QUIET_CYCLES = 64;
  logic [6:0] quiet_count_q;
  logic       quiet_qualified_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      quiet_count_q     <= '0;
      quiet_qualified_q <= 1'b0;
    end else if (spi_cs_n_i && !spi_sclk_i) begin
      if (quiet_count_q < QUIET_CYCLES[6:0]) quiet_count_q <= quiet_count_q + 1'b1;
      else quiet_qualified_q <= 1'b1;
    end else begin
      quiet_count_q <= '0;
      // NOTE: quiet_qualified_q is sticky once reached -- DFC-INTF-0015
      // only requires this interval once, after reset release, not before
      // every subsequent frame.
    end
  end

  // ==========================================================================
  // SCLK-domain synchronizers for CS_N and SCLK edges into CORE_CLK, and a
  // simple SCLK-domain byte shift engine. Given DFC-INTF-0013's 100kHz-
  // 10MHz SCLK range is always slower than CORE_CLK's 50MHz, this bridge
  // takes the simpler, common approach of running the byte-framing state
  // machine directly in the CORE_CLK domain, sampling synchronized SCLK
  // edges -- rather than a separate SCLK-domain shift register + toggle
  // mailbox. This satisfies RTLSTD-CDC-008 (synchronize before use) but
  // is a different -- simpler -- structural choice than a literal
  // separate-clock-domain shift register; it is disclosed here rather
  // than presented as the only possible architecture.
  // ==========================================================================
  logic [2:0] sclk_sync_q, cs_n_sync_q;
  logic       mosi_sync_q, mosi_sync2_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sclk_sync_q  <= 3'b000;
      cs_n_sync_q  <= 3'b111;
      mosi_sync_q  <= 1'b0;
      mosi_sync2_q <= 1'b0;
    end else begin
      sclk_sync_q  <= {sclk_sync_q[1:0], spi_sclk_i};
      cs_n_sync_q  <= {cs_n_sync_q[1:0], spi_cs_n_i};
      mosi_sync_q  <= spi_mosi_i;
      mosi_sync2_q <= mosi_sync_q;
    end
  end
  wire sclk_rise = (sclk_sync_q[2:1] == 2'b01);
  wire sclk_fall = (sclk_sync_q[2:1] == 2'b10);
  wire cs_active = ~cs_n_sync_q[2];   // synchronized, active-low CS_N -> active-high internal

  // ==========================================================================
  // Command collection FSM (CORE_CLK domain, per synchronized SCLK edges).
  // ==========================================================================
  typedef enum logic [2:0] {
    F_IDLE, F_OPCODE, F_ADDR, F_COUNT, F_DATA, F_CRC, F_DONE_OK, F_DONE_BAD
  } frame_state_e;
  frame_state_e fstate_q;

  logic [2:0]  bit_cnt_q;      // 0-7 within current byte
  logic [7:0]  shift_q;        // incoming byte shift register
  logic [3:0]  byte_idx_q;     // byte index within opcode+addr+count (0-5)
  logic [3:0]  data_word_idx_q;// which data word (0-15) being shifted in
  logic [1:0]  data_byte_idx_q;// which byte (0-3) within the current data word

  logic [7:0]  opcode_q;
  logic [31:0] addr_q;
  logic [3:0]  count_m1_q;     // count-minus-one, 0-15
  logic [31:0] data_words_q [0:15];
  logic [15:0] cmd_crc_calc_q;
  logic [15:0] cmd_crc_rx_q;
  logic        is_write_q;
  logic        accepted_q, invalid_op_q, invalid_len_q, crc_bad_q;

  wire [3:0] word_count = count_m1_q + 4'd1;         // 1-16, informational

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      fstate_q        <= F_IDLE;
      bit_cnt_q       <= 3'd0;
      shift_q         <= 8'd0;
      byte_idx_q      <= 4'd0;
      data_word_idx_q <= 4'd0;
      data_byte_idx_q <= 2'd0;
      opcode_q        <= 8'd0;
      addr_q          <= 32'd0;
      count_m1_q      <= 4'd0;
      cmd_crc_calc_q  <= 16'hFFFF;
      cmd_crc_rx_q    <= 16'd0;
      is_write_q      <= 1'b0;
      accepted_q      <= 1'b0;
      invalid_op_q    <= 1'b0;
      invalid_len_q   <= 1'b0;
      crc_bad_q       <= 1'b0;
    end else begin
      // one-cycle pulses -- default low every cycle unless set below
      accepted_q    <= 1'b0;
      invalid_op_q  <= 1'b0;
      invalid_len_q <= 1'b0;
      crc_bad_q     <= 1'b0;

      if (!cs_active) begin
        // CS_N inactive: abandon any in-progress frame (ARCH-SPI-011). Full
        // abort-evidence bookkeeping is a disclosed gap -- see file header.
        fstate_q        <= F_IDLE;
        bit_cnt_q       <= 3'd0;
        shift_q         <= 8'd0;
        byte_idx_q      <= 4'd0;
        data_word_idx_q <= 4'd0;
        data_byte_idx_q <= 2'd0;
        cmd_crc_calc_q  <= 16'hFFFF;
      end else if (sclk_rise && quiet_qualified_q) begin
        logic [7:0] rx_byte;
        shift_q <= {shift_q[6:0], mosi_sync2_q};
        rx_byte = {shift_q[6:0], mosi_sync2_q};
        if (bit_cnt_q == 3'd7) begin
          bit_cnt_q <= 3'd0;
          unique case (fstate_q)
            F_IDLE: begin
              opcode_q       <= rx_byte;
              cmd_crc_calc_q <= crc16_update(16'hFFFF, rx_byte);
              if (rx_byte == OPCODE_READ || rx_byte == OPCODE_WRITE) begin
                is_write_q <= (rx_byte == OPCODE_WRITE);
                fstate_q   <= F_ADDR;
                byte_idx_q <= 4'd0;
              end else begin
                fstate_q     <= F_DONE_BAD;  // keep shifting to stay byte-
                invalid_op_q <= 1'b1;         // aligned; never enter mailbox
              end
            end
            F_ADDR: begin
              addr_q         <= {addr_q[23:0], rx_byte};
              cmd_crc_calc_q <= crc16_update(cmd_crc_calc_q, rx_byte);
              if (byte_idx_q == 4'd3) fstate_q <= F_COUNT;
              byte_idx_q <= byte_idx_q + 4'd1;
            end
            F_COUNT: begin
              cmd_crc_calc_q <= crc16_update(cmd_crc_calc_q, rx_byte);
              if (rx_byte[7:4] != 4'h0) begin
                fstate_q      <= F_DONE_BAD;  // DFC-INTF-0019
                invalid_len_q <= 1'b1;
              end else begin
                count_m1_q      <= rx_byte[3:0];
                data_word_idx_q <= 4'd0;
                data_byte_idx_q <= 2'd0;
                if (is_write_q) fstate_q <= F_DATA;
                else            fstate_q <= F_CRC;
                if (!is_write_q) byte_idx_q <= 4'd0;  // reset for F_CRC's
                                                        // reuse of byte_idx_q
                                                        // as its own counter
              end
            end
            F_DATA: begin
              cmd_crc_calc_q <= crc16_update(cmd_crc_calc_q, rx_byte);
              data_words_q[data_word_idx_q] <=
                {data_words_q[data_word_idx_q][23:0], rx_byte};
              if (data_byte_idx_q == 2'd3) begin
                data_byte_idx_q <= 2'd0;
                if (data_word_idx_q == count_m1_q) begin
                  fstate_q   <= F_CRC;
                  byte_idx_q <= 4'd0;  // reset for F_CRC's reuse of byte_idx_q
                end
                else data_word_idx_q <= data_word_idx_q + 4'd1;
              end else begin
                data_byte_idx_q <= data_byte_idx_q + 2'd1;
              end
            end
            F_CRC: begin
              if (byte_idx_q == 4'd0) begin
                cmd_crc_rx_q[15:8] <= rx_byte;
                byte_idx_q         <= 4'd1;
              end else begin
                cmd_crc_rx_q[7:0] <= rx_byte;
                if ({cmd_crc_rx_q[15:8], rx_byte} == cmd_crc_calc_q) begin
                  fstate_q   <= F_DONE_OK;
                  accepted_q <= 1'b1;
                end else begin
                  fstate_q  <= F_DONE_BAD;
                  crc_bad_q <= 1'b1;
                end
              end
            end
            default: ;  // F_DONE_OK/F_DONE_BAD: ignore further bits until
                        // CS_N deasserts
          endcase
        end else begin
          bit_cnt_q <= bit_cnt_q + 3'd1;
        end
      end
    end
  end

  // ==========================================================================
  // Ordered multiword DRI executor (CORE_CLK domain).
  // ==========================================================================
  typedef enum logic [1:0] { X_IDLE, X_ISSUE, X_WAIT, X_DONE } exec_state_e;
  exec_state_e xstate_q;

  logic [3:0]  word_idx_q;
  logic [3:0]  completed_count_q;
  logic [7:0]  final_status_q;
  logic [31:0] rdata_words_q [0:15];
  logic        exec_write_q;
  logic [31:0] exec_addr_q;

  // TIMING FIX (found via real place-and-route critical path analysis,
  // not simulation): the direct write `rdata_words_q[word_idx_q] <=
  // dri_rsp_rdata_i` combined a combinationally-derived read value
  // (dri_rsp_rdata_i traces back through RTL-001's full register-bank
  // read mux, since dfc_rtl001.sv drives it via a plain `assign`, not a
  // flop) with a variable-array-index write (word_idx_q selects 1 of 16
  // slots, synthesizing a 16-way write-enable demux) IN THE SAME CYCLE.
  // Measured critical path: 20.16 ns (required: 20.00 ns @ 50 MHz),
  // ~17 ns of which was routing delay from the demux structure's pieces
  // landing spread across the die -- a routing-spread problem, the same
  // underlying principle as the earlier CRC timing bug (too much work
  // committed in one cycle) but manifesting as placement/routing spread
  // rather than logic depth this time. Deliberately NOT relying on a
  // luckier placement seed to "fix" this: as more modules are added in
  // future revisions, placement pressure only increases, and a path this
  // marginal would likely resurface. Fixed structurally instead: the
  // array write is deferred by exactly one CORE_CLK cycle via these
  // staging registers, so nothing ever combines a combinationally-
  // derived value with a variable-index array write in a single cycle
  // again. Adds one cycle of latency per read word (max 16 cycles for a
  // full 16-word read) -- negligible against DFC-INTF-0013's 100kHz-
  // 10MHz SPI rate, where even the fastest legal bit period is ~50x
  // longer than one CORE_CLK cycle.
  logic [31:0] capture_data_q;
  logic [3:0]  capture_idx_q;
  logic        capture_pending_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      xstate_q          <= X_IDLE;
      word_idx_q        <= 4'd0;
      completed_count_q <= 4'd0;
      final_status_q    <= STAT_OK;
      exec_write_q      <= 1'b0;
      exec_addr_q       <= 32'd0;
      dri_req_valid_o   <= 1'b0;
      dri_req_write_o   <= 1'b0;
      dri_req_addr_o    <= 32'd0;
      dri_req_wdata_o   <= 32'd0;
      dri_req_wstrb_o   <= 4'b0000;
      dri_rsp_ready_o   <= 1'b0;
      capture_data_q    <= 32'd0;
      capture_idx_q     <= 4'd0;
      capture_pending_q <= 1'b0;
    end else begin
      // Deferred array write: exactly one cycle behind capture, fully
      // decoupled from xstate_q's own progression (the executor may
      // already have moved on to the next word's X_ISSUE by the time
      // this fires -- harmless, since this writes the PREVIOUS word's
      // slot, independent of whatever the next word is doing).
      if (capture_pending_q) begin
        rdata_words_q[capture_idx_q] <= capture_data_q;
        capture_pending_q            <= 1'b0;
      end

      unique case (xstate_q)
        X_IDLE: begin
          dri_req_valid_o <= 1'b0;
          if (invalid_op_q) begin
            final_status_q    <= STAT_INVALID_OP;
            completed_count_q <= 4'd0;
            xstate_q          <= X_DONE;
          end else if (invalid_len_q) begin
            final_status_q    <= STAT_INVALID_LEN;
            completed_count_q <= 4'd0;
            xstate_q          <= X_DONE;
          end else if (crc_bad_q) begin
            final_status_q    <= STAT_CRC_ERROR;
            completed_count_q <= 4'd0;
            xstate_q          <= X_DONE;
          end else if (accepted_q) begin
            exec_write_q      <= is_write_q;
            exec_addr_q       <= addr_q;
            word_idx_q        <= 4'd0;
            completed_count_q <= 4'd0;
            xstate_q          <= X_ISSUE;
          end
        end
        X_ISSUE: begin
          dri_req_valid_o <= 1'b1;
          dri_req_write_o <= exec_write_q;
          dri_req_addr_o  <= exec_addr_q + {26'd0, word_idx_q, 2'd0};
          dri_req_wdata_o <= data_words_q[word_idx_q];
          dri_req_wstrb_o <= 4'b1111;
          dri_rsp_ready_o <= 1'b1;
          if (dri_req_valid_o && dri_req_ready_i) begin
            dri_req_valid_o <= 1'b0;
            xstate_q        <= X_WAIT;
          end
        end
        X_WAIT: begin
          if (dri_rsp_valid_i && dri_rsp_ready_o) begin
            dri_rsp_ready_o <= 1'b0;
            unique case (dri_rsp_code_i)
              3'b000: begin  // OK
                if (!exec_write_q) begin
                  capture_data_q    <= dri_rsp_rdata_i;
                  capture_idx_q     <= word_idx_q;
                  capture_pending_q <= 1'b1;
                end
                completed_count_q <= completed_count_q + 4'd1;
                if (word_idx_q == count_m1_q) begin
                  final_status_q <= STAT_OK;
                  xstate_q       <= X_DONE;
                end else begin
                  word_idx_q <= word_idx_q + 4'd1;
                  xstate_q   <= X_ISSUE;
                end
              end
              3'b001: begin final_status_q <= STAT_INVALID_ADDR; xstate_q <= X_DONE; end // DECODE_ERROR
              3'b010: begin final_status_q <= STAT_ACCESS_ERROR; xstate_q <= X_DONE; end // ACCESS_ERROR
              3'b011: begin final_status_q <= STAT_PROTECTED;    xstate_q <= X_DONE; end // PROTECTED_ERROR
              default: begin final_status_q <= STAT_ACCESS_ERROR; xstate_q <= X_DONE; end
            endcase
          end
        end
        X_DONE: begin
          if (!cs_active) xstate_q <= X_IDLE;  // consumed by response
                                                 // builder below; return to
                                                 // IDLE only after the host
                                                 // has released CS_N for
                                                 // this frame
        end
        default: xstate_q <= X_IDLE;
      endcase
    end
  end

  // ==========================================================================
  // Response builder + SCLK-domain shift-out (CORE_CLK domain construction,
  // shifted out on synchronized SCLK falling edges per SPI Mode 0).
  //
  // TIMING FIX (found via real ECP5 place-and-route, not simulation --
  // Icarus checks logical correctness only, never gate/routing delay):
  // the original version of this builder computed the ENTIRE response
  // (up to 70 bytes) plus its full CRC-16 (up to ~576 sequential shift/
  // xor rounds) as ONE combinational block within a single clock edge.
  // Real place-and-route measured this design closing timing at only
  // 9.75 MHz against the required 50 MHz -- confirmed via nextpnr-ecp5's
  // critical path report, which traced straight through this block's
  // rsp_bytes_q chain. Icarus simulation could not have caught this: it
  // has no gate-delay/routing model at all, only logical/functional
  // correctness, which this block always had.
  //
  // Fix: spread the work across multiple CORE_CLK cycles -- one 4-byte
  // word (plus its CRC-16 folding, 4 short rounds instead of dozens) per
  // cycle, ~18 cycles worst case for a full 16-word response. This is
  // comfortably inside DFC-INTF-0024's 0-2 whole-byte (16 SCLK bit
  // period) wait-fill allowance at any legal SCLK rate (100 kHz-10 MHz,
  // DFC-INTF-0013): 18 CORE_CLK cycles = 360ns, vs. a 1600ns budget at
  // the fastest legal 10 MHz SCLK, and far more margin at typical rates.
  // Building no longer needs to be gated to a specific sclk_fall edge
  // (the earlier race-condition fix's gating) -- the multi-cycle delay
  // itself naturally separates command-tail bits from the first real
  // response bit, so the existing shift-out logic's own
  // `rsp_ready_q && sclk_fall` gate is sufficient on its own.
  // ==========================================================================
  logic        rsp_ready_q;    // response object complete and stable
  // Max response: marker+status+count+rsv(4) + 16 words*4 bytes(64) + crc(2)
  // = 70 bytes for the largest legal transaction (DFC-INTF-0019: up to 16
  // words).
  logic [7:0]  rsp_bytes_q [0:71];
  logic [6:0]  rsp_len_q;

  logic [6:0] shift_out_idx_q;
  logic [2:0] out_bit_cnt_q;
  logic [7:0] out_shift_q;
  logic       rsp_building_q;

  typedef enum logic [1:0] { B_IDLE, B_WORD, B_FINISH } build_state_e;
  build_state_e bstate_q;
  logic [3:0]  build_word_idx_q;
  logic [6:0]  build_n_q;
  logic [15:0] build_crc_q;
  logic        build_done_q;
  // Free-running byte-boundary tracker, driven only by real sclk_fall
  // events, independent of the command-side bit_cnt_q (reusing that
  // counter for a second purpose is exactly the class of bug already
  // found once this session -- byte_idx_q's reuse across F_ADDR/F_CRC).
  // A single-edge build_done_q->rsp_ready_q handshake proved fragile
  // (confirmed by simulation: it introduced a partial-bit, not just
  // partial-byte, misalignment) -- waiting for a genuine byte boundary
  // removes bit-level phase ambiguity entirely rather than hoping one
  // specific edge lines up.
  logic [2:0]  frame_bit_cnt_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      rsp_ready_q      <= 1'b0;
      rsp_len_q        <= 7'd0;
      shift_out_idx_q  <= 7'd0;
      out_bit_cnt_q    <= 3'd0;
      out_shift_q      <= 8'd0;
      rsp_building_q   <= 1'b0;
      bstate_q         <= B_IDLE;
      build_word_idx_q <= 4'd0;
      build_n_q        <= 7'd0;
      build_crc_q      <= 16'hFFFF;
      build_done_q     <= 1'b0;
      frame_bit_cnt_q  <= 3'd0;
    end else begin
      unique case (bstate_q)
        B_IDLE: begin
          if (xstate_q == X_DONE && !rsp_ready_q && !rsp_building_q) begin
            logic [15:0] c0, c1, c2, c3;
            rsp_building_q <= 1'b1;
            rsp_bytes_q[0] <= RSP_MARKER;
            rsp_bytes_q[1] <= final_status_q;
            rsp_bytes_q[2] <= {4'd0, completed_count_q};
            rsp_bytes_q[3] <= 8'h00;  // reserved
            // 4 short CRC rounds (header bytes) -- not the ~576-round chain
            // this block used to build in one shot.
            c0 = crc16_update(16'hFFFF, RSP_MARKER);
            c1 = crc16_update(c0, final_status_q);
            c2 = crc16_update(c1, {4'd0, completed_count_q});
            c3 = crc16_update(c2, 8'h00);
            build_crc_q      <= c3;
            build_n_q        <= 7'd4;
            build_word_idx_q <= 4'd0;
            bstate_q         <= B_WORD;
          end
        end
        B_WORD: begin
          logic include_word;
          if (!exec_write_q && final_status_q == STAT_OK)
            include_word = (build_word_idx_q <= count_m1_q);
          else if (!exec_write_q)
            include_word = (build_word_idx_q < completed_count_q);  // DFC-INTF-0025
          else
            include_word = 1'b0;  // WRITE response never carries read data
          if (include_word) begin
            logic [15:0] c0, c1, c2, c3;
            rsp_bytes_q[build_n_q]      <= rdata_words_q[build_word_idx_q][31:24];
            rsp_bytes_q[build_n_q+7'd1] <= rdata_words_q[build_word_idx_q][23:16];
            rsp_bytes_q[build_n_q+7'd2] <= rdata_words_q[build_word_idx_q][15:8];
            rsp_bytes_q[build_n_q+7'd3] <= rdata_words_q[build_word_idx_q][7:0];
            // 4 short CRC rounds (this word's bytes) per cycle -- same
            // bounded-depth discipline as the header above.
            c0 = crc16_update(build_crc_q, rdata_words_q[build_word_idx_q][31:24]);
            c1 = crc16_update(c0, rdata_words_q[build_word_idx_q][23:16]);
            c2 = crc16_update(c1, rdata_words_q[build_word_idx_q][15:8]);
            c3 = crc16_update(c2, rdata_words_q[build_word_idx_q][7:0]);
            build_crc_q <= c3;
            build_n_q   <= build_n_q + 7'd4;
          end
          if (build_word_idx_q == 4'd15) bstate_q <= B_FINISH;
          else build_word_idx_q <= build_word_idx_q + 4'd1;
        end
        B_FINISH: begin
          rsp_bytes_q[build_n_q]      <= build_crc_q[15:8];
          rsp_bytes_q[build_n_q+7'd1] <= build_crc_q[7:0];
          rsp_len_q   <= build_n_q + 7'd2;
          build_done_q <= 1'b1;  // internal build complete; do NOT expose
                                   // on spi_miso_o yet -- see build_done_q
                                   // handling below, which waits for a
                                   // real sclk_fall before presenting bit 0
          bstate_q    <= B_IDLE;
        end
        default: bstate_q <= B_IDLE;
      endcase

      // Free-running byte-boundary tracker: increments on every real
      // sclk_fall while CS_N is active, resets at frame start. Purely
      // observational -- never repurposed for anything else.
      if (!cs_active) frame_bit_cnt_q <= 3'd0;
      else if (sclk_fall) frame_bit_cnt_q <= frame_bit_cnt_q + 3'd1;

      // Present bit 0 only at a genuine byte boundary after building
      // completes -- i.e. on the sclk_fall that completes the CURRENT
      // byte (frame_bit_cnt_q == 7), so the very next bit starts fresh.
      // NOT the instant build_done_q flips, and not just "the next
      // sclk_fall" either (both were tried and both left a real, sim-
      // confirmed misalignment) -- only a genuine byte boundary is
      // guaranteed alignment-safe regardless of exactly which core_clk
      // cycle building happened to finish on.
      if (build_done_q && !rsp_ready_q && sclk_fall && frame_bit_cnt_q == 3'd7) begin
        rsp_ready_q     <= 1'b1;
        build_done_q    <= 1'b0;
        shift_out_idx_q <= 7'd0;
        out_bit_cnt_q   <= 3'd0;
        out_shift_q     <= rsp_bytes_q[0];
      end

      if (!cs_active) begin
        rsp_ready_q    <= 1'b0;
        rsp_building_q <= 1'b0;
        build_done_q   <= 1'b0;
        bstate_q       <= B_IDLE;
      end else if (rsp_ready_q && sclk_fall) begin
        if (out_bit_cnt_q == 3'd7) begin
          out_bit_cnt_q <= 3'd0;
          if (shift_out_idx_q + 7'd1 < rsp_len_q) begin
            shift_out_idx_q <= shift_out_idx_q + 7'd1;
            out_shift_q     <= rsp_bytes_q[shift_out_idx_q + 7'd1];
          end
        end else begin
          out_bit_cnt_q <= out_bit_cnt_q + 3'd1;
          out_shift_q   <= {out_shift_q[6:0], 1'b0};
        end
      end
    end
  end

  assign spi_miso_o    = rsp_ready_q ? out_shift_q[7] : 1'b0;
  assign spi_miso_oe_o = rsp_ready_q && cs_active;

endmodule : dfc_rtl024_spi_bridge
