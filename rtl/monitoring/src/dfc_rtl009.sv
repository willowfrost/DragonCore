// dfc_rtl009.sv -- RTL-009 Pulse/Frequency Measurement: two fully
// independent edge-input Q17.15 frequency channels, sharing ARCH-MON-002's
// edge-qualification/mode-selection algorithm with RTL-007/008 but using
// ARCH-MON-004's Q17.15 arithmetic in place of RPM arithmetic (ARCH-002
// SS9 ARCH-MOD-009/ARCH-MON-002/004/005, Appendix F.1 ARCH-RTL009-001,
// Appendix F.3 index 8). Owns REG-002's Pulse/Frequency block
// (0x2200-0x22FF, 19 registers). Third module in the Monitoring domain.
//
// Controlling documents: docs/rtl_specs/RTL-009_RevA.md, RCA-DFC-ARCH-002
// SS9/Appendix B.5/Appendix F.1 ARCH-RTL009-001/Appendix F.3 index 8/
// Appendix C.5/C.7 event ID 0x0032/ARCH-VAL-009, RCA-DFC-REG-002 SS21
// (0x2200-0x2254).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// TASK-DIRECTED DESIGN CHOICE, MADE FROM THE START (not rediscovered a
// third time): OPEN_ISSUES.md item 31 explicitly warns that RTL-007's own
// real timing margin (52.87 MHz) was not enough headroom to absorb RTL-008
// duplicating its identical edge-qualification comparator and divider
// multiply -- three sequential real fixes were needed (equality+sticky-bit
// comparator instead of a live magnitude compare; explicit multiply-input
// muxing; pipelining the multiply into its own MEAS_MULT register-to-
// register stage) before both modules closed timing together (55.84 MHz).
// RTL-009 adds TWO MORE independent instances of this same architecture in
// a single module -- the confirmed-working, already-pipelined shape from
// dfc_rtl007.sv/dfc_rtl008.sv is used for BOTH channels from the very first
// line of this file, not the original fragile combinational-comparator/
// direct-multiply-into-register shape those two files started with and had
// to fix under real timing pressure.
//
// ONE REAL ARCH-002 GAP, FOUND AND FIXED BEFORE this module was implemented,
// APPROVED BEFORE IMPLEMENTATION -- explicitly anticipated by this project's
// own task instructions given the seven prior real instances of this exact
// gap class (RTL-002/003's EVT_OVERFLOW_STATUS, RTL-004's SNAPSHOT_VALID/
// SYNC_VALID, RTL-005's SNAPSHOT_VALID, RTL-006/007/008's EVT_OVERFLOW_
// STATUS):
//   dfc_rtl009_control_t (334 bits) had no clear-request field for
//   RTL009_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x2250 bit 0, a real
//   W1C field). Fixed: ARCH-002 grew the struct 334->335 bits, adding
//   rtl009_evt_overflow_status__event_overflow at the new highest bit
//   (334) -- every pre-existing field's bit position confirmed unchanged
//   via a real regenerate.ps1 run (every _HI/_LO constant below bit 334 is
//   byte-identical to the pre-growth layout).
//
// A SECOND CHECK, PERFORMED BEFORE IMPLEMENTATION (per OPEN_ISSUES.md items
// 21/23's own lesson): RTL009_EVT_OVERFLOW_STATUS's real host-READ path is
// wired from the start via tools/reggen/rtl009_field_map.json's own
// status_registers section (mapped onto this struct's generic
// event_overflow/event_drop_count fields), NOT reproducing the still-open
// RTL-002/003/004 readback gap (OPEN_ISSUES.md item 21) -- same discipline
// already established for RTL-006/007/008.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (ARCH-MOD-009, ARCH-MON-002/004/
// 005, ARCH-RTL009-001, ARCH-VAL-009, Appendix C.7 event 0x0032):
//
//   - TWO FULLY INDEPENDENT CHANNELS, NOT TIME-MULTIPLEXED (ARCH-RTL009-001:
//     "each channel independently applies ARCH-MON-002, ARCH-MON-004, and
//     ARCH-MON-005. Same-cycle accepted edges update both channel states
//     independently"): every register/FSM below is duplicated verbatim as
//     two separate, independently-clocked instances (ch0_*/ch1_* signal
//     prefixes) -- no shared divider, no shared CDC synchronizer, no shared
//     mode-selection state. This is the literal reading of "same-cycle
//     accepted edges update both channel states independently": a shared/
//     time-multiplexed divider could not guarantee that.
//   - SINGLE PHYSICAL PORT, TWO LOGICAL CHANNELS: `pulse_i[1:0]` is one
//     2-bit port per the Architecture catalog (RTL-009_RevA.md SS2: "both
//     channels share this one 2-bit port ... there is no separate physical
//     pin per channel"). `pulse_i[0]` feeds channel 0's own CDC-PULSE
//     synchronizer; `pulse_i[1]` feeds channel 1's own, entirely independent
//     synchronizer instance -- same two-flop idiom as dfc_rtl007.sv/
//     dfc_rtl008.sv, just applied to two bits of one port instead of two
//     separate single-bit ports.
//   - EDGE QUALIFICATION / MODE SELECTION (ARCH-MON-002): identical
//     equations and identical toolchain-driven fixes as dfc_rtl007.sv/
//     dfc_rtl008.sv (see those files' own headers for the full account) --
//     applied independently per channel from the start: the sticky
//     min_edge_met_q latch (replacing a live wide magnitude compare against
//     a variable threshold), cycles_since_accepted_q reset to 1 (not 0) on
//     acceptance and always read LIVE (never through a registered
//     intermediate copy read the same cycle it updates), and the 2-deep
//     mode-history hysteresis shift register. OPEN_ISSUES.md items 26/27/30
//     (real, hard-won testbench-authoring and RTL lessons from RTL-007/008's
//     own bring-up) are applied here from the start, not rediscovered.
//   - Q17.15 ARITHMETIC (ARCH-MON-004) -- the one thing genuinely different
//     from RTL-007/008's RPM arithmetic, and genuinely SIMPLER than it in
//     one real respect: RTL-009 has no PPR field at all, so there is no
//     analogous divide-by-zero risk to defend against (RTL-007/008's own
//     `commit_divzero_c = (ctl_ppr == 16'd0)` path has no RTL-009
//     equivalent -- omitted, not silently dropped: see below for why the
//     divisor can never be zero here).
//       PERIOD MODE: `FREQ_Q17_15 = round_nearest((50,000,000 << 15) /
//       period_ticks)`. Implemented with dividend = the fixed 64-bit
//       constant `FREQ_PERIOD_CONST` (50,000,000<<15 = 1,638,400,000,000,
//       computed once, not re-derived at runtime) and divisor =
//       period_ticks (the live cycles_since_accepted_q value at commit,
//       which is always >=1 by construction -- it resets to 1, never 0, on
//       every accepted edge, per the same OPEN_ISSUES.md item 27 fix used
//       here). Routed through the SAME pipelined-multiply stage as count
//       mode below (operand_b forced to 1) purely for structural uniformity
//       with count mode's genuine multiply -- not because period mode
//       itself needs a multiply -- so both modes present an identical
//       critical-path shape to the timing-closure tool, rather than one
//       mode being "the cheap one" and the other "the expensive one" in a
//       way that could shift under a future edit.
//       COUNT MODE: `FREQ_Q17_15 = round_nearest((edge_count x 50,000,000
//       << 15) / 100,000)`. A literal reading (multiply by 1,638,400,000,000
//       then divide by 100,000) would require an intermediate product up to
//       ~73 bits (32-bit edge_count x 41-bit constant) -- wider than the
//       64-bit dividend/quotient register this divider (and RTL-007/008's)
//       shares. DISCLOSED, mathematically EXACT algebraic simplification,
//       not a behavioral change: 1,638,400,000,000 is an exact multiple of
//       100,000 (quotient 16,384,000, remainder 0 for every value of
//       edge_count, since the division by 100,000 is exact regardless of
//       edge_count), so `(edge_count x 1,638,400,000,000) / 100,000 ==
//       edge_count x 16,384,000` identically -- implemented as ONE multiply
//       (edge_count x the 24-bit constant `FREQ_COUNT_CONST` =
//       16,384,000) with the divisor forced to the constant 1 (i.e. the
//       64-iteration shift-subtract divider runs to completion against a
//       divisor of 1, which is functionally correct -- quotient equals the
//       dividend exactly, zero remainder -- just not the cheapest possible
//       implementation of "divide by 1"; kept this way rather than special-
//       cased specifically so both modes route through the identical
//       MEAS_MULT/MEAS_RUN/MEAS_APPLY pipeline with no per-mode shortcut).
//       TIES ROUND UP via the same explicit remainder-based test
//       (`2*remainder >= divisor`) as RTL-007/008, and the 32-bit result
//       SATURATES (never wraps) -- wider than RTL-007/008's 16-bit RPM
//       result because Q17.15's 15 fractional bits need the full 32 bits
//       to cover the 0.5 Hz-100 kHz range, not a coincidental oversizing.
//   - WHY THE DIVISOR CAN NEVER BE ZERO (justifying the omitted divzero
//     defense above): period mode's divisor is `period_ticks * 1`, and
//     period_ticks (cycles_since_accepted_q, read live) is >=1 at every
//     commit by construction (OPEN_ISSUES.md item 27's "reset to 1, not 0"
//     fix, applied here from the start) -- it can never be captured as 0.
//     Count mode's divisor is the hardwired constant 1. Neither path can
//     ever present a 0 divisor to the shift-subtract divider.
//   - PIPELINED MULTIPLY (per this file's own opening note): operands are
//     captured into `chN_active_*_q` registers the cycle a commit trigger
//     arrives, the actual multiply runs alone in its own MEAS_MULT state
//     the following cycle, and only then does MEAS_RUN begin -- identical
//     shape, identical one-extra-cycle latency (65 cycles total, ~1.3 us at
//     50 MHz) as dfc_rtl007.sv/dfc_rtl008.sv, applied independently to both
//     channels. Both real entry points (a fresh trigger while MEAS_IDLE,
//     and a queued "redo" trigger arriving while the divider is already
//     busy) funnel through this same MEAS_MULT state per channel, per the
//     real, easy-to-miss second-instance lesson OPEN_ISSUES.md item 31
//     documents finding for RTL-007/008's own redo path.
//   - THRESHOLD/HYSTERESIS (ARCH-MON-005): identical structure to RTL-007/
//     008, widened to 32-bit Q17.15 comparisons. LOW/HIGH are hysteretic
//     LATCHES (not W1C), evaluated in the measurement's own APPLY cycle
//     (the cycle the divider's result and the FREQ/PERIOD_TICKS readbacks
//     update together), per channel.
//   - ILLEGAL CONFIGURATION (ARCH-VAL-009): `0x00004000 <= LOW <=
//     0xC3500000` (0.5 Hz-100,000 Hz, both bounds independently checked on
//     LOW and on HIGH), `LOW <= HIGH`, `HYST <= HIGH-LOW`, and nonzero
//     TIMEOUT_US when enabled -- all directly checkable against this
//     module's real fields, same "defend against what RTL-001 doesn't yet
//     reject" precedent already established by dfc_rtl003/006/007/008.sv
//     (OPEN_ISSUES.md item 4). ARCH-VAL-009's remaining clause,
//     "qualification 0-100 ms", has NO corresponding field anywhere in
//     RTL-009's real register set (`PULSEn_EDGE_FILTER.MIN_EDGE_CYCLES` is
//     a raw CORE_CLK-cycle count, not milliseconds) -- the third real
//     instance of this exact, almost-certainly-copy-forward-from-
//     ARCH-VAL-006 gap already logged for RTL-007/008 (OPEN_ISSUES.md items
//     25/29). Disclosed as not implemented/not applicable, zero functional
//     consequence (no field exists to range-check), not logged as a new
//     blocking item.
//   - EVENT ID 0x0032, SOURCE INDEX 8 (Appendix C.5/C.7): both channels'
//     diagnostic events share ONE event ID and ONE pending slot (per the
//     Architecture port catalog -- RTL-009 has a single evt_valid_o/
//     evt_ready_i/evt_record_o triple, not one pair per channel), with the
//     IDENTICAL subtype encoding as RTL-007/008's own 0x0030/0x0031 rows
//     (0 low, 1 high, 2 timeout, 3 updated, 4 saturation, 5 recovery, 6
//     configuration reject) per channel, packed per C.7's own explicit text
//     for this event ID: event_data's low 16 bits carry the "upper sixteen
//     bits of Q17.15 value" (i.e. `apply_freqN_q[31:16]`, NOT the full
//     32-bit value -- dfc_event_record_t's own event_data field is only 32
//     bits wide and REG-002's own C.7 text explicitly narrows this), and
//     bits 16-23 carry the subtype, matching RTL-007/008's own
//     EVENT_DATA_LO(+16) packing convention. Bits 24-31 of event_data are
//     left reserved-zero.
//   - REAL, DISCLOSED GAP -- LOGGED IN OPEN_ISSUES.md, NOT SILENTLY
//     RESOLVED: neither REG-002's C.7 row for 0x0032 nor dfc_event_record_t
//     itself (Appendix B.1: timestamp/event_id/source_id/flags/event_data,
//     no channel field anywhere) allocates any bit to indicate WHICH of the
//     two channels produced a given 0x0032 event record. This module does
//     NOT invent a channel-indicator bit in the currently-reserved-zero
//     upper byte of event_data (doing so would be inventing behavior absent
//     from the owning documents, CHTR-DOC-006) -- a host observing an 0x0032
//     record must correlate against PULSE0_STATUS/PULSE1_STATUS's own
//     independently-readable per-channel sticky bits to determine origin.
//     Zero functional consequence for this module's own conformance (the
//     event log has always been a diagnostic aid layered on top of the real,
//     independently-host-readable per-channel status registers in this
//     project, e.g. RTL-005/007/008's own identical relationship between
//     their event stream and their real status registers).
//   - SHARED-SLOT EVENT ARBITRATION, a real design this module needs that
//     RTL-007/008 (single producer each) never did: when both channels
//     present a candidate event the SAME cycle, at most one can occupy the
//     one pending slot. DISCLOSED, locally-chosen priority (no spec
//     guidance on cross-channel priority exists, same class of disclosed
//     choice as RTL-007/008's own in-channel subtype priority): channel 0
//     wins ties. Whichever channel's candidate is NOT captured this cycle
//     (either because the slot was already occupied, or because it lost
//     ties to the other channel) is counted as a genuine loss -- ONE
//     pending slot shared by two producers means BOTH can genuinely lose
//     evidence in the same cycle (a case RTL-007/008 structurally could not
//     hit), so `event_drop_count_q` increments by the actual count of
//     losses this cycle (0, 1, or 2), not by a fixed 1 -- a real,
//     disclosed generalization of RTL-007/008's own single-producer
//     drop-by-1 shape, not a simplification that would silently undercount.
//   - EVENT/IRQ CONDITION-MASK ALLOCATION (Appendix F.3 index 8): channel 0
//     occupies bits 0-5 (low/high/timeout/updated/recovery/saturation),
//     channel 1 occupies bits 8-13 in the same order, bit 16 is this
//     module's own event-slot-overflow mask bit (no real consumer here,
//     same functionally-unused pattern as every other module's identical
//     bit) -- confirmed directly against ARCH-002's own F.3 table, matching
//     RTL-009_RevA.md SS1 verbatim.
//   - READY/FAULT: `ready = !ch0_illegal_config && !ch1_illegal_config`
//     (module ready only when NEITHER channel is misconfigured).
//     `fault`/`fault_req_o` = live `(ch0_illegal_config || ch0_timeout_now)
//     || (ch1_illegal_config || ch1_timeout_now)` -- same "active condition
//     plus RTL-013 sticky evidence" matrix text as RTL-007/008 (RTL-013
//     does not exist yet; `fault_req_o` is left genuinely unconsumed in
//     dfc_rtl024.sv, same disclosed pattern as every other not-yet-existing
//     RTL-013 consumer in this project).
//   - `module_enable_i` is a SINGLE, module-wide port (RTL-002.
//     module_enable_o[8] -- confirmed against the real 17-port catalog,
//     there is no per-channel enable port): gates both channels' own
//     `pulseN_control__enable` together via `chN_active`, same
//     "disabled module contributes no degraded/fault request" reading
//     already established for RTL-007/008. `operating_state_i`/
//     `observational_mode_i` are real, structurally-required ports with no
//     functional use in this implementation, same disclosed-no-use
//     precedent already established for these ports on dfc_rtl003/005/
//     007/008.sv -- sunk via the unused-port sink below.
// ============================================================================

