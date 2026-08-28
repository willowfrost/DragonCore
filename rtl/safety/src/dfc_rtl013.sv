// dfc_rtl013.sv -- RTL-013 Fault Manager: the sole consumer of the fixed
// 32-bit fault-source matrix (ARCH-002 Appendix C.6, 17 assigned bits 0-16,
// 15 reserved 17-31), classifying each source's recoverability, selecting a
// primary source, and requesting lane 1 of the safety-response matrix on
// any nonrecoverable evidence. Owns REG-002's Fault Manager block
// (0x3100-0x31FF, 9 registers). The second Safety-domain module.
//
// Controlling documents: docs/rtl_specs/RTL-013_RevA.md, RCA-DFC-ARCH-002
// SS10.1/SS10.2/SS10.4/Appendix C.6/Appendix C.7 event 0x0041/Appendix C.8/
// ARCH-RTL013-001/ARCH-VAL-013, RCA-DFC-REG-002 SS25 (0x3100-0x3120).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// ONE REAL ARCH-002 GAP, FOUND AND APPROVED BEFORE this module was
// implemented (the TWELFTH real instance of this exact gap class --
// RTL-002/003/004/005/006/007/008/009/010/011/012's own identical gap):
// dfc_rtl013_control_t (112 bits) had no clear-request field for
// RTL013_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-3120 bit 0, a real W1C
// field). Fixed, with explicit approval before implementation: ARCH-002 grew
// the struct 112->113 bits, adding rtl013_evt_overflow_status__event_overflow
// at the new highest bit (112) -- every pre-existing field's bit position
// confirmed unchanged via a real regenerate.ps1 run (git diff of
// include/dfc_types_pkg.sv shows only the new field/width/localparam lines
// changed, nothing else). tools/reggen/rtl013_field_map.json's own
// status_registers section also closes the RTL-002/003/004-style host-READ
// gap (OPEN_ISSUES.md item 21) for RTL013_EVT_OVERFLOW_STATUS from the start,
// same discipline already established for RTL-006 through RTL-012.
//
// ONE REAL reggen.py GAP, FOUND AND FIXED BEFORE this module's field-map was
// used for real: FAULT_RECOVERABLE_MASK (REG-311C) is a CONST register whose
// own write-validation text is "Any register write is ACCESS_ERROR" -- but
// it still needs to appear in this module's control_registers section (its
// fixed 0x00017FEF value must forward into dfc_rtl013_control_t's
// fault_recoverable_mask__recoverable field per RTL-013_RevA.md SS3's own
// "decode this mask directly [from the real forwarded field]" instruction,
// and reggen.py's own generator invariant requires every field-map entry's
// control struct bits to be covered by exactly one field-map entry -- there
// is no partial-coverage escape valve). reggen.py's PRE-EXISTING rule
// ("any register appearing in a field-map's control_registers reports
// write_illegal_o = 1'b0") was correct for every RW/WO-CMD/W1C entry used by
// every module through RTL-012, but wrong here: it would have silently
// ACCEPTED a host write to this ACCESS_ERROR-only register (with zero real
// effect on the always-0x00017FEF wire, but a real, wrong DRI response
// code). Fixed in the generator itself (RTLSTD-ORG-003: fix the generator,
// never hand-edit generated output): a register whose ctrl_entry fields are
// ALL class "CONST" now falls back to the ordinary readback-based
// write_illegal_o rule instead of being unconditionally cleared -- confirmed
// via a real regenerate.ps1 diff that FAULT_RECOVERABLE_MASK is the ONLY
// register whose write_illegal_o value changed relative to the naive,
// unfixed generator output, and that every pre-existing RW/WO-CMD/W1C
// field-map entry across all 12 consumer modules is completely unaffected.
//
// PHYSICAL PINS -- CONFIRMED NOT NEEDED, same class of finding as RTL-010's/
// RTL-012's own modules. Checked directly against ARCH-002's own 19-port
// catalog (RTL-013 - Fault Manager) before writing this file: every port is
// either the standard clock/reset/control/status/event/irq/condition-mask
// group, a same-domain signal to RTL-002 (degraded_req_o/faulted_req_o) or
// RTL-016 (response_req_o/safety_inhibit_o, neither of which exists yet), or
// the fixed fault_source_i matrix (same-domain, from other RTL modules). No
// external pad, no CDC/RDC inventory entry names this module. No
// fpga/ecp5/ulx3s_dfc.lpf or ULX3S_CONNECTION_MAP.md change was needed or
// made for this module.
//
// TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
// Yosys build -- see dfc_rtl002.sv's header for the full account): a
// package-scoped type cannot be a port's declared type. control_i/status_o/
// response_req_o are plain `logic [W-1:0]` vectors sized via generated
// `dfc_types_pkg::DFC_RTL013_*_WIDTH`/`DFC_SAFETY_RESPONSE_REQ_WIDTH` VALUE
// constants; individual fields are extracted/packed via generated `_HI`/
// `_LO` bit-slice constants -- never a hand-copied literal.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (real gaps in the owning documents,
// resolved deliberately, not guessed -- CHTR-DOC-006):
//
//   - FIXED RECOVERABILITY MASK, DECODED FROM THE REAL FORWARDED FIELD, NOT
//     A LOCAL LITERAL. ctl_recoverable_mask below is control_i's
//     fault_recoverable_mask__recoverable field, forwarded from RTL-001's
//     own const-readback wire (always 0x00017FEF -- see the reggen.py gap
//     above). Cross-checked bit-for-bit against ARCH-002 Appendix C.6's own
//     per-source recoverability column before trusting it (RTL-013_RevA.md
//     SS3's own instruction: "confirm each bit's recoverability against
//     Appendix C.6's own per-source class column rather than trusting a
//     manual bit-count") -- all 17 bits confirmed to match exactly (bit 4
//     RTL-011/bit 15 RTL-022 clear=nonrecoverable; every other assigned bit
//     0-16 set=recoverable).
//   - PRIMARY-SOURCE SELECTION AND MULTIPLE-SOURCE DETECTION use the SAME
//     evidence set: if any source is currently ACTIVE, primary = lowest-
//     numbered active bit and MULTIPLE = (countones(active) > 1); otherwise,
//     if any source is STICKY (latched, none currently active), primary =
//     lowest-numbered sticky bit and MULTIPLE = (countones(sticky) > 1) --
//     directly per SS10.1's own "primary source is the lowest-numbered
//     active bit, or the lowest sticky bit when no source is active."
//     CLASS_VALID is high whenever either set is nonempty. No `break`
//     construct is used in the priority-search loops below (Icarus rejects
//     `break` inside a `for` loop, PROJECT_CONTINUITY.md Section 2) -- both
//     use the established flag-gated loop-body idiom instead.
//   - degraded_req_o (LEVEL request, per the Architecture port catalog's own
//     "level request" wording) tracks ONLY recoverable ACTIVE evidence
//     (SS10.1: "recoverable active evidence requests DEGRADED") -- it
//     deasserts the same cycle the underlying active condition clears, even
//     if sticky evidence for that same source remains latched.
//     faulted_req_o (LATCHED request, per the port catalog's own "latched
//     request" wording) tracks nonrecoverable evidence from EITHER active OR
//     sticky sources (SS10.1: "nonrecoverable active-or-sticky evidence
//     requests FAULTED") -- it naturally persists via the STICKY register
//     even after the triggering source's own active condition clears, until
//     an eligible host clear (or a fresh nonrecoverable detection, which
//     dominates per SS10.1's "new detection dominates clear"). This exact
//     LEVEL-vs-LATCHED asymmetry is the concrete, testable confirmation that
//     the port catalog's own wording and SS10.1's own equations agree.
//   - safety_inhibit_o[3:0] (feeding RTL-016.fault_inhibit_i per SS10.4) is
//     the OR of ACTIVE (not active-or-sticky) nonrecoverable sources only --
//     RTL-013_RevA.md SS2's own port description: "all four bits tied equal
//     to the OR of active nonrecoverable fault sources." This is narrower
//     than faulted_req_o's own active-or-sticky evidence set (a real,
//     source-specified difference, not an oversight): a safety-output
//     INHIBIT should track the live danger condition, not stale latched
//     evidence from a source that has already recovered.
//   - FAULT_CONTROL has NO module-wide EVENT_ENABLE/IRQ_ENABLE bit (real,
//     confirmed by direct reading of REG-3100's own two real fields, ENABLE
//     and CLEAR_ALL_REQ only) -- unlike every prior module's own XXX_CONTROL
//     register. event_req/irq_req_o below are therefore gated ONLY by their
//     own per-condition event_condition_enable_i/irq_condition_enable_i bits
//     (Appendix F.3 index 12), with no additional module-wide AND term (none
//     exists to AND with) -- a real, disclosed difference from RTL-012's own
//     per-condition-plus-module-wide-enable shape, not a simplification.
//   - RESPONSE_PENDING LATCH-VS-LEVEL POLICY, directly mirroring SS10.4's own
//     analogous LATCHED_REQUEST[c] equation for RTL-016's channels ("zero
//     when latch policy is disabled... an active request sets the retained
//     latch; it clears only on... reset" when enabled) -- the closest real,
//     cited precedent for FAULT_RESPONSE.LATCH_UNTIL_HOST_CLEAR's own
//     behavior, since no equation names this field directly.
//     response_pending_q (FAULT_STATUS.RESPONSE_PENDING, also
//     response_req_o.valid) sets whenever nonrecoverable evidence newly
//     qualifies for a response request (SAFETY_RESPONSE_ENABLE gated); while
//     LATCH_UNTIL_HOST_CLEAR is clear, it auto-tracks the live condition
//     (deasserts the same cycle the condition clears); while
//     LATCH_UNTIL_HOST_CLEAR is set, it stays asserted until an explicit host
//     FAULT_STATUS.RESPONSE_PENDING W1C clear (new evidence dominates a
//     simultaneous clear, per REG-GEN-013's own universal ordering).
//   - DEGRADED_STATUS lifecycle (ACTIVE/ENTRY/RECOVERY_AVAILABLE/RECOVERED),
//     a disclosed design forced by REG-3110's own generic W1C boilerplate
//     text (no bit-exact algorithm given) -- not RTL-002's own, separate,
//     episode/DEGRADED_ACK mechanism, which this module has no visibility
//     into and does not model:
//       ACTIVE   = degraded_req_o itself (live).
//       ENTRY    = sticky, set-dominates while degraded_req_o is high,
//                  cleared only by an explicit host clear while
//                  degraded_req_o is low (identical shape to every other
//                  sticky field in this project).
//       RECOVERED = a one-shot pulse-latch, set on the falling edge of
//                  degraded_req_o (an explicit registered "previous cycle"
//                  comparison, not a same-always_ff same-cycle stale read --
//                  PROJECT_CONTINUITY.md Section 2's own confirmed lag
//                  finding), cleared by an explicit host clear.
//       RECOVERY_AVAILABLE = ENTRY && !ACTIVE (a live, RO derived signal:
//                  "there was a degraded entry, not yet acknowledged, and it
//                  is not currently re-active") -- not a separate register.
//   - EVENT 0x0041 ("Fault manager": 0 asserted, 1 recovered, 2 cleared, 3
//     response requested), source index 12 per the Architecture port catalog
//     (evt_valid_o -> RTL-005.evt_valid_i[12]). Subtypes are disclosed
//     designs tracking the module's OWN overall evidence lifecycle (any of
//     the 17 sources, not the DEGRADED-specific sub-case above):
//       asserted  = rising edge of "any source currently active"
//                  (0 -> nonzero active17).
//       recovered = falling edge of the same condition (nonzero -> 0).
//       cleared   = an accepted host clear command issued (CLEAR_ALL_REQ or
//                  any FAULT_LATCHED_SOURCE bit) while enabled -- the command
//                  itself is the trigger, matching REG-3100/REG-3118's own
//                  "Reads zero"/"reads current retained value... requests
//                  clear" WO-CMD/W1C command-pulse semantics used
//                  project-wide (the event fires whether or not any bit was
//                  actually cleared, exactly as RTL-012's own analogous
//                  service/timeout events fire on the qualifying command/
//                  condition, not on an after-the-fact "did anything change"
//                  check).
//       response requested = the cycle response_pending_q newly sets.
//     Simultaneous-condition priority when more than one subtype qualifies
//     the same cycle (only one event record fits per cycle, same class of
//     disclosed local priority as RTL-012's own): response requested (most
//     safety-relevant) > asserted > cleared > recovered. event_data[15:8]
//     (C.7's own "channel or originating source index") carries the current
//     primary_index; event_data[31:16] ("fault bit and class" per this
//     event ID's own row) carries {8'h0, class_byte} -- a disclosed packing
//     choice, same class as RTL-012's own "elapsed-time low bits" packing.
//   - ARCH-VAL-013's "injection requires test-active": RTL-013 has NO
//     dedicated test_active_i port on its own real 19-port catalog (unlike
//     RTL-002) -- the only test-related input this module receives is
//     operating_state_i. "test-active" is read as the qualified TEST_DEBUG
//     operating state (operating_state_i == dfc_types_pkg::TEST_DEBUG),
//     consistent with how every other module without its own dedicated
//     test_active_i port gates test-only behavior in this project.
//     TEST_FAULT_INJECT.SOURCE_MASK's captured pulse is ORed into the SAME
//     fault_source_i-derived evidence path used by real sources ("injects
//     selected fault source through the normal fault path," REG-0614's own
//     text) ONLY while TEST_DEBUG is qualified; outside TEST_DEBUG, an
//     injection write is accepted at the register level (RTL-001 does not
//     yet implement per-field validation, OPEN_ISSUES.md item 4) but has no
//     effect here, same disclosed "defend against what RTL-001 doesn't yet
//     reject" precedent already established by every fault-facing module.
//   - ILLEGAL RESERVED-BIT ACTIVITY -> status_o.fault (ARCH-VAL-013's "source/
//     configuration masks may set only bits 0-16"): a write to
//     TEST_FAULT_INJECT.SOURCE_MASK or FAULT_LATCHED_SOURCE.LATCHED_SOURCE
//     setting any of bits 17-31 is illegal per REG-0614/REG-3118's own write-
//     validation text ("Any subset of bits 0-16; bits 17-31 zero") -- RTL-001
//     does not yet reject this at the register level (OPEN_ISSUES.md item 4),
//     so this module defends itself the same way RTL-003/007-012 already do:
//     detects the reserved-bit activity and asserts the generic status_o.fault
//     bit (DISTINCT from faulted_req_o, the domain-specific nonrecoverable-
//     evidence safety-fault request -- the same clean two-tier separation
//     RTL-011/012 already established).
//   - event_condition_enable_i/irq_condition_enable_i: real ports per the
//     Architecture catalog, tied to a disclosed stub (64'h0) in
//     dfc_rtl024.sv, same reasoning as every prior module (OPEN_ISSUES.md
//     item 6 -- RTL-001 does not yet implement the per-module CONDITION_MASK
//     storage/forwarding mechanism). Means none of RTL-013's own events/irqs
//     can actually fire in this integration yet -- a real, disclosed
//     consequence, not a defect in this file.
// ============================================================================

