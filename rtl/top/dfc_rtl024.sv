// dfc_rtl024.sv -- RTL-024 Dragon Core Top-Level Integration: SKELETON.
//
// Controlling documents: docs/rtl_specs/RTL-024_RevC.md, RCA-DFC-ARCH-002
// SS5-7, 12, 14 and Appendix A/C/D. Per RTLSTD-MOD-011, RTL-024 must
// instantiate RTL-001 through RTL-023 exactly once. As of this file, only
// RTL-001 (dfc_rtl001.sv) exists in this repository; RTL-002 through
// RTL-024's other 22 children do not. This is therefore explicitly a
// SKELETON, not a full implementation:
//
//   - External ports (33, ARCH-002 Appendix A "RTL-024") are REAL.
//   - core_rst_n generation from por_n_i is REAL (ARCH-RST-001: async
//     assert, synchronized release after 4 valid CORE_CLK edges).
//   - RTL-001 instantiation is REAL (dfc_rtl001.sv, first HIL target).
//   - SPI-to-DRI bridge (dfc_rtl024_spi_bridge.sv) is REAL and verified
//     end-to-end (see verification/testbench/rtl-024/spi_bridge_tb.sv):
//     RTL-001 is now reachable from the physical spi_* pins, not just via
//     direct DRI-port access in simulation.
//   - RTL-002 through RTL-023 are LABELED STUBS -- see STUB blocks below.
//     Each stub ties its RTL-001-facing control input to a safe default
//     and its status/ready/fault output to a fixed "not ready, no fault"
//     value. This is NOT real behavior; it exists only so this file
//     elaborates and RTL-001 can be exercised on real ECP5 hardware before
//     its sibling modules are written. Do not treat a stub's fixed output
//     as evidence of anything about the real module's behavior.
//   - RTL-024's OWN derivation contract (ARCH-RTL024-001: ready requires
//     reset/host mailboxes/DRI/shared buffer/test controller initialized;
//     fault from host timeout/internal/shared-buffer/clock-reset-
//     integration error) is NOT implemented -- there is no shared buffer,
//     host mailbox, or test controller yet to aggregate.
//   - SPI-to-DRI bridge (ARCH-SPI-*, RTLSTD-SPI-*) is real and verified;
//     see dfc_rtl024_spi_bridge.sv for its own disclosed scope/limitations
//     (per-field validation, abort-evidence bookkeeping, and a documented
//     response-timing characteristic around early-rejection cases).
//
// This is intentional, disclosed scope for a first ECP5 HIL bring-up
// skeleton -- not a shortcut taken silently. Log anything this reveals as
// a genuine spec gap in OPEN_ISSUES.md.

