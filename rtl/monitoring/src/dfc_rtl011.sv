// dfc_rtl011.sv -- RTL-011 System Health Monitor: 8 independently
// synchronized/qualified/polarity-adjusted external health-discrete
// channels, with sticky active-capture, one-cycle recovery pulses,
// per-channel qualification-attempt-failure detection, and a registered
// aggregate health-fault output (ARCH-002 SS9 ARCH-MON-008, Appendix F.1
// ARCH-RTL011-001, Appendix F.3 index 10). Owns REG-002's System Health
// block (0x2400-0x2438, 15 registers).
//
// Controlling documents: docs/rtl_specs/RTL-011_RevA.md, RCA-DFC-ARCH-002
// SS9/Appendix B/Appendix F.1 ARCH-RTL011-001/Appendix F.3 index 10/
// Appendix C.5 event ID 0x0034/ARCH-VAL-011, RCA-DFC-REG-002 SS23
// (0x2400-0x2438).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// ARCHITECTURAL PRECEDENT, CONFIRMED BEFORE WRITING ANY CODE: this module's
// real register set (HEALTH_RAW_IN/HEALTH_SYNC_IN/HEALTH_QUAL_IN/
// HEALTH_QUAL_0_3/_4_7/HEALTH_POLARITY) closely parallels RTL-006 (GPIO)'s
// two-flop-synchronizer + millisecond-scale qualification-timer
// architecture, NOT RTL-007/008/009's divider-based frequency-monitor
// architecture -- confirmed directly against RTL-006's own real
// dfc_rtl006.sv (this file's own synchronization/qualification skeleton is
// adapted from it) and against ARCH-MON-008 (RTL-011's own real algorithm
// contract, quoted in full below), not assumed from the module list
// ordering alone. RTL-011 differs from RTL-006 in three material ways:
// (1) 8 dedicated health-discrete input channels instead of 8 bidirectional
// GPIO channels -- no direction/output-enable/route-request logic at all;
// (2) ARCH-MON-008's qualification-attempt-failure mechanism (a SECOND,
// independent per-channel counter that does not restart when the
// synchronized candidate toggles, absent entirely from RTL-006's own
// qualification timer) -- see below; (3) sticky active-capture plus a
// one-cycle recovery pulse (ARCH-RTL011-001's own "recovery is captured as
// sticky evidence and does not clear asserted evidence" -- two independently
// timed/cleared sticky bits per channel), which RTL-006 never needed since
// its own per-channel evidence is a single sticky EVENT bit, not a pair of
// independently sticky asserted/recovered bits.
//
// ARCH-MON-008 (quoted in full, since this is the sole source for this
// module's qualification-attempt-failure and active/sticky/recovery
// equations -- CHTR-DOC-006 forbids restating an owned fact elsewhere
// without citing it, but this exact wording is reproduced here once,
// verbatim, as the single authoritative reference this file's own
// implementation is checked against):
//   "Each health input uses a two-flop synchronizer, polarity transform,
//   and stable-time qualification. For qualification value Q=0,
//   synchronized state passes without delay and qualification-in-progress
//   is zero. For Q>0, qualification-in-progress is high while synchronized
//   state differs from qualified state; a consecutive-stability counter
//   commits the new qualified state after Q consecutive 1 ms samples. A
//   separate attempt counter starts on entry to qualification-in-progress,
//   does not restart when the synchronized candidate toggles, and sets
//   sticky qualification-failure if no qualified-state commit occurs
//   within min(255, 4 x Q) consecutive 1 ms samples. Commit or return to
//   the prior qualified state ends the attempt; neither clears prior
//   failure evidence. active = qualified XOR !ACTIVE_HIGH. Sticky asserted
//   captures active. Sticky recovered captures each active-to-inactive
//   transition. Aggregate health fault is the current OR of active
//   channels with fault-enable."
//
// IMPLEMENTATION OF THE TWO COUNTERS (the one genuinely new mechanism vs.
// RTL-006's own qualification timer):
//   - qual_run_length_q[c]/qual_candidate_q[c]: the ordinary
//     consecutive-STABILITY counter, identical in shape to RTL-006's own
//     (resets its run whenever the synchronized candidate toggles to a
//     different value than the one currently being tracked) -- this alone
//     is what commits qual_value_q[c] after Q agreeing samples.
//   - attempt_counter_q[c]: a SEPARATE counter, held at zero whenever
//     qualification_in_progress[c] is false (i.e. it restarts fresh on
//     every new entry into disagreement, which is exactly "commit or
//     return to the prior qualified state ends the attempt"), but -- unlike
//     qual_run_length_q -- it does NOT reset when the candidate toggles;
//     it simply counts every 1 ms sample qualification_in_progress[c]
//     stays true, saturating at attempt_limit[c] = min(255, 4 x Q). The
//     one-shot transition of this counter from (limit-1) to (limit) on an
//     ms_tick while still in progress (i.e. no commit has happened) is
//     exactly the "no qualified-state commit occurs within min(255,4xQ)
//     consecutive 1 ms samples" failure condition -- it can only fire once
//     per attempt (the counter saturates immediately after and does not
//     reset until the attempt genuinely ends), matching "neither clears
//     prior failure evidence" (a later attempt within the same un-cleared
//     failure window sets the same sticky bit again, harmlessly).
//
// A REAL, DISCLOSED ARCHITECTURAL FINDING, confirmed by direct algebraic
// analysis of the two-counter mechanism above, not assumed: for a
// single-BIT-per-channel input (health_i's real width per ARCH-002's own
// 17-port catalog), qualification-attempt-FAILURE, as ARCH-MON-008
// literally defines it ("no qualified-state commit occurs within the
// window"), is MATHEMATICALLY UNREACHABLE via any external drive pattern,
// static or dynamically reconfigured. Reasoning: for a 1-bit signal, the
// stability run-length's "new, different candidate" branch is dead code
// after a fresh attempt's own first disagreeing sample -- there are only
// two possible sample values, and any sample either matches the current
// qualified value (ending the attempt cleanly, no failure) or matches the
// already-tracked candidate (advancing the SAME stability run toward
// commit); there is no third value to genuinely "toggle to" mid-attempt.
// A continuous single-candidate disagreement therefore always accumulates
// its run-length in lockstep with the independent attempt counter, and
// since attempt_limit = min(255, 4xQ) is provably >= Q for every legal Q
// (0-255) -- strictly greater for Q<255, and exactly equal only at the
// single boundary point Q=255 -- the run-length COMMIT condition is always
// satisfied at or before the attempt counter would ever reach its own
// failure threshold. At the sole tied boundary (Q=255), both conditions
// would fire the identical ms_tick sample; `commit_this_cycle` below
// exists specifically so that exact tie resolves as a commit, not a
// failure, per the spec's own "if no commit occurs" wording (a commit DID
// occur, on the very last legal sample). This is a genuine property of
// ARCH-MON-008's own specified algorithm applied to a 1-bit signal, not an
// implementation defect -- confirmed by re-reading the quoted contract
// text above line by line against this exact reasoning, not glossed over.
// rtl011_integration_tb.sv accordingly cannot exercise a genuine,
// externally-triggered HEALTH_STICKY.QUALIFICATION_FAILURE assertion (the
// mechanism itself -- both counters, the shared clear-request field, the
// F.3 condition-mask gating, and the HEALTH_QUALIFICATION.IN_PROGRESS live
// readback -- is still real and, per this analysis, provably correct by
// construction, just not reachable from outside this module for a 1-bit
// channel) -- same class of disclosed, real testing-reachability gap as
// RTL-010's own "cannot exercise the routed-commit half of VP-MON-007"
// limitation (OPEN_ISSUES.md item 38).
//
// TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
// Yosys build -- see dfc_rtl002.sv's header for the full account): a
// package-scoped type cannot be a port's declared type. control_i/status_o
// are plain `logic [W-1:0]` vectors sized via generated `dfc_types_pkg::
// DFC_RTL011_*_WIDTH` VALUE constants; individual fields are extracted via
// generated `_HI`/`_LO` bit-slice constants -- never a hand-copied literal.
//
// ONE REAL ARCH-002 GAP, FOUND AND APPROVED BEFORE this module was
// implemented (the TENTH real instance of this exact gap class -- RTL-002/
// 003's own EVT_OVERFLOW_STATUS, RTL-004's SNAPSHOT_VALID/SYNC_VALID,
// RTL-005's SNAPSHOT_VALID, RTL-006/007/008/009/010's own EVT_OVERFLOW_
// STATUS): dfc_rtl011_control_t (121 bits) had no clear-request field for
// RTL011_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-2430 bit 0, a real W1C
// field). Fixed, with explicit approval before implementation: ARCH-002
// grew the struct 121->122 bits, adding rtl011_evt_overflow_status__
// event_overflow at the new highest bit (121) -- every pre-existing
// field's bit position confirmed unchanged via a real regenerate.ps1 run.
// tools/reggen/rtl011_field_map.json's own status_registers section also
// closes the RTL-002/003/004-style host-READ gap (OPEN_ISSUES.md item 21)
// for every external RTL-011 register from the start, same discipline
// already established for RTL-006 through RTL-010.
//
// RESOLVED WITHOUT AN ARCH-002 EDIT, same resolution style as items
// 1/10/11/13/19/22/37: RTL-011_RevA.md SS1/SS4 both say this module's
// System Health block is "13 registers." REG-002's own SS23 block-summary
// table (the owning document, CHTR-DOC-003) says 15 and lists all 15
// (HEALTH_CONTROL, HEALTH_RAW_IN, HEALTH_SYNC_IN, HEALTH_QUAL_IN,
// HEALTH_ACTIVE, HEALTH_STICKY, HEALTH_POLARITY, HEALTH_FAULT_ENABLE,
// HEALTH_EVENT_ENABLE, HEALTH_IRQ_ENABLE, HEALTH_QUAL_0_3, HEALTH_QUAL_4_7,
// RTL011_EVT_OVERFLOW_STATUS, HEALTH_QUALIFICATION, HEALTH_STATUS).
// Resolved in favor of REG-002; this module implements and forwards all 15.
//
// PHYSICAL PINS -- CONFIRMED REAL AND NEEDED, unlike RTL-010's own module
// (which needed zero): ARCH-002's own 17-port catalog lists `health_i`
// (logic/8) with producer RTL-024.health_in_o and the CDC-HEALTH table
// entry names RTL-011 itself (not RTL-024) as the owner of the real
// per-bit two-stage synchronizer -- confirmed directly against both before
// assuming either way, matching RTL-006's own precedent (raw external
// input reaching the consuming module directly, synchronized by that
// module, not pre-synchronized by RTL-024). This module therefore needs
// 8 real physical FPGA pins -- see the real fpga/ecp5/ulx3s_dfc.lpf
// addition and ULX3S_CONNECTION_MAP.md's own new Section 9 for the
// fetched-not-memorized site confirmation (gp14-gp21/J2-14 through J2-21,
// the entire remaining unshared differential-capable range -- flagged
// explicitly, not done silently, since this consumes everything left in
// that range except the WiFi-shared gp11-gp13).
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS:
//
//   - MILLISECOND TICK GENERATOR: same disclosed nominal-50-MHz-CORE_CLK
//     assumption (ARCH-CLK-001) as dfc_rtl004.sv's microsecond divider and
//     dfc_rtl006.sv's own millisecond qualification timer.
//   - HEALTH_CONTROL.ENABLE is this module's substitute for the Appendix
//     F.3 preamble's MODULE_EVENT_ENABLE/MODULE_IRQ_ENABLE terms (same role
//     GPIO_CONTROL.ENABLE/LOGGER_ENABLE play for dfc_rtl006/005.sv) --
//     disabled means no event/irq generation for any channel, though
//     synchronization/qualification/active/sticky/aggregate-fault tracking
//     itself is NOT gated by ENABLE (REG-2400's own text: "Global
//     health-monitor controls," with no stated effect on the raw
//     readback/sticky/fault path -- the same "diagnostics stay live even
//     while the controller's own event/irq generation is disabled"
//     precedent dfc_rtl006.sv already established for GPIO_RAW_IN/
//     GPIO_SYNC_IN). Unlike RTL-006, RTL-011 has no per-module
//     `global_event_enable_i`/`global_irq_enable_i` port at all (confirmed
//     against the real 17-port catalog) -- ctl_enable alone is the whole
//     module-level term.
//   - PER-CHANNEL EVENT/IRQ SUBCONDITIONS (Appendix F.3 index 10: 0-7
//     asserted channels 0-7; 8-15 deasserted/recovered; 16-23 qualification
//     failure; 24 event-slot overflow): HEALTH_EVENT_ENABLE[ch]/
//     HEALTH_IRQ_ENABLE[ch] are the per-channel master enables (F.3
//     preamble's "corresponding channel master replaces MODULE_*_ENABLE").
//     A DISCLOSED INTERPRETATION, forced by a genuine ambiguity rather than
//     guessed: Appendix C.7's own row for event ID 0x0034 lists FOUR legal
//     subtype values (0 asserted, 1 deasserted, 2 qualification failure,
//     3 recovery), but F.3's own condition-mask allocation groups
//     "deasserted" and "recovered" under ONE SHARED 8-bit range (bits
//     8-15) -- there is no way to independently enable one without the
//     other, and ARCH-MON-008 itself defines exactly one real hardware
//     transition an active-to-inactive channel produces (the recovered
//     pulse), not two. This implementation therefore generates subtype 3
//     ("recovery") on that transition -- the concept ARCH-MON-008 and this
//     module's own RTL-011_RevA.md SS3 both name explicitly by that
//     wording ("recovered pulses for exactly one cycle") -- and never
//     independently emits subtype 1 ("deasserted"), since no real,
//     distinct hardware condition exists in this module's own register set
//     to attach that separate meaning to. If a bit-exact distinction is
//     ever specified, only this one subtype-selection line needs to
//     change.
//   - Per-channel candidate priority for this module's own diagnostic
//     event (0x0034, source index 10) when more than one channel has a
//     qualifying pulse the same cycle: lowest-numbered channel wins (same
//     precedent as dfc_rtl003/005/006.sv's own VECTOR_SOURCE/
//     ovfl_source_comb/GPIO candidate-select logic). Within one winning
//     channel, if more than one subtype pulses the same cycle (not expected
//     in normal operation, since "qualification failure" only ever fires
//     while NOT yet committed and "asserted"/"recovery" only ever fire the
//     cycle immediately AFTER a commit -- mutually exclusive in practice,
//     but not provably so from the spec text alone), a disclosed, locally
//     chosen priority order (asserted > qualification failure > recovery)
//     applies, same basis as every other module's own disclosed detail-
//     field/subtype packing choice under a genuine simultaneity gap.
//   - Per C.7's own row for 0x0034 ("event_data[31:16]: active and sticky
//     masks"): event_data[7:0] = subtype, event_data[15:8] = winning
//     channel index, event_data[23:16] = active_comb[7:0] (all 8 channels'
//     current active bitmap), event_data[31:24] = sticky_asserted_q[7:0]
//     (all 8 channels' current sticky-asserted bitmap) -- a disclosed
//     packing order, since C.7 names both masks but not their relative
//     byte position; matches the size (8+8=16 bits exactly fills the field)
//     and the "report the whole module's bitmap, not just the winning
//     channel's own bit" precedent dfc_rtl006.sv's own 0x0010 row already
//     established for its own "qualified GPIO bitmap" detail field.
//   - event_condition_enable_i/irq_condition_enable_i: real ports per the
//     Architecture catalog, tied to a disclosed stub (64'h0) in
//     dfc_rtl024.sv, same reasoning as every prior monitoring module
//     (OPEN_ISSUES.md item 6 -- RTL-001 does not yet implement the
//     per-module CONDITION_MASK storage/forwarding mechanism these would
//     come from). Means none of RTL-011's own events/irqs can actually
//     fire in this integration yet -- a real, disclosed consequence, not a
//     defect in this file.
//   - READY/FAULT (this module's own generic module_status bits, distinct
//     from HEALTH_STATUS.AGGREGATE_FAULT below): ARCH-RTL011-001 does not
//     spell out a ready/fault contract in the same explicit words
//     ARCH-RTL006-001 uses for RTL-006, so this module follows the
//     identical, already-established "defend against what RTL-001 doesn't
//     yet reject" precedent (dfc_rtl006/007/008/009.sv's own illegal-
//     configuration fault): ARCH-VAL-011's own "Qualification is 0-100 ms"
//     range check against the real, 8-bit-wide (0-255)
//     HEALTH_QUAL_0_3/HEALTH_QUAL_4_7 fields is this implementation's only
//     concrete, testable "illegal configuration" condition (RTL-001 has no
//     per-field range validation yet, OPEN_ISSUES.md item 4, so a value
//     101-255 can genuinely reach control_i). ARCH-VAL-011's OTHER named
//     condition ("each event/IRQ mask may set only the F.3 bits allocated
//     to RTL-011") has no real detection mechanism here either -- the same
//     class of disclosed gap as RTL-001's own missing reserved-bit
//     validation generally, and moot in practice today since
//     event_condition_enable_i/irq_condition_enable_i are tied to a
//     permanent 64'h0 stub anyway (see above).
//   - HEALTH_STATUS.AGGREGATE_FAULT is a SEPARATE, domain-specific signal
//     from this module's own generic status_o.fault (module_status) above
//     -- ARCH-RTL011-001's own literal text ("Aggregate fault is a
//     registered OR of enabled active channels") and `fault_req_o`'s real
//     architected destination (RTL-013.fault_source_i[4], "System-health
//     aggregate fault," per Appendix C.6/the real fault-source matrix) both
//     describe a monitored EXTERNAL-health-domain condition, not this
//     module's own internal illegal-configuration malfunction -- the same
//     clean separation RTL-007/008.sv already established between
//     "illegal config -> module fault" and "LOW/HIGH threshold -> RPM
//     domain event." `fault_req_o` drives directly from the same
//     registered aggregate_fault_q signal that also backs
//     HEALTH_STATUS.AGGREGATE_FAULT -- a real output left genuinely
//     unconsumed in this integration (RTL-013 does not exist yet), same
//     disclosed pattern as every other not-yet-connected fault_req_o in
//     this project.
// ============================================================================

