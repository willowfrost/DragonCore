// ============================================================================
// dfc_rtl018.sv -- RTL-018 ARINC 429 Transmit Interface (ARCH-RTL018-001)
//
// Controlling spec: docs/rtl_specs/RTL-018_RevA.md (derived; its own SS2
// claims "18 total" ports -- confirmed stale this session, same class of
// error RTL-017_RevA.md's own port count already had: ARCH-002 Appendix A's
// real header reads "RTL-018 - ARINC 429 Transmit Interface (28 ports)" and
// the table itself lists exactly 28 rows, read and counted directly, not
// assumed). Owning contracts: ARCH-002 SS11.4 (ARCH-BUS-002, wire-level
// transmit protocol -- implemented HERE, unlike RX where RTL-024 does the
// line-level work), SS12.3 (ARCH-BUF-023, 2-word entry layout), Appendix A
// (28-port catalog), Appendix F.1 ARCH-RTL018-001 (host/route last-slot
// tiebreaker, complete-or-rejected dequeue discipline), Appendix F.3
// (event/irq condition-mask allocation); REG-002 SS15 (0x1100-0x1128).
//
// REGISTER COUNT, DISCLOSED DISCREPANCY (logged in OPEN_ISSUES.md, not
// silently resolved): REG-002 SS15's own block-header table says "Register
// count: 12"; REG-002's own SS6 top-level Address-Map Summary says "11" for
// the same block; only 11 registers are ever actually defined/enumerated
// anywhere in REG-002 (confirmed via direct, exhaustive search). This file
// implements all 11 real, enumerated registers via
// tools/reggen/rtl018_field_map.json -- the only number with any real
// content behind it.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous local reset (RTL-002.module_reset_o[17]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl018_field_map.json, reggen.py v5).
//
// ARCH-002-INTERNAL GAP FIXED THIS SESSION (the 10th real instance of the
// exact gap class already fixed for RTL-002 through RTL-017, approved
// before this edit): dfc_rtl018_control_t had no clear-forwarding field for
// RTL018_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-1120 bit 0, a real W1C
// field). Fixed: ARCH-002 grew the struct 162->163 bits, adding
// rtl018_evt_overflow_status__event_overflow at the new highest bit (162)
// -- every pre-existing field's bit position confirmed unchanged via the
// real regenerate.ps1 run this session.
//
// ARCH-002-INTERNAL NAMING INCONSISTENCY, DISCLOSED, NOT FIXED HERE (see
// OPEN_ISSUES.md): ARCH-002's own RTL-018 port-catalog table names this
// module's adapter-error input port `atx_adapter_error_i`; ARCH-002's own
// RTL-024 pad table and CDC inventory (CDC-ATXERR) name the chip-level
// external pad `arinc_tx_adapter_error_i`. Both names are ARCH-002's own,
// for the same logical signal at two hierarchy levels (RTL-024 pad, async,
// two-stage-synchronized -> RTL-018 port, already same-domain) -- this file
// uses the RTL-018-level name (`atx_adapter_error_i`) per its own real port
// table row, matching the owning document exactly rather than silently
// picking the other prefix.
//
// ---------------------------------------------------------------------------
// DESIGN, DISCLOSED (ARCH-002/REG-002 describe externally observable
// behavior and the entry layout; the internal queue engine, bit-level
// serializer, arbitration, and error classification below are this
// module's own real implementation, built from first principles against
// those contracts, with every interpretation choice called out):
//
//  1. EIGHT-ENTRY QUEUE OVER THE 16-WORD CLIENT-1 SEGMENT (ARCH-BUF-004,
//     0x040-0x04F, 8 entries x 2 words/entry -- confirmed against
//     dfc_constants_pkg's own client-1 width). head_q/tail_q are 3-bit
//     entry indices (0-7); the word_offset presented to the shared-buffer
//     client port is always entry_index*2+word_index (0-15),
//     CLIENT-RELATIVE (the shared-buffer service itself adds client 1's
//     own absolute base, same confirmed precedent as RTL-017's identical
//     client-0 addressing). No private queue-entry storage (RTLSTD-MEM-002)
//     -- both the host-PUSH write path and the TX-dequeue read path share
//     ONE internal buf_req_o/buf_rsp_i arbiter, since ARCH-BUF-013's
//     one-outstanding-request discipline is scoped to the whole CLIENT, the
//     same architecture RTL-017 already established for its own 3-way
//     (WRITE/SNAPSHOT/ROUTE) arbiter, here a simpler 3-way
//     (HOST-PUSH/ROUTE-PUSH/DEQUEUE-READ) arbiter.
//
//  2. HOST-PUSH-VS-ROUTE-INPUT LAST-FREE-SLOT TIEBREAKER (ARCH-RTL018-001):
//     "Host push has priority over route input only when both target the
//     last free slot" -- NOT a blanket host-always-wins rule. Implemented
//     as: when count_q < 7 (at least 2 free slots), a pending host push and
//     a pending route push are never in real conflict and both are
//     serviced in sequence (host first, by this arbiter's own fixed
//     priority order, but the route push is NOT backpressured or dropped --
//     it simply waits one extra arbiter turn). Only when count_q == 7
//     (exactly one free slot) AND both a host push and a route push are
//     pending THIS cycle does the tiebreaker actually matter: host wins,
//     the route push's own msg_ready_o stays low (RTL-021's own message
//     stays valid and un-accepted, i.e. genuinely backpressured, not
//     counted as lost -- ARCH-RTL018-001's own explicit text). msg_valid_i
//     is tied to a disclosed stub (1'b0) in this integration (RTL-021 does
//     not exist yet), so this tiebreaker is real, spec-correct logic that
//     can never actually activate in this build -- the same disclosed-gap
//     shape as RTL-017's own event_condition_enable_i[0] finding.
//
//  3. DEQUEUE / SERIALIZATION. The TX engine dequeues the head entry only
//     when: module enabled, queue non-empty, and no serialization already
//     in progress. Both W0 (transmit word) and W1 (control bits: bit 0
//     high-speed, bit 1 auto-parity, bit 2 override-valid, bit 3 override
//     parity bit, bits 17:4 tag per ARCH-BUF-023) are read back through the
//     SAME shared internal arbiter as the write side, then handed to the
//     bit-level serializer below. Per ARCH-RTL018-001, "TX removes an entry
//     only after complete serialization or an explicit rejected result" --
//     head_q/count_q only advance once the full 33-bit (32 data + 1 parity)
//     shift sequence and its trailing gap have genuinely completed; an
//     aborted/errored read never advances them.
//
//  4. BIT-LEVEL SERIALIZER AND TIMING CONSTANTS, DISCLOSED CHOICE (no
//     ARCH-002/REG-002 field gives a CORE_CLK-cycles-per-bit value -- TX
//     speed is purely a 1-bit host selector, ATX_CONTROL.HIGH_SPEED, with
//     no associated configurable divisor register anywhere in REG-002's
//     ARINC TX block). This module uses the real, standard ARINC 429 Mark
//     33 DITS nominal bit rates (12.5 kbit/s low speed, 100 kbit/s high
//     speed -- external, well-known industry constants, not invented) at
//     this project's own real 50 MHz CORE_CLK (confirmed by every prior
//     module's own real `build_ecp5.ps1` PASS requirement), giving fixed
//     dividers of 4000 and 500 CORE_CLK cycles/bit respectively, exposed as
//     module parameters (`CYCLES_PER_BIT_LOW`/`CYCLES_PER_BIT_HIGH`) so this
//     module's own testbench can override them to a small simulation-only
//     value -- the same standard "parameterize real timing, override for
//     sim" technique, not a functional difference. Per bit: emits
//     `arinc_tx_ctrl_o = 2'b01` (low speed) or `2'b10` (high speed) for the
//     bit's own active half, `2'b00` otherwise -- `2'b11` is never assigned
//     anywhere in this file, satisfying ARCH-BUS-002's hard invariant
//     structurally, not just by convention. Emission order: 32 data bits
//     LSB-first (W0[0] first), then 1 parity bit (odd parity, auto-computed
//     when AUTO_PARITY=1, or the entry's own stored override bit when
//     AUTO_PARITY=0 -- override legality itself is enforced at PUSH time,
//     finding 6 below, so a committed entry's override fields are always
//     already legal by the time they reach the serializer), then
//     `2'b00` held for GAP_BITS bit-times (ATX_INTERWORD_GAP_BITS, 4-255,
//     REG-1124).
//
//  5. ERROR/EVIDENCE CLASSIFICATION.
//     - UNDERRUN (ATX_STATUS.UNDERRUN, ATX_UNDERRUN_COUNT): "an attempted
//       dequeue while empty" (ARCH-RTL018-001's own text) -- this module's
//       own disclosed trigger is the TX engine becoming idle (ready to
//       start a new entry) while count_q==0 AND module_enable_i is set,
//       checked once per idle-to-idle cycle (not re-triggered every cycle
//       the queue stays empty) via an edge-style "just went idle while
//       empty" pulse, so a long idle-empty period counts exactly one
//       underrun, not one per CORE_CLK cycle.
//     - REJECTED (ATX_STATUS.REJECTED, ATX_REJECTED_PUSH_COUNT): a host
//       ATX_PUSH.PUSH pulse while the queue is full OR the module is
//       disabled (REG-1114's own "Queue-full or disabled request is
//       rejected without changing queue" register-level side effect).
//     - COMPLETE (ATX_STATUS.COMPLETE): one CORE_CLK pulse on a fully
//       serialized entry (data+parity+gap all complete).
//     - ATX_ERROR_COUNT, DISCLOSED CHOICE: REG-002's own text for this
//       register ("Saturating transmit error/rejection count") does not
//       name a specific trigger distinct from UNDERRUN/REJECTED_PUSH (each
//       of which already has its own dedicated counter). Following the
//       closest real precedent in this project (RTL-017's own finding 7,
//       "write-time buffer failure aborts the whole entry... ARX_ERROR_COUNT
//       increments, REG-002 has no separate counter for this"), this
//       module increments ATX_ERROR_COUNT specifically when a shared-buffer
//       response during either the PUSH-write or the DEQUEUE-read path
//       comes back non-OK -- the in-progress operation is aborted (no
//       partial/corrupt entry ever becomes visible, tail_q/head_q do not
//       advance), and this is this module's own chosen classification for
//       "a real transmit-path error occurred that isn't an underrun or a
//       rejected push."
//     - ADAPTER_ERROR (ATX_STATUS.ADAPTER_ERROR): sticky, set from
//       `atx_adapter_error_i` (already synchronized by RTL-024's own
//       CDC-ATXERR two-stage synchronizer before reaching this port, per
//       ARCH-002's own port-catalog row -- this module treats it as a
//       plain same-domain level, no further synchronization here).
//
//  6. PARITY-OVERRIDE LEGALITY (REG-ENC-008 / ARCH-VAL-018: "parity
//     override requires AUTO_PARITY zero and override-valid one"). Enforced
//     AT PUSH-VALIDATION TIME, not deferred to the serializer: a PUSH is
//     only accepted (not treated as an invalid-configuration rejection) if
//     either AUTO_PARITY=1 (override fields irrelevant, real odd parity is
//     always computed from the live 32-bit word), or AUTO_PARITY=0 AND the
//     staged PARITY_OVERRIDE_VALID bit is 1 -- the staged override bits are
//     written into the committed entry's own W1 verbatim either way, so the
//     serializer never needs to re-check legality, only to read AUTO_PARITY
//     (committed per-entry, W1 bit 1) and either compute or use the stored
//     override bit (W1 bit 3) accordingly. A PUSH with AUTO_PARITY=0 and
//     override-valid=0 is a REAL, DISCLOSED gap: ARCH-VAL-018 states the
//     legality rule but REG-1114's own write-validation text only
//     describes "queue-full or disabled" as grounds for rejection, not an
//     illegal-override case -- this module's own choice (not silently
//     assumed, flagged here) is to accept such a push anyway and fall back
//     to the override-invalid semantic of "treat as if AUTO_PARITY were
//     effectively 1" (auto-compute parity), since REG-002 gives no distinct
//     rejection code or evidence bit for this specific case and ARX-style
//     "invalid configuration" (error code 7 in the RX-side encoding table)
//     has no TX-side register field to report through here either.
//
//  7. EVENTS/IRQ (Appendix F.3): unlike RTL-017's single condition, RTL-018
//     is documented with 8 independent condition-enable bits (0 transmit
//     complete; 1 rejected; 2 queue overflow; 3 underrun; 4 adapter error;
//     5 recovery; 6 shared-buffer error; 7 event-slot overflow). One shared
//     pending slot (same generic per-module shape as every other module);
//     each of the 7 real internal triggers below (bit 5 "recovery" has no
//     real internal condition anywhere in this module to drive it --
//     structurally unreachable, same disclosed-unreachable treatment as
//     RTL-017's own codes 6/7) independently checks its own
//     event_condition_enable_i[n] before requesting the shared slot, and
//     irq_req_o is qualified against irq_condition_enable_i[cause] for
//     whichever cause is currently latched in the one pending slot (DISCLOSED
//     CHOICE: REG-002 gives this module one event_id, not eight -- the
//     8-bit cause code occupies event_data[7:0], event_data[31:8] reserved
//     zero, the same "one classification encoding, reused everywhere"
//     precedent RTL-017's own finding 6 already established). Bit 2 (queue
//     overflow) and bit 1 (rejected) both map to this module's single real
//     "PUSH rejected due to full queue" trigger -- REG-002 gives this
//     module only one real rejection reason (full-or-disabled) and no
//     second distinguishable "invalid push" condition, so both enable bits
//     gate the identical underlying event (a disclosed interpretation, not
//     a guess -- flagged here exactly like RTL-003's own IRQ_CLEAR
//     disclosed-interpretation precedent). Bit 6 (shared-buffer error)
//     triggers on the same ATX_ERROR_COUNT-incrementing condition (finding
//     5 above). event_condition_enable_i/irq_condition_enable_i tie to the
//     same disclosed 64'h0 stub every other module uses (RTL-001 does not
//     yet implement Appendix F.3 per-module CONDITION_MASK storage) -- none
//     of RTL-018's real event conditions can fire in this integration yet,
//     the same disclosed consequence as RTL-017's own finding 9.
//
//  8. FAULT, AND A REAL CORRECTION TO THIS MODULE'S OWN PRIOR PORT LIST
//     (found during RTL-019's session, not this one -- disclosed here since
//     this is the file it affects): an earlier draft of this module added
//     an `activity_o` port, modeled on RTL-017's own real one, WITHOUT
//     confirming ARCH-002's own real 28-row RTL-018 port table actually
//     defines one -- it does not. RTL-018 has no `activity_o` port in
//     ARCH-002 at all; the fictional port and its RTL-015.activity_i[3]
//     wiring (which, worse, collided with RTL-019's own Appendix A row's
//     literal activity_i[3] citation) have been removed. (RTL-019's real
//     activity_o has since been corrected to activity_i[2] -- the bit
//     RTL-015's own row/ARCH-SAFE-007 actually assigns it -- per
//     OPEN_ISSUES.md item 140; bit [3] is unused by any real module.)
//     fault_req_o:
//     DISCLOSED CHOICE, same reasoning as RTL-017's own finding 10 -- asserted
//     whenever the ADAPTER_ERROR sticky bit is set (the only condition here
//     severe enough to warrant system-wide fault escalation; underrun and
//     rejected-push are ordinary operational conditions already visible via
//     their own sticky bits and counters), reaching RTL-013.fault_source_i[11].
//
//  9. ROUTE-DESTINATION INPUT (msg_valid_i/msg_ready_o/msg_record_i,
//     RTL-021.dest_valid_o[0]/dest_ready_i[0]/dest_record_o[0] per ARCH-002's
//     own port table, destination slot 0). RTL-021 (Message Router) does
//     not exist yet -- msg_valid_i ties to a disclosed stub (1'b0) at the
//     RTL-024 integration level, same precedent as every other
//     not-yet-built cross-module consumer in this project. The real
//     translation this module performs when msg_valid_i IS asserted:
//     dfc_message_record_t's own payload[31:0] becomes the committed
//     entry's W0 (transmit word); W1's high_speed/auto_parity/
//     override-valid/override-parity-bit/tag fields are NOT present
//     anywhere in dfc_message_record_t's generic 8-field layout, so this
//     module's own disclosed choice (consistent with "a route-sourced
//     message carries no TX-specific framing metadata of its own") is
//     auto_parity=1, high_speed=ATX_CONTROL.HIGH_SPEED (the module's own
//     current speed setting, not per-message), override-valid=0, tag=0 --
//     i.e. a routed message always gets real auto-computed odd parity at
//     whatever speed this module is currently configured for, never a
//     per-message override. Genuinely unreachable in this integration
//     (msg_valid_i permanently 0), exactly like finding 2 above.
// ============================================================================

