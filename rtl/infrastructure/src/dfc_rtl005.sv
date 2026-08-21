// dfc_rtl005.sv -- RTL-005 Event Logger: the sole arbiter and store for all
// 24 producers' diagnostic event records (ARCH-002 SS8.3, ARCH-EVT-001
// through 008, Appendix F.1 ARCH-RTL005-001, Appendix F.3 index 4). Owns
// REG-002's Event Logger block (0x0300-0x0338, 15 registers -- see header
// note below on the 14-vs-15 discrepancy).
//
// Controlling documents: docs/rtl_specs/RTL-005_RevA.md, RCA-DFC-ARCH-002
// SS8.3/Appendix B/Appendix F.1 ARCH-RTL005-001/Appendix F.3 index 4,
// RCA-DFC-REG-002 SS10 (0x0300-0x0338).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement anywhere
// in this file.
//
// ============================================================================
// ONE REAL ARCH-002 GAP, FOUND AND FIXED (with explicit approval) BEFORE this
// module was implemented -- not silently worked around:
//   dfc_rtl005_control_t (originally 128 bits, exactly full with no spare
//   bits) had no clear-request field for EVT_STATUS.SNAPSHOT_VALID (REG-002
//   0x0304 bit 2, a real W1C field: "One requests clear; zero has no effect
//   ... Requests clear of selected sticky evidence only") -- identical in
//   kind to the OVERFLOW/SOURCE_DROP/POP_ERROR/CLEAR_COMPLETE clear fields
//   the struct already had. Fixed, with explicit approval: ARCH-002 grew the
//   struct 128->129 bits, adding evt_status__snapshot_valid at the new
//   highest bit (128) -- every pre-existing field's bit position confirmed
//   unchanged via a real regenerate.ps1 run. This is the fourth real
//   instance of this exact gap class (RTL-002/003's EVT_OVERFLOW_STATUS,
//   RTL-004's SNAPSHOT_VALID/SYNC_VALID, now RTL-005's SNAPSHOT_VALID) --
//   logged in OPEN_ISSUES.md.
//
// A LOWER-STAKES DISCREPANCY, RESOLVED WITHOUT AN EDIT (same resolution
// style as OPEN_ISSUES.md items 1/10/11): REG-002's own top-level block
// summary table lists RTL-005's Event Logger block as 15 registers;
// RTL-005_RevA.md SS4 says "14 registers" without listing them. Resolved in
// favor of REG-002 (the owning document, CHTR-DOC-003) -- this module
// implements and forwards all 15 (EVT_CONTROL, EVT_STATUS, EVT_COUNT,
// EVT_OVERFLOW_COUNT, EVT_SOURCE_ENABLE, EVT_SNAPSHOT, EVT_DATA0-3, EVT_POP,
// EVT_CLEAR, EVT_DROP_SOURCE, EVT_ARB_STATUS, EVT_POP_ERROR_COUNT).
//
// ============================================================================
// ARCHITECTURE NOTE -- how this module's port list maps onto ARCH-002's
// self-referencing wiring for RTL-005 (read before changing anything below):
//
// ARCH-002's own RTL-005 port-catalog row for evt_valid_o/evt_ready_i/
// evt_record_o shows PRODUCER *and* CONSUMER as "RTL-005" -- unlike the
// RTL-004 timestamp_i self-reference (resolved as a table-generation
// artifact, OPEN_ISSUES.md item 10), this one is a REAL, deliberate design:
// RTL-005 is simultaneously the ARBITER for 24 external producers AND ITS
// OWN 25th conceptual producer (of its own diagnostic events 0x000A/0x007E/
// 0x007F). Concretely: this module presents its own generated diagnostic
// candidate on evt_valid_o/evt_record_o (a genuine one-deep pending
// register, `self_evt_pending_q`/`self_evt_record_q`, exactly the same
// shape every other module uses for its own event generation), and
// `dfc_rtl024.sv` -- the integrator, per ARCH-002's own wiring table --
// loops that output back into THIS module's own `evt_valid_i[4]`/
// `evt_ready_o[4]`/`evt_record_i[4]` (index 4, matching ARCH-002's fixed
// evt_valid_i[23:0] producer allocation: index i <-> RTL-(i+1), so index 4
// <-> RTL-005 itself). This module never special-cases index 4 internally
// beyond inspecting slot 4's EVENT_ID for arbitration priority (below) --
// the self-loop is entirely an INTEGRATION-level wiring fact, not something
// this module's own logic hard-codes structurally.
//
// ============================================================================
// DESIGN, WITH DISCLOSED INTERPRETATIONS (RTL-005_RevA.md SS5 flags this
// module as verification-heavy relative to its port count -- every judgment
// call below is deliberate, not accidental):
//
//   - 24 independent one-deep PRODUCER SLOTS (`slot_valid_q[23:0]`,
//     `slot_record_q[i]`). `evt_ready_o[i]` is combinational:
//     LOGGER_ENABLE && SOURCE_ENABLE[i] && !slot_valid_q[i]. A slot drains
//     (clears) the same cycle the arbiter services it into the store.
//   - ARCH-EVT-001 "arrival to an occupied slot": literal reading --
//     evt_valid_i[i] asserted while slot_valid_q[i] is already 1 (source
//     enabled). EDGE-qualified (only the RISING edge of this condition per
//     source schedules a 0x007E candidate -- same edge-qualification
//     precedent already used in dfc_rtl003.sv/dfc_rtl004.sv for an
//     analogous reason: a well-behaved producer holds `valid` "stable while
//     valid and not ready" per its own port contract, so without edge-
//     qualification a single stalled producer would spuriously re-trigger
//     every cycle it waits for round-robin service, even though it is not
//     losing anything new). The sticky per-source evidence
//     (EVT_DROP_SOURCE[i]) and the aggregate (EVT_STATUS.SOURCE_DROP) are
//     level-independent sticky W1C bits, set on the rising edge and held
//     until host-cleared -- ARCH-EVT-003's "multiple losses coalesce while
//     a report is pending; counts include every loss" is satisfied by
//     these bits staying set (coalescing) across repeated overflow onsets
//     without a per-source magnitude counter (REG-002 defines no such
//     register -- only the sticky per-source bit and the aggregate).
//   - ARBITRATION (ARCH-EVT-002): only slot 4 can ever hold a 0x007E/0x007F
//     record (RTL-005 is the only source of those event IDs, and its own
//     output is wired only to slot 4). Priority per cycle: slot 4 holding
//     0x007F, then slot 4 holding 0x007E, then ordinary round-robin over
//     every occupied slot (0-23, including slot 4 when it holds an
//     ORDINARY 0x000A self-record) starting after `last_ordinary_source_q`
//     -- updated only by an ORDINARY service, never by an overflow-priority
//     one, matching the spec's literal "starting after the last accepted
//     ORDINARY source". At most one slot is drained per CORE_CLK.
//   - STORE (ARCH-EVT-004/005/006/007/008): a real 64x128-bit register
//     array (`store_q[0:63]`), head/tail/level pointers. CLEAR_ALL has
//     priority over POP and ordinary push and touches ONLY head/tail/level
//     (per REG-002's own "no unrelated state changes" text for EVT_CLEAR --
//     producer slots and the OVERFLOW/SOURCE_DROP/POP_ERROR/SNAPSHOT_VALID
//     sticky evidence are deliberately left untouched, each independently
//     host-clearable). Simultaneous push+POP on nonempty removes old head
//     and appends new tail with level unchanged (ARCH-EVT-006). Push-only
//     while full overwrites the oldest (head and tail both advance, level
//     stays 64) and sets/increments EVT_STATUS.OVERFLOW/EVT_OVERFLOW_COUNT
//     -- UNLESS the record being pushed is itself a 0x007E/0x007F
//     diagnostic record, in which case the overwrite mechanics still
//     execute but the overflow evidence/counter are NOT incremented again
//     (ARCH-EVT-007's explicit nonrecursion guarantee). POP on empty is
//     rejected (EVT_STATUS.POP_ERROR set, EVT_POP_ERROR_COUNT incremented).
//     CAPTURE_OLDEST/POP both require nonempty (ARCH-VAL-005); a rejected
//     CAPTURE_OLDEST has no defined error evidence in REG-002 and is simply
//     a no-op. "Snapshot old head, then POP" (ARCH-EVT-008) is automatically
//     satisfied by nonblocking-assignment semantics -- `store_q[head_q]` is
//     read at its pre-cycle value regardless of what else updates
//     head_q/store_q[tail_q] the same cycle (same technique already proven
//     in dfc_rtl004.sv's SNAPSHOT handling). A plain POP (no simultaneous
//     CAPTURE) invalidates the snapshot per REG-002's EVT_POP text; a fresh
//     CAPTURE this same cycle dominates a simultaneous POP's invalidation
//     (new evidence over clear, the same general precedence rule used
//     project-wide) -- REG-002/ARCH-002 do not spell out this exact
//     three-way precedence explicitly; this is a disclosed interpretation.
//   - EVT_OVERFLOW_COUNT/EVT_POP_ERROR_COUNT (REG-002 access class
//     COUNTER-CLR: read 0-0xFFFFFFFF; write only 0x00000000 (no effect) or
//     0xFFFFFFFF (one clear pulse), every other value ACCESS_ERROR):
//     reggen.py v4 has no dedicated COUNTER-CLR pulse-capture path, so
//     rtl005_field_map.json maps these two control fields as class "W1C"
//     to reuse its existing one-cycle raw-wdata_i pulse-capture mechanism.
//     This module checks the captured pulse equals exactly 32'hFFFFFFFF
//     before treating it as an accepted clear; any other nonzero value is
//     neither validated nor rejected as ACCESS_ERROR (RTL-001 has no
//     per-field write-value validation yet -- OPEN_ISSUES.md item 4, a
//     pre-existing gap this does not worsen).
//   - SELF-EVENT GENERATION (mirrors every other module's own one-deep
//     evt_valid_o/evt_ready_i pending shape exactly): candidates, priority
//     high to low: 0x007F (new store-overflow evidence this cycle) >
//     0x007E (a rising producer-slot collision this cycle, source_id = the
//     lowest-indexed source that just collided) > 0x000A subtype 0
//     (not-empty transition, level was 0 before an accepted push) >
//     subtype 1 (pop error) > subtype 2 (clear complete). Per the module
//     spec's own text ("safety-mandatory and 0x007E/0x007F overflow events
//     bypass this gate entirely") and the Appendix F.3 preamble
//     (`evt_request = mandatory_event | (GLOBAL_EVENT_ENABLE &
//     MODULE_EVENT_ENABLE & OR(EVENT_CONDITION & EVENT_MASK))`), 0x007E/
//     0x007F are treated as the `mandatory_event` term -- generated
//     unconditionally, bypassing LOGGER_ENABLE, global_event_enable_i, AND
//     event_condition_enable_i. The three 0x000A subtypes are ordinary,
//     gated by LOGGER_ENABLE (reused here as MODULE_EVENT_ENABLE -- RTL-005
//     has no separate named enable field) AND global_event_enable_i AND
//     their respective event_condition_enable_i bit (0/3/4 per Appendix
//     F.3's RTL-005 allocation). Bit 5 ("event-slot overflow") is real per
//     the allocation table but not separately wired to anything -- same
//     precedent already established by dfc_rtl002/003/004.sv for their own
//     identical "event-slot overflow" condition bit: it has no event of
//     its own to gate, only the generic status_o.event_overflow/
//     event_drop_count fields below. If this module's own single pending
//     slot (self_evt_pending_q) is still occupied when a new candidate
//     arises, the candidate is dropped and counted via the GENERIC
//     status_o.event_overflow/event_drop_count fields (bits 2/220:235) --
//     the same pattern every prior module uses for this exact condition,
//     independent of (and layered underneath) the 24-wide producer-slot
//     bookkeeping above, which only applies once a candidate has actually
//     reached slot 4 via the external self-loop.
//   - irq_req_o: RTL-005 has no dedicated "IRQ_ENABLE"-named field in its
//     own registers (unlike RTL-003's per-source IRQ_ENABLE, which serves a
//     different purpose -- aggregation source masking, not a module-level
//     master gate). Per the Appendix F.3 preamble's general equation
//     (`irq_req = MODULE_IRQ_ENABLE & OR(IRQ_CONDITION & IRQ_MASK)`) and
//     the RTL-005 condition-mask row not stating "no ordinary interrupt is
//     generated" (unlike RTL-003/RTL-004's own rows), this module DOES
//     generate an ordinary level-type interrupt request. Disclosed
//     interpretation: LOGGER_ENABLE is reused as MODULE_IRQ_ENABLE (the
//     only candidate master-gate field this module has), ORed live
//     condition signals (not-empty transition / store overflow / producer
//     drop / pop error / clear complete -- bit 5 "event-slot overflow" has
//     no live signal, tied 0) gated by irq_condition_enable_i[5:0], per
//     RTL-003's own Section 8.1 latching (this module presents a raw level,
//     not sticky evidence -- matches the port table's "level or sticky
//     evidence as source matrix specifies").
//   - fault_req_o / status_o.fault: ARCH-RTL005-001 says fault is "retained
//     internal-storage/control error or a configured event-overflow fault
//     condition" -- this register-array implementation has no ECC/parity
//     to ever detect an "internal-storage/control error" (same underlying
//     gap as RTL-004's identical disclosure for "illegal command"), so both
//     signals are driven by the one implementable fault source: the sticky
//     EVT_STATUS.OVERFLOW (store-overflow) condition, matching the
//     fault-source table's own "Event logger overflow" description.
//   - ready: unconditional 1'b1 once released from reset/module_reset --
//     every state-holding register (pointers, slots, sticky evidence)
//     clears in the SAME reset branch, so "ready after pointers and pending
//     slots clear" (ARCH-RTL005-001) is trivially true on the very first
//     post-reset cycle; no multi-cycle startup exists.
//   - EVT_SOURCE_ENABLE gating: a disabled source's evt_valid_i is silently
//     ignored (no accept, no collision counted) -- REG-002 defines no
//     evidence for this case.
//   - Known dependency gap per RTL-005_RevA.md SS6: with only RTL-001
//     through RTL-004 real today, this module is testable for its own
//     store/overflow/snapshot/arbitration mechanics using real producers
//     0-3 plus its own self-loop (index 4), but not for genuine 24-way
//     arbitration fairness until RTL-006 onward exist -- disclosed, not a
//     defect in this file.
// ============================================================================

