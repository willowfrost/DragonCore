# RTL-019 Module Specification — Classical CAN Interface

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, SRS-002, VP-002.

## 1. Identity and role

RTL-019 is a complete Classical CAN 2.0A/B controller: bit stuffing,
arbitration, ACK, CRC-15, error frames, TEC/REC counters,
error-active/passive/bus-off state machine, plus independent RX/TX
queues and shared-buffer client state. This is the most protocol-complex
single module in the Databus domain — unlike ARINC/UART, CAN's error
confinement state machine has no simpler analog elsewhere in this
project. Owns REG-002's CAN block (0x1200–0x12FF, 21 registers — the
largest Databus register footprint).

Controlling documents: `ARCH-002` SS11.4 `ARCH-BUS-003`, SS12.3
`ARCH-BUF-024` (entry layout), Appendix F.1 `ARCH-RTL019-001`,
`SRS-002` `DFC-FUNC-0061`–`0066`, VP-002 `VP-MOD-019`/`VP-BUS-003`.

## 2. Ports (19 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`, `control_i`/
`status_o`, `timestamp_i`, `evt_valid_o`/`evt_ready_i`/`evt_record_o`
(source index 18), `irq_req_o` (RTL-003 index 5), `operating_state_i`,
`observational_mode_i`, `module_enable_i`, condition-enable pair.
RTL-019-specific: **`can_rx_i`**/**`can_tx_o`** (synchronized external
pins), **`can_transceiver_error_i`** (`CDC-CANERR`-synchronized), shared-
buffer client ports, route source/destination ports (`ARCH-MSG-002`, CAN
RX and CAN TX are the *same* module ID `0x01` for both source and
destination — confirm this self-referential routing case is handled
correctly, not assumed impossible).

## 3. Protocol contract (`ARCH-BUS-003`)

RTL-019 implements: **Classical CAN base/extended data and remote
frames**, **bit stuffing**, **arbitration**, **ACK**, **CRC-15**, **error
frames**, **TEC/REC** (transmit/receive error counters), **error-active/
passive** states, and **bus-off**. **Loopback disconnects external TX**
(internal echo only); **listen-only never drives dominant** (pure
observation, no ACK either — confirm this against `REG-ENC-006`'s
`LOOPBACK`/`LISTEN_ONLY=11` illegal-combination rule, since loopback and
listen-only are independently configurable but that specific combined
encoding is rejected). **Recovery requires host command or 128
occurrences of 11 consecutive recessive bits** as configured — this is
the standard CAN bus-off recovery sequence count, not an arbitrary value;
implement the counter exactly, not approximately.

Per `REG-ENC-006`: DLC is 0–8; standard (11-bit) IDs have bits 28:11
zero; RTR (remote) frames carry zero data words regardless of DLC.

Per `DFC-FUNC-0066`: **transmission remains inhibited in bus-off until a
host-commanded or configured standards-conforming recovery completes** —
this is not optional/best-effort; bus-off must be a hard TX inhibit.

## 4. Queue and shared-buffer contract

`ARCH-BUF-024` (entry layout, 6 words — the largest single-entry layout
in the Databus domain): **W0** bits 28:0 identifier, bit 29 IDE, bit 30
RTR, bit 31 valid; **W1** data bytes 0–3; **W2** data bytes 4–7; **W3** raw
timestamp low; **W4** raw timestamp high; **W5** bits 3:0 DLC, bits 15:4
flags, bits 31:16 sequence.

Per `ARCH-RTL019-001`: RX and TX queues use the generic
`ARCH-BUF-005`/`006` push/pop discipline (Appendix F.2's common queue
table). Protocol state **writes complete frames before valid** — a
frame's queue entry is not marked valid until every field (including the
CRC check result) is settled. **Host TX push has priority over route
input for the last slot** (same last-slot-only tiebreaker pattern as
RTL-018). **Bus-off forces recessive output and blocks dequeue until
recovery.** **Natural protocol error dominates a host error-clear
attempt** — same active-dominates-clear discipline seen throughout the
Safety domain, applied here to protocol errors specifically.

## 5. Registers owned (REG-002 0x1200–0x12FF, 21 registers)

Enable/mode(loopback/listen-only)/bit-timing configuration, RX/TX
queue level/data/push/pop, TEC/REC readback, error-active/passive/bus-off
status, `CAN_RECOVERY` (confirmed real register at `0x1250`, WO-CMD,
protected, "requests manual bus-off recovery after the Architecture-
defined recessive-bus observation requirement is satisfied" — note this
means the command can still be *rejected* if the 128-recessive-bit
observation hasn't actually completed, not an unconditional override),
error count, and `RTL019_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-019-owned entries.

## 6. Verification obligations

- **`VP-MOD-019`**: RX/TX queue discipline, complete-frame-before-valid,
  host/route priority, bus-off force/block, natural-error-dominates-clear,
  reset, ready, fault, and validation satisfy `ARCH-RTL019-001`/
  `ARCH-VAL-019`.
- **`VP-BUS-003`**: standard/extended IDs, DLC, RTR, data, bit timing,
  arbitration, stuffing, errors, error confinement, listen-only, loopback,
  bus-off, and recovery all match SS11.4 exactly. Given this is the most
  protocol-complex module in the domain, this case realistically needs a
  dedicated CAN protocol-conformance test suite (arbitration-loss
  scenarios, stuffing-bit edge cases at exactly 5 consecutive identical
  bits, bus-off entry at exactly TEC/REC thresholds, the 128-recessive-bit
  recovery count exactly), not a handful of representative frames.
