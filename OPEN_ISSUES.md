# Open Issues

Genuine ambiguities, spec conflicts, and disclosed gaps found while
implementing/integrating real RTL against the `-002` document set, per
CLAUDE.md's working rule 8. These are not coding mistakes -- they are places
where the `-002` documents (or the toolchain) are silent, inconsistent, or
incomplete, logged here rather than silently resolved or guessed.

## RTL-003 (Interrupt Controller) integration

1. **`RTL-003_RevA.md` (module spec) conflicts with `RCA-DFC-ARCH-002.md`
   (owning document) over RTL-003's own aggregate output port name.**
   `RTL-003_RevA.md` SS2 describes the module's aggregate output as if it
   were literally `host_irq_n_o` ("the sole host-visible aggregate output...
   ultimately the `host_irq_n_o` external pad"). ARCH-002's own formal port
   catalog (the actual owner of internal-interface facts, CHTR-002 SS3.1)
   names RTL-003's real 16th port `aggregate_pending_o` (active-high,
   producer RTL-003, consumer `RTL-024.aggregate_pending_i`); ARCH-002's
   separate RTL-024 port table shows `host_irq_n_o` as RTL-024's OWN external
   pad, fed by `aggregate_pending_i`, not a port RTL-003 itself owns.
   **Resolved in favor of ARCH-002** (owns this fact per CHTR-DOC-003) --
   `dfc_rtl003.sv` implements `aggregate_pending_o`; `dfc_rtl024.sv` performs
   the final active-low inversion onto the real `host_irq_n_o` pad. If
   `RTL-003_RevA.md` is ever revised, its own port-name claim should be
   corrected to cite ARCH-002 rather than restate it (CHTR-DOC-003).

2. **RESOLVED (2026-08-20).** `dfc_rtl003_control_t` (128 bits, exactly 4
   fields) and `dfc_rtl002_control_t` (59 bits) each had no field for
   clearing their respective `RTL00N_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW`
   W1C bit (REG-0044/REG-011C). Fixed by growing ARCH-002 itself (the
   correct fix per this item's own original text -- not something a
   field-map could invent): `dfc_rtl002_control_t` grew from 59 to 60 bits
   (new field `rtl002_evt_overflow_status__event_overflow` at bit 59) and
   `dfc_rtl003_control_t` grew from 128 to 129 bits (new field
   `rtl003_evt_overflow_status__event_overflow` at bit 128) -- each new
   field placed at the struct's new highest bit specifically so every
   pre-existing field keeps its exact prior bit position (confirmed
   byte-identical via a real regeneration: every other `_HI`/`_LO`
   constant in both structs in the regenerated `dfc_types_pkg.sv` is
   unchanged from before this fix). `tools/reggen/rtl002_field_map.json`
   and `rtl003_field_map.json` each gained one new `control_registers`
   entry (the register's real EVENT_OVERFLOW bit, class W1C, mapped to the
   new struct field) -- same pattern already used for
   RESET_STATUS/RESET_DIAGNOSTIC. Confirmed via a real `reggen.py` run:
   `write_illegal_o` for both `RTL002_EVT_OVERFLOW_STATUS` and
   `RTL003_EVT_OVERFLOW_STATUS` is now `1'b0` (previously `1'b1`).
   `dfc_rtl002.sv`/`dfc_rtl003.sv` each gained a real bit-slice wire off
   the new control field and real clear logic on their sticky
   `event_overflow_q` register, gated so a genuinely new overflow event
   landing the same cycle as the clear request wins (REG-0044/REG-011C's
   own documented field priority: "reset/disable, then new evidence, then
   clear") -- `DROP_COUNT` itself has no defined clear side effect and is
   left untouched by this fix, per REG-002's own register-level side-effect
   text ("DROP_COUNT is read-only"). Proven via new, real checks added to
   `rtl002_integration_tb.sv` and `rtl003_integration_tb.sv`: each
   withholds its module's event handshake to force a genuine (not
   fabricated) overflow condition, confirms `event_overflow_q` sets, issues
   the real host clear write through RTL-001's real DRI path, and confirms
   `event_overflow_q` actually clears. Verified end-to-end: full Icarus
   regression (7/7 testbenches, 133/133 checks), a real `gate.ps1` run
   (lint/sim/formal bmc+prove/coverage all clean), and a real
   `build_ecp5.ps1` run (Build ID `20260820_074244`, **63.17 MHz PASS at
   50 MHz required**).

3. **REG-002's own text for `IRQ_CLEAR` (0x0114) is ambiguous about what
   "reads current retained value" means for a register whose write side is
   a per-source clear-request mask, not itself a status register.** REG-GEN-013
   (W1C fields report "retained evidence", cleared by an explicit host
   write) is written for the common case where the SAME register holds both
   the sticky evidence and accepts the W1C clear (e.g. RTL-002's
   `RESET_STATUS`). `IRQ_CLEAR` is architecturally distinct from
   `IRQ_RAW_STATUS` (0x0104, the actual LATCH readback) -- and ARCH-002's own
   `dfc_rtl003_status_t` confirms this by giving `irq_clear__clear` its own,
   separate 32-bit status-struct member (bits 130:99), distinct from
   `irq_raw_status__raw_status` (bits 34:3). Neither REG-002 nor ARCH-002
   states exactly what value this distinct field should read back.
   **Implemented as a disclosed interpretation** (see `dfc_rtl003.sv`'s own
   header): a direct echo of `control_i`'s one-cycle `irq_clear__clear` pulse
   into `status_o.irq_clear__clear` -- i.e. a host read shortly after an
   accepted CLEAR write can observe which mask was just applied, decaying to
   zero the following cycle. If a bit-exact alternative is ever specified,
   only this one field's packing needs to change.

4. **RTL-001's per-field reserved-bit/legal-range write validation
   (REG-ENC-001 through 019) still does not exist** (already disclosed in
   `dfc_rtl001.sv`'s own header before RTL-003). This now has a concrete,
   demonstrated consequence for RTL-003 specifically: a host write setting
   `IRQ_ENABLE`/`IRQ_ACK`/`IRQ_CLEAR`/`TEST_IRQ_INJECT` bits 24-31
   (Appendix C.4's reserved source positions, which RTL-003 spec SS3 says
   "writes selecting them are rejected") is accepted by RTL-001's DRI path
   rather than rejected before ever reaching `control_i`.
   `rtl003_integration_tb.sv` exercises this exact case and confirms
   RTL-003 defends itself (reserved state is always tied zero internally,
   illegal activity is detected and faulted/eventable) even though the
   real, spec-correct fix belongs in RTL-001's validation path, not in each
   downstream consumer module.

5. **RESOLVED (2026-08-20).** `dfc_rtl002.sv` did not expose 4 ports
   ARCH-002's own formal port catalog lists for RTL-002: `global_irq_enable_o`,
   `global_event_enable_o`, `event_condition_enable_i`,
   `irq_condition_enable_i`. Fixed by adding all 4 as real ports on
   `dfc_rtl002.sv` directly. `global_irq_enable_o`/`global_event_enable_o`
   are driven from the same real `SYS_CONTROL.GLOBAL_IRQ_ENABLE`/
   `GLOBAL_EVENT_ENABLE` bits this module already extracts from `control_i`
   (`global_event_enable_o` reuses the exact wire already used internally to
   gate event generation; `global_irq_enable_o` uses a new, identically-
   patterned extraction wire, since RTL-002 previously had no internal use
   for that bit at all). `dfc_rtl024.sv` was updated to connect
   `RTL-003.global_irq_enable_i` to this new real `global_irq_enable_o`
   port, **removing the workaround that read `rtl002_control` directly**.
   `event_condition_enable_i`/`irq_condition_enable_i` are real ports, tied
   to a disclosed stub (`64'h0`) in `dfc_rtl024.sv`, consistent with item 6
   below (RTL-001 does not yet implement the underlying CONDITION_MASK
   storage/forwarding mechanism) -- genuinely unused inside `dfc_rtl002.sv`
   itself, intentionally consumed via an unused-port sink per
   RTLSTD-MOD-009 (same pattern `dfc_rtl003.sv` already used for its own
   analogous unused real ports). Verified end-to-end: full Icarus regression
   (7/7 testbenches, 133/133 checks, including `rtl002_state_tb.sv`'s and
   `rtl002_integration_tb.sv`'s updated instantiations for the 4 new
   ports), a real `gate.ps1` run, and a real `build_ecp5.ps1` run (Build ID
   `20260820_074244`, 63.17 MHz PASS at 50 MHz required).

6. **`event_condition_enable_i`/`irq_condition_enable_i` (Appendix F.3
   per-module condition masks) have no real producer anywhere in this
   project yet** -- RTL-001 does not implement the underlying
   `EVENT_CONDITION_MASK`/`IRQ_CONDITION_MASK` storage-and-per-module-
   forwarding mechanism these ports are supposed to come from (a separate,
   much larger piece of infrastructure spanning all 24 modules' own 64-bit
   masks). Every module with these ports (RTL-002, RTL-003, and every
   module after them) will need them tied to a disclosed stub (`64'h0`)
   until this exists. For RTL-003 specifically, this means the module's own
   diagnostic event (0x0008, illegal reserved-source activity) can never
   actually fire in the current integration, since
   `event_condition_enable_i[0]` is permanently 0 -- a real, disclosed
   consequence, not a defect in `dfc_rtl003.sv` itself.

## RTL-004 (Timestamp Engine) integration

7. **RESOLVED (2026-08-20), approved before implementation.**
   `dfc_rtl004_control_t` (70 bits) had no clear-request field for 2 of
   `TIME_STATUS`'s 4 real W1C bits: `SNAPSHOT_VALID` (bit 1) and
   `SYNC_VALID` (bit 2) -- REG-0204 declares both genuine W1C ("requests
   clear of selected sticky evidence only"), identical wording to
   `SYNC_UPDATED`/`ERROR`, which already had control-struct fields
   (`time_status__sync_updated`/`time_status__error`). Found while
   building `tools/reggen/rtl004_field_map.json`, before any RTL was
   written. Fixed, with explicit approval: ARCH-002 grew the struct
   70->72 bits, adding `time_status__snapshot_valid`/
   `time_status__sync_valid` at the two new highest bits -- every
   pre-existing field's bit position confirmed unchanged via a real
   `regenerate.ps1` run.

8. **RESOLVED (2026-08-20), approved before implementation.** The same
   already-known `EVENT_OVERFLOW`-clear-path gap closed for RTL-002/
   RTL-003 (item 2 above) recurred for RTL-004's own
   `RTL004_EVT_OVERFLOW_STATUS` (REG-0224) -- exactly as predicted in
   `PROJECT_CONTINUITY.md`'s own lessons-learned ("expect every future
   module's own `RTL0NN_EVT_OVERFLOW_STATUS` to hit the identical gap").
   Fixed the same way, before any RTL was written: ARCH-002 grew
   `dfc_rtl004_control_t` again, 72->73 bits, adding
   `rtl004_evt_overflow_status__event_overflow` at the new highest bit.

9. **RESOLVED (2026-08-20), approved before implementation.**
    `dfc_rtl004_status_t` (105 bits) had no field at all to carry the real
    active (committed) correlation offset back to `TIME_ACTIVE_OFFSET_LO`/
    `_HI` (REG-0228/022C) -- both registers are classified `readback:
    external` in the real extracted `dfc_registers_pkg.json`, meaning they
    have no other real data source, yet the struct already carried
    `time_sync_status__active_valid`/`update_sequence` for the identical
    COMMIT event without the offset value itself. A fragile RTL-001-side
    mirror of the commit logic was considered and rejected (risks desync
    from RTL-004's real internal state, e.g. across a `module_reset_i`
    RTL-001 has no visibility into). Fixed: ARCH-002 grew the status
    struct 105->169 bits, adding `time_active_offset_lo__offset_lo`/
    `time_active_offset_hi__offset_hi` (32 bits each) at the new highest
    bits -- RTL-004 itself is the single source of truth, matching how
    `active_valid`/`update_sequence` already work.
    - All three fixes above (items 7-9) verified end-to-end together: a
      real `regenerate.ps1` run confirmed every pre-existing `_HI`/`_LO`
      constant in both structs unchanged; a real `reggen.py` run confirmed
      `write_illegal_o` for `TIME_RAW_LO`/`TIME_RAW_HI`/`TIME_SYNC_STATUS`/
      `TIME_ACTIVE_OFFSET_LO`/`TIME_ACTIVE_OFFSET_HI` correctly stayed
      `1'b1` (pure-RO, no field-map control entry) while `TIME_CONTROL`/
      `TIME_STATUS`/`TIME_SNAPSHOT`/`TIME_SYNC_OFFSET_LO`/
      `TIME_SYNC_OFFSET_HI`/`TIME_SYNC_COMMIT`/`RTL004_EVT_OVERFLOW_STATUS`
      are `1'b0`; a real `rtl004_integration_tb.sv` proves real host
      writes reach RTL-004's real behavior and real internal state reaches
      back to a host read, including the `EVENT_OVERFLOW` clear path; a
      real `gate.ps1` run (162/162 checks, 8/8 testbenches) and a real
      `build_ecp5.ps1` run (Build ID `20260820_133515`, **65.52 MHz PASS
      at 50 MHz required**) both passed clean.

10. **Resolved without an ARCH-002 edit, same resolution style as item 1's
    `host_irq_n_o` conflict.** ARCH-002's own "RTL-004 - Timestamp Engine
    (14 ports)" port-catalog table lists a `timestamp_i` INPUT whose
    producer AND consumer are both listed as "RTL-004" -- a self-
    referencing port. RTL-004_RevA.md SS2 explicitly states "RTL-004 does
    not consume its own output; it is the origin," and a module consuming
    its own not-yet-registered output as an external port makes no
    engineering sense (and would require a real combinational loop).
    Treated as a table-generation artifact: this exact `timestamp_i` row
    template is mechanically repeated for every other module in the same
    table and was evidently never updated for RTL-004's own special case
    as the broadcast's true origin. `dfc_rtl004.sv` implements 13 real
    ports, not 14 -- only `timestamp_o` (the real broadcast). If ARCH-002
    is ever revised, this spurious row should be removed and the header
    count corrected to 13.

11. **Resolved without an edit, same reasoning as item 10.**
    RTL-004_RevA.md SS4 says REG-002's Timestamp block has "10 registers";
    REG-002 itself (the owning document, CHTR-DOC-003) says 12 and lists
    all 12 (`TIME_CONTROL`, `TIME_STATUS`, `TIME_SNAPSHOT`, `TIME_RAW_LO`,
    `TIME_RAW_HI`, `TIME_SYNC_OFFSET_LO`, `TIME_SYNC_OFFSET_HI`,
    `TIME_SYNC_COMMIT`, `TIME_SYNC_STATUS`, `RTL004_EVT_OVERFLOW_STATUS`,
    `TIME_ACTIVE_OFFSET_LO`, `TIME_ACTIVE_OFFSET_HI`). Resolved in favor of
    REG-002 per CHTR-DOC-003; `dfc_rtl004.sv` implements and forwards all
    12.

## RTL-005 (Event Logger) integration

12. **RESOLVED (2026-08-20), approved before implementation.** `dfc_rtl005_control_t`
    (128 bits, exactly full with no spare bits) had no clear-request field for
    EVT_STATUS.SNAPSHOT_VALID (REG-002 0x0304 bit 2, a real W1C field: "One
    requests clear; zero has no effect ... Requests clear of selected sticky
    evidence only") -- identical in kind to the OVERFLOW/SOURCE_DROP/
    POP_ERROR/CLEAR_COMPLETE clear fields the struct already had, and the
    fourth real instance of this exact gap class (items 2/7/8 above were the
    first three, for RTL-002/003's EVT_OVERFLOW_STATUS and RTL-004's
    SNAPSHOT_VALID/SYNC_VALID). Fixed, with explicit approval: ARCH-002 grew
    the struct 128->129 bits, adding `evt_status__snapshot_valid` at the new
    highest bit (128) -- every pre-existing field's bit position confirmed
    unchanged via a real `regenerate.ps1` run. `tools/reggen/rtl005_field_map.json`
    gained the corresponding `control_registers` entry. Proven via a real,
    new check in `rtl005_integration_tb.sv` (Part 5): a real capture sets
    SNAPSHOT_VALID, and the real host clear write using this session's new
    field genuinely clears it.

13. **Resolved without an edit, same reasoning as items 1/10/11.** REG-002's
    own top-level block-summary table lists RTL-005's Event Logger block as
    15 registers; `RTL-005_RevA.md` SS4 says "14 registers" without listing
    them. Resolved in favor of REG-002 (the owning document, CHTR-DOC-003)
    -- `dfc_rtl005.sv` implements and forwards all 15 (`EVT_CONTROL`,
    `EVT_STATUS`, `EVT_COUNT`, `EVT_OVERFLOW_COUNT`, `EVT_SOURCE_ENABLE`,
    `EVT_SNAPSHOT`, `EVT_DATA0`-`3`, `EVT_POP`, `EVT_CLEAR`,
    `EVT_DROP_SOURCE`, `EVT_ARB_STATUS`, `EVT_POP_ERROR_COUNT`).

14. **Genuine, disclosed gap -- not fixed this session, logged for a future
    decision.** Unlike RTL-002/003/004, REG-002 owns no
    `RTL005_EVT_OVERFLOW_STATUS`-equivalent register for RTL-005's own
    *generic* `status_o.event_overflow`/`event_drop_count` pair (the fields
    every module's Appendix B struct template carries for "did my own
    one-deep event-generation register drop a candidate because the
    downstream consumer hadn't accepted the previous one yet"). This pair is
    real and reachable in `dfc_rtl005.sv` (confirmed via a real, forced test
    in `rtl005_integration_tb.sv` Part 6 -- two real CLEAR_ALL-triggered
    self-events with the handshake withheld genuinely set it), but has
    **no REG-002 address at all**, so the host can neither read nor clear it
    -- a real, permanent-until-fixed gap, not something a field-map can
    invent. This is distinct from `EVT_DROP_SOURCE[4]`/`EVT_STATUS.
    SOURCE_DROP` (the ARBITER's own, separately real and host-visible
    per-producer-slot-4 evidence -- see `dfc_rtl005.sv`'s own header for why
    these are two non-redundant layers). Proposed fix, not yet applied or
    approved: a 16th RTL-005-owned register (e.g. `EVT_SELF_OVERFLOW_STATUS`
    at 0x033C) exposing `EVENT_OVERFLOW` (W1C) and `DROP_COUNT` (RO),
    mirroring the RTL0NN_EVT_OVERFLOW_STATUS shape already used for
    RTL-002/003/004.

15. **Real, pre-existing testbench gap found and fixed while checking for
    breakage from RTL-005's own new `dfc_rtl001.sv` ports (rule 8/task item
    9).** `rtl002_integration_tb.sv` and `rtl003_integration_tb.sv` were
    each missing `rtl004_control_o`/`rtl004_status_i` from their
    `dfc_rtl001` instantiation ENTIRELY (not merely stub-tied) -- left as
    floating/undriven inputs since RTL-004's own integration session added
    those ports to `dfc_rtl001.sv` without updating either file (that
    session's own account only mentions checking `dri_transaction_tb.sv`/
    `regbank_smoke_tb.sv`). Found only because this session added a fifth
    pair (`rtl005_control_o`/`rtl005_status_i`) and checked every existing
    `dfc_rtl001` instantiation site directly rather than assuming the
    RTL-004 session's own account was exhaustive. Fixed: both files now
    wire disclosed stubs for both the RTL-004 and RTL-005 pairs, same
    pattern already used for RTL-002/RTL-003 in whichever file isolates a
    different module.

## Toolchain findings

17. **RESOLVED (2026-08-20), two real false starts before the actual fix --
    kept here as a genuine lesson, not smoothed over.** RTL-005's round-
    robin arbiter caused a real `build_ecp5.ps1` timing failure: the first
    `nextpnr-ecp5` run reported **Max frequency 44.21 MHz (FAIL at 50.00
    MHz required)**, with the real critical-path report naming
    `dfc_rtl005.sv:348` -- the per-candidate rotated-index computation --
    directly. Root cause, confirmed from the report: the original code
    computed each of 24 candidates' rotated index (a conditional-subtract,
    i.e. an adder/comparator) INSIDE the same loop that also accumulated
    the priority decision (`if (!push_valid_comb && ...)`), so each
    iteration depended on every earlier one -- 24 sequentially chained
    adder+compare+select stages.
    - **First attempted fix (WRONG, made it WORSE, 38.14 MHz):** split the
      loop into computing all 24 candidates' indices in parallel
      (independent adders, no cross-iteration dependency) followed by a
      separate priority encode. This removed the sequential coupling but
      NOT the real cost: 24 real 5-bit adders (each a chain of CCU2C carry
      cells) is expensive regardless of whether they're chained or
      parallel, and the real, subsequent `build_ecp5.ps1` run proved this
      empirically (a WORSE result), not a fluke -- the same
      `dfc_rtl005.sv` line was still named in the new critical-path report.
    - **Real fix:** replaced per-candidate ARITHMETIC with a REGISTERED
      PRIORITY MASK (`rr_mask_q`), the standard round-robin-arbiter
      technique. Each cycle's arbitration reads only the already-
      registered mask -- two static bitwise ANDs
      (`slot_valid_q & rr_mask_q` / `& ~rr_mask_q`) and two STATIC priority
      encoders (fixed bit positions, no per-candidate dynamic index
      arithmetic) -- genuinely cheap, log-depth boolean logic. The mask
      for the NEXT cycle updates via a single 5-bit increment
      (`ordinary_idx + 1`) feeding one barrel SHIFT
      (`24'hFFFFFF << next_ptr`, muxes, not carry chains) -- one adder and
      one shifter total per cycle, not 24. Confirmed working via a real,
      subsequent `build_ecp5.ps1` run: **62.70 MHz PASS at 50 MHz
      required** (Build ID `20260820_200244`), TRELLIS_COMB 19%/
      TRELLIS_FF 15% utilization. Reconfirmed via a full Icarus regression
      after each of the three code states (9/9 testbenches, 205/205
      checks, unchanged throughout -- this was purely a timing-closure
      issue, never a functional/simulation one). **Lesson for RTL-006
      onward: "parallelize the per-candidate work" is not automatically a
      timing fix if the per-candidate work is itself genuinely expensive
      (real arithmetic) -- check whether the operation can be replaced
      with a cheaper one (here, a registered mask + shift instead of 24
      runtime modular adds) rather than just changing how N expensive
      operations are scheduled.**

18. **A real, transient `nextpnr-ecp5` internal router assertion crash was
    observed once during this session's `build_ecp5.ps1` runs**:
    `ERROR: Assert 'valid_arcs.count(arc)' failed in
    .../nextpnr/common/route/router1.cc:360` followed by
    `ERROR: Routing design failed.` -- occurring on a default (unspecified)
    placement seed run, after routing had already processed ~171,000 of
    ~51,000 (recurring) arcs without full convergence. Confirmed **not** a
    combinational loop (the log contains no "combinational loop" text, the
    check `build_ecp5.ps1` itself already runs before choosing its error
    message) and **not reproducible**: an immediate retry of the exact same
    default invocation (no explicit `-Seed`) completed cleanly
    (Build ID `20260819_210250`, real timing closure at 63.66 MHz), and a
    separate retry with an explicit `-Seed 42` also completed cleanly
    (Build ID `20260819_205626`, 61.49 MHz) -- confirming nextpnr's own
    default seed is not fixed run-to-run on this build, and that this was a
    one-off router-internal robustness limitation tied to one particular
    placement draw, not a property of the design itself. Utilization
    (12% LUT / 7% DFF) is well under half capacity both times, so resource
    congestion is not a plausible explanation either. Logged here as a real,
    disclosed toolchain-robustness finding, not silently ignored -- if this
    recurs more persistently on a future module's build (i.e., every seed
    tried crashes the same way), that would be a much stronger signal
    pointing at an actual design-side congestion/fanout problem worth
    investigating directly, the same way the earlier ABC9 combinational-loop
    investigation was (see PROJECT_CONTINUITY.md Section 4).

## RTL-006 (GPIO Controller) integration

19. **RESOLVED (2026-08-21), same resolution style as items 1/10/11/13.**
    `RTL-006_RevA.md` SS2 states `control_i`/`status_o` are 114/51 bits.
    `RCA-DFC-ARCH-002.md`'s own Appendix B struct tables (the owning
    document, CHTR-DOC-003) gave `dfc_rtl006_control_t` as 122 bits and
    `dfc_rtl006_status_t` as 83 bits, confirmed directly against the real
    struct field tables, not restated from the spec. Resolved in favor of
    ARCH-002 -- `dfc_rtl006.sv` implements the real ARCH-002 widths.

