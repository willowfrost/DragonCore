// ============================================================================
// dfc_rtl015.sv -- RTL-015 Lost-Link Supervisor (ARCH-MOD-015)
//
// Controlling spec: docs/rtl_specs/RTL-015_RevB.md (derived; Rev A's port
// list was close but its "per-monitor activity-ID select" claim and the
// true activity_i bit wiring were both wrong -- OPEN_ISSUES item 81/82).
// Owning contracts: ARCH-002 SS10.3 ARCH-SAFE-007/008, Appendix F.1
// ARCH-RTL015-001, F.3 RTL-015 row and preamble, F.4 ARCH-VAL-015;
// Appendix C.1 (activity producers), C.8 (lane 3, source IDs 0-7,
// authorization bits 24-31), C.4 bit 16, C.5 index 14, C.7 event 0x0043;
// REG-002 SS27 (0x3300-0x3324, 10 registers); VP-002 VP-MOD-015/VP-SAFE-008.
//
// Clock/reset: CORE_CLK only; core_rst_n_i asynchronous assert (RDC-001),
// module_reset_i synchronous safety-scope reset (RTL-002.module_reset_o[14]).
// Register ownership: none decoded here (RTLSTD-REG-001); every register
// arrives through RTL-001's generated control_i/status_o forwarding
// (tools/reggen/rtl015_field_map.json, reggen.py v5).
//
// Port list: the 17 ports of ARCH-002 Appendix A "RTL-015 - Lost-Link
// Supervisor (17 ports)". Flat logic vectors sized by generated
// dfc_types_pkg _WIDTH constants; fields sliced by generated _HI/_LO
// constants (PROJECT_CONTINUITY.md Section 2 pkg::type_t rule).
//
// ---------------------------------------------------------------------------
// STRUCTURE (see OPEN_ISSUES.md items 81-89 for every disclosed decision):
//
//  1. MONITOR <-> ACTIVITY ID IS FIXED 1:1, NOT HOST-CONFIGURABLE (item 81).
//     REG-002's own real field table for LLINK_MONITOR_CONTROL (REG-330C)
//     has NO activity-ID-select field -- only ENABLE/EVENT_ENABLE/
//     IRQ_ENABLE/FAULT_ENABLE/SAFETY_RESPONSE_MASK. RTL-015_RevA.md's own
//     "Per-monitor activity-ID select" prose (SS4) and ARCH-VAL-015's
//     "activity source 0-7" clause both describe a mapping that is
//     structurally hardwired: monitor m always watches activity_i[m].
//     LLINK_MONITOR_SELECT selects which monitor's ENABLE/QUALIFY_US/
//     TIMEOUT_US/RECOVERY_US/mask you are CONFIGURING or READING, same
//     selector role as RTL-014's ILOCK_ENTRY_SELECT -- it does not select
//     an activity source.
//
//  2. PER-MONITOR CONFIG BANK (item 82, same architectural problem and fix
//     as RTL-014 item 68). REG-002 describes LLINK_MONITOR_CONTROL/
//     QUALIFY_US/TIMEOUT_US/RECOVERY_US as "selected monitor" registers,
//     but all 8 monitors run simultaneously and continuously -- a single
//     selected-only view cannot carry that. These four registers are
//     selector-indexed x8 by LLINK_MONITOR_SELECT.MONITOR (reggen.py v5
//     indexed_registers, reusing RTL-014's own mechanism with zero new
//     generator work), and the complete bank reaches this module as
//     llink_monitor_m<0..7>__* (dfc_rtl015_control_t grown 128->961 bits).
//     The struct's pre-existing selected-view fields (llink_monitor_
//     control__*, llink_qualify_us__qualify_us, etc.) are forwarded but
//     functionally unused here (item 73 precedent) -- consumed by the
//     unused-port sink.
//
//  3. NO STAGED/COMMIT STEP (confirmed, not assumed -- REG-002's real
//     10-register list has no VALIDATE_COMMIT-shaped register). Every
//     per-monitor field is LIVE-IMMEDIATE: a write takes effect the cycle
//     it is accepted, same as RTL-010's live-RW thresholds (item 39
//     precedent), not RTL-014's whole-bank atomicity.
//
//  4. ACTIVITY_i WIRING (item 83, resolved in favor of this port's OWN
//     Appendix A row text, which doubly restates ARCH-SAFE-007's ID order
//     verbatim -- CHTR-DOC-003): 0 accepted host command, 1 ARINC RX word,
//     2 CAN RX frame, 3 UART RX byte, 4 any qualified GPIO transition,
//     5 any qualified health transition, 6 synchronized user diagnostic
//     transition, 7 accepted external watchdog-service pulse. FIVE other
//     Appendix A rows (RTL-012.service_activity_o->[1], RTL-017.activity_o
//     ->[2], RTL-019.activity_o->[3], RTL-020.activity_o->[4],
//     RTL-021.activity_o->[5]) conflict both with this row and with each
//     other, and RTL-021 (Databus Routing) is not even a legal activity ID
//     at all -- resolved as a stale table-generation artifact, same class
//     as items 1/10/11/13/19/22/37/44/61/74, the tenth instance and the
//     largest (5 conflicting rows at once). Each activity_i bit is a real,
//     already-qualified ONE-CYCLE PULSE per its own row text -- this module
//     does no further edge-detection on it.
//
//     Real producers wired in dfc_rtl024.sv this session: [4] GPIO
//     transition (derived, registered, from RTL-006's real qualified
//     levels -- no dedicated pulse port exists anywhere for this), [5]
//     health transition (same, from RTL-011), [7] RTL-012's real, real,
//     previously-unconsumed service_activity_o port. Disclosed stub-zero:
//     [0] host-accepted command (NO real Appendix A port exists anywhere
//     for this -- a genuine ARCH-002 gap, not invented here, item 84),
//     [1]/[2]/[3] (RTL-017/019/020 not built), [6] (RTL-022 permanently
//     out of scope).
//
//  5. QUALIFY_US / TIMEOUT_US / RECOVERY_US algorithm (item 85, a real,
//     disclosed design -- CHTR-DOC-006, no bit-exact algorithm is given).
//     Two free-running per-monitor microsecond counters, sharing one
//     module-wide us_tick (CORE_CLK/50, the same divider idiom as
//     dfc_rtl012.sv's elapsed_us_q):
//       elapsed_us_q[m]     -- time since the last qualifying activity on
//                              monitor m; resets to 0 on every effective
//                              activity pulse (natural OR injected);
//                              LOST declares the tick it first reaches
//                              TIMEOUT_US[m].
//       recovery_progress_q[m] -- MEANINGFUL ONLY WHILE active_q[m] (LOST)
//                              is set: held at zero whenever not currently
//                              lost, so recovery always starts counting
//                              fresh from the moment a loss is genuinely
//                              declared, never with stale head-start
//                              credit. While lost, accumulates each
//                              us_tick that elapsed_us_q[m] stays within
//                              QUALIFY_US[m] ("continuous qualified
//                              activity"); resets to 0 the instant a gap
//                              exceeds QUALIFY_US[m]. RECOVERED (clears
//                              LOST) the tick this first reaches
//                              RECOVERY_US[m]. QUALIFY_US[m]==0 bypasses
//                              the gap check entirely (every tick counts),
//                              the same "zero disables" idiom as RTL-010's
//                              MAX_AGE_MS. (A real bug was found and fixed
//                              here during bring-up, confirmed by a real
//                              simulation trace: an earlier draft let this
//                              counter free-run independent of active_q,
//                              so with QUALIFY_US=0 it accumulated stale
//                              credit BEFORE any loss began, making
//                              recovery_clear true the instant active_q
//                              set and clearing it again next cycle --
//                              active_q oscillated set/clear every single
//                              cycle. Item 88.)
//     ARCH-VAL-015's own "QUALIFY_US < TIMEOUT_US" requirement makes the
//     LOST-set and RECOVERED-clear conditions mutually exclusive by
//     construction (recovery can only accumulate while elapsed_us_q stays
//     below a bound strictly under TIMEOUT_US) -- no extra priority logic
//     is needed between them. TIMEOUT_US==0 or RECOVERY_US==0 (both
//     required nonzero by ARCH-VAL-015) and QUALIFY_US>=TIMEOUT_US are
//     each a live "configuration rejected" condition -> status_o.fault,
//     the same "defend against what RTL-001 doesn't yet reject" precedent
//     every prior monitoring module uses (item 4).
//
//  6. INJECTION (ARCH-SAFE-008, item 86). LLINK_ACTIVITY_INJECT.HEARTBEAT
//     targets the CURRENTLY SELECTED monitor, accepted only while
//     operating_state_i==TEST_DEBUG: value 1 injects one activity pulse
//     (ORed into the same effective-activity path a natural pulse uses --
//     "adds to, never replaces" -- no separate tag, since its only
//     observable effect is resetting elapsed_us_q exactly as real activity
//     would); value 2 injects loss evidence (ORs into the LOST-set trigger
//     for that monitor, but only takes effect while not already active,
//     the same "first equals" edge-only semantics the natural trigger
//     uses); value 3 is reserved -- RTL-001 has no per-field range
//     validation (item 4), so this module defends itself by simply never
//     matching the illegal encoding (no effect, same precedent as
//     RTL-003/007-014's own reserved-value defenses). "Natural loss has
//     priority over injected evidence": when both triggers are true the
//     same cycle (only possible if a host literally forces both the same
//     cycle), the SET is tagged natural, never injected. A set caused by
//     the injected path is reported as event subtype 3 "injection" instead
//     of subtype 0 "lost" (replacing, not adding a parallel event) -- this
//     satisfies "tagged injected, distinguishable from natural evidence"
//     using the event record's own subtype field, with no extra bits
//     needed. "Clear never suppresses an active loss": the host W1C clear
//     of LOST_STICKY is ineffective while LOST_ACTIVE is still set, the
//     same discipline as RTL-013's active-dominates-clear rule.
//
//  7. EVENT/IRQ (C.7 0x0043, F.3 RTL-015 row, item 39 precedent). Subtypes:
//     0 lost (natural), 1 recovered, 2 configuration rejected, 3 injection
//     (an injected-loss set, replacing subtype 0 for that specific
//     transition). Each monitor's own EVENT_ENABLE/IRQ_ENABLE replaces the
//     module-wide LLINK_CONTROL enables for F.3 bits 0-15 (per-monitor
//     lost/recovered); the module enables gate bits 16-18 (config-reject/
//     injection/overflow). One shared pending slot (same one-deep shape as
//     every prior module); losing/blocked candidates are counted into
//     event_drop_count/event_overflow (RTL-009/010/014 precedent).
//     source_id = C.5 index 14, using the bare-index convention of all 13
//     prior producers (item 74's open project-wide question, not resolved
//     here -- see OPEN_ISSUES item 87).
//
//  8. SAFETY OUTPUTS. fault_req_o (C.6 bit 2, class 0x03, recoverable) =
//     OR of every FAULT_ENABLE-gated active monitor, gated by
//     LLINK_CONTROL.ENABLE. response_req_o (lane 3, C.8 bits 24-31):
//     lowest active monitor with a nonzero response mask wins (same
//     lowest-index priority as RTL-014's lane 2, item 72 precedent);
//     source_id is structurally 0-7 (3 bits), so no reserved lane-3 ID can
//     ever be asserted (RTLSTD-SAFE-014).
//
//  9. PER-MONITOR ENABLE (REG-330C "selected monitor enable AND action
//     policy", item 89). ctl_m_enable[m]==0 gates this monitor out of the
//     absence/recovery timers entirely (held at zero, so re-enabling later
//     starts clean) and, same "disable releases" precedent as RTL-014's
//     module-wide ENABLE=0, clears an already-latched LOST_ACTIVE[m] too --
//     a real gap found and fixed during bring-up: without this, a monitor
//     that had genuinely timed out (e.g. from a leftover real timer
//     elapsing during an unrelated earlier test part, OPEN_ISSUES item
//     64's own lesson) stayed permanently stuck LOST after being disabled,
//     with no way to clear it short of a full module reset.
//
// operating_state_i is used only for the TEST_DEBUG injection qualifier;
// observational_mode_i has no equation in this module's owning contracts
// -- both consumed via the unused-port sink alongside the selected-view
// control fields.
// ============================================================================