module dfc_rtl009 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[8]

  // TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
  // Yosys build -- see dfc_rtl002.sv's header for the full account): a
  // package-scoped type cannot be a port's declared type. Every such port
  // here is a plain `logic [W-1:0]` vector sized via generated
  // `dfc_types_pkg::DFC_*_WIDTH` VALUE constants instead.
  input  logic [dfc_types_pkg::DFC_RTL009_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL009_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,
  output logic         fault_req_o,      // RTL-013.fault_source_i[8] -- no
                                          // real consumer yet, RTL-013 does
                                          // not exist. Left genuinely
                                          // unconsumed in dfc_rtl024.sv.

  input  logic [1:0]   pulse_i,          // raw external edge inputs,
                                          // CDC-PULSE -- one shared 2-bit
                                          // port, bit0=channel0/bit1=
                                          // channel1, each with its own,
                                          // fully independent two-flop
                                          // synchronizer owned by this
                                          // module

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic         module_enable_i,           // RTL-002.module_enable_o[8]

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 8
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 8
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as every module from RTL-003
  // onward), duplicated per channel ----
  wire        ctl0_enable        = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_CONTROL__ENABLE_HI];
  wire        ctl0_rising_edge   = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_CONTROL__RISING_EDGE_HI];
  wire        ctl0_event_enable  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_CONTROL__EVENT_ENABLE_HI];
  wire        ctl0_irq_enable    = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_CONTROL__IRQ_ENABLE_HI];
  wire        ctl0_clear_timeout     = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_STATUS__TIMEOUT_HI];
  wire        ctl0_clear_range_error = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_STATUS__RANGE_ERROR_HI];
  wire        ctl0_clear_updated     = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_STATUS__UPDATED_HI];
  wire [31:0] ctl0_thresh_low  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_THRESH_LOW_Q17_15__THRESHOLD_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_THRESH_LOW_Q17_15__THRESHOLD_LO];
  wire [31:0] ctl0_thresh_high = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_THRESH_HIGH_Q17_15__THRESHOLD_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_THRESH_HIGH_Q17_15__THRESHOLD_LO];
  wire [31:0] ctl0_timeout_us  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_TIMEOUT_US__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_TIMEOUT_US__TIMEOUT_US_LO];
  wire [31:0] ctl0_min_edge_cycles = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_EDGE_FILTER__MIN_EDGE_CYCLES_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_EDGE_FILTER__MIN_EDGE_CYCLES_LO];
  wire [31:0] ctl0_hysteresis  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_HYSTERESIS_Q17_15__HYSTERESIS_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE0_HYSTERESIS_Q17_15__HYSTERESIS_LO];

  wire        ctl1_enable        = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_CONTROL__ENABLE_HI];
  wire        ctl1_rising_edge   = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_CONTROL__RISING_EDGE_HI];
  wire        ctl1_event_enable  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_CONTROL__EVENT_ENABLE_HI];
  wire        ctl1_irq_enable    = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_CONTROL__IRQ_ENABLE_HI];
  wire        ctl1_clear_timeout     = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_STATUS__TIMEOUT_HI];
  wire        ctl1_clear_range_error = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_STATUS__RANGE_ERROR_HI];
  wire        ctl1_clear_updated     = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_STATUS__UPDATED_HI];
  wire [31:0] ctl1_thresh_low  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_THRESH_LOW_Q17_15__THRESHOLD_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_THRESH_LOW_Q17_15__THRESHOLD_LO];
  wire [31:0] ctl1_thresh_high = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_THRESH_HIGH_Q17_15__THRESHOLD_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_THRESH_HIGH_Q17_15__THRESHOLD_LO];
  wire [31:0] ctl1_timeout_us  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_TIMEOUT_US__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_TIMEOUT_US__TIMEOUT_US_LO];
  wire [31:0] ctl1_min_edge_cycles = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_EDGE_FILTER__MIN_EDGE_CYCLES_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_EDGE_FILTER__MIN_EDGE_CYCLES_LO];
  wire [31:0] ctl1_hysteresis  = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_HYSTERESIS_Q17_15__HYSTERESIS_HI:dfc_types_pkg::DFC_RTL009_CONTROL__PULSE1_HYSTERESIS_Q17_15__HYSTERESIS_LO];

  wire ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL009_CONTROL__RTL009_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire ch0_active = ctl0_enable && module_enable_i;
  wire ch1_active = ctl1_enable && module_enable_i;

  // ==========================================================================
  // Shared arithmetic constants (ARCH-MON-004) -- see header for the
  // disclosed, mathematically-exact count-mode simplification.
  // ==========================================================================
  localparam logic [63:0] FREQ_PERIOD_CONST = 64'd1_638_400_000_000;  // 50,000,000 << 15
  localparam logic [23:0] FREQ_COUNT_CONST  = 24'd16_384_000;          // (50,000,000<<15)/100,000, exact

  // ==========================================================================
  // CHANNEL 0
  // ==========================================================================

  // ---- CDC synchronizer (RTLSTD-CDC-008 / CDC-PULSE) + selected-edge
  // detect -- own, independent instance on pulse_i[0]. ----
  logic ch0_sync1_q, ch0_sync2_q, ch0_sync2_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_sync1_q <= 1'b0; ch0_sync2_q <= 1'b0; ch0_sync2_prev_q <= 1'b0;
    end else begin
      ch0_sync1_q      <= pulse_i[0];
      ch0_sync2_q      <= ch0_sync1_q;
      ch0_sync2_prev_q <= ch0_sync2_q;
    end
  end
  wire ch0_rising_raw  = ch0_sync2_q & ~ch0_sync2_prev_q;
  wire ch0_falling_raw = ~ch0_sync2_q & ch0_sync2_prev_q;
  wire ch0_selected_edge = ctl0_rising_edge ? ch0_rising_raw : ch0_falling_raw;

  // ---- Edge qualification (ARCH-MON-002): OPEN_ISSUES.md item 27's
  // sticky min_edge_met_q latch and "reset to 1, never 0" fix, applied
  // from the start -- see dfc_rtl007.sv's own header for the full
  // real-simulation-failure account of both. ----
  logic [31:0] ch0_cycles_since_accepted_q;
  logic        ch0_have_prior_edge_q;
  logic        ch0_min_edge_met_q;

  wire ch0_min_edge_reached_now = (ch0_cycles_since_accepted_q == ctl0_min_edge_cycles);
  wire ch0_min_edge_is_zero     = (ctl0_min_edge_cycles == 32'd0);
  wire ch0_edge_qualified = ch0_selected_edge && ch0_active &&
                            (ch0_min_edge_met_q || ch0_min_edge_reached_now);

  // NOTE: the real async reset is checked in its own, standalone top-level
  // `if`, never OR'd with module_reset_i/!active in the same branch -- the
  // standing, project-wide rule (PROJECT_CONTINUITY.md Section 2).
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_cycles_since_accepted_q <= 32'd0;
      ch0_have_prior_edge_q       <= 1'b0;
      ch0_min_edge_met_q          <= 1'b0;
    end else if (module_reset_i || !ch0_active) begin
      ch0_cycles_since_accepted_q <= 32'd0;
      ch0_have_prior_edge_q       <= 1'b0;
      ch0_min_edge_met_q          <= 1'b0;
    end else if (ch0_edge_qualified) begin
      ch0_have_prior_edge_q        <= 1'b1;
      ch0_cycles_since_accepted_q  <= 32'd1;
      ch0_min_edge_met_q           <= ch0_min_edge_is_zero;
    end else begin
      if (ch0_cycles_since_accepted_q != 32'hFFFFFFFF)
        ch0_cycles_since_accepted_q <= ch0_cycles_since_accepted_q + 32'd1;
      if (ch0_min_edge_reached_now)
        ch0_min_edge_met_q <= 1'b1;
    end
  end

  wire ch0_new_period_valid = ch0_edge_qualified && ch0_have_prior_edge_q;

  // ---- Mode selection (ARCH-MON-002 hysteresis) ----
  typedef enum logic { MODE_PERIOD, MODE_COUNT } mode_e;
  mode_e ch0_mode_q;
  logic [1:0] ch0_mode_hist_q;

  wire ch0_mode_test_this_period = (ch0_mode_q == MODE_PERIOD) ? (ch0_cycles_since_accepted_q < 32'd1000)
                                                                : (ch0_cycles_since_accepted_q > 32'd1250);
  wire ch0_mode_switch = ch0_new_period_valid && ch0_mode_test_this_period && ch0_mode_hist_q[0];

  // ---- Count-mode gate counter (100,000-cycle window) + edge counter ----
  localparam int unsigned COUNT_GATE_CYCLES = 100_000;
  logic [16:0] ch0_gate_counter_q;
  logic [31:0] ch0_edge_count_q;
  wire ch0_gate_expire = (ch0_mode_q == MODE_COUNT) && ch0_active &&
                         (ch0_gate_counter_q == COUNT_GATE_CYCLES-1);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_mode_q         <= MODE_PERIOD;
      ch0_mode_hist_q    <= 2'b00;
      ch0_gate_counter_q <= 17'd0;
      ch0_edge_count_q   <= 32'd0;
    end else if (module_reset_i || !ch0_active) begin
      ch0_mode_q         <= MODE_PERIOD;
      ch0_mode_hist_q    <= 2'b00;
      ch0_gate_counter_q <= 17'd0;
      ch0_edge_count_q   <= 32'd0;
    end else begin
      if (ch0_mode_switch) begin
        if (ch0_mode_q == MODE_PERIOD) ch0_mode_q <= MODE_COUNT;
        else                            ch0_mode_q <= MODE_PERIOD;
        ch0_mode_hist_q    <= 2'b00;
        ch0_gate_counter_q <= 17'd0;
        ch0_edge_count_q   <= 32'd0;
      end else if (ch0_new_period_valid) begin
        ch0_mode_hist_q <= {ch0_mode_hist_q[0], ch0_mode_test_this_period};
      end

      if (!ch0_mode_switch) begin
        if (ch0_mode_q == MODE_COUNT) begin
          if (ch0_gate_expire) begin
            ch0_gate_counter_q <= 17'd0;
            ch0_edge_count_q   <= 32'd0;
          end else begin
            ch0_gate_counter_q <= ch0_gate_counter_q + 17'd1;
            if (ch0_edge_qualified && ch0_edge_count_q != 32'hFFFFFFFF)
              ch0_edge_count_q <= ch0_edge_count_q + 32'd1;
          end
        end
      end
    end
  end

  // ---- FREQ measurement divider (ARCH-MON-004): pipelined multiply +
  // bit-serial 64-iteration shift-subtract division -- see header for the
  // full account of why the multiply is pipelined and why no divide-by-
  // zero defense is needed here. ----
  typedef enum logic [1:0] { MEAS_IDLE, MEAS_MULT, MEAS_RUN, MEAS_APPLY } meas_state_e;
  meas_state_e ch0_meas_state_q;
  logic [5:0]  ch0_meas_iter_q;
  logic [63:0] ch0_meas_rem_q, ch0_meas_quot_q, ch0_meas_divisor_q;
  wire [64:0] ch0_meas_rem_x2      = {ch0_meas_rem_q, 1'b0};
  wire [64:0] ch0_meas_divisor_ext = {1'b0, ch0_meas_divisor_q};
  wire        ch0_meas_round_up    = (ch0_meas_rem_x2 >= ch0_meas_divisor_ext);
  wire [64:0] ch0_meas_freq_wide   = {1'b0, ch0_meas_quot_q} + (ch0_meas_round_up ? 65'd1 : 65'd0);

  wire ch0_period_commit_trig = ch0_new_period_valid && (ch0_mode_q == MODE_PERIOD) && !ch0_mode_switch;
  wire ch0_count_commit_trig  = ch0_gate_expire && !ch0_mode_switch;
  wire ch0_any_commit_trig    = ch0_period_commit_trig || ch0_count_commit_trig;

  // Period mode's operand_b is forced to 1 (a trivial multiply) purely so
  // both modes route through the identical pipelined-multiply shape -- see
  // header.
  wire [31:0] ch0_mult_operand_a_c = ch0_period_commit_trig ? ch0_cycles_since_accepted_q : ch0_edge_count_q;
  wire [23:0] ch0_mult_operand_b_c = ch0_period_commit_trig ? 24'd1 : FREQ_COUNT_CONST;

  logic        ch0_active_is_period_q;
  logic [31:0] ch0_active_mult_a_q;
  logic [23:0] ch0_active_mult_b_q;
  logic        ch0_mult_pending_q;

  wire [63:0] ch0_active_mult_result_c = {32'd0, ch0_active_mult_a_q} * {40'd0, ch0_active_mult_b_q};

  wire [63:0] ch0_meas_new_rem_c = {ch0_meas_rem_q[62:0], ch0_meas_quot_q[63]};

  logic        ch0_apply_fire_q;
  logic [31:0] ch0_apply_freq_q;
  logic        ch0_apply_range_error_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_meas_state_q        <= MEAS_IDLE;
      ch0_meas_iter_q         <= 6'd0;
      ch0_meas_rem_q          <= 64'd0;
      ch0_meas_quot_q         <= 64'd0;
      ch0_meas_divisor_q      <= 64'd0;
      ch0_active_is_period_q  <= 1'b0;
      ch0_active_mult_a_q     <= 32'd0;
      ch0_active_mult_b_q     <= 24'd0;
      ch0_mult_pending_q      <= 1'b0;
      ch0_apply_fire_q        <= 1'b0;
      ch0_apply_freq_q        <= 32'd0;
      ch0_apply_range_error_q <= 1'b0;
    end else if (module_reset_i || !ch0_active) begin
      ch0_meas_state_q        <= MEAS_IDLE;
      ch0_meas_iter_q         <= 6'd0;
      ch0_meas_rem_q          <= 64'd0;
      ch0_meas_quot_q         <= 64'd0;
      ch0_meas_divisor_q      <= 64'd0;
      ch0_active_is_period_q  <= 1'b0;
      ch0_active_mult_a_q     <= 32'd0;
      ch0_active_mult_b_q     <= 24'd0;
      ch0_mult_pending_q      <= 1'b0;
      ch0_apply_fire_q        <= 1'b0;
      ch0_apply_freq_q        <= 32'd0;
      ch0_apply_range_error_q <= 1'b0;
    end else begin
      ch0_apply_fire_q <= 1'b0;

      unique case (ch0_meas_state_q)
        MEAS_IDLE: begin
          if (ch0_any_commit_trig) ch0_meas_state_q <= MEAS_MULT;
        end
        MEAS_MULT: begin
          ch0_meas_quot_q    <= ch0_active_is_period_q ? FREQ_PERIOD_CONST : ch0_active_mult_result_c;
          ch0_meas_rem_q     <= 64'd0;
          ch0_meas_divisor_q <= ch0_active_is_period_q ? ch0_active_mult_result_c : 64'd1;
          ch0_meas_iter_q    <= 6'd63;
          ch0_meas_state_q   <= MEAS_RUN;
        end
        MEAS_RUN: begin
          if (ch0_meas_new_rem_c >= ch0_meas_divisor_q) begin
            ch0_meas_rem_q  <= ch0_meas_new_rem_c - ch0_meas_divisor_q;
            ch0_meas_quot_q <= {ch0_meas_quot_q[62:0], 1'b1};
            if (ch0_meas_iter_q == 6'd0) ch0_meas_state_q <= MEAS_APPLY;
            else                          ch0_meas_iter_q  <= ch0_meas_iter_q - 6'd1;
          end else begin
            ch0_meas_rem_q  <= ch0_meas_new_rem_c;
            ch0_meas_quot_q <= {ch0_meas_quot_q[62:0], 1'b0};
            if (ch0_meas_iter_q == 6'd0) ch0_meas_state_q <= MEAS_APPLY;
            else                          ch0_meas_iter_q  <= ch0_meas_iter_q - 6'd1;
          end
        end
        MEAS_APPLY: begin
          if (ch0_meas_freq_wide > 65'd4294967295) begin
            ch0_apply_freq_q        <= 32'hFFFFFFFF;
            ch0_apply_range_error_q <= 1'b1;
          end else begin
            ch0_apply_freq_q        <= ch0_meas_freq_wide[31:0];
            ch0_apply_range_error_q <= 1'b0;
          end
          ch0_apply_fire_q <= 1'b1;
          if (ch0_mult_pending_q) begin
            ch0_mult_pending_q <= 1'b0;
            ch0_meas_state_q   <= MEAS_MULT;
          end else begin
            ch0_meas_state_q <= MEAS_IDLE;
          end
        end
        default: ch0_meas_state_q <= MEAS_IDLE;
      endcase

      if (ch0_any_commit_trig) begin
        ch0_active_is_period_q <= ch0_period_commit_trig;
        ch0_active_mult_a_q    <= ch0_mult_operand_a_c;
        ch0_active_mult_b_q    <= ch0_mult_operand_b_c;
        if (ch0_meas_state_q != MEAS_IDLE) ch0_mult_pending_q <= 1'b1;
      end
    end
  end

  // ---- Timeout (ARCH-MON-005) ----
  localparam int unsigned US_CYCLES = 50;  // nominal 50 MHz CORE_CLK (ARCH-CLK-001)
  logic [5:0]  ch0_us_phase_q;
  wire         ch0_us_tick = (ch0_us_phase_q == US_CYCLES-1);
  logic [31:0] ch0_elapsed_us_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)                       ch0_us_phase_q <= 6'd0;
    else if (module_reset_i || !ch0_active)  ch0_us_phase_q <= 6'd0;
    else if (ch0_us_tick)                    ch0_us_phase_q <= 6'd0;
    else                                       ch0_us_phase_q <= ch0_us_phase_q + 6'd1;
  end

  logic ch0_timeout_now_prev_q;
  wire  ch0_timeout_now = ch0_active && (ctl0_timeout_us != 32'd0) &&
                          (ch0_elapsed_us_q >= ctl0_timeout_us);
  wire  ch0_timeout_new = ch0_timeout_now && !ch0_timeout_now_prev_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_elapsed_us_q       <= 32'd0;
      ch0_timeout_now_prev_q <= 1'b0;
    end else if (module_reset_i || !ch0_active) begin
      ch0_elapsed_us_q       <= 32'd0;
      ch0_timeout_now_prev_q <= 1'b0;
    end else begin
      ch0_timeout_now_prev_q <= ch0_timeout_now;
      if (ch0_edge_qualified) begin
        ch0_elapsed_us_q <= 32'd0;
      end else if (ch0_us_tick && ch0_elapsed_us_q != 32'hFFFFFFFF) begin
        ch0_elapsed_us_q <= ch0_elapsed_us_q + 32'd1;
      end
    end
  end

  // ---- Illegal configuration (ARCH-VAL-009) -- live, not sticky ----
  wire [31:0] ch0_hyst_budget = (ctl0_thresh_high >= ctl0_thresh_low) ?
                                (ctl0_thresh_high - ctl0_thresh_low) : 32'd0;
  wire ch0_illegal_config = ctl0_enable && (
    (ctl0_thresh_low  < 32'h00004000) ||
    (ctl0_thresh_low  > 32'hC3500000) ||
    (ctl0_thresh_high < 32'h00004000) ||
    (ctl0_thresh_high > 32'hC3500000) ||
    (ctl0_thresh_low  > ctl0_thresh_high) ||
    (ctl0_hysteresis  > ch0_hyst_budget) ||
    (ctl0_timeout_us == 32'd0)
  );
  logic ch0_illegal_config_prev_q;
  wire  ch0_config_reject_new = ch0_illegal_config && !ch0_illegal_config_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       ch0_illegal_config_prev_q <= 1'b0;
    else if (module_reset_i) ch0_illegal_config_prev_q <= 1'b0;
    else                       ch0_illegal_config_prev_q <= ch0_illegal_config;
  end

  // ---- Threshold latches + sticky W1C evidence, updated in APPLY cycle ----
  logic        ch0_valid_q;
  logic        ch0_low_q, ch0_high_q;
  logic [31:0] ch0_freq_q;
  logic        ch0_timeout_sticky_q, ch0_range_error_sticky_q, ch0_updated_sticky_q;

  wire [32:0] ch0_low_exit_sum_w   = {1'b0, ctl0_thresh_low} + {1'b0, ctl0_hysteresis};
  wire [31:0] ch0_low_exit_thresh  = (ch0_low_exit_sum_w > 33'hFFFFFFFF) ? 32'hFFFFFFFF : ch0_low_exit_sum_w[31:0];
  wire [31:0] ch0_high_exit_thresh = (ctl0_thresh_high >= ctl0_hysteresis) ?
                                     (ctl0_thresh_high - ctl0_hysteresis) : 32'd0;

  wire ch0_low_enter_test  = !ch0_low_q  && (ch0_apply_freq_q <  ctl0_thresh_low);
  wire ch0_low_exit_test   =  ch0_low_q  && (ch0_apply_freq_q >= ch0_low_exit_thresh);
  wire ch0_high_enter_test = !ch0_high_q && (ch0_apply_freq_q >  ctl0_thresh_high);
  wire ch0_high_exit_test  =  ch0_high_q && (ch0_apply_freq_q <= ch0_high_exit_thresh);

  wire ch0_low_enter_ev  = ch0_apply_fire_q && ch0_low_enter_test;
  wire ch0_high_enter_ev = ch0_apply_fire_q && ch0_high_enter_test;
  wire ch0_recovery_ev   = ch0_apply_fire_q && (ch0_low_exit_test || ch0_high_exit_test);
  wire ch0_saturation_ev = ch0_apply_fire_q && ch0_apply_range_error_q;
  wire ch0_updated_ev    = ch0_apply_fire_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_valid_q               <= 1'b0;
      ch0_low_q                 <= 1'b0;
      ch0_high_q                <= 1'b0;
      ch0_freq_q                <= 32'd0;
      ch0_timeout_sticky_q      <= 1'b0;
      ch0_range_error_sticky_q  <= 1'b0;
      ch0_updated_sticky_q      <= 1'b0;
    end else if (module_reset_i || !ch0_active) begin
      ch0_valid_q               <= 1'b0;
      ch0_low_q                 <= 1'b0;
      ch0_high_q                <= 1'b0;
      ch0_freq_q                <= 32'd0;
      ch0_timeout_sticky_q      <= 1'b0;
      ch0_range_error_sticky_q  <= 1'b0;
      ch0_updated_sticky_q      <= 1'b0;
    end else begin
      if (ch0_apply_fire_q) begin
        ch0_valid_q <= 1'b1;
        ch0_freq_q  <= ch0_apply_freq_q;
        if (ch0_low_enter_test)  ch0_low_q  <= 1'b1;
        else if (ch0_low_exit_test)  ch0_low_q  <= 1'b0;
        if (ch0_high_enter_test) ch0_high_q <= 1'b1;
        else if (ch0_high_exit_test) ch0_high_q <= 1'b0;
        ch0_updated_sticky_q <= 1'b1;
        if (ch0_apply_range_error_q) ch0_range_error_sticky_q <= 1'b1;
      end

      if (ch0_timeout_new) begin
        ch0_valid_q          <= 1'b0;
        ch0_low_q            <= 1'b0;
        ch0_high_q           <= 1'b0;
        ch0_timeout_sticky_q <= 1'b1;
      end

      if (ctl0_clear_timeout && !ch0_timeout_new)          ch0_timeout_sticky_q     <= 1'b0;
      if (ctl0_clear_range_error && !ch0_saturation_ev)    ch0_range_error_sticky_q <= 1'b0;
      if (ctl0_clear_updated && !ch0_updated_ev)           ch0_updated_sticky_q     <= 1'b0;
    end
  end

  logic [31:0] ch0_period_ticks_readback_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)                       ch0_period_ticks_readback_q <= 32'd0;
    else if (module_reset_i || !ch0_active)  ch0_period_ticks_readback_q <= 32'd0;
    else if (ch0_new_period_valid)           ch0_period_ticks_readback_q <= ch0_cycles_since_accepted_q;
  end

  // ==========================================================================
  // CHANNEL 1 -- structurally identical to channel 0 above, entirely
  // independent state (ARCH-RTL009-001: "same-cycle accepted edges update
  // both channel states independently"), fed from pulse_i[1].
  // ==========================================================================

  logic ch1_sync1_q, ch1_sync2_q, ch1_sync2_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_sync1_q <= 1'b0; ch1_sync2_q <= 1'b0; ch1_sync2_prev_q <= 1'b0;
    end else begin
      ch1_sync1_q      <= pulse_i[1];
      ch1_sync2_q      <= ch1_sync1_q;
      ch1_sync2_prev_q <= ch1_sync2_q;
    end
  end
  wire ch1_rising_raw  = ch1_sync2_q & ~ch1_sync2_prev_q;
  wire ch1_falling_raw = ~ch1_sync2_q & ch1_sync2_prev_q;
  wire ch1_selected_edge = ctl1_rising_edge ? ch1_rising_raw : ch1_falling_raw;

  logic [31:0] ch1_cycles_since_accepted_q;
  logic        ch1_have_prior_edge_q;
  logic        ch1_min_edge_met_q;

  wire ch1_min_edge_reached_now = (ch1_cycles_since_accepted_q == ctl1_min_edge_cycles);
  wire ch1_min_edge_is_zero     = (ctl1_min_edge_cycles == 32'd0);
  wire ch1_edge_qualified = ch1_selected_edge && ch1_active &&
                            (ch1_min_edge_met_q || ch1_min_edge_reached_now);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_cycles_since_accepted_q <= 32'd0;
      ch1_have_prior_edge_q       <= 1'b0;
      ch1_min_edge_met_q          <= 1'b0;
    end else if (module_reset_i || !ch1_active) begin
      ch1_cycles_since_accepted_q <= 32'd0;
      ch1_have_prior_edge_q       <= 1'b0;
      ch1_min_edge_met_q          <= 1'b0;
    end else if (ch1_edge_qualified) begin
      ch1_have_prior_edge_q        <= 1'b1;
      ch1_cycles_since_accepted_q  <= 32'd1;
      ch1_min_edge_met_q           <= ch1_min_edge_is_zero;
    end else begin
      if (ch1_cycles_since_accepted_q != 32'hFFFFFFFF)
        ch1_cycles_since_accepted_q <= ch1_cycles_since_accepted_q + 32'd1;
      if (ch1_min_edge_reached_now)
        ch1_min_edge_met_q <= 1'b1;
    end
  end

  wire ch1_new_period_valid = ch1_edge_qualified && ch1_have_prior_edge_q;

  mode_e ch1_mode_q;
  logic [1:0] ch1_mode_hist_q;

  wire ch1_mode_test_this_period = (ch1_mode_q == MODE_PERIOD) ? (ch1_cycles_since_accepted_q < 32'd1000)
                                                                : (ch1_cycles_since_accepted_q > 32'd1250);
  wire ch1_mode_switch = ch1_new_period_valid && ch1_mode_test_this_period && ch1_mode_hist_q[0];

  logic [16:0] ch1_gate_counter_q;
  logic [31:0] ch1_edge_count_q;
  wire ch1_gate_expire = (ch1_mode_q == MODE_COUNT) && ch1_active &&
                         (ch1_gate_counter_q == COUNT_GATE_CYCLES-1);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_mode_q         <= MODE_PERIOD;
      ch1_mode_hist_q    <= 2'b00;
      ch1_gate_counter_q <= 17'd0;
      ch1_edge_count_q   <= 32'd0;
    end else if (module_reset_i || !ch1_active) begin
      ch1_mode_q         <= MODE_PERIOD;
      ch1_mode_hist_q    <= 2'b00;
      ch1_gate_counter_q <= 17'd0;
      ch1_edge_count_q   <= 32'd0;
    end else begin
      if (ch1_mode_switch) begin
        if (ch1_mode_q == MODE_PERIOD) ch1_mode_q <= MODE_COUNT;
        else                            ch1_mode_q <= MODE_PERIOD;
        ch1_mode_hist_q    <= 2'b00;
        ch1_gate_counter_q <= 17'd0;
        ch1_edge_count_q   <= 32'd0;
      end else if (ch1_new_period_valid) begin
        ch1_mode_hist_q <= {ch1_mode_hist_q[0], ch1_mode_test_this_period};
      end

      if (!ch1_mode_switch) begin
        if (ch1_mode_q == MODE_COUNT) begin
          if (ch1_gate_expire) begin
            ch1_gate_counter_q <= 17'd0;
            ch1_edge_count_q   <= 32'd0;
          end else begin
            ch1_gate_counter_q <= ch1_gate_counter_q + 17'd1;
            if (ch1_edge_qualified && ch1_edge_count_q != 32'hFFFFFFFF)
              ch1_edge_count_q <= ch1_edge_count_q + 32'd1;
          end
        end
      end
    end
  end

  meas_state_e ch1_meas_state_q;
  logic [5:0]  ch1_meas_iter_q;
  logic [63:0] ch1_meas_rem_q, ch1_meas_quot_q, ch1_meas_divisor_q;
  wire [64:0] ch1_meas_rem_x2      = {ch1_meas_rem_q, 1'b0};
  wire [64:0] ch1_meas_divisor_ext = {1'b0, ch1_meas_divisor_q};
  wire        ch1_meas_round_up    = (ch1_meas_rem_x2 >= ch1_meas_divisor_ext);
  wire [64:0] ch1_meas_freq_wide   = {1'b0, ch1_meas_quot_q} + (ch1_meas_round_up ? 65'd1 : 65'd0);

  wire ch1_period_commit_trig = ch1_new_period_valid && (ch1_mode_q == MODE_PERIOD) && !ch1_mode_switch;
  wire ch1_count_commit_trig  = ch1_gate_expire && !ch1_mode_switch;
  wire ch1_any_commit_trig    = ch1_period_commit_trig || ch1_count_commit_trig;

  wire [31:0] ch1_mult_operand_a_c = ch1_period_commit_trig ? ch1_cycles_since_accepted_q : ch1_edge_count_q;
  wire [23:0] ch1_mult_operand_b_c = ch1_period_commit_trig ? 24'd1 : FREQ_COUNT_CONST;

  logic        ch1_active_is_period_q;
  logic [31:0] ch1_active_mult_a_q;
  logic [23:0] ch1_active_mult_b_q;
  logic        ch1_mult_pending_q;

  wire [63:0] ch1_active_mult_result_c = {32'd0, ch1_active_mult_a_q} * {40'd0, ch1_active_mult_b_q};

  wire [63:0] ch1_meas_new_rem_c = {ch1_meas_rem_q[62:0], ch1_meas_quot_q[63]};

  logic        ch1_apply_fire_q;
  logic [31:0] ch1_apply_freq_q;
  logic        ch1_apply_range_error_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_meas_state_q        <= MEAS_IDLE;
      ch1_meas_iter_q         <= 6'd0;
      ch1_meas_rem_q          <= 64'd0;
      ch1_meas_quot_q         <= 64'd0;
      ch1_meas_divisor_q      <= 64'd0;
      ch1_active_is_period_q  <= 1'b0;
      ch1_active_mult_a_q     <= 32'd0;
      ch1_active_mult_b_q     <= 24'd0;
      ch1_mult_pending_q      <= 1'b0;
      ch1_apply_fire_q        <= 1'b0;
      ch1_apply_freq_q        <= 32'd0;
      ch1_apply_range_error_q <= 1'b0;
    end else if (module_reset_i || !ch1_active) begin
      ch1_meas_state_q        <= MEAS_IDLE;
      ch1_meas_iter_q         <= 6'd0;
      ch1_meas_rem_q          <= 64'd0;
      ch1_meas_quot_q         <= 64'd0;
      ch1_meas_divisor_q      <= 64'd0;
      ch1_active_is_period_q  <= 1'b0;
      ch1_active_mult_a_q     <= 32'd0;
      ch1_active_mult_b_q     <= 24'd0;
      ch1_mult_pending_q      <= 1'b0;
      ch1_apply_fire_q        <= 1'b0;
      ch1_apply_freq_q        <= 32'd0;
      ch1_apply_range_error_q <= 1'b0;
    end else begin
      ch1_apply_fire_q <= 1'b0;

      unique case (ch1_meas_state_q)
        MEAS_IDLE: begin
          if (ch1_any_commit_trig) ch1_meas_state_q <= MEAS_MULT;
        end
        MEAS_MULT: begin
          ch1_meas_quot_q    <= ch1_active_is_period_q ? FREQ_PERIOD_CONST : ch1_active_mult_result_c;
          ch1_meas_rem_q     <= 64'd0;
          ch1_meas_divisor_q <= ch1_active_is_period_q ? ch1_active_mult_result_c : 64'd1;
          ch1_meas_iter_q    <= 6'd63;
          ch1_meas_state_q   <= MEAS_RUN;
        end
        MEAS_RUN: begin
          if (ch1_meas_new_rem_c >= ch1_meas_divisor_q) begin
            ch1_meas_rem_q  <= ch1_meas_new_rem_c - ch1_meas_divisor_q;
            ch1_meas_quot_q <= {ch1_meas_quot_q[62:0], 1'b1};
            if (ch1_meas_iter_q == 6'd0) ch1_meas_state_q <= MEAS_APPLY;
            else                          ch1_meas_iter_q  <= ch1_meas_iter_q - 6'd1;
          end else begin
            ch1_meas_rem_q  <= ch1_meas_new_rem_c;
            ch1_meas_quot_q <= {ch1_meas_quot_q[62:0], 1'b0};
            if (ch1_meas_iter_q == 6'd0) ch1_meas_state_q <= MEAS_APPLY;
            else                          ch1_meas_iter_q  <= ch1_meas_iter_q - 6'd1;
          end
        end
        MEAS_APPLY: begin
          if (ch1_meas_freq_wide > 65'd4294967295) begin
            ch1_apply_freq_q        <= 32'hFFFFFFFF;
            ch1_apply_range_error_q <= 1'b1;
          end else begin
            ch1_apply_freq_q        <= ch1_meas_freq_wide[31:0];
            ch1_apply_range_error_q <= 1'b0;
          end
          ch1_apply_fire_q <= 1'b1;
          if (ch1_mult_pending_q) begin
            ch1_mult_pending_q <= 1'b0;
            ch1_meas_state_q   <= MEAS_MULT;
          end else begin
            ch1_meas_state_q <= MEAS_IDLE;
          end
        end
        default: ch1_meas_state_q <= MEAS_IDLE;
      endcase

      if (ch1_any_commit_trig) begin
        ch1_active_is_period_q <= ch1_period_commit_trig;
        ch1_active_mult_a_q    <= ch1_mult_operand_a_c;
        ch1_active_mult_b_q    <= ch1_mult_operand_b_c;
        if (ch1_meas_state_q != MEAS_IDLE) ch1_mult_pending_q <= 1'b1;
      end
    end
  end

  logic [5:0]  ch1_us_phase_q;
  wire         ch1_us_tick = (ch1_us_phase_q == US_CYCLES-1);
  logic [31:0] ch1_elapsed_us_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)                       ch1_us_phase_q <= 6'd0;
    else if (module_reset_i || !ch1_active)  ch1_us_phase_q <= 6'd0;
    else if (ch1_us_tick)                    ch1_us_phase_q <= 6'd0;
    else                                       ch1_us_phase_q <= ch1_us_phase_q + 6'd1;
  end

  logic ch1_timeout_now_prev_q;
  wire  ch1_timeout_now = ch1_active && (ctl1_timeout_us != 32'd0) &&
                          (ch1_elapsed_us_q >= ctl1_timeout_us);
  wire  ch1_timeout_new = ch1_timeout_now && !ch1_timeout_now_prev_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_elapsed_us_q       <= 32'd0;
      ch1_timeout_now_prev_q <= 1'b0;
    end else if (module_reset_i || !ch1_active) begin
      ch1_elapsed_us_q       <= 32'd0;
      ch1_timeout_now_prev_q <= 1'b0;
    end else begin
      ch1_timeout_now_prev_q <= ch1_timeout_now;
      if (ch1_edge_qualified) begin
        ch1_elapsed_us_q <= 32'd0;
      end else if (ch1_us_tick && ch1_elapsed_us_q != 32'hFFFFFFFF) begin
        ch1_elapsed_us_q <= ch1_elapsed_us_q + 32'd1;
      end
    end
  end

  wire [31:0] ch1_hyst_budget = (ctl1_thresh_high >= ctl1_thresh_low) ?
                                (ctl1_thresh_high - ctl1_thresh_low) : 32'd0;
  wire ch1_illegal_config = ctl1_enable && (
    (ctl1_thresh_low  < 32'h00004000) ||
    (ctl1_thresh_low  > 32'hC3500000) ||
    (ctl1_thresh_high < 32'h00004000) ||
    (ctl1_thresh_high > 32'hC3500000) ||
    (ctl1_thresh_low  > ctl1_thresh_high) ||
    (ctl1_hysteresis  > ch1_hyst_budget) ||
    (ctl1_timeout_us == 32'd0)
  );
  logic ch1_illegal_config_prev_q;
  wire  ch1_config_reject_new = ch1_illegal_config && !ch1_illegal_config_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       ch1_illegal_config_prev_q <= 1'b0;
    else if (module_reset_i) ch1_illegal_config_prev_q <= 1'b0;
    else                       ch1_illegal_config_prev_q <= ch1_illegal_config;
  end

  logic        ch1_valid_q;
  logic        ch1_low_q, ch1_high_q;
  logic [31:0] ch1_freq_q;
  logic        ch1_timeout_sticky_q, ch1_range_error_sticky_q, ch1_updated_sticky_q;

  wire [32:0] ch1_low_exit_sum_w   = {1'b0, ctl1_thresh_low} + {1'b0, ctl1_hysteresis};
  wire [31:0] ch1_low_exit_thresh  = (ch1_low_exit_sum_w > 33'hFFFFFFFF) ? 32'hFFFFFFFF : ch1_low_exit_sum_w[31:0];
  wire [31:0] ch1_high_exit_thresh = (ctl1_thresh_high >= ctl1_hysteresis) ?
                                     (ctl1_thresh_high - ctl1_hysteresis) : 32'd0;

  wire ch1_low_enter_test  = !ch1_low_q  && (ch1_apply_freq_q <  ctl1_thresh_low);
  wire ch1_low_exit_test   =  ch1_low_q  && (ch1_apply_freq_q >= ch1_low_exit_thresh);
  wire ch1_high_enter_test = !ch1_high_q && (ch1_apply_freq_q >  ctl1_thresh_high);
  wire ch1_high_exit_test  =  ch1_high_q && (ch1_apply_freq_q <= ch1_high_exit_thresh);

  wire ch1_low_enter_ev  = ch1_apply_fire_q && ch1_low_enter_test;
  wire ch1_high_enter_ev = ch1_apply_fire_q && ch1_high_enter_test;
  wire ch1_recovery_ev   = ch1_apply_fire_q && (ch1_low_exit_test || ch1_high_exit_test);
  wire ch1_saturation_ev = ch1_apply_fire_q && ch1_apply_range_error_q;
  wire ch1_updated_ev    = ch1_apply_fire_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_valid_q               <= 1'b0;
      ch1_low_q                 <= 1'b0;
      ch1_high_q                <= 1'b0;
      ch1_freq_q                <= 32'd0;
      ch1_timeout_sticky_q      <= 1'b0;
      ch1_range_error_sticky_q  <= 1'b0;
      ch1_updated_sticky_q      <= 1'b0;
    end else if (module_reset_i || !ch1_active) begin
      ch1_valid_q               <= 1'b0;
      ch1_low_q                 <= 1'b0;
      ch1_high_q                <= 1'b0;
      ch1_freq_q                <= 32'd0;
      ch1_timeout_sticky_q      <= 1'b0;
      ch1_range_error_sticky_q  <= 1'b0;
      ch1_updated_sticky_q      <= 1'b0;
    end else begin
      if (ch1_apply_fire_q) begin
        ch1_valid_q <= 1'b1;
        ch1_freq_q  <= ch1_apply_freq_q;
        if (ch1_low_enter_test)  ch1_low_q  <= 1'b1;
        else if (ch1_low_exit_test)  ch1_low_q  <= 1'b0;
        if (ch1_high_enter_test) ch1_high_q <= 1'b1;
        else if (ch1_high_exit_test) ch1_high_q <= 1'b0;
        ch1_updated_sticky_q <= 1'b1;
        if (ch1_apply_range_error_q) ch1_range_error_sticky_q <= 1'b1;
      end

      if (ch1_timeout_new) begin
        ch1_valid_q          <= 1'b0;
        ch1_low_q            <= 1'b0;
        ch1_high_q           <= 1'b0;
        ch1_timeout_sticky_q <= 1'b1;
      end

      if (ctl1_clear_timeout && !ch1_timeout_new)          ch1_timeout_sticky_q     <= 1'b0;
      if (ctl1_clear_range_error && !ch1_saturation_ev)    ch1_range_error_sticky_q <= 1'b0;
      if (ctl1_clear_updated && !ch1_updated_ev)           ch1_updated_sticky_q     <= 1'b0;
    end
  end

  logic [31:0] ch1_period_ticks_readback_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)                       ch1_period_ticks_readback_q <= 32'd0;
    else if (module_reset_i || !ch1_active)  ch1_period_ticks_readback_q <= 32'd0;
    else if (ch1_new_period_valid)           ch1_period_ticks_readback_q <= ch1_cycles_since_accepted_q;
  end

  // ==========================================================================
  // Shared event generation (event ID 0x0032, source index 8) -- ONE
  // pending slot for BOTH channels' own diagnostic events. See header for
  // the disclosed channel-0-wins-ties arbitration and the disclosed lack of
  // a channel indicator in the record itself (logged in OPEN_ISSUES.md).
  // ==========================================================================
  localparam logic [15:0] EVT_ID_PULSE = 16'h0032;
  localparam logic [7:0]  EVT_SUBTYPE_LOW        = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_HIGH       = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_TIMEOUT    = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_UPDATED    = 8'd3;
  localparam logic [7:0]  EVT_SUBTYPE_SATURATION = 8'd4;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERY   = 8'd5;
  localparam logic [7:0]  EVT_SUBTYPE_CFG_REJECT = 8'd6;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL009 = 8'd8;  // ARCH-002 C.5 index 8
  localparam int unsigned CH0_COND_BASE = 0;   // Appendix F.3 index 8, channel 0
  localparam int unsigned CH1_COND_BASE = 8;   // Appendix F.3 index 8, channel 1

  wire ev_gate_low0        = ch0_low_enter_ev  & ctl0_event_enable & event_condition_enable_i[CH0_COND_BASE+0];
  wire ev_gate_high0       = ch0_high_enter_ev & ctl0_event_enable & event_condition_enable_i[CH0_COND_BASE+1];
  wire ev_gate_timeout0    = ch0_timeout_new   & ctl0_event_enable & event_condition_enable_i[CH0_COND_BASE+2];
  wire ev_gate_updated0    = ch0_updated_ev    & ctl0_event_enable & event_condition_enable_i[CH0_COND_BASE+3];
  wire ev_gate_recovery0   = ch0_recovery_ev   & ctl0_event_enable & event_condition_enable_i[CH0_COND_BASE+4];
  wire ev_gate_saturation0 = ch0_saturation_ev & ctl0_event_enable & event_condition_enable_i[CH0_COND_BASE+5];
  wire ev_gate_cfgreject0  = ch0_config_reject_new;  // mandatory event, see dfc_rtl007.sv's header

  wire ev_gate_low1        = ch1_low_enter_ev  & ctl1_event_enable & event_condition_enable_i[CH1_COND_BASE+0];
  wire ev_gate_high1       = ch1_high_enter_ev & ctl1_event_enable & event_condition_enable_i[CH1_COND_BASE+1];
  wire ev_gate_timeout1    = ch1_timeout_new   & ctl1_event_enable & event_condition_enable_i[CH1_COND_BASE+2];
  wire ev_gate_updated1    = ch1_updated_ev    & ctl1_event_enable & event_condition_enable_i[CH1_COND_BASE+3];
  wire ev_gate_recovery1   = ch1_recovery_ev   & ctl1_event_enable & event_condition_enable_i[CH1_COND_BASE+4];
  wire ev_gate_saturation1 = ch1_saturation_ev & ctl1_event_enable & event_condition_enable_i[CH1_COND_BASE+5];
  wire ev_gate_cfgreject1  = ch1_config_reject_new;

  wire iq_gate_low0        = ch0_low_enter_ev  & ctl0_irq_enable & irq_condition_enable_i[CH0_COND_BASE+0];
  wire iq_gate_high0       = ch0_high_enter_ev & ctl0_irq_enable & irq_condition_enable_i[CH0_COND_BASE+1];
  wire iq_gate_timeout0    = ch0_timeout_new   & ctl0_irq_enable & irq_condition_enable_i[CH0_COND_BASE+2];
  wire iq_gate_updated0    = ch0_updated_ev    & ctl0_irq_enable & irq_condition_enable_i[CH0_COND_BASE+3];
  wire iq_gate_recovery0   = ch0_recovery_ev   & ctl0_irq_enable & irq_condition_enable_i[CH0_COND_BASE+4];
  wire iq_gate_saturation0 = ch0_saturation_ev & ctl0_irq_enable & irq_condition_enable_i[CH0_COND_BASE+5];

  wire iq_gate_low1        = ch1_low_enter_ev  & ctl1_irq_enable & irq_condition_enable_i[CH1_COND_BASE+0];
  wire iq_gate_high1       = ch1_high_enter_ev & ctl1_irq_enable & irq_condition_enable_i[CH1_COND_BASE+1];
  wire iq_gate_timeout1    = ch1_timeout_new   & ctl1_irq_enable & irq_condition_enable_i[CH1_COND_BASE+2];
  wire iq_gate_updated1    = ch1_updated_ev    & ctl1_irq_enable & irq_condition_enable_i[CH1_COND_BASE+3];
  wire iq_gate_recovery1   = ch1_recovery_ev   & ctl1_irq_enable & irq_condition_enable_i[CH1_COND_BASE+4];
  wire iq_gate_saturation1 = ch1_saturation_ev & ctl1_irq_enable & irq_condition_enable_i[CH1_COND_BASE+5];

  assign irq_req_o = iq_gate_low0  | iq_gate_high0  | iq_gate_timeout0  | iq_gate_updated0  | iq_gate_recovery0  | iq_gate_saturation0 |
                      iq_gate_low1  | iq_gate_high1  | iq_gate_timeout1  | iq_gate_updated1  | iq_gate_recovery1  | iq_gate_saturation1;

  wire ch0_evt_candidate_valid = ev_gate_cfgreject0 | ev_gate_timeout0 | ev_gate_saturation0 |
                                  ev_gate_low0 | ev_gate_high0 | ev_gate_recovery0 | ev_gate_updated0;
  wire ch1_evt_candidate_valid = ev_gate_cfgreject1 | ev_gate_timeout1 | ev_gate_saturation1 |
                                  ev_gate_low1 | ev_gate_high1 | ev_gate_recovery1 | ev_gate_updated1;

  logic [7:0] evt_subtype_comb0, evt_subtype_comb1;
  always_comb begin
    if (ev_gate_cfgreject0)       evt_subtype_comb0 = EVT_SUBTYPE_CFG_REJECT;
    else if (ev_gate_timeout0)    evt_subtype_comb0 = EVT_SUBTYPE_TIMEOUT;
    else if (ev_gate_saturation0) evt_subtype_comb0 = EVT_SUBTYPE_SATURATION;
    else if (ev_gate_low0)        evt_subtype_comb0 = EVT_SUBTYPE_LOW;
    else if (ev_gate_high0)       evt_subtype_comb0 = EVT_SUBTYPE_HIGH;
    else if (ev_gate_recovery0)   evt_subtype_comb0 = EVT_SUBTYPE_RECOVERY;
    else                           evt_subtype_comb0 = EVT_SUBTYPE_UPDATED;
  end
  always_comb begin
    if (ev_gate_cfgreject1)       evt_subtype_comb1 = EVT_SUBTYPE_CFG_REJECT;
    else if (ev_gate_timeout1)    evt_subtype_comb1 = EVT_SUBTYPE_TIMEOUT;
    else if (ev_gate_saturation1) evt_subtype_comb1 = EVT_SUBTYPE_SATURATION;
    else if (ev_gate_low1)        evt_subtype_comb1 = EVT_SUBTYPE_LOW;
    else if (ev_gate_high1)       evt_subtype_comb1 = EVT_SUBTYPE_HIGH;
    else if (ev_gate_recovery1)   evt_subtype_comb1 = EVT_SUBTYPE_RECOVERY;
    else                           evt_subtype_comb1 = EVT_SUBTYPE_UPDATED;
  end

  // event_data packing per Appendix C.7's own text for 0x0032: low 16 bits
  // = "upper sixteen bits of Q17.15 value" (apply_freqN_q[31:16], NOT the
  // full 32-bit value -- dfc_event_record_t's event_data field is only 32
  // bits and C.7 explicitly narrows it), bits 16-23 = subtype, bits 24-31
  // reserved zero (no channel indicator -- see header/OPEN_ISSUES.md).
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate0, evt_candidate1;
  always_comb begin
    evt_candidate0 = '0;
    evt_candidate0[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_PULSE;
    evt_candidate0[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL009;
    // apply_freq_q, not freq_q: assembled COMBINATIONALLY in the same cycle
    // apply_fire_q pulses -- freq_q (the status-visible register) only
    // picks up this commit's value one cycle later, same one-cycle-lag
    // reasoning as dfc_rtl007.sv's own identical comment.
    evt_candidate0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 16] = ch0_apply_freq_q[31:16];
    evt_candidate0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = evt_subtype_comb0;
  end
  always_comb begin
    evt_candidate1 = '0;
    evt_candidate1[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_PULSE;
    evt_candidate1[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL009;
    evt_candidate1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 16] = ch1_apply_freq_q[31:16];
    evt_candidate1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = evt_subtype_comb1;
  end

  logic                                              evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  evt_record_q;
  logic                                              event_overflow_q;
  logic [15:0]                                       event_drop_count_q;

  // Shared-slot arbitration: channel 0 wins ties (see header). A channel's
  // candidate is either captured or genuinely dropped this cycle -- never
  // silently lost with no accounting.
  wire slot_available = !evt_pending_q || (evt_pending_q && evt_ready_i);
  wire capture_ch0 = ch0_evt_candidate_valid && slot_available;
  wire capture_ch1 = ch1_evt_candidate_valid && slot_available && !ch0_evt_candidate_valid;
  wire drop_ch0    = ch0_evt_candidate_valid && !slot_available;
  wire drop_ch1    = ch1_evt_candidate_valid && (!slot_available || ch0_evt_candidate_valid);
  wire [1:0] drop_count_this_cycle = {1'b0, drop_ch0} + {1'b0, drop_ch1};
  wire overflow_sets_this_cycle = (drop_count_this_cycle != 2'd0);

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

      if (capture_ch0) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate0;
      end else if (capture_ch1) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate1;
      end

      if (drop_count_this_cycle != 2'd0) begin
        event_overflow_q <= 1'b1;
        if (event_drop_count_q <= (16'hFFFF - {14'd0, drop_count_this_cycle}))
          event_drop_count_q <= event_drop_count_q + {14'd0, drop_count_this_cycle};
        else
          event_drop_count_q <= 16'hFFFF;
      end

      // Real host clear-request for RTL009_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-2250) -- new-overflow-evidence-dominates-clear, same priority
      // as every prior module's identical fix.
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // Ready/fault (see header) + fault_req_o.
  // ==========================================================================
  wire ch0_fault_live = ch0_illegal_config || ch0_timeout_now;
  wire ch1_fault_live = ch1_illegal_config || ch1_timeout_now;
  wire fault_live = ch0_fault_live || ch1_fault_live;
  assign fault_req_o = fault_live;

  // ==========================================================================
  // status_o packing (dfc_rtl009_status_t, 159 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL009_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__READY_HI] = !ch0_illegal_config && !ch1_illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__FAULT_HI] = fault_live;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_STATUS__VALID_HI]       = ch0_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_STATUS__LOW_HI]        = ch0_low_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_STATUS__HIGH_HI]       = ch0_high_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_STATUS__TIMEOUT_HI]     = ch0_timeout_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_STATUS__RANGE_ERROR_HI] = ch0_range_error_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_STATUS__UPDATED_HI]     = ch0_updated_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_FREQ_Q17_15__FREQUENCY_Q17_15_HI:dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_FREQ_Q17_15__FREQUENCY_Q17_15_LO] = ch0_freq_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_PERIOD_TICKS__PERIOD_TICKS_HI:dfc_types_pkg::DFC_RTL009_STATUS__PULSE0_PERIOD_TICKS__PERIOD_TICKS_LO] = ch0_period_ticks_readback_q;

    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_STATUS__VALID_HI]       = ch1_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_STATUS__LOW_HI]        = ch1_low_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_STATUS__HIGH_HI]       = ch1_high_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_STATUS__TIMEOUT_HI]     = ch1_timeout_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_STATUS__RANGE_ERROR_HI] = ch1_range_error_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_STATUS__UPDATED_HI]     = ch1_updated_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_FREQ_Q17_15__FREQUENCY_Q17_15_HI:dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_FREQ_Q17_15__FREQUENCY_Q17_15_LO] = ch1_freq_q;
    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_PERIOD_TICKS__PERIOD_TICKS_HI:dfc_types_pkg::DFC_RTL009_STATUS__PULSE1_PERIOD_TICKS__PERIOD_TICKS_LO] = ch1_period_ticks_readback_q;

    status_comb[dfc_types_pkg::DFC_RTL009_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL009_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): operating_state_i/
  // observational_mode_i are real, structurally-required ports with no
  // functional use in this implementation (see header). ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i;

endmodule : dfc_rtl009
