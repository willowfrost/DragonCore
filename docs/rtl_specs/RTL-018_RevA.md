# RTL-018 Module Specification — ARINC 429 Transmit Interface

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-018 owns the ARINC 429 transmit queue and dequeue/serialization
logic; RTL-018 itself performs the wire-level emission per `ARCH-BUS-002`
(unlike RX, where RTL-024 does the line-level work — TX is RTL-018's own
responsibility end-to-end). Owns REG-002's ARINC TX block (0x1100–0x11FF,
10 registers).

Controlling documents: `ARCH-002` SS11.4 `ARCH-BUS-002`, SS12.3
`ARCH-BUF-023` (entry layout), Appendix F.1 `ARCH-RTL018-001`, VP-002
`VP-MOD-018`/`VP-BUS-002`.

## 2. Ports (18 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`, `control_i`/
`status_o`, `timestamp_i`, `evt_valid_o`/`evt_ready_i`/`evt_record_o`
(source index 17), `irq_req_o` (RTL-003 index 4), `operating_state_i`,
`observational_mode_i`, `module_enable_i`, condition-enable pair.
RTL-018-specific: **`arinc_tx_ctrl_o[1:0]`** (the external speed-control
pad, `01` low-speed active, `10` high-speed active, **`11` never
generated** — confirm against Appendix A's exact RTL-018 row for the
actual serialized-word output port name), shared-buffer client ports,
route-destination conversion ports (destination `0x00` per
`ARCH-MSG-001`).

## 3. Transmit contract (`ARCH-BUS-002`)

RTL-018: **dequeues in order**, emits **32 bits LSB-first**, **inserts or
validates odd parity as configured** (auto-parity vs. host-override, per
`REG-ENC-008`: override is legal only when `AUTO_PARITY=0` and
`override-valid=1`), **holds `00` for the configured interword gap** (4–255
bit times), and drives `01` low-speed or `10` high-speed active control;
**`11` is never generated** by this module under any condition.

## 4. Queue and shared-buffer contract

`ARCH-BUF-023` (entry layout, 2 words): **W0** transmit word; **W1** bit 0
high-speed, bit 1 auto-parity, bit 2 override-valid, bit 3 override parity
bit, bits 17:4 tag, bits 31:18 zero.

Per `ARCH-RTL018-001`: a host or route request is **validated then written
completely** to the `ARCH-BUF-004`-governed storage **before** TX tail
advances. **Host push has priority over route input only when both target
the last free slot** (i.e. when there's room for both, no priority
conflict exists at all — the priority rule is specifically a last-slot
tiebreaker); **the losing route remains backpressured**, not dropped. **TX
removes an entry only after complete serialization or an explicit
rejected result** — no partial-dequeue state.

## 5. Registers owned (REG-002 0x1100–0x11FF, 10 registers)

Enable/speed/gap/parity-override configuration, TX queue level, TX data +
PUSH command, underrun/rejection/adapter-error status, and
`RTL018_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-018-owned entries.

## 6. Verification obligations

- **`VP-MOD-018`**: validation, complete entry, **host/route priority**,
  timing/parity/serialization, dequeue, errors, evidence, reset, and
  validation satisfy `ARCH-RTL018-001`/`ARCH-VAL-018`.
- **`VP-BUS-002`**: speed, gap, parity controls, queue state, and
  serialization are all validated; completion, rejection, underrun,
  adapter, disabled, and shared-buffer evidence are exact and distinct.
- The **last-free-slot host-vs-route priority rule** (SS4 above) is
  narrower than "host always wins" — it only matters when exactly one
  slot remains and both sides want it. Test the non-conflicting case too
  (both fit) to confirm no unintended priority is applied when it
  shouldn't matter.
