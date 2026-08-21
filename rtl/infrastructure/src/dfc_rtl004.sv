// dfc_rtl004.sv -- RTL-004 Timestamp Engine. Hand-authored (not generated);
// sole producer of the always-running 64-bit raw microsecond timestamp
// broadcast to every other module, and of an independently correlated
// (host-offset) time value exposed via the register interface. Implements
// ARCH-002 SS8.2 (ARCH-TIME-001 through 006) and RTL-004 spec SS3/SS4
// (REG-002 0x0200-0x022C).
//
// Controlling documents: docs/rtl_specs/RTL-004_RevA.md, RCA-DFC-ARCH-002
// SS8.2/Appendix B/Appendix F.1 ARCH-RTL004-001/Appendix F.3, RCA-DFC-REG-002
// SS9 (0x0200-0x022C, 12 registers).
//
// RTLSTD-LANG-008 prohibits wildcard imports; every cross-package symbol
// below is fully qualified at its use site -- no import statement is
// emitted anywhere in this file.
//
// ============================================================================
// THREE REAL ARCH-002 GAPS, FOUND AND FIXED (with explicit approval) BEFORE
// this module was implemented -- not silently worked around:
//   1. dfc_rtl004_control_t (originally 70 bits) had no clear-request field
//      for 2 of TIME_STATUS's 4 real W1C bits (SNAPSHOT_VALID, SYNC_VALID --
//      REG-0204 declares both genuine W1C, "requests clear of selected
//      sticky evidence only", identical wording to SYNC_UPDATED/ERROR, which
//      DID already have control-struct fields). Fixed: ARCH-002 grew the
//      struct to 72 bits, adding time_status__snapshot_valid/
//      time_status__sync_valid at the two new highest bits, every
//      pre-existing field's bit position confirmed unchanged.
//   2. The same already-known EVENT_OVERFLOW-clear gap that was fixed for
//      RTL-002/RTL-003 (OPEN_ISSUES.md item 2) recurred for RTL-004's own
//      RTL004_EVT_OVERFLOW_STATUS (REG-0224) -- exactly as predicted in
//      PROJECT_CONTINUITY.md's own lessons-learned. Fixed the same way:
//      ARCH-002 grew the control struct again, 72->73 bits, adding
//      rtl004_evt_overflow_status__event_overflow at the new highest bit.
//   3. dfc_rtl004_status_t (originally 105 bits) had NO field at all to
//      carry the real active (committed) correlation offset back to
//      TIME_ACTIVE_OFFSET_LO/_HI (REG-0228/022C, readback class "external"
//      per the real extracted dfc_registers_pkg.json -- meaning these two
//      registers have no other real data source). Fixed: ARCH-002 grew the
//      status struct 105->169 bits, adding time_active_offset_lo__offset_lo/
//      time_active_offset_hi__offset_hi (32 bits each) at the new highest
//      bits -- a single source of truth in RTL-004 itself, matching how
//      active_valid/update_sequence (for the same COMMIT event) already work,
//      rather than a fragile independent mirror on RTL-001's side.
// All three regenerated and reconfirmed via a real `regenerate.ps1` run
// (dfc_types_pkg.sv's every pre-existing `_HI`/`_LO` constant in both structs
// unchanged; only the new fields at the new highest bits are new).
//
// A FOURTH, LOWER-STAKES DISCREPANCY, RESOLVED WITHOUT AN EDIT (same
// resolution style as OPEN_ISSUES.md item 1's host_irq_n_o conflict):
// ARCH-002's own "RTL-004 - Timestamp Engine (14 ports)" table lists a
// `timestamp_i` INPUT whose producer AND consumer are both listed as
// "RTL-004" -- a self-referencing port. RTL-004_RevA.md SS2 explicitly says
// "RTL-004 does not consume its own output; it is the origin," and a module
// cannot meaningfully consume its own not-yet-registered output as an
// external port without a real combinational loop. Treated as a table-
// generation artifact (this exact `timestamp_i` row template is mechanically
// repeated for every other module in the same table, and was evidently not
// updated for RTL-004's own special case as the broadcast's true origin).
// This module therefore has 13 real ports, not 14; only `timestamp_o` is
// implemented. Logged in OPEN_ISSUES.md, not silently dropped. Separately,
// RTL-004_RevA.md SS4 says "10 registers" for REG-002's Timestamp block;
// REG-002 itself (the owning document, CHTR-DOC-003) says 12 and lists 12 --
// resolved in favor of REG-002, same reasoning.
// ============================================================================
//
// SCOPE OF THIS FIRST IMPLEMENTATION -- read before trusting this for
// anything beyond first HIL bring-up alongside RTL-001/RTL-002/RTL-003:
//
// IMPLEMENTED:
//   - ARCH-TIME-001/002: a 6-bit phase counter divides CORE_CLK by 50;
//     raw_timestamp_q increments exactly once every 50 valid edges (the
//     50th edge after release is the first tick, per spec). The raw counter
//     NEVER stops and is never gated by TIME_CONTROL.ENABLE -- that field is
//     forwarded into control_i (struct completeness) but deliberately unused
//     internally, per RTL-004_RevA.md SS3/ARCH-TIME-002's own explicit text
//     ("the legacy enable control reads constant one -- software has no
//     means to stop it") and ARCH-VAL-004 ("raw-time enable is constant
//     one").
//   - ARCH-TIME-003 (SNAPSHOT): TIME_SNAPSHOT.CAPTURE captures the raw
//     counter's PRE-cycle value into snapshot_raw_q (TIME_RAW_LO/HI's real
//     data source, per REG-002's own "Snapshot timestamp bits" register-
//     behavior text) and sets sticky SNAPSHOT_VALID evidence. "If SNAPSHOT
//     and tick coincide, the snapshot contains the value before that tick"
//     is automatically satisfied by ordinary nonblocking-assignment
//     semantics (every always_ff block reads the same pre-edge register
//     values this cycle, regardless of which block updates what).
//   - ARCH-TIME-004 (COMMIT): TIME_SYNC_COMMIT.COMMIT atomically copies the
//     staged 64-bit signed offset (TIME_SYNC_OFFSET_LO/HI) into
//     active_offset_q, increments the 16-bit wrapping update_sequence_q, and
//     sets active_valid_q (permanent RO live-state, per TIME_SYNC_STATUS)
//     plus sticky SYNC_VALID/SYNC_UPDATED evidence (both real W1C fields per
//     REG-0204, both set together by the same COMMIT -- a disclosed
//     interpretation, see NOT YET IMPLEMENTED below).
//   - ARCH-TIME-005: correlation-error detection uses a genuine 65-bit
//     sign-extended addition (raw zero-extended, active offset sign-
//     extended) so the low 64 bits are always the correct modulo-2^64
//     correlated-time result by construction; bit 64 vs. bit 63 disagreement
//     is the standard signed-overflow tell, latched as sticky ERROR evidence
//     only while correlation is actually enabled and active (disclosed
//     interpretation of "signed overflow/underflow", see below).
//   - ARCH-TIME-006 priority (reset, module reset, COMMIT, SNAPSHOT, tick,
//     clear evidence): reset/module_reset always checked first in every
//     always_ff block; within the COMMIT/SNAPSHOT/ERROR blocks, the real
//     event-setting branch is checked and unconditionally taken before any
//     same-cycle host clear-request is considered, so new evidence always
//     dominates a simultaneous clear (same pattern already proven in
//     dfc_rtl002.sv/dfc_rtl003.sv for their own W1C fields).
//   - TIME_CONTROL/TIME_STATUS/TIME_SNAPSHOT/TIME_RAW_LO/TIME_RAW_HI/
//     TIME_SYNC_OFFSET_LO/TIME_SYNC_OFFSET_HI/TIME_SYNC_COMMIT/
//     TIME_SYNC_STATUS/RTL004_EVT_OVERFLOW_STATUS/TIME_ACTIVE_OFFSET_LO/
//     TIME_ACTIVE_OFFSET_HI real cross-module forwarding via `control_i`/
//     `status_o`, generated by reggen.py v4 from
//     tools/reggen/rtl004_field_map.json.
//   - Real, counted own-event generation (event ID 0x0009, source index 3,
//     ARCH-002 Appendix C.5/C.7): subtypes 0 (correlation commit), 1
//     (correlation arithmetic error, edge-qualified same as dfc_rtl003.sv's
//     illegal-reserved-activity event), 2 (snapshot complete) -- each gated
//     by its own Appendix F.3 condition-mask bit (event_condition_enable_i
//     bits 0/1/2 respectively), same one-deep pending-slot/real-counted-
//     overflow shape already proven for RTL-002/RTL-003.
//   - Ready is unconditional 1'b1 once released from reset/module_reset --
//     this module has no multi-cycle startup sequence.
//
// NOT YET IMPLEMENTED / DISCLOSED INTERPRETATIONS -- real, disclosed gaps,
// not silent no-ops:
//   - `fault_o` (status_o.fault) is driven ONLY by correlation-arithmetic-
//     error evidence (error_q). ARCH-RTL004-001 also names "illegal command"
//     as a fault source, but ARCH-002's own dfc_rtl004_control_t declares
//     `time_snapshot__capture`/`time_sync_commit__commit` as plain 1-bit
//     command-pulse fields (unlike RTL-003's IRQ_ENABLE/IRQ_ACK/etc., which
//     ARE forwarded at their full 32-bit register width specifically so
//     RTL-003 can police its own reserved bits) -- there is no bit position
//     in `control_i` for this module to ever observe a host write's reserved
//     bits at all, so "illegal command" has no implementable content given
//     the current struct shape. This is the same underlying gap as
//     OPEN_ISSUES.md item 4 (RTL-001's own missing per-field reserved-bit
//     validation) manifesting differently here, not a new, separate defect.
//   - SYNC_VALID and SYNC_UPDATED (REG-0204 bits 2/3) are both set together
//     by every accepted COMMIT and are independently host-clearable. REG-002
//     does not explain how these two W1C bits are meant to differ in
//     practice (both fire on the identical event); implemented as two
//     genuinely independent sticky flags rather than inventing a
//     distinction the spec doesn't state.
//   - "Signed overflow/underflow" (ARCH-TIME-005) has no REG-002/ARCH-002
//     bit-exact detection algorithm. Implemented as the standard two's-
//     complement overflow tell on a 65-bit sign-extended addition (see
//     IMPLEMENTED above) -- a disclosed engineering interpretation, not a
//     cited spec fact.
//   - "If SNAPSHOT and COMMIT coincide, COMMIT occurs first for snapshot
//     correlation" (ARCH-TIME-004) has no observable effect in this
//     implementation: REG-002 exposes only the raw-timestamp half of a
//     SNAPSHOT (TIME_RAW_LO/HI), which never depends on the correlation
//     offset at all -- there is no separate frozen "correlated timestamp at
//     snapshot instant" register for this ordering to matter to. If a
//     bit-exact alternative is ever specified (e.g. a dedicated captured-
//     correlated-time register), only this module's SNAPSHOT handling needs
//     revisiting.
//   - `event_condition_enable_i` bit 3 ("event-slot overflow" per Appendix
//     F.3's RTL-004 allocation) is not separately wired to gate this
//     module's own pending-slot-overflow bookkeeping -- same precedent
//     already established by dfc_rtl002.sv/dfc_rtl003.sv, neither of which
//     gates its own overflow path on a dedicated condition-mask bit either.
//     With this whole port tied to a disclosed stub (64'h0) in
//     `dfc_rtl024.sv` (RTL-001 doesn't implement the underlying
//     CONDITION_MASK storage/forwarding mechanism, OPEN_ISSUES.md item 6),
//     none of this module's own events (subtypes 0/1/2) can actually fire in
//     this integration yet regardless -- a real, disclosed consequence, not
//     a defect in this file.
//   - `irq_condition_enable_i` is a real port per the Architecture catalog,
//     intentionally unused: RTL-004 generates no ordinary interrupt at all
//     (Appendix F.3: "no ordinary interrupt is generated" by RTL-004) --
//     there is no IRQ request of this module's own to gate with it. Tied off
//     in the module's own unused-signal sink below, not silently dropped.
//   - `operating_state_i`/`observational_mode_i` are real ports per the
//     Architecture catalog with no functional consumer in this
//     implementation -- RTL-004_RevA.md does not condition any of its
//     behavior on either. Intentionally consumed via the unused-signal sink
//     below, same pattern as dfc_rtl003.sv's identical case.
//
// Log anything this reveals as a genuine spec gap -- not a coding mistake
// -- in OPEN_ISSUES.md per CLAUDE.md's working rules.
// ============================================================================

