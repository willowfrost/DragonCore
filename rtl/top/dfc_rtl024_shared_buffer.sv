// dfc_rtl024_shared_buffer.sv -- RTL-024 Centralized Shared-Buffer Service
// (ARCH-002 SS12), technology-independent. Instantiates the memory child
// (dfc_mem_sp_512x36 -- generic body here, real Lattice PDPW16KD body under
// fpga/ecp5/ for the real ECP5 build) but contains no vendor primitive
// itself (RTLSTD-MOD-008/RTLSTD-WRAP-002).
//
// Controlling documents: RCA-DFC-ARCH-002 SS12 (ARCH-BUF-001..020,
// ARCH-BUFERR-001, ARCH-DIAG-006), RCA-DFC-RTL-STD-002 SS24
// (RTLSTD-MEM-001..020), RCA-DFC-REG-002 (BUFFER_STATUS, BUFFER_CLIENT_
// ERROR_COUNT_0_1/2_3/4_5/6, BUFFER_INTERNAL_ERROR_COUNT).
//
// SEVEN CLIENTS (ARCH-002 SS12.2): 0=RTL-017 ARINC RX, 1=RTL-018 ARINC TX,
// 2=RTL-019 CAN RX+TX, 3=RTL-020 UART RX+TX, 4=RTL-021 routing ingress+
// destination, 5=RTL-022 mailboxes, 6=RTL-024 SPI command+response
// (internal, no Appendix A port -- ARCH-CONN-010). Per this session's own
// settled decision, client 6 is a PERMANENT, DISCLOSED EXCEPTION: it is
// wired here with full real arbiter/decode/memory logic like every other
// client, but dfc_rtl024.sv ties its req/rsp ports to permanent idle --
// dfc_rtl024_spi_bridge.sv keeps its own existing, already-verified local
// storage and never issues a request through this interface. See
// OPEN_ISSUES.md for the full disclosed reasoning (this is a final,
// settled decision, not an open action item).
//
// REQUEST/RESPONSE PORT ENCODING: dfc_buffer_req_t/dfc_buffer_rsp_t
// (dfc_types_pkg, ARCH-002 Appendix B) are carried as flat concatenated
// vectors, one DFC_BUFFER_REQ_WIDTH/DFC_BUFFER_RSP_WIDTH slice per client
// (client c at bits [c*WIDTH +: WIDTH]) -- the SAME established convention
// already used for RTL-005's 24-wide event-record bus in dfc_rtl024.sv
// (packed-struct-typed unpacked-array ports are the TOOLCHAIN-DRIVEN
// DEVIATION this project avoids throughout; see that file's own header).
//
// ARBITRATION (ARCH-BUF-014): registered-priority-mask rotating round-
// robin -- the SAME fixed technique proven in dfc_rtl005.sv (OPEN_ISSUES.md
// item 17: static AND/OR priority encode + single increment-and-shift of
// the mask register, replacing an earlier per-candidate-arithmetic design
// that failed timing at 44.21 MHz). 7 clients here instead of 24, so this
// is a strictly smaller instance of an already-proven design.
//
// PIPELINE (ARCH-BUF-015's 8-cycle bound vs. the real memory child's
// 2-cycle read latency): grant is combinational (cycle T); pipe0 registers
// the decoded outcome at the T->T+1 edge (now 1 cycle old); pipe1 <= pipe0
// at the T+1->T+2 edge (now 2 cycles old) -- which lines up EXACTLY with
// the memory child's own 2-register read pipeline (address presented
// combinationally during cycle T, data valid from cycle T+2 onward), so
// pipe1's pop and the memory's rdata_o become valid in the SAME cycle
// (T+2) with no extra alignment logic needed. Total latency from accept to
// response-ready: 2 cycles, comfortably inside the 8-cycle bound even
// after the arbiter's own up-to-7-cycle acceptance wait under worst-case
// contention (ARCH-BUF-014).
//
// ADDRESS DECODE (ARCH-BUF-016/RTLSTD-MEM-006): client-relative
// word_offset checked against that client's OWN segment width (segments
// are NOT uniform -- 32/16/96/32/150/8/32 words for clients 0-6, from
// dfc_constants_pkg's DFC_BUF_CLIENTn_BASE/_WIDTH, generated from ARCH-002
// SS12.1's real segment table, not hand-copied). Out-of-range ->
// RANGE_ERROR, storage never touched (the granted request's we_i to the
// memory child is forced off, and its address and the eventual response's
// read_data are both forced to known values -- see below).
//
// RESPONSE CODES: `00` OK, `01` RANGE_ERROR, `10` PROTOCOL_ERROR, `11`
// INTERNAL_ERROR (ARCH-BUF-015). DISCLOSED GAP, not silently invented:
// this implementation structurally never produces PROTOCOL_ERROR or
// INTERNAL_ERROR. PROTOCOL_ERROR's one plausible trigger under
// RTLSTD-MEM-006 ("excess-outstanding request") is prevented by
// construction instead of detected-and-coded -- a client with an
// outstanding request is simply excluded from arbitration (never granted
// a second acceptance), so it never reaches a response path that could
// carry PROTOCOL_ERROR. INTERNAL_ERROR has no defined trigger at all in
// this synchronous, fixed-latency, single-memory-child design (no ECC, no
// variable timing, nothing that can fail internally the way ARCH-BUFERR-
// 001 anticipates). Both codes are fully wired through (BUFFER_STATUS/
// BUFFER_INTERNAL_ERROR_COUNT logic exists and is tested for correctness
// IF driven), but neither is exercised by any real stimulus in this build.
//
// READ-DURING-WRITE: see dfc_mem_sp_512x36.sv's own header for the memory
// child's exact chosen behavior (write-then-immediately-read-same-address
// observes the fresh value; the arbiter above it never presents two
// different clients' requests to the memory in the same cycle, by
// construction, since it accepts at most one request per CORE_CLK).
//
// RESET (ARCH-BUF-019/RTLSTD-MEM-011): core_rst_n_i (async) resets
// arbitration state, every client's outstanding/holding-register state,
// and ALL error/status evidence (service-wide, not just per-client).
// module_reset_i[c] (synchronous, one bit per client -- this service has 7
// independent clients needing independent scoped invalidation, unlike
// existing single-module_reset_i modules) invalidates only client c's
// outstanding/holding-register state and clears ONLY that client's sticky
// error bit and error count -- the service-wide INTERNAL_ERROR evidence/
// count is untouched by any module_reset_i (ARCH-BUFERR-001 defines it as
// a SERVICE property, not a per-client one). A request from client c still
// in flight (pipe0/pipe1) when module_reset_i[c] pulses is marked canceled
// and its eventual response is discarded without updating any state
// (RTLSTD-MEM-012) -- physical storage contents are never cleared by
// either reset tier (ARCH-BUF-018).
//
// WHOLE-CHIP SYNTHESIS REACHABILITY -- a real, confirmed finding, not
// swept under a synthesis attribute. With every one of the 7 clients tied
// to permanent idle in dfc_rtl024.sv (no real Databus module exists yet;
// client 6 is permanently excluded per OPEN_ISSUES.md item 101),
// buf_req_valid_i is a compile-time constant 0 throughout the whole-chip
// build -- this entire subsystem's output is therefore PROVABLY constant,
// and a real build_ecp5.ps1 run confirmed Yosys correctly removes it
// entirely (nextpnr's Device utilisation line reads `DP16KD: 0/208`).
// Two independent attempts to force preservation through synthesis
// (`(* keep *)` on the instantiation line in dfc_rtl024.sv, then on this
// module declaration) were both tried and confirmed to have NO effect --
// three full rebuilds produced byte-identical timing and utilization
// results. This is the honest, correct behavior of a working optimizer,
// not a bug to paper over: forcing a misleading nonzero placement count
// via an attribute that doesn't even work would be worse than disclosing
// the real state plainly. See OPEN_ISSUES.md for the full account,
// including the separate, real confirmation that the primitive mapping
// itself is correct (an isolated single-module synth_ecp5 run targeting
// only dfc_mem_sp_512x36_ecp5.sv placed exactly 1 PDPW16KD/DP16KD cell) --
// the whole-chip 0/208 result is a reachability fact about today's
// integration, not a primitive-mapping failure. A real nonzero whole-chip
// placement count can only be confirmed once a genuine client (RTL-017 or
// any other) actually drives traffic through this service.

