// ============================================================================
// dfc_rtl021.sv -- RTL-021 Databus Routing Engine (ARCH-RTL021-001)
//
// Controlling spec: docs/rtl_specs/RTL-021_RevA.md (derived; its own SS2
// claims "16 total" ports and two places claim "17 registers" -- BOTH
// confirmed stale this session, continuing the unbroken run of stale
// Databus module-spec counts (RTL-017 20->33, RTL-018 18->28, RTL-019
// 19->33, RTL-020 17->32): ARCH-002 Appendix A's real header reads
// "RTL-021 - Databus Routing Engine (30 ports)" -- confirmed by direct row
// count of the real table, not assumed from the header alone -- and
// REG-002's own Section 18 block header says "Register count: 24", also
// confirmed by direct row count (24, including the 5 ROUTE_ACTIVE_*
// readback registers and the two independently-clearable
// ROUTE_INGRESS_LOSS_COUNT_*/ROUTE_DESTINATION_DROP_COUNT_* counter groups
// RevA's own prose never enumerates). Implemented against the real
// 30-port/24-register set. Owning contracts: ARCH-002 SS11 (ARCH-MSG-001
// through 005 canonical endpoints/types, SS11.2 fixed 5x5 authorization
// matrix, SS11.3 ARCH-ROUTE-001 through 008 routing algorithm), SS12.1
// (ARCH-BUF-009/010 shared-buffer allocation), Appendix A (30-port
// catalog), Appendix B.2 (dfc_message_record_t, 192 bits), Appendix F.1
// ARCH-RTL021-001 (epoch-capture discipline), Appendix F.3 (8 real event/
// irq conditions); REG-002 SS18 (0x1400-0x145C, 24 registers);
// VP-002 VP-MOD-021/VP-BUS-007 through 009.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous local reset (RTL-002.module_reset_o[20]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl021_field_map.json, reggen.py v6).
//
// ARCH-002-INTERNAL GAPS FIXED THIS SESSION (same gap CLASS already fixed
// for RTL-002 through RTL-020, approved before this edit -- ARCH-002
// undershoots a REG-002-specified real forwarding need by a small,
// unambiguous number of bits):
//  (a) dfc_rtl021_control_t had no clear-forwarding field for
//      RTL021_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-1440 bit 0, a real
//      W1C field) -- the 13th real instance of this exact CONTROL-side gap
//      class. Fixed: ARCH-002 grew the struct 135->136 bits, adding
//      rtl021_evt_overflow_status__event_overflow at the new highest bit
//      (135).
//  (b) dfc_rtl021_status_t had NO field anywhere for ROUTE_ACTIVE_CONTROL's
//      ENABLE/DROP_ON_FULL (REG-145C, a real "external" readback register
//      with real, specific REG-002 text: "Reads selected entry's active
//      enable"/"active drop-on-full policy") -- confirmed by summing the
//      struct's own documented bit ranges end to end (0 through 335
//      inclusive, exactly 336 bits, fully tiled, no gap anywhere for this).
//      This is the SAME gap class as (a), applied to the STATUS side
//      instead of the CONTROL side, with equally unambiguous semantics (two
//      single RO mirror bits, nothing to invent). Fixed: ARCH-002 grew the
//      struct 336->338 bits, adding route_active_control__enable/
//      __drop_on_full at the new highest bits (336/337).
//  Both fixes regenerated via extract_types.py/pkggen.py with an isolated,
//  confirmed diff (every other struct's bit positions unchanged).
//
// REGGEN.PY EXTENDED THIS SESSION (v5->v6): a brand-new "COUNTER16-CLR"
// register access class, the first real need for it anywhere in this
// project. REG-002's own text for the six ROUTE_INGRESS_LOSS_COUNT_*/
// ROUTE_DESTINATION_DROP_COUNT_* registers ("Independent halfword
// whole-counter clears"; "Any other halfword rejects the complete word")
// packs TWO independent 16-bit saturating counters per 32-bit register,
// each independently host-clearable -- a shape neither of reggen.py's two
// existing mechanisms (COUNTER-CLR's whole-32-bit raw-value-forward, or
// WO-CMD/W1C's whole-32-bit pulse) can produce. reggen.py now generates,
// per register HALF: a genuine one-cycle clear-pulse (write 0xFFFF to that
// 16-bit half, same halfword-isolation discipline as the 32-bit
// COUNTER-CLR precedent but per-halfword) on the CONTROL side, driving one
// specific bit of the wider 5-bit dfc_rtl021_control_t clear vector named
// by a new field-map "bit" key; and, on the STATUS side, a sub-slice read
// (one 16-bit window out of the wider 80-bit packed
// dfc_rtl021_status_t count vector, "five packed 16-bit saturating counts
// ... in ascending slices" per ARCH-002's own text) using the same "bit"
// key. See tools/reggen/rtl021_field_map.json's own "_source" note and
// reggen.py's own inline comments at both edit points for the full
// reasoning; verified via a real regenerate.ps1 run producing
// "real cross-module forwarding wired for RTL-021: 18 control regs, 15
// status regs" with no assertion failures (the generic
// mapped_bits==control_width tiling check, run unmodified, still passed).
//
// MASTER SHARED-RESOURCE-INDEX TABLE CHECKED BEFORE WIRING (OPEN_ISSUES.md
// item 140, mandatory per this session's own task briefing, re-run here
// exactly as for RTL-020's own session): RTL-021's own Appendix A
// `activity_o` row literally reads "RTL-015.activity_i[5]" -- but the
// master table (dfc_rtl024.sv's own rtl015_activity_vector_comb block,
// built directly from RTL-015's own activity_i row + ARCH-SAFE-007's
// ID-order text, the resolution authority item 83 already established and
// item 140 already re-confirmed against RTL-017/019/020's own analogous
// rows) assigns bit 5 to "health qualified transition" (RTL-011, already
// real and correctly wired there). RTL-021's own row is the SIXTH instance
// of the exact same already-identified-and-rejected conflict class (item
// 83: five conflicting individual producer rows -- RTL-012/017/019/020/021
// -- each overruled in favor of RTL-015's own consumer-side row), not a
// fresh ambiguity. RTL-015's own canonical 8-bit order (0 host, 1 ARINC RX,
// 2 CAN RX, 3 UART RX, 4 GPIO, 5 health, 6 user diagnostic, 7 watchdog) has
// NO slot anywhere for "routing engine activity" -- unlike RTL-012/017/
// 019/020, which each genuinely do have a different, correct slot
// elsewhere in that same order, RTL-021 has no legal activity_i
// destination AT ALL. activity_o is therefore implemented as a real,
// correctly-pulsing port (one CORE_CLK pulse per qualified accepted unit
// of work, matching Appendix A's own generic description) but left
// UNCONNECTED at dfc_rtl024.sv integration -- a disclosed, structural
// consequence of this conflict class, not a bug in this module.
//
// ---------------------------------------------------------------------------
// DESIGN, DISCLOSED (ARCH-002/REG-002 describe externally observable
// behavior, the routing algorithm contracts, and the entry/buffer layouts;
// the internal ingress-slot/route-table/destination-queue engine below is
// this module's own real implementation, built from first principles
// against those contracts, with every interpretation choice called out):
//
//  1. ROUTE TABLE STORAGE: ONE WORKING "STAGED" FIELD SET (ROUTE_STAGE_*,
//     stored and continuously forwarded by RTL-001 itself as plain
//     internal_reg registers -- confirmed via dfc_rtl001_regbank_slice.json
//     readback classes), committed into ONE of SIXTEEN internal "ACTIVE"
//     entries selected by ROUTE_ENTRY_SELECT.ENTRY only on an accepted
//     VALIDATE_COMMIT pulse. ENTRY_SELECT is dual-purpose (REG-002's own
//     text: "Selects route entry 0-15 for staging/readback") -- it ALSO
//     selects which active entry ROUTE_ACTIVE_*/ROUTE_ENTRY_STATUS/
//     ROUTE_ACTIVE_CONTROL read back, both handled generically below via a
//     single plain array-index mux (entry_select, no indexed_registers
//     reggen.py machinery needed here -- that v5 mechanism is for RTL-001
//     holding N independent STORED values; the sixteen ACTIVE entries are
//     RTL-021's own internal state, not RTL-001's).
//
//  2. ARCH-RTL021-001 "COMMIT REPLACES ALL SIXTEEN ENTRIES ATOMICALLY" vs.
//     REG-1424's OWN LITERAL PER-ENTRY VALIDATE_COMMIT/ENTRY_SELECT
//     mechanism (which can only ever commit ONE entry per pulse) is a real,
//     confirmed ARCH-002-internal tension, not invented: REG-002 gives no
//     "commit all sixteen simultaneously" register mechanism anywhere.
//     Reconciled (disclosed, not silently picked) by reading "atomically"
//     as "each single-entry commit is itself all-or-nothing" (no torn
//     partial-field update), and treating the genuinely load-bearing half
//     of ARCH-RTL021-001 as its OWN explicit epoch-capture sentence: "an
//     in-flight record completes under the configuration epoch captured at
//     ingress acceptance." Implemented literally: at the exact cycle an
//     ingress record is accepted, its FULL routing decision (which
//     destinations, via which entries, with which DROP_ON_FULL policy) is
//     resolved COMBINATIONALLY against the CURRENT active table and
//     REGISTERED once (slot_pending_mask_q/slot_drop_on_full_q/
//     slot_winning_entry_q below) -- never re-evaluated again for that
//     record, even if a LATER VALIDATE_COMMIT changes the active table
//     while this record is still being replicated to its destinations.
//     This is VP-BUS-009's own named highest-risk case and has its own
//     dedicated testbench test, not incidental commit-timing coverage.
//
//  3. COMMIT VALIDATION CODES (ARCH-ROUTE-007): 02 invalid source (staged
//     SOURCE_ID > 4), 03 zero/invalid destination mask (staged DEST_MASK==0
//     while ENABLE=1 -- REG-002's own "0x01-0x1F when enabled" legal-range
//     text; DEST_MASK cannot structurally exceed 0x1F, being a real 5-bit
//     field), 04 unauthorized pair (ANY set DEST_MASK bit fails the fixed
//     5x5 matrix for the staged SOURCE_ID, checked only while ENABLE=1),
//     05 undefined type bit (ANY TYPE_MASK bit outside 0-4 set, OR
//     TYPE_MASK==0 while ENABLE=1 -- REG-002's own "nonzero when enabled"
//     text folded into the SAME code, disclosed, since no separate code
//     exists for "zero type mask") are all REAL and reachable, all checked
//     only while the staged ENABLE bit is 1 (a disabled staged entry
//     commits unconditionally, matching "Updates only this stored field;
//     staged fields do not alter active state until commit" plus the
//     entry's own ENABLE simply landing as 0). Three codes are
//     STRUCTURALLY UNREACHABLE here, disclosed rather than silently never
//     tested: 01 invalid entry (ENTRY_SELECT is a real 4-bit field,
//     0-15 all legal -- there is no encoding of "invalid entry" to detect),
//     06 reserved flag/field (every ROUTE_STAGE_* register's own RSV0 bits
//     are already rejected whole-write by RTL-001's generic bus-decode
//     layer before ever reaching control_i -- the same "generic protection
//     already enforced upstream" reasoning as every other module's own
//     disclosed-unreachable reserved-bit codes), 08 busy (this module's own
//     real design commits in a single CORE_CLK cycle, pure internal
//     register update, with no shared-buffer or multi-cycle dependency --
//     there is no busy state a commit could ever observe). 07 duplicate
//     conflict is DISCLOSED-AMBIGUOUS, not unreachable-by-construction and
//     not implemented: REG-002 names the code but gives no definition of
//     what "duplicate" means at COMMIT time (ARCH-ROUTE-003's own
//     "duplicate selections... produce one copy" text is an INGRESS-TIME
//     replication rule, not a commit-time validation rule) -- inventing a
//     specific definition (e.g. "identical SOURCE_ID+TYPE_MASK+FILTER vs.
//     an already-active entry with overlapping DEST_MASK") would be
//     inventing behavior this module has no authority to impose
//     unilaterally; this code is therefore never generated, logged in
//     OPEN_ISSUES.md as a genuine, open architecture ambiguity.
//     VALIDATE_COMMIT and DISABLE_ENTRY asserted in the SAME cycle (REG-1424's
//     own "undefined encoding... rejects with no command pulse" text) is a
//     REAL case this module must itself defensively reject: RTL-001's
//     generic WO-CMD pulse-capture forwards wdata_i VERBATIM with no
//     per-encoding exactly-one-hot validation (the same already-disclosed,
//     pre-existing RTL-001 gap named in its own header, "no per-field
//     legal-value range checks"), so both pulses WOULD otherwise arrive
//     simultaneously; this module checks for exactly that collision and
//     executes NEITHER command when it occurs (no state change, no LAST_ERROR
//     update -- "no command pulse" taken literally).
//
//  4. STATUS BITS, DISCLOSED INTERPRETATIONS (REG-002 gives per-field
//     behavior text but not always a unique internal trigger):
//     ROUTE_STATUS.ACTIVE: this register's own behavior text groups it with
//     "commit/runtime errors," and its name is otherwise generic -- read as
//     a direct mirror of the global ROUTE_CONTROL.ENABLE bit (this engine
//     is "active" exactly when routing itself is enabled), not some
//     separate derived busy/in-flight indicator.
//     ROUTE_STATUS.LAST_ERROR[15:8]: ONE shared 8-bit field for BOTH
//     ARCH-ROUTE-007 commit codes (00-08) and ARCH-ROUTE-008 runtime codes
//     (10-15) -- the two code SPACES are disjoint and tested independently
//     (own dedicated testbench cases), but they share one storage field,
//     overwritten by whichever class of event happens most recently; this
//     is a storage-sharing fact, not a conflation of the two spaces'
//     meaning.
//     ROUTE_STATUS.UNAUTHORIZED: fires ADDITIONALLY to COMMIT_REJECTED
//     specifically when the rejection reason was code 04, giving
//     finer-grained sticky evidence than COMMIT_REJECTED alone.
//     ROUTE_ENTRY_STATUS (selected by ENTRY_SELECT): VALID = this entry
//     index has been committed at least once (distinguishes a genuinely
//     populated entry from a virgin, never-committed one); ACTIVE = VALID
//     AND the entry's own current ENABLE bit is 1 (a convenience
//     "effectively active right now" flag, not literally redundant with
//     ROUTE_ACTIVE_CONTROL.ENABLE -- it is a derived AND of two other real
//     facts, same class of convenience status bit used project-wide);
//     ERROR (W1C) = sticky evidence that the LAST VALIDATE_COMMIT pulse
//     WHILE this entry index was selected was rejected (per-entry
//     granularity alongside the global COMMIT_REJECTED bit);
//     FORWARDED_COUNT = saturating count of destination copies
//     successfully written attributable to this entry (see finding 6 for
//     the entry-attribution tie-break).
//
//  5. MESSAGE ACCEPTANCE AND MALFORMED CLASSIFICATION (ARCH-ROUTE-001
//     "Accepted messages are range-checked before the slot becomes valid";
//     ARCH-ROUTE-008 "10 malformed message"): source_ready_o[s] is
//     asserted purely on slot-space availability (empty slot, routing
//     enabled, no content peek -- avoiding a same-cycle combinational
//     dependency on the record's own content, the same handshake
//     convention every prior Databus module uses for its own route-input
//     path). The record is then classified the SAME cycle it is accepted:
//     malformed = message_type not one of {0x01,0x02,0x04,0x08,0x10} (SS11.1),
//     OR payload_length > 8, OR flags[7]!=0 (SS11.1's own "reserved zero"),
//     OR the record's own declared source_id field does not equal this
//     slot's own fixed index (ARCH-MSG-001..005's own fixed per-slot ID,
//     self-consistency check -- a producing module asserting the wrong
//     source_id for its own ingress slot is itself a malformed condition,
//     not silently trusted). A malformed record, and a well-formed record
//     that resolves to ZERO selected destinations (no match, or a filter-
//     mismatch-only near-miss), are BOTH disclosed as never occupying the
//     shared ingress-staging segment at all (ARCH-BUF-009) -- no
//     destination will ever need to read either back, so writing either
//     into the shared buffer would be pure wasted bandwidth; only a record
//     with at least one real selected destination copy ever becomes
//     "slot_valid" (buffer-backed). ARCH-DIAG-015's own "ingress-slot
//     losses by source" is incremented for ALL THREE zero-destination
//     outcomes (malformed, no-match, filter-mismatch-only) -- each is
//     equally a record this source's slot accepted but that was never
//     forwarded anywhere, which is exactly what "loss" means.
//
//  6. ROUTE RESOLUTION AND ENTRY-ORDER TIE-BREAK (ARCH-ROUTE-003): for the
//     record just accepted into slot s, every ACTIVE entry e=0..15 (entry
//     order, ascending) is evaluated; entry e "selects" destination d when
//     entry_enable_q[e] && entry_source_id_q[e]==s && the record's own
//     message_type bit is set in entry_type_mask_q[e] && (metadata &
//     filter_mask)==(filter_value & filter_mask) && entry_dest_mask_q[e][d].
//     The fixed 5x5 matrix is NOT re-checked at resolution time -- commit-
//     time validation (finding 3, code 04) already guarantees every ACTIVE
//     entry's own DEST_MASK bits are authorized for its own SOURCE_ID, so a
//     runtime re-check would be pure redundant logic, not a safety net
//     (there is no path for an active entry's dest_mask to ever hold an
//     unauthorized bit). "Duplicate selections of the same destination
//     produce one copy" (ARCH-ROUTE-003): for each destination d, the
//     LOWEST-INDEXED matching entry wins (first-match, matching the
//     document's own "evaluated in entry order" framing) -- that entry's
//     own DROP_ON_FULL policy is the one captured for this (ingress,
//     destination) copy, and that entry is the one credited in
//     FORWARDED_COUNT once the copy is actually written (finding 4). This
//     tie-break is a disclosed choice: REG-002/ARCH-002 do not say WHICH
//     matching entry "owns" a duplicate-selected destination's policy/
//     credit, only that exactly one copy results.
//
//  7. DESTINATION QUEUES, ROUND-ROBIN, AND THE DROP_ON_FULL/BACKPRESSURE
//     SPLIT (ARCH-ROUTE-004/005/006 -- VP-BUS-009's second named risk: no
//     head-of-line blocking). Per destination d, each CORE_CLK cycle, a
//     combinational priority scan starts just after dest_rr_ptr_q[d] and
//     walks all five ingress indices in rotation order; for the FIRST
//     ingress index i found with slot_pending_mask_q[i][d] set, the scan
//     asks: does destination d currently have shared-buffer queue space?
//     If yes, (i,d) is the WRITE candidate this cycle (drop_on_full is
//     irrelevant when space exists, matching ARCH-ROUTE-004's own "a
//     REQUIRED full destination backpressures" -- backpressure/drop only
//     ever matter while genuinely full). If no (full) and this specific
//     (i,d) copy's own captured DROP_ON_FULL is 1, (i,d) is the DROP
//     candidate this cycle (pure bookkeeping -- saturating count + sticky
//     evidence + pending-bit clear -- no shared-buffer transaction at all,
//     so it can resolve the SAME cycle regardless of whether the single
//     shared buf_req/rsp channel is simultaneously busy servicing a
//     DIFFERENT destination's write). If no (full) and this (i,d) copy's
//     own DROP_ON_FULL is 0, this specific candidate is NOT serviceable
//     this cycle -- the scan CONTINUES past it to the next eligible index
//     in rotation order, rather than fixating on the first-found index:
//     this is the one real design decision that prevents a required,
//     currently-blocked copy from one source from starving a SIMULTANEOUS
//     drop-eligible copy from a DIFFERENT source at the SAME, physically
//     full destination (the exact head-of-line-blocking failure mode
//     VP-BUS-009 calls out by name). A genuinely WRITE-serviceable
//     candidate across the five destinations is granted the single shared
//     buf_req/rsp channel via a fixed dest-index priority (0 highest) --
//     ARCH-ROUTE-006's own round-robin fairness requirement is about which
//     INGRESS SOURCE a given destination services next, not about which
//     DESTINATION gets the shared buffer first when several are
//     simultaneously write-ready; a disclosed, uncontested fixed order for
//     that orthogonal question, same class of choice as every prior
//     module's own fixed internal arbiter priority.
//
//  8. SHARED-BUFFER WORD SEQUENCING (12-word REPLICATE copy: 6-word READ
//     from the winning ingress slot's own staging segment, immediately
//     followed by a 6-word WRITE into the destination's own queue segment
//     at its current tail) uses the SAME word_idx_q 0-5 sequencing
//     technique RTL-019's own 6-word CAN entries already established
//     (wr_w_q[]/rd_w_q[] transient per-operation staging arrays -- RTLSTD-
//     MEM-002's own allowed "data captured before being committed"
//     exception, not a forbidden duplicate store of already-committed
//     data: these arrays hold a record only for the few cycles needed to
//     move it from one shared-buffer segment to another, never a
//     standing second copy). Each of the five destinations independently
//     maintains a continuously-refreshed 6-word head-snapshot cache
//     (dest_head_snap_q[]), refreshed via its own dedicated buffer-read
//     sequence exactly on the same "becomes non-empty" / "pop leaves
//     non-empty" triggers RTL-020's own UART_RX_DATA snapshot cache
//     already established -- dest_record_o presents this snapshot
//     directly, never a live mid-transfer partial word.
//
//  9. BUFFER ARBITER PRIORITY (ARCH-BUF-013, one outstanding request):
//     INGRESS-WRITE (a just-accepted, already-resolved record waiting to
//     land in its staging segment -- real-time, the producing module's own
//     queue is already committed to this record) > DEST-HEAD-REFRESH
//     (keeping each destination's continuously-maintained snapshot
//     current, same "refresh promptly" precedent as RTL-020's own
//     RX-HEAD-REFRESH tier) > REPLICATE (the 12-word copy itself, the
//     slowest and least time-critical of the three, fixed dest-index
//     order when multiple destinations are simultaneously write-ready,
//     finding 7). Each tier scans its own five candidates in fixed index
//     order 0-4 (not round-robin -- round-robin fairness is reserved for
//     finding 7's own per-destination ingress-source selection, the one
//     place ARCH-ROUTE-006 actually requires it).
//
// 10. GLOBAL ENABLE/OPERATIONAL GATING. ROUTE_CONTROL.ENABLE gates
//     source_ready_o directly (disabled routing accepts no new ingress
//     records at all); already-accepted, already-resolved in-flight
//     records continue draining to completion regardless (same "disable
//     does not abort in-flight work" convention as every prior module's
//     own TX serializer). effective_operational_enable_i additionally
//     gates BOTH ingress acceptance and destination replication (routing a
//     message to another module is this module's own "externally
//     effective action," the same severity class as another module's own
//     TX/transmit actuation) -- disclosed, since RTL-021 has no physical
//     pins of its own and ARCH-002 does not spell out what "externally
//     effective" means for a purely-internal routing engine.
//     module_enable_i gates only the generic READY/fault-contribution
//     status bit (project-wide convention); module_reset_i performs a
//     full functional reset of ALL of this module's own internal state,
//     INCLUDING the sixteen-entry active route table (treated as this
//     module's own configuration storage, analogous to CAN's own
//     bit-timing config being module_reset-cleared, not analogous to the
//     plain single-value control fields RTL-001 itself continues to drive
//     unconditionally through every other module's control_i).
//
// 11. EVENTS/IRQ (Appendix F.3, 8 real condition bits -- 0 commit
//     [successful VALIDATE_COMMIT], 1 reject [any rejected VALIDATE_COMMIT],
//     2 forward [one destination copy successfully written], 3 drop [one
//     DROP_ON_FULL drop], 4 filter mismatch [the 0x12 zero-destination
//     near-miss classification specifically -- plain "no matching route at
//     all" (0x11) has no dedicated condition bit and generates evidence via
//     LAST_ERROR/the per-source loss counter only, disclosed, same
//     "not every runtime fact has a condition bit" precedent as every
//     prior module's own non-primary causes], 5 unauthorized [specifically
//     a code-04 rejected commit, fires ALONGSIDE bit 1 for that one
//     sub-case, same pairing as the ROUTE_STATUS.UNAUTHORIZED/
//     COMMIT_REJECTED sticky pair], 6 shared-buffer error [any non-OK
//     buffer response, any of the three buffer-using operation classes],
//     7 event-slot overflow [generic, every module]). One shared pending
//     slot (project-wide generic shape); irq_req_o qualified against
//     irq_condition_enable_i[cause] for whichever cause is currently
//     latched. event_data: cause 0/5 carry {28'h0, entry_select} (which
//     entry); cause 1 carries {24'h0, last_error_code}; causes 2/3 carry
//     {26'h0, src_idx[2:0], dest_idx[2:0]}; cause 4 carries
//     {29'h0, src_idx[2:0]}; causes 6/7 carry the generic {24'h0,
//     cause_code} fallback (same convention as every prior module's own
//     non-primary causes). event_condition_enable_i/irq_condition_enable_i
//     tie to the same disclosed 64'h0 stub every other module uses (RTL-001
//     does not yet implement Appendix F.3 per-module CONDITION_MASK
//     storage) -- none of RTL-021's real event conditions can fire in this
//     integration yet, the same disclosed consequence as every prior
//     module's own finding.
//
// 12. ROUTE PORTS, SELF-REFERENTIAL IDS, AND THE RTL-001/RTL-022 FORWARD
//     REFERENCES. source_valid_i[4:0]/dest_valid_o[4:0] index EXACTLY by
//     the fixed ARCH-MSG-001..005 module ID (0 ARINC/RTL-017+018, 1 CAN/
//     RTL-019, 2 UART/RTL-020, 3 Host/RTL-001, 4 ULI/RTL-022), confirmed
//     directly from Appendix A's own real per-bit producer/consumer lists
//     for both ports (not assumed from the generic port width alone) --
//     RTL-019/020's own already-shipped self-referential CAN/UART wiring
//     (both source AND destination under one module ID, with no internal
//     cross-wiring inside those modules -- the real self-referential-ID
//     enforcement is the fixed matrix's own job, confirmed RTL-019/020's
//     own header comments already state this correctly) needed no change
//     here: RTL-021 just presents 5 ordinary, independent source/dest
//     channels and lets the matrix (row CAN/col CAN = 0, row UART/col
//     UART = 0) do the real enforcement. RTL-001's own route_tx_msg_*/
//     route_rx_msg_* ports (index 3, ARCH-002 Appendix A's own real RTL-001
//     row) are a REAL, CONFIRMED GAP -- these ports did not exist on
//     dfc_rtl001.sv at all before this session (grepped and confirmed
//     absent) -- added this session with a permanent RTLSTD-MOD-009
//     disclosed-stub tie (REG-002 defines no register-level mechanism for
//     the host to drive a host-originated routed message at all, so there
//     is no real content to wire these ports to yet; a genuine, open gap,
//     not a forward reference that will resolve soon). RTL-022 (ULI,
//     index 4) IS a genuine forward reference, same structural shape as
//     RTL-017/018's own earlier forward references to RTL-021 before it
//     existed -- tied off identically (disclosed stub: source_valid_i[4]=0,
//     dest_ready_i[4]=0, source_record_i[4]/dest ignored) but expected to
//     resolve soon, per this session's own task briefing, since RTL-022 is
//     explicitly planned as a near-term module, not a permanent exclusion.
//
// 13. FAULT. DISCLOSED CHOICE, same reasoning as every prior Databus
//     module's own finding: routing/queue errors (drops, rejected commits,
//     shared-buffer errors) are ordinary operational conditions already
//     visible via their own sticky bits and counters, not systemic faults
//     -- fault_req_o is tied to a disclosed, permanently-0 stub.
// ============================================================================

