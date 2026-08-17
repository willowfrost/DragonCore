# RTL-020 Module Specification — UART Interface

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-020 is a complete full-duplex UART: baud generation, framing,
parity, 16-byte RX/TX queues, and persistent error evidence. Owns
REG-002's UART block (0x1300–0x13FF, 11 registers, all offsets
confirmed).

Controlling documents: `ARCH-002` SS11.4 `ARCH-BUS-004`, SS12.3
`ARCH-BUF-025`/`026` (entry layouts), Appendix F.1 `ARCH-RTL020-001`,
VP-002 `VP-MOD-020`/`VP-BUS-004`.

## 2. Ports (17 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`, `control_i`/
`status_o`, `timestamp_i`, `evt_valid_o`/`evt_ready_i`/`evt_record_o`
(source index 19), `irq_req_o` (RTL-003 index 6), `operating_state_i`,
`observational_mode_i`, `module_enable_i`, condition-enable pair.
RTL-020-specific: **`uart_rx_i`**/**`uart_tx_o`** (synchronized external
pins), shared-buffer client ports, route source/destination ports
(`ARCH-MSG-003`, UART RX and UART TX share module ID `0x02`, same
self-referential pattern as RTL-019's CAN).

## 3. Baud, framing, and error contract

**`ARCH-BUS-004`**: full-duplex, independent RX/TX. **`REG-ENC-007`**
(the exact, confirmed formula): `UART_BAUD_DIV.DIVISOR = round(50,000,000
/ baud)`, **legal range 50–50,000**, **reset 434** (≈115,200 baud,
computed as `50,000,000/434 ≈ 115,207`). **Parity: 0 none, 1 even, 2 odd;
3 is reserved.** RX error flags occupy **bits 0–4**: framing, parity,
overrun, break, shared-buffer error; **bits 5–7 are zero** (not
reserved-in-the-usual-sense — architecturally fixed at zero, never
assigned to a future error type without a spec revision).

Per `ARCH-RTL020-001`: a received byte plus flags becomes valid
**atomically** after stop-bit evaluation — no byte is visible before its
complete frame (including stop bit) has been checked. **Host TX push has
priority over route input for the last slot** (same last-slot-only
tiebreaker as RTL-018/019). **Disable completes the current transmitted
character then idles high**; **reset aborts immediately** — this is a
real behavioral difference between disable and reset that's easy to
conflate: disable is graceful (finish the in-flight byte), reset is not.

## 4. Queue and shared-buffer contract

`ARCH-BUF-025` (RX entry, 1 word): bits 7:0 data, bits 15:8 error flags,
bits 31:16 sequence. `ARCH-BUF-026` (TX entry, 1 word): bits 7:0 data,
bits 31:8 zero. Both are the simplest entry layouts in the Databus
domain — a useful implementation-order signal: RTL-020's queue mechanics
are the least complex to get right, making it a reasonable
starting point within this domain if implementation order is otherwise
open.

## 5. Registers owned (REG-002 0x1300–0x13FF, 11 registers, confirmed)

`UART_CONTROL` (0x1300, protected for format while enabled),
`UART_STATUS` (0x1304), `UART_BAUD_DIV` (0x1308), `UART_RX_LEVEL` (0x130C),
`UART_RX_DATA` (0x1310), `UART_RX_POP` (0x1314), `UART_TX_LEVEL` (0x1318),
`UART_TX_DATA` (0x131C), `UART_TX_PUSH` (0x1320), `UART_ERROR_COUNT`
(0x1324), `RTL020_EVT_OVERFLOW_STATUS` (0x1328). Implement against
`dfc_registers_pkg.json`'s RTL-020-owned entries — these offsets are
already confirmed exactly, no ambiguity to resolve.

## 6. Verification obligations

- **`VP-MOD-020`**: RX/TX byte-valid atomicity, host/route priority,
  disable-vs-reset distinction, reset, ready, fault, and validation
  satisfy `ARCH-RTL020-001`/`ARCH-VAL-020`.
- **`VP-BUS-004`**: divisor, baud, parity, stop bits, RX/TX framing,
  break, overrun, underflow, **disable completion**, and **reset abort**
  match SS11.4 and REG-002 encodings exactly — the disable-completes/
  reset-aborts distinction (SS3 above) should be its own explicit test
  case, not incidental coverage from a generic reset test.
