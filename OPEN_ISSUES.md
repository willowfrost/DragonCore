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
