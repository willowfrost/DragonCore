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

## Toolchain findings

12. **A real, transient `nextpnr-ecp5` internal router assertion crash was
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
