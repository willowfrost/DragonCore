// dfc_rtl007.sv -- RTL-007 Rotor RPM Monitor: single-edge-input RPM
// measurement with automatic hysteretic period/count-mode switching,
// configurable thresholds/hysteresis/timeout, and fault-request output
// (ARCH-002 SS9 ARCH-MON-002/003/005, Appendix F.1 ARCH-RTL007-001,
// Appendix F.3 index 6). Owns REG-002's Rotor RPM block (0x2000-0x20FF,
// 11 registers). First module in the Monitoring domain.
//
// Controlling documents: docs/rtl_specs/RTL-007_RevA.md, RCA-DFC-ARCH-002
// SS9/Appendix B.5/Appendix F.1 ARCH-RTL007-001/Appendix F.3 index 6/
// Appendix C.5/C.7 event ID 0x0030/ARCH-VAL-007, RCA-DFC-REG-002 SS19
// (0x2000-0x2028).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// ONE REAL ARCH-002 GAP, FOUND AND FIXED BEFORE this module was implemented
// -- explicitly anticipated by this project's own task instructions given
// the six prior real instances of this exact gap class (RTL-002/003's
// EVT_OVERFLOW_STATUS, RTL-004's SNAPSHOT_VALID/SYNC_VALID, RTL-005's
// SNAPSHOT_VALID, RTL-006's EVT_OVERFLOW_STATUS):
//   dfc_rtl007_control_t (135 bits) had no clear-request field for
//   RTL007_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x2024 bit 0, a real
//   W1C field). Fixed: ARCH-002 grew the struct 135->136 bits, adding
//   rtl007_evt_overflow_status__event_overflow at the new highest bit
//   (135) -- every pre-existing field's bit position confirmed unchanged
//   via a real regenerate.ps1 run (every _HI/_LO constant below bit 135 is
//   byte-identical to before this fix).
//
// A SECOND CHECK, PERFORMED BEFORE IMPLEMENTATION (per OPEN_ISSUES.md items
// 21/23's own lesson): RTL007_EVT_OVERFLOW_STATUS's real host-READ path is
// wired from the start via tools/reggen/rtl007_field_map.json's own
// status_registers section (mapped onto this struct's generic
// event_overflow/event_drop_count fields), NOT reproducing the still-open
// RTL-002/003/004 readback gap (OPEN_ISSUES.md item 21) -- same discipline
// already established for RTL-006.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (ARCH-MON-002/003/005,
// ARCH-RTL007-001, ARCH-VAL-007):
//
//   - CDC (RTLSTD-CDC-008 / CDC-PULSE): a plain two-flop synchronizer on the
//     raw async `rotor_i` pad (`sync1_q`/`sync2_q`) -- edge qualification
//     (MIN_EDGE_CYCLES) below already serves the debounce role a dedicated
//     qualification stage would play elsewhere in this project (e.g.
//     dfc_rtl006.sv's own ms-scale qualifier), so no separate debounce
//     stage is added here; this matches the module spec's own text (CDC
//     synchronization "before any use", nothing more).
//   - SELECTED EDGE: `rotor_control__rising_edge` chooses which raw
//     transition (rising or falling) of the synchronized input is the
//     "selected edge" ARCH-MON-002 qualifies.
//   - EDGE QUALIFICATION (ARCH-MON-002): a free-running `cycles_since_
//     accepted_q` saturating counter tracks time since the last ACCEPTED
//     edge; a new selected-edge pulse is accepted only once this counter
//     is >= `rotor_edge_filter__min_edge_cycles`. On acceptance, the
//     counter's PRE-reset value (read LIVE/combinationally, never through
//     a registered intermediate copy -- see `cycles_since_accepted_q`'s
//     own in-code comment for the real, found-and-fixed one-cycle-lag bug
//     that shape hit during this module's own bring-up) becomes this
//     edge's measured period, and the counter resets to 0.
//   - MODE SELECTION (ARCH-MON-002's own hysteretic rule): this measured
//     period is measured on EVERY accepted edge regardless of the module's current
//     active mode (a deliberate, disclosed design choice -- this is what
//     lets the same single history mechanism serve both transition
//     directions: "2 consecutive periods <1,000" to enter count mode from
//     period mode, and "2 consecutive periods >1,250" to return, without a
//     second, redundant measurement path). A 2-deep shift register
//     (`mode_hist_q`) records the relevant pass/fail test for the current
//     mode on each accepted edge (after the first, which has no valid
//     period yet -- `have_prior_edge_q` gates this); two consecutive passes
//     switch the mode and reset the history. The count-mode gate itself
//     (`gate_counter_q`, a free-running 100,000-cycle window while in count
//     mode) is independent of this classification counter.
//   - RPM ARITHMETIC (ARCH-MON-003): TIES ROUND UP via an explicit
//     remainder-based test (`2*remainder >= divisor`), not a `N+D/2`
//     pre-add (which would require an extra guard bit and is no easier to
//     reason about). The >=64-bit-intermediate requirement, AND this
//     project's own real, hard-won lesson from RTL-005's round-robin
//     arbiter (OPEN_ISSUES.md item 17: N chained/parallel per-candidate
//     arithmetic operations blew the 50 MHz timing budget; the real fix was
//     ONE registered operation per cycle, not many), are both satisfied
//     the same way: a bit-serial, 64-iteration shift-subtract divider
//     (`meas_state_e` FSM) performing exactly ONE 64-bit subtract+compare
//     per CORE_CLK cycle, not a single combinational 64-bit `/` operator
//     (which this project's own toolchain findings make clear would
//     synthesize as a deep chain of subtractors and very likely fail
//     timing the same way 24 chained adders did). A measurement commit is
//     relatively rare (at most once per accepted edge in period mode, or
//     once per 100,000-cycle gate in count mode) -- 64 CORE_CLK cycles
//     (1.28 us at the nominal 50 MHz) is negligible against either
//     timescale. If a new commit trigger arrives while the divider is
//     already busy, it is latched as a single pending redo (the latest
//     trigger's operands overwrite any earlier still-pending one -- a
//     disclosed simplification: only the newest measurement's threshold/
//     event consequences are guaranteed to be reported, not every
//     intermediate one, for the practically-unreachable case of commit
//     triggers arriving faster than 64 CORE_CLK cycles apart).
//     PPR == 0 (a real division-by-zero risk RTL-001 does not yet reject,
//     OPEN_ISSUES.md item 4) is defended against explicitly: the divide is
//     skipped and the result forced to the saturated maximum with
//     RANGE_ERROR set, never actually dividing by a captured-zero divisor.
//   - THRESHOLD/HYSTERESIS (ARCH-MON-005): evaluated in the measurement's
//     own APPLY cycle (the single cycle the divider's result, rpm_q, and
//     ROTOR_PERIOD_TICKS's readback all update together) -- satisfying "a
//     newly committed measurement precedes threshold-event evaluation"
//     literally: threshold comparison reads the fresh value in the exact
//     cycle it becomes the new committed value, never the stale one.
//     LOW/HIGH+HYST/HIGH-HYST saturate (never wrap) via explicit clamped
//     16-bit add/subtract, per ARCH-MON-005's own text. LOW and HIGH are
//     hysteretic LATCHES (not W1C), retaining their value between commits
//     until their own exit condition is met -- the same "enter/exit with a
//     dead band" idiom the spec's own text describes.
//   - EVENT SUBTYPE ENCODING (0x0030, Appendix C.7's own row: "0 low, 1
//     high, 2 timeout, 3 updated, 4 saturation, 5 recovery, 6 configuration
//     reject", event_data = "saturated RPM"): this is a DIFFERENT
//     enumeration, for a different purpose, than Appendix F.3's own
//     condition-mask bit allocation for RTL-007 ("0 low; 1 high; 2 timeout;
//     3 updated; 4 recovery; 5 saturation/range; 6 event-slot overflow",
//     confirmed directly against ARCH-002's own F.3 table, matching
//     RTL-007_RevA.md SS2 verbatim) -- the two numbering schemes are not
//     required to agree (RTL-006's own F.3 allocation and its own
//     event_data subtype encoding already have unrelated shapes; this is
//     the established, expected pattern in this project, not a spec
//     conflict to resolve). This module therefore uses TWO distinct
//     3-bit-or-fewer encodings in the places each is actually cited: F.3's
//     ordering gates `event_condition_enable_i`/`irq_condition_enable_i`
//     bit selection (bits 0-5; bit 6, event-slot overflow, has no real
//     consumer here, same as every other module's identically-shaped,
//     functionally-unused "own overflow" mask bit); C.7's ordering packs
//     the winning subtype into the generated event record's `event_data`
//     lower byte. "Configuration reject" (C.7 subtype 6) has no
//     corresponding F.3 mask bit at all -- treated as a MANDATORY event
//     (the F.3 preamble's own `mandatory_event |` term), i.e. never gated
//     by EVENT_ENABLE/the condition mask, since illegal-configuration
//     detection already implies `rotor_control__enable` is set (see below)
//     and there is no dedicated enable bit for it to gate on regardless.
//     Priority among conditions co-occurring in the same APPLY/detect
//     cycle (disclosed, locally chosen, same basis as every other module's
//     analogous choice): configuration-reject > timeout > saturation/range
//     > low-enter > high-enter > recovery (low/high exit) > updated
//     (plain commit, no threshold transition).
//   - ILLEGAL CONFIGURATION (ARCH-VAL-007): `0 <= LOW <= HIGH <= 1000`,
//     `HYST <= HIGH-LOW`, `PPR` nonzero when enabled, and `TIMEOUT_US`
//     nonzero when enabled are all directly checkable against this
//     module's real fields and implemented as live (non-sticky)
//     `illegal_config`, the same "defend against what RTL-001 doesn't yet
//     reject" precedent already established by dfc_rtl003/006.sv (RTL-001
//     has no per-field legal-range write validation yet, OPEN_ISSUES.md
//     item 4). ARCH-VAL-007's remaining clause, "qualification 0-100 ms",
//     has NO corresponding field anywhere in RTL-007's real register set
//     (`ROTOR_EDGE_FILTER.MIN_EDGE_CYCLES` is a raw CORE_CLK-cycle count,
//     not a millisecond value, and no other "qualification" concept exists
//     for this module) -- almost certainly copied forward from
//     ARCH-VAL-006's own GPIO-specific qualification-time clause rather
//     than an intentional RTL-007 constraint. Disclosed as not implemented/
//     not applicable rather than silently invented a meaning for; not
//     logged as a blocking OPEN_ISSUES.md item since it has zero
//     functional consequence either way (no field exists to range-check).
//   - READY/FAULT: `ready = !illegal_config` (configuration legality only,
//     same pattern as dfc_rtl006.sv). `fault`/`fault_req_o` = live
//     `illegal_config OR timeout_now` (a currently-elapsed no-edge
//     condition, re-derived from the live counter/threshold each cycle,
//     not the sticky W1C `TIMEOUT` evidence bit) -- matching the fault
//     matrix's own "active condition plus RTL-013 sticky evidence" text
//     (RTL-013 does not exist yet to latch it; `fault_req_o` is left
//     genuinely unconsumed in dfc_rtl024.sv, same disclosed pattern as
//     every other not-yet-existing RTL-013 consumer in this project).
//   - `module_enable_i` (optional-mask module, per its own port semantic
//     "disabled module contributes no degraded/fault request"): gates all
//     measurement/event/irq/fault activity together with
//     `rotor_control__enable` via a single derived `active` signal, the
//     most conservative reading consistent with the port's own documented
//     semantic. `operating_state_i`/`observational_mode_i` are real,
//     structurally-required ports with no functional use in this
//     implementation (RTL-007's own spec text never names either in an
//     equation, unlike dfc_rtl006.sv's explicit OE contract) -- same
//     disclosed-no-use precedent already established for these same ports
//     on dfc_rtl003/005.sv; sunk via the unused-port sink below.
// ============================================================================

