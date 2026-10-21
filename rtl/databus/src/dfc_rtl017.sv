// ============================================================================
// dfc_rtl017.sv -- RTL-017 ARINC 429 Receive Interface (ARCH-RTL017-001)
//
// Controlling spec: docs/rtl_specs/RTL-017_RevA.md (derived; its own SS2
// explicitly warns its port list is stale -- confirmed: real count is 33,
// not 20, against ARCH-002 Appendix A's own "RTL-017 - ARINC 429 Receive
// Interface (33 ports)" header, read directly this session, not from
// RevA's own guess). Owning contracts: ARCH-002 SS11.4 (ARCH-BUS-001,
// receive adapter behavior -- implemented in the SIBLING module
// dfc_rtl024_arinc_rx_adapter.sv, not here), SS12.3 (ARCH-BUF-022, the
// 4-word queue-entry layout), Appendix A (33-port catalog), Appendix F.1
// ARCH-RTL017-001 (one-outstanding buffer discipline owned by THIS
// module's own FSM, host-POP/route-POP same-head arbitration), Appendix
// F.3 (event/irq condition-mask allocation); REG-002 SS14 (0x1000-0x10FF,
// 13 registers, REG-1000..REG-1030); REG-ENC-008 (odd parity, error-code
// enumeration 0-8); VP-002 VP-MOD-017, VP-BUF-007/008/009/011 (disclosed
// in OPEN_ISSUES.md item 102 as CLIENT-module responsibilities the shared
// buffer's own testbench could not itself exercise -- this module's own
// testbench is what closes them, not inherited coverage).
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous local reset (RTL-002.module_reset_o[16]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl017_field_map.json, reggen.py v5). ARX_CONTROL
// (0x1000) does NOT reach this module at all -- its 5 real fields were
// migrated to a dedicated dfc_rtl024_arinc_rx_adapter_control_t struct
// consumed by the SIBLING adapter module (see that struct's own header
// and tools/reggen/rtl024_field_map.json for the full history of why).
//
// Port list: the 33 ports of ARCH-002 Appendix A "RTL-017 - ARINC 429
// Receive Interface (33 ports)", read directly and confirmed field-by-
// field this session (not assumed from RevA). Flat logic vectors sized
// by generated dfc_types_pkg _WIDTH constants; fields sliced by generated
// _HI/_LO constants (PROJECT_CONTINUITY.md Section 2 pkg::type_t rule --
// confirmed broken on this toolchain as a DECLARED TYPE; pkg::VALUE
// references in expressions remain safe and are used below).
//
// ---------------------------------------------------------------------------
// DESIGN, DISCLOSED (none of this is restated spec -- ARCH-002 describes
// externally observable behavior and the entry layout; the internal queue
// engine, arbitration, and error classification below are this module's
// own real implementation, built from first principles against those
// contracts, with every interpretation choice called out):
//
//  1. EIGHT-ENTRY QUEUE OVER THE 32-WORD CLIENT-0 SEGMENT (ARCH-BUF-022,
//     REG-1008's own "LEVEL... 0-8" legal range, confirmed against
//     dfc_constants_pkg::DFC_BUF_CLIENT0_WIDTH = 32 words = 8 entries x 4
//     words/entry). head_q/tail_q are 3-bit entry indices (0-7);
//     word_offset presented to the shared-buffer client port is always
//     entry_index*4+word_index (0-31), CLIENT-RELATIVE -- the shared-
//     buffer service itself adds the client's own absolute base
//     (confirmed from dfc_rtl024_shared_buffer.sv's own client_base()
//     function), so this module never computes or stores an absolute
//     0x020-0x03F address anywhere.
//
//  2. NO PRIVATE QUEUE-ENTRY STORAGE (RTLSTD-MEM-002). Every one of the 8
//     entries' 4 words lives ONLY in the centralized shared-buffer
//     memory, never duplicated into a local register array. This means
//     BOTH the host-snapshot path (ARX_SNAPSHOT/ARX_DATA/ARX_META/
//     ARX_TIME_LO/ARX_TIME_HI) and the route-source path (msg_record_o)
//     must each independently READ BACK the head entry's 4 words through
//     the SAME single buf_req_o/buf_rsp_i client-0 port a captured word's
//     own WRITE uses -- all three operation classes (WRITE new word,
//     SNAPSHOT read, ROUTE read) are serialized through one internal
//     arbiter below, since ARCH-BUF-013's one-outstanding-request
//     discipline is scoped to the whole CLIENT, not to an operation
//     class. Priority: WRITE (real-time, no backpressure from the
//     adapter) > SNAPSHOT (host-commanded, rare) > ROUTE (continuous
//     drain). The one-outstanding discipline is implemented IN THIS
//     MODULE'S OWN FSM (never issuing buf_req_valid_o for word N+1 before
//     buf_rsp_valid_i for word N arrives) -- the arbiter's own formal
//     proof (OPEN_ISSUES.md item 104) only guarantees the SERVICE never
//     double-grants two clients; it says nothing about a single client
//     issuing two outstanding requests of its own, which is this module's
//     own responsibility and has its own dedicated testbench case.
//
//  3. HOST POP IS PURE POINTER BOOKKEEPING, NOT A BUFFER ACCESS.
//     REG-100C/REG-1020's own register-behavior text is exact: ARX_SNAPSHOT
//     "Snapshots the oldest queued receive word" (a real read), ARX_POP
//     "Removes the snapped oldest word" (no read implied at all) -- POP
//     only needs to advance head_q/count_q, never touching buf_req_o/
//     buf_rsp_i. This means POP can be serviced on ANY cycle, including
//     while the internal arbiter is mid-WRITE or mid-SNAPSHOT or mid-ROUTE
//     (POP never contends for buffer bandwidth) -- implemented in its own
//     always_ff block below, independent of op_q/phase_q.
//
//  4. HOST-POP-VS-ROUTE-TRANSFER SAME-HEAD ARBITRATION (ARCH-RTL017-001's
//     own text: "only one removal may commit per cycle" -- the single
//     most structurally subtle requirement in this module, and
//     RTL-017_RevA.md SS6's own named test case). Two distinct hazards,
//     both handled:
//       (a) MID-READ RACE: a route transfer's own 4-word read takes
//           multiple cycles; if a host POP fires and advances head_q
//           WHILE that read is still in progress, the data already read
//           reflects an entry that is no longer head. Guarded by
//           head_snapshot_q (captured when the route read begins) vs.
//           head_q (compared the instant the read completes, before
//           presenting msg_valid_o) -- on a mismatch the read is
//           DISCARDED with no msg_valid_o assertion at all, and the
//           arbiter restarts fresh against whatever is now head. This
//           costs a redundant read in the rare contention case; it never
//           presents stale or double-removed data.
//       (b) SAME-CYCLE COMMIT RACE: a completed route read reaches its
//           commit cycle (msg_valid_o asserted, msg_ready_i accepting)
//           on the EXACT same cycle a host POP pulse also fires. DISCLOSED
//           CHOICE: host POP wins -- it is a deliberate, already-committed
//           host action, while the route path's own "commit" at that
//           point is just this module's internal bookkeeping catching up
//           to data it already decided to send. The message is STILL
//           delivered to RTL-021 this cycle either way (the valid/ready
//           handshake completes regardless of who wins the pointer
//           update) -- only whether THIS module's own head_q/count_q
//           advance a second time for the same entry is affected. When
//           host POP wins the tie, the route path's own removal is
//           suppressed (head_q/count_q already advanced via the POP path
//           this same cycle; advancing again would double-remove a
//           single entry).
//
//  5. ERROR-CODE CLASSIFICATION (REG-ENC-008: 0 none, 1 parity, 2
//     framing/gap, 3 RX overrun, 4 TX underrun [not applicable to a
//     receive-only module], 5 adapter, 6 disabled, 7 invalid
//     configuration, 8 shared-buffer; 9-0xFFF reserved). Classified at
//     CAPTURE time from the adapter's own four raw per-word signals
//     (rx_parity_error_i, rx_framing_error_i, rx_adapter_overrun_i,
//     arx_adapter_error_i) with a disclosed priority order for the single
//     numeric code field (the three independent PARITY_OK/FRAMING_OK/
//     ERROR_PRESENT bits in ARX_META/W1 are NOT priority-ordered -- each
//     reflects its own raw condition exactly): adapter(5) > overrun(3) >
//     framing(2) > parity(1) > none(0) -- hardware/transceiver-level
//     conditions outrank data-quality conditions, matching the adapter
//     module's own disclosed severity ordering for its sticky status
//     bits. Codes 6 (disabled) and 7 (invalid configuration) are
//     structurally UNREACHABLE from this classification path: a disabled
//     adapter (ARX_CONTROL.ENABLE=0) never produces rx_word_valid_i at
//     all (gated in the adapter's own FSM), and REG-1000's own write-
//     validation text ("value and all cross-field constraints validated
//     before atomic acceptance") means an invalid configuration can never
//     be committed in the first place -- consistent with the adapter
//     module's own header disclosure of the same two codes as
//     unreachable. Code 8 (shared-buffer) is NEVER a value stored in a
//     queue entry's own W1 (a write that fails any of its 4 words aborts
//     the whole entry without committing, per finding 7 below) --
//     it is produced LIVE, only in the host-snapshot and route-read
//     paths, as a disclosed override of whatever stale W1 a failed
//     read happened to return, since a mid-read shared-buffer error means
//     the just-read word data cannot be trusted.
//
//  6. MESSAGE-RECORD MAPPING (dfc_message_record_t, 192 bits -- ARCH-002
//     gives the generic 8-field canonical layout but no ARINC-specific
//     sub-mapping; this is this module's own disclosed choice, not a
//     restated spec fact): source_id=8'h00 (ARCH-MSG-001, this module's
//     fixed route-source identity), message_type=8'h01 (ARINC_WORD, the
//     confirmed SS11.3 message-type encoding), payload_length=4'd4 (the
//     ARINC word's 4-byte size), sequence=W1's own 16-bit SEQUENCE
//     truncated to this field's 4 bits (a real information loss, disclosed
//     -- the full 16-bit value remains available via ARX_META for any
//     host wanting the untruncated count), payload[31:0]=the 32-bit
//     ARINC word (LSB-justified in the 64-bit payload field,
//     payload[63:32]=0, reserved -- a single ARINC word never needs the
//     upper half), metadata[31:0]=the identical W1 value stored in the
//     queue entry (parity_ok/framing_ok/high_speed/error_present/
//     error_code/sequence, verbatim -- the route consumer gets the exact
//     same classification the host would see via ARX_META, not a
//     second, differently-encoded copy), flags[3:0]={error_present,
//     high_speed,framing_ok,parity_ok} (the same four status bits,
//     repeated for a consumer that only wants the top-level flags octet
//     without decoding metadata), flags[7:4]=0 reserved,
//     timestamp[63:0]={timestamp_hi,timestamp_lo} verbatim.
//
//  7. WRITE-TIME BUFFER FAILURE ABORTS THE WHOLE ENTRY, NO PARTIAL COMMIT
//     (ARCH-RTL017-001: "accepted word written completely before tail/
//     valid advances"). If any of the 4 words' buf_rsp_i.code is non-OK,
//     the in-progress write is abandoned immediately -- tail_q/count_q do
//     NOT advance (no partial, corrupt, or half-written entry is ever
//     made visible), the captured word is lost (not retried -- there is
//     nowhere to hold it once the adapter has moved on to a new bit-timing
//     window), and ARX_ERROR_COUNT increments (a real receive error,
//     disclosed as this module's own chosen classification -- REG-002 has
//     no separate "buffer write failed" counter, and ARX_OVERFLOW_COUNT is
//     reserved specifically for queue-full drops per REG-1028's own
//     "queue overrun count" text, a different condition).
//
//  8. OVERFLOW / BUSY-CAPTURE-REGISTER ADMISSION (ARCH-RTL017-001: "full
//     queue rejects+counts overrun"). Checked at CAPTURE time (the cycle
//     rx_word_valid_i pulses), not deferred to the arbiter: if count_q
//     already equals 8 (queue full), OR this module's own single-word
//     capture-staging register is still occupied by a PRIOR captured word
//     the arbiter has not yet started writing (write_pending_q still set
//     -- structurally unreachable in practice given the real ARINC bit-
//     timing margin vs. this module's few-cycle write-start latency, but
//     handled defensively and disclosed rather than assumed away per
//     CHTR-DOC-006), the new word is dropped and ARX_OVERFLOW_COUNT
//     increments (both hazards folded into the same counter -- REG-002
//     gives no separate counter to distinguish them, and both represent
//     the identical externally observable fact "a received word could not
//     be queued").
//
//  9. EVENTS/IRQ (Appendix F.3, RTL-017.evt_valid_o -> RTL-005 slot 16,
//     RTL-017.irq_req_o -> RTL-003 slot 3). Unlike RTL-016, this module's
//     OWN control struct (dfc_rtl017_control_t) carries no EVENT_ENABLE/
//     IRQ_ENABLE field at all -- those bits live in the ADAPTER's own
//     dedicated struct now (finding 3 of the plan's own architecture
//     section), reachable only to the adapter, not to this module. Event/
//     irq generation here is therefore gated purely by the generic
//     event_condition_enable_i[0]/irq_condition_enable_i[0] mask bits
//     (Appendix F.3) -- tied to a disclosed 64'h0 stub from dfc_rtl024.sv
//     in this build (RTL-001 does not yet implement per-module CONDITION_
//     MASK storage, the same gap every other module's own integration
//     discloses), so this module's one real event condition ("a word was
//     successfully queued") can never actually fire in this integration
//     yet -- a real, disclosed consequence, not a defect in this file.
//     One shared pending slot (same shape as every prior module);
//     RTL017_EVT_OVERFLOW_STATUS/event_drop_count_q track records lost
//     while that slot was occupied, the same generic per-module pattern.
//     event_data (dfc_event_record_t.event_data, 32 bits) carries the
//     entry's own W1 value verbatim, same reasoning as finding 6's
//     metadata field -- one classification encoding, reused everywhere.
//
// 10. ACTIVITY/FAULT. activity_o pulses one CORE_CLK cycle on a successful
//     WRITE commit (ARCH-002's own "one CORE_CLK pulse on qualified
//     accepted unit of work" -- a word accepted into the queue is this
//     module's clearest unit of work), reaching RTL-015.activity_i[1]
//     (ARCH-SAFE-007 ID 1, "ARINC RX word" -- not this module's own
//     Appendix A row's literal [2]; see OPEN_ISSUES.md items 83/140).
//     fault_req_o/status_o.fault: DISCLOSED CHOICE -- asserted whenever
//     the ADAPTER_ERROR sticky bit is set (a genuine external-transceiver
//     fault, the only condition here severe enough to warrant system-wide
//     fault escalation; parity/framing/overrun are ordinary data-quality
//     conditions already visible via their own sticky bits and error
//     counters, not systemic faults), reaching RTL-013.fault_source_i[10].
//     No explicit ARCH-002 fault-condition text for this module was
//     available to cite directly; this follows the same "report what is
//     genuinely wrong, not every imperfect word" judgment the adapter
//     module itself already applied to its own disclosed gaps.
// ============================================================================