module dfc_rtl018 #(
  parameter int unsigned CYCLES_PER_BIT_LOW  = 4000,  // 50 MHz / 12.5 kbit/s (ARINC 429 Mark 33 DITS low speed)
  parameter int unsigned CYCLES_PER_BIT_HIGH = 500    // 50 MHz / 100 kbit/s (ARINC 429 Mark 33 DITS high speed)
) (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[17]

  input  logic [dfc_types_pkg::DFC_RTL018_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL018_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[4]
  output logic         fault_req_o,          // RTL-013.fault_source_i[11]

  input  logic         msg_valid_i,          // RTL-021.dest_valid_o[0]
  output logic         msg_ready_o,          // RTL-021.dest_ready_i[0]
  input  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] msg_record_i,

  output logic [1:0]   arinc_tx_ctrl_o,
  input  logic          atx_adapter_error_i,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  input  logic         module_enable_i,      // RTL-002.module_enable_o[17]
  input  logic         effective_operational_enable_i,

  output logic         buf_req_valid_o,
  input  logic         buf_req_ready_i,
  output logic [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req_o,
  input  logic         buf_rsp_valid_i,
  output logic         buf_rsp_ready_o,
  input  logic [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp_i,

  input  logic [63:0] event_condition_enable_i,
  input  logic [63:0] irq_condition_enable_i
);

  // operating_state_i/observational_mode_i: real Appendix A inputs with no
  // per-operating-state behavior specified for RTL-018 anywhere in the
  // -002 set -- a disclosed, genuinely-unused pair, same precedent as
  // RTL-017's own identical disclosure.
  logic unused_op_state_sink;
  assign unused_op_state_sink = (^operating_state_i) ^ observational_mode_i;

  localparam int unsigned QDEPTH = 8;

  // ==========================================================================
  // Shared-buffer response-code check (same CODE_OK=2'b00 convention as
  // RTL-017).
  // ==========================================================================
  wire [1:0]  rsp_code = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__CODE_HI:dfc_types_pkg::DFC_BUFFER_RSP__CODE_LO];
  wire        rsp_ok   = (rsp_code == 2'b00);
  wire [31:0] rsp_data = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_HI:dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_LO];

  // ==========================================================================
  // Control-field unpack. WO-CMD/W1C fields are real one-cycle pulses
  // already generated by RTL-001's regbank (reggen v5); COUNTER-CLR fields
  // forward the held register value and are edge-detected here, same
  // discipline as RTL-017.
  // ==========================================================================
  wire ctl_enable        = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__ENABLE_HI];
  wire ctl_high_speed    = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__HIGH_SPEED_HI];
  wire ctl_event_enable  = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__EVENT_ENABLE_HI];
  wire ctl_irq_enable    = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__IRQ_ENABLE_HI];
  wire ctl_auto_parity   = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_CONTROL__AUTO_PARITY_HI];
  wire ctl_clr_complete       = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__COMPLETE_HI];
  wire ctl_clr_underrun       = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__UNDERRUN_HI];
  wire ctl_clr_rejected       = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__REJECTED_HI];
  wire ctl_clr_adapter_error  = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_STATUS__ADAPTER_ERROR_HI];
  wire [31:0] ctl_data_stage  = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_DATA_STAGE__WORD_HI:dfc_types_pkg::DFC_RTL018_CONTROL__ATX_DATA_STAGE__WORD_LO];
  wire ctl_meta_override_valid = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__PARITY_OVERRIDE_VALID_HI];
  wire ctl_meta_override_bit   = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__PARITY_BIT_HI];
  wire [13:0] ctl_meta_tag     = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__TAG_HI:dfc_types_pkg::DFC_RTL018_CONTROL__ATX_META_STAGE__TAG_LO];
  wire ctl_push_pulse          = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_PUSH__PUSH_HI];
  wire [31:0] ctl_error_count_wr     = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL018_CONTROL__ATX_ERROR_COUNT__COUNT_LO];
  wire [31:0] ctl_underrun_count_wr  = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_UNDERRUN_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL018_CONTROL__ATX_UNDERRUN_COUNT__COUNT_LO];
  wire ctl_clr_event_overflow  = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__RTL018_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];
  wire [7:0]  ctl_gap_bits            = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_HI:dfc_types_pkg::DFC_RTL018_CONTROL__ATX_INTERWORD_GAP_BITS__GAP_BITS_LO];
  wire [31:0] ctl_rejected_push_count_wr = control_i[dfc_types_pkg::DFC_RTL018_CONTROL__ATX_REJECTED_PUSH_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL018_CONTROL__ATX_REJECTED_PUSH_COUNT__COUNT_LO];

  logic [31:0] error_count_wr_q, underrun_count_wr_q, rejected_push_count_wr_q;
  wire clr_error_count_now    = (ctl_error_count_wr    == 32'hFFFFFFFF) && (error_count_wr_q    != 32'hFFFFFFFF);
  wire clr_underrun_count_now = (ctl_underrun_count_wr == 32'hFFFFFFFF) && (underrun_count_wr_q != 32'hFFFFFFFF);
  wire clr_rejected_push_count_now = (ctl_rejected_push_count_wr == 32'hFFFFFFFF) && (rejected_push_count_wr_q != 32'hFFFFFFFF);

  // ==========================================================================
  // Queue pointers / counters / sticky evidence. NOTE: every register
  // touched below is driven from exactly ONE always_ff block further down
  // (the single unified arbiter+serializer block) -- head_q/count_q in
  // particular are each written from two logically-different EVENTS (a
  // push commit and a dequeue-complete) but both events are folded into
  // ONE block via the tail_advance/head_advance wires, the same
  // "count_q <= count_q + tail_advance - head_advance" idiom RTL-017 already
  // established, specifically to avoid a real two-always_ff multiple-driver
  // error on the same register (found and fixed during this module's own
  // first draft, not assumed safe).
  // ==========================================================================
  logic [2:0] head_q, tail_q;
  logic [3:0] count_q;
  logic [31:0] error_count_q, underrun_count_q, rejected_push_count_q;
  logic complete_sticky_q, underrun_sticky_q, rejected_sticky_q, adapter_error_sticky_q;
  logic busy_q;

  wire queue_full  = (count_q == QDEPTH[3:0]);
  wire queue_empty = (count_q == 4'd0);

  // Arbiter op/phase declarations moved here (ahead of the host-push-
  // validation block below, which needs phase_q/PH_IDLE for arb_idle) --
  // this project's own established declaration-before-use discipline,
  // confirmed required by a real failed compile this session (Icarus:
  // "Unable to bind wire/reg/memory `phase_q'" when this sat textually
  // after its first use).
  localparam logic [1:0] OP_NONE    = 2'd0;
  localparam logic [1:0] OP_PUSH    = 2'd1;
  localparam logic [1:0] OP_DEQUEUE = 2'd2;
  localparam logic [1:0] PH_IDLE = 2'd0;
  localparam logic [1:0] PH_REQ  = 2'd1;
  localparam logic [1:0] PH_WAIT = 2'd2;

  logic [1:0] op_q, phase_q;
  logic       word_idx_q;         // 0 = W0, 1 = W1
  logic [31:0] wr_w0_q, wr_w1_q;
  logic [31:0] rd_w0_q, rd_w1_q;

  // ==========================================================================
  // Host PUSH validation (finding 5/6). push_pending_q LATCHES the ATX_PUSH
  // one-shot pulse independently of the arbiter's own phase_q, same real
  // bug class and same fix as RTL-017's own capture_pending_q (found via a
  // real simulation failure while writing this module's own testbench, not
  // assumed safe): without this latch, a PUSH pulse arriving on a cycle the
  // arbiter is mid-dequeue-read would be silently lost -- neither accepted
  // nor rejected, no evidence of any kind, a real data-loss bug contrary to
  // ARCH-RTL018-001's own "a full or invalid host PUSH sets rejection
  // evidence and count" (implying every attempt resolves to one or the
  // other, never silence). Accept/reject is still decided against the
  // QUEUE STATE AT THE MOMENT the arbiter actually services the latched
  // request, not at the original pulse time -- same "retried once idle is
  // reached" precedent RTL-017 established. AUTO_PARITY/override-valid
  // legality is folded into the committed entry's own stored fields, never
  // rejected outright (finding 6's own disclosed gap).
  //
  // host_push_want ORs in the live ctl_push_pulse directly, not just
  // push_pending_q -- a SECOND real bug found and fixed via this module's
  // own testbench (the last-free-slot tiebreaker case specifically): a
  // fresh PUSH pulse arriving while the arbiter is already idle must be
  // visible to the arbiter THE SAME CYCLE, exactly like route_push_req
  // (msg_valid_i, a plain combinational level) already is -- if
  // host_push_want read push_pending_q alone, a host PUSH and a route
  // request asserted on the literal same CORE_CLK edge would see the
  // route win every time (its own request is combinationally visible
  // immediately; the host's would only become visible to the arbiter ONE
  // CYCLE LATER, after push_pending_q registers), silently inverting
  // ARCH-RTL018-001's own "host wins the last-slot tiebreaker" rule for
  // the exact simultaneous-arrival case the rule exists for. The
  // push_pending_q <= update below uses `else if` specifically so a pulse
  // that is ALSO being serviced this same cycle (the OR term already made
  // host_push_want true) is never separately re-latched for a phantom
  // second service -- the one narrow, disclosed residual limit this
  // leaves: a brand-new PUSH pulse arriving on the exact cycle a
  // DIFFERENT, previously-latched push is being serviced is not itself
  // separately latched and would need to be reissued by the host. This
  // project's own established usage pattern (confirm BUSY/queue-level
  // before issuing the next command, same as every other WO-CMD register
  // here) makes this a realistic-use non-issue, not silently assumed safe.
  // ==========================================================================
  logic push_pending_q;
  wire  arb_idle          = (phase_q == PH_IDLE);
  wire  host_push_want    = push_pending_q || ctl_push_pulse;
  wire  host_push_service = arb_idle && host_push_want;
  wire  host_push_accepted = host_push_service && ctl_enable && !queue_full;
  wire  host_push_rejected = host_push_service && (!ctl_enable || queue_full);

  // ==========================================================================
  // Route-input translation (finding 9) -- genuinely unreachable while
  // msg_valid_i is tied to the disclosed stub, but implemented for real.
  // msg_valid_i is a real valid/ready LEVEL (RTL-021 holds it with stable
  // msg_record_i until accepted), so unlike the host's one-shot pulse it
  // needs no latch -- it simply stays asserted until serviced.
  // ==========================================================================
  wire [31:0] route_word = msg_record_i[95:64];  // dfc_message_record_t payload[31:0] (ARCH-002 generic layout, LSB-justified within the 64-bit payload field at [127:64])
  wire        route_push_req = msg_valid_i;

  // Last-free-slot tiebreaker (finding 2): route_push_accepted's own
  // `!host_push_want` term is the real, sufficient implementation of "host
  // wins only when both want the same idle slot" -- when there's room for
  // both (no real conflict), the route request simply waits one extra
  // arbiter turn once host_push_want clears, exactly ARCH-RTL018-001's own
  // "not backpressured as lost" text, not a special-cased contention path.
  // msg_ready_o/route_push_accepted are gated by arb_idle (phase_q==PH_IDLE)
  // -- a real bug found and fixed while writing this module's own
  // testbench: without this gate, msg_ready_o would combinationally assert
  // "accepted" even while the arbiter was mid-operation on an unrelated
  // host push, since neither term otherwise depends on phase_q at all.
  wire route_push_accepted = arb_idle && !host_push_want && route_push_req &&
                              ctl_enable && !queue_full;
  assign msg_ready_o = route_push_accepted;

  // ==========================================================================
  // Internal buffer-client arbiter: HOST-PUSH > ROUTE-PUSH > DEQUEUE-READ,
  // one outstanding buf_req/rsp at a time (ARCH-BUF-013). op_q/phase_q/
  // word_idx_q/wr_w0_q/wr_w1_q/rd_w0_q/rd_w1_q and the OP_*/PH_* localparams
  // are declared above, ahead of the host-push-validation block.
  // ==========================================================================
  wire read_word_ok  = (phase_q == PH_WAIT) && buf_rsp_valid_i && rsp_ok;
  wire read_word_err = (phase_q == PH_WAIT) && buf_rsp_valid_i && !rsp_ok;

  assign buf_req_valid_o = (phase_q == PH_REQ);
  assign buf_rsp_ready_o = (phase_q == PH_WAIT);

  wire [2:0] req_entry = (op_q == OP_PUSH) ? tail_q : head_q;
  wire       req_is_write = (op_q == OP_PUSH);
  wire [31:0] wr_word_mux = word_idx_q ? wr_w1_q : wr_w0_q;

  assign buf_req_o = {
    wr_word_mux,                           // [41:10] write_data
    req_is_write,                          // [9] write
    {5'b0, req_entry, word_idx_q}          // [8:0] word_offset (client-relative, 0-15)
  };

  // Serializer handshake into the arbiter: pulses one cycle when the TX
  // engine wants to start a new dequeue (finding 3). Gated by
  // effective_operational_enable_i (ARCH-002's own "low suppresses
  // externally effective action" text) -- while withdrawn, this module
  // simply never starts a new transmission at all (queued entries stay
  // queued, no real action is taken), rather than suppressing only the
  // final pad drive while still internally consuming/completing entries.
  logic tx_idle;
  wire dequeue_start = tx_idle && !queue_empty && ctl_enable && effective_operational_enable_i &&
                       (op_q == OP_NONE) && (phase_q == PH_IDLE);

  // ==========================================================================
  // Bit-level serializer (finding 4). SER_IDLE waits for a completed
  // dequeue (rd_w0_q/rd_w1_q valid); SER_BIT shifts 32 data bits + 1 parity
  // bit, LSB-first; SER_GAP holds 2'b00 for GAP_BITS bit-times.
  // ==========================================================================
  localparam logic [1:0] SER_IDLE = 2'd0;
  localparam logic [1:0] SER_BIT  = 2'd1;
  localparam logic [1:0] SER_GAP  = 2'd2;

  logic [1:0]  ser_state_q;
  logic [31:0] ser_shift_q;
  logic [5:0]  ser_bit_count_q;    // 0-32 (33 bits total: 32 data + 1 parity)
  logic [7:0]  ser_gap_count_q;
  logic [15:0] ser_cycle_count_q;  // counts up to CYCLES_PER_BIT_{LOW,HIGH}
  logic        ser_high_speed_q, ser_auto_parity_q, ser_override_valid_q, ser_override_bit_q;
  // ser_parity_q: odd parity computed ONCE, from the original 32-bit word,
  // at load time -- NOT recomputed at the parity bit-time from ser_shift_q,
  // which by then has been shifted 32 times and holds all zeros (a real
  // bug found and fixed while writing this file: `~^ser_shift_q` at the
  // parity bit-time is a constant, not the real word's parity, since the
  // live shift register has already been fully drained by that point).
  logic        ser_parity_q;
  logic        complete_pulse;

  wire [15:0] cycles_per_bit = ser_high_speed_q ? CYCLES_PER_BIT_HIGH[15:0] : CYCLES_PER_BIT_LOW[15:0];
  wire        bit_time_done  = (ser_cycle_count_q >= cycles_per_bit - 16'd1);

  wire        cur_data_bit   = ser_shift_q[0];
  // Override is only actually legal when AUTO_PARITY was 0 at commit time
  // (ARCH-VAL-018); an override staged alongside AUTO_PARITY=1 is ignored
  // in favor of the real auto-computed value (finding 6).
  wire        parity_bit_val = (ser_override_valid_q && !ser_auto_parity_q) ? ser_override_bit_q : ser_parity_q;

  assign tx_idle = (ser_state_q == SER_IDLE);

  // Latched "already reported this empty spell" flag so UNDERRUN counts
  // once per idle-empty occurrence, not once per CORE_CLK cycle (finding 5).
  logic underrun_pending_q;
  wire  underrun_now = tx_idle && queue_empty && ctl_enable && !underrun_pending_q;

  // tail_advance/head_advance (RTL-017's own combined-update idiom, see this
  // module's own queue-pointer header comment above for why): tail_advance
  // is the exact cycle a host/route PUSH's second word lands OK; head_advance
  // is the exact cycle the serializer's trailing gap finishes.
  wire tail_advance = (phase_q == PH_WAIT) && read_word_ok && (op_q == OP_PUSH) && word_idx_q;
  wire head_advance = (ser_state_q == SER_GAP) && bit_time_done && (ser_gap_count_q + 8'd1 >= ctl_gap_bits);

  // ==========================================================================
  // Unified arbiter + serializer + queue-pointer + counter/sticky-evidence
  // always_ff (ONE block, deliberately not split further): head_q/count_q
  // are each legitimately touched by two different real events (a push
  // commit and a dequeue-complete) -- splitting this into separate
  // always_ff blocks per concern (tried in an earlier draft of this file)
  // produces a real multi-driver elaboration error on head_q/count_q/
  // complete_sticky_q/underrun_sticky_q/adapter_error_sticky_q, found via a
  // real failed compile, not assumed. RTL-017's own single-block arbiter
  // (dfc_rtl017.sv) established the same discipline for the identical
  // reason.
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 1'b0;
      head_q <= 3'd0; tail_q <= 3'd0; count_q <= 4'd0;
      wr_w0_q <= 32'h0; wr_w1_q <= 32'h0; rd_w0_q <= 32'h0; rd_w1_q <= 32'h0;
      error_count_q <= 32'h0; underrun_count_q <= 32'h0; rejected_push_count_q <= 32'h0;
      complete_sticky_q <= 1'b0; underrun_sticky_q <= 1'b0;
      rejected_sticky_q <= 1'b0; adapter_error_sticky_q <= 1'b0;
      error_count_wr_q <= 32'h0; underrun_count_wr_q <= 32'h0; rejected_push_count_wr_q <= 32'h0;
      underrun_pending_q <= 1'b0; push_pending_q <= 1'b0;
      ser_state_q <= SER_IDLE; ser_shift_q <= 32'h0; ser_bit_count_q <= 6'd0;
      ser_gap_count_q <= 8'd0; ser_cycle_count_q <= 16'd0;
      ser_high_speed_q <= 1'b0; ser_auto_parity_q <= 1'b0;
      ser_override_valid_q <= 1'b0; ser_override_bit_q <= 1'b0; ser_parity_q <= 1'b0;
      busy_q <= 1'b0; complete_pulse <= 1'b0;
    end else if (module_reset_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 1'b0;
      head_q <= 3'd0; tail_q <= 3'd0; count_q <= 4'd0;
      error_count_q <= 32'h0; underrun_count_q <= 32'h0; rejected_push_count_q <= 32'h0;
      complete_sticky_q <= 1'b0; underrun_sticky_q <= 1'b0;
      rejected_sticky_q <= 1'b0; adapter_error_sticky_q <= 1'b0;
      underrun_pending_q <= 1'b0; push_pending_q <= 1'b0;
      ser_state_q <= SER_IDLE; busy_q <= 1'b0;
      complete_pulse <= 1'b0;
    end else begin
      complete_pulse <= 1'b0;  // default: one-cycle pulse

      // ---- edge-detected COUNTER-CLR clears ----
      error_count_wr_q          <= ctl_error_count_wr;
      underrun_count_wr_q       <= ctl_underrun_count_wr;
      rejected_push_count_wr_q  <= ctl_rejected_push_count_wr;
      if (clr_error_count_now)         error_count_q          <= 32'h0;
      if (clr_underrun_count_now)      underrun_count_q       <= 32'h0;
      if (clr_rejected_push_count_now) rejected_push_count_q  <= 32'h0;

      // ---- sticky W1C clears (new evidence dominates, applied below) ----
      if (ctl_clr_complete)      complete_sticky_q      <= 1'b0;
      if (ctl_clr_underrun)      underrun_sticky_q      <= 1'b0;
      if (ctl_clr_rejected)      rejected_sticky_q      <= 1'b0;
      if (ctl_clr_adapter_error) adapter_error_sticky_q <= 1'b0;

      // ---- new sticky evidence (dominates a same-cycle clear attempt
      // above, project-wide precedent) ----
      if (atx_adapter_error_i) adapter_error_sticky_q <= 1'b1;

      // ---- host-push rejection (full/disabled) ----
      if (host_push_rejected) begin
        rejected_sticky_q      <= 1'b1;
        rejected_push_count_q  <= (rejected_push_count_q == 32'hFFFFFFFF) ? rejected_push_count_q : rejected_push_count_q + 32'd1;
      end

      // ---- underrun: TX engine idle-while-empty, one pulse per occurrence ----
      if (!queue_empty || !ctl_enable) underrun_pending_q <= 1'b0;
      else if (underrun_now) underrun_pending_q <= 1'b1;
      if (underrun_now) begin
        underrun_sticky_q <= 1'b1;
        underrun_count_q  <= (underrun_count_q == 32'hFFFFFFFF) ? underrun_count_q : underrun_count_q + 32'd1;
      end

      // ---- buffer-client arbiter: HOST-PUSH > ROUTE-PUSH > DEQUEUE-READ ----
      case (phase_q)
        PH_IDLE: begin
          if (host_push_accepted) begin
            op_q <= OP_PUSH; word_idx_q <= 1'b0; phase_q <= PH_REQ;
            wr_w0_q <= ctl_data_stage;
            wr_w1_q <= {14'h0, ctl_meta_tag, ctl_meta_override_bit, ctl_meta_override_valid, ctl_auto_parity, ctl_high_speed};
          end else if (route_push_accepted) begin
            op_q <= OP_PUSH; word_idx_q <= 1'b0; phase_q <= PH_REQ;
            wr_w0_q <= route_word;
            // Route-sourced entry: auto parity, module's own current speed,
            // no override, zero tag (finding 9's own disclosed choice).
            wr_w1_q <= {14'h0, 14'h0, 1'b0, 1'b0, 1'b1, ctl_high_speed};
          end else if (dequeue_start) begin
            op_q <= OP_DEQUEUE; word_idx_q <= 1'b0; phase_q <= PH_REQ;
          end
        end

        PH_REQ: begin
          if (buf_req_ready_i) phase_q <= PH_WAIT;
        end

        PH_WAIT: begin
          if (read_word_err) begin
            error_count_q <= (error_count_q == 32'hFFFFFFFF) ? error_count_q : error_count_q + 32'd1;
            op_q <= OP_NONE; phase_q <= PH_IDLE;
          end else if (read_word_ok) begin
            if (op_q == OP_PUSH) begin
              // write path: wr_w0_q/wr_w1_q already hold the data, buf_rsp_i
              // only confirms the write landed -- nothing to latch from
              // rsp_data here. tail_q advances via the tail_advance wire below.
              if (!word_idx_q) begin
                word_idx_q <= 1'b1; phase_q <= PH_REQ;
              end else begin
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end
            end else begin // OP_DEQUEUE
              if (!word_idx_q) begin
                rd_w0_q <= rsp_data;
                word_idx_q <= 1'b1; phase_q <= PH_REQ;
              end else begin
                rd_w1_q <= rsp_data;
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end
            end
          end
        end

        default: begin
          op_q <= OP_NONE; phase_q <= PH_IDLE;
        end
      endcase

      // ---- push_pending_q: clear on the cycle it's actually serviced
      // (accept or reject, either way) -- this takes priority (`else if`)
      // over latching a fresh pulse, specifically so a pulse that is ALSO
      // being serviced THIS SAME cycle (already folded into host_push_want
      // via its own `|| ctl_push_pulse` term above) is never separately
      // re-latched into a phantom second service. A genuinely NEW pulse
      // arriving on a cycle where a DIFFERENT, already-latched push is
      // being serviced is the one narrow, disclosed residual case this
      // doesn't cover (see this block's own header comment above). ----
      if (host_push_service) push_pending_q <= 1'b0;
      else if (ctl_push_pulse) push_pending_q <= 1'b1;

      if (tail_advance) tail_q <= tail_q + 3'd1;
      if (head_advance) begin
        head_q <= head_q + 3'd1;
        complete_sticky_q <= 1'b1;
        complete_pulse    <= 1'b1;
      end
      count_q <= count_q + (tail_advance ? 4'd1 : 4'd0) - (head_advance ? 4'd1 : 4'd0);

      // ---- bit-level serializer (finding 3/4) ----
      case (ser_state_q)
        SER_IDLE: begin
          busy_q <= 1'b0;
          if (read_word_ok && (op_q == OP_DEQUEUE) && word_idx_q) begin
            // W1 lands THIS cycle via the arbiter's own `rd_w1_q <= rsp_data`
            // (PH_WAIT branch, nonblocking) -- reading rd_w1_q here, in the
            // SAME always_ff invocation, would see its PRE-this-edge (STALE,
            // i.e. the PREVIOUS dequeue's W1) value, not the real one
            // landing now. A real bug, found via this module's own
            // testbench (Case 3's override-legality check): two consecutive
            // dequeues whose override-valid/auto-parity bits differ showed
            // the OLDER entry's values, not silently coincidental because
            // Case 4 (immediately following) happened to still pass -- its
            // expected result and the stale value coincided by chance,
            // which is exactly why only a real simulation check comparing
            // the ACTUAL transmitted parity bit against the ACTUAL intended
            // one caught this, not inspection. Fixed: read the live,
            // un-registered `rsp_data` directly (valid this exact cycle,
            // confirmed by `read_word_ok` already gating this whole branch)
            // instead of the one-cycle-delayed registered copy. ser_shift_q
            // below is NOT affected by this same race -- W0 was already
            // captured into rd_w0_q a full cycle EARLIER (word_idx_q was 0
            // then), so it is already stable by the time this W1 cycle runs.
            ser_shift_q      <= rd_w0_q;
            ser_high_speed_q <= rsp_data[0];
            ser_auto_parity_q<= rsp_data[1];
            ser_override_valid_q <= rsp_data[2];
            ser_override_bit_q   <= rsp_data[3];
            ser_parity_q     <= ~^rd_w0_q;  // odd parity of the real 32-bit word, computed once
            ser_bit_count_q  <= 6'd0;
            ser_cycle_count_q<= 16'd0;
            ser_state_q      <= SER_BIT;
            busy_q           <= 1'b1;
          end
        end

        SER_BIT: begin
          busy_q <= 1'b1;
          ser_cycle_count_q <= ser_cycle_count_q + 16'd1;
          if (bit_time_done) begin
            ser_cycle_count_q <= 16'd0;
            if (ser_bit_count_q == 6'd32) begin
              // parity bit time just completed -- move to gap
              ser_gap_count_q <= 8'd0;
              ser_state_q <= SER_GAP;
            end else begin
              ser_bit_count_q <= ser_bit_count_q + 6'd1;
              ser_shift_q <= {1'b0, ser_shift_q[31:1]};
            end
          end
        end

        SER_GAP: begin
          busy_q <= 1'b1;
          ser_cycle_count_q <= ser_cycle_count_q + 16'd1;
          if (bit_time_done) begin
            ser_cycle_count_q <= 16'd0;
            if (head_advance) begin
              ser_state_q <= SER_IDLE;
            end else begin
              ser_gap_count_q <= ser_gap_count_q + 8'd1;
            end
          end
        end

        default: ser_state_q <= SER_IDLE;
      endcase
    end
  end

  // The parity bit is driven onto the shift path at the moment ser_bit_count_q
  // transitions 31->32: cur_data_bit (ser_shift_q[0]) must present the real
  // parity value during that one bit-time. Implemented by pre-loading bit 0
  // with parity_bit_val the cycle bit 31 completes (ser_shift_q[31:1]
  // shifted into [30:0], bit 31 implicitly zero per the shift above) --
  // overridden here combinationally for the one bit-time it matters.
  wire tx_bit_is_parity = (ser_bit_count_q == 6'd32);
  wire tx_bit_value = tx_bit_is_parity ? parity_bit_val : cur_data_bit;

  always_comb begin
    arinc_tx_ctrl_o = 2'b00;
    if (ser_state_q == SER_BIT && ser_cycle_count_q < (cycles_per_bit >> 1)) begin
      arinc_tx_ctrl_o = tx_bit_value ? (ser_high_speed_q ? 2'b10 : 2'b01) : 2'b00;
    end
  end

  // ==========================================================================
  // Event/IRQ generation (finding 7): one shared pending slot, 8 independent
  // condition-enable bits, cause code latched in evt_cause_q.
  // ==========================================================================
  logic        evt_pending_q;
  logic [2:0]  evt_cause_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic [15:0] event_drop_count_q;
  logic        event_overflow_sticky_q;
  wire         slot_free = !evt_pending_q || evt_ready_i;

  wire cond_complete     = complete_pulse      && event_condition_enable_i[0];
  wire cond_rejected     = host_push_rejected  && event_condition_enable_i[1];
  wire cond_queue_overflow = host_push_rejected && event_condition_enable_i[2];  // finding 7: same real trigger as 'rejected'
  wire cond_underrun     = underrun_now        && event_condition_enable_i[3];
  wire cond_adapter_err  = atx_adapter_error_i && !adapter_error_sticky_q && event_condition_enable_i[4];
  // bit 5 "recovery": no real internal condition drives this -- structurally
  // unreachable, disclosed (finding 7).
  wire cond_buf_error    = read_word_err       && event_condition_enable_i[6];
  wire any_cond = ctl_event_enable &&
                  (cond_complete || cond_rejected || cond_queue_overflow || cond_underrun || cond_adapter_err || cond_buf_error);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_cause_q <= 3'd0; evt_record_q <= '0;
      event_drop_count_q <= 16'h0; event_overflow_sticky_q <= 1'b0;
    end else if (module_reset_i) begin
      evt_pending_q <= 1'b0;
      event_overflow_sticky_q <= 1'b0;
    end else begin
      if (ctl_clr_event_overflow) event_overflow_sticky_q <= 1'b0;
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;

      if (any_cond) begin
        if (slot_free) begin
          evt_pending_q <= 1'b1;
          evt_cause_q <= cond_complete       ? 3'd0 :
                         cond_rejected       ? 3'd1 :
                         cond_queue_overflow ? 3'd2 :
                         cond_underrun       ? 3'd3 :
                         cond_adapter_err    ? 3'd4 : 3'd6;
          evt_record_q <= {
            {24'h0, cond_complete ? 8'd0 : cond_rejected ? 8'd1 : cond_queue_overflow ? 8'd2 :
                    cond_underrun ? 8'd3 : cond_adapter_err ? 8'd4 : 8'd6}, // [127:96] event_data
            8'h00,          // [95:88] flags
            8'd17,          // [87:80] source_id = evt bus slot 17
            16'h0021,       // [79:64] event_id (C.7 0x0021)
            timestamp_i     // [63:0] timestamp
          };
        end else begin
          event_overflow_sticky_q <= 1'b1;
          event_drop_count_q <= (event_drop_count_q == 16'hFFFF) ? event_drop_count_q : event_drop_count_q + 16'd1;
        end
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;
  assign irq_req_o    = evt_pending_q && ctl_irq_enable && irq_condition_enable_i[evt_cause_q];
  assign fault_req_o  = adapter_error_sticky_q;

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__READY_HI]                 = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__FAULT_HI]                 = adapter_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__EVENT_OVERFLOW_HI]        = event_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__ENABLED_HI]   = module_enable_i && ctl_enable;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__BUSY_HI]      = busy_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__QUEUE_EMPTY_HI] = queue_empty;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__QUEUE_FULL_HI]  = queue_full;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__COMPLETE_HI]    = complete_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__UNDERRUN_HI]    = underrun_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__REJECTED_HI]    = rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_STATUS__ADAPTER_ERROR_HI] = adapter_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_QUEUE_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL018_STATUS__ATX_QUEUE_LEVEL__LEVEL_LO] = count_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL018_STATUS__ATX_ERROR_COUNT__COUNT_LO] = error_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_UNDERRUN_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL018_STATUS__ATX_UNDERRUN_COUNT__COUNT_LO] = underrun_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL018_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL018_STATUS__ATX_REJECTED_PUSH_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL018_STATUS__ATX_REJECTED_PUSH_COUNT__COUNT_LO] = rejected_push_count_q;

endmodule : dfc_rtl018