20. **RESOLVED (2026-08-21), approved before implementation, same pattern
    as items 2/7/8/12 (the fifth real instance of this exact gap class --
    exactly as PROJECT_CONTINUITY.md's own lessons-learned predicted).**
    `dfc_rtl006_control_t` (122 bits) had no clear-request field for
    `RTL006_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-002 0x0434 bit 0, a
    real W1C field). Fixed: ARCH-002 grew the struct 122->123 bits, adding
    `rtl006_evt_overflow_status__event_overflow` at the new highest bit
    (122) -- every pre-existing field's bit position confirmed unchanged
    via a real `regenerate.ps1` run. `tools/reggen/rtl006_field_map.json`
    carries the corresponding `control_registers` entry from the start.

21. **A real, previously-undiscovered gap found in RTL-002/003/004's own
    already-shipped `RTLNNN_EVT_OVERFLOW_STATUS` registers while building
    `rtl006_field_map.json` -- logged here, NOT fixed this session (out of
    scope; RTL-006 avoids reproducing it, see below).** Items 2/7/8 closed
    each module's real host-WRITE (clear) path for its own generic
    `EVENT_OVERFLOW`/`DROP_COUNT` pair, but none of the three modules'
    field-maps ever added the matching `status_registers` entry -- confirmed
    directly in the real generated `dfc_config_regbank_regs.sv`: e.g.
    `RTL002_EVT_OVERFLOW_STATUS`'s read value
    (`rtl002_evt_overflow_status_q`) is still wired from the OLD individual
    `rtl002_evt_overflow_status_status_i` port, which `dfc_rtl001.sv` still
    ties to a permanent `'0`. A host READ of any of these three registers'
    `EVENT_OVERFLOW`/`DROP_COUNT` fields therefore always returns zero
    regardless of the module's real internal state, even though the real
    host WRITE (clear) works. This was never caught because
    `rtl002/003/004_integration_tb.sv` each only ever checked the DUT's
    internal `status_o` signal directly (white-box), never a real host
    REGISTER READ of that specific address. `rtl006_field_map.json`'s own
    `status_registers` section maps `RTL006_EVT_OVERFLOW_STATUS.
    EVENT_OVERFLOW`/`DROP_COUNT` directly onto `dfc_rtl006_status_t`'s
    generic `event_overflow`/`event_drop_count` fields, closing this gap
    for RTL-006 from the start -- confirmed via `rtl006_integration_tb.sv`
    Part 6 issuing a real host READ. Backporting the equivalent field-map
    fix to RTL-002/003/004 (each needs one new `status_registers` entry
    mapping its own `RTLNNN_EVT_OVERFLOW_STATUS` to its struct's existing
    `event_overflow`/`event_drop_count` fields, plus a real
    `reggen.py`/`regenerate.ps1` run and a real host-READ check added to
    each module's own integration testbench) is real, disclosed,
    out-of-scope future work for this session.

22. **RESOLVED (2026-08-21), same class as item 5 ("a sibling module's own
    port-catalog nonconformance can surface during a later module's
    integration").** RTL-006's own real ARCH-002 port catalog names its
    `module_enable_i`/`effective_operational_enable_i` producers as
    `RTL-002.module_enable_o[5]`/`RTL-002.effective_operational_enable_o`
    -- both real ports already present in ARCH-002's own RTL-002 port
    catalog table (rows `module_enable_o`/`effective_operational_enable_o`),
    but `dfc_rtl002.sv`, as it existed before this session, implemented
    neither. This was an implementation gap in already-shipped RTL-002, not
    an ARCH-002 document gap (ARCH-002 already specified both ports
    correctly). Fixed by adding both as real outputs on `dfc_rtl002.sv`:
    `module_enable_o` is the real SUBSYS_ENABLE bitmap with mandatory bits
    forced to `SUBSYS_ENABLE_MANDATORY_MASK` (matching the port's own
    documented "mandatory bits fixed, optional bits configurable"
    semantic) ORed with the already-computed `effective_optional_enable`
    wire; `effective_operational_enable_o` is a direct passthrough of the
    already-computed `effective_operational_enable` wire. Every existing
    testbench instantiating `dfc_rtl002` (via `.*` wildcard or explicit
    named ports) was checked and updated for the two new ports, same
    discipline as every prior port addition in this project.

23. **Real, newly-found `extract_registers.py` bug -- cosmetic only, not
    fixed this session (out of scope; logged, not silently worked
    around).** `GPIO_DIR`'s real, compound `Owner` field in
    `RCA-DFC-REG-002.md` (`RTL-001 / RTL-006`, confirmed by direct read of
    the source document) extracts into `dfc_registers_pkg.json`/the real
    generated `regmap_manifest.txt` as `RTL-006 / RTL-024` instead --
    confirmed wrong by direct comparison, not assumed. Every OTHER
    RTL-006-owned register with a plain single-value `Owner` field (e.g.
    `GPIO_CONTROL`, `GPIO_OUT`, `GPIO_RAW_IN`, all `Owner: RTL-006`)
    extracts correctly, isolating this to compound (`A / B`) owner values
    specifically -- `GPIO_DIR` is the only RTL-006 register with a
    compound owner, so this project has no other RTL-006 example to
    triangulate against. Confirmed NOT to affect any functional generated
    behavior: `protection`/`readback`/`access_summary` (the fields that
    actually drive `write_illegal_o`/`protected_o`/forwarding logic) are
    each extracted correctly for `GPIO_DIR` (protection=Yes, matching
    REG-002's real "Protection: Yes" text) -- `owner` is used only in
    `reggen.py`'s own generated comments and `regmap_manifest.txt`, never
    in any functional decode/protection/forwarding logic. Real, disclosed,
    out-of-scope future work: find and fix the compound-owner parsing case
    in `extract_registers.py`, then re-run `regenerate.ps1` and confirm
    `GPIO_DIR`'s owner field reads `RTL-001 / RTL-006` for real.

## RTL-007 (Rotor RPM Monitor) integration

24. **RESOLVED (2026-08-21), approved before implementation, same pattern
    as items 2/7/8/12/20 (the sixth real instance of this exact gap class).**
    `dfc_rtl007_control_t` (135 bits) had no clear-request field for
    `RTL007_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-002 0x2024 bit 0, a
    real W1C field). Fixed: ARCH-002 grew the struct 135->136 bits, adding
    `rtl007_evt_overflow_status__event_overflow` at the new highest bit
    (135) -- every pre-existing field's bit position confirmed unchanged
    via a real `regenerate.ps1` run. `tools/reggen/rtl007_field_map.json`
    carries the corresponding `control_registers` entry, and its
    `status_registers` section closes the RTL-002/003/004-style readback
    gap (item 21) for RTL-007 from the start, same discipline already
    established for RTL-006.

25. **Real, disclosed spec ambiguity -- no functional consequence, not
    fixed (nothing to fix: no field exists to attach a meaning to).**
    `ARCH-VAL-007` (RTL-007's own validation contract) reads "`0 ≤ LOW ≤
    HIGH ≤ 1000`, `HYST ≤ HIGH-LOW`, PPR 1–65535 when enabled, qualification
    0–100 ms, and nonzero timeout when enabled." Every clause maps onto a
    real RTL-007 field except "qualification 0-100 ms" -- confirmed
    directly against `RTL-007_RevA.md` and REG-002's own Rotor RPM block
    (0x2000-0x2028): `ROTOR_EDGE_FILTER.MIN_EDGE_CYCLES` is a raw CORE_CLK-
    cycle count (0-0xFFFFFFFF), not a millisecond value, and no other
    "qualification" concept exists anywhere in this module's real register
    set. Almost certainly carried forward from `ARCH-VAL-006`'s own
    GPIO-specific qualification-time clause (RTL-006's real, distinct
    `GPIO_QUAL_0_3`/`GPIO_QUAL_4_7` millisecond fields) rather than an
    intentional RTL-007 constraint. `dfc_rtl007.sv` implements every other
    clause as a real, live `illegal_config` check and disclaims this one
    specifically in its own header, rather than inventing a meaning for it.

26. **Real, hard-won testbench-authoring lesson, kept here for RTL-008/009
    (Engine RPM Monitor, Pulse/Frequency Monitor) -- both share
    `ARCH-MON-002`'s identical edge-to-edge period measurement, so both
    will need the identical testbench discipline this module's own
    bring-up got wrong twice before getting right.** A testbench helper
    that "produces one rising edge, then waits N more cycles before
    returning" (the natural, obvious way to write a reusable pulse-
    generator task) makes the edge fire on the task's OWN first clock edge
    -- the `N` argument controls the gap to the NEXT edge, not the gap FROM
    whatever edge preceded this call. Calling such a task only ONCE after
    unrelated code (a DRI/SPI transaction, a register write) does NOT
    produce a known, exact inter-edge period -- the real period is
    whatever time has genuinely elapsed since the true previous edge,
    which depends on unrelated transaction timing the test author did not
    account for. Confirmed via two real, distinct simulation failures
    during `rtl007_integration_tb.sv`'s own bring-up: (1) a single such
    call produced a measured RPM wildly different from the intended value
    (a genuinely different period than assumed, not a DUT bug -- traced
    directly to this exact mechanism); (2) even after separating "exact
    back-to-back pairs" (correct for Parts 3-5's precise threshold checks)
    from "one-off single calls" (Parts 7-8's event/irq checks), the
    single-call design still inherited a large, un-budgeted trailing wait
    left over from the PRECEDING pair's own second call (which does not
    return until its full own gap has elapsed AFTER producing its edge),
    making the intended "short gap" edge measure thousands of cycles
    instead. The real fix: a second, distinct helper task
    (`rotor_edge_after`, waits an explicit N cycles, THEN produces the
    edge, THEN returns immediately with no trailing wait) for every
    "one-off, explicit gap from whatever came before" use, keeping the
    original back-to-back-pair task only for "two edges spaced exactly N
    apart, precision required" use. Any future module needing a real,
    simulated periodic/edge-based external input for its own integration
    testbench should design both task shapes from the start, not
    rediscover this the same way twice.

27. **Real, hard-won RTL lesson, kept here for RTL-008/009 for the same
    reason as item 26.** A measurement's "just-completed interval" must be
    read as the LIVE value of whatever free-running counter tracks it,
    never through a registered intermediate copy updated in the same
    always_ff, in the same clock edge, that other logic then reads
    combinationally that same cycle -- the registered copy's own update is
    a nonblocking assignment, not yet visible, so a same-cycle
    combinational reader sees the STALE value one full measurement behind.
    Confirmed via a real simulation failure during this module's own
    bring-up (`dfc_rtl007.sv`'s original `period_ticks_q` register, whose
    very first real use produced a genuine divide-by-zero substitute
    result -- ROTOR_RPM saturated to 0xFFFF -- because the divisor read
    still-zero reset state one full cycle before the real 3000-tick period
    it was supposed to carry ever became visible). Separately, and for the
    same underlying reason: an "accepted-edge" counter that resets to 0 on
    acceptance, then increments once per cycle thereafter, under-reports
    the true elapsed-cycle count by exactly one when read combinationally
    at the moment of the NEXT acceptance (the counter's own "+1 for this
    cycle" is superseded by that cycle's reset before it can apply) --
    resetting to 1 instead of 0 (i.e. "cycles elapsed including this one")
    is the real, confirmed fix, needed with no further per-use-site
    correction anywhere else. Any future module measuring elapsed time
    between two edges/events (RTL-008/009's own period measurement,
    RTL-012's Lost Link elapsed-time tracking, RTL-015's own analogous
    counters) should read the live free-running counter directly wherever
    a "just-elapsed" value is needed, and should audit whether its own
    accepted-event counter needs the same 0-vs-1 reset-value treatment,
    rather than re-deriving this the hard way via a real simulation
    failure.

## RTL-008 (Engine RPM Monitor) integration

28. **RESOLVED (2026-08-21), approved before implementation, same pattern
    as items 2/7/8/12/20/24 (the seventh real instance of this exact gap
    class).** `dfc_rtl008_control_t` (135 bits) had no clear-request field
    for `RTL008_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-002 0x2124 bit 0,
    a real W1C field). Fixed: ARCH-002 grew the struct 135->136 bits,
    adding `rtl008_evt_overflow_status__event_overflow` at the new highest
    bit (135) -- every pre-existing field's bit position confirmed
    unchanged via a real `regenerate.ps1` run. `tools/reggen/rtl008_field_map.json`
    carries the corresponding `control_registers` entry, and its
    `status_registers` section closes the RTL-002/003/004-style readback
    gap (item 21) for RTL-008 from the start, same discipline already
    established for RTL-006/RTL-007.

29. **Real, disclosed spec ambiguity -- no functional consequence, not
    fixed (nothing to fix: no field exists to attach a meaning to). Same
    class as item 25.** `ARCH-VAL-008` (RTL-008's own validation contract)
    reads "`0 ≤ LOW ≤ HIGH ≤ 20000`, `HYST ≤ HIGH-LOW`, PPR 1–65535 when
    enabled, qualification 0–100 ms, and nonzero timeout when enabled."
    Every clause maps onto a real RTL-008 field except "qualification
    0-100 ms" -- confirmed directly against `RTL-008_RevA.md` and REG-002's
    own Engine RPM block (0x2100-0x2128): `ENGINE_EDGE_FILTER.MIN_EDGE_CYCLES`
    is a raw CORE_CLK-cycle count, not a millisecond value, and no other
    "qualification" concept exists anywhere in this module's real register
    set -- the identical, almost-certainly-copy-forward gap already logged
    for RTL-007. `dfc_rtl008.sv` implements every other clause as a real,
    live `illegal_config` check and disclaims this one specifically in its
    own header, same as `dfc_rtl007.sv`.

30. **Real, hard-won testbench-authoring lesson, found and fixed during
    this module's own bring-up -- kept here for RTL-009 (Pulse/Frequency
    Monitor), which shares this identical hysteretic mode-selection
    mechanism.** `rtl008_integration_tb.sv`'s first draft drove
    back-to-back pulse pairs with 100-250 CORE_CLK-cycle gaps throughout
    (Parts 2-5, 9, 11) to keep RPM values inside the engine's own
    8,000-12,000 test range. This genuinely, silently tripped
    ARCH-MON-002's own hysteretic period/count-mode switch (2 CONSECUTIVE
    accepted periods under 1,000 CORE_CLK cycles switches the module from
    period mode to count mode, after which per-edge commits stop firing
    entirely -- commits only happen on the much slower 100,000-cycle
    count-mode gate instead): the second call of the very first
    back-to-back pair (Part 2, both calls 150 cycles apart) satisfied this
    condition, silently switching RTL-008 into count mode and freezing
    every subsequent RPM/PERIOD_TICKS/event/irq check at Part 2's own
    baseline value for the rest of the test -- confirmed via a real
    simulation failure (11 of 47 checks failing, every failure from Part 3
    onward) that was traced directly to this mechanism, not a DUT bug (a
    clean re-run of `dfc_rtl008.sv` unchanged, with every gap rescaled to
    1000+ CORE_CLK cycles -- 1500/2500/1200/6000, choosing PPR=200 instead
    of RTL-007's PPR=2000 to land in the engine's own higher RPM range at
    those larger, mode-safe periods -- passed all 47 checks). Single,
    non-consecutive one-off short periods (e.g. `engine_edge_after(50)` for
    a HIGH-threshold commit) remain safe and were kept, matching
    `rotor_edge_after(50)`'s identical, already-proven-safe usage in
    `rtl007_integration_tb.sv` -- the real hazard is specifically TWO
    CONSECUTIVE accepted periods both under 1,000 cycles, not short periods
    in isolation. Any future module sharing ARCH-MON-002's mode-selection
    mechanism (RTL-009) should choose test period values with this
    threshold in mind from the start, not rediscover it the hard way via a
    real simulation failure a second time.

31. **RESOLVED (2026-08-21), a real, three-part timing-closure
    investigation into already-shipped, already-verified RTL-007 --
    approved before any change to that file, per this project's own
    docs-governance discipline for touching prior work.** RTL-007's own
    real timing margin (52.87 MHz, the narrowest of any module so far --
    PROJECT_CONTINUITY.md's own lessons-learned explicitly flagged this as
    "worth a closer look if RTL-008/009's own, architecturally-identical
    dividers compound this further") was NOT enough headroom to absorb
    RTL-008 duplicating RTL-007's identical, genuinely expensive per-cycle
    arithmetic. Confirmed as a real design-margin problem, not placement
    luck, before touching any RTL: 4 real `build_ecp5.ps1` attempts on the
    original code (default, `-noabc9`, and two different `-Seed` retries)
    all genuinely failed between 43-49 MHz, never reaching 50 -- the same
    "retry before assuming a real problem" discipline already established
    in this project (item 7) was followed, and it correctly ruled out
    placement/ABC9 artifacts before any RTL change was proposed.
    Three sequential real fixes were needed, applied identically to both
    `dfc_rtl007.sv` and `dfc_rtl008.sv`, each found by actually re-running
    `nextpnr-ecp5` and reading its new critical path report -- not guessed,
    and not all found or fixed in one pass:
    1. **Edge-qualification comparator.** `cycles_since_accepted_q >=
       ctl_min_edge_cycles` -- a full 32-bit magnitude comparison between
       two live-varying values -- synthesized as a real, deep CCU2C carry
       chain that was the actual worst path (21.16 ns total, confirmed via
       the real critical path report naming `dfc_rtl007.sv`'s own edge-
       qualification line). Fixed the same architectural way as RTL-005's
       own round-robin-arbiter timing fix (item 17): replaced the per-cycle
       ARITHMETIC comparison with a cheap EQUALITY test plus a registered
       sticky bit (`min_edge_met_q`) -- the counter increments by exactly 1
       every cycle it doesn't reset, so it passes through every integer
       value on its way up, including the threshold itself, at the
       identical cycle the original `>=` first held (no off-by-one).
       **Disclosed, narrow, approved behavioral difference from the
       original:** a host write that LOWERS MIN_EDGE_CYCLES mid-flight,
       strictly after the live counter has already passed the new, lower
       value, does not retroactively qualify until the next accepted edge
       (the original, live combinational comparator would have reacted the
       same cycle) -- not exercised by any real test in this project.
    2. **Divider multiply resource sharing, made explicit.** This fix alone
       did not close timing (confirmed via a real subsequent build, 48.48
       MHz): the two mutually-exclusive divider multiplies (period mode's
       `cycles_since_accepted_q * ctl_ppr`, count mode's `edge_count_q *
       30,000`) were originally two independent expressions muxed AFTER
       multiplying; Yosys's own automatic resource-sharing pass merged them
       into one physical unit whose generated input-selection muxing was
       itself expensive. Made explicit at the RTL level instead (mux the
       multiply's own inputs first) -- a pure refactor, bit-for-bit
       identical result for any mode. **A real, self-found regression in
       this fix's own first draft:** the second multiply operand was
       accidentally widened from 16 to 32 bits (matching the first
       operand's width for no real reason), turning a 32x16 multiply into
       a full 32x32 one and making timing measurably worse before the
       width mistake was caught and corrected back to 16 bits.
    3. **Divider multiply, pipelined.** Even the correctly-sized,
       explicitly-shared 32x16 multiply feeding directly into a register in
       the same cycle it's selected remained the real critical path (8.83
       ns logic + 11.80 ns/12.69 ns routing across two further real
       nextpnr runs) -- a genuinely expensive operation, duplicated across
       two modules, that no amount of input restructuring alone could make
       cheap enough. Fixed by pipelining the multiply into its own,
       isolated register-to-register state (`MEAS_MULT`, inserted between
       `MEAS_IDLE` and `MEAS_RUN`): operands are captured into registers
       the cycle a commit trigger arrives, the multiply itself runs alone
       the following cycle, and only then does `MEAS_RUN` begin -- adding
       exactly one CORE_CLK cycle of latency (65 cycles total instead of
       64, ~1.3 us at 50 MHz instead of ~1.28 us), a real but functionally
       and numerically IDENTICAL-result change already comfortably covered
       by every testbench's own generous divider-latency margin (100
       CORE_CLK cycles). **A real, easy-to-miss second instance of the same
       problem, found by auditing every entry point rather than trusting
       the "obvious" one alone:** the divider's own pre-existing "a new
       trigger arrived while busy, latch it as a pending redo" path also
       fed a multiply directly into a register in the exact same way, and
       needed the identical pipeline treatment (funneled through the same
       new `MEAS_MULT` state) to actually be closed, not just the
       first-trigger-while-idle path.
    Verified end-to-end after all three fixes: a full Icarus regression
    (12/12 testbenches, 368/368 checks, unchanged throughout -- confirming
    all three fixes are pure timing/refactor changes with no functional
    regression except the one disclosed, approved MIN_EDGE_CYCLES
    mid-flight-lowering edge case), a real `gate.ps1` run (lint/sim/formal
    bmc+prove/coverage all clean), and a real `build_ecp5.ps1` run (Build
    ID `20260821_220624`, **55.84 MHz PASS at 50 MHz required** -- a wider
    margin than RTL-007 alone ever had (52.87 MHz), not just a narrow
    recovery), 4/156 MULT18X18D (2%), TRELLIS_COMB 22%/TRELLIS_FF 17%
    utilization. **Lesson for RTL-009 (Pulse/Frequency Monitor, which
    shares this identical architecture across two channels in a single
    module) and beyond: a module's own real timing margin at first
    shipment is not a permanent property -- a narrow margin (RTL-007's
    52.87 MHz) is a real, standing risk for every later module that
    duplicates its architecture, and closing it can require multiple
    sequential, independently-necessary fixes (comparator, then multiplier
    sharing, then multiplier pipelining), each only discoverable by
    actually re-running the real toolchain and reading its new critical
    path report -- not something to budget as a single quick fix.**

## RTL-009 (Pulse/Frequency Measurement) integration

32. **RESOLVED (2026-08-22), approved before implementation, same pattern
    as items 2/7/8/12/20/24/28 (the eighth real instance of this exact gap
    class).** `dfc_rtl009_control_t` (334 bits) had no clear-request field
    for `RTL009_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-002 0x2250 bit 0,
    a real W1C field). Fixed: ARCH-002 grew the struct 334->335 bits,
    adding `rtl009_evt_overflow_status__event_overflow` at the new highest
    bit (334) -- every pre-existing field's bit position confirmed
    unchanged via a real `regenerate.ps1` run. `tools/reggen/rtl009_field_map.json`
    carries the corresponding `control_registers` entry, and its
    `status_registers` section closes the RTL-002/003/004-style readback
    gap (item 21) for RTL-009 from the start, same discipline already
    established for RTL-006/007/008.

33. **Real, disclosed gap -- logged, not silently resolved (nothing to fix:
    no field exists to attach a meaning to, and inventing one would violate
    CHTR-DOC-006).** RTL-009's two channels share ONE event ID (0x0032) and
    ONE pending slot (a single `evt_valid_o`/`evt_ready_i`/`evt_record_o`
    triple per the Architecture port catalog, not one pair per channel).
    Neither REG-002's own C.7 row for 0x0032 nor `dfc_event_record_t` itself
    (Appendix B.1: timestamp/event_id/source_id/flags/event_data, no
    channel field anywhere) allocates any bit to indicate WHICH channel
    produced a given record. `dfc_rtl009.sv` does not invent a channel
    indicator in the currently-reserved-zero upper byte of `event_data` --
    a host observing an 0x0032 record must correlate against
    `PULSE0_STATUS`/`PULSE1_STATUS`'s own independently-readable per-channel
    sticky bits to determine origin. Zero functional consequence for this
    module's own conformance (the event log has always been a diagnostic
    aid layered on top of the real, independently-host-readable per-channel
    status registers in this project, e.g. RTL-005/007/008's own identical
    relationship between their event stream and their real status
    registers).

34. **Real, disclosed spec ambiguity -- no functional consequence, not
    fixed (nothing to fix: no field exists to attach a meaning to). Same
    class as items 25/29, the third real instance.** `ARCH-VAL-009`
    (RTL-009's own validation contract) reads "Each Q17.15 threshold lies
    from 0.5 through 100000 Hz, LOW <= HIGH, HYST <= HIGH-LOW,
    qualification 0-100 ms, and nonzero timeout when enabled." Every clause
    maps onto a real RTL-009 field except "qualification 0-100 ms" --
    confirmed directly against `RTL-009_RevA.md` and REG-002's own
    Pulse/Frequency block (0x2200-0x2254): `PULSEn_EDGE_FILTER.
    MIN_EDGE_CYCLES` is a raw CORE_CLK-cycle count, not a millisecond
    value, and no other "qualification" concept exists anywhere in this
    module's real register set -- the identical, almost-certainly-copy-
    forward gap already logged for RTL-007/008. `dfc_rtl009.sv` implements
    every other clause as a real, live `illegal_config` check per channel
    and disclaims this one specifically in its own header, same as
    `dfc_rtl007.sv`/`dfc_rtl008.sv`.

35. **Real, hard-won testbench-authoring lesson, found and fixed during
    this module's own bring-up (`rtl009_integration_tb.sv`'s Part 5 and
    `rtl024_skeleton_tb.sv`'s own RTL-009 section) -- kept here for any
    future module sharing ARCH-MON-002's count-mode gate or this project's
    own back-to-back-pulse-pair testbench idiom.**
    - **Triggering the count-mode switch needs exactly THREE pulses at a
      sub-1,000-cycle gap, not two.** The first accepted edge after
      `have_prior_edge_q` is false only ever sets that flag -- no period is
      measured yet, so it cannot count toward the "two consecutive periods
      under 1,000 cycles" hysteresis test. The earliest a genuine two-in-a-
      row classification can complete is the edge that measures the
      SECOND real period, i.e. the third edge overall.
    - **An edge landing exactly on the 100,000-cycle count-mode gate
      boundary is genuinely NOT counted into that window's `edge_count`.**
      `dfc_rtl009.sv`'s own gate-counter logic resets `edge_count_q` to 0 on
      the exact cycle `gate_counter_q` reaches 99,999, regardless of
      whether an edge also lands that same cycle -- reset wins over
      increment on a real tie. A test that drives exactly 100 pulses at a
      1,000-cycle gap after the switch (expecting the 100th to complete the
      window) will find only 99 were ever counted; the 100th coincides with
      the automatic gate expiry and is dropped. The gate expiry itself is
      unconditional on `pulse_i` (a free-running counter), so a test needs
      only enough pulses to cover the window, then a plain wait for the
      commit to fire on its own.
    - **A missing settle delay (`#1;`) between the end of a back-to-back
      pulse pair's wait loop and re-asserting the pin for a SUBSEQUENT
      pulse shifts the measured period by exactly one cycle**, confirmed via
      a real, observed `PULSE0_PERIOD_TICKS` reading of 1999 instead of the
      intended 2000 in `rtl024_skeleton_tb.sv`'s own first draft (which
      inlined the pulse sequence instead of calling a shared task like
      `rotor_pulse`/`engine_pulse`/`ch_pulse`, all of which already include
      this exact settle delay before returning -- confirmed by inspection
      once the discrepancy was found, not the origin of the bug). This
      one-cycle error is invisible to PPR-scaled RPM checks (RTL-007/008's
      own rounding happens to land on the same integer RPM whether the real
      gap is N or N-1 cycles for the specific values those files chose),
      which is exactly why it was never caught there -- RTL-009's exact
      Q17.15 division has no such rounding slack, which is what actually
      surfaced it. Any future module's testbench inlining a pulse sequence
      rather than calling a shared task must include this same trailing
      settle delay.

## RTL-010 (Sensor Monitor Interface) integration

36. **RESOLVED (2026-08-22), approved before implementation, same pattern
    as items 2/7/8/12/20/24/28/32 (the ninth real instance of this exact
    gap class).** `dfc_rtl010_control_t` (345 bits) had no clear-request
    field for `RTL010_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-002 0x235C
    bit 0, a real W1C field). Fixed: ARCH-002 grew the struct 345->346
    bits, adding `rtl010_evt_overflow_status__event_overflow` at the new
    highest bit (345) -- every pre-existing field's bit position confirmed
    unchanged via a real `regenerate.ps1` run. `tools/reggen/rtl010_field_map.json`
    carries the corresponding `control_registers` entry, and its
    `status_registers` section closes the RTL-002/003/004-style readback
    gap (item 21) for every external RTL-010 register from the start, same
    discipline already established for RTL-006 through RTL-009.

37. **Resolved without an ARCH-002 edit, same resolution style as items
    1/10/11/13/19/22.** `RTL-010_RevA.md` SS1 describes Appendix F.3 index 9
    as "0-3 sensor 0 low/high/stale/invalid, and by the documented pattern
    4-7 sensor 1 same order, 8 event-slot overflow". ARCH-002's own real F.3
    table (the owning document, CHTR-DOC-003) instead gives "0-3 sensor 0
    low/high/stale/invalid; 8-11 sensor 1 in the same order; 16 update
    accepted; 17 update rejected; 18 event-slot overflow" -- a genuinely
    different bit layout, not merely a restatement. Resolved in favor of
    ARCH-002; `dfc_rtl010.sv` implements ARCH-002's real layout (including
    the two module-wide update-accepted/update-rejected condition bits
    RTL-010_RevA.md's own summary omits entirely), not RTL-010_RevA.md's
    own restated (and here, wrong) summary of it.

38. **Real, disclosed gap -- logged, NOT fixed this session (a real
    architectural dependency on a module that does not exist yet, out of
    scope for RTL-010's own integration).** `ARCH-MON-007`/`ARCH-RTL010-001`
    both describe a "host commit precedes ROUTED commit" priority, implying
    RTL-021 (Databus Routing Engine) can also commit a sensor update.
    ARCH-002's own 16-port catalog for RTL-010 gives this module NO port at
    all for a routed update -- unlike `event_condition_enable_i`/
    `irq_condition_enable_i` (real ports simply tied to a disclosed stub,
    item 6), there is no port here to tie off in the first place; RTL-021
    itself does not exist yet either. `dfc_rtl010.sv` therefore implements
    ONLY the real, real-port host-commit half of `ARCH-MON-007`/
    `VP-MON-007`: `SENSOR_UPDATE_SELECT`/`_VALUE`/`_META`/`_COMMIT` always
    wins by construction, because nothing else can ever compete for the
    same cycle -- confirmed via `rtl010_integration_tb.sv`'s own atomicity
    check (Part 7), which explicitly notes it cannot exercise the "host
    wins a same-cycle conflict against a routed commit" half of
    `VP-MON-007` for the same reason. No routed-commit input is invented
    (CHTR-DOC-006). **Real, disclosed future work:** when RTL-021 is
    implemented, ARCH-002 will need a real port added to RTL-010's own
    16-port catalog (and REG-002's register set may need a real staging
    path distinct from the host's own `SENSOR_UPDATE_*` registers, since
    REG-002 currently defines only one staging area) before the routed half
    of `VP-MON-007` can be exercised end-to-end.

39. **Real, disclosed design interpretations -- no ARCH-002 edit needed,
    each forced by a genuine gap in the owning documents rather than a
    guess (CHTR-DOC-006).**
    - **Recovery shares its own condition's mask bit.** RTL-007/008/009's
      own F.3 rows each give "recovery" its OWN condition-mask bit, separate
      from "low"/"high". RTL-010's F.3 row (index 9, see item 37) does NOT
      -- no standalone recovery bit exists anywhere in it, even though
      Appendix C.7's own 0x0033 event-subtype row lists "5 recovery" as a
      distinct subtype. Since no field exists to attach a separate
      recovery-enable meaning to, `dfc_rtl010.sv` has each condition's own
      mask bit (`SENSORn_EVENT_IRQ_CFG.EVENT_ENABLE`/`IRQ_ENABLE[i]`,
      `event_condition_enable_i`/`irq_condition_enable_i[F3 bit]`) gate BOTH
      that condition's entry (LOW/HIGH/STALE/INVALID) and its own exit
      (packed as the shared RECOVERY subtype).
    - **Layered enable gating, derived directly from Appendix F.3's own
      preamble formula.** `SENSOR_CONTROL.ENABLE` (with `module_enable_i`)
      gates whether the module does ANY processing at all. `SENSOR_CONTROL.
      EVENT_ENABLE`/`IRQ_ENABLE` (module-wide) serve as `MODULE_EVENT_ENABLE`/
      `MODULE_IRQ_ENABLE` only for the two F.3 conditions with no channel
      master (update-accepted/update-rejected, bits 16/17).
      `SENSORn_EVENT_IRQ_CFG.EVENT_ENABLE`/`IRQ_ENABLE[3:0]` (ARCH-MON-007's
      own "four independent... bits [0]-[3]") REPLACE (not AND with) the
      module-wide enables for their own four per-channel F.3 bits, per the
      preamble's literal "the corresponding channel master replaces
      MODULE_*_ENABLE" text.
    - **Commit accept/reject precondition.** REG-2314's own generic WO-CMD
      boilerplate ("unmet precondition ... rejects") plus ARCH-VAL-010's
      "commit requires all staged update members" are read together as: the
      precondition is `active` (module must be enabled for a commit to take
      effect), and "all staged update members" describes the commit's
      ATOMICITY (value/valid/source/sequence/age=0 all replace together,
      never partially -- ARCH-MON-007's own text), not an additional
      "has-been-staged" completeness check (no such tracking field exists
      anywhere in the real register set).
    - **Continuous threshold evaluation, not commit-gated.** Unlike
      RTL-007/008/009 (whose measured value only changes at a divider APPLY
      cycle), RTL-010's `THRESH_LOW`/`THRESH_HIGH`/`HYSTERESIS` are plain RW
      registers a host can change at any time independent of a value
      commit. `ARCH-RTL010-001`'s fixed pipeline order is read as running
      every active cycle, not only on a commit cycle -- a value held steady
      across a live threshold/hysteresis change is re-evaluated the very
      next cycle, matching `ARCH-MON-006`'s own live "enters at / exits at"
      wording. All four interpretations are proven via real, dedicated
      checks in `rtl010_integration_tb.sv` (channel independence, signed
      boundary values, hysteresis enter/exit at the exact boundary, the
      disabled-module commit-rejection path, and the age/stale model).

40. **RESOLVED (2026-08-22), a real timing regression in an already-shipped
    file, approval sought and given before touching it (per this session's
    own task instructions).** `build_ecp5.ps1` failed timing TWICE in a
    row with the IDENTICAL result (47.98 MHz, FAIL at 50 MHz required;
    3.38 ns logic / 17.47 ns routing) on two independent place-and-route
    runs (different default seeds) after RTL-010 was added -- confirmed
    genuinely reproducible, not placement variance, before touching any
    RTL (same "retry before assuming a real problem" discipline as items
    7/18). The failing critical path was entirely inside the already-
    shipped `dfc_rtl024_spi_bridge.sv` (`word_idx_q`/`exec_write_q`/
    `rdata_words_q` chain) -- it does not touch any RTL-010 signal.
    Device utilization was only 29-30% COMB / 19% FF (not resource-
    exhausted), so RTL-010's added die area evidently consumed just enough
    routing headroom to break an already-marginal SPI-bridge path, the
    same general class as RTL-007/008's own timing-margin regression (item
    31), but here in a different already-shipped file. Root cause: this
    file's own `B_WORD` state (SPI response building) read the variable-
    index `rdata_words_q[build_word_idx_q]` array FOUR times combinationally
    in the same cycle, each feeding directly into a chained `crc16_update()`
    call and into `rsp_bytes_q` -- the identical underlying principle this
    file's own header already documented fixing once before on the WRITE
    side ("too much work committed in one cycle... manifesting as
    placement/routing spread"), just never applied to this READ side.
    Fixed the same structural way: `B_WORD` split into `B_WORD_FETCH` (a
    plain registered array read, `build_word_data_q <= rdata_words_q[
    build_word_idx_q]`, no combinational consumer that cycle) and
    `B_WORD_CRC` (the CRC/byte-packing work, sourced from the now-plain
    `build_word_data_q` register). Adds one more CORE_CLK cycle per word
    (32 cycles total for a full 16-word response instead of 16) --
    negligible against DFC-INTF-0013's 100kHz-10MHz SPI rate, same
    justification already established for the write-side fix. Verified
    end-to-end: a full regression (14/14 testbenches, 508/508 checks,
    unchanged -- confirming this is a pure timing/refactor change with no
    functional regression, `spi_bridge_tb.sv` itself included), a real
    `gate.ps1` run (lint/sim/formal bmc+prove/coverage all clean), and a
    real `build_ecp5.ps1` run (Build ID `20260822_220658`, **50.30 MHz
    PASS at 50 MHz required**, TRELLIS_COMB 29%/TRELLIS_FF 19%
    utilization, no `--timing-allow-fail` needed). **Lesson for RTL-011
    onward, same spirit as item 31's own warning:** this margin (50.30 MHz)
    is narrow -- under 1% headroom above the 50 MHz requirement. A future
    module adding meaningful new combinational depth or die area should
    expect this margin to need attention again, the same way RTL-007's own
    narrow margin correctly predicted RTL-008's later regression.

41. **RESOLVED (2026-08-23), a real architectural correction to
    `dfc_rtl024_spi_bridge.sv`, not a third reactive timing pipeline stage
    stacked on top of items above -- requested and approved before
    implementation.** Both prior fixes to this file (the write-side
    capture staging documented in this file's own former "TIMING FIX"
    comment, and TIMING FIX #2/item 40 above on the read side) paid a
    real pipeline-latency cost to route AROUND a genuine root cause they
    never actually removed: `rdata_words_q [0:15]`, a 16-entry register
    array addressed by a *variable* index on both sides
    (`word_idx_q` writing it during DRI-read capture, `build_word_idx_q`
    reading it during response building) -- a 16-way write demux and a
    16-way read mux, i.e. genuine RAM-shaped hardware, for access that a
    direct reading of both index variables confirms is actually strictly
    sequential: each starts at 0, advances by exactly 1 per use, counts up
    to the transaction's own word count (1-16), and resets -- neither ever
    jumps to an arbitrary position. No genuine random-access need was
    found anywhere in the file for this array; the two prior fixes only
    ever pipelined around the resulting mux's routing cost, never removed
    it, which is exactly why RTL-010's own timing regression (item 40)
    happened at all: each new module's die area eats into the same fixed
    routing budget this mux keeps consuming.
    - **Replaced the array with a genuine 16-deep shift register**
      (`rdata_shift_q`), one single write process (previously the array
      was written from the executor's own process and read from the
      builder's; the new design needs exactly one writer, so both sides'
      shifting now live in one dedicated `always_comb`/`always_ff` pair
      declared next to the response builder). Insertion is always at a
      FIXED position (index 0); every other position is a static
      point-to-point shift chain (`rdata_shift_q[i] <= rdata_shift_q[i-1]`)
      -- no address decode of any kind, so there is no mux left to place
      or route. The former `capture_data_q`/`capture_idx_q`/
      `capture_pending_q` staging registers (which existed only to
      tolerate the now-removed write-side mux) are gone entirely, along
      with the array itself.
    - **Alignment scheme, the one genuinely new piece of design this fix
      needed:** a transaction can capture anywhere from 0 to 16 real
      words, so the FIRST word captured does not sit at a fixed shift
      position by itself -- after N real shifts it is at position (N-1),
      which depends on N. Fixed the same way a shift-register FIFO always
      handles this: always perform exactly 16 total shifts before the
      first real read. A new response-builder state, `B_ALIGN`, pads with
      don't-care zero-shifts for whatever fewer than 16 words were really
      captured (a new dedicated counter, `shift_count_q`, tracks the real
      count per transaction). After exactly 16 total shifts, the first
      captured word is ALWAYS at `rdata_shift_q[15]` -- one single, fixed,
      architecturally-constant read point, regardless of the transaction's
      real word count. `B_ALIGN` is skipped entirely (straight to
      `B_WORD_FETCH`) when `shift_count_q` is 0 (a WRITE, or a transaction
      rejected before any word was captured) or 16 (a full 16-word READ),
      since both already need zero padding.
    - **`B_WORD_FETCH`/`B_WORD_CRC` deliberately stay split**, exactly as
      item 40 left them -- that split's own remaining value (a clean
      pipeline cut between the register read and the 4-round CRC chain)
      doesn't depend on whether a mux used to feed it, and un-splitting
      them was no part of what this fix was asked to do. `B_WORD_FETCH`
      now loads `build_word_data_q` from the fixed `rdata_shift_q[15]`
      point (and the dedicated shift process advances the register the
      same cycle), instead of an indexed array read.
    - **New, bounded, justified latency, same discipline as both prior
      fixes' own accounting:** `B_ALIGN`'s worst case is 15 cycles (a
      1-word transaction; 0- and 16-word transactions skip it). Combined
      worst-case builder latency: 1 (`B_IDLE`) + 15 (`B_ALIGN`) + 32
      (`B_WORD_FETCH`/`B_WORD_CRC`, unchanged from item 40) + 1
      (`B_FINISH`) = 49 CORE_CLK cycles = 980 ns @ 50 MHz -- still
      comfortably inside DFC-INTF-0024's 0-2 whole-byte wait-fill
      allowance at the fastest legal 10 MHz SCLK (1600 ns budget, the
      same reference point both prior fixes used), and far more margin at
      any slower legal SCLK rate. The write-side capture latency is
      actually LOWER than before (the former 1-cycle staging delay is
      gone, since the shift's destination is now fixed rather than
      variable-indexed) -- this fix is cheaper on that side, not just
      safer, matching what was asked.
    - **Verified the fix actually removed the mux, not just that timing
      happened to pass**, by direct comparison of the real
      `nextpnr-ecp5` `Info: Device utilisation:` block between the
      immediately-preceding real build (`20260822_220658`, item 40's own
      result) and this fix's real build (`20260823_081313`), same
      toolchain, same target:
      | | before (`...220658`) | after (`...081313`) |
      |---|---|---|
      | TRELLIS_COMB | 25044/83640 | 24865/83640 |
      | TRELLIS_FF | 16432/83640 | 16406/83640 |
      | Max frequency (final, post-route) | 50.30 MHz PASS | 53.69 MHz PASS |

      TRELLIS_COMB genuinely dropped by 179 cells and TRELLIS_FF by 26 --
      both real, absolute-count reductions in synthesized logic, not
      merely an unchanged design getting a luckier placement (both builds
      used `build_ecp5.ps1`'s own default, unseeded invocation). The
      rounded percentages both still read 29%/19% -- confirming why a
      percentage alone is not sufficient evidence and the raw counts had
      to be compared directly, exactly as this fix's own task instructions
      required.
    - Verified end-to-end: a full Icarus regression (14/14 testbenches,
      **508/508 checks, unchanged** -- confirming this is a pure
      architectural refactor with no functional regression,
      `spi_bridge_tb.sv` and `rtl024_skeleton_tb.sv` both included,
      counted by hand from the real per-testbench totals:
      12+12+16+28+30+24+37+35+44+47+60+50+100+13=508); a real `gate.ps1`
      run (lint/sim/formal `bmc`+`prove`/coverage all clean, coverage
      unchanged at 120/353 registers referenced -- expected, since this
      fix touches no register-visible behavior); and the real
      `build_ecp5.ps1` run above (Build ID `20260823_081313`, **53.69 MHz
      PASS at 50 MHz required** -- a wider margin than item 40's own
      50.30 MHz, not just a narrow recovery). **Lesson for RTL-011
      onward, superseding item 40's own "expect this margin to need
      attention again" warning with a more durable fix than another
      pipeline stage would have been:** where a variable-index array
      turns out to be addressed only sequentially (confirm this directly
      by reading the index variables' own update logic before assuming
      it), replacing the array with a shift register removes the
      mux/demux at its root instead of buying temporary headroom by
      pipelining around it -- a real margin improvement, not merely a
      deferred version of the same regression RTL-007/008 and RTL-010
      already hit twice.

42. **Real, disclosed, out-of-scope observation found while confirming
    item 41's own sequential-access claim -- NOT fixed, since this
    session's task named only `word_idx_q`/`build_word_idx_q`/
    `rdata_words_q` specifically, not this sibling structure.**
    `data_words_q [0:15]` (the OUTGOING write-data array, filled
    sequentially by `data_word_idx_q` during F_DATA frame collection and
    read sequentially by `word_idx_q` during `X_ISSUE`'s DRI writes) has
    the identical shape as the array item 41 just replaced -- a 16-entry
    register array addressed by indices that, by the same direct reading
    applied to `rdata_words_q`'s own indices, also appear to be purely
    sequential. This was deliberately left untouched: it was not named in
    the task that produced item 41's fix, and converting it was never
    asked for. Logged here so a future session doesn't need to
    rediscover the parallel -- if `data_words_q` is ever implicated in a
    real timing finding the way `rdata_words_q` was (items 40/41 and the
    original write-side fix), the same shift-register replacement is the
    candidate fix, subject to the same direct-reading confirmation this
    item's own sibling fix required before touching anything.

## RTL-011 (System Health Monitor) integration

43. **RESOLVED (2026-08-26), approved before implementation, same pattern
    as items 2/7/8/12/20/24/28/32/36 (the tenth real instance of this exact
    gap class).** `dfc_rtl011_control_t` (121 bits) had no clear-request
    field for `RTL011_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-2430 bit 0,
    a real W1C field). Fixed: ARCH-002 grew the struct 121->122 bits,
    adding `rtl011_evt_overflow_status__event_overflow` at the new highest
    bit (121) -- every pre-existing field's bit position confirmed
    unchanged via a real `regenerate.ps1` run. `tools/reggen/
    rtl011_field_map.json` carries the corresponding `control_registers`
    entry, and its `status_registers` section closes the RTL-002/003/004-
    style readback gap (item 21) for every external RTL-011 register from
    the start, same discipline already established for RTL-006 through
    RTL-010.

44. **Resolved without an ARCH-002 edit, same resolution style as items
    1/10/11/13/19/22/37.** `RTL-011_RevA.md` SS1/SS4 both describe this
    module's System Health block as "13 registers." REG-002's own SS23
    block-summary table (the owning document, CHTR-DOC-003) says 15 and
    lists all 15 (`HEALTH_CONTROL`, `HEALTH_RAW_IN`, `HEALTH_SYNC_IN`,
    `HEALTH_QUAL_IN`, `HEALTH_ACTIVE`, `HEALTH_STICKY`, `HEALTH_POLARITY`,
    `HEALTH_FAULT_ENABLE`, `HEALTH_EVENT_ENABLE`, `HEALTH_IRQ_ENABLE`,
    `HEALTH_QUAL_0_3`, `HEALTH_QUAL_4_7`, `RTL011_EVT_OVERFLOW_STATUS`,
    `HEALTH_QUALIFICATION`, `HEALTH_STATUS`). Resolved in favor of REG-002
    -- `dfc_rtl011.sv` implements and forwards all 15.

45. **Real, disclosed architectural finding, confirmed by direct algebraic
    analysis before writing the integration testbench, not discovered by a
    failing test guess -- logged, not silently worked around.** For a
    single-BIT-per-channel input (`health_i`'s real width per ARCH-002's
    own 17-port catalog), the qualification-ATTEMPT-FAILURE condition
    ARCH-MON-008 defines ("no qualified-state commit occurs within
    `min(255, 4 x Q)` consecutive 1 ms samples") is mathematically
    UNREACHABLE via any external drive pattern, static or dynamically
    reconfigured. Reasoning: for a 1-bit signal there are only two possible
    sample values, so the stability run-length's "new, different candidate"
    branch is dead code after an attempt's own first disagreeing sample --
    every sample either matches the current qualified value (cleanly
    ending the attempt, no failure) or matches the already-tracked
    candidate (advancing the SAME run toward commit). A continuous
    single-candidate disagreement therefore always accumulates its
    run-length in lockstep with the independent attempt counter, and since
    `attempt_limit = min(255, 4xQ)` is provably `>= Q` for every legal Q
    (0-255) -- strictly greater for Q<255, exactly equal only at the single
    boundary point Q=255 -- the run-length COMMIT condition is always
    satisfied at or before the attempt counter could ever reach its own
    failure threshold. `dfc_rtl011.sv` fixes a related, genuine same-cycle
    race this analysis surfaced (at the sole Q=255 tie, both conditions
    would otherwise fire the identical ms_tick sample; a `commit_this_cycle`
    term makes the tie resolve as a commit, not a failure, per the spec's
    own "if no commit occurs" wording) -- but the underlying reachability
    finding itself is a property of ARCH-MON-008's own algorithm applied to
    a 1-bit signal, not an implementation defect, and no RTL/spec change is
    proposed. `rtl011_integration_tb.sv` accordingly cannot exercise a
    genuine, externally-triggered `HEALTH_STICKY.QUALIFICATION_FAILURE`
    assertion -- the mechanism itself (both counters, the clear-request
    field, the F.3 condition-mask gating, and the
    `HEALTH_QUALIFICATION.IN_PROGRESS` live readback) is still real and,
    per this analysis, correct by construction, just not reachable from
    outside this module for a 1-bit channel -- same class of disclosed
    testing-reachability gap as RTL-010's own untestable routed-commit half
    of VP-MON-007 (item 38).

46. **RESOLVED (2026-08-26), same class of gap RTL-002/004/009/010 each hit
    before it (PROJECT_CONTINUITY.md Section 2's own standing lesson).**
    The first `build_ecp5.ps1` attempt after RTL-011 was added failed
    cleanly at the Yosys hierarchy-check stage ("Module `\dfc_rtl011'
    referenced... is not part of the design") because `dfc_rtl011.sv` was
    missing from both `$SourceFiles` and the synthesis `.ys` script's read
    order. Fixed by adding it in both places, immediately after
    `dfc_rtl010.sv`, matching the existing pattern exactly.

47. **Real, disclosed consequence of RTL-011's own physical pin assignment
    -- flagged explicitly per this session's own task instructions, not
    discovered silently later.** RTL-011's 8 health-discrete channels
    consumed the ENTIRE remaining unshared differential-capable pin range
    (`gp14`-`gp21`/J2-14 through J2-21) in one module -- see
    `ULX3S_CONNECTION_MAP.md`'s own new Section 9. After this module, only
    `gp11`-`gp13` (J1-11 through J1-13, WiFi-shared per the real board
    file's own comments) remain open on the differential-capable range at
    all; the single-ended-only range was already fully exhausted by
    RTL-006/007 (Sections 5/6). Any future module needing a physical pin
    (RTL-017/019/020, or whichever module needs one next) must use one of
    these 3 WiFi-shared positions -- there is no unshared option left.

## Timing/floorplanning investigation (item 42 follow-up)

48. **Real, disclosed investigation -- NOT fixed, no RTL/LPF/toolchain change
    made. Read-only per this session's own task instructions; a decision on
    whether to act on any of this is deferred, not resolved here.** Ran a
    real `build_ecp5.ps1` (Build ID `20260826_182249`, byte-identical
    placement/routing to the immediately preceding real build
    `20260826_171940` from the same day, confirmed via direct `diff` --
    deterministic default placement for this exact netlist). Final result:
    **50.12 MHz PASS at 50.00 MHz required**, 30% TRELLIS_COMB / 19%
    TRELLIS_FF.
    - **`data_words_q` (item 42's own subject): confirmed present in the
      netlist in the identical risky shape `rdata_words_q` had before item
      41's fix, but NOT on either of this build's two worst measured
      paths.** `grep -c data_words_q` on the real P&R log
      (`ecp5_pnr_20260826_182249.log`) returns 0; it appears only in the
      synthesis log (83 hits), all from Yosys's real memory-to-register-array
      conversion message ("`Replacing memory \data_words_q with list of
      registers`", `dfc_rtl024_spi_bridge.sv:284`). For comparison,
      `rdata_shift_q` (the already-fixed signal) DOES survive Yosys's
      name-mangling into hop-level cell names on a real reported critical
      path, confirming mangling doesn't hide a signal that's actually on a
      worst path -- so this is a real, not merely inconclusive, absence.
      **Conclusion: item 42's concern is real in shape but currently
      dormant, not urgent** -- worth revisiting if a future module's growth
      ever implicates it directly, per item 42's own original framing.
    - **The real limiting path (the one that sets 50.12 MHz) touches four
      modules in one chain**, confirmed from the real nextpnr-ecp5 JSON
      report (`--report`, `ecp5_pnr_report_20260826_182249.json`):
      `rtl009_status` (25,18) -> `u_rtl006.illegal_config` (24,18) ->
      `rtl002_status` (48,29) -> `rtl009_status`, a DIFFERENT bit (95,27) ->
      `u_rtl005.store_q[54]` (61,36). 19.95ns total, 3.13ns logic / 16.30ns
      routing -- **routing is 82% of the path**. nextpnr-ecp5 does not
      produce a Vivado-style ranked top-N-distinct-paths report; it reports
      exactly one full source-to-sink chain per clock-domain-crossing
      category (3 total for this design), decomposed hop-by-hop -- 24 real
      routing hops across all three, ranked by delay, span 0.22ns/0 tiles up
      to 3.68ns/37 tiles.
    - **Real, computed distance-vs-delay correlation across those 24 routing
      hops: Pearson r = 0.957** (dist 0-49 tiles, delay 0.22-3.68ns; linear
      fit `delay ~= 0.062*dist + 0.57`). Physical distance is a real, strong
      driver of the worst delays in this build -- not a theoretical
      concern.
    - **But the worst hops are wide fan-in/fan-out HUB nodes, not clean
      pairwise module-to-module relationships, confirmed directly in RTL**:
      `dfc_rtl002.sv:362-366`'s `mandatory_fault_now`/`init_ready_now` are
      24-wide OR/AND reductions over every module's `module_fault_i`/
      `module_ready_i` bit (line 934's `status_comb` then passes the full
      24-bit `module_fault_i` straight into RTL-002's own status word);
      `dfc_rtl003.sv:213`'s `raw = irq_source_i[23:0] | ...` is the same
      24-wide OR for interrupts; `dfc_rtl005.sv:479`'s
      `store_q[tail_q] <= slot_record_q[push_idx]` is a runtime-indexed 24:1
      mux over every event-producer's registered record, feeding directly
      into the flop (`store_q[54]`) that ends the worst path above;
      `dfc_config_regbank_regs.sv:2181`'s 353-way `case(addr_i)` register
      readback mux touches essentially every module's state. The placement
      data itself shows why this doesn't map onto pairwise clustering:
      **`rtl009_status` appears at two physically unrelated locations** --
      (25,18) for one bit, (95,27) for a different bit of the same 336-bit
      status word -- because each bit is placed near ITS OWN downstream
      consumer, not near "RTL-009" as a single physical object. A region
      constraint clustering "RTL-009 near RTL-005" would help only the bits
      actually feeding RTL-005, doing nothing (or displacing the problem)
      for the other bits of that same signal feeding the register-readback
      mux or RTL-002's fault OR-tree.
    - **Real, disclosed assessment, not assumed either direction, per this
      session's own task instructions: the evidence supports "distance
      matters" but not "pairwise region constraints are the fix."** With
      20+ modules each reaching 2-4 shared aggregation hubs (RTL-001's
      readback mux, RTL-002's fault/ready OR-trees, RTL-003's IRQ OR-tree,
      RTL-005's event mux) on a roughly 127x100-tile die, some inputs to any
      given hub will always be physically far away -- 20+ scattered sources
      cannot all be simultaneously adjacent to one point. This is also a
      more parsimonious explanation for the project's own observed margin
      volatility than "this specific pair happened to land far apart this
      time": real utilization has climbed steadily and monotonically across
      builds (RTL-005 19% COMB -> RTL-006 20% -> RTL-010 29% -> RTL-011
      30%, all from real build manifests already in this document), and
      each new module adds another input to the SAME wide OR-trees/muxes
      above, not a new independent pairwise relationship.
    - **Real, separate problem with the specific mechanism a floorplanning
      fix would need: this toolchain has no LPF-level internal-logic
      region/area constraint syntax.** Confirmed directly: every one of the
      153 real lines in `fpga/ecp5/ulx3s_dfc.lpf` is `LOCATE COMP "<port>"
      SITE "<pin>"` -- I/O pin/pad placement only -- and a real
      `nextpnr-ecp5 --help` confirms there is no LPF-based region/cluster
      constraint flag. A real region constraint in nextpnr-ecp5 requires a
      `--pre-place` Python script calling `ctx.constrainCellsToRegion(...)`
      -- a genuinely new, more invasive toolchain integration (new script,
      new `build_ecp5.ps1` wiring), not a `.lpf` edit.
    - **No action taken.** Whether to pursue a region-constraint mechanism,
      restructure any of the four wide-fanin hubs above, or leave this as a
      standing, monitored margin risk is a decision for a future session,
      not resolved by this investigation.

## RTL-012 (Watchdog Manager) integration

49. **RESOLVED (2026-08-27), approved before implementation, same pattern
    as items 2/7/8/12/20/24/28/32/36/43 (the eleventh real instance of this
    exact gap class -- the first in the Safety domain).**
    `dfc_rtl012_control_t` (110 bits) had no clear-request field for
    `RTL012_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-301C bit 0, a real W1C
    field). Fixed: ARCH-002 grew the struct 110->111 bits, adding
    `rtl012_evt_overflow_status__event_overflow` at the new highest bit
    (110) -- every pre-existing field's bit position confirmed unchanged
    via a real `regenerate.ps1` run (`git diff` of the regenerated
    `include/dfc_types_pkg.sv` shows only the new field/width/localparam
    lines changed). `tools/reggen/rtl012_field_map.json` carries the
    corresponding `control_registers` entry, and its `status_registers`
    section closes the RTL-002/003/004-style readback gap (item 21) for
    every external RTL-012 register from the start, same discipline
    already established for RTL-006 through RTL-011.

50. **Real, disclosed ARCH-002 internal inconsistency -- a new class of
    finding, distinct from every prior module-spec-vs-ARCH-002 conflict
    already resolved in this document (items 1/10/11/13/19/22/37/44), since
    both conflicting tables here belong to ARCH-002 itself, the owning
    document, not to a restating module spec.** ARCH-002's own Appendix F.3
    (RTL-012 condition-mask bit allocation: "0 early; 1 late/missing; 2
    invalid key; 3 timeout; 4 recovery; 5 service accepted; 6 event-slot
    overflow") and its own Appendix C.7 (event ID 0x0040 subtype values: "0
    early, 1 late, 2 missing/timeout, 3 invalid key, 4 recovered, 5 service
    accepted") do not align positionally -- F.3 folds "late" and "missing"
    onto one shared condition-mask bit, while C.7 keeps them as two
    distinct subtype values, and REG-002's real `WDOG_STATUS` register has
    exactly 4 sticky W1C bits (SERVICE_ACCEPTED/EARLY_SERVICE/
    BAD_SERVICE_KEY/TIMEOUT -- no dedicated LATE bit at all), consistent
    with neither table read literally. **Resolved with explicit approval,
    not silently:** `dfc_rtl012.sv` keeps LATE and TIMEOUT/MISSING as two
    independently real, distinct conditions -- F.3 bit 1 gates a "late
    service attempt" condition (C.7 subtype 1) and F.3 bit 3 gates the
    actual "counter reached MAX_WINDOW" timeout-declared condition (C.7
    subtype 2) -- both can genuinely coincide on the identical cycle
    (ARCH-RTL012-001's own named "timeout detection precedes same-cycle
    late service" race), proven as two independently-observed real event
    subtypes in `rtl012_integration_tb.sv` Parts 5 and 7. If ARCH-002 is
    ever revised to reconcile these two tables, only this module's
    condition-mask-bit-to-subtype mapping needs to change.

51. **Real, disclosed, narrow architectural limitation -- logged, not
    silently worked around.** `WDOG_SERVICE.SERVICE_KEY` (REG-300C) is a
    32-bit WO-CMD field whose entire legal range (0-0xFFFFFFFF) is
    meaningful -- every value, including a legitimately-written
    `0x00000000`, is a real service attempt subject to the exact-key check
    (REG-300C's own text: "Correct value services; any other value sets
    service error"). This project's existing WO-CMD pulse-capture
    mechanism (`reggen.py`'s generated `{name}_pulse_q`, confirmed by
    direct reading of `reggen.py`'s own generation code before writing
    `dfc_rtl012.sv`) holds the raw written value for exactly one cycle,
    defaulting to `32'h0` every other cycle -- meaning a host write of
    EXACTLY `0x00000000` is indistinguishable from "no write this cycle."
    `dfc_rtl012.sv` detects a service attempt as `ctl_service_key != 32'h0`,
    correctly classifying every other legal write (the valid key and every
    other wrong key) but silently missing the single specific case of a
    host writing the all-zero key -- that one case is treated as no
    service attempt rather than `BAD_SERVICE_KEY`. A bit-exact fix would
    require a dedicated write-strobe signal alongside the pulse value,
    which no cross-module register-bus mechanism in this project currently
    provides -- real, disclosed future work, not something this module's
    own field-map or RTL can invent around.

52. **Real, disclosed interpretation -- no functional consequence, not
    fixed (nothing to fix: no equation exists anywhere in the owning
    documents to attach a meaning to). Same class as items 25/29/34.**
    `WDOG_CONTROL.WINDOW_ENABLE` has NO wired functional effect anywhere in
    `dfc_rtl012.sv`. `ARCH-SAFE-005` (the sole owning contract for
    EARLY/LATE/window behavior, quoted in full in `RTL-012_RevA.md` SS3)
    describes the window/key algorithm completely and unconditionally
    whenever "an enabled counter" (`WDOG_CONTROL.ENABLE`) is running -- it
    never references WINDOW_ENABLE at all, and neither does
    `ARCH-RTL012-001` or `ARCH-VAL-012`. REG-3000 lists WINDOW_ENABLE only
    as one of the protected control bits with no further behavioral text of
    its own. The field is still real: stored, forwarded, and host-readable
    via `WDOG_CONTROL` itself, exactly per REG-3000's own RW access class --
    just genuinely inert.

53. **Real, disclosed design, not a bit-exact citation -- forced by a
    genuine absence of further specification, not guessed.**
    ARCH-RTL012-001's own text ("Recovery requires exactly one valid
    in-window service after the source condition clears") plus
    ARCH-VAL-012's "recovery command with invalid timing is rejected" and
    REG-3018's own "recovery/clear command after source condition is
    inactive" description leave the exact RECOVER/recovery-completion
    sequencing underspecified at the bit level. `dfc_rtl012.sv` implements:
    (1) RECOVER is accepted only while the live timeout condition is
    currently active (issuing it while not timed out is rejected, no
    effect -- ARCH-VAL-012's "invalid timing"); (2) an accepted RECOVER
    resets the elapsed counter to zero and clears the live timeout
    condition ("the source condition clears") but does NOT by itself clear
    `RESPONSE_PENDING`/deassert `response_req_o` -- the safety-response
    request stays pending, the conservative reading of "recovery
    REQUIRES..."; (3) exactly one subsequent valid in-window service (an
    ordinary service, checked against the freshly-reset counter under
    unchanged window rules) completes recovery, clearing `RESPONSE_PENDING`
    the same cycle it also sets `SERVICE_ACCEPTED`; (4) if the counter
    instead reaches `MAX_WINDOW` again before that confirming service
    arrives, the single-shot recovery opportunity is spent and a fresh
    RECOVER is required. Proven end-to-end in `rtl012_integration_tb.sv`
    Part 6, including the "RECOVER rejected while not timed out" case.

54. **Real, pre-existing testbench gap found while checking every existing
    `dfc_rtl001` instantiation site during this session, same discipline as
    items 15/22 -- and materially larger in scope than either of those.**
    8 of the 10 pre-existing per-module `dfc_rtl001`-instantiating
    integration testbenches (`rtl002_integration_tb.sv` through
    `rtl009_integration_tb.sv`) were missing `rtl010_control_o`/
    `rtl010_status_i` AND `rtl011_control_o`/`rtl011_status_i` ENTIRELY
    (not merely stub-tied -- the ports were never even declared or
    connected), since neither RTL-010's nor RTL-011's own integration
    session swept every existing testbench, only the ones each session's
    own account happened to check. `rtl010_integration_tb.sv` was likewise
    missing `rtl011_control_o`/`rtl011_status_i`. Confirmed via a real,
    direct `grep` across all 10 files before assuming any single file's own
    account was exhaustive (the same lesson item 15 already drew from a
    smaller instance of this exact gap class). Fixed: all 10 files now
    declare/connect the correct disclosed-stub pairs for every sibling
    module not under that file's own test, through `rtl012` inclusive.
    Verified via the real, full `sim.ps1` regression (see
    PROJECT_CONTINUITY.md Section 4 for the exact pass/fail counts).

55. **Confirmed, not assumed: RTL-012 needs no physical FPGA pin**, same
    class of finding as RTL-010's own module. Checked directly against
    ARCH-002's own 17-port catalog (RTL-012 - Watchdog Manager) before
    writing `dfc_rtl012.sv`: every port is either the standard clock/reset/
    control/status/event/irq/fault group, an internal same-domain signal to
    a not-yet-existing sibling module (`response_req_o` -> RTL-016,
    `service_activity_o` -> RTL-015), or a broadcast input from an
    already-real module. No external pad, no CDC/RDC inventory entry names
    this module. No `fpga/ecp5/ulx3s_dfc.lpf` or `ULX3S_CONNECTION_MAP.md`
    change was needed or made for this module.

56. **Real, transient toolchain-robustness finding -- confirmed
    non-reproducible via an immediate retry, same class of finding as item
    18 (a one-off `nextpnr-ecp5` router-internal assertion crash).** A real
    `gate.ps1` run's `formal.ps1` step failed its `prove` task: the
    `basecase` SMT engine crashed with "Unexpected EOF response from
    solver" (`returncode=1`) while the `induction` engine, checked in the
    same run, genuinely returned `pass` -- this is a solver-process crash,
    not a genuine counterexample (no trace was produced, and the crash
    message names an unexpected process-communication failure, not a
    property violation). An immediate retry of `formal.ps1` alone, no
    other change, passed both `bmc` and `prove` completely clean. Logged
    here as a real, disclosed toolchain-robustness finding, not silently
    retried-and-ignored -- if this recurs more persistently on a future
    module's `gate.ps1` run (every retry crashes the same way), that would
    be a much stronger signal worth investigating directly, the same
    reasoning item 18 already applied to its own analogous finding.

57. **RESOLVED (2026-08-27), a real timing-closure fix to already-shipped
    RTL-005, approved before implementation per this session's own task
    instructions (touching a prior module's shipped file requires explicit
    approval).** A real `build_ecp5.ps1` run after RTL-012 was added failed
    timing: **47.73 MHz, FAIL at 50 MHz required** (3.38 ns logic + 17.57 ns
    routing = 20.95 ns). The real critical-path report named a chain
    entirely inside already-shipped code -- RTL-010's status register ->
    RTL-004's `error_q` -> the SPI bridge's `rdata_shift_q` -> RTL-005's
    `store_q[56]` -- confirmed to NOT touch `dfc_rtl012.sv`'s own new logic
    at all. This is the exact same worst-path sink item 48's own prior
    investigation had already named (`store_q[54]` then, a different bit
    of the same signal) -- RTL-012's added die area pushed an
    already-razor-thin, already-identified margin problem (RTL-011's own
    build closed at only 50.12 MHz) over the edge, not a defect in RTL-012
    itself.
    - **Root cause, confirmed by direct reading of `dfc_rtl005.sv`, not
      guessed:** `store_q[tail_q] <= slot_record_q[push_idx]`
      (ARCH-EVT-004/005) is a runtime-indexed 24:1 128-bit read-mux
      (`slot_record_q[push_idx]`) feeding a runtime-indexed 64-way write
      (`store_q[tail_q]`), both resolved in the same cycle a push is
      accepted -- genuinely expensive combinational depth, unlike item 41's
      own array (RTL-005's store is a true, randomly-addressed ring buffer,
      not a sequential-only access pattern, so the shift-register
      replacement technique does not apply here).
    - **Real fix: pipelined the store write into two cycles**, same
      "capture this cycle, commit the next" technique already proven by
      item 41's own SPI-bridge fix. The push/pop pointer bookkeeping
      (`tail_q`/`head_q`/`level_q`) is UNCHANGED and still commits the same
      cycle a push is accepted (ARCH-EVT-004's "one accept per CORE_CLK" is
      unaffected) -- only the 128-bit data payload's actual landing in
      `store_q` is delayed by one cycle, via two new registers
      (`pending_write_q`/`pending_write_data_q`/`pending_write_addr_q`).
    - **A real, genuine read-after-write hazard was identified BEFORE
      implementation, not discovered after a failing test:** the one-cycle
      write pipeline creates exactly one cycle where a `CAPTURE_OLDEST`/POP
      of the just-pushed slot (`head_q == the in-flight write's target
      address`) would read stale/default data from `store_q`, since the
      real data hasn't landed yet. Closed with an explicit forwarding mux
      on the `EVT_SNAPSHOT` read (`store_q[head_q]` only when nothing is
      in flight to that exact address; the staged register directly
      otherwise) -- preserves ARCH-EVT-008's "snapshot old head" semantics
      bit-for-bit against the pre-pipelined design.
    - **Proven via a new, real, deterministically-engineered test**,
      `rtl005_integration_tb.sv` Part 7 (43/43 checks total, up from 37):
      a real dri_write() for `CAPTURE_OLDEST` and a real one-cycle producer
      push (through the real `evt_valid_i`/`accept_i` handshake on
      producer slot 0, not a hierarchical force) are started in a `fork`
      at the exact same simulation instant -- since a real DRI write takes
      exactly 2 CORE_CLK edges from call to its own write-commit cycle, and
      this module's own arbiter puts a freshly-asserted producer's
      `evt_valid_i` exactly one edge from `do_push`, this lands the
      capture's own pulse and the push's pipelined-write visibility on the
      IDENTICAL cycle by construction, not by chance retry. **The test was
      verified to actually catch the regression it claims to catch**: a
      real, temporary negative-control run (forwarding mux reverted to
      plain `store_q[head_q]`, then restored) confirmed Part 7 genuinely
      FAILS without the fix -- reading back stale data (0x00030009/
      0x00000002, an earlier test part's own leftover record) instead of
      the real just-pushed 0x00051234/0xCAFEBABE pattern -- not merely
      passing by coincidence.
    - Verified end-to-end: a full Icarus regression (16/16 testbenches,
      **660/660 checks** -- 654 from the RTL-012 baseline plus 6 new
      Part 7 checks), a real `gate.ps1` run (lint/sim/formal/coverage all
      clean), and a real `build_ecp5.ps1` run -- see
      PROJECT_CONTINUITY.md's own RTL-012 entry for the exact, real
      post-fix Max frequency and utilization figures.

58. **Confirmed, not assumed: `build_ecp5.ps1`'s `$SourceFiles` list is NO
    LONGER a manually-maintained list** -- it was converted to real
    per-domain auto-discovery (`Get-ChildItem` over every `rtl\<domain>\
    src\*.sv`, sorted by name) at some point after RTL-011's own session
    (whose own account, PROJECT_CONTINUITY.md Section 4, still described
    this as a manually-maintained list needing a new line added "immediately
    after `dfc_rtl010.sv`" -- the recurring gap this session's own task
    instructions specifically named as having "recurred 4 times"). Checked
    directly against the real, current `build_ecp5.ps1` before assuming
    either way: `rtl\safety\src\dfc_rtl012.sv` is picked up automatically
    by this existing mechanism -- no manual edit to `build_ecp5.ps1` was
    needed or made for this module. This class of gap is now closed
    generically, not just for this one module.

## RTL-013 (Fault Manager) integration

59. **RESOLVED (2026-08-28), approved before implementation, same pattern
    as items 2/7/8/12/20/24/28/32/36/43/49 (the twelfth real instance of
    this exact gap class -- the second in the Safety domain).**
    `dfc_rtl013_control_t` (112 bits) had no clear-request field for
    `RTL013_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-3120 bit 0, a real W1C
    field). Fixed: ARCH-002 grew the struct 112->113 bits, adding
    `rtl013_evt_overflow_status__event_overflow` at the new highest bit
    (112) -- every pre-existing field's bit position confirmed unchanged via
    a real `regenerate.ps1` run (`git diff` of `include/dfc_types_pkg.sv`
    shows only the new field/width/localparam lines changed).
    `tools/reggen/rtl013_field_map.json` carries the corresponding
    `control_registers` entry, and its `status_registers` section closes the
    RTL-002/003/004-style readback gap (item 21) for every external RTL-013
    register from the start, same discipline already established for
    RTL-006 through RTL-012.

60. **RESOLVED (2026-08-28), a real, newly-found `reggen.py` generator gap
    -- fixed in the generator itself, not worked around in the field-map or
    hand-patched in generated output (RTLSTD-ORG-003).** `FAULT_RECOVERABLE_
    MASK` (REG-311C) is a CONST register whose own real write-validation
    text is "Any register write is ACCESS_ERROR" -- but RTL-013_RevA.md
    SS3's own instruction ("decode this mask directly" from the real
    forwarded field) plus reggen.py's own generator invariant (every field-
    map control struct bit must be covered by exactly one field-map entry,
    no partial-coverage escape valve) both require this fixed value to
    still forward into `dfc_rtl013_control_t`'s own
    `fault_recoverable_mask__recoverable` field through the ordinary
    control_registers mechanism. reggen.py's PRE-EXISTING rule ("any
    register appearing in a field-map's control_registers reports
    write_illegal_o = 1'b0") was correct for every RW/WO-CMD/W1C entry used
    by every module through RTL-012 (a real write path genuinely exists for
    those), but wrong here -- it would have silently ACCEPTED a host write
    to this ACCESS_ERROR-only register (REG-311C's own explicit text),
    reporting the wrong DRI response code even though the write has zero
    real effect on the always-0x00017FEF constant wire. Fixed in reggen.py:
    a register whose ctrl_entry fields are ALL class "CONST" now falls back
    to the ordinary readback-based `write_illegal_o` rule instead of being
    unconditionally cleared. Confirmed via a real `regenerate.ps1` diff that
    `FAULT_RECOVERABLE_MASK` is the ONLY register whose `write_illegal_o`
    value changed relative to the pre-fix generator output, and that every
    pre-existing RW/WO-CMD/W1C field-map entry across all 12 consumer
    modules is completely unaffected (confirmed by the identical diff
    showing exactly 4 changed `write_illegal_o` lines, all RTL-013's own new
    external-class registers, none of them `FAULT_RECOVERABLE_MASK`).

61. **RESOLVED (2026-08-28), a real, pre-existing gap in already-shipped
    RTL-002 -- same class as items 5/22/54 (a sibling module's own port-
    catalog nonconformance surfacing during a later module's integration).**
    ARCH-002's own RTL-002 port catalog already specified `degraded_req_i`/
    `faulted_req_i` (producer `RTL-013.degraded_req_o`/`faulted_req_o`), but
    `dfc_rtl002.sv`, as it existed before this session, implemented neither
    -- unsurprising, since RTL-013 (the only real producer for either port)
    did not exist until this session. Fixed by adding both as real inputs on
    `dfc_rtl002.sv`, folded into the primary-state FSM's FAULTED/DEGRADED
    entry conditions as ADDITIONAL causes alongside the pre-existing
    `module_fault_i`-based mandatory/optional aggregation
    (`faulted_request_now = mandatory_fault_now || faulted_req_i`;
    `degraded_request_now = optional_enabled_fault_now || degraded_req_i`) --
    ARCH-STATE-004/005's own generic wording ("at least one enabled
    optional-function fault"/"a mandatory or nonrecoverable fault") covers
    both sources uniformly, and this does NOT change SUBSYS_FAULT/
    `module_fault_i` aggregation, which remains pure per-module status. A
    real, concrete consequence confirmed live in `rtl024_skeleton_tb.sv`:
    forcing RTL-013's real `faulted_req_o` (via a real RTL-011 health fault)
    now genuinely drives RTL-002 into FAULTED through this newly-wired path,
    proven by intentionally sequencing that test's own RTL-013 section AFTER
    the pre-existing 499,000-cycle mandatory-init-timeout wait (forcing it
    any earlier would make RTL-002 latch into FAULTED immediately and defeat
    that wait's own, separate proof of the timeout path).

62. **Real, disclosed design, not a bit-exact citation -- forced by a
    genuine absence of further specification in the owning documents, same
    class as items 25/29/34/52/53 (CHTR-DOC-006).** Several bit-exact
    behaviors in `dfc_rtl013.sv` have no owning-document equation to cite
    directly:
    - **FAULT_RESPONSE.LATCH_UNTIL_HOST_CLEAR's own level-vs-latch policy**
      for `response_pending_q`/`response_req_o.valid` mirrors ARCH-002
      SS10.4's own analogous `LATCHED_REQUEST[c]` equation for RTL-016's
      channels ("zero when latch policy is disabled... an active request
      sets the retained latch" when enabled) -- the closest real, cited
      precedent, since no equation names this field directly. This
      required a real, live design fix found only by direct simulation, not
      inspection: `response_trigger` must gate on ACTIVE-only nonrecoverable
      evidence (`nonrecoverable_active17`, the same scope already used for
      `safety_inhibit_o`), not active-OR-sticky (`nonrecoverable_evidence17`,
      the scope `faulted_req_o` uses) -- using the broader, sticky-inclusive
      set would make `response_pending_q` track sticky evidence
      unconditionally, defeating the "level policy" case entirely (it could
      never auto-clear once any nonrecoverable source had ever latched).
    - **DEGRADED_STATUS lifecycle** (ACTIVE/ENTRY/RECOVERY_AVAILABLE/
      RECOVERED): REG-3110 gives only generic W1C boilerplate text per bit,
      no algorithm. Implemented as: ACTIVE = `degraded_req_o` itself (live);
      ENTRY = sticky, set-dominates while `degraded_req_o` is high, cleared
      only by host clear while low; RECOVERED = a one-shot pulse-latch on
      the registered falling edge of `degraded_req_o` (an explicit
      "previous cycle" comparison register, not a same-`always_ff`
      same-cycle stale read -- PROJECT_CONTINUITY.md Section 2's own
      confirmed lag finding); RECOVERY_AVAILABLE = `ENTRY && !ACTIVE` (a
      live, derived signal, not its own register).
    - **Event 0x0041 ("Fault manager") subtype definitions** (0 asserted, 1
      recovered, 2 cleared, 3 response requested) track the module's OWN
      overall evidence lifecycle (any of the 17 sources' `any_active` rising/
      falling edge, an accepted clear command, or `response_pending_q`
      newly setting) -- not the DEGRADED-specific sub-case above. Priority
      when multiple subtypes qualify the same cycle: response requested >
      asserted > cleared > recovered (most safety-relevant first, same
      class of disclosed local priority as RTL-012's own).
    - **ARCH-VAL-013's "injection requires test-active"**: RTL-013 has NO
      dedicated `test_active_i` port on its own real 19-port catalog (unlike
      RTL-002) -- `operating_state_i == dfc_types_pkg::TEST_DEBUG` is the
      only test-related signal this module receives, used as the
      "test-active" qualifier.
    All four are proven via real, dedicated checks in
    `rtl013_integration_tb.sv` (the level-vs-latch distinction specifically
    in Parts 4/6, including the real bug found and fixed above).

63. **Real, hard-won testbench-authoring lesson, kept here for RTL-014
    onward.** A brand-new testbench (`rtl013_integration_tb.sv`) with a
    completely missing clock generator (`always #10 core_clk_i = ~core_clk_i;`)
    produces a real, genuine SILENT FAILURE mode distinct from every other
    class of testbench bug already documented in this project: the
    simulation elaborates cleanly, `vvp` runs and exits with code 0, and
    produces ZERO output of any kind -- not a single `$display`, not an
    error, nothing -- because the very first `initial`-block statement
    (`repeat (4) @(posedge core_clk_i);`) blocks forever waiting for an edge
    that will never come, the simulator detects no further events are
    possible, and ends cleanly. This is easy to misdiagnose as a tool/
    redirection problem (confirmed directly: re-ran the identical vvp
    invocation against an already-working testbench to rule that out first)
    rather than what it actually is -- a missing clock driver. **Any future
    module's own new, from-scratch integration testbench should have its
    clock-generator `always` block checked FIRST if it produces zero output
    at all**, before investigating anything else.

64. **Real, disclosed side effect of this project's own whole-system
    testbench (`rtl024_skeleton_tb.sv`) growing long enough in real
    simulated time -- found while adding RTL-013's own section, logged for
    RTL-014 onward, not a defect.** RTL-012's own `WDOG_TIMEOUT_US` (1000us,
    configured once early in that module's own section) genuinely elapses
    for real by the time later sections run, since the ~499,000-cycle
    mandatory-init-timeout wait alone is ~10ms of real simulated time and
    WDOG_CONTROL is never re-serviced afterward -- RTL-012's own real
    `fault_req_o` was found genuinely (not spuriously) active on
    `fault_source_i[0]` by the time RTL-013's own section ran, confirmed via
    direct signal inspection before concluding it was a real side effect
    and not an RTL-013 bug. Any future module's own whole-system-testbench
    section relying on an EARLIER module's timer/timeout-based module
    remaining in a specific state should check whether enough real
    simulated time has elapsed since that state was last set, not assume it
    still holds -- RTL-013's own section now explicitly disables
    `WDOG_CONTROL` first to keep its own scenario clean, with this
    reasoning documented in the test itself.

65. **RESOLVED (2026-08-28), a real, multi-attempt timing-closure
    investigation confirming PROJECT_CONTINUITY.md's own item-48
    "wide fan-in hub" prediction finally tipped over into a genuine build
    failure -- same discipline as items 17/31/40/41/57, three sequential
    real fixes needed, not all found or fixed in one pass.** A real
    `build_ecp5.ps1` run after RTL-013 was added failed timing:
    **40.14 MHz, FAIL at 50 MHz required** (device utilization only
    7-9%, ruling out resource exhaustion). Three real critical-path
    investigations were needed:
    1. **`dfc_rtl013.sv`'s own primary-source priority search.** The
       original implementation threaded a "found" flag through two
       17-iteration `for` loops (one over active sources, one over sticky
       sources), each iteration's own condition reading the PREVIOUS
       iteration's own flag update -- structurally the identical genuine
       17-deep SERIAL dependency chain already found and fixed once for
       RTL-005's own round-robin arbiter (item 17). Fixed the same way:
       replaced with a genuine `casez`-based priority encoder (one pattern
       per bit position, each an independent parallel comparison), and
       reduced two unconditional 17-way encodes down to one (select which
       17-bit vector to encode first, via a plain mux, rather than
       encoding both every cycle). This measurably helped (40.14 -> 40.36
       MHz) but was not, by itself, sufficient -- the dominant bottleneck
       was elsewhere.
    2. **Investigated and found NOT the real cause, kept here as a real
       lesson, not smoothed over:** the real critical path (24.78 ns:
       6.16 ns logic, 18.62 ns routing) was named as running through
       already-shipped `dfc_rtl010.sv`'s own `ch0_range_ext`/
       `ch1_range_ext` (a 64-bit signed subtraction of two 32-bit signed
       operands, sign-extended to a width 31 bits wider than the subtrahend
       could ever need). Approved and narrowed to the minimum
       non-overflowing 33-bit width, a pure width reduction with zero
       functional change -- confirmed via a real, direct build-to-build
       comparison that this produced a BYTE-IDENTICAL post-route result
       (same 40.36 MHz, same exact ns figures to two decimal places),
       proving Yosys's own `opt`/width-reduction passes had already
       trimmed the unused high bits regardless of the declared RTL width.
       **Lesson: a source-line attribution in a critical-path report is not
       proof that widening/narrowing that exact RTL construct will move
       the number** -- confirm via a real before/after build comparison,
       not just a plausible-sounding hypothesis, before concluding a fix
       worked. The width reduction was kept anyway (genuinely correct,
       harmless, and clearer about the field's real range) but logged
       honestly as NOT the fix that closed timing.
    3. **The real fix: pipelined `rtl013_fault_source` in `dfc_rtl024.sv`.**
       This new, wide (7-source) combinational fan-in from physically-
       scattered real modules' own registered `fault_req_o` outputs,
       feeding directly into RTL-013's own further combinational
       classification logic, was itself a brand-new instance of exactly
       the "wide fan-in hub" pattern item 48 already identified as this
       design's own standing architectural risk. Fixed via the same
       "capture this cycle, commit the next" technique already proven for
       the SPI bridge (item 41) and RTL-005's own event store (item 57):
       registered the aggregation one CORE_CLK cycle before RTL-013 ever
       sees it (`rtl013_fault_source_q`), breaking the combinational path
       from seven distant modules' registers through RTL-013's own
       downstream logic in one cut. Adds exactly one CORE_CLK cycle of
       latency to fault-source detection -- negligible for a safety-
       monitoring signal, and confirmed via a real, full regression
       (17/17 testbenches, 756/756 checks, unchanged) that this is a pure
       timing/latency change with no functional regression (every test's
       own wait margins were already generous enough to absorb it).
    Verified end-to-end: a full Icarus regression after each of the three
    fix attempts (17/17 testbenches, 756/756 checks, unchanged throughout
    -- confirming this was purely a timing-closure investigation, never a
    functional one), a real `gate.ps1` run (lint/sim/formal/coverage all
    clean) after the final fix, and a real `build_ecp5.ps1` run (Build ID
    `20260828_134327`, **50.19 MHz PASS at 50 MHz required**,
    TRELLIS_COMB 26057/83640 (31%), TRELLIS_FF 16926/83640 (20%),
    MULT18X18D 12/156 (7%), no `--timing-allow-fail` needed). **Lesson for
    RTL-014 onward, reinforcing item 48's own standing warning with a real,
    now-proven fix pattern**: any NEW module that creates its own wide
    aggregation across several already-scattered real producers (not just
    "one more input to an existing hub") should have that aggregation's
    own output registered from the start, before it ever reaches further
    combinational logic -- don't wait for a real build failure to
    discover this a second time.

## RTL-014 (Interlock Engine) integration

**Approval note, read first:** every ARCH-002/generator decision below was
made in one session under the person's explicit instruction to run the
RTL-014 task end to end without stopping for item-by-item approval. Each
one is a real, disclosed decision, logged here so it can be reviewed and
reversed through the normal process, not a silently settled fact.

66. **Resolved without an ARCH-002 edit, same resolution style as items
    1/10/11/13/19/37/44.** `RTL-014_RevA.md` SS2 lists only `response_req_o`
    as RTL-014-specific, omitting five real ports in ARCH-002 Appendix A's
    "RTL-014 - Interlock Engine (19 ports)" table: `interlock_terms_i[63:0]`,
    `interlock_satisfied_o[7:0]`, `interlock_inhibit_o[7:0]`, `irq_req_o`
    (to `RTL-003.irq_source_i[15]`), and `fault_req_o` (to
    `RTL-013.fault_source_i[1]`). Its SS1/SS4 also say "10 registers", where
    REG-002 SS26 says and lists 16. Both resolved in favor of the owning
    documents. `dfc_rtl014.sv` implements all 19 ports and all 16
    registers. **The module spec itself was then corrected:**
    `docs/rtl_specs/RTL-014_RevB.md` supersedes Rev A (retired), with the
    real 19-port list, 16 registers, the staged-bank/term-source/commit
    design, and a VP evidence table citing items 66-79. **An earlier briefing for this task claimed RTL-014 does not
    feed RTL-013's fault matrix. That claim was wrong:** Appendix A and C.6
    bit 1 ("Interlock violation, class 0x04, recoverable") both assign it,
    and it is now wired.

67. **RESOLVED (2026-10-02), ARCH-002 struct growth, three gap classes in
    one change.**
    - `dfc_rtl014_control_t` grew from 68 to 513 bits:
      - bits 71:68, `ilock_stage_response__safety_response_mask`. REG-002's
        own generation-check paragraph (near line 7123) requires "a
        four-bit control member in `dfc_rtl014_control_t`" for
        `ILOCK_STAGE_RESPONSE.SAFETY_RESPONSE_MASK`, and the 68-bit struct
        had none. This was a REG-002-vs-ARCH-002 conflict, not just a gap.
      - bit 72, `rtl014_evt_overflow_status__event_overflow`. This is the
        **13th instance** of the EVENT_OVERFLOW-clear gap class (items
        2/7/8/12/20/24/28/32/36/43/49/59).
      - bits 512:73, `ilock_stage_e<0..7>__*`: the complete 8 x 55-bit
        staged bank (item 68).
    - `dfc_rtl014_status_t` grew from 53 to 108 bits (bits 107:53): the
      selected-entry readback for the five external `ILOCK_ACTIVE_*`
      registers (REG-322C..323C). Before this, none of them had any status
      field, so VP-MOD-014 "active readback", VP-SAFE-016 and VP-REG-022
      could not be met.
    - Appendix A's two width columns (the RTL-001 rows and the RTL-014 rows)
      were updated to match.
    - Every pre-existing field kept its bit position. A `git diff` of the
      regenerated `include/dfc_types_pkg.sv` shows only RTL-014 lines
      changed.

68. **RESOLVED (2026-10-02): where the eight staged entries live.** This is
    a new architectural question no prior module had.
    - **The gap:** REG-002 defines each `ILOCK_STAGE_*` register as a single
      `internal_reg` register in RTL-001. Yet REG-3228 says "reads selected
      entry's staged response mask", REG-COH-001 says "selector writes do
      not change staged or active object contents", and VP-SAFE-016 requires
      each of the 8 entries to stage and read back independently. Taken
      together, that means 8 independent staged objects. `reggen.py` v4 had
      no way to represent them: one `_q` per address, RW fields forwarded as
      levels with no write strobe, and status mapping only for
      `external`-class registers.
    - **Options considered:** (i) selector-indexed storage in RTL-001,
      forwarding the whole bank; (ii) an RTL-014-side bank captured on new
      RW write strobes, which would also require changing the five STAGE_*
      registers' readback class through the extractor or REG-002.
    - **Chosen: (i).** It keeps staged readback in RTL-001 exactly as REG-002
      classifies it, satisfies ARCH-GEN-019 literally, and needs no
      readback-class change.
    - **Implementation:** `reggen.py` **v5** adds an `indexed_registers`
      field-map declaration. Each named register becomes `depth` stores,
      written and read only at the selector's current entry, plus a
      selected-entry view `{name}_q`. Field-map fields with an explicit
      `"entry": i` forward that entry's store.
    - **Generator checks (fail loud):** non-`internal_reg` target, a
      selector declared after its target (Icarus declaration-before-use), a
      register claimed by two field-maps, and depth exceeding the selector
      range.
    - **Proof of no side effects:** the regeneration diff of
      `dfc_config_regbank_regs.sv` outside RTL-014 is exactly two lines: the
      version-header line, and a trailing comma on the previous last port.
      Every other consumer's output is byte-identical.
    - **Cost:** 5 x 8 x 32 = 1,280 stored bits (Yosys trims unused high
      bits) and one 8:1 mux in front of five read-mux cases. Item 48's
      readback hub gets 5 slightly deeper inputs. This is worth watching on
      future builds.

69. **Real, disclosed design: COMMIT_ALL validation details (CHTR-DOC-006,
    no owning table exists).**
    - **Field order within an entry:** TERM0, TERM1, TERM2, TERM3 (C.3 legal
      0-31 or 37), then OPERATOR 0-3, then the cross-field "enabled entry
      requires nonzero guard" check. This order follows REG-002 register
      order and is consistent with F.4's "range, then cross-field
      relation". Entries are checked in parallel; the first error in
      **entry order** wins, selected by a documented `casez` encoder.
    - **Error codes** (now owned by ARCH-VAL-014): 1-4 TERM0-3 illegal, 5
      OPERATOR illegal, 6 enabled entry with zero guard.
    - **Where the first error is reported:** ILOCK_STATUS has no first-error
      field, so it is reported only in event 0x0042's detail (subtype 3,
      `event_data[15:8]` = entry, `[31:16]` = code).
    - **RESOLVED in the same session:** REG-COH-003's "records the first
      error" had no host-readable home. REG-002 REG-3204 gained RO
      `FIRST_ERROR_ENTRY` (20:18) and `FIRST_ERROR_CODE` (24:21) in
      ILOCK_STATUS's former reserved bits. ARCH-VAL-014 now owns the field
      order and the code table. `dfc_rtl014_status_t` grew 108→115 bits.
      Retention: captured on the earliest rejection since COMMIT_REJECTED
      was last clear, cleared with it, and a same-cycle new rejection wins
      (F.4). These are proven by four host-read checks in
      `rtl014_integration_tb.sv` Part 7.
    - **Not checkable here:** ARCH-VAL-014's "zero reserved bits" cannot be
      checked in RTL-014, because reserved register bits are never
      forwarded and RTL-001 has no per-field reserved validation (item 4).
    - **Response mask:** `SAFETY_RESPONSE_MASK` 0-15 is always legal.
    - **Timing:** for timing, the staged bank and the COMMIT_ALL pulse are
      registered together one cycle inside RTL-014, so validation reads
      local registers (the items 41/57/65 technique). The commit result
      therefore lands two edges after the RTL-001 pulse, not one. F.4 says
      "a commit result is one cycle". The validated bank is still exactly
      the bank present in the COMMIT_ALL cycle (RTLSTD-SEQ-010). Disclosed.

70. **Real, disclosed design: LATCH_VIOLATION (precedent ARCH-002 SS10.4
    `LATCHED_REQUEST`, and item 62's active-vs-sticky lesson).**
    - **Equation:** effective violation = `ILOCK_CONTROL.ENABLE &
      entry_enable & (live_violation | (LATCH_VIOLATION &
      VIOLATION_STICKY))`.
    - **Latch off:** guards, the lane-2 response, and the event/IRQ follow
      the live condition.
    - **Latch on:** they stay asserted until the host clears that entry's
      sticky bit. A clear is ineffective while the violation is still live
      (new evidence dominates, REG-3204/DFC-SAFE-0009).
    - `VIOLATION_ACTIVE` always reports the live condition, and
      `fault_req_o` uses live violations only (C.6 "active condition").
    - `ILOCK_CONTROL.ENABLE=0` releases everything but does **not** clear
      sticky evidence. REG-002's "Reset/disable, then new evidence" priority
      could also be read as "disable clears"; the conservative,
      evidence-preserving reading was chosen.

71. **Real, disclosed interpretations: guard and satisfied outputs.**
    - **Guard rule:** a guarded action g is inhibited when any
      effective-violated entry has bit g in its guard mask (DFC-FUNC-0107).
      `interlock_inhibit_o[g] = ~GUARD_ALLOWED[g]`, indexed **per guard**.
    - **Satisfied output:** `interlock_satisfied_o[e] = ENTRY_TRUE[e] =
      ENABLE & entry_enable[e] & expression[e]`, indexed **per entry**.
      Nothing in the owning documents states this index. If both ports were
      per guard, they would be redundant complements. RTL-016's 8-bit
      `SAFETY_INTERLOCK_MASK.REQUIRED_INTERLOCKS` ("required
      interlock-permission mask") is their consumer and must be read
      against this choice when RTL-016 is built.
    - **Reset values:** during reset or module reset, `interlock_inhibit_o =
      0xFF` (Appendix A reset 1), and GUARD_ALLOWED/satisfied are 0
      (REG-3220 reset 0x00).
    - **Steady state:** with no enabled entry, or with `ENABLE=0`, every
      guard is allowed. Nothing configured means nothing is inhibited.
    - **Same-edge rule (VP-SAFE-007):** all guard, violation, response, and
      fault outputs register from one combinational evaluation on one edge.
      `rtl014_integration_tb.sv` checks this on every edge across a
      12-transition sweep. A **negative control** (inhibit made one cycle
      late) was confirmed to fail that check, with 12 bad cycles counted,
      before the fix was restored.

72. **Real, disclosed design: lane-2 `response_req_o` (one 8-bit
    `dfc_safety_response_req_t`).** `valid` asserts when any
    effective-violated entry has a nonzero response mask. `source_id` is the
    **lowest** such entry, the same rule as RTL-013's primary-source
    selection. `response_mask` is that entry's mask. A zero mask requests
    nothing. Other simultaneously violated entries are not represented in
    the single request: ARCH-CONN-008 forbids merging before authorization,
    and no owning text defines a multi-source encoding. This can't be done
    better until RTL-016's per-source authorization exists. `source_id` is 3
    bits, so it can never name a reserved lane-2 ID (RTLSTD-SAFE-014).

73. **Real, disclosed gaps, no functional consequence.**
    - `status_o.fault` is held 0. No local fault source is detectable,
      because the active bank can only ever hold validated values.
    - `status_o.ready` is 1 from the cycle after reset release (mandatory,
      D.1 bit 13).
    - `operating_state_i`/`observational_mode_i` have no equation in
      RTL-014's owning contracts (observational output gating belongs to
      RTL-016, REG-GEN-012); they go to the unused sink.
    - The selected-entry staged view members of `control_i` are forwarded
      but unused (staged readback is RTL-001's own store).

74. **Real, disclosed, PROJECT-WIDE finding, not fixed: event `source_id`
    convention vs Appendix C.5.** C.5's "Source ID" column is index+1: index
    0 is `0x01` (RTL-001), and index 13 is `0x0E` (RTL-014). All 12 shipped
    producers (RTL-002 through RTL-013) set `evt_record.source_id` to the
    bare **index** instead (e.g. `EVT_SOURCE_INDEX_RTL013 = 8'd12`,
    `dfc_rtl013.sv:547`). RTL-014 follows the shipped convention (`8'd13`)
    so the project stays internally consistent. Which value is correct, and
    whether to fix all 13 modules together, needs a decision. Fixing only
    RTL-014 would split the convention.

75. **Real, disclosed design: events and IRQ.**
    - **Subtypes (C.7 0x0042):** 0 violation (rising edge), 1
      satisfied/recovered (falling edge), 2 commit accepted, 3 commit
      rejected.
    - **Enable gating (F.3 preamble, item 39 precedent):** each active
      entry's own EVENT_ENABLE/IRQ_ENABLE replaces `ILOCK_CONTROL`'s
      module-wide enables for F.3 bits 0-15. The module enables gate bits
      16-18.
    - **IRQ shape:** violation IRQs are level (C.4); recovery, commit, and
      overflow IRQs are one-cycle pulses.
    - **Slot priority:** one shared pending slot, ordered rejected >
      accepted > lowest-entry violation > lowest-entry recovery.
    - **Drop accounting:** every losing candidate, or every candidate when
      the slot is blocked, is counted into the saturating
      `event_drop_count` and sets `event_overflow` (RTL-009/010 precedent).
      For example, three entries recovering in the same cycle record one
      event and count two drops.
    - **Integration stub:** `event_condition_enable_i`/
      `irq_condition_enable_i` are tied to `64'h0` in `dfc_rtl024.sv` (item
      6), so no RTL-014 event or IRQ fires in the integrated build yet.

76. **RESOLVED (2026-10-02): `internal_source_vector` built for the first
    time, and registered proactively.**
    - **Why RTL-024 builds it:** ARCH-002 Appendix A names
      `dragon_core_top.internal_source_vector[63:0]` as the producer of
      `interlock_terms_i`. Nothing in `rtl/` built it before this session.
      Its only other consumer, `RTL-023.route_source_i`, is permanently out
      of scope.
    - **Construction:** `dfc_rtl024.sv` assembles it per C.1 from
      already-real modules' `status_o`, using generated `_HI`/`_LO`
      constants.
    - **Fixed and stubbed bits:**
      - Bit 30 ("any lost link") is a disclosed stub 0, because RTL-015 is
        not built.
      - Bits 33-36 are permanently 0 (RTL-022 is out of scope).
      - Bit 37 is 1; bits 0 and 38-63 are 0.
      - Bit 32 (RTL-014's own "any violation") is included. It is never a
        legal term (C.3), and because the vector is registered there is no
        combinational loop.
    - **Registered from the start:** applying items 48/57/65 before any
      failure, the vector is registered (`internal_source_vector_q`) one
      CORE_CLK before RTL-014 sees it. This adds one cycle between a source
      change and its evaluation. It does not affect which active bank
      evaluates it, or the same-edge guard rule, which is internal to
      RTL-014.

77. **Confirmed, not assumed: RTL-014 needs no physical FPGA pin.** None of
    the 19 Appendix A ports is an external pad, and every C.1 term source is
    an existing internal status signal. No `fpga/ecp5/ulx3s_dfc.lpf` or
    `ULX3S_CONNECTION_MAP.md` change was made. Only the WiFi-shared
    `gp11`-`gp13` remain open.

78. **Real, disclosed verification gap: VP-SAFE-007 and VP-MOD-014 list
    `F-PROP` (formal).** `formal.ps1` covers RTL-001 only, and no RTL-014
    formal harness was added this session. The same-edge guard property is
    proven by T-SIM only: an every-edge monitor plus the item 71 negative
    control. A real immediate-assertion harness, using the
    PROJECT_CONTINUITY Section 2 rules, remains future work.

79. **Real, hard-won lessons from this session.**
    - **(a) Git Bash has no `iverilog` on its PATH on this machine.** A
      bash pipeline like `iverilog ... | head; echo rc=$?` reports `head`'s
      exit code 0 even when `iverilog` was never found (rc 127), which
      looks exactly like a clean compile. Every real compile, simulation,
      and build in this project must go through the PowerShell scripts or
      the PowerShell tool.
    - **(b) Per-entry EVENT_ENABLE gating:** a first-draft testbench part
      expected recovery events from entries staged with EVENT_ENABLE=0. The
      DUT was correct; the stimulus was fixed.
    - **(c) `regbank_smoke_tb.sv` floating inputs:** it declared only 3 of
      RTL-014's 8 individual status ports. The five `ilock_active_*` inputs
      were floating, a pre-existing gap of the items 15/54 class. This is
      moot now: all 8 are aggregated into `rtl014_status_i`. Its Check 3 was
      redirected a 13th time, to `LLINK_STATUS`.

80. **RESOLVED (2026-10-02): a real timing failure on the final RTL-014
    tree, fixed in already-shipped RTL-005.** The person's standing
    approve-before-touching-shipped-files rule was applied under their
    explicit instruction in this session to finish the pass without
    stopping, so the change is disclosed here for review.
    - **The failure.** A first RTL-014 build (Build ID `20261002_130553`,
      before the item-69 first-error fields) passed at 52.18 MHz. The
      final-tree build (`20261002_164121`, which added only 7 first-error
      flip-flops plus a status mux) failed timing at **48.41 MHz (FAIL at
      50 MHz)**, 3.61 ns logic + 17.04 ns routing.
    - **The critical path** was entirely inside RTL-005's event-store push
      cone: arbitration → `push_idx` → `slot_record_q[push_idx]` (24:1 ×
      128-bit) → `pending_write_data_q`. Its hops crossed tiles x=25 → 87 →
      47 → 58 → 111, and no RTL-014 net was on it.
    - **Why RTL-014 matters to it:** RTL-014 turned slot 13 from a constant
      zero, which synthesis had removed, into a live producer. That widened
      this mux in practice.
    - **Router time grew** 6412 s (RTL-013) → 8373 s → 11159 s. That's a
      real congestion signal.
    - **Root cause found by reading the code:** RTL-005's two lowest-set-bit
      encoders were `for` loops where the last assignment wins. That
      synthesizes as a 24-deep serial priority chain, the same shape
      item 65 fix 1 removed from RTL-013. The chain's binary `push_idx`
      then drove a binary-indexed 24:1 record read.
    - **The fix (timing fix #3 in `dfc_rtl005.sv`), with identical
      selection semantics:**
      - each candidate's "no lower bit set" term is an independent parallel
        reduction;
      - the grant is one-hot;
      - the record is read through a one-hot AND-OR mux;
      - `push_idx` is OR-encoded from the one-hot grant.
      Arbitration order, push timing, and every other `push_idx` consumer
      are unchanged. `rtl005_integration_tb.sv` still passes 43/43,
      including its arbitration tests.
    - **Build result after the fix:** a real `build_ecp5.ps1` run (Build ID
      `20261002_203309`, default invocation) reached **55.02 MHz PASS at 50
      MHz**. That is the real, final post-route line; an earlier pre-route
      estimate read 42.89 MHz FAIL.
      - Critical path: 2.18 ns logic + 10.08 ns routing.
      - Utilization: TRELLIS_COMB 30251/83640 (36%), TRELLIS_FF 19045/83640
        (22%), MULT18X18D 12/156.
      - **Router1 time fell from 11159 s to 1356 s.** Removing the serial
        chain and the binary mux cut real routing congestion, not just one
        path.
      - The new worst path starts at RTL-001's `req_accept` and leaves
        RTL-005 entirely.
    - **Verified:** a full `gate.ps1` after the fix passed (lint; sim 18/18,
      894/894; formal bmc+prove; coverage 168/353).

## RTL-015 (Lost-Link Supervisor) integration

**Approval note, read first (same as item 66's own note for RTL-014):**
every ARCH-002/generator decision below was made under the person's
explicit instruction to run the RTL-015 task end to end without stopping
for item-by-item approval. Each one is a real, disclosed decision, logged
here so it can be reviewed and reversed through the normal process, not a
silently settled fact.

81. **RESOLVED (2026-10-03): the monitor index and the activity-ID index are
    the SAME fixed space, not two separate configurable spaces.** The
    task's own briefing (and `RTL-015_RevA.md` SS4's "Per-monitor
    activity-ID select" prose) assumed each of the 8 monitors selects
    which activity ID it watches. REG-002's real field table for
    `LLINK_MONITOR_CONTROL` (REG-330C) has **no such field** -- only
    `ENABLE`/`EVENT_ENABLE`/`IRQ_ENABLE`/`FAULT_ENABLE`/
    `SAFETY_RESPONSE_MASK`. Monitor `m` is hardwired to `activity_i[m]`;
    `LLINK_MONITOR_SELECT` (REG-3308) selects which monitor's
    config/readback you are addressing (the same role as RTL-014's
    `ILOCK_ENTRY_SELECT`), not an activity source. `dfc_rtl015.sv`
    implements the fixed mapping; `RTL-015_RevB.md` corrects the prose.
    This also means VP-SAFE-008's "every reserved identifier (8-15)"
    clause is structurally unreachable, not something a register check
    enforces: `activity_i` is 8 bits wide and no field anywhere accepts an
    ID 0-15 selector, so IDs 8-15 simply have no wire to reach.

82. **RESOLVED (2026-10-03), ARCH-002 struct growth, reusing RTL-014's
    item-68 generator mechanism with zero new `reggen.py` work.**
    - **The gap:** REG-002 describes `LLINK_MONITOR_CONTROL`/
      `QUALIFY_US`/`TIMEOUT_US`/`RECOVERY_US` as "selected monitor"
      registers, but all 8 monitors run simultaneously and continuously --
      a single selected-only view in `control_i` cannot carry that (the
      exact same architectural problem item 68 solved for RTL-014's
      staged bank).
    - **Fix:** these four registers are declared in
      `rtl015_field_map.json`'s `indexed_registers` (reggen.py v5, reused
      unchanged), giving 8 real stores each in RTL-001, selected by
      `LLINK_MONITOR_SELECT.MONITOR`. The complete bank reaches RTL-015 as
      `llink_monitor_m<0..7>__*`. `dfc_rtl015_control_t` grew 128->961
      bits: 8 x 104 bits (enable/event/irq/fault/mask[4]/qualify_us[32]/
      timeout_us[32]/recovery_us[32] per monitor) plus the 14th
      EVENT_OVERFLOW-clear-field instance.
    - **Each of the four field-map entries carries BOTH the struct's
      pre-existing selected-view fields (plain, driven by the generic
      `{name}_q` the indexed-register generator already emits) and the new
      8-wide array**, in one combined `fields` list per register, since
      every bit of the control struct must be covered exactly once and
      `reggen.py` keys `control_registers` by register name. The
      selected-view fields are forwarded but functionally unused in
      `dfc_rtl015.sv` (item 73's RTL-014 precedent).
    - `dfc_rtl015_status_t` needed **no growth** (unlike RTL-014's status
      struct): `LLINK_STATUS.LOST_ACTIVE/STICKY/RECOVERED` are already
      full 8-bit vectors, and `LLINK_ELAPSED_US` is intentionally a single
      selected-monitor readback (RTL-015 mutes its own 8 internal counters
      with the live selector, the same pattern as RTL-014's
      `ILOCK_ACTIVE_RESULT`).
    - **Proof of no side effects:** the regeneration diff of
      `dfc_config_regbank_regs.sv` outside RTL-015 is exactly the version
      header and a trailing comma on the previous last port. Every other
      consumer's output is byte-identical.

83. **RESOLVED (2026-10-03), the `activity_i` bit wiring -- the exact class
    of discrepancy the task's own briefing anticipated, confirmed and
    found to be larger than expected (five conflicting rows, not one).**
    ARCH-002's own `RTL-015.activity_i` row (in RTL-015's own Appendix A
    catalog) gives the producer order verbatim, matching `ARCH-SAFE-007`'s
    ID list word for word: 0 accepted host command, 1 ARINC RX word, 2 CAN
    RX frame, 3 UART RX byte, 4 any qualified GPIO transition, 5 any
    qualified health transition, 6 synchronized user diagnostic
    transition, 7 accepted external watchdog-service pulse. Five OTHER
    Appendix A rows, each in a DIFFERENT module's own port catalog
    (`RTL-012.service_activity_o`->`activity_i[1]`,
    `RTL-017.activity_o`->`[2]`, `RTL-019.activity_o`->`[3]`,
    `RTL-020.activity_o`->`[4]`, `RTL-021.activity_o`->`[5]`) conflict both
    with this order and with each other -- and `RTL-021` (Databus Routing)
    is not even one of the eight legal activity IDs at all. Resolved in
    favor of RTL-015's own port-catalog row, per CHTR-DOC-003 (the port's
    own definition owns the fact of its wiring) and the project's own
    established precedent for exactly this conflict class (items
    1/10/11/13/19/22/37/44/61/74) -- the tenth instance, and the largest
    (five conflicting rows, not one or two). `dfc_rtl012.sv`'s own stale
    comment (`service_activity_o // RTL-015.activity_i[1]`) was fixed to
    `[7]` in the same pass, since it was simply wrong, not merely
    unverified.

84. **Real, disclosed gap -- logged, not invented around.** Activity ID 0
    ("accepted host command") has **no real Appendix A port anywhere** to
    source it from: RTL-001's own real, complete 74-port catalog has
    nothing resembling a "command accepted" pulse (the closest internal
    candidate, `dfc_rtl001.sv`'s own `req_accept` wire, is not a port at
    all, and the project's existing `dbg_regbank_write_en_o` observability
    port is both not in Appendix A and write-only, not matching "accepted
    host command" which should include reads too per RTLSTD-DRI-011's
    accept semantics). `rtl015_activity_vector_comb[0]` is a disclosed
    stub 0 in `dfc_rtl024.sv`. Real, disclosed future work: ARCH-002 needs
    a real port added to RTL-001's own catalog (e.g. `host_cmd_accept_o`)
    before this activity ID can ever be exercised for real.

85. **Real, disclosed design: the QUALIFY_US/TIMEOUT_US/RECOVERY_US
    algorithm (CHTR-DOC-006, no bit-exact algorithm is given in any owning
    document).** Two free-running per-monitor microsecond counters sharing
    one module-wide `us_tick` (the same CORE_CLK/50 divider idiom as
    `dfc_rtl012.sv`'s `elapsed_us_q`):
    - `elapsed_us_q[m]`: time since the last qualifying activity; resets
      to 0 on every effective (natural or injected) activity pulse; LOST
      declares the tick it first reaches `TIMEOUT_US[m]`.
    - `recovery_progress_q[m]`: accumulates while `elapsed_us_q[m]` stays
      within `QUALIFY_US[m]` ("continuous qualified activity"); resets the
      instant a gap exceeds it. RECOVERED (clears LOST) the tick this
      first reaches `RECOVERY_US[m]`. `QUALIFY_US[m]==0` bypasses the gap
      check entirely (same "zero disables" idiom as RTL-010's
      `MAX_AGE_MS`).
    - `ARCH-VAL-015`'s own "QUALIFY_US < TIMEOUT_US" requirement makes the
      LOST-set and RECOVERED-clear conditions mutually exclusive by
      construction -- no extra priority logic needed between them.
    - `TIMEOUT_US==0`, `RECOVERY_US==0` (both required nonzero by
      ARCH-VAL-015), and `QUALIFY_US>=TIMEOUT_US` are each a live
      "configuration rejected" condition feeding `status_o.fault`, the
      same "defend against what RTL-001 doesn't yet reject" precedent
      every prior monitoring module uses (item 4).

86. **Real, disclosed design: injection (ARCH-SAFE-008).**
    `LLINK_ACTIVITY_INJECT.HEARTBEAT` targets the CURRENTLY SELECTED
    monitor, accepted only while `operating_state_i==TEST_DEBUG`: value 1
    injects one activity pulse (ORed into the same effective-activity path
    a natural pulse uses -- no separate tag, since its only observable
    effect is resetting `elapsed_us_q` exactly as real activity would);
    value 2 injects loss evidence (ORs into the LOST-set trigger, taking
    effect only while not already active, the same "first equals" semantics
    the natural trigger uses); value 3 is reserved, defended by simply
    never matching it (item 4 precedent). "Natural loss has priority over
    injected evidence": when both triggers are true the same cycle, the
    SET is tagged natural, never injected. A set caused by the injected
    path is reported as event subtype 3 "injection" **instead of** subtype
    0 "lost" (replacing, not adding a parallel event) -- this satisfies
    "tagged injected, distinguishable from natural evidence" using the
    event record's own subtype field, with no extra bits needed.

87. **Real, disclosed, PROJECT-WIDE finding, not fixed -- same open
    question as item 74, now with a 14th instance.** RTL-015 follows the
    bare-index `source_id` convention all 13 prior producers use
    (`EVT_SOURCE_INDEX_RTL015 = 8'd14`), not Appendix C.5's own
    index+1 "Source ID" column (`0x0F`). Still needs a project-wide
    decision; not resolved here, to stay consistent with the 13 modules
    already shipped.

88. **RESOLVED (2026-10-03), a real bug found and fixed during this
    module's own bring-up -- confirmed by a real simulation trace, not by
    inspection.** The first draft of `recovery_progress_q[m]` free-ran
    whenever `within_qualify[m]` held, completely independent of whether
    the monitor was actually LOST (`active_q[m]`). With `QUALIFY_US=0`
    ("disabled", so `within_qualify` is always true), this let
    `recovery_progress_q[m]` accumulate stale credit continuously, even
    BEFORE any loss ever began. The instant `active_q[m]` set (a genuine
    timeout), `recovery_clear[m]` was ALREADY true from that stale credit,
    clearing `active_q[m]` again the very next cycle -- which let
    `natural_set[m]` re-fire immediately (nothing else had changed), which
    set `active_q[m]` again, which cleared again, forever. A real,
    continuous one-cycle oscillation, confirmed directly via a per-cycle
    simulation trace (`active_q` alternating `00100000`/`00000000` every
    single edge) before being traced to its root cause. **Fix:**
    `recovery_progress_q[m]` is now held at zero whenever `!active_q[m]`,
    so recovery always starts counting fresh from the moment a loss is
    genuinely declared, never with head-start credit from before it began.

89. **RESOLVED (2026-10-03), a related real gap found and fixed in the same
    bring-up session: per-monitor `ENABLE` never actually gated anything.**
    The first draft extracted `ctl_m_enable[m]` but never referenced it
    anywhere in the timer/active logic -- every monitor's absence timer
    ran, and could declare LOST, regardless of its own `ENABLE` bit. Fixed
    two ways, both disclosed, same "disable releases" precedent RTL-014
    already established for its own module-wide `ENABLE=0`:
    - `elapsed_us_q[m]`/`recovery_progress_q[m]` are held at zero while
      `!ctl_m_enable[m]`, so re-enabling a monitor later starts clean
      rather than with a stale timeout.
    - **Disabling a monitor also clears an already-latched
      `LOST_ACTIVE[m]`**, not just future sets -- found directly from a
      real test failure: a monitor that had genuinely timed out from a
      leftover real timer elapsing during an unrelated, earlier test part
      (the same real effect `PROJECT_CONTINUITY.md`/item 64 already
      documented for RTL-013's own whole-system test) stayed permanently
      stuck LOST after being disabled, with no way to clear it short of a
      full module reset, until this fix.
    `rtl015_integration_tb.sv`'s own Part 11/12 needed a matching fix
    (explicitly disabling monitor 2 after exercising it, the same
    discipline RTL-013's own session applied to `WDOG_CONTROL`) once this
    real effect was confirmed, not assumed.

**Verified on the person's machine.** `gate.ps1` passed clean:
- `lint.ps1`: PASSED (24 files)
- `sim.ps1`: 19/19 testbenches, 0 failed, 946/946 checks total
  (12+12+16+28+30+24+43+35+44+47+60+50+60+59+71+105+40+197+13)
- `formal.ps1`: 2/2 tasks PASSED (bmc + prove)
- `check_coverage.py`: 178/353 registers referenced (+10 over the
  RTL-014 baseline, matching RTL-015's 10 new registers exactly)

`build_ecp5.ps1` (LFE5U-85F-6BG381C, `ulx3s_dfc_top`) then built clean:
real, final (last line in `pnr.log`, per this project's own standing
convention that earlier lines are pessimistic pre-route estimates) timing
result **PASS**: `Max frequency for clock '$glbnet$core_clk': 50.53 MHz
(PASS at 50.00 MHz)`. Worst path (posedge->posedge, RTL-010 to RTL-005):
4.30 ns logic, 15.49 ns routing, 19.79 ns total. Utilization:
TRELLIS_COMB 33811/83640 (40%), TRELLIS_FF 20549/83640 (24%),
MULT18X18D 12/156 (7%), TRELLIS_IO 34/365 (9%), EHXPLLL 1/4 (25%).
Build ID `20261003_145704`; bitstream
`output/bitstreams/ulx3s_dfc_20261003_145704.bit`
(SHA-256 `7E7AFD52AA194FF3B3ABB672A8C910406B36C224B083C39891BA7A2C21D1AF63`).

## RTL-016 (Safety Output Controller) integration — closes the Safety domain

**Approval note, read first (same as item 66/81's own note):** every
ARCH-002/generator decision below was made under the person's explicit
instruction to run the RTL-016 task end to end without stopping for
item-by-item approval. Each one is a real, disclosed decision, logged here
so it can be reviewed and reversed through the normal process, not a
silently settled fact.

90. **RESOLVED (2026-10-04): the real Appendix A port list has 22 ports,
    not ~16, and `dfc_rtl016_control_t` is really 226 bits (grown from
    53), not RevA's claimed 52/47 for control/status.** RevA's own SS2
    "RTL-016-specific" list named only `response_req_i`/`fault_inhibit_i`/
    `safety_out_o` -- standard group (13) plus those three reaches 16, not
    22. The real Appendix A rows add six more this module genuinely owns:
    `irq_req_o` (RTL-003.irq_source_i[17]), `fault_req_o`
    (RTL-013.fault_source_i[3]), `interlock_satisfied_i[7:0]`
    (RTL-014.interlock_satisfied_o), `interlock_inhibit_i[7:0]`
    (RTL-014.interlock_inhibit_o, idle 1), `effective_operational_enable_i`
    (RTL-002), and `test_inhibit_i` (RTL-024, idle 1 during reset,
    CDC-TEST-001). Built against the real 22-port list directly.
    `dfc_rtl016_control_t` grew 53->226 bits: a complete 4-channel array
    (`safety_channel_c<0..3>__*`, 43 bits each: enable/active_high/
    latch_response/response_source_mask[32]/required_interlocks[8]) via
    `reggen.py` v5's `indexed_registers` mechanism (reused unchanged a
    third time, zero new generator work -- items 68/82 precedent), plus 1
    bit for `rtl016_evt_overflow_status__event_overflow` -- a real gap
    found while writing `rtl016_field_map.json`: ARCH-002's first-draft
    `dfc_rtl016_control_t` omitted RTL-016's own EVENT_OVERFLOW-clear-
    forwarding control field entirely, the 15th instance of this same gap
    class (item 6 precedent). `dfc_rtl016_status_t` needed NO growth
    (confirmed, not assumed): `SAFETY_STATUS`'s own `COMMANDED`/
    `EFFECTIVE`/`INHIBITED`/`FAULTED`/`EVENT` fields are already complete
    4-bit-per-channel aggregates, and `SAFETY_CHANNEL_STATUS` is
    intentionally a single selected-channel view (same precedent as
    RTL-014's `ILOCK_ACTIVE_RESULT`/RTL-015's `LLINK_ELAPSED_US`).
    `RTL016_EVT_OVERFLOW_STATUS` (0x341C) was already present in REG-002
    and already named in RevA -- unlike every module from RTL-002 through
    RTL-015, this was NOT a gap to add; confirmed real and wired for real.

91. **RESOLVED (2026-10-04): `GLOBAL_INHIBIT` is its own independent RW
    field, not `!safety_control__enable` as RevA's own SS3 equation
    claimed.** REG-002's real `SAFETY_CONTROL` (0x3400) has bit 0 `ENABLE`
    (reset 0) and bit 3 `GLOBAL_INHIBIT` (reset 1) as two INDEPENDENT RW
    fields -- `GLOBAL_INHIBIT`'s own write-validation text says explicitly
    "does not alter controller enable." `SAFETY_CHANNEL_STATUS`
    independently confirms with two separate readback bits
    (`CONTROLLER_DISABLED` bit 10, `GLOBAL_INHIBIT` bit 11, both reset 1).
    `dfc_rtl016.sv` uses both as separate PERMIT[c] AND terms -- collapsing
    them into one signal (RevA's equation) would mean a host could never
    inhibit outputs globally without fully disabling the controller, or
    vice versa, a real functional/safety distinction.

92. **RESOLVED (2026-10-04): `fault_inhibit_i` is genuinely per-channel,
    not module-wide as RevA's own SS3 prose claimed ("asserted for EVERY
    channel... RTL-013-wide, not per-channel-specific").** The real
    Appendix A row for `fault_inhibit_i` says "per-channel active-high
    inhibit," sourced from `RTL-013.safety_inhibit_o` -- a real 4-bit
    port, not a single bit fanned out. Confirmed directly against
    `dfc_rtl013.sv`'s own driving assignment:
    `safety_inhibit_o = {4{ctl_enable && (|nonrecoverable_active17)}}` --
    all four bits DO currently carry the same value (RTL-013 has no real
    per-channel fault classification yet), but `dfc_rtl016.sv` indexes the
    port per channel (`fault_inhibit_i[c]`), not as a single module-wide
    gate, so a future RTL-013 revision with real per-channel fault scoping
    needs no RTL-016 change.

93. **RESOLVED (2026-10-04): TEST_DEBUG is a genuinely separate term this
    module must OR in itself -- NOT already inside `test_inhibit_i`.**
    ARCH-002 SS10.4 defines `TEST_INHIBIT` as the OR of (a) physical
    production-test authorization, (b) qualified test-active, AND (c)
    TEST_DEBUG. But `test_inhibit_i`'s own Appendix A producer description
    is only "RTL-024 physical test authorization OR test-active" -- terms
    (a) and (b), NOT (c). TEST_DEBUG (`dfc_operating_state_t` 3'b111) is a
    distinct primary operating state this module already receives via
    `operating_state_i`, orthogonal to the registered `test_active_i`
    qualifier RTL-002 broadcasts separately. `dfc_rtl016.sv` therefore ORs
    `operating_state_i==TEST_DEBUG` into `test_inhibit_i` itself to form
    the single `TEST_INHIBIT` term PERMIT[c] uses -- algebraically
    identical to RevA's own two separate `!test_inhibit & !TEST_DEBUG` AND
    terms (De Morgan: `!A & !B` == `!(A|B)`), so RevA's PERMIT *value* was
    actually right here even though its stated reasoning ("already
    included") was not; the real canonical PERMIT[c] (ARCH-002 line 349)
    has exactly ONE TEST_INHIBIT term, not two, and the combined value is
    also what `SAFETY_CHANNEL_STATUS.TEST_INHIBIT` (bit 7) reports.

94. **RESOLVED (2026-10-04): PERMIT[c] is a real nine-term AND, not RevA's
    eight.** RevA omitted `RESET_HELD[c]` and conflated
    `CONTROLLER_DISABLED` into `GLOBAL_INHIBIT` (item 91). The real
    equation (ARCH-002 line 349): `PERMIT[c] = !CHANNEL_DISABLED[c] &
    !CONTROLLER_DISABLED & !GLOBAL_INHIBIT & !OPERATIONAL_INHIBIT &
    !OBSERVATIONAL_INHIBIT & !TEST_INHIBIT & !INTERLOCK_INHIBIT[c] &
    !FAULT_INHIBIT[c] & !RESET_HELD[c]`. `RESET_HELD` is computed once
    (shared across channels, no per-channel reset mechanism exists) as
    `!core_rst_n_i | module_reset_i | (operating_state_i==RESET_ACTIVE)`
    -- covering external reset, safety-domain/system reset (RTL-002
    dispatches both to `module_reset_o[15]` per ARCH-RST-006), and
    reset-release qualification. In practice every other PERMIT term
    already independently reads its own "blocked" reset-default value
    while truly in reset (the DRI bus cannot be written while held in
    reset), so `RESET_HELD` is implemented faithfully per the literal
    nine-term equation rather than omitted as provably redundant under
    today's wiring (CHTR-DOC-006).

95. **RESOLVED (2026-10-04), the single most structurally subtle finding
    this session: `INTERLOCK_INHIBIT[c]` must use RTL-014's GUARD-indexed
    `interlock_inhibit_o`, NOT its ENTRY-indexed `interlock_satisfied_o`.**
    `dfc_rtl014.sv`'s own header comment (its own SS5 "GUARDS") is
    unambiguous: `GUARD_ALLOWED[g]` = no effective-violated entry has bit
    `g` in its guard mask; `interlock_inhibit_o = ~GUARD_ALLOWED` is
    indexed PER GUARD (an 8-position space RTL-014's own per-entry 8-bit
    `guard_mask` fields select into), while
    `interlock_satisfied_o[e] = ENTRY_TRUE[e]` is indexed PER ENTRY
    (RTL-014's own 8 interlock expressions) -- "the two ports would be
    redundant complements if both were per guard" (RTL-014's own words).
    These are NOT the same 8-bit space. REG-002's real
    `SAFETY_INTERLOCK_MASK` (0x3414).`REQUIRED_INTERLOCKS` is "Required
    interlock-permission mask for SELECTED CHANNEL" -- a per-channel
    subset of the GUARD space, confirming
    `INTERLOCK_INHIBIT[c] = OR over g in required_interlocks[c] of
    interlock_inhibit_i[g]`. `interlock_satisfied_i` (entry-indexed) is
    consequently a real Appendix A port this module receives with NO
    functional use in the PERMIT equation and NO REG-002 status field
    anywhere to expose it (`SAFETY_CHANNEL_STATUS` has no "satisfied" bit,
    only `INTERLOCK_INHIBIT`) -- a disclosed, genuinely unused real input,
    consumed only by the unused-port sink, confirmed by a real test
    (toggling it has no effect) not just by inspection.

96. **RESOLVED (2026-10-04), the two-layer response-authorization model --
    resolved from first principles, since neither RevA nor ARCH-002
    SS10.4's prose spells this out in full, though C.8 and REG-ENC-015
    together fix it exactly.** Each lane's `dfc_safety_response_req_t`
    carries THREE fields: valid, source_id (0-7, which of that lane's own
    sources is currently winning), and response_mask (4 bits -- the
    PRODUCER's own already-configured "which of RTL-016's 4 output
    channels do I want" selection, e.g. RTL-014's own per-entry
    SAFETY_RESPONSE_MASK field). SEPARATELY, THIS module's own
    SAFETY_RESPONSE_MASK register (0x3410, selected-channel-indexed, 32
    bits, legal bits only C.8's 0/8/16-23/24-31) is channel c's
    AUTHORIZATION over the full 32-position (lane,source) space
    (`mask_bit = 8*lane + source_id`, ARCH-002 SS10.2). `AUTHORIZED_REQ[c]`
    therefore requires BOTH: the producer's own response_mask bit c set,
    AND this module's own channel-c authorization bit (8*lane+source_id)
    set -- a genuine two-key design (the source decides what it wants;
    this module's own host-configured authorization independently decides
    whether it is allowed), matching SS10.4's literal "whose response mask
    contains c AND whose fixed authorization bit is set" wording. Verified
    with both a positive test (both keys set -> authorized) and a negative
    test (producer wants it, this module's own authorization bit for that
    exact (lane,source) not set -> NOT authorized) in
    `rtl016_integration_tb.sv` Part 6.

97. **RESOLVED (2026-10-04), `LATCHED_REQUEST[c]` clear semantics --
    ARCH-002 SS10.4's literal text, more specific than and not identical
    to RTL-014/015's own "disable releases" precedent (items 68/89).** The
    clear is qualified "after every contributing request is inactive" for
    the level-held cause (channel disable): while disabled AND
    `REQUESTED[c]` is still live, the latch HOLDS (new evidence dominates
    a level-held clear attempt, the same project-wide sticky precedent)
    and only actually clears the cycle `REQUESTED[c]` drops. "Re-enabling
    a channel begins with its latch clear" is a SEPARATE, unconditional
    edge-triggered override applied exactly on the disabled-to-enabled
    transition, regardless of any request still live that cycle (a
    deliberate host action; PERMIT[c] still gates the actual output
    independently). `core_rst_n_i`/`module_reset_i` clear the latch
    unconditionally via the ordinary reset branch, the same as every other
    sticky/latch register in this project (RTLSTD-RST-005/008) --
    satisfying "safety-domain reset, system reset, external reset"
    without needing a request-inactive qualifier on the reset path itself.

98. **REAL, EMPIRICALLY-CONFIRMED FINDING -- NOT caused by RTL-016, found
    while verifying RTL-016's own whole-system integration.**
    `rtl024_skeleton_tb.sv`'s long-standing "RTL-002 reaches FAULTED via
    the ~499,000-cycle mandatory-init timeout" outcome was expected to
    change now that every mandatory-mask module (RTL-001/002/004/005/
    012/013/014/015/016/024) is finally real -- it does NOT, confirmed by
    actually running the test (197/197, then 219/219 with the new RTL-016
    section, both reaching FAULTED exactly as before), not by assuming the
    fix would land automatically. The real root cause is a genuine
    structural self-reference in RTL-002's own already-shipped FSM, found
    by reading `dfc_rtl002.sv` directly after the empirical result
    contradicted the expectation: `mandatory_ready_now` requires
    `module_ready_i[1]` (RTL-002's OWN self-looped `status_o.ready`), but
    RTL-002's own `status_o.ready = host_ready_q && init_complete_q`, and
    `init_complete_q` is only set the cycle STARTUP transitions away
    (which itself requires `mandatory_ready_now`) -- a self-referential
    gate that can never be satisfied by `mandatory_ready_now` alone,
    regardless of how many OTHER mandatory modules are real.
    `init_timeout_expired` is therefore not a disclosed consequence of
    incomplete stub topology (this project's own standing assumption,
    carried in `rtl024_skeleton_tb.sv`'s own comments since early
    sessions); it is the ONLY path STARTUP can ever leave by in the
    current RTL-002 design. Not fixed here -- out of RTL-016's own scope,
    a real, disclosed finding about already-shipped RTL-002, logged for
    whoever picks up RTL-002 again, not silently worked around.
    `rtl024_skeleton_tb.sv`'s own comment block was corrected in the same
    pass (removing the now-wrong "remaining stub module" attribution).

99. **REAL TIMING FIX, found by `build_ecp5.ps1`, not assumed: a real,
    already-marginal path inside already-shipped `dfc_rtl014.sv` failed
    for the first time once RTL-016's own added placement/routing
    pressure tipped it over -- 49.52 MHz vs 50.00 MHz required.** The real
    critical path report traced from a flop inside RTL-024's own
    `internal_source_vector_q` (already registered, per items 48/57/65's
    own fan-in-hub precedent), combinationally through RTL-014's own
    64:1 term-select mux (`tv[e][k] = interlock_terms_i[active_q[...]] ^
    active_q[...]`, 32 of these -- 8 entries x 4 terms, each a real 64:1
    dynamic multiplexer) and expression evaluation, into `fault_q` -- one
    long hop, 4.03 ns logic + 16.16 ns routing = 20.19 ns, the routing
    portion dominated by the long physical distance between
    `internal_source_vector_q`'s bits and RTL-014's own mux. **Fix:** a
    new free-running `interlock_terms_q` register inside `dfc_rtl014.sv`
    itself, registering `interlock_terms_i` again, UNCONDITIONALLY every
    cycle -- deliberately NOT tied to `commit_accept`/`active_q`'s own
    update, so it adds no delay to `ARCH-RTL014-001`'s own "same-edge
    guard rule" / "no grace period for a freshly committed bank"
    guarantee (that rule governs how fast the BANK's own configuration
    takes effect, not how fresh the external term-source vector is). The
    64:1 mux now reads `interlock_terms_q` instead of `interlock_terms_i`,
    splitting the one long hop into two: external flop -> (already-
    existing) `internal_source_vector_q` -> (new) `interlock_terms_q`,
    then `interlock_terms_q` + `active_q` -> the SAME-EDGE evaluation ->
    `fault_q`/etc, exactly as before. The only real, disclosed consequence
    is one additional CORE_CLK cycle between a real-world
    `interlock_terms_i` change and its reflection in violation state --
    the same "capture this cycle, commit the next" precedent already used
    repeatedly in this project (items 41/57/65), applied one stage closer
    to this specific consumer. Re-ran the full `gate.ps1` regression after
    the fix: identical results (`rtl014_integration_tb.sv` still 105/105,
    `rtl024_skeleton_tb.sv` still 219/219) -- the extra cycle did not
    break any existing check's own timing margin. This is the same
    discipline the RTL-014 session's own RTL-005 fix established: a fix
    to an already-shipped file is applied directly when a real build
    demands it, fully disclosed here, verified via full regression, never
    worked around with `--timing-allow-fail` or seed-hunting. Confirmed
    by a real, complete rebuild: final `pnr.log` reads `Max frequency for
    clock '$glbnet$core_clk': 51.22 MHz (PASS at 50.00 MHz)` (Build ID
    `20261004_142815`), worst path 3.36 ns logic + 16.17 ns routing =
    19.53 ns total.

**Verified on the person's machine.** `gate.ps1` passed clean:
- `lint.ps1`: PASSED (25 files, +1 for `dfc_rtl016.sv`)
- `sim.ps1`: 20/20 testbenches, 0 failed, 1039/1039 checks total
  (12+12+16+28+30+24+43+35+44+47+60+50+60+59+71+105+40+71+219+13 --
  independently summed; equals the RTL-015-session baseline of 946 plus
  71 new `rtl016_integration_tb.sv` checks plus 22 new
  `rtl024_skeleton_tb.sv` checks, 946+71+22=1039, exact)
- `formal.ps1`: 2/2 tasks PASSED (bmc + prove)
- `check_coverage.py`: 186/353 registers referenced (+8 over the
  RTL-015 baseline, exactly RTL-016's 8 new registers)

## RTL-024 Centralized Shared-Buffer Service (ARCH-002 SS12) integration

Infrastructure session, not a new RTL-0NN module: implements the
centralized 512-word shared-buffer service RTL-017 through RTL-022 (and
RTL-024's own SPI path) will depend on, ahead of the Databus domain.

100. **Architecture decision: centralized shared buffer kept over
     per-module private RAM, after a real, adversarial design review --
     logged here because the alternative was seriously considered, not
     because the `-002` documents left this ambiguous.** Mid-session, the
     centralized design (one arbiter, one `PDPW16KD`-backed store, 7
     typed clients per ARCH-002 SS12) was challenged in favor of giving
     each of RTL-017 through RTL-022 its own private block RAM. Both
     sides were argued out concretely, not abstractly:
     - *For per-module RAM:* removes the 7-client round-robin arbiter and
       its associated timing-closure risk class (this project's own
       `OPEN_ISSUES.md` items 17/48/57/65/99 already document repeated
       wide-fan-in/arbitration-mux timing failures); removes the
       RTL-024-SPI-bridge/`ARCH-SPI-005` friction that came up mid-
       investigation (see item 101); the shared-buffer error class
       (`RANGE_ERROR`/`PROTOCOL_ERROR`) becomes structurally impossible
       with private per-module addressing instead of merely rare.
     - *For the centralized design:* every one of the 7 clients' entry
       words is 32 bits wide under ARCH-002 SS12.3's own entry layouts
       (`ARCH-BUF-021` through `-028`) -- confirmed directly against the
       real `DP16KD`/`PDPW16KD` primitive limits (Yosys's own ECP5
       techlib: true independent-port access caps at 18 bits/side, a
       hard pin-count limit of the physical 18Kbit EBR tile, not a Yosys
       quirk -- cross-checked against Microchip/Intel EBR documentation
       and found to be a universal block-RAM architecture pattern, not
       ECP5-specific), so ANY module needing a 32-bit word pays the
       pseudo-dual-port-combination cost regardless of which design wins
       -- paid ONCE centrally, or separately for every one of RTL-017
       through RTL-022 under a per-module design (confirmed concretely:
       RTL-019's CAN entries need the full 29-bit identifier, RTL-021's
       192-bit canonical message sliced into 32-bit chunks needs the full
       width -- neither shrinks under repacking). The technology-wrapper-
       swap engineering itself (generic behavioral body + real-primitive
       FPGA body + build-script inclusion/exclusion logic -- see item 104)
       would also multiply per module instead of being done once. Shared
       arbitrated aggregation is also this project's own established
       pattern, not a novel one: RTL-005's 24-producer event store already
       runs a real round-robin arbiter into one shared store; RTL-003/013/
       016 all aggregate many independent sources through one shared
       structure.
     - *Residual, not numerically resolved either way:* this is this
       project's first BIDIRECTIONAL arbitrated READ-AND-WRITE access
       structure across heterogeneous clients -- RTL-005's precedent is
       write-mostly/append-only from producers with a separate simple
       host-read path, not the same shape. This genuine novelty is why
       this session pursued formal proof for the arbiter's core safety
       properties rather than simulation alone (item 103), instead of
       treating the cost/benefit numbers alone as dispositive.
     **Decision: keep the centralized design**, per explicit instruction,
     with the elevated verification rigor in item 103 as the direct
     answer to the residual novelty risk.

101. **RTL-024's own SPI bridge (`dfc_rtl024_spi_bridge.sv`) is a
     PERMANENT, SETTLED exception to the shared-buffer service -- client 6
     (`RTL-024 SPI`) is real, arbitrated, and fully exercised by
     `rtl024_buffer_tb.sv`'s own direct stimulus, but has NO real producer
     connected to it, by final decision, not by omission.** ARCH-BUF-001/
     002 allocate buffer words `0x000-0x01F` to "RTL-024 SPI command/
     response," and ARCH-BUF-021 describes per-word DRI-data-word staging
     there. Investigating whether the bridge's existing command-word
     capture (`data_words_q`) and response read-data staging
     (`rdata_shift_q`) should be redirected through client 6 found two
     independent, real obstacles, not a hypothetical one:
     - A genuine real-time margin problem for the response side:
       redirecting `rdata_shift_q` needs a client-6 WRITE (stash the
       register-read result into the response segment) THEN a client-6
       READ (fetch it back for framing) per word, each up to ~15 CORE_CLK
       cycles under `ARCH-BUF-014`'s worst-case 7-cycle acceptance wait +
       `ARCH-BUF-015`'s 8-cycle completion bound -- for up to 16 words
       that is ~480 cycles worst case against an ~80-cycle total budget
       (`DFC-INTF-0024`'s "0-2 wait-fill byte" allowance at the fastest
       legal 10 MHz SCLK), 6x over.
     - A DECISIVE, independent reason that makes the margin problem moot:
       `ARCH-SPI-005` ("the response builder constructs ONE COMPLETE
       STABLE response payload BEFORE the response mailbox ownership
       toggle") directly forbids the streaming/overlap restructuring
       (ship the header while later words are still being fetched) that
       would otherwise have closed the margin gap -- a genuine
       requirement-ordering conflict, not something any amount of buffer
       speed or reduced contention fixes.
     The write-side redirect (`data_words_q`, during live SPI command
     reception) was confirmed to have ample real margin (~160 CORE_CLK
     cycles/word available at the fastest legal 10 MHz SCLK vs. ~15
     needed) and no `ARCH-SPI-005` conflict (it completes before response
     construction begins) -- but by final, explicit instruction, client 6
     stays wholly unconnected and `dfc_rtl024_spi_bridge.sv` is left
     completely untouched (confirmed zero diff against its last known-good
     commit). **This is final, not an implied TODO.** If client 6
     integration is revisited later, it requires a fresh decision that
     reconsiders `ARCH-SPI-005` itself (a different definition of
     "response payload," or a different CDC/mailbox handoff model) --
     not a continuation of this investigation.

102. **Disclosed coverage gaps, all structural, not oversights:**
     - **Whole-system integration**: `rtl024_skeleton_tb.sv` was
       deliberately NOT extended with a real buffer round-trip this
       session (per explicit instruction) -- there is no real client to
       round-trip through yet (RTL-017 through RTL-022 don't exist;
       client 6 is permanently excluded per item 101). True whole-system
       buffer integration can't be proven until the first real Databus
       client exists -- same precedent as RTL-005's own disclosed gap
       before real event producers existed.
     - **Arbitration fairness stimulus**: `rtl024_buffer_tb.sv`'s
       contention-stress case drives only clients 0-5 directly (client 6
       excluded per item 101) -- real coverage of the arbiter's fairness
       logic, just not full 7-client coverage with a real producer behind
       every port.
     - **VP-BUF-007 (multiword-entry atomicity), VP-BUF-008 (word-order/
       layout preservation), VP-BUF-009 (per-client pointer/evidence
       ownership), VP-BUF-011 (uninitialized-word non-disclosure)**: all
       four are CLIENT-MODULE responsibilities under RTLSTD-MEM-003
       ("queue-control state stays in the client modules, not here"), not
       properties this service can exercise in isolation. `rtl024_
       buffer_tb.sv` covers this service's own relevant contribution to
       each (adjacent-word independence for -008, error-evidence ownership
       for -009) but genuine entry-level coverage needs a real RTL-017..
       022 client, same structural gap as above.
     - **VP-BUF-012 (FPGA/ASIC behavioral equivalence)**: only a real
       `build_ecp5.ps1` synthesis/PnR run (confirming `PDPW16KD` placement,
       item 104) can speak to this; simulation against the generic
       behavioral memory body cannot prove primitive-level equivalence on
       its own.

103. **Formal verification of the arbiter's core safety properties --
     pursued and PROVEN by k-induction, not simulation alone, per this
     session's own elevated-rigor instruction for this project's first
     bidirectional arbitrated heterogeneous-client access structure.**
     `verification/formal/rtl-024/buffer_arbiter_formal.sv` +
     `buffer_arbiter.sby`, real `sby` runs (not aspirational):
     - `P_MUTEX` (at most one client's request ever reaches the memory
       port in a given cycle, `$onehot0` on the grant vector, ARCH-BUF-014)
       -- **PASSED**, both `bmc` (depth 40) and `prove` (k-induction
       basecase + induction, unbounded).
     - `P_RANGE_CHECK` (a granted request's derived absolute address can
       never fall outside its own client's assigned segment, for every
       legal and illegal `word_offset` value -- not sampled cases,
       ARCH-BUF-016/RTLSTD-MEM-006) -- **PASSED**, both `bmc` and `prove`.
     - `P_ONE_OUTSTANDING` (a client already outstanding is never granted
       a second acceptance, ARCH-BUF-013) -- **PASSED**, both `bmc` and
       `prove`.
     - `P_FAIRNESS` (every continuously eligible client accepted within 7
       acceptance opportunities, ARCH-BUF-014) -- **NOT attempted as a
       formal property, explicitly, not silently dropped.** It is a
       BOUNDED LIVENESS property ("eventually, within 7 cycles"), which
       would need either an unrolled multi-cycle BMC assertion over a
       sliding 7-cycle x 7-client window (expensive, and this project has
       no existing liveness/cover-based formal flow to build on -- every
       other formal harness in this project checks safety properties
       only) or a dedicated flow this session did not have time to stand
       up from scratch. Covered instead by `rtl024_buffer_tb.sv`'s own
       direct simulation (VP-BUF-005/ARCH-BUF-014 case: measures the real
       max inter-grant gap under continuous 6-client contention, confirms
       <=7 cycles) -- real coverage, simulation-only for this one
       property, disclosed rather than blended in with the three formally
       proven ones.
     **A real, confirmed toolchain finding along the way, not assumed**:
     an initial version of this formal harness used hierarchical
     references (`u_dut.grant_onehot` etc.) to observe the DUT's internal
     arbiter state -- exactly the pattern `dri_one_outstanding_formal.sv`
     already warned doesn't work on this toolchain, and this session hit
     the identical failure mode directly: Yosys's native frontend silently
     turns a hierarchical reference into a free, undriven phantom wire
     instead of resolving it, producing a bogus "failing" counterexample
     driven entirely by that phantom wire's own unconstrained value. Fixed
     the same way `dfc_rtl001.sv`'s `dbg_regbank_write_en_o` already
     established: real, permanent `dbg_*_o` observability ports added to
     `dfc_rtl024_shared_buffer.sv` (`RTLSTD-MOD-014`'s exception for formal
     observability, not a production-interface violation).

104. **Primitive choice: `PDPW16KD` instantiated directly
     (`fpga/ecp5/dfc_mem_sp_512x36_ecp5.sv`), not a hand-wired `DP16KD`
     with both physical sides combined.** Confirmed from Yosys's own
     `techlibs/lattice/cells_bb_ecp5.v` (real blackbox port declaration:
     clean, separate `ADW[8:0]`/`ADR[13:0]`/`BE[3:0]` buses) and
     `techlibs/lattice/brams_map_16kd.v` (the alternative route: building
     a 36-bit word from bare `DP16KD` directly repurposes `ADA0`-`ADA3` as
     write-enable lanes at width >=36, with the real address starting at
     `ADA4` -- confirmed directly from the real techmap source, not
     inferred). `PDPW16KD` avoids that repurposing ambiguity entirely and
     is also the standard, vendor-recommended configuration for a
     write-only-port/read-only-port access shape in general, not a
     workaround. Two minor, unreconciled discrepancies the research
     surfaced, neither resolved by guessing:
     - `CSDECODE_W`/`CSDECODE_R`: **this exact discrepancy was the real
       root cause of item 112's `nextpnr-ecp5` crash, confirmed and fixed
       -- see item 112's own full account.** The `3'b000` sized literal
       used here turned out not to be a harmless convention match; it is
       what caused the crash, once a real `PDPW16KD` cell finally reached
       `nextpnr-ecp5`'s own report-generation code path for the first
       time. Fixed to `"0b000"` (a genuine string literal, matching
       Yosys's own primitive default format exactly).
     - `GSR("AUTO")`: Yosys's own working `synth_ecp5` output always
       chooses `"AUTO"` over the blackbox's simulation default
       `"ENABLED"`; Lattice's own Appendix A does not document `GSR` at
       all. This file matches Yosys's own known-working synthesis default
       rather than the simulation default, disclosed as matching observed
       tool behavior, not an independently-verified semantic choice.
     **Real `build_ecp5.ps1` confirmation, done -- with a genuine,
     disclosed result, not a clean pass assumed in advance.** The
     whole-chip build's `Device utilisation` line reads `DP16KD: 0/208`.
     This is NOT a primitive-mapping failure -- confirmed by a SEPARATE,
     isolated `synth_ecp5` run targeting only `dfc_mem_sp_512x36_ecp5.sv`
     (so its ports stay genuinely observable, not provably dead), which
     placed exactly 1 `PDPW16KD`/`DP16KD` cell correctly. The whole-chip
     0/208 is a real, correct reachability fact instead: every one of the
     7 clients is tied to permanent idle in today's integration (item
     101/102), so `buf_req_valid_i` is a compile-time constant 0 and this
     entire subsystem's output is provably constant -- a correct optimizer
     removing it entirely is the right behavior, not a bug. Two
     independent attempts to force preservation anyway (`(* keep *)` on
     the instantiation line, then on the module declaration) were tried
     and confirmed to have NO effect -- three full rebuilds produced
     byte-identical timing (39.72 MHz pre-route estimate / 52.06 MHz
     final, both PASS at 50.00 MHz) and utilization results regardless.
     Forcing a misleading nonzero count would have been worse than
     disclosing the real state. **A real nonzero whole-chip placement
     count can only be confirmed once a genuine client (RTL-017 or any
     other) actually drives traffic through this service** -- logged here
     as a required follow-up check for whoever builds the first real
     Databus client, not an open item against this session's own work.

105. **`PROTOCOL_ERROR` and `INTERNAL_ERROR` are structurally unreachable
     in this implementation -- disclosed, not silently invented.**
     `PROTOCOL_ERROR`'s one plausible RTLSTD-MEM-006 trigger ("excess-
     outstanding request") is prevented BY CONSTRUCTION (a client with one
     outstanding request is simply excluded from arbitration, never
     reaching a response path at all) rather than detected-and-coded.
     `INTERNAL_ERROR` has no defined trigger anywhere in this synchronous,
     fixed-2-cycle-latency, single-memory-child design (no ECC, no
     variable timing, nothing that can fail internally the way
     `ARCH-BUFERR-001` anticipates). Both codes are fully wired through
     (`BUFFER_STATUS`/`BUFFER_INTERNAL_ERROR_COUNT` logic exists and is
     verified correct IF driven -- `rtl024_buffer_tb.sv`'s own checks
     confirm `RANGE_ERROR` does NOT increment the internal-error count,
     exercising the discrimination logic even though the `INTERNAL_ERROR`
     path itself is never taken), but neither code is ever produced by any
     real stimulus in this build.

106. **Host-write-clear path for `BUFFER_STATUS` (W1C) and the five
     `BUFFER_*_ERROR_COUNT` registers (`COUNTER16-CLR`/`COUNTER-CLR`) does
     not exist -- a real, confirmed, PRE-EXISTING `reggen.py` gap, not
     something this session left incomplete.** `reggen.py`'s "external"
     register class (used for all six of these, confirmed by direct
     reading of `reggen.py`'s own `emit_regbank()`) generates a pure
     read-only mirror in `dfc_config_regbank_regs.sv`
     (`write_illegal_o = 1'b1` hardcoded, confirmed directly) with NO
     write-forwarding port to the owning module at all -- unlike the
     RW-class registers (RTL-002 through RTL-016's own control/status
     buses), "external" registers have no mechanism for a host write to
     reach the owner, regardless of what the owning module itself
     implements. `dfc_rtl024_shared_buffer.sv` maintains real sticky bits/
     saturating counters internally (set/incremented correctly per
     `ARCH-BUFERR-001`, confirmed by `rtl024_buffer_tb.sv`), but per
     `RTLSTD-REG-001` ("RTL-001 is the sole host-visible DRI register
     endpoint... never decode register addresses locally"), this module
     cannot invent its own address-decode/write-forwarding path to close
     the gap itself -- `reggen.py` needs a write-forwarding port for the
     "external" class first. Until then, these six registers accumulate
     and are read-only from the host's perspective in every build.

## RTL-017 (ARINC 429 Receive Interface) integration — first real Databus
## client, first real exercise of the shared-buffer service

107. **`ARX_CONTROL` (0x1000)'s 5 real fields were migrated out of the
     general-purpose `dfc_rtl024_control_t` into a new, dedicated
     `dfc_rtl024_arinc_rx_adapter_control_t`/`_status_t` struct pair,
     after a real `reggen.py` failure, not a design preference decided in
     advance.** `reggen.py` v5 asserts a field-map's `control_registers`
     cover its consumer struct's ENTIRE declared width exactly (confirmed
     by reading the assertion itself); mapping only `ARX_CONTROL`'s 5
     fields against the 278-bit `dfc_rtl024_control_t` failed with
     `control_o field-map covers 5 bits, expected exactly 278`. Three
     options were weighed (build the full 278-bit map, extend `reggen.py`
     to allow partial coverage, or split a dedicated struct); the user
     chose the split. Before approving, the user required two things
     confirmed first, not assumed: (a) whether removing the 5 fields
     forced renumbering every other field in the 278-bit struct -- NO,
     `extract_types.py` parses each field's explicit bit range from the
     table's own "Bits" column rather than auto-assigning from row order,
     so the 5 fields were replaced in place with one
     `reserved_arx_control_migrated` row at the SAME bit positions
     (223:219), and the tool's own gap/overlap re-validation passed; (b)
     whether the SPI bridge's `host_control`/`host_status` depended on
     today's exact bit positions in `dfc_rtl024_control_t` -- confirmed by
     direct grep across `rtl/` and `include/` that nothing references
     `dfc_rtl024_control_t`/`DFC_RTL024_CONTROL`/`rtl024_control_o`/
     `rtl024_status_i` anywhere (the SPI bridge uses the raw DRI protocol
     directly). `dfc_rtl017_control_t`/`_status_t` were NOT touched by
     this split -- RTL-017 never had visibility into `ARX_CONTROL`'s
     fields in the first place (REG-002's "Owner: RTL-017 / RTL-024" is
     descriptive prose, not a per-field split directive this toolchain
     supports). `tools/pkggen/extract_types.py`'s own
     `EXPECTED_RICH_STRUCTS` sanity constant grew 47->49 to account for
     the 2 new structs, with a disclosure paragraph added to that file's
     own docstring explaining why the formula is no longer purely
     `1 + 23*2`. A real, narrower bug surfaced while adding the second new
     struct: its heading read "1 bit" (singular) instead of the
     regex-required literal "bits" (plural, confirmed as a hard
     requirement via `extract_types.py`'s own `HDR` pattern), so the
     struct boundary was not recognized and its one row merged into the
     adapter CONTROL struct's own table, producing a bit-0 overlap --
     fixed by correcting the heading to "1 bits" and disclosed as a
     warning in `extract_types.py`'s own updated docstring for whoever
     adds the next struct.

108. **`RTL017_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW`'s host-write-clear path
     was genuinely missing, the same gap class fixed for 15 prior modules
     (RTL-002 through RTL-016) — now fixed for RTL-017 too, with explicit
     approval obtained first per the task's own instruction.**
     `dfc_rtl017_control_t` (103 bits before this fix) had no
     `rtl017_evt_overflow_status__event_overflow` `clear_mask` field,
     unlike every already-fixed module. Fixed the same way every prior
     instance was: one new `clear_mask` bit added at the new highest bit
     position (bit 103, growing the struct to 104 bits), so every other
     field keeps its existing bit position unchanged. A second,
     independent gap of the identical kind was found in the SAME pass
     while double-checking `ARX_STATUS`'s own W1C table against
     `dfc_rtl017_control_t`: `arx_status__snapshot_valid` (bit 3 of
     `ARX_STATUS`) also had no clear-forwarding field. Fixed identically
     (one more bit at the new highest position, 104->105 bits). Final
     width: 105 bits, confirmed via `tools/pkggen/dfc_types_pkg.json`.

109. **Pin budget for the remaining Databus domain is real and tighter
     than `PROJECT_CONTINUITY.md`'s prior accounting assumed -- flagged
     explicitly, the same way RTL-011's and RTL-016's own connection-map
     sections flagged their own consequences.** RTL-017 needs 2 real
     external pins, not 1: `arinc_rx_i` (line data, already digital per
     ARCH-BUS-001's own scope note that an external transceiver IC has
     already converted BPRZ to NRZ) AND `arinc_rx_adapter_error_i` (the
     transceiver's own fault output) -- confirmed as a genuine, real
     Appendix A external pin, not internal or stale, by direct inspection
     of `dfc_rtl024.sv`'s own pre-existing port list (written before
     RTL-017 was in scope). The same is true for RTL-018/019/020's own
     adapter-error pins (`arinc_tx_adapter_error_i`,
     `can_transceiver_error_i`), already real ports on `dfc_rtl024.sv`
     today. Real total remaining need across RTL-017-020: 2 (RTL-017) + 3
     (RTL-018: 2-bit tx_ctrl + tx_adapter_error) + 3 (RTL-019: rx+tx+
     transceiver_error) + 2 (RTL-020: rx+tx) = 10, against 13 available
     conductors (`gn15`-`gn21`, 7 unshared + `gp11`-`13`/`gn11`-`13`, 6
     WiFi-shared) -- still fits, with 3 spare, tighter than a
     data-pins-only accounting would suggest. Pins chosen per this
     project's own established "exhaust unshared, lowest-numbered first"
     rule and the real `gn14-gn21` SITE ordering (U17/P16/M17/L17/H17/
     G18/E17/D17) `ULX3S_CONNECTION_MAP.md` Section 10 already recorded:
     `arinc_rx_i` -> `gn15` (SITE P16), `arinc_rx_adapter_error_i` ->
     `gn16` (SITE M17). See `ULX3S_CONNECTION_MAP.md` Section 11 for the
     full pin-assignment record.

110. **Two real, genuine design bugs were found and fixed this session via
     real failed testbench runs -- not found by inspection, not assumed
     away, and both would have affected real hardware behavior, not just
     this testbench.** `verification/testbench/rtl-017/
     rtl017_integration_tb.sv`'s own Case 2 (error-code classification)
     initially failed with every `ARX_META.ERROR_CODE` reading 0
     regardless of the injected error condition. Root-caused via a focused
     debug trace (not guessed): (a) **the arbiter could get permanently
     stuck presenting an unaccepted route message.** RTL-017's internal
     buffer-client arbiter originally held `op_q`/`phase_q` in a dedicated
     commit-wait state until `msg_ready_i` accepted a completed route
     read -- correct per valid/ready's own "stable while stalled" rule,
     but it meant the SAME arbiter that also services WRITE (ARCH-
     RTL017-001's own "real-time, no backpressure from the adapter"
     requirement) and SNAPSHOT could be blocked indefinitely by a slow or
     absent route consumer. Masked in this integration only because
     `dfc_rtl024.sv` ties `msg_ready_i` to a permanent 1 (RTL-021 does not
     exist yet) -- a real future RTL-021 applying ordinary backpressure
     would have starved RTL-017 of ALL further capture/snapshot/pop
     service. Fixed by decoupling: a completed route read is now latched
     into independent `route_pending_q`/`route_pending_record_q` registers
     and the arbiter returns to `PH_IDLE` immediately, free to service
     WRITE/SNAPSHOT/a new ROUTE read while the held message separately
     waits for `msg_ready_i`. This introduced one new race (a host POP
     landing while a read message is held-but-unaccepted) handled with a
     `route_pending_removed_q` flag so the later acceptance never
     double-removes the same entry. (b) **a host `CAPTURE` command pulse
     arriving while the arbiter was mid-WRITE or mid-ROUTE (both
     genuinely multi-cycle) was silently dropped with no trace** --
     `ctl_capture_pulse` was only ever checked in `PH_IDLE`, and a bare
     one-cycle pulse has no guarantee of landing on an idle cycle. Fixed
     the same way `write_pending_q` already latches an incoming adapter
     word: a new `capture_pending_q` register latches the request
     independently of `phase_q` and is serviced the next time the arbiter
     reaches `PH_IDLE`, however long that takes. Both fixes are disclosed
     in `dfc_rtl017.sv`'s own header and inline comments; after both,
     `rtl017_integration_tb.sv` passes all 19 checks with 0 errors,
     including the dedicated host-POP-vs-route-transfer simultaneous-
     contention case (`RTL-017_RevA.md` SS6's own named test) and the
     one-outstanding-discipline runtime monitor (a real, dedicated check
     of this module's OWN FSM, not inherited from the shared-buffer
     arbiter's own formal proof, per the task's explicit instruction).

111. **The three "first real exercise" risks this task explicitly called
     out to verify, not assume:**
     - **`DP16KD`/`PDPW16KD` placement**: RESOLVED, confirmed nonzero --
       `1/208`, per `nextpnr-ecp5`'s own real `Device utilisation:` log
       output, Build ID `20261006_112421`. Item 104's own prediction
       ("a real nonzero whole-chip placement count can only be confirmed
       once a genuine client actually drives traffic through this
       service") is now directly verified, not assumed. This same build
       surfaced a SEPARATE, genuinely serious finding of its own as a
       direct consequence -- see item 112 (`nextpnr-ecp5` crashes after
       completing a real, PASSING timing analysis, specifically because
       this is the first build with a nonzero BRAM placement).
     - **One-outstanding discipline in RTL-017's OWN FSM**: a dedicated
       runtime monitor in `rtl017_integration_tb.sv` (and a structural
       argument in `dfc_rtl017.sv`'s own design -- the single `op_q`/
       `phase_q` state machine makes a second concurrent `buf_req_valid_o`
       assertion structurally unreachable, not merely untested) confirms
       this independently of the arbiter's own formal proof (which only
       guarantees the SERVICE never double-grants, not that a single
       client's own FSM behaves).
     - **VP-BUF-007/008/009/011** (OPEN_ISSUES.md item 102's own disclosed
       client-module responsibilities): all four now have real coverage
       in `rtl017_integration_tb.sv` -- multiword-entry atomicity (Case
       3's full 4-word entries, verified via snapshot readback),
       word-order preservation (Case 3's explicit oldest-word-first check
       across an 8-entry fill), pointer/evidence ownership (Case 3/4's
       queue-level and rejected-access counters), and uninitialized-word
       non-disclosure (every read in every case reads only words this
       module itself wrote, never a stale/uninitialized buffer slot).

112. **`build_ecp5.ps1`'s real result, disclosed in full -- a genuine,
     confirmed TOOLCHAIN bug, not an RTL defect, but a real, currently
     BLOCKING finding for this and every future build with a nonzero BRAM
     placement.** `DP16KD` placement is genuinely nonzero for the first
     time in this project's history -- `1/208`, confirmed directly in
     `nextpnr-ecp5`'s own `Device utilisation:` log output -- resolving
     item 104's own "a real nonzero whole-chip placement count can only
     be confirmed once a genuine client actually drives traffic through
     this service" follow-up. Placement, routing, AND timing analysis all
     genuinely completed and PASSED (`Max frequency for clock
     '$glbnet$core_clk': 50.02 MHz (PASS at 50.00 MHz)`, confirmed by
     direct reading of `nextpnr-ecp5`'s own full log, Build ID
     `20261006_112421`). But `nextpnr-ecp5` then crashes immediately
     after printing its own slack histogram, every time, with
     `ERROR: Expecting string value but got integer 0.` -- BEFORE writing
     either the `--textcfg` output or the `--report` JSON, so
     `build_ecp5.ps1` cannot proceed to `ecppack` and no bitstream is
     produced. **Isolated, not assumed**: a direct, manual re-run of the
     exact same `nextpnr-ecp5 --85k --package CABGA381 ...` invocation
     with `--report` REMOVED entirely produced the IDENTICAL crash at the
     identical point (preserved at
     `output/logs/ecp5_pnr_20261006_112421_noreport_isolation.log`),
     ruling out the `--report` JSON writer specifically as the cause --
     this is some OTHER internal post-place-and-route step `nextpnr-ecp5`
     always runs (its own in-memory report/summary construction most
     likely, given the error's JSON-type-mismatch phrasing and its
     position immediately after the timing summary), one this project has
     never exercised before because `DP16KD` was `0/208` (provably dead,
     optimized away) in every single prior build. Every earlier build's
     own real, successful `--report` JSON generation (quoted at length
     throughout this document's own RTL-002 through RTL-016 sections) is
     real evidence this is NOT a generic, always-present toolchain defect
     -- it is specifically triggered by a nonzero BRAM-class cell
     placement, confirmed via this session's own two independent repro
     runs (with and without `--report`) against the exact same pinned
     toolchain (`nextpnr-0.10-82-g2b560ad0`). **Not yet fixed -- this
     requires either a `nextpnr-ecp5` upgrade/patch (out of scope for an
     RTL session to decide unilaterally) or a confirmed workaround
     neither tried nor assumed here** (an alternate `--seed` was
     considered but not attempted -- the crash's own phrasing suggests a
     structural/schema issue in report-construction, not a placement-
     dependent one, so a different seed changing the outcome is a weak
     hypothesis not worth another real ~90-minute PnR run to test without
     better reason). **Every other real verification this task required
     is genuinely complete and passing**: `gate.ps1` -- lint PASSED; sim
     22/22 testbenches, 0 failures; formal 2/2 (bmc+prove) PASS; coverage
     189/353 (53.5%). The real, physical hardware-side-effects question
     (does the synthesized design actually behave correctly) is answered
     by simulation and the real, completed (if never packaged) PnR
     timing PASS -- only the bitstream-packaging step itself is blocked.

     **Two specific root-cause leads investigated and ruled out in
     follow-up sessions, so a future session doesn't re-walk either
     path:**
     - **Source-side parameter-typing bug** (a `PDPW16KD` parameter
       landing as a bare unquoted JSON integer instead of a quoted
       string, which placement/routing/timing wouldn't care about but
       report/summary serialization would crash on). RULED OUT: the
       actual JSON netlist `nextpnr-ecp5` consumes was dumped directly
       and the one real instantiated cell
       (`u_dragon_core.u_rtl024_shared_buffer.u_mem.u_pdpw16kd`, from
       `dfc_mem_sp_512x36_ecp5.sv:100.5-131.4`) was inspected parameter
       by parameter -- `ASYNC_RESET_RELEASE`, `CSDECODE_R`, `CSDECODE_W`,
       `DATA_WIDTH_R`, `DATA_WIDTH_W`, `GSR`, `REGMODE`, `RESETMODE`, all
       8 of them -- confirmed as properly quoted JSON strings via both
       `json.load()` type-checking and direct raw-text inspection. No
       source-side type mismatch exists.
     - **Missing `CLKRMUX`/`CLKWMUX` blackbox parameters** (a real
       upstream Yosys bug, fixed in a real April 2025 commit: prjtrellis
       documents optional EBR clock-input inverters that Yosys's own
       `PDPW16KD`/`DP16KD` blackbox declarations didn't carry before that
       fix, which could plausibly explain a report-generation crash on
       the very first design to place a real BRAM cell). RULED OUT,
       checked two independent ways: (1) the installed Yosys's own
       `/c/tools/oss-cad-suite/share/yosys/lattice/cells_bb_ecp5.v`
       already declares `parameter CLKRMUX = "CLKR";` and
       `parameter CLKWMUX = "CLKW";` on `PDPW16KD` (confirmed by direct
       read, lines 27-28); `cells_sim_ecp5.v`'s own `DP16KD` simulation
       model likewise already declares `CLKAMUX`/`CLKBMUX` (lines 67/125).
       (2) the installed OSS CAD Suite's own `VERSION` file reads
       `20260709` (2026-07-09) -- well over a year after the April 2025
       fix landed -- confirmed via `yosys -V`
       (`Yosys 0.66+252, git sha1 b35b6706f`) and `nextpnr-ecp5 --version`
       (`nextpnr-0.10-82-g2b560ad0`) alongside the VERSION file. This
       installation already has the fix; the real crash has a different,
       still-unidentified cause.

     **Status after both investigations: the real root cause remains
     unknown.** It is confirmed internal to `nextpnr-ecp5` itself (not
     this project's own RTL, not a source-side parameter type, not the
     already-fixed missing-clock-mux-parameter class of bug, not the
     `--report` JSON writer specifically). Resolving it further needs
     either a newer/different toolchain build to test against, or direct
     `nextpnr-ecp5` debugging -- both real environment/tooling decisions
     for the person to make, not something an RTL session should pursue
     unilaterally.

     **A third attempt (newer OSS CAD Suite release, `20261006` vs. the
     installed `20260709`) was tried and made things worse, not better --
     disclosed for completeness.** `nextpnr-ecp5` itself was upgraded
     (`0.10-82-g2b560ad0` -> `0.11.1-50-gaa8c83b8`) alongside Yosys
     (`0.66+252` -> `0.69+190`). This never even reached the original
     `nextpnr-ecp5` crash: the newer Yosys's own `synth_ecp5` crashes
     earlier, during synthesis itself, in a new experimental `AIGMAP`/
     `XAIGER2` ABC9 integration path (`ERROR: Assert 'data_start ==
     f->tellp()' failed in .../aiger2/aiger.cc:1078`), confirmed via a
     real, isolated test (an isolated `git worktree` checkout of the
     pre-RTL-017 commit `a00f54e`, synthesized with the new toolchain) to
     be completely UNRELATED to BRAM -- it crashes even when zero real
     `DP16KD`/`PDPW16KD` cells reach the mapper, so it is a general
     regression in this newer Yosys version, not a different flavor of
     the same underlying problem. The `-NoAbc9` diagnostic flag already
     built into `build_ecp5.ps1` does not route around it either (the new
     `AIGMAP`/`XAIGER2` path runs unconditionally in this Yosys version
     regardless of that flag). The `20261006` install was removed after
     this finding; the project is back on the original `20260709`
     toolchain, which was never actually switched system-wide in the
     first place (the test used a scoped `PATH` override only).

     **Decision (2026-10-06): the project is holding at the RTL-016 FPGA
     baseline rather than continuing to chase this.** The user was
     warned in advance that using RAM with OSS CAD Suite on this project
     carried exactly this risk, and declined to pursue either remaining
     path raised (further toolchain-version bisection, or reworking the
     shared buffer to a register/flip-flop-based implementation instead
     of `PDPW16KD` -- the latter a real option likely to avoid this
     specific crash, since no other module in this project uses BRAM,
     but with its own real tradeoff: a 512-deep read mux is exactly the
     shape of combinational structure this project's own item 48 "wide
     fan-in hub" congestion finding already warns about). The known-good
     fallback is `output/bitstreams/ulx3s_dfc_20261004_142815.bit`
     (SHA-256 `49a96af0242ec3ed2f1d010457c1292ed9a99ac72c69bb767dffe9b04cd4807c`,
     verified intact against disk this session) -- RTL-001 through
     RTL-016 only, real final timing 51.22 MHz PASS, predating the
     shared-buffer/RAM module's existence in the design entirely. Do not
     resume RTL-017 work, start RTL-018, or attempt another FPGA build of
     RTL-017+ without the user's explicit go-ahead.

     **ROOT CAUSE CONFIRMED, FIX IDENTIFIED -- build verification
     pending (real `build_ecp5.ps1` run on the full design in progress
     at the time of this writing; update this entry with the real final
     build result once it completes, per this file's own "don't leave
     it stale" discipline).**

     **Method**: `gdb` is not installed anywhere on this system (checked
     directly -- not in OSS CAD Suite, not in MinGW, no `windbg`/`cdb`
     either). Built a minimal, isolated repro instead: a tiny top module
     instantiating only the real `dfc_mem_sp_512x36_ecp5.sv` (the
     `PDPW16KD` wrapper) with a free-running counter driving it and one
     real, already-validated pin pair (`clk_25mhz`/`led0`, reused from
     this project's own `.lpf`). Full synthesis->place->route->timing
     on this takes under 2 seconds and reproduces the exact same crash,
     same message, same point (right after the slack histogram) as the
     full ~90-minute real build -- proving the crash depends on nothing
     but a real `PDPW16KD` cell reaching this stage, independent of the
     rest of the design's size. `nextpnr-ecp5`'s own `--on-failure`
     (the real flag name in this installed version; `--exe-on-crash`
     does not exist here) never fired for this error, and `--debug`
     added no instrumentation at this step -- both results are
     consistent with a plain internal `log_error()` abort in native
     C++ code. Cloned the real `YosysHQ/nextpnr` source at the exact
     installed commit (`2b560ad0`, dated 2026-06-19 upstream) and ran
     an exhaustive local `grep -rn` across the entire tree (not a
     filtered guess, not `WebFetch` summarization) for the literal
     crash text.

     **The exact mechanism, fully confirmed, not a hypothesis:**

     1. `fpga/ecp5/dfc_mem_sp_512x36_ecp5.sv` lines 95-96 (before this
        fix) passed `CSDECODE_W`/`CSDECODE_R` as Verilog BIT-VECTOR
        literals -- `.CSDECODE_W (3'b000), .CSDECODE_R (3'b000)` --
        the ONLY two parameters on this cell written this way; every
        other parameter (`REGMODE`, `RESETMODE`,
        `ASYNC_RESET_RELEASE`, `GSR`) already used a proper quoted
        string literal. Confirmed by direct inspection this is the
        ONLY instance of this pattern anywhere in the codebase (the
        only other real ECP5 hard-primitive instantiation,
        `fpga/ecp5/dfc_ecp5_pll.v`'s `EHXPLLL`, has every string-typed
        parameter already using letter-containing string literals that
        could never be ambiguous this way).
     2. Yosys faithfully serializes this bit-vector literal into the
        JSON netlist `nextpnr-ecp5` consumes as a bare quoted string of
        `0`/`1` characters -- `"CSDECODE_R": "000", "CSDECODE_W":
        "000"` -- a perfectly valid JSON string, and not a Yosys bug:
        Yosys's own RTLIL representation has no way to know this
        parameter is semantically supposed to be a string, since our
        own source gave it a plain bit-vector literal, not a Verilog
        string literal.
     3. `nextpnr`'s own JSON importer
        (`common/kernel/property.cc`, `Property::from_string()`,
        confirmed by reading the real source at the real installed
        commit):
        ```cpp
        Property Property::from_string(const std::string &s)
        {
            Property p;
            size_t cursor = s.find_first_not_of("01xz");
            if (cursor == std::string::npos) {
                // every character is '0'/'1'/'x'/'z' -> NUMERIC, not string
                p.str = std::string(s.rbegin(), s.rend());
                p.is_string = false;
                p.update_intval();
            } else if (s.find_first_not_of(' ', cursor) == std::string::npos) {
                // all [01xz] chars followed only by trailing spaces ->
                // the documented escape: strip one trailing space, treat
                // the rest as a literal string
                p = Property(s.substr(0, s.size() - 1));
            } else {
                // any other character present -> unambiguously a string
                p = Property(s);
            }
            return p;
        }
        ```
        Any string composed ENTIRELY of `0`/`1`/`x`/`z` characters is
        classified as NUMERIC (`is_string = false`), not as a string --
        a documented, deliberate disambiguation convention. A genuine
        string value is supposed to opt out of this via a trailing
        space (added by whichever JSON writer knows the parameter is
        semantically a string); Yosys never adds that escape here,
        because from Yosys's own point of view this genuinely is a
        plain bit-vector constant. `"000"` (three zero characters) is
        exactly this case: silently imported as a NUMERIC `Property`
        with `intval = 0`.
     4. `ecp5/pack.cc`'s `pack_ebr()` (the function that converts a
        `PDPW16KD`-typed cell into nextpnr's internal `DP16KD`
        representation, since there is only one physical EBR primitive
        on the chip) renames `CSDECODE_W`/`CSDECODE_R` to
        `CSDECODE_A`/`CSDECODE_B` via a plain key rename
        (`rename_param`), carrying the already-mistyped numeric
        `Property` through unchanged.
     5. `ecp5/bitstream.cc:1012` reads it back:
        `str_to_bitvector(str_or_default(ci->params, id_CSDECODE_A,
        "0b000"), 3)`. `str_or_default()` (`common/kernel/util.h:65`)
        hard-requires a string-typed `Property` and calls
        `log_error("Expecting string value but got integer %d.\n",
        int(found->second.intval));` when it finds a numeric one
        instead -- the exact crash text, with the exact printed
        integer being the bit pattern's decimal value. (By contrast,
        `DATA_WIDTH_A`/`DATA_WIDTH_B` -- also 32-bit all-`[01xz]`
        strings, also misclassified as numeric by the same import rule
        -- never crash, because they're read via the TOLERANT
        `intstr_or_default()`, confirmed to accept either
        representation, not the strict `str_or_default()`.)
     6. This was never reachable before RTL-017 because no real
        `PDPW16KD`/`DP16KD` cell had ever survived synthesis to reach
        this code path in any prior build -- every one had it
        optimized away at `0/208`.

     **Empirical confirmation table** (fast repro, each row a full
     real synthesis->place->route->textcfg-write cycle, seconds each):

     | `CSDECODE_W`/`CSDECODE_R` value | Result |
     |---|---|
     | `3'b000` (bit-vector literal, original) | FAILED -- `Expecting string value but got integer 0.` |
     | `3'b101` (bit-vector literal, non-zero) | FAILED -- `Expecting string value but got integer 5.` (exactly the decimal value of `101`) |
     | `"0b000"` (string literal, fix) | SUCCESS -- real `.bit`-equivalent textcfg written |
     | `"0b000"` + `REGMODE` changed to `"NOREG"` (isolating `REGMODE` as a non-factor) | SUCCESS |
     | `REGMODE` alone changed to `"NOREG"` (`CSDECODE` still `3'b000`) | FAILED -- identical crash, confirming `REGMODE` was never the cause |

     The `3'b101` row is the decisive confirmation: the crash's own
     printed integer changes to exactly match the new bit pattern's
     decimal value (5), with zero remaining ambiguity about the
     mechanism.

     **The confirmed fix** (matching the blackbox's own declared
     default format exactly, and required by Yosys's own `CSDECODE`
     parser -- a bare `"000"` string without the `0b` prefix fails
     synthesis with `error parsing value '000', expected 0b prefix`):
     ```systemverilog
     .CSDECODE_W          ("0b000"),
     .CSDECODE_R          ("0b000"),
     ```
     The `b` character falls outside `{0,1,x,z}`, so `Property::
     from_string()` unambiguously classifies it as a genuine string,
     and the crash never occurs. Applied to
     `fpga/ecp5/dfc_mem_sp_512x36_ecp5.sv` lines 95-96 (now expanded
     with an inline disclosure comment at that location). Confirmed
     via direct codebase search that this is the only instance of this
     pattern anywhere in the project -- no second occurrence to fix.

     **Verification status**: `gate.ps1` re-run after the fix -- lint
     PASSED, sim 22/22 testbenches with IDENTICAL check counts to
     before the fix (19/232/etc., unchanged, confirming zero simulation
     impact, exactly as expected since this file is the ECP5-only real-
     hardware body, never used in sim/formal), formal 2/2 PASS, `GATE
     PASSED`. A real, full-design `build_ecp5.ps1` run is in progress
     at the time of this writing to confirm the crash is actually gone
     end-to-end (not just on the isolated repro) and that a real `.bit`
     file is produced for the first time, with `DP16KD`/`PDPW16KD`
     placement still nonzero and timing still passing. This entry will
     be updated with that real result once the build completes.

     **Note on one specific build attempt (Build ID `20261006_210922`,
     stopped 2026-10-07, not a finding about the fix itself):** this
     attempt's router was still actively converging (overused nodes
     dropping steadily, from 162,028 at iteration 1,000 down to 92,505
     by iteration 689,000, ~320 real minutes elapsed) when it was
     stopped to hold overnight, rather than left running indefinitely.
     The convergence rate was clearly decelerating over that window
     (roughly 2.7 overused-nodes/sec between iterations 600k-650k,
     dropping to roughly 0.38/sec between 650k-689k) -- consistent with
     real placement-seed variance in how long a full route takes to
     converge, not a new crash, not a regression, and not evidence
     against the fix above (synthesis and the early placement/routing
     phases were already running cleanly, exactly as the fix predicts;
     this run simply had not reached the timing-analysis/report stage
     yet when it was stopped). A fresh attempt (same fix, possibly a
     different `-Seed`) is the next real step whenever building is
     resumed.

     **Real, final result of the follow-up `-Seed 42` attempt (Build ID
     `20261007_135035`, 2026-10-07) -- the CSDECODE fix above is now
     CONFIRMED end-to-end as far as that specific crash goes, but a
     SEPARATE, different nextpnr-ecp5 crash newly surfaced and still
     blocks bitstream production.** This run used an explicit, fixed
     `-Seed 42` (chosen and documented in advance, matching the seed
     already used successfully once elsewhere in this project's history
     -- see the `nextpnr-ecp5` internal router assertion finding earlier
     in this item's own document) specifically to get a reproducible,
     non-default placement/routing draw. `gate.ps1` was re-run
     immediately beforehand as a sanity check and passed identically to
     every prior report in this item (lint PASSED; sim 22/22
     testbenches, 0 failures, identical check counts to every prior
     gate run; formal 2/2 `.sby` files, 4/4 tasks, all PASS; coverage
     189/353).
     - **The original crash (`Expecting string value but got integer N`)
       did NOT recur** -- confirmed by a direct, exhaustive grep of the
       full, real `output\logs\ecp5_pnr_20261007_135035.log` for that
       exact text: zero matches. Synthesis, placement, and the
       post-placement slack-histogram step (the exact point the
       original crash always occurred, every time, before this fix) all
       completed cleanly. `DP16KD` placement is confirmed nonzero again
       (`1/208`, directly from this run's own `Device utilisation:`
       block), so the fix's target code path was genuinely exercised
       again, not skipped.
     - **Routing then ran far longer and far further than either
       previous attempt before anything went wrong**: 31,401 real
       seconds (~8.7 hours) of routing, reaching iteration 1,322,000 of
       the ripup-reroute loop, with remaining (overused) arcs down to
       **26,953 of the original 162,672 (83.4% resolved)** -- well past
       the `20261006_210922` attempt's own best point (92,505 remaining
       after ~320 minutes) and still actively converging when it ended
       (remaining arcs were still trending down over the final tracked
       iterations, e.g. 27,061 -> 26,953 from iteration 1,321,000 to
       1,322,000), not plateaued.
     - **A genuinely NEW, different internal `nextpnr-ecp5` crash then
       occurred**, confirmed by direct reading of the real log's exact
       final lines:
       ```
       terminate called after throwing an instance of 'nextpnr_ecp5::assertion_failure'
         what():  Assertion failure: cond (/work/_builds/windows-x64/nextpnr-ecp5/nextpnr/common/kernel/hashlib.h:233)
       ```
       This is an internal C++ assertion inside nextpnr's own generic
       hash-table implementation (`hashlib.h`), thrown from somewhere in
       the ripup-reroute router after ~1.3 million routing iterations --
       structurally a different code path, different file, and
       different failure mode than the original `CSDECODE`/
       `property.cc`/`bitstream.cc` crash this item's fix targets. No
       crash dump or core file was produced (checked directly; none
       exists under `output\_scratch\ecp5`). This is **not yet
       investigated** -- unlike the original crash, no isolated repro,
       no source-level root cause, and no confirmed fix exist for this
       one yet.
     - **No new `.bit` file was produced** -- `output\bitstreams\`'s
       newest file still predates this run (from the RTL-016-only
       baseline, `20261005_230516`). The bitstream-packaging question
       this item exists to answer remains open, now blocked by a
       different cause than when this item was opened.
     - **The `40.52 MHz (FAIL at 50.00 MHz)` line appearing earlier in
       this run's own log is NOT a final, meaningful timing result and
       must not be read as a real timing failure.** Confirmed by its
       exact position in the log: it is printed by the placer's own
       pre-route timing ESTIMATE, immediately after simulated-annealing
       placement and before `Routing globals...`/`Routing..` even
       begin -- i.e. before any real net delays exist. Every prior
       successful build in this project's history (e.g. the 50.02 MHz
       PASS this item itself opened with, Build ID `20261006_112421`)
       reaches its real, authoritative `Max frequency ... PASS` number
       only from the POST-route timing analysis, which this run never
       reached because routing crashed first. This run furnishes no
       evidence either way about whether the design meets timing.
     - **Per this task's own explicit instruction not to silently try a
       third seed or workaround on a differently-crashing build:
       stopped here and reported back rather than continuing.** No
       further build attempt was made this session. The real, open
       questions for whoever picks this up next: (1) is the
       `hashlib.h:233` assertion itself seed-dependent (i.e. does a
       third `-Seed` value avoid it, the same way `-Seed 42` avoided
       the router-assertion crash logged earlier in this item), or is
       it a function of routing duration/iteration count regardless of
       seed; (2) is this a known upstream `nextpnr-ecp5` bug at the
       pinned `nextpnr-0.10-82-g2b560ad0` commit (not yet checked -- the
       upstream source clone used to root-cause the original CSDECODE
       crash earlier in this item has not yet been searched for this
       new assertion text); (3) given routing now reliably gets much
       further (83.4% resolved, still converging) before failing, is a
       longer timeout alone (running past the ~8.7-hour mark this
       attempt reached) a viable next step, or does the crash recur at
       a similar iteration/arc count regardless of how far routing has
       progressed. **Decision (2026-10-07): holding at the RTL-016 FPGA
       baseline continues to apply** (unchanged from the decision
       earlier in this item) -- do not resume RTL-017+ FPGA build
       attempts without the user's explicit go-ahead on which of the
       three questions above to pursue first.

## RTL-018 (ARINC 429 Transmit Interface) integration — compile/synthesize/verify scope only

113. **Resolved in favor of REG-002's own Section 6 Address-Map Summary,
     same reasoning as items 1/10/11/13/19 (a genuine REG-002-INTERNAL
     discrepancy, not something this module invented or silently picked
     one side of without checking).** REG-002 Section 15's own block-header
     table says "Register count: 12" for the ARINC 429 Transmit block
     (0x1100-0x11FF); REG-002's own Section 6 top-level Address-Map Summary
     says "11" for the identical block; only 11 registers are ever actually
     defined, named, and field-specified anywhere in REG-002 (confirmed via
     an exhaustive search for `ATX_`/`RTL018`/`0x1100` across the whole
     document -- no twelfth register exists under any name). Resolved in
     favor of 11, the only number with real content behind it.
     `tools/reggen/rtl018_field_map.json` implements all 11 real,
     enumerated registers.

114. **RESOLVED (2026-10-20), the 10th real instance of the exact gap class
     already fixed for RTL-002 through RTL-017 (items 2/7/8/12/20/24/28/32/
     36/etc.), approved before implementation.** `dfc_rtl018_control_t` had
     no clear-forwarding field for `RTL018_EVT_OVERFLOW_STATUS.
     EVENT_OVERFLOW` (REG-1120 bit 0, a real W1C field). Fixed: ARCH-002
     grew the struct 162->163 bits, adding
     `rtl018_evt_overflow_status__event_overflow` at the new highest bit
     (162) -- every pre-existing field's bit position confirmed unchanged
     via a real `regenerate.ps1` run (diffed directly against the
     already-generated `include/dfc_types_pkg.sv` before this edit, not
     assumed). `tools/reggen/rtl018_field_map.json` carries the
     corresponding `control_registers` entry from the start, and its
     `status_registers` section closes the RTL-002/003/004-style readback
     gap (item 21) for RTL-018 too, same discipline already established for
     RTL-006 through RTL-017.

115. **Real, disclosed ARCH-002-internal apparent off-by-one, logged, not
     silently resolved either way (CLAUDE.md rule 8).** ARCH-002's own
     Appendix F event-source-matrix row for RTL-018 lists index **17**
     alongside a second "hex" column reading **0x12** (18 decimal, not
     0x11=17) -- RTL-017's own row immediately above shows the identical
     pattern (index 16, hex column 0x11=17, also one higher than the index
     column). This looks systematic across at least these two adjacent
     rows, not a one-off typo. **Resolved operationally in favor of the
     plain decimal INDEX column** (17 for RTL-018), matching the real,
     already-working precedent: `dfc_rtl017.sv`'s own real, shipped,
     passing-gate wiring uses `RTL-005.evt_valid_i[16]` (the index column's
     value, not the hex column's), and this session's own
     `dfc_rtl024.sv` wiring for RTL-018 follows the identical pattern
     (`evt_valid_i[17]`). The distinct event-ID code embedded in event
     records (0x0020 for RTL-017, 0x0021 for RTL-018) comes from a THIRD,
     separate column and is unaffected by this question. Whoever edits
     ARCH-002's Appendix F table next should check whether the "hex" column
     is simply redundant/miscomputed throughout this region before trusting
     it for anything.

116. **Real, disclosed ARCH-002-internal naming inconsistency, not fixed
     (ARCH-002 is the owning document for both names and uses both
     inconsistently -- not something a single RTL session should
     reconcile unilaterally, same category as item 1's own resolution
     style).** ARCH-002's own RTL-018 port-catalog table (Appendix A) names
     the adapter-error input port at the RTL-018 module boundary
     `atx_adapter_error_i` (already-synchronized, same-domain, fed by
     RTL-024's own internal `atx_adapter_error_o`). ARCH-002's own RTL-024
     top-level external-pad table and its Appendix E CDC inventory
     (`CDC-ATXERR`) instead name the chip-level pad `arinc_tx_adapter_error_i`
     (asynchronous, active-high, routed through a real two-stage
     synchronizer owned by RTL-024). Both names refer to the SAME logical
     signal at two different hierarchy levels; `dfc_rtl018.sv` uses the
     RTL-018-level name (`atx_adapter_error_i`) per its own real port-table
     row, and `dfc_rtl024.sv`'s own new synchronizer this session is named
     `atx_adapter_error_sync`/`atx_adapter_error_sync_q` to match. If
     RTL-STD-002 SS8 naming rules are ever applied retroactively to
     ARCH-002 itself, this pair should be reconciled to one prefix.

117. **Real, disclosed stale port-count claim in `RTL-018_RevA.md`, resolved
     in favor of ARCH-002, same resolution style as items 1/10/11/13/19 (the
     module spec is a derived artifact, never the owning document, per
     CHTR-DOC-003).** `RTL-018_RevA.md` SS2 claims "18 total" ports.
     ARCH-002's own Appendix A header reads "RTL-018 - ARINC 429 Transmit
     Interface (28 ports)", and the real table beneath it lists exactly 28
     rows, counted directly, not assumed -- the identical class of stale
     module-spec port count RTL-017_RevA.md already had (that item's own
     resolution, RTL-017 using ARCH-002's real 33 rather than RevA's stale
     20, is the direct precedent here). `dfc_rtl018.sv` implements all 28
     real ports.

118. **Real, disclosed interpretation choice -- no distinct REG-002 trigger
     exists to cite, same reasoning precedent as RTL-017's own finding 7
     (ARX_ERROR_COUNT).** REG-002's own text for `ATX_ERROR_COUNT`
     ("Saturating transmit error/rejection count") names no trigger
     distinct from `ATX_UNDERRUN_COUNT`/`ATX_REJECTED_PUSH_COUNT`, each of
     which already has its own dedicated, clearly-scoped counter.
     `dfc_rtl018.sv` increments `ATX_ERROR_COUNT` specifically on a
     non-OK shared-buffer response during either the PUSH-write or the
     DEQUEUE-read path (the in-progress operation is aborted, no
     partial/corrupt entry ever becomes visible) -- this module's own
     chosen classification for "a real transmit-path error that isn't an
     underrun or a rejected push," disclosed in the file's own header
     (finding 5), not assumed without comment.

119. **Real, disclosed interpretation choice for RTL-018's own 8-bit
     event-condition allocation (Appendix F.3).** Per the real table (0
     transmit complete; 1 rejected; 2 queue overflow; 3 underrun; 4 adapter
     error; 5 recovery; 6 shared-buffer error; 7 event-slot overflow):
     bits 1 ("rejected") and 2 ("queue overflow") both map to this module's
     single real rejection trigger (a PUSH failing because the queue is
     full or the module is disabled) -- REG-002 gives RTL-018 no second,
     independently-distinguishable "invalid push" condition to separate
     them. Bit 5 ("recovery") has no real internal condition anywhere in
     this module to drive it at all -- structurally unreachable, same
     disclosed-unreachable treatment as RTL-017's own codes 6/7 (item 5's
     RX-side encoding table). See `dfc_rtl018.sv`'s own header (finding 7)
     for the full disclosure.

120. **Real, disclosed gap -- nothing to fix (no rejection code or evidence
     bit exists anywhere in REG-002's ARINC TX block for this specific
     case).** ARCH-VAL-018 states parity override is only legal when
     `AUTO_PARITY=0` AND the staged override-valid bit is 1; REG-1114's own
     write-validation text for `ATX_PUSH` only names "queue-full or
     disabled" as grounds for rejection, nothing about an illegal
     parity-override combination. `dfc_rtl018.sv`'s own disclosed choice
     (finding 6): a PUSH with `AUTO_PARITY=0` and override-valid=0 is
     accepted anyway and falls back to the real auto-computed parity value,
     rather than inventing a rejection this module has no register field to
     report through.

121. **Compile/synthesize/verify scope, explicitly NOT full P&R-level
     completeness -- disclosed here so this entry isn't mistaken for a
     RTL-017-style full close-out.** Per this session's own explicit task
     scope (HIL-testing phase at the RTL-016 hardware baseline; RTL-018
     through RTL-023 integrate at compile/synthesize/verify only, given the
     two unresolved toolchain crashes already on record in item 112): a
     real `gate.ps1` run passed clean (lint/sim/formal), including a new
     dedicated `rtl018_integration_tb.sv` (32/32 checks) covering queue
     push/pop/overflow, the host-vs-route last-free-slot tiebreaker (both
     the genuine-conflict and no-real-conflict cases, synchronized to the
     exact same CORE_CLK edge to actually exercise the race rather than
     approximate it), parity-override legality, interword-gap timing
     (measured against the real internal `ser_state_q`, not just the
     external pin, to avoid conflating the real gap with the separate
     buffer-read latency for the next entry), the `arinc_tx_ctrl_o != 2'b11`
     invariant (checked every cycle for the whole run), and underrun/
     rejection classification. A real Yosys `synth_ecp5` run (via
     `build_ecp5.ps1 -SynthOnly`, a new flag added this session specifically
     because no existing stop-point after synthesis existed -- see that
     script's own header) completed cleanly with real cell-count statistics
     recorded in `output/logs/`. **`nextpnr-ecp5` was never invoked this
     session** -- no place-and-route, no timing closure, no bitstream.
     RTL-018's status is "compiled, synthesized, verified," not "built" or
     "complete" -- the project continues holding at the RTL-016 FPGA
     baseline (item 112) for any real hardware target.

## RTL-019 (Classical CAN Interface) integration — compile/synthesize/verify scope only, most protocol-complex module to date

122. **Resolved in favor of ARCH-002's own real Appendix A port table, same
     resolution style as items 1/10/11/13/19/117 (the module spec is a
     derived artifact, never the owning document, per CHTR-DOC-003).**
     `RTL-019_RevA.md` SS2 claims "19 total" ports and SS1/SS5 claim "21
     registers" -- both stale, the third consecutive module spec with this
     exact class of error (RTL-017: 20 vs 33 real; RTL-018: 18 vs 28 real).
     ARCH-002's own Appendix A header reads "RTL-019 - Classical CAN
     Interface (33 ports)" with exactly 33 real rows, counted directly, not
     assumed. `dfc_rtl019.sv` implements all 33 real ports.

123. **REG-002's own CAN block (0x1200-0x1258) is genuinely self-consistent
     at 23 registers** (block header, Section 6 Address-Map Summary, and
     the actual enumerated row count all agree) -- unlike RTL-018's own
     ARINC TX 11-vs-12 discrepancy (item 113), there is no internal REG-002
     conflict to resolve here; `RTL-019_RevA.md`'s stale "21" (item 122) is
     the module spec's own error alone. `tools/reggen/rtl019_field_map.json`
     implements all 23 real, enumerated registers.

124. **RESOLVED (2026-10-20), the 11th real instance of the exact gap class
     already fixed for RTL-002 through RTL-018 (items 2/7/8/12/20/24/28/32/
     36/114/etc.), approved before implementation.** `dfc_rtl019_control_t`
     had no clear-forwarding field for `RTL019_EVT_OVERFLOW_STATUS.
     EVENT_OVERFLOW` (REG-124C bit 0, a real W1C field). Fixed: ARCH-002
     grew the struct 203->204 bits, adding
     `rtl019_evt_overflow_status__event_overflow` at the new highest bit
     (203) -- every pre-existing field's bit position confirmed unchanged
     via a real `regenerate.ps1` run. `tools/reggen/rtl019_field_map.json`
     carries the corresponding `control_registers` entry from the start.

125. **A real, pre-existing defect in RTL-018 (not RTL-019), found while
     wiring THIS module, fixed in `dfc_rtl018.sv`/`dfc_rtl024.sv`/
     `rtl018_integration_tb.sv`, disclosed here since it directly affects
     RTL-019's own `activity_o` slot.** ARCH-002's real, 28-row RTL-018
     port table (confirmed by direct count) has NO `activity_o` port at
     all -- an earlier session invented one, modeling it on RTL-017's real
     one without checking, and wired it to `RTL-015.activity_i[3]`, the
     EXACT bit ARCH-002 real explicitly reserves for RTL-019
     (`RTL-019.activity_o | RTL-015.activity_i[3]`, confirmed directly).
     The fictional port and its wiring have been fully removed; RTL-019's
     own `activity_o` is the real, ARCH-002-confirmed occupant of that bit.

     **FOLLOW-UP CORRECTION (see item 140): "that bit" above (`activity_i[3]`)
     was itself the wrong resolution** -- it silently reopened and reversed
     item 83's earlier, already-made decision for this exact conflict class.
     RTL-019's real `activity_o` has been moved to `activity_i[2]` (the bit
     item 83's resolution actually assigns it). Left here unedited as an
     accurate record of what this session found and did at the time; item
     140 is the real, final correction.

126. **Real, disclosed gap -- neither ARCH-002 nor REG-002 states the
     classical CAN numeric error-confinement thresholds anywhere.**
     ARCH-002/REG-002 give only the counter widths (8 bits each, CAN_ERROR_
     COUNT) and the bus-off recovery count (128 occurrences of 11
     consecutive recessive bits, stated explicitly, twice) -- no numeric
     value for ERROR_WARNING/ERROR_PASSIVE/BUS_OFF thresholds anywhere.
     `dfc_rtl019.sv` uses the real, standard, external ISO 11898-1 values
     (not invented): ERROR_WARNING at TEC>=96 or REC>=96; ERROR_PASSIVE at
     TEC>127 or REC>127; BUS_OFF at TEC>255. Same class of disclosure as
     RTL-018's own real ARINC bit-rate constants (item set for that
     module). See `dfc_rtl019.sv`'s own header (finding 6) for the full
     disclosure, including the deliberately simplified (non-real-standard)
     TEC/REC increment/decrement rules (a bounded, disclosed scope cut
     given the number of narrow exception cases in the real standard).

127. **Real, disclosed gap -- the real CAN CRC-15 polynomial and the 5-bit
     stuffing interval are external, well-known standard values, not
     invented, but ARCH-002/REG-002 state neither numerically.** `dfc_rtl019.sv`
     uses the real, standard CAN CRC-15 polynomial
     (x^15+x^14+x^10+x^8+x^7+x^4+x^3+1, 0x4599) and the real, standard
     5-consecutive-bit stuffing interval. See `dfc_rtl019.sv`'s own header
     (findings 2/3) for the full algorithmic disclosure.

128. **Real, disclosed simplification: hard synchronization at SOF only, no
     continuous mid-frame resynchronization.** The real ISO 11898-1
     standard requires continuously correcting the current bit's TSEG1/
     TSEG2 boundary by up to SJW quanta on every unexpected edge, needed
     for robustness against two independent nodes' oscillators drifting
     apart over a frame. `dfc_rtl019.sv` only resets its bit-phase counter
     to quantum 0 on a real recessive-to-dominant edge while bus-idle
     (hard sync at SOF) -- `SJW_MINUS_1` is still a real, validated
     register field but is not consumed by any resync logic. A real,
     narrower scope than a full conformant CAN PHY would need for two
     genuinely independent, free-running-clock nodes on a real bus;
     sufficient for this project's own real verification path (loopback
     self-test, and a synchronous CORE_CLK-timed bus with no independent
     oscillator drift to correct for). See `dfc_rtl019.sv`'s own header
     (finding 1) for the full disclosure.

129. **Real, disclosed design choice for LOOPBACK's own ACK behavior.**
     ARCH-BUS-003's own "disconnects external TX... internal echo only"
     text does not specify what happens at the ACK slot when there is no
     real second node to generate one. `dfc_rtl019.sv` unconditionally
     treats the ACK slot as acknowledged while `LOOPBACK=1` -- a real,
     common simplification for self-test loopback modes (without it, every
     loopback TX would show a real ACK error despite sending a
     structurally perfect frame). See `dfc_rtl019.sv`'s own header (finding
     5) for the full disclosure.

130. **Real, disclosed design choice for LISTEN_ONLY's own TX-queue
     interaction.** REG-ENC-006's "never drives dominant, including no
     ACK" is unambiguous about the PAD, but ARCH-002/REG-002 do not say
     whether a queued TX entry should still ATTEMPT arbitration while
     listen-only (which could only ever "lose," since this module can
     never assert a dominant bit). `dfc_rtl019.sv` disables the TX-dequeue
     engine itself while `LISTEN_ONLY=1` -- queued entries simply wait, not
     popped, not retried-and-failed -- rather than attempting a
     structurally-guaranteed-to-fail transmission that would corrupt error
     counters for no reason. See `dfc_rtl019.sv`'s own header (finding 5)
     for the full disclosure.

131. **Real, disclosed defensive clamp for REG-ENC-006's own `11`
     LOOPBACK/LISTEN_ONLY illegal combination.** REG-002's own per-field
     validation text is generic ("value and cross-field constraints
     validated") without a field-map mechanism (reggen v5) to express a
     real cross-field rejection rule at the regbank level -- a real,
     disclosed gap in reggen v5's own expressiveness, not something this
     session's scope extends to fixing. `dfc_rtl019.sv` defends the
     invariant itself: if both raw bits are ever seen asserted
     simultaneously on live `control_i`, LOOPBACK wins (LISTEN_ONLY is
     combinationally clamped to 0), as a last-resort measure, never
     operating with both true regardless of how that live state was
     reached. Verified directly by `rtl019_integration_tb.sv`'s own Case
     13. See `dfc_rtl019.sv`'s own header (finding 9) for the full
     disclosure.

132. **Real, disclosed gap -- `CAN_RECOVERY.REQUEST`'s own rejection has no
     dedicated evidence field.** REG-1250's own text ("after the
     Architecture-defined recessive-bus observation requirement is
     satisfied") confirms a premature manual recovery request is NOT an
     unconditional override, but REG-002 gives this specific WO-CMD
     register no rejection-count/evidence field of its own to report
     through (unlike `CAN_TX_PUSH`'s own `CAN_TX_REJECTED_COUNT`). A
     rejected manual request is silently ignored in `dfc_rtl019.sv` --
     disclosed, not a bug. Verified directly by `rtl019_integration_tb.sv`'s
     own Case 15 (both the premature-rejection and eventual-acceptance
     paths, though see item 136 below for a real caveat on how reliably
     the premature-rejection path can be exercised).

133. **CAN_RX_META.FLAGS bit meanings are found in ARCH-002's own SS11.1
     prose, not in REG-002's own register-field tables.** The real, cited
     meanings (0 CRC error, 1 stuff error, 2 form error, 3 bit error, 4 ACK
     error, 5 arbitration lost, 6 error passive, 7 bus off, 8 transceiver
     error, 9 injected, 10-11 reserved) are implemented in
     `dfc_rtl019.sv`'s own RX-capture W5 assembly. Bits 0-4 are
     tautologically always 0 for any frame that reaches real capture (any
     of those conditions would have diverted the frame to the error-flag
     path instead, never reaching capture). Bit 5 (arbitration lost) is a
     real per-frame history bit, separately latched (`arb_loss_in_frame_q`)
     since the point-in-time arbitration-loss pulse happens earlier in the
     same frame than its own eventual capture. Bits 6-8 are real STATE at
     the moment of capture, not per-frame history. Bit 9 (injected) has no
     real source anywhere in this design -- disclosed, left 0, not
     silently assumed.

134. **Self-referential `ARCH-MSG-002` routing (CAN RX and CAN TX share
     module ID 0x01) is confirmed NOT this module's own concern.**
     ARCH-002's own 5x5 routing authorization matrix explicitly marks
     CAN-RX-to-CAN-TX as disallowed (a real `0` in that matrix cell) --
     the policy question of whether RTL-021 (Message Router, not yet
     built) is ever allowed to route CAN RX's own output back to CAN TX's
     own input is RTL-021's to enforce, not something `dfc_rtl019.sv`
     needs to special-case or prevent itself. `dfc_rtl019.sv` implements
     two ordinary, independent route port pairs
     (`rx_msg_valid_o`/`rx_msg_ready_i`/`rx_msg_record_o` and
     `tx_msg_valid_i`/`tx_msg_ready_o`/`tx_msg_record_i`) with no internal
     cross-wiring between them, same pattern as RTL-017's own source-only
     and RTL-018's own destination-only route ports. The generic
     `dfc_message_record_t`'s own CAN-specific ID/IDE/RTR bit-packing
     convention (into the record's payload field, since that 192-bit
     layout was never designed with CAN's own arbitration fields in mind)
     is this module's own disclosed interpretation choice, exercised
     directly by `rtl019_integration_tb.sv`'s own Case 8 route-push path.

135. **Nine real, genuine RTL bugs found and fixed while implementing this
     module, all caught by this module's own dedicated testbench before
     this entry was written, none left unfixed:**
     - **Swapped RTR/IDE bit positions** when loading `is_extended_q`/
       `is_rtr_q` from a dequeued TX entry's own W0 word (`tx_stage_w[0]`)
       -- the two fields were read from each other's real bit position.
     - **`ctrl_field_last_bit` declared `[1:0]` (0-3 only)** but needed to
       hold 4 or 5 (the real standard/extended control-field bit counts)
       -- silently truncated, causing the control field to exit after only
       1-2 bits instead of the real 5/6 in every case not masked by
       loopback's own TX-side preload.
     - **No real bit-by-bit ID/IDE/RTR/DLC capture existed for a genuinely
       RECEIVED (non-loopback, non-self-originated) frame** -- only the
       TX-side preload path populated `frame_id_q`/`is_extended_q`/
       `is_rtr_q`/`frame_dlc_q`, so a real external frame's own arbitration
       and control fields were never actually decoded bit-by-bit at all.
       Real standard-vs-extended determination (both real formats share
       the identical bit position for the IDE bit) and a same-edge hazard
       in the resulting exit-condition check (the newly-determined
       `is_extended_q`/live DLC value is not yet visible via the
       registered read on the very cycle it is determined) were both
       fixed together.
     - **Multi-byte data field transmitted/received the LAST byte first**
       instead of the real standard's byte-0-first, MSB-first-within-byte
       order -- a flat `(total_bits-1-bit_idx_q)` index over the whole
       64-bit `frame_data_q` register reverses byte order for any payload
       over 1 byte.
     - **The internal `rd_w_q[]` read-accumulator was shared between
       host/route-visible RX reads (SNAPSHOT/ROUTE) and the purely
       internal TX-dequeue read** -- every time this module dequeued its
       OWN queued TX entry to attempt transmission, it silently clobbered
       the host-visible `CAN_RX_ID`/`CAN_RX_META`/`CAN_RX_DATA`/`CAN_RX_TIME`
       status fields with the TX entry's own, unrelated W0-W5 content.
       TX-dequeue now reads directly into `tx_stage_w[]` instead.
     - **A real same-edge hazard in the TX-dequeue arbiter request**: the
       exit condition `tx_count_q != 0` read the stale pre-decrement value
       on the exact cycle a real pop was also retiring, letting a spurious
       extra dequeue start against an already-logically-empty queue and
       underflow `tx_count_q` into a large garbage value that never
       self-corrected (since `tx_queue_empty`'s own `==0` check could never
       match again) -- a real, reproducible runaway bug, not a cosmetic
       off-by-one. Guarded with `&& !frame_tx_commit_pop`; the equivalent
       RX-side guard was added defensively even though the specific race
       was only directly observed on the TX side.
     - **A lost-arbitration node kept driving its own (no-longer-relevant)
       staged frame content** instead of going silent (recessive) for the
       rest of that frame's arbitration/control/data/CRC fields --
       `compute_tx_bit()` never checked `is_transmitter_q` for those
       states. Fixed with an explicit override (ST_ACK and the
       error-flag states, where every node drives regardless of role, are
       deliberately excluded).
     - **LOOPBACK frame completion only ever took the TX-commit path OR
       the RX-capture path (an if/else), never both** -- since
       `is_transmitter_q` never clears in a pure loopback round-trip (no
       real external node exists to contest it), a successfully
       self-looped frame was popping its own TX entry but never actually
       landing in the RX queue at all. Fixed so loopback explicitly does
       BOTH: the TX commit (the entry was genuinely sent) and the RX
       capture (this module is also, genuinely, the frame's own receiver
       in loopback).
     - **`effective_operational_enable_i` was a declared port, read nowhere
       in the module.** Real architectural gap (the same signal gates
       RTL-018's own TX dequeue) -- `want_tx_frame` now requires it, same
       role as RTL-018's own identical port.

     Every one of these was found via this module's own dedicated
     testbench (`rtl019_integration_tb.sv`), not by inspection alone --
     several only became visible once the testbench's own bit-timing
     margin was widened enough to stop masking them with a coincidental
     one-bit misalignment (see item 137).

136. **Real, disclosed testbench-level finding (not an RTL defect): the
     128x11 bus-off recovery observation counter runs continuously
     regardless of recovery mode (matching real hardware), so it can
     become satisfied DURING an error-passive TEC-building retry phase,
     before bus-off even latches** -- once error-passive (TEC>127), this
     module's own error flag becomes all-recessive by design (a passive
     node's error flag must not disturb other traffic), and each further
     retry's flag+delimiter is itself a real multi-bit recessive run. This
     is a genuine protocol property this testbench's own TEC-building
     strategy exposed, not an artifact: `rtl019_integration_tb.sv`'s own
     Case 15 checks `recovery_ready_q` directly and only asserts the
     "premature rejection" sub-case when it is actually still
     unsatisfied, rather than assuming a fixed timing window.

137. **Real testbench-level finding: the bit-timing margin matters for a
     synchronous, software-driven testbench stimulus, separate from any
     RTL defect.** This module's own hard-sync edge detection is
     correctly REGISTERED (`sensed_bus_prev_q`, one real CORE_CLK cycle of
     latency, a real and correct synchronous design, not a bug), so the
     phase-counter reset lands one cycle into the externally-driven SOF
     bit's own held window. `rtl019_integration_tb.sv` originally used a
     4-cycle-per-bit test configuration (BRP=1/TSEG1=2/TSEG2=1) with a
     sample point only 2 quanta after reset, leaving just one cycle of
     margin -- too tight for the testbench's own bit-driving task
     boundaries, producing a real, reproducible one-bit sampling
     misalignment on every externally-driven frame. Widened to 8
     cycles/bit (BRP=1/TSEG1=4/TSEG2=3) to give real margin; real external
     CAN traffic on an actual bus would never run this close to the wire.

138. **Compile/synthesize/verify scope, explicitly NOT full P&R-level
     completeness -- same disclosed scope as RTL-018 (item 121), not a
     RTL-017-style full close-out.** Per this session's own explicit task
     scope: a real `gate.ps1` run passed clean (lint/sim/formal/coverage),
     including a new dedicated `rtl019_integration_tb.sv` (567/567 checks)
     covering standard and extended frames, remote (RTR) frames, DLC edge
     cases (0 and 8), the real 5-bit stuffing boundary, a REAL externally-
     driven frame (not just a self-consistent loopback round trip, using a
     real CRC-15/bit-stuffing reference model built into the testbench
     itself), a real CRC error and a real ACK error (each independently
     checked for correct sticky/count/REC-or-TEC evidence and non-
     capture), the host-vs-route last-free-slot tiebreaker, TX and RX
     queue overflow, a real externally-forced arbitration loss (confirmed
     via the real internal `is_transmitter_q`, with the retained entry
     verified to actually drain once it can get a real ACK), LISTEN_ONLY
     (confirmed never driving dominant, confirmed never even attempting a
     queued transmission), the REG-ENC-006 `11` illegal combination
     clamp, a full TEC-to-BUS_OFF-to-AUTOMATIC-recovery cycle via the real
     128x11 count, a second BUS_OFF cycle exercising MANUAL recovery's own
     premature-rejection/eventual-acceptance behavior, and
     `can_transceiver_error_i` passthrough to both the dedicated sticky
     bit and `fault_req_o`. Two incidental stale-port breakages were found
     and fixed in `verification/testbench/rtl-001/regbank_smoke_tb.sv` and
     `dri_transaction_tb.sv` (both still referencing the 13 individual
     per-register CAN status stub ports removed from `dfc_rtl001.sv` in
     this same session, instead of the new aggregate `rtl019_control_o`/
     `rtl019_status_i` pair). A real Yosys `synth_ecp5` run (Build ID
     `20261020_180031`, via `build_ecp5.ps1 -SynthOnly`) completed cleanly,
     0 CHECK-pass problems reported, full statistics recorded in
     `output/logs/ecp5_synth_20261020_180031.log`. Real cumulative design
     totals (vs the RTL-018 baseline, Build ID `20261020_132014`): CCU2C
     3470->3719 (+249), L6MUX21 189->215 (+26), LUT4 28654->30286 (+1632),
     PFUMX 2598->2716 (+118), TRELLIS_FF 22360->23437 (+1077), MULT18X18D
     12->13 (+1, the client-2 word-offset `entry*6` multiply), PDPW16KD
     unchanged at 1. The real module-level delta is substantially bigger
     than RTL-018's own (+93 CCU2C/+864 LUT4/+188 PFUMX/+488 TRELLIS_FF),
     consistent with RTL-019 being the most protocol-complex single module
     in this project to date. **`nextpnr-ecp5` was never invoked this
     session** -- no
     place-and-route, no timing closure, no bitstream. RTL-019's status is
     "compiled, synthesized, verified," not "built" or "complete" -- the
     project continues holding at the RTL-016 FPGA baseline (item 112)
     for any real hardware target. Real physical pin assignment
     (`gn20`/`gn21`/`gn11`, the last two unshared `gn14`-`gn21` positions
     plus a genuine first spillover into the WiFi-shared range) is
     recorded in `ULX3S_CONNECTION_MAP.md`'s own new Section 13, not
     repeated here.

139. **RESOLVED (2026-10-20): the `check_coverage.py` 189/353-unchanged
     finding reported across the RTL-017, RTL-018, and RTL-019 gate runs
     (items 112 and 138) was a real, fixable script defect, not a
     "known limitation" -- that framing was asserted three times and never
     actually verified until this session. Closing it out with the real
     explanation and the real fix:**
     - **The prior explanation ("a word-boundary regex problem against
       this project's own `__`-delimited compound identifiers") was
       checked against `check_coverage.py`'s real matching code and found
       to be wrong.** The script's only pattern was `\bDFC_ADDR_<NAME>\b`,
       and that `\b`-bounded match was never the obstacle -- `DFC_ADDR_` is
       a plain, unambiguous prefix with no compound-identifier collision
       risk. The real cause, confirmed directly: `DFC_ADDR_` **never
       appears at all** in `verification/testbench/rtl-017`,
       `rtl-018`, or `rtl-019` (`grep -c DFC_ADDR_` on each is 0/0/0).
     - **Real root cause: a reference-PATTERN gap, not a regex-correctness
       bug.** RTL-001 through RTL-016's testbenches exercise registers
       almost entirely through a bus-level `dri_write`/`dri_read(
       DFC_ADDR_<NAME>, ...)` driver. RTL-017/018/019's own dedicated
       integration testbenches instead exercise the same registers
       directly at each module's `control_i`/`status_o` ports, indexed by
       the per-module aggregated-struct bit constants
       `pkggen.py`'s `emit_struct_field_consts()` emits for every
       register/field pair: `DFC_RTL<NNN>_(CONTROL|STATUS)__<REG_NAME>__
       <FIELD_NAME>_(HI|LO)` (e.g.
       `DFC_RTL017_STATUS__ARX_STATUS__NOT_EMPTY_HI`). `check_coverage.py`
       never recognized this second, equally-real reference convention, so
       every register exercised only that way counted as "unreferenced"
       regardless of how thoroughly it was actually tested.
     - **Fix**: `scripts/check_coverage.py` now also matches the
       `__<REG_NAME>__` substring that convention always embeds, alongside
       the original `DFC_ADDR_<NAME>` match (either counts as
       "referenced"). The double-underscore wrapping is itself an
       unambiguous delimiter -- a shorter register name cannot falsely
       match inside a different, longer register name's own `__..__`
       wrapping, since the character immediately following the shorter
       name would be `_`+a letter, not a second `_`.
     - **Real, confirmed result**: a real `gate.ps1` run after the fix
       moved coverage from the stale 189/353 (53.5%) to **225/353
       (63.7%)**, a genuine +36-register jump with zero RTL/testbench
       changes -- confirming the fix recognizes real, pre-existing test
       references the old script simply couldn't see, not new testing
       added to produce a number. `ARX_STATUS`, `ATX_CONTROL`,
       `CAN_CONTROL`, and every other register exercised only via the
       per-module bit-constant convention now correctly show as
       referenced. The remaining 128 unreferenced registers (e.g.
       `DFC_PRODUCT_REV`, `HOST_CONTROL`, `TEST_CONTROL`,
       `RTL02x_EVT_OVERFLOW_STATUS` for not-yet-implemented modules, the
       event/IRQ condition masks) are real, unaffected gaps -- genuinely
       untouched by any test, through either convention -- not an
       artifact of this fix.
     - Lint/sim (24/24 testbenches)/formal (4/4 tasks) were unaffected and
       unchanged by this fix, as expected: it only changes how
       `check_coverage.py` counts existing references, not any RTL or
       testbench behavior.

140. **RESOLVED (2026-10-20): a real, fixable `activity_i` wiring regression
     against this project's OWN already-made decision (item 83), found by a
     deliberate, project-wide master shared-resource-index audit (every
     `irq_source_i`/`fault_source_i`/`evt_valid_i`/`evt_record_i`/`activity_i`
     bit, RTL-001 through RTL-019, cross-referenced against ARCH-002's real,
     claimed owner for each bit and against `dfc_rtl024.sv`'s actual
     wiring) -- this generalizes item 125's accidental RTL-018/019 collision
     into the deliberate, complete check that collision implicitly called
     for, and it found one more real defect of the same underlying class
     (a module wired to the wrong shared-vector bit), this time a
     regression rather than a fresh collision.**

     **The master table** (bit : real claimed owner : real wiring before
     this item's fix : status):

     `irq_source_i[31:0]` (RTL-003), all 32 bits checked: 0=RTL-002,
     1=RTL-005, 2=RTL-006, 3=RTL-017, 4=RTL-018, 5=RTL-019, 6=RTL-020(not
     real yet), 7=RTL-021(not real yet), 8=RTL-007, 9=RTL-008, 10=RTL-009,
     11=RTL-010, 12=RTL-011, 13=RTL-012, 14=RTL-013, 15=RTL-014, 16=RTL-015,
     17=RTL-016, 18=RTL-022(not real yet), 19=RTL-023(not real yet),
     20=reserved, 21=RTL-001(claimed by ARCH-002 Appendix A, but RTL-001 has
     no real `irq_req_o` port yet -- pre-existing, already-disclosed gap,
     confirmed still correctly stubbed at `dfc_rtl024.sv:894`, not new),
     22-23=reserved. **Real wiring (`dfc_rtl024.sv:932`) matches exactly,
     bit for bit** -- no collisions, no fixes needed.

     `fault_source_i[31:0]` (RTL-013), all 17 real bits checked: 0=RTL-012,
     1=RTL-014, 2=RTL-015, 3=RTL-016, 4=RTL-011, 5=RTL-005, 6=RTL-007,
     7=RTL-008, 8=RTL-009, 9=RTL-010, 10=RTL-017, 11=RTL-018, 12=RTL-019,
     13-16=RTL-020..023 (not real yet), 17-31=reserved. **Real wiring
     (`dfc_rtl024.sv:548-564`) matches exactly** -- no collisions, no fixes
     needed.

     `evt_valid_i[23:0]`/`evt_record_i[23:0]` (RTL-005), all 24 slots
     checked: 0=RTL-001(claimed, but RTL-001 has no real `evt_valid_o` yet --
     pre-existing, already-disclosed gap, correctly stubbed), 1=RTL-002,
     2=RTL-003, 3=RTL-004, 4=RTL-005 (self-loop), 5=RTL-006, 6=RTL-007,
     7=RTL-008, 8=RTL-009, 9=RTL-010, 10=RTL-011, 11=RTL-012, 12=RTL-013,
     13=RTL-014, 14=RTL-015, 15=RTL-016, 16=RTL-017, 17=RTL-018, 18=RTL-019,
     19-22=RTL-020..023 (not real yet), 23=RTL-024 (no self-event). **Real
     wiring (`dfc_rtl024.sv:1041-1061`) matches exactly** -- no collisions,
     no fixes needed.

     `activity_i[7:0]` (RTL-015) -- **the one vector with a real, confirmed
     discrepancy.** `RTL-015.activity_i`'s own Appendix A row states the
     vector follows "exact source order from ARCH-SAFE-007" (ARCH-002:338,
     970): 0=host accepted command, 1=ARINC RX word, 2=CAN RX frame,
     3=UART RX byte, 4=GPIO qualified transition, 5=health qualified
     transition, 6=user diagnostic input transition, 7=watchdog-service
     pulse. Item 83 (2026-10-03) already found and resolved a conflict here
     in favor of this exact row, over five other modules' own individual
     Appendix A rows that each claimed a different bit for themselves
     (`RTL-012`/`RTL-017`/`RTL-019`/`RTL-020`/`RTL-021`'s own rows) -- and
     fixed `dfc_rtl012.sv`'s comment (bit1 -> bit7) accordingly at the time.
     **This audit found that item 83's resolution had been silently
     reversed for TWO of those five bits since then, by two later,
     unrelated sessions that never checked item 83 first:** RTL-017's own
     session (2026-10-06) wired its real `activity_o` to `activity_i[2]`
     (its own row's literal value, not the `[1]` item 83 had already
     decided), and this project's own RTL-019 session (today, item 125
     above) did the same for `activity_i[3]` (`[2]` was correct). Net
     effect before this fix: bit 1 was dead (tied 0, though ARINC RX
     activity is real and available), bit 2 carried ARINC RX activity
     instead of CAN RX frame activity, and bit 3 carried CAN RX frame
     activity instead of being dead -- RTL-015's loss-detection monitor
     configured for "ARINC RX word" (ID 1) was silently watching a
     permanently-dead bit, and a monitor configured for "CAN RX frame"
     (ID 2) was silently watching ARINC RX activity instead. Bits 4/5/7
     (RTL-006 GPIO, RTL-011 health, RTL-012 watchdog) were, by contrast,
     already correctly wired to item 83's resolution and are unaffected.
     Confirmed this bit position is not a configurable, don't-care detail
     before fixing it: REG-002's `LLINK_MONITOR_SELECT.MONITOR` (Section 27)
     only selects which of the 8 monitors `LLINK_MONITOR_CONTROL` configures
     (enable/event/irq/fault/response-mask) -- there is no separate
     activity-source-ID remapping field anywhere in RTL-015's register set,
     and `dfc_rtl015.sv`'s own header confirms monitor `m` is structurally
     hardwired to watch `activity_i[m]` directly. So which physical bit
     ARINC/CAN activity lands on directly determines which monitor's
     lost-link detection is actually watching it -- not a cosmetic detail.
     **Fixed**: `dfc_rtl024.sv`'s `rtl015_activity_vector_comb` now assigns
     `[1]=rtl017_activity`, `[2]=rtl019_activity` (previously `[2]`/`[3]`),
     consistent with bits 4/5/7 and with item 83's original resolution;
     updated comments in `dfc_rtl024.sv`, `dfc_rtl017.sv`, `dfc_rtl018.sv`,
     and `dfc_rtl019.sv` to match and to cross-reference this item. Bit 0
     (no real port anywhere, item 84, unchanged) and bit 6 (no real
     producer yet -- RTL-022/023 unimplemented) remain disclosed stub
     zeros, not invented. A real `gate.ps1` re-run after this fix
     (lint/sim 24/24/formal 4/4/coverage) confirms no regression; this
     wiring is combinational/registered-vector-composition only, not
     exercised bit-exactly by any existing testbench (`rtl015_integration_tb.sv`
     and `rtl024_skeleton_tb.sv` both only ever exercise bit 4 for their
     whole-system activity proofs), so no testbench changes were needed or
     made.

     **Why this is a DEFECT, not a fresh ambiguity**: the underlying
     ARCH-002-internal inconsistency (five conflicting rows vs. one
     canonical row) is the same one item 83 already classified and
     resolved; nothing new about ARCH-002 itself was discovered here. What
     was found is a real implementation regression -- two already-shipped
     modules' wiring silently drifted away from a decision this project had
     already made and recorded, exactly the class of mistake Part 2 of this
     session's task was designed to catch project-wide, not module-by-
     module.

141. **Real, disclosed ARCH-002-internal (Appendix A vs Appendix B) width
     staleness, found during this session's module-by-module RTL-001..019
     audit -- FOUR instances (a fourth found on a direct re-check of the
     full RTL-001..024 width table, after this item's own first pass missed
     it), same root cause, not an RTL defect (the implementation correctly
     follows the owning Appendix B/REG-002 struct width in all four cases,
     not Appendix A's stale annotation).** When a module's control struct
     grew by one bit to add an `EVT_OVERFLOW_STATUS`/`EVT_STATUS`-class
     clear-request field (the same fix class as items 40/43/122/etc.),
     Appendix B's own field table and the generated `dfc_types_pkg.sv` were
     correctly updated, but Appendix A's two restated width annotations for
     that struct (the producer row in RTL-001's own port table and the
     consumer row in the module's own port table) were left at the
     pre-growth value in four cases: `dfc_rtl005_control_t` (Appendix A
     says 128 at `docs/architecture/RCA-DFC-ARCH-002.md:601,734`; Appendix
     B `:1455` and `include/dfc_types_pkg.sv:418` correctly say 129 --
     `evt_status__snapshot_valid`, a `EVT_STATUS.SNAPSHOT_VALID` W1C clear
     field, added at the new highest bit per that struct's own header
     comment), `dfc_rtl007_control_t` (Appendix A says 135 at
     `docs/architecture/RCA-DFC-ARCH-002.md:605,783`; Appendix B and
     `include/dfc_types_pkg.sv:648` correctly say 136),
     `dfc_rtl011_control_t` (Appendix A says 121 at `ARCH-002:613,870`;
     Appendix B `:1733` and `dfc_types_pkg.sv:1138,1160` correctly say 122;
     see item 43's own original fix), and `dfc_rtl013_control_t` (Appendix A
     says 112 at `ARCH-002:617,914`; Appendix B `:1810` and
     `dfc_types_pkg.sv:1337,1359` correctly say 113; see item 110's area).
     Logged here per CHTR-DOC-006/this session's own instructions rather
     than silently fixed -- correcting Appendix A's own prose width columns
     is a documentation edit to a `-002` source document, not something an
     RTL session resolves unilaterally. RTL-001 through RTL-019's full
     control/status struct width table was mechanically cross-checked
     (Appendix A row vs Appendix B heading vs generated `_WIDTH` constant)
     during this audit; these four are the only mismatches found, and all
     four share the identical root cause (an `EVT_STATUS`/
     `EVT_OVERFLOW_STATUS`-class clear field added without touching
     Appendix A's two restated copies), not four independent defects.

142. **RESOLVED (2026-10-20): a real, confirmed missing-port defect in
     RTL-001, found during this session's RTL-001..005 module audit --
     the mirror-image of item 125's fabricated-port class (a real port
     ARCH-002 requires that the implementation never added, not an invented
     one it shouldn't have).** ARCH-002's real 74-port RTL-001 catalog
     includes `timestamp_i` (producer RTL-004, `ARCH-002:642`),
     `operating_state_i` (producer RTL-002, `ARCH-002:647`), and
     `observational_mode_i` (producer RTL-002, `ARCH-002:648`) -- none of
     the three self-referencing-row table-generation artifacts item 10
     already excuses (different real producer modules, not RTL-001 itself).
     `dfc_rtl001.sv` never declared any of the three. Confirmed this was a
     genuine oversight, not a deliberate scope cut: every other real module
     in this project (RTL-003/005/006/etc.) implements all three as real
     ports with an explicit RTLSTD-MOD-009 unused-port-sink tie-off when
     it has no functional consumer for them yet, and `dfc_rtl024.sv`'s own
     RTL-004 instantiation comment already (incorrectly) claimed
     "`timestamp_o` now genuinely reaches RTL-001/RTL-002/RTL-003" -- the
     comment was aspirational, not a description of real code; RTL-001 was
     simply never actually wired.

     **Fixed** (a real, mechanical defect fix, not an architecture
     judgment call -- RTL-001 has no state-dependent behavior and does not
     yet generate its own events, per that module's own header, so there
     is no real consumer for any of the three yet, same as RTL-003/005's
     own precedent):
     - Added `timestamp_i` (64 bits), `operating_state_i`
       (`dfc_types_pkg::DFC_OPERATING_STATE_WIDTH` bits), and
       `observational_mode_i` (1 bit) to `dfc_rtl001.sv`'s port list, with
       the same `unused_stub_sink` XOR tie-off idiom `dfc_rtl003.sv`/
       `dfc_rtl005.sv` already use for the identical situation.
     - Wired all three at `dfc_rtl024.sv`'s `u_rtl001` instantiation
       (`rtl004_timestamp`, `rtl002_operating_state`,
       `rtl002_observational_mode` -- the same broadcast wires every other
       consumer already uses). `rtl002_operating_state`/
       `rtl002_observational_mode`'s own declarations had to move earlier
       in the file (before `u_rtl001`, not their original spot just before
       `u_rtl002`) since `iverilog` requires a signal's declaration to
       lexically precede the instance referencing it.
     - Corrected `dfc_rtl024.sv`'s stale RTL-004-instantiation comment that
       had falsely claimed RTL-001 was already a consumer.
     - Added the same disclosed-stub `timestamp_i`/`operating_state_i`/
       `observational_mode_i` ('0) to `dri_transaction_tb.sv`, the one
       testbench that instantiates `dfc_rtl001` via a `.*` wildcard
       connection (which requires an exact-name match for every port,
       unlike an explicit named-connection instantiation).
     - The RTL-001 formal harness (`dri_one_outstanding_formal.sv`) uses
       explicit named port connections and was left as-is -- an omitted
       input port is legal SV (floats as a formal-solver free variable)
       and these three signals feed nothing but the new dead-end
       `unused_stub_sink`, so leaving them unconnected there changes
       nothing the proof actually checks.
     - A real `gate.ps1` re-run confirms no regression: lint PASSED; sim
       24/24 testbenches, 0 failures; formal 4/4 tasks PASSED (one
       interim run hit `dri_one_outstanding_prove`'s "Unexpected EOF
       response from solver" at the basecase engine -- reproduced in
       isolation and confirmed to be solver flakiness, not a real proof
       regression: an immediate standalone re-run of the identical task
       passed cleanly, basecase and induction both PASS); coverage
       unchanged at 225/353 (expected -- this fix adds dead-end plumbing,
       not new testable register behavior).

     **Full RTL-001..005 audit result (the rest of this session's
     module-by-module Part 2 coverage for these five modules):**
     - RTL-001: the one defect above; register/field audit otherwise
       clean (`dfc_rtl001_status_t`, 19 bits, matches Appendix B/REG-002
       bit-for-bit; no `rtl001_field_map.json` exists, correctly -- RTL-001
       uses `tools/reggen/dfc_rtl001_regbank_slice.json` per CLAUDE.md,
       being the regbank itself).
     - RTL-002: audited, no discrepancies found (24/24 ports, struct
       widths, REG-002 §7 fields, and `irq_source_i[0]`/`evt_valid_i[1]`
       wiring all confirmed correct).
     - RTL-003: audited, no discrepancies found (16/16 ports, struct
       widths, REG-002 §8's 8 registers, and `irq_source_i[31:0]`
       assembly all confirmed correct).
     - RTL-004: audited, no discrepancies found (13 real ports, correctly
       excluding item 10's self-referencing row; struct widths and REG-002
       §9's 12 registers confirmed correct).
     - RTL-005: audited, no discrepancies found beyond item 141's own
       already-disclosed Appendix A width staleness (confirmed, not new);
       19/19 ports including the deliberate `evt_valid_i[4]` self-loop,
       and REG-002 §10's 15 registers, all confirmed correct.

## RTL-020 (UART Interface) integration — compile/synthesize/verify scope only, most protocol-complex module to date

143. **RESOLVED (2026-10-20): `RTL-020_RevA.md` has a stale port count
     (same class as RTL-017/018/019's own 20/18/19-vs-33/28/33) AND, for
     the first time, a stale REGISTER count too.** SS2's own claim of "17
     total" ports is wrong -- ARCH-002 Appendix A's real header reads
     "RTL-020 - UART Interface (32 ports)" and the real table lists exactly
     32 rows, confirmed by direct count. SS1/SS5's own claim of "11
     registers, all offsets confirmed" is wrong too, and stated with more
     confidence than any prior module spec's own port-count error: REG-002
     §17's own block header says "Register count: 15," and the real listed
     rows confirm it -- `RTL-020_RevA.md`'s own list is missing
     `UART_RX_OVERFLOW_COUNT` (0x132C), `UART_RX_UNDERFLOW_COUNT` (0x1330),
     `UART_TX_REJECTED_COUNT` (0x1334), and `UART_TX_UNDERFLOW_COUNT`
     (0x1338) entirely -- an entire group of four real diagnostic counters,
     not a single off-by-one. Implemented against the real 32-port/
     15-register set via `tools/reggen/rtl020_field_map.json`; disclosed
     here, not followed.

144. **RESOLVED (2026-10-20): the 12th real instance of the exact
     `EVT_OVERFLOW_STATUS` clear-forwarding gap already fixed for RTL-002
     through RTL-019, approved before this session's edit.**
     `dfc_rtl020_control_t` had no clear-forwarding field for
     `RTL020_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-1328 bit 0, a real
     W1C field). Fixed the same way as every prior instance: ARCH-002 grew
     the struct 215->216 bits, adding `rtl020_evt_overflow_status__
     event_overflow` as a new `clear_mask` field at the new highest bit
     (215) -- every pre-existing field's bit position confirmed unchanged
     via the real `regenerate.ps1` run this session (a clean, isolated
     diff against `include/dfc_types_pkg.sv`, touching only
     `dfc_rtl020_control_t`'s own declaration).

145. **The master shared-resource-index table (item 140) was checked
     BEFORE wiring `activity_o`, exactly as this session's own task
     briefing required, and it caught a real collision before it shipped
     -- not after, the way items 83/125/140 each had to.** RTL-020's own
     Appendix A `activity_o` row literally reads "RTL-015.activity_i[4]" --
     identical in kind to RTL-012/017/019/021's own already-identified-
     and-overruled rows (item 83: five conflicting individual rows, each
     resolved in favor of RTL-015's own row instead). Bit 4 is already,
     correctly occupied by RTL-006 (GPIO qualified transition, per
     ARCH-SAFE-007's own ID order and item 83/140's resolution); RTL-020's
     real ID is 3 ("UART RX byte"), which item 140's own master table
     already identified as free. Wired to `RTL-015.activity_i[3]` in
     `dfc_rtl024.sv`, NOT this module's own row's literal `[4]` -- this
     session's own task briefing was itself wrong on this specific point
     (it asserted "RTL-020 has no `activity_o` port per the real Appendix
     A row," when the real row both exists and names a bit already
     occupied by a different, correct, real module) -- the master-table
     check this session's own briefing itself mandated is exactly what
     caught that assertion before it was trusted uncritically. `activity_o`
     pulses specifically on a byte genuinely committed into the RX queue,
     matching ID 3's own "UART RX byte" description, not on any TX event.

146. **Three real, genuine RTL bugs found and fixed while implementing and
     testing this module, all caught by this module's own dedicated
     testbench or by a direct design review before first test run, none
     left unfixed:**
     - **A real BREAK condition did not actually suppress the queued
       commit**, despite this module's own header already asserting "no
       byte is queued for a break" as a disclosed design choice -- the
       assertion was written, but the RTL never implemented it:
       `rx_commit_want_q` pulsed unconditionally on every completed frame,
       break or not. Found by this module's own testbench (Case 8: "no
       byte queued for a break" failed with a real queued byte present).
       Fixed by splitting the single completion pulse into two: a
       break-suppressed `rx_commit_want_q` (queues the byte) and an
       unconditional `rx_frame_done_q` (drives classification/evidence --
       `BREAK_DETECTED` sticky and the aggregate error count must still
       fire on a break, only the queue commit itself is suppressed).
     - **The real RX-queue-full overflow sub-case was never actually
       checked.** REG-1324's own text names two distinct causes under one
       counter ("overflow OR dropped-byte"); this module's header already
       disclosed both, but only sub-case (a) (the one-deep staging
       register already occupied) was ever implemented -- sub-case (b)
       (the arbiter ready to commit a staged byte, but the 16-entry queue
       itself already full) was asserted in the header and never coded,
       silently overflowing `rx_count_q` past 16 and corrupting the real
       16-entry client-3 segment. Found by this module's own testbench
       (Case 10: a 17th byte was accepted into a supposedly-full queue).
       Fixed: the arbiter's own `PH_IDLE` dispatch now checks
       `rx_queue_full` before ever issuing the commit write, dropping the
       staged byte with the same overflow sticky/count instead.
     - **Majority-vote polarity was inverted** (`>=2 of 3 samples HIGH`
       was mapped to a sampled bit of `0`, the exact opposite of what a
       majority-HIGH vote means) -- found via direct design review before
       this module's first real simulation run, not by a failed test
       (the error would have manifested as every real frame being
       misread, likely surfacing as a false start-bit glitch-rejection on
       nearly every real byte). Also found and fixed the same way, before
       first run: the even/odd parity formulas were swapped (`PARITY=01`
       even is the XOR-reduce, not the XNOR-reduce) in both the RX
       classifier and the TX serializer; and the TX serializer's own
       bit-index advance used a blind `+1` increment that would walk
       through the real `TXB_PARITY` state as an actual extra bit-time
       even when parity was disabled, corrupting the frame length --
       replaced with an explicit next-state table mirroring the RX side's
       own already-correct `want_parity ? RXS_PARITY : RXS_STOP1`
       transition.
     A real `gate.ps1` run after all three fixes passed clean (lint;
     sim 25/25 testbenches including this module's own new 65-check
     `rtl020_integration_tb.sv`, 0 failures; formal 4/4; coverage
     239/353, up from 225/353 -- a genuine +14-register jump from this
     module's own 15 new registers, most now exercised for real).

147. **Real, disclosed design choices and genuine gaps, logged per
     CHTR-DOC-006 rather than silently assumed or invented:**
     - **BREAK-detection heuristic** (neither ARCH-002 nor REG-002 states
       a bit-exact algorithm): a break is classified when the stop-bit
       framing check fails AND every sampled data bit AND the parity bit
       (if checked) were all 0 -- the entire frame held low, the standard
       real-world break signature, distinct from an ordinary single-bit
       framing glitch.
     - **`PARITY==2'b11` defensive clamp** (REG-ENC-007: "parity 3 is
       rejected," and RTL-001 does not yet implement per-field legal-value
       range checks at all -- the same already-disclosed, pre-existing gap
       RTL-001's own header names as its single biggest conformance gap):
       treated identically to `PARITY==2'b00` (no parity) by both RX and
       TX, the same defensive-clamp-for-an-illegal-2-bit-encoding
       precedent RTL-019's own CAN `LOOPBACK`/`LISTEN_ONLY` `11` handling
       already established (item 131).
     - **The second stop bit's own value is not separately validated**
       when `TWO_STOP_BITS=1` -- only the first stop bit's framing check
       is real; the second is timed but not re-checked, a disclosed
       simplification common to many real UART implementations.
     - **UART's own "underflow" event/irq condition bit (Appendix F.3 bit
       5) is shared by two real, independently-counted conditions**
       (`RX_UNDERFLOW` and `TX_UNDERFLOW`) -- REG-002/Appendix F.3 give
       this module only one condition-enable bit for both, the same
       "two real conditions, one condition-enable bit" disclosed-
       interpretation precedent RTL-018's own bits 1/2 and RTL-019's own
       bit 4 already established.
     - **A route-drained RX byte's own message-record timestamp is read
       LIVE at drain time, not the real original receive time** --
       `ARCH-BUF-025`'s own 1-word RX entry layout has no stored timestamp
       field at all (unlike ARINC's 4-word/CAN's 6-word entries, which
       both carry one), so there is nothing to replay. A disclosed
       information loss, same class as finding 6's own sequence
       truncation in RTL-017, just total rather than partial, and
       inherited directly from REG-002's own entry-layout choice, not
       invented here.
     - **`fault_req_o` is a permanent, disclosed stub (tied `1'b0`)** --
       ARCH-002's real 32-port RTL-020 table defines no adapter-error- or
       transceiver-error-equivalent input for UART at all (unlike ARINC/
       CAN), so there is no real hardware-fault condition for this module
       to escalate; every RX/TX error condition is already visible via its
       own sticky bit and counter, the same severity judgment RTL-017/
       018's own fault_req_o documentation already applies to their own
       non-adapter-error conditions.
     - **Genuine, newly-found ARCH-002-internal tension (not a defect,
       disclosed not resolved)**: SS11.1's own generic per-type text says
       UART's `dfc_message_record_t` data lives in "metadata bits 7:0...
       with payload length zero" -- but RTL-017/018/019's own already-
       shipped, already-verified implementations all put their own data in
       PAYLOAD (length nonzero) and classification/status info in
       METADATA, the opposite convention. This module follows the
       already-shipped sibling convention for project-wide consistency
       (payload=data, metadata=`{sequence,error_flags,data}` verbatim)
       rather than SS11.1's own literal text, since this entire path is
       unreachable either way until RTL-021 (Message Router) exists to
       actually consume it. Not something this module can resolve
       unilaterally; flagged for a future ARCH-002 reconciliation pass.
     - **Pin budget**: `uart_rx_i`/`uart_tx_o` are the simplest Databus
       pin budget so far (2 pads, no transceiver-error-equivalent input).
       Both come from the WiFi-shared range (`gp11`/`gn12`, SITEs F4/F3) --
       the unshared `gn14`-`gn21` range was already fully exhausted by
       RTL-019 (item set for that module). Real consequence disclosed in
       `ULX3S_CONNECTION_MAP.md` Section 14 and `fpga/ecp5/ulx3s_dfc.lpf`'s
       own comments: neither pad is genuinely available while the onboard
       WiFi module is active on real hardware.
     - **`nextpnr-ecp5` was not invoked this session** -- no place-and-
       route, no timing closure, no bitstream. RTL-020's status is
       "compiled, synthesized, verified," not "built" or "complete" -- the
       project continues holding at the RTL-016 FPGA baseline (item 112)
       for any real hardware target.

## RTL-021 (Databus Routing Engine) integration — the central routing hub every other Databus module's route ports finally connect through

148. **RESOLVED (2026-10-22): `RTL-021_RevA.md` has a stale port count
     (same class as RTL-017/018/019/020's own 20/18/19/17-vs-33/28/33/32)
     AND two separately-stated stale register counts.** SS2's own claim of
     "16 total" ports is wrong -- ARCH-002 Appendix A's real header reads
     "RTL-021 - Databus Routing Engine (30 ports)" and the real table
     lists exactly 30 rows, confirmed by direct count (not assumed from
     the header alone, the same discipline every prior module's own
     session applied). SS1/SS5's own claim of "17 registers" (stated
     twice) is also wrong: REG-002 §18's own block header says "Register
     count: 24," and the real listed rows confirm exactly 24 by direct
     count -- the entire 5-register `ROUTE_ACTIVE_*` readback group and
     the two independently-clearable `ROUTE_INGRESS_LOSS_COUNT_*`/
     `ROUTE_DESTINATION_DROP_COUNT_*` counter groups RevA's own prose never
     enumerates at all, not a single off-by-one. Implemented against the
     real 30-port/24-register set via `tools/reggen/rtl021_field_map.json`;
     disclosed here, not followed.

149. **RESOLVED (2026-10-22): the 13th real instance of the exact
     `EVT_OVERFLOW_STATUS` clear-forwarding gap already fixed for RTL-002
     through RTL-020, approved before this session's edit.**
     `dfc_rtl021_control_t` had no clear-forwarding field for
     `RTL021_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` (REG-1440 bit 0, a real
     W1C field). Fixed the same way as every prior instance: ARCH-002 grew
     the struct 135->136 bits, adding `rtl021_evt_overflow_status__
     event_overflow` as a new `clear_mask` field at the new highest bit
     (135) -- every pre-existing field's bit position confirmed unchanged
     via a real `regenerate.ps1` run (a clean, isolated diff against
     `include/dfc_types_pkg.sv`, touching only `dfc_rtl021_control_t`'s own
     declaration).

150. **RESOLVED (2026-10-22): a NEW gap class this session, the same
     undershoot pattern as item 149 but on the STATUS side instead of the
     CONTROL side.** `dfc_rtl021_status_t` had no field anywhere for
     `ROUTE_ACTIVE_CONTROL`'s `ENABLE`/`DROP_ON_FULL` (REG-145C, a real
     `external`-readback register with specific REG-002 text: "Reads
     selected entry's active enable"/"active drop-on-full policy") --
     confirmed by summing the struct's own documented bit ranges end to
     end (0 through 335 inclusive, exactly 336 bits, fully tiled, no gap
     anywhere for this). Judged to be the SAME gap class as item 149
     (ARCH-002 undershooting a REG-002-specified real forwarding need by a
     small, unambiguous number of bits), just on the read side, with
     equally unambiguous semantics (two single RO mirror bits, nothing to
     invent) -- fixed the identical way: ARCH-002 grew the struct 336->338
     bits, adding `route_active_control__enable`/`__drop_on_full` at the
     new highest bits (336/337). Confirmed via a real `regenerate.ps1` run
     (isolated diff, every other struct unaffected).

151. **`reggen.py` extended to v6: a brand-new "COUNTER16-CLR" register
     access class, the first real need for it anywhere in this project.**
     REG-002's own text for the six `ROUTE_INGRESS_LOSS_COUNT_*`/
     `ROUTE_DESTINATION_DROP_COUNT_*` registers ("Independent halfword
     whole-counter clears"; "Any other halfword rejects the complete
     word") packs TWO independent 16-bit saturating counters per 32-bit
     register (or one real counter + one RSV0 halfword for the two
     `_4` registers, source/destination ID 4 ULI), each independently
     host-clearable -- a shape neither `COUNTER-CLR` (RTL-020's own
     `UART_*_COUNT` precedent: whole-32-bit raw-value-forward, consumer
     does its own edge detection) nor plain `RW`/`W1C` (whole-32-bit pulse
     or stored value) can produce. `reggen.py` now generates, per register
     HALF: on the CONTROL side, a genuine one-cycle clear-pulse (write
     0xFFFF to that 16-bit half, same halfword-isolation discipline as the
     32-bit `COUNTER-CLR` precedent but per-halfword) driving one specific
     bit of the wider 5-bit `dfc_rtl021_control_t` clear vector named by a
     new field-map `"bit"` key; on the STATUS side, a sub-slice read (one
     16-bit window out of the wider 80-bit packed `dfc_rtl021_status_t`
     count vector, "five packed 16-bit saturating counts ... in ascending
     slices" per ARCH-002's own text) using the same `"bit"` key. Verified
     via a real `regenerate.ps1` run producing "real cross-module
     forwarding wired for RTL-021: 18 control regs, 15 status regs" with
     no assertion failures -- the pre-existing, unmodified
     `mapped_bits==control_width` whole-struct tiling check still passed,
     confirming no overlap/gap was introduced across all 24 registers. See
     `tools/reggen/rtl021_field_map.json`'s own `_source` note and
     `reggen.py`'s own inline comments at both edit points for the full
     reasoning. A genuine, scoped generator extension, not a hand-authored
     workaround (RTLSTD-ORG-003/004/010).

152. **The master shared-resource-index table (item 140) was checked
     BEFORE wiring `activity_o`, exactly as every Databus session since
     item 140 has required, and it correctly ruled out RTL-021 as well --
     the SIXTH instance of the exact item-83 conflict class, but the FIRST
     one with no real destination anywhere for this module's own activity.**
     RTL-021's own Appendix A `activity_o` row literally reads
     "RTL-015.activity_i[5]" -- but the master table (RTL-015's own
     consumer-side row + ARCH-SAFE-007's own fixed ID-order text: 0 host,
     1 ARINC RX, 2 CAN RX, 3 UART RX, 4 GPIO, 5 health, 6 user diagnostic,
     7 watchdog) assigns bit 5 to "health qualified transition" (RTL-011,
     already real and correctly wired there) -- RTL-021's own row is the
     same already-identified-and-overruled conflict class as RTL-012/017/
     019/020's own rows (item 83: five conflicting individual producer
     rows, each overruled in favor of RTL-015's own row), EXCEPT that,
     unlike those five, RTL-015's own canonical order has no OTHER slot
     anywhere that legitimately belongs to RTL-021 either -- there simply
     is no legal `activity_i` destination for "routing engine activity" in
     this design. `activity_o` is implemented as a real, correctly-pulsing
     port (one CORE_CLK pulse per qualified accepted unit of work,
     dfc_rtl021.sv's own finding, matching Appendix A's own generic
     description) but left genuinely unconsumed at `dfc_rtl024.sv`
     integration -- a disclosed structural consequence of this conflict
     class, not a bug in this module, and not something this session has
     authority to resolve unilaterally (it would require either revising
     RTL-015's own fixed 8-condition order, or accepting that one more
     Appendix-A-claimed `activity_i` destination is permanently
     unreachable).

153. **REAL, CONFIRMED GAP found and fixed: RTL-001's own
     `route_tx_msg_*`/`route_rx_msg_*` ports (ARCH-002 Appendix A's real
     RTL-001 row, Host ingress/egress, ARCH-MSG-004 module ID 0x03) did
     not exist on `dfc_rtl001.sv` at all before this session** -- confirmed
     absent via direct grep of the file before this edit, not assumed.
     Added this session with a permanent RTLSTD-MOD-009 disclosed-stub tie
     (`route_tx_msg_valid_o=1'b0`, `route_tx_msg_record_o='0`,
     `route_rx_msg_ready_o=1'b0`): REG-002 defines NO register-level
     mechanism anywhere for the host to stage an outgoing routed message
     or read back a delivered one for this channel, so there is no real
     content to wire these ports to yet, and none is invented here. This
     is a genuine, OPEN gap -- not a forward reference expected to resolve
     soon the way RTL-022/ULI (item 156) is -- since closing it for real
     would require REG-002 itself to define a host-visible staging
     mechanism for this channel, which is this session's finding to
     surface, not to invent.

154. **REAL, CONFIRMED BUG found and fixed, pre-existing from RTL-020's own
     session, not introduced this session: `dfc_rtl001.sv`'s own
     `rtl020_control_o`/`rtl020_status_i` ports were never connected to
     the matching `rtl020_control`/`rtl020_status` top-level wires inside
     `dfc_rtl024.sv`.** Both individual modules' own sides of this
     cross-module register bus were wired correctly (`dfc_rtl001.sv`
     itself forwards these ports to its internal generated regbank;
     `u_rtl020`'s own instantiation correctly uses `rtl020_control`/
     `rtl020_status`) but the two were never actually joined to each other
     at the one integration point that connects them -- `u_rtl001`'s own
     instantiation in `dfc_rtl024.sv` simply omitted both port
     connections, leaving `rtl020_control_o` genuinely floating and
     `rtl020_status_i` reading X in simulation. A real, user-visible
     consequence: every RTL-020 (UART) register the host believes it
     configured through the real DRI/SPI path was never actually reaching
     `dfc_rtl020.sv` at all, and RTL-020's own real status never reached
     the host's own readable registers either, in the full chip
     integration specifically (not in `rtl020_integration_tb.sv`, which
     instantiates `dfc_rtl020` directly and never exercises this path).
     Not caught by RTL-020's own session because a named-connection
     instantiation silently omitting a port is not an Icarus elaboration
     error (a dangling port, not a syntax failure) -- found here only
     because this session's own `lint.ps1` run surfaced a *different*,
     unrelated compile failure (the regenerated regbank no longer exposing
     the old individual `route_*_status_i` ports once RTL-021's own
     field-map existed), which led to inspecting `dfc_rtl001.sv`'s own
     instantiation closely enough to notice the RTL-020 omission sitting
     right next to where the RTL-021 connection needed to be added. Fixed
     by adding `.rtl020_control_o(rtl020_control)`/
     `.rtl020_status_i(rtl020_status)` alongside the new RTL-021
     connections.

155. **REAL, CONFIRMED BUG found and fixed via `rtl024_skeleton_tb.sv`,
     this session's own new wiring, not pre-existing: `rtl017_msg_ready`
     was declared and connected at `u_rtl017`'s own instantiation but the
     one `assign` actually driving it from `rtl021_source_ready[0]` was
     never written**, leaving it a genuinely undriven (X in simulation)
     dangling net -- RTL-017's own queue never drained (`count_q` read X,
     not a clean 0/1) even with `ROUTE_CONTROL.ENABLE` real and correctly
     set. Every other newly-wired route-port signal this session used
     either a direct read-slice of one of RTL-021's own output vectors
     (`source_ready_o`/`dest_valid_o`/`dest_record_o`, safe with no
     dedicated signal needed) or a dedicated signal actually driven by
     the OTHER module's own output port (`rtl018_msg_ready` et al.,
     correctly driven since it's an output of `u_rtl018`) -- this one slot
     used a dedicated signal name for what should have been a direct
     read-slice, and the corresponding `assign` was simply never added.
     Caught by the whole-chip skeleton test, not by inspection; the
     per-module `rtl021_integration_tb.sv` could not have caught this
     class of bug at all, since it drives RTL-021 standalone with no
     RTL-017 in the loop.

156. **DESIGN REFINEMENT, found via `rtl024_skeleton_tb.sv`'s own real
     system state, not by inspection: `effective_operational_enable_i` was
     originally read to gate BOTH ingress acceptance and replication,
     which turned out to be broader than every other module's own
     established convention and genuinely blocked RTL-017's queue from
     ever draining while the system had not yet reached NORMAL/DEGRADED
     (OPEN_ISSUES.md item 98's own mandatory-init gate, under which
     `EFFECTIVE_OPERATIONAL_ENABLE` is real and legitimately low).**
     Every other module's own `effective_operational_enable_i` gates only
     its OWN outward/TX-equivalent action (e.g. RTL-020's own gate applies
     only to `dequeue_start`, never to its own RX acceptance path) --
     accepting a message into RTL-021's own internal ingress slot has no
     effect outside this module yet, so it is not itself "externally
     effective action" the way delivering a copy to ANOTHER module is.
     Refined to match: `source_ready_o` (ingress acceptance) is now gated
     only by `ROUTE_CONTROL.ENABLE`; `effective_operational_enable_i`
     gates only the decision to START a REPLICATE (the real delivery
     action) -- drops (pure internal bookkeeping, no external effect) and
     head-refreshes/dequeues remain ungated either way. Re-verified against
     both `rtl021_integration_tb.sv` (63/63, no regression, since that
     testbench always drives this signal `1'b1`) and the full whole-chip
     skeleton test (which exercises the real, low-during-bring-up case).

157. **Two real RTL-021 defects found via its own `rtl021_integration_tb.sv`
     simulation (not by inspection), both in the destination-queue
     head-snapshot mechanism, both fixed:**
     - **Premature `dest_head_valid_q` assertion (a genuine data hazard).**
       The original centralized per-destination queue-bookkeeping block set
       `dest_head_valid_q<=1'b1` immediately at the SAME cycle a replicate-
       write landed into a previously-empty queue, rather than waiting for
       the dedicated `OP_HEAD_REFRESH` read that actually brings the real
       head data into `dest_head_snap_q` to complete. This let
       `dest_valid_o`/`dest_record_o` assert ONE head-refresh-latency early,
       with `dest_record_o` still showing stale/reset-zero content -- the
       testbench's own "duplicate-route dedup produces exactly one copy"
       check caught a consumer popping this premature snapshot (read as a
       second, spurious delivery). Fixed: `dest_head_valid_q` is now set
       ONLY by `OP_HEAD_REFRESH`'s own completion, never pre-emptively in
       the write-completion path.
     - **`OP_HEAD_REFRESH`'s own completion did not re-check queue
       emptiness.** A head-refresh queued while the destination queue still
       held one item could complete AFTER that same item was, in the
       meantime, popped by an intervening dequeue (the read itself takes
       six real CORE_CLK cycles) -- the original code unconditionally set
       `dest_head_valid_q<=1'b1` at completion regardless, re-asserting
       `dest_valid_o` with a stale snapshot of an entry that was never
       really written. Fixed: the completion now gates on
       `dest_count_q[op_dst_q] != 0`, the exact live count at that cycle
       (already reflecting every write/pop that happened during the
       refresh's own multi-cycle read).
     Both found and fixed BEFORE moving on to the remaining required test
     cases, each confirmed via a small, isolated, hierarchically-
     instrumented debug testbench (not the full 25-pair/backpressure/
     epoch-capture suite) before being re-verified against the complete
     `rtl021_integration_tb.sv` run.

158. **Real, disclosed design choices and genuine gaps, logged per
     CHTR-DOC-006 rather than silently assumed or invented:**
     - **ARCH-RTL021-001's "commit replaces all sixteen entries
       atomically" vs. REG-1424's own literal per-entry
       `VALIDATE_COMMIT`/`ENTRY_SELECT` mechanism (which can only ever
       commit ONE entry per pulse) is a real, confirmed ARCH-002-internal
       tension** -- REG-002 gives no "commit all sixteen simultaneously"
       register mechanism anywhere. Reconciled (disclosed, not silently
       picked) by reading "atomically" as "each single-entry commit is
       itself all-or-nothing" (no torn partial-field update), and treating
       the genuinely load-bearing half of ARCH-RTL021-001 as its own
       explicit epoch-capture sentence: "an in-flight record completes
       under the configuration epoch captured at ingress acceptance."
       Implemented literally: a record's full routing decision is resolved
       combinationally and registered once, at the exact cycle it is
       accepted, against the active table as it existed at that instant --
       never re-evaluated even if a later commit changes the table while
       that record is still being replicated. Has its own dedicated test
       (VP-BUS-009's own named highest-risk case).
     - **Three ARCH-ROUTE-007 commit codes are structurally unreachable,
       one is disclosed-ambiguous and never generated, not silently
       skipped.** `01` invalid entry: `ENTRY_SELECT` is a real 4-bit field,
       0-15 all legal, so there is no encoding of "invalid entry" to
       detect. `06` reserved flag/field: every `ROUTE_STAGE_*` register's
       own RSV0 bits are already rejected whole-write by RTL-001's generic
       bus-decode layer before ever reaching `control_i`. `08` busy: this
       module commits in a single CORE_CLK cycle, pure internal register
       update, with no shared-buffer or multi-cycle dependency -- there is
       no busy state a commit could ever observe. `07` duplicate conflict
       is different in kind: REG-002 names the code but gives no
       definition of what "duplicate" means at COMMIT time
       (ARCH-ROUTE-003's own "duplicate selections... produce one copy"
       text is an INGRESS-TIME replication rule, not a commit-time
       validation rule) -- inventing a specific definition would be
       inventing behavior this module has no authority to impose
       unilaterally, so this code is never generated. A genuine, open
       architecture ambiguity, not resolved here.
     - **`VALIDATE_COMMIT`+`DISABLE_ENTRY` asserted the same cycle (REG-1424's
       own "undefined encoding... rejects with no command pulse") is a
       real case this module must itself defensively reject** -- RTL-001's
       generic WO-CMD pulse-capture forwards `wdata_i` verbatim with no
       per-encoding exactly-one-hot validation (the same already-disclosed,
       pre-existing RTL-001 gap its own header names, "no per-field
       legal-value range checks"), so both pulses would otherwise arrive
       simultaneously. This module checks for exactly that collision and
       executes NEITHER command when it occurs, with its own dedicated
       test case.
     - **Status-bit interpretations where REG-002 gives behavior text but
       not a unique internal trigger:** `ROUTE_STATUS.ACTIVE` reads as a
       direct mirror of the global `ROUTE_CONTROL.ENABLE` bit (this
       register's own text groups it with "commit/runtime errors" and its
       name is otherwise generic). `ROUTE_STATUS.LAST_ERROR` is ONE shared
       8-bit field for both ARCH-ROUTE-007 commit codes (00-08) and
       ARCH-ROUTE-008 runtime codes (10-15) -- the two spaces are disjoint
       and tested independently (own dedicated test cases confirming codes
       02/03/05 and 10/11/12/13 each independently, never conflated), but
       they share one storage field, overwritten by whichever class of
       event happens most recently -- a storage-sharing fact, not a
       conflation of meaning. When multiple distinct `LAST_ERROR`-writing
       events genuinely collide in the identical cycle (e.g. a destination
       drop and an ingress-loss classification both firing together), the
       textually-last assignment in the generated `always_ff` wins, a
       disclosed, deterministic-but-arbitrary resolution of a
       simultaneous-event ambiguity REG-002 itself does not address,
       matching the project's own established "first-failure priority
       order" disclosure precedent. `ROUTE_ENTRY_STATUS` (selected by
       `ENTRY_SELECT`): `VALID` = this entry index has been committed at
       least once; `ACTIVE` = `VALID` AND the entry's own current `ENABLE`
       bit (a convenience derived-AND flag, not literally redundant with
       `ROUTE_ACTIVE_CONTROL.ENABLE`); `ERROR` (W1C) = sticky evidence that
       the LAST `VALIDATE_COMMIT` pulse while this entry was selected was
       rejected (per-entry granularity alongside the global
       `COMMIT_REJECTED` bit); `FORWARDED_COUNT` = saturating count of
       destination copies successfully written attributable to this entry.
     - **Duplicate-route entry-order tie-break** (ARCH-ROUTE-003): for each
       destination, the LOWEST-INDEXED matching entry wins (first-match,
       "evaluated in entry order"); that entry's own `DROP_ON_FULL` policy
       is the one captured for that copy, and that entry is the one
       credited in `FORWARDED_COUNT`. REG-002/ARCH-002 do not say which
       matching entry "owns" a duplicate-selected destination's policy/
       credit, only that exactly one copy results -- a disclosed choice,
       with its own dedicated dedup test (VP-BUS-008).
     - **Destination round-robin + the real no-head-of-line-blocking
       mechanism** (VP-BUS-009's second named risk): each destination's
       per-cycle candidate scan continues PAST a required-but-currently-
       full candidate (`DROP_ON_FULL=0`) to find the next eligible one in
       rotation, rather than fixating on the first-found index -- the one
       real design decision that prevents a currently-blocked required
       copy from one source starving a SIMULTANEOUS drop-eligible copy
       from a different source at the same, physically full destination.
       Drops are pure internal bookkeeping (no shared-buffer transaction),
       so they resolve the same cycle regardless of whether the single
       shared buffer channel is simultaneously busy servicing a DIFFERENT
       destination's write -- confirmed via its own dedicated
       simultaneous-backpressure-and-drop test, both outcomes in the same
       cycle window.
     - **Buffer arbiter priority**: INGRESS-WRITE > DEST-HEAD-REFRESH >
       REPLICATE, fixed dest-index order (0 highest) when multiple
       destinations are simultaneously write-ready -- a disclosed,
       uncontested fixed order for an orthogonal question ARCH-ROUTE-006's
       own round-robin requirement does not reach (that requirement is
       about which INGRESS SOURCE a destination services next, not which
       DESTINATION gets the shared buffer first), same class of choice as
       every prior module's own fixed internal arbiter priority.
     - **RTL-022 (ULI, source/destination index 4) is a genuine forward
       reference**, same structural shape as RTL-017/018's own earlier
       forward references to RTL-021 before it existed -- tied off
       identically (disclosed stub: `source_valid_i[4]`/`dest_ready_i[4]`
       never asserted by this integration) but expected to resolve soon,
       per this session's own task briefing, since RTL-022 is explicitly
       planned as a near-term module.
     - **`fault_req_o` is a permanent, disclosed stub (tied `1'b0`)** --
       routing/queue errors (drops, rejected commits, shared-buffer
       errors) are ordinary operational conditions already visible via
       their own sticky bits and counters, not systemic faults, the same
       severity judgment every prior Databus module's own fault_req_o
       documentation already applies.
     - **`rtl024_skeleton_tb.sv` extension judged NOT done this session,
       disclosed as real future work, not silently skipped**: RTL-021 is
       plausibly the first module that could route a genuine message
       end-to-end between two already-real Databus modules (e.g. a real
       committed ARINC->CAN route, verified by driving a real ARINC word
       and observing it land in CAN's own real TX queue through RTL-021),
       a meaningfully stronger whole-chip integration test than RTL-018/
       019/020's own individual sessions could offer. Only the minimal fix
       needed to keep the EXISTING skeleton test passing (a real
       `ROUTE_CONTROL.ENABLE` SPI write, plus widening its own queue-drain
       wait margin to reflect RTL-021's own real, multi-stage buffer
       latency) was made this session; a real end-to-end route-and-deliver
       extension is judged meaningful but out of scope for this already-
       large session, not attempted hastily.
     - **`nextpnr-ecp5` was not invoked this session** -- no place-and-
       route, no timing closure, no bitstream. RTL-021's status is
       "compiled, synthesized, verified," not "built" or "complete" -- the
       project continues holding at the RTL-016 FPGA baseline (item 112)
       for any real hardware target.

159. **REAL, CONFIRMED BUG found and fixed via `build_ecp5.ps1 -SynthOnly`
     itself, not by simulation or inspection: a genuine Yosys synthesis-
     tool latch-inference false positive, the first of its own specific
     kind this project has hit.** `dfc_rtl021.sv`'s own route-resolution
     `always_comb` block wrapped its 16-entry scan `for` loop inside an
     outer `if (!rslv_malformed[rs])` conditional -- a shape no other
     `always_comb`/`always_ff` block in this file (or, as far as this
     session confirmed, anywhere else in the project) uses: every other
     loop in this module runs unconditionally, with any gating folded into
     the loop BODY's own conditions instead of around the loop itself.
     Yosys's own latch-inference check misread the loop's own index
     variable `re` (pure loop-unrolling scratch state, never read outside
     this process) as a real signal needing a latch purely because the
     whole `for` statement -- including `re`'s own loop-control assignment
     -- was reachable only through that outer conditional:
     `ERROR: Latch inferred for signal \`re[3:0]\` from always_comb process`.
     A real, reproducible toolchain limitation around this specific
     "conditional wrapping an entire for-loop, including its own index"
     shape, not a functional RTL defect -- `rtl021_integration_tb.sv`'s own
     63/63 passing run, both before and after this fix, confirms the
     module's real behavior is unchanged (the malformed guard was moved
     into `r_entry_match_src_type`'s own condition, functionally
     identical, just restructured so the `for` loop itself is always
     entered). Caught at `build_ecp5.ps1 -SynthOnly` time specifically --
     neither `lint.ps1`'s own per-file Icarus elaborate check nor the full
     `gate.ps1` run (lint+sim+formal+coverage, all of which passed clean
     before this fix) exercises Yosys's own synth_ecp5 flow at all, so this
     class of defect is only ever caught by a real synthesis attempt, the
     same reason this project's own standing discipline never treats
     `gate.ps1 PASSED` as a substitute for a real `build_ecp5.ps1` run.
     Real, confirmed final cell-count/utilization stats after the fix
     (Build ID `20261022_104724`, `-SynthOnly`, 0 CHECK-pass problems,
     `nextpnr-ecp5` never invoked): CCU2C 3997, L6MUX21 805, LUT4 41313,
     PFUMX 4431, TRELLIS_FF 27574, MULT18X18D 44, PDPW16KD 1. Real
     cumulative delta against the last explicitly-recorded baseline in
     `PROJECT_CONTINUITY.md` (RTL-019's own post-build figures, Build ID
     `20261020_180031`, since no RTL-020-specific synthesis entry was ever
     separately recorded there): CCU2C +278 (3719->3997), L6MUX21 +590
     (215->805), LUT4 +11027 (30286->41313), PFUMX +1715 (2716->4431),
     TRELLIS_FF +4137 (23437->27574), MULT18X18D +31 (13->44), PDPW16KD
     unchanged at 1 -- disclosed honestly as covering BOTH RTL-020's own
     and RTL-021's own real additions together, not RTL-021 alone, since
     no intermediate RTL-020-only checkpoint exists to isolate the split.
