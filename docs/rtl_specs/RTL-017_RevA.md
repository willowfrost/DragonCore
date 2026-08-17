# RTL-017 Module Specification — ARINC 429 Receive Interface

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-017 owns the ARINC 429 receive queue and shared-buffer client state;
the actual bit-timing recovery and framing happen in **RTL-024's digital
receive adapter** (`ARCH-BUS-001`) — RTL-017 consumes already-assembled
32-bit words plus metadata, not raw line signal. Owns REG-002's ARINC RX
block (0x1000–0x10FF, 12 registers).

Controlling documents: `ARCH-002` SS11.4 `ARCH-BUS-001`, SS12.3
`ARCH-BUF-022` (entry layout), Appendix F.1 `ARCH-RTL017-001`, VP-002
`VP-MOD-017`/`VP-BUS-001`.

## 2. Ports (20 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`, `control_i`/
`status_o`, `timestamp_i`, `evt_valid_o`/`evt_ready_i`/`evt_record_o`
(source index 16), `irq_req_o` (RTL-003 index 3), `operating_state_i`,
`observational_mode_i`, `module_enable_i` (optional-mask), condition-enable
pair. RTL-017-specific: **the already-assembled word/metadata transfer
from RTL-024's digital receive adapter** (`ARCH-BUS-001` — confirm exact
port names against Appendix A's RTL-017 row rather than assuming a raw
line-level port exists on RTL-017 itself), shared-buffer client
request/response ports (`ARCH-CONN-010`), route-source conversion ports
into RTL-021 (message source `0x00` per `ARCH-MSG-001`).

## 3. Receive adapter contract (`ARCH-BUS-001`, owned by RTL-024, consumed here)

RTL-024's adapter: oversamples the conditioned input in CORE_CLK,
recognizes configured **12–14.5 kb/s (low speed) or 100 kb/s (high
speed)** timing, requires **at least 4 bit times of null** between words,
assembles **32 bits LSB-first as transmitted by ARINC**, evaluates **odd
parity**, and presents **one atomic word/metadata transfer** to RTL-017.
RTL-017's own responsibility begins at that atomic transfer — queue
management, not signal recovery.

## 4. Queue and shared-buffer contract

`ARCH-BUF-022` (entry layout, 4 words): **W0** received word; **W1** bit 0
parity-ok, bit 1 framing-ok, bit 2 high-speed, bit 3 adapter-error, bits
15:4 error code, bits 31:16 sequence; **W2** raw timestamp low; **W3** raw
timestamp high. Error codes per `REG-ENC-008`: 0 none, 1 parity, 2
framing/gap, 3 RX overrun, 4 TX underrun (TX-side code, listed here for
completeness since RTL-018 shares the same code space), 5 adapter, 6
disabled, 7 invalid configuration, 8 shared-buffer.

Per `ARCH-RTL017-001`: an accepted adapter word is **written completely**
to the `ARCH-BUF-003`-governed storage **before** RX tail/valid advances
(no partial-entry visibility). A full queue **rejects and counts
overrun**. POP reads the **oldest complete entry** before advancing head.
**Route-source transfer and host POP independently reference the same
head, and only one removal may commit per cycle** — this is a genuine
arbitration point: two consumers (the host via register POP, and RTL-021
via route-source conversion) contend for the same queue head, and exactly
one wins per cycle.

## 5. Registers owned (REG-002 0x1000–0x10FF, 12 registers)

Enable/speed/parity configuration, RX queue level, RX data + POP command,
error count, adapter-error status, and `RTL017_EVT_OVERFLOW_STATUS`.
Implement against `dfc_registers_pkg.json`'s RTL-017-owned entries.

## 6. Verification obligations

- **`VP-MOD-017`**: protocol intake, complete shared-buffer entry,
  queue/full/pop ordering, timestamp/metadata, **host/route removal
  arbitration**, evidence, reset, and validation satisfy
  `ARCH-RTL017-001`/`ARCH-VAL-017`.
- **`VP-BUS-001`**: every legal speed/word/parity form is accepted with
  exact metadata/timestamp/sequence; parity, gap/framing, adapter,
  disabled, overflow, and shared-buffer errors are all reported
  distinctly — not collapsed into one generic RX-error bit.
- The host-vs-route POP arbitration (SS4 above) deserves a dedicated
  simultaneous-access test: drive both consumers to contend for the same
  head entry in the same cycle and confirm exactly one commits, the other
  correctly stalls/retries, and no entry is silently duplicated or lost.