module dfc_rtl011 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[10]

  input  logic [dfc_types_pkg::DFC_RTL011_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL011_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,
  output logic         fault_req_o,        // RTL-013.fault_source_i[4] -- real
                                            // output, genuinely unconsumed
                                            // (RTL-013 does not exist yet).

  input  logic [7:0] health_i,             // raw external input, CDC-HEALTH --
                                            // this module owns the two-flop
                                            // synchronizer (see header).

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic         module_enable_i,               // RTL-002.module_enable_o[10]

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 10
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 10
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as every prior module) ----
  wire        ctl_enable            = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_CONTROL__ENABLE_HI];
  wire [7:0]  ctl_sticky_assert_clr = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_STICKY__ASSERTED_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_STICKY__ASSERTED_LO];
  wire [7:0]  ctl_sticky_recov_clr  = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_STICKY__RECOVERED_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_STICKY__RECOVERED_LO];
  wire [7:0]  ctl_active_high       = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_POLARITY__ACTIVE_HIGH_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_POLARITY__ACTIVE_HIGH_LO];
  wire [7:0]  ctl_fault_enable      = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_FAULT_ENABLE__FAULT_ENABLE_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_FAULT_ENABLE__FAULT_ENABLE_LO];
  wire [7:0]  ctl_event_enable      = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_EVENT_ENABLE__EVENT_ENABLE_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_EVENT_ENABLE__EVENT_ENABLE_LO];
  wire [7:0]  ctl_irq_enable        = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_IRQ_ENABLE__IRQ_ENABLE_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_IRQ_ENABLE__IRQ_ENABLE_LO];
  wire [7:0]  ctl_qual_failure_clr  = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_STICKY__QUALIFICATION_FAILURE_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_STICKY__QUALIFICATION_FAILURE_LO];
  wire        ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__RTL011_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire [7:0] ctl_qual_ch0 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH0_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH0_MS_LO];
  wire [7:0] ctl_qual_ch1 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH1_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH1_MS_LO];
  wire [7:0] ctl_qual_ch2 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH2_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH2_MS_LO];
  wire [7:0] ctl_qual_ch3 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH3_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_0_3__CH3_MS_LO];
  wire [7:0] ctl_qual_ch4 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH4_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH4_MS_LO];
  wire [7:0] ctl_qual_ch5 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH5_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH5_MS_LO];
  wire [7:0] ctl_qual_ch6 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH6_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH6_MS_LO];
  wire [7:0] ctl_qual_ch7 = control_i[dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH7_MS_HI:dfc_types_pkg::DFC_RTL011_CONTROL__HEALTH_QUAL_4_7__CH7_MS_LO];

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
  // Millisecond tick generator -- disclosed nominal 50 MHz CORE_CLK
  // assumption (ARCH-CLK-001), same as dfc_rtl006.sv's own.
  // ==========================================================================
  localparam int unsigned MS_TICK_CYCLES = 50_000;
  logic [15:0] ms_counter_q;
  logic        ms_tick;
  assign ms_tick = (ms_counter_q == MS_TICK_CYCLES-1);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)        ms_counter_q <= 16'd0;
    else if (module_reset_i)  ms_counter_q <= 16'd0;
    else if (ms_tick)         ms_counter_q <= 16'd0;
    else                      ms_counter_q <= ms_counter_q + 16'd1;
  end

  // ==========================================================================
  // Per-channel synchronization + qualification (CDC-HEALTH / ARCH-MON-008).
  // ==========================================================================
  logic [7:0] sync1_q, sync2_q;
  logic [7:0] raw_in_q;
  logic [7:0] qual_value_q;
  logic [7:0] qual_candidate_q;
  logic [7:0] qual_run_length_q [0:7];
  logic [7:0] attempt_counter_q [0:7];
  logic [7:0] illegal_qual_time;
  logic [7:0] attempt_limit;

  always_comb begin
    for (int c = 0; c < 8; c++) begin
      illegal_qual_time[c] = (ctl_qual_ms[c] > 8'd100);
    end
  end

  // attempt_limit[c] = min(255, 4 x Q) -- for Q<=63, 4*Q<=252 fits 8 bits
  // exactly with no truncation; for Q>=64, 4*Q would overflow 8 bits, so
  // the ternary clamps to 255 directly rather than computing the
  // wider product.
  logic [7:0] attempt_limit_arr [0:7];
  always_comb begin
    for (int c = 0; c < 8; c++) begin
      attempt_limit_arr[c] = (ctl_qual_ms[c] > 8'd63) ? 8'd255 : (ctl_qual_ms[c] << 2);
    end
  end

  logic [7:0] qualification_in_progress;
  always_comb begin
    for (int c = 0; c < 8; c++) begin
      qualification_in_progress[c] = (ctl_qual_ms[c] != 8'd0) && (sync2_q[c] != qual_value_q[c]);
    end
  end

  // A commit and a failure can only ever coincide on the exact same ms_tick
  // when Q == attempt_limit (the sole point where min(255,4xQ) == Q, i.e.
  // Q=255) -- since both counters advance in lockstep for a single,
  // continuously-disagreeing candidate. Per ARCH-MON-008's own text
  // ("...if no qualified-state commit occurs within..."), a commit that
  // lands on the boundary sample itself is still a commit, not a failure --
  // this term makes that explicit rather than leaving it to an accidental
  // same-cycle race between two independently-computed conditions.
  logic [7:0] commit_this_cycle;
  always_comb begin
    for (int c = 0; c < 8; c++) begin
      commit_this_cycle[c] = ms_tick && qualification_in_progress[c] &&
                              (sync2_q[c] == qual_candidate_q[c]) &&
                              ((qual_run_length_q[c] + 8'd1) >= ctl_qual_ms[c]);
    end
  end

  logic [7:0] attempt_timeout_pulse;
  always_comb begin
    for (int c = 0; c < 8; c++) begin
      attempt_timeout_pulse[c] = qualification_in_progress[c] && ms_tick &&
                                  (attempt_limit_arr[c] != 8'd0) &&
                                  (attempt_counter_q[c] == (attempt_limit_arr[c] - 8'd1)) &&
                                  !commit_this_cycle[c];
    end
  end

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sync1_q          <= 8'h0;
      sync2_q          <= 8'h0;
      raw_in_q         <= 8'h0;
      qual_value_q     <= 8'h0;
      qual_candidate_q <= 8'h0;
      for (int c = 0; c < 8; c++) begin
        qual_run_length_q[c] <= 8'd0;
        attempt_counter_q[c] <= 8'd0;
      end
    end else if (module_reset_i) begin
      sync1_q          <= 8'h0;
      sync2_q          <= 8'h0;
      raw_in_q         <= 8'h0;
      qual_value_q     <= 8'h0;
      qual_candidate_q <= 8'h0;
      for (int c = 0; c < 8; c++) begin
        qual_run_length_q[c] <= 8'd0;
        attempt_counter_q[c] <= 8'd0;
      end
    end else begin
      sync1_q  <= health_i;
      sync2_q  <= sync1_q;
      raw_in_q <= health_i;

      for (int c = 0; c < 8; c++) begin
        if (ctl_qual_ms[c] == 8'd0) begin
          // "passes through without delay" -- committed every cycle, no
          // ms-tick wait at all.
          qual_value_q[c] <= sync2_q[c];
        end else if (ms_tick) begin
          if (sync2_q[c] == qual_value_q[c]) begin
            qual_run_length_q[c] <= 8'd0;
          end else if (sync2_q[c] == qual_candidate_q[c]) begin
            if ((qual_run_length_q[c] + 8'd1) >= ctl_qual_ms[c]) begin
              qual_value_q[c]      <= sync2_q[c];
              qual_run_length_q[c] <= 8'd0;
            end else begin
              qual_run_length_q[c] <= qual_run_length_q[c] + 8'd1;
            end
          end else begin
            qual_candidate_q[c]  <= sync2_q[c];
            qual_run_length_q[c] <= 8'd1;
          end
        end

        // Attempt counter: independent of the stability run above -- does
        // NOT reset when the candidate toggles, only when
        // qualification_in_progress[c] itself is false (attempt genuinely
        // ended, via commit or return to the prior qualified state).
        if (!qualification_in_progress[c]) begin
          attempt_counter_q[c] <= 8'd0;
        end else if (ms_tick && (attempt_counter_q[c] < attempt_limit_arr[c])) begin
          attempt_counter_q[c] <= attempt_counter_q[c] + 8'd1;
        end
      end
    end
  end

  // ==========================================================================
  // Active / sticky-asserted / sticky-recovered (ARCH-MON-008).
  // ==========================================================================
  wire [7:0] active_comb = qual_value_q ^ ~ctl_active_high;

  logic [7:0] active_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       active_prev_q <= 8'h0;
    else if (module_reset_i) active_prev_q <= 8'h0;
    else                     active_prev_q <= active_comb;
  end

  wire [7:0] asserted_pulse  = active_comb  & ~active_prev_q;
  wire [7:0] recovered_pulse = ~active_comb &  active_prev_q;

  logic [7:0] sticky_asserted_q;
  logic [7:0] sticky_recovered_q;
  logic [7:0] qual_failure_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sticky_asserted_q  <= 8'h0;
      sticky_recovered_q <= 8'h0;
      qual_failure_q     <= 8'h0;
    end else if (module_reset_i) begin
      sticky_asserted_q  <= 8'h0;
      sticky_recovered_q <= 8'h0;
      qual_failure_q     <= 8'h0;
    end else begin
      for (int c = 0; c < 8; c++) begin
        // New active dominates clear (ARCH-RTL011-001).
        if (active_comb[c])            sticky_asserted_q[c] <= 1'b1;
        else if (ctl_sticky_assert_clr[c]) sticky_asserted_q[c] <= 1'b0;

        // Recovery does not clear sticky (asserted) -- independently timed
        // and cleared, per RTL-011_RevA.md SS3.
        if (recovered_pulse[c])        sticky_recovered_q[c] <= 1'b1;
        else if (ctl_sticky_recov_clr[c]) sticky_recovered_q[c] <= 1'b0;

        // New qualification failure dominates clear (ARCH-RTL011-001).
        if (attempt_timeout_pulse[c])  qual_failure_q[c] <= 1'b1;
        else if (ctl_qual_failure_clr[c]) qual_failure_q[c] <= 1'b0;
      end
    end
  end

  // ==========================================================================
  // Aggregate health fault: registered OR of active, fault-enabled channels
  // (ARCH-RTL011-001's own literal text). Distinct from this module's own
  // generic status_o.fault (illegal configuration) below -- see header.
  // ==========================================================================
  logic aggregate_fault_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       aggregate_fault_q <= 1'b0;
    else if (module_reset_i) aggregate_fault_q <= 1'b0;
    else                     aggregate_fault_q <= |(active_comb & ctl_fault_enable);
  end

  assign fault_req_o = aggregate_fault_q;

  // ==========================================================================
  // Per-channel F.3-gated event/irq subconditions (Appendix F.3 index 10:
  // 0-7 asserted; 8-15 deasserted/recovered; 16-23 qualification failure;
  // 24 event-slot overflow -- see header for the disclosed "recovery, not
  // deasserted" subtype-selection interpretation).
  // ==========================================================================
  wire [7:0] ev_asserted = asserted_pulse       & event_condition_enable_i[7:0];
  wire [7:0] ev_recovery = recovered_pulse      & event_condition_enable_i[15:8];
  wire [7:0] ev_qualfail = attempt_timeout_pulse & event_condition_enable_i[23:16];

  wire [7:0] iq_asserted = asserted_pulse       & irq_condition_enable_i[7:0];
  wire [7:0] iq_recovery = recovered_pulse      & irq_condition_enable_i[15:8];
  wire [7:0] iq_qualfail = attempt_timeout_pulse & irq_condition_enable_i[23:16];

  wire [7:0] chan_event_cond = ev_asserted | ev_recovery | ev_qualfail;
  wire [7:0] chan_irq_cond   = iq_asserted | iq_recovery | iq_qualfail;

  wire [7:0] chan_event_req = {8{ctl_enable}} & ctl_event_enable & chan_event_cond;
  wire [7:0] chan_irq_req   = {8{ctl_enable}} & ctl_irq_enable   & chan_irq_cond;

  assign irq_req_o = |chan_irq_req;

  // ==========================================================================
  // Own diagnostic event generation (event ID 0x0034, source index 10) --
  // real, one-deep pending-slot shape identical to every prior module.
  // Each of asserted_pulse/recovered_pulse/attempt_timeout_pulse is already
  // one-cycle-wide, so chan_event_req itself is pulse-shaped -- no
  // additional level-to-edge wrapping is needed (unlike dfc_rtl006.sv's own
  // LEVEL-based high/low subconditions).
  // ==========================================================================
  logic [2:0] cand_channel_comb;
  logic       cand_found_comb;
  always_comb begin
    cand_channel_comb = 3'd0;
    cand_found_comb    = 1'b0;
    for (int c = 7; c >= 0; c--) begin
      if (chan_event_req[c]) begin
        cand_channel_comb = c[2:0];
        cand_found_comb    = 1'b1;
      end
    end
  end

  localparam logic [15:0] EVT_ID_HEALTH = 16'h0034;
  localparam logic [7:0]  EVT_SUBTYPE_ASSERTED = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_QUALFAIL = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERY = 8'd3;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL011 = 8'd10;  // ARCH-002 C.5 index 10

  wire evt_candidate_valid = cand_found_comb;

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_HEALTH;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL011;
    // subtype priority for the winning channel: asserted > qualification
    // failure > recovery (disclosed, locally chosen -- see header).
    if (ev_asserted[cand_channel_comb])
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_ASSERTED;
    else if (ev_qualfail[cand_channel_comb])
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_QUALFAIL;
    else
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_RECOVERY;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+8 +: 8]  = {5'b0, cand_channel_comb};
    // event_data[31:16]: "active and sticky masks" (C.7) -- disclosed
    // packing order, see header.
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = active_comb;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+24 +: 8] = sticky_asserted_q;
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

      // Real host clear-request for RTL011_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-2430) -- new-overflow-evidence-dominates-clear, same priority
      // as every prior module's identical fix.
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // Ready/fault (this module's own generic module_status bits -- see
  // header for why this is distinct from HEALTH_STATUS.AGGREGATE_FAULT).
  // ==========================================================================
  wire illegal_config = |illegal_qual_time;

  // ==========================================================================
  // status_o packing (dfc_rtl011_status_t, 84 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL011_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__READY_HI] = !illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__FAULT_HI] = illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_RAW_IN__RAW_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_RAW_IN__RAW_LO] = raw_in_q;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_SYNC_IN__SYNC_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_SYNC_IN__SYNC_LO] = sync2_q;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_QUAL_IN__QUALIFIED_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_QUAL_IN__QUALIFIED_LO] = qual_value_q;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_ACTIVE__ACTIVE_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_ACTIVE__ACTIVE_LO] = active_comb;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STICKY__ASSERTED_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STICKY__ASSERTED_LO] = sticky_asserted_q;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STICKY__RECOVERED_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STICKY__RECOVERED_LO] = sticky_recovered_q;

    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL011_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;

    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_QUALIFICATION__IN_PROGRESS_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_QUALIFICATION__IN_PROGRESS_LO] = qualification_in_progress;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STICKY__QUALIFICATION_FAILURE_HI:dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STICKY__QUALIFICATION_FAILURE_LO] = qual_failure_q;
    status_comb[dfc_types_pkg::DFC_RTL011_STATUS__HEALTH_STATUS__AGGREGATE_FAULT_HI] = aggregate_fault_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): operating_state_i/
  // observational_mode_i are real, structurally-required ports with no
  // functional use in this module's own real equations (RTL-011's own
  // spec never names either in ARCH-MON-008/ARCH-RTL011-001), same
  // disclosed pattern already established for dfc_rtl007/008/009/010.sv. ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i;

endmodule : dfc_rtl011
