// ============================================================================
// dfc_rtl020.sv -- RTL-020 UART Interface (ARCH-RTL020-001)
//
// Controlling spec: docs/rtl_specs/RTL-020_RevA.md (derived; its own SS2
// claims "17 total" ports and SS1/SS5 claim "11 registers" -- both confirmed
// stale this session, the fourth consecutive module spec with a stale port
// count (same class as RTL-017/018/019's own 20/18/19-vs-33/28/33) and the
// first with a stale REGISTER count too: ARCH-002 Appendix A's real header
// reads "RTL-020 - UART Interface (32 ports)" and REG-002's own Section 17
// block header says "Register count: 15" -- REG-002's own listed rows
// confirm 15, not 11: RTL-020_RevA.md's list is missing
// UART_RX_OVERFLOW_COUNT (0x132C), UART_RX_UNDERFLOW_COUNT (0x1330),
// UART_TX_REJECTED_COUNT (0x1334), and UART_TX_UNDERFLOW_COUNT (0x1338)
// entirely -- an entire group of four real diagnostic counters, not a
// single off-by-one. Implemented against the real 32-port/15-register
// set. Owning contracts: ARCH-002 SS11.4 (ARCH-BUS-004, baud/oversample/
// framing), SS12.3 (ARCH-BUF-025/026, 1-word entry layouts), Appendix A
// (32-port catalog), Appendix F.1 ARCH-RTL020-001 (shared-buffer
// discipline, host/route last-slot tiebreaker, disable-vs-reset), Appendix
// F.3 (event/irq condition-mask allocation, 10 real conditions); REG-002
// SS17 (0x1300-0x1338, 15 registers); VP-002 VP-MOD-020/VP-BUS-004.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous local reset (RTL-002.module_reset_o[19]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl020_field_map.json, reggen.py).
//
// ARCH-002-INTERNAL GAP FIXED THIS SESSION (the 12th real instance of the
// exact gap class already fixed for RTL-002 through RTL-019, approved
// before this edit): dfc_rtl020_control_t had no clear-forwarding field for
// RTL020_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-1328 bit 0, a real W1C
// field). Fixed: ARCH-002 grew the struct 215->216 bits, adding
// rtl020_evt_overflow_status__event_overflow at the new highest bit (215)
// -- every pre-existing field's bit position confirmed unchanged via the
// real regenerate.ps1 run this session.
//
// MASTER SHARED-RESOURCE-INDEX TABLE CHECKED BEFORE WIRING (OPEN_ISSUES.md
// item 140, mandatory per this session's own task briefing): RTL-020's own
// Appendix A `activity_o` row literally reads "RTL-015.activity_i[4]" --
// but item 140's own master table (built directly from RTL-015's own
// activity_i row + ARCH-SAFE-007's ID-order text, the resolution authority
// item 83 already established and item 140 already re-confirmed) assigns
// bit 4 to "GPIO any qualified transition" (RTL-006, already real and
// correctly wired there) and assigns bit 3 ("UART RX byte") to THIS
// module. RTL-020's own row is therefore the SAME already-identified-and-
// rejected conflict class as RTL-012/017/019/021's own rows (item 83: five
// conflicting individual rows, each overruled in favor of RTL-015's own
// row) -- not a fresh ambiguity, and not something to re-discover by
// accident the way item 125 did for RTL-018/019. Wired to
// `RTL-015.activity_i[3]` (dfc_rtl024.sv), NOT this module's own row's
// literal [4], which would have silently collided with RTL-006's own
// already-real, already-correct wiring. activity_o pulses on a byte
// genuinely accepted into the RX queue (matching ID 3's own "UART RX
// byte" description exactly), not on any TX event.
//
// ---------------------------------------------------------------------------
// DESIGN, DISCLOSED (ARCH-002/REG-002 describe externally observable
// behavior and the entry layouts; the internal baud/oversample engine,
// queue arbiter, and error classification below are this module's own real
// implementation, built from first principles against those contracts,
// with every interpretation choice called out):
//
//  1. SIXTEEN-ENTRY RX QUEUE + SIXTEEN-ENTRY TX QUEUE, ONE WORD PER ENTRY,
//     SHARING CLIENT 3's 32-WORD SEGMENT (ARCH-BUF-007 RX 0x0B0-0x0BF,
//     ARCH-BUF-008 TX 0x0C0-0x0CF; confirmed against
//     dfc_constants_pkg::DFC_BUF_CLIENT3_WIDTH = 32). Client-relative
//     word_offset is RX_BASE(0)+rx_entry for RX, TX_BASE(16)+tx_entry for
//     TX -- the shared-buffer service itself adds client 3's own absolute
//     base, same confirmed precedent as every prior Databus module. No
//     private queue-entry storage (RTLSTD-MEM-002): both queues live ONLY
//     in the centralized shared-buffer memory. One word per entry (unlike
//     ARINC's 2/4 or CAN's 6) means every arbiter operation below is a
//     single-word read or write -- no word_idx sequencing needed at all,
//     the simplest queue-engine shape in the Databus domain (RTL-020_RevA.md
//     SS4's own, correct observation).
//
//  2. FOUR-WAY INTERNAL BUFFER-CLIENT ARBITER, ONE OUTSTANDING buf_req/rsp
//     AT A TIME (ARCH-BUF-013): RX-COMMIT (a genuinely received byte
//     waiting to be written into the RX queue -- real-time, the serial
//     line does not wait) > RX-HEAD-REFRESH (re-reading the new RX head
//     entry after a POP leaves the queue non-empty, so UART_RX_DATA always
//     reflects the current head with no explicit SNAPSHOT command -- see
//     finding 3) > TX-PUSH (host PUSH or route input, ATX-style last-slot
//     tiebreaker, finding 5) > TX-DEQUEUE (the TX serializer pulling its
//     next byte). Same single-outstanding-request discipline as every
//     prior Databus module's own FSM (never issuing word N+1 before word
//     N's response arrives).
//
//  3. UART_RX_DATA IS A CONTINUOUSLY-MAINTAINED SNAPSHOT, NOT AN EXPLICIT-
//     CAPTURE REGISTER (DISCLOSED DESIGN CHOICE, not restated spec): unlike
//     RTL-017's ARX_SNAPSHOT/ARX_DATA pair (ARINC RX has a dedicated
//     CAPTURE command), REG-002's UART block has no equivalent
//     "UART_RX_SNAPSHOT" register at all -- UART_RX_DATA's own text just
//     says "reads the coherent selected/snapshot value," with no command
//     register to drive a capture. This module keeps a one-entry head
//     cache (head_snap_valid_q/data_q/flags_q/seq_q) that is refreshed
//     every time the RX head entry could have changed: a POP that leaves
//     the queue non-empty (RX-HEAD-REFRESH above), or a commit while the
//     queue was empty (the new byte becomes head). For simplicity and
//     correctness over a micro-optimization, EVERY such event schedules a
//     real RX-HEAD-REFRESH read rather than special-casing "I already have
//     this word in hand" at commit time -- a negligible extra read-latency
//     cost (one shared-buffer round trip, typically a handful of CORE_CLK
//     cycles, utterly negligible against real UART bit times even at the
//     fastest legal baud) in exchange for one single, uniformly-correct
//     code path instead of two. UART_RX_POP is otherwise pure pointer
//     bookkeeping (head_q/count_q only), same "POP never touches the
//     buffer itself" precedent as RTL-017's own finding 3.
//
//  4. HOST-POP-VS-ROUTE-DRAIN SAME-HEAD ARBITRATION (same structural
//     concern as RTL-017's own finding 4, here genuinely unreachable in
//     this integration since rx_msg_ready_i is tied to a disclosed stub --
//     RTL-021 does not exist yet -- but implemented correctly, not
//     skipped): on the rare same-cycle race between a host POP pulse and a
//     route-drain accept (rx_msg_ready_i && rx_msg_valid_o), host POP wins
//     (same disclosed choice as RTL-017's own finding 4(b): a host POP is
//     a deliberate, already-committed action; the route path's own commit
//     at that instant is just this module's internal bookkeeping catching
//     up). The message is still delivered to RTL-021 the same cycle either
//     way; only whether head_q/count_q advance a SECOND time for the same
//     entry is affected (suppressed when host POP already won).
//
//  5. HOST-PUSH-VS-ROUTE-INPUT LAST-FREE-SLOT TIEBREAKER (ARCH-RTL020-001,
//     identical structural shape to RTL-018's own finding 2): "host wins
//     ONLY when both target the last free slot," not a blanket priority.
//     tx_msg_valid_i is tied to a disclosed stub (1'b0) in this integration
//     (RTL-021 does not exist yet) -- real, spec-correct logic that cannot
//     actually activate in this build, same disclosed-gap shape as every
//     prior Databus module's own route-input finding.
//
//  6. BIT-LEVEL TX SERIALIZER AND TIMING. TX uses a plain CORE_CLK-cycle
//     divider (UART_BAUD_DIV.DIVISOR cycles per bit, reloaded each bit --
//     TX does not need oversampling, only RX does per ARCH-BUS-004's own
//     text, which specifically requires the 16-phase/3-sample-vote
//     mechanism for receiving, never mentioning it for transmission).
//     Frame: 1 start bit (0), 8 data bits LSB-first (the universal,
//     external, well-known UART convention -- ARCH-002/REG-002 state no
//     bit order for UART, unlike ARINC's explicit "32 bits LSB-first," so
//     this is a disclosed external-standard choice, not invented), 1
//     parity bit when PARITY!=0 (even/odd per REG-ENC-007), 1 or 2 stop
//     bits (1) per TWO_STOP_BITS. uart_tx_o idles high (1); the start bit
//     and any 0 data/parity bit drive it low for one bit time.
//     DISABLE-VS-RESET (the one real behavioral distinction this session's
//     own briefing specifically called out, now its own dedicated
//     testbench case, not incidental reset coverage): the serializer only
//     ever checks ctl_enable at the moment it is about to START a new
//     byte (dequeue_start below) -- once a byte is in flight, ctl_enable
//     going to 0 does NOT abort it; the in-progress byte (including its
//     stop bit(s)) completes normally and the line idles high only once
//     truly done, exactly "disable completes the current transmitted
//     character then idles high." module_reset_i/core_rst_n_i, by
//     contrast, unconditionally force the serializer back to IDLE (and the
//     line high) on the very next edge regardless of state -- "reset
//     aborts immediately." No extra logic is needed to get this right: it
//     falls directly out of ctl_enable being consulted ONLY at
//     dequeue_start and never again until the next byte, the same
//     technique RTL-018 already uses for its own (unrelated) enable gate.
//
//  7. SIXTEEN-PHASE FRACTIONAL-ACCUMULATOR OVERSAMPLING AND 3-SAMPLE
//     MAJORITY VOTE (ARCH-BUS-004's own explicit text: "a fractional phase
//     accumulator derives 16 evenly spaced sample phases and votes the
//     three samples centered on each bit" -- a real, specific algorithmic
//     requirement, not a simplification left to this module's own
//     judgment). A free-running Bresenham-style accumulator
//     (phase_acc_q += 16 each CORE_CLK cycle; whenever phase_acc_q+16 >=
//     DIVISOR, instead subtract DIVISOR and emit one phase_tick) produces
//     exactly 16 phase_tick pulses evenly spread across every DIVISOR
//     CORE_CLK cycles -- the literal "fractional phase accumulator"
//     technique, not a plain divide-by-16. Each bit's own phase_count_q
//     (0-15, incremented once per phase_tick) drives a 3-sample window at
//     phases 7, 8, and 9 (the three ticks nearest the bit's own center,
//     disclosed choice -- ARCH-BUS-004 says "centered on each bit" but
//     gives no exact phase numbers): the synchronized uart_rx_i line is
//     sampled at each of those three ticks into a small shift register,
//     and the majority (>=2 of 3) is this bit's real sampled value,
//     latched at phase 9. The bit itself is considered complete (ready to
//     advance to the next bit/state) at phase 15.
//
//  8. START-BIT DETECTION AND GLITCH REJECTION. RX_IDLE continuously
//     watches the synchronized line for a high-to-low transition (real
//     edge detection, not a level check, so a line already low at
//     power-up/reset never falsely triggers). On that edge, phase_count_q
//     resets to 0 and the engine enters the START state; the START bit's
//     own 3-sample vote (phases 7/8/9, i.e. roughly mid-bit) must read
//     dominant (0) to confirm a real start condition -- a majority-1
//     result (noise glitch, not a real start) returns to RX_IDLE with no
//     error of any kind, standard UART glitch rejection, not a defect.
//
//  9. FRAMING/PARITY/BREAK CLASSIFICATION (REG-ENC-007/ARCH-BUS-004 give
//     the legal encodings; the specific break-detection heuristic below is
//     this module's own disclosed choice -- neither document states a
//     bit-exact break algorithm). FRAMING_ERROR: the first stop bit's own
//     3-sample vote reads 0 instead of the required 1 (the second stop
//     bit, when TWO_STOP_BITS=1, is timed but its own value is not
//     separately validated -- a disclosed simplification, common to many
//     real UART implementations, matching this project's own "parameterize
//     real timing, keep the validated contract narrow" precedent).
//     PARITY_ERROR: when PARITY!=0, the sampled parity bit disagrees with
//     the computed even/odd parity of the 8 real sampled data bits.
//     BREAK_DETECTED (a distinct, OVERRIDING condition, not an additional
//     one): when the stop-bit framing check fails AND every one of the 8
//     data bits AND the parity bit (if checked) all sampled 0 -- i.e. the
//     entire frame was held low, the standard real-world signature of a
//     break condition, not an ordinary single-bit framing glitch. On a
//     real break, FRAMING_ERROR/PARITY_ERROR are NOT also set (BREAK_
//     DETECTED alone reports it, per this module's own disclosed
//     classification priority), and -- disclosed choice, ARCH-RTL020-001
//     does not state this either way -- no byte is queued at all for a
//     break (there is no real framed byte to report, only a line
//     condition), unlike an ordinary framing/parity error, where the
//     byte+flags unit IS still queued (ARCH-RTL020-001: "a received byte
//     plus flags becomes valid atomically after stop-bit evaluation" --
//     stop-bit evaluation still genuinely happened, it just failed).
//     DEFENSIVE CLAMP (REG-ENC-007: "parity 3 is rejected," and RTL-001
//     does not yet implement per-field legal-value range checks at all --
//     the same already-disclosed, pre-existing gap RTL-001's own header
//     names as its single biggest conformance gap): PARITY==2'b11 is
//     treated identically to PARITY==2'b00 (no parity bit at all) by both
//     the RX sampler and TX serializer, the same defensive-clamp-for-an-
//     illegal-2-bit-encoding precedent RTL-019's own CAN LOOPBACK/
//     LISTEN_ONLY `11` handling already established (OPEN_ISSUES.md item
//     131) -- not a numeric range re-validation (DIVISOR's own 50-50,000
//     legal range is NOT re-validated here, consistent with every other
//     module's numeric configuration fields never being re-validated
//     either; only illegal ENCODING values get this treatment).
//
// 10. RX OVERFLOW / DROPPED-BYTE (REG-1324's own exact text: "Saturating
//     receive overflow OR dropped-byte count" -- the spec itself names two
//     distinct causes under one counter). A completed RX byte is staged
//     into a one-deep register (rx_stage_valid_q) for the arbiter to
//     write; TWO distinct real conditions both increment
//     UART_RX_OVERFLOW_COUNT/set RX_OVERFLOW sticky: (a) a new byte
//     completes while rx_stage_valid_q is STILL set (the arbiter has not
//     yet drained the previous staged byte -- a genuine dropped byte, the
//     new byte is discarded, not the old one, so evidence of what WAS
//     already in flight is preserved) -- structurally rare in practice
//     given real UART bit times vs. this module's few-cycle buffer-write
//     latency, same "handled defensively, disclosed, not assumed
//     unreachable" treatment as RTL-017's own finding 8; and (b) the
//     arbiter attempts the RX-COMMIT write and finds the RX QUEUE ITSELF
//     already full (rx_count_q==16) -- the ordinary full-queue case. Both
//     represent the identical externally observable fact "a received byte
//     could not be queued," matching REG-002's own "overflow or
//     dropped-byte" wording exactly, not a guess.
//
// 11. ERROR/EVIDENCE CLASSIFICATION, THE REST. RX_UNDERFLOW (sticky +
//     UART_RX_UNDERFLOW_COUNT): UART_RX_POP.POP while the RX queue is
//     empty. TX_REJECTED (sticky + UART_TX_REJECTED_COUNT): a host
//     UART_TX_PUSH.PUSH while the TX queue is full OR the module is
//     disabled (REG-1320's own "full-queue or disabled request is
//     rejected" text), same shape as RTL-018's own host_push_rejected.
//     TX_UNDERFLOW (sticky + UART_TX_UNDERFLOW_COUNT): the TX engine goes
//     idle-while-empty, counted once per occurrence via a pending latch,
//     same technique as RTL-018's own underrun_now. UART_ERROR_COUNT
//     (DISCLOSED CHOICE, same reasoning as RTL-017/018's own generic
//     aggregate counters -- REG-002's own text, "Saturating aggregate UART
//     error count," does not name a specific trigger distinct from the
//     four counters that already have their own dedicated register):
//     increments once per occurrence of FRAMING_ERROR, PARITY_ERROR, or
//     BREAK_DETECTED (the three data-quality/line conditions with no
//     dedicated counter of their own), OR once per shared-buffer
//     transaction (RX commit, TX push, or TX dequeue) that returns a
//     non-OK response code.
//
// 12. EVENTS/IRQ (Appendix F.3, 10 real condition bits -- the richest
//     allocation outside RTL-019's own CAN controller): 0 receive
//     (fires when a byte is genuinely committed into the RX queue, i.e.
//     the RX-COMMIT write itself succeeds -- not merely staged, same
//     "fire at actual successful commit" precedent as RTL-017's own
//     write_word_commit), 1 transmit (TX serializer completes a byte), 2
//     framing, 3 parity, 4 overflow (either dropped-byte sub-case from
//     finding 10), 5 underflow (DISCLOSED CHOICE: REG-002/Appendix F.3
//     give this module only ONE "underflow" condition bit while there are
//     TWO real, independently counted underflow conditions internally,
//     RX_UNDERFLOW and TX_UNDERFLOW -- both real triggers share this one
//     bit, the same "two real conditions, one condition-enable bit"
//     disclosed-interpretation precedent RTL-018's own bits 1/2 and
//     RTL-019's own bit 4 already established), 6 break, 7 recovery (no
//     real internal condition drives this -- structurally unreachable,
//     same disclosed-unreachable treatment as every prior module's own
//     "recovery" bit), 8 shared-buffer error, 9 event-slot overflow. One
//     shared pending slot (same generic per-module shape as every other
//     module); irq_req_o qualified against irq_condition_enable_i[cause]
//     for whichever cause is currently latched. event_data: cause 0
//     (receive) carries the full real committed RX entry word verbatim
//     (data/flags/sequence, the same "one classification encoding, reused
//     everywhere" precedent as every prior module); every other cause
//     carries {24'h0, cause_code} (same generic fallback as RTL-018/019's
//     own non-primary causes). event_condition_enable_i/
//     irq_condition_enable_i tie to the same disclosed 64'h0 stub every
//     other module uses (RTL-001 does not yet implement Appendix F.3
//     per-module CONDITION_MASK storage) -- none of RTL-020's real event
//     conditions can fire in this integration yet, the same disclosed
//     consequence as every prior module's own finding.
//
// 13. ROUTE PORTS AND THE SELF-REFERENTIAL MODULE ID (ARCH-MSG-003: UART RX
//     and UART TX share module ID 0x02 for both source and destination,
//     the same self-referential pattern RTL-019's own CAN already
//     established at ID 0x01 -- confirmed via the real 5x5 authorization
//     matrix, ARCH-002 SS11.2: UART-RX-to-UART-TX is `0`, disallowed, the
//     identical pattern as CAN-RX-to-CAN-TX). This module implements two
//     ORDINARY, INDEPENDENT port pairs -- rx_msg_valid_o/rx_msg_ready_i/
//     rx_msg_record_o (source, draining the RX queue to RTL-021) and
//     tx_msg_valid_i/tx_msg_ready_o/tx_msg_record_i (destination, accepting
//     a routed byte into the TX queue) -- with NO internal cross-wiring,
//     matching RTL-019's own finding 11 exactly: the real self-
//     referential-ID policy question is RTL-021's (not yet built) to
//     enforce via the authorization matrix, not this module's to special-
//     case. Both route ports tie to disclosed stubs in this integration
//     (RTL-021 does not exist yet). message_record mapping (dfc_message_
//     record_t, 192 bits -- the generic 8-field canonical layout, ARCH-002
//     gives no UART-specific sub-mapping; this module's own disclosed
//     choice, consistent with RTL-017/018/019's own already-shipped
//     convention of payload-for-the-data/metadata-for-classification,
//     flagged in OPEN_ISSUES.md as a genuine, newly-found ARCH-002-
//     internal tension against SS11.1's own generic per-type text, which
//     literally describes UART's data as living in METADATA bits 7:0 with
//     payload length zero -- this module follows the already-shipped
//     sibling-module convention instead, for project-wide consistency,
//     since this entire path is unreachable either way until RTL-021
//     exists): source_id=8'h02, message_type=8'h04 (UART_BYTE),
//     payload_length=4'd1, payload[63:0]={56'h0,data} (LSB-justified),
//     metadata[31:0]={sequence[15:0],error_flags[7:0],data[7:0]} (the real
//     RX entry word, reused verbatim), sequence[3:0]=the entry's own
//     16-bit sequence truncated (disclosed information loss, same
//     precedent as RTL-017's own finding 6), flags[0]=parity_error,
//     flags[1]=framing_error, flags[7:2]=0, timestamp=timestamp_i read
//     LIVE at drain time (DISCLOSED LIMITATION: ARCH-BUF-025's own 1-word
//     RX entry layout has no stored timestamp field at all, unlike ARINC's
//     4-word/CAN's 6-word entries which both carry one -- this module
//     cannot replay the real original receive time for a route-drained
//     byte, only the time it happened to be read, same class of
//     information loss as finding 6's sequence truncation, just total
//     rather than partial). A routed byte accepted via tx_msg_valid_i
//     becomes a committed TX entry with data=tx_msg_record_i's own
//     payload[7:0] (consistent with the same convention), no
//     module-specific metadata of its own to preserve.
//
// 14. FAULT. DISCLOSED CHOICE, same reasoning as every prior Databus
//     module's own finding: no dedicated external hardware-fault pin
//     exists for UART (unlike ARINC/CAN's adapter-error/transceiver-error
//     inputs -- UART_BUS-004 names no such signal and Appendix A's real
//     32-port table confirms no such input port exists for RTL-020), so
//     fault_req_o is tied to a disclosed, permanently-0 stub (no internal
//     condition in this module rises to system-wide fault severity) --
//     RX/TX errors are ordinary operational conditions already visible via
//     their own sticky bits and counters, not systemic faults, the same
//     severity judgment RTL-017/018's own fault_req_o documentation
//     already applies to their own non-adapter-error conditions.
// ============================================================================

