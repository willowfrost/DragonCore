// dfc_rtl024.sv -- RTL-024 Dragon Core Top-Level Integration: SKELETON.
//
// Controlling documents: docs/rtl_specs/RTL-024_RevC.md, RCA-DFC-ARCH-002
// SS5-7, 12, 14 and Appendix A/C/D. Per RTLSTD-MOD-011, RTL-024 must
// instantiate RTL-001 through RTL-023 exactly once. As of this file,
// RTL-001 (dfc_rtl001.sv), RTL-002 (dfc_rtl002.sv), RTL-003
// (dfc_rtl003.sv), and RTL-004 (dfc_rtl004.sv) exist in this repository;
// RTL-005 through RTL-023 do not. This is therefore explicitly a SKELETON,
// not a full implementation:
//
//   - External ports (33, ARCH-002 Appendix A "RTL-024") are REAL.
//   - core_rst_n generation from por_n_i is REAL (ARCH-RST-001: async
//     assert, synchronized release after 4 valid CORE_CLK edges).
//   - RTL-001 instantiation is REAL (dfc_rtl001.sv, first HIL target).
//   - RTL-002 instantiation is REAL (dfc_rtl002.sv, system control logic --
//     see that file's own header for its disclosed scope, most notably:
//     TEST_DEBUG is unreachable pending a real test-active source, event
//     generation is not yet implemented, and module_reset_o[0] has no real
//     consumer because dfc_rtl001.sv has no module_reset_i port).
//     module_ready_i[23:0]/module_fault_i[23:0] are wired from every
//     module's real or stub status.ready/.fault bit (see per-module wiring
//     below); module_reset_o[23:0] fans out to every real module's
//     module_reset_i (stubs have no such port to receive it, since they
//     are not real modules).
//   - RTL-003 instantiation is REAL (dfc_rtl003.sv, interrupt controller):
//     RTL-002's real irq_req_o now genuinely aggregates through RTL-003's
//     real RAW/LATCH/PENDING/ACKED equations into the real, external
//     host_irq_n_o pad -- closing the previously-disclosed RTL-002<->
//     RTL-024 interrupt gap (see that file's own header for its disclosed
//     scope, most notably the ARCH-002-vs-RTL-003_RevA.md port-name
//     conflict and the still-stubbed producer/condition-mask inputs).
//   - SPI-to-DRI bridge (dfc_rtl024_spi_bridge.sv) is REAL and verified
//     end-to-end (see verification/testbench/rtl-024/spi_bridge_tb.sv):
//     RTL-001 is now reachable from the physical spi_* pins, not just via
//     direct DRI-port access in simulation.
//   - RTL-004 instantiation is REAL (dfc_rtl004.sv, Timestamp Engine): the
//     real always-running raw microsecond timestamp now genuinely
//     broadcasts to RTL-001/RTL-002/RTL-003 (previously hard-tied to
//     64'h0 with an explicit "RTL-004 does not exist yet" comment) -- see
//     that file's own header for its full disclosed scope, most notably
//     three real ARCH-002 struct-growth fixes made before this module was
//     implemented and the resolved-without-an-edit self-referencing
//     `timestamp_i` port-catalog discrepancy.
//   - RTL-005 instantiation is REAL (dfc_rtl005.sv, Event Logger): RTL-005
//     is simultaneously the arbiter/store for all 24 producers' diagnostic
//     events AND its own 25th conceptual producer (self-looped through
//     evt_valid_i[4]/evt_ready_o[4]/evt_record_i[4] -- see that file's own
//     header for the full account). RTL-002/003/004's own evt_valid_o/
//     evt_ready_i/evt_record_o (previously genuinely unconsumed, tied to
//     `()`/1'b1/`()`) now genuinely reach RTL-005's real evt_valid_i[1:3]/
//     evt_ready_o[1:3]/evt_record_i[1:3]; RTL-002's real
//     global_event_enable_o now genuinely reaches RTL-005's real
//     global_event_enable_i.
//   - RTL-006 (GPIO Controller) instantiation is REAL (dfc_rtl006.sv):
//     gpio_i/gpio_o/gpio_oe_o now genuinely reach the real external pads
//     (previously hard-tied), RTL-006's own irq_req_o now genuinely
//     reaches RTL-003's real irq_source_i[2], and its own evt_valid_o/
//     evt_record_o now genuinely reach RTL-005's real evt_valid_i[5]/
//     evt_record_i[5] -- see that file's own header for its full
//     disclosed scope, most notably the ARCH-002 struct-growth fix, the
//     RTL006_EVT_OVERFLOW_STATUS readback gap closed for RTL-006 from the
//     start (not backported to RTL-002/003/004's own identical,
//     newly-found gap), and the real dfc_rtl002.sv port-conformance fix
//     (`module_enable_o`/`effective_operational_enable_o`) this module's
//     own integration required.
//   - RTL-007 (Rotor RPM Monitor) instantiation is REAL (dfc_rtl007.sv):
//     the first Monitoring-domain module. `rotor_i` now genuinely reaches
//     the real external pad (previously hard-tied `1'b0`) -- see the real
//     LOCATE COMP/IOBUF addition in fpga/ecp5/ulx3s_dfc.lpf and
//     ULX3S_CONNECTION_MAP.md's own new Section 6 for the physical pin
//     assignment (`gp27`/J2-27, the last remaining single-ended-only
//     position -- exhausted by this module). RTL-007's own `irq_req_o`
//     now genuinely reaches RTL-003's real `irq_source_i[8]`, and its
//     `evt_valid_o`/`evt_record_o` now genuinely reach RTL-005's real
//     `evt_valid_i[6]`/`evt_record_i[6]`. `fault_req_o` is a real output
//     with no real consumer yet (its architected destination,
//     RTL-013.fault_source_i[6], does not exist) -- left genuinely
//     unconsumed below, same disclosed pattern as RTL-005's own
//     `fault_req_o`. See that file's own header for its full disclosed
//     scope, most notably the ARCH-002 struct-growth fix (the sixth real
//     instance of the EVENT_OVERFLOW-clear-field gap class) and the
//     bit-serial RPM divider design (avoiding the timing-closure failure
//     class already found and fixed for RTL-005's round-robin arbiter,
//     OPEN_ISSUES.md item 17).
//   - RTL-008 (Engine RPM Monitor) instantiation is REAL (dfc_rtl008.sv):
//     functionally identical to RTL-007 (same ARCH-MON-002/003/005
//     algorithm), applied to a completely independent edge input/register
//     block/state per ARCH-RTL008-001. `engine_i` now genuinely reaches the
//     real external pad (previously hard-tied 1'b0) -- the first module
//     assigned from the differential-capable pin range (gp8/J1-8), the
//     single-ended-only range having been fully exhausted by RTL-007 --
//     see the real LOCATE COMP/IOBUF addition in fpga/ecp5/ulx3s_dfc.lpf
//     and ULX3S_CONNECTION_MAP.md's own new Section 7. RTL-008's own
//     `irq_req_o` now genuinely reaches RTL-003's real `irq_source_i[9]`,
//     and its `evt_valid_o`/`evt_record_o` now genuinely reach RTL-005's
//     real `evt_valid_i[7]`/`evt_record_i[7]`. `fault_req_o` is a real
//     output with no real consumer yet (RTL-013 does not exist), left
//     genuinely unconsumed below. See that file's own header for its full
//     disclosed scope, most notably the ARCH-002 struct-growth fix (the
//     seventh real instance of the EVENT_OVERFLOW-clear-field gap class)
//     and the engine-specific ARCH-VAL-008 illegal-configuration range
//     (0-20000, not RTL-007's 0-1000).
//   - RTL-009 (Pulse/Frequency Measurement) instantiation is REAL
//     (dfc_rtl009.sv): the third Monitoring-domain module, and the first
//     with TWO independent measurement channels sharing one physical port.
//     `pulse_i[1:0]` now genuinely reaches the real external pads
//     (previously hard-tied via the unused-signal sink for bit 0, and never
//     referenced at all for bit 1) -- see the real LOCATE COMP/IOBUF
//     addition in fpga/ecp5/ulx3s_dfc.lpf and ULX3S_CONNECTION_MAP.md's own
//     new Section 8 for the physical pin assignment (`gp9`/J1-9 and
//     `gp10`/J1-10, the next two positions in the differential-capable
//     range after RTL-008's `gp8`). RTL-009's own `irq_req_o` now genuinely
//     reaches RTL-003's real `irq_source_i[10]`, and its `evt_valid_o`/
//     `evt_record_o` now genuinely reach RTL-005's real `evt_valid_i[8]`/
//     `evt_record_i[8]` -- both channels' own diagnostic events share this
//     one slot (RTL-009 has a single evt_valid_o/evt_record_o triple per
//     the Architecture port catalog, not one pair per channel).
//     `fault_req_o` is a real output with no real consumer yet (its
//     architected destination, RTL-013.fault_source_i[8], does not exist)
//     -- left genuinely unconsumed below, same disclosed pattern as
//     RTL-005/007/008's own `fault_req_o`. See that file's own header for
//     its full disclosed scope, most notably the ARCH-002 struct-growth
//     fix (the eighth real instance of the EVENT_OVERFLOW-clear-field gap
//     class), the pipelined-multiply divider architecture applied from the
//     start (per OPEN_ISSUES.md item 31's own warning about RTL-007/008's
//     combined timing margin), and the disclosed shared-slot event
//     arbitration between the two channels.
//   - RTL-010 (Sensor Monitor Interface) instantiation is REAL
//     (dfc_rtl010.sv): the fourth Monitoring-domain module, and the first
//     with NO physical pin at all -- confirmed against ARCH-002's own
//     16-port catalog before writing that file; sensor values arrive
//     exclusively through host writes to the staged SENSOR_UPDATE_SELECT/
//     _VALUE/_META/_COMMIT registers. RTL-010's own `irq_req_o` now
//     genuinely reaches RTL-003's real `irq_source_i[11]`, and its
//     `evt_valid_o`/`evt_record_o` now genuinely reach RTL-005's real
//     `evt_valid_i[9]`/`evt_record_i[9]` -- both channels' own diagnostic
//     events, plus the module-wide accepted/rejected commit events, share
//     this one slot. `fault_req_o` is a real output with no real consumer
//     yet (its architected destination, RTL-013.fault_source_i[9], does
//     not exist) -- left genuinely unconsumed below, same disclosed
//     pattern as every other not-yet-connected `fault_req_o` in this
//     integration. See that file's own header for its full disclosed
//     scope, most notably the ARCH-002 struct-growth fix (the ninth real
//     instance of the EVENT_OVERFLOW-clear-field gap class), the
//     resolved-in-favor-of-ARCH-002 Appendix F.3 discrepancy, and the real,
//     disclosed gap that RTL-021 (Databus Routing Engine) has no port on
//     RTL-010 yet for the "routed commit" half of ARCH-MON-007.
//   - RTL-011 (System Health Monitor) instantiation is REAL (dfc_rtl011.sv):
//     the fifth Monitoring-domain module, and the first module to consume
//     the entire remaining unshared differential-capable pin range in one
//     go (8 channels, gp14-gp21/J2-14 through J2-21) -- see the real
//     LOCATE COMP/IOBUF addition in fpga/ecp5/ulx3s_dfc.lpf and
//     ULX3S_CONNECTION_MAP.md's own new Section 9. RTL-011's own
//     `irq_req_o` now genuinely reaches RTL-003's real `irq_source_i[12]`,
//     and its `evt_valid_o`/`evt_record_o` now genuinely reach RTL-005's
//     real `evt_valid_i[10]`/`evt_record_i[10]`. `fault_req_o` is a real
//     output with no real consumer yet (RTL-013 does not exist), left
//     genuinely unconsumed below. See that file's own header for its full
//     disclosed scope, most notably the ARCH-002 struct-growth fix (the
//     tenth real instance of the EVENT_OVERFLOW-clear-field gap class),
//     the resolved-in-favor-of-REG-002 13-vs-15-register discrepancy, and
//     the disclosed "recovery, not deasserted" F.3/C.7 subtype-selection
//     interpretation. This completes the Monitoring domain (RTL-007
//     through RTL-011) -- Safety (RTL-012) is next.
//   - RTL-012 through RTL-023 are LABELED STUBS -- see STUB block below.
//     Each stub's own status/ready/fault contribution to RTL-002's
//     module_ready_i/module_fault_i fan-in is a fixed "not ready, no
//     fault" value. This is NOT real behavior; it exists only so this
//     file elaborates and RTL-001 through RTL-008 can be exercised on
//     real ECP5 hardware before their sibling modules are written. Do
//     not treat a stub's fixed output as evidence of anything about the
//     real module's behavior. NOTE: because RTL-002 requires every
//     SUBSYS_ENABLE mandatory-mask module to report ready before leaving
//     STARTUP, and several mandatory bits (0x80F81F) still belong to
//     not-yet-real modules (e.g. RTL-012 through RTL-016), this skeleton's
//     RTL-002 instance will run to its 499,000-cycle mandatory-init
//     timeout and enter FAULTED every time, not NORMAL -- that is the
//     real, disclosed consequence of the stub topology, not a bug in
//     RTL-002 itself. It will read NORMAL/DEGRADED correctly only once
//     enough mandatory-mask modules are real.
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
  // Declared here, immediately before first use -- moved up from their
  // previous location near the RTL-002 instantiation after a real,
  // confirmed elaboration failure on the person's actual Icarus toolchain
  // ("Net rtl002_control is not defined in this context... declared here
  // ... check for declaration after use"). My own sandbox's Icarus
  // tolerated the old ordering (module-item order is generally
  // unconstrained in standard SystemVerilog), but the person's real
  // toolchain enforces declaration-before-use for named port connections
  // specifically -- rather than rely on that difference, this is simply
  // reordered correctly, which is unambiguously legal on every toolchain.
  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0] rtl002_control;
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]  rtl002_status;
  logic [dfc_types_pkg::DFC_RTL001_STATUS_WIDTH-1:0]  rtl001_status;
  logic [dfc_types_pkg::DFC_RTL003_CONTROL_WIDTH-1:0] rtl003_control;
  logic [dfc_types_pkg::DFC_RTL003_STATUS_WIDTH-1:0]  rtl003_status;
  logic [dfc_types_pkg::DFC_RTL004_CONTROL_WIDTH-1:0] rtl004_control;
  logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0]  rtl004_status;
  logic [dfc_types_pkg::DFC_RTL005_CONTROL_WIDTH-1:0] rtl005_control;
  logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0]  rtl005_status;
  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] rtl006_control;
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  rtl006_status;
  logic [dfc_types_pkg::DFC_RTL007_CONTROL_WIDTH-1:0] rtl007_control;
  logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0]  rtl007_status;
  logic [dfc_types_pkg::DFC_RTL008_CONTROL_WIDTH-1:0] rtl008_control;
  logic [dfc_types_pkg::DFC_RTL008_STATUS_WIDTH-1:0]  rtl008_status;
  logic [dfc_types_pkg::DFC_RTL009_CONTROL_WIDTH-1:0] rtl009_control;
  logic [dfc_types_pkg::DFC_RTL009_STATUS_WIDTH-1:0]  rtl009_status;
  logic [dfc_types_pkg::DFC_RTL010_CONTROL_WIDTH-1:0] rtl010_control;
  logic [dfc_types_pkg::DFC_RTL010_STATUS_WIDTH-1:0]  rtl010_status;
  logic [dfc_types_pkg::DFC_RTL011_CONTROL_WIDTH-1:0] rtl011_control;
  logic [dfc_types_pkg::DFC_RTL011_STATUS_WIDTH-1:0]  rtl011_status;
  // Real RTL-004 timestamp broadcast -- declared here, before u_rtl002's own
  // use of it below, per this file's own established declaration-before-use
  // discipline (see the comment block just above this one). Driven by
  // u_rtl004's real timestamp_o further down this file; the signal only
  // needs to be DECLARED before first use, not yet driven.
  logic [63:0] rtl004_timestamp;
  logic        rtl002_global_event_enable;
  // Real RTL-002 module_enable_o[23:0]/effective_operational_enable_o --
  // added this session, closing the real gap dfc_rtl006.sv's own header
  // documents (RTL-002 previously had neither port). Declared here, before
  // u_rtl002's own instantiation below.
  logic [23:0]  rtl002_module_enable;
  logic         rtl002_effective_operational_enable;
  logic         rtl006_irq_req;
  logic         rtl007_irq_req;
  logic         rtl008_irq_req;
  logic         rtl009_irq_req;
  logic         rtl010_irq_req;
  logic         rtl011_irq_req;

  // ==========================================================================
  // RTL-005 (Event Logger) event-bus wiring -- declared here, before any of
  // RTL-002/003/004's own instantiations below reference their real
  // evt_valid_o/evt_ready_i/evt_record_o (previously genuinely unconsumed,
  // tied to `()`/1'b1/`()` with an explicit "no RTL-005 exists yet"
  // comment -- see u_rtl005's own instantiation further down for how this
  // gap closes for real). evt_record_i is a flat 3072-bit vector (24 x
  // 128-bit dfc_event_record_t) -- same TOOLCHAIN-DRIVEN DEVIATION as every
  // other package-scoped-type port in this project.
  // ==========================================================================
  logic         rtl002_evt_valid, rtl002_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl002_evt_record;
  logic         rtl003_evt_valid, rtl003_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl003_evt_record;
  logic         rtl004_evt_valid, rtl004_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl004_evt_record;
  logic         rtl005_evt_valid, rtl005_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl005_evt_record;
  logic         rtl005_irq_req;
  logic [23:0]  rtl005_evt_valid_i, rtl005_evt_ready_o;
  logic [24*dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl005_evt_record_i;
  logic         rtl006_evt_valid, rtl006_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl006_evt_record;
  logic         rtl007_evt_valid, rtl007_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl007_evt_record;
  logic         rtl008_evt_valid, rtl008_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl008_evt_record;
  logic         rtl009_evt_valid, rtl009_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl009_evt_record;
  logic         rtl010_evt_valid, rtl010_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl010_evt_record;
  logic         rtl011_evt_valid, rtl011_evt_ready;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] rtl011_evt_record;

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
    .dri_rsp_code_o  (dri_rsp_code),
    // REAL cross-module register bus to RTL-002 -- replaces the prior
    // disconnected placeholder entirely (see RTL-002 instantiation notes
    // below). Generated by reggen.py v4 from
    // tools/reggen/rtl002_field_map.json.
    .rtl002_control_o (rtl002_control),
    .rtl002_status_i  (rtl002_status),
    // REAL cross-module register bus to RTL-003 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl003_field_map.json.
    .rtl003_control_o (rtl003_control),
    .rtl003_status_i  (rtl003_status),
    // REAL cross-module register bus to RTL-004 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl004_field_map.json.
    .rtl004_control_o (rtl004_control),
    .rtl004_status_i  (rtl004_status),
    // REAL cross-module register bus to RTL-005 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl005_field_map.json.
    .rtl005_control_o (rtl005_control),
    .rtl005_status_i  (rtl005_status),
    // REAL cross-module register bus to RTL-006 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl006_field_map.json.
    .rtl006_control_o (rtl006_control),
    .rtl006_status_i  (rtl006_status),
    // REAL cross-module register bus to RTL-007 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl007_field_map.json.
    .rtl007_control_o (rtl007_control),
    .rtl007_status_i  (rtl007_status),
    // REAL cross-module register bus to RTL-008 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl008_field_map.json.
    .rtl008_control_o (rtl008_control),
    .rtl008_status_i  (rtl008_status),
    // REAL cross-module register bus to RTL-009 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl009_field_map.json.
    .rtl009_control_o (rtl009_control),
    .rtl009_status_i  (rtl009_status),
    // REAL cross-module register bus to RTL-010 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl010_field_map.json.
    .rtl010_control_o (rtl010_control),
    .rtl010_status_i  (rtl010_status),
    // REAL cross-module register bus to RTL-011 -- same treatment,
    // generated by reggen.py v4 from tools/reggen/rtl011_field_map.json.
    .rtl011_control_o (rtl011_control),
    .rtl011_status_i  (rtl011_status),
    // RTL-001's own real status_o -- closes the previously-disclosed gap
    // where module_ready_i[0]/module_fault_i[0] were tied to a permanent
    // placeholder regardless of RTL-001's real condition.
    .status_o         (rtl001_status)
  );

  // ==========================================================================
  // RTL-002: REAL instantiation (dfc_rtl002.sv). See that file's own header
  // for its full disclosed scope.
  //
  // REAL, CLOSED THIS SESSION: SYS_CONTROL/SUBSYS_ENABLE/RESET_CONTROL now
  // reach RTL-002 for real via RTL-001's `rtl002_control_o` (generated by
  // reggen.py v3 from tools/reggen/rtl002_field_map.json), and RTL-002's
  // real SYS_STATUS/SUBSYS_READY/SUBSYS_FAULT/RESET_STATUS/
  // RESET_DIAGNOSTIC status reaches the host via RTL-001's
  // `rtl002_status_i`. This replaces what was previously a disconnected
  // static placeholder -- a host write to these registers now genuinely
  // changes RTL-002's behavior, and RTL-002's real internal state is now
  // genuinely host-readable. See `rtl002_field_map.json`'s own `_source`
  // note for exactly which fields this covers and which extraction step
  // (per-field bit tables for all 353 registers, not just these 8) is
  // still real, disclosed future work rather than solved generically.
  //
  // STILL DISCLOSED, NOT YET CLOSED:
  //   1. `dfc_rtl001.sv` still has no `status_o`-equivalent (ready/fault)
  //      port of its OWN -- `module_ready_i[0]`/`module_fault_i[0]` below
  //      are still tied to a disclosed placeholder (not-ready, no-fault),
  //      unrelated to the SYS_CONTROL/SYS_STATUS bus this session closed.
  //   2. RTL-002's own `status_o.ready`/`.fault` would normally reach
  //      `module_ready_i[1]`/`module_fault_i[1]` via RTL-001's port catalog
  //      (RTL-002_RevA.md SS1: "via its own status_o.ready/.fault looped
  //      back through RTL-001's ownership of the port catalog"). Since
  //      that specific path doesn't exist either, this integration loops
  //      RTL-002's status_o directly back to its own module_ready_i[1]/
  //      module_fault_i[1] -- functionally equivalent for this skeleton,
  //      but bypassing the RTL-001-mediated path the Architecture
  //      specifies.
  //
  // operating_state_o/observational_mode_o are real outputs with no real
  // consumer yet (no other real module has an operating_state_i/
  // observational_mode_i port) -- referenced only in the unused-signal sink
  // below. irq_req_o now has a REAL consumer: RTL-003.irq_source_i[0] (see
  // RTL-003 instantiation below), closing the real, previously-disclosed
  // RTL-002<->RTL-024 interrupt-aggregation gap.
  // ==========================================================================
  logic [23:0] module_ready;
  logic [23:0] module_fault;
  logic [23:0] module_reset;
  // Same TOOLCHAIN-DRIVEN DEVIATION as dfc_rtl002.sv (see that file's
  // header) -- dfc_types_pkg::some_type_t cannot be a declared type on the
  // person's real production Yosys build, so these three internal signals
  // are plain flat vectors, sized via the generated `dfc_types_pkg::
  // DFC_*_WIDTH` VALUE constants (pkggen.py now emits one per struct/enum)
  // rather than a hardcoded width literal.
  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] rtl002_operating_state;
  logic        rtl002_observational_mode;
  logic        rtl002_irq_req;
  logic        rtl002_global_irq_enable;   // real RTL-002 port, closes
                                            // OPEN_ISSUES.md item 5 -- see
                                            // u_rtl003's global_irq_enable_i
                                            // connection below.
  // rtl002_status/rtl001_status/rtl002_control are now declared earlier,
  // immediately before dfc_rtl001's instantiation -- see that block's own
  // comment for why.

  dfc_rtl002 u_rtl002 (
    .core_clk_i           (core_clk_i),
    .core_rst_n_i         (core_rst_n),
    .module_reset_i       (module_reset[1]),
    .control_i            (rtl002_control),
    .status_o             (rtl002_status),
    .timestamp_i          (rtl004_timestamp),  // real RTL-004 broadcast
    // REAL as of RTL-005's own integration: RTL-002's own event output now
    // genuinely reaches RTL-005's real evt_valid_i[1]/evt_ready_o[1]/
    // evt_record_i[1] below -- closes the previously-disclosed "no RTL-005
    // exists yet" gap.
    .evt_valid_o          (rtl002_evt_valid),
    .evt_ready_i          (rtl002_evt_ready),
    .evt_record_o         (rtl002_evt_record),
    .irq_req_o            (rtl002_irq_req),
    .module_ready_i       (module_ready),
    .module_fault_i       (module_fault),
    .module_reset_o       (module_reset),
    .operating_state_o    (rtl002_operating_state),
    .observational_mode_o (rtl002_observational_mode),
    // Real port per the Architecture catalog (RTL-024.test_active_o ->
    // RTL-002.test_active_i), tied to a disclosed stub here since RTL-024
    // has no real production-test infrastructure yet to drive it for
    // real -- see dfc_rtl002.sv's own port header note.
    .test_active_i        (1'b0),
    // Real ports, added this session, closing OPEN_ISSUES.md item 5.
    // global_irq_enable_o now feeds u_rtl003's global_irq_enable_i below
    // directly, replacing the prior rtl002_control-read workaround.
    // global_event_enable_o now genuinely reaches RTL-005's real
    // global_event_enable_i below -- closes the previously-disclosed "no
    // RTL-005 exists yet" gap. event_condition_enable_i/
    // irq_condition_enable_i are real ports tied to a disclosed stub
    // (64'h0): RTL-001 does not yet implement the per-module
    // CONDITION_MASK storage/forwarding mechanism (Appendix F.3) these
    // would come from (OPEN_ISSUES.md item 6).
    .global_irq_enable_o       (rtl002_global_irq_enable),
    .global_event_enable_o     (rtl002_global_event_enable),
    .event_condition_enable_i  (64'h0),
    .irq_condition_enable_i    (64'h0),
    // Real ports, added this session -- see dfc_rtl002.sv's own port
    // declaration header note. module_enable_o[5]/effective_operational_
    // enable_o now genuinely reach RTL-006's real module_enable_i/
    // effective_operational_enable_i below.
    .module_enable_o                (rtl002_module_enable),
    .effective_operational_enable_o (rtl002_effective_operational_enable)
  );

  // ==========================================================================
  // RTL-003: REAL instantiation (dfc_rtl003.sv), closing the real, confirmed
  // RTL-002<->RTL-024 interrupt-aggregation gap (previously: `host_irq_n_o`
  // hard-tied 1'b1, RTL-002's real `irq_req_o` sunk into the dummy
  // unused_stub_sink XOR chain). See that file's own header for its full
  // disclosed scope, most notably the ARCH-002-vs-RTL-003_RevA.md port-name
  // conflict (this module's real aggregate output is `aggregate_pending_o`,
  // not `host_irq_n_o` -- RTL-024 performs the final active-low inversion
  // onto the real external pad below).
  //
  // irq_source_i[31:0] per ARCH-002 Appendix C.4: bit 0 (System Control) is
  // REAL, RTL-002.irq_req_o. Bits 1-20/22-23 (Event Logger through
  // Production Test) have no real producer yet (RTL-004 through RTL-023 do
  // not exist); bit 21 (Configuration Error, RTL-001) also has no real
  // producer -- dfc_rtl001.sv has no irq_req_o port of its own yet. Bits
  // 24-31 are the Architecture's own reserved/constant-zero positions. All
  // disclosed stub-zero, per RTL-003_RevA.md SS6's own acknowledged
  // dependency gap -- not something this integration can close until each
  // producer module is real.
  //
  // global_irq_enable_i: RTL-002 now has a real, dedicated
  // global_irq_enable_o port (added this session, closing OPEN_ISSUES.md
  // item 5) -- connected directly below via `rtl002_global_irq_enable`,
  // replacing the prior workaround that read `rtl002_control` directly.
  //
  // event_condition_enable_i/irq_condition_enable_i: real ports per the
  // Architecture catalog, tied to a disclosed stub (64'h0) here since
  // RTL-001 does not yet implement the per-module CONDITION_MASK storage/
  // forwarding mechanism (Appendix F.3) these would come from -- a separate,
  // much larger, not-yet-scheduled piece of infrastructure spanning all 24
  // modules, out of scope for RTL-003's own integration. This means
  // RTL-003's own diagnostic event (0x0008) can never fire in this
  // integration yet (event_condition_enable_i[0] is permanently 0) -- a
  // real, disclosed consequence, not a defect in dfc_rtl003.sv itself.
  // ==========================================================================
  logic [31:0] rtl003_irq_source;
  logic        rtl003_aggregate_pending;

  // Bit 12 (System Health) is now REAL: RTL-011's own irq_req_o, per
  // ARCH-002's own port catalog (RTL-003.irq_source_i[12]). Bit 11
  // (Sensor Monitor) is RTL-010's real irq_req_o. Bit 10 (Pulse/Frequency)
  // is RTL-009's real irq_req_o. Bit 9 (Engine RPM) is RTL-008's real
  // irq_req_o. Bit 8 (Rotor RPM) is RTL-007's real irq_req_o. Bit 2 (GPIO)
  // is RTL-006's real irq_req_o. Bit 1 (Event Logger) is RTL-005's real
  // irq_req_o. Bit 0 (System Control) is RTL-002's real irq_req_o, as
  // before. Bits 7:3 (Timestamp through Watchdog Manager) have no real
  // producer yet.
  assign rtl003_irq_source = {19'h0, rtl011_irq_req, rtl010_irq_req, rtl009_irq_req, rtl008_irq_req, rtl007_irq_req, 5'h0, rtl006_irq_req, rtl005_irq_req, rtl002_irq_req};

  dfc_rtl003 u_rtl003 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[2]),
    .control_i                (rtl003_control),
    .status_o                 (rtl003_status),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    // REAL as of RTL-005's own integration -- see u_rtl002's identical note
    // above.
    .evt_valid_o              (rtl003_evt_valid),
    .evt_ready_i              (rtl003_evt_ready),
    .evt_record_o             (rtl003_evt_record),
    .irq_source_i             (rtl003_irq_source),
    .aggregate_pending_o      (rtl003_aggregate_pending),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .global_irq_enable_i      (rtl002_global_irq_enable),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-004: REAL instantiation (dfc_rtl004.sv, Timestamp Engine). See that
  // file's own header for its full disclosed scope (three real ARCH-002
  // struct-growth fixes made and approved before this module was
  // implemented, plus the resolved-without-an-edit self-referencing
  // `timestamp_i` port-catalog discrepancy).
  //
  // timestamp_o now genuinely reaches RTL-001/RTL-002/RTL-003 (see
  // `rtl004_timestamp`, declared earlier in this file and wired into
  // u_rtl001/u_rtl002/u_rtl003's own `timestamp_i` ports above) -- this
  // closes the real, previously-disclosed gap where those three modules'
  // timestamp_i was hard-tied to 64'h0 with an explicit "RTL-004 does not
  // exist yet" comment.
  //
  // evt_valid_o/evt_record_o: no RTL-005 exists yet to accept RTL-004's
  // real events -- output genuinely unconsumed, same disclosed-gap pattern
  // as RTL-002/RTL-003's own event outputs above, not a stub on RTL-004's
  // own side. event_condition_enable_i/irq_condition_enable_i: real ports
  // tied to a disclosed stub (64'h0), same reasoning as RTL-002/RTL-003
  // above (OPEN_ISSUES.md item 6).
  // ==========================================================================
  dfc_rtl004 u_rtl004 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[3]),
    .control_i                (rtl004_control),
    .status_o                 (rtl004_status),
    // REAL as of RTL-005's own integration -- see u_rtl002's identical note
    // above.
    .evt_valid_o              (rtl004_evt_valid),
    .evt_ready_i              (rtl004_evt_ready),
    .evt_record_o             (rtl004_evt_record),
    .timestamp_o              (rtl004_timestamp),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-005: REAL instantiation (dfc_rtl005.sv, Event Logger). See that
  // file's own header for its full disclosed scope (one real ARCH-002
  // struct-growth fix made and approved before this module was
  // implemented, plus the resolved-without-an-edit 14-vs-15-register
  // discrepancy).
  //
  // THE REAL, CONFIRMED EVENT-BUS GAP IS CLOSED: RTL-002/003/004's own
  // evt_valid_o/evt_ready_i/evt_record_o (previously tied to `()`/1'b1/`()`
  // with an explicit "no RTL-005 exists yet" comment) now genuinely reach
  // RTL-005's real evt_valid_i[1]/[2]/[3], evt_ready_o[1]/[2]/[3], and
  // evt_record_i[1]/[2]/[3]. RTL-002's real global_event_enable_o now
  // genuinely reaches RTL-005's real global_event_enable_i (previously
  // tied to `()`).
  //
  // evt_valid_i[23:0] per ARCH-002's fixed index i <-> RTL-(i+1) allocation:
  //   [0]  RTL-001  -- disclosed stub-zero: dfc_rtl001.sv has no evt_valid_o
  //        port of its own yet (RTL-001's own event generation is not
  //        implemented -- a pre-existing, disclosed gap, same class as its
  //        incomplete `fault` signal).
  //   [1]  RTL-002  -- REAL (rtl002_evt_valid/rtl002_evt_ready/rtl002_evt_record).
  //   [2]  RTL-003  -- REAL.
  //   [3]  RTL-004  -- REAL.
  //   [4]  RTL-005  -- REAL, the self-loop ARCH-002's own port catalog
  //        specifies (RTL-005.evt_valid_o -> RTL-005.evt_valid_i[4] -- see
  //        dfc_rtl005.sv's own header for why this is a genuine design, not
  //        a table-generation artifact like RTL-004's timestamp_i case).
  //   [5]  RTL-006  -- REAL.
  //   [6]  RTL-007  -- REAL (Rotor RPM Monitor).
  //   [7]  RTL-008  -- REAL (Engine RPM Monitor).
  //   [8]  RTL-009  -- REAL (Pulse/Frequency Measurement -- both channels'
  //        own diagnostic events share this one slot).
  //   [9]  RTL-010  -- REAL (Sensor Monitor Interface -- both channels'
  //        own diagnostic events, plus the module-wide accepted/rejected
  //        commit events, share this one slot).
  //   [10] RTL-011  -- REAL, this session (System Health Monitor).
  //   [11..22]/[23] RTL-012 through RTL-023/RTL-024 -- disclosed stub-zero;
  //        none of these modules (or RTL-024's own event generation, which
  //        does not exist) are real yet.
  //
  // irq_req_o now genuinely reaches RTL-003's real irq_source_i[1] (see
  // rtl003_irq_source above). fault_req_o has no real consumer yet (its
  // architected destination, RTL-013.fault_source_i[5], does not exist) --
  // genuinely unconsumed, same disclosed-gap pattern as every other
  // not-yet-connected inter-module port in this integration, left
  // unconnected below rather than stubbed.
  // ==========================================================================
  assign rtl005_evt_valid_i = {1'b0,                    // [23] RTL-024 (no self-event)
                               12'h0,                    // [22:11] RTL-012..023 (not real)
                               rtl011_evt_valid,          // [10] RTL-011 (real, this session)
                               rtl010_evt_valid,          // [9] RTL-010
                               rtl009_evt_valid,          // [8] RTL-009
                               rtl008_evt_valid,          // [7] RTL-008
                               rtl007_evt_valid,          // [6] RTL-007
                               rtl006_evt_valid,          // [5] RTL-006
                               rtl005_evt_valid,          // [4] RTL-005 self-loop
                               rtl004_evt_valid,          // [3] RTL-004
                               rtl003_evt_valid,          // [2] RTL-003
                               rtl002_evt_valid,          // [1] RTL-002
                               1'b0};                     // [0] RTL-001 (no evt_valid_o yet)
  assign rtl002_evt_ready = rtl005_evt_ready_o[1];
  assign rtl003_evt_ready = rtl005_evt_ready_o[2];
  assign rtl004_evt_ready = rtl005_evt_ready_o[3];
  assign rtl005_evt_ready = rtl005_evt_ready_o[4];
  assign rtl006_evt_ready = rtl005_evt_ready_o[5];
  assign rtl007_evt_ready = rtl005_evt_ready_o[6];
  assign rtl008_evt_ready = rtl005_evt_ready_o[7];
  assign rtl009_evt_ready = rtl005_evt_ready_o[8];
  assign rtl010_evt_ready = rtl005_evt_ready_o[9];
  assign rtl011_evt_ready = rtl005_evt_ready_o[10];
  assign rtl005_evt_record_i =
    {1536'h0,             // [23:11] RTL-012..023 (12 x 128 zero -- not real)
     rtl011_evt_record,   // [10] RTL-011 (real, this session)
     rtl010_evt_record,   // [9] RTL-010
     rtl009_evt_record,   // [8] RTL-009
     rtl008_evt_record,   // [7] RTL-008
     rtl007_evt_record,   // [6] RTL-007
     rtl006_evt_record,   // [5] RTL-006
     rtl005_evt_record,   // [4]
     rtl004_evt_record,   // [3]
     rtl003_evt_record,   // [2]
     rtl002_evt_record,   // [1]
     128'h0};             // [0] RTL-001 (no evt_record_o yet)

  dfc_rtl005 u_rtl005 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[4]),
    .control_i                (rtl005_control),
    .status_o                 (rtl005_status),
    .evt_valid_o              (rtl005_evt_valid),
    .evt_ready_i              (rtl005_evt_ready),
    .evt_record_o             (rtl005_evt_record),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    .irq_req_o                (rtl005_irq_req),
    .fault_req_o              (),  // no real consumer yet -- RTL-013 does not exist
    .evt_valid_i              (rtl005_evt_valid_i),
    .evt_ready_o              (rtl005_evt_ready_o),
    .evt_record_i             (rtl005_evt_record_i),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .global_event_enable_i    (rtl002_global_event_enable),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-006: REAL instantiation (dfc_rtl006.sv, GPIO Controller). See that
  // file's own header for its full disclosed scope (the ARCH-002 struct
  // growth fix, the RTL006_EVT_OVERFLOW_STATUS readback gap closed for
  // RTL-006 from the start, and the real dfc_rtl002.sv port-conformance fix
  // this module's own integration required).
  //
  // gpio_i/gpio_o/gpio_oe_o now genuinely reach the real, external pads
  // (previously hard-tied: gpio_o/gpio_oe_o forced to 8'h00, gpio_i sunk
  // into the unused-signal sink) -- see the real LOCATE COMP/IOBUF
  // additions in fpga/ecp5/ulx3s_dfc.lpf and ULX3S_CONNECTION_MAP.md's own
  // new GPIO section for the physical pin assignment.
  //
  // route_gpio_req_i: real port per the Architecture catalog, tied to a
  // disclosed stub (8'h0) -- RTL-022/023 are permanently out of scope for
  // this build (PROJECT_CONTINUITY.md Section 5), not a "not yet built"
  // gap, so this stub will never become real.
  // ==========================================================================
  dfc_rtl006 u_rtl006 (
    .core_clk_i                      (core_clk_i),
    .core_rst_n_i                    (core_rst_n),
    .module_reset_i                  (module_reset[5]),
    .control_i                       (rtl006_control),
    .status_o                        (rtl006_status),
    .timestamp_i                     (rtl004_timestamp),  // real RTL-004 broadcast
    .evt_valid_o                     (rtl006_evt_valid),
    .evt_ready_i                     (rtl006_evt_ready),
    .evt_record_o                    (rtl006_evt_record),
    .irq_req_o                       (rtl006_irq_req),
    .gpio_i                          (gpio_i),
    .gpio_o                          (gpio_o),
    .gpio_oe_o                       (gpio_oe_o),
    .operating_state_i               (rtl002_operating_state),
    .observational_mode_i            (rtl002_observational_mode),
    .route_gpio_req_i                (8'h0),  // RTL-023 permanently out of scope
    .module_enable_i                 (rtl002_module_enable[5]),
    .effective_operational_enable_i  (rtl002_effective_operational_enable),
    .event_condition_enable_i        (64'h0),
    .irq_condition_enable_i          (64'h0)
  );

  // ==========================================================================
  // RTL-007: REAL instantiation (dfc_rtl007.sv, Rotor RPM Monitor). The
  // first Monitoring-domain module. See that file's own header for its full
  // disclosed scope (the ARCH-002 struct-growth fix, the RTL007_EVT_OVERFLOW_
  // STATUS readback gap closed from the start, and the bit-serial RPM
  // divider design).
  //
  // rotor_i now genuinely reaches the real external pad (previously
  // hard-tied 1'b0 -- see the real LOCATE COMP/IOBUF addition in
  // fpga/ecp5/ulx3s_dfc.lpf and ULX3S_CONNECTION_MAP.md's own new Section 6
  // for the physical pin assignment). Unlike RTL-006, RTL-007's own real
  // ARCH-002 port catalog has no `effective_operational_enable_i` port at
  // all (confirmed against the real 17-port catalog) -- only
  // `module_enable_i` (RTL-002.module_enable_o[6]).
  // ==========================================================================
  dfc_rtl007 u_rtl007 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[6]),
    .control_i                (rtl007_control),
    .status_o                 (rtl007_status),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    .evt_valid_o              (rtl007_evt_valid),
    .evt_ready_i              (rtl007_evt_ready),
    .evt_record_o             (rtl007_evt_record),
    .irq_req_o                (rtl007_irq_req),
    .fault_req_o              (),  // no real consumer yet -- RTL-013 does not exist
    .rotor_i                  (rotor_i),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .module_enable_i          (rtl002_module_enable[6]),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-008: REAL instantiation (dfc_rtl008.sv, Engine RPM Monitor). Same
  // ARCH-MON-002/003/005 algorithm as RTL-007, completely independent
  // state, per ARCH-RTL008-001. See that file's own header for its full
  // disclosed scope (the ARCH-002 struct-growth fix, the
  // RTL008_EVT_OVERFLOW_STATUS readback gap closed from the start, and the
  // engine-range-specific illegal-configuration bound).
  //
  // engine_i now genuinely reaches the real external pad (previously
  // hard-tied 1'b0 -- see the real LOCATE COMP/IOBUF addition in
  // fpga/ecp5/ulx3s_dfc.lpf and ULX3S_CONNECTION_MAP.md's own new Section 7
  // for the physical pin assignment). This is the first module assigned
  // from the differential-capable pin range (J1-8/gp8), the single-ended-
  // only range having been fully exhausted by RTL-007. Same port shape as
  // RTL-007 -- only `module_enable_i` (RTL-002.module_enable_o[7]), no
  // `effective_operational_enable_i`.
  // ==========================================================================
  dfc_rtl008 u_rtl008 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[7]),
    .control_i                (rtl008_control),
    .status_o                 (rtl008_status),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    .evt_valid_o              (rtl008_evt_valid),
    .evt_ready_i              (rtl008_evt_ready),
    .evt_record_o             (rtl008_evt_record),
    .irq_req_o                (rtl008_irq_req),
    .fault_req_o              (),  // no real consumer yet -- RTL-013 does not exist
    .engine_i                 (engine_i),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .module_enable_i          (rtl002_module_enable[7]),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-009: REAL instantiation (dfc_rtl009.sv, Pulse/Frequency
  // Measurement). Two independent Q17.15 frequency channels sharing one
  // physical port, per ARCH-RTL009-001. See that file's own header for its
  // full disclosed scope (the ARCH-002 struct-growth fix, the
  // RTL009_EVT_OVERFLOW_STATUS readback gap closed from the start, the
  // pipelined-multiply divider design applied from the start per
  // OPEN_ISSUES.md item 31's own warning, and the disclosed shared-slot
  // event arbitration between the two channels).
  //
  // pulse_i[1:0] now genuinely reaches the real external pads (previously
  // hard-tied/unreferenced -- see the real LOCATE COMP/IOBUF addition in
  // fpga/ecp5/ulx3s_dfc.lpf and ULX3S_CONNECTION_MAP.md's own new Section 8
  // for the physical pin assignment, gp9/J1-9 and gp10/J1-10). Same port
  // shape as RTL-007/008 -- only `module_enable_i` (RTL-002.
  // module_enable_o[8]), no `effective_operational_enable_i`.
  // ==========================================================================
  dfc_rtl009 u_rtl009 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[8]),
    .control_i                (rtl009_control),
    .status_o                 (rtl009_status),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    .evt_valid_o              (rtl009_evt_valid),
    .evt_ready_i              (rtl009_evt_ready),
    .evt_record_o             (rtl009_evt_record),
    .irq_req_o                (rtl009_irq_req),
    .fault_req_o              (),  // no real consumer yet -- RTL-013 does not exist
    .pulse_i                  (pulse_i),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .module_enable_i          (rtl002_module_enable[8]),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-010: REAL instantiation (dfc_rtl010.sv, Sensor Monitor Interface).
  // Two independent signed sampled-sensor channels updated exclusively via
  // host writes (SENSOR_UPDATE_SELECT/_VALUE/_META/_COMMIT), per
  // ARCH-RTL010-001. See that file's own header for its full disclosed
  // scope: the ARCH-002 struct-growth fix, the RTL010_EVT_OVERFLOW_STATUS
  // (plus every other external RTL-010 register's) readback gap closed
  // from the start, the resolved-in-favor-of-ARCH-002 Appendix F.3
  // discrepancy against RTL-010_RevA.md's own restated summary, and the
  // disclosed real gap that RTL-021 (Databus Routing Engine) has no real
  // port on RTL-010 yet for the "routed commit" half of ARCH-MON-007.
  //
  // NO PHYSICAL PIN: confirmed directly against ARCH-002's own 16-port
  // catalog before writing dfc_rtl010.sv -- this module has no external
  // sensor input pad at all, unlike RTL-007/008/009. No fpga/ecp5/
  // ulx3s_dfc.lpf or ULX3S_CONNECTION_MAP.md change was needed or made for
  // this module. Same port shape as RTL-007/008/009 otherwise -- only
  // `module_enable_i` (RTL-002.module_enable_o[9]), no
  // `effective_operational_enable_i`.
  // ==========================================================================
  dfc_rtl010 u_rtl010 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[9]),
    .control_i                (rtl010_control),
    .status_o                 (rtl010_status),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    .evt_valid_o              (rtl010_evt_valid),
    .evt_ready_i              (rtl010_evt_ready),
    .evt_record_o             (rtl010_evt_record),
    .irq_req_o                (rtl010_irq_req),
    .fault_req_o              (),  // no real consumer yet -- RTL-013 does not exist
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .module_enable_i          (rtl002_module_enable[9]),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // ==========================================================================
  // RTL-011: REAL instantiation (dfc_rtl011.sv, System Health Monitor). The
  // fifth Monitoring-domain module -- 8 independent synchronized/qualified/
  // polarity-adjusted health-discrete channels, per ARCH-MON-008/
  // ARCH-RTL011-001. See that file's own header for its full disclosed
  // scope: the confirmed architectural parallel to RTL-006's own
  // synchronizer/qualification-timer skeleton (not RTL-007-010's divider
  // architecture), the ARCH-002 struct-growth fix (the tenth real instance
  // of the EVENT_OVERFLOW-clear-field gap class), the resolved-in-favor-
  // of-REG-002 13-vs-15-register discrepancy against RTL-011_RevA.md's own
  // restated summary, and the disclosed "recovery, not deasserted" F.3/C.7
  // subtype-selection interpretation.
  //
  // health_i[7:0] now genuinely reaches the real external pads (previously
  // hard-tied 8'h00) -- see the real LOCATE COMP/IOBUF addition in
  // fpga/ecp5/ulx3s_dfc.lpf and ULX3S_CONNECTION_MAP.md's own new Section 9
  // for the physical pin assignment (gp14-gp21/J2-14 through J2-21, the
  // entire remaining unshared differential-capable range -- flagged
  // explicitly in that section, not consumed silently). RTL-011's own
  // irq_req_o now genuinely reaches RTL-003's real irq_source_i[12], and
  // its evt_valid_o/evt_record_o now genuinely reach RTL-005's real
  // evt_valid_i[10]/evt_record_i[10]. fault_req_o is a real output left
  // genuinely unconsumed (its architected destination, RTL-013.
  // fault_source_i[4], "System-health aggregate fault," does not exist
  // yet), same disclosed pattern as every other not-yet-connected
  // fault_req_o in this integration. Same port shape as RTL-007/008/009/010
  // -- only `module_enable_i` (RTL-002.module_enable_o[10]), no
  // `effective_operational_enable_i`.
  // ==========================================================================
  dfc_rtl011 u_rtl011 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[10]),
    .control_i                (rtl011_control),
    .status_o                 (rtl011_status),
    .timestamp_i              (rtl004_timestamp),  // real RTL-004 broadcast
    .evt_valid_o              (rtl011_evt_valid),
    .evt_ready_i              (rtl011_evt_ready),
    .evt_record_o             (rtl011_evt_record),
    .irq_req_o                (rtl011_irq_req),
    .fault_req_o              (),  // no real consumer yet -- RTL-013 does not exist
    .health_i                 (health_i),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .module_enable_i          (rtl002_module_enable[10]),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // module_ready_i/module_fault_i fan-in: bit i = RTL-(i+1). Bit 0
  // (RTL-001) is now REAL, via RTL-001's own status_o added this session
  // (previously a disclosed placeholder). Bits 2-3 (RTL-003/RTL-004) are
  // now REAL too (see the registered self-status pattern below). Bits 4-23
  // (RTL-005 through RTL-024) remain disclosed stub values -- see notes
  // above and the original STUB BLOCK comment below.
  //
  // Bit 1 (RTL-002's own self-loop) is REGISTERED, not combinational --
  // a REAL bug, found and fixed this session, not a synthesis-tool
  // artifact: RTL-002's own status_o.fault is computed as
  // `... || mandatory_fault_now || ...`, and mandatory_fault_now reads
  // module_fault_i (which includes the mandatory mask's bit 1 -- RTL-002
  // is one of its own mandatory-mask members, confirmed against
  // 0x80F81F's real bit pattern). Combinationally looping status_o.fault
  // straight back into module_fault_i[1] therefore makes module_fault_i[1]
  // algebraically a function of itself -- a genuine combinational cycle,
  // confirmed by tracing the actual signal dependencies, not by
  // inspection alone. This was silently tolerated by every prior real
  // Yosys ABC9 synthesis run (apparently optimized into a form that
  // didn't trip nextpnr's loop-checker) until a real, deliberate
  // `-noabc9` diagnostic run exposed it structurally. `status_comb.ready`
  // has no equivalent problem (`host_ready_q && init_complete_q` never
  // reads module_ready_i at all) -- registering fault alone would
  // suffice, but both are registered here together for a uniform,
  // less fragile self-status pattern rather than leaving one
  // combinational and one not for no principled reason.
  // RTL-003's own ready/fault has no equivalent combinational-loop risk to
  // RTL-002's (dfc_rtl003.sv's status_o.ready/.fault depend on no
  // module_ready_i/module_fault_i input at all -- it has no such port).
  // Registered here anyway, for the same uniform, less-fragile self-status
  // pattern established for RTL-002's bit above rather than leaving one
  // module's self-loop combinational and another registered for no
  // principled reason.
  logic rtl002_ready_self_q, rtl002_fault_self_q;
  logic rtl003_ready_self_q, rtl003_fault_self_q;
  logic rtl004_ready_self_q, rtl004_fault_self_q;
  logic rtl005_ready_self_q, rtl005_fault_self_q;
  logic rtl006_ready_self_q, rtl006_fault_self_q;
  logic rtl007_ready_self_q, rtl007_fault_self_q;
  logic rtl008_ready_self_q, rtl008_fault_self_q;
  logic rtl009_ready_self_q, rtl009_fault_self_q;
  logic rtl010_ready_self_q, rtl010_fault_self_q;
  logic rtl011_ready_self_q, rtl011_fault_self_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n) begin
    if (!core_rst_n) begin
      rtl002_ready_self_q <= 1'b0;
      rtl002_fault_self_q <= 1'b0;
      rtl003_ready_self_q <= 1'b0;
      rtl003_fault_self_q <= 1'b0;
      rtl004_ready_self_q <= 1'b0;
      rtl004_fault_self_q <= 1'b0;
      rtl005_ready_self_q <= 1'b0;
      rtl005_fault_self_q <= 1'b0;
      rtl006_ready_self_q <= 1'b0;
      rtl006_fault_self_q <= 1'b0;
      rtl007_ready_self_q <= 1'b0;
      rtl007_fault_self_q <= 1'b0;
      rtl008_ready_self_q <= 1'b0;
      rtl008_fault_self_q <= 1'b0;
      rtl009_ready_self_q <= 1'b0;
      rtl009_fault_self_q <= 1'b0;
      rtl010_ready_self_q <= 1'b0;
      rtl010_fault_self_q <= 1'b0;
      rtl011_ready_self_q <= 1'b0;
      rtl011_fault_self_q <= 1'b0;
    end else begin
      rtl002_ready_self_q <= rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__READY_HI];
      rtl002_fault_self_q <= rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__FAULT_HI];
      rtl003_ready_self_q <= rtl003_status[dfc_types_pkg::DFC_RTL003_STATUS__READY_HI];
      rtl003_fault_self_q <= rtl003_status[dfc_types_pkg::DFC_RTL003_STATUS__FAULT_HI];
      rtl004_ready_self_q <= rtl004_status[dfc_types_pkg::DFC_RTL004_STATUS__READY_HI];
      rtl004_fault_self_q <= rtl004_status[dfc_types_pkg::DFC_RTL004_STATUS__FAULT_HI];
      rtl005_ready_self_q <= rtl005_status[dfc_types_pkg::DFC_RTL005_STATUS__READY_HI];
      rtl005_fault_self_q <= rtl005_status[dfc_types_pkg::DFC_RTL005_STATUS__FAULT_HI];
      rtl006_ready_self_q <= rtl006_status[dfc_types_pkg::DFC_RTL006_STATUS__READY_HI];
      rtl006_fault_self_q <= rtl006_status[dfc_types_pkg::DFC_RTL006_STATUS__FAULT_HI];
      rtl007_ready_self_q <= rtl007_status[dfc_types_pkg::DFC_RTL007_STATUS__READY_HI];
      rtl007_fault_self_q <= rtl007_status[dfc_types_pkg::DFC_RTL007_STATUS__FAULT_HI];
      rtl008_ready_self_q <= rtl008_status[dfc_types_pkg::DFC_RTL008_STATUS__READY_HI];
      rtl008_fault_self_q <= rtl008_status[dfc_types_pkg::DFC_RTL008_STATUS__FAULT_HI];
      rtl009_ready_self_q <= rtl009_status[dfc_types_pkg::DFC_RTL009_STATUS__READY_HI];
      rtl009_fault_self_q <= rtl009_status[dfc_types_pkg::DFC_RTL009_STATUS__FAULT_HI];
      rtl010_ready_self_q <= rtl010_status[dfc_types_pkg::DFC_RTL010_STATUS__READY_HI];
      rtl010_fault_self_q <= rtl010_status[dfc_types_pkg::DFC_RTL010_STATUS__FAULT_HI];
      rtl011_ready_self_q <= rtl011_status[dfc_types_pkg::DFC_RTL011_STATUS__READY_HI];
      rtl011_fault_self_q <= rtl011_status[dfc_types_pkg::DFC_RTL011_STATUS__FAULT_HI];
    end
  end

  assign module_ready = {13'h0, rtl011_ready_self_q, rtl010_ready_self_q, rtl009_ready_self_q, rtl008_ready_self_q, rtl007_ready_self_q, rtl006_ready_self_q, rtl005_ready_self_q, rtl004_ready_self_q, rtl003_ready_self_q, rtl002_ready_self_q,
                          rtl001_status[dfc_types_pkg::DFC_RTL001_STATUS__READY_HI]};
  assign module_fault = {13'h0, rtl011_fault_self_q, rtl010_fault_self_q, rtl009_fault_self_q, rtl008_fault_self_q, rtl007_fault_self_q, rtl006_fault_self_q, rtl005_fault_self_q, rtl004_fault_self_q, rtl003_fault_self_q, rtl002_fault_self_q,
                          rtl001_status[dfc_types_pkg::DFC_RTL001_STATUS__FAULT_HI]};

  // ==========================================================================
  // STUB BLOCK -- RTL-012 through RTL-023 do not exist yet in this
  // repository. Each entry below is a labeled placeholder: it consumes no
  // real signal from RTL-001 through RTL-011 (module control/status
  // wiring per ARCH-CONN-003 is not connected) and produces no real
  // behavior. This block exists so this file elaborates for ECP5 synthesis
  // and simulation; it is NOT a model of any child module's behavior.
  // Replace each stub with a real instantiation as that module is
  // implemented -- do not extend the stub pattern into real logic.
  //
  // Modules stubbed (per RTLSTD-MOD-011, all must eventually be
  // instantiated exactly once): RTL-012 through RTL-023.
  // ==========================================================================

  // Aggregate host_irq_n_o: per ARCH-002 Appendix A, high in reset or with
  // no enabled pending source. REAL as of this session: RTL-003's real
  // `aggregate_pending_o` (active-high, per ARCH-002's port catalog -- see
  // dfc_rtl003.sv's own header for the SPEC CONFLICT note on why this isn't
  // named `host_irq_n_o` at RTL-003's own boundary) is inverted here onto
  // the real external active-low pad -- this is the concrete, testable
  // proof that the previously-disclosed RTL-002<->RTL-024 interrupt-
  // aggregation gap is actually closed, not just described as closed. Still
  // correctly stays high in practice today because GLOBAL_IRQ_ENABLE and
  // IRQ_ENABLE both reset to 0 (no host write yet in a fresh bring-up) and
  // most of the 24 real source producers don't exist yet -- that is the
  // real, disclosed consequence of the current integration stage, not
  // evidence the aggregation path itself is inactive (see
  // rtl003_integration_tb.sv and rtl024_skeleton_tb.sv for real, driven
  // proof that it responds once enabled).
  assign host_irq_n_o = !rtl003_aggregate_pending;

  // GPIO: REAL as of this session -- gpio_i/gpio_o/gpio_oe_o are wired
  // directly to u_rtl006 above. dfc_rtl006.sv itself implements
  // ARCH-RTL006-001's full "zero in reset/disable/test" OE-gating
  // contract (see that file's own header) -- no additional pad-safe gate
  // is layered here, since RTL-006's own real gating already covers
  // every ARCH-CONN-012 condition (reset via its own registered-output
  // reset branch, disable via module_enable_i, test/observation via
  // operating_state_i/observational_mode_i).

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
                            arinc_rx_i ^ arinc_rx_adapter_error_i ^
                            arinc_tx_adapter_error_i ^ can_rx_i ^
                            can_transceiver_error_i ^ uart_rx_i ^
                            user_i[0] ^
                            test_enable_i ^ test_clock_i ^ test_data_i ^
                            (^rtl002_operating_state) ^ rtl002_observational_mode ^
                            (|module_reset[23:11]);
                            // rtl002_irq_req is no longer unused -- it is
                            // now a real input to RTL-003's irq_source_i[0]
                            // above. module_reset[2]/module_reset[3]/
                            // module_reset[4]/module_reset[5]/module_reset[6]/
                            // module_reset[7]/module_reset[8] are no longer
                            // unused either -- they are now RTL-003's/
                            // RTL-004's/RTL-005's/RTL-006's/RTL-007's/
                            // RTL-008's/RTL-009's real module_reset_i.
                            // gpio_i is no longer unused -- it is now a real
                            // input to RTL-006's gpio_i above. rotor_i is no
                            // longer unused -- it is now a real input to
                            // RTL-007's rotor_i above. engine_i is no longer
                            // unused -- it is now a real input to RTL-008's
                            // engine_i above. pulse_i[1:0] is no longer
                            // unused -- both bits are real inputs to
                            // RTL-009's pulse_i above. module_reset[9] is no
                            // longer unused -- it is now RTL-010's real
                            // module_reset_i. RTL-010 has no physical pin at
                            // all (see its own header) so there is no new
                            // signal to remove from this sink for it.
                            // health_i[7:0] is no longer unused -- all 8
                            // bits are now real inputs to RTL-011's health_i
                            // above. module_reset[10] is no longer unused
                            // either -- it is now RTL-011's real
                            // module_reset_i.

endmodule : dfc_rtl024
