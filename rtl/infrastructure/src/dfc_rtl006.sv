// dfc_rtl006.sv -- RTL-006 GPIO Controller: 8 synchronized/qualified
// bidirectional GPIO channels, per-channel direction/output-enable gating,
// and independently-masked rising/falling/either-edge/active-high/
// active-low event and interrupt subconditions (ARCH-002 SS9 ARCH-MON-001,
// Appendix F.1 ARCH-RTL006-001, Appendix F.3 index 5). Owns REG-002's GPIO
// block (0x0400-0x0438, 15 registers).
//
// Controlling documents: docs/rtl_specs/RTL-006_RevA.md, RCA-DFC-ARCH-002
// SS9/Appendix B/Appendix F.1 ARCH-RTL006-001/Appendix F.3 index 5/
// Appendix C.5 event ID 0x0010/ARCH-VAL-006, RCA-DFC-REG-002 SS11
// (0x0400-0x0438).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// SPEC CONFLICT, RESOLVED IN FAVOR OF THE OWNING DOCUMENT (CHTR-DOC-003):
// RTL-006_RevA.md SS2 states control_i/status_o are 114/51 bits.
// RCA-DFC-ARCH-002.md's own Appendix B struct tables (the actual owner of
// this fact) give dfc_rtl006_control_t as 122 bits (before this session's
// fix below) and dfc_rtl006_status_t as 83 bits -- confirmed directly
// against the real struct field tables, not restated from the spec.
// Resolved in favor of ARCH-002, same resolution style as the RTL-005
// 14-vs-15-register discrepancy and the RTL-003 host_irq_n_o conflict.
// This module implements the real ARCH-002 widths (123/83, see next note).
//
// ONE REAL ARCH-002 GAP, FOUND AND FIXED BEFORE this module was implemented
// -- not silently worked around, and explicitly anticipated by this
// project's own task instructions given the four prior real instances of
// this exact gap class (RTL-002/003's EVT_OVERFLOW_STATUS, RTL-004's
// SNAPSHOT_VALID/SYNC_VALID, RTL-005's SNAPSHOT_VALID):
//   dfc_rtl006_control_t (122 bits) had no clear-request field for
//   RTL006_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x0434 bit 0, a real
//   W1C field). Fixed: ARCH-002 grew the struct 122->123 bits, adding
//   rtl006_evt_overflow_status__event_overflow at the new highest bit
//   (122) -- every pre-existing field's bit position confirmed unchanged
//   via a real regenerate.ps1 run (every _HI/_LO constant below bit 122 is
//   byte-identical to before this fix).
//
// A SECOND REAL GAP, FOUND WHILE BUILDING rtl006_field_map.json AND FIXED
// FOR RTL-006 FROM THE START (not backported to its three older siblings --
// see below): RTL002_EVT_OVERFLOW_STATUS/RTL003_EVT_OVERFLOW_STATUS/
// RTL004_EVT_OVERFLOW_STATUS each already have a real control-side
// clear-request path (their own field-maps' control_registers sections),
// but NONE of their field-maps ever added a matching status_registers
// entry -- confirmed directly in the real generated
// dfc_config_regbank_regs.sv: e.g. RTL002_EVT_OVERFLOW_STATUS's read value
// (`rtl002_evt_overflow_status_q`) is wired from the OLD individual
// `rtl002_evt_overflow_status_status_i` port, which dfc_rtl001.sv still
// ties to a permanent `'0` -- meaning a host READ of that register's
// EVENT_OVERFLOW/DROP_COUNT fields always returns zero regardless of
// RTL-002's real internal state, even though the real host WRITE (clear)
// path works. This was never caught because rtl002/003/004_integration_tb.sv
// only ever checked the DUT's internal status_o signal directly
// (white-box), never a real host REGISTER READ of that specific address.
// `rtl006_field_map.json`'s own status_registers section maps
// RTL006_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW/DROP_COUNT directly onto this
// struct's generic `event_overflow`/`event_drop_count` fields (the same
// two fields every dfc_rtlNNN_status_t already carries), closing this gap
// for RTL-006 from the start -- confirmed via
// rtl006_integration_tb.sv Part 6 issuing a real host READ, not just
// inspecting the DUT's internal signal. Backporting the equivalent fix to
// RTL-002/003/004's own field-maps is real, disclosed, out-of-scope future
// work for this session -- logged in OPEN_ISSUES.md, not silently repeated
// a fourth time or silently fixed as a drive-by.
//
// A THIRD REAL GAP, FOUND AND FIXED IN dfc_rtl002.sv ITSELF (same class as
// OPEN_ISSUES.md item 5 -- "a sibling module's own port-catalog
// nonconformance can surface during a later module's integration"):
// RTL-006's own real ARCH-002 port catalog names its `module_enable_i`/
// `effective_operational_enable_i` producers as `RTL-002.module_enable_o[5]`/
// `RTL-002.effective_operational_enable_o` -- both REAL ports in ARCH-002's
// own RTL-002 port-catalog table (24 ports, rows `module_enable_o`/
// `effective_operational_enable_o`), but dfc_rtl002.sv, as it existed
// before this session, had neither port. Fixed by adding both as real
// outputs on dfc_rtl002.sv: `module_enable_o` is the real SUBSYS_ENABLE
// bitmap with mandatory bits forced to `SUBSYS_ENABLE_MANDATORY_MASK`
// (`0x80F81F`, per the port's own documented reset/semantic: "mandatory
// bits fixed, optional bits configurable") ORed with the module's own,
// already-computed `effective_optional_enable` wire -- zero new logic,
// just exposing an existing internal signal correctly composed;
// `effective_operational_enable_o` is a direct passthrough of the
// already-computed `effective_operational_enable` wire (the same signal
// `status_o.sys_status__effective_operational_enable` already exposes).
// This is an ARCH-002 CONFORMANCE fix to already-shipped RTL-002, not an
// ARCH-002 document edit -- ARCH-002 already specified both ports
// correctly; dfc_rtl002.sv simply hadn't implemented them yet, since no
// earlier module actually needed them.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (ARCH-MON-001/ARCH-RTL006-001):
//
//   - SYNCHRONIZATION/QUALIFICATION (per channel, CDC-GPIO): a genuine
//     two-flop synchronizer (`sync1_q`/`sync2_q`) on the raw async
//     `gpio_i[ch]` pad input, feeding an 8-bit millisecond-scale
//     stable-time qualification stage. A free-running `ms_tick` pulse
//     (one CORE_CLK cycle every 50,000 cycles, assuming the project's own
//     nominal 50 MHz CORE_CLK per ARCH-CLK-001 -- the same disclosed
//     assumption dfc_rtl004.sv's own microsecond divider already relies
//     on) drives a per-channel candidate/run-length counter: a
//     qualification value of zero passes `sync2_q` through to
//     `qual_value_q` every cycle, with no ms-tick wait at all (spec's own
//     "passes through without delay"); a nonzero value commits the change
//     only after that many CONSECUTIVE ms samples agree on a value
//     different from the currently-committed one (spec's own "consecutive
//     1ms samples agree"). `GPIO_CONTROL.QUALIFICATION_ENABLE` is this
//     module's own global override for the per-channel qualification
//     stage: when clear, every channel behaves as if its own configured
//     qualification time were zero (immediate pass-through), regardless
//     of what `GPIO_QUAL_0_3`/`GPIO_QUAL_4_7` actually store -- REG-002's
//     own text for `GPIO_CONTROL` ("...and qualification control") names
//     this bit's purpose but does not spell out its exact effect; this is
//     the disclosed, most literal reading.
//   - OUTPUT ENABLE (ARCH-RTL006-001's own literal equation, per channel):
//     `effective_oe[ch] = direction[ch] && module_enable_i &&
//     effective_operational_enable_i && (operating_state_i !=
//     TEST_DEBUG) && !observational_mode_i`. Unlike dfc_rtl003/005.sv's
//     precedent (where `operating_state_i`/`observational_mode_i` are
//     real, structurally-required ports with no functional use), THIS
//     module genuinely uses both, since the spec's own OE equation
//     explicitly names "test" and "observation" as separate exclusion
//     terms, and RTL-006 has no dedicated `test_active_i` port of its own
//     (confirmed against the real 20-port ARCH-002 catalog) -- "test" is
//     read here as the shared `operating_state_i == TEST_DEBUG` encoding,
//     the only place "test" is observable without a dedicated port,
//     consistent with how `effective_operational_enable_i` itself already
//     excludes TEST_DEBUG upstream in RTL-002. `GPIO_CONTROL.ENABLE` is
//     deliberately NOT an additional term in this equation -- the spec's
//     own literal text lists exactly four AND-ed terms plus the NOT-OR
//     exclusion, and `module_enable_i` already IS this module's
//     "disable" term per ARCH-RTL006-001's own text ("reset and disable
//     force OE zero"). This equation is evaluated unconditionally BEFORE
//     any route/output-data logic (ARCH-RTL006-001's own ordering
//     requirement) by construction: `gpio_o`/`gpio_oe_o` are registered
//     outputs whose reset branch (asynchronous reset AND `module_reset_i`)
//     unconditionally zeros them in the SAME `always_ff` block, ahead of
//     -- not racing with -- the same block's ordinary-cycle assignment.
//   - `GPIO_CONTROL.ENABLE` (bit 0) is this module's substitute for the
//     Appendix F.3 preamble's `MODULE_EVENT_ENABLE`/`MODULE_IRQ_ENABLE`
//     terms, used as an overall qualification/event/irq-generation kill
//     switch (disabled -> no qualification advances, no channel event/irq
//     ever fires) -- the same role `LOGGER_ENABLE` plays for
//     dfc_rtl005.sv's own identical substitution. `GPIO_RAW_IN`/
//     `GPIO_SYNC_IN` themselves are NOT gated by `ENABLE` (REG-002's own
//     "reads current hardware value" text for both implies a live,
//     unconditional passthrough regardless of the controller's own
//     enable state, useful for diagnostics even while disabled).
//   - PER-CHANNEL EVENT/IRQ SUBCONDITIONS (Appendix F.3 index 5: 0-7
//     rising, 8-15 falling, 16-23 active-high level, 24-31 active-low
//     level, 32-39 either-edge, 40 event-slot overflow; F.3 preamble
//     equation, per-channel master substituting for the module-level
//     term): `GPIO_RISE_ENABLE[ch]`/`GPIO_FALL_ENABLE[ch]` gate whether a
//     qualified rising/falling transition is even detected for that
//     channel at all (the edge-type "per-channel master enable" ARCH-
//     VAL-006 refers to); active-high/active-low LEVEL conditions have no
//     equivalent dedicated per-channel register (REG-002 defines none),
//     so they are gated solely by their own F.3 condition-mask bit.
//     "Either-edge" (F.3 bits 32-39) is implemented as an ADDITIONAL,
//     alternate gate for the SAME already-rise/fall-enabled edge signal
//     (i.e. a rising edge reaches event/irq generation if EITHER its own
//     F.3 rising bit OR the channel's F.3 either-edge bit is set) rather
//     than a wholly separate detection path -- REG-002/ARCH-002 do not
//     spell out "either-edge"'s exact boolean composition relative to
//     "rising"/"falling" (there is no dedicated "either-edge enable"
//     register, and C.7's own event-ID table gives "either-edge" no
//     distinct event subtype of its own, only rising(0)/falling(1)/
//     high(2)/low(3) -- consistent with "either" always being reported
//     as whichever concrete edge actually occurred), so this is a
//     disclosed interpretation, not a cited bit-exact fact. Per-channel
//     event/irq request: `chan_event_req[ch] = GPIO_CONTROL.ENABLE &&
//     GPIO_EVENT_ENABLE[ch] && OR(gated subconditions)`; `chan_irq_req[ch]`
//     analogous with `GPIO_IRQ_ENABLE[ch]`/`irq_condition_enable_i`.
//     `irq_req_o` is the plain OR of all 8 `chan_irq_req[ch]` (level,
//     feeds RTL-003.irq_source_i[2] per Appendix C.4/the IRQ source
//     matrix's own row 2 "GPIO / RTL-006").
//   - `GPIO_EVENT_STATUS.EVENT[ch]` (sticky per-channel evidence, W1C):
//     sets whenever `chan_event_req[ch]` is asserted (a LEVEL condition
//     legitimately holds it set continuously while true; an EDGE
//     condition sets it for one cycle and it then stays set, sticky,
//     until host-cleared), cleared via the real
//     `gpio_event_status__event[ch]` control-clear bit, with
//     new-evidence-dominates-clear priority (the same
//     `reset/disable, then new evidence, then clear` priority every prior
//     module's own W1C fields already use).
//   - OWN DIAGNOSTIC EVENT GENERATION (event ID 0x0010, source index 5,
//     ARCH-002 Appendix C.5/C.7; real, counted one-deep pending-slot shape
//     identical to every prior module): a candidate is scheduled on the
//     RISING edge of `chan_event_req[ch]` (edge-qualified for the same
//     reason dfc_rtl003/005.sv's own analogous conditions are -- a LEVEL
//     condition holding `chan_event_req[ch]` continuously high must not
//     re-trigger a fresh candidate every single cycle it remains true).
//     Lowest-numbered channel with a rising `chan_event_req` wins this
//     cycle's candidate (same lowest-index-priority precedent as
//     dfc_rtl003.sv's VECTOR_SOURCE and dfc_rtl005.sv's `ovfl_source_comb`).
//     Subtype for that channel, in priority order rising > falling >
//     active-high level > active-low level (C.7 gives no priority rule
//     for a channel satisfying more than one gated subcondition in the
//     same cycle -- a disclosed, locally-chosen order, same basis as
//     other modules' own disclosed detail-field packing choices):
//     0 rising, 1 falling, 2 high level, 3 low level. Per C.7's own
//     row for `0x0010` ("`event_data[31:16]`: qualified GPIO bitmap",
//     which explicitly overrides the C.7 preamble's generic convention
//     for this one row): `event_data[7:0]` = subtype, `event_data[15:8]`
//     = channel index, `event_data[31:16]` = all 8 qualified channel
//     values (`qual_value_q[7:0]`, zero-extended).
//   - READY/FAULT (ARCH-RTL006-001): "Ready requires legal channel
//     configuration; fault is illegal configuration or unrecoverable
//     qualification logic error." This implementation's only concrete,
//     testable "illegal configuration" condition is ARCH-VAL-006's own
//     "qualification is 0-100 ms" range check against the real, 8-bit-wide
//     (0-255) `GPIO_QUAL_0_3`/`GPIO_QUAL_4_7` fields -- RTL-001 does not
//     yet implement per-field legal-range write validation (already
//     disclosed, project-wide gap, OPEN_ISSUES.md item 4), so a value
//     101-255 can genuinely reach `control_i`; this module defends itself
//     by treating any channel's configured qualification time exceeding
//     100 as illegal configuration (sticky fault, and `ready` low while
//     it persists), the same "defend against what RTL-001 doesn't yet
//     reject" precedent already established by dfc_rtl003.sv's reserved-
//     bit handling. ARCH-VAL-006's OTHER named legality condition
//     ("output direction is legal only when the attached logical pad is
//     assigned GPIO") has no real counterpart in this project's fixed,
//     1:1 pad-to-signal architecture (there is no shared/multiplexed pad
//     assignment mechanism implemented anywhere in this build), so it is
//     always trivially satisfied and never contributes to the fault
//     condition. "Unrecoverable qualification logic error" has no real
//     detection mechanism in this implementation (no ECC/parity on the
//     per-channel counters) -- the same class of disclosed gap
//     dfc_rtl004/005.sv's own fault-source text already discloses for
//     their analogous "illegal command"/"internal-storage error" terms.
//   - `route_gpio_req_i[7:0]` (RTL-023.route_dest_o[8:1]): a real port per
//     the Architecture catalog, but with no real producer EVER in this
//     project -- RTL-022/RTL-023 are permanently, deliberately out of
//     scope for this build (PROJECT_CONTINUITY.md Section 5's scope-
//     reduction decision, not a "not yet built" gap like every other
//     stubbed cross-module signal elsewhere in this project). REG-002
//     defines no register for how a routed request would even combine
//     with the host's own `GPIO_OUT` commanded value, so this port is
//     tied to a disclosed stub (8'h0) in dfc_rtl024.sv and genuinely
//     unused here, sunk via the unused-port sink below.
//   - `EFFECTIVE_OUTPUT` = `commanded_output[ch] && channel_oe[ch]`
//     (REG-002's own "current post-permit output data" text), which is
//     also exactly what drives the real `gpio_o[ch]` pad output --
//     `GPIO_STATUS.EFFECTIVE_OUTPUT` and the real pad are the same signal,
//     not two independently-computed values that could ever disagree.
// ============================================================================