module dfc_rtl021 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,              // RTL-002.module_reset_o[20]

  input  logic [dfc_types_pkg::DFC_RTL021_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL021_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,            // RTL-003.irq_source_i[7]
  output logic         fault_req_o,          // RTL-013.fault_source_i[14] (disclosed stub, finding 13)

  input  logic [4:0]   source_valid_i,       // [0]=RTL-017 ARINC,[1]=RTL-019 CAN,[2]=RTL-020 UART,[3]=RTL-001 Host,[4]=RTL-022 ULI
  output logic [4:0]   source_ready_o,
  input  logic [5*dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] source_record_i,

  output logic [4:0]   dest_valid_o,         // [0]=RTL-018 ARINC,[1]=RTL-019 CAN,[2]=RTL-020 UART,[3]=RTL-001 Host,[4]=RTL-022 ULI
  input  logic [4:0]   dest_ready_i,
  output logic [5*dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH-1:0] dest_record_o,

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,
  output logic         activity_o,           // disclosed stub at integration -- no legal activity_i slot (item 83/140 class, finding "master table")

  input  logic         module_enable_i,      // RTL-002.module_enable_o[20]
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
  // per-operating-state behavior specified for RTL-021 anywhere in the
  // -002 set -- a disclosed, genuinely-unused pair, same precedent as
  // every prior Databus module.
  logic unused_op_state_sink;
  assign unused_op_state_sink = (^operating_state_i) ^ observational_mode_i;

  localparam int unsigned NSRC = 5;
  localparam int unsigned NDST = 5;
  localparam int unsigned NENT = 16;
  localparam int unsigned RECW = dfc_types_pkg::DFC_MESSAGE_RECORD_WIDTH;

  // Client-relative shared-buffer layout (finding 8; absolute base
  // DFC_BUF_CLIENT4_BASE is added by dfc_rtl024.sv's own top-level
  // arbiter, same convention as every prior Databus module -- this module
  // only ever deals in client-relative offsets).
  localparam int unsigned INGRESS_BASE = 0;    // 5 x 6 words = 0..29  (ARCH-BUF-009)
  localparam int unsigned DEST_BASE    = 30;   // 5 x 4 x 6 words = 30..149 (ARCH-BUF-010)
  localparam int unsigned DEPTH        = 4;

  // Fixed 5x5 authorization matrix (ARCH-002 SS11.2), row=source, col=dest,
  // index order per Appendix A's own real per-bit lists (finding 12):
  // 0 ARINC, 1 CAN, 2 UART, 3 Host, 4 ULI.
  function automatic logic matrix_ok(input logic [2:0] src, input logic [2:0] dst);
    case (src)
      3'd0: matrix_ok = (dst == 3'd1) || (dst == 3'd2) || (dst == 3'd3);
      3'd1: matrix_ok = (dst == 3'd0) || (dst == 3'd2) || (dst == 3'd3);
      3'd2: matrix_ok = (dst == 3'd0) || (dst == 3'd1) || (dst == 3'd3);
      3'd3: matrix_ok = (dst == 3'd0) || (dst == 3'd1) || (dst == 3'd2) || (dst == 3'd4);
      3'd4: matrix_ok = (dst == 3'd3);
      default: matrix_ok = 1'b0;
    endcase
  endfunction

  // ==========================================================================
  // Shared-buffer response-code check (CODE_OK=2'b00 convention, same as
  // every prior Databus module).
  // ==========================================================================
  wire [1:0]  rsp_code = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__CODE_HI:dfc_types_pkg::DFC_BUFFER_RSP__CODE_LO];
  wire        rsp_ok   = (rsp_code == 2'b00);
  wire [31:0] rsp_data = buf_rsp_i[dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_HI:dfc_types_pkg::DFC_BUFFER_RSP__READ_DATA_LO];

  // ==========================================================================
  // Buffer arbiter state (finding 9) -- declared early, before anything
  // else in this module that reads op_q/phase_q/word_idx_q/op_src_q/
  // op_dst_q (the destination-queue bookkeeping, the slot-release race
  // fix, and the event logic all need to see these; Icarus requires a
  // plain module-scope declaration to textually precede every one of its
  // uses, the same declare-before-use discipline this project's own
  // RTL-019/020 header notes already document hitting for procedural
  // blocks, confirmed here to also apply to plain continuous-assignment/
  // generate-block reads, not only always_ff bodies).
  // ==========================================================================
  localparam logic [2:0] OP_NONE           = 3'd0;
  localparam logic [2:0] OP_INGRESS_WRITE  = 3'd1;
  localparam logic [2:0] OP_HEAD_REFRESH   = 3'd2;
  localparam logic [2:0] OP_REPLICATE_READ = 3'd3;
  localparam logic [2:0] OP_REPLICATE_WRITE= 3'd4;
  localparam logic [1:0] PH_IDLE = 2'd0;
  localparam logic [1:0] PH_REQ  = 2'd1;
  localparam logic [1:0] PH_WAIT = 2'd2;

  logic [2:0] op_q;
  logic [1:0] phase_q;
  logic [2:0] word_idx_q;
  logic [2:0] op_src_q, op_dst_q;
  logic [31:0] wr_w_q [0:5];
  logic [31:0] rd_w_q [0:5];

  wire read_word_ok  = (phase_q == PH_WAIT) && buf_rsp_valid_i && rsp_ok;
  wire read_word_err = (phase_q == PH_WAIT) && buf_rsp_valid_i && !rsp_ok;

  // ==========================================================================
  // Control-field unpack.
  // ==========================================================================
  wire ctl_enable       = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_CONTROL__ENABLE_HI];
  wire ctl_event_enable = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_CONTROL__EVENT_ENABLE_HI];
  wire ctl_irq_enable   = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_CONTROL__IRQ_ENABLE_HI];

  wire ctl_clr_commit_complete  = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STATUS__COMMIT_COMPLETE_HI];
  wire ctl_clr_commit_rejected  = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STATUS__COMMIT_REJECTED_HI];
  wire ctl_clr_dest_overflow    = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STATUS__DEST_OVERFLOW_HI];
  wire ctl_clr_unauthorized     = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STATUS__UNAUTHORIZED_HI];
  wire ctl_clr_entry_error      = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_ENTRY_STATUS__ERROR_HI];
  wire ctl_clr_event_overflow   = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__RTL021_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  wire [3:0]  entry_select = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_ENTRY_SELECT__ENTRY_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_ENTRY_SELECT__ENTRY_LO];
  wire [7:0]  staged_source_id    = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_SOURCE__SOURCE_ID_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_SOURCE__SOURCE_ID_LO];
  wire [4:0]  staged_dest_mask    = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_DEST__DEST_MASK_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_DEST__DEST_MASK_LO];
  wire [31:0] staged_type_mask    = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_TYPE_MASK__TYPE_MASK_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_TYPE_MASK__TYPE_MASK_LO];
  wire [31:0] staged_filter_value = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_FILTER_VALUE__FILTER_VALUE_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_FILTER_VALUE__FILTER_VALUE_LO];
  wire [31:0] staged_filter_mask  = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_FILTER_MASK__FILTER_MASK_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_FILTER_MASK__FILTER_MASK_LO];
  wire        staged_enable       = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_CONTROL__ENABLE_HI];
  wire        staged_drop_on_full = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_STAGE_CONTROL__DROP_ON_FULL_HI];

  wire validate_commit_pulse = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_VALIDATE_COMMIT__VALIDATE_COMMIT_HI];
  wire disable_entry_pulse   = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_VALIDATE_COMMIT__DISABLE_ENTRY_HI];
  // Finding 3: both pulses the same cycle is REG-1424's own "undefined
  // encoding" -- neither command executes.
  wire do_validate_commit = validate_commit_pulse && !disable_entry_pulse;
  wire do_disable_entry   = disable_entry_pulse   && !validate_commit_pulse;

  wire [4:0] ctl_ingress_clear = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_INGRESS_LOSS_COUNT__CLEAR_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_INGRESS_LOSS_COUNT__CLEAR_LO];
  wire [4:0] ctl_dest_clear    = control_i[dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_DESTINATION_DROP_COUNT__CLEAR_HI:dfc_types_pkg::DFC_RTL021_CONTROL__ROUTE_DESTINATION_DROP_COUNT__CLEAR_LO];

  // ==========================================================================
  // Route table (finding 1): sixteen active entries.
  // ==========================================================================
  logic        entry_enable_q       [0:NENT-1];
  logic [7:0]  entry_source_id_q    [0:NENT-1];
  logic [4:0]  entry_dest_mask_q    [0:NENT-1];
  logic [31:0] entry_type_mask_q    [0:NENT-1];
  logic [31:0] entry_filter_value_q [0:NENT-1];
  logic [31:0] entry_filter_mask_q  [0:NENT-1];
  logic        entry_drop_on_full_q [0:NENT-1];
  logic        entry_valid_q        [0:NENT-1];
  logic        entry_error_q        [0:NENT-1];
  logic [15:0] entry_forwarded_count_q [0:NENT-1];

  // ==========================================================================
  // Commit-time combinational validation (finding 3).
  // ==========================================================================
  logic [2:0] commit_dbit;
  logic       commit_dest_auth_ok;
  integer     cv_d;
  always_comb begin
    commit_dest_auth_ok = 1'b1;
    for (cv_d = 0; cv_d < NDST; cv_d = cv_d + 1) begin
      commit_dbit = cv_d[2:0];
      if (staged_dest_mask[cv_d] && !matrix_ok(staged_source_id[2:0], commit_dbit))
        commit_dest_auth_ok = 1'b0;
    end
  end
  wire commit_type_ok = !staged_enable ||
                        ((staged_type_mask[31:5] == 27'h0) && (staged_type_mask[4:0] != 5'h0));
  wire commit_src_ok   = (staged_source_id <= 8'd4);
  wire commit_dest_ok  = !staged_enable || (staged_dest_mask != 5'h0);
  wire commit_auth_ok  = !staged_enable || commit_dest_auth_ok;

  // Priority order matches ARCH-ROUTE-007's own code listing (02 before 03
  // before 04 before 05) -- a disclosed, uncontested first-failure order,
  // same class of choice as every other module's own validation priority.
  wire [7:0] commit_code = !commit_src_ok   ? 8'h02 :
                           !commit_dest_ok  ? 8'h03 :
                           !commit_auth_ok  ? 8'h04 :
                           !commit_type_ok  ? 8'h05 : 8'h00;
  wire commit_ok = (commit_code == 8'h00);

  // ==========================================================================
  // Global status stickies/counters.
  // ==========================================================================
  logic        commit_complete_sticky_q, commit_rejected_sticky_q;
  logic        dest_overflow_sticky_q, unauthorized_sticky_q;
  logic [7:0]  last_error_q;
  logic [15:0] global_drop_count_q;
  logic        event_overflow_sticky_q;
  logic [15:0] event_drop_count_q;

  // ==========================================================================
  // Per-source ingress slots (finding 5/6).
  // ==========================================================================
  logic              slot_valid_q         [0:NSRC-1];
  logic              slot_write_pending_q [0:NSRC-1];
  logic [RECW-1:0]   slot_capture_q       [0:NSRC-1];
  logic              slot_pending_mask_q  [0:NSRC-1][0:NDST-1];
  logic              slot_drop_on_full_q  [0:NSRC-1][0:NDST-1];
  logic [3:0]        slot_winning_entry_q [0:NSRC-1][0:NDST-1];
  logic [15:0]        ingress_loss_count_q [0:NSRC-1];

  // ==========================================================================
  // Per-destination queues (finding 7/8).
  // ==========================================================================
  logic [1:0]       dest_head_q   [0:NDST-1];
  logic [1:0]       dest_tail_q   [0:NDST-1];
  logic [2:0]       dest_count_q  [0:NDST-1];
  logic [2:0]       dest_rr_ptr_q [0:NDST-1];
  logic             dest_head_valid_q [0:NDST-1];
  logic [RECW-1:0]  dest_head_snap_q  [0:NDST-1];
  logic             dest_head_refresh_pending_q [0:NDST-1];
  logic [15:0]      dest_drop_count_q [0:NDST-1];

  wire [NDST-1:0] dest_queue_full;
  wire [NDST-1:0] dest_queue_empty;
  wire [NDST-1:0] dq_pop_fire;
  wire [NDST-1:0] dq_write_fire;
  genvar gd;
  generate
    for (gd = 0; gd < NDST; gd = gd + 1) begin : g_dest_flags
      assign dest_queue_full[gd]  = (dest_count_q[gd] == DEPTH[2:0]);
      assign dest_queue_empty[gd] = (dest_count_q[gd] == 3'd0);
      assign dq_pop_fire[gd]      = dest_ready_i[gd] && dest_valid_o[gd];
    end
  endgenerate

  // ==========================================================================
  // Per-destination round-robin candidate scan (finding 7): for each
  // destination, find the first serviceable ingress candidate starting
  // just after dest_rr_ptr_q, continuing past a required-but-currently-
  // blocked candidate instead of fixating on it (the real no-head-of-line-
  // blocking mechanism).
  // ==========================================================================
  logic [NDST-1:0] dest_cand_found;
  logic [NDST-1:0] dest_cand_is_drop;
  logic [2:0]      dest_cand_src [0:NDST-1];
  integer d, k, cand;
  always_comb begin
    for (d = 0; d < NDST; d = d + 1) begin
      dest_cand_found[d]   = 1'b0;
      dest_cand_is_drop[d] = 1'b0;
      dest_cand_src[d]     = 3'd0;
      for (k = 0; k < NSRC; k = k + 1) begin
        cand = (dest_rr_ptr_q[d] + 1 + k) % NSRC;
        if (!dest_cand_found[d] && slot_valid_q[cand] && slot_pending_mask_q[cand][d]) begin
          if (!dest_queue_full[d]) begin
            dest_cand_found[d]   = 1'b1;
            dest_cand_is_drop[d] = 1'b0;
            dest_cand_src[d]     = cand[2:0];
          end else if (slot_drop_on_full_q[cand][d]) begin
            dest_cand_found[d]   = 1'b1;
            dest_cand_is_drop[d] = 1'b1;
            dest_cand_src[d]     = cand[2:0];
          end
          // else: required + currently full -- keep scanning (no HOL block)
        end
      end
    end
  end

  // Slot-release race fix: a drop at one destination and a replicate-write
  // completion at ANOTHER destination for the SAME source can both clear
  // their own pending bit in the SAME cycle -- if each path independently
  // decided "release the slot" from the STALE (pre-this-cycle) pending
  // mask, BOTH would see the other's bit still set and neither would ever
  // release it (a real simultaneous-last-two-clears race, found and fixed
  // during design review before this ever reached simulation). Computed
  // combinationally here, ONCE, accounting for every clear source that can
  // fire this same cycle, and applied as a single centralized assignment
  // in the always_ff below -- not decided independently in each clearing
  // path.
  wire replicate_write_complete = (phase_q == PH_WAIT) && read_word_ok &&
                                  (op_q == OP_REPLICATE_WRITE) && (word_idx_q == 3'd5);
  genvar gw;
  generate
    for (gw = 0; gw < NDST; gw = gw + 1) begin : g_dq_write_fire
      assign dq_write_fire[gw] = replicate_write_complete && (op_dst_q == gw[2:0]);
    end
  endgenerate
  logic clearing_this_cycle [0:NSRC-1][0:NDST-1];
  logic slot_will_be_empty  [0:NSRC-1];
  integer ce_s, ce_d;
  always_comb begin
    for (ce_s = 0; ce_s < NSRC; ce_s = ce_s + 1) begin
      slot_will_be_empty[ce_s] = 1'b1;
      for (ce_d = 0; ce_d < NDST; ce_d = ce_d + 1) begin
        clearing_this_cycle[ce_s][ce_d] =
            (dest_cand_found[ce_d] && dest_cand_is_drop[ce_d] && (dest_cand_src[ce_d] == ce_s[2:0])) ||
            (replicate_write_complete && (op_src_q == ce_s[2:0]) && (op_dst_q == ce_d[2:0]));
        if (slot_pending_mask_q[ce_s][ce_d] && !clearing_this_cycle[ce_s][ce_d])
          slot_will_be_empty[ce_s] = 1'b0;
      end
    end
  end

  // Count of simultaneous same-cycle drops across all five destinations
  // (used to correctly sum into the single shared global_drop_count_q
  // aggregate below, see that comment for why a naive per-destination +1
  // would under-count).
  logic [2:0] drop_count_this_cycle;
  always_comb begin
    drop_count_this_cycle = {2'b0, dest_cand_found[0] && dest_cand_is_drop[0]} +
                             {2'b0, dest_cand_found[1] && dest_cand_is_drop[1]} +
                             {2'b0, dest_cand_found[2] && dest_cand_is_drop[2]} +
                             {2'b0, dest_cand_found[3] && dest_cand_is_drop[3]} +
                             {2'b0, dest_cand_found[4] && dest_cand_is_drop[4]};
  end

  // Fixed dest-index priority (finding 7) for the single shared buf_req
  // channel among simultaneously write-ready destinations.
  logic       replicate_want;
  logic [2:0] replicate_dst, replicate_src;
  integer rd;
  always_comb begin
    replicate_want = 1'b0;
    replicate_dst  = 3'd0;
    replicate_src  = 3'd0;
    for (rd = NDST - 1; rd >= 0; rd = rd - 1) begin
      if (dest_cand_found[rd] && !dest_cand_is_drop[rd]) begin
        replicate_want = 1'b1;
        replicate_dst  = rd[2:0];
        replicate_src  = dest_cand_src[rd];
      end
    end
  end

  // ==========================================================================
  // Ingress accept + combinational route resolution (findings 5/6): run in
  // parallel for all five sources every cycle.
  // ==========================================================================
  wire [NSRC-1:0] slot_free = {
    !slot_valid_q[4] && !slot_write_pending_q[4],
    !slot_valid_q[3] && !slot_write_pending_q[3],
    !slot_valid_q[2] && !slot_write_pending_q[2],
    !slot_valid_q[1] && !slot_write_pending_q[1],
    !slot_valid_q[0] && !slot_write_pending_q[0]
  };
  // Finding 10, REFINED (found via a real whole-chip test, not by
  // inspection -- rtl024_skeleton_tb.sv's own real EFFECTIVE_OPERATIONAL_
  // ENABLE stays low for a real, legitimate reason this early in system
  // bring-up, OPEN_ISSUES.md item 98's own mandatory-init gate, and a
  // naive "gate ingress too" reading left RTL-017's own queue completely
  // undrainable for as long as that held, not merely slower): ingress
  // ACCEPTANCE is gated only by ROUTE_CONTROL.ENABLE, matching every
  // other module's own established "RX always accepts, only TX/outward
  // actuation is suppressed" convention (RTL-020's own effective_
  // operational_enable_i gates only its TX dequeue_start, never its own
  // RX path) -- accepting a message into this module's own internal
  // ingress slot has no effect OUTSIDE this module yet, so it is not
  // itself "externally effective action." Only REPLICATION (the actual
  // delivery of a copy to ANOTHER module, see replicate_want below) is
  // gated by effective_operational_enable_i.
  wire route_admit = ctl_enable;
  assign source_ready_o[0] = route_admit && slot_free[0];
  assign source_ready_o[1] = route_admit && slot_free[1];
  assign source_ready_o[2] = route_admit && slot_free[2];
  assign source_ready_o[3] = route_admit && slot_free[3];
  assign source_ready_o[4] = route_admit && slot_free[4];
  wire [NSRC-1:0] accept = source_valid_i & source_ready_o;

  logic [RECW-1:0] src_rec [0:NSRC-1];
  always_comb begin
    src_rec[0] = source_record_i[1*RECW-1 -: RECW];
    src_rec[1] = source_record_i[2*RECW-1 -: RECW];
    src_rec[2] = source_record_i[3*RECW-1 -: RECW];
    src_rec[3] = source_record_i[4*RECW-1 -: RECW];
    src_rec[4] = source_record_i[5*RECW-1 -: RECW];
  end

  logic [NSRC-1:0] rslv_malformed;
  logic [NSRC-1:0] rslv_filter_near_miss;
  logic [NSRC-1:0] rslv_any_selected;
  logic            rslv_selected_mask [0:NSRC-1][0:NDST-1];
  logic [3:0]      rslv_winning_entry [0:NSRC-1][0:NDST-1];
  logic            rslv_dest_claimed  [0:NSRC-1][0:NDST-1];

  integer rs, re, rdst;
  logic [7:0]  r_mtype;
  logic [3:0]  r_plen;
  logic [7:0]  r_flags;
  logic [7:0]  r_srcid;
  logic [31:0] r_meta;
  logic        r_type_bit_set;
  logic        r_filter_match;
  logic        r_entry_match_src_type;

  always_comb begin
    for (rs = 0; rs < NSRC; rs = rs + 1) begin
      r_mtype = src_rec[rs][dfc_types_pkg::DFC_MESSAGE_RECORD__MESSAGE_TYPE_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__MESSAGE_TYPE_LO];
      r_plen  = src_rec[rs][dfc_types_pkg::DFC_MESSAGE_RECORD__PAYLOAD_LENGTH_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__PAYLOAD_LENGTH_LO];
      r_flags = src_rec[rs][dfc_types_pkg::DFC_MESSAGE_RECORD__FLAGS_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__FLAGS_LO];
      r_srcid = src_rec[rs][dfc_types_pkg::DFC_MESSAGE_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__SOURCE_ID_LO];
      r_meta  = src_rec[rs][dfc_types_pkg::DFC_MESSAGE_RECORD__METADATA_HI:dfc_types_pkg::DFC_MESSAGE_RECORD__METADATA_LO];

      rslv_malformed[rs] = !(r_mtype == 8'h01 || r_mtype == 8'h02 || r_mtype == 8'h04 ||
                              r_mtype == 8'h08 || r_mtype == 8'h10) ||
                           (r_plen > 4'd8) || r_flags[7] || (r_srcid != rs[7:0]);

      rslv_filter_near_miss[rs] = 1'b0;
      for (rdst = 0; rdst < NDST; rdst = rdst + 1) begin
        rslv_selected_mask[rs][rdst] = 1'b0;
        rslv_winning_entry[rs][rdst] = 4'd0;
        rslv_dest_claimed[rs][rdst]  = 1'b0;
      end

      // The entry-scan runs unconditionally (not wrapped in an
      // `if (!rslv_malformed[rs])` around the whole `for`) -- a real,
      // confirmed Yosys synthesis issue, found via a real
      // `build_ecp5.ps1 -SynthOnly` run, not by inspection: a `for` loop
      // whose entire body (including its own loop-index variable's
      // assignment) is reachable only through an outer conditional made
      // Yosys's latch-inference check misread the loop index `re` itself
      // as a signal needing a latch ("ERROR: Latch inferred for signal
      // `re[3:0]`"), even though `re` is pure loop-unrolling scratch state
      // never read outside this process -- the same unconditional-`for`
      // shape every OTHER loop in this module's own always blocks
      // already uses without issue. Restructured so the `for` itself is
      // never conditionally entered; the malformed gate is folded into
      // `r_entry_match_src_type` instead (a malformed record's own
      // r_mtype is likely nonsensical anyway, but this makes the
      // "malformed selects nothing" guarantee explicit and independent
      // of that).
      for (re = 0; re < NENT; re = re + 1) begin
        r_type_bit_set = (r_mtype == 8'h01) ? entry_type_mask_q[re][0] :
                         (r_mtype == 8'h02) ? entry_type_mask_q[re][1] :
                         (r_mtype == 8'h04) ? entry_type_mask_q[re][2] :
                         (r_mtype == 8'h08) ? entry_type_mask_q[re][3] :
                                              entry_type_mask_q[re][4];
        r_filter_match = (r_meta & entry_filter_mask_q[re]) == (entry_filter_value_q[re] & entry_filter_mask_q[re]);
        r_entry_match_src_type = !rslv_malformed[rs] && entry_enable_q[re] &&
                                 (entry_source_id_q[re] == rs[7:0]) && r_type_bit_set;

        if (r_entry_match_src_type && entry_filter_mask_q[re] != 32'h0 && !r_filter_match)
          rslv_filter_near_miss[rs] = 1'b1;

        if (r_entry_match_src_type && r_filter_match) begin
          for (rdst = 0; rdst < NDST; rdst = rdst + 1) begin
            if (entry_dest_mask_q[re][rdst] && !rslv_dest_claimed[rs][rdst]) begin
              rslv_dest_claimed[rs][rdst]  = 1'b1;
              rslv_selected_mask[rs][rdst] = 1'b1;
              rslv_winning_entry[rs][rdst] = re[3:0];
            end
          end
        end
      end

      rslv_any_selected[rs] = rslv_selected_mask[rs][0] || rslv_selected_mask[rs][1] ||
                              rslv_selected_mask[rs][2] || rslv_selected_mask[rs][3] ||
                              rslv_selected_mask[rs][4];
    end
  end

  // ==========================================================================
  // Buffer arbiter: address/request assembly (state itself is declared
  // earlier in this file -- see that section's own comment).
  // ==========================================================================
  assign buf_req_valid_o = (phase_q == PH_REQ);
  assign buf_rsp_ready_o = (phase_q == PH_WAIT);

  wire req_is_write = (op_q == OP_INGRESS_WRITE) || (op_q == OP_REPLICATE_WRITE);
  wire [7:0] dst_entry_sel = (op_q == OP_HEAD_REFRESH) ? {6'h0, dest_head_q[op_dst_q]} : {6'h0, dest_tail_q[op_dst_q]};
  wire [7:0] req_offset =
      (op_q == OP_INGRESS_WRITE || op_q == OP_REPLICATE_READ) ?
          (INGRESS_BASE[7:0] + {5'h0, op_src_q} * 8'd6 + {5'h0, word_idx_q}) :
          (DEST_BASE[7:0] + {5'h0, op_dst_q} * 8'd24 + dst_entry_sel * 8'd6 + {5'h0, word_idx_q});

  assign buf_req_o = {
    wr_w_q[word_idx_q],         // [41:10] write_data
    req_is_write,               // [9] write
    1'b0, req_offset            // [8:0] word_offset (client-relative, 0-149)
  };

  // ==========================================================================
  // Main sequential block (ONE block, deliberately not split further --
  // same multi-driver-avoidance reasoning as RTL-019/020's own header
  // notes: route-table/slot/destination state is each legitimately touched
  // by more than one real event per cycle).
  // ==========================================================================
  integer ri, rj;
  logic [15:0] fwd_sat;
  logic [15:0] loss_sat;
  logic [15:0] drop_sat;
  logic [15:0] gdrop_sat;

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      op_q <= OP_NONE; phase_q <= PH_IDLE; word_idx_q <= 3'd0; op_src_q <= 3'd0; op_dst_q <= 3'd0;
      commit_complete_sticky_q <= 1'b0; commit_rejected_sticky_q <= 1'b0;
      dest_overflow_sticky_q <= 1'b0; unauthorized_sticky_q <= 1'b0;
      last_error_q <= 8'h00; global_drop_count_q <= 16'h0;
      event_overflow_sticky_q <= 1'b0; event_drop_count_q <= 16'h0;
      for (ri = 0; ri < NENT; ri = ri + 1) begin
        entry_enable_q[ri] <= 1'b0; entry_source_id_q[ri] <= 8'h0; entry_dest_mask_q[ri] <= 5'h0;
        entry_type_mask_q[ri] <= 32'h0; entry_filter_value_q[ri] <= 32'h0; entry_filter_mask_q[ri] <= 32'h0;
        entry_drop_on_full_q[ri] <= 1'b0; entry_valid_q[ri] <= 1'b0; entry_error_q[ri] <= 1'b0;
        entry_forwarded_count_q[ri] <= 16'h0;
      end
      for (ri = 0; ri < NSRC; ri = ri + 1) begin
        slot_valid_q[ri] <= 1'b0; slot_write_pending_q[ri] <= 1'b0; slot_capture_q[ri] <= '0;
        ingress_loss_count_q[ri] <= 16'h0;
        for (rj = 0; rj < NDST; rj = rj + 1) begin
          slot_pending_mask_q[ri][rj] <= 1'b0; slot_drop_on_full_q[ri][rj] <= 1'b0;
          slot_winning_entry_q[ri][rj] <= 4'h0;
        end
      end
      for (rj = 0; rj < NDST; rj = rj + 1) begin
        dest_head_q[rj] <= 2'd0; dest_tail_q[rj] <= 2'd0; dest_count_q[rj] <= 3'd0;
        dest_rr_ptr_q[rj] <= 3'd4; dest_head_valid_q[rj] <= 1'b0; dest_head_snap_q[rj] <= '0;
        dest_head_refresh_pending_q[rj] <= 1'b0; dest_drop_count_q[rj] <= 16'h0;
      end
    end else if (module_reset_i) begin
      // Finding 10: a full functional reset of this module's own internal
      // state, including the active route table (this module's own
      // configuration storage, not RTL-001's).
      op_q <= OP_NONE; phase_q <= PH_IDLE;
      commit_complete_sticky_q <= 1'b0; commit_rejected_sticky_q <= 1'b0;
      dest_overflow_sticky_q <= 1'b0; unauthorized_sticky_q <= 1'b0;
      event_overflow_sticky_q <= 1'b0;
      for (ri = 0; ri < NENT; ri = ri + 1) begin
        entry_enable_q[ri] <= 1'b0; entry_valid_q[ri] <= 1'b0; entry_error_q[ri] <= 1'b0;
      end
      for (ri = 0; ri < NSRC; ri = ri + 1) begin
        slot_valid_q[ri] <= 1'b0; slot_write_pending_q[ri] <= 1'b0;
        for (rj = 0; rj < NDST; rj = rj + 1) slot_pending_mask_q[ri][rj] <= 1'b0;
      end
      for (rj = 0; rj < NDST; rj = rj + 1) begin
        dest_head_q[rj] <= 2'd0; dest_tail_q[rj] <= 2'd0; dest_count_q[rj] <= 3'd0;
        dest_rr_ptr_q[rj] <= 3'd4; dest_head_valid_q[rj] <= 1'b0;
        dest_head_refresh_pending_q[rj] <= 1'b0;
      end
    end else begin
      // ---- COUNTER16-CLR per-index clears (already edge-detected pulses
      // from reggen.py -- no further edge detection needed here) ----
      for (ri = 0; ri < NSRC; ri = ri + 1)
        if (ctl_ingress_clear[ri]) ingress_loss_count_q[ri] <= 16'h0;
      for (rj = 0; rj < NDST; rj = rj + 1)
        if (ctl_dest_clear[rj]) dest_drop_count_q[rj] <= 16'h0;

      // ---- sticky W1C clears (new evidence dominates, project-wide precedent) ----
      if (ctl_clr_commit_complete) commit_complete_sticky_q <= 1'b0;
      if (ctl_clr_commit_rejected) commit_rejected_sticky_q <= 1'b0;
      if (ctl_clr_dest_overflow)   dest_overflow_sticky_q   <= 1'b0;
      if (ctl_clr_unauthorized)    unauthorized_sticky_q    <= 1'b0;
      if (ctl_clr_entry_error)     entry_error_q[entry_select] <= 1'b0;
      if (ctl_clr_event_overflow)  event_overflow_sticky_q  <= 1'b0;

      // ---- commit / disable-entry (finding 2/3) ----
      if (do_disable_entry) begin
        entry_enable_q[entry_select] <= 1'b0;
      end else if (do_validate_commit) begin
        if (commit_ok) begin
          entry_enable_q[entry_select]       <= staged_enable;
          entry_source_id_q[entry_select]    <= staged_source_id;
          entry_dest_mask_q[entry_select]    <= staged_dest_mask;
          entry_type_mask_q[entry_select]    <= staged_type_mask;
          entry_filter_value_q[entry_select] <= staged_filter_value;
          entry_filter_mask_q[entry_select]  <= staged_filter_mask;
          entry_drop_on_full_q[entry_select] <= staged_drop_on_full;
          entry_valid_q[entry_select]        <= 1'b1;
          commit_complete_sticky_q <= 1'b1;
          last_error_q <= 8'h00;
        end else begin
          entry_error_q[entry_select] <= 1'b1;
          commit_rejected_sticky_q <= 1'b1;
          if (commit_code == 8'h04) unauthorized_sticky_q <= 1'b1;
          last_error_q <= commit_code;
        end
      end

      // ---- ingress accept + resolution (findings 5/6) ----
      for (ri = 0; ri < NSRC; ri = ri + 1) begin
        if (accept[ri]) begin
          if (rslv_any_selected[ri]) begin
            slot_valid_q[ri]         <= 1'b1;
            slot_write_pending_q[ri] <= 1'b1;
            slot_capture_q[ri]       <= src_rec[ri];
            for (rj = 0; rj < NDST; rj = rj + 1) begin
              slot_pending_mask_q[ri][rj]  <= rslv_selected_mask[ri][rj];
              slot_winning_entry_q[ri][rj] <= rslv_winning_entry[ri][rj];
              slot_drop_on_full_q[ri][rj]  <= entry_drop_on_full_q[rslv_winning_entry[ri][rj]];
            end
          end else begin
            // malformed, no-match, or filter-mismatch-only: never occupies
            // the shared ingress-staging segment (finding 5).
            loss_sat = (ingress_loss_count_q[ri] == 16'hFFFF) ? ingress_loss_count_q[ri] : ingress_loss_count_q[ri] + 16'd1;
            ingress_loss_count_q[ri] <= loss_sat;
            if (rslv_malformed[ri]) begin
              last_error_q <= 8'h10;
            end else if (rslv_filter_near_miss[ri]) begin
              last_error_q <= 8'h12;
            end else begin
              last_error_q <= 8'h11;
            end
          end
        end
      end

      // ---- destination drops (finding 7, pure bookkeeping, no buffer
      // transaction -- can happen for multiple destinations the same
      // cycle, independent of whatever the buffer arbiter is doing).
      // global_drop_count_q is a SINGLE shared aggregate counter, so
      // several simultaneous same-cycle drops are summed combinationally
      // (drop_count_this_cycle) rather than each computing its own +1 off
      // the same stale pre-cycle value -- found and fixed during design
      // review before this reached simulation (the naive per-destination
      // "+1 off global_drop_count_q" would under-count whenever two or
      // more destinations drop in the identical cycle, since only the
      // textually-last non-blocking assignment survives). Each
      // destination's OWN independent dest_drop_count_q[] has no such
      // hazard (at most one drop per destination per cycle). ----
      for (rj = 0; rj < NDST; rj = rj + 1) begin
        if (dest_cand_found[rj] && dest_cand_is_drop[rj]) begin
          slot_pending_mask_q[dest_cand_src[rj]][rj] <= 1'b0;
          dest_rr_ptr_q[rj] <= dest_cand_src[rj];
          drop_sat = (dest_drop_count_q[rj] == 16'hFFFF) ? dest_drop_count_q[rj] : dest_drop_count_q[rj] + 16'd1;
          dest_drop_count_q[rj] <= drop_sat;
        end
      end
      if (drop_count_this_cycle != 3'd0) begin
        gdrop_sat = (global_drop_count_q > (16'hFFFF - {13'h0, drop_count_this_cycle})) ?
                    16'hFFFF : global_drop_count_q + {13'h0, drop_count_this_cycle};
        global_drop_count_q <= gdrop_sat;
        dest_overflow_sticky_q <= 1'b1;
        last_error_q <= 8'h13;
      end

      // ---- centralized slot release (race fix: see slot_will_be_empty's
      // own comment above -- a drop and a replicate-write-completion for
      // the SAME source can both clear their own pending bit in the same
      // cycle, so release is decided once here from the combinational
      // preview, never independently in either clearing path). ----
      for (ri = 0; ri < NSRC; ri = ri + 1)
        if (slot_valid_q[ri] && slot_will_be_empty[ri]) slot_valid_q[ri] <= 1'b0;

      // ---- buffer arbiter: INGRESS-WRITE > HEAD-REFRESH > REPLICATE (finding 9) ----
      case (phase_q)
        PH_IDLE: begin
          if (slot_write_pending_q[0]) begin
            op_q <= OP_INGRESS_WRITE; op_src_q <= 3'd0; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            for (rj = 0; rj < 6; rj = rj + 1) wr_w_q[rj] <= slot_capture_q[0][rj*32 +: 32];
          end else if (slot_write_pending_q[1]) begin
            op_q <= OP_INGRESS_WRITE; op_src_q <= 3'd1; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            for (rj = 0; rj < 6; rj = rj + 1) wr_w_q[rj] <= slot_capture_q[1][rj*32 +: 32];
          end else if (slot_write_pending_q[2]) begin
            op_q <= OP_INGRESS_WRITE; op_src_q <= 3'd2; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            for (rj = 0; rj < 6; rj = rj + 1) wr_w_q[rj] <= slot_capture_q[2][rj*32 +: 32];
          end else if (slot_write_pending_q[3]) begin
            op_q <= OP_INGRESS_WRITE; op_src_q <= 3'd3; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            for (rj = 0; rj < 6; rj = rj + 1) wr_w_q[rj] <= slot_capture_q[3][rj*32 +: 32];
          end else if (slot_write_pending_q[4]) begin
            op_q <= OP_INGRESS_WRITE; op_src_q <= 3'd4; word_idx_q <= 3'd0; phase_q <= PH_REQ;
            for (rj = 0; rj < 6; rj = rj + 1) wr_w_q[rj] <= slot_capture_q[4][rj*32 +: 32];
          end else if (dest_head_refresh_pending_q[0]) begin
            op_q <= OP_HEAD_REFRESH; op_dst_q <= 3'd0; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (dest_head_refresh_pending_q[1]) begin
            op_q <= OP_HEAD_REFRESH; op_dst_q <= 3'd1; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (dest_head_refresh_pending_q[2]) begin
            op_q <= OP_HEAD_REFRESH; op_dst_q <= 3'd2; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (dest_head_refresh_pending_q[3]) begin
            op_q <= OP_HEAD_REFRESH; op_dst_q <= 3'd3; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (dest_head_refresh_pending_q[4]) begin
            op_q <= OP_HEAD_REFRESH; op_dst_q <= 3'd4; word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end else if (replicate_want && effective_operational_enable_i) begin
            // Replication is the real "externally effective action"
            // (delivering a copy to ANOTHER module) -- gated here, not on
            // ingress acceptance (see route_admit's own comment above).
            // Drops (dest_cand_is_drop) are NOT gated: they are pure
            // internal bookkeeping with no external effect, handled
            // unconditionally in the same always_ff, same reasoning.
            op_q <= OP_REPLICATE_READ; op_src_q <= replicate_src; op_dst_q <= replicate_dst;
            word_idx_q <= 3'd0; phase_q <= PH_REQ;
          end
        end

        PH_REQ: begin
          if (buf_req_ready_i) phase_q <= PH_WAIT;
        end

        PH_WAIT: begin
          if (read_word_err) begin
            last_error_q <= 8'h14;
            // generic retry-free abort: same "leave state as it was"
            // treatment as RTL-020's own failed-HEAD-REFRESH path.
            op_q <= OP_NONE; phase_q <= PH_IDLE;
          end else if (read_word_ok) begin
            case (op_q)
              OP_INGRESS_WRITE: begin
                if (word_idx_q == 3'd5) begin
                  slot_write_pending_q[op_src_q] <= 1'b0;
                  op_q <= OP_NONE; phase_q <= PH_IDLE;
                end else begin
                  word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
                end
              end
              OP_HEAD_REFRESH: begin
                rd_w_q[word_idx_q] <= rsp_data;
                if (word_idx_q == 3'd5) begin
                  dest_head_snap_q[op_dst_q] <= {rsp_data, rd_w_q[4], rd_w_q[3], rd_w_q[2], rd_w_q[1], rd_w_q[0]};
                  // Guard against a stale/delayed refresh completing AFTER
                  // the queue has, in the meantime, become empty via an
                  // intervening pop (this read takes 6 real cycles; a pop
                  // can land anywhere in that window) -- found via
                  // simulation, not by inspection: an unconditional <=1
                  // here let a refresh that was queued while the queue
                  // still had one item complete AFTER that same item was
                  // already popped, re-asserting dest_valid_o with a
                  // second, stale/garbage snapshot of an entry that was
                  // never really written. dest_count_q[op_dst_q] is this
                  // exact cycle's own live count, already reflecting every
                  // write/pop that happened during this refresh's own
                  // multi-cycle read.
                  dest_head_valid_q[op_dst_q] <= (dest_count_q[op_dst_q] != 3'd0);
                  dest_head_refresh_pending_q[op_dst_q] <= 1'b0;
                  op_q <= OP_NONE; phase_q <= PH_IDLE;
                end else begin
                  word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
                end
              end
              OP_REPLICATE_READ: begin
                rd_w_q[word_idx_q] <= rsp_data;
                if (word_idx_q == 3'd5) begin
                  wr_w_q[0] <= rd_w_q[0]; wr_w_q[1] <= rd_w_q[1]; wr_w_q[2] <= rd_w_q[2];
                  wr_w_q[3] <= rd_w_q[3]; wr_w_q[4] <= rd_w_q[4]; wr_w_q[5] <= rsp_data;
                  op_q <= OP_REPLICATE_WRITE; word_idx_q <= 3'd0; phase_q <= PH_REQ;
                end else begin
                  word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
                end
              end
              default: begin // OP_REPLICATE_WRITE
                if (word_idx_q == 3'd5) begin
                  slot_pending_mask_q[op_src_q][op_dst_q] <= 1'b0;
                  dest_rr_ptr_q[op_dst_q] <= op_src_q;
                  fwd_sat = (entry_forwarded_count_q[slot_winning_entry_q[op_src_q][op_dst_q]] == 16'hFFFF) ?
                            entry_forwarded_count_q[slot_winning_entry_q[op_src_q][op_dst_q]] :
                            entry_forwarded_count_q[slot_winning_entry_q[op_src_q][op_dst_q]] + 16'd1;
                  entry_forwarded_count_q[slot_winning_entry_q[op_src_q][op_dst_q]] <= fwd_sat;
                  // dest_tail_q/dest_count_q/dest_head_valid_q/
                  // dest_head_refresh_pending_q are updated below, in the
                  // centralized per-destination queue-bookkeeping block --
                  // not here (see that block's own comment for why).
                  op_q <= OP_NONE; phase_q <= PH_IDLE;
                end else begin
                  word_idx_q <= word_idx_q + 3'd1; phase_q <= PH_REQ;
                end
              end
            endcase
          end
        end

        default: begin
          op_q <= OP_NONE; phase_q <= PH_IDLE;
        end
      endcase

      // ---- centralized per-destination queue bookkeeping (tail/head
      // pointers, count, head-valid, head-refresh-pending): a replicate-
      // write completion (advances tail, +1 count) and a host/route POP
      // (advances head, -1 count) are independent events that can both
      // fire for the SAME destination in the SAME cycle -- two separate
      // non-blocking assignments to the same dest_count_q[d] (one +1, one
      // -1) would only apply whichever is textually last, silently
      // dropping the other (a real simultaneous-write-and-pop race, found
      // and fixed during design review before this reached simulation,
      // same hazard CLASS as the global_drop_count_q fix above). Combined
      // into one case per destination instead. ----
      for (rj = 0; rj < NDST; rj = rj + 1) begin
        if (dq_write_fire[rj]) dest_tail_q[rj] <= dest_tail_q[rj] + 2'd1;
        if (dq_pop_fire[rj])   dest_head_q[rj] <= dest_head_q[rj] + 2'd1;
        case ({dq_write_fire[rj], dq_pop_fire[rj]})
          2'b10: begin // write only: queue grows by one
            dest_count_q[rj] <= dest_count_q[rj] + 3'd1;
            // Only REQUEST a refresh here (when the write landed into a
            // previously-empty queue) -- dest_head_valid_q is set ONLY by
            // OP_HEAD_REFRESH's own completion (see that case's own
            // comment), never pre-emptively here. Found via simulation,
            // not by inspection: an earlier version set dest_head_valid_q
            // <=1'b1 unconditionally in this same branch, asserting
            // dest_valid_o/dest_record_o a full real-buffer-read latency
            // BEFORE dest_head_snap_q actually held the real data -- a
            // genuine data hazard (the testbench's own duplicate-route
            // dedup check caught a consumer popping that premature, still-
            // stale snapshot).
            if (dest_count_q[rj] == 3'd0) dest_head_refresh_pending_q[rj] <= 1'b1;
          end
          2'b01: begin // pop only: queue shrinks by one
            dest_count_q[rj] <= dest_count_q[rj] - 3'd1;
            if (dest_count_q[rj] - 3'd1 == 3'd0) dest_head_valid_q[rj] <= 1'b0;
            else dest_head_refresh_pending_q[rj] <= 1'b1;
          end
          2'b11: begin // simultaneous write+pop: net count unchanged, but
                        // the head entry itself still genuinely changed
                        // (the popped entry is gone; the new head is
                        // whatever the just-completed write landed, if
                        // the queue held exactly one item, or the next
                        // already-queued entry otherwise) -- a fresh
                        // refresh is needed either way. dest_head_valid_q
                        // is left alone here (same reasoning as the write-
                        // only case above): OP_HEAD_REFRESH's own
                        // completion is the sole place that sets it.
            dest_head_refresh_pending_q[rj] <= 1'b1;
          end
          default: ; // neither fired this cycle
        endcase
      end
    end
  end

  // ==========================================================================
  // Destination route-output presentation (continuously-maintained head
  // snapshot, finding 8).
  // ==========================================================================
  assign dest_valid_o[0] = dest_head_valid_q[0];
  assign dest_valid_o[1] = dest_head_valid_q[1];
  assign dest_valid_o[2] = dest_head_valid_q[2];
  assign dest_valid_o[3] = dest_head_valid_q[3];
  assign dest_valid_o[4] = dest_head_valid_q[4];
  assign dest_record_o[1*RECW-1 -: RECW] = dest_head_snap_q[0];
  assign dest_record_o[2*RECW-1 -: RECW] = dest_head_snap_q[1];
  assign dest_record_o[3*RECW-1 -: RECW] = dest_head_snap_q[2];
  assign dest_record_o[4*RECW-1 -: RECW] = dest_head_snap_q[3];
  assign dest_record_o[5*RECW-1 -: RECW] = dest_head_snap_q[4];

  // ==========================================================================
  // Event/IRQ generation (finding 11).
  // ==========================================================================
  logic        evt_pending_q;
  logic [3:0]  evt_cause_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  wire         slot_free_evt = !evt_pending_q || evt_ready_i;

  wire cond_commit       = do_validate_commit && commit_ok  && event_condition_enable_i[0];
  wire cond_reject       = do_validate_commit && !commit_ok && event_condition_enable_i[1];
  wire cond_forward      = (phase_q == PH_WAIT) && read_word_ok && (op_q == OP_REPLICATE_WRITE) &&
                            (word_idx_q == 3'd5) && event_condition_enable_i[2];
  // Reports the lowest-indexed destination's own drop evidence when
  // several destinations drop in the same cycle (disclosed simplification
  // -- one shared event payload, same "fallback to generic" convention
  // every prior module already uses when multiple causes compete).
  logic       any_drop_this_cycle;
  logic [2:0] drop_report_dst, drop_report_src;
  integer dr;
  always_comb begin
    any_drop_this_cycle = 1'b0;
    drop_report_dst = 3'd0;
    drop_report_src = 3'd0;
    for (dr = NDST - 1; dr >= 0; dr = dr - 1) begin
      if (dest_cand_found[dr] && dest_cand_is_drop[dr]) begin
        any_drop_this_cycle = 1'b1;
        drop_report_dst = dr[2:0];
        drop_report_src = dest_cand_src[dr];
      end
    end
  end
  wire cond_drop = any_drop_this_cycle && event_condition_enable_i[3];
  logic       any_filter_mismatch_this_cycle;
  logic [2:0] filter_mismatch_report_src;
  integer fm;
  always_comb begin
    any_filter_mismatch_this_cycle = 1'b0;
    filter_mismatch_report_src = 3'd0;
    for (fm = NSRC - 1; fm >= 0; fm = fm - 1) begin
      if (accept[fm] && !rslv_any_selected[fm] && rslv_filter_near_miss[fm]) begin
        any_filter_mismatch_this_cycle = 1'b1;
        filter_mismatch_report_src = fm[2:0];
      end
    end
  end
  wire cond_filter_mismatch = any_filter_mismatch_this_cycle && event_condition_enable_i[4];
  wire cond_unauthorized = do_validate_commit && !commit_ok && (commit_code == 8'h04) && event_condition_enable_i[5];
  wire cond_buf_error    = read_word_err && event_condition_enable_i[6];
  wire any_cond = ctl_event_enable &&
                  (cond_commit || cond_reject || cond_forward || cond_drop ||
                   cond_filter_mismatch || cond_unauthorized || cond_buf_error);

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      evt_pending_q <= 1'b0; evt_cause_q <= 4'd0; evt_record_q <= '0;
    end else if (module_reset_i) begin
      evt_pending_q <= 1'b0;
    end else begin
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;
      if (any_cond) begin
        if (slot_free_evt) begin
          evt_pending_q <= 1'b1;
          evt_cause_q <= cond_commit  ? 4'd0 :
                         cond_reject  ? 4'd1 :
                         cond_forward ? 4'd2 :
                         cond_drop    ? 4'd3 :
                         cond_filter_mismatch ? 4'd4 :
                         cond_unauthorized    ? 4'd5 :
                         cond_buf_error       ? 4'd6 : 4'd7;
          evt_record_q <= {
            cond_commit || cond_unauthorized ? {28'h0, entry_select} :
            cond_reject                      ? {24'h0, last_error_q} :
            cond_forward                     ? {26'h0, op_src_q, op_dst_q} :
            cond_drop                        ? {26'h0, drop_report_src, drop_report_dst} :
            cond_filter_mismatch             ? {29'h0, filter_mismatch_report_src} :
                                                {24'h0, (cond_buf_error ? 8'd6 : 8'd7)},
            8'h00,          // [95:88] flags
            8'd20,          // [87:80] source_id = evt bus slot 20
            16'h0024,       // [79:64] event_id (C.7 0x0024)
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
  assign fault_req_o  = 1'b0; // disclosed stub, finding 13

  // ==========================================================================
  // Activity (disclosed stub at integration -- finding "master table"):
  // pulses on a genuinely accepted-and-resolved-with-at-least-one-
  // destination ingress record, matching Appendix A's own generic
  // "qualified accepted unit of work" description; left unconnected in
  // dfc_rtl024.sv since RTL-015's own canonical order has no slot for it.
  // ==========================================================================
  assign activity_o = (accept[0] && rslv_any_selected[0]) || (accept[1] && rslv_any_selected[1]) ||
                       (accept[2] && rslv_any_selected[2]) || (accept[3] && rslv_any_selected[3]) ||
                       (accept[4] && rslv_any_selected[4]);

  // ==========================================================================
  // Status assembly.
  // ==========================================================================
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__READY_HI]          = module_enable_i;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__FAULT_HI]          = 1'b0;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__EVENT_OVERFLOW_HI] = event_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__ACTIVE_HI]          = ctl_enable;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__COMMIT_COMPLETE_HI] = commit_complete_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__COMMIT_REJECTED_HI] = commit_rejected_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__DEST_OVERFLOW_HI]   = dest_overflow_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__UNAUTHORIZED_HI]    = unauthorized_sticky_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__LAST_ERROR_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__LAST_ERROR_LO] = last_error_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__DROP_COUNT_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_STATUS__DROP_COUNT_LO] = global_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_SOURCE__SOURCE_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_SOURCE__SOURCE_LO] = entry_source_id_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_DEST__DEST_MASK_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_DEST__DEST_MASK_LO] = entry_dest_mask_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_TYPE_MASK__TYPE_MASK_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_TYPE_MASK__TYPE_MASK_LO] = entry_type_mask_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_FILTER_VALUE__FILTER_VALUE_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_FILTER_VALUE__FILTER_VALUE_LO] = entry_filter_value_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_FILTER_MASK__FILTER_MASK_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_FILTER_MASK__FILTER_MASK_LO] = entry_filter_mask_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ENTRY_STATUS__ACTIVE_HI] = entry_valid_q[entry_select] && entry_enable_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ENTRY_STATUS__VALID_HI]  = entry_valid_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ENTRY_STATUS__ERROR_HI]  = entry_error_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ENTRY_STATUS__FORWARDED_COUNT_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ENTRY_STATUS__FORWARDED_COUNT_LO] = entry_forwarded_count_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL021_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_INGRESS_LOSS_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_INGRESS_LOSS_COUNT__COUNT_LO] =
      {ingress_loss_count_q[4], ingress_loss_count_q[3], ingress_loss_count_q[2], ingress_loss_count_q[1], ingress_loss_count_q[0]};
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_DESTINATION_DROP_COUNT__COUNT_HI:dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_DESTINATION_DROP_COUNT__COUNT_LO] =
      {dest_drop_count_q[4], dest_drop_count_q[3], dest_drop_count_q[2], dest_drop_count_q[1], dest_drop_count_q[0]};
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_CONTROL__ENABLE_HI]       = entry_enable_q[entry_select];
  assign status_o[dfc_types_pkg::DFC_RTL021_STATUS__ROUTE_ACTIVE_CONTROL__DROP_ON_FULL_HI] = entry_drop_on_full_q[entry_select];

endmodule : dfc_rtl021