module dfc_rtl013 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[12]

  input  logic [dfc_types_pkg::DFC_RTL013_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL013_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,

  input  logic [31:0]  fault_source_i,     // fixed Appendix C.6 matrix, bits
                                            // 0-16 assigned, 17-31 constant
                                            // zero from the real port catalog

  output logic         degraded_req_o,     // RTL-002.degraded_req_i -- real
                                            // output, genuinely unconsumed
                                            // (dfc_rtl002.sv does not have
                                            // this port yet -- see the
                                            // dfc_rtl002.sv header for the
                                            // real fix closing this gap).
  output logic         faulted_req_o,      // RTL-002.faulted_req_i -- same.

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  output logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_req_o,
                                            // RTL-016.response_req_i[1] -- real
                                            // output, genuinely unconsumed
                                            // (RTL-016 does not exist yet).
  output logic [3:0]   safety_inhibit_o,   // RTL-016.fault_inhibit_i -- same.

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 12
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 12
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as every prior module) ----
  wire        ctl_enable           = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_CONTROL__ENABLE_HI];
  wire        ctl_clear_all_req    = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_CONTROL__CLEAR_ALL_REQ_HI];
  wire        ctl_clr_fault_active   = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_STATUS__FAULT_ACTIVE_HI];
  wire        ctl_clr_multi_fault    = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_STATUS__MULTI_FAULT_HI];
  wire        ctl_clr_event_pending  = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_STATUS__EVENT_PENDING_HI];
  wire        ctl_clr_response_pending = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_STATUS__RESPONSE_PENDING_HI];
  wire        ctl_degraded_enable       = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RESPONSE__DEGRADED_ENABLE_HI];
  wire        ctl_safety_response_enable = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RESPONSE__SAFETY_RESPONSE_ENABLE_HI];
  wire        ctl_event_on_clear         = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RESPONSE__EVENT_ON_CLEAR_HI];
  wire        ctl_latch_until_host_clear = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RESPONSE__LATCH_UNTIL_HOST_CLEAR_HI];
  wire [3:0]  ctl_safety_output_request_enable = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RESPONSE__SAFETY_OUTPUT_REQUEST_ENABLE_HI:dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RESPONSE__SAFETY_OUTPUT_REQUEST_ENABLE_LO];
  wire        ctl_clr_degraded_entry     = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__DEGRADED_STATUS__ENTRY_HI];
  wire        ctl_clr_degraded_recovered = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__DEGRADED_STATUS__RECOVERED_HI];
  wire [31:0] ctl_latched_source_clear = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_LATCHED_SOURCE__LATCHED_SOURCE_HI:dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_LATCHED_SOURCE__LATCHED_SOURCE_LO];
  wire [31:0] ctl_recoverable_mask     = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RECOVERABLE_MASK__RECOVERABLE_HI:dfc_types_pkg::DFC_RTL013_CONTROL__FAULT_RECOVERABLE_MASK__RECOVERABLE_LO];
  wire        ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__RTL013_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];
  wire [31:0] ctl_test_fault_inject_pulse = control_i[dfc_types_pkg::DFC_RTL013_CONTROL__TEST_FAULT_INJECT__SOURCE_MASK_HI:dfc_types_pkg::DFC_RTL013_CONTROL__TEST_FAULT_INJECT__SOURCE_MASK_LO];

  // ==========================================================================
  // Reserved-bit defense (ARCH-VAL-013: "source/configuration masks may set
  // only bits 0-16") -- see header. RTL-001 does not yet reject this itself.
  // ==========================================================================
  wire illegal_reserved_activity =
    (|ctl_test_fault_inject_pulse[31:17]) || (|ctl_latched_source_clear[31:17]);

  // ==========================================================================
  // Test-injection path (ARCH-VAL-013: "injection requires test-active") --
  // see header for why operating_state_i == TEST_DEBUG is this module's own
  // "test-active" qualifier.
  // ==========================================================================
  wire        test_active_qualified = (operating_state_i == dfc_types_pkg::TEST_DEBUG);
  wire [31:0] inject_masked = (test_active_qualified ? ctl_test_fault_inject_pulse : 32'h0) & 32'h0001FFFF;

  // ==========================================================================
  // ACTIVE[31:0] / STICKY[31:0] (ARCH-002 SS10.1) -- declared here, ahead of
  // every combinational wire below that reads sticky_q, per this project's
  // own confirmed Icarus declaration-before-use finding.
  // ==========================================================================
  logic [31:0] sticky_q;

  wire [31:0] active_qualified = ctl_enable ? ((fault_source_i | inject_masked) & 32'h0001FFFF) : 32'h0;
  wire [16:0] active17 = active_qualified[16:0];
  wire [16:0] sticky17 = sticky_q[16:0];

  wire [31:0] clear_effective_mask =
    ((ctl_latched_source_clear | {32{ctl_clear_all_req}}) & 32'h0001FFFF);
  wire [31:0] sticky_next = active_qualified | (sticky_q & ~clear_effective_mask);

  wire any_active = |active17;
  wire any_sticky = |sticky17;
  wire class_valid = any_active || any_sticky;

  // ---- Primary-source selection: lowest-numbered active bit, else lowest-
  // numbered sticky bit (SS10.1). ----
  //
  // TIMING FIX (found via a real build_ecp5.ps1 failure, not by
  // inspection): the original implementation threaded a "found" flag
  // through two 17-iteration `for` loops (one over active17, one over
  // sticky17), each iteration's own condition reading the PREVIOUS
  // iteration's own flag update -- structurally the identical genuine
  // 17-deep SERIAL dependency chain already found and fixed once in this
  // project for RTL-005's own round-robin arbiter (OPEN_ISSUES.md item
  // 17: "24 sequentially chained... stages"), not a balanced priority
  // structure. A real `build_ecp5.ps1` run confirmed this landed on the
  // worst path: 40.14 MHz, FAIL at 50 MHz required (device utilization
  // only 7-9%, ruling out resource exhaustion as the cause). Fixed the
  // same architectural way as item 17's own real fix: replaced the
  // per-bit sequential arithmetic-like flag-threading with a genuine
  // priority encoder (`casez`, one pattern per bit position, each an
  // independent parallel comparison rather than a threaded dependency) --
  // and reduced two 17-way encodes down to exactly one, by first selecting
  // WHICH 17-bit vector to encode (active17 or sticky17, a plain 17-bit
  // mux) rather than running both encodes unconditionally every cycle.
  wire [16:0] primary_source_vec = any_active ? active17 : sticky17;
  logic [4:0] primary_index_comb;
  always_comb begin
    casez (primary_source_vec)
      17'b????????????????1: primary_index_comb = 5'd0;
      17'b???????????????10: primary_index_comb = 5'd1;
      17'b??????????????100: primary_index_comb = 5'd2;
      17'b?????????????1000: primary_index_comb = 5'd3;
      17'b????????????10000: primary_index_comb = 5'd4;
      17'b???????????100000: primary_index_comb = 5'd5;
      17'b??????????1000000: primary_index_comb = 5'd6;
      17'b?????????10000000: primary_index_comb = 5'd7;
      17'b????????100000000: primary_index_comb = 5'd8;
      17'b???????1000000000: primary_index_comb = 5'd9;
      17'b??????10000000000: primary_index_comb = 5'd10;
      17'b?????100000000000: primary_index_comb = 5'd11;
      17'b????1000000000000: primary_index_comb = 5'd12;
      17'b???10000000000000: primary_index_comb = 5'd13;
      17'b??100000000000000: primary_index_comb = 5'd14;
      17'b?1000000000000000: primary_index_comb = 5'd15;
      17'b10000000000000000: primary_index_comb = 5'd16;
      default:                primary_index_comb = 5'd0;  // no bit set (class_valid=0)
    endcase
  end

  wire multiple_now = any_active ? ($countones(active17) > 6'd1) : ($countones(sticky17) > 6'd1);

  // ---- FAULT_CLASS.CLASS lookup (ARCH-002 Appendix C.6's own per-source
  // class column, confirmed directly, not restated from memory) ----
  logic [7:0] class_byte_comb;
  always_comb begin
    if (!class_valid) begin
      class_byte_comb = 8'h00;
    end else begin
      case (primary_index_comb)
        5'd0:  class_byte_comb = 8'h04;  // Watchdog timeout, RTL-012
        5'd1:  class_byte_comb = 8'h04;  // Interlock violation, RTL-014
        5'd2:  class_byte_comb = 8'h03;  // Lost-link condition, RTL-015
        5'd3:  class_byte_comb = 8'h04;  // Safety-output configuration error, RTL-016
        5'd4:  class_byte_comb = 8'h06;  // System-health aggregate fault, RTL-011
        5'd5:  class_byte_comb = 8'h05;  // Event logger overflow, RTL-005
        5'd6:  class_byte_comb = 8'h02;  // Rotor RPM abnormal/error, RTL-007
        5'd7:  class_byte_comb = 8'h02;  // Engine RPM abnormal/error, RTL-008
        5'd8:  class_byte_comb = 8'h02;  // Pulse/frequency abnormal/error, RTL-009
        5'd9:  class_byte_comb = 8'h02;  // Sensor abnormal/configuration error, RTL-010
        5'd10: class_byte_comb = 8'h03;  // ARINC RX error, RTL-017
        5'd11: class_byte_comb = 8'h03;  // ARINC TX error, RTL-018
        5'd12: class_byte_comb = 8'h03;  // CAN error or bus-off, RTL-019
        5'd13: class_byte_comb = 8'h03;  // UART error, RTL-020
        5'd14: class_byte_comb = 8'h03;  // Databus routing error, RTL-021
        5'd15: class_byte_comb = 8'h7F;  // Mask-defined user-logic error, RTL-022
        5'd16: class_byte_comb = 8'h03;  // User-routing error, RTL-023
        default: class_byte_comb = 8'h00;
      endcase
    end
  end

  // ==========================================================================
  // FAULTED/DEGRADED requests and safety inhibit (SS10.1, RTL-013_RevA.md
  // SS2 -- see header for the level-vs-latched/active-vs-active-or-sticky
  // distinctions).
  // ==========================================================================
  wire [16:0] nonrecoverable_mask17 = ~ctl_recoverable_mask[16:0];
  wire [16:0] nonrecoverable_evidence17 = (active17 | sticky17) & nonrecoverable_mask17;
  wire [16:0] recoverable_active17     = active17 & ctl_recoverable_mask[16:0];
  wire [16:0] nonrecoverable_active17  = active17 & nonrecoverable_mask17;

  assign faulted_req_o    = ctl_enable && (|nonrecoverable_evidence17);
  assign degraded_req_o   = ctl_enable && ctl_degraded_enable && (|recoverable_active17);
  assign safety_inhibit_o = {4{ctl_enable && (|nonrecoverable_active17)}};

  // ACTIVE-only nonrecoverable evidence (not active-OR-sticky) -- the "live
  // REQUESTED" input to the level-vs-latch policy below, same active-only
  // scope already used for safety_inhibit_o. Using the broader active-OR-
  // sticky nonrecoverable_evidence17 here would make response_pending_q
  // track sticky evidence unconditionally, defeating LATCH_UNTIL_HOST_
  // CLEAR's own "level policy" case entirely (response_pending_q could
  // never auto-clear once any nonrecoverable source had ever latched).
  wire response_trigger = ctl_enable && ctl_safety_response_enable && (|nonrecoverable_active17);

  // ==========================================================================
  // Sticky W1C module-level status evidence + response_pending_q +
  // DEGRADED_STATUS lifecycle -- new-evidence-dominates-clear
  // (RTLSTD-PRIN-006/RTLSTD-REG-008), cleared by core/module reset or an
  // accepted host clear-request (same "Reset, then new evidence, then
  // clear" priority every REG-002 row for these fields documents).
  // ==========================================================================
  logic fault_active_sticky_q;
  logic multi_fault_sticky_q;
  logic event_pending_sticky_q;
  logic response_pending_q;
  logic degraded_entry_sticky_q;
  logic degraded_recovered_q;
  logic degraded_active_prev_q;
  logic any_active_prev_q;

  wire degraded_active_now = degraded_req_o;
  wire degraded_recovery_available = degraded_entry_sticky_q && !degraded_active_now;

  // event_pending_sticky tracks this module's own one-deep event-generation
  // slot occupancy (evt_pending_q, declared below) -- forward-referenced
  // here only as a plain continuous wire read, resolved by simulation/
  // synthesis regardless of declaration order for a sequential always_ff
  // read (this project's own confirmed forward-reference finding applies to
  // continuous assigns, not registered reads inside always_ff).
  logic evt_pending_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sticky_q                <= 32'h0;
      fault_active_sticky_q   <= 1'b0;
      multi_fault_sticky_q    <= 1'b0;
      event_pending_sticky_q  <= 1'b0;
      response_pending_q      <= 1'b0;
      degraded_entry_sticky_q <= 1'b0;
      degraded_recovered_q    <= 1'b0;
      degraded_active_prev_q  <= 1'b0;
      any_active_prev_q       <= 1'b0;
    end else if (module_reset_i) begin
      sticky_q                <= 32'h0;
      fault_active_sticky_q   <= 1'b0;
      multi_fault_sticky_q    <= 1'b0;
      event_pending_sticky_q  <= 1'b0;
      response_pending_q      <= 1'b0;
      degraded_entry_sticky_q <= 1'b0;
      degraded_recovered_q    <= 1'b0;
      degraded_active_prev_q  <= 1'b0;
      any_active_prev_q       <= 1'b0;
    end else begin
      sticky_q <= sticky_next;

      if (any_active)                  fault_active_sticky_q <= 1'b1;
      else if (ctl_clr_fault_active)   fault_active_sticky_q <= 1'b0;

      if (multiple_now)                multi_fault_sticky_q <= 1'b1;
      else if (ctl_clr_multi_fault)    multi_fault_sticky_q <= 1'b0;

      if (evt_pending_q)               event_pending_sticky_q <= 1'b1;
      else if (ctl_clr_event_pending)  event_pending_sticky_q <= 1'b0;

      if (response_trigger)                 response_pending_q <= 1'b1;
      else if (ctl_clr_response_pending)    response_pending_q <= 1'b0;
      else if (!ctl_latch_until_host_clear) response_pending_q <= 1'b0;  // level policy: auto-tracks live condition

      if (degraded_active_now)            degraded_entry_sticky_q <= 1'b1;
      else if (ctl_clr_degraded_entry)    degraded_entry_sticky_q <= 1'b0;

      if (degraded_active_prev_q && !degraded_active_now) degraded_recovered_q <= 1'b1;
      else if (ctl_clr_degraded_recovered)                degraded_recovered_q <= 1'b0;

      degraded_active_prev_q <= degraded_active_now;
      any_active_prev_q      <= any_active;
    end
  end

  // ==========================================================================
  // response_req_o (dfc_safety_response_req_t, 8 bits): lane 1, source 0
  // fixed (Appendix C.8 "RTL-013 fault manager"). Real output, genuinely
  // unconsumed (RTL-016 does not exist yet).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_req_comb;
  always_comb begin
    response_req_comb = '0;
    response_req_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_LO] = ctl_safety_output_request_enable;
    response_req_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_LO] = 3'd0;
    response_req_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI] = response_pending_q;
  end
  assign response_req_o = response_req_comb;

  // ==========================================================================
  // Per-condition F.3-gated event/irq subconditions (Appendix F.3 index 12:
  // 0 asserted; 1 recovered; 2 cleared; 3 response requested -- matching C.7
  // event 0x0041's own subtype ordering). No module-wide EVENT_ENABLE/
  // IRQ_ENABLE term exists for this module (see header) -- these bits are
  // the sole gate.
  // ==========================================================================
  wire clear_command_issued = ctl_enable && (ctl_clear_all_req || (|ctl_latched_source_clear[16:0]));

  wire cond_asserted  = any_active && !any_active_prev_q;
  wire cond_recovered = !any_active && any_active_prev_q;
  wire cond_cleared   = clear_command_issued;
  wire cond_response  = response_trigger && !response_pending_q;

  wire ev_asserted  = cond_asserted  & event_condition_enable_i[0];
  wire ev_recovered = cond_recovered & event_condition_enable_i[1];
  wire ev_cleared   = cond_cleared   & event_condition_enable_i[2];
  wire ev_response  = cond_response  & event_condition_enable_i[3];

  wire iq_asserted  = cond_asserted  & irq_condition_enable_i[0];
  wire iq_recovered = cond_recovered & irq_condition_enable_i[1];
  wire iq_cleared   = cond_cleared   & irq_condition_enable_i[2];
  wire iq_response  = cond_response  & irq_condition_enable_i[3];

  wire event_req = ev_asserted | ev_recovered | ev_cleared | ev_response;
  assign irq_req_o = iq_asserted | iq_recovered | iq_cleared | iq_response;

  // ==========================================================================
  // Own diagnostic event generation (event ID 0x0041, source index 12) --
  // real, one-deep pending-slot shape identical to every prior module.
  // Priority when more than one condition pulses the same cycle: response
  // requested > asserted > cleared > recovered (see header).
  // ==========================================================================
  localparam logic [15:0] EVT_ID_FAULT_MANAGER = 16'h0041;
  localparam logic [7:0]  EVT_SUBTYPE_ASSERTED  = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERED = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_CLEARED   = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_RESPONSE  = 8'd3;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL013 = 8'd12;  // ARCH-002 port catalog

  wire evt_candidate_valid = event_req;

  logic [7:0] evt_subtype_comb;
  always_comb begin
    evt_subtype_comb = EVT_SUBTYPE_ASSERTED;
    if (ev_response)        evt_subtype_comb = EVT_SUBTYPE_RESPONSE;
    else if (ev_asserted)   evt_subtype_comb = EVT_SUBTYPE_ASSERTED;
    else if (ev_cleared)    evt_subtype_comb = EVT_SUBTYPE_CLEARED;
    else if (ev_recovered)  evt_subtype_comb = EVT_SUBTYPE_RECOVERED;
    else                    evt_subtype_comb = EVT_SUBTYPE_ASSERTED;
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_FAULT_MANAGER;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL013;
    // event_data[7:0]: subtype. event_data[15:8]: primary source index
    // (C.7's own "channel or originating source index"). event_data[31:16]:
    // {8'h0, class_byte} -- disclosed packing, see header.
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]    = evt_subtype_comb;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+8 +: 8]  = {3'h0, primary_index_comb};
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = class_byte_comb;
  end

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

      // Real host clear-request for RTL013_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-3120) -- new-overflow-evidence-dominates-clear, same priority
      // as every prior module's identical fix.
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // status_o packing (dfc_rtl013_status_t, 106 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL013_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__READY_HI] = !illegal_reserved_activity;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_HI] = illegal_reserved_activity;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_STATUS__FAULT_ACTIVE_HI]      = fault_active_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_STATUS__MULTI_FAULT_HI]       = multi_fault_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_STATUS__EVENT_PENDING_HI]     = event_pending_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_STATUS__RESPONSE_PENDING_HI]  = response_pending_q;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_STATUS__CLASS_VALID_HI]       = class_valid;

    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_CLASS__CLASS_HI:dfc_types_pkg::DFC_RTL013_STATUS__FAULT_CLASS__CLASS_LO] = class_byte_comb;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_CLASS__PRIMARY_SOURCE_HI:dfc_types_pkg::DFC_RTL013_STATUS__FAULT_CLASS__PRIMARY_SOURCE_LO] = primary_index_comb;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_CLASS__MULTIPLE_HI] = multiple_now;

    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__DEGRADED_STATUS__ACTIVE_HI]             = degraded_active_now;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__DEGRADED_STATUS__ENTRY_HI]              = degraded_entry_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__DEGRADED_STATUS__RECOVERY_AVAILABLE_HI] = degraded_recovery_available;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__DEGRADED_STATUS__RECOVERED_HI]          = degraded_recovered_q;

    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_ACTIVE_SOURCE__ACTIVE_SOURCE_HI:dfc_types_pkg::DFC_RTL013_STATUS__FAULT_ACTIVE_SOURCE__ACTIVE_SOURCE_LO] = active_qualified;
    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__FAULT_LATCHED_SOURCE__LATCHED_SOURCE_HI:dfc_types_pkg::DFC_RTL013_STATUS__FAULT_LATCHED_SOURCE__LATCHED_SOURCE_LO] = sticky_q;

    status_comb[dfc_types_pkg::DFC_RTL013_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL013_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): observational_mode_i is a real,
  // structurally-required port with no functional use in this module's own
  // real equations (RTL-013's own spec never names it), same disclosed
  // pattern already established for dfc_rtl007/008/009/010/011/012.sv.
  // ctl_event_on_clear joins this sink too -- FAULT_RESPONSE.EVENT_ON_CLEAR
  // is real, stored, and host-readable via FAULT_RESPONSE itself, but no
  // owning contract gives it a bit-exact wired effect distinct from the
  // already-real "cleared" event subtype above (which fires on every
  // accepted clear command regardless of this bit) -- same class of
  // no-functional-consequence disclosed gap as RTL-012's own
  // WDOG_CONTROL.WINDOW_ENABLE. ----
  logic unused_stub_sink;
  assign unused_stub_sink = observational_mode_i ^ ctl_event_on_clear;

endmodule : dfc_rtl013
