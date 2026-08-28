// dfc_rtl002.sv -- RTL-002 System Control Logic. Hand-authored (not
// generated); sole producer of dfc_operating_state_t and sole source of
// module_reset_o[23:0]. Implements ARCH-002 SS4 (primary/orthogonal state,
// startup/readiness), RTL-002 spec SS5 (module enable, reset fan-out,
// readiness aggregation), SS6 (SYS_CONTROL/SYS_STATUS), and Appendix F.1
// (ARCH-RTL002-001 derivation contract).
//
// Controlling documents: docs/rtl_specs/RTL-002_RevA.md, RCA-DFC-ARCH-002
// SS4/Appendix B.5/Appendix F.1, RCA-DFC-REG-002 0x0000-0x005C.
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement is
// emitted anywhere in this file.
//
// ============================================================================
// SCOPE OF THIS FIRST IMPLEMENTATION -- read before trusting this for
// anything beyond first HIL bring-up alongside RTL-001 (CHTR-002 SS5.2):
//
// IMPLEMENTED:
//   - Primary operating-state FSM, exact priority order (RESET_ACTIVE >
//     FAULTED > STARTUP > DEGRADED > TEST_DEBUG > NORMAL), reserved-state
//     safety net (any encoding outside the six named states forces FAULTED,
//     RTLSTD-FSM-005).
//   - EFFECTIVE_OPERATIONAL_ENABLE computed exactly as RTL-002 spec SS3/
//     ARCH-002 SS4.1 states it -- imported verbatim, not re-derived.
//   - SUBSYS_ENABLE mandatory (0x80F81F, always-on) / optional (0x7F07E0,
//     host-configurable) masking; mandatory-module readiness/fault
//     aggregation; enabled-optional-module fault aggregation for DEGRADED
//     entry (DFC-FUNC-0010).
//   - Mandatory-init timeout per DFC-PERF-0002 (499,000 CORE_CLK cycles):
//     INIT_COMPLETE if mandatory readiness achieved first, INIT_FAILED (->
//     FAULTED) if the timeout expires first.
//   - DEGRADED_ACK: sticky-per-episode acceptance (latched while in
//     DEGRADED, including same-cycle ack+causes-clear), cleared whenever
//     the state machine leaves DEGRADED by any path -- a later, new
//     DEGRADED episode requires a fresh ack.
//   - RESET_CONTROL/RESET_STATUS: real busy/assert/wait-ready sequencing
//     for exactly one of {SYSTEM_RESET, one MODULE_RESET bit,
//     SAFETY_DOMAIN_RESET}; multiple-simultaneous-scope and busy-reject
//     handling (REG-ENC-019); >=4-cycle assert hold; 2-consecutive-ready-
//     cycle completion check; sticky complete/rejected/timeout/
//     recovery_failure evidence with new-terminal-result-dominates-clear
//     priority (DFC-FUNC-0014); last_scope (24-bit mask actually acted on)
//     and last_result (locally-defined 5-bit encoding, see RC_RESULT_*
//     below -- REG-002/ARCH-002 do not give this field's bit-exact
//     encoding, so this is an implementation choice within the field's
//     documented width, not a copied spec fact).
//   - SYSTEM_RESET scope (ARCH-RST-005): asserts module_reset_o[23:1]
//     (RTL-002 through RTL-024, never bit 0), waits for mandatory-mask
//     readiness, records completion, then -- exactly one CORE_CLK later,
//     as the spec's own timing requires -- pulses module_reset_o[0] once
//     to clear RTL-001 configuration.
//   - SAFETY_DOMAIN_RESET scope (ARCH-RST-006): asserts module_reset_o
//     bits 11-15 (RTL-012 through RTL-016) only, using the same generic
//     assert/wait-ready sequencing as a normal module reset.
//   - HOST_READY qualifier registered from module_ready_i[0] (RTL-001) AND
//     module_ready_i[23] (RTL-024) -- see NOT YET IMPLEMENTED note below,
//     this is a disclosed interpretation, not a directly-cited spec fact.
//   - IRQ_REQ_O (source index 0): level-active while DEGRADED, FAULTED, or
//     any reset-command sticky evidence (complete/rejected/timeout/
//     recovery_failure) is set and unacknowledged -- see NOT YET
//     IMPLEMENTED note, RTL-002 spec does not enumerate this module's
//     exact IRQ source condition set.
//   - REAL, CONFIRMED PORT-CATALOG GAP CLOSED THIS SESSION (RTL-013's own
//     integration): this module previously had no `degraded_req_i`/
//     `faulted_req_i` ports at all, despite ARCH-002's own RTL-002 port
//     catalog already specifying both (producer RTL-013.degraded_req_o/
//     faulted_req_o) -- same class of gap as OPEN_ISSUES.md items 5/22/54
//     (a sibling module's own port-catalog nonconformance surfacing during
//     a later module's integration). Both are now real ports, folded into
//     the primary-state FSM's FAULTED/DEGRADED entry conditions as
//     ADDITIONAL causes alongside the pre-existing module_fault_i-based
//     mandatory/optional aggregation (`faulted_request_now`/
//     `degraded_request_now`, ARCH-STATE-004/005's own generic wording
//     covers both sources uniformly) -- see those wires' own declaration
//     comment for the full derivation. This does NOT change SUBSYS_FAULT/
//     module_fault_i aggregation, which remains pure per-module status.
//
// NOT YET IMPLEMENTED -- real, disclosed gaps, not silent no-ops:
//   - TEST_DEBUG is now genuinely reachable (see the real test_active_i
//     port added this session, per ARCH-002's port catalog -- producer
//     RTL-024.test_active_o) -- but only structurally: RTL-024 does not
//     yet have real production-test infrastructure (CAPTURE/SHIFT/
//     SAFE_LOOPBACK, physical authorization timing), so test_active_i is
//     tied to a disclosed stub (1'b0) in dfc_rtl024.sv until that exists.
//     The state machine's entry/exit logic for TEST_DEBUG is real and
//     tested (see rtl002_state_tb.sv); only the upstream signal driving
//     it is still a placeholder.
//   - Event generation (evt_valid_o/evt_record_o) is now REAL: event
//     0x0001 (operating-state transition, entry/degraded-ack subtypes)
//     and event 0x0004 (controlled reset, requested/complete/rejected/
//     timeout subtypes), source index 1 per ARCH-002 Appendix C.5, with a
//     real one-deep pending-record holding register and real, counted
//     overflow evidence (event_overflow/event_drop_count). Disclosed
//     simplifications: a state transition's implicit "exit" subtype is
//     collapsed into the single "entry" record rather than emitting two
//     records per transition; the 0x0001 event's prior/new-state bit
//     packing within the detail field is an interpretation, not a
//     bit-exact citation (see the block's own header comment); this
//     module has no safety-class event source, so the documented
//     safety/overflow-bypass clause never applies here.
//   - The recovery-timeout bound used while waiting for post-reset
//     readiness reuses DFC-PERF-0002's 499,000-cycle mandatory-init bound.
//     RTL-002 spec SS5 does not give an independent bound for this case;
//     this is a disclosed assumption, not a cited fact.
//   - This implementation's only reset-command failure path (post-reset
//     readiness never regained) sets BOTH reset_status__timeout and
//     reset_status__recovery_failure sticky evidence together. The spec
//     gives these as two distinct W1C bits without describing a scenario
//     that sets one without the other; a future failure mode that
//     genuinely separates "the command timed out" from "readiness
//     specifically was never regained" is not modeled.
//   - module_reset_o[0] (used only by the SYSTEM_RESET RTL-001-config-clear
//     pulse) currently has no real consumer: dfc_rtl001.sv, as delivered,
//     has no module_reset_i port at all. This is a genuine, disclosed
//     cross-module integration gap, not something this file can fix
//     unilaterally -- log it in OPEN_ISSUES.md.
//   - RESET_CONTROL's protection-key gating (REG-002 SS4, the same
//     PROTECT_KEY sequence RTL-001 implements for other protected
//     registers) is enforced by RTL-001's own DRI validation path before a
//     write ever reaches control_i, not re-checked here. RTL-002 trusts
//     that any command_pulse arriving on control_i was already
//     authorization-gated upstream.
//
// Log anything this reveals as a genuine spec gap -- not a coding mistake
// -- in OPEN_ISSUES.md per CLAUDE.md's working rules.
//
// PACKAGE-CONTENT ASSUMPTION (verify against the real generated
// dfc_types_pkg.sv, which this file was written without direct sight of --
// only ARCH-002/RTL-002_RevA.md's prose and bit-layout tables were
// available in this session): dfc_operating_state_t's enum literals are
// assumed spelled exactly as ARCH-002 SS4.1's "State" column
// (RESET_ACTIVE, STARTUP, NORMAL, DEGRADED, FAULTED, TEST_DEBUG), and
// dfc_rtl002_control_t/dfc_rtl002_status_t's member names are assumed
// spelled exactly as ARCH-002 Appendix B.5's "Member" column (e.g.
// sys_control__operational_enable). If the real generated package spells
// any of these differently, this file will fail to compile at that exact
// point -- fix the reference here to match the generator's real output,
// do not change the generator to match a guess made in this file.
// ============================================================================