module dfc_rtl004 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[3]

  // TOOLCHAIN-DRIVEN DEVIATION (confirmed real on the person's production
  // Yosys build, see dfc_rtl002.sv's header for the full account): a
  // package-scoped type cannot be a port's declared type on this exact
  // toolchain. Every such port here is a plain `logic [W-1:0]` vector sized
  // via generated `dfc_types_pkg::DFC_*_WIDTH` VALUE constants instead.
  input  logic [dfc_types_pkg::DFC_RTL004_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0]  status_o,

  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  // RTL-004-specific real port: the sole raw-time broadcast every other
  // module's timestamp_i consumes (see header note on the self-referencing
  // `timestamp_i` row this module does NOT implement).
  output logic [63:0] timestamp_o,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3: bits 0-2
                                                   // used (commit/error/
                                                   // snapshot); bit 3
                                                   // (event-slot overflow)
                                                   // and 4-63 intentionally
                                                   // unused -- see header
  input  logic [63:0] irq_condition_enable_i      // real port, intentionally
                                                   // unused -- see header
                                                   // ("no ordinary interrupt")
);

  // ---- control_i field extraction (bit-slice wires, generated _HI/_LO
  // constants -- same confirmed-safe pattern as dfc_rtl002.sv/dfc_rtl003.sv) ----
  wire        ctl_time_enable = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_CONTROL__ENABLE_HI];
                                          // extracted for struct completeness
                                          // only -- never used to gate the
                                          // raw counter, see header
  wire        ctl_correlation_enable = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_CONTROL__CORRELATION_ENABLE_HI];
  wire        ctl_clear_sync_updated = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_STATUS__SYNC_UPDATED_HI];
  wire        ctl_clear_error        = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_STATUS__ERROR_HI];
  wire        ctl_snapshot_capture   = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_SNAPSHOT__CAPTURE_HI];
  wire [31:0] ctl_offset_lo =
    control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_SYNC_OFFSET_LO__OFFSET_LO_HI:dfc_types_pkg::DFC_RTL004_CONTROL__TIME_SYNC_OFFSET_LO__OFFSET_LO_LO];
  wire [31:0] ctl_offset_hi =
    control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_SYNC_OFFSET_HI__OFFSET_HI_HI:dfc_types_pkg::DFC_RTL004_CONTROL__TIME_SYNC_OFFSET_HI__OFFSET_HI_LO];
  wire        ctl_commit              = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_SYNC_COMMIT__COMMIT_HI];
  wire        ctl_clear_snapshot_valid = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_STATUS__SNAPSHOT_VALID_HI];
  wire        ctl_clear_sync_valid     = control_i[dfc_types_pkg::DFC_RTL004_CONTROL__TIME_STATUS__SYNC_VALID_HI];

  // Real host-initiated clear-request for RTL004_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW
  // (REG-002 0x0224, contract REG-0224) -- closes this module's own instance
  // of the already-known EVENT_OVERFLOW gap (see header item 2).
  wire        ctl_clear_event_overflow =
    control_i[dfc_types_pkg::DFC_RTL004_CONTROL__RTL004_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire [63:0] staged_offset = {ctl_offset_hi, ctl_offset_lo};

  // ==========================================================================
  // Always-running raw timestamp (ARCH-TIME-001/002): 6-bit phase counter
  // divides CORE_CLK by 50; a tick (raw increment) fires when phase's PRIOR
  // value was 49 -- i.e. the 50th valid edge after release is the first
  // tick, matching the spec exactly.
  // ==========================================================================
  logic [63:0] raw_timestamp_q;
  logic [5:0]  phase_q;
  wire         tick = (phase_q == 6'd49);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      raw_timestamp_q <= 64'd0;
      phase_q         <= 6'd0;
    end else if (module_reset_i) begin
      raw_timestamp_q <= 64'd0;
      phase_q         <= 6'd0;
    end else if (tick) begin
      raw_timestamp_q <= raw_timestamp_q + 64'd1;
      phase_q         <= 6'd0;
    end else begin
      phase_q <= phase_q + 6'd1;
    end
  end

  assign timestamp_o = raw_timestamp_q;

  // ==========================================================================
  // SNAPSHOT (ARCH-TIME-003): captures the PRE-cycle raw value (nonblocking-
  // assignment semantics automatically give "value before a coincident
  // tick", see header). SNAPSHOT_VALID is real, host-clearable W1C sticky
  // evidence; a fresh capture dominates a simultaneous clear attempt.
  // ==========================================================================
  logic [63:0] snapshot_raw_q;
  logic        snapshot_valid_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      snapshot_raw_q   <= 64'd0;
      snapshot_valid_q <= 1'b0;
    end else if (module_reset_i) begin
      snapshot_raw_q   <= 64'd0;
      snapshot_valid_q <= 1'b0;
    end else if (ctl_snapshot_capture) begin
      snapshot_raw_q   <= raw_timestamp_q;
      snapshot_valid_q <= 1'b1;
    end else if (ctl_clear_snapshot_valid) begin
      snapshot_valid_q <= 1'b0;
    end
  end

  // ==========================================================================
  // Correlation offset / COMMIT (ARCH-TIME-004/005): a real 65-bit sign-
  // extended addition of the LIVE raw counter and the currently ACTIVE
  // offset, continuously evaluated -- the low 64 bits are always the correct
  // modulo-2^64 correlated-time result by construction; bit 64 vs. bit 63
  // disagreement is the standard signed-overflow tell (disclosed
  // interpretation, see header).
  // ==========================================================================
  logic [63:0] active_offset_q;
  logic        active_valid_q;
  logic [15:0] update_sequence_q;
  logic        sync_valid_q;
  logic        sync_updated_q;
  logic        error_q;
  logic        correlation_would_overflow_prev_q;

  wire [64:0] raw_ext              = {1'b0, raw_timestamp_q};
  wire [64:0] active_offset_ext    = {{1{active_offset_q[63]}}, active_offset_q};
  wire [64:0] correlated_sum_ext   = raw_ext + active_offset_ext;
  wire        correlation_would_overflow =
    ctl_correlation_enable && active_valid_q &&
    (correlated_sum_ext[64] != correlated_sum_ext[63]);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      active_offset_q                   <= 64'd0;
      active_valid_q                    <= 1'b0;
      update_sequence_q                 <= 16'd0;
      sync_valid_q                      <= 1'b0;
      sync_updated_q                    <= 1'b0;
      error_q                           <= 1'b0;
      correlation_would_overflow_prev_q <= 1'b0;
    end else if (module_reset_i) begin
      active_offset_q                   <= 64'd0;
      active_valid_q                    <= 1'b0;
      update_sequence_q                 <= 16'd0;
      sync_valid_q                      <= 1'b0;
      sync_updated_q                    <= 1'b0;
      error_q                           <= 1'b0;
      correlation_would_overflow_prev_q <= 1'b0;
    end else begin
      // COMMIT dominates a simultaneous clear of SYNC_VALID/SYNC_UPDATED
      // (ARCH-TIME-006 priority: COMMIT outranks "clear evidence").
      if (ctl_commit) begin
        active_offset_q   <= staged_offset;
        active_valid_q    <= 1'b1;
        update_sequence_q <= update_sequence_q + 16'd1;
        sync_valid_q      <= 1'b1;
        sync_updated_q    <= 1'b1;
      end else begin
        if (ctl_clear_sync_valid)   sync_valid_q   <= 1'b0;
        if (ctl_clear_sync_updated) sync_updated_q <= 1'b0;
      end

      // A new arithmetic error dominates a simultaneous clear (RTL-004_RevA
      // SS3/ARCH-TIME-006's own explicit text).
      if (correlation_would_overflow) error_q <= 1'b1;
      else if (ctl_clear_error)       error_q <= 1'b0;

      correlation_would_overflow_prev_q <= correlation_would_overflow;
    end
  end

  wire arithmetic_error_rising =
    correlation_would_overflow && !correlation_would_overflow_prev_q;

  // ==========================================================================
  // Event generation (RTL-004 is event source index 3, event ID 0x0009;
  // ARCH-002 Appendix C.5/C.7) -- real implementation, same one-deep
  // pending-record shape already proven in dfc_rtl002.sv/dfc_rtl003.sv.
  // Subtypes: 0 correlation commit, 1 correlation arithmetic error
  // (edge-qualified, same reasoning as dfc_rtl003.sv's illegal-reserved-
  // activity event), 2 snapshot complete -- each gated by its own Appendix
  // F.3 condition-mask bit.
  // ==========================================================================
  localparam logic [15:0] EVT_ID_TIMESTAMP        = 16'h0009;
  localparam logic [7:0]  EVT_SUBTYPE_COMMIT       = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_ARITH_ERROR  = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_SNAPSHOT     = 8'd2;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL004  = 8'd3;  // ARCH-002 C.5 index 3

  wire commit_event_this_cycle   = ctl_commit           && event_condition_enable_i[0];
  wire error_event_this_cycle    = arithmetic_error_rising && event_condition_enable_i[1];
  wire snapshot_event_this_cycle = ctl_snapshot_capture  && event_condition_enable_i[2];

  wire evt_candidate_valid =
    commit_event_this_cycle || error_event_this_cycle || snapshot_event_this_cycle;

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = raw_timestamp_q;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL004;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO]   = EVT_ID_TIMESTAMP;
    // Detail: ARCH-002's own event registry text for 0x0009 says "update
    // sequence or error detail" without specifying which subtype gets
    // which -- disclosed interpretation: the post-commit update_sequence_q
    // value for the commit subtype (the one genuinely new piece of data a
    // host couldn't otherwise correlate to this exact event), zero for the
    // other two subtypes (nothing further to disclose beyond the subtype
    // and timestamp already carried).
    if (commit_event_this_cycle) begin
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]      = EVT_SUBTYPE_COMMIT;
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO+8 +: 16]   = update_sequence_q + 16'd1;
    end else if (error_event_this_cycle) begin
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]      = EVT_SUBTYPE_ARITH_ERROR;
    end else if (snapshot_event_this_cycle) begin
      evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]      = EVT_SUBTYPE_SNAPSHOT;
    end
  end

  logic                                              evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0]  evt_record_q;
  logic                                              event_overflow_q;
  logic [15:0]                                       event_drop_count_q;

  // ---- EVENT_OVERFLOW clear-vs-new-evidence priority (REG-0224's own
  // documented simultaneous-condition priority for this field: "reset/
  // disable, then new evidence, then clear") -- same reasoning and same
  // algebraic restatement as dfc_rtl002.sv/dfc_rtl003.sv's identical fix.
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
          // slot still occupied -- a real, counted overflow, not a
          // silent drop.
          if (event_drop_count_q != 16'hFFFF) event_drop_count_q <= event_drop_count_q + 16'd1;
          event_overflow_q <= 1'b1;
        end
      end

      // Real host clear-request for EVENT_OVERFLOW (REG-0224). DROP_COUNT is
      // a separate RO field with no clear side effect of its own (REG-002's
      // own register-level side-effect text: "DROP_COUNT is read-only"), so
      // this clear only ever affects event_overflow_q. Gated so new overflow
      // evidence landing this same cycle wins over a simultaneous clear
      // attempt.
      if (ctl_clear_event_overflow && !overflow_sets_this_cycle) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;

  // ==========================================================================
  // status_o packing (dfc_rtl004_status_t, 169 bits, ARCH-002 Appendix B).
  // status_comb is a plain flat vector, not the package struct type -- same
  // reasoning as dfc_rtl002.sv/dfc_rtl003.sv's status_comb (declared-type
  // toolchain limitation). Each field written via its exact bit index/range,
  // sliced using generated `dfc_types_pkg::DFC_RTL004_STATUS__<FIELD>_HI`/
  // `_LO` constants.
  // ==========================================================================
  logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0] status_comb;

  always_comb begin
    status_comb = '0;

    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__READY_HI] = 1'b1;  // no
                                                                       // multi-
                                                                       // cycle
                                                                       // startup
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__FAULT_HI]          = error_q;  // see header:
                                                                                  // "illegal command"
                                                                                  // has no
                                                                                  // implementable
                                                                                  // content here
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;

    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_STATUS__RUNNING_HI]       = 1'b1;
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_STATUS__SNAPSHOT_VALID_HI] = snapshot_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_STATUS__SYNC_VALID_HI]     = sync_valid_q;
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_STATUS__SYNC_UPDATED_HI]   = sync_updated_q;
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_STATUS__ERROR_HI]          = error_q;

    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_RAW_LO__RAW_LO_HI:dfc_types_pkg::DFC_RTL004_STATUS__TIME_RAW_LO__RAW_LO_LO]
      = snapshot_raw_q[31:0];
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_RAW_HI__RAW_HI_HI:dfc_types_pkg::DFC_RTL004_STATUS__TIME_RAW_HI__RAW_HI_LO]
      = snapshot_raw_q[63:32];

    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_SYNC_STATUS__UPDATE_SEQUENCE_HI:dfc_types_pkg::DFC_RTL004_STATUS__TIME_SYNC_STATUS__UPDATE_SEQUENCE_LO]
      = update_sequence_q;
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_SYNC_STATUS__ACTIVE_VALID_HI] = active_valid_q;

    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL004_STATUS__EVENT_DROP_COUNT_LO]
      = event_drop_count_q;

    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_ACTIVE_OFFSET_LO__OFFSET_LO_HI:dfc_types_pkg::DFC_RTL004_STATUS__TIME_ACTIVE_OFFSET_LO__OFFSET_LO_LO]
      = active_offset_q[31:0];
    status_comb[dfc_types_pkg::DFC_RTL004_STATUS__TIME_ACTIVE_OFFSET_HI__OFFSET_HI_HI:dfc_types_pkg::DFC_RTL004_STATUS__TIME_ACTIVE_OFFSET_HI__OFFSET_HI_LO]
      = active_offset_q[63:32];
  end

  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): operating_state_i/
  // observational_mode_i/irq_condition_enable_i/event_condition_enable_i[63:3]
  // and ctl_time_enable (struct-completeness only, see header) are real
  // signals with no functional consumer in this implementation. Intentionally
  // consumed here, not silently dropped. ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i ^
                            (|irq_condition_enable_i) ^ (|event_condition_enable_i[63:3]) ^
                            ctl_time_enable;

endmodule : dfc_rtl004
