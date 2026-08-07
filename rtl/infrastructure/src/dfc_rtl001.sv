// dfc_rtl001.sv -- RTL-001 Configuration Register Bank: DRI controller +
// generated storage layer. Hand-authored (not generated); implements
// ARCH-002 SS7.1-7.2 and REG-002's validation order on top of the
// mechanically-generated rtl001_regbank_regs (tools/reggen/reggen.py).
//
// Controlling documents: docs/rtl_specs/RTL-001_RevB.md, RCA-DFC-ARCH-002
// SS7, RCA-DFC-REG-002 SS2/SS4/SS5.
//
// ============================================================================
// SCOPE OF THIS FIRST IMPLEMENTATION -- read before trusting this for
// anything beyond first HIL bring-up on the ECP5 validation platform
// (CHTR-002 SS5.2):
//
// IMPLEMENTED:
//   - DRI request/response protocol: one-outstanding, valid/ready, request/
//     response field stability (ARCH-DRI-001/006), response within 8 cycles
//     (ARCH-DRI-009 -- trivially met, response is same-or-next-cycle here).
//   - Validation order per ARCH-REG-001: alignment, decode, access class,
//     full-word write-strobe check (REG-GEN-002), protection state.
//   - Write commits only in the same cycle as its OK response
//     (ARCH-REG-002, RTLSTD-DRI-012).
//   - PROTECT_KEY two-key authorization sequence, 50,000-cycle timeout,
//     consumed by exactly one protected write (REG-002 SS4).
//
// NOT YET IMPLEMENTED -- real, disclosed gaps, not silent no-ops:
//   - Reserved-bit masking and per-field legal-value/range/encoding checks
//     (REG-ENC-001 through 019). A write with reserved bits set or an
//     out-of-range field value is currently ACCEPTED if the register as a
//     whole is writable. This is the single biggest conformance gap.
//   - BUSY/ENDPOINT_ERROR: no downstream module exists yet to be busy or to
//     fail at the endpoint, so those response codes are never produced.
//   - Staging/commit atomic objects (multi-register commit semantics).
//   - Authorization clearing on CRC failure / pre-acceptance abort / post-
///    acceptance response truncation -- those events originate in the SPI
//     bridge, which does not exist yet in this repository.
//   - Per-field masking within mixed registers for write_illegal_o (this
//     module inherits regbank's whole-register-only access-class check).
//   - All 142 status_i inputs are tied to zero below (see TIE-OFF section)
//     because RTL-002 through RTL-024 do not exist yet. This is a bring-up
//     placeholder, not real behavior, and must be removed once those
//     modules exist.
//
// Log anything this reveals as a genuine spec gap -- not a coding mistake
// -- in OPEN_ISSUES.md per CLAUDE.md's working rules.
// ============================================================================