module dfc_rtl002 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002's own local-reset input
                                            // (module_reset_o[1] looped back)

  // TOOLCHAIN-DRIVEN DEVIATION (real, confirmed): the person's actual
  // production Yosys build ("Yosys 0.66+252" in oss-cad-suite) rejects a
  // package-scoped type used directly as a port's declared type --
  // confirmed via a real build failure: "dfc_rtl002.sv:141: ERROR: syntax
  // error, unexpected TOK_PACKAGESEP, expecting ')' or ',' or '='" on
  // exactly this pattern (`output dfc_types_pkg::dfc_operating_state_t
  // operating_state_o`). This could NOT be reproduced against either
  // yowasp-yosys 0.66.0.0.post1165 or 0.68.0.0.post1208 in a sandbox
  // check -- both accept the construct fine, including a minimal isolated
  // reproduction of this exact pattern -- so this is a specific-commit
  // parser difference within the "0.66" line, not something to dismiss
  // because it didn't reproduce elsewhere. Fix: every port that would
  // otherwise be `dfc_types_pkg::some_type_t` is declared here as a plain
  // `logic [W-1:0]` vector instead (bit-identical layout -- a packed
  // struct/enum IS a packed vector under the hood in SV), with the real,
  // fully-typed value cast to/from that vector immediately inside the
  // module. This is a Verilog-port-declaration-syntax deviation only --
  // the port's real name, direction, and width still match the
  // Architecture formal port catalog exactly (RTLSTD-MOD-004); only the
  // declared-type spelling at the port itself changes, because the
  // person's actual toolchain cannot parse the alternative. If this
  // toolchain limitation is ever fixed/worked around upstream, this can
  // revert to the direct pkg::type_t form.
  //
  // Widths below reference `dfc_types_pkg::DFC_*_WIDTH` -- generated
  // localparam VALUE constants (pkggen.py now emits one WIDTH constant
  // plus one HI/LO bit-position pair per field for every struct/enum in
  // dfc_types_pkg.sv), not hardcoded numeric literals and not
  // `$bits(dfc_types_pkg::some_type_t)` (that alternative was tried and
  // is ALSO rejected by this exact toolchain build: "syntax error,
  // unexpected ')', expecting OP_CAST" -- `$bits()` given a bare type
  // name, rather than an expression, in a port's packed-dimension
  // position is a second, independent parser limitation in the same
  // build). A plain package-scoped VALUE reference in a packed-dimension
  // range expression uses the identical constant-expression grammar
  // already proven safe elsewhere in this file and in `dfc_rtl001.sv`
  // (e.g. `dri_req_addr_i == dfc_registers_pkg::DFC_ADDR_PROTECT_KEY`) --
  // this is expected to be safe by the same reasoning, but has NOT been
  // independently confirmed against the person's exact toolchain in this
  // specific position (a port's packed-dimension range) the way the
  // simpler expression-context case has. If the person's real
  // `build_ecp5.ps1` run rejects this too, report the exact new error
  // back rather than assume it works.
  input  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0]  control_i,
  output logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]   status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,
  output logic         irq_req_o,

  input  logic [23:0] module_ready_i,
  input  logic [23:0] module_fault_i,
  output logic [23:0] module_reset_o,

  // REAL ports, per the Architecture formal port catalog (RTL-002 -- rows
  // `degraded_req_i`/`faulted_req_i`, producer RTL-013.degraded_req_o/
  // faulted_req_o) -- closes a real, pre-existing gap in this already-
  // shipped module (same class as OPEN_ISSUES.md items 5/22/54: a sibling
  // module's own port-catalog nonconformance surfacing during a later
  // module's integration; ARCH-002 already specified both ports correctly,
  // this file simply never implemented them before RTL-013 existed to
  // drive them). `degraded_req_i` is RTL-013's own qualified, classified
  // "at least one recoverable source is currently active" request;
  // `faulted_req_i` is its qualified "at least one nonrecoverable source is
  // active or latched" request -- both are ADDITIONAL causes alongside this
  // module's own pre-existing module_fault_i-based mandatory/optional
  // aggregation, not a replacement for it (ARCH-STATE-004/005's own generic
  // "at least one enabled optional-function fault"/"a mandatory or
  // nonrecoverable fault" wording covers both sources uniformly). See
  // faulted_request_now/degraded_request_now below.
  input  logic         degraded_req_i,
  input  logic         faulted_req_i,
  output logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_o,
  output logic         observational_mode_o,

  // REAL port, per the Architecture formal port catalog (RTL-002 -- 24
  // ports): `test_active_i`, producer `RTL-024.test_active_o`. Added this
  // session to close a real port-catalog nonconformance -- previously
  // this port didn't exist on this module at all. Tied to a disclosed
  // stub (1'b0, "test never active") in `dfc_rtl024.sv` until RTL-024's
  // own production-test infrastructure (CAPTURE/SHIFT/SAFE_LOOPBACK,
  // physical authorization timing) is real -- that is genuinely separate,
  // larger work, not something this port's mere existence solves. Until
  // then, `TEST_DEBUG` remains structurally present in the state machine
  // below but is never actually entered, since its qualifying input is
  // always driven low.
  input  logic         test_active_i,

  // REAL ports, per the Architecture formal port catalog -- closes
  // OPEN_ISSUES.md item 5 (this module previously had no port carrying
  // either gate, forcing `dfc_rtl024.sv` to read `rtl002_control` directly
  // as a workaround). `global_irq_enable_o`/`global_event_enable_o` are
  // driven below from the same real SYS_CONTROL.GLOBAL_IRQ_ENABLE/
  // GLOBAL_EVENT_ENABLE bits this module already extracts from control_i
  // (the latter already used internally to gate event generation above).
  // `event_condition_enable_i`/`irq_condition_enable_i` (Appendix F.3
  // per-module condition masks) are real ports but have no real producer
  // anywhere in this project yet (OPEN_ISSUES.md item 6 -- RTL-001 does
  // not implement the underlying CONDITION_MASK storage/forwarding
  // mechanism); tied to a disclosed stub (64'h0) in `dfc_rtl024.sv` and
  // genuinely unused inside this module until that mechanism exists.
  output logic         global_irq_enable_o,
  output logic         global_event_enable_o,
  input  logic [63:0]  event_condition_enable_i,
  input  logic [63:0]  irq_condition_enable_i,

  // REAL ports, per the Architecture formal port catalog (RTL-002 -- 24
  // ports, rows `module_enable_o`/`effective_operational_enable_o`) --
  // added during RTL-006's own integration session, same class of gap as
  // OPEN_ISSUES.md item 5 (a sibling module's own port-catalog
  // nonconformance surfacing during a later module's integration):
  // RTL-006's real `module_enable_i`/`effective_operational_enable_i`
  // ports name these two as their producer, but neither existed on this
  // module before now. `module_enable_o` is the real SUBSYS_ENABLE bitmap
  // with mandatory bits forced to `SUBSYS_ENABLE_MANDATORY_MASK`
  // (matching the port's own documented "mandatory bits fixed, optional
  // bits configurable" semantic/reset value `0x80F81F`) ORed with the
  // already-computed `effective_optional_enable` wire -- zero new logic.
  // `effective_operational_enable_o` is a direct passthrough of the
  // already-computed `effective_operational_enable` wire (the same signal
  // `status_o.sys_status__effective_operational_enable` already exposes).
  output logic [23:0]  module_enable_o,
  output logic         effective_operational_enable_o
);

  // SECOND TOOLCHAIN-DRIVEN DEVIATION (real, confirmed): the person's real
  // build ALSO rejects `dfc_types_pkg::some_type_t` used as a plain
  // internal variable's declared type (not just a port) -- confirmed via
  // a second real build failure, same root cause, different spot:
  // "dfc_rtl002.sv:228: ERROR: syntax error, unexpected TOK_PACKAGESEP,
  // expecting TOK_ID or '#'" on `dfc_types_pkg::dfc_operating_state_t
  // state_q, state_d;`. This build has now failed on `pkg::type` used as
  // a DECLARED TYPE in two different contexts (a port, and a plain
  // internal variable) -- both are avoided below by declaring the
  // relevant signals as flat `logic [W-1:0]` vectors instead.
  //
  // This does NOT extend to plain VALUE references (`dfc_types_pkg::
  // SOME_ENUM_LITERAL` or `dfc_types_pkg::DFC_SOME_WIDTH`/`_HI`/`_LO`
  // used as an rvalue, never as a declared type) -- checked directly
  // against `dfc_rtl001.sv`, which already relies on this exact pattern
  // (`dri_req_addr_i == dfc_registers_pkg::DFC_ADDR_PROTECT_KEY`,
  // `dri_req_wdata_i == dfc_constants_pkg::DFC_PROTECT_KEY1`) and has
  // already been synthesized and place-and-routed clean on this same
  // production toolchain. So this file's primary-state comparisons/
  // assignments (below) reference `dfc_types_pkg::RESET_ACTIVE` etc.
  // directly as values, the same way RTL-001 already does -- there is no
  // local, hand-duplicated copy of the state encoding in this file for
  // that reason.
  //
  // Struct FIELD access is a separate matter: `control_i`'s individual
  // fields are extracted below as individually-named bit-slice wires from
  // the flat port vector (not a package-struct-typed local variable,
  // which would reintroduce the same declared-type failure), sliced using
  // `dfc_types_pkg::DFC_RTL002_CONTROL__<FIELD>_HI`/`_LO` -- generated
  // localparam VALUE constants, not hand-copied literal bit positions.
  // `pkggen.py` computes these directly from the real ARCH-002 Appendix B
  // field ordering every time `dfc_types_pkg.sv` is regenerated, so a
  // future ARCH-002 change to this struct's layout is picked up
  // automatically here instead of requiring a hand-updated literal --
  // closing the drift/duplication risk a hardcoded-bit-position version
  // of this file would otherwise carry.
  wire        ctl_clear_recovery_failure = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_STATUS__RECOVERY_FAILURE_HI];
  wire        ctl_clear_timeout          = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_STATUS__TIMEOUT_HI];
  wire        ctl_safety_reset           = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__SAFETY_DOMAIN_RESET_HI];
  wire        ctl_clear_rejected         = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_STATUS__REJECTED_HI];
  wire        ctl_clear_complete         = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_STATUS__COMPLETE_HI];
  wire [23:0] ctl_mod_reset_vec          = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__MODULE_RESET_HI:dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__MODULE_RESET_LO];
  wire        ctl_sys_reset              = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__SYSTEM_RESET_HI];
  wire [23:0] ctl_subsys_enable          = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SUBSYS_ENABLE__ENABLE_HI:dfc_types_pkg::DFC_RTL002_CONTROL__SUBSYS_ENABLE__ENABLE_LO];
  wire        ctl_degraded_ack           = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__DEGRADED_ACK_HI];
  wire        ctl_observational_mode     = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__OBSERVATIONAL_MODE_HI];
  wire        ctl_operational_enable     = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__OPERATIONAL_ENABLE_HI];
  wire        ctl_global_irq_enable      = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__GLOBAL_IRQ_ENABLE_HI];

  // Real host-initiated clear-request for RTL002_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
  // (REG-002 0x0044, contract REG-0044) -- closes OPEN_ISSUES.md item 2. Field
  // added to dfc_rtl002_control_t at the new highest bit (ARCH-002), so this
  // is the first real write path into event_overflow_q below.
  wire        ctl_clear_event_overflow   = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RTL002_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  // ==========================================================================
  // Fixed masks (RTL-002 spec SS5, DFC-FUNC-0010) -- Architecture-owned
  // constants, not host-configurable. Written as named localparams (not
  // bare literals) per RTLSTD-PKG-006; these exact values are cited
  // directly from RTL-002_RevA.md SS5, not invented.
  // ==========================================================================
  localparam logic [23:0] SUBSYS_ENABLE_MANDATORY_MASK = 24'h80F81F;
  localparam logic [23:0] SUBSYS_ENABLE_OPTIONAL_MASK  = 24'h7F07E0;

  // RTL-012 through RTL-016 -- bits 11-15 (index i = RTL-(i+1)) -- the
  // ARCH-RST-006 safety-domain-reset target group.
  localparam logic [23:0] SAFETY_DOMAIN_MASK           = 24'h00F800;

  // ARCH-RST-005: system reset targets RTL-002 through RTL-024, never
  // bit 0 (RTL-001) -- that module's config clear is a separate, delayed
  // one-cycle pulse (see RC_SYS_CLEAR handling below).
  localparam logic [23:0] SYSTEM_RESET_MASK            = 24'hFFFFFE;

  localparam int unsigned INIT_TIMEOUT_CYCLES     = 499_000;  // DFC-PERF-0002
  localparam int unsigned RECOVERY_TIMEOUT_CYCLES = 499_000;  // reused, see
                                                                // header note
  localparam int unsigned RESET_ASSERT_MIN_CYCLES = 4;         // ARCH-RST-004

  // ---- Locally-defined RESET_STATUS.last_result encoding (5 bits) --
  // RTL-002 spec/REG-002 give the field's width and semantic category
  // (terminal reset result) but not a bit-exact encoding; this is an
  // implementation choice within the documented width, per the header
  // note above.
  localparam logic [4:0] RC_RESULT_NONE              = 5'd0;
  localparam logic [4:0] RC_RESULT_COMPLETE           = 5'd1;
  localparam logic [4:0] RC_RESULT_REJECTED_BUSY      = 5'd2;
  localparam logic [4:0] RC_RESULT_REJECTED_MULTIPLE  = 5'd3;
  localparam logic [4:0] RC_RESULT_TIMEOUT            = 5'd4;
  localparam logic [4:0] RC_RESULT_RECOVERY_FAILURE   = 5'd5;

  // ==========================================================================
  // Primary operating-state register (ARCH-002 SS4.1 / dfc_operating_state_t)
  // ==========================================================================
  // state_q/state_d are a plain `logic [2:0]`, NOT `dfc_types_pkg::
  // dfc_operating_state_t` -- that declared-type usage is the confirmed-
  // broken pattern on the person's real toolchain (see the header's
  // TOOLCHAIN-DRIVEN DEVIATION notes above). Comparisons/assignments
  // against the six named states below reference `dfc_types_pkg::` as a
  // plain VALUE, not a declared type -- this is the SAME pattern
  // `dfc_rtl001.sv` already uses successfully (e.g.
  // `dri_req_addr_i == dfc_registers_pkg::DFC_ADDR_PROTECT_KEY`,
  // `dri_req_wdata_i == dfc_constants_pkg::DFC_PROTECT_KEY1`), and
  // RTL-001 has already been synthesized and place-and-routed clean on
  // this exact production toolchain with that pattern -- confirming
  // `pkg::VALUE` in an expression is safe here, unlike `pkg::TYPE` used
  // as a declared type. No local, hand-duplicated copy of the encoding is
  // needed for this reason; the single source of truth stays
  // `dfc_types_pkg::dfc_operating_state_t` itself.
  logic [2:0] state_q, state_d;

  logic init_complete_q, init_failed_q;
  logic illegal_state_q;

  // ---- SUBSYS_ENABLE / readiness-fault aggregation (combinational -- these
  // reflect the *current* module_ready_i/module_fault_i and control_i, per
  // ARCH-RTL002-001's "ready is host-path AND state-logic initialized")
  wire [23:0] effective_optional_enable =
    ctl_subsys_enable & SUBSYS_ENABLE_OPTIONAL_MASK;

  wire mandatory_ready_now =
    &(module_ready_i | ~SUBSYS_ENABLE_MANDATORY_MASK);
  wire mandatory_fault_now =
    |(module_fault_i & SUBSYS_ENABLE_MANDATORY_MASK);
  wire optional_enabled_fault_now =
    |(module_fault_i & effective_optional_enable);

  // ---- RTL-013's own classified escalation requests, folded in as
  // ADDITIONAL causes for the primary-state FSM's FAULTED/DEGRADED entry
  // conditions (see the degraded_req_i/faulted_req_i port declarations
  // above for the full derivation) -- these do NOT feed SUBSYS_FAULT/
  // module_fault_i aggregation, which remains pure per-module status.
  wire faulted_request_now  = mandatory_fault_now || faulted_req_i;
  wire degraded_request_now = optional_enabled_fault_now || degraded_req_i;

  // ---- Mandatory-init timeout counter (DFC-PERF-0002) ----
  logic [31:0] init_timeout_q;
  wire         init_timeout_expired = (init_timeout_q >= INIT_TIMEOUT_CYCLES);

  // ---- HOST_READY qualifier -- see header NOT YET IMPLEMENTED-adjacent
  // disclosed-interpretation note: registered from RTL-001/RTL-024
  // readiness, the two producers ARCH-START-003 actually names.
  logic host_ready_q;

  // ---- DEGRADED_ACK per-episode latch ----
  logic degraded_ack_latched_q;
  wire  degraded_ack_effective =
    degraded_ack_latched_q || ctl_degraded_ack;

  // ---- Observational-mode broadcast register ----
  logic observational_mode_q;

  // ==========================================================================
  // Primary-state next-state logic (priority: RESET_ACTIVE, FAULTED,
  // STARTUP, DEGRADED, TEST_DEBUG, NORMAL -- ARCH-STATE-001-007)
  // ==========================================================================
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      dfc_types_pkg::RESET_ACTIVE: begin
        // core_rst_n_i arrives already synchronized (RTL-024 performs the
        // 4-edge release sync, ARCH-RST-001); the first non-reset cycle
        // here *is* "the first CORE_CLK edge after qualified release".
        state_d = dfc_types_pkg::STARTUP;
      end

      dfc_types_pkg::STARTUP: begin
        if (faulted_request_now || init_timeout_expired) begin
          state_d = dfc_types_pkg::FAULTED;
        end else if (mandatory_ready_now) begin
          if (degraded_request_now)        state_d = dfc_types_pkg::DEGRADED;
          else if (test_active_i)          state_d = dfc_types_pkg::TEST_DEBUG;
          else                             state_d = dfc_types_pkg::NORMAL;
        end
      end

      dfc_types_pkg::NORMAL: begin
        if (faulted_request_now) state_d = dfc_types_pkg::FAULTED;
        else if (degraded_request_now) state_d = dfc_types_pkg::DEGRADED;
        else if (test_active_i) state_d = dfc_types_pkg::TEST_DEBUG;
      end

      dfc_types_pkg::DEGRADED: begin
        if (faulted_request_now) begin
          state_d = dfc_types_pkg::FAULTED;
        end else if (!degraded_request_now && degraded_ack_effective) begin
          state_d = test_active_i ? dfc_types_pkg::TEST_DEBUG : dfc_types_pkg::NORMAL;
        end
        // test_active_i alone never overrides an active DEGRADED cause --
        // DEGRADED outranks TEST_DEBUG in the documented priority order.
      end

      dfc_types_pkg::FAULTED: begin
        state_d = dfc_types_pkg::FAULTED;  // latched until system/ext reset
      end

      dfc_types_pkg::TEST_DEBUG: begin
        // Now genuinely reachable: qualifies on the real test_active_i
        // port (see that port's header note). DEGRADED still outranks
        // TEST_DEBUG per the documented priority order, so a newly
        // enabled optional fault exits to DEGRADED even while test-active
        // remains asserted; otherwise exits back to NORMAL once
        // test_active_i deasserts.
        if (faulted_request_now) state_d = dfc_types_pkg::FAULTED;
        else if (degraded_request_now) state_d = dfc_types_pkg::DEGRADED;
        else if (!test_active_i) state_d = dfc_types_pkg::NORMAL;
      end

      default: state_d = dfc_types_pkg::FAULTED;  // reserved-state safety net
    endcase
  end

  // ==========================================================================
  // Sequential state: primary FSM, startup summary, degraded-ack episode,
  // observational-mode/host-ready registers. module_reset_i (looped back
  // from this module's own module_reset_o[1]) forces the same synchronous
  // reinitialization as core_rst_n_i while asserted, per ARCH-RST-004's
  // per-module reset contract.
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      state_q                <= dfc_types_pkg::RESET_ACTIVE;
      init_complete_q         <= 1'b0;
      init_failed_q           <= 1'b0;
      illegal_state_q         <= 1'b0;
      init_timeout_q          <= 32'd0;
      host_ready_q            <= 1'b0;
      degraded_ack_latched_q  <= 1'b0;
      observational_mode_q    <= 1'b1;  // SYS_CONTROL reset value, SS6
    end else if (module_reset_i) begin
      state_q                <= dfc_types_pkg::RESET_ACTIVE;
      init_complete_q         <= 1'b0;
      init_failed_q           <= 1'b0;
      illegal_state_q         <= 1'b0;
      init_timeout_q          <= 32'd0;
      host_ready_q            <= 1'b0;
      degraded_ack_latched_q  <= 1'b0;
      observational_mode_q    <= 1'b1;
    end else begin
      state_q <= state_d;

      // reserved-encoding safety evidence (RTLSTD-FSM-005): can only ever
      // observe this if state_q somehow read back outside the six named
      // literals -- kept as a defensive latch, not expected to assert.
      if (state_q != dfc_types_pkg::RESET_ACTIVE   &&
          state_q != dfc_types_pkg::STARTUP        &&
          state_q != dfc_types_pkg::NORMAL         &&
          state_q != dfc_types_pkg::DEGRADED       &&
          state_q != dfc_types_pkg::FAULTED        &&
          state_q != dfc_types_pkg::TEST_DEBUG) begin
        illegal_state_q <= 1'b1;
      end

      // startup timeout counter: runs only in STARTUP, clears on exit/entry
      if (state_q == dfc_types_pkg::STARTUP && state_d == dfc_types_pkg::STARTUP) begin
        init_timeout_q <= init_timeout_q + 32'd1;
      end else if (state_d == dfc_types_pkg::STARTUP) begin
        init_timeout_q <= 32'd0;
      end

      // startup summary: latched once, on the cycle STARTUP is left
      if (state_q == dfc_types_pkg::STARTUP && state_d != dfc_types_pkg::STARTUP) begin
        if (state_d == dfc_types_pkg::FAULTED) begin
          init_failed_q   <= 1'b1;
          init_complete_q <= 1'b0;
        end else begin
          init_complete_q <= 1'b1;
          init_failed_q   <= 1'b0;
        end
      end

      host_ready_q <= module_ready_i[0] && module_ready_i[23];

      // degraded-ack episode: sticky only while actually in DEGRADED
      if (state_q != dfc_types_pkg::DEGRADED) begin
        degraded_ack_latched_q <= 1'b0;
      end else if (ctl_degraded_ack) begin
        degraded_ack_latched_q <= 1'b1;
      end

      observational_mode_q <= ctl_observational_mode;
    end
  end

  assign operating_state_o    = state_q;
  assign observational_mode_o = observational_mode_q;

  // ==========================================================================
  // EFFECTIVE_OPERATIONAL_ENABLE -- imported verbatim from RTL-002 spec SS3
  // / ARCH-002 SS4.1, never re-derived differently.
  // ==========================================================================
  wire effective_operational_enable =
    ctl_operational_enable &&
    init_complete_q && !init_failed_q &&
    ((state_q == dfc_types_pkg::NORMAL) || (state_q == dfc_types_pkg::DEGRADED)) &&
    !observational_mode_q &&
    (state_q != dfc_types_pkg::TEST_DEBUG);

  // ==========================================================================
  // RESET_CONTROL / RESET_STATUS command sequencing (REG-002 0x0028/0x002C,
  // ARCH-RST-004/005/006, RTL-002 spec SS5)
  // ==========================================================================
  typedef enum logic [2:0] {
    RC_IDLE, RC_ASSERT, RC_WAIT_READY, RC_SYS_CLEAR_PULSE
  } rc_state_e;
  rc_state_e rc_state_q, rc_state_d;

  logic [23:0] target_mask_q;       // module_reset_o bits asserted this cmd
  logic [23:0] ready_check_mask_q;  // bits that must all read ready
  logic        scope_is_system_q;
  logic [23:0] last_scope_q;
  logic [4:0]  last_result_q;
  logic [2:0]  assert_count_q;
  logic [1:0]  ready_streak_q;
  logic [31:0] recovery_timeout_q;

  logic reset_status_complete_q, reset_status_rejected_q;
  logic reset_status_timeout_q, reset_status_recovery_failure_q;
  logic sys_clear_pulse_q;  // one-cycle RTL-001-config-clear pulse (bit 0)

  // ---- Incoming command decode (only meaningful while RC_IDLE) ----
  wire        sys_reset_req    = ctl_sys_reset;
  wire [23:0] mod_reset_vec    = ctl_mod_reset_vec;
  wire        safety_reset_req = ctl_safety_reset;
  wire [4:0]  requested_scope_count =
    5'(sys_reset_req) + 5'(safety_reset_req) + 5'($countones(mod_reset_vec));
  wire        any_scope_requested = (requested_scope_count != 5'd0);
  wire        valid_single_scope  = (requested_scope_count == 5'd1);

  // ---- Combinational "next streak" value -- completion must be decided
  // against the value ready_streak_q is ABOUT to become this cycle, not the
  // stale pre-update value. A same-always_ff read of ready_streak_q on the
  // very cycle it is also being updated reads the old value (confirmed via a
  // real Icarus simulation run: without this wire, completion required
  // THREE consecutive ready cycles instead of the two ARCH-RST-004
  // specifies -- a genuine off-by-one, not a testbench artifact).
  wire mask_ready_now = (module_ready_i & ready_check_mask_q) == ready_check_mask_q;
  wire [1:0] ready_streak_next =
    mask_ready_now ? ((ready_streak_q == 2'd2) ? 2'd2 : (ready_streak_q + 2'd1)) : 2'd0;

  always_comb begin
    rc_state_d = rc_state_q;
    unique case (rc_state_q)
      RC_IDLE: begin
        if (any_scope_requested && valid_single_scope) rc_state_d = RC_ASSERT;
      end
      RC_ASSERT: begin
        if (assert_count_q == 3'(RESET_ASSERT_MIN_CYCLES - 1)) rc_state_d = RC_WAIT_READY;
      end
      RC_WAIT_READY: begin
        if (ready_streak_next == 2'd2) begin
          if (scope_is_system_q) rc_state_d = RC_SYS_CLEAR_PULSE;
          else                   rc_state_d = RC_IDLE;
        end else if (recovery_timeout_q >= RECOVERY_TIMEOUT_CYCLES) begin
          rc_state_d = RC_IDLE;
        end
      end
      RC_SYS_CLEAR_PULSE: rc_state_d = RC_IDLE;  // exactly one cycle
      default: rc_state_d = RC_IDLE;
    endcase
  end

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      rc_state_q                       <= RC_IDLE;
      target_mask_q                    <= 24'h0;
      ready_check_mask_q                <= 24'h0;
      scope_is_system_q                 <= 1'b0;
      last_scope_q                      <= 24'h0;
      last_result_q                     <= RC_RESULT_NONE;
      assert_count_q                    <= 3'd0;
      ready_streak_q                    <= 2'd0;
      recovery_timeout_q                <= 32'd0;
      reset_status_complete_q           <= 1'b0;
      reset_status_rejected_q           <= 1'b0;
      reset_status_timeout_q            <= 1'b0;
      reset_status_recovery_failure_q   <= 1'b0;
      sys_clear_pulse_q                 <= 1'b0;
    end else if (module_reset_i) begin
      rc_state_q                       <= RC_IDLE;
      target_mask_q                    <= 24'h0;
      ready_check_mask_q                <= 24'h0;
      scope_is_system_q                 <= 1'b0;
      last_scope_q                      <= 24'h0;
      last_result_q                     <= RC_RESULT_NONE;
      assert_count_q                    <= 3'd0;
      ready_streak_q                    <= 2'd0;
      recovery_timeout_q                <= 32'd0;
      reset_status_complete_q           <= 1'b0;
      reset_status_rejected_q           <= 1'b0;
      reset_status_timeout_q            <= 1'b0;
      reset_status_recovery_failure_q   <= 1'b0;
      sys_clear_pulse_q                 <= 1'b0;
    end else begin
      rc_state_q <= rc_state_d;
      sys_clear_pulse_q <= 1'b0;  // default: one-cycle pulse, cleared unless re-set below

      unique case (rc_state_q)
        RC_IDLE: begin
          if (any_scope_requested && valid_single_scope) begin
            // ---- accept exactly one scope ----
            if (sys_reset_req) begin
              target_mask_q      <= SYSTEM_RESET_MASK;
              ready_check_mask_q <= SUBSYS_ENABLE_MANDATORY_MASK;
              scope_is_system_q  <= 1'b1;
              last_scope_q        <= SYSTEM_RESET_MASK;
            end else if (safety_reset_req) begin
              target_mask_q      <= SAFETY_DOMAIN_MASK;
              ready_check_mask_q <= SAFETY_DOMAIN_MASK;
              scope_is_system_q  <= 1'b0;
              last_scope_q        <= SAFETY_DOMAIN_MASK;
            end else begin
              target_mask_q      <= mod_reset_vec;
              ready_check_mask_q <= mod_reset_vec;
              scope_is_system_q  <= 1'b0;
              last_scope_q        <= mod_reset_vec;
            end
            assert_count_q      <= 3'd0;
            ready_streak_q      <= 2'd0;
            recovery_timeout_q  <= 32'd0;
            // new terminal result dominates a simultaneous clear -- but
            // acceptance itself is not a terminal result, so leave
            // complete/rejected untouched here (handled by the W1C block
            // below) except that starting a new command with stale
            // evidence pending is legitimate; evidence clears only via
            // explicit host W1C or a new terminal result.
          end else if (any_scope_requested && !valid_single_scope) begin
            // multiple simultaneous scopes -- reject atomically, no state
            // change, no module_reset_o assertion
            reset_status_rejected_q <= 1'b1;
            last_result_q            <= RC_RESULT_REJECTED_MULTIPLE;
          end
        end

        RC_ASSERT: begin
          assert_count_q <= assert_count_q + 3'd1;
        end

        RC_WAIT_READY: begin
          recovery_timeout_q <= recovery_timeout_q + 32'd1;
          ready_streak_q <= ready_streak_next;

          if (ready_streak_next == 2'd2) begin
            reset_status_complete_q <= 1'b1;
            last_result_q            <= RC_RESULT_COMPLETE;
            if (scope_is_system_q) sys_clear_pulse_q <= 1'b1;
          end else if (recovery_timeout_q >= RECOVERY_TIMEOUT_CYCLES) begin
            reset_status_timeout_q          <= 1'b1;
            reset_status_recovery_failure_q <= 1'b1;
            last_result_q                    <= RC_RESULT_TIMEOUT;
          end
        end

        RC_SYS_CLEAR_PULSE: begin
          // module_reset_o[0] pulses this single cycle (see assign below);
          // nothing further to latch.
        end

        default: ;
      endcase

      // ---- a request arriving while genuinely busy is rejected, never
      // queued or preempted (DFC-FUNC-0012/0013) ----
      if (rc_state_q != RC_IDLE && any_scope_requested) begin
        reset_status_rejected_q <= 1'b1;
        last_result_q            <= RC_RESULT_REJECTED_BUSY;
      end

      // ---- new-terminal-result-dominates-clear W1C evidence handling
      // (DFC-FUNC-0014): a host write of the clear_mask bit clears the
      // corresponding sticky bit UNLESS this exact cycle is also setting
      // it for a new terminal result (handled by the assignments above,
      // which unconditionally set to 1 and therefore already win over any
      // same-cycle clear attempt below).
      if (!(rc_state_q == RC_WAIT_READY && ready_streak_next == 2'd2) &&
          !(rc_state_q == RC_IDLE && any_scope_requested && !valid_single_scope) &&
          !(rc_state_q != RC_IDLE && any_scope_requested)) begin
        if (ctl_clear_complete) reset_status_complete_q <= 1'b0;
        if (ctl_clear_rejected) reset_status_rejected_q <= 1'b0;
      end
      if (!(rc_state_q == RC_WAIT_READY &&
            ready_streak_next != 2'd2 && recovery_timeout_q >= RECOVERY_TIMEOUT_CYCLES)) begin
        if (ctl_clear_timeout)          reset_status_timeout_q          <= 1'b0;
        if (ctl_clear_recovery_failure)  reset_status_recovery_failure_q <= 1'b0;
      end
    end
  end

  wire reset_busy = (rc_state_q != RC_IDLE);

  assign module_reset_o = (rc_state_q == RC_ASSERT)         ? target_mask_q :
                           (rc_state_q == RC_SYS_CLEAR_PULSE) ? 24'h1        :
                           24'h0;

  // ==========================================================================
  // IRQ source (index 0 into RTL-003) -- disclosed interpretation, see
  // header note: level-active while degraded/faulted or any reset-command
  // sticky evidence is outstanding.
  // ==========================================================================
  assign irq_req_o = (state_q == dfc_types_pkg::DEGRADED) ||
                      (state_q == dfc_types_pkg::FAULTED) ||
                      reset_status_complete_q || reset_status_rejected_q ||
                      reset_status_timeout_q  || reset_status_recovery_failure_q;

  // ==========================================================================
  // Event generation (RTL-002 is event source index 1, event ID 0x02;
  // ARCH-002 Appendix C.5/C.7): real implementation this session, replacing
  // the prior stub. Two event IDs: 0x0001 (operating-state transition,
  // subtypes entry/exit/degraded-ack -- this implementation only ever
  // emits the "entry" and "degraded-ack" subtypes, collapsing a
  // transition's implicit "exit" into the same single record rather than
  // emitting two separate records per transition, a disclosed
  // simplification) and 0x0004 (controlled reset, subtypes requested/
  // complete/rejected/timeout/recovery-failure). One-deep pending-record
  // holding register per the real spec text ("one stable pending record...
  // handshake clears record only"); a new candidate arriving while the
  // slot is still occupied is a real, counted overflow (saturating
  // event_drop_count, sticky event_overflow) -- except when
  // GLOBAL_EVENT_ENABLE is off, in which case a new event is suppressed
  // without counting as overflow, per the RTM's own note that "disabled
  // normal events are suppressed without overflow."
  //
  // DISCLOSED INTERPRETATION (REG-002/ARCH-002 don't spell out the exact
  // bit convention for this specific row): "prior and new three-bit
  // states packed in bits 2:0 and 6:4" is read here as offsets WITHIN the
  // 16-bit detail field (event_data[31:16]), not as absolute bit
  // positions in the full 32-bit event_data word. If this is later found
  // wrong, only this block needs correcting.
  // ==========================================================================
  localparam logic [15:0] EVT_ID_STATE_TRANSITION = 16'h0001;
  localparam logic [15:0] EVT_ID_CONTROLLED_RESET  = 16'h0004;
  localparam logic [7:0]  EVT_SUBTYPE_STATE_ENTRY         = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_STATE_DEGRADED_ACK  = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_RESET_REQUESTED        = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_RESET_COMPLETE         = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_RESET_REJECTED         = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_RESET_TIMEOUT          = 8'd3;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL002 = 8'd1;  // ARCH-002 C.5 index 1

  wire ctl_global_event_enable = control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__GLOBAL_EVENT_ENABLE_HI];

  // Real global_irq_enable_o/global_event_enable_o ports (closes
  // OPEN_ISSUES.md item 5) -- driven directly from the same real
  // SYS_CONTROL bits extracted above/here, not a new, separately-latched
  // copy: control_i itself already carries RTL-001's registered storage
  // (reggen.py drives each RW field from its own stored register), so no
  // additional registration stage is needed inside this module.
  assign global_irq_enable_o   = ctl_global_irq_enable;
  assign global_event_enable_o = ctl_global_event_enable;

  // Real module_enable_o/effective_operational_enable_o -- see the port
  // declarations' own header note above for exactly which prior gap this
  // closes.
  assign module_enable_o               = SUBSYS_ENABLE_MANDATORY_MASK | effective_optional_enable;
  assign effective_operational_enable_o = effective_operational_enable;

  wire real_state_transition   = (state_d != state_q);
  wire degraded_ack_this_cycle = (state_q == dfc_types_pkg::DEGRADED) &&
                                  (state_d == state_q) && ctl_degraded_ack;
  wire reset_requested_this_cycle = (rc_state_q == RC_IDLE) && any_scope_requested && valid_single_scope;
  wire reset_complete_this_cycle  = (rc_state_q == RC_WAIT_READY) && (ready_streak_next == 2'd2);
  wire reset_rejected_this_cycle  = (rc_state_q != RC_IDLE && any_scope_requested) ||
                                     (rc_state_q == RC_IDLE && any_scope_requested && !valid_single_scope);
  wire reset_timeout_this_cycle   = (rc_state_q == RC_WAIT_READY) && (ready_streak_next != 2'd2) &&
                                     (recovery_timeout_q >= RECOVERY_TIMEOUT_CYCLES);

  wire evt_candidate_valid = real_state_transition || degraded_ack_this_cycle ||
    reset_requested_this_cycle || reset_complete_this_cycle ||
    reset_rejected_this_cycle || reset_timeout_this_cycle;

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL002;
    if (real_state_transition || degraded_ack_this_cycle) begin
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_STATE_TRANSITION;
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] =
        real_state_transition ? EVT_SUBTYPE_STATE_ENTRY : EVT_SUBTYPE_STATE_DEGRADED_ACK;
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16+2 -: 3] = state_q;  // prior state, detail[2:0]
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16+6 -: 3] =
        real_state_transition ? state_d : state_q;  // new state, detail[6:4]
    end else if (reset_requested_this_cycle || reset_complete_this_cycle ||
                 reset_rejected_this_cycle || reset_timeout_this_cycle) begin
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_CONTROLLED_RESET;
      if (reset_requested_this_cycle)
        evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_RESET_REQUESTED;
      else if (reset_complete_this_cycle)
        evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_RESET_COMPLETE;
      else if (reset_rejected_this_cycle)
        evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_RESET_REJECTED;
      else
        evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = EVT_SUBTYPE_RESET_TIMEOUT;
      // detail: this implementation's own last_result_q value, in the
      // detail field's own low byte -- a disclosed, locally-chosen
      // encoding, same basis as RESET_STATUS.last_result's own locally-
      // defined encoding elsewhere in this file.
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+8 +: 8] = {3'b0, last_result_q};
    end
  end

  logic                                              evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  evt_record_q;
  logic                                              event_overflow_q;
  logic [15:0]                                       event_drop_count_q;

  // ---- EVENT_OVERFLOW clear-vs-new-evidence priority (REG-0044's own
  // documented simultaneous-condition priority for this field: "reset/
  // disable, then new evidence, then clear") -- new overflow evidence
  // landing the same cycle as a host clear-write dominates, matching the
  // identical new-terminal-result-dominates-clear pattern already used for
  // RESET_STATUS's W1C fields above. Algebraically equivalent to the
  // overflow-setting condition inside the always_ff block below
  // (evt_candidate_valid && ctl_global_event_enable && evt_pending_q &&
  // !evt_ready_i), restated here as its own named wire for the clear gate.
  wire overflow_sets_this_cycle = evt_candidate_valid && ctl_global_event_enable &&
                                   evt_pending_q && !evt_ready_i;

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

      if (evt_candidate_valid && ctl_global_event_enable) begin
        if (!evt_pending_q || (evt_pending_q && evt_ready_i)) begin
          evt_pending_q <= 1'b1;
          evt_record_q  <= evt_candidate;
        end else begin
          // slot still occupied -- a real, counted overflow, not a
          // silent drop.
          if (event_drop_count_q != 16'hFFFF) event_drop_count_q <= event_drop_count_q + 16'd1;
          event_overflow_q <= 1'b1;
        end
      end
      // GLOBAL_EVENT_ENABLE off: a new event is suppressed without
      // counting as overflow (RTM's own note) -- already handled by the
      // ctl_global_event_enable gate above; no separate branch needed.

      // Real host clear-request for EVENT_OVERFLOW (REG-0044) -- closes
      // OPEN_ISSUES.md item 2. DROP_COUNT is a separate RO field with no
      // clear side effect of its own (REG-002's own register-level side-
      // effect text: "DROP_COUNT is read-only"), so this clear only ever
      // affects event_overflow_q. Gated so new overflow evidence landing
      // this same cycle wins over a simultaneous clear attempt (see
      // overflow_sets_this_cycle's own comment above).
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // status_o packing (dfc_rtl002_status_t, 112 bits, ARCH-002 Appendix B.5).
  // status_comb is a plain flat vector, not the package struct type --
  // same reasoning as control_i above: a package-scoped struct used as a
  // DECLARED TYPE is the confirmed-broken pattern on the person's real
  // toolchain, so no variable in this file is ever declared with one.
  // Each field is written via its exact bit index/range, sliced using
  // `dfc_types_pkg::DFC_RTL002_STATUS__<FIELD>_HI`/`_LO` -- generated
  // localparam VALUE constants (see the equivalent note above control_i's
  // bit-slice wires for why this is the confirmed-safe pattern, and why
  // it closes the hand-duplication/drift risk a hardcoded-bit-position
  // version of this file would otherwise carry). (The `state_q ==
  // dfc_types_pkg::SOME_STATE` comparisons below are separately a plain
  // VALUE reference to the shared enum, not a struct field -- also safe,
  // for the same underlying reason.)
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0] status_comb;

  always_comb begin
    status_comb = '0;

    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__READY_HI] = host_ready_q && init_complete_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__FAULT_HI] =
      illegal_state_q || faulted_request_now || init_failed_q || reset_status_timeout_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__RESET_ACTIVE_HI]  = (state_q == dfc_types_pkg::RESET_ACTIVE);
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__STARTUP_HI]       = (state_q == dfc_types_pkg::STARTUP);
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__HOST_READY_HI]    = host_ready_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__NORMAL_HI]        = (state_q == dfc_types_pkg::NORMAL);
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__DEGRADED_HI]      = (state_q == dfc_types_pkg::DEGRADED);
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__FAULTED_HI]       = (state_q == dfc_types_pkg::FAULTED) || illegal_state_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__OBSERVATIONAL_HI] = observational_mode_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__TEST_DEBUG_HI]    = (state_q == dfc_types_pkg::TEST_DEBUG);
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__INIT_COMPLETE_HI] = init_complete_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__INIT_FAILED_HI]   = init_failed_q;

    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SUBSYS_READY__READY_HI:dfc_types_pkg::DFC_RTL002_STATUS__SUBSYS_READY__READY_LO] = module_ready_i;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SUBSYS_FAULT__FAULT_HI:dfc_types_pkg::DFC_RTL002_STATUS__SUBSYS_FAULT__FAULT_LO] = module_fault_i;

    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__BUSY_HI]     = reset_busy;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__COMPLETE_HI] = reset_status_complete_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__REJECTED_HI] = reset_status_rejected_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__LAST_SCOPE_HI:dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__LAST_SCOPE_LO] = last_scope_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__LAST_RESULT_HI:dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__LAST_RESULT_LO] = last_result_q;

    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL002_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;

    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI] = effective_operational_enable;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__TIMEOUT_HI]          = reset_status_timeout_q;
    status_comb[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__RECOVERY_FAILURE_HI] = reset_status_recovery_failure_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): event_condition_enable_i/
  // irq_condition_enable_i are real ports per the Architecture catalog
  // (Appendix F.3) with no functional consumer in this implementation --
  // RTL-002 does not yet gate its own event/irq generation on a per-source
  // condition mask (OPEN_ISSUES.md item 6). Intentionally consumed here,
  // not silently dropped, same pattern as dfc_rtl003.sv's identical case. ----
  logic unused_stub_sink;
  assign unused_stub_sink = (|event_condition_enable_i) ^ (|irq_condition_enable_i);

endmodule : dfc_rtl002
