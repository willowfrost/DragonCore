// dfc_rtl012.sv -- RTL-012 Watchdog Manager: a protected, windowed
// service-timer with key checking, requesting lane 0 of the safety-
// response authorization matrix on timeout (ARCH-002 SS10.3 ARCH-SAFE-005,
// Appendix F.1 ARCH-RTL012-001, Appendix C.8 "RTL-012 lane 0, source 0").
// Owns REG-002's Watchdog block (0x3000-0x30FF, 8 registers). The first
// module in the Safety domain -- RTLSTD-PRIN-006's set-dominates-clear
// discipline and exact simultaneous-condition boundary behavior matter
// more here than in Infrastructure/Monitoring.
//
// Controlling documents: docs/rtl_specs/RTL-012_RevA.md, RCA-DFC-ARCH-002
// SS10.3 ARCH-SAFE-005/Appendix F.1 ARCH-RTL012-001/Appendix F.3 index 11/
// Appendix C.5 event index 11/Appendix C.7 event ID 0x0040/Appendix C.8/
// ARCH-VAL-012, RCA-DFC-REG-002 SS24 (0x3000-0x301C).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// ARCHITECTURAL PRECEDENT, CONFIRMED BEFORE WRITING ANY CODE: this module's
// real register set (WDOG_WINDOW_OPEN_US/WDOG_TIMEOUT_US/WDOG_ELAPSED_US, a
// microsecond free-running counter compared against two live boundaries) is
// closer in shape to RTL-004's own microsecond correlation-timer divider
// (a phase counter dividing CORE_CLK by 50 to produce a 1 us tick, per the
// disclosed nominal-50-MHz ARCH-CLK-001 assumption) than to any
// Monitoring-domain module's edge/period-measurement architecture -- there
// is no external asynchronous pad here at all (see PHYSICAL PINS below), no
// CDC synchronizer, and no divider/multiplier. RTL-002's own
// RESET_CONTROL/RESET_STATUS busy/assert/wait-ready command sequencer was
// also checked directly (dfc_rtl002.sv's own RC_* states) as a candidate
// precedent for WDOG_SERVICE/WDOG_RECOVERY's own command-pulse handling --
// confirmed NOT applicable: RTL-002's sequencer exists because a controlled
// reset takes multiple cycles to assert/settle/report ready across other
// modules, whereas a watchdog service or recovery request is evaluated and
// resolved COMBINATIONALLY against the live elapsed counter in the same
// cycle the command pulse arrives -- no multi-cycle busy/wait state is
// needed or was invented.
//
// TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
// Yosys build -- see dfc_rtl002.sv's header for the full account): a
// package-scoped type cannot be a port's declared type. control_i/status_o
// are plain `logic [W-1:0]` vectors sized via generated `dfc_types_pkg::
// DFC_RTL012_*_WIDTH` VALUE constants; individual fields are extracted via
// generated `_HI`/`_LO` bit-slice constants -- never a hand-copied literal.
// response_req_o (dfc_safety_response_req_t, 8 bits) uses the identical
// flat-vector treatment, packed via `dfc_types_pkg::DFC_SAFETY_RESPONSE_
// REQ__*_HI/_LO`.
//
// ONE REAL ARCH-002 GAP, FOUND AND APPROVED BEFORE this module was
// implemented (the ELEVENTH real instance of this exact gap class --
// RTL-002/003's own EVT_OVERFLOW_STATUS, RTL-004's SNAPSHOT_VALID/
// SYNC_VALID, RTL-005's SNAPSHOT_VALID, RTL-006/007/008/009/010/011's own
// EVT_OVERFLOW_STATUS): dfc_rtl012_control_t (110 bits) had no
// clear-request field for RTL012_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
// (REG-301C bit 0, a real W1C field). Fixed, with explicit approval before
// implementation: ARCH-002 grew the struct 110->111 bits, adding
// rtl012_evt_overflow_status__event_overflow at the new highest bit (110)
// -- every pre-existing field's bit position confirmed unchanged via a
// real regenerate.ps1 run (git diff of include/dfc_types_pkg.sv shows only
// the new field/width/localparam lines changed, nothing else).
// tools/reggen/rtl012_field_map.json's own status_registers section also
// closes the RTL-002/003/004-style host-READ gap (OPEN_ISSUES.md item 21)
// for RTL012_EVT_OVERFLOW_STATUS from the start, same discipline already
// established for RTL-006 through RTL-011.
//
// PHYSICAL PINS -- CONFIRMED NOT NEEDED, same class of finding as RTL-010's
// own module. Checked directly against ARCH-002's own 17-port catalog
// (RTL-012 - Watchdog Manager) before writing this file: every port is
// either the standard clock/reset/control/status/event/irq/fault group, an
// internal same-domain signal to another not-yet-existing RTL module
// (response_req_o -> RTL-016, service_activity_o -> RTL-015.activity_i[7]), or a
// broadcast input from an already-real module (timestamp_i, operating_
// state_i, observational_mode_i). No external pad, no CDC/RDC inventory
// entry names this module. No fpga/ecp5/ulx3s_dfc.lpf or
// ULX3S_CONNECTION_MAP.md change was needed or made for this module.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (real gaps in the owning documents,
// resolved deliberately, not guessed -- CHTR-DOC-006):
//
//   - SERVICE-KEY WRITE DETECTION, a real, narrow, disclosed architectural
//     limitation of this project's existing WO-CMD pulse-capture mechanism
//     (reggen.py's `{nm}_pulse_q`, confirmed by direct reading of
//     reggen.py's own generation code before writing this file): a WO-CMD
//     register's pulse register holds the RAW WRITTEN VALUE for exactly one
//     cycle, defaulting to 32'h0 every other cycle. For a narrow command
//     field (e.g. WDOG_RECOVERY.RECOVER, legal values 0 or 1) this is
//     unambiguous -- 0 always means "no command," matching ordinary intent.
//     For WDOG_SERVICE.SERVICE_KEY, whose entire 32-bit legal range
//     (0-0xFFFFFFFF per REG-300C) is meaningful (every value is a real
//     service attempt subject to the exact-key check, including a
//     legitimately-written 0x00000000, which REG-300C's own text says
//     "sets service error"), a host write of EXACTLY 0x00000000 is
//     indistinguishable from "no write this cycle" using this mechanism --
//     both read as ctl_service_key==32'h0. This implementation detects a
//     service attempt as `ctl_service_key != 32'h0`, which correctly
//     classifies every other legal write (the correct key and every other
//     wrong key) but cannot detect the single specific case of a host
//     writing exactly the all-zero key -- that one case is silently treated
//     as no service attempt rather than BAD_SERVICE_KEY. This is a real,
//     narrow, disclosed gap, not a defect in this module's own logic --
//     logged in OPEN_ISSUES.md. A bit-exact fix would require a dedicated
//     write-strobe signal alongside the pulse value, which no cross-module
//     register-bus mechanism in this project currently provides.
//   - WDOG_CONTROL.WINDOW_ENABLE has NO wired functional effect in this
//     implementation -- a real, disclosed gap, not silently invented.
//     ARCH-SAFE-005 (the sole owning contract for EARLY/LATE/window
//     behavior, quoted in RTL-012_RevA.md SS3) describes the window/key
//     algorithm completely and unconditionally whenever "an enabled
//     counter" (WDOG_CONTROL.ENABLE) is running -- it never references
//     WINDOW_ENABLE at all, and neither does ARCH-RTL012-001 or
//     ARCH-VAL-012. REG-3000 lists WINDOW_ENABLE only as one of the
//     protected control bits with no further behavioral text of its own.
//     Since the module's single owning behavioral contract (ARCH-SAFE-005)
//     never conditions any real equation on this bit, inventing a specific
//     effect for it (e.g. disabling the MIN_WINDOW/EARLY check) would be a
//     guess, not a derivation -- CHTR-DOC-006 forbids that. The field is
//     still real: stored, forwarded, and host-readable via WDOG_CONTROL
//     itself, exactly per REG-3000's own RW access class. Logged in
//     OPEN_ISSUES.md as a real, no-functional-consequence gap, same class
//     as RTL-007/008/009's own "qualification 0-100 ms" ARCH-VAL clause
//     with no real field to attach a meaning to.
//   - F.3 (RTL-012 condition-mask bit allocation: "0 early; 1 late/missing;
//     2 invalid key; 3 timeout; 4 recovery; 5 service accepted; 6
//     event-slot overflow") and C.7 (event ID 0x0040 subtype values: "0
//     early, 1 late, 2 missing/timeout, 3 invalid key, 4 recovered, 5
//     service accepted") are two tables INSIDE THE SAME OWNING DOCUMENT
//     (ARCH-002) that do not align positionally -- F.3 folds "late" and
//     "missing" onto one shared bit while C.7 keeps them as two distinct
//     subtype values, and the numbering of "invalid key"/"timeout" then
//     differs between the two tables as a consequence. This is a genuine
//     ARCH-002 internal inconsistency, not a module-spec-vs-owning-document
//     conflict of the kind already resolved for RTL-003/004/005/006/010/011
//     (OPEN_ISSUES.md items 1/10/11/13/19/22/37/44) -- logged as its own,
//     new item. Resolved (per explicit approval before implementation) by
//     keeping LATE and TIMEOUT as two independently real, distinct
//     conditions: F.3 bit 1 gates a "late service attempt" condition
//     (event/irq subtype C.7 value 1, "late") and F.3 bit 3 gates the
//     actual "counter reached MAX_WINDOW" timeout-declared condition
//     (event/irq subtype C.7 value 2, "missing/timeout") -- these are two
//     real, independently observable hardware events in this
//     implementation (a late-but-eventually-arriving service is not the
//     same moment as the counter's own MAX_WINDOW boundary crossing,
//     though both can coincide on the identical cycle -- see the
//     simultaneous-timeout/late-service priority note below), matching
//     REG-002's own WDOG_STATUS.TIMEOUT sticky bit tracking specifically
//     the free-running "currently timed out" condition, distinct from any
//     one late service attempt.
//   - Simultaneous timeout/late-service priority (ARCH-RTL012-001's own
//     explicit text: "Timeout detection precedes same-cycle late
//     service"): satisfied structurally, not via extra logic -- LATE and
//     the live timeout condition share the identical boundary test
//     (elapsed_us_q >= MAX_WINDOW), so a late service landing on the exact
//     cycle the counter first reaches MAX_WINDOW is inherently simultaneous
//     with timeout declaration, and only a genuinely VALID in-window
//     service (impossible once elapsed_us_q >= MAX_WINDOW) can prevent or
//     retroactively cancel a timeout -- a late service never can. For this
//     module's own single-slot diagnostic-event candidate selection (only
//     one event record fits per cycle), a disclosed local priority applies
//     when more than one condition pulses the same cycle: timeout >
//     recovery > bad-key > late > early > plain-accepted (timeout ranked
//     highest, matching the spec's own "timeout detection precedes"
//     wording; irq_req_o has no such conflict since it is a plain OR
//     reduction, not a single-record subtype selection).
//   - RECOVERY sequencing, derived directly from ARCH-RTL012-001's literal
//     text ("Recovery requires exactly one valid in-window service after
//     the source condition clears") plus ARCH-VAL-012's "recovery command
//     with invalid timing is rejected" and REG-3018's own "recovery/clear
//     command after source condition is inactive" description -- no field
//     exists to make this a guess-free bit-for-bit citation, so this
//     sequencing is a disclosed, deliberate design, not an accident:
//       1. WDOG_RECOVERY.RECOVER is accepted ("valid timing") ONLY while
//          the live timeout condition (timeout_active_q) is currently
//          active -- issuing RECOVER while NOT timed out is REJECTED
//          (ARCH-VAL-012's "invalid timing," no counter/state effect).
//       2. An accepted RECOVER resets the elapsed counter to zero (exactly
//          like a valid service would) and clears the live timeout
//          condition -- this is "the source condition clears." It does
//          NOT by itself clear WDOG_STATUS.RESPONSE_PENDING or deassert
//          response_req_o -- the safety-response request stays pending,
//          the conservative reading of "recovery REQUIRES...", i.e. the
//          request is not yet resolved.
//       3. Exactly one subsequent VALID IN-WINDOW service (checked against
//          the freshly-reset counter, ordinary window rules apply
//          unchanged) completes recovery: clears RESPONSE_PENDING/
//          deasserts response_req_o, same cycle it also sets
//          SERVICE_ACCEPTED sticky evidence and restarts the counter
//          (ordinary valid-service consequence, unchanged).
//       4. If instead the counter reaches MAX_WINDOW again before that
//          confirming service ever arrives, the single-shot recovery
//          opportunity is spent: a fresh RECOVER is required to try again
//          (a new TIMEOUT sticky/response_req_o assertion also fires, per
//          ordinary timeout rules -- response_req_o was never deasserted
//          in the interim, so this is evidence re-assertion, not a new
//          request).
//   - response_req_o.source_id is the fixed constant 0 (RTL-012 lane 0,
//     source 0, Appendix C.8's sole legal watchdog authorization
//     position) -- response_mask forwards WDOG_CONTROL.SAFETY_RESPONSE_MASK
//     directly (only bit 0 legal per RTL-012_RevA.md SS4's own citation of
//     REG-ENC-015/Appendix C.8; bits 3:1 set is this module's own
//     "response mask is four bits"-adjacent illegal-configuration
//     condition -- see ARCH-VAL-012 below).
//   - Illegal-configuration -> status_o.fault (ARCH-VAL-012, the "defend
//     against what RTL-001 doesn't yet reject" precedent already
//     established by every monitoring module, OPEN_ISSUES.md item 4):
//     MIN_WINDOW_US >= MAX_WINDOW_US, MAX_WINDOW_US == 0, or
//     SAFETY_RESPONSE_MASK bits [3:1] nonzero, each checked only while
//     WDOG_CONTROL.ENABLE is set (an illegal value merely stored while
//     disabled is inert, matching every prior module's own "checked only
//     when it would actually matter" precedent). While illegal, this
//     module behaves as though not enabled at all (`active` below) --
//     "Enable...command with invalid timing is rejected" (ARCH-VAL-012).
//   - status_o.fault (generic module-status illegal-configuration bit) is
//     DISTINCT from fault_req_o (the domain-specific watchdog-timeout
//     safety-fault request into RTL-013.fault_source_i[0], gated by
//     WDOG_CONTROL.FAULT_ENABLE) -- the same clean two-tier separation
//     RTL-011 already established between its own generic status_o.fault
//     and HEALTH_STATUS.AGGREGATE_FAULT/fault_req_o.
//   - event_condition_enable_i/irq_condition_enable_i: real ports per the
//     Architecture catalog, tied to a disclosed stub (64'h0) in
//     dfc_rtl024.sv, same reasoning as every prior module (OPEN_ISSUES.md
//     item 6 -- RTL-001 does not yet implement the per-module
//     CONDITION_MASK storage/forwarding mechanism). Means none of RTL-012's
//     own events/irqs can actually fire in this integration yet -- a real,
//     disclosed consequence, not a defect in this file. response_req_o
//     itself is NOT gated by any condition mask (it is not an
//     event/irq-shaped signal at all), so the safety-response path itself
//     remains genuinely live and testable even with these two ports
//     stubbed.
// ============================================================================