module dfc_rtl001 (
  input  logic         core_clk_i,
  input  logic         core_rst_n_i,

  input  logic         dri_req_valid_i,
  output logic         dri_req_ready_o,
  input  logic         dri_req_write_i,
  input  logic [31:0]  dri_req_addr_i,
  input  logic [31:0]  dri_req_wdata_i,
  input  logic [3:0]   dri_req_wstrb_i,

  output logic         dri_rsp_valid_o,
  input  logic         dri_rsp_ready_i,
  output logic [31:0]  dri_rsp_rdata_o,
  output logic [2:0]   dri_rsp_code_o
);

  import dfc_constants_pkg::*;
  import dfc_registers_pkg::*;

  // ---- DRI response codes (ARCH-DRI-008) ----
  localparam logic [2:0] RSP_OK              = 3'b000;
  localparam logic [2:0] RSP_DECODE_ERROR    = 3'b001;
  localparam logic [2:0] RSP_ACCESS_ERROR    = 3'b010;
  localparam logic [2:0] RSP_PROTECTED_ERROR = 3'b011;
  // ENDPOINT_ERROR (100), TIMEOUT (101), BUSY (110) are not produced by
  // this first implementation -- see SCOPE note above.

  // ---- FSM ----
  typedef enum logic [1:0] { S_IDLE, S_RESPOND } state_e;
  state_e state_q, state_d;

  logic [31:0] req_addr_q, req_wdata_q;
  logic        req_write_q;
  logic [2:0]  rsp_code_q;

  // one-outstanding (ARCH-002 SS7.1): only accept in S_IDLE
  assign dri_req_ready_o = (state_q == S_IDLE);
  wire   req_accept = dri_req_valid_i && dri_req_ready_o;

  // ---- regbank instance: addr_i muxed by FSM state (see file header) ----
  logic [31:0] regbank_addr;
  logic [31:0] regbank_rdata;
  logic        regbank_decode_hit, regbank_write_illegal, regbank_protected;
  logic        regbank_write_en;

  assign regbank_addr = (state_q == S_IDLE) ? dri_req_addr_i : req_addr_q;

  // ---- protection / authorization (REG-002 SS4) ----
  typedef enum logic [1:0] { P_IDLE, P_KEY1_SEEN, P_ARMED } prot_state_e;
  prot_state_e prot_state_q, prot_state_d;
  logic [31:0] prot_timeout_q;
  wire         key1_write = req_accept && dri_req_write_i &&
                            (dri_req_addr_i == DFC_ADDR_PROTECT_KEY) &&
                            (dri_req_wdata_i == DFC_PROTECT_KEY1);
  wire         key2_write = req_accept && dri_req_write_i &&
                            (dri_req_addr_i == DFC_ADDR_PROTECT_KEY) &&
                            (dri_req_wdata_i == DFC_PROTECT_KEY2);
  wire         protect_key_write = req_accept && dri_req_write_i &&
                            (dri_req_addr_i == DFC_ADDR_PROTECT_KEY);
  wire         authorized = (prot_state_q == P_ARMED);

  always_comb begin
    prot_state_d = prot_state_q;
    unique case (prot_state_q)
      P_IDLE:      if (key1_write) prot_state_d = P_KEY1_SEEN;
      P_KEY1_SEEN: begin
        if (key2_write) prot_state_d = P_ARMED;
        else if (protect_key_write) prot_state_d = P_IDLE;  // bad second key
      end
      P_ARMED: begin
        // consumed by exactly one accepted protected write, or by timeout
        if (protect_key_write) prot_state_d = P_IDLE;  // re-keying clears arm
        else if (req_accept && dri_req_write_i && regbank_protected &&
                 regbank_decode_hit && !regbank_write_illegal &&
                 (dri_req_wstrb_i == 4'b1111))
          prot_state_d = P_IDLE;  // consumed this cycle
        else if (prot_timeout_q == 32'd0)
          prot_state_d = P_IDLE;  // timeout
      end
      default: prot_state_d = P_IDLE;
    endcase
  end

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      prot_state_q   <= P_IDLE;
      prot_timeout_q <= '0;
    end else begin
      prot_state_q <= prot_state_d;
      if (prot_state_d == P_ARMED && prot_state_q != P_ARMED)
        prot_timeout_q <= DFC_PROTECT_TIMEOUT_CYCLES[31:0];
      else if (prot_state_q == P_ARMED && prot_timeout_q != 32'd0)
        prot_timeout_q <= prot_timeout_q - 32'd1;
    end
  end

  // ---- validation (ARCH-REG-001 order: alignment, decode, access class, ----
  // ---- write-strobe/full-word, protection) computed in S_IDLE for the ----
  // ---- incoming request ----
  logic [2:0] validate_code;
  always_comb begin
    if (dri_req_addr_i[1:0] != 2'b00)
      validate_code = RSP_ACCESS_ERROR;  // REG-GEN-001: 4-byte aligned;
                                          // REG-GEN-009 expects the SPI/DRI
                                          // bridge to reject unaligned before
                                          // DRI, but RTL-001 checks defensively
    else if (!regbank_decode_hit)
      validate_code = RSP_DECODE_ERROR;  // REG-GEN-009
    else if (dri_req_write_i && regbank_write_illegal)
      validate_code = RSP_ACCESS_ERROR;
    else if (dri_req_write_i && dri_req_wstrb_i != 4'b1111)
      validate_code = RSP_ACCESS_ERROR;  // REG-GEN-002: full-word writes only
    else if (dri_req_write_i && regbank_protected && !authorized)
      validate_code = RSP_PROTECTED_ERROR;
    else
      validate_code = RSP_OK;
  end

  // ---- FSM sequencing ----
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      S_IDLE:    if (req_accept) state_d = S_RESPOND;
      S_RESPOND: if (dri_rsp_valid_o && dri_rsp_ready_i) state_d = S_IDLE;
      default:   state_d = S_IDLE;
    endcase
  end

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      state_q     <= S_IDLE;
      req_addr_q  <= '0;
      req_wdata_q <= '0;
      req_write_q <= 1'b0;
      rsp_code_q  <= RSP_OK;
    end else begin
      state_q <= state_d;
      if (req_accept) begin
        req_addr_q  <= dri_req_addr_i;
        req_wdata_q <= dri_req_wdata_i;
        req_write_q <= dri_req_write_i;
        rsp_code_q  <= validate_code;
      end
    end
  end

  // ---- response + same-cycle write commit (ARCH-REG-002/RTLSTD-DRI-012) ----
  assign dri_rsp_valid_o  = (state_q == S_RESPOND);
  assign dri_rsp_code_o   = rsp_code_q;
  assign dri_rsp_rdata_o  = req_write_q ? 32'h0 : regbank_rdata;
  assign regbank_write_en = (state_q == S_RESPOND) && req_write_q &&
                            (rsp_code_q == RSP_OK);

  rtl001_regbank_regs regbank (
    .clk_i           (core_clk_i),
    .rst_ni          (core_rst_n_i),
    .addr_i          (regbank_addr),
    .wdata_i         (req_wdata_q),
    .write_en_i      (regbank_write_en),
    .rdata_o         (regbank_rdata),
    .decode_hit_o    (regbank_decode_hit),
    .write_illegal_o (regbank_write_illegal),
    .protected_o     (regbank_protected),

    // ------------------------------------------------------------------
    // TIE-OFF: every external status_i input is zero because RTL-002
    // through RTL-024 do not exist yet in this repository. This is a
    // bring-up placeholder for first HIL test on the ECP5 -- remove and
    // wire to the real producer modules as each one is implemented.
    // ------------------------------------------------------------------
    .sys_status_status_i('0), .subsys_ready_status_i('0), .subsys_fault_status_i('0),
    .reset_status_status_i('0), .protect_status_status_i('0),
    .rtl002_evt_overflow_status_status_i('0), .irq_raw_status_status_i('0),
    .irq_pending_status_i('0), .irq_acked_status_i('0), .irq_clear_status_i('0),
    .irq_vector_status_i('0), .rtl003_evt_overflow_status_status_i('0),
    .time_status_status_i('0), .time_raw_lo_status_i('0), .time_raw_hi_status_i('0),
    .time_sync_status_status_i('0), .rtl004_evt_overflow_status_status_i('0),
    .evt_status_status_i('0), .evt_count_status_i('0), .evt_overflow_count_status_i('0),
    .evt_data0_status_i('0), .evt_data1_status_i('0), .evt_data2_status_i('0),
    .evt_data3_status_i('0), .evt_drop_source_status_i('0), .evt_arb_status_status_i('0),
    .gpio_raw_in_status_i('0), .gpio_sync_in_status_i('0), .gpio_qual_in_status_i('0),
    .gpio_event_status_status_i('0), .rtl006_evt_overflow_status_status_i('0),
    .host_status_status_i('0), .host_last_result_status_i('0), .host_last_address_status_i('0),
    .host_completed_count_status_i('0), .host_crc_error_count_status_i('0),
    .host_abort_count_status_i('0), .host_timeout_count_status_i('0),
    .host_access_error_count_status_i('0), .rtl024_evt_overflow_status_status_i('0),
    .buffer_status_status_i('0), .host_last_sequence_status_i('0), .test_status_status_i('0),
    .arx_status_status_i('0), .arx_queue_level_status_i('0), .arx_data_status_i('0),
    .arx_meta_status_i('0), .arx_time_lo_status_i('0), .arx_time_hi_status_i('0),
    .arx_error_count_status_i('0), .arx_overflow_count_status_i('0),
    .rtl017_evt_overflow_status_status_i('0), .atx_status_status_i('0),
    .atx_queue_level_status_i('0), .atx_error_count_status_i('0), .atx_underrun_count_status_i('0),
    .rtl018_evt_overflow_status_status_i('0), .can_status_status_i('0), .can_error_count_status_i('0),
    .can_rx_level_status_i('0), .can_rx_id_status_i('0), .can_rx_meta_status_i('0),
    .can_rx_data_lo_status_i('0), .can_rx_data_hi_status_i('0), .can_rx_time_lo_status_i('0),
    .can_rx_time_hi_status_i('0), .can_tx_level_status_i('0), .rtl019_evt_overflow_status_status_i('0),
    .uart_status_status_i('0), .uart_rx_level_status_i('0), .uart_rx_data_status_i('0),
    .uart_tx_level_status_i('0), .uart_error_count_status_i('0), .rtl020_evt_overflow_status_status_i('0),
    .route_status_status_i('0), .route_active_source_status_i('0), .route_active_dest_status_i('0),
    .route_active_type_mask_status_i('0), .route_active_filter_value_status_i('0),
    .route_active_filter_mask_status_i('0), .route_entry_status_status_i('0),
    .rtl021_evt_overflow_status_status_i('0), .rotor_status_status_i('0), .rotor_rpm_status_i('0),
    .rotor_period_ticks_status_i('0), .rtl007_evt_overflow_status_status_i('0),
    .engine_status_status_i('0), .engine_rpm_status_i('0), .engine_period_ticks_status_i('0),
    .rtl008_evt_overflow_status_status_i('0), .pulse0_status_status_i('0),
    .pulse0_freq_q17_15_status_i('0), .pulse0_period_ticks_status_i('0),
    .pulse1_status_status_i('0), .pulse1_freq_q17_15_status_i('0), .pulse1_period_ticks_status_i('0),
    .rtl009_evt_overflow_status_status_i('0), .sensor_status_status_i('0), .sensor0_value_status_i('0),
    .sensor0_status_status_i('0), .sensor0_current_age_ms_status_i('0), .sensor1_value_status_i('0),
    .sensor1_status_status_i('0), .sensor1_current_age_ms_status_i('0),
    .rtl010_evt_overflow_status_status_i('0), .sensor0_meta_status_i('0), .sensor1_meta_status_i('0),
    .health_raw_in_status_i('0), .health_sync_in_status_i('0), .health_qual_in_status_i('0),
    .health_active_status_i('0), .health_sticky_status_i('0), .rtl011_evt_overflow_status_status_i('0),
    .wdog_status_status_i('0), .wdog_elapsed_us_status_i('0), .rtl012_evt_overflow_status_status_i('0),
    .fault_status_status_i('0), .fault_class_status_i('0), .degraded_status_status_i('0),
    .fault_active_source_status_i('0), .fault_latched_source_status_i('0),
    .rtl013_evt_overflow_status_status_i('0), .ilock_status_status_i('0), .ilock_active_result_status_i('0),
    .rtl014_evt_overflow_status_status_i('0), .llink_status_status_i('0), .llink_elapsed_us_status_i('0),
    .rtl015_evt_overflow_status_status_i('0), .safety_status_status_i('0),
    .safety_channel_status_status_i('0), .rtl016_evt_overflow_status_status_i('0),
    .uli_status_status_i('0), .uli_in_level_status_i('0), .uli_out_level_status_i('0),
    .uli_out_data_status_i('0), .uli_io_input_status_i('0), .rtl022_evt_overflow_status_status_i('0),
    .uroute_status_status_i('0), .uroute_active_source_status_i('0), .uroute_active_dest_status_i('0),
    .uroute_entry_status_status_i('0), .rtl023_evt_overflow_status_status_i('0)
  );

endmodule : dfc_rtl001
