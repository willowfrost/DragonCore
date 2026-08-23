// dfc_rtl010.sv -- RTL-010 Sensor Monitor Interface: two independent signed
// 32-bit sampled-sensor channels with host-write atomic update, signed
// threshold/hysteresis comparison, and an age/staleness model (ARCH-002 SS9
// ARCH-MOD-010/ARCH-MON-006/007, Appendix F.1 ARCH-RTL010-001, Appendix F.3
// index 9). Owns REG-002's Sensor Monitor block (0x2300-0x236C, 25
// registers). Fourth module in the Monitoring domain, and the first whose
// input is not a physical edge pin at all -- see below.
//
// Controlling documents: docs/rtl_specs/RTL-010_RevA.md, RCA-DFC-ARCH-002
// SS9/Appendix B.5/Appendix F.1 ARCH-RTL010-001/Appendix F.3 index 9/
// Appendix C.5/C.7 event ID 0x0033/ARCH-VAL-010, RCA-DFC-REG-002 SS?? (block
// 0x2300-0x236C).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// NO PHYSICAL PIN -- CONFIRMED, NOT ASSUMED, BEFORE ANY LPF/CONNECTION-MAP
// WORK WAS DONE. RTL-010_RevA.md SS2 states this module has "no dedicated
// physical sensor input port" and ARCH-002's own formal port catalog
// ("RTL-010 - Sensor Monitor Interface (16 ports)") lists exactly the
// standard group plus timestamp_i/evt_*/irq_req_o/fault_req_o/
// operating_state_i/observational_mode_i/module_enable_i/condition-enable
// pair -- no analog/discrete input pin anywhere in that list, unlike every
// other Monitoring-domain module before it (RTL-007/008/009 each have a
// real external edge pin). Sensor values arrive exclusively through
// control_i (host writes via the staged SENSOR_UPDATE_* mechanism below).
// Confirmed directly against fpga/ecp5/ulx3s_dfc.lpf and
// ULX3S_CONNECTION_MAP.md before writing this file: NEITHER needs any new
// entry for RTL-010 -- no LOCATE COMP/IOBUF addition, no new connection-map
// section. This is a real, confirmed absence, not an oversight.
//
// ONE REAL ARCH-002 GAP, FOUND AND FIXED BEFORE this module was implemented,
// APPROVED BEFORE IMPLEMENTATION -- explicitly anticipated by this project's
// own task instructions given the eight prior real instances of this exact
// gap class (RTL-002/003's EVT_OVERFLOW_STATUS, RTL-004's SNAPSHOT_VALID/
// SYNC_VALID, RTL-005's SNAPSHOT_VALID, RTL-006/007/008/009's EVT_OVERFLOW_
// STATUS):
//   dfc_rtl010_control_t (345 bits) had no clear-request field for
//   RTL010_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x235C bit 0, a real
//   W1C field). Fixed: ARCH-002 grew the struct 345->346 bits, adding
//   rtl010_evt_overflow_status__event_overflow at the new highest bit
//   (345) -- every pre-existing field's bit position confirmed unchanged
//   via a real regenerate.ps1 run (every _HI/_LO constant below bit 345 is
//   byte-identical to the pre-growth layout).
//
// A SECOND CHECK, PERFORMED BEFORE IMPLEMENTATION (per OPEN_ISSUES.md items
// 21/23's own lesson): RTL010_EVT_OVERFLOW_STATUS's real host-READ path is
// wired from the start via tools/reggen/rtl010_field_map.json's own
// status_registers section (mapped onto this struct's generic
// event_overflow/event_drop_count fields), NOT reproducing the still-open
// RTL-002/003/004 readback gap (OPEN_ISSUES.md item 21) -- same discipline
// already established for RTL-006/007/008/009. The field-map's
// status_registers section also closes the readback path for every OTHER
// external RTL-010 register (SENSOR_STATUS/SENSOR0_VALUE/SENSOR0_STATUS/
// SENSOR0_CURRENT_AGE_MS/SENSOR1_VALUE/SENSOR1_STATUS/
// SENSOR1_CURRENT_AGE_MS/SENSOR0_META/SENSOR1_META) from the start.
//
// A REAL, DISCLOSED GAP -- LOGGED IN OPEN_ISSUES.md, NOT SILENTLY WORKED
// AROUND: ARCH-MON-007/ARCH-RTL010-001 both describe a "host commit
// precedes ROUTED commit" priority, implying RTL-021 (Databus Routing
// Engine) can also commit a sensor update. ARCH-002's own 16-port catalog
// for RTL-010 gives this module NO port at all for a routed update (RTL-021
// does not exist yet, and -- unlike event_condition_enable_i/
// irq_condition_enable_i, which are real ports simply tied to a disclosed
// stub -- there is no port here to tie off in the first place). This module
// therefore implements ONLY the real, real-port host-commit half of
// ARCH-MON-007/VP-MON-007: SENSOR_UPDATE_SELECT/_VALUE/_META/_COMMIT always
// wins by construction, because nothing else can ever compete for the same
// cycle. No routed-commit input is invented (CHTR-DOC-006) -- when RTL-021
// is implemented, ARCH-002 will need a real port added to RTL-010's own
// catalog before the "host wins a same-cycle conflict" half of
// VP-MON-007 can be genuinely exercised end-to-end.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (ARCH-MOD-010, ARCH-MON-006/007,
// ARCH-RTL010-001, ARCH-VAL-010, Appendix F.3 index 9, Appendix C.7 event
// 0x0033):
//
//   - TWO FULLY INDEPENDENT CHANNELS (dfc_rtl010_control_t/status_t each
//     carry a complete, separate sensor0_*/sensor1_* field set): every
//     register/latch below is duplicated verbatim as two separate signal
//     groups (ch0_*/ch1_* prefixes), sharing only the module-wide SENSOR_
//     CONTROL enables, the SENSOR_UPDATE_* staging registers (one shared
//     staging area, per REG-002's own single set of these four registers),
//     and the single shared ms-tick generator and event-log pending slot.
//   - LAYERED ENABLE GATING, derived directly from Appendix F.3's own
//     preamble formula (`evt_request = mandatory_event | (GLOBAL_EVENT_
//     ENABLE & MODULE_EVENT_ENABLE & |(EVENT_CONDITION & EVENT_MASK))`,
//     "for per-channel master enables, the corresponding channel master
//     REPLACES MODULE_*_ENABLE"): `active` (= SENSOR_CONTROL.ENABLE &&
//     module_enable_i) gates whether this module does ANY processing at
//     all (commit acceptance, age tick, threshold evaluation -- same
//     "disabled module contributes no degraded/fault request" reading
//     already established for RTL-006 onward). SENSOR_CONTROL.EVENT_ENABLE/
//     IRQ_ENABLE (module-wide) are the MODULE_EVENT_ENABLE/MODULE_IRQ_ENABLE
//     terms for the two MODULE-WIDE F.3 conditions that have no channel
//     master (bit 16 update-accepted, bit 17 update-rejected).
//     SENSORn_EVENT_IRQ_CFG.EVENT_ENABLE[3:0]/IRQ_ENABLE[3:0] (four
//     independent bits, ARCH-MON-007's own explicit text: "low, high,
//     stale, and invalid are four independent event/interrupt mask bits
//     [0]-[3]") are each channel's own master enable, and per the preamble's
//     literal "replaces" wording they REPLACE (not AND with)
//     SENSOR_CONTROL.EVENT_ENABLE/IRQ_ENABLE for their own four F.3 bits.
//   - COMMIT ACCEPT/REJECT, a disclosed reading of REG-2314's own generic
//     WO-CMD boilerplate ("unmet precondition ... rejects") plus
//     ARCH-VAL-010's "commit requires all staged update members": the
//     precondition is `active` (the module must be enabled for a commit to
//     take effect); "all staged update members" is read as describing the
//     commit's ATOMICITY (value/valid/source/sequence/age=0 all replace
//     together, never partially -- exactly ARCH-MON-007's own text), not an
//     additional "has been staged" completeness check (no such tracking
//     field exists anywhere in the real register set, and inventing one
//     would violate CHTR-DOC-006). SOURCE (0-127) and SEQUENCE (0-0xFFFFFF)
//     are structurally legal by field width alone, same "no separate check
//     needed" precedent as every PPR-width-based ARCH-VAL-00N clause before
//     this one.
//   - CONTINUOUS THRESHOLD EVALUATION, not commit-gated: unlike RTL-007/
//     008/009 (whose measured value only ever changes at a divider APPLY
//     cycle, so threshold eval is naturally gated on that same pulse),
//     RTL-010's THRESH_LOW/THRESH_HIGH/HYSTERESIS are plain RW registers a
//     host can change at any time independent of a value commit.
//     ARCH-RTL010-001's fixed pipeline order ("host commit precedes routed
//     commit, then age tick, then threshold evaluation, then evidence
//     clear") is read as running EVERY active cycle, not only on a commit
//     cycle -- a value held steady across a live THRESH_HIGH/LOW/HYSTERESIS
//     change is re-evaluated the very next cycle, matching ARCH-MON-006's
//     own live "enters at / exits at" wording rather than a commit-latched
//     snapshot.
//   - RECOVERY SHARES ITS OWN CONDITION'S BIT, a disclosed interpretation
//     forced by a real, confirmed F.3 asymmetry: RTL-007/008/009's own F.3
//     rows give "recovery" its OWN condition-mask bit, separate from "low"/
//     "high". RTL-010's F.3 row (index 9) does NOT -- it lists only "0-3
//     sensor 0 low/high/stale/invalid; 8-11 sensor 1 ... ; 16 update
//     accepted; 17 update rejected; 18 event-slot overflow", with no
//     standalone recovery bit at all, even though Appendix C.7's own 0x0033
//     event-subtype row lists "5 recovery" as a distinct subtype. Since no
//     field exists to attach a separate recovery-enable meaning to
//     (inventing one would violate CHTR-DOC-006), each condition's own
//     mask bit (SENSORn_EVENT_IRQ_CFG.EVENT_ENABLE/IRQ_ENABLE[i],
//     event_condition_enable_i/irq_condition_enable_i[F3 bit]) gates BOTH
//     that condition's entry (LOW/HIGH/STALE/INVALID) and its own exit
//     (packed as the shared RECOVERY subtype) -- e.g. the "low" bit gates
//     both entering AND leaving the low condition for that channel.
//   - PER-CHANNEL EVENT STICKY BIT (SENSORn_STATUS.EVENT, W1C): set
//     whenever any of that channel's four live status bits (VALID/STALE/
//     LOW/HIGH) actually changes value this cycle (either direction),
//     matching REG-002's own text for this register ("Channel N validity,
//     stale, thresholds, and event evidence") -- a generic "this channel's
//     live status changed" latch, distinct from the module-wide UPDATED/
//     UPDATE_REJECTED bits (which track commit outcomes specifically, not
//     threshold-state changes) and distinct from the shared 0x0033 event
//     LOG stream (a diagnostic aid layered on top, same non-redundant-
//     layers relationship RTL-005/007/008/009 already established between
//     their own event stream and real status registers).
//   - EVENT/IRQ SUBTYPE PACKING (0x0033, C.7: "0 low, 1 high, 2 stale, 3
//     invalid, 4 updated, 5 recovery, 6 rejected | source and sequence low
//     bits"): event_data[15:0] = {sequence[8:0], source[6:0]} (16 bits
//     exactly -- 9+7 -- of the relevant commit's/channel's real 7-bit
//     source and 24-bit sequence, narrowed per C.7's own explicit
//     "sequence low bits" text, dfc_event_record_t's event_data field
//     being only 32 bits wide), event_data[23:16] = subtype,
//     event_data[31:24] reserved zero -- same low-16/subtype-at-16..23/
//     reserved-24..31 convention RTL-007/008/009 already established. For
//     a channel's own low/high/stale/invalid/recovery candidate, source/
//     sequence are that channel's own (possibly just-committed-this-cycle)
//     meta. For the module-wide "accepted" candidate, source/sequence are
//     the just-accepted channel's new meta. For "rejected", source/
//     sequence are the STAGED (never-committed) meta -- the only real data
//     available for a rejected commit.
//   - RESOLVED WITHOUT AN ARCH-002 EDIT, same resolution style as
//     OPEN_ISSUES.md items 1/10/11/13/19/22: RTL-010_RevA.md SS1 describes
//     Appendix F.3 index 9 as "0-3 sensor 0 low/high/stale/invalid, and by
//     the documented pattern 4-7 sensor 1 same order, 8 event-slot
//     overflow" -- ARCH-002's own real F.3 table (the owning document,
//     CHTR-DOC-003) instead gives "0-3 sensor 0 ...; 8-11 sensor 1 ...; 16
//     update accepted; 17 update rejected; 18 event-slot overflow".
//     Resolved in favor of ARCH-002; this file's CH1_COND_BASE/
//     UPDATE_ACCEPTED_BIT/UPDATE_REJECTED_BIT/OVERFLOW_BIT localparams
//     below implement ARCH-002's real layout, not RTL-010_RevA.md's own
//     restated (and here, wrong) summary of it.
//   - SHARED-SLOT EVENT ARBITRATION (one evt_valid_o/evt_ready_i/
//     evt_record_o triple total, per the Architecture port catalog):
//     four top-level candidates can coincide the same cycle (module-wide
//     reject, channel 0's own transition, channel 1's own transition,
//     module-wide accept -- reject and accept are mutually exclusive by
//     construction, since one COMMIT pulse is either accepted or rejected,
//     never both). DISCLOSED, locally-chosen priority (no spec guidance on
//     cross-condition priority exists, same class of disclosed choice as
//     RTL-007/008/009's own in-channel subtype priority): reject > channel
//     0 > channel 1 > accept -- channel 0 wins channel-vs-channel ties,
//     same convention RTL-009 already established; the module-wide
//     "rejected" alarm outranks everything (matching RTL-007/008's own
//     "configuration reject" being their highest-priority subtype), and the
//     module-wide plain "accepted" notification is lowest priority
//     (matching RTL-007/008/009's own plain "updated" always being their
//     lowest-priority subtype). Any candidate not captured this cycle
//     (lost to a higher-priority candidate this same cycle, or because the
//     one pending slot was already occupied) is counted as a genuine loss
//     -- `event_drop_count_q` increments by the actual count of losses
//     this cycle (0-3, since reject/accept cannot both be true), same
//     real, disclosed generalization RTL-009 already established for its
//     own two-producer shared slot.
//   - READY/FAULT: `ready = !ch0_illegal_config && !ch1_illegal_config`.
//     `fault`/`fault_req_o` = live `ch0_illegal_config || ch1_illegal_config`
//     -- same "active condition plus RTL-013 sticky evidence" matrix text
//     as every prior Monitoring module (RTL-013 does not exist yet;
//     `fault_req_o` is left genuinely unconsumed in dfc_rtl024.sv, same
//     disclosed pattern as RTL-005/007/008/009's own `fault_req_o`). No
//     timeout-style fault condition exists for this module (RTL-010 has no
//     timeout field anywhere in its real register set) -- illegal
//     configuration is the only fault source.
//   - ILLEGAL CONFIGURATION (ARCH-VAL-010): `signed(LOW) <= signed(HIGH)`;
//     hysteresis nonnegative; hysteresis <= (HIGH-LOW) computed in a
//     64-bit sign-extended intermediate so the check itself can never
//     overflow (same "widen, compute, clamp/compare" discipline this
//     project already uses for RTL-007/008/009's own saturating
//     arithmetic) -- all directly checkable against this module's real
//     fields, gated on `active` (a disabled/unconfigured channel does not
//     count against readiness), same "defend against what RTL-001 doesn't
//     yet reject" precedent already established project-wide
//     (OPEN_ISSUES.md item 4).
//   - SIGNED SATURATING BOUND ARITHMETIC (ARCH-MON-006: "signed bound
//     arithmetic saturates"): the low-exit bound (LOW + HYST) and
//     high-exit bound (HIGH - HYST) are each computed in a 33-bit signed
//     intermediate (one guard bit beyond the 32-bit operands, sufficient
//     since both operands are already width-limited to 32 bits) and
//     clamped to [INT32_MIN, INT32_MAX] before use -- the first genuinely
//     SIGNED comparison/saturation in this project (RTL-007/008/009's own
//     saturating arithmetic is all unsigned); `$signed()` casts are
//     ordinary IEEE-1800 syntax with no toolchain finding against them
//     anywhere in PROJECT_CONTINUITY.md Section 2, unlike the
//     package-scoped-type patterns that are genuinely broken on this
//     toolchain.
//   - `module_enable_i` is a SINGLE, module-wide port (RTL-002.
//     module_enable_o[9] -- confirmed against the real 16-port catalog,
//     there is no per-channel enable port, no `effective_operational_
//     enable_i` port either, matching RTL-007/008/009's identical port
//     shape). `operating_state_i`/`observational_mode_i` are real,
//     structurally-required ports with no functional use in this
//     implementation, same disclosed-no-use precedent already established
//     for these ports on dfc_rtl003/005/007/008/009.sv -- sunk via the
//     unused-port sink below.
// ============================================================================

