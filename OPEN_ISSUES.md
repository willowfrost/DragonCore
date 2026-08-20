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

2. **`dfc_rtl003_control_t` (ARCH-002 Appendix B, 128 bits, exactly 4
   fields: `irq_enable__enable`, `irq_ack__ack_set`, `irq_clear__clear`,
   `test_irq_inject__source_mask`) has no field for clearing
   `RTL003_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW`** (REG-011C, a real W1C bit
   per REG-002's own access-class table). The struct's own extractor
   confirms its 4 fields tile the full 128 bits with nothing left over, so
   there is no unused bit position to repurpose without ARCH-002 itself
   growing this struct -- not something RTL-003's own implementation or
   `tools/reggen/rtl003_field_map.json` can invent (CHTR-DOC-006). This
   mirrors a **pre-existing, identical gap already present for RTL-002**
   (`RTL002_EVT_OVERFLOW_STATUS` at 0x0044 is likewise absent from
   `rtl002_field_map.json`'s `control_registers`, for the same reason:
   `dfc_rtl002_control_t` has no such field either). Both registers
   currently have `write_illegal_o = 1'b1` (no real write path exists),
   which is honest given the constraint, but means the host genuinely cannot
   clear either module's event-overflow evidence via the register interface
   today. A real fix requires ARCH-002 to grow both control structs by (at
   least) one bit each.

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

5. **`dfc_rtl002.sv`, as already delivered before this session, does not
   expose several ports ARCH-002's own formal port catalog lists for
   RTL-002**: `global_irq_enable_o`, `global_event_enable_o`,
   `event_condition_enable_i`, `irq_condition_enable_i`. This is a
   pre-existing gap independent of RTL-003, but RTL-003's integration
   exposed it concretely: `dfc_rtl024.sv` cannot connect
   `RTL-003.global_irq_enable_i` to a real `RTL-002.global_irq_enable_o` port
   because that port does not exist. Worked around (not fixed) by reading
   the underlying `SYS_CONTROL.GLOBAL_IRQ_ENABLE` bit directly off
   `rtl002_control` (the real net RTL-001 already drives into RTL-002,
   owned by `dfc_rtl024.sv` itself) -- this is real, live, host-writable
   data, not a stub, but it bypasses the port RTL-002 should have had. A
   real fix means adding these 4 ports to `dfc_rtl002.sv` directly.

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

## Toolchain findings

7. **A real, transient `nextpnr-ecp5` internal router assertion crash was
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
