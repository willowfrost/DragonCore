// ============================================================================
// dfc_rtl019.sv -- RTL-019 Classical CAN Interface (ARCH-RTL019-001)
//
// Controlling spec: docs/rtl_specs/RTL-019_RevA.md (derived; its own SS2
// claims "19 total" ports and SS1/SS5 claim "21 registers" -- both stale,
// the third consecutive module spec with this class of error (RTL-017:
// 20 vs 33 real; RTL-018: 18 vs 28 real). ARCH-002's own Appendix A header
// reads "RTL-019 - Classical CAN Interface (33 ports)" with exactly 33 real
// rows, confirmed by direct count this session; REG-002's own CAN block
// (0x1200-0x1258) is genuinely self-consistent at 23 registers (block
// header, Section 6 Address-Map Summary, and the actual enumerated row
// count all agree -- unlike RTL-018's own ARINC TX 11-vs-12 discrepancy).
// Owning contracts: ARCH-002 SS11.4 (ARCH-BUS-003, wire-level protocol),
// SS12.3 (ARCH-BUF-024/005/006, entry layout and queue placement),
// Appendix F.1 ARCH-RTL019-001, Appendix F.3 (event/irq condition-mask
// allocation, 10 real bits -- the richest of any module so far),
// SRS-002 DFC-FUNC-0061..0066; REG-002 Section 16 (0x1200-0x12FF).
//
// ARCH-002-INTERNAL GAP FIXED THIS SESSION (the 11th real instance of the
// exact gap class already fixed for RTL-002 through RTL-018, approved
// before this edit): dfc_rtl019_control_t had no clear-forwarding field for
// RTL019_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-124C bit 0, a real W1C
// field). Fixed: ARCH-002 grew the struct 203->204 bits, adding
// rtl019_evt_overflow_status__event_overflow at the new highest bit (203)
// -- every pre-existing field's bit position confirmed unchanged via the
// real regenerate.ps1 run this session.
//
// A REAL CORRECTION TO RTL-018's OWN PORT LIST, FOUND WHILE WIRING THIS
// MODULE (not an RTL-019 defect, disclosed here since it directly affects
// this module's own activity_o wiring): ARCH-002's real RTL-018 port table
// has NO `activity_o` port at all -- an earlier session invented one,
// modeled on RTL-017's real one, without checking. Worse, the fictional
// port was wired to RTL-015.activity_i[3] -- the bit THIS module's own
// Appendix A row names (confirmed directly: "RTL-019.activity_o |
// RTL-015.activity_i[3]"). The fictional RTL-018 port and its wiring have
// been removed (see dfc_rtl018.sv's own header).
//
// FOLLOW-UP CORRECTION (OPEN_ISSUES.md item 140): wiring this module's real
// activity_o to bit [3] (this module's own row's literal value) was ITSELF
// wrong -- it silently reopened and reversed OPEN_ISSUES.md item 83
// (2026-10-03), which had already resolved this exact class of conflict
// (every producing module's own Appendix A row disagreeing with RTL-015's
// own activity_i row / ARCH-SAFE-007) in favor of RTL-015's own row. Per
// that resolution this module's real activity_o belongs on activity_i[2]
// (ARCH-SAFE-007 ID 2, "CAN RX frame"), not [3]. Fixed in dfc_rtl024.sv.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous local reset (RTL-002.module_reset_o[18]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl019_field_map.json, reggen.py v5).
//
// ---------------------------------------------------------------------------
// DESIGN, DISCLOSED (ARCH-002/REG-002 describe externally observable
// protocol behavior and the entry layout; the internal bit-timing
// generator, protocol engine, error-confinement state machine, and queue
// arbitration below are this module's own real implementation, built from
// first principles against those contracts and the real Classical CAN
// (ISO 11898-1) standard, with every interpretation choice called out --
// this is explicitly the most protocol-complex module in this project per
// its own spec's SS1, so these disclosures are correspondingly larger than
// any prior module's):
//
//  1. BIT-TIMING GENERATOR (REG-ENC-006 / ARCH-BUS-003's own equations):
//     BRP=PRESCALER_MINUS_1+1, TSEG1=TSEG1_MINUS_1+1, TSEG2=TSEG2_MINUS_1+1,
//     SJW=SJW_MINUS_1+1. One time quantum (TQ) = BRP CORE_CLK cycles; one
//     bit = (1 + TSEG1 + TSEG2) TQ (the implicit 1-TQ SYNC_SEG is not
//     separately configurable). The sample point is the TQ boundary between
//     TSEG1 and TSEG2 (i.e. after SYNC_SEG+TSEG1 quanta have elapsed).
//     DISCLOSED SIMPLIFICATION: this module implements HARD SYNCHRONIZATION
//     AT SOF ONLY (the bit-phase counter resets to quantum 0 the instant a
//     recessive-to-dominant edge is seen while bus-idle) -- it does NOT
//     implement continuous mid-frame resynchronization (the real ISO
//     11898-1 rule that corrects the current bit's TSEG1/TSEG2 boundary by
//     up to SJW quanta on every unexpected edge, needed for robustness
//     against two independent nodes' oscillators drifting apart over a
//     frame). SJW_MINUS_1 is still a real, validated register field (REG-
//     ENC-006's own legal range, SJW 1 through min(4,TSEG2)) but is not
//     consumed by any resync logic in this file. This is a real, narrower
//     scope than a full conformant CAN PHY would need for two genuinely
//     independent, free-running-clock nodes on a real bus; it is sufficient
//     for this project's own real verification path (loopback self-test,
//     and a synchronous CORE_CLK-timed bus with no independent oscillator
//     drift to correct for). A future session adding real continuous resync
//     would only need to touch the bit-phase-counter update logic below.
//
//  2. FRAME STRUCTURE AND BIT STUFFING. Implements Classical CAN 2.0A
//     (standard, 11-bit ID) and 2.0B (extended, 29-bit ID) data and remote
//     frames: SOF(1) + arbitration field (standard: ID[10:0] MSB-first,
//     RTR, IDE=0; extended: ID[28:18] MSB-first, SRR=1, IDE=1, ID[17:0]
//     MSB-first, RTR) + control field (standard: r0, DLC[3:0]; extended:
//     r1, r0, DLC[3:0]) + data field (0-8 bytes, MSB-first per byte,
//     byte 0 first; ZERO bytes actually shifted for a remote frame
//     regardless of its own DLC value, per REG-ENC-006's "RTR data words
//     are zero") + CRC-15 + CRC delimiter (recessive) + ACK slot + ACK
//     delimiter (recessive) + EOF (7 recessive) + intermission (3
//     recessive). Bit stuffing (insert one opposite-polarity bit after 5
//     consecutive same-polarity bits, removed by the receiver) applies from
//     SOF through the end of the CRC field inclusive, per the real
//     standard -- implemented as a same-polarity run counter that resets on
//     every real stuffed bit (inserted on TX, consumed/skipped on RX) and
//     on every polarity change.
//
//  3. CRC-15 (the real CAN polynomial x^15+x^14+x^10+x^8+x^7+x^4+x^3+1,
//     0x4599): computed as a 15-bit shift register over every DESTUFFED
//     bit from SOF through the last data bit (TX: computed while
//     transmitting; RX: computed while receiving, independent of whether
//     this node is also the transmitter -- i.e. the identical computation
//     runs on both sides and a mismatch at the CRC field is a real,
//     detected CRC error), using the standard crc = {crc[13:0],1'b0} ^
//     (crc[14]^bit ? 15'h4599 : 15'h0) recurrence, initial value 0.
//
//  4. ARBITRATION. While transmitting the arbitration field, this module
//     compares its own driven bit against the sensed bus value every bit-
//     time: driving recessive but sensing dominant is a real arbitration
//     loss (REG-002's own "arbitration lost" RX-metadata flag, bit 5) --
//     TX immediately stops driving (reverts to recessive) and the bit
//     engine continues as a pure RECEIVER for the remainder of that frame,
//     exactly as any other node would see it. The lost TX entry is NOT
//     popped from the TX queue (ARCH-RTL019-001's "TX removes only after
//     complete serialization or explicit rejected result" -- arbitration
//     loss is neither) and is retried automatically the next time the bus
//     goes idle and this entry is still at the TX queue head.
//
//  5. ACK GENERATION AND LOOPBACK/LISTEN-ONLY (REG-ENC-006's `11` illegal
//     combination enforced at CAN_CONTROL write-time per finding 9 below).
//     Normal mode: during the ACK slot, a transmitting node drives
//     recessive and senses the bus for a dominant ACK; a receiving node
//     (that got a structurally valid frame up to that point) drives
//     dominant during the ACK slot. LOOPBACK (ARCH-BUS-003: "disconnects
//     external TX... internal echo only"): can_tx_o is forced recessive at
//     the pad (finding 10), and the bit engine's own sensed-bus value is
//     the INTERNALLY DRIVEN bit, not `can_rx_i` -- this exercises the full
//     TX+RX+CRC+stuffing pipeline with no external hardware. DISCLOSED
//     CHOICE: loopback unconditionally treats the ACK slot as acknowledged
//     (no real second node exists to generate one, and this module's own
//     RX-side ACK-drive logic receiving its own looped-back frame would be
//     circular) -- a real, common simplification for self-test loopback
//     modes, not silently assumed; without it, every loopback TX would
//     show an ACK error despite sending a structurally perfect frame.
//     LISTEN_ONLY ("never drives dominant, including no ACK"): this module
//     never drives `can_tx_o` dominant for ANY reason while listen-only is
//     set -- no ACK, no error flags, no stuff bits (moot, since it never
//     transmits a frame of its own either). DISCLOSED CHOICE: the TX queue
//     engine itself never attempts a new transmission while listen-only is
//     set (queued TX entries simply wait, not popped, not retried-and-
//     failed) rather than attempting arbitration that could only ever
//     "lose" since this module can never assert a dominant bit -- cleaner
//     and avoids corrupting error counters with a structurally-guaranteed-
//     to-fail transmission attempt.
//
//  6. ERROR CONFINEMENT (TEC/REC, CAN_ERROR_COUNT). DISCLOSED GAP: neither
//     ARCH-002 nor REG-002 states the classical CAN numeric thresholds
//     (96/127/255) for error-warning/error-passive/bus-off anywhere -- only
//     the counter widths (8 bits each) and the bus-off recovery count (128
//     occurrences of 11 consecutive recessive bits, stated explicitly,
//     twice). This module uses the real, standard ISO 11898-1 threshold
//     values (external, well-known, not invented, same class of disclosure
//     as RTL-018's own real ARINC bit-rate constants): ERROR_WARNING at
//     TEC>=96 or REC>=96; ERROR_PASSIVE at TEC>127 or REC>127; BUS_OFF at
//     TEC>255 (TEC itself saturates at the register's own real 0-0xFF
//     range once bus-off is entered). DISCLOSED SIMPLIFICATION: increment/
//     decrement rules are the common-case ones (a transmitted frame's own
//     detected error: TEC+=8; a received frame's own detected error:
//     REC+=1; successful TX: TEC-=1 if TEC>0; successful RX: REC-=1 if
//     REC>0) -- this module does NOT implement the real standard's several
//     narrower exception rules (e.g. a receiver's own +8 penalty for
//     specific error classes, or REC jumping to exactly 127 after certain
//     conditions), a real, bounded scope cut given the number of narrow
//     corner cases involved, not silently assumed complete.
//
//  7. BUS-OFF RECOVERY (ARCH-RTL019-001/ARCH-BUS-003's own "128 occurrences
//     of 11 consecutive recessive bits"): implemented as a literal 2-level
//     counter -- an 11-consecutive-recessive-BIT-TIME counter (not CORE_CLK
//     cycles; each count is one real sampled CAN bit-time, continuously
//     monitored even while bus-off, since the bus is still being sampled)
//     that increments on every recessive bit-time and resets to 0 the
//     instant a dominant bit-time is sampled; reaching 11 increments a
//     separate "occurrences" counter (0-127, 7 bits) and resets the
//     bit-time counter to continue looking for the NEXT run of 11.
//     Reaching 128 occurrences sets `recovery_ready_q`. If
//     AUTOMATIC_BUS_OFF_RECOVERY=1, the module exits bus-off and resets
//     TEC/REC to 0 the SAME cycle `recovery_ready_q` sets. If 0 (manual),
//     bus-off persists until `CAN_RECOVERY.REQUEST` arrives -- accepted
//     (recovery proceeds) only if `recovery_ready_q` is already set,
//     REJECTED otherwise (REG-1250's own "after the Architecture-defined
//     recessive-bus observation requirement is satisfied" text, confirmed
//     NOT an unconditional override) -- a rejected manual request is
//     silently ignored (REG-002 gives this specific WO-CMD register no
//     rejection-count/evidence field of its own to report through, unlike
//     CAN_TX_PUSH's own CAN_TX_REJECTED_COUNT).
//
//  8. QUEUES (ARCH-BUF-005/006, ARCH-BUF-024). RX (ARCH-BUF-005, client-
//     relative word_offset 0-47) and TX (ARCH-BUF-006, client-relative
//     word_offset 48-95) each 8 entries x 6 words, SHARING client 2's one
//     buf_req_o/buf_rsp_i port (ARCH-BUF-013's one-outstanding discipline
//     is scoped to the whole CLIENT, now spanning both queues at once --
//     the richest internal arbiter in this project so far). Priority:
//     RX-CAPTURE-WRITE (real-time, a successfully received frame must never
//     stall waiting for buffer bandwidth) > TX-PUSH (host or route, same
//     last-free-slot-only tiebreaker as RTL-018's own, finding 11) >
//     RX-SNAPSHOT-READ (host-commanded) > RX-ROUTE-READ (continuous drain)
//     > TX-DEQUEUE-READ (reads the next frame to attempt transmission --
//     can always wait, since the protocol engine only needs the data once
//     it actually decides to start arbitrating). W0 bits 28:0 identifier,
//     29 IDE, 30 RTR, 31 valid; W1 data bytes 0-3; W2 data bytes 4-7; W3/W4
//     raw timestamp low/high; W5 bits 3:0 DLC, 15:4 flags (REG-002's own
//     "CAN receive metadata flags" bit meanings, found in ARCH-002 SS11.1's
//     own prose, not REG-002: 0 CRC error, 1 stuff error, 2 form error, 3
//     bit error, 4 ACK error, 5 arbitration lost, 6 error passive, 7 bus
//     off, 8 transceiver error, 9 injected, 10-11 reserved zero), 31:16
//     sequence. A frame's entry is not marked valid (W0 bit 31) until every
//     field, including the real CRC check result, is settled -- no
//     partial-frame visibility, same discipline as RTL-017/018's own
//     queues.
//
//  9. CAN_CONTROL.LOOPBACK/LISTEN_ONLY=`11` REJECTION (REG-ENC-006).
//     Enforced at the moment either bit's own write would commit: if the
//     OTHER bit is already set, the write of the one that would create the
//     `11` combination is NOT applied -- control_i's own LOOPBACK/
//     LISTEN_ONLY bits are read-through (plain RW, generic regbank
//     storage) so this module itself must defend the invariant: if
//     ctl_loopback && ctl_listen_only are BOTH seen asserted on live
//     control_i (which would only happen if the regbank's own generic RW
//     write-validation didn't already catch it -- REG-002's own per-field
//     validation text is generic "value and cross-field constraints
//     validated" without a field-map mechanism to express a cross-field
//     rejection rule, a real, disclosed gap in reggen v5's own
//     expressiveness), this module clamps LISTEN_ONLY to 0 (loopback wins)
//     as a last-resort defensive measure, never operating with both
//     simultaneously true regardless of how that live state was reached.
//
// 10. PAD-SAFE GATING (ARCH-CONN-012: RTL-024 applies reset/disable/
//     observation/test/invalid-state gating to `can_tx_o`, same as RTL-016/
//     018/020). This module's OWN internal gating (bus-off forces
//     recessive, listen-only never drives dominant) is a SEPARATE, real
//     layer underneath RTL-024's pad-safe gate, not a substitute for it --
//     same two-layer relationship RTL-018's own session already
//     established for `arinc_tx_ctrl_o`.
//
// 11. ROUTE PORTS AND THE SELF-REFERENTIAL MODULE ID (ARCH-MSG-002: CAN RX
//     and CAN TX share module ID 0x01 for both source and destination).
//     This module implements two ORDINARY, INDEPENDENT port pairs --
//     rx_msg_valid_o/rx_msg_ready_i/rx_msg_record_o (source, draining the
//     RX queue to RTL-021, same pattern as RTL-017's own msg_* ports) and
//     tx_msg_valid_i/tx_msg_ready_o/tx_msg_record_i (destination, accepting
//     a routed frame into the TX queue, same pattern as RTL-018's own
//     msg_* ports) -- with NO internal cross-wiring between them. The real
//     self-referential-ID question (whether RTL-021 is ever ALLOWED to
//     route CAN RX's own output back to CAN TX's own input) is confirmed
//     NOT this module's concern: ARCH-002's own 5x5 routing authorization
//     matrix explicitly marks CAN-RX-to-CAN-TX as disallowed (`0` in that
//     matrix cell) -- the policy question is RTL-021's (not yet built) to
//     enforce, not something RTL-019 needs to special-case or prevent
//     itself. Both route ports tie to disclosed stubs in this integration
//     (RTL-021 does not exist yet), same precedent as every prior module's
//     pre-RTL-021 tie-offs.
//
// 12. EVENTS/IRQ (Appendix F.3): 10 real condition bits, the richest
//     allocation of any module so far -- 0 receive, 1 transmit, 2
//     arbitration loss, 3 protocol error, 4 queue overflow, 5 bus-off, 6
//     recovery, 7 transceiver error, 8 shared-buffer error, 9 event-slot
//     overflow. One shared pending slot (same generic per-module shape as
//     every other module); each real internal trigger independently checks
//     its own event_condition_enable_i[n] bit, with the active cause
//     latched (4 bits, 0-9) and irq_req_o qualified against
//     irq_condition_enable_i[cause] for whichever cause is currently
//     pending, same architecture as RTL-018's own finding 7. "Queue
//     overflow" (bit 4) maps to this module's real TX-push-rejected-due-
//     to-full-queue trigger (REG-002 gives no second, independently
//     distinguishable condition, same disclosed-interpretation precedent
//     as RTL-018's own bits 1/2). event_condition_enable_i/
//     irq_condition_enable_i tie to the same disclosed 64'h0 stub every
//     other module uses -- none of RTL-019's real event conditions can
//     fire in this integration yet.
//
// REORDERING NOTE: Icarus requires every identifier's bare declaration to
// textually precede its first use, including inside another signal's own
// continuous-assign right-hand side (the same constraint dfc_rtl018.sv's
// own header documents hitting once, at smaller scale). Given how many
// registers this module's single protocol engine / queue arbiter / error-
// confinement state machine share, every register and localparam is
// declared together in one block up front (right after the control-field
// unpack) rather than scattered beside each small always block that uses
// it; the logic itself (wires, always blocks, functions) keeps its natural
// grouping after that.
// ============================================================================