module dfc_rtl005 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[4]

  // TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
  // Yosys build -- see dfc_rtl002.sv's header for the full account): a
  // package-scoped type cannot be a port's declared type. Every such port
  // here is a plain `logic [W-1:0]` vector sized via generated
  // `dfc_types_pkg::DFC_*_WIDTH` VALUE constants instead.
  input  logic [dfc_types_pkg::DFC_RTL005_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0]  status_o,

  // RTL-005's OWN diagnostic-event output (own event IDs 0x000A/0x007E/
  // 0x007F) -- externally self-looped by dfc_rtl024.sv into evt_valid_i[4]/
  // evt_ready_o[4]/evt_record_i[4] below, per ARCH-002's own port catalog
  // (see header note).
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  input  logic [63:0] timestamp_i,

  output logic irq_req_o,
  output logic fault_req_o,

  // 24 independent producer channels (RTL-001 through RTL-024, index i <->
  // RTL-(i+1)) -- index 4 is RTL-005's own self-loop (see header).
  // dfc_event_record_t[24] cannot be a packed array of a package-scoped
  // type on this toolchain either (same TOOLCHAIN-DRIVEN DEVIATION as
  // above) -- flattened to a single 3072-bit vector, sliced per-source via
  // `evt_record_i[i*128 +: 128]`.
  input  logic [23:0]  evt_valid_i,
  output logic [23:0]  evt_ready_o,
  input  logic [24*dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_i,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  input  logic         global_event_enable_i,

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3: bits 0/3/4
                                                   // used (not-empty/pop-
                                                   // error/clear-complete);
                                                   // bit 5 (event-slot
                                                   // overflow) real but
                                                   // unwired -- see header.
                                                   // Bits 1/2 (store/
                                                   // producer overflow) are
                                                   // real per the F.3 table
                                                   // but 0x007E/0x007F
                                                   // bypass this gate
                                                   // entirely -- see header.
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3, same
                                                   // allocation -- see
                                                   // header's irq_req_o note
);

  localparam int unsigned EVID_HI = dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI;
  localparam int unsigned EVID_LO = dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO;
  localparam logic [15:0] EVT_ID_LOGGER_OP   = 16'h000A;
  localparam logic [15:0] EVT_ID_SOURCE_OVFL = 16'h007E;
  localparam logic [15:0] EVT_ID_STORE_OVFL  = 16'h007F;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL005 = 8'd4;  // ARCH-002 C.5 index 4

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as dfc_rtl002/003/004.sv) ----
  wire        ctl_logger_enable = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_CONTROL__LOGGER_ENABLE_HI];
  wire        ctl_clear_overflow        = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_STATUS__OVERFLOW_HI];
  wire        ctl_clear_source_drop_agg = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_STATUS__SOURCE_DROP_HI];
  wire        ctl_clear_pop_error       = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_STATUS__POP_ERROR_HI];
  wire        ctl_clear_clear_complete  = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_STATUS__CLEAR_COMPLETE_HI];
  wire        ctl_clear_snapshot_valid  = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_STATUS__SNAPSHOT_VALID_HI];
  wire [31:0] ctl_overflow_count_pulse  =
    control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL005_CONTROL__EVT_OVERFLOW_COUNT__COUNT_LO];
  wire [23:0] ctl_source_enable =
    control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_SOURCE_ENABLE__SOURCE_ENABLE_HI:dfc_types_pkg::DFC_RTL005_CONTROL__EVT_SOURCE_ENABLE__SOURCE_ENABLE_LO];
  wire        ctl_capture_oldest = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_SNAPSHOT__CAPTURE_OLDEST_HI];
  wire        ctl_pop            = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_POP__POP_HI];
  wire        ctl_clear_all      = control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_CLEAR__CLEAR_ALL_HI];
  wire [31:0] ctl_drop_source_clear =
    control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_DROP_SOURCE__SOURCE_DROP_HI:dfc_types_pkg::DFC_RTL005_CONTROL__EVT_DROP_SOURCE__SOURCE_DROP_LO];
  wire [31:0] ctl_pop_error_count_pulse =
    control_i[dfc_types_pkg::DFC_RTL005_CONTROL__EVT_POP_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL005_CONTROL__EVT_POP_ERROR_COUNT__COUNT_LO];

  wire ctl_clear_overflow_count   = (ctl_overflow_count_pulse  == 32'hFFFFFFFF);
  wire ctl_clear_pop_error_count  = (ctl_pop_error_count_pulse == 32'hFFFFFFFF);

  // ==========================================================================
  // 24 producer pending slots (ARCH-EVT-001) + per-source collision
  // (occupied-slot arrival) detection, edge-qualified (see header).
  // ==========================================================================
  logic [23:0]  slot_valid_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] slot_record_q [0:23];
  logic [23:0]  prev_collision_q;

  wire [23:0] accept_i          = evt_valid_i & evt_ready_o;
  wire [23:0] collision_i       = evt_valid_i & ctl_source_enable & slot_valid_q;
  wire [23:0] collision_rising  = collision_i & ~prev_collision_q;
  wire        any_collision_rising = |collision_rising;

  assign evt_ready_o = {24{ctl_logger_enable}} & ctl_source_enable & ~slot_valid_q;

  // Lowest-indexed rising-collision source, for the 0x007E candidate's
  // SOURCE_ID field.
  logic [4:0] ovfl_source_comb;
  always_comb begin
    ovfl_source_comb = 5'd0;
    for (int k = 23; k >= 0; k--) begin
      if (collision_rising[k]) ovfl_source_comb = k[4:0];
    end
  end

  // ==========================================================================
  // Arbitration (ARCH-EVT-002): slot 4 holding 0x007F, then slot 4 holding
  // 0x007E, then ordinary round-robin over every occupied slot starting
  // after last_ordinary_source_q. Declared ahead of the slot-capture
  // always_ff below (which reads do_push/push_idx) -- the person's real
  // Icarus rejects a plain continuous-assignment forward reference to a
  // signal not yet declared (PROJECT_CONTINUITY.md Section 2).
  // ==========================================================================
  logic [4:0] last_ordinary_source_q;
  logic [4:0] last_source_reported_q;
  logic [23:0] rr_mask_q;  // registered priority mask -- see arbitration note below

  wire slot4_is_007F = slot_valid_q[4] && (slot_record_q[4][EVID_HI:EVID_LO] == EVT_ID_STORE_OVFL);
  wire slot4_is_007E = slot_valid_q[4] && !slot4_is_007F && (slot_record_q[4][EVID_HI:EVID_LO] == EVT_ID_SOURCE_OVFL);

  // ---- Round-robin arbitration, TIMING-CRITICAL PATH FIX (second pass) ----
  // A real, confirmed `build_ecp5.ps1` timing failure (Max frequency
  // 44.21 MHz, FAIL at 50 MHz required) traced directly to this block: the
  // original code computed each of 24 candidates' rotated index via a
  // conditional-subtract (an adder/comparator) chained together with the
  // priority decision, 24 deep. A first fix (parallel per-candidate adders
  // + a separate priority encode) actually made timing WORSE (38.14 MHz):
  // 24 independent 5-bit adders is still 24 real carry-chain (CCU2C) cells
  // feeding a wide dynamic bit-select, regardless of whether they're
  // sequentially chained or not -- real, measured evidence, not assumed,
  // that "parallel adders" was the wrong fix shape here.
  //
  // REAL FIX: replace per-candidate ARITHMETIC with a REGISTERED PRIORITY
  // MASK (`rr_mask_q`), the standard round-robin-arbiter technique. Each
  // cycle's arbitration reads only the ALREADY-REGISTERED mask -- two
  // static bitwise ANDs (`slot_valid_q & rr_mask_q` / `& ~rr_mask_q`) and
  // two STATIC priority encoders (fixed bit positions, no per-candidate
  // dynamic index arithmetic at all) -- genuinely cheap, log-depth
  // boolean logic. The mask for the NEXT cycle is updated via a single
  // 5-bit increment (`ordinary_idx + 1`) feeding ONE barrel SHIFT
  // (`24'hFFFFFF << next_ptr`, implemented as muxes, not carry chains) --
  // one adder and one shifter total per cycle, not 24.
  wire [23:0] high_group = slot_valid_q & rr_mask_q;   // indices AFTER last serviced
  wire [23:0] low_group  = slot_valid_q & ~rr_mask_q;  // indices AT/BEFORE (wrap-around)

  logic [4:0] high_idx, low_idx;
  logic       high_found, low_found;
  always_comb begin
    high_idx = 5'd0; high_found = 1'b0;
    for (int i = 23; i >= 0; i--) begin
      if (high_group[i]) begin high_idx = i[4:0]; high_found = 1'b1; end
    end
  end
  always_comb begin
    low_idx = 5'd0; low_found = 1'b0;
    for (int i = 23; i >= 0; i--) begin
      if (low_group[i]) begin low_idx = i[4:0]; low_found = 1'b1; end
    end
  end

  wire        ordinary_found = high_found || low_found;
  wire [4:0]  ordinary_idx   = high_found ? high_idx : low_idx;

  logic       push_valid_comb;
  logic [4:0] push_idx_comb;
  logic       push_ordinary_comb;

  always_comb begin
    push_valid_comb    = 1'b0;
    push_idx_comb       = 5'd0;
    push_ordinary_comb  = 1'b0;
    if (slot4_is_007F || slot4_is_007E) begin
      push_valid_comb   = 1'b1;
      push_idx_comb      = 5'd4;
      push_ordinary_comb = 1'b0;
    end else if (ordinary_found) begin
      push_valid_comb   = 1'b1;
      push_idx_comb      = ordinary_idx;
      push_ordinary_comb = 1'b1;
    end
  end

  wire        push_valid        = push_valid_comb;
  wire [4:0]  push_idx          = push_idx_comb;
  wire        push_ordinary     = push_ordinary_comb;
  wire        accepted_clear_all = ctl_clear_all;
  wire        do_push           = push_valid && !accepted_clear_all;
  wire        pushing_overflow_rec = do_push && !push_ordinary;  // slot 4 holding 0x007E/0x007F

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      slot_valid_q     <= 24'h0;
      prev_collision_q <= 24'h0;
      for (int i = 0; i < 24; i++) slot_record_q[i] <= '0;
    end else if (module_reset_i) begin
      slot_valid_q     <= 24'h0;
      prev_collision_q <= 24'h0;
      for (int i = 0; i < 24; i++) slot_record_q[i] <= '0;
    end else begin
      for (int i = 0; i < 24; i++) begin
        if (do_push && (push_idx == i[4:0])) begin
          slot_valid_q[i] <= 1'b0;
        end else if (accept_i[i]) begin
          slot_valid_q[i]  <= 1'b1;
          slot_record_q[i] <= evt_record_i[i*dfc_types_pkg::DFC_EVENT_RECORD_WIDTH +: dfc_types_pkg::DFC_EVENT_RECORD_WIDTH];
        end
      end
      prev_collision_q <= collision_i;
    end
  end

  // ==========================================================================
  // Store (ARCH-EVT-004 through 008): 64x128-bit register array.
  // ==========================================================================
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] store_q [0:63];
  logic [5:0] head_q, tail_q;
  logic [6:0] level_q;

  wire not_empty = (level_q != 7'd0);
  wire full      = (level_q == 7'd64);

  wire accepted_capture     = ctl_capture_oldest && not_empty && !accepted_clear_all;
  wire accepted_pop         = ctl_pop && not_empty && !accepted_clear_all;
  wire reject_pop_error     = ctl_pop && !not_empty && !accepted_clear_all;
  wire new_store_overflow   = do_push && full && !pushing_overflow_rec;

  logic        evt_status_overflow_q;
  logic        evt_status_source_drop_q;
  logic        evt_status_pop_error_q;
  logic        evt_status_clear_complete_q;
  logic        evt_status_snapshot_valid_q;
  logic [31:0] evt_overflow_count_q;
  logic [31:0] evt_pop_error_count_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] snapshot_record_q;
  logic [23:0] evt_drop_source_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      head_q <= 6'd0; tail_q <= 6'd0; level_q <= 7'd0;
      evt_status_overflow_q      <= 1'b0;
      evt_status_pop_error_q     <= 1'b0;
      evt_status_clear_complete_q <= 1'b0;
      evt_status_snapshot_valid_q <= 1'b0;
      evt_overflow_count_q  <= 32'd0;
      evt_pop_error_count_q <= 32'd0;
      snapshot_record_q     <= '0;
      last_ordinary_source_q <= 5'd0;
      last_source_reported_q <= 5'd0;
      rr_mask_q <= 24'hFFFFFF;
    end else if (module_reset_i) begin
      head_q <= 6'd0; tail_q <= 6'd0; level_q <= 7'd0;
      evt_status_overflow_q      <= 1'b0;
      evt_status_pop_error_q     <= 1'b0;
      evt_status_clear_complete_q <= 1'b0;
      evt_status_snapshot_valid_q <= 1'b0;
      evt_overflow_count_q  <= 32'd0;
      evt_pop_error_count_q <= 32'd0;
      snapshot_record_q     <= '0;
      last_ordinary_source_q <= 5'd0;
      last_source_reported_q <= 5'd0;
      rr_mask_q <= 24'hFFFFFF;
    end else begin
      if (accepted_clear_all) begin
        head_q <= 6'd0; tail_q <= 6'd0; level_q <= 7'd0;
      end else begin
        if (do_push && accepted_pop) begin
          store_q[tail_q] <= slot_record_q[push_idx];
          tail_q <= tail_q + 6'd1;
          head_q <= head_q + 6'd1;
        end else if (do_push) begin
          store_q[tail_q] <= slot_record_q[push_idx];
          tail_q <= tail_q + 6'd1;
          if (full) head_q <= head_q + 6'd1;
          else      level_q <= level_q + 7'd1;
        end else if (accepted_pop) begin
          head_q  <= head_q + 6'd1;
          level_q <= level_q - 7'd1;
        end

        if (do_push && push_ordinary) begin
          last_ordinary_source_q <= push_idx;
          rr_mask_q <= 24'hFFFFFF << (push_idx + 5'd1);
        end
        if (do_push)                  last_source_reported_q <= push_idx;
      end

      // ---- W1C/sticky evidence: new evidence dominates a simultaneous
      // clear (REG-002's own documented priority, same pattern used
      // project-wide). ----
      if (new_store_overflow) begin
        evt_status_overflow_q <= 1'b1;
      end else if (ctl_clear_overflow) begin
        evt_status_overflow_q <= 1'b0;
      end

      if (reject_pop_error) begin
        evt_status_pop_error_q <= 1'b1;
      end else if (ctl_clear_pop_error) begin
        evt_status_pop_error_q <= 1'b0;
      end

      if (accepted_clear_all) begin
        evt_status_clear_complete_q <= 1'b1;
      end else if (ctl_clear_clear_complete) begin
        evt_status_clear_complete_q <= 1'b0;
      end

      if (accepted_capture) begin
        snapshot_record_q <= store_q[head_q];
        evt_status_snapshot_valid_q <= 1'b1;
      end else if (accepted_pop) begin
        evt_status_snapshot_valid_q <= 1'b0;
      end else if (ctl_clear_snapshot_valid) begin
        evt_status_snapshot_valid_q <= 1'b0;
      end

      if (new_store_overflow) begin
        if (evt_overflow_count_q != 32'hFFFFFFFF) evt_overflow_count_q <= evt_overflow_count_q + 32'd1;
      end else if (ctl_clear_overflow_count) begin
        evt_overflow_count_q <= 32'd0;
      end

      if (reject_pop_error) begin
        if (evt_pop_error_count_q != 32'hFFFFFFFF) evt_pop_error_count_q <= evt_pop_error_count_q + 32'd1;
      end else if (ctl_clear_pop_error_count) begin
        evt_pop_error_count_q <= 32'd0;
      end
    end
  end

  // EVT_DROP_SOURCE per-source W1C (24 meaningful bits): new collision-rising
  // evidence for source i dominates a simultaneous host clear of bit i.
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_drop_source_q       <= 24'h0;
      evt_status_source_drop_q <= 1'b0;
    end else if (module_reset_i) begin
      evt_drop_source_q       <= 24'h0;
      evt_status_source_drop_q <= 1'b0;
    end else begin
      for (int i = 0; i < 24; i++) begin
        if (collision_rising[i]) evt_drop_source_q[i] <= 1'b1;
        else if (ctl_drop_source_clear[i]) evt_drop_source_q[i] <= 1'b0;
      end
      if (any_collision_rising) evt_status_source_drop_q <= 1'b1;
      else if (ctl_clear_source_drop_agg) evt_status_source_drop_q <= 1'b0;
    end
  end

  // ==========================================================================
  // Self-event generation (own diagnostic events 0x000A/0x007E/0x007F) --
  // real, one-deep pending shape identical to every prior module's own
  // event generation. See header for full gating/priority rationale.
  // ==========================================================================
  wire trigger_007F               = new_store_overflow;
  wire trigger_007E               = any_collision_rising;
  wire trigger_not_empty          = do_push && !not_empty;
  wire trigger_pop_error_evt      = reject_pop_error;
  wire trigger_clear_complete_evt = accepted_clear_all;

  wire ordinary_gate = ctl_logger_enable && global_event_enable_i;

  wire self_candidate_valid =
    trigger_007F || trigger_007E ||
    (ordinary_gate && (
      (trigger_not_empty          && event_condition_enable_i[0]) ||
      (trigger_pop_error_evt      && event_condition_enable_i[3]) ||
      (trigger_clear_complete_evt && event_condition_enable_i[4])));

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] self_candidate;
  always_comb begin
    self_candidate = '0;
    self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    if (trigger_007F) begin
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_STORE_OVFL;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL005;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__FLAGS_HI:dfc_types_pkg::DFC_EVENT_RECORD__FLAGS_LO] = 8'h10;  // bit4 overflow report
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 16] = evt_overflow_count_q[15:0];
    end else if (trigger_007E) begin
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_SOURCE_OVFL;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = {3'b0, ovfl_source_comb};
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__FLAGS_HI:dfc_types_pkg::DFC_EVENT_RECORD__FLAGS_LO] = 8'h10;  // bit4 overflow report
    end else if (trigger_not_empty) begin
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_LOGGER_OP;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL005;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = 8'd0;
    end else if (trigger_pop_error_evt) begin
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_LOGGER_OP;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL005;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = 8'd1;
    end else if (trigger_clear_complete_evt) begin
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO] = EVT_ID_LOGGER_OP;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL005;
      self_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8] = 8'd2;
    end
  end

  logic                                              self_evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  self_evt_record_q;
  logic                                              self_evt_overflow_q;
  logic [15:0]                                       self_evt_drop_count_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      self_evt_pending_q    <= 1'b0;
      self_evt_record_q     <= '0;
      self_evt_overflow_q   <= 1'b0;
      self_evt_drop_count_q <= 16'd0;
    end else if (module_reset_i) begin
      self_evt_pending_q    <= 1'b0;
      self_evt_record_q     <= '0;
      self_evt_overflow_q   <= 1'b0;
      self_evt_drop_count_q <= 16'd0;
    end else begin
      if (self_evt_pending_q && evt_ready_i) self_evt_pending_q <= 1'b0;

      if (self_candidate_valid) begin
        if (!self_evt_pending_q || (self_evt_pending_q && evt_ready_i)) begin
          self_evt_pending_q <= 1'b1;
          self_evt_record_q  <= self_candidate;
        end else begin
          if (self_evt_drop_count_q != 16'hFFFF) self_evt_drop_count_q <= self_evt_drop_count_q + 16'd1;
          self_evt_overflow_q <= 1'b1;
        end
      end
    end
  end

  assign evt_valid_o  = self_evt_pending_q;
  assign evt_record_o = self_evt_record_q;

  // ==========================================================================
  // irq_req_o / fault_req_o -- see header for disclosed interpretation.
  // ==========================================================================
  wire [5:0] irq_condition_live = {1'b0, trigger_clear_complete_evt, trigger_pop_error_evt,
                                    trigger_007E, trigger_007F, trigger_not_empty};
  assign irq_req_o   = ctl_logger_enable && |(irq_condition_live & irq_condition_enable_i[5:0]);
  assign fault_req_o = evt_status_overflow_q;

  // ==========================================================================
  // status_o packing (dfc_rtl005_status_t, 268 bits).
  // ==========================================================================
  logic [4:0] next_source_comb;
  always_comb next_source_comb = (last_ordinary_source_q == 5'd23) ? 5'd0 : (last_ordinary_source_q + 5'd1);

  logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__READY_HI]          = 1'b1;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__FAULT_HI]          = evt_status_overflow_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVENT_OVERFLOW_HI] = self_evt_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__NOT_EMPTY_HI]      = not_empty;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__FULL_HI]          = full;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__SNAPSHOT_VALID_HI] = evt_status_snapshot_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__OVERFLOW_HI]      = evt_status_overflow_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__SOURCE_DROP_HI]   = evt_status_source_drop_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__POP_ERROR_HI]     = evt_status_pop_error_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_STATUS__CLEAR_COMPLETE_HI] = evt_status_clear_complete_q;

    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_COUNT__COUNT_LO] = level_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_OVERFLOW_COUNT__COUNT_LO] = evt_overflow_count_q;

    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA0__TIMESTAMP_LO_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA0__TIMESTAMP_LO_LO]
      = snapshot_record_q[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO+31:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO];
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA1__TIMESTAMP_HI_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA1__TIMESTAMP_HI_LO]
      = snapshot_record_q[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO+32];
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA2__EVENT_ID_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA2__EVENT_ID_LO]
      = snapshot_record_q[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO];
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA2__SOURCE_ID_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA2__SOURCE_ID_LO]
      = snapshot_record_q[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO];
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA2__FLAGS_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA2__FLAGS_LO]
      = snapshot_record_q[dfc_types_pkg::DFC_EVENT_RECORD__FLAGS_HI:dfc_types_pkg::DFC_EVENT_RECORD__FLAGS_LO];
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA3__EVENT_DATA_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DATA3__EVENT_DATA_LO]
      = snapshot_record_q[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO];

    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_DROP_SOURCE__SOURCE_DROP_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_DROP_SOURCE__SOURCE_DROP_LO]
      = {8'h0, evt_drop_source_q};

    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_ARB_STATUS__LAST_SOURCE_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_ARB_STATUS__LAST_SOURCE_LO]
      = last_source_reported_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_ARB_STATUS__NEXT_SOURCE_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_ARB_STATUS__NEXT_SOURCE_LO]
      = next_source_comb;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_ARB_STATUS__ARB_ACTIVE_HI] = do_push;

    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVENT_DROP_COUNT_LO]
      = self_evt_drop_count_q;
    status_comb[dfc_types_pkg::DFC_RTL005_STATUS__EVT_POP_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL005_STATUS__EVT_POP_ERROR_COUNT__COUNT_LO]
      = evt_pop_error_count_q;
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): operating_state_i/
  // observational_mode_i are real ports with no functional consumer in this
  // implementation (same precedent as dfc_rtl003/004.sv's identical case).
  // ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i;

endmodule : dfc_rtl005