module dfc_rtl012 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[11]

  input  logic [dfc_types_pkg::DFC_RTL012_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL012_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,
  output logic         fault_req_o,        // RTL-013.fault_source_i[0] -- real
                                            // output, genuinely unconsumed
                                            // (RTL-013 does not exist yet).

  output logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_req_o,
                                            // RTL-016.response_req_i[0] -- real
                                            // output, genuinely unconsumed
                                            // (RTL-016 does not exist yet).

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  output logic         service_activity_o, // RTL-015.activity_i[7] (C.1 ID 7, watchdog-
                                            // service pulse -- OPEN_ISSUES item 83) -- real
                                            // output, genuinely unconsumed
                                            // (RTL-015 does not exist yet).

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 11
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 11
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as every prior module) ----
  wire        ctl_enable        = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__ENABLE_HI];
  wire        ctl_window_enable = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__WINDOW_ENABLE_HI];  // stored/forwarded, no wired effect -- see header
  wire        ctl_event_enable  = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__EVENT_ENABLE_HI];
  wire        ctl_irq_enable    = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__IRQ_ENABLE_HI];
  wire        ctl_fault_enable  = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__FAULT_ENABLE_HI];
  wire [3:0]  ctl_safety_response_mask = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_CONTROL__SAFETY_RESPONSE_MASK_LO];
  wire [31:0] ctl_window_open_us = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_WINDOW_OPEN_US__WINDOW_OPEN_US_HI:dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_WINDOW_OPEN_US__WINDOW_OPEN_US_LO];
  wire [31:0] ctl_timeout_us     = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_TIMEOUT_US__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_TIMEOUT_US__TIMEOUT_US_LO];
  wire [31:0] ctl_service_key    = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_SERVICE__SERVICE_KEY_HI:dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_SERVICE__SERVICE_KEY_LO];
  wire        ctl_clr_service_accepted = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_STATUS__SERVICE_ACCEPTED_HI];
  wire        ctl_clr_early_service    = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_STATUS__EARLY_SERVICE_HI];
  wire        ctl_clr_bad_service_key  = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_STATUS__BAD_SERVICE_KEY_HI];
  wire        ctl_clr_timeout          = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_STATUS__TIMEOUT_HI];
  wire        ctl_recover              = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__WDOG_RECOVERY__RECOVER_HI];
  wire        ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL012_CONTROL__RTL012_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  localparam logic [31:0] SERVICE_KEY_VALID = 32'hA5C35A3C;  // ARCH-SAFE-005

  // ==========================================================================
  // Microsecond tick generator -- disclosed nominal 50 MHz CORE_CLK
  // assumption (ARCH-CLK-001), identical structure to dfc_rtl004.sv's own
  // microsecond phase counter (divide-by-50, free-running, never gated by
  // enable -- avoids skewed tick period across an enable toggle).
  // ==========================================================================
  logic [5:0] us_phase_q;
  wire        us_tick = (us_phase_q == 6'd49);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       us_phase_q <= 6'd0;
    else if (module_reset_i) us_phase_q <= 6'd0;
    else if (us_tick)        us_phase_q <= 6'd0;
    else                     us_phase_q <= us_phase_q + 6'd1;
  end

  // ==========================================================================
  // Live timeout/elapsed/recovery state -- declared here, ahead of every
  // combinational wire below that reads elapsed_us_q, per this project's
  // own confirmed Icarus declaration-before-use finding (a plain
  // continuous-assignment forward reference to an ordinary signal fails to
  // elaborate, distinct from the named-port-connection case documented
  // elsewhere -- see PROJECT_CONTINUITY.md Section 2).
  // ==========================================================================
  logic [31:0] elapsed_us_q;
  logic        timeout_active_q;    // live "source condition" level
  logic        recovery_pending_q;  // one-shot: awaiting the confirming
                                     // valid in-window service after RECOVER
  logic        response_pending_q;  // WDOG_STATUS.RESPONSE_PENDING / drives
                                     // response_req_o.valid

  // ==========================================================================
  // Illegal configuration -> `active` gating (ARCH-VAL-012, see header).
  // ==========================================================================
  wire illegal_window        = ctl_enable && (ctl_window_open_us >= ctl_timeout_us);
  wire illegal_timeout_zero  = ctl_enable && (ctl_timeout_us == 32'h0);
  wire illegal_response_mask = |ctl_safety_response_mask[3:1];
  wire illegal_config = illegal_window || illegal_timeout_zero || illegal_response_mask;
  wire active = ctl_enable && !illegal_config;

  // ==========================================================================
  // Service-key write detection and disposition -- see header for the
  // disclosed 0x00000000-write gap. Key mismatch (INVALID) is independent
  // of window position, per ARCH-SAFE-005's own "any other value is
  // INVALID" (checked ahead of, not instead of, the window classification).
  // ==========================================================================
  wire service_write_pulse = (ctl_service_key != 32'h0);
  wire service_key_valid   = (ctl_service_key == SERVICE_KEY_VALID);

  // Half-open legal window [MIN_WINDOW, MAX_WINDOW) -- legal at MIN, legal
  // through MAX-1, LATE at exactly MAX (ARCH-RTL012-001's own explicit
  // boundary text).
  wire in_window = active && (elapsed_us_q >= ctl_window_open_us) && (elapsed_us_q < ctl_timeout_us);
  wire is_early  = active && (elapsed_us_q <  ctl_window_open_us);
  wire is_late   = active && (elapsed_us_q >= ctl_timeout_us);

  wire service_bad_key  = active && service_write_pulse && !service_key_valid;
  wire service_early    = active && service_write_pulse && service_key_valid && is_early;
  wire service_late     = active && service_write_pulse && service_key_valid && is_late;
  wire service_valid_ok = active && service_write_pulse && service_key_valid && in_window;

  assign service_activity_o = service_valid_ok;

  // ==========================================================================
  // Live timeout condition, elapsed counter, and recovery sequencing
  // (ARCH-RTL012-001, ARCH-VAL-012 -- see header for the full derivation).
  // ==========================================================================
  wire timeout_reached  = active && (elapsed_us_q >= ctl_timeout_us);
  wire recover_accept   = active && ctl_recover && timeout_active_q;
  wire recovery_complete = active && recovery_pending_q && service_valid_ok;
  wire elapsed_reset_this_cycle = service_valid_ok || recover_accept;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      elapsed_us_q       <= 32'd0;
      timeout_active_q   <= 1'b0;
      recovery_pending_q <= 1'b0;
      response_pending_q <= 1'b0;
    end else if (module_reset_i || !active) begin
      // ARCH-RTL012-001: reset/disable clears both the timer and any
      // pending safety request. Sticky W1C evidence is NOT part of "the
      // timer and any pending safety request" -- it survives disable,
      // handled in its own always_ff block below.
      elapsed_us_q       <= 32'd0;
      timeout_active_q   <= 1'b0;
      recovery_pending_q <= 1'b0;
      response_pending_q <= 1'b0;
    end else begin
      if (elapsed_reset_this_cycle) begin
        elapsed_us_q <= 32'd0;
      end else if (us_tick && (elapsed_us_q != 32'hFFFF_FFFF)) begin
        elapsed_us_q <= elapsed_us_q + 32'd1;
      end

      if (elapsed_reset_this_cycle) timeout_active_q <= 1'b0;
      else if (timeout_reached)     timeout_active_q <= 1'b1;

      if (recover_accept)                              recovery_pending_q <= 1'b1;
      else if (recovery_complete)                       recovery_pending_q <= 1'b0;
      else if (timeout_reached && recovery_pending_q)   recovery_pending_q <= 1'b0;  // opportunity spent

      if (timeout_reached)          response_pending_q <= 1'b1;
      else if (recovery_complete)   response_pending_q <= 1'b0;
    end
  end

  // ==========================================================================
  // response_req_o (dfc_safety_response_req_t, 8 bits): lane 0, source 0
  // fixed (Appendix C.8). Real output, genuinely unconsumed (RTL-016 does
  // not exist yet).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_req_comb;
  always_comb begin
    response_req_comb = '0;
    response_req_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_LO] = ctl_safety_response_mask;
    response_req_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_LO] = 3'd0;
    response_req_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI] = response_pending_q;
  end
  assign response_req_o = response_req_comb;

  // ==========================================================================
  // fault_req_o: domain-specific watchdog-timeout safety-fault request into
  // RTL-013.fault_source_i[0] -- distinct from status_o.fault below (see
  // header). Gated by WDOG_CONTROL.FAULT_ENABLE.
  // ==========================================================================
  assign fault_req_o = timeout_active_q && ctl_fault_enable;

  // ==========================================================================
  // Sticky W1C status evidence (WDOG_STATUS): new-evidence-dominates-clear
  // (RTLSTD-PRIN-006/RTLSTD-REG-008), survives disable, cleared by core/
  // module reset or an accepted host clear-request.
  // ==========================================================================
  logic status_service_accepted_q;
  logic status_early_q;
  logic status_bad_key_q;
  logic status_timeout_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      status_service_accepted_q <= 1'b0;
      status_early_q            <= 1'b0;
      status_bad_key_q          <= 1'b0;
      status_timeout_q          <= 1'b0;
    end else if (module_reset_i) begin
      status_service_accepted_q <= 1'b0;
      status_early_q            <= 1'b0;
      status_bad_key_q          <= 1'b0;
      status_timeout_q          <= 1'b0;
    end else begin
      if (service_valid_ok)              status_service_accepted_q <= 1'b1;
      else if (ctl_clr_service_accepted) status_service_accepted_q <= 1'b0;

      if (service_early)                 status_early_q <= 1'b1;
      else if (ctl_clr_early_service)    status_early_q <= 1'b0;

      if (service_bad_key)               status_bad_key_q <= 1'b1;
      else if (ctl_clr_bad_service_key)  status_bad_key_q <= 1'b0;

      if (timeout_active_q)              status_timeout_q <= 1'b1;  // set-dominates-clear while live
      else if (ctl_clr_timeout)          status_timeout_q <= 1'b0;
    end
  end

  // ==========================================================================
  // Per-condition F.3-gated event/irq subconditions (Appendix F.3 index 11:
  // 0 early; 1 late; 2 invalid key; 3 timeout; 4 recovery; 5 service
  // accepted; 6 event-slot overflow -- see header for the disclosed F.3-
  // vs-C.7 numbering resolution). timeout_declared/recovery_complete are
  // already one-cycle pulse-shaped; service_early/_late/_bad_key are
  // pulse-shaped by construction (gated on service_write_pulse, itself one
  // cycle).
  // ==========================================================================
  wire timeout_declared = timeout_reached && !timeout_active_q;

  wire ev_early    = service_early      & event_condition_enable_i[0];
  wire ev_late     = service_late       & event_condition_enable_i[1];
  wire ev_badkey   = service_bad_key    & event_condition_enable_i[2];
  wire ev_timeout  = timeout_declared   & event_condition_enable_i[3];
  wire ev_recovery = recovery_complete  & event_condition_enable_i[4];
  wire ev_accepted = service_valid_ok   & event_condition_enable_i[5];

  wire iq_early    = service_early      & irq_condition_enable_i[0];
  wire iq_late     = service_late       & irq_condition_enable_i[1];
  wire iq_badkey   = service_bad_key    & irq_condition_enable_i[2];
  wire iq_timeout  = timeout_declared   & irq_condition_enable_i[3];
  wire iq_recovery = recovery_complete  & irq_condition_enable_i[4];
  wire iq_accepted = service_valid_ok   & irq_condition_enable_i[5];

  wire chan_event_cond = ev_early | ev_late | ev_badkey | ev_timeout | ev_recovery | ev_accepted;
  wire chan_irq_cond   = iq_early | iq_late | iq_badkey | iq_timeout | iq_recovery | iq_accepted;

  wire event_req = ctl_event_enable && chan_event_cond;
  assign irq_req_o = ctl_irq_enable && chan_irq_cond;

  // ==========================================================================
  // Own diagnostic event generation (event ID 0x0040, source index 11) --
  // real, one-deep pending-slot shape identical to every prior module.
  // Priority when more than one condition pulses the same cycle: timeout >
  // recovery > bad-key > late > early > plain-accepted (see header).
  // ==========================================================================
  localparam logic [15:0] EVT_ID_WATCHDOG = 16'h0040;
  localparam logic [7:0]  EVT_SUBTYPE_EARLY    = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_LATE     = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_TIMEOUT  = 8'd2;  // "missing/timeout" per C.7
  localparam logic [7:0]  EVT_SUBTYPE_BADKEY   = 8'd3;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERED = 8'd4;
  localparam logic [7:0]  EVT_SUBTYPE_ACCEPTED  = 8'd5;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL012 = 8'd11;  // ARCH-002 C.5 index 11

  wire evt_candidate_valid = event_req;

  logic [7:0] evt_subtype_comb;
  always_comb begin
    evt_subtype_comb = EVT_SUBTYPE_ACCEPTED;
    if (ev_timeout)        evt_subtype_comb = EVT_SUBTYPE_TIMEOUT;
    else if (ev_recovery)  evt_subtype_comb = EVT_SUBTYPE_RECOVERED;
    else if (ev_badkey)    evt_subtype_comb = EVT_SUBTYPE_BADKEY;
    else if (ev_late)      evt_subtype_comb = EVT_SUBTYPE_LATE;
    else if (ev_early)     evt_subtype_comb = EVT_SUBTYPE_EARLY;
    else                   evt_subtype_comb = EVT_SUBTYPE_ACCEPTED;
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_WATCHDOG;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL012;
    // event_data[7:0]: subtype. event_data[31:8]: "elapsed-time low bits"
    // (C.7) -- disclosed packing, low 24 bits of the live elapsed counter.
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]  = evt_subtype_comb;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+8 +: 24] = elapsed_us_q[23:0];
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

      // Real host clear-request for RTL012_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-301C) -- new-overflow-evidence-dominates-clear, same priority
      // as every prior module's identical fix.
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // status_o packing (dfc_rtl012_status_t, 58 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL012_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__READY_HI] = !illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__FAULT_HI] = illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__ENABLED_HI] = active;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__WINDOW_OPEN_HI] = in_window;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__SERVICE_ACCEPTED_HI] = status_service_accepted_q;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__EARLY_SERVICE_HI]    = status_early_q;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__BAD_SERVICE_KEY_HI]  = status_bad_key_q;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__TIMEOUT_HI]          = status_timeout_q;
    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_STATUS__RESPONSE_PENDING_HI] = response_pending_q;

    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__WDOG_ELAPSED_US__ELAPSED_US_HI:dfc_types_pkg::DFC_RTL012_STATUS__WDOG_ELAPSED_US__ELAPSED_US_LO] = elapsed_us_q;

    status_comb[dfc_types_pkg::DFC_RTL012_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL012_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): operating_state_i/
  // observational_mode_i are real, structurally-required ports with no
  // functional use in this module's own real equations (RTL-012's own
  // spec never names either in ARCH-SAFE-005/ARCH-RTL012-001), same
  // disclosed pattern already established for dfc_rtl007/008/009/010/011.sv.
  // ctl_window_enable joins this sink too -- see header for why it has no
  // wired functional effect anywhere else in this module. ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i ^ ctl_window_enable;

endmodule : dfc_rtl012
