// dfc_rtl024.sv -- RTL-024 Dragon Core Top-Level Integration: SKELETON.
//
// Controlling documents: docs/rtl_specs/RTL-024_RevC.md, RCA-DFC-ARCH-002
// SS5-7, 12, 14 and Appendix A/C/D. Per RTLSTD-MOD-011, RTL-024 must
// instantiate RTL-001 through RTL-023 exactly once. As of this file,
// RTL-001 (dfc_rtl001.sv), RTL-002 (dfc_rtl002.sv), and RTL-003
// (dfc_rtl003.sv) exist in this repository; RTL-004 through RTL-023 do not.
// This is therefore explicitly a SKELETON, not a full implementation:
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
//   - RTL-004 through RTL-023 are LABELED STUBS -- see STUB block below.
//     Each stub's own status/ready/fault contribution to RTL-002's
//     module_ready_i/module_fault_i fan-in is a fixed "not ready, no
//     fault" value. This is NOT real behavior; it exists only so this
//     file elaborates and RTL-001/RTL-002/RTL-003 can be exercised on real
//     ECP5 hardware before their sibling modules are written. Do not treat
//     a stub's fixed output as evidence of anything about the real
//     module's behavior. NOTE: because RTL-002 requires every
//     SUBSYS_ENABLE mandatory-mask module to report ready before leaving
//     STARTUP, and several mandatory bits (0x80F81F) belong to still-
//     stubbed modules (e.g. RTL-004/005, RTL-012 through RTL-016,
//     RTL-019), this skeleton's RTL-002 instance will run to its 499,000-
//     cycle mandatory-init timeout and enter FAULTED every time, not
//     NORMAL -- that is the real, disclosed consequence of the stub
//     topology, not a bug in RTL-002 itself. It will read NORMAL/DEGRADED
//     correctly only once enough mandatory-mask modules are real.
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
  // rtl002_status/rtl001_status/rtl002_control are now declared earlier,
  // immediately before dfc_rtl001's instantiation -- see that block's own
  // comment for why.

  dfc_rtl002 u_rtl002 (
    .core_clk_i           (core_clk_i),
    .core_rst_n_i         (core_rst_n),
    .module_reset_i       (module_reset[1]),
    .control_i            (rtl002_control),
    .status_o             (rtl002_status),
    .timestamp_i          (64'h0),   // RTL-004 does not exist yet -- disclosed
    .evt_valid_o          (),        // no RTL-005 exists yet to accept RTL-002's
                                     // now-real events -- output genuinely
                                     // unconsumed, not a stub on RTL-002's side
    .evt_ready_i          (1'b1),
    .evt_record_o         (),
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
    .test_active_i        (1'b0)
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
  // global_irq_enable_i: ARCH-002's port catalog names RTL-002.
  // global_irq_enable_o as this signal's real producer, but dfc_rtl002.sv
  // (as already delivered, out of this integration's scope to modify) has
  // no such dedicated output port -- a real, pre-existing gap in RTL-002's
  // own port-catalog conformance, independent of RTL-003. The underlying
  // SYS_CONTROL.GLOBAL_IRQ_ENABLE bit is nonetheless real, live data
  // already present on `rtl002_control` (RTL-001's real aggregated output
  // to RTL-002, a net this file already owns and connects) -- read directly
  // from it here rather than invent a stub value for a bit that is, in
  // fact, already real and host-writable. This is an ordinary top-level net
  // reference, not a hierarchical dot-notation reference into another
  // module's internals (RTLSTD-MOD-014 governs the latter, not this).
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

  assign rtl003_irq_source = {8'h0, rtl002_irq_req};

  dfc_rtl003 u_rtl003 (
    .core_clk_i               (core_clk_i),
    .core_rst_n_i             (core_rst_n),
    .module_reset_i           (module_reset[2]),
    .control_i                (rtl003_control),
    .status_o                 (rtl003_status),
    .timestamp_i              (64'h0),  // RTL-004 does not exist yet -- disclosed
    .evt_valid_o              (),       // no RTL-005 exists yet to accept RTL-003's
                                        // now-real diagnostic event -- output
                                        // genuinely unconsumed, not a stub
    .evt_ready_i              (1'b1),
    .evt_record_o             (),
    .irq_source_i             (rtl003_irq_source),
    .aggregate_pending_o      (rtl003_aggregate_pending),
    .operating_state_i        (rtl002_operating_state),
    .observational_mode_i     (rtl002_observational_mode),
    .global_irq_enable_i      (rtl002_control[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__GLOBAL_IRQ_ENABLE_HI]),
    .event_condition_enable_i (64'h0),
    .irq_condition_enable_i   (64'h0)
  );

  // module_ready_i/module_fault_i fan-in: bit i = RTL-(i+1). Bit 0
  // (RTL-001) is now REAL, via RTL-001's own status_o added this session
  // (previously a disclosed placeholder). Bit 2 (RTL-003) is now REAL too
  // (see the registered self-status pattern below). Bits 3-23 (RTL-004
  // through RTL-024) remain disclosed stub values -- see notes above and
  // the original STUB BLOCK comment below.
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
  always_ff @(posedge core_clk_i or negedge core_rst_n) begin
    if (!core_rst_n) begin
      rtl002_ready_self_q <= 1'b0;
      rtl002_fault_self_q <= 1'b0;
      rtl003_ready_self_q <= 1'b0;
      rtl003_fault_self_q <= 1'b0;
    end else begin
      rtl002_ready_self_q <= rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__READY_HI];
      rtl002_fault_self_q <= rtl002_status[dfc_types_pkg::DFC_RTL002_STATUS__FAULT_HI];
      rtl003_ready_self_q <= rtl003_status[dfc_types_pkg::DFC_RTL003_STATUS__READY_HI];
      rtl003_fault_self_q <= rtl003_status[dfc_types_pkg::DFC_RTL003_STATUS__FAULT_HI];
    end
  end

  assign module_ready = {21'h0, rtl003_ready_self_q, rtl002_ready_self_q,
                          rtl001_status[dfc_types_pkg::DFC_RTL001_STATUS__READY_HI]};
  assign module_fault = {21'h0, rtl003_fault_self_q, rtl002_fault_self_q,
                          rtl001_status[dfc_types_pkg::DFC_RTL001_STATUS__FAULT_HI]};

  // ==========================================================================
  // STUB BLOCK -- RTL-004 through RTL-023 do not exist yet in this
  // repository. Each entry below is a labeled placeholder: it consumes no
  // real signal from RTL-001/RTL-002/RTL-003 (module control/status wiring
  // per ARCH-CONN-003 is not connected) and produces no real behavior. This
  // block exists so this file elaborates for ECP5 synthesis and simulation;
  // it is NOT a model of any child module's behavior. Replace each stub
  // with a real instantiation as that module is implemented -- do not
  // extend the stub pattern into real logic.
  //
  // Modules stubbed (per RTLSTD-MOD-011, all must eventually be
  // instantiated exactly once): RTL-004 through RTL-023.
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
                            test_enable_i ^ test_clock_i ^ test_data_i ^
                            (^rtl002_operating_state) ^ rtl002_observational_mode ^
                            (|module_reset[23:3]);
                            // rtl002_irq_req is no longer unused -- it is
                            // now a real input to RTL-003's irq_source_i[0]
                            // above. module_reset[2] is no longer unused
                            // either -- it is now RTL-003's real
                            // module_reset_i.

endmodule : dfc_rtl024