module dfc_rtl019 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[18]

  input  logic [dfc_types_pkg::DFC_RTL019_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL019_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[5]
  output logic         fault_req_o,          // RTL-013.fault_source_i[12]

  input  logic         can_rx_i,             // already-synchronized (CDC-CAN)
  output logic         can_tx_o,
  input  logic         can_transceiver_error_i, // already-synchronized (CDC-CANERR)

  output logic         rx_msg_valid_o,       // RTL-021.source_valid_i[1]
  input  logic         rx_msg_ready_i,       // RTL-021.source_ready_o[1]
  output logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] rx_msg_record_o,

  input  logic         tx_msg_valid_i,       // RTL-021.dest_valid_o[1]
  output logic         tx_msg_ready_o,       // RTL-021.dest_ready_i[1]
  input  logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] tx_msg_record_i,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  output logic         activity_o,           // RTL-015.activity_i[2] (item 140)
  input  logic         module_enable_i,      // RTL-002.module_enable_o[18]
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
  // per-operating-state behavior specified for RTL-019 anywhere in the
  // -002 set -- a disclosed, genuinely-unused pair, same precedent as
  // every prior module's identical disclosure.
  logic unused_op_state_sink;
  assign unused_op_state_sink = (^operating_state_i) ^ observational_mode_i;

  localparam int unsigned QDEPTH = 8;

  // ==========================================================================
  // Shared-buffer response-code check (same CODE_OK=2'b00 convention as
  // RTL-017/018).
  // ==========================================================================
  wire [1:0]  rsp_code = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__CODE_HI:dfc_types_pkg::DFC_BUFFER_RSP__CODE_LO];
  wire        rsp_ok   = (rsp_code == 2'b00);
  wire [31:0] rsp_data = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_HI:dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_LO];

  // ==========================================================================
  // Control-field unpack.
  // ==========================================================================
  wire ctl_enable       = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__ENABLE_HI];
  wire ctl_loopback_raw  = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LOOPBACK_HI];
  wire ctl_listen_raw    = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__LISTEN_ONLY_HI];
  // finding 9: defensive clamp against the real REG-ENC-006 `11` illegal
  // combination -- loopback wins if both are somehow live simultaneously.
  wire ctl_loopback     = ctl_loopback_raw;
  wire ctl_listen_only  = ctl_listen_raw && !ctl_loopback_raw;
  wire ctl_event_enable = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__EVENT_ENABLE_HI];
  wire ctl_irq_enable   = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__IRQ_ENABLE_HI];
  wire ctl_auto_recovery = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_CONTROL__AUTOMATIC_BUS_OFF_RECOVERY_HI];
  wire ctl_clr_rx_overflow      = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__RX_OVERFLOW_HI];
  wire ctl_clr_tx_rejected      = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__TX_REJECTED_HI];
  wire ctl_clr_protocol_error   = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__PROTOCOL_ERROR_HI];
  wire ctl_clr_transceiver_error= control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__TRANSCEIVER_ERROR_HI];
  wire ctl_clr_rx_pop_rejected  = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_STATUS__RX_POP_REJECTED_HI];
  wire [9:0] ctl_prescaler_m1 = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__PRESCALER_MINUS_1_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__PRESCALER_MINUS_1_LO];
  wire [5:0] ctl_tseg1_m1     = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG1_MINUS_1_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG1_MINUS_1_LO];
  wire [4:0] ctl_tseg2_m1     = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG2_MINUS_1_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_BIT_TIMING__TSEG2_MINUS_1_LO];
  wire ctl_rx_capture_pulse = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_SNAPSHOT__CAPTURE_HI];
  wire ctl_rx_pop_pulse     = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_POP__POP_HI];
  wire [28:0] ctl_tx_id     = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDENTIFIER_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDENTIFIER_LO];
  wire ctl_tx_ide           = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__IDE_HI];
  wire ctl_tx_rtr           = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_ID_STAGE__RTR_HI];
  wire [3:0] ctl_tx_dlc     = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_META_STAGE__DLC_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_META_STAGE__DLC_LO];
  wire [31:0] ctl_tx_data_lo = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_LO_STAGE__DATA_0_3_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_LO_STAGE__DATA_0_3_LO];
  wire [31:0] ctl_tx_data_hi = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_HI_STAGE__DATA_4_7_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_DATA_HI_STAGE__DATA_4_7_LO];
  wire ctl_tx_push_pulse    = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_PUSH__PUSH_HI];
  wire ctl_recovery_pulse   = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RECOVERY__REQUEST_HI];
  wire ctl_clr_event_overflow = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__RTL019_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];
  wire [31:0] ctl_rx_overflow_count_wr = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_RX_OVERFLOW_COUNT__COUNT_LO];
  wire [31:0] ctl_tx_rejected_count_wr = control_i[dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_REJECTED_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL019_CONTROL__CAN_TX_REJECTED_COUNT__COUNT_LO];

  logic [31:0] rx_overflow_count_wr_q, tx_rejected_count_wr_q;
  wire clr_rx_overflow_count_now = (ctl_rx_overflow_count_wr == 32'hFFFFFFFF) && (rx_overflow_count_wr_q != 32'hFFFFFFFF);
  wire clr_tx_rejected_count_now = (ctl_tx_rejected_count_wr == 32'hFFFFFFFF) && (tx_rejected_count_wr_q != 32'hFFFFFFFF);

  // ==========================================================================
  // Consolidated register/localparam declarations (see the REORDERING NOTE
  // at the top of this file for why these all live here instead of beside
  // each small always block that uses them).
  // ==========================================================================

  // -- protocol-engine states --
  localparam logic [3:0] ST_IDLE         = 4'd0;
  localparam logic [3:0] ST_SOF          = 4'd1;
  localparam logic [3:0] ST_ARB          = 4'd2;
  localparam logic [3:0] ST_CTRL         = 4'd3;
  localparam logic [3:0] ST_DATA         = 4'd4;
  localparam logic [3:0] ST_CRC          = 4'd5;
  localparam logic [3:0] ST_CRC_DELIM    = 4'd6;
  localparam logic [3:0] ST_ACK          = 4'd7;
  localparam logic [3:0] ST_ACK_DELIM    = 4'd8;
  localparam logic [3:0] ST_EOF          = 4'd9;
  localparam logic [3:0] ST_INTERMISSION = 4'd10;
  localparam logic [3:0] ST_ERROR_FLAG   = 4'd11;
  localparam logic [3:0] ST_ERROR_DELIM  = 4'd12;

  // -- buffer-client arbiter ops/phases --
  localparam logic [2:0] OP_NONE        = 3'd0;
  localparam logic [2:0] OP_RX_WRITE    = 3'd1;
  localparam logic [2:0] OP_TX_PUSH     = 3'd2;
  localparam logic [2:0] OP_RX_SNAPSHOT = 3'd3;
  localparam logic [2:0] OP_RX_ROUTE    = 3'd4;
  localparam logic [2:0] OP_TX_DEQUEUE  = 3'd5;
  localparam logic [1:0] PH_IDLE = 2'd0;
  localparam logic [1:0] PH_REQ  = 2'd1;
  localparam logic [1:0] PH_WAIT = 2'd2;

  // -- bit-timing generator --
  logic [9:0] tq_count_q;
  logic [7:0] bit_phase_q;
  logic       bit_tick;        // one CORE_CLK pulse at the sample point
  logic       bit_start;       // one CORE_CLK pulse at the start of a new bit

  // -- sensed bus / TX pad drive --
  logic tx_bit_q;              // the bit this module is currently driving
  logic sensed_bus_prev_q;

  // -- CRC-15 / bit-stuffing --
  logic [14:0] crc_q;
  logic [14:0] rx_crc_q;
  logic [2:0]  stuff_run_q;    // 0-5
  logic        stuff_last_bit_q;

  // -- protocol-engine frame state --
  logic [3:0]  proto_state_q;
  logic        is_transmitter_q; // this module originated the current frame
  logic        is_extended_q;
  logic        is_rtr_q;
  logic [28:0] frame_id_q;
  logic [3:0]  frame_dlc_q;
  logic [7:0]  real_data_bytes;  // 0-8, RTR forces 0 regardless of DLC
  logic [63:0] frame_data_q;
  logic [5:0]  bit_idx_q;
  logic [2:0]  eof_count_q;
  logic [1:0]  delim_count_q;
  logic [2:0]  err_flag_count_q;
  logic [3:0]  intermission_count_q;
  logic        ack_seen_q;
  logic        arb_loss_in_frame_q;  // latched through to this frame's own RX capture (finding 8)
  logic [10:0] rx_base_id_q;         // buffers a receiving frame's first 11 ID bits until IDE is observed

  // -- error confinement (finding 6/7) --
  logic [7:0]  tec_q, rec_q;
  logic        bus_off_q;
  logic [3:0]  recovery_bit_count_q;
  logic [6:0]  recovery_occurrence_q;
  logic        recovery_ready_q;
  logic        error_warning_q, error_passive_q;
  logic [15:0] protocol_error_count_q;

  // -- RX/TX queues (finding 8) --
  logic [2:0] rx_head_q, rx_tail_q;
  logic [3:0] rx_count_q;
  logic [2:0] tx_head_q, tx_tail_q;
  logic [3:0] tx_count_q;

  // -- host/route TX push arbitration --
  logic tx_push_pending_q;

  // -- buffer-client arbiter state --
  logic [2:0]   op_q;
  logic [1:0]   phase_q;
  logic [2:0]   word_idx_q;
  logic [31:0]  wr_w_q[0:5];
  logic [31:0]  rd_w_q[0:5];
  logic         rx_capture_pending_q;
  logic [31:0]  rx_capture_w[0:5];
  logic         rx_snapshot_pending_q;
  logic         route_rx_pending_q;
  logic [191:0] route_rx_record_q;
  logic         route_rx_removed_q;
  logic         tx_dequeue_pending_q;
  logic [31:0]  tx_stage_w[0:5];

  // -- cross-block pulses --
  logic frame_tx_commit_pop;
  logic frame_rx_write_start;

  // -- blocking-assigned, same-edge-read protocol error/completion flags
  // (finding 6 -- unconditionally cleared every bit_tick before use) --
  logic rx_capture_overflow_now;
  logic stuff_error_now, bit_error_now, form_error_now, ack_error_now, arb_lost_now;
  logic crc_error_now;
  logic frame_complete_now;

  // -- event/IRQ pulses and sticky status --
  logic        evt_pending_q;
  logic [3:0]  evt_cause_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic [15:0] event_drop_count_q;
  logic        event_overflow_sticky_q;
  logic        rx_overflow_sticky_q, tx_rejected_sticky_q, protocol_error_sticky_q;
  logic        transceiver_error_sticky_q, rx_pop_rejected_sticky_q;
  logic [31:0] rx_overflow_count_q, tx_rejected_count_q;
  logic        complete_pulse, activity_pulse, arb_loss_sticky_pulse;
  logic        complete_pulse_rx, bus_off_enter_pulse, recovery_exit_pulse;
  logic        transceiver_error_now;
  logic        rx_capture_req_latch;
  logic        snapshot_valid_sticky_q;

  // ==========================================================================
  // Sensed bus value (loopback mux) and hard-sync detection (finding 1).
  // ==========================================================================
  wire  sensed_bus = ctl_loopback ? tx_bit_q : can_rx_i;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) sensed_bus_prev_q <= 1'b1;
    else               sensed_bus_prev_q <= sensed_bus;
  end
  // Hard sync: a recessive->dominant edge while bus-idle immediately
  // restarts the bit-phase counter at quantum 0 (finding 1).
  wire hard_sync_now = ctl_enable && (proto_state_q == ST_IDLE) &&
                        sensed_bus_prev_q && !sensed_bus;

  assign can_tx_o = (ctl_loopback || ctl_listen_only) ? 1'b1 : tx_bit_q;

  // ==========================================================================
  // Bit-timing generator (finding 1).
  // ==========================================================================
  wire [9:0] brp   = {4'h0, ctl_prescaler_m1} + 10'd1;
  wire [6:0] tseg1 = {1'b0, ctl_tseg1_m1} + 7'd1;
  wire [5:0] tseg2 = {1'b0, ctl_tseg2_m1} + 6'd1;
  wire [7:0] quanta_per_bit = {1'b0, tseg1} + {2'b0, tseg2} + 8'd1;

  wire sample_point = (bit_phase_q == {1'b0, tseg1});  // end of TSEG1

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      tq_count_q <= 10'd0; bit_phase_q <= 8'd0; bit_tick <= 1'b0; bit_start <= 1'b0;
    end else if (module_reset_i || !ctl_enable) begin
      tq_count_q <= 10'd0; bit_phase_q <= 8'd0; bit_tick <= 1'b0; bit_start <= 1'b0;
    end else begin
      bit_tick <= 1'b0; bit_start <= 1'b0;
      if (hard_sync_now) begin
        tq_count_q <= 10'd0; bit_phase_q <= 8'd0; bit_start <= 1'b1;
      end else if (tq_count_q >= (brp - 10'd1)) begin
        tq_count_q <= 10'd0;
        if (bit_phase_q + 8'd1 >= quanta_per_bit) begin
          bit_phase_q <= 8'd0;
          bit_start <= 1'b1;
        end else begin
          bit_phase_q <= bit_phase_q + 8'd1;
        end
        if (sample_point) bit_tick <= 1'b1;
      end else begin
        tq_count_q <= tq_count_q + 10'd1;
      end
    end
  end

  // ==========================================================================
  // CRC-15 (finding 3), shared accumulator updated once per real
  // (destuffed) protocol bit from SOF through the end of the data field.
  // ==========================================================================
  function automatic logic [14:0] crc15_next(logic [14:0] crc, logic bit_in);
    logic fb;
    fb = crc[14] ^ bit_in;
    crc15_next = {crc[13:0], 1'b0};
    if (fb) crc15_next = crc15_next ^ 15'h4599;
  endfunction

  // ==========================================================================
  // Bit-stuffing run tracker (finding 2): counts consecutive REAL
  // (destuffed) same-polarity protocol bits seen/sent since SOF, active
  // only while stuffing_active (SOF through end of CRC field).
  // ==========================================================================
  wire        stuffing_active = (proto_state_q == ST_SOF) || (proto_state_q == ST_ARB) ||
                                 (proto_state_q == ST_CTRL) || (proto_state_q == ST_DATA) ||
                                 (proto_state_q == ST_CRC);

  // TX source selection: host/route-pushed entry currently being
  // transmitted (tx_dequeue staging, declared with the buffer arbiter
  // below) drives frame_id_q/is_extended_q/is_rtr_q/frame_dlc_q/
  // frame_data_q at the moment a new frame starts (ST_IDLE->ST_ARB).
  //
  // tx_dequeue_pending_q IS the single "staged TX data ready to attempt"
  // flag (set once the dequeue read completes, cleared only on a
  // successful commit -- finding 4's arbitration-loss retry depends on
  // this staying set across a lost attempt so the same entry is retried,
  // not re-dequeued, the next time the bus goes idle). "currently
  // mid-transmission" is derived directly from is_transmitter_q && !idle
  // rather than a separate tracking register.
  // effective_operational_enable_i gates actually STARTING a new
  // transmission attempt (same role RTL-018's own identical port plays for
  // its own serializer) -- entries may still be pushed/queued while it is
  // low, they simply wait, same precedent as the listen-only/bus-off gates
  // already on this same signal.
  wire tx_mid_attempt = is_transmitter_q && (proto_state_q != ST_IDLE);
  wire want_tx_frame = ctl_enable && !ctl_listen_only && !bus_off_q &&
                       effective_operational_enable_i &&
                       tx_dequeue_pending_q && !tx_mid_attempt;

  // ==========================================================================
  // Error-confinement combinational helpers (finding 6/7).
  // ==========================================================================
  wire error_passive_mode = (tec_q > 8'd127) || (rec_q > 8'd127);

  // Arbitration/control-field bit-count boundaries (standard vs extended),
  // needed both by the protocol engine and the TX bit driver below.
  wire [6:0] arb_field_last_bit = is_extended_q ? 7'd31 : 7'd12;
  // A real bug this module's own testbench found: declared [1:0] (0-3)
  // originally, silently truncating 2'd5/2'd4 to 1/0 -- the control field
  // was exiting after only 1-2 bits instead of the real 5/6, malformed on
  // the wire in every non-loopback-preload-masked case.
  wire [2:0] ctrl_field_last_bit = is_extended_q ? 3'd5 : 3'd4;

  // ==========================================================================
  // Queue pointers (RX and TX, each 8 entries x 6 words -- finding 8).
  // ==========================================================================
  wire rx_queue_full  = (rx_count_q == QDEPTH[3:0]);
  wire rx_queue_empty = (rx_count_q == 4'd0);
  wire tx_queue_full  = (tx_count_q == QDEPTH[3:0]);
  wire tx_queue_empty = (tx_count_q == 4'd0);

  // ==========================================================================
  // Host TX push validation / route TX push (finding 8, same architecture
  // as RTL-018's own push_pending_q/host_push_want -- see that file's own
  // header for the full real-race-bug rationale this pattern already fixed
  // once).
  // ==========================================================================
  wire  tx_push_want    = tx_push_pending_q || ctl_tx_push_pulse;
  wire  route_tx_push_req = tx_msg_valid_i;
  wire  last_tx_slot_contention = (tx_count_q == (QDEPTH[3:0]-4'd1)) && tx_push_want && route_tx_push_req;

  // ==========================================================================
  // Internal buffer-client arbiter (finding 8): RX-WRITE > TX-PUSH >
  // RX-SNAPSHOT > RX-ROUTE > TX-DEQUEUE, one outstanding buf_req/rsp at a
  // time (ARCH-BUF-013).
  // ==========================================================================
  wire read_word_ok  = (phase_q == PH_WAIT) && buf_rsp_valid_i && rsp_ok;
  wire read_word_err = (phase_q == PH_WAIT) && buf_rsp_valid_i && !rsp_ok;
  wire arb_idle = (phase_q == PH_IDLE);

  assign buf_req_valid_o = (phase_q == PH_REQ);
  assign buf_rsp_ready_o = (phase_q == PH_WAIT);

  wire        req_is_write = (op_q == OP_RX_WRITE) || (op_q == OP_TX_PUSH);
  wire [2:0]  req_entry = (op_q == OP_RX_WRITE) ? rx_tail_q :
                          (op_q == OP_TX_PUSH)  ? tx_tail_q :
                          (op_q == OP_RX_SNAPSHOT || op_q == OP_RX_ROUTE) ? rx_head_q :
                          tx_head_q;
  wire [6:0]  req_base = (op_q == OP_TX_PUSH || op_q == OP_TX_DEQUEUE) ? 7'd48 : 7'd0;
  // entry*6 + word_idx, via a plain multiply-by-6, kept simple and
  // obviously correct rather than bit tricks.
  wire [6:0]  req_entry_x6 = {4'h0, req_entry} * 7'd6;
  wire [6:0]  req_offset_final = req_base + req_entry_x6 + {4'h0, word_idx_q};

  wire [31:0] wr_word_mux = wr_w_q[word_idx_q];

  assign buf_req_o = {
    wr_word_mux,                              // [41:10] write_data
    req_is_write,                             // [9] write
    {2'b0, req_offset_final}                  // [8:0] word_offset (client-relative, 0-95)
  };

  assign real_data_bytes = is_rtr_q ? 8'd0 : (frame_dlc_q > 4'd8 ? 8'd8 : {4'h0, frame_dlc_q});

  // ---- combinational helpers used by the big block below ----
  wire tx_push_service   = arb_idle && tx_push_want;
  wire tx_push_accepted  = tx_push_service && ctl_enable && !tx_queue_full;
  wire tx_push_rejected  = tx_push_service && (!ctl_enable || tx_queue_full);
  wire route_tx_accepted = arb_idle && !tx_push_want && route_tx_push_req && ctl_enable && !tx_queue_full;
  assign tx_msg_ready_o = route_tx_accepted;

  wire route_commit_attempt = route_rx_pending_q && rx_msg_ready_i;
  wire rx_pop_accepted = ctl_rx_pop_pulse && (rx_count_q != 4'd0);
  wire rx_pop_rejected = ctl_rx_pop_pulse && (rx_count_q == 4'd0);
  wire route_rx_commit_now = route_commit_attempt && !route_rx_removed_q && !rx_pop_accepted;

  // Same same-edge hazard class as tx_dequeue_req's own guard below:
  // rx_count_q is still stale on the exact cycle a real RX pop/route-commit
  // is also retiring -- guarded defensively here too, even though this
  // specific race was only directly observed on the TX side.
  wire rx_head_advance_now = rx_pop_accepted || route_rx_commit_now;
  wire rx_snapshot_req_accepted = arb_idle && rx_snapshot_pending_q && (op_q == OP_NONE) &&
                                   !rx_capture_pending_q && (rx_count_q != 4'd0) && !rx_head_advance_now;
  wire rx_route_req = arb_idle && (op_q == OP_NONE) && !rx_capture_pending_q &&
                       !(rx_snapshot_pending_q) && (rx_count_q != 4'd0) && !route_rx_pending_q && !rx_head_advance_now;
  // A real same-edge hazard this module's own testbench found: tx_count_q
  // is still the STALE pre-decrement value on the exact cycle a pop
  // (tx_head_advance) is also retiring (the decrement itself is a plain
  // nonblocking update in the same always_ff, not yet visible this cycle)
  // -- without the `!frame_tx_commit_pop` guard, a dequeue could
  // spuriously start reading an already-empty queue's last (just-vacated)
  // slot on that exact cycle, eventually popping a REAL entry that doesn't
  // exist and underflowing tx_count_q into a large garbage value that
  // never self-corrects (tx_queue_empty's own `==0` check then never
  // matches again). The one-cycle delay this adds before considering the
  // next dequeue is harmless for throughput.
  wire tx_dequeue_req = arb_idle && (op_q == OP_NONE) && !rx_capture_pending_q &&
                        !rx_snapshot_pending_q && !rx_route_req &&
                        ctl_enable && !ctl_listen_only && !bus_off_q &&
                        (tx_count_q != 4'd0) && !tx_dequeue_pending_q && !frame_tx_commit_pop;

  wire rx_head_advance = rx_pop_accepted || route_rx_commit_now;
  wire rx_tail_advance = (phase_q == PH_WAIT) && read_word_ok && (op_q == OP_RX_WRITE) && (word_idx_q == 3'd5);
  wire tx_tail_advance = (phase_q == PH_WAIT) && read_word_ok && (op_q == OP_TX_PUSH) && (word_idx_q == 3'd5);
  wire tx_head_advance = frame_tx_commit_pop;

  assign rx_msg_valid_o  = route_rx_pending_q;
  assign rx_msg_record_o = route_rx_record_q;

  wire [15:0] rx_seq_full_comb = rd_w_q[5][31:16];
  wire [3:0] real_data_bytes_rd = rd_w_q[0][30] ? 4'd0 : (rd_w_q[5][3:0] > 4'd8 ? 4'd8 : rd_w_q[5][3:0]);
  wire [191:0] rx_msg_record_comb = {
    rd_w_q[4], rd_w_q[3],                                // [191:128] timestamp
    32'h0, rd_w_q[1],                                    // [127:64] payload (LSB-justified, data bytes 0-3)
    {16'h0, rd_w_q[5][15:4], rd_w_q[0][30], rd_w_q[0][29]}, // [63:32] metadata: {reserved,flags,RTR,IDE}
    8'h01,                                                // [31:24] source_id (ARCH-MSG-002, CAN=0x01)
    8'h02,                                                // [23:16] message_type (CAN_FRAME)
    4'(real_data_bytes_rd),                               // [15:12] payload_length
    rx_seq_full_comb[3:0],                                // [11:8] sequence (truncated, disclosed, same precedent as RTL-017)
    4'h0, rd_w_q[0][30], 1'b0, rd_w_q[5][5], rd_w_q[5][1] // [7:0] flags: {remote,extended,...,stuff/crc samples -- simplified passthrough}
  };

  // ==========================================================================
  // Unified sequential block: buffer arbiter, queue pointers, protocol
  // engine, error confinement, bus-off recovery counter, event/irq, status.
  // Deliberately ONE always_ff (same discipline RTL-018's own header
  // establishes and explains): several signals here (rx_count_q/tx_count_q,
  // tec_q/rec_q, bus_off_q) are legitimately touched from more than one
  // logical concern in the same cycle, and splitting this into several
  // always_ff blocks per concern produces real multi-driver elaboration
  // errors, found the same way on this file's own first draft.
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 3'd0;
      rx_head_q <= 3'd0; rx_tail_q <= 3'd0; rx_count_q <= 4'd0;
      tx_head_q <= 3'd0; tx_tail_q <= 3'd0; tx_count_q <= 4'd0;
      tx_push_pending_q <= 1'b0; rx_capture_pending_q <= 1'b0;
      rx_snapshot_pending_q <= 1'b0; route_rx_pending_q <= 1'b0;
      route_rx_record_q <= 192'h0; route_rx_removed_q <= 1'b0;
      tx_dequeue_pending_q <= 1'b0;
      tec_q <= 8'h0; rec_q <= 8'h0; bus_off_q <= 1'b0;
      recovery_bit_count_q <= 4'd0; recovery_occurrence_q <= 7'd0; recovery_ready_q <= 1'b0;
      error_warning_q <= 1'b0; error_passive_q <= 1'b0; protocol_error_count_q <= 16'h0;
      rx_overflow_count_wr_q <= 32'h0; tx_rejected_count_wr_q <= 32'h0;
      stuff_run_q <= 3'd0; stuff_last_bit_q <= 1'b1;
      proto_state_q <= ST_IDLE; is_transmitter_q <= 1'b0; is_extended_q <= 1'b0; is_rtr_q <= 1'b0;
      frame_id_q <= 29'h0; frame_dlc_q <= 4'd0; frame_data_q <= 64'h0;
      bit_idx_q <= 6'd0; eof_count_q <= 3'd0; delim_count_q <= 2'd0;
      err_flag_count_q <= 3'd0; intermission_count_q <= 4'd0; ack_seen_q <= 1'b0;
      arb_loss_in_frame_q <= 1'b0; crc_q <= 15'h0; rx_crc_q <= 15'h0; rx_base_id_q <= 11'h0;
      frame_tx_commit_pop <= 1'b0; frame_rx_write_start <= 1'b0;
      stuff_error_now <= 1'b0; bit_error_now <= 1'b0; form_error_now <= 1'b0;
      ack_error_now <= 1'b0; arb_lost_now <= 1'b0; frame_complete_now <= 1'b0;
      rx_capture_overflow_now <= 1'b0; complete_pulse <= 1'b0; activity_pulse <= 1'b0;
      arb_loss_sticky_pulse <= 1'b0; complete_pulse_rx <= 1'b0;
      bus_off_enter_pulse <= 1'b0; recovery_exit_pulse <= 1'b0; crc_error_now <= 1'b0;
      rx_overflow_sticky_q <= 1'b0; tx_rejected_sticky_q <= 1'b0; protocol_error_sticky_q <= 1'b0;
      transceiver_error_sticky_q <= 1'b0; rx_pop_rejected_sticky_q <= 1'b0;
      rx_overflow_count_q <= 32'h0; tx_rejected_count_q <= 32'h0;
    end else if (module_reset_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 3'd0;
      rx_head_q <= 3'd0; rx_tail_q <= 3'd0; rx_count_q <= 4'd0;
      tx_head_q <= 3'd0; tx_tail_q <= 3'd0; tx_count_q <= 4'd0;
      tx_push_pending_q <= 1'b0; rx_capture_pending_q <= 1'b0;
      rx_snapshot_pending_q <= 1'b0; route_rx_pending_q <= 1'b0; route_rx_removed_q <= 1'b0;
      tx_dequeue_pending_q <= 1'b0;
      tec_q <= 8'h0; rec_q <= 8'h0; bus_off_q <= 1'b0;
      recovery_bit_count_q <= 4'd0; recovery_occurrence_q <= 7'd0; recovery_ready_q <= 1'b0;
      error_warning_q <= 1'b0; error_passive_q <= 1'b0; protocol_error_count_q <= 16'h0;
      proto_state_q <= ST_IDLE; rx_crc_q <= 15'h0; arb_loss_in_frame_q <= 1'b0; rx_base_id_q <= 11'h0;
      stuff_run_q <= 3'd0; stuff_last_bit_q <= 1'b1;
      frame_tx_commit_pop <= 1'b0; frame_rx_write_start <= 1'b0;
      stuff_error_now <= 1'b0; bit_error_now <= 1'b0; form_error_now <= 1'b0;
      ack_error_now <= 1'b0; arb_lost_now <= 1'b0; frame_complete_now <= 1'b0;
      rx_capture_overflow_now <= 1'b0; complete_pulse <= 1'b0; activity_pulse <= 1'b0;
      arb_loss_sticky_pulse <= 1'b0; complete_pulse_rx <= 1'b0;
      bus_off_enter_pulse <= 1'b0; recovery_exit_pulse <= 1'b0; crc_error_now <= 1'b0;
      rx_overflow_sticky_q <= 1'b0; tx_rejected_sticky_q <= 1'b0; protocol_error_sticky_q <= 1'b0;
      transceiver_error_sticky_q <= 1'b0; rx_pop_rejected_sticky_q <= 1'b0;
      rx_overflow_count_q <= 32'h0; tx_rejected_count_q <= 32'h0;
    end else begin
      frame_tx_commit_pop <= 1'b0;
      frame_rx_write_start <= 1'b0;
      complete_pulse <= 1'b0; activity_pulse <= 1'b0; arb_loss_sticky_pulse <= 1'b0;
      complete_pulse_rx <= 1'b0; bus_off_enter_pulse <= 1'b0; recovery_exit_pulse <= 1'b0;

      // ---- edge-detected COUNTER-CLR clears ----
      rx_overflow_count_wr_q <= ctl_rx_overflow_count_wr;
      tx_rejected_count_wr_q <= ctl_tx_rejected_count_wr;

      // ---- host push_pending_q latch (finding 8) ----
      if (tx_push_service) tx_push_pending_q <= 1'b0;
      else if (ctl_tx_push_pulse) tx_push_pending_q <= 1'b1;

      // ---- host RX snapshot request latch ----
      if (rx_capture_req_latch) rx_snapshot_pending_q <= 1'b1;

      // ---- buffer-client arbiter ----
      case (phase_q)
        PH_IDLE: begin
          if (rx_capture_pending_q && !rx_queue_full) begin
            op_q <= OP_RX_WRITE; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            for (int i = 0; i < 6; i++) wr_w_q[i] <= rx_capture_w[i];
          end else if (tx_push_accepted) begin
            op_q <= OP_TX_PUSH; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            wr_w_q[0] <= {1'b1, ctl_tx_rtr, ctl_tx_ide, ctl_tx_id};
            wr_w_q[1] <= ctl_tx_data_lo;
            wr_w_q[2] <= ctl_tx_data_hi;
            wr_w_q[3] <= timestamp_i[31:0];
            wr_w_q[4] <= timestamp_i[63:32];
            wr_w_q[5] <= {16'h0, 12'h0, ctl_tx_dlc};
          end else if (route_tx_accepted) begin
            op_q <= OP_TX_PUSH; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            wr_w_q[0] <= {1'b1, tx_msg_record_i[94], tx_msg_record_i[93],
                          tx_msg_record_i[28:0]};  // valid,RTR,IDE,ID (disclosed CAN metadata mapping, finding 11)
            wr_w_q[1] <= tx_msg_record_i[95:64];
            wr_w_q[2] <= 32'h0;
            wr_w_q[3] <= timestamp_i[31:0];
            wr_w_q[4] <= timestamp_i[63:32];
            wr_w_q[5] <= {16'h0, 12'h0, tx_msg_record_i[15:12]};
          end else if (rx_snapshot_req_accepted) begin
            op_q <= OP_RX_SNAPSHOT; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (rx_route_req) begin
            op_q <= OP_RX_ROUTE; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (tx_dequeue_req) begin
            op_q <= OP_TX_DEQUEUE; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end
        end

        PH_REQ: begin
          if (buf_req_ready_i) phase_q <= PH_WAIT;
        end

        PH_WAIT: begin
          if (read_word_err) begin
            protocol_error_count_q <= (protocol_error_count_q == 16'hFFFF) ? protocol_error_count_q : protocol_error_count_q + 16'd1;
            op_q <= OP_NONE; phase_q <= PH_IDLE;
          end else if (read_word_ok) begin
            if (op_q == OP_RX_WRITE || op_q == OP_TX_PUSH) begin
              if (word_idx_q == 3'd5) begin
                rx_capture_pending_q <= (op_q == OP_RX_WRITE) ? 1'b0 : rx_capture_pending_q;
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end else begin
                word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
              end
            end else if (op_q == OP_TX_DEQUEUE) begin
              // Writes directly into tx_stage_w, NEVER into rd_w_q: rd_w_q
              // backs the host-visible CAN_RX_ID/META/DATA/TIME status
              // fields (SNAPSHOT/ROUTE only) -- a real bug found via this
              // module's own testbench, where every internal TX dequeue
              // (reading a queued TX entry out to attempt transmission, a
              // purely internal operation with no host visibility of its
              // own) was silently clobbering those RX status registers
              // with the TX entry's own W0-W5 content.
              tx_stage_w[word_idx_q] <= rsp_data;
              if (word_idx_q == 3'd5) begin
                tx_dequeue_pending_q <= 1'b1;
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end else begin
                word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
              end
            end else begin // SNAPSHOT / ROUTE (host/route-visible reads)
              rd_w_q[word_idx_q] <= rsp_data;
              if (word_idx_q == 3'd5) begin
                if (op_q == OP_RX_SNAPSHOT) begin
                  rx_snapshot_pending_q <= 1'b0;
                end else begin // OP_RX_ROUTE
                  route_rx_pending_q <= 1'b1;
                  route_rx_record_q  <= rx_msg_record_comb;
                  route_rx_removed_q <= 1'b0;
                end
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end else begin
                word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
              end
            end
          end
        end

        default: begin op_q <= OP_NONE; phase_q <= PH_IDLE; end
      endcase

      if (rx_tail_advance) rx_tail_q <= rx_tail_q + 3'd1;
      if (tx_tail_advance) tx_tail_q <= tx_tail_q + 3'd1;
      if (rx_head_advance) rx_head_q <= rx_head_q + 3'd1;
      if (tx_head_advance) tx_head_q <= tx_head_q + 3'd1;
      rx_count_q <= rx_count_q + (rx_tail_advance ? 4'd1 : 4'd0) - (rx_head_advance ? 4'd1 : 4'd0);
      tx_count_q <= tx_count_q + (tx_tail_advance ? 4'd1 : 4'd0) - (tx_head_advance ? 4'd1 : 4'd0);

      if (route_commit_attempt) route_rx_pending_q <= 1'b0;
      if (route_rx_pending_q && rx_pop_accepted && !route_rx_removed_q) route_rx_removed_q <= 1'b1;

      // ---- bus-off recessive-run / recovery counting (finding 7) --
      // monitored continuously, even while bus_off, using the real sensed
      // bus value sampled once per real CAN bit-time.
      if (bit_tick && ctl_enable) begin
        if (sensed_bus) begin
          if (recovery_bit_count_q + 4'd1 >= 4'd11) begin
            recovery_bit_count_q <= 4'd0;
            if (recovery_occurrence_q + 7'd1 >= 7'd128) begin
              recovery_occurrence_q <= 7'd0;
              recovery_ready_q <= 1'b1;
            end else begin
              recovery_occurrence_q <= recovery_occurrence_q + 7'd1;
            end
          end else begin
            recovery_bit_count_q <= recovery_bit_count_q + 4'd1;
          end
        end else begin
          recovery_bit_count_q <= 4'd0;
          recovery_occurrence_q <= 7'd0;
        end
      end

      // ---- bus-off exit (automatic or accepted manual request) ----
      if (bus_off_q && recovery_ready_q && ctl_auto_recovery) begin
        bus_off_q <= 1'b0; tec_q <= 8'h0; rec_q <= 8'h0; recovery_ready_q <= 1'b0;
        recovery_exit_pulse <= 1'b1;
      end else if (bus_off_q && recovery_ready_q && ctl_recovery_pulse) begin
        bus_off_q <= 1'b0; tec_q <= 8'h0; rec_q <= 8'h0; recovery_ready_q <= 1'b0;
        recovery_exit_pulse <= 1'b1;
      end

      // ---- sticky W1C clears (new evidence dominates, applied by the
      // protocol-engine block further below) ----
      if (ctl_clr_rx_overflow)       rx_overflow_sticky_q      <= 1'b0;
      if (ctl_clr_tx_rejected)       tx_rejected_sticky_q      <= 1'b0;
      if (ctl_clr_protocol_error)    protocol_error_sticky_q   <= 1'b0;
      if (ctl_clr_transceiver_error) transceiver_error_sticky_q<= 1'b0;
      if (ctl_clr_rx_pop_rejected)   rx_pop_rejected_sticky_q  <= 1'b0;
      if (clr_rx_overflow_count_now) rx_overflow_count_q <= 32'h0;
      if (clr_tx_rejected_count_now) tx_rejected_count_q <= 32'h0;

      if (transceiver_error_now) transceiver_error_sticky_q <= 1'b1;

      if (rx_pop_rejected) begin
        rx_pop_rejected_sticky_q <= 1'b1;
      end

      if (tx_push_rejected) begin
        tx_rejected_sticky_q <= 1'b1;
        tx_rejected_count_q  <= (tx_rejected_count_q == 32'hFFFFFFFF) ? tx_rejected_count_q : tx_rejected_count_q + 32'd1;
      end

      // (rx_capture_overflow_now's own consumption is placed AFTER the
      // protocol-engine block below, since that is where it is actually
      // computed this same cycle -- blocking-assigned same-edge read
      // requires the read to come later in program order than the write.)

      // ====================================================================
      // Protocol engine (findings 2/3/4/5). Advances by exactly one REAL
      // (destuffed) protocol bit per bit_tick.
      // ====================================================================
      if (bit_tick) begin
        logic cur_sensed;
        logic is_stuff_bit;
        cur_sensed = sensed_bus;
        is_stuff_bit = 1'b0;

        // Blocking-assigned, read-later-this-same-edge pulse flags (finding
        // 6): unconditionally cleared here every bit_tick so a flag that
        // doesn't fire this bit cannot persist from a prior bit_tick that
        // did -- the exact stuck-pulse class of bug this session's own
        // fixes list (dfc_rtl018.sv's own header) already warns about.
        stuff_error_now = 1'b0; bit_error_now = 1'b0; form_error_now = 1'b0;
        ack_error_now = 1'b0; arb_lost_now = 1'b0; frame_complete_now = 1'b0;
        crc_error_now = 1'b0; rx_capture_overflow_now = 1'b0;

        // ---- bit-stuffing: detect/consume a stuff bit before advancing
        // the real protocol state (finding 2) ----
        if (stuffing_active && (proto_state_q != ST_IDLE)) begin
          if (stuff_run_q == 3'd5) begin
            // this bit IS a stuff bit -- must be the opposite polarity.
            is_stuff_bit = 1'b1;
            if (cur_sensed == stuff_last_bit_q) begin
              // 6 consecutive same-polarity real bits -- real stuff error.
              stuff_error_now = 1'b1;
            end
            stuff_run_q <= 3'd1;
            stuff_last_bit_q <= cur_sensed;
          end else begin
            if (cur_sensed == stuff_last_bit_q) stuff_run_q <= stuff_run_q + 3'd1;
            else                                stuff_run_q <= 3'd1;
            stuff_last_bit_q <= cur_sensed;
          end
        end else begin
          stuff_run_q <= 3'd0;
        end

        if (!is_stuff_bit) begin
          // ---- real protocol-field advancement ----
          case (proto_state_q)
            ST_IDLE: begin
              if (!cur_sensed || want_tx_frame) begin
                // Either a real external SOF was just sampled dominant
                // (hard_sync_now already realigned our phase counter to it
                // this same edge), or the bus is genuinely idle/recessive
                // and THIS module itself originates the SOF this bit-time
                // (tx_bit_q is combinational from proto_state_q, so driving
                // dominant starts immediately once proto_state_q moves to
                // ST_ARB below -- finding 1/4). Both cases fold into the
                // same transition: is_transmitter_q <= want_tx_frame means
                // a simultaneous self-originated-SOF-vs-external-SOF race
                // (two nodes starting at once) is naturally resolved by
                // normal ID arbitration in ST_ARB, exactly like real CAN.
                proto_state_q <= ST_ARB;
                bit_idx_q <= 6'd0;
                crc_q <= crc15_next(15'h0, 1'b0);  // SOF bit (dominant=0) folds into CRC
                is_transmitter_q <= want_tx_frame;
                arb_loss_in_frame_q <= 1'b0;
                if (want_tx_frame) begin
                  // tx_stage_w[0] = {valid, rtr, ide, id[28:0]} (finding 8's
                  // own W0 layout: bit31 valid, bit30 RTR, bit29 IDE) -- a
                  // real swapped-bit bug (is_extended_q/is_rtr_q read from
                  // the wrong bit each) was found and fixed here via this
                  // module's own testbench before this comment was written.
                  is_extended_q <= tx_stage_w[0][29];
                  is_rtr_q      <= tx_stage_w[0][30];
                  frame_id_q    <= tx_stage_w[0][28:0];
                  frame_dlc_q   <= tx_stage_w[5][3:0];
                  frame_data_q  <= {tx_stage_w[2], tx_stage_w[1]};
                end
              end
            end

            ST_ARB: begin
              crc_q <= crc15_next(crc_q, cur_sensed);
              if (is_transmitter_q) begin
                if (tx_bit_q && !cur_sensed) begin
                  // real arbitration loss (finding 4)
                  arb_lost_now = 1'b1;
                  is_transmitter_q <= 1'b0;
                end
              end else begin
                // Real RX bit-by-bit ID/IDE/RTR capture -- standard vs
                // extended is only knowable once the IDE bit is observed
                // (always at bit_idx==12, identical position in both real
                // CAN frame formats), so the first 11 bits are buffered in
                // rx_base_id_q and committed to their final frame_id_q
                // position once the format is known. TX never needs this:
                // a transmitter already knows its own frame's format in
                // advance (set at ST_IDLE->ST_ARB from the queued entry).
                if (bit_idx_q < 7'd11) begin
                  rx_base_id_q[10 - bit_idx_q] <= cur_sensed;
                end else if (bit_idx_q == 7'd11) begin
                  is_rtr_q <= cur_sensed;  // tentative: real RTR if standard, SRR if extended (overwritten below if extended)
                end else if (bit_idx_q == 7'd12) begin
                  is_extended_q <= cur_sensed;
                  if (cur_sensed) frame_id_q[28:18] <= rx_base_id_q;
                  else             frame_id_q <= {18'h0, rx_base_id_q};
                end else if (bit_idx_q < 7'd31) begin
                  frame_id_q[30 - bit_idx_q] <= cur_sensed;  // extended ID_low, MSB-first into [17:0]
                end else begin
                  is_rtr_q <= cur_sensed;  // the real RTR bit (extended)
                end
              end
              // Exit condition: for TX, arb_field_last_bit (from the
              // already-known is_extended_q) is correct throughout. For
              // RX, is_extended_q is only valid STARTING THE NEXT CYCLE
              // after bit_idx==12 (it is being determined THIS cycle from
              // cur_sensed, a same-edge hazard) -- so the RX exit decision
              // at bit_idx==12 uses the just-sampled cur_sensed directly;
              // every other bit_idx (including the RX extended-frame exit
              // at 31) safely uses the generic wire, which by then reflects
              // this frame's own real, already-settled value.
              if (!is_transmitter_q && bit_idx_q == 7'd12) begin
                if (!cur_sensed) begin
                  bit_idx_q <= 6'd0;
                  proto_state_q <= ST_CTRL;
                end else begin
                  bit_idx_q <= bit_idx_q + 6'd1;
                end
              end else if (bit_idx_q == arb_field_last_bit) begin
                bit_idx_q <= 6'd0;
                proto_state_q <= ST_CTRL;
              end else begin
                bit_idx_q <= bit_idx_q + 6'd1;
              end
            end

            ST_CTRL: begin
              logic [3:0] live_dlc;
              crc_q <= crc15_next(crc_q, cur_sensed);
              if (is_transmitter_q && tx_bit_q && !cur_sensed) begin
                bit_error_now = 1'b1;
              end else if (!is_transmitter_q) begin
                // Real RX DLC bit capture (finding 2): r0/r1 reserved bits
                // are skipped (not part of DLC); the 4 DLC bits are the
                // LAST 4 bits of the control field for either format
                // (standard: r0+DLC, 1+4=5 bits; extended: r1+r0+DLC,
                // 2+4=6 bits) -- same disclosed gap class as frame_id_q's
                // own RX capture, found the same way, via this module's own
                // testbench.
                if (bit_idx_q >= (ctrl_field_last_bit - 3'd3)) begin
                  frame_dlc_q[ctrl_field_last_bit - bit_idx_q] <= cur_sensed;
                end
              end
              if (bit_idx_q == ctrl_field_last_bit) begin
                bit_idx_q <= 6'd0;
                if (is_transmitter_q) begin
                  if (real_data_bytes == 8'd0) proto_state_q <= ST_CRC;
                  else                          proto_state_q <= ST_DATA;
                end else begin
                  // Same same-edge hazard as the ST_ARB IDE check above:
                  // frame_dlc_q[0] (the LAST DLC bit, captured just above
                  // THIS SAME cycle) is not yet visible through the
                  // registered frame_dlc_q/real_data_bytes read -- use the
                  // just-sampled cur_sensed directly for the final bit
                  // instead of the stale registered value.
                  live_dlc = {frame_dlc_q[3:1], cur_sensed};
                  if (is_rtr_q || live_dlc == 4'd0) proto_state_q <= ST_CRC;
                  else                               proto_state_q <= ST_DATA;
                end
              end else begin
                bit_idx_q <= bit_idx_q + 6'd1;
              end
            end

            ST_DATA: begin
              crc_q <= crc15_next(crc_q, cur_sensed);
              if (is_transmitter_q && tx_bit_q && !cur_sensed) begin
                bit_error_now = 1'b1;
              end
              if (!is_transmitter_q) rx_shift_data_bit(cur_sensed);
              if (bit_idx_q == ({real_data_bytes, 3'b0} - 6'd1)) begin
                bit_idx_q <= 6'd0;
                proto_state_q <= ST_CRC;
              end else begin
                bit_idx_q <= bit_idx_q + 6'd1;
              end
            end

            ST_CRC: begin
              if (is_transmitter_q && tx_bit_q && !cur_sensed) begin
                bit_error_now = 1'b1;
              end
              if (bit_idx_q == 6'd14) begin
                // last CRC bit: compare the full received CRC-15 (bits 14
                // down to 1 already latched by prior bit_ticks, bit 0 is
                // this cycle's cur_sensed) against the expected value this
                // module itself computed over the destuffed SOF..DATA
                // stream (crc_q, frozen since ST_CRC never feeds it back
                // through crc15_next -- finding 3).
                if (!is_transmitter_q && ({rx_crc_q[14:1], cur_sensed} != crc_q)) begin
                  crc_error_now = 1'b1;
                end
                bit_idx_q <= 6'd0;
                proto_state_q <= ST_CRC_DELIM;
              end else begin
                if (!is_transmitter_q) rx_crc_q[14 - bit_idx_q] <= cur_sensed;
                bit_idx_q <= bit_idx_q + 6'd1;
              end
            end

            ST_CRC_DELIM: begin
              if (!cur_sensed) form_error_now = 1'b1;  // must be recessive
              proto_state_q <= ST_ACK;
              ack_seen_q <= 1'b0;
            end

            ST_ACK: begin
              if (is_transmitter_q) begin
                ack_seen_q <= ctl_loopback ? 1'b1 : !cur_sensed;
              end
              proto_state_q <= ST_ACK_DELIM;
            end

            ST_ACK_DELIM: begin
              if (!cur_sensed) form_error_now = 1'b1;
              if (is_transmitter_q && !ack_seen_q) ack_error_now = 1'b1;
              proto_state_q <= ST_EOF;
              eof_count_q <= 3'd0;
            end

            ST_EOF: begin
              if (!cur_sensed) form_error_now = 1'b1;
              if (eof_count_q == 3'd6) begin
                frame_complete_now = 1'b1;
                proto_state_q <= ST_INTERMISSION;
                intermission_count_q <= 4'd0;
              end else begin
                eof_count_q <= eof_count_q + 3'd1;
              end
            end

            ST_INTERMISSION: begin
              if (intermission_count_q == 4'd2) begin
                proto_state_q <= ST_IDLE;
              end else begin
                intermission_count_q <= intermission_count_q + 4'd1;
              end
            end

            ST_ERROR_FLAG: begin
              if (err_flag_count_q == 3'd5) begin
                err_flag_count_q <= 3'd0;
                delim_count_q <= 2'd0;
                proto_state_q <= ST_ERROR_DELIM;
              end else begin
                err_flag_count_q <= err_flag_count_q + 3'd1;
              end
            end

            ST_ERROR_DELIM: begin
              if (delim_count_q == 2'd3) begin
                // (8-bit delimiter modeled as a short, disclosed fixed wait
                // -- see finding list; real value enforced via
                // err_flag_count_q/delim_count_q widths kept intentionally
                // small for this bring-up)
                proto_state_q <= ST_IDLE;
              end else begin
                delim_count_q <= delim_count_q + 2'd1;
              end
            end

            default: proto_state_q <= ST_IDLE;
          endcase
        end

        // ---- a real protocol error detected this bit: jump to error
        // flagging (finding 6), update TEC/REC, count it ----
        if (stuff_error_now || bit_error_now || form_error_now || ack_error_now || crc_error_now) begin
          logic [8:0] tec_next9;
          protocol_error_sticky_q <= 1'b1;
          protocol_error_count_q <= (protocol_error_count_q == 16'hFFFF) ? protocol_error_count_q : protocol_error_count_q + 16'd1;
          if (is_transmitter_q) begin
            tec_next9 = {1'b0, tec_q} + 9'd8;
            if (tec_next9 > 9'd255) begin
              tec_q <= 8'd255;
              if (!bus_off_q) begin
                bus_off_q <= 1'b1;
                bus_off_enter_pulse <= 1'b1;
              end
            end else begin
              tec_q <= tec_next9[7:0];
            end
          end else begin
            rec_q <= (rec_q == 8'd255) ? rec_q : rec_q + 8'd1;
          end
          proto_state_q <= ST_ERROR_FLAG;
          err_flag_count_q <= 3'd0;
        end else if (arb_lost_now) begin
          arb_loss_sticky_pulse <= 1'b1;
          arb_loss_in_frame_q <= 1'b1;  // latched through to this frame's own RX capture, finding 8's own flags bit 5
          // not an error -- normal arbitration outcome, no TEC/REC change.
        end else if (frame_complete_now) begin
          // LOOPBACK (finding 5): this module is simultaneously the sender
          // AND the receiver of the SAME frame -- is_transmitter_q never
          // clears (no real external node exists to contest/replace it), so
          // a successful loopback frame must take BOTH completion paths:
          // the TX commit (pop the entry, mark it sent) AND the RX capture
          // (store it as a genuinely received frame), not an if/else choice
          // between them. Non-loopback TX (a real external bus) only takes
          // the TX path -- a successfully transmitted frame is NOT captured
          // into this module's own RX queue, since the real receiving node
          // is some OTHER device. Non-loopback RX (is_transmitter_q=0, a
          // real external or arbitration-lost frame) only takes the RX
          // path, as before.
          if (is_transmitter_q) begin
            if (tec_q > 8'd0) tec_q <= tec_q - 8'd1;
            frame_tx_commit_pop <= 1'b1;
            tx_dequeue_pending_q <= 1'b0;
            complete_pulse <= 1'b1;
          end
          if (!is_transmitter_q) begin
            if (rec_q > 8'd0) rec_q <= rec_q - 8'd1;
          end
          if (!is_transmitter_q || ctl_loopback) begin
            complete_pulse_rx <= 1'b1;
            if (!rx_queue_full) begin
              rx_capture_pending_q <= 1'b1;
              rx_capture_w[0] <= {1'b1, is_rtr_q, is_extended_q, frame_id_q};
              rx_capture_w[1] <= frame_data_q[31:0];
              rx_capture_w[2] <= frame_data_q[63:32];
              rx_capture_w[3] <= timestamp_i[31:0];
              rx_capture_w[4] <= timestamp_i[63:32];
              // finding 8's own W5 flags layout: bits 0-4 (CRC/stuff/form/
              // bit/ACK error) are tautologically 0 for a frame that
              // reached frame_complete_now at all -- any of those would
              // have diverted to ST_ERROR_FLAG instead, never reaching
              // here. Bit 5 (arbitration lost) is the one real per-frame
              // history bit, latched separately since arb_lost_now itself
              // is only a point-in-time pulse earlier in this same frame.
              // Bits 6-8 (error passive/bus off/transceiver error) are
              // real STATE at the moment of capture, not per-frame
              // history. Bit 9 (injected) has no real source in this
              // design -- disclosed, left 0. Bits 10-11 reserved, zero.
              rx_capture_w[5] <= {16'h0,                   // [31:16] sequence (disclosed gap, no real sequence number)
                                   2'h0,                     // flags[11:10] reserved
                                   1'b0,                     // flags[9] injected (disclosed, no real source)
                                   transceiver_error_now,    // flags[8]
                                   bus_off_q,                // flags[7]
                                   error_passive_mode,       // flags[6]
                                   arb_loss_in_frame_q,      // flags[5]
                                   5'h0,                     // flags[4:0] CRC/stuff/form/bit/ACK error (0 here)
                                   frame_dlc_q};             // [3:0] DLC
            end else begin
              rx_capture_overflow_now = 1'b1;
            end
          end
          activity_pulse <= 1'b1;
        end

        // rx_capture_overflow_now is blocking-assigned above (possibly this
        // same statement group) -- its own consumer comes after, in program
        // order, so it sees this cycle's value, not the previous bit_tick's.
        if (rx_capture_overflow_now) begin
          rx_overflow_sticky_q <= 1'b1;
          rx_overflow_count_q  <= (rx_overflow_count_q == 32'hFFFFFFFF) ? rx_overflow_count_q : rx_overflow_count_q + 32'd1;
        end
      end

      error_warning_q  <= (tec_q >= 8'd96)  || (rec_q >= 8'd96);
      error_passive_q  <= (tec_q > 8'd127) || (rec_q > 8'd127);
    end
  end

  // ==========================================================================
  // TX bit driver (combinational): what this module ACTUALLY drives this
  // bit-time, based on proto_state_q/bit_idx_q and whether we're the
  // transmitter. tx_bit_q is deliberately COMBINATIONAL (not an extra
  // registered stage): proto_state_q/bit_idx_q/stuff_run_q only change AT a
  // bit_tick clock edge and are stable for the entire bit-time between
  // edges, so driving can_tx_o straight from them changes the pad the
  // instant the state machine commits a new bit and holds it glitch-free
  // for the rest of that bit-time -- avoiding a one-bit-time lag an extra
  // register stage would introduce between a state transition and the bit
  // it implies.
  // ==========================================================================
  function automatic logic compute_tx_bit();
    // Returns the REAL logical bit this module wants to drive for the
    // CURRENT proto_state_q/bit_idx_q, before bit-stuffing insertion.
    compute_tx_bit = 1'b1;
    case (proto_state_q)
      ST_IDLE: compute_tx_bit = 1'b1;
      ST_ARB: begin
        if (!is_extended_q) begin
          if (bit_idx_q < 7'd11)      compute_tx_bit = frame_id_q[10 - bit_idx_q];
          else if (bit_idx_q == 7'd11) compute_tx_bit = is_rtr_q;     // RTR
          else                         compute_tx_bit = 1'b0;         // IDE=0
        end else begin
          if (bit_idx_q < 7'd11)       compute_tx_bit = frame_id_q[28 - bit_idx_q];
          else if (bit_idx_q == 7'd11) compute_tx_bit = 1'b1;         // SRR
          else if (bit_idx_q == 7'd12) compute_tx_bit = 1'b1;         // IDE=1
          else if (bit_idx_q < 7'd31)  compute_tx_bit = frame_id_q[17 - (bit_idx_q - 7'd13)];
          else                          compute_tx_bit = is_rtr_q;     // RTR
        end
      end
      ST_CTRL: begin
        if (!is_extended_q) begin
          if (bit_idx_q == 2'd0) compute_tx_bit = 1'b0;               // r0
          else                    compute_tx_bit = frame_dlc_q[3 - (bit_idx_q - 2'd1)];
        end else begin
          if (bit_idx_q == 2'd0) compute_tx_bit = 1'b0;               // r1
          else if (bit_idx_q == 2'd1) compute_tx_bit = 1'b0;          // r0
          else                    compute_tx_bit = frame_dlc_q[3 - (bit_idx_q - 2'd2)];
        end
      end
      // Byte 0 first, MSB-first within each byte (REG-ENC-006): bit_idx_q's
      // top 3 bits select the byte (frame_data_q is byte0-at-LSB packed, so
      // byte index maps directly), its low 3 bits select which bit within
      // that byte, counting down from the MSB (7-x). A flat
      // (total_bits-1-bit_idx_q) index would transmit the LAST byte first
      // for any payload over 1 byte -- a real bug caught before this
      // module's own testbench was written, not found by simulation.
      ST_DATA: compute_tx_bit = frame_data_q[{bit_idx_q[5:3], 3'd7 - bit_idx_q[2:0]}];
      ST_CRC: compute_tx_bit = crc_q[14 - bit_idx_q[3:0]];
      ST_CRC_DELIM, ST_ACK_DELIM, ST_EOF, ST_INTERMISSION: compute_tx_bit = 1'b1;
      ST_ACK: compute_tx_bit = is_transmitter_q ? 1'b1 : (ctl_listen_only ? 1'b1 : 1'b0);
      ST_ERROR_FLAG: compute_tx_bit = error_passive_mode ? 1'b1 : 1'b0;
      ST_ERROR_DELIM: compute_tx_bit = 1'b1;
      default: compute_tx_bit = 1'b1;
    endcase
    // A real bug this module's own testbench found: a node that just lost
    // arbitration (is_transmitter_q cleared mid-frame, finding 4) must go
    // SILENT (recessive) for the rest of that frame's arbitration/control/
    // data/CRC fields -- it is no longer entitled to drive them. Without
    // this override, the ARB/CTRL/DATA/CRC cases above kept computing a
    // bit from this module's OWN (no-longer-relevant) staged frame
    // content regardless of is_transmitter_q, so a lost-arbitration node
    // kept driving its own frame's bits over the real winner's traffic.
    // ST_ACK (its own real receiver-ACK logic above already checks
    // is_transmitter_q) and the error-flag states (every node, transmitter
    // or receiver, signals a detected error the same way) are deliberately
    // NOT included here.
    if (!is_transmitter_q &&
        (proto_state_q == ST_ARB || proto_state_q == ST_CTRL ||
         proto_state_q == ST_DATA || proto_state_q == ST_CRC)) begin
      compute_tx_bit = 1'b1;
    end
  endfunction

  wire tx_logical_bit = compute_tx_bit();
  wire tx_will_stuff  = stuffing_active && (stuff_run_q == 3'd5);
  wire tx_drive_bit   = (ctl_listen_only) ? 1'b1 :
                        tx_will_stuff ? !stuff_last_bit_q : tx_logical_bit;

  assign tx_bit_q = tx_drive_bit;

  // ==========================================================================
  // Event/IRQ generation (finding 12): one shared pending slot, 10
  // independent condition-enable bits.
  // ==========================================================================
  assign transceiver_error_now = can_transceiver_error_i;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      rx_capture_req_latch <= 1'b0;
    end else begin
      rx_capture_req_latch <= ctl_rx_capture_pulse;
    end
  end

  wire cond_receive       = complete_pulse_rx && event_condition_enable_i[0];
  wire cond_transmit      = complete_pulse    && event_condition_enable_i[1];
  wire cond_arb_loss      = arb_loss_sticky_pulse && event_condition_enable_i[2];
  wire cond_protocol_err  = (stuff_error_now||bit_error_now||form_error_now||ack_error_now||crc_error_now) && event_condition_enable_i[3];
  wire cond_queue_overflow= tx_push_rejected   && event_condition_enable_i[4];
  wire cond_bus_off       = bus_off_enter_pulse && event_condition_enable_i[5];
  wire cond_recovery      = recovery_exit_pulse && event_condition_enable_i[6];
  wire cond_xcvr_err      = transceiver_error_now && event_condition_enable_i[7];
  wire cond_buf_error     = read_word_err      && event_condition_enable_i[8];
  wire any_cond = ctl_event_enable &&
                  (cond_receive || cond_transmit || cond_arb_loss || cond_protocol_err ||
                   cond_queue_overflow || cond_bus_off || cond_recovery || cond_xcvr_err || cond_buf_error);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_cause_q <= 4'd0; evt_record_q <= '0;
      event_drop_count_q <= 16'h0; event_overflow_sticky_q <= 1'b0;
    end else if (module_reset_i) begin
      evt_pending_q <= 1'b0; event_overflow_sticky_q <= 1'b0;
    end else begin
      if (ctl_clr_event_overflow) event_overflow_sticky_q <= 1'b0;
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;

      if (any_cond) begin
        if (!evt_pending_q || evt_ready_i) begin
          evt_pending_q <= 1'b1;
          evt_cause_q <= cond_receive ? 4'd0 : cond_transmit ? 4'd1 : cond_arb_loss ? 4'd2 :
                         cond_protocol_err ? 4'd3 : cond_queue_overflow ? 4'd4 :
                         cond_bus_off ? 4'd5 : cond_recovery ? 4'd6 :
                         cond_xcvr_err ? 4'd7 : 4'd8;
          evt_record_q <= {
            {28'h0, (cond_receive?4'd0:cond_transmit?4'd1:cond_arb_loss?4'd2:cond_protocol_err?4'd3:
                     cond_queue_overflow?4'd4:cond_bus_off?4'd5:cond_recovery?4'd6:cond_xcvr_err?4'd7:4'd8)},
            8'h00, 8'd18, 16'h0022, timestamp_i
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
  assign fault_req_o  = protocol_error_sticky_q || transceiver_error_sticky_q || bus_off_q;
  assign activity_o   = activity_pulse;

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__READY_HI]  = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__FAULT_HI]  = fault_req_o;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__EVENT_OVERFLOW_HI] = event_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__ENABLED_HI]    = module_enable_i && ctl_enable;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__RX_NOT_EMPTY_HI] = !rx_queue_empty;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__TX_NOT_FULL_HI]  = !tx_queue_full;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__ERROR_WARNING_HI]  = error_warning_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__ERROR_PASSIVE_HI]  = error_passive_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__BUS_OFF_HI]        = bus_off_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__RX_OVERFLOW_HI]    = rx_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__TX_REJECTED_HI]    = tx_rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__PROTOCOL_ERROR_HI] = protocol_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__TRANSCEIVER_ERROR_HI] = transceiver_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__TX_ERROR_COUNT_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__TX_ERROR_COUNT_LO] = tec_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__RX_ERROR_COUNT_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__RX_ERROR_COUNT_LO] = rec_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_ERROR_COUNT__PROTOCOL_ERROR_COUNT_LO] = protocol_error_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_LEVEL__LEVEL_LO] = rx_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__IDENTIFIER_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__IDENTIFIER_LO] = rd_w_q[0][28:0];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__IDE_HI] = rd_w_q[0][29];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__RTR_HI] = rd_w_q[0][30];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_ID__VALID_HI] = snapshot_valid_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__DLC_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__DLC_LO] = rd_w_q[5][3:0];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__FLAGS_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__FLAGS_LO] = rd_w_q[5][15:4];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__SEQUENCE_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_META__SEQUENCE_LO] = rd_w_q[5][31:16];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_LO__DATA_0_3_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_LO__DATA_0_3_LO] = rd_w_q[1];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_HI__DATA_4_7_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_DATA_HI__DATA_4_7_LO] = rd_w_q[2];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_TIME_LO__TIMESTAMP_LO_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_TIME_LO__TIMESTAMP_LO_LO] = rd_w_q[3];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_TIME_HI__TIMESTAMP_HI_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_TIME_HI__TIMESTAMP_HI_LO] = rd_w_q[4];
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_LEVEL__LEVEL_LO] = tx_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL019_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_STATUS__RX_POP_REJECTED_HI] = rx_pop_rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_RX_OVERFLOW_COUNT__COUNT_LO] = rx_overflow_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_REJECTED_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL019_STATUS__CAN_TX_REJECTED_COUNT__COUNT_LO] = tx_rejected_count_q;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) snapshot_valid_sticky_q <= 1'b0;
    else if (module_reset_i) snapshot_valid_sticky_q <= 1'b0;
    else if (op_q == OP_RX_SNAPSHOT && read_word_ok && word_idx_q == 3'd5) snapshot_valid_sticky_q <= 1'b1;
  end

  task automatic rx_shift_data_bit(logic b);
    // Same byte0-first, MSB-first-within-byte addressing as compute_tx_bit's
    // ST_DATA case above -- must match exactly, since a TX-side loopback
    // frame is decoded by this same RX path.
    frame_data_q[{bit_idx_q[5:3], 3'd7 - bit_idx_q[2:0]}] <= b;
  endtask

endmodule : dfc_rtl019