module dfc_rtl024 (
  input  logic core_clk_i,
  input  logic por_n_i,

  input  logic spi_sclk_i,
  input  logic spi_cs_n_i,
  input  logic spi_mosi_i,
  output logic spi_miso_o,
  output logic spi_miso_oe_o,

  output logic host_irq_n_o,

  input  logic [7:0] gpio_i,
  output logic [7:0] gpio_o,
  output logic [7:0] gpio_oe_o,

  input  logic arinc_rx_i,
  output logic [1:0] arinc_tx_ctrl_o,
  input  logic arinc_rx_adapter_error_i,
  input  logic arinc_tx_adapter_error_i,

  input  logic can_rx_i,
  output logic can_tx_o,
  input  logic can_transceiver_error_i,

  input  logic uart_rx_i,
  output logic uart_tx_o,

  input  logic rotor_i,
  input  logic engine_i,
  input  logic [1:0] pulse_i,
  input  logic [7:0] health_i,

  output logic [3:0] safety_out_o,

  input  logic [3:0] user_i,
  output logic [3:0] user_o,
  output logic [3:0] user_oe_o,

  input  logic test_enable_i,
  input  logic test_clock_i,
  input  logic test_data_i,
  output logic test_data_o,
  output logic test_data_oe_o
);

  // ==========================================================================
  // Clock/reset generation (ARCH-CONN-001, ARCH-RST-001) -- REAL, not a stub.
  // core_clk_i is the platform clock root (nominal 50 MHz, ARCH-CLK-001).
  // core_rst_n is derived here: asynchronous assert from por_n_i,
  // synchronized release after >=4 valid CORE_CLK edges (ARCH-RST-001,
  // RDC-001).
  // ==========================================================================
  logic [3:0] rst_sync_q;
  logic core_rst_n;

  always_ff @(posedge core_clk_i or negedge por_n_i) begin
    if (!por_n_i) rst_sync_q <= 4'b0000;
    else          rst_sync_q <= {rst_sync_q[2:0], 1'b1};
  end
  assign core_rst_n = rst_sync_q[3];  // released only after 4 valid edges

  // ==========================================================================
  // SPI-to-DRI bridge: REAL, verified implementation (dfc_rtl024_spi_bridge.sv
  // -- see its own file header for exact scope/disclosed gaps). Replaces the
  // tie-inactive placeholder this skeleton originally shipped with.
  // ==========================================================================
  logic        dri_req_valid;
  logic        dri_req_ready;
  logic        dri_req_write;
  logic [31:0] dri_req_addr;
  logic [31:0] dri_req_wdata;
  logic [3:0]  dri_req_wstrb;
  logic        dri_rsp_valid;
  logic        dri_rsp_ready;
  logic [31:0] dri_rsp_rdata;
  logic [2:0]  dri_rsp_code;

  dfc_rtl024_spi_bridge u_spi_bridge (
    .core_clk_i      (core_clk_i),
    .core_rst_n_i    (core_rst_n),
    .spi_sclk_i      (spi_sclk_i),
    .spi_cs_n_i      (spi_cs_n_i),
    .spi_mosi_i      (spi_mosi_i),
    .spi_miso_o      (spi_miso_o),
    .spi_miso_oe_o   (spi_miso_oe_o),
    .dri_req_valid_o (dri_req_valid),
    .dri_req_ready_i (dri_req_ready),
    .dri_req_write_o (dri_req_write),
    .dri_req_addr_o  (dri_req_addr),
    .dri_req_wdata_o (dri_req_wdata),
    .dri_req_wstrb_o (dri_req_wstrb),
    .dri_rsp_valid_i (dri_rsp_valid),
    .dri_rsp_ready_o (dri_rsp_ready),
    .dri_rsp_rdata_i (dri_rsp_rdata),
    .dri_rsp_code_i  (dri_rsp_code)
  );

  // ==========================================================================
  // RTL-001: REAL instantiation, the first HIL bring-up target.
  // ==========================================================================
  dfc_rtl001 u_rtl001 (
    .core_clk_i      (core_clk_i),
    .core_rst_n_i    (core_rst_n),
    .dri_req_valid_i (dri_req_valid),
    .dri_req_ready_o (dri_req_ready),
    .dri_req_write_i (dri_req_write),
    .dri_req_addr_i  (dri_req_addr),
    .dri_req_wdata_i (dri_req_wdata),
    .dri_req_wstrb_i (dri_req_wstrb),
    .dri_rsp_valid_o (dri_rsp_valid),
    .dri_rsp_ready_i (dri_rsp_ready),
    .dri_rsp_rdata_o (dri_rsp_rdata),
    .dri_rsp_code_o  (dri_rsp_code)
  );

  // ==========================================================================
  // STUB BLOCK -- RTL-002 through RTL-023 do not exist yet in this
  // repository. Each entry below is a labeled placeholder: it consumes no
  // real signal from RTL-001 (module control/status wiring per ARCH-CONN-003
  // is not connected) and produces no real behavior. This block exists so
  // this file elaborates for ECP5 synthesis and simulation; it is NOT a
  // model of any child module's behavior. Replace each stub with a real
  // instantiation as that module is implemented -- do not extend the stub
  // pattern into real logic.
  //
  // Modules stubbed (per RTLSTD-MOD-011, all must eventually be
  // instantiated exactly once): RTL-002 through RTL-023.
  // ==========================================================================

  // Aggregate host_irq_n_o: per ARCH-002 Appendix A, high in reset or with
  // no enabled pending source. With no interrupt-controller (RTL-003) or
  // any source module instantiated yet, there is no real pending source --
  // this correctly stays high, but only because nothing exists to assert
  // it, not because interrupt logic has been verified inactive.
  assign host_irq_n_o = 1'b1;

  // GPIO (RTL-006 not instantiated): outputs safe-zero per Appendix A
  // ("Zero in reset/disable/test").
  assign gpio_o    = 8'h00;
  assign gpio_oe_o = 8'h00;

  // ARINC TX (RTL-018 not instantiated): idle per Appendix A.
  assign arinc_tx_ctrl_o = 2'b00;

  // CAN TX (RTL-019 not instantiated): recessive high per Appendix A.
  assign can_tx_o = 1'b1;

  // UART TX (RTL-020 not instantiated): idle high per Appendix A.
  assign uart_tx_o = 1'b1;

  // Safety outputs (RTL-016 not instantiated): inactive under every
  // ARCH-SAFE inhibit -- with no safety-response module instantiated,
  // there is no real safety decision being made; this is a hard-tied
  // inactive state, not a verified inhibited state.
  assign safety_out_o = 4'b0000;

  // User I/O (RTL-023/RTL-001 user routing not instantiated): Revision A
  // constant zero on output/OE, per Appendix A.
  assign user_o    = 4'h0;
  assign user_oe_o = 4'h0;

  // Production test (test controller not instantiated): TEST_DATA high
  // impedance, matching "ignored unless authorized" -- there is no
  // authorization state machine yet, so this is unconditionally disabled,
  // which is safe but not the real behavior once RTL-024's test controller
  // exists.
  assign test_data_o    = 1'b0;
  assign test_data_oe_o = 1'b0;

  // Unused inputs from not-yet-instantiated consumers: explicitly
  // referenced in a null sink to avoid "unused port" warnings without
  // pretending they are consumed (RTLSTD-MOD-009: unused ports must be
  // deterministically tied or intentionally consumed -- this is the
  // "intentionally consumed as a placeholder" case, disclosed, not silent).
  logic unused_stub_sink;
  assign unused_stub_sink = spi_sclk_i ^ spi_cs_n_i ^ spi_mosi_i ^
                            gpio_i[0] ^ arinc_rx_i ^ arinc_rx_adapter_error_i ^
                            arinc_tx_adapter_error_i ^ can_rx_i ^
                            can_transceiver_error_i ^ uart_rx_i ^ rotor_i ^
                            engine_i ^ pulse_i[0] ^ health_i[0] ^ user_i[0] ^
                            test_enable_i ^ test_clock_i ^ test_data_i;

endmodule : dfc_rtl024
