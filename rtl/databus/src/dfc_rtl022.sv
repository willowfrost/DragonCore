// ============================================================================
// dfc_rtl022.sv -- RTL-022 Mask-Defined User Logic Island (ARCH-RTL022-001)
//
// Controlling spec: docs/rtl_specs/RTL-022_RevA.md (derived; its own SS2
// claims "11 total" ports and "20 registers" -- BOTH confirmed stale this
// session: ARCH-002 Appendix A's real row count for RTL-022 is 35 ports,
// and REG-002's own Section 29 block header says "Register count: 23",
// confirmed by direct row count (23); RevA's own prose never mentions
// ULI_IO_DIRECTION/ULI_IO_INPUT/ULI_IO_OUTPUT at all. Implemented against
// the real 35-port/23-register set. Owning contracts: ARCH-002 SS-ULI
// (ARCH-MOD-022, ARCH-ULI-001 through 005, ARCH-RTL022-001, ARCH-VAL-022),
// Appendix A (35-port catalog), Appendix B (dfc_rtl022_control_t 309 bits /
// dfc_rtl022_status_t 137 bits), Appendix C.4/C.5/C.6 (irq slot 18/evt slot
// 21/fault slot 15), Appendix D.2 (CDC-USER), Appendix F.3 (condition-mask
// allocation), Appendix F.4 (ARCH-VAL-022); REG-002 Section 29
// (0x4000-0x4058, 23 registers); VP-002 VP-MOD-022/VP-USER-010.
//
// THIS MODULE'S DEFINING CHARACTERISTIC (quoted from its own governing
// prose, repeated here deliberately because every design choice below
// follows from it): "the 'correct implementation' here is one that
// provably does nothing operational, not one that does something useful."
// ARCH-ULI-001 through 005, implemented literally:
//  - ENABLE, IRQ_ENABLE, PARAM0-7, and OUTPUT_REQUEST have the sole legal
//    value zero (REG-ENC-017); any nonzero write attempt is rejected (has
//    no operational effect of any kind) and sets sticky VIOLATION evidence.
//  - user_o/user_oe_o are hardwired 4'b0000 in EVERY state, including test
//    mode -- no exception anywhere in this file.
//  - tx_msg_valid_o/tx_msg_record_o are hardwired inactive -- RTL-022 can be
//    a message DESTINATION (ARCH-MSG-005) but is never a real SOURCE. This
//    is the real wiring of RTL-021's own disclosed ULI forward-reference
//    (OPEN_ISSUES.md item 152): RTL-021's ULI-destination port is now real;
//    RTL-021's ULI-SOURCE side stays permanently tied inactive from this
//    module's side, an intentional asymmetry, not a gap to "fix."
//  - irq_req_o is permanently hardwired 0: Appendix F.3's own RTL-022 row
//    states all 5 real condition bits "are diagnostic-event-only and never
//    assert IRQ" -- IRQ_ENABLE being forced zero-only is consistent with,
//    but not the sole reason for, this; even if a future revision allowed
//    IRQ_ENABLE=1, this module generates no condition eligible to drive an
//    interrupt.
//  - fault_req_o is permanently hardwired 0: a disclosed stub. REG-002/
//    ARCH-002 reserve fault slot 15 (code 0x7F) for this module, but an
//    inert module with every operational input/parameter forced to zero
//    has no real internal condition left to ever detect as a fault.
//
// MASTER SHARED-RESOURCE-INDEX TABLE CHECKED BEFORE WIRING (OPEN_ISSUES.md
// item 140, mandatory per this session's own task briefing): irq_source_i
// [18], fault_source_i[15], evt_valid_i/evt_record_i[21] all cross-checked
// against the master table (OPEN_ISSUES.md item 140's own text: "18=RTL-022
// (not real yet)" on the irq vector, "13-16=RTL-020..023" i.e. 15=RTL-022 on
// the fault vector, "19-22=RTL-020..023" i.e. 21=RTL-022 on the evt vector)
// -- all three match ARCH-002's own claimed indices exactly, the FIRST
// Databus-family module this session class to produce a clean master-table
// result with no stale claim anywhere to fix (RTL-017/018/019/020/021 each
// found one real conflict). activity_i[6] ("user diagnostic input
// transition" per RTL-015's own ARCH-SAFE-007 order) remains a disclosed,
// pre-existing stub with NO real producer: RTL-022 has no activity_o port
// anywhere in its real 35-port Appendix A catalog, confirmed directly (not
// assumed) -- this module does not drive that bit, now or ever.
//
// ARCH-002-INTERNAL GAP FIXED THIS SESSION (same gap CLASS already fixed
// for RTL-002 through RTL-021, approved before this edit -- ARCH-002
// undershoots a REG-002-specified real forwarding need by a small,
// unambiguous number of bits): dfc_rtl022_control_t had no clear-forwarding
// field for RTL022_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-404C bit 0, a
// real W1C field) -- the 14th real instance of this exact gap class. Fixed:
// ARCH-002 grew the struct 308->309 bits, adding
// rtl022_evt_overflow_status__event_overflow at the new highest bit (308),
// appended at the end exactly as RTL-021's own analogous fix (item 148) was
// appended, not inserted in REG-002 address order -- same precedent.
// Regenerated via extract_types.py/pkggen.py with an isolated, confirmed
// diff (every other struct's bit positions unchanged); reggen.py then
// produced "real cross-module forwarding wired for RTL-022: 18 control
// regs, 9 status regs" with no assertion failures.
//
// A GENUINE, DISCLOSED REG-002-INTERNAL INCONSISTENCY, RESOLVED (not
// silently picked): ULI_CONTROL's own "Register behavior" prose states
// "ENABLE and IRQ_ENABLE have the sole legal value zero," directly
// contradicting its OWN per-field "Legal values/range" column ("0 or 1" for
// both, with no "in Revision A" qualifier every OTHER real zero-only field
// in this same section consistently carries). Resolved in favor of the
// prose: ENABLE and IRQ_ENABLE get the same reject-nonzero-plus-violation
// treatment as the 8 parameters and OUTPUT_REQUEST, per ARCH-ULI-001's own
// text ("Any nonzero parameter write or enable attempt is rejected and
// sets violation evidence") and this session's own task briefing
// explicitly requiring "ENABLE/IRQ_ENABLE nonzero-write rejection
// (REG-ENC-017)". REG-ENC-017's own literal text names only "functional
// enable" (ENABLE) by name, not IRQ_ENABLE -- so IRQ_ENABLE's own inclusion
// rests on REG-002's ULI_CONTROL prose plus this session's explicit
// instruction, not REG-ENC-017's narrower literal wording. EVENT_ENABLE is
// the one confirmed exception (REG-002's own prose: "diagnostic
// EVENT_ENABLE remain available") -- an ordinary RW bit, consulted below
// only to gate event generation, same as every other module's own
// EVENT_ENABLE.
//
// A SECOND GENUINE, DISCLOSED INCONSISTENCY (Appendix F.3 vs. Appendix
// C.7): F.3's own RTL-022 row lists condition-mask bits as "0 parameter
// rejection, 1 diagnostic mailbox activity, 2 reset complete, 3
// shared-buffer error, 4 event-slot overflow" (the condition_enable_i gate
// allocation used below). C.7's own event_id 0x0050 row for RTL-022 lists
// a DIFFERENT, non-corresponding cause set: "0 diagnostic input, 1
// mailbox, 2 parameter rejected, 3 reset" -- omitting shared-buffer error
// entirely (itself normal: "event-slot overflow" is likewise absent from
// every OTHER module's own C.7 row, since it drains the shared pending-slot
// counter rather than producing its own typed record -- confirmed against
// RTL-021's own 0x0024 row, which also omits its own F.3 bit 7) but ALSO
// inventing an unreferenced "diagnostic input" cause C.7 nowhere else
// supports. Resolved in favor of F.3's own 4-cause list for the record's
// own cause/data encoding below (parameter rejection=0, mailbox
// activity=1, reset complete=2, shared-buffer error=3), because: (a) F.3's
// stated purpose is precisely per-condition subcondition-mask allocation;
// (b) Appendix D.2's own CDC-USER entry states user_i has "no operational
// output in Revision A" -- textually confirming no event of any kind is
// generated from a user_i transition, which rules out C.7's own
// "diagnostic input" cause as ever being real. event_id 0x0050 itself
// (C.7's only undisputed fact for this module) is used unchanged.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous local reset (RTL-002.module_reset_o[21]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl022_field_map.json).
//
// ---------------------------------------------------------------------------
// DESIGN, DISCLOSED:
//
//  1. OUTPUT MAILBOX IS A LITERAL HARDWIRED CONSTANT, NOT REAL
//     SHARED-BUFFER-BACKED INFRASTRUCTURE THAT HAPPENS TO STAY EMPTY. REG-
//     002's own text for ULI_OUT_LEVEL/ULI_OUT_DATA/ULI_OUT_POP each say
//     "fixed zero"/"rejected as empty" in Revision A, not merely "currently
//     empty" -- there is no register path anywhere that can ever push a
//     word into it (no ULI_OUT_PUSH-shaped register exists), so building
//     real backing store for a path that can never be fed would itself be
//     "doing more than required." Implemented as: LEVEL=0, DATA=0 hardwired
//     combinationally; every ULI_OUT_POP command pulse is treated as a real
//     underflow attempt against a structurally-always-empty queue (see
//     finding 3).
//
//  2. INPUT MAILBOX IS REAL, SHARED-BUFFER-BACKED (ARCH-BUF-011 allocates
//     RTL-022 2x4 words at client-relative offsets 0-7; offsets 0-3 are
//     this module's real input-mailbox storage, offsets 4-7 are reserved/
//     never wired to anything, a disclosed future-revision placeholder
//     matching finding 1's own reasoning for why the output side needs no
//     such storage today). One-outstanding-request client discipline
//     (ARCH-BUF-013), same IDLE/REQ/WAIT arbiter shape as every prior
//     Databus module's own shared-buffer client. PUSH is host-driven only;
//     there is no host-visible or internal consumer that ever drains the
//     input mailbox in Revision A -- REG-002 defines no ULI_IN_POP-shaped
//     register anywhere, and ARCH-002 describes no internal consumer. The
//     ONLY way the input mailbox ever empties is RESET_REQ/module_reset_i
//     clearing its pointers. This produces a disclosed, deliberate
//     asymmetry, confirmed consistent across both mailboxes: the INPUT
//     mailbox can overflow (host-driven push, no drain path) but can NEVER
//     underflow (no pop path exists at all, host-visible or internal); the
//     OUTPUT mailbox can underflow (host-driven pop, permanently empty) but
//     can NEVER overflow (no push path exists at all). INPUT_UNDERFLOW and
//     OUTPUT_OVERFLOW are therefore both real register fields
//     (ULI_MAILBOX_STATUS bits 1/2, and their own COUNTER16-CLR loss
//     counters) that are structurally unreachable in this Revision -- a
//     disclosed stub pair, same class of choice as RTL-021's own several
//     unreachable commit codes.
//
//  3. A SECOND PUSH COMMAND ARRIVING WHILE THE SHARED-BUFFER ARBITER IS
//     STILL BUSY WITH AN EARLIER ONE IS DROPPED, NOT QUEUED, treated
//     identically to a push against an already-full mailbox (both count as
//     INPUT_OVERFLOW evidence/loss). A disclosed simplification: the
//     one-outstanding-request discipline gives this module no way to
//     accept a second concurrent push, and REG-4030's own PUSH command
//     semantics ("Issues one PUSH command pulse") say nothing about
//     queuing a second one -- the host's own push-then-poll-LEVEL
//     discipline is expected to serialize these naturally, same precedent
//     as every prior module's own single-outstanding shared-buffer client.
//
//  4. rx_msg_ready_o IS UNCONDITIONALLY 1 (never gated by module_enable_i/
//     ctl_enable/reset). ARCH-ULI-005 describes RTL-022 as a message
//     destination with "diagnostic capture only, zero operational effect"
//     -- received records are accepted and discarded (not stored, not
//     exposed through any register, not forwarded anywhere); applying any
//     backpressure to RTL-021's own replication pipeline here would be an
//     invented operational effect this inert module must not have.
//     Acceptance is diagnostic-silent: no event, no counter, no status bit
//     anywhere reflects it (a deliberately narrower reading than "mailbox
//     activity" might suggest -- REG-002's own ULI_MAILBOX_STATUS section
//     and F.3's own "diagnostic mailbox activity" condition both describe
//     ONLY the two register-mailboxes' own push/pop traffic, never
//     Databus message reception, so message reception gets no diagnostic
//     surface at all, consistent with "zero operational effect" taken
//     literally).
// ---------------------------------------------------------------------------