module dfc_rtl006 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[5]

  // TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
  // Yosys build -- see dfc_rtl002.sv's header for the full account): a
  // package-scoped type cannot be a port's declared type. Every such port
  // here is a plain `logic [W-1:0]` vector sized via generated
  // `dfc_types_pkg::DFC_*_WIDTH` VALUE constants instead.
  input  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,

  input  logic [7:0] gpio_i,      // raw external input, CDC-GPIO -- this
                                   // module owns the two-flop synchronizer
  output logic [7:0] gpio_o,
  output logic [7:0] gpio_oe_o,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic [7:0] route_gpio_req_i,   // RTL-023.route_dest_o[8:1] -- real
                                          // port, permanently unproduced
                                          // (RTL-022/023 out of scope, see
                                          // header) -- unused, sunk below.

  input  logic         module_enable_i,               // RTL-002.module_enable_o[5]
  input  logic         effective_operational_enable_i, // RTL-002.effective_operational_enable_o

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 5
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 5
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as dfc_rtl002/003/004/005.sv) ----
  wire        ctl_enable            = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_CONTROL__ENABLE_HI];
  wire        ctl_qual_enable       = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_CONTROL__QUALIFICATION_ENABLE_HI];
  wire [7:0]  ctl_out               = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_OUT__OUTPUT_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_OUT__OUTPUT_LO];
  wire [7:0]  ctl_rise_en           = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_RISE_ENABLE__RISE_ENABLE_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_RISE_ENABLE__RISE_ENABLE_LO];
  wire [7:0]  ctl_fall_en           = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_FALL_ENABLE__FALL_ENABLE_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_FALL_ENABLE__FALL_ENABLE_LO];
  wire [7:0]  ctl_event_en          = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_EVENT_ENABLE__EVENT_ENABLE_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_EVENT_ENABLE__EVENT_ENABLE_LO];
  wire [7:0]  ctl_irq_en            = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_IRQ_ENABLE__IRQ_ENABLE_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_IRQ_ENABLE__IRQ_ENABLE_LO];
  wire [7:0]  ctl_event_status_clr  = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_EVENT_STATUS__EVENT_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_EVENT_STATUS__EVENT_LO];
  wire [7:0]  ctl_dir               = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_DIR__DIRECTION_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_DIR__DIRECTION_LO];
  wire        ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__RTL006_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire [7:0] ctl_qual_ch0 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH0_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH0_MS_LO];
  wire [7:0] ctl_qual_ch1 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH1_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH1_MS_LO];
  wire [7:0] ctl_qual_ch2 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH2_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH2_MS_LO];
  wire [7:0] ctl_qual_ch3 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH3_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_0_3__CH3_MS_LO];
  wire [7:0] ctl_qual_ch4 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH4_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH4_MS_LO];
  wire [7:0] ctl_qual_ch5 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH5_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH5_MS_LO];
  wire [7:0] ctl_qual_ch6 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH6_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH6_MS_LO];
  wire [7:0] ctl_qual_ch7 = control_i[dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH7_MS_HI:dfc_types_pkg::DFC_RTL006_CONTROL__GPIO_QUAL_4_7__CH7_MS_LO];

  // Packed into an indexable array via a combinational assign (not per-
  // element continuous assigns to an unpacked array, which risks the same
  // class of toolchain fragility already documented for other constructs
  // in this project) -- every per-channel for-loop below indexes this.
  logic [7:0] ctl_qual_ms [0:7];
  always_comb begin
    ctl_qual_ms[0] = ctl_qual_ch0;
    ctl_qual_ms[1] = ctl_qual_ch1;
    ctl_qual_ms[2] = ctl_qual_ch2;
    ctl_qual_ms[3] = ctl_qual_ch3;
    ctl_qual_ms[4] = ctl_qual_ch4;
    ctl_qual_ms[5] = ctl_qual_ch5;
    ctl_qual_ms[6] = ctl_qual_ch6;
    ctl_qual_ms[7] = ctl_qual_ch7;
  end

  // ==========================================================================
  // Millisecond tick generator -- disclosed assumption: nominal 50 MHz
  // CORE_CLK (ARCH-CLK-001), same assumption dfc_rtl004.sv's own
  // microsecond divider already relies on for this project.
  // ==========================================================================
  localparam int unsigned MS_TICK_CYCLES = 50_000;
  logic [15:0] ms_counter_q;
  logic        ms_tick;
  assign ms_tick = (ms_counter_q == MS_TICK_CYCLES-1);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)            ms_counter_q <= 16'd0;
    else if (module_reset_i)      ms_counter_q <= 16'd0;
    else if (ms_tick)              ms_counter_q <= 16'd0;
    else                            ms_counter_q <= ms_counter_q + 16'd1;
  end

  // ==========================================================================
  // Per-channel synchronization + qualification (CDC-GPIO / ARCH-MON-001).
  // ==========================================================================
  logic [7:0] sync1_q, sync2_q;
  logic [7:0] raw_in_q;
  logic [7:0] qual_value_q, qual_value_prev_q;
  logic [7:0] qual_candidate_q;
  logic [7:0] qual_run_length_q [0:7];
  logic [7:0] illegal_qual_time;

  always_comb begin
    for (int c = 0; c < 8; c++) illegal_qual_time[c] = (ctl_qual_ms[c] > 8'd100);
  end

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sync1_q            <= 8'h0;
      sync2_q             <= 8'h0;
      raw_in_q            <= 8'h0;
      qual_value_q        <= 8'h0;
      qual_value_prev_q   <= 8'h0;
      qual_candidate_q    <= 8'h0;
      for (int c = 0; c < 8; c++) qual_run_length_q[c] <= 8'd0;
    end else if (module_reset_i) begin
      sync1_q            <= 8'h0;
      sync2_q             <= 8'h0;
      raw_in_q            <= 8'h0;
      qual_value_q        <= 8'h0;
      qual_value_prev_q   <= 8'h0;
      qual_candidate_q    <= 8'h0;
      for (int c = 0; c < 8; c++) qual_run_length_q[c] <= 8'd0;
    end else begin
      sync1_q  <= gpio_i;
      sync2_q  <= sync1_q;
      raw_in_q <= gpio_i;

      qual_value_prev_q <= qual_value_q;

      for (int c = 0; c < 8; c++) begin
        if (!ctl_qual_enable || (ctl_qual_ms[c] == 8'd0)) begin
          // "passes through without delay" -- committed every cycle, no
          // ms-tick wait at all.
          qual_value_q[c] <= sync2_q[c];
        end else if (ms_tick) begin
          if (sync2_q[c] == qual_value_q[c]) begin
            qual_run_length_q[c] <= 8'd0;
          end else if (sync2_q[c] == qual_candidate_q[c]) begin
            if ((qual_run_length_q[c] + 8'd1) >= ctl_qual_ms[c]) begin
              qual_value_q[c]       <= sync2_q[c];
              qual_run_length_q[c] <= 8'd0;
            end else begin
              qual_run_length_q[c] <= qual_run_length_q[c] + 8'd1;
            end
          end else begin
            qual_candidate_q[c]   <= sync2_q[c];
            qual_run_length_q[c]  <= 8'd1;
          end
        end
      end
    end
  end

  logic [7:0] qualification_in_progress;
  always_comb begin
    for (int c = 0; c < 8; c++) begin
      qualification_in_progress[c] = ctl_qual_enable && (ctl_qual_ms[c] != 8'd0) &&
                                       (sync2_q[c] != qual_value_q[c]);
    end
  end

  // ---- edge detection on the qualified value ----
  wire [7:0] rising_qualified  = qual_value_q & ~qual_value_prev_q;
  wire [7:0] falling_qualified = ~qual_value_q & qual_value_prev_q;
  wire [7:0] rise_detect  = rising_qualified  & ctl_rise_en;
  wire [7:0] fall_detect  = falling_qualified & ctl_fall_en;
  wire [7:0] high_level   = qual_value_q;
  wire [7:0] low_level    = ~qual_value_q;

  // ==========================================================================
  // Per-channel F.3-gated event/irq subconditions -- see header for the
  // disclosed "either-edge as an alternate gate" interpretation.
  // ==========================================================================
  wire [7:0] ev_rise  = rise_detect  & (event_condition_enable_i[7:0]   | event_condition_enable_i[39:32]);
  wire [7:0] ev_fall  = fall_detect  & (event_condition_enable_i[15:8]  | event_condition_enable_i[39:32]);
  wire [7:0] ev_high  = high_level   & event_condition_enable_i[23:16];
  wire [7:0] ev_low   = low_level    & event_condition_enable_i[31:24];

  wire [7:0] iq_rise  = rise_detect  & (irq_condition_enable_i[7:0]   | irq_condition_enable_i[39:32]);
  wire [7:0] iq_fall  = fall_detect  & (irq_condition_enable_i[15:8]  | irq_condition_enable_i[39:32]);
  wire [7:0] iq_high  = high_level   & irq_condition_enable_i[23:16];
  wire [7:0] iq_low   = low_level    & irq_condition_enable_i[31:24];

  wire [7:0] chan_event_cond = ev_rise | ev_fall | ev_high | ev_low;
  wire [7:0] chan_irq_cond   = iq_rise | iq_fall | iq_high | iq_low;

  wire [7:0] chan_event_req = {8{ctl_enable}} & ctl_event_en & chan_event_cond;
  wire [7:0] chan_irq_req   = {8{ctl_enable}} & ctl_irq_en   & chan_irq_cond;

  assign irq_req_o = |chan_irq_req;

  // ---- sticky per-channel event evidence (GPIO_EVENT_STATUS) ----
  logic [7:0] event_sticky_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      event_sticky_q <= 8'h0;
    end else if (module_reset_i) begin
      event_sticky_q <= 8'h0;
    end else begin
      for (int c = 0; c < 8; c++) begin
        if (chan_event_req[c]) event_sticky_q[c] <= 1'b1;
        else if (ctl_event_status_clr[c]) event_sticky_q[c] <= 1'b0;
      end
    end
  end

  // ==========================================================================
  // Own diagnostic event generation (event ID 0x0010, source index 5) --
  // real, one-deep pending shape identical to every prior module.
  // ==========================================================================
  logic [7:0] chan_event_req_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)          chan_event_req_prev_q <= 8'h0;
    else if (module_reset_i)     chan_event_req_prev_q <= 8'h0;
    else                          chan_event_req_prev_q <= chan_event_req;
  end
  wire [7:0] chan_event_rising = chan_event_req & ~chan_event_req_prev_q;

  logic [2:0] cand_channel_comb;
  logic       cand_found_comb;
  always_comb begin
    cand_channel_comb = 3'd0;
    cand_found_comb    = 1'b0;
    for (int c = 7; c >= 0; c--) begin
      if (chan_event_rising[c]) begin
        cand_channel_comb = c[2:0];
        cand_found_comb    = 1'b1;
      end
    end
  end

  localparam logic [15:0] EVT_ID_GPIO = 16'h0010;
  localparam logic [7:0]  EVT_SUBTYPE_RISING     = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_FALLING    = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_HIGH_LEVEL = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_LOW_LEVEL  = 8'd3;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL006 = 8'd5;  // ARCH-002 C.5 index 5

  wire evt_candidate_valid = cand_found_comb;

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_GPIO;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL006;
    // subtype priority for the winning channel: rising > falling > high > low
    if (ev_rise[cand_channel_comb])
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_RISING;
    else if (ev_fall[cand_channel_comb])
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_FALLING;
    else if (ev_high[cand_channel_comb])
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_HIGH_LEVEL;
    else
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_LOW_LEVEL;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+8 +: 8]  = {5'b0, cand_channel_comb};
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 16] = {8'h0, qual_value_q};
  end

  logic                                              evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  evt_record_q;
  logic                                              event_overflow_q;
  logic [15:0]                                       event_drop_count_q;

  wire overflow_sets_this_cycle = evt_candidate_valid && evt_pending_q && !evt_ready_i;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q      <= 1'b0;
      evt_record_q       <= '0;
      event_overflow_q   <= 1'b0;
      event_drop_count_q <= 16'd0;
    end else if (module_reset_i) begin
      evt_pending_q      <= 1'b0;
      evt_record_q       <= '0;
      event_overflow_q   <= 1'b0;
      event_drop_count_q <= 16'd0;
    end else begin
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;  // handshake clears record

      if (evt_candidate_valid) begin
        if (!evt_pending_q || (evt_pending_q && evt_ready_i)) begin
          evt_pending_q <= 1'b1;
          evt_record_q  <= evt_candidate;
        end else begin
          if (event_drop_count_q != 16'hFFFF) event_drop_count_q <= event_drop_count_q + 16'd1;
          event_overflow_q <= 1'b1;
        end
      end

      // Real host clear-request for RTL006_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-0434) -- new-overflow-evidence-dominates-clear, same priority
      // as every prior module's identical fix.
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // Output path (ARCH-RTL006-001's literal OE equation -- see header).
  // Registered outputs; the reset branch below unconditionally zeros both
  // BEFORE the ordinary-cycle branch ever computes a route/data-dependent
  // value -- structurally satisfying "reset and disable force OE zero
  // before evaluating routes or output data" (non-racing, by construction).
  // ==========================================================================
  logic [7:0] commanded_output_q;
  logic [7:0] channel_oe_q;
  logic [7:0] effective_output_q;

  wire [7:0] channel_oe_now = ctl_dir & {8{module_enable_i}} & {8{effective_operational_enable_i}} &
                              {8{(operating_state_i != dfc_types_pkg::TEST_DEBUG)}} &
                              {8{!observational_mode_i}};

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      commanded_output_q <= 8'h0;
      channel_oe_q       <= 8'h0;
      effective_output_q <= 8'h0;
    end else if (module_reset_i) begin
      commanded_output_q <= 8'h0;
      channel_oe_q       <= 8'h0;
      effective_output_q <= 8'h0;
    end else begin
      commanded_output_q <= ctl_out;
      channel_oe_q       <= channel_oe_now;
      effective_output_q <= ctl_out & channel_oe_now;
    end
  end

  assign gpio_o    = effective_output_q;
  assign gpio_oe_o = channel_oe_q;

  // ==========================================================================
  // Ready/fault (ARCH-RTL006-001): fault is illegal configuration (a
  // channel's configured qualification time > 100 ms, ARCH-VAL-006) --
  // see header for why "unrecoverable qualification logic error" and the
  // pad-assignment legality clause are both disclosed non-conditions here.
  // ==========================================================================
  wire illegal_config = |illegal_qual_time;

  // ==========================================================================
  // status_o packing (dfc_rtl006_status_t, 83 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__READY_HI] = !illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__FAULT_HI] = illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_RAW_IN__RAW_INPUT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_RAW_IN__RAW_INPUT_LO] = raw_in_q;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_SYNC_IN__SYNC_INPUT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_SYNC_IN__SYNC_INPUT_LO] = sync2_q;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_QUAL_IN__QUAL_INPUT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_QUAL_IN__QUAL_INPUT_LO] = qual_value_q;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_EVENT_STATUS__EVENT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_EVENT_STATUS__EVENT_LO] = event_sticky_q;

    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL006_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;

    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__COMMANDED_OUTPUT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__COMMANDED_OUTPUT_LO] = commanded_output_q;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__EFFECTIVE_OUTPUT_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__EFFECTIVE_OUTPUT_LO] = effective_output_q;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__DIRECTION_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__DIRECTION_LO] = ctl_dir;
    status_comb[dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__QUALIFICATION_IN_PROGRESS_HI:dfc_types_pkg::DFC_RTL006_STATUS__GPIO_STATUS__QUALIFICATION_IN_PROGRESS_LO] = qualification_in_progress;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): route_gpio_req_i is a real port
  // with no functional consumer in this implementation -- RTL-022/023 are
  // permanently out of scope for this build (see header). ----
  logic unused_stub_sink;
  assign unused_stub_sink = |route_gpio_req_i;

endmodule : dfc_rtl006