module dfc_rtl007 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[6]

  // TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
  // Yosys build -- see dfc_rtl002.sv's header for the full account): a
  // package-scoped type cannot be a port's declared type. Every such port
  // here is a plain `logic [W-1:0]` vector sized via generated
  // `dfc_types_pkg::DFC_*_WIDTH` VALUE constants instead.
  input  logic [dfc_types_pkg::DFC_RTL007_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,
  output logic         fault_req_o,      // RTL-013.fault_source_i[6] -- no
                                          // real consumer yet, RTL-013 does
                                          // not exist. Left genuinely
                                          // unconsumed in dfc_rtl024.sv.

  input  logic         rotor_i,          // raw external edge input,
                                          // CDC-PULSE -- this module owns
                                          // the two-flop synchronizer

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic         module_enable_i,           // RTL-002.module_enable_o[6]

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 6
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 6
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as every module from RTL-003
  // onward) ----
  wire        ctl_enable        = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_CONTROL__ENABLE_HI];
  wire        ctl_rising_edge   = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_CONTROL__RISING_EDGE_HI];
  wire        ctl_event_enable  = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_CONTROL__EVENT_ENABLE_HI];
  wire        ctl_irq_enable    = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_CONTROL__IRQ_ENABLE_HI];
  wire        ctl_clear_timeout      = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_STATUS__TIMEOUT_HI];
  wire        ctl_clear_range_error  = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_STATUS__RANGE_ERROR_HI];
  wire        ctl_clear_updated      = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_STATUS__UPDATED_HI];
  wire [15:0] ctl_thresh_low     = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_THRESH_LOW__THRESHOLD_HI:dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_THRESH_LOW__THRESHOLD_LO];
  wire [15:0] ctl_thresh_high    = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_THRESH_HIGH__THRESHOLD_HI:dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_THRESH_HIGH__THRESHOLD_LO];
  wire [15:0] ctl_ppr            = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_PULSES_PER_REV__PPR_HI:dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_PULSES_PER_REV__PPR_LO];
  wire [31:0] ctl_timeout_us     = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_TIMEOUT_US__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_TIMEOUT_US__TIMEOUT_US_LO];
  wire [31:0] ctl_min_edge_cycles = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_EDGE_FILTER__MIN_EDGE_CYCLES_HI:dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_EDGE_FILTER__MIN_EDGE_CYCLES_LO];
  wire [15:0] ctl_hysteresis     = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_HYSTERESIS__HYSTERESIS_HI:dfc_types_pkg::DFC_RTL007_CONTROL__ROTOR_HYSTERESIS__HYSTERESIS_LO];
  wire        ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL007_CONTROL__RTL007_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire active = ctl_enable && module_enable_i;  // see header: gates all
                                                  // measurement/event/irq/
                                                  // fault activity together

  // ==========================================================================
  // CDC synchronizer (RTLSTD-CDC-008 / CDC-PULSE) + selected-edge detect.
  // ==========================================================================
  logic sync1_q, sync2_q, sync2_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sync1_q <= 1'b0; sync2_q <= 1'b0; sync2_prev_q <= 1'b0;
    end else begin
      sync1_q      <= rotor_i;
      sync2_q      <= sync1_q;
      sync2_prev_q <= sync2_q;
    end
  end
  wire rising_raw  = sync2_q & ~sync2_prev_q;
  wire falling_raw = ~sync2_q & sync2_prev_q;
  wire selected_edge = ctl_rising_edge ? rising_raw : falling_raw;

  // ==========================================================================
  // Edge qualification (ARCH-MON-002): accept only after MIN_EDGE_CYCLES
  // since the preceding accepted edge. On acceptance, the counter's
  // pre-reset value becomes the new measured period.
  // ==========================================================================
  logic [31:0] cycles_since_accepted_q;
  logic        have_prior_edge_q;
  logic        min_edge_met_q;

  // min_edge_met_q: a sticky latch replacing a direct wide (32-bit)
  // magnitude comparison (cycles_since_accepted_q >= ctl_min_edge_cycles)
  // against a fully variable, live threshold -- a real, found-and-fixed
  // timing-closure bug, not a stylistic change: this comparator,
  // duplicated identically in dfc_rtl008.sv (ARCH-RTL008-001's own
  // "same algorithm, separate instance"), pushed the combined design's
  // real critical path over the 50 MHz budget once RTL-008 existed
  // alongside this module's own already-narrow 52.87 MHz margin --
  // confirmed via 4 real build attempts (default, -noabc9, and two
  // different -Seed retries, all genuinely failing 43-49 MHz, never
  // reaching 50) before concluding this was a real design-margin problem,
  // not placement luck (per this project's own standing "retry before
  // assuming a real problem" discipline, OPEN_ISSUES.md item 7). Fixed
  // the same architectural way as RTL-005's own round-robin-arbiter
  // timing fix (OPEN_ISSUES.md item 17): replace an expensive per-cycle
  // ARITHMETIC comparison with a cheap EQUALITY test plus a registered
  // sticky bit. cycles_since_accepted_q increments by exactly 1 every
  // cycle it doesn't reset, so it passes through every integer value on
  // its way up, including ctl_min_edge_cycles itself -- the exact cycle
  // equality first holds is the same cycle the original ">=" comparison
  // first held (no off-by-one), and the sticky latch then holds true for
  // every subsequent cycle until the next accepted edge, matching ">="
  // staying true forever after the threshold is first reached.
  // DISCLOSED, narrow behavioral difference from the original (approved
  // before this fix was made): a host write that LOWERS MIN_EDGE_CYCLES
  // mid-flight, strictly AFTER the live counter has already passed the
  // new, lower value, will not retroactively qualify until the NEXT
  // accepted edge resets the measurement window (the original, live
  // combinational ">=" comparator would have reacted the same cycle) --
  // not exercised by any real test in this project, disclosed here rather
  // than silently accepted.
  wire min_edge_reached_now = (cycles_since_accepted_q == ctl_min_edge_cycles);
  wire min_edge_is_zero     = (ctl_min_edge_cycles == 32'd0);
  wire edge_qualified = selected_edge && active &&
                        (min_edge_met_q || min_edge_reached_now);

  // NOTE: the just-completed period is deliberately read as the LIVE
  // cycles_since_accepted_q value (below, and at every other use-site in
  // this file), never a registered "period_ticks_q" copy of it -- a real,
  // found-and-fixed bug during this module's own bring-up: a registered
  // copy updated via `period_ticks_q <= cycles_since_accepted_q` in this
  // same always_ff, read combinationally by other logic in the SAME
  // clock cycle the edge that triggers that read also arrives, sees the
  // STALE pre-update value (nonblocking-assignment semantics), not the
  // fresh one -- confirmed via a real simulation failure (ROTOR_RPM
  // saturated to 0xFFFF because the divisor was genuinely zero: the very
  // first commit's divisor read period_ticks_q's still-zero reset value,
  // one cycle before the update carrying the real 3000-tick period ever
  // became visible). cycles_since_accepted_q itself has no such lag: at
  // the exact cycle new_period_valid is high, it still holds its
  // pre-reset value (the reset to 0 is a nonblocking assign in this same
  // cycle, not yet visible), which IS the just-completed period -- reading
  // it directly, everywhere, is what actually fixes this.
  //
  // A SECOND real, found-and-fixed off-by-one, discovered the same way
  // (ROTOR_PERIOD_TICKS read one tick short of the real, testbench-driven
  // gap): resetting the counter to 0 on acceptance means its value, read
  // combinationally on the NEXT accepted edge, reflects only the cycles
  // strictly BETWEEN the two edges' own recognition cycles, not counting
  // the recognition cycle itself -- i.e. exactly one short of the true
  // elapsed CORE_CLK cycle count. Resetting to 1 instead (this counter
  // means "cycles elapsed since the last accepted edge, INCLUSIVE of the
  // current cycle") makes both this comparison and the MIN_EDGE_CYCLES
  // qualification test above read the true, real elapsed cycle count with
  // no further correction needed anywhere else in this file.
  // NOTE: the real async reset (core_rst_n_i) is checked in its own,
  // standalone top-level `if`, never OR'd together with module_reset_i/
  // !active in the same branch -- a real, confirmed Yosys PROC_DFF
  // failure ("Multiple edge sensitive events found for this signal!")
  // this exact module hit during its own bring-up, matching the standing,
  // project-wide rule already documented in PROJECT_CONTINUITY.md
  // Section 2 (first found on dfc_rtl002.sv's own compound-reset
  // condition). Every always_ff below follows this same corrected shape.
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      cycles_since_accepted_q <= 32'd0;
      have_prior_edge_q       <= 1'b0;
      min_edge_met_q          <= 1'b0;
    end else if (module_reset_i || !active) begin
      cycles_since_accepted_q <= 32'd0;
      have_prior_edge_q       <= 1'b0;
      min_edge_met_q          <= 1'b0;
    end else if (edge_qualified) begin
      have_prior_edge_q        <= 1'b1;
      cycles_since_accepted_q  <= 32'd1;
      min_edge_met_q           <= min_edge_is_zero;
    end else begin
      if (cycles_since_accepted_q != 32'hFFFFFFFF)
        cycles_since_accepted_q <= cycles_since_accepted_q + 32'd1;
      if (min_edge_reached_now)
        min_edge_met_q <= 1'b1;
    end
  end

  wire new_period_valid = edge_qualified && have_prior_edge_q;

  // ==========================================================================
  // Mode selection (ARCH-MON-002 hysteresis): period mode <-> count mode.
  // ==========================================================================
  typedef enum logic { MODE_PERIOD, MODE_COUNT } mode_e;
  mode_e mode_q;
  logic [1:0] mode_hist_q;

  wire mode_test_this_period = (mode_q == MODE_PERIOD) ? (cycles_since_accepted_q < 32'd1000)
                                                        : (cycles_since_accepted_q > 32'd1250);
  wire mode_switch = new_period_valid && mode_test_this_period && mode_hist_q[0];

  // ==========================================================================
  // Count-mode gate counter (100,000-cycle window) + edge counter.
  // ==========================================================================
  localparam int unsigned COUNT_GATE_CYCLES = 100_000;
  logic [16:0] gate_counter_q;
  logic [31:0] edge_count_q;
  wire gate_expire = (mode_q == MODE_COUNT) && active &&
                     (gate_counter_q == COUNT_GATE_CYCLES-1);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      mode_q         <= MODE_PERIOD;
      mode_hist_q    <= 2'b00;
      gate_counter_q <= 17'd0;
      edge_count_q   <= 32'd0;
    end else if (module_reset_i || !active) begin
      mode_q         <= MODE_PERIOD;
      mode_hist_q    <= 2'b00;
      gate_counter_q <= 17'd0;
      edge_count_q   <= 32'd0;
    end else begin
      if (mode_switch) begin
        if (mode_q == MODE_PERIOD) mode_q <= MODE_COUNT;
        else                        mode_q <= MODE_PERIOD;
        mode_hist_q    <= 2'b00;
        gate_counter_q <= 17'd0;
        edge_count_q   <= 32'd0;
      end else if (new_period_valid) begin
        mode_hist_q <= {mode_hist_q[0], mode_test_this_period};
      end

      if (!mode_switch) begin
        if (mode_q == MODE_COUNT) begin
          if (gate_expire) begin
            gate_counter_q <= 17'd0;
            edge_count_q   <= 32'd0;
          end else begin
            gate_counter_q <= gate_counter_q + 17'd1;
            if (edge_qualified && edge_count_q != 32'hFFFFFFFF)
              edge_count_q <= edge_count_q + 32'd1;
          end
        end
      end
    end
  end

  // ==========================================================================
  // RPM measurement divider (ARCH-MON-003): bit-serial 64-iteration
  // shift-subtract division, one 64-bit subtract+compare per cycle -- see
  // header for why this is not a single combinational `/` operator.
  // ==========================================================================
  typedef enum logic [1:0] { MEAS_IDLE, MEAS_MULT, MEAS_RUN, MEAS_APPLY } meas_state_e;
  meas_state_e meas_state_q;
  logic [5:0]  meas_iter_q;
  logic [63:0] meas_rem_q, meas_quot_q, meas_divisor_q;
  // Ties round up: 2*remainder >= divisor -- computed combinationally from
  // whichever values meas_rem_q/meas_quot_q/meas_divisor_q hold; only
  // meaningful (and only read) during the MEAS_APPLY cycle, once the
  // divider has actually finished. Declared here, at module scope, rather
  // than as `automatic` locals inside the case item below -- consistent
  // with this project's own established style of plain module-scope wires
  // for every other combinational expression in this file.
  wire [64:0] meas_rem_x2      = {meas_rem_q, 1'b0};
  wire [64:0] meas_divisor_ext = {1'b0, meas_divisor_q};
  wire        meas_round_up    = (meas_rem_x2 >= meas_divisor_ext);
  wire [64:0] meas_rpm_wide    = {1'b0, meas_quot_q} + (meas_round_up ? 65'd1 : 65'd0);
  logic        meas_divzero_q;

  wire period_commit_trig = new_period_valid && (mode_q == MODE_PERIOD) && !mode_switch;
  wire count_commit_trig  = gate_expire && !mode_switch;
  wire any_commit_trig    = period_commit_trig || count_commit_trig;

  // A real, found-and-fixed multi-step timing-closure investigation,
  // needed after RTL-008 came into existence alongside this module and
  // pushed the combined design's real critical path over the 50 MHz
  // budget (confirmed via 4 real build attempts on the ORIGINAL edge-
  // qualification comparator alone: default/-noabc9/-Seed 1/-Seed
  // 42-class, all genuinely failing 43-49 MHz). Two further real,
  // sequential fixes were needed beyond that comparator fix, each found by
  // actually re-running nextpnr and reading its new critical path report,
  // not guessed:
  //   1. Making the two mutually-exclusive divider multiplies' resource
  //      sharing EXPLICIT (mux the multiply's own INPUTS before
  //      multiplying instead of muxing the two multiplies' RESULTS
  //      afterward) -- this alone did not close timing (confirmed via a
  //      real subsequent nextpnr run, 48.48 MHz), because a genuinely
  //      correctly-sized 32x16 multiplier feeding DIRECTLY into a register
  //      in the SAME cycle it is selected is still real, unavoidable
  //      combinational cost (8.83 ns logic + 11.80 ns routing, confirmed
  //      via that same run's own critical path report) -- duplicated
  //      identically in dfc_rtl008.sv.
  //   2. PIPELINING the multiply into its own, isolated register-to-
  //      register step (this block, below): capture the cheaply-selected
  //      operands into registers the cycle a commit trigger arrives, then
  //      perform the actual multiply in a dedicated MEAS_MULT state, and
  //      only then load meas_quot_q/meas_divisor_q for MEAS_RUN. This adds
  //      exactly one CORE_CLK cycle of latency before the divider's own
  //      already-established 64-cycle run (65 cycles total, ~1.3 us at
  //      50 MHz instead of ~1.28 us) -- a real, disclosed, but
  //      functionally and numerically IDENTICAL-result timing change, not
  //      a shortcut: every existing testbench's own generous
  //      divider-latency margin (100 CORE_CLK cycles, wait_for_divide())
  //      already comfortably covers this. BOTH real entry points that
  //      previously fed a multiply directly into a register in the same
  //      cycle -- a fresh trigger arriving while MEAS_IDLE, and a queued
  //      "redo" trigger that arrived while the divider was already busy --
  //      now funnel through this SAME MEAS_MULT state, so neither remains
  //      a same-cycle-multiply-into-register path (the redo path was a
  //      real, easy-to-miss second instance of the identical problem: a
  //      per-candidate audit found it, not inspection of the "obvious"
  //      path alone).
  wire [31:0] mult_operand_a_c = period_commit_trig ? cycles_since_accepted_q : edge_count_q;
  // Narrowed to 16 bits, matching the real width of both real operands
  // (ctl_ppr is a real 16-bit REG-002 field; 30,000 fits in 16 bits) -- a
  // real, self-found regression in this fix's own first draft: widening
  // this operand to 32 bits (matching mult_operand_a_c's width, for no
  // real reason) made the multiplier a full 32x32 rather than the
  // original, smaller 32x16 shape.
  wire [15:0] mult_operand_b_c = period_commit_trig ? ctl_ppr : 16'd30_000;
  wire        commit_divzero_c = (ctl_ppr == 16'd0);

  // The "active" operand set for whichever multiply MEAS_MULT is about to
  // perform -- captured combinationally-selected values above into
  // registers, isolating the actual multiply into its own cycle (see
  // header). Refreshed unconditionally whenever any_commit_trig fires
  // (below), regardless of meas_state_q, since once MEAS_MULT has
  // consumed the previous contents (copying the product into
  // meas_quot_q/meas_divisor_q), these registers are free to hold the
  // newest trigger's operands even while MEAS_RUN/MEAS_APPLY are still
  // processing the earlier commit -- the same "latest wins" disclosed
  // simplification as before, just applied one pipeline stage earlier.
  logic        active_is_period_q;
  logic [31:0] active_mult_a_q;
  logic [15:0] active_mult_b_q;
  logic [15:0] active_ppr_q;
  logic        active_divzero_q;
  logic        mult_pending_q;  // a redo should run through MEAS_MULT again after the current divide finishes

  wire [63:0] active_mult_result_c = {32'd0, active_mult_a_q} * {48'd0, active_mult_b_q};

  wire [63:0] meas_new_rem_c = {meas_rem_q[62:0], meas_quot_q[63]};

  logic       apply_fire_q;
  logic [15:0] apply_rpm_q;
  logic        apply_range_error_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      meas_state_q             <= MEAS_IDLE;
      meas_iter_q              <= 6'd0;
      meas_rem_q               <= 64'd0;
      meas_quot_q              <= 64'd0;
      meas_divisor_q           <= 64'd0;
      meas_divzero_q           <= 1'b0;
      active_is_period_q       <= 1'b0;
      active_mult_a_q          <= 32'd0;
      active_mult_b_q          <= 16'd0;
      active_ppr_q             <= 16'd0;
      active_divzero_q         <= 1'b0;
      mult_pending_q           <= 1'b0;
      apply_fire_q             <= 1'b0;
      apply_rpm_q              <= 16'd0;
      apply_range_error_q      <= 1'b0;
    end else if (module_reset_i || !active) begin
      meas_state_q             <= MEAS_IDLE;
      meas_iter_q              <= 6'd0;
      meas_rem_q               <= 64'd0;
      meas_quot_q              <= 64'd0;
      meas_divisor_q           <= 64'd0;
      meas_divzero_q           <= 1'b0;
      active_is_period_q       <= 1'b0;
      active_mult_a_q          <= 32'd0;
      active_mult_b_q          <= 16'd0;
      active_ppr_q             <= 16'd0;
      active_divzero_q         <= 1'b0;
      mult_pending_q           <= 1'b0;
      apply_fire_q             <= 1'b0;
      apply_rpm_q              <= 16'd0;
      apply_range_error_q      <= 1'b0;
    end else begin
      apply_fire_q <= 1'b0;

      unique case (meas_state_q)
        MEAS_IDLE: begin
          if (any_commit_trig) meas_state_q <= MEAS_MULT;
        end
        MEAS_MULT: begin
          // The isolated, register-to-register multiply step -- see
          // header for why this exists as its own state.
          meas_quot_q    <= active_is_period_q ? 64'd3_000_000_000 : active_mult_result_c;
          meas_rem_q     <= 64'd0;
          meas_divisor_q <= active_is_period_q ? active_mult_result_c : {48'd0, active_ppr_q};
          meas_divzero_q <= active_divzero_q;
          meas_iter_q    <= 6'd63;
          meas_state_q   <= MEAS_RUN;
        end
        MEAS_RUN: begin
          if (meas_divzero_q) begin
            // defended divide-by-zero: skip arithmetic, force saturated
            // max with RANGE_ERROR (see header).
            meas_quot_q  <= 64'hFFFF_FFFF_FFFF_FFFF;
            meas_rem_q   <= 64'd0;
            meas_state_q <= MEAS_APPLY;
          end else if (meas_new_rem_c >= meas_divisor_q) begin
            meas_rem_q  <= meas_new_rem_c - meas_divisor_q;
            meas_quot_q <= {meas_quot_q[62:0], 1'b1};
            if (meas_iter_q == 6'd0) meas_state_q <= MEAS_APPLY;
            else                     meas_iter_q  <= meas_iter_q - 6'd1;
          end else begin
            meas_rem_q  <= meas_new_rem_c;
            meas_quot_q <= {meas_quot_q[62:0], 1'b0};
            if (meas_iter_q == 6'd0) meas_state_q <= MEAS_APPLY;
            else                     meas_iter_q  <= meas_iter_q - 6'd1;
          end
        end
        MEAS_APPLY: begin
          if (meas_divzero_q) begin
            apply_rpm_q         <= 16'hFFFF;
            apply_range_error_q <= 1'b1;
          end else if (meas_rpm_wide > 65'd65535) begin
            apply_rpm_q         <= 16'hFFFF;
            apply_range_error_q <= 1'b1;
          end else begin
            apply_rpm_q         <= meas_rpm_wide[15:0];
            apply_range_error_q <= 1'b0;
          end
          apply_fire_q <= 1'b1;
          if (mult_pending_q) begin
            mult_pending_q <= 1'b0;
            meas_state_q   <= MEAS_MULT;
          end else begin
            meas_state_q <= MEAS_IDLE;
          end
        end
        default: meas_state_q <= MEAS_IDLE;
      endcase

      // Refresh the "active" operand set whenever a new trigger arrives --
      // unconditional on state (see the signals' own declaration comment
      // above for why this is safe). While busy (not MEAS_IDLE), also
      // queue a redo so MEAS_APPLY loops back through MEAS_MULT once the
      // in-flight divide finishes (latest wins -- see header).
      if (any_commit_trig) begin
        active_is_period_q <= period_commit_trig;
        active_mult_a_q    <= mult_operand_a_c;
        active_mult_b_q    <= mult_operand_b_c;
        active_ppr_q       <= ctl_ppr;
        active_divzero_q   <= commit_divzero_c;
        if (meas_state_q != MEAS_IDLE) mult_pending_q <= 1'b1;
      end
    end
  end

  // ==========================================================================
  // Timeout (ARCH-MON-005): saturating microsecond elapsed-time counter
  // since the last accepted edge.
  // ==========================================================================
  localparam int unsigned US_CYCLES = 50;  // nominal 50 MHz CORE_CLK
                                             // (ARCH-CLK-001) -- same
                                             // disclosed assumption
                                             // dfc_rtl004.sv's own divider
                                             // already relies on.
  logic [5:0]  us_phase_q;
  logic        us_tick;
  logic [31:0] elapsed_us_q;

  assign us_tick = (us_phase_q == US_CYCLES-1);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)                                us_phase_q <= 6'd0;
    else if (module_reset_i || !active)               us_phase_q <= 6'd0;
    else if (us_tick)                                 us_phase_q <= 6'd0;
    else                                                us_phase_q <= us_phase_q + 6'd1;
  end

  logic timeout_now_prev_q;
  wire timeout_now = active && (ctl_timeout_us != 32'd0) &&
                     (elapsed_us_q >= ctl_timeout_us);
  wire timeout_new = timeout_now && !timeout_now_prev_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      elapsed_us_q       <= 32'd0;
      timeout_now_prev_q <= 1'b0;
    end else if (module_reset_i || !active) begin
      elapsed_us_q       <= 32'd0;
      timeout_now_prev_q <= 1'b0;
    end else begin
      timeout_now_prev_q <= timeout_now;
      if (edge_qualified) begin
        elapsed_us_q <= 32'd0;
      end else if (us_tick && elapsed_us_q != 32'hFFFFFFFF) begin
        elapsed_us_q <= elapsed_us_q + 32'd1;
      end
    end
  end

  // ==========================================================================
  // Illegal configuration (ARCH-VAL-007) -- live, not sticky.
  // ==========================================================================
  wire [15:0] hyst_budget = (ctl_thresh_high >= ctl_thresh_low) ?
                             (ctl_thresh_high - ctl_thresh_low) : 16'd0;
  wire illegal_config = ctl_enable && (
    (ctl_thresh_low  > 16'd1000) ||
    (ctl_thresh_high > 16'd1000) ||
    (ctl_thresh_low  > ctl_thresh_high) ||
    (ctl_hysteresis  > hyst_budget) ||
    (ctl_ppr == 16'd0) ||
    (ctl_timeout_us == 32'd0)
  );
  logic illegal_config_prev_q;
  wire  config_reject_new = illegal_config && !illegal_config_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)         illegal_config_prev_q <= 1'b0;
    else if (module_reset_i)   illegal_config_prev_q <= 1'b0;
    else                        illegal_config_prev_q <= illegal_config;
  end

  // ==========================================================================
  // Threshold latches (ARCH-MON-005: saturating enter/exit with hysteresis)
  // + sticky W1C status evidence, all updated in the measurement's own
  // APPLY cycle (see header).
  // ==========================================================================
  logic        valid_q;
  logic        low_q, high_q;
  logic [15:0] rpm_q;
  logic        timeout_sticky_q, range_error_sticky_q, updated_sticky_q;

  wire [16:0] low_exit_sum_w  = {1'b0, ctl_thresh_low}  + {1'b0, ctl_hysteresis};
  wire [15:0] low_exit_thresh  = (low_exit_sum_w > 17'd65535) ? 16'hFFFF : low_exit_sum_w[15:0];
  wire [15:0] high_exit_thresh = (ctl_thresh_high >= ctl_hysteresis) ?
                                  (ctl_thresh_high - ctl_hysteresis) : 16'd0;

  wire low_enter_test  = !low_q  && (apply_rpm_q <  ctl_thresh_low);
  wire low_exit_test   =  low_q  && (apply_rpm_q >= low_exit_thresh);
  wire high_enter_test = !high_q && (apply_rpm_q >  ctl_thresh_high);
  wire high_exit_test  =  high_q && (apply_rpm_q <= high_exit_thresh);

  wire low_enter_ev  = apply_fire_q && low_enter_test;
  wire high_enter_ev = apply_fire_q && high_enter_test;
  wire recovery_ev   = apply_fire_q && (low_exit_test || high_exit_test);
  wire saturation_ev = apply_fire_q && apply_range_error_q;
  wire updated_ev    = apply_fire_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      valid_q                       <= 1'b0;
      low_q                         <= 1'b0;
      high_q                        <= 1'b0;
      rpm_q                         <= 16'd0;
      timeout_sticky_q              <= 1'b0;
      range_error_sticky_q          <= 1'b0;
      updated_sticky_q              <= 1'b0;
    end else if (module_reset_i || !active) begin
      valid_q                       <= 1'b0;
      low_q                         <= 1'b0;
      high_q                        <= 1'b0;
      rpm_q                         <= 16'd0;
      timeout_sticky_q              <= 1'b0;
      range_error_sticky_q          <= 1'b0;
      updated_sticky_q              <= 1'b0;
    end else begin
      if (apply_fire_q) begin
        valid_q <= 1'b1;
        rpm_q   <= apply_rpm_q;
        if (low_enter_test)  low_q  <= 1'b1;
        else if (low_exit_test)  low_q  <= 1'b0;
        if (high_enter_test) high_q <= 1'b1;
        else if (high_exit_test) high_q <= 1'b0;
        updated_sticky_q <= 1'b1;
        if (apply_range_error_q) range_error_sticky_q <= 1'b1;
      end

      if (timeout_new) begin
        valid_q          <= 1'b0;
        low_q             <= 1'b0;
        high_q            <= 1'b0;
        timeout_sticky_q <= 1'b1;
      end

      // Real host clear-requests -- new-evidence-dominates-clear priority,
      // same as every prior module's identical fix.
      if (ctl_clear_timeout && !timeout_new)                        timeout_sticky_q     <= 1'b0;
      if (ctl_clear_range_error && !saturation_ev)                  range_error_sticky_q <= 1'b0;
      if (ctl_clear_updated && !updated_ev)                         updated_sticky_q     <= 1'b0;
    end
  end

  // period_ticks readback: updates immediately on each accepted edge
  // (a raw counter value, needs no divide) -- see header for why this is
  // allowed to be slightly ahead of the divided RPM value. Captures the
  // LIVE cycles_since_accepted_q value (see that signal's own comment for
  // why -- a registered intermediate copy read this same cycle is exactly
  // the real, found-and-fixed one-cycle-lag bug this module's own bring-up
  // hit).
  logic [31:0] period_ticks_readback_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)                                period_ticks_readback_q <= 32'd0;
    else if (module_reset_i || !active)               period_ticks_readback_q <= 32'd0;
    else if (new_period_valid)                        period_ticks_readback_q <= cycles_since_accepted_q;
  end

  // ==========================================================================
  // Own diagnostic event generation (event ID 0x0030, source index 6) --
  // real, one-deep pending shape identical to every prior module. Subtype
  // priority per header: config-reject > timeout > saturation > low-enter
  // > high-enter > recovery > updated.
  // ==========================================================================
  localparam logic [15:0] EVT_ID_ROTOR = 16'h0030;
  localparam logic [7:0]  EVT_SUBTYPE_LOW        = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_HIGH       = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_TIMEOUT    = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_UPDATED    = 8'd3;
  localparam logic [7:0]  EVT_SUBTYPE_SATURATION = 8'd4;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERY   = 8'd5;
  localparam logic [7:0]  EVT_SUBTYPE_CFG_REJECT = 8'd6;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL007 = 8'd6;  // ARCH-002 C.5 index 6

  wire ev_gate_low        = low_enter_ev  & ctl_event_enable & event_condition_enable_i[0];
  wire ev_gate_high       = high_enter_ev & ctl_event_enable & event_condition_enable_i[1];
  wire ev_gate_timeout    = timeout_new   & ctl_event_enable & event_condition_enable_i[2];
  wire ev_gate_updated    = updated_ev    & ctl_event_enable & event_condition_enable_i[3];
  wire ev_gate_recovery   = recovery_ev   & ctl_event_enable & event_condition_enable_i[4];
  wire ev_gate_saturation = saturation_ev & ctl_event_enable & event_condition_enable_i[5];
  wire ev_gate_cfgreject  = config_reject_new;  // mandatory event, see header

  wire iq_gate_low        = low_enter_ev  & ctl_irq_enable & irq_condition_enable_i[0];
  wire iq_gate_high       = high_enter_ev & ctl_irq_enable & irq_condition_enable_i[1];
  wire iq_gate_timeout    = timeout_new   & ctl_irq_enable & irq_condition_enable_i[2];
  wire iq_gate_updated    = updated_ev    & ctl_irq_enable & irq_condition_enable_i[3];
  wire iq_gate_recovery   = recovery_ev   & ctl_irq_enable & irq_condition_enable_i[4];
  wire iq_gate_saturation = saturation_ev & ctl_irq_enable & irq_condition_enable_i[5];

  assign irq_req_o = iq_gate_low | iq_gate_high | iq_gate_timeout | iq_gate_updated |
                      iq_gate_recovery | iq_gate_saturation;

  wire evt_candidate_valid = ev_gate_cfgreject | ev_gate_timeout | ev_gate_saturation |
                              ev_gate_low | ev_gate_high | ev_gate_recovery | ev_gate_updated;

  logic [7:0] evt_subtype_comb;
  always_comb begin
    if (ev_gate_cfgreject)       evt_subtype_comb = EVT_SUBTYPE_CFG_REJECT;
    else if (ev_gate_timeout)    evt_subtype_comb = EVT_SUBTYPE_TIMEOUT;
    else if (ev_gate_saturation) evt_subtype_comb = EVT_SUBTYPE_SATURATION;
    else if (ev_gate_low)        evt_subtype_comb = EVT_SUBTYPE_LOW;
    else if (ev_gate_high)       evt_subtype_comb = EVT_SUBTYPE_HIGH;
    else if (ev_gate_recovery)   evt_subtype_comb = EVT_SUBTYPE_RECOVERY;
    else                          evt_subtype_comb = EVT_SUBTYPE_UPDATED;
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_ROTOR;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL007;
    // apply_rpm_q, not rpm_q: this candidate is assembled COMBINATIONALLY
    // in the SAME cycle apply_fire_q pulses -- rpm_q (the status-visible
    // register) only picks up this commit's value one cycle later
    // (nonblocking assignment in the threshold-latch always_ff), so
    // reading it here would pack the PREVIOUS commit's stale value. Same
    // class of one-cycle-lag bug as cycles_since_accepted_q's own header
    // comment describes, found and fixed the same way, by a real
    // simulation failure (this field read the prior baseline RPM instead
    // of the fresh, genuinely-committed one).
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 16] = apply_rpm_q;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = evt_subtype_comb;
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

      // Real host clear-request for RTL007_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-2024) -- new-overflow-evidence-dominates-clear, same priority
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
  wire fault_live = illegal_config || timeout_now;
  assign fault_req_o = fault_live;

  // ==========================================================================
  // status_o packing (dfc_rtl007_status_t, 73 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__READY_HI] = !illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__FAULT_HI] = fault_live;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_STATUS__VALID_HI]       = valid_q;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_STATUS__LOW_HI]        = low_q;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_STATUS__HIGH_HI]       = high_q;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_STATUS__TIMEOUT_HI]     = timeout_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_STATUS__RANGE_ERROR_HI] = range_error_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_STATUS__UPDATED_HI]     = updated_sticky_q;

    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_RPM__RPM_HI:dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_RPM__RPM_LO] = rpm_q;
    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_PERIOD_TICKS__PERIOD_TICKS_HI:dfc_types_pkg::DFC_RTL007_STATUS__ROTOR_PERIOD_TICKS__PERIOD_TICKS_LO] = period_ticks_readback_q;

    status_comb[dfc_types_pkg::DFC_RTL007_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL007_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): operating_state_i/
  // observational_mode_i are real, structurally-required ports with no
  // functional use in this implementation (see header). ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i;

endmodule : dfc_rtl007