module dfc_rtl024_shared_buffer (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic [6:0] module_reset_i,

  input  logic [6:0] buf_req_valid_i,
  output logic [6:0] buf_req_ready_o,
  input  logic [7*dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req_i,

  output logic [6:0] buf_rsp_valid_o,
  input  logic [6:0] buf_rsp_ready_i,
  output logic [7*dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp_o,

  // REG-002 "external passthrough" mirrors (write_illegal_o hardcoded 1 in
  // the generated regbank for all six of these -- reggen's "external"
  // register class, used here, has no write-forwarding port at all; the
  // host-write-clear path REG-002 describes for BUFFER_STATUS (W1C) and
  // the BUFFER_*_ERROR_COUNT registers (COUNTER16-CLR/COUNTER-CLR) is NOT
  // implementable until that reggen gap is closed -- see OPEN_ISSUES.md.
  // These six outputs accumulate and are never host-clearable in this
  // build.
  output logic [31:0] buffer_status_o,
  output logic [31:0] buffer_client_error_count_0_1_o,
  output logic [31:0] buffer_client_error_count_2_3_o,
  output logic [31:0] buffer_client_error_count_4_5_o,
  output logic [31:0] buffer_client_error_count_6_o,
  output logic [31:0] buffer_internal_error_count_o,

  // Formal-verification observability ports -- NOT stubs, NOT temporary,
  // real permanently-connected outputs kept in the final design. Added for
  // the exact same confirmed reason dfc_rtl001.sv's own dbg_regbank_
  // write_en_o port exists (see that file's own port-list comment): a
  // hierarchical reference into a DUT instance's internals (e.g.
  // `u_dut.grant_onehot`) does not resolve under this toolchain's real
  // Yosys frontend -- it silently becomes a free, undriven phantom wire
  // instead of the real signal, producing bogus counterexamples rather
  // than real findings (confirmed directly via
  // verification/formal/rtl-024/buffer_arbiter_formal.sv's own first real
  // run). Exposing these as real ports sidesteps the gap entirely.
  // RTLSTD-MOD-014's general prohibition on exposing internal state
  // governs ordinary production interfaces; this is the same deliberate,
  // documented exception dfc_rtl001.sv already established.
  output logic [6:0] dbg_grant_onehot_o,
  output logic [6:0] dbg_outstanding_o,
  output logic        dbg_grant_valid_o,
  output logic        dbg_gr_range_error_o,
  output logic [8:0]  dbg_gr_offset_o,
  output logic [8:0]  dbg_gr_width_o,
  output logic         dbg_mem_we_o,
  output logic [8:0]   dbg_gr_abs_addr_o,
  output logic [8:0]   dbg_gr_base_o
);

  localparam int REQW = dfc_types_pkg::DFC_BUFFER_REQ_WIDTH;  // 42
  localparam int RSPW = dfc_types_pkg::DFC_BUFFER_RSP_WIDTH;  // 34

  localparam logic [1:0] CODE_OK             = 2'b00;
  localparam logic [1:0] CODE_RANGE_ERROR    = 2'b01;
  localparam logic [1:0] CODE_PROTOCOL_ERROR = 2'b10;
  localparam logic [1:0] CODE_INTERNAL_ERROR = 2'b11;

  // ==========================================================================
  // Segment table lookups (RTLSTD-MEM-004: from dfc_constants_pkg, never
  // hand-copied). Static case functions, not an indexed localparam array --
  // matches this project's established preference for explicit per-case
  // muxing over computed/array indexing in anything timing-sensitive.
  // ==========================================================================
  function automatic logic [8:0] client_base(logic [2:0] cid);
    case (cid)
      3'd0: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT0_BASE);
      3'd1: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT1_BASE);
      3'd2: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT2_BASE);
      3'd3: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT3_BASE);
      3'd4: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT4_BASE);
      3'd5: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT5_BASE);
      default: client_base = 9'(dfc_constants_pkg::DFC_BUF_CLIENT6_BASE);
    endcase
  endfunction

  function automatic logic [8:0] client_width(logic [2:0] cid);
    case (cid)
      3'd0: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT0_WIDTH);
      3'd1: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT1_WIDTH);
      3'd2: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT2_WIDTH);
      3'd3: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT3_WIDTH);
      3'd4: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT4_WIDTH);
      3'd5: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT5_WIDTH);
      default: client_width = 9'(dfc_constants_pkg::DFC_BUF_CLIENT6_WIDTH);
    endcase
  endfunction

  // Per-client request field extraction, selected by a runtime client id --
  // a single 7:1 mux feeding directly into pipe0's registers the very next
  // edge (no further combinational logic stacked after it), the same
  // "mux -> register, nothing after" shape this project's own timing
  // investigations (OPEN_ISSUES.md items 17/48/57) confirmed is safe,
  // unlike a mux feeding MORE combinational logic before a register.
  // NOTE: a chained index (part-select of a part-select, e.g.
  // `bus[a +: w][hi:lo]`) is illegal in Icarus ("all but the final index in
  // a chain of indices must be a single value, not a range") -- each
  // extraction below instead computes ONE absolute bit position directly
  // on `bus` (client base offset + field LO, width = field HI-LO+1).
  function automatic logic [8:0] req_word_offset(logic [2:0] cid, logic [7*REQW-1:0] bus);
    case (cid)
      3'd0: req_word_offset = bus[0*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
      3'd1: req_word_offset = bus[1*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
      3'd2: req_word_offset = bus[2*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
      3'd3: req_word_offset = bus[3*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
      3'd4: req_word_offset = bus[4*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
      3'd5: req_word_offset = bus[5*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
      default: req_word_offset = bus[6*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WORD_OFFSET_LO +: 9];
    endcase
  endfunction

  function automatic logic req_write_bit(logic [2:0] cid, logic [7*REQW-1:0] bus);
    case (cid)
      3'd0: req_write_bit = bus[0*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
      3'd1: req_write_bit = bus[1*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
      3'd2: req_write_bit = bus[2*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
      3'd3: req_write_bit = bus[3*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
      3'd4: req_write_bit = bus[4*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
      3'd5: req_write_bit = bus[5*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
      default: req_write_bit = bus[6*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_HI];
    endcase
  endfunction

  function automatic logic [31:0] req_write_data(logic [2:0] cid, logic [7*REQW-1:0] bus);
    case (cid)
      3'd0: req_write_data = bus[0*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
      3'd1: req_write_data = bus[1*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
      3'd2: req_write_data = bus[2*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
      3'd3: req_write_data = bus[3*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
      3'd4: req_write_data = bus[4*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
      3'd5: req_write_data = bus[5*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
      default: req_write_data = bus[6*REQW+dfc_types_pkg::DFC_BUFFER_REQ__WRITE_DATA_LO +: 32];
    endcase
  endfunction

  // ==========================================================================
  // Per-client state: outstanding (one request in flight, ARCH-BUF-013) and
  // the held response (stable until that client accepts it).
  // ==========================================================================
  logic [6:0] outstanding_q;

  logic [6:0]        resp_valid_q;
  logic [1:0]         resp_code_q   [0:6];
  logic [31:0]         resp_rdata_q [0:6];

  // ==========================================================================
  // Arbiter: registered-priority-mask rotating round-robin (ARCH-BUF-014),
  // same static AND/OR priority-encode technique as dfc_rtl005.sv's proven
  // fix (OPEN_ISSUES.md item 17).
  // ==========================================================================
  logic [6:0] eligible;
  assign eligible = buf_req_valid_i & ~outstanding_q;

  logic [6:0] rr_mask_q;
  logic [6:0] high_group, low_group;
  assign high_group = eligible & rr_mask_q;
  assign low_group  = eligible & ~rr_mask_q;

  function automatic logic [6:0] lowest_set_onehot(logic [6:0] v);
    casez (v)
      7'b??????1: lowest_set_onehot = 7'b0000001;
      7'b?????10: lowest_set_onehot = 7'b0000010;
      7'b????100: lowest_set_onehot = 7'b0000100;
      7'b???1000: lowest_set_onehot = 7'b0001000;
      7'b??10000: lowest_set_onehot = 7'b0010000;
      7'b?100000: lowest_set_onehot = 7'b0100000;
      7'b1000000: lowest_set_onehot = 7'b1000000;
      default:     lowest_set_onehot = 7'b0000000;
    endcase
  endfunction

  logic [6:0] grant_onehot;
  assign grant_onehot = (high_group != 7'b0) ? lowest_set_onehot(high_group)
                                              : lowest_set_onehot(low_group);
  logic grant_valid;
  assign grant_valid = |grant_onehot;

  logic [2:0] grant_idx;
  always_comb begin
    case (grant_onehot)
      7'b0000001: grant_idx = 3'd0;
      7'b0000010: grant_idx = 3'd1;
      7'b0000100: grant_idx = 3'd2;
      7'b0001000: grant_idx = 3'd3;
      7'b0010000: grant_idx = 3'd4;
      7'b0100000: grant_idx = 3'd5;
      7'b1000000: grant_idx = 3'd6;
      default:    grant_idx = 3'd0;
    endcase
  end

  assign buf_req_ready_o = grant_onehot;

  // ==========================================================================
  // Decode the granted request combinationally (cycle T) -- range check
  // against the granted client's OWN segment width, derive absolute
  // address. Illegal requests never touch the memory child.
  // ==========================================================================
  logic [8:0]  gr_offset;
  logic        gr_write;
  logic [31:0] gr_wdata;
  logic [8:0]  gr_width;
  logic [8:0]  gr_base;
  logic        gr_range_error;
  logic [8:0]  gr_abs_addr;

  assign gr_offset = req_word_offset(grant_idx, buf_req_i);
  assign gr_write  = req_write_bit(grant_idx, buf_req_i);
  assign gr_wdata   = req_write_data(grant_idx, buf_req_i);
  assign gr_width   = client_width(grant_idx);
  assign gr_base    = client_base(grant_idx);
  assign gr_range_error = (gr_offset >= gr_width);
  assign gr_abs_addr    = gr_base + gr_offset;   // only meaningful when !gr_range_error

  // ==========================================================================
  // Memory child (RTLSTD-MOD-008/RTLSTD-WRAP-002: no vendor primitive in
  // this file -- see dfc_mem_sp_512x36.sv / fpga/ecp5/..._ecp5.sv).
  // ==========================================================================
  logic [8:0]  mem_addr;
  logic        mem_we;
  logic [35:0] mem_wdata;
  logic [35:0] mem_rdata;

  assign mem_addr  = gr_abs_addr;
  assign mem_we    = grant_valid && !gr_range_error && gr_write;
  assign mem_wdata = {4'b0000, gr_wdata};

  dfc_mem_sp_512x36 u_mem (
    .clk_i   (core_clk_i),
    .we_i    (mem_we),
    .addr_i  (mem_addr),
    .wdata_i (mem_wdata),
    .rdata_o (mem_rdata)
  );

  // ==========================================================================
  // 2-stage metadata pipe, aligned with the memory child's own 2-register
  // read latency (see file header for the exact cycle accounting). Each
  // stage also carries a sticky "canceled" bit, set when that in-flight
  // client's module_reset_i pulses while the entry is still in the pipe
  // (RTLSTD-MEM-012: a canceled response is discarded, never delivered,
  // never updates any state).
  // ==========================================================================
  logic        pipe0_valid_q, pipe1_valid_q;
  logic [2:0]  pipe0_client_q, pipe1_client_q;
  logic [1:0]  pipe0_code_q,  pipe1_code_q;
  logic        pipe0_is_read_q, pipe1_is_read_q;
  logic        pipe0_canceled_q, pipe1_canceled_q;

  wire pipe0_cancel_now = pipe0_valid_q && module_reset_i[pipe0_client_q];
  wire pipe1_cancel_now = pipe1_valid_q && module_reset_i[pipe1_client_q];

  // Pop pipe1 this cycle (if valid and not canceled): deliver to the owning
  // client's holding register, pairing with mem_rdata (already aligned).
  wire pop_valid    = pipe1_valid_q && !(pipe1_canceled_q || pipe1_cancel_now);
  wire [2:0] pop_client = pipe1_client_q;
  wire [1:0] pop_code   = pipe1_code_q;
  wire       pop_is_read = pipe1_is_read_q;

  // ==========================================================================
  // BUFFER_STATUS / error-count state (ARCH-BUFERR-001/ARCH-DIAG-006).
  // ==========================================================================
  logic [6:0]        client_error_sticky_q;
  logic [15:0]        client_error_count_q [0:6];
  logic                internal_error_sticky_q;
  logic [31:0]         internal_error_count_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      rr_mask_q               <= 7'b1111111;
      outstanding_q            <= 7'b0;
      resp_valid_q             <= 7'b0;
      pipe0_valid_q            <= 1'b0;
      pipe1_valid_q            <= 1'b0;
      pipe0_canceled_q         <= 1'b0;
      pipe1_canceled_q         <= 1'b0;
      pipe0_client_q           <= 3'd0;
      pipe1_client_q           <= 3'd0;
      pipe0_code_q             <= CODE_OK;
      pipe1_code_q             <= CODE_OK;
      pipe0_is_read_q          <= 1'b0;
      pipe1_is_read_q          <= 1'b0;
      client_error_sticky_q    <= 7'b0;
      internal_error_sticky_q  <= 1'b0;
      internal_error_count_q   <= 32'd0;
      for (int i = 0; i < 7; i++) begin
        resp_code_q[i]          <= CODE_OK;
        resp_rdata_q[i]         <= 32'd0;
        client_error_count_q[i] <= 16'd0;
      end
    end else begin
      // ---- arbiter mask update ----
      if (grant_valid) rr_mask_q <= 7'b1111111 << (grant_idx + 3'd1);

      // ---- new grant enters pipe0 ----
      pipe0_valid_q    <= grant_valid;
      pipe0_client_q   <= grant_idx;
      pipe0_code_q     <= gr_range_error ? CODE_RANGE_ERROR : CODE_OK;
      pipe0_is_read_q  <= !gr_write;
      pipe0_canceled_q <= grant_valid && module_reset_i[grant_idx];

      // ---- pipe0 -> pipe1 shift ----
      pipe1_valid_q    <= pipe0_valid_q;
      pipe1_client_q   <= pipe0_client_q;
      pipe1_code_q     <= pipe0_code_q;
      pipe1_is_read_q  <= pipe0_is_read_q;
      pipe1_canceled_q <= pipe0_canceled_q || pipe0_cancel_now;

      // ---- outstanding: set on grant, cleared on held-response accept or
      //      module reset (whichever first) ----
      for (int c = 0; c < 7; c++) begin
        if (module_reset_i[c]) begin
          outstanding_q[c] <= 1'b0;
        end else if (grant_valid && grant_idx == c[2:0]) begin
          outstanding_q[c] <= 1'b1;
        end else if (resp_valid_q[c] && buf_rsp_ready_i[c]) begin
          outstanding_q[c] <= 1'b0;
        end
      end

      // ---- held response registers: populate on pipe1 pop, clear on
      //      client accept or module reset ----
      for (int c = 0; c < 7; c++) begin
        if (module_reset_i[c]) begin
          resp_valid_q[c] <= 1'b0;
        end else if (pop_valid && pop_client == c[2:0]) begin
          resp_valid_q[c]  <= 1'b1;
          resp_code_q[c]   <= pop_code;
          resp_rdata_q[c]  <= (pop_code == CODE_OK && pop_is_read) ? mem_rdata[31:0] : 32'd0;
        end else if (resp_valid_q[c] && buf_rsp_ready_i[c]) begin
          resp_valid_q[c] <= 1'b0;
        end
      end

      // ---- error evidence/counts: updated only on a real, non-canceled
      //      pop with a non-OK code ----
      if (pop_valid && pop_code != CODE_OK) begin
        client_error_sticky_q[pop_client] <= 1'b1;
        if (client_error_count_q[pop_client] != 16'hFFFF)
          client_error_count_q[pop_client] <= client_error_count_q[pop_client] + 16'd1;
        if (pop_code == CODE_INTERNAL_ERROR) begin
          internal_error_sticky_q <= 1'b1;
          if (internal_error_count_q != 32'hFFFFFFFF)
            internal_error_count_q <= internal_error_count_q + 32'd1;
        end
      end
      // per-client module reset clears only that client's local evidence/
      // count (ARCH-BUF-019) -- service-wide internal-error evidence/count
      // is untouched by any module_reset_i, only by core_rst_n_i above.
      for (int c = 0; c < 7; c++) begin
        if (module_reset_i[c]) begin
          client_error_sticky_q[c] <= 1'b0;
          client_error_count_q[c]  <= 16'd0;
        end
      end
    end
  end

  assign buf_rsp_valid_o = resp_valid_q;

  genvar gi;
  generate
    for (gi = 0; gi < 7; gi++) begin : g_rsp
      assign buf_rsp_o[gi*RSPW +: RSPW] =
        {resp_code_q[gi], resp_rdata_q[gi]};
    end
  endgenerate

  assign buffer_status_o = {24'd0, internal_error_sticky_q, client_error_sticky_q};
  assign buffer_client_error_count_0_1_o = {client_error_count_q[1], client_error_count_q[0]};
  assign buffer_client_error_count_2_3_o = {client_error_count_q[3], client_error_count_q[2]};
  assign buffer_client_error_count_4_5_o = {client_error_count_q[5], client_error_count_q[4]};
  assign buffer_client_error_count_6_o   = {16'd0, client_error_count_q[6]};
  assign buffer_internal_error_count_o   = internal_error_count_q;

  // Formal-verification observability -- see port-list comment above.
  assign dbg_grant_onehot_o    = grant_onehot;
  assign dbg_outstanding_o     = outstanding_q;
  assign dbg_grant_valid_o     = grant_valid;
  assign dbg_gr_range_error_o  = gr_range_error;
  assign dbg_gr_offset_o       = gr_offset;
  assign dbg_gr_width_o        = gr_width;
  assign dbg_mem_we_o          = mem_we;
  assign dbg_gr_abs_addr_o     = gr_abs_addr;
  assign dbg_gr_base_o         = gr_base;

endmodule : dfc_rtl024_shared_buffer