module dfc_rtl017 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[16]

  input  logic [dfc_types_pkg::DFC_RTL017_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL017_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[3]

  output logic         msg_valid_o,          // RTL-021.source_valid_i[0]
  input  logic         msg_ready_i,          // RTL-021.source_ready_o[0]
  output logic [dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] msg_record_o,

  input  logic rx_word_valid_i,              // RTL-024.arinc_rx_adapter.rx_word_valid_o
  input  logic [31:0] rx_word_i,
  input  logic rx_parity_error_i,
  input  logic rx_framing_error_i,
  input  logic rx_speed_high_i,
  input  logic rx_adapter_overrun_i,
  input  logic arx_adapter_error_i,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  output logic         activity_o,           // RTL-015.activity_i[1] (item 140)
  input  logic         module_enable_i,      // RTL-002.module_enable_o[16]
  output logic         fault_req_o,          // RTL-013.fault_source_i[10]

  output logic         buf_req_valid_o,
  input  logic         buf_req_ready_i,
  output logic [dfc_types_pkg::DFC_BUFFER_REQ_WIDTH-1:0] buf_req_o,
  input  logic         buf_rsp_valid_i,
  output logic         buf_rsp_ready_o,
  input  logic [dfc_types_pkg::DFC_BUFFER_RSP_WIDTH-1:0] buf_rsp_i,

  input  logic [63:0] event_condition_enable_i,
  input  logic [63:0] irq_condition_enable_i
);

  // operating_state_i/observational_mode_i are real Appendix A inputs with
  // no functional use in this module's own logic (no per-operating-state
  // behavior is specified for RTL-017 anywhere in the -002 set) -- a
  // disclosed, genuinely-unused pair, consumed only by the unused-port
  // sink below, same precedent as RTL-016's own interlock_satisfied_i.
  logic unused_op_state_sink;
  assign unused_op_state_sink = (^operating_state_i) ^ observational_mode_i;

  localparam int unsigned QDEPTH = 8;

  // ==========================================================================
  // Shared-buffer response-code check (dfc_rtl024_shared_buffer.sv's own
  // CODE_OK=2'b00; any other value is treated uniformly as REG-ENC-008's
  // single "shared-buffer" classification -- this module does not split
  // RANGE/PROTOCOL/INTERNAL error further, since REG-002 gives it no
  // field to report that distinction in).
  // ==========================================================================
  wire [1:0]  rsp_code   = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__CODE_HI:dfc_types_pkg::DFC_BUFFER_RSP__CODE_LO];
  wire        rsp_ok     = (rsp_code == 2'b00);
  wire [31:0] rsp_data   = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_HI:dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_LO];

  // ==========================================================================
  // Control-field unpack (reggen v5 WO-CMD/W1C classes are real one-cycle
  // pulses already generated by RTL-001's regbank -- confirmed directly
  // from reggen.py's own needs_pulse/pulse_q generation logic -- so the
  // CAPTURE/POP/W1C-clear fields below are used directly as one-shot
  // pulses, no edge-detection needed here. COUNTER-CLR fields are NOT
  // auto-pulsed (reggen only pulses WO-CMD/W1C) -- they forward the held,
  // last-written register value, so this module edge-detects the
  // all-ones clear command itself below.)
  // ==========================================================================
  wire ctl_clr_parity_error   = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__PARITY_ERROR_HI];
  wire ctl_clr_framing_error  = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__FRAMING_ERROR_HI];
  wire ctl_clr_overrun        = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__OVERRUN_HI];
  wire ctl_clr_adapter_error  = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__ADAPTER_ERROR_HI];
  wire ctl_capture_pulse      = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_SNAPSHOT__CAPTURE_HI];
  wire ctl_pop_pulse          = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_POP__POP_HI];
  wire [31:0] ctl_error_count_wr    = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_CONTROL__ARX_ERROR_COUNT__COUNT_LO];
  wire [31:0] ctl_overflow_count_wr = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_CONTROL__ARX_OVERFLOW_COUNT__COUNT_LO];
  wire ctl_clr_pop_rejected   = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__POP_REJECTED_HI];
  wire [31:0] ctl_rejected_access_count_wr = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_REJECTED_ACCESS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_CONTROL__ARX_REJECTED_ACCESS_COUNT__COUNT_LO];
  wire ctl_clr_event_overflow = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__RTL017_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];
  wire ctl_clr_snapshot_valid = control_i[dfc_types_pkg::DFC_RTL017_CONTROL__ARX_STATUS__SNAPSHOT_VALID_HI];

  logic [31:0] error_count_wr_q, overflow_count_wr_q, rejected_access_count_wr_q;
  wire clr_error_count_now    = (ctl_error_count_wr    == 32'hFFFFFFFF) && (error_count_wr_q    != 32'hFFFFFFFF);
  wire clr_overflow_count_now = (ctl_overflow_count_wr == 32'hFFFFFFFF) && (overflow_count_wr_q != 32'hFFFFFFFF);
  wire clr_rejected_access_count_now = (ctl_rejected_access_count_wr == 32'hFFFFFFFF) && (rejected_access_count_wr_q != 32'hFFFFFFFF);

  // ==========================================================================
  // Word capture: latches one adapter-presented word per rx_word_valid_i
  // pulse into a one-deep staging register, classifies its error code,
  // and performs the overflow/busy admission check (finding 8).
  // ==========================================================================
  // capture_pending_q: latches a host CAPTURE command exactly like
  // write_pending_q latches an adapter word -- without this, a CAPTURE
  // pulse arriving while the arbiter is mid-WRITE or mid-ROUTE (both
  // multi-cycle) would be silently lost, since PH_IDLE is the only place
  // a command can be serviced and a bare one-cycle pulse has no guarantee
  // of landing on an IDLE cycle. Real bug found via a real failed
  // testbench run this session (Case 2's first error-code check), not
  // assumed -- see this module's own testbench for the exact scenario
  // (an automatic ROUTE read starting the same cycle a CAPTURE pulse
  // arrives swallowed the command with no trace).
  logic        capture_pending_q;
  logic        write_pending_q;
  logic [31:0] capture_word_q;
  logic        capture_parity_ok_q, capture_framing_ok_q, capture_high_speed_q;
  logic [11:0] capture_error_code_q;
  logic [63:0] capture_timestamp_q;

  function automatic logic [11:0] classify_error_code(
    logic parity_err, logic framing_err, logic overrun, logic adapter_err
  );
    if (adapter_err)      classify_error_code = 12'd5;
    else if (overrun)     classify_error_code = 12'd3;
    else if (framing_err) classify_error_code = 12'd2;
    else if (parity_err)  classify_error_code = 12'd1;
    else                  classify_error_code = 12'd0;
  endfunction

  // ==========================================================================
  // Queue pointers / counters.
  // ==========================================================================
  logic [2:0] head_q, tail_q;
  logic [3:0] count_q;
  logic [15:0] seq_q;

  logic [31:0] error_count_q, overflow_count_q, rejected_access_count_q;
  logic parity_error_sticky_q, framing_error_sticky_q, overrun_sticky_q;
  logic adapter_error_sticky_q, pop_rejected_sticky_q;

  // Host-snapshot staging (REAL RTL-017-owned registers -- a single-entry
  // scratch snapshot, not a duplicate of the whole queue; finding 2).
  logic [31:0] arx_data_q;
  logic        snap_parity_ok_q, snap_framing_ok_q, snap_high_speed_q, snap_error_present_q;
  logic [11:0] snap_error_code_q;
  logic [15:0] snap_sequence_q;
  logic [31:0] snap_time_lo_q, snap_time_hi_q;
  logic        snapshot_valid_sticky_q;

  // Internal buffer-client arbiter: WRITE > SNAPSHOT > ROUTE (finding 2).
  localparam logic [1:0] OP_NONE     = 2'd0;
  localparam logic [1:0] OP_WRITE    = 2'd1;
  localparam logic [1:0] OP_SNAPSHOT = 2'd2;
  localparam logic [1:0] OP_ROUTE    = 2'd3;
  localparam logic [1:0] PH_IDLE   = 2'd0;
  localparam logic [1:0] PH_REQ    = 2'd1;
  localparam logic [1:0] PH_WAIT   = 2'd2;

  logic [1:0] op_q, phase_q;
  logic [1:0] word_idx_q;
  logic [2:0] head_snapshot_q;    // captured at OP_ROUTE start, finding 4(a)

  logic [31:0] wr_w0_q, wr_w1_q, wr_w2_q, wr_w3_q;   // WRITE staging
  logic [31:0] rd_w0_q, rd_w1_q, rd_w2_q, rd_w3_q;   // SNAPSHOT/ROUTE staging

  // Held route message, independent of the arbiter's own op_q/phase_q --
  // see the "route_pending_q" header comment above (finding 4 fix).
  logic         route_pending_q;
  logic [191:0] route_pending_record_q;
  logic         route_pending_removed_q;
  logic         activity_q;

  // ---- event/irq (finding 9): one shared pending slot, same shape as
  // every prior module. Single condition: "a word was successfully
  // queued" (write commit).
  logic        evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic [15:0] event_drop_count_q;
  logic        event_overflow_sticky_q;
  wire         evt_condition_now = event_condition_enable_i[0];
  wire         irq_condition_now = irq_condition_enable_i[0];
  wire         slot_free = !evt_pending_q || evt_ready_i;

  // --------------------------------------------------------------------
  // Combinational: what completes / commits THIS cycle (shared between
  // the main arbiter block and the independent host-POP block, finding
  // 3/4). All are function-of-current-state, read by both blocks below.
  // --------------------------------------------------------------------
  wire write_word_commit = (op_q == OP_WRITE) && (phase_q == PH_WAIT) &&
                            buf_rsp_valid_i && rsp_ok && (word_idx_q == 2'd3);
  wire write_word_abort   = (op_q == OP_WRITE) && (phase_q == PH_WAIT) &&
                             buf_rsp_valid_i && !rsp_ok;
  wire read_word_ok       = (phase_q == PH_WAIT) && buf_rsp_valid_i && rsp_ok;
  wire read_word_err      = (phase_q == PH_WAIT) && buf_rsp_valid_i && !rsp_ok;
  wire read_last_word     = (word_idx_q == 2'd3);

  // route_pending_q/route_pending_record_q hold a COMPLETED route read
  // independently of the arbiter's own op_q/phase_q (finding 4, real bug
  // found and fixed this session via a real failed testbench run, not
  // assumed correct from the design alone -- see this module's own
  // testbench, "Case2/Case3 arbiter-stuck" symptom). Presenting
  // msg_valid_o through the SAME state machine that also services WRITE/
  // SNAPSHOT meant an unaccepted route message (msg_ready_i low) parked
  // the arbiter in a commit-wait state FOREVER, since valid/ready's own
  // "stable while stalled" rule correctly forbids retracting msg_valid_o
  // before acceptance -- but that starved WRITE of its required TOP
  // priority (ARCH-RTL017-001: real-time, no backpressure from the
  // adapter) for as long as the route consumer applied backpressure, a
  // real correctness bug (masked in THIS integration only because
  // dfc_rtl024.sv ties msg_ready_i to a permanent 1, never exercising
  // backpressure -- a future real RTL-021 would have hit this). Fixed by
  // decoupling: the arbiter latches route_pending_record_q and returns to
  // PH_IDLE immediately once a route read completes, free to service
  // WRITE/SNAPSHOT/a new ROUTE read while the held message independently
  // waits for msg_ready_i. route_pending_removed_q tracks the one
  // remaining race this split creates: a host POP can still fire while a
  // read message is held pending acceptance (host POP never touches the
  // buffer, so nothing stops it) -- when that happens, head_q/count_q are
  // already correctly advanced by the POP path below, and this flag
  // simply tells the LATER acceptance not to remove the same entry twice.
  wire route_commit_attempt = route_pending_q && msg_ready_i;
  wire host_pop_accepted    = ctl_pop_pulse && (count_q != 4'd0);
  wire host_pop_rejected    = ctl_pop_pulse && (count_q == 4'd0);
  wire route_commit_now     = route_commit_attempt && !route_pending_removed_q && !host_pop_accepted;  // finding 4(b)

  wire head_advance = host_pop_accepted || route_commit_now;
  wire tail_advance  = write_word_commit;

  assign msg_valid_o  = route_pending_q;
  assign msg_record_o = route_pending_record_q;

  assign buf_req_valid_o = (phase_q == PH_REQ);
  assign buf_rsp_ready_o = (phase_q == PH_WAIT);

  wire [2:0] req_entry = (op_q == OP_WRITE) ? tail_q : head_q;
  wire [4:0] req_word_offset = {req_entry, word_idx_q};
  wire       req_is_write    = (op_q == OP_WRITE);

  wire [31:0] wr_word_mux = (word_idx_q == 2'd0) ? wr_w0_q :
                             (word_idx_q == 2'd1) ? wr_w1_q :
                             (word_idx_q == 2'd2) ? wr_w2_q : wr_w3_q;

  assign buf_req_o = {
    wr_word_mux,                                                        // [41:10] write_data
    req_is_write,                                                       // [9] write
    {4'b0, req_word_offset}                                             // [8:0] word_offset
  };

  // ==========================================================================
  // Message-record construction (finding 6) -- built combinationally from
  // the read-back staging registers; declared here (before the arbiter's
  // own always_ff block below references it when a route read completes)
  // per this project's confirmed real toolchain requirement
  // that a referenced wire be declared textually before its use, not just
  // for named port connections (PROJECT_CONTINUITY.md Section 2).
  // ==========================================================================
  wire [15:0] route_sequence_full = rd_w1_q[31:16];
  wire [191:0] msg_record_comb = {
    rd_w3_q, rd_w2_q,                                   // [191:128] timestamp
    32'h0, rd_w0_q,                                     // [127:64] payload (LSB-justified)
    rd_w1_q,                                            // [63:32] metadata (verbatim W1)
    8'h00,                                               // [31:24] source_id (ARCH-MSG-001)
    8'h01,                                               // [23:16] message_type (ARINC_WORD)
    4'd4,                                                // [15:12] payload_length (bytes)
    route_sequence_full[3:0],                            // [11:8] sequence (truncated, disclosed)
    4'h0, rd_w1_q[3], rd_w1_q[2], rd_w1_q[1], rd_w1_q[0] // [7:0] flags
  };

  // ==========================================================================
  // Capture (always_ff): admits a new adapter word into the one-deep
  // staging register, or drops it with ARX_OVERFLOW_COUNT (finding 8).
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      write_pending_q      <= 1'b0;
      capture_word_q        <= 32'h0;
      capture_parity_ok_q    <= 1'b0;
      capture_framing_ok_q   <= 1'b0;
      capture_high_speed_q   <= 1'b0;
      capture_error_code_q   <= 12'h0;
      capture_timestamp_q    <= 64'h0;
    end else if (module_reset_i) begin
      write_pending_q <= 1'b0;
    end else if (rx_word_valid_i && module_enable_i) begin
      if (!(count_q == QDEPTH[3:0] || write_pending_q)) begin
        write_pending_q      <= 1'b1;
        capture_word_q        <= rx_word_i;
        capture_parity_ok_q   <= !rx_parity_error_i;
        capture_framing_ok_q  <= !rx_framing_error_i;
        capture_high_speed_q  <= rx_speed_high_i;
        capture_error_code_q  <= classify_error_code(rx_parity_error_i, rx_framing_error_i,
                                                       rx_adapter_overrun_i, arx_adapter_error_i);
        capture_timestamp_q   <= timestamp_i;
      end
    end else if (write_word_commit || write_word_abort) begin
      // consumed by the arbiter this cycle -- clear only once the
      // in-flight attempt actually resolves (commit or abort), never
      // before, so a second adapter word arriving mid-write is correctly
      // seen as "still pending" by the admission check above.
      write_pending_q <= 1'b0;
    end
  end

  wire overflow_drop_now = rx_word_valid_i && module_enable_i &&
                            (count_q == QDEPTH[3:0] || write_pending_q);

  // ==========================================================================
  // Main buffer-client arbiter (always_ff): WRITE/SNAPSHOT/ROUTE, one
  // outstanding buf_req/rsp at a time (finding 2).
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 2'd0;
      head_q <= 3'd0; tail_q <= 3'd0; count_q <= 4'd0;
      head_snapshot_q <= 3'd0;
      wr_w0_q <= 32'h0; wr_w1_q <= 32'h0; wr_w2_q <= 32'h0; wr_w3_q <= 32'h0;
      rd_w0_q <= 32'h0; rd_w1_q <= 32'h0; rd_w2_q <= 32'h0; rd_w3_q <= 32'h0;
      route_pending_q <= 1'b0; route_pending_record_q <= 192'h0; route_pending_removed_q <= 1'b0;
      capture_pending_q <= 1'b0;
      seq_q <= 16'h0;
      activity_q <= 1'b0;
      arx_data_q <= 32'h0;
      snap_parity_ok_q <= 1'b0; snap_framing_ok_q <= 1'b0; snap_high_speed_q <= 1'b0;
      snap_error_present_q <= 1'b0; snap_error_code_q <= 12'h0; snap_sequence_q <= 16'h0;
      snap_time_lo_q <= 32'h0; snap_time_hi_q <= 32'h0;
      snapshot_valid_sticky_q <= 1'b0;
      error_count_q <= 32'h0; overflow_count_q <= 32'h0; rejected_access_count_q <= 32'h0;
      parity_error_sticky_q <= 1'b0; framing_error_sticky_q <= 1'b0;
      overrun_sticky_q <= 1'b0; adapter_error_sticky_q <= 1'b0; pop_rejected_sticky_q <= 1'b0;
      error_count_wr_q <= 32'h0; overflow_count_wr_q <= 32'h0; rejected_access_count_wr_q <= 32'h0;
    end else if (module_reset_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 2'd0;
      head_q <= 3'd0; tail_q <= 3'd0; count_q <= 4'd0; seq_q <= 16'h0;
      route_pending_q <= 1'b0; route_pending_removed_q <= 1'b0;
      capture_pending_q <= 1'b0;
      error_count_q <= 32'h0; overflow_count_q <= 32'h0; rejected_access_count_q <= 32'h0;
      parity_error_sticky_q <= 1'b0; framing_error_sticky_q <= 1'b0;
      overrun_sticky_q <= 1'b0; adapter_error_sticky_q <= 1'b0; pop_rejected_sticky_q <= 1'b0;
      snapshot_valid_sticky_q <= 1'b0;
      activity_q <= 1'b0;
    end else begin
      activity_q <= 1'b0;   // default: one-cycle pulse

      // -------------------- edge-detected COUNTER-CLR clears -----------
      error_count_wr_q            <= ctl_error_count_wr;
      overflow_count_wr_q         <= ctl_overflow_count_wr;
      rejected_access_count_wr_q <= ctl_rejected_access_count_wr;
      if (clr_error_count_now)            error_count_q            <= 32'h0;
      if (clr_overflow_count_now)         overflow_count_q         <= 32'h0;
      if (clr_rejected_access_count_now)  rejected_access_count_q  <= 32'h0;

      // -------------------- sticky W1C clears (new evidence dominates,
      // applied below after this block -- see the "new evidence" writes
      // further down, which unconditionally override a same-cycle clear,
      // the project-wide sticky precedent) ------------------------------
      if (ctl_clr_parity_error)   parity_error_sticky_q   <= 1'b0;
      if (ctl_clr_framing_error)  framing_error_sticky_q  <= 1'b0;
      if (ctl_clr_overrun)        overrun_sticky_q        <= 1'b0;
      if (ctl_clr_adapter_error)  adapter_error_sticky_q  <= 1'b0;
      if (ctl_clr_pop_rejected)   pop_rejected_sticky_q   <= 1'b0;
      if (ctl_clr_snapshot_valid) snapshot_valid_sticky_q <= 1'b0;

      // -------------------- overflow drop (finding 8) -------------------
      if (overflow_drop_now) overflow_count_q <= (overflow_count_q == 32'hFFFFFFFF) ? overflow_count_q : overflow_count_q + 32'd1;

      // -------------------- host POP (finding 3) ------------------------
      if (host_pop_rejected) begin
        pop_rejected_sticky_q  <= 1'b1;
        rejected_access_count_q <= (rejected_access_count_q == 32'hFFFFFFFF) ? rejected_access_count_q : rejected_access_count_q + 32'd1;
      end

      // -------------------- arbiter state machine -----------------------
      case (phase_q)
        PH_IDLE: begin
          if (write_pending_q) begin
            op_q <= OP_WRITE; word_idx_q <= 2'd0; phase_q <= PH_REQ;
            wr_w0_q <= capture_word_q;
            // W1 = {sequence[31:16], error_code[15:4], error_present[3],
            // high_speed[2], framing_ok[1], parity_ok[0]} -- 16+12+1+1+1+1=32,
            // matching ARX_META's confirmed layout exactly (finding 5/6).
            wr_w1_q <= {seq_q, capture_error_code_q,
                        (capture_error_code_q != 12'd0),
                        capture_high_speed_q,
                        capture_framing_ok_q,
                        capture_parity_ok_q};
            wr_w2_q <= capture_timestamp_q[31:0];
            wr_w3_q <= capture_timestamp_q[63:32];
          end else if (capture_pending_q) begin
            capture_pending_q <= 1'b0;
            if (count_q == 4'd0) begin
              pop_rejected_sticky_q   <= 1'b1;
              rejected_access_count_q <= (rejected_access_count_q == 32'hFFFFFFFF) ? rejected_access_count_q : rejected_access_count_q + 32'd1;
            end else begin
              op_q <= OP_SNAPSHOT; word_idx_q <= 2'd0; phase_q <= PH_REQ;
            end
          end else if (count_q != 4'd0 && !route_pending_q) begin
            op_q <= OP_ROUTE; word_idx_q <= 2'd0; phase_q <= PH_REQ;
            head_snapshot_q <= head_q;
          end
        end

        PH_REQ: begin
          if (buf_req_ready_i) phase_q <= PH_WAIT;
        end

        PH_WAIT: begin
          if (read_word_err) begin
            // abort whatever op is in progress; WRITE/READ both count as
            // a receive error (finding 5/7); nothing commits.
            error_count_q <= (error_count_q == 32'hFFFFFFFF) ? error_count_q : error_count_q + 32'd1;
            op_q <= OP_NONE; phase_q <= PH_IDLE;
          end else if (read_word_ok) begin
            case (word_idx_q)
              2'd0: rd_w0_q <= rsp_data;
              2'd1: rd_w1_q <= rsp_data;
              2'd2: rd_w2_q <= rsp_data;
              default: rd_w3_q <= rsp_data;
            endcase
            if (read_last_word) begin
              if (op_q == OP_WRITE) begin
                seq_q <= seq_q + 16'd1;
                activity_q <= 1'b1;
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end else if (op_q == OP_SNAPSHOT) begin
                arx_data_q <= rd_w0_q;
                snap_parity_ok_q     <= rd_w1_q[0];
                snap_framing_ok_q    <= rd_w1_q[1];
                snap_high_speed_q    <= rd_w1_q[2];
                snap_error_present_q <= rd_w1_q[3];
                snap_error_code_q    <= rd_w1_q[15:4];
                snap_sequence_q      <= rd_w1_q[31:16];
                snap_time_lo_q       <= rd_w2_q;
                snap_time_hi_q       <= rd_w3_q;
                snapshot_valid_sticky_q <= 1'b1;
                op_q <= OP_NONE; phase_q <= PH_IDLE;
              end else begin // OP_ROUTE
                // finding 4 fix: latch the held message and return to
                // IDLE immediately -- never park the arbiter itself
                // waiting for msg_ready_i (see route_pending_q's own
                // header comment above for why).
                if (head_snapshot_q != head_q) begin
                  // finding 4(a): stale -- head moved mid-read, discard
                  // and let IDLE restart fresh next cycle.
                  op_q <= OP_NONE; phase_q <= PH_IDLE;
                end else begin
                  route_pending_q         <= 1'b1;
                  route_pending_record_q  <= msg_record_comb;
                  route_pending_removed_q <= 1'b0;
                  op_q <= OP_NONE; phase_q <= PH_IDLE;
                end
              end
            end else begin
              word_idx_q <= word_idx_q + 2'd1;
              phase_q <= PH_REQ;
            end
          end
        end

        default: begin
          op_q <= OP_NONE; phase_q <= PH_IDLE;
        end
      endcase

      // -------------------- held route message (finding 4 fix) ----------
      // Independent of phase_q/op_q above -- a host POP can fire, or the
      // held message can be accepted, on any cycle regardless of what the
      // main arbiter is doing.
      if (route_commit_attempt) route_pending_q <= 1'b0;
      if (route_pending_q && host_pop_accepted && !route_pending_removed_q)
        route_pending_removed_q <= 1'b1;

      // Latch a new CAPTURE request independently of phase_q, so it is
      // never missed while the arbiter is mid-WRITE/mid-ROUTE (see
      // capture_pending_q's own header comment above). This statement
      // runs AFTER PH_IDLE's own clear earlier in this same block, so on
      // the rare cycle where an old pending request is just starting to
      // be serviced AND a brand-new CAPTURE pulse arrives simultaneously,
      // this later write wins and the new request stays latched for the
      // NEXT PH_IDLE visit rather than being silently absorbed/lost.
      if (ctl_capture_pulse) capture_pending_q <= 1'b1;

      // -------------------- queue pointer update (finding 3/4) ----------
      if (tail_advance) tail_q <= tail_q + 3'd1;
      if (head_advance) head_q <= head_q + 3'd1;
      count_q <= count_q + (tail_advance ? 4'd1 : 4'd0) - (head_advance ? 4'd1 : 4'd0);

      // -------------------- new sticky evidence (dominates a same-cycle
      // clear attempt above, project-wide precedent) ---------------------
      if (write_word_commit) begin
        if (!capture_parity_ok_q)  parity_error_sticky_q  <= 1'b1;
        if (!capture_framing_ok_q) framing_error_sticky_q <= 1'b1;
        if (capture_error_code_q == 12'd3) overrun_sticky_q       <= 1'b1;
        if (capture_error_code_q == 12'd5) adapter_error_sticky_q <= 1'b1;
      end
    end
  end

  // ==========================================================================
  // Event/IRQ generation (finding 9).
  // ==========================================================================
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_record_q <= '0;
      event_drop_count_q <= 16'h0; event_overflow_sticky_q <= 1'b0;
    end else if (module_reset_i) begin
      evt_pending_q <= 1'b0;
      event_overflow_sticky_q <= 1'b0;
    end else begin
      if (ctl_clr_event_overflow) event_overflow_sticky_q <= 1'b0;

      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;

      if (write_word_commit && evt_condition_now) begin
        if (slot_free) begin
          evt_pending_q <= 1'b1;
          // dfc_event_record_t (128b): [127:96] event_data, [95:88] flags,
          // [87:80] source_id, [79:64] event_id, [63:0] timestamp. wr_w1_q
          // already holds this word's complete 32-bit W1 encoding (built at
          // the PH_IDLE->PH_REQ transition, held constant through the whole
          // write sequence) -- reused verbatim as event_data (finding 9).
          evt_record_q  <= {
            wr_w1_q,        // [127:96] event_data
            8'h00,          // [95:88] flags
            8'd16,          // [87:80] source_id = evt bus slot 16
            16'h0020,       // [79:64] event_id (C.7 0x0020)
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
  assign irq_req_o    = evt_pending_q && irq_condition_now;
  assign fault_req_o  = adapter_error_sticky_q;
  assign activity_o   = activity_q;

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__READY_HI]                  = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__FAULT_HI]                  = adapter_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__EVENT_OVERFLOW_HI]         = event_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__ENABLED_HI]    = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__NOT_EMPTY_HI]  = (count_q != 4'd0);
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__FULL_HI]       = (count_q == QDEPTH[3:0]);
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__SNAPSHOT_VALID_HI] = snapshot_valid_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__PARITY_ERROR_HI]   = parity_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__FRAMING_ERROR_HI]  = framing_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__OVERRUN_HI]        = overrun_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__ADAPTER_ERROR_HI]  = adapter_error_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_QUEUE_LEVEL__LEVEL_LO] = count_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_DATA__WORD_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_DATA__WORD_LO] = arx_data_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__PARITY_OK_HI]     = snap_parity_ok_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__FRAMING_OK_HI]    = snap_framing_ok_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__HIGH_SPEED_HI]    = snap_high_speed_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_PRESENT_HI] = snap_error_present_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__ERROR_CODE_LO] = snap_error_code_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__SEQUENCE_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_META__SEQUENCE_LO] = snap_sequence_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_TIME_LO__TIMESTAMP_LO_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_TIME_LO__TIMESTAMP_LO_LO] = snap_time_lo_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_TIME_HI__TIMESTAMP_HI_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_TIME_HI__TIMESTAMP_HI_LO] = snap_time_hi_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_ERROR_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_ERROR_COUNT__COUNT_LO] = error_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_OVERFLOW_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_OVERFLOW_COUNT__COUNT_LO] = overflow_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_STATUS__POP_REJECTED_HI] = pop_rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL017_STATUS__ARX_REJECTED_ACCESS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL017_STATUS__ARX_REJECTED_ACCESS_COUNT__COUNT_LO] = rejected_access_count_q;

endmodule : dfc_rtl017