module dfc_rtl022 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[21]

  input  logic [dfc_types_pkg::DFC_RTL022_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL022_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[18] -- permanently 0, finding header
  output logic         fault_req_o,          // RTL-013.fault_source_i[15] -- disclosed stub, finding header

  input  logic [3:0]   user_i,               // CDC-USER, async, RTL-024.user_in_o
  output logic [3:0]   user_o,               // hardwired 4'b0000 (ARCH-ULI-002)
  output logic [3:0]   user_oe_o,            // hardwired 4'b0000 (ARCH-ULI-002)

  input  logic         rx_msg_valid_i,       // RTL-021.dest_valid_o[4]
  output logic         rx_msg_ready_o,
  input  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] rx_msg_record_i,

  output logic         tx_msg_valid_o,       // hardwired 0 -- RTL-021.source_valid_i[4], finding header
  input  logic         tx_msg_ready_i,
  output logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] tx_msg_record_o,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic [3:0]   route_user_req_i,     // RTL-023.route_dest_o[12:9] -- real as of RTL-023's own session; still a disclosed no-op here per ARCH-ULI-005 (diagnostic only, never affects an output in Revision A)
  input  logic [7:0]   route_term_i,         // RTL-023.route_dest_o[20:13] -- real as of RTL-023's own session; still a disclosed no-op here per ARCH-ULI-005 (diagnostic only, never affects an output in Revision A)

  input  logic         module_enable_i,      // RTL-002.module_enable_o[21]
  input  logic         effective_operational_enable_i,
  input  logic         test_active_i,        // RTL-024.test_active_o -- disclosed stub, same precedent as RTL-002's own

  output logic         buf_req_valid_o,
  input  logic         buf_req_ready_i,
  output logic [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req_o,
  input  logic         buf_rsp_valid_i,
  output logic         buf_rsp_ready_o,
  input  logic [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp_i,

  input  logic [63:0] event_condition_enable_i,
  input  logic [63:0] irq_condition_enable_i
);

  // operating_state_i/observational_mode_i/route_user_req_i/route_term_i/
  // test_active_i/effective_operational_enable_i: real Appendix A inputs
  // with no per-state behavior specified for an inert module -- a
  // disclosed, genuinely-unused set, same precedent as every prior Databus
  // module's own operating_state_i/observational_mode_i pair.
  logic unused_stub_sink;
  assign unused_stub_sink = (^operating_state_i) ^ observational_mode_i ^
                            (^route_user_req_i) ^ (^route_term_i) ^
                            test_active_i ^ effective_operational_enable_i ^
                            tx_msg_ready_i;

  // ==========================================================================
  // CDC-USER: two-stage synchronizer for the four async diagnostic user
  // inputs (Appendix D.2). Captured to status only (ULI_IO_INPUT.INPUT);
  // never influences user_o/user_oe_o or any other output (ARCH-ULI-004).
  // ==========================================================================
  logic [3:0] user_sync1_q, user_sync2_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      user_sync1_q <= 4'h0; user_sync2_q <= 4'h0;
    end else begin
      user_sync1_q <= user_i;
      user_sync2_q <= user_sync1_q;
    end
  end

  // ==========================================================================
  // Control-field unpack.
  // ==========================================================================
  wire ctl_enable        = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__ENABLE_HI];
  wire ctl_reset_req     = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__RESET_REQ_HI];
  wire ctl_event_enable  = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__EVENT_ENABLE_HI];
  wire ctl_irq_enable    = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_CONTROL__IRQ_ENABLE_HI];

  wire ctl_clr_violation      = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__VIOLATION_HI];
  wire ctl_clr_reset_complete = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_STATUS__RESET_COMPLETE_HI];

  wire [31:0] ctl_param0 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM0__PARAM0_LO];
  wire [31:0] ctl_param1 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM1__PARAM1_LO];
  wire [31:0] ctl_param2 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM2__PARAM2_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM2__PARAM2_LO];
  wire [31:0] ctl_param3 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM3__PARAM3_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM3__PARAM3_LO];
  wire [31:0] ctl_param4 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM4__PARAM4_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM4__PARAM4_LO];
  wire [31:0] ctl_param5 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM5__PARAM5_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM5__PARAM5_LO];
  wire [31:0] ctl_param6 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM6__PARAM6_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM6__PARAM6_LO];
  wire [31:0] ctl_param7 = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM7__PARAM7_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_PARAM7__PARAM7_LO];

  wire [31:0] ctl_in_data  = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_DATA__MAILBOX_DATA_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_DATA__MAILBOX_DATA_LO];
  wire        ctl_in_push  = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IN_PUSH__PUSH_HI];
  wire        ctl_out_pop  = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_OUT_POP__POP_HI];

  wire [3:0]  ctl_output_request = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_IO_OUTPUT__OUTPUT_REQUEST_LO];

  wire [3:0]  ctl_mbox_clear  = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_CLEAR_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_CLEAR_LO];
  wire [3:0]  ctl_loss_clear  = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__ULI_MAILBOX_LOSS_COUNT__CLEAR_HI:dfc_types_pkg::DFC_RTL022_CONTROL__ULI_MAILBOX_LOSS_COUNT__CLEAR_LO];

  wire ctl_clr_event_overflow = control_i[dfc_types_pkg::DFC_RTL022_CONTROL__RTL022_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  // ==========================================================================
  // Reject-nonzero-and-violate (ARCH-ULI-001, REG-ENC-017): ENABLE,
  // IRQ_ENABLE, all 8 PARAMs, and OUTPUT_REQUEST have the sole legal value
  // zero. RTL-001's generic regbank has no per-field range check (a
  // standing, disclosed, project-wide gap -- same precedent used for every
  // other module's own "legal value" constraints); this module itself
  // detects a nonzero value on any of these fields and treats it as having
  // NO operational effect (trivially true: none of these fields drive
  // anything below) while setting sticky VIOLATION evidence. Level-
  // sensitive (stays set for as long as the offending field is nonzero);
  // edge-detected separately below for the one-shot diagnostic event.
  // ==========================================================================
  wire params_nonzero = (ctl_param0 != 32'h0) || (ctl_param1 != 32'h0) ||
                        (ctl_param2 != 32'h0) || (ctl_param3 != 32'h0) ||
                        (ctl_param4 != 32'h0) || (ctl_param5 != 32'h0) ||
                        (ctl_param6 != 32'h0) || (ctl_param7 != 32'h0);
  wire violation_condition = ctl_enable || ctl_irq_enable ||
                            (ctl_output_request != 4'h0) || params_nonzero;

  logic violation_condition_q;
  logic violation_sticky_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      violation_condition_q <= 1'b0;
      violation_sticky_q    <= 1'b0;
    end else if (module_reset_i) begin
      violation_condition_q <= 1'b0;
      violation_sticky_q    <= 1'b0;
    end else begin
      violation_condition_q <= violation_condition;
      if (violation_condition) violation_sticky_q <= 1'b1;        // new evidence, then clear
      else if (ctl_clr_violation) violation_sticky_q <= 1'b0;
    end
  end
  wire violation_rising = violation_condition && !violation_condition_q;

  // ==========================================================================
  // RESET_REQ / module soft-reset (ARCH-ULI-003): clears both mailboxes'
  // pointer/valid sets and VIOLATION/RESET_COMPLETE evidence; explicitly
  // does NOT touch RTL-001's own stored (always-rejected, always-zero in
  // practice) parameter copies -- RTL-022 has no write path back into
  // RTL-001's register storage at all, so this is structural, not a
  // separate thing to "not do."
  // ==========================================================================
  logic module_reset_prev_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) module_reset_prev_q <= 1'b1;
    else               module_reset_prev_q <= module_reset_i;
  end
  wire module_reset_falling = module_reset_prev_q && !module_reset_i;
  wire do_soft_reset = ctl_reset_req || module_reset_falling;

  logic reset_complete_sticky_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) reset_complete_sticky_q <= 1'b0;
    else if (module_reset_i) reset_complete_sticky_q <= 1'b0;
    else if (do_soft_reset) reset_complete_sticky_q <= 1'b1;      // new evidence, then clear
    else if (ctl_clr_reset_complete) reset_complete_sticky_q <= 1'b0;
  end

  // ==========================================================================
  // Shared-buffer response-code check (CODE_OK=2'b00 convention, same as
  // every prior Databus module).
  // ==========================================================================
  wire [1:0] rsp_code = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__CODE_HI:dfc_types_pkg::DFC_BUFFER_RSP__CODE_LO];
  wire       rsp_ok   = (rsp_code == 2'b00);

  // ==========================================================================
  // Input mailbox (finding 2/3): real shared-buffer-backed 4-deep FIFO,
  // client-relative offsets 0-3 of DFC_BUF_CLIENT5's 8-word window (offsets
  // 4-7 reserved, unwired -- finding 1).
  // ==========================================================================
  localparam logic [1:0] MB_IDLE = 2'd0;
  localparam logic [1:0] MB_REQ  = 2'd1;
  localparam logic [1:0] MB_WAIT = 2'd2;

  logic [1:0]  mb_phase_q;
  logic [1:0]  mb_tail_at_req_q;
  logic [31:0] mb_wdata_q;
  logic [1:0]  in_tail_q;
  logic [2:0]  in_count_q;

  wire push_can_start = (mb_phase_q == MB_IDLE) && (in_count_q != 3'd4);
  wire push_started   = ctl_in_push && push_can_start;
  wire push_rejected  = ctl_in_push && !push_can_start;    // full OR arbiter busy -- finding 2/3

  wire mb_req_fire  = (mb_phase_q == MB_REQ) && buf_req_ready_i;
  wire mb_rsp_fire  = (mb_phase_q == MB_WAIT) && buf_rsp_valid_i;
  wire mb_rsp_ok    = mb_rsp_fire && rsp_ok;
  wire mb_rsp_err   = mb_rsp_fire && !rsp_ok;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      mb_phase_q <= MB_IDLE; mb_tail_at_req_q <= 2'd0; mb_wdata_q <= 32'h0;
      in_tail_q <= 2'd0; in_count_q <= 3'd0;
    end else if (module_reset_i) begin
      mb_phase_q <= MB_IDLE; mb_tail_at_req_q <= 2'd0; mb_wdata_q <= 32'h0;
      in_tail_q <= 2'd0; in_count_q <= 3'd0;
    end else if (do_soft_reset) begin
      // RESET_REQ (ARCH-ULI-003): clears both mailboxes' pointer/valid
      // sets -- abandons any in-flight request too (disclosed: a push in
      // PH_WAIT when RESET_REQ lands is simply abandoned, not completed).
      mb_phase_q <= MB_IDLE; in_tail_q <= 2'd0; in_count_q <= 3'd0;
    end else begin
      case (mb_phase_q)
        MB_IDLE: begin
          if (push_started) begin
            mb_wdata_q        <= ctl_in_data;
            mb_tail_at_req_q  <= in_tail_q;
            mb_phase_q        <= MB_REQ;
          end
        end
        MB_REQ: begin
          if (mb_req_fire) mb_phase_q <= MB_WAIT;
        end
        MB_WAIT: begin
          if (mb_rsp_ok) begin
            in_count_q <= in_count_q + 3'd1;
            in_tail_q  <= in_tail_q + 2'd1;
            mb_phase_q <= MB_IDLE;
          end else if (mb_rsp_err) begin
            mb_phase_q <= MB_IDLE;   // word lost to a shared-buffer error, not counted as overflow -- own diagnostic event instead
          end
        end
        default: mb_phase_q <= MB_IDLE;
      endcase
    end
  end

  assign buf_req_valid_o = (mb_phase_q == MB_REQ);
  assign buf_rsp_ready_o = (mb_phase_q == MB_WAIT);
  assign buf_req_o = {mb_wdata_q, 1'b1, {7'b0, mb_tail_at_req_q}};

  wire in_mailbox_not_empty = (in_count_q != 3'd0);
  wire in_mailbox_full      = (in_count_q == 3'd4);

  // Output mailbox: hardwired fixed-zero (finding 1); every POP attempt is
  // a real underflow against a structurally-always-empty queue.
  wire out_pop_attempt = ctl_out_pop;

  // ==========================================================================
  // Mailbox status evidence (W1C) + independent loss counters
  // (COUNTER16-CLR, bit order matches REG-4050/4054/4058: 0=input
  // overflow, 1=input underflow, 2=output overflow, 3=output underflow).
  // INPUT_UNDERFLOW (bit1) and OUTPUT_OVERFLOW (bit2) are structurally
  // unreachable in this Revision -- finding 2.
  // ==========================================================================
  logic [3:0]  mbox_sticky_q;
  logic [15:0] loss_count_q [0:3];
  wire [3:0] mbox_new_evidence = {1'b0, 1'b0, 1'b0, 1'b0} |
                                ({4{push_rejected}}  & 4'b0001) |
                                ({4{out_pop_attempt}} & 4'b1000);
  integer mb_i;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      mbox_sticky_q <= 4'h0;
      for (mb_i = 0; mb_i < 4; mb_i = mb_i + 1) loss_count_q[mb_i] <= 16'h0;
    end else if (module_reset_i) begin
      mbox_sticky_q <= 4'h0;
      for (mb_i = 0; mb_i < 4; mb_i = mb_i + 1) loss_count_q[mb_i] <= 16'h0;
    end else begin
      for (mb_i = 0; mb_i < 4; mb_i = mb_i + 1) begin
        if (mbox_new_evidence[mb_i]) begin
          mbox_sticky_q[mb_i] <= 1'b1;                              // new evidence, then clear
          loss_count_q[mb_i]  <= (loss_count_q[mb_i] == 16'hFFFF) ? loss_count_q[mb_i] : loss_count_q[mb_i] + 16'd1;
        end else if (ctl_mbox_clear[mb_i]) begin
          mbox_sticky_q[mb_i] <= 1'b0;
        end
        if (ctl_loss_clear[mb_i] && !mbox_new_evidence[mb_i]) loss_count_q[mb_i] <= 16'h0;
      end
    end
  end

  // ==========================================================================
  // Event/IRQ generation. Cause encoding per F.3's own 4-entry list
  // (header finding "second genuine inconsistency"): 0=parameter
  // rejection, 1=diagnostic mailbox activity, 2=reset complete,
  // 3=shared-buffer error. event_id=0x0050 (C.7), evt slot 21 (master
  // table, header finding).
  // ==========================================================================
  wire mailbox_activity = push_started || push_rejected || out_pop_attempt;

  wire cond_param_reject = violation_rising               && event_condition_enable_i[0];
  wire cond_mbox_activity = mailbox_activity               && event_condition_enable_i[1];
  wire cond_reset_complete = do_soft_reset                 && event_condition_enable_i[2];
  wire cond_buf_error     = mb_rsp_err                     && event_condition_enable_i[3];
  wire any_cond = ctl_event_enable &&
                  (cond_param_reject || cond_mbox_activity || cond_reset_complete || cond_buf_error);

  logic        evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic        event_overflow_sticky_q;
  logic [15:0] event_drop_count_q;
  wire         slot_free_evt = !evt_pending_q || evt_ready_i;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_record_q <= '0;
      event_overflow_sticky_q <= 1'b0; event_drop_count_q <= 16'h0;
    end else if (module_reset_i) begin
      evt_pending_q <= 1'b0;
      event_overflow_sticky_q <= 1'b0; event_drop_count_q <= 16'h0;
    end else begin
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;
      if (ctl_clr_event_overflow) event_overflow_sticky_q <= 1'b0;
      if (any_cond) begin
        if (slot_free_evt) begin
          evt_pending_q <= 1'b1;
          evt_record_q <= {
            cond_param_reject ? 32'h0 :
            cond_mbox_activity ? {28'h0, in_count_q} :
            cond_reset_complete ? 32'h0 : 32'h0,
            8'h00,          // [95:88] flags
            8'd21,          // [87:80] source_id = evt bus slot 21
            16'h0050,       // [79:64] event_id (C.7 0x0050)
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
  assign irq_req_o    = 1'b0; // permanently 0 -- header finding (F.3: diagnostic-event-only, never asserts IRQ)
  assign fault_req_o  = 1'b0; // permanently 0, disclosed stub -- header finding

  // ==========================================================================
  // Databus message destination (ARCH-MSG-005/ARCH-ULI-005): accepted and
  // discarded, zero operational effect, zero diagnostic surface -- finding
  // 4. RTL-022 is never a real message source.
  // ==========================================================================
  assign rx_msg_ready_o  = 1'b1;
  assign tx_msg_valid_o  = 1'b0;
  assign tx_msg_record_o = '0;
  logic unused_rx_msg_sink;
  assign unused_rx_msg_sink = rx_msg_valid_i ^ (^rx_msg_record_i);

  // ==========================================================================
  // Permanently-zero operational outputs (ARCH-ULI-002): every state,
  // including test mode, no exception.
  // ==========================================================================
  assign user_o   = 4'b0000;
  assign user_oe_o = 4'b0000;

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__READY_HI]          = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__FAULT_HI]          = 1'b0;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__EVENT_OVERFLOW_HI] = event_overflow_sticky_q;

  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__ENABLED_HI]             = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__READY_HI]               = module_enable_i && !module_reset_i;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__IN_MAILBOX_NOT_EMPTY_HI] = in_mailbox_not_empty;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__OUT_MAILBOX_NOT_EMPTY_HI] = 1'b0;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__IN_MAILBOX_FULL_HI]      = in_mailbox_full;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__OUT_MAILBOX_FULL_HI]     = 1'b0;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__VIOLATION_HI]            = violation_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_STATUS__RESET_COMPLETE_HI]       = reset_complete_sticky_q;

  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_IN_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_IN_LEVEL__LEVEL_LO] = {1'b0, in_count_q};
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_LEVEL__LEVEL_LO] = 3'd0;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_DATA__MAILBOX_DATA_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_OUT_DATA__MAILBOX_DATA_LO] = 32'h0;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_IO_INPUT__INPUT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_IO_INPUT__INPUT_LO] = user_sync2_q;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL022_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_STATUS__OVERFLOW_UNDERFLOW_LO] = mbox_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL022_STATUS__ULI_MAILBOX_LOSS_COUNT__COUNT_LO] =
    {loss_count_q[3], loss_count_q[2], loss_count_q[1], loss_count_q[0]};

endmodule