module dfc_rtl010 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[9]

  // TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
  // Yosys build -- see dfc_rtl002.sv's header for the full account): a
  // package-scoped type cannot be a port's declared type. Every such port
  // here is a plain `logic [W-1:0]` vector sized via generated
  // `dfc_types_pkg::DFC_*_WIDTH` VALUE constants instead.
  input  logic [dfc_types_pkg::DFC_RTL010_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL010_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,
  output logic         fault_req_o,      // RTL-013.fault_source_i[9] -- no
                                          // real consumer yet, RTL-013 does
                                          // not exist. Left genuinely
                                          // unconsumed in dfc_rtl024.sv.

  // NO PHYSICAL SENSOR PIN -- see header. Sensor values arrive exclusively
  // through control_i's staged SENSOR_UPDATE_* fields below.

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic         module_enable_i,           // RTL-002.module_enable_o[9]

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 9
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 9
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as every module from RTL-003
  // onward) ----
  wire ctl_sensor_enable       = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_CONTROL__ENABLE_HI];
  wire ctl_sensor_event_enable = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_CONTROL__EVENT_ENABLE_HI];
  wire ctl_sensor_irq_enable   = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_CONTROL__IRQ_ENABLE_HI];
  wire ctl_clear_update_rejected = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_STATUS__UPDATE_REJECTED_HI];
  wire ctl_clear_updated         = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_STATUS__UPDATED_HI];

  wire        ctl_sel_channel = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_SELECT__CHANNEL_HI];
  wire [31:0] ctl_staged_value = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_VALUE__VALUE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_VALUE__VALUE_LO];
  wire        ctl_staged_valid = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_META__VALID_HI];
  wire [6:0]  ctl_staged_source = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_META__SOURCE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_META__SOURCE_LO];
  wire [23:0] ctl_staged_sequence = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_META__SEQUENCE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_META__SEQUENCE_LO];
  wire        ctl_commit_pulse = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR_UPDATE_COMMIT__COMMIT_HI];

  wire        ctl0_clear_event = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_STATUS__EVENT_HI];
  wire [31:0] ctl0_max_age_ms  = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_MAX_AGE_MS__MAX_AGE_MS_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_MAX_AGE_MS__MAX_AGE_MS_LO];
  wire [31:0] ctl0_thresh_low  = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_THRESH_LOW__THRESHOLD_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_THRESH_LOW__THRESHOLD_LO];
  wire [31:0] ctl0_thresh_high = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_THRESH_HIGH__THRESHOLD_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_THRESH_HIGH__THRESHOLD_LO];
  wire [3:0]  ctl0_event_enable = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_EVENT_IRQ_CFG__EVENT_ENABLE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_EVENT_IRQ_CFG__EVENT_ENABLE_LO];
  wire [3:0]  ctl0_irq_enable   = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_EVENT_IRQ_CFG__IRQ_ENABLE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_EVENT_IRQ_CFG__IRQ_ENABLE_LO];
  wire [31:0] ctl0_hysteresis  = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_HYSTERESIS__HYSTERESIS_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR0_HYSTERESIS__HYSTERESIS_LO];

  wire        ctl1_clear_event = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_STATUS__EVENT_HI];
  wire [31:0] ctl1_max_age_ms  = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_MAX_AGE_MS__MAX_AGE_MS_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_MAX_AGE_MS__MAX_AGE_MS_LO];
  wire [31:0] ctl1_thresh_low  = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_THRESH_LOW__THRESHOLD_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_THRESH_LOW__THRESHOLD_LO];
  wire [31:0] ctl1_thresh_high = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_THRESH_HIGH__THRESHOLD_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_THRESH_HIGH__THRESHOLD_LO];
  wire [3:0]  ctl1_event_enable = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_EVENT_IRQ_CFG__EVENT_ENABLE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_EVENT_IRQ_CFG__EVENT_ENABLE_LO];
  wire [3:0]  ctl1_irq_enable   = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_EVENT_IRQ_CFG__IRQ_ENABLE_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_EVENT_IRQ_CFG__IRQ_ENABLE_LO];
  wire [31:0] ctl1_hysteresis  = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_HYSTERESIS__HYSTERESIS_HI:dfc_types_pkg::DFC_RTL010_CONTROL__SENSOR1_HYSTERESIS__HYSTERESIS_LO];

  wire ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL010_CONTROL__RTL010_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire active = ctl_sensor_enable && module_enable_i;

  // ==========================================================================
  // Shared 1 ms tick generator (ARCH-MON-007: "age increments every 1 ms
  // tick"). Free-running once out of reset -- independent of `active`, same
  // "the underlying divider clock keeps ticking" idiom as every other
  // module's own free-running phase counter; the per-channel age register
  // itself gates on `active`, not this generator.
  // ==========================================================================
  localparam int unsigned MS_TICK_CYCLES = 50_000;  // nominal 50 MHz CORE_CLK, ARCH-CLK-001
  logic [15:0] ms_phase_q;
  wire         ms_tick = (ms_phase_q == MS_TICK_CYCLES-1);
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)         ms_phase_q <= 16'd0;
    else if (module_reset_i)   ms_phase_q <= 16'd0;
    else if (ms_tick)          ms_phase_q <= 16'd0;
    else                       ms_phase_q <= ms_phase_q + 16'd1;
  end

  // ==========================================================================
  // Commit acceptance/rejection -- module-wide, ARCH-MON-007 + REG-2314's
  // own boilerplate (see header for the disclosed accept/reject reading).
  // ==========================================================================
  wire commit_accepted = ctl_commit_pulse && active;
  wire commit_rejected = ctl_commit_pulse && !active;
  wire ch0_commit_this_cycle = commit_accepted && !ctl_sel_channel;
  wire ch1_commit_this_cycle = commit_accepted &&  ctl_sel_channel;

  // ==========================================================================
  // CHANNEL 0
  // ==========================================================================
  logic [31:0] ch0_value_q;
  logic        ch0_valid_q;
  logic [6:0]  ch0_source_q;
  logic [23:0] ch0_sequence_q;
  logic [31:0] ch0_age_ms_q;
  logic        ch0_low_q, ch0_high_q, ch0_stale_q;
  logic        ch0_event_sticky_q;

  wire [31:0] ch0_value_next = ch0_commit_this_cycle ? ctl_staged_value : ch0_value_q;
  wire        ch0_valid_next = ch0_commit_this_cycle ? ctl_staged_valid : ch0_valid_q;
  wire [6:0]  ch0_source_next   = ch0_commit_this_cycle ? ctl_staged_source   : ch0_source_q;
  wire [23:0] ch0_sequence_next = ch0_commit_this_cycle ? ctl_staged_sequence : ch0_sequence_q;
  wire [31:0] ch0_age_next = ch0_commit_this_cycle ? 32'd0 :
                             (active && ms_tick && (ch0_age_ms_q != 32'hFFFFFFFF)) ? (ch0_age_ms_q + 32'd1) :
                             ch0_age_ms_q;
  wire        ch0_stale_next = (ctl0_max_age_ms != 32'd0) && (ch0_age_next > ctl0_max_age_ms);

  wire signed [32:0] ch0_low_exit_sum  = {ctl0_thresh_low[31], ctl0_thresh_low} + {ctl0_hysteresis[31], ctl0_hysteresis};
  wire [31:0] ch0_low_exit_bound  = (ch0_low_exit_sum > 33'sd2147483647) ? 32'h7FFFFFFF :
                                     (ch0_low_exit_sum < -33'sd2147483648) ? 32'h80000000 : ch0_low_exit_sum[31:0];
  wire signed [32:0] ch0_high_exit_diff = {ctl0_thresh_high[31], ctl0_thresh_high} - {ctl0_hysteresis[31], ctl0_hysteresis};
  wire [31:0] ch0_high_exit_bound = (ch0_high_exit_diff > 33'sd2147483647) ? 32'h7FFFFFFF :
                                     (ch0_high_exit_diff < -33'sd2147483648) ? 32'h80000000 : ch0_high_exit_diff[31:0];

  wire ch0_low_enter_test  = !ch0_low_q  && ($signed(ch0_value_next) <  $signed(ctl0_thresh_low));
  wire ch0_low_exit_test   =  ch0_low_q  && ($signed(ch0_value_next) >= $signed(ch0_low_exit_bound));
  wire ch0_high_enter_test = !ch0_high_q && ($signed(ch0_value_next) >  $signed(ctl0_thresh_high));
  wire ch0_high_exit_test  =  ch0_high_q && ($signed(ch0_value_next) <= $signed(ch0_high_exit_bound));
  wire ch0_stale_enter_test   = !ch0_stale_q &&  ch0_stale_next;
  wire ch0_stale_exit_test    =  ch0_stale_q && !ch0_stale_next;
  wire ch0_invalid_enter_test =  ch0_valid_q && !ch0_valid_next;
  wire ch0_invalid_exit_test  = !ch0_valid_q &&  ch0_valid_next;

  wire ch0_any_transition = ch0_low_enter_test || ch0_low_exit_test ||
                             ch0_high_enter_test || ch0_high_exit_test ||
                             ch0_stale_enter_test || ch0_stale_exit_test ||
                             ch0_invalid_enter_test || ch0_invalid_exit_test;

  // ---- illegal configuration (ARCH-VAL-010), live, not sticky ----
  wire signed [63:0] ch0_range_ext = {{32{ctl0_thresh_high[31]}}, ctl0_thresh_high} -
                                      {{32{ctl0_thresh_low[31]}},  ctl0_thresh_low};
  wire signed [63:0] ch0_hyst_ext  = {{32{ctl0_hysteresis[31]}}, ctl0_hysteresis};
  wire ch0_illegal_config = active && (
    ($signed(ctl0_thresh_low) > $signed(ctl0_thresh_high)) ||
    (ch0_hyst_ext < 64'sd0) ||
    (ch0_hyst_ext > ch0_range_ext)
  );

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch0_value_q        <= 32'd0;
      ch0_valid_q        <= 1'b0;
      ch0_source_q       <= 7'd0;
      ch0_sequence_q     <= 24'd0;
      ch0_age_ms_q       <= 32'd0;
      ch0_low_q          <= 1'b0;
      ch0_high_q         <= 1'b0;
      ch0_stale_q        <= 1'b0;
      ch0_event_sticky_q <= 1'b0;
    end else if (module_reset_i || !active) begin
      ch0_value_q        <= 32'd0;
      ch0_valid_q        <= 1'b0;
      ch0_source_q       <= 7'd0;
      ch0_sequence_q     <= 24'd0;
      ch0_age_ms_q       <= 32'd0;
      ch0_low_q          <= 1'b0;
      ch0_high_q         <= 1'b0;
      ch0_stale_q        <= 1'b0;
      ch0_event_sticky_q <= 1'b0;
    end else begin
      ch0_value_q    <= ch0_value_next;
      ch0_valid_q    <= ch0_valid_next;
      ch0_source_q   <= ch0_source_next;
      ch0_sequence_q <= ch0_sequence_next;
      ch0_age_ms_q   <= ch0_age_next;
      ch0_stale_q    <= ch0_stale_next;
      if (ch0_low_enter_test)       ch0_low_q  <= 1'b1;
      else if (ch0_low_exit_test)   ch0_low_q  <= 1'b0;
      if (ch0_high_enter_test)      ch0_high_q <= 1'b1;
      else if (ch0_high_exit_test)  ch0_high_q <= 1'b0;

      if (ch0_any_transition) ch0_event_sticky_q <= 1'b1;
      else if (ctl0_clear_event && !ch0_any_transition) ch0_event_sticky_q <= 1'b0;
    end
  end

  // ==========================================================================
  // CHANNEL 1 -- structurally identical to channel 0 above, entirely
  // independent state, fed from the shared staging registers gated by
  // ctl_sel_channel==1.
  // ==========================================================================
  logic [31:0] ch1_value_q;
  logic        ch1_valid_q;
  logic [6:0]  ch1_source_q;
  logic [23:0] ch1_sequence_q;
  logic [31:0] ch1_age_ms_q;
  logic        ch1_low_q, ch1_high_q, ch1_stale_q;
  logic        ch1_event_sticky_q;

  wire [31:0] ch1_value_next = ch1_commit_this_cycle ? ctl_staged_value : ch1_value_q;
  wire        ch1_valid_next = ch1_commit_this_cycle ? ctl_staged_valid : ch1_valid_q;
  wire [6:0]  ch1_source_next   = ch1_commit_this_cycle ? ctl_staged_source   : ch1_source_q;
  wire [23:0] ch1_sequence_next = ch1_commit_this_cycle ? ctl_staged_sequence : ch1_sequence_q;
  wire [31:0] ch1_age_next = ch1_commit_this_cycle ? 32'd0 :
                             (active && ms_tick && (ch1_age_ms_q != 32'hFFFFFFFF)) ? (ch1_age_ms_q + 32'd1) :
                             ch1_age_ms_q;
  wire        ch1_stale_next = (ctl1_max_age_ms != 32'd0) && (ch1_age_next > ctl1_max_age_ms);

  wire signed [32:0] ch1_low_exit_sum  = {ctl1_thresh_low[31], ctl1_thresh_low} + {ctl1_hysteresis[31], ctl1_hysteresis};
  wire [31:0] ch1_low_exit_bound  = (ch1_low_exit_sum > 33'sd2147483647) ? 32'h7FFFFFFF :
                                     (ch1_low_exit_sum < -33'sd2147483648) ? 32'h80000000 : ch1_low_exit_sum[31:0];
  wire signed [32:0] ch1_high_exit_diff = {ctl1_thresh_high[31], ctl1_thresh_high} - {ctl1_hysteresis[31], ctl1_hysteresis};
  wire [31:0] ch1_high_exit_bound = (ch1_high_exit_diff > 33'sd2147483647) ? 32'h7FFFFFFF :
                                     (ch1_high_exit_diff < -33'sd2147483648) ? 32'h80000000 : ch1_high_exit_diff[31:0];

  wire ch1_low_enter_test  = !ch1_low_q  && ($signed(ch1_value_next) <  $signed(ctl1_thresh_low));
  wire ch1_low_exit_test   =  ch1_low_q  && ($signed(ch1_value_next) >= $signed(ch1_low_exit_bound));
  wire ch1_high_enter_test = !ch1_high_q && ($signed(ch1_value_next) >  $signed(ctl1_thresh_high));
  wire ch1_high_exit_test  =  ch1_high_q && ($signed(ch1_value_next) <= $signed(ch1_high_exit_bound));
  wire ch1_stale_enter_test   = !ch1_stale_q &&  ch1_stale_next;
  wire ch1_stale_exit_test    =  ch1_stale_q && !ch1_stale_next;
  wire ch1_invalid_enter_test =  ch1_valid_q && !ch1_valid_next;
  wire ch1_invalid_exit_test  = !ch1_valid_q &&  ch1_valid_next;

  wire ch1_any_transition = ch1_low_enter_test || ch1_low_exit_test ||
                             ch1_high_enter_test || ch1_high_exit_test ||
                             ch1_stale_enter_test || ch1_stale_exit_test ||
                             ch1_invalid_enter_test || ch1_invalid_exit_test;

  wire signed [63:0] ch1_range_ext = {{32{ctl1_thresh_high[31]}}, ctl1_thresh_high} -
                                      {{32{ctl1_thresh_low[31]}},  ctl1_thresh_low};
  wire signed [63:0] ch1_hyst_ext  = {{32{ctl1_hysteresis[31]}}, ctl1_hysteresis};
  wire ch1_illegal_config = active && (
    ($signed(ctl1_thresh_low) > $signed(ctl1_thresh_high)) ||
    (ch1_hyst_ext < 64'sd0) ||
    (ch1_hyst_ext > ch1_range_ext)
  );

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ch1_value_q        <= 32'd0;
      ch1_valid_q        <= 1'b0;
      ch1_source_q       <= 7'd0;
      ch1_sequence_q     <= 24'd0;
      ch1_age_ms_q       <= 32'd0;
      ch1_low_q          <= 1'b0;
      ch1_high_q         <= 1'b0;
      ch1_stale_q        <= 1'b0;
      ch1_event_sticky_q <= 1'b0;
    end else if (module_reset_i || !active) begin
      ch1_value_q        <= 32'd0;
      ch1_valid_q        <= 1'b0;
      ch1_source_q       <= 7'd0;
      ch1_sequence_q     <= 24'd0;
      ch1_age_ms_q       <= 32'd0;
      ch1_low_q          <= 1'b0;
      ch1_high_q         <= 1'b0;
      ch1_stale_q        <= 1'b0;
      ch1_event_sticky_q <= 1'b0;
    end else begin
      ch1_value_q    <= ch1_value_next;
      ch1_valid_q    <= ch1_valid_next;
      ch1_source_q   <= ch1_source_next;
      ch1_sequence_q <= ch1_sequence_next;
      ch1_age_ms_q   <= ch1_age_next;
      ch1_stale_q    <= ch1_stale_next;
      if (ch1_low_enter_test)       ch1_low_q  <= 1'b1;
      else if (ch1_low_exit_test)   ch1_low_q  <= 1'b0;
      if (ch1_high_enter_test)      ch1_high_q <= 1'b1;
      else if (ch1_high_exit_test)  ch1_high_q <= 1'b0;

      if (ch1_any_transition) ch1_event_sticky_q <= 1'b1;
      else if (ctl1_clear_event && !ch1_any_transition) ch1_event_sticky_q <= 1'b0;
    end
  end

  // ==========================================================================
  // Module-wide UPDATED/UPDATE_REJECTED sticky evidence (SENSOR_STATUS,
  // W1C) -- track commit OUTCOME, distinct from either channel's own
  // threshold-state EVENT sticky bit above.
  // ==========================================================================
  logic sensor_updated_sticky_q, sensor_update_rejected_sticky_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      sensor_updated_sticky_q         <= 1'b0;
      sensor_update_rejected_sticky_q <= 1'b0;
    end else if (module_reset_i) begin
      sensor_updated_sticky_q         <= 1'b0;
      sensor_update_rejected_sticky_q <= 1'b0;
    end else begin
      if (commit_accepted) sensor_updated_sticky_q <= 1'b1;
      else if (ctl_clear_updated && !commit_accepted) sensor_updated_sticky_q <= 1'b0;

      if (commit_rejected) sensor_update_rejected_sticky_q <= 1'b1;
      else if (ctl_clear_update_rejected && !commit_rejected) sensor_update_rejected_sticky_q <= 1'b0;
    end
  end

  wire any_invalid = !ch0_valid_q || !ch1_valid_q;
  wire any_stale   = ch0_stale_q  || ch1_stale_q;
  wire any_low     = ch0_low_q    || ch1_low_q;
  wire any_high    = ch0_high_q   || ch1_high_q;

  // ==========================================================================
  // Event/IRQ condition gating (Appendix F.3 index 9 -- see header for the
  // resolved-in-favor-of-ARCH-002 bit layout and the layered-enable
  // derivation).
  // ==========================================================================
  localparam int unsigned CH0_COND_BASE = 0;   // low/high/stale/invalid
  localparam int unsigned CH1_COND_BASE = 8;   // low/high/stale/invalid
  localparam int unsigned UPDATE_ACCEPTED_BIT = 16;
  localparam int unsigned UPDATE_REJECTED_BIT = 17;

  wire ev0_low_enter  = ch0_low_enter_test  & ctl0_event_enable[0] & event_condition_enable_i[CH0_COND_BASE+0];
  wire ev0_low_exit   = ch0_low_exit_test   & ctl0_event_enable[0] & event_condition_enable_i[CH0_COND_BASE+0];
  wire ev0_high_enter = ch0_high_enter_test & ctl0_event_enable[1] & event_condition_enable_i[CH0_COND_BASE+1];
  wire ev0_high_exit  = ch0_high_exit_test  & ctl0_event_enable[1] & event_condition_enable_i[CH0_COND_BASE+1];
  wire ev0_stale_enter   = ch0_stale_enter_test   & ctl0_event_enable[2] & event_condition_enable_i[CH0_COND_BASE+2];
  wire ev0_stale_exit    = ch0_stale_exit_test    & ctl0_event_enable[2] & event_condition_enable_i[CH0_COND_BASE+2];
  wire ev0_invalid_enter = ch0_invalid_enter_test & ctl0_event_enable[3] & event_condition_enable_i[CH0_COND_BASE+3];
  wire ev0_invalid_exit  = ch0_invalid_exit_test  & ctl0_event_enable[3] & event_condition_enable_i[CH0_COND_BASE+3];
  wire ch0_evt_candidate_valid = ev0_low_enter | ev0_low_exit | ev0_high_enter | ev0_high_exit |
                                  ev0_stale_enter | ev0_stale_exit | ev0_invalid_enter | ev0_invalid_exit;

  wire iq0_low_enter  = ch0_low_enter_test  & ctl0_irq_enable[0] & irq_condition_enable_i[CH0_COND_BASE+0];
  wire iq0_low_exit   = ch0_low_exit_test   & ctl0_irq_enable[0] & irq_condition_enable_i[CH0_COND_BASE+0];
  wire iq0_high_enter = ch0_high_enter_test & ctl0_irq_enable[1] & irq_condition_enable_i[CH0_COND_BASE+1];
  wire iq0_high_exit  = ch0_high_exit_test  & ctl0_irq_enable[1] & irq_condition_enable_i[CH0_COND_BASE+1];
  wire iq0_stale_enter   = ch0_stale_enter_test   & ctl0_irq_enable[2] & irq_condition_enable_i[CH0_COND_BASE+2];
  wire iq0_stale_exit    = ch0_stale_exit_test    & ctl0_irq_enable[2] & irq_condition_enable_i[CH0_COND_BASE+2];
  wire iq0_invalid_enter = ch0_invalid_enter_test & ctl0_irq_enable[3] & irq_condition_enable_i[CH0_COND_BASE+3];
  wire iq0_invalid_exit  = ch0_invalid_exit_test  & ctl0_irq_enable[3] & irq_condition_enable_i[CH0_COND_BASE+3];

  wire ev1_low_enter  = ch1_low_enter_test  & ctl1_event_enable[0] & event_condition_enable_i[CH1_COND_BASE+0];
  wire ev1_low_exit   = ch1_low_exit_test   & ctl1_event_enable[0] & event_condition_enable_i[CH1_COND_BASE+0];
  wire ev1_high_enter = ch1_high_enter_test & ctl1_event_enable[1] & event_condition_enable_i[CH1_COND_BASE+1];
  wire ev1_high_exit  = ch1_high_exit_test  & ctl1_event_enable[1] & event_condition_enable_i[CH1_COND_BASE+1];
  wire ev1_stale_enter   = ch1_stale_enter_test   & ctl1_event_enable[2] & event_condition_enable_i[CH1_COND_BASE+2];
  wire ev1_stale_exit    = ch1_stale_exit_test    & ctl1_event_enable[2] & event_condition_enable_i[CH1_COND_BASE+2];
  wire ev1_invalid_enter = ch1_invalid_enter_test & ctl1_event_enable[3] & event_condition_enable_i[CH1_COND_BASE+3];
  wire ev1_invalid_exit  = ch1_invalid_exit_test  & ctl1_event_enable[3] & event_condition_enable_i[CH1_COND_BASE+3];
  wire ch1_evt_candidate_valid = ev1_low_enter | ev1_low_exit | ev1_high_enter | ev1_high_exit |
                                  ev1_stale_enter | ev1_stale_exit | ev1_invalid_enter | ev1_invalid_exit;

  wire iq1_low_enter  = ch1_low_enter_test  & ctl1_irq_enable[0] & irq_condition_enable_i[CH1_COND_BASE+0];
  wire iq1_low_exit   = ch1_low_exit_test   & ctl1_irq_enable[0] & irq_condition_enable_i[CH1_COND_BASE+0];
  wire iq1_high_enter = ch1_high_enter_test & ctl1_irq_enable[1] & irq_condition_enable_i[CH1_COND_BASE+1];
  wire iq1_high_exit  = ch1_high_exit_test  & ctl1_irq_enable[1] & irq_condition_enable_i[CH1_COND_BASE+1];
  wire iq1_stale_enter   = ch1_stale_enter_test   & ctl1_irq_enable[2] & irq_condition_enable_i[CH1_COND_BASE+2];
  wire iq1_stale_exit    = ch1_stale_exit_test    & ctl1_irq_enable[2] & irq_condition_enable_i[CH1_COND_BASE+2];
  wire iq1_invalid_enter = ch1_invalid_enter_test & ctl1_irq_enable[3] & irq_condition_enable_i[CH1_COND_BASE+3];
  wire iq1_invalid_exit  = ch1_invalid_exit_test  & ctl1_irq_enable[3] & irq_condition_enable_i[CH1_COND_BASE+3];

  wire ev_gate_accepted = commit_accepted & ctl_sensor_event_enable & event_condition_enable_i[UPDATE_ACCEPTED_BIT];
  wire ev_gate_rejected = commit_rejected & ctl_sensor_event_enable & event_condition_enable_i[UPDATE_REJECTED_BIT];
  wire iq_gate_accepted = commit_accepted & ctl_sensor_irq_enable   & irq_condition_enable_i[UPDATE_ACCEPTED_BIT];
  wire iq_gate_rejected = commit_rejected & ctl_sensor_irq_enable   & irq_condition_enable_i[UPDATE_REJECTED_BIT];

  assign irq_req_o = iq0_low_enter | iq0_low_exit | iq0_high_enter | iq0_high_exit |
                      iq0_stale_enter | iq0_stale_exit | iq0_invalid_enter | iq0_invalid_exit |
                      iq1_low_enter | iq1_low_exit | iq1_high_enter | iq1_high_exit |
                      iq1_stale_enter | iq1_stale_exit | iq1_invalid_enter | iq1_invalid_exit |
                      iq_gate_accepted | iq_gate_rejected;

  // ==========================================================================
  // Event subtype selection + event_data packing (0x0033, see header for
  // the exact packing convention and cross-candidate priority).
  // ==========================================================================
  localparam logic [7:0] EVT_SUBTYPE_LOW      = 8'd0;
  localparam logic [7:0] EVT_SUBTYPE_HIGH     = 8'd1;
  localparam logic [7:0] EVT_SUBTYPE_STALE    = 8'd2;
  localparam logic [7:0] EVT_SUBTYPE_INVALID  = 8'd3;
  localparam logic [7:0] EVT_SUBTYPE_UPDATED  = 8'd4;
  localparam logic [7:0] EVT_SUBTYPE_RECOVERY = 8'd5;
  localparam logic [7:0] EVT_SUBTYPE_REJECTED = 8'd6;
  localparam logic [15:0] EVT_ID_SENSOR = 16'h0033;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL010 = 8'd9;  // ARCH-002 C.5 index 9

  logic [7:0] ch0_evt_subtype_comb;
  always_comb begin
    if (ev0_invalid_enter)     ch0_evt_subtype_comb = EVT_SUBTYPE_INVALID;
    else if (ev0_stale_enter)  ch0_evt_subtype_comb = EVT_SUBTYPE_STALE;
    else if (ev0_low_enter)    ch0_evt_subtype_comb = EVT_SUBTYPE_LOW;
    else if (ev0_high_enter)   ch0_evt_subtype_comb = EVT_SUBTYPE_HIGH;
    else                        ch0_evt_subtype_comb = EVT_SUBTYPE_RECOVERY;  // one of the 4 *_exit gates
  end
  logic [7:0] ch1_evt_subtype_comb;
  always_comb begin
    if (ev1_invalid_enter)     ch1_evt_subtype_comb = EVT_SUBTYPE_INVALID;
    else if (ev1_stale_enter)  ch1_evt_subtype_comb = EVT_SUBTYPE_STALE;
    else if (ev1_low_enter)    ch1_evt_subtype_comb = EVT_SUBTYPE_LOW;
    else if (ev1_high_enter)   ch1_evt_subtype_comb = EVT_SUBTYPE_HIGH;
    else                        ch1_evt_subtype_comb = EVT_SUBTYPE_RECOVERY;
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate_ch0, evt_candidate_ch1,
                                                     evt_candidate_accepted, evt_candidate_rejected;
  always_comb begin
    evt_candidate_ch0 = '0;
    evt_candidate_ch0[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate_ch0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_SENSOR;
    evt_candidate_ch0[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL010;
    evt_candidate_ch0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 9]    = ch0_sequence_next[8:0];
    evt_candidate_ch0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+9 +: 7]  = ch0_source_next;
    evt_candidate_ch0[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = ch0_evt_subtype_comb;
  end
  always_comb begin
    evt_candidate_ch1 = '0;
    evt_candidate_ch1[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate_ch1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_SENSOR;
    evt_candidate_ch1[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL010;
    evt_candidate_ch1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 9]    = ch1_sequence_next[8:0];
    evt_candidate_ch1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+9 +: 7]  = ch1_source_next;
    evt_candidate_ch1[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = ch1_evt_subtype_comb;
  end
  always_comb begin
    evt_candidate_accepted = '0;
    evt_candidate_accepted[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate_accepted[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_SENSOR;
    evt_candidate_accepted[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL010;
    evt_candidate_accepted[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 9]    = ctl_sel_channel ? ch1_sequence_next[8:0] : ch0_sequence_next[8:0];
    evt_candidate_accepted[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+9 +: 7]  = ctl_sel_channel ? ch1_source_next       : ch0_source_next;
    evt_candidate_accepted[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = EVT_SUBTYPE_UPDATED;
  end
  always_comb begin
    evt_candidate_rejected = '0;
    evt_candidate_rejected[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate_rejected[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_SENSOR;
    evt_candidate_rejected[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL010;
    evt_candidate_rejected[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 9]    = ctl_staged_sequence[8:0];
    evt_candidate_rejected[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+9 +: 7]  = ctl_staged_source;
    evt_candidate_rejected[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+16 +: 8] = EVT_SUBTYPE_REJECTED;
  end

  logic                                              evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  evt_record_q;
  logic                                              event_overflow_q;
  logic [15:0]                                       event_drop_count_q;

  // Shared-slot arbitration: reject > channel 0 > channel 1 > accept (see
  // header). Reject and accept can never both be true the same cycle (one
  // COMMIT pulse is either accepted or rejected, never both).
  wire slot_available = !evt_pending_q || (evt_pending_q && evt_ready_i);
  wire capture_rejected = ev_gate_rejected && slot_available;
  wire capture_ch0      = ch0_evt_candidate_valid && slot_available && !ev_gate_rejected;
  wire capture_ch1      = ch1_evt_candidate_valid && slot_available && !ev_gate_rejected && !ch0_evt_candidate_valid;
  wire capture_accepted = ev_gate_accepted && slot_available && !ev_gate_rejected &&
                           !ch0_evt_candidate_valid && !ch1_evt_candidate_valid;

  wire drop_rejected = ev_gate_rejected && !slot_available;
  wire drop_ch0       = ch0_evt_candidate_valid && (!slot_available || ev_gate_rejected);
  wire drop_ch1       = ch1_evt_candidate_valid && (!slot_available || ev_gate_rejected || ch0_evt_candidate_valid);
  wire drop_accepted   = ev_gate_accepted && (!slot_available || ev_gate_rejected ||
                                               ch0_evt_candidate_valid || ch1_evt_candidate_valid);
  wire [2:0] drop_count_this_cycle = {2'b0, drop_rejected} + {2'b0, drop_ch0} + {2'b0, drop_ch1} + {2'b0, drop_accepted};
  wire overflow_sets_this_cycle = (drop_count_this_cycle != 3'd0);

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

      if (capture_rejected) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate_rejected;
      end else if (capture_ch0) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate_ch0;
      end else if (capture_ch1) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate_ch1;
      end else if (capture_accepted) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate_accepted;
      end

      if (drop_count_this_cycle != 3'd0) begin
        event_overflow_q <= 1'b1;
        if (event_drop_count_q <= (16'hFFFF - {13'd0, drop_count_this_cycle}))
          event_drop_count_q <= event_drop_count_q + {13'd0, drop_count_this_cycle};
        else
          event_drop_count_q <= 16'hFFFF;
      end

      // Real host clear-request for RTL010_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
      // (REG-235C) -- new-overflow-evidence-dominates-clear, same priority
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
  wire fault_live = ch0_illegal_config || ch1_illegal_config;
  assign fault_req_o = fault_live;

  // ==========================================================================
  // status_o packing (dfc_rtl010_status_t, 225 bits).
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL010_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__READY_HI] = !ch0_illegal_config && !ch1_illegal_config;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__FAULT_HI] = fault_live;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR_STATUS__ANY_INVALID_HI] = any_invalid;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR_STATUS__ANY_STALE_HI]   = any_stale;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR_STATUS__ANY_LOW_HI]     = any_low;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR_STATUS__ANY_HIGH_HI]    = any_high;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR_STATUS__UPDATE_REJECTED_HI] = sensor_update_rejected_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR_STATUS__UPDATED_HI]         = sensor_updated_sticky_q;

    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_VALUE__VALUE_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_VALUE__VALUE_LO] = ch0_value_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_STATUS__VALID_HI] = ch0_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_STATUS__STALE_HI] = ch0_stale_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_STATUS__LOW_HI]   = ch0_low_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_STATUS__HIGH_HI]  = ch0_high_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_STATUS__EVENT_HI] = ch0_event_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_CURRENT_AGE_MS__CURRENT_AGE_MS_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_CURRENT_AGE_MS__CURRENT_AGE_MS_LO] = ch0_age_ms_q;

    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_VALUE__VALUE_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_VALUE__VALUE_LO] = ch1_value_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_STATUS__VALID_HI] = ch1_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_STATUS__STALE_HI] = ch1_stale_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_STATUS__LOW_HI]   = ch1_low_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_STATUS__HIGH_HI]  = ch1_high_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_STATUS__EVENT_HI] = ch1_event_sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_CURRENT_AGE_MS__CURRENT_AGE_MS_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_CURRENT_AGE_MS__CURRENT_AGE_MS_LO] = ch1_age_ms_q;

    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_META__SOURCE_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_META__SOURCE_LO]     = ch0_source_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_META__SEQUENCE_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR0_META__SEQUENCE_LO] = ch0_sequence_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_META__SOURCE_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_META__SOURCE_LO]     = ch1_source_q;
    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_META__SEQUENCE_HI:dfc_types_pkg::DFC_RTL010_STATUS__SENSOR1_META__SEQUENCE_LO] = ch1_sequence_q;

    status_comb[dfc_types_pkg::DFC_RTL010_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL010_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end
  assign status_o = status_comb;

  // ---- unused real ports (structurally required, no functional use in
  // this implementation -- same disclosed-no-use precedent already
  // established for dfc_rtl003/005/007/008/009.sv) ----
  logic unused_sink;
  assign unused_sink = (^operating_state_i) ^ observational_mode_i;

endmodule : dfc_rtl010