module dfc_rtl020 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[19]

  input  logic [dfc_types_pkg::DFC_RTL020_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL020_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[6]
  output logic         fault_req_o,          // RTL-013.fault_source_i[13] (disclosed stub, finding 14)

  input  logic         uart_rx_i,            // already-synchronized (CDC-UART)
  output logic         uart_tx_o,

  output logic         rx_msg_valid_o,       // RTL-021.source_valid_i[2]
  input  logic         rx_msg_ready_i,       // RTL-021.source_ready_o[2]
  output logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] rx_msg_record_o,

  input  logic         tx_msg_valid_i,       // RTL-021.dest_valid_o[2]
  output logic         tx_msg_ready_o,       // RTL-021.dest_ready_i[2]
  input  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] tx_msg_record_i,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  output logic         activity_o,           // RTL-015.activity_i[3] (item 140 -- NOT this module's own row's literal [4])

  input  logic         module_enable_i,      // RTL-002.module_enable_o[19]
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
  // per-operating-state behavior specified for RTL-020 anywhere in the
  // -002 set -- a disclosed, genuinely-unused pair, same precedent as
  // every prior Databus module.
  logic unused_op_state_sink;
  assign unused_op_state_sink = (^operating_state_i) ^ observational_mode_i;

  localparam int unsigned QDEPTH  = 16;
  localparam int unsigned RX_BASE = 0;
  localparam int unsigned TX_BASE = 16;

  // ==========================================================================
  // Shared-buffer response-code check (CODE_OK=2'b00 convention, same as
  // every prior Databus module).
  // ==========================================================================
  wire [1:0]  rsp_code = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__CODE_HI:dfc_types_pkg::DFC_BUFFER_RSP__CODE_LO];
  wire        rsp_ok   = (rsp_code == 2'b00);
  wire [31:0] rsp_data = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_HI:dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_LO];

  // ==========================================================================
  // Control-field unpack.
  // ==========================================================================
  wire ctl_enable        = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__ENABLE_HI];
  wire [1:0] ctl_parity_raw = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__PARITY_LO];
  // DEFENSIVE CLAMP (finding 9): PARITY==2'b11 behaves as 2'b00 (no parity).
  wire [1:0] ctl_parity  = (ctl_parity_raw == 2'b11) ? 2'b00 : ctl_parity_raw;
  wire ctl_two_stop_bits = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__TWO_STOP_BITS_HI];
  wire ctl_event_enable  = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__EVENT_ENABLE_HI];
  wire ctl_irq_enable    = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_CONTROL__IRQ_ENABLE_HI];
  wire ctl_clr_framing_error = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__FRAMING_ERROR_HI];
  wire ctl_clr_parity_error  = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__PARITY_ERROR_HI];
  wire ctl_clr_rx_overflow   = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__RX_OVERFLOW_HI];
  wire ctl_clr_tx_underflow  = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__TX_UNDERFLOW_HI];
  wire ctl_clr_break_detected = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__BREAK_DETECTED_HI];
  wire ctl_clr_rx_underflow  = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__RX_UNDERFLOW_HI];
  wire ctl_clr_tx_rejected   = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_STATUS__TX_REJECTED_HI];
  wire [31:0] ctl_divisor    = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_BAUD_DIV__DIVISOR_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_BAUD_DIV__DIVISOR_LO];
  wire ctl_rx_pop_pulse      = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_POP__POP_HI];
  wire [7:0] ctl_tx_data     = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_DATA__DATA_LO];
  wire ctl_tx_push_pulse     = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_PUSH__PUSH_HI];
  wire [31:0] ctl_error_count_wr          = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_ERROR_COUNT__COUNT_LO];
  wire [31:0] ctl_rx_overflow_count_wr    = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_OVERFLOW_COUNT__COUNT_LO];
  wire [31:0] ctl_rx_underflow_count_wr   = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_RX_UNDERFLOW_COUNT__COUNT_LO];
  wire [31:0] ctl_tx_rejected_count_wr    = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_REJECTED_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_REJECTED_COUNT__COUNT_LO];
  wire [31:0] ctl_tx_underflow_count_wr   = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_CONTROL__UART_TX_UNDERFLOW_COUNT__COUNT_LO];
  wire ctl_clr_event_overflow = control_i[dfc_types_pkg::DFC_RTL020_CONTROL__RTL020_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  logic [31:0] error_count_wr_q, rx_overflow_count_wr_q, rx_underflow_count_wr_q, tx_rejected_count_wr_q, tx_underflow_count_wr_q;
  wire clr_error_count_now         = (ctl_error_count_wr         == 32'hFFFFFFFF) && (error_count_wr_q         != 32'hFFFFFFFF);
  wire clr_rx_overflow_count_now   = (ctl_rx_overflow_count_wr   == 32'hFFFFFFFF) && (rx_overflow_count_wr_q   != 32'hFFFFFFFF);
  wire clr_rx_underflow_count_now  = (ctl_rx_underflow_count_wr  == 32'hFFFFFFFF) && (rx_underflow_count_wr_q  != 32'hFFFFFFFF);
  wire clr_tx_rejected_count_now   = (ctl_tx_rejected_count_wr   == 32'hFFFFFFFF) && (tx_rejected_count_wr_q   != 32'hFFFFFFFF);
  wire clr_tx_underflow_count_now  = (ctl_tx_underflow_count_wr  == 32'hFFFFFFFF) && (tx_underflow_count_wr_q  != 32'hFFFFFFFF);

  // ==========================================================================
  // Declarations up front (Icarus declare-before-use discipline, same
  // reasoning as RTL-019's own header note -- this module's single shared
  // arbiter touches RX queue, TX queue, RX sampler, and TX serializer
  // state together).
  // ==========================================================================
  localparam logic [2:0] OP_NONE         = 3'd0;
  localparam logic [2:0] OP_RX_COMMIT    = 3'd1;
  localparam logic [2:0] OP_HEAD_REFRESH = 3'd2;
  localparam logic [2:0] OP_TX_PUSH      = 3'd3;
  localparam logic [2:0] OP_TX_DEQUEUE   = 3'd4;
  localparam logic [1:0] PH_IDLE = 2'd0;
  localparam logic [1:0] PH_REQ  = 2'd1;
  localparam logic [1:0] PH_WAIT = 2'd2;

  logic [2:0] op_q;
  logic [1:0] phase_q;
  logic [31:0] wr_word_q;
  logic [31:0] rd_word_q;

  logic [3:0] rx_head_q, rx_tail_q;
  logic [4:0] rx_count_q;
  logic [3:0] tx_head_q, tx_tail_q;
  logic [4:0] tx_count_q;
  logic [15:0] rx_seq_q;

  wire rx_queue_full  = (rx_count_q == QDEPTH[4:0]);
  wire rx_queue_empty = (rx_count_q == 5'd0);
  wire tx_queue_full  = (tx_count_q == QDEPTH[4:0]);
  wire tx_queue_empty = (tx_count_q == 5'd0);

  // ---- RX byte staging (finding 10) ----
  logic       rx_stage_valid_q;
  logic [7:0] rx_stage_data_q;
  logic [7:0] rx_stage_flags_q;

  // ---- RX head snapshot cache (finding 3) ----
  logic        head_snap_valid_q;
  logic [7:0]  head_snap_data_q;
  logic [7:0]  head_snap_flags_q;
  logic [15:0] head_snap_seq_q;
  logic        head_refresh_pending_q;

  // ---- sticky evidence / counters ----
  logic framing_error_sticky_q, parity_error_sticky_q, rx_overflow_sticky_q;
  logic tx_underflow_sticky_q, break_detected_sticky_q, rx_underflow_sticky_q, tx_rejected_sticky_q;
  logic [31:0] error_count_q, rx_overflow_count_q, rx_underflow_count_q, tx_rejected_count_q, tx_underflow_count_q;
  logic tx_underflow_pending_q;

  // ---- TX push validation (same shape as RTL-018's own push_pending_q) ----
  logic push_pending_q;
  wire  arb_idle          = (phase_q == PH_IDLE);
  wire  host_push_want    = push_pending_q || ctl_tx_push_pulse;
  wire  host_push_service = arb_idle && host_push_want && (op_q == OP_NONE);
  wire  host_push_accepted = host_push_service && ctl_enable && !tx_queue_full;
  wire  host_push_rejected = host_push_service && (!ctl_enable || tx_queue_full);

  // ---- Route-input translation (finding 5), genuinely unreachable while
  // tx_msg_valid_i is tied to the disclosed stub. payload[63:64-8]... the
  // real dfc_message_record_t payload field is [127:64] of the 192-bit
  // record (64 bits wide, LSB-justified); for this consumer only the
  // low byte matters. ----
  wire [7:0] route_tx_data = tx_msg_record_i[71:64];
  wire       route_push_req = tx_msg_valid_i;
  wire       route_push_accepted = arb_idle && !host_push_want && route_push_req &&
                                    (op_q == OP_NONE) && ctl_enable && !tx_queue_full;
  assign tx_msg_ready_o = route_push_accepted;

  // ---- RX completed-bit staging interface (driven by the RX sampler
  // FSM further down; consumed by the arbiter) ----
  logic       rx_commit_want_q;  // pulses once per completed frame that should be QUEUED (break suppresses this)
  logic       rx_frame_done_q;   // pulses once per completed frame UNCONDITIONALLY, incl. break -- classification/evidence always fires even when the byte itself is not queued
  logic [7:0] rx_commit_data_q;
  logic [7:0] rx_commit_flags_q;

  // ---- TX serializer handshake into the arbiter ----
  logic tx_idle;
  wire dequeue_start = tx_idle && !tx_queue_empty && ctl_enable && effective_operational_enable_i &&
                       (op_q == OP_NONE) && (phase_q == PH_IDLE);

  // ==========================================================================
  // Internal buffer-client arbiter wiring.
  // ==========================================================================
  wire read_word_ok  = (phase_q == PH_WAIT) && buf_rsp_valid_i && rsp_ok;
  wire read_word_err = (phase_q == PH_WAIT) && buf_rsp_valid_i && !rsp_ok;

  assign buf_req_valid_o = (phase_q == PH_REQ);
  assign buf_rsp_ready_o = (phase_q == PH_WAIT);

  wire [3:0] req_entry = (op_q == OP_RX_COMMIT) ? rx_tail_q :
                         (op_q == OP_HEAD_REFRESH) ? rx_head_q :
                         (op_q == OP_TX_PUSH) ? tx_tail_q : tx_head_q;
  wire [4:0] req_base  = (op_q == OP_RX_COMMIT || op_q == OP_HEAD_REFRESH) ? RX_BASE[4:0] : TX_BASE[4:0];
  wire       req_is_write = (op_q == OP_RX_COMMIT) || (op_q == OP_TX_PUSH);
  wire [4:0] req_offset = req_base + {1'b0, req_entry};

  assign buf_req_o = {
    wr_word_q,                  // [41:10] write_data
    req_is_write,               // [9] write
    {4'b0, req_offset}          // [8:0] word_offset (client-relative, 0-31)
  };

  // ==========================================================================
  // Unified arbiter + queue-pointer + sticky/counter always_ff (ONE block,
  // deliberately not split further -- rx_head_q/rx_count_q/tx_head_q/
  // tx_count_q etc. are each legitimately touched by more than one real
  // event per cycle; splitting this up produces the same real multi-driver
  // elaboration failure RTL-018/019's own header comments already
  // document hitting).
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; wr_word_q <= 32'h0; rd_word_q <= 32'h0;
      rx_head_q <= 4'd0; rx_tail_q <= 4'd0; rx_count_q <= 5'd0; rx_seq_q <= 16'h0;
      tx_head_q <= 4'd0; tx_tail_q <= 4'd0; tx_count_q <= 5'd0;
      rx_stage_valid_q <= 1'b0; rx_stage_data_q <= 8'h0; rx_stage_flags_q <= 8'h0;
      head_snap_valid_q <= 1'b0; head_snap_data_q <= 8'h0; head_snap_flags_q <= 8'h0;
      head_snap_seq_q <= 16'h0; head_refresh_pending_q <= 1'b0;
      framing_error_sticky_q <= 1'b0; parity_error_sticky_q <= 1'b0; rx_overflow_sticky_q <= 1'b0;
      tx_underflow_sticky_q <= 1'b0; break_detected_sticky_q <= 1'b0;
      rx_underflow_sticky_q <= 1'b0; tx_rejected_sticky_q <= 1'b0;
      error_count_q <= 32'h0; rx_overflow_count_q <= 32'h0; rx_underflow_count_q <= 32'h0;
      tx_rejected_count_q <= 32'h0; tx_underflow_count_q <= 32'h0;
      error_count_wr_q <= 32'h0; rx_overflow_count_wr_q <= 32'h0; rx_underflow_count_wr_q <= 32'h0;
      tx_rejected_count_wr_q <= 32'h0; tx_underflow_count_wr_q <= 32'h0;
      tx_underflow_pending_q <= 1'b0; push_pending_q <= 1'b0;
    end else if (module_reset_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE;
      rx_head_q <= 4'd0; rx_tail_q <= 4'd0; rx_count_q <= 5'd0; rx_seq_q <= 16'h0;
      tx_head_q <= 4'd0; tx_tail_q <= 4'd0; tx_count_q <= 5'd0;
      rx_stage_valid_q <= 1'b0; head_snap_valid_q <= 1'b0; head_refresh_pending_q <= 1'b0;
      framing_error_sticky_q <= 1'b0; parity_error_sticky_q <= 1'b0; rx_overflow_sticky_q <= 1'b0;
      tx_underflow_sticky_q <= 1'b0; break_detected_sticky_q <= 1'b0;
      rx_underflow_sticky_q <= 1'b0; tx_rejected_sticky_q <= 1'b0;
      tx_underflow_pending_q <= 1'b0; push_pending_q <= 1'b0;
    end else begin
      // ---- edge-detected COUNTER-CLR clears ----
      error_count_wr_q        <= ctl_error_count_wr;
      rx_overflow_count_wr_q  <= ctl_rx_overflow_count_wr;
      rx_underflow_count_wr_q <= ctl_rx_underflow_count_wr;
      tx_rejected_count_wr_q  <= ctl_tx_rejected_count_wr;
      tx_underflow_count_wr_q <= ctl_tx_underflow_count_wr;
      if (clr_error_count_now)        error_count_q         <= 32'h0;
      if (clr_rx_overflow_count_now)  rx_overflow_count_q   <= 32'h0;
      if (clr_rx_underflow_count_now) rx_underflow_count_q  <= 32'h0;
      if (clr_tx_rejected_count_now)  tx_rejected_count_q   <= 32'h0;
      if (clr_tx_underflow_count_now) tx_underflow_count_q  <= 32'h0;

      // ---- sticky W1C clears (new evidence dominates, project-wide precedent) ----
      if (ctl_clr_framing_error)  framing_error_sticky_q  <= 1'b0;
      if (ctl_clr_parity_error)   parity_error_sticky_q   <= 1'b0;
      if (ctl_clr_rx_overflow)    rx_overflow_sticky_q    <= 1'b0;
      if (ctl_clr_tx_underflow)   tx_underflow_sticky_q   <= 1'b0;
      if (ctl_clr_break_detected) break_detected_sticky_q <= 1'b0;
      if (ctl_clr_rx_underflow)   rx_underflow_sticky_q   <= 1'b0;
      if (ctl_clr_tx_rejected)    tx_rejected_sticky_q    <= 1'b0;

      // ---- host-push rejection (full/disabled, finding 5) ----
      if (host_push_rejected) begin
        tx_rejected_sticky_q <= 1'b1;
        tx_rejected_count_q  <= (tx_rejected_count_q == 32'hFFFFFFFF) ? tx_rejected_count_q : tx_rejected_count_q + 32'd1;
      end

      // ---- RX underflow: empty POP (finding 11) ----
      if (ctl_rx_pop_pulse && rx_queue_empty) begin
        rx_underflow_sticky_q <= 1'b1;
        rx_underflow_count_q  <= (rx_underflow_count_q == 32'hFFFFFFFF) ? rx_underflow_count_q : rx_underflow_count_q + 32'd1;
      end

      // ---- TX underflow: idle-while-empty, one pulse per occurrence ----
      if (!tx_queue_empty || !ctl_enable) tx_underflow_pending_q <= 1'b0;
      else if (tx_idle && tx_queue_empty && ctl_enable && !tx_underflow_pending_q) tx_underflow_pending_q <= 1'b1;
      if (tx_idle && tx_queue_empty && ctl_enable && !tx_underflow_pending_q) begin
        tx_underflow_sticky_q <= 1'b1;
        tx_underflow_count_q  <= (tx_underflow_count_q == 32'hFFFFFFFF) ? tx_underflow_count_q : tx_underflow_count_q + 32'd1;
      end

      // ---- RX byte completed by the sampler this cycle (finding 10) ----
      if (rx_commit_want_q) begin
        if (rx_stage_valid_q) begin
          // dropped byte: arbiter hasn't drained the previous staged byte yet
          rx_overflow_sticky_q <= 1'b1;
          rx_overflow_count_q  <= (rx_overflow_count_q == 32'hFFFFFFFF) ? rx_overflow_count_q : rx_overflow_count_q + 32'd1;
        end else begin
          rx_stage_valid_q <= 1'b1;
          rx_stage_data_q  <= rx_commit_data_q;
          rx_stage_flags_q <= rx_commit_flags_q;
        end
      end

      // ---- host POP (pure pointer bookkeeping, finding 3/4) vs. route
      // drain same-head arbitration: host POP wins a same-cycle race. ----
      begin
        logic pop_now;
        logic route_accept_now;
        pop_now           = ctl_rx_pop_pulse && !rx_queue_empty;
        route_accept_now  = rx_msg_ready_i && rx_msg_valid_o && !pop_now;
        if (pop_now || route_accept_now) begin
          rx_head_q  <= rx_head_q + 4'd1;
          rx_count_q <= rx_count_q - 5'd1;
          if (rx_count_q - 5'd1 == 5'd0) begin
            head_snap_valid_q <= 1'b0;
          end else begin
            head_refresh_pending_q <= 1'b1;
          end
        end
      end

      // ---- arbiter: RX-COMMIT > RX-HEAD-REFRESH > TX-PUSH > TX-DEQUEUE ----
      case (phase_q)
        PH_IDLE: begin
          if (rx_stage_valid_q) begin
            // Sub-case (b) of finding 10 (REG-1324's own "overflow OR
            // dropped-byte" text): the QUEUE ITSELF is full at the exact
            // moment the arbiter is ready to commit the staged byte --
            // distinct from sub-case (a) (staging register already
            // occupied, checked where rx_stage_valid_q is first set
            // above). A real, confirmed gap: this sub-case was disclosed
            // in this module's own header comment but never actually
            // implemented until caught by this module's own testbench
            // (Case 10) -- the staged byte was silently written into the
            // queue regardless of fullness, corrupting count_q/overflowing
            // the real 16-entry client segment. Dropped here instead,
            // with no shared-buffer request ever issued for it.
            if (rx_queue_full) begin
              rx_stage_valid_q <= 1'b0;
              rx_overflow_sticky_q <= 1'b1;
              rx_overflow_count_q  <= (rx_overflow_count_q == 32'hFFFFFFFF) ? rx_overflow_count_q : rx_overflow_count_q + 32'd1;
            end else begin
              op_q <= OP_RX_COMMIT; phase_q <= PH_REQ;
              wr_word_q <= {rx_seq_q, rx_stage_flags_q, rx_stage_data_q};
            end
          end else if (head_refresh_pending_q) begin
            op_q <= OP_HEAD_REFRESH; phase_q <= PH_REQ;
          end else if (host_push_accepted) begin
            op_q <= OP_TX_PUSH; phase_q <= PH_REQ;
            wr_word_q <= {24'h0, ctl_tx_data};
          end else if (route_push_accepted) begin
            op_q <= OP_TX_PUSH; phase_q <= PH_REQ;
            wr_word_q <= {24'h0, route_tx_data};
          end else if (dequeue_start) begin
            op_q <= OP_TX_DEQUEUE; phase_q <= PH_REQ;
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
            case (op_q)
              OP_RX_COMMIT: begin
                rx_tail_q <= rx_tail_q + 4'd1;
                rx_count_q <= rx_count_q + 5'd1;
                rx_seq_q   <= rx_seq_q + 16'd1;
                rx_stage_valid_q <= 1'b0;
                if (rx_count_q == 5'd0) begin
                  // queue was empty: the new byte becomes head immediately
                  head_refresh_pending_q <= 1'b1;
                end
              end
              OP_HEAD_REFRESH: begin
                head_snap_valid_q <= 1'b1;
                head_snap_data_q  <= rsp_data[7:0];
                head_snap_flags_q <= rsp_data[15:8];
                head_snap_seq_q   <= rsp_data[31:16];
                head_refresh_pending_q <= 1'b0;
              end
              OP_TX_PUSH: begin
                tx_tail_q  <= tx_tail_q + 4'd1;
                tx_count_q <= tx_count_q + 5'd1;
              end
              default: rd_word_q <= rsp_data; // OP_TX_DEQUEUE
            endcase
            op_q <= OP_NONE; phase_q <= PH_IDLE;
          end
        end

        default: begin
          op_q <= OP_NONE; phase_q <= PH_IDLE;
        end
      endcase

      // ---- push_pending_q: same latch-and-clear discipline as RTL-018's
      // own finding 5 (OR'd combinationally into host_push_want so a fresh
      // pulse is visible to the arbiter the SAME cycle, not one cycle late). ----
      if (host_push_service) push_pending_q <= 1'b0;
      else if (ctl_tx_push_pulse) push_pending_q <= 1'b1;
    end
  end

  // ==========================================================================
  // RX: synchronizer, 16-phase fractional-accumulator oversampler, 3-sample
  // majority vote, start-bit detection, byte/flag assembly (findings 7/8/9).
  // uart_rx_i arrives already synchronized per its own Appendix A row
  // (CDC-UART handled in dfc_rtl024.sv), so this is a plain same-domain
  // level here -- consistent with every other already-synchronized input
  // in this project (can_rx_i, etc.).
  // ==========================================================================
  localparam logic [2:0] RXS_IDLE  = 3'd0;
  localparam logic [2:0] RXS_START = 3'd1;
  localparam logic [2:0] RXS_DATA  = 3'd2;
  localparam logic [2:0] RXS_PARITY= 3'd3;
  localparam logic [2:0] RXS_STOP1 = 3'd4;
  localparam logic [2:0] RXS_STOP2 = 3'd5;

  logic [31:0] phase_acc_q;
  wire         phase_tick = ctl_enable && ((phase_acc_q + 32'd16) >= ctl_divisor);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) phase_acc_q <= 32'h0;
    else if (module_reset_i || !ctl_enable) phase_acc_q <= 32'h0;
    else if (phase_tick) phase_acc_q <= phase_acc_q + 32'd16 - ctl_divisor;
    else phase_acc_q <= phase_acc_q + 32'd16;
  end

  logic rx_prev_q;
  wire  rx_falling_edge = rx_prev_q && !uart_rx_i;

  logic [2:0] rxs_q;
  logic [3:0] rx_phase_count_q;
  logic [2:0] rx_data_idx_q;
  logic [2:0] rx_vote_sum_q;
  logic       rx_sampled_bit_q;
  logic [7:0] rx_shift_q;
  logic [7:0] rx_stop1_flags_q; // STOP1's own captured classification, used verbatim at STOP2's commit (see RXS_STOP1 case below)
  logic       rx_parity_bit_q;
  logic [7:0] rx_flags_comb;
  logic       rx_this_bit_all_zero_q; // tracks whether every sampled bit so far this frame was 0

  wire want_parity = (ctl_parity != 2'b00);
  wire rx_sample_now  = phase_tick && (rx_phase_count_q == 4'd7 || rx_phase_count_q == 4'd8 || rx_phase_count_q == 4'd9);
  wire rx_bit_done     = phase_tick && (rx_phase_count_q == 4'd15);
  wire rx_computed_parity = (ctl_parity == 2'b01) ? (^rx_shift_q) : (~^rx_shift_q); // 01=even (XOR-reduce), 10=odd (XNOR-reduce)

  // Classification combinational (finding 9): framing error is "stop bit
  // sampled 0" (valid at the STOP1/STOP2 bit_done instant -- rx_sampled_bit_q
  // was last written at that same bit's own phase-9 vote, strictly earlier
  // in this same bit period, so it is already settled by the time rx_bit_done
  // fires); break overrides framing/parity when the whole frame was 0.
  // ARCH-002's own real bit order (SS11.4): 0 framing, 1 parity, 2 overrun
  // (not a per-frame condition -- always 0 here), 3 break, 4 shared-buffer
  // error, bits 5-7 architecturally fixed zero. Bit 4 is structurally
  // UNREACHABLE in this implementation: a RX-HEAD-REFRESH read that fails
  // (read_word_err) simply aborts and leaves the prior snapshot untouched
  // (head_refresh_pending_q stays set and the arbiter retries later), the
  // same real, confirmed behavior RTL-017's own SNAPSHOT-read-error path
  // already uses (snap_*_q is never overridden on a failed read there
  // either) -- not the "live override" RTL-017's own header prose
  // describes for its ROUTE path specifically, which is a different path
  // from SNAPSHOT/HEAD-REFRESH. Disclosed, not silently assumed.
  // Declared here, BEFORE the RX sampler's own always_ff block below (not
  // after it, as an earlier draft had it) -- a real Icarus "declaration
  // after use" compile failure, found and fixed before this shipped, not
  // assumed safe: rx_is_break/rx_flags_comb are both read inside that
  // always_ff (RXS_STOP1's own commit branch), so this project's own
  // declare-before-use discipline applies here too.
  wire rx_framing_err = !rx_sampled_bit_q;
  wire rx_parity_err  = want_parity && (rx_parity_bit_q != rx_computed_parity);
  wire rx_is_break    = rx_framing_err && rx_this_bit_all_zero_q && (!want_parity || !rx_parity_bit_q);
  assign rx_flags_comb = rx_is_break ? 8'b0000_1000 : {3'b000, 1'b0, 1'b0, 1'b0, rx_parity_err, rx_framing_err};

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      rx_prev_q <= 1'b1; rxs_q <= RXS_IDLE; rx_phase_count_q <= 4'd0;
      rx_data_idx_q <= 3'd0; rx_vote_sum_q <= 3'd0; rx_sampled_bit_q <= 1'b1;
      rx_shift_q <= 8'h0; rx_parity_bit_q <= 1'b0; rx_commit_want_q <= 1'b0; rx_frame_done_q <= 1'b0; rx_stop1_flags_q <= 8'h0;
      rx_commit_data_q <= 8'h0; rx_commit_flags_q <= 8'h0; rx_this_bit_all_zero_q <= 1'b1;
    end else if (module_reset_i || !ctl_enable) begin
      rxs_q <= RXS_IDLE; rx_phase_count_q <= 4'd0; rx_commit_want_q <= 1'b0; rx_frame_done_q <= 1'b0;
    end else begin
      rx_prev_q <= uart_rx_i;
      rx_commit_want_q <= 1'b0; // default: one-cycle pulse into the arbiter
      rx_frame_done_q  <= 1'b0; // default: one-cycle pulse for classification/evidence

      if (rx_sample_now) begin
        rx_vote_sum_q <= rx_vote_sum_q + {2'b0, uart_rx_i};
        if (rx_phase_count_q == 4'd9) begin
          rx_sampled_bit_q <= ((rx_vote_sum_q + {2'b0, uart_rx_i}) >= 3'd2) ? 1'b1 : 1'b0;
          // (sum includes this cycle's own sample; >=2 of 3 samples HIGH -> majority is 1)
        end
      end
      if (rx_phase_count_q == 4'd6 && phase_tick) rx_vote_sum_q <= 3'd0; // reset just before the 3-sample window opens

      case (rxs_q)
        RXS_IDLE: begin
          rx_phase_count_q <= 4'd0;
          if (rx_falling_edge) begin
            rxs_q <= RXS_START;
            rx_this_bit_all_zero_q <= 1'b1;
          end
        end

        RXS_START: begin
          if (phase_tick) rx_phase_count_q <= rx_phase_count_q + 4'd1;
          if (rx_bit_done) begin
            rx_phase_count_q <= 4'd0;
            if (rx_sampled_bit_q) begin
              rxs_q <= RXS_IDLE; // glitch: not a real start (finding 8)
            end else begin
              rxs_q <= RXS_DATA; rx_data_idx_q <= 3'd0;
            end
          end
        end

        RXS_DATA: begin
          if (phase_tick) rx_phase_count_q <= rx_phase_count_q + 4'd1;
          if (rx_bit_done) begin
            rx_phase_count_q <= 4'd0;
            rx_shift_q <= {rx_sampled_bit_q, rx_shift_q[7:1]}; // LSB-first
            if (rx_sampled_bit_q) rx_this_bit_all_zero_q <= 1'b0;
            if (rx_data_idx_q == 3'd7) begin
              rxs_q <= want_parity ? RXS_PARITY : RXS_STOP1;
            end else begin
              rx_data_idx_q <= rx_data_idx_q + 3'd1;
            end
          end
        end

        RXS_PARITY: begin
          if (phase_tick) rx_phase_count_q <= rx_phase_count_q + 4'd1;
          if (rx_bit_done) begin
            rx_phase_count_q <= 4'd0;
            rx_parity_bit_q <= rx_sampled_bit_q;
            if (rx_sampled_bit_q) rx_this_bit_all_zero_q <= 1'b0;
            rxs_q <= RXS_STOP1;
          end
        end

        RXS_STOP1: begin
          if (phase_tick) rx_phase_count_q <= rx_phase_count_q + 4'd1;
          if (rx_bit_done) begin
            rx_phase_count_q <= 4'd0;
            if (ctl_two_stop_bits) begin
              // Only the FIRST stop bit's value is validated (finding 9,
              // disclosed simplification) -- latch its classification NOW,
              // while rx_sampled_bit_q still genuinely holds STOP1's own
              // vote, since STOP2's own sampling will overwrite
              // rx_sampled_bit_q (a shared register across all bit
              // positions) before this frame actually commits. Using the
              // live rx_flags_comb at STOP2's own commit instant would
              // silently classify on STOP2's sample instead of STOP1's --
              // a real bug, caught here before it shipped, not after.
              rx_stop1_flags_q <= rx_flags_comb;
              rxs_q <= RXS_STOP2;
            end else begin
              rxs_q <= RXS_IDLE;
              // A real break gets no queued byte at all (finding 9's own
              // disclosed choice -- there is no real framed byte to
              // report, only a line condition); this was asserted in the
              // header comment but never actually implemented here until
              // this fix -- a real, confirmed gap, caught by this
              // module's own testbench (Case 8), not by inspection.
              rx_commit_want_q  <= !rx_is_break;
              rx_frame_done_q   <= 1'b1; // classification/evidence fires regardless of break
              rx_commit_data_q  <= rx_shift_q;
              rx_commit_flags_q <= rx_flags_comb;
            end
          end
        end

        RXS_STOP2: begin
          if (phase_tick) rx_phase_count_q <= rx_phase_count_q + 4'd1;
          if (rx_bit_done) begin
            rx_phase_count_q <= 4'd0;
            rxs_q <= RXS_IDLE;
            // Same break-suppresses-commit fix as the no-two-stop branch
            // above, using STOP1's own captured flags (bit 3), not a live
            // rx_is_break read (which would reflect STOP2's own bit, the
            // same stale-classification hazard rx_stop1_flags_q itself
            // already exists to avoid).
            rx_commit_want_q  <= !rx_stop1_flags_q[3];
            rx_frame_done_q   <= 1'b1;
            rx_commit_data_q  <= rx_shift_q;
            rx_commit_flags_q <= rx_stop1_flags_q; // STOP1's own captured result, not STOP2's live sample
          end
        end

        default: rxs_q <= RXS_IDLE;
      endcase
    end
  end

  // ==========================================================================
  // RX classification sticky/counter update (fires once, at the exact
  // cycle rx_frame_done_q pulses -- i.e. STOP1/STOP2's own bit_done --
  // UNCONDITIONALLY, including on a break, where rx_commit_want_q itself
  // is deliberately suppressed (finding 9: no byte is queued for a break,
  // but it is still real, reportable evidence).
  // ==========================================================================
  wire rx_frame_framing_err = rx_frame_done_q && rx_commit_flags_q[0];
  wire rx_frame_parity_err  = rx_frame_done_q && rx_commit_flags_q[1];
  wire rx_frame_break       = rx_frame_done_q && rx_commit_flags_q[3];

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      // covered by the main reset block above for the sticky/count regs
    end else if (!module_reset_i) begin
      if (rx_frame_break) begin
        break_detected_sticky_q <= 1'b1;
      end else begin
        if (rx_frame_framing_err) begin
          framing_error_sticky_q <= 1'b1;
          error_count_q <= (error_count_q == 32'hFFFFFFFF) ? error_count_q : error_count_q + 32'd1;
        end
        if (rx_frame_parity_err) begin
          parity_error_sticky_q <= 1'b1;
          error_count_q <= (error_count_q == 32'hFFFFFFFF) ? error_count_q : error_count_q + 32'd1;
        end
      end
      if (rx_frame_break) begin
        error_count_q <= (error_count_q == 32'hFFFFFFFF) ? error_count_q : error_count_q + 32'd1;
      end
      if (read_word_err) begin
        // (handled in the main arbiter block's own error_count_q increment;
        // this block only adds the RX-frame-level contributions above, so
        // no double-count here.)
      end
    end
  end

  // ==========================================================================
  // TX: plain CORE_CLK divider + serializer (finding 6).
  // ==========================================================================
  localparam logic [1:0] SER_IDLE = 2'd0;
  localparam logic [1:0] SER_BIT  = 2'd1;

  logic [1:0]  ser_state_q;
  localparam logic [3:0] TXB_START=4'd0, TXB_D0=4'd1, TXB_D1=4'd2, TXB_D2=4'd3, TXB_D3=4'd4,
                          TXB_D4=4'd5, TXB_D5=4'd6, TXB_D6=4'd7, TXB_D7=4'd8, TXB_PARITY=4'd9,
                          TXB_STOP1=4'd10, TXB_STOP2=4'd11;
  logic [3:0]  tx_bit_idx_q;
  logic [31:0] tx_cycle_count_q;
  logic [7:0]  tx_shift_q;
  logic        tx_parity_bit_q;
  logic        tx_want_parity_q, tx_two_stop_q;
  logic        complete_pulse;

  wire tx_bit_time_done = (tx_cycle_count_q + 32'd1 >= ctl_divisor);
  // The last bit of the frame is always STOP1 or STOP2 (whichever is
  // configured) regardless of whether parity is enabled -- parity, when
  // present, is simply one more bit earlier in the sequence (TXB_PARITY,
  // between the data bits and STOP1), not a different final state.
  wire tx_last_bit = tx_two_stop_q ? (tx_bit_idx_q == TXB_STOP2) : (tx_bit_idx_q == TXB_STOP1);
  assign tx_idle = (ser_state_q == SER_IDLE);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      ser_state_q <= SER_IDLE; tx_bit_idx_q <= TXB_START; tx_cycle_count_q <= 32'h0;
      tx_shift_q <= 8'h0; tx_parity_bit_q <= 1'b0; tx_want_parity_q <= 1'b0; tx_two_stop_q <= 1'b0;
      complete_pulse <= 1'b0;
    end else if (module_reset_i) begin
      // real reset abort: immediately back to idle, line goes high next cycle
      ser_state_q <= SER_IDLE; complete_pulse <= 1'b0;
    end else begin
      complete_pulse <= 1'b0;
      case (ser_state_q)
        SER_IDLE: begin
          if (read_word_ok && (op_q == OP_TX_DEQUEUE)) begin
            tx_shift_q        <= rsp_data[7:0];
            tx_want_parity_q  <= want_parity; // ctl_parity sampled live; real config doesn't change mid-byte in practice
            tx_two_stop_q     <= ctl_two_stop_bits;
            tx_parity_bit_q   <= (ctl_parity == 2'b01) ? (^rsp_data[7:0]) : (~^rsp_data[7:0]); // 01=even, 10=odd
            tx_bit_idx_q      <= TXB_START;
            tx_cycle_count_q  <= 32'h0;
            ser_state_q       <= SER_BIT;
          end
        end

        SER_BIT: begin
          tx_cycle_count_q <= tx_cycle_count_q + 32'd1;
          if (tx_bit_time_done) begin
            tx_cycle_count_q <= 32'h0;
            if (tx_last_bit) begin
              ser_state_q <= SER_IDLE;
              complete_pulse <= 1'b1;
              tx_head_q <= tx_head_q + 4'd1;
              tx_count_q <= tx_count_q - 5'd1;
            end else begin
              // Explicit next-state table, not a blind +1 increment: a
              // linear counter would walk through TXB_PARITY as a real
              // bit-time even when parity is disabled, sending one
              // extra, unwanted bit and corrupting the frame length. The
              // RX side's own rxs_q transition (want_parity ? RXS_PARITY
              // : RXS_STOP1) already does this correctly; this mirrors
              // it for TX.
              case (tx_bit_idx_q)
                TXB_D7:     tx_bit_idx_q <= tx_want_parity_q ? TXB_PARITY : TXB_STOP1;
                TXB_PARITY: tx_bit_idx_q <= TXB_STOP1;
                TXB_STOP1:  tx_bit_idx_q <= TXB_STOP2; // only reached when tx_two_stop_q (else tx_last_bit already fired at STOP1)
                default:    tx_bit_idx_q <= tx_bit_idx_q + 4'd1; // TXB_START->D0->D1->...->D7
              endcase
            end
          end
        end

        default: ser_state_q <= SER_IDLE;
      endcase
    end
  end

  // Serial output: idle high; start bit low; data/parity bits driven from
  // tx_shift_q (LSB-first, shifted at each bit boundary below); stop
  // bit(s) high.
  logic tx_cur_bit;
  always_comb begin
    case (tx_bit_idx_q)
      TXB_START: tx_cur_bit = 1'b0;
      TXB_D0, TXB_D1, TXB_D2, TXB_D3, TXB_D4, TXB_D5, TXB_D6, TXB_D7: tx_cur_bit = tx_shift_q[0];
      TXB_PARITY: tx_cur_bit = tx_parity_bit_q;
      default: tx_cur_bit = 1'b1; // stop bit(s)
    endcase
  end
  assign uart_tx_o = tx_idle ? 1'b1 : tx_cur_bit;

  // Shift the data register once per completed data bit (so tx_shift_q[0]
  // always presents the NEXT bit to send).
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      // covered by the main TX reset above
    end else if (!module_reset_i && ser_state_q == SER_BIT && tx_bit_time_done &&
                 tx_bit_idx_q >= TXB_D0 && tx_bit_idx_q <= TXB_D7) begin
      tx_shift_q <= {1'b0, tx_shift_q[7:1]};
    end
  end

  // ==========================================================================
  // Event/IRQ generation (finding 12).
  // ==========================================================================
  logic        evt_pending_q;
  logic [3:0]  evt_cause_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic [15:0] event_drop_count_q;
  logic        event_overflow_sticky_q;
  wire         slot_free = !evt_pending_q || evt_ready_i;

  wire rx_commit_ok    = (op_q == OP_RX_COMMIT) && read_word_ok;
  wire cond_receive    = rx_commit_ok           && event_condition_enable_i[0];
  wire cond_transmit   = complete_pulse         && event_condition_enable_i[1];
  wire cond_framing    = rx_frame_framing_err   && event_condition_enable_i[2];
  wire cond_parity     = rx_frame_parity_err    && event_condition_enable_i[3];
  wire rx_overflow_queue_full_drop = (phase_q == PH_IDLE) && rx_stage_valid_q && rx_queue_full;
  wire cond_overflow   = ((rx_commit_want_q && rx_stage_valid_q) || rx_overflow_queue_full_drop) && event_condition_enable_i[4]; // both finding-10 sub-cases
  wire cond_underflow  = ((ctl_rx_pop_pulse && rx_queue_empty) ||
                          (tx_idle && tx_queue_empty && ctl_enable && !tx_underflow_pending_q)) &&
                          event_condition_enable_i[5];
  wire cond_break      = rx_frame_break         && event_condition_enable_i[6];
  // bit 7 "recovery": no real internal condition drives this -- disclosed
  // unreachable (finding 12).
  wire cond_buf_error  = read_word_err          && event_condition_enable_i[8];
  wire any_cond = ctl_event_enable &&
                  (cond_receive || cond_transmit || cond_framing || cond_parity ||
                   cond_overflow || cond_underflow || cond_break || cond_buf_error);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_cause_q <= 4'd0; evt_record_q <= '0;
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
          evt_cause_q <= cond_receive  ? 4'd0 :
                         cond_transmit ? 4'd1 :
                         cond_framing  ? 4'd2 :
                         cond_parity   ? 4'd3 :
                         cond_overflow ? 4'd4 :
                         cond_underflow? 4'd5 :
                         cond_break    ? 4'd6 : 4'd8;
          evt_record_q <= {
            cond_receive ? {8'h0, rx_seq_q, rx_commit_flags_q, rx_commit_data_q} :
                           {24'h0, (cond_transmit ? 8'd1 : cond_framing ? 8'd2 : cond_parity ? 8'd3 :
                                    cond_overflow ? 8'd4 : cond_underflow ? 8'd5 : cond_break ? 8'd6 : 8'd8)},
            8'h00,          // [95:88] flags
            8'd19,          // [87:80] source_id = evt bus slot 19
            16'h0023,       // [79:64] event_id (C.7 0x0023)
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
  assign fault_req_o  = 1'b0; // disclosed stub, finding 14

  // ==========================================================================
  // Activity (item 140 -- wired to RTL-015.activity_i[3] at dfc_rtl024.sv,
  // NOT this module's own Appendix A row's literal [4]): pulses on a byte
  // genuinely committed into the RX queue, matching ARCH-SAFE-007 ID 3's
  // own "UART RX byte" description exactly.
  // ==========================================================================
  assign activity_o = rx_commit_ok;

  // ==========================================================================
  // Route-source output (finding 4): presents the current head snapshot:
  // ==========================================================================
  assign rx_msg_valid_o = head_snap_valid_q;
  assign rx_msg_record_o = {
    timestamp_i,                                              // [191:128] (live, drain-time; disclosed, finding 13)
    56'h0, head_snap_data_q,                                   // [127:64] payload (LSB-justified)
    head_snap_seq_q, head_snap_flags_q, head_snap_data_q,      // [63:32] metadata (verbatim entry word)
    8'h02,                                                     // [31:24] source_id (ARCH-MSG-003)
    8'h04,                                                     // [23:16] message_type (UART_BYTE)
    4'd1,                                                      // [15:12] payload_length (bytes)
    head_snap_seq_q[3:0],                                      // [11:8] sequence (truncated, disclosed)
    6'h0, head_snap_flags_q[0], head_snap_flags_q[1]           // [7:0] flags: 0 parity/error, 1 framing/protocol error
  };

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__READY_HI]          = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__FAULT_HI]          = 1'b0;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__EVENT_OVERFLOW_HI] = event_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__ENABLED_HI]      = module_enable_i && ctl_enable;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__RX_NOT_EMPTY_HI] = !rx_queue_empty;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_NOT_FULL_HI]  = !tx_queue_full;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_BUSY_HI]      = !tx_idle;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__FRAMING_ERROR_HI]   = framing_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__PARITY_ERROR_HI]    = parity_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__RX_OVERFLOW_HI]     = rx_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_UNDERFLOW_HI]    = tx_underflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__BREAK_DETECTED_HI]  = break_detected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__RX_UNDERFLOW_HI]    = rx_underflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_STATUS__TX_REJECTED_HI]     = tx_rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_LEVEL__LEVEL_LO] = rx_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__DATA_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__DATA_LO] = head_snap_data_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__ERROR_FLAGS_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__ERROR_FLAGS_LO] = head_snap_flags_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_DATA__VALID_HI] = head_snap_valid_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_LEVEL__LEVEL_LO] = tx_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_ERROR_COUNT__COUNT_LO] = error_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_OVERFLOW_COUNT__COUNT_LO] = rx_overflow_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_RX_UNDERFLOW_COUNT__COUNT_LO] = rx_underflow_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_REJECTED_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_REJECTED_COUNT__COUNT_LO] = tx_rejected_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_UNDERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL020_STATUS__UART_TX_UNDERFLOW_COUNT__COUNT_LO] = tx_underflow_count_q;

endmodule : dfc_rtl020