module dfc_rtl015 (
  input  logic core_clk_i,
  input  logic core_rst_n_i,
  input  logic module_reset_i,             // RTL-002.module_reset_o[14]

  input  logic [dfc_types_pkg::DFC_RTL015_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL015_STATUS_WIDTH-1:0]  status_o,

  input  logic [63:0] timestamp_i,
  output logic         evt_valid_o,
  input  logic         evt_ready_i,
  output logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o,

  output logic         irq_req_o,          // RTL-003.irq_source_i[16]
  output logic         fault_req_o,        // RTL-013.fault_source_i[2]

  input  logic [7:0]   activity_i,         // RTL-024 activity vector, C.1 order
  output logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_req_o,
                                            // RTL-016.response_req_i[3]

  input  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i,
  input  logic         observational_mode_i,

  input  logic [63:0] event_condition_enable_i,  // Appendix F.3 index 14
  input  logic [63:0] irq_condition_enable_i      // Appendix F.3 index 14
);

  localparam int unsigned NM = 8;

  // ---- control_i field extraction: module-wide fields ----
  wire       ctl_enable       = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_CONTROL__ENABLE_HI];
  wire       ctl_event_enable = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_CONTROL__EVENT_ENABLE_HI];
  wire       ctl_irq_enable   = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_CONTROL__IRQ_ENABLE_HI];
  wire [7:0] ctl_clr_lost_sticky = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_STATUS__LOST_STICKY_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_STATUS__LOST_STICKY_LO];
  wire [7:0] ctl_clr_recovered   = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_STATUS__RECOVERED_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_STATUS__RECOVERED_LO];
  wire [2:0] ctl_monitor_select  = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_SELECT__MONITOR_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_SELECT__MONITOR_LO];
  wire [1:0] ctl_heartbeat       = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_ACTIVITY_INJECT__HEARTBEAT_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_ACTIVITY_INJECT__HEARTBEAT_LO];
  wire       ctl_clear_event_overflow = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__RTL015_EVT_OVERFLOW_STATUS__EVENT_OVERFLOW_HI];

  // Selected-entry view fields (pre-existing struct members, see header
  // item 2) -- forwarded but functionally unused by this module.
  wire [103:0] ctl_selected_view = {
    control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_RECOVERY_US__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_CONTROL__ENABLE_LO]};

  // ---- per-monitor config bank (reggen.py v5 indexed_registers forwarding) ----
  logic [7:0] ctl_m_enable;
  logic [7:0] ctl_m_event_enable;
  logic [7:0] ctl_m_irq_enable;
  logic [7:0] ctl_m_fault_enable;
  logic [3:0] ctl_m_safety_response_mask [0:7];
  logic [31:0] ctl_m_qualify_us [0:7];
  logic [31:0] ctl_m_timeout_us [0:7];
  logic [31:0] ctl_m_recovery_us [0:7];

  always_comb begin
    ctl_m_enable[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__ENABLE_HI];
    ctl_m_event_enable[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__EVENT_ENABLE_HI];
    ctl_m_irq_enable[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__IRQ_ENABLE_HI];
    ctl_m_fault_enable[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__QUALIFY_US_LO];
    ctl_m_timeout_us[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__TIMEOUT_US_LO];
    ctl_m_recovery_us[0] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M0__RECOVERY_US_LO];
    ctl_m_enable[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__ENABLE_HI];
    ctl_m_event_enable[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__EVENT_ENABLE_HI];
    ctl_m_irq_enable[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__IRQ_ENABLE_HI];
    ctl_m_fault_enable[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__QUALIFY_US_LO];
    ctl_m_timeout_us[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__TIMEOUT_US_LO];
    ctl_m_recovery_us[1] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M1__RECOVERY_US_LO];
    ctl_m_enable[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__ENABLE_HI];
    ctl_m_event_enable[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__EVENT_ENABLE_HI];
    ctl_m_irq_enable[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__IRQ_ENABLE_HI];
    ctl_m_fault_enable[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__QUALIFY_US_LO];
    ctl_m_timeout_us[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__TIMEOUT_US_LO];
    ctl_m_recovery_us[2] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M2__RECOVERY_US_LO];
    ctl_m_enable[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__ENABLE_HI];
    ctl_m_event_enable[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__EVENT_ENABLE_HI];
    ctl_m_irq_enable[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__IRQ_ENABLE_HI];
    ctl_m_fault_enable[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__QUALIFY_US_LO];
    ctl_m_timeout_us[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__TIMEOUT_US_LO];
    ctl_m_recovery_us[3] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M3__RECOVERY_US_LO];
    ctl_m_enable[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__ENABLE_HI];
    ctl_m_event_enable[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__EVENT_ENABLE_HI];
    ctl_m_irq_enable[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__IRQ_ENABLE_HI];
    ctl_m_fault_enable[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__QUALIFY_US_LO];
    ctl_m_timeout_us[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__TIMEOUT_US_LO];
    ctl_m_recovery_us[4] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M4__RECOVERY_US_LO];
    ctl_m_enable[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__ENABLE_HI];
    ctl_m_event_enable[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__EVENT_ENABLE_HI];
    ctl_m_irq_enable[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__IRQ_ENABLE_HI];
    ctl_m_fault_enable[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__QUALIFY_US_LO];
    ctl_m_timeout_us[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__TIMEOUT_US_LO];
    ctl_m_recovery_us[5] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M5__RECOVERY_US_LO];
    ctl_m_enable[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__ENABLE_HI];
    ctl_m_event_enable[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__EVENT_ENABLE_HI];
    ctl_m_irq_enable[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__IRQ_ENABLE_HI];
    ctl_m_fault_enable[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__QUALIFY_US_LO];
    ctl_m_timeout_us[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__TIMEOUT_US_LO];
    ctl_m_recovery_us[6] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M6__RECOVERY_US_LO];
    ctl_m_enable[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__ENABLE_HI];
    ctl_m_event_enable[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__EVENT_ENABLE_HI];
    ctl_m_irq_enable[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__IRQ_ENABLE_HI];
    ctl_m_fault_enable[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__FAULT_ENABLE_HI];
    ctl_m_safety_response_mask[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__SAFETY_RESPONSE_MASK_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__SAFETY_RESPONSE_MASK_LO];
    ctl_m_qualify_us[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__QUALIFY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__QUALIFY_US_LO];
    ctl_m_timeout_us[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__TIMEOUT_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__TIMEOUT_US_LO];
    ctl_m_recovery_us[7] = control_i[dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__RECOVERY_US_HI:dfc_types_pkg::DFC_RTL015_CONTROL__LLINK_MONITOR_M7__RECOVERY_US_LO];
  end

  // ==========================================================================
  // Shared microsecond tick (same CORE_CLK/50 idiom as dfc_rtl012.sv's
  // elapsed_us_q -- one generator, shared by all 8 monitors' counters).
  // ==========================================================================
  logic [5:0] us_phase_q;
  wire        us_tick = (us_phase_q == 6'd49);
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       us_phase_q <= 6'd0;
    else if (module_reset_i) us_phase_q <= 6'd0;
    else if (us_tick)        us_phase_q <= 6'd0;
    else                     us_phase_q <= us_phase_q + 6'd1;
  end

  // ==========================================================================
  // Injection (ARCH-SAFE-008) -- targets the CURRENTLY SELECTED monitor only.
  // ==========================================================================
  wire test_active_qualified = (operating_state_i == dfc_types_pkg::TEST_DEBUG);
  wire inject_activity_cmd   = test_active_qualified && (ctl_heartbeat == 2'd1);
  wire inject_loss_cmd       = test_active_qualified && (ctl_heartbeat == 2'd2);
  // ctl_heartbeat==2'd3 (reserved) and any command outside TEST_DEBUG: no
  // effect, defended here since RTL-001 has no per-field range validation
  // (OPEN_ISSUES item 4).

  logic [NM-1:0] inject_activity_pulse, inject_loss_pulse;
  always_comb begin
    inject_activity_pulse = {NM{1'b0}};
    inject_loss_pulse      = {NM{1'b0}};
    inject_activity_pulse[ctl_monitor_select] = inject_activity_cmd;
    inject_loss_pulse[ctl_monitor_select]      = inject_loss_cmd;
  end

  // ==========================================================================
  // Per-monitor absence/recovery timers, active/sticky/recovered state.
  // ==========================================================================
  logic [31:0] elapsed_us_q         [0:NM-1];
  logic [31:0] recovery_progress_q  [0:NM-1];
  logic [NM-1:0] active_q, active_prev_q, sticky_q, recovered_q, inject_set_prev_q;

  wire [NM-1:0] effective_activity = activity_i | inject_activity_pulse;

  logic [NM-1:0] within_qualify, illegal_cfg;
  always_comb begin
    for (int m = 0; m < NM; m++) begin
      within_qualify[m] = (ctl_m_qualify_us[m] == 32'd0) || (elapsed_us_q[m] <= ctl_m_qualify_us[m]);
      illegal_cfg[m]    = (ctl_m_qualify_us[m] >= ctl_m_timeout_us[m]) ||
                          (ctl_m_timeout_us[m] == 32'd0) ||
                          (ctl_m_recovery_us[m] == 32'd0);
    end
  end

  // ctl_m_enable[m] gates this monitor's own participation entirely (REG-330C
  // "selected monitor enable AND action policy"): a disabled monitor never
  // declares loss and its absence timer is held at zero (reset below), so
  // re-enabling it later starts clean rather than with a stale timeout.
  logic [NM-1:0] natural_set, injected_set, recovery_clear;
  always_comb begin
    for (int m = 0; m < NM; m++) begin
      natural_set[m]   = ctl_m_enable[m] && !active_q[m] && (elapsed_us_q[m] >= ctl_m_timeout_us[m]) && !effective_activity[m];
      injected_set[m]  = ctl_m_enable[m] && !active_q[m] && !natural_set[m] && inject_loss_pulse[m];
      recovery_clear[m] = active_q[m] && (recovery_progress_q[m] >= ctl_m_recovery_us[m]);
    end
  end

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      for (int m = 0; m < NM; m++) begin
        elapsed_us_q[m]        <= 32'd0;
        recovery_progress_q[m] <= 32'd0;
      end
      active_q          <= {NM{1'b0}};
      active_prev_q      <= {NM{1'b0}};
      sticky_q           <= {NM{1'b0}};
      recovered_q         <= {NM{1'b0}};
      inject_set_prev_q   <= {NM{1'b0}};
    end else if (module_reset_i) begin
      for (int m = 0; m < NM; m++) begin
        elapsed_us_q[m]        <= 32'd0;
        recovery_progress_q[m] <= 32'd0;
      end
      active_q          <= {NM{1'b0}};
      active_prev_q      <= {NM{1'b0}};
      sticky_q           <= {NM{1'b0}};
      recovered_q         <= {NM{1'b0}};
      inject_set_prev_q   <= {NM{1'b0}};
    end else begin
      for (int m = 0; m < NM; m++) begin
        // Absence timer: held at zero while this monitor is disabled; reset
        // on any effective (natural or injected) activity; otherwise advance
        // once per us_tick, saturating.
        if (!ctl_m_enable[m] || effective_activity[m]) begin
          elapsed_us_q[m] <= 32'd0;
        end else if (us_tick && (elapsed_us_q[m] != 32'hFFFF_FFFF)) begin
          elapsed_us_q[m] <= elapsed_us_q[m] + 32'd1;
        end

        // Recovery-progress timer: only meaningful WHILE this monitor is
        // genuinely LOST (active_q[m]) -- a real bug was found and fixed
        // here during this module's own bring-up (not caught by inspection):
        // the first draft let this counter free-run unconditionally whenever
        // within_qualify held, independent of active_q. With QUALIFY_US=0
        // ("disabled", always within_qualify), that let recovery_progress_q
        // accumulate stale credit BEFORE a loss ever began, so the instant
        // active_q[m] set, recovery_clear[m] could already be true from that
        // stale credit, immediately clearing it again -- active_q[m]
        // oscillated set/clear every single cycle, confirmed via a real
        // simulation trace, not by inspection. Fixed: reset to zero whenever
        // NOT lost (recovery only starts counting from the moment a loss is
        // genuinely declared, giving it no head start), accumulate while
        // lost AND gaps stay within QUALIFY_US, reset on a gap violation
        // while lost, or while disabled.
        if (!ctl_m_enable[m] || !active_q[m]) begin
          recovery_progress_q[m] <= 32'd0;
        end else if (us_tick) begin
          if (within_qualify[m]) begin
            if (recovery_progress_q[m] != 32'hFFFF_FFFF)
              recovery_progress_q[m] <= recovery_progress_q[m] + 32'd1;
          end else begin
            recovery_progress_q[m] <= 32'd0;
          end
        end

        // Active/sticky/recovered (new-dominates-clear; recovery is sticky
        // evidence that does not clear LOST_STICKY -- RTL-011 precedent).
        // Disabling a monitor releases its own already-latched LOST_ACTIVE
        // too, not just future sets (same "disable releases" precedent as
        // RTL-014's module-wide ENABLE=0) -- a real gap found and fixed
        // during this module's own bring-up: without this, re-disabling a
        // monitor that happened to genuinely time out earlier (e.g. a
        // leftover real timer from an earlier test part, OPEN_ISSUES item
        // 64's own lesson) left it permanently stuck LOST with no way to
        // clear it short of a module reset.
        if (!ctl_m_enable[m])                       active_q[m] <= 1'b0;
        else if (natural_set[m] || injected_set[m]) active_q[m] <= 1'b1;
        else if (recovery_clear[m])                  active_q[m] <= 1'b0;

        if (active_q[m])                             sticky_q[m] <= 1'b1;
        else if (ctl_clr_lost_sticky[m])              sticky_q[m] <= 1'b0;

        if (active_prev_q[m] && !active_q[m])         recovered_q[m] <= 1'b1;
        else if (ctl_clr_recovered[m])                 recovered_q[m] <= 1'b0;

        active_prev_q[m]    <= active_q[m];
        inject_set_prev_q[m] <= injected_set[m];
      end
    end
  end

  // ==========================================================================
  // Local fault aggregate (illegal configuration, item 4/5) -- distinct
  // from fault_req_o (the real C.6 safety-fault request, below).
  // ==========================================================================
  wire local_fault = |illegal_cfg;

  // ==========================================================================
  // Safety outputs (header item 8).
  // ==========================================================================
  wire [NM-1:0] fault_contrib = active_q & ctl_m_fault_enable;
  assign fault_req_o = ctl_enable && (|fault_contrib);

  logic [NM-1:0] resp_eligible;
  always_comb begin
    for (int m = 0; m < NM; m++)
      resp_eligible[m] = ctl_enable && active_q[m] && (ctl_m_safety_response_mask[m] != 4'h0);
  end
  logic [2:0] resp_monitor;
  always_comb begin
    casez (resp_eligible)
      8'b???????1: resp_monitor = 3'd0;
      8'b??????10: resp_monitor = 3'd1;
      8'b?????100: resp_monitor = 3'd2;
      8'b????1000: resp_monitor = 3'd3;
      8'b???10000: resp_monitor = 3'd4;
      8'b??100000: resp_monitor = 3'd5;
      8'b?1000000: resp_monitor = 3'd6;
      8'b10000000: resp_monitor = 3'd7;
      default:     resp_monitor = 3'd0;
    endcase
  end
  logic [dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ_WIDTH-1:0] response_comb;
  always_comb begin
    response_comb = '0;
    if (resp_eligible != 8'h00) begin
      response_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__RESPONSE_MASK_LO] = ctl_m_safety_response_mask[resp_monitor];
      response_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_HI:dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__SOURCE_ID_LO] = resp_monitor;
      response_comb[dfc_types_pkg::DFC_SAFETY_RESPONSE_REQ__VALID_HI] = 1'b1;
    end
  end
  assign response_req_o = response_comb;

  // ==========================================================================
  // Events / IRQ (C.7 0x0043, F.3 index 14).
  // ==========================================================================
  wire [NM-1:0] cond_lost_natural = natural_set;
  wire [NM-1:0] cond_lost_inject  = injected_set;
  wire [NM-1:0] cond_recovered    = active_prev_q & ~active_q;
  wire          cond_config_rej   = local_fault;

  wire [NM-1:0] ev_lost      = cond_lost_natural & ctl_m_event_enable & event_condition_enable_i[7:0];
  wire [NM-1:0] ev_inject    = cond_lost_inject  & ctl_m_event_enable & event_condition_enable_i[7:0];
  wire [NM-1:0] ev_recovered = cond_recovered    & ctl_m_event_enable & event_condition_enable_i[15:8];
  wire          ev_config_rej = cond_config_rej  & ctl_event_enable    & event_condition_enable_i[16];

  wire [NM-1:0] iq_lost      = (cond_lost_natural | cond_lost_inject) & ctl_m_irq_enable & irq_condition_enable_i[7:0];
  wire [NM-1:0] iq_recovered = cond_recovered & ctl_m_irq_enable & irq_condition_enable_i[15:8];
  wire          iq_config_rej = cond_config_rej & ctl_irq_enable & irq_condition_enable_i[16];

  localparam logic [15:0] EVT_ID_LOST_LINK       = 16'h0043;
  localparam logic [7:0]  EVT_SUBTYPE_LOST       = 8'd0;
  localparam logic [7:0]  EVT_SUBTYPE_RECOVERED  = 8'd1;
  localparam logic [7:0]  EVT_SUBTYPE_CONFIG_REJ = 8'd2;
  localparam logic [7:0]  EVT_SUBTYPE_INJECTION  = 8'd3;
  localparam logic [7:0]  EVT_SOURCE_INDEX_RTL015 = 8'd14;  // ARCH-002 C.5 index 14

  wire [7:0]  cand_lost   = ev_lost;
  wire [7:0]  cand_inject = ev_inject;
  wire [7:0]  cand_rec    = ev_recovered;
  wire        cand_cfg    = ev_config_rej;

  logic [2:0] lost_idx, inject_idx, rec_idx;
  always_comb begin
    casez (cand_lost)
      8'b???????1: lost_idx = 3'd0; 8'b??????10: lost_idx = 3'd1; 8'b?????100: lost_idx = 3'd2;
      8'b????1000: lost_idx = 3'd3; 8'b???10000: lost_idx = 3'd4; 8'b??100000: lost_idx = 3'd5;
      8'b?1000000: lost_idx = 3'd6; 8'b10000000: lost_idx = 3'd7; default: lost_idx = 3'd0;
    endcase
    casez (cand_inject)
      8'b???????1: inject_idx = 3'd0; 8'b??????10: inject_idx = 3'd1; 8'b?????100: inject_idx = 3'd2;
      8'b????1000: inject_idx = 3'd3; 8'b???10000: inject_idx = 3'd4; 8'b??100000: inject_idx = 3'd5;
      8'b?1000000: inject_idx = 3'd6; 8'b10000000: inject_idx = 3'd7; default: inject_idx = 3'd0;
    endcase
    casez (cand_rec)
      8'b???????1: rec_idx = 3'd0; 8'b??????10: rec_idx = 3'd1; 8'b?????100: rec_idx = 3'd2;
      8'b????1000: rec_idx = 3'd3; 8'b???10000: rec_idx = 3'd4; 8'b??100000: rec_idx = 3'd5;
      8'b?1000000: rec_idx = 3'd6; 8'b10000000: rec_idx = 3'd7; default: rec_idx = 3'd0;
    endcase
  end

  wire [3:0] n_lost   = $countones(cand_lost);
  wire [3:0] n_inject = $countones(cand_inject);
  wire [3:0] n_rec    = $countones(cand_rec);
  wire [3:0] n_cfg    = {3'b0, cand_cfg};
  wire [4:0] n_total  = n_lost + n_inject + n_rec + n_cfg;

  // Priority when multiple classes qualify the same cycle: config-reject
  // (module-wide, most safety-relevant) > injection > natural lost >
  // recovered (same "most safety-relevant first" precedent as RTL-013's
  // own event-priority disclosure, item 62).
  logic [7:0]  evt_subtype_comb;
  logic [2:0]  evt_monitor_comb;
  logic        evt_candidate_valid;
  always_comb begin
    evt_subtype_comb    = EVT_SUBTYPE_LOST;
    evt_monitor_comb    = 3'd0;
    evt_candidate_valid = (n_total != 5'd0);
    if (cand_cfg) begin
      evt_subtype_comb = EVT_SUBTYPE_CONFIG_REJ;
    end else if (cand_inject != 8'h00) begin
      evt_subtype_comb = EVT_SUBTYPE_INJECTION;
      evt_monitor_comb  = inject_idx;
    end else if (cand_lost != 8'h00) begin
      evt_subtype_comb = EVT_SUBTYPE_LOST;
      evt_monitor_comb  = lost_idx;
    end else if (cand_rec != 8'h00) begin
      evt_subtype_comb = EVT_SUBTYPE_RECOVERED;
      evt_monitor_comb  = rec_idx;
    end
  end

  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_candidate;
  always_comb begin
    evt_candidate = '0;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_HI:dfc_types_pkg::DFC_EVENT_RECORD__TIMESTAMP_LO] = timestamp_i;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__EVENT_ID_LO]   = EVT_ID_LOST_LINK;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_HI:dfc_types_pkg::DFC_EVENT_RECORD__SOURCE_ID_LO] = EVT_SOURCE_INDEX_RTL015;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO +: 8]     = evt_subtype_comb;
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO + 8 +: 8] = {5'h00, evt_monitor_comb};
    // event_data[31:16]: elapsed-time low bits (C.7), the selected monitor's
    // own elapsed_us_q for config-reject (module-wide), else the reporting
    // monitor's own elapsed_us_q.
    evt_candidate[dfc_types_pkg::DFC_EVENT_RECORD__EVENT_DATA_LO + 16 +: 16] =
      cand_cfg ? elapsed_us_q[ctl_monitor_select][15:0] : elapsed_us_q[evt_monitor_comb][15:0];
  end

  logic                                             evt_pending_q;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_q;
  logic                                             event_overflow_q;
  logic [15:0]                                      event_drop_count_q;

  wire        slot_free = !evt_pending_q || evt_ready_i;
  wire [4:0]  drops_now = !evt_candidate_valid ? 5'd0 : (slot_free ? (n_total - 5'd1) : n_total);
  wire        overflow_sets_this_cycle = (drops_now != 5'd0);
  wire [16:0] drop_sum = {1'b0, event_drop_count_q} + {12'h000, drops_now};

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
      if (evt_pending_q && evt_ready_i) evt_pending_q <= 1'b0;
      if (evt_candidate_valid && slot_free) begin
        evt_pending_q <= 1'b1;
        evt_record_q  <= evt_candidate;
      end
      if (overflow_sets_this_cycle) begin
        event_overflow_q   <= 1'b1;
        event_drop_count_q <= drop_sum[16] ? 16'hFFFF : drop_sum[15:0];
      end else if (ctl_clear_event_overflow) begin
        event_overflow_q <= 1'b0;
      end
    end
  end

  assign evt_valid_o  = evt_pending_q;
  assign evt_record_o = evt_record_q;
  assign irq_req_o    = (|iq_lost) | (|iq_recovered) | iq_config_rej;

  // ==========================================================================
  // status_o packing (dfc_rtl015_status_t, 75 bits). ELAPSED_US is a
  // registered mux of the currently-selected monitor's own live counter
  // (same selected-entry-readback pattern as RTL-014's ACTIVE_RESULT,
  // item 67 precedent).
  // ==========================================================================
  logic [31:0] elapsed_sel_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       elapsed_sel_q <= 32'd0;
    else if (module_reset_i) elapsed_sel_q <= 32'd0;
    else                     elapsed_sel_q <= elapsed_us_q[ctl_monitor_select];
  end

  logic ready_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i)       ready_q <= 1'b0;
    else if (module_reset_i) ready_q <= 1'b0;
    else                     ready_q <= 1'b1;
  end

  logic [dfc_types_pkg::DFC_RTL015_STATUS_WIDTH-1:0] status_comb;
  always_comb begin
    status_comb = '0;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__READY_HI]          = ready_q;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__FAULT_HI]          = local_fault;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__EVENT_OVERFLOW_HI] = event_overflow_q;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__LLINK_STATUS__LOST_ACTIVE_HI:dfc_types_pkg::DFC_RTL015_STATUS__LLINK_STATUS__LOST_ACTIVE_LO] = active_q;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__LLINK_STATUS__LOST_STICKY_HI:dfc_types_pkg::DFC_RTL015_STATUS__LLINK_STATUS__LOST_STICKY_LO] = sticky_q;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__LLINK_STATUS__RECOVERED_HI:dfc_types_pkg::DFC_RTL015_STATUS__LLINK_STATUS__RECOVERED_LO]     = recovered_q;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__LLINK_ELAPSED_US__ELAPSED_US_HI:dfc_types_pkg::DFC_RTL015_STATUS__LLINK_ELAPSED_US__ELAPSED_US_LO] = elapsed_sel_q;
    status_comb[dfc_types_pkg::DFC_RTL015_STATUS__EVENT_DROP_COUNT_HI:dfc_types_pkg::DFC_RTL015_STATUS__EVENT_DROP_COUNT_LO] = event_drop_count_q;
  end
  assign status_o = status_comb;

  // ---- unused-port sink (RTLSTD-MOD-009): see header ----
  logic unused_stub_sink;
  assign unused_stub_sink = (^ctl_selected_view) ^ observational_mode_i;

endmodule : dfc_rtl015
