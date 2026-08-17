# RTL-021 Module Specification — Databus Routing Engine

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, SRS-002, VP-002.

## 1. Identity and role

RTL-021 is the Dragon Core databus message router: **5 fixed canonical
sources**, **16 host-staged route entries**, per-destination filtering
and replication, into **5 fixed canonical destinations** — the central
hub every other Databus module's route ports ultimately connect through.
Owns REG-002's Databus Routing block (0x1400–0x14FF, 17 registers).

Controlling documents: `ARCH-002` SS11.1 (canonical record/endpoints),
SS11.2 (fixed 5×5 authorization matrix), SS11.3 `ARCH-ROUTE-001`–`008`,
SS12.3 `ARCH-BUF-027` (entry layout), Appendix F.1 `ARCH-RTL021-001`,
`SRS-002` `DFC-FUNC-0071`–`0083`, VP-002 `VP-MOD-021`/`VP-BUS-005`–`009`.

## 2. Ports (16 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`, `control_i`/
`status_o`, `timestamp_i`, `evt_valid_o`/`evt_ready_i`/`evt_record_o`
(source index 20), `irq_req_o` (RTL-003 index 7), `operating_state_i`,
`observational_mode_i`, condition-enable pair. RTL-021-specific: **5
source-side valid/ready/record ports** (`source_valid_i[4:0]`/
`source_ready_o[4:0]`/`source_record_i[4:0]`, one triple per canonical
source — RTL-017, RTL-019, RTL-020, RTL-001, RTL-022) and **5
destination-side ports** (`dest_valid_o[4:0]`/`dest_ready_i[4:0]`/
`dest_record_o[4:0]`) — confirm exact port names against Appendix A's
RTL-021 row; this spec summarizes the *count and role*, not the literal
signal names.

## 3. Canonical record and authorization (SS11.1/11.2)

Every canonical message is **exactly 192 bits** (Appendix B). Sources/
destinations are fixed IDs `0x00`–`0x04` (ARINC RX→TX, CAN RX→TX, UART
RX→TX, Host in→out, ULI in→out — note RTL-019 and RTL-020 are each their
own source *and* destination under the same module ID, a self-referential
routing case). Message types: `0x01` ARINC_WORD, `0x02` CAN_FRAME, `0x04`
UART_BYTE, `0x08` HOST_OPAQUE, `0x10` ULI_DIAGNOSTIC — all others
reserved. Payload length 0–8. Flags bit 0 parity/error, 1
framing/protocol, 2 remote frame, 3 extended ID, 4 injected, 5
truncated/lost, 6 timestamp-valid, 7 reserved zero. **Sequence wraps
modulo 16 per source.**

**Fixed 5×5 authorization matrix** (confirmed exact table):

| Source ↓ / Dest → | ARINC TX | CAN TX | UART TX | Host | ULI |
|---|---:|---:|---:|---:|---:|
| ARINC RX | 0 | 1 | 1 | 1 | 0 |
| CAN RX | 1 | 0 | 1 | 1 | 0 |
| UART RX | 1 | 1 | 0 | 1 | 0 |
| Host | 1 | 1 | 1 | 0 | 1 |
| ULI | 0 | 0 | 0 | 1 | 0 |

Note the **asymmetry**: ULI may send to Host but not vice versa in this
table's ULI row (ULI row is all-zero except Host); Host *can* reach ULI
(Host row has a 1 in the ULI column) — a route from Host to ULI is legal,
the reverse direction from this specific reading is not. Implement
exactly this matrix; do not assume symmetry.

## 4. Routing algorithm (`ARCH-ROUTE-001`–`008`)

- **`001`**: each source owns one ingress slot; source READY is high when
  empty and routing enabled; accepted messages are range-checked *before*
  the slot becomes valid.
- **`002`**: 16 route entries — enable, 8-bit source ID, 5-bit destination
  mask, 32-bit message-type mask, 32-bit metadata filter value/mask,
  `DROP_ON_FULL`.
- **`003`**: for an ingress record, every enabled matching route is
  evaluated **in entry order**. A destination copy is selected if source
  matches, type bit enabled, `(metadata & filter_mask) == (filter_value &
  filter_mask)`, and the fixed matrix authorizes the pair. **Duplicate
  selections of the same destination produce one copy** (not N copies for
  N matching routes to the same destination).
- **`004`**: destination queues are **independent 4-record queues**.
  `DROP_ON_FULL=0` → a full required destination **backpressures** the
  whole ingress record's completion. `DROP_ON_FULL=1` → that copy drops
  (saturating count + sticky evidence), **other copies proceed
  independently**.
- **`005`**: an ingress record releases only after **every** selected
  destination has accepted, dropped, or been found inapplicable. A
  blocked destination **never** prevents already-ready independent
  copies from committing — no head-of-line blocking across destinations.
- **`006`**: each destination chooses among eligible ingress records by
  **rotating round-robin**, advancing its pointer after a committed copy.
  **Filter mismatch is evidence only when an enabled route matched
  source/type but failed its nonzero filter** — a route that never
  matched source/type at all doesn't generate filter-mismatch evidence.
- **`007`** (commit validation codes): `00` none, `01` invalid entry, `02`
  invalid source, `03` zero/invalid destination mask, `04` unauthorized
  pair, `05` undefined type bit, `06` reserved flag/field, `07` duplicate
  conflict, `08` busy.
- **`008`** (runtime `LAST_ERROR`): `00` none, `10` malformed message,
  `11` no matching route, `12` filter mismatch, `13` destination
  full/drop, `14` shared-buffer error, `15` destination rejection. Note
  the two error-code spaces (`007` commit-time vs. `008` runtime) are
  **disjoint and not interchangeable** — a commit rejection and a runtime
  routing failure are reported through different fields with different
  legal values.

Per `ARCH-RTL021-001`: **commit replaces all 16 entries atomically**; an
in-flight record completes under the **configuration epoch captured at
ingress acceptance** — i.e. a route reconfiguration mid-flight does not
retroactively change how an already-accepted record gets routed.

## 5. Queue and shared-buffer contract

`ARCH-BUF-027` (ingress/destination entry, 6 words — the 192-bit
canonical record split across 6×32-bit words): W0 bits 31:0, W1 bits
63:32, W2 bits 95:64, W3 bits 127:96, W4 bits 159:128, W5 bits 191:160.

## 6. Registers owned (REG-002 0x1400–0x14FF, 17 registers)

Per-entry staged source/destination-mask/type-mask/filter/`DROP_ON_FULL`
configuration, `COMMIT` command, active-bank readback, `LAST_ERROR`,
per-destination queue status, and `RTL021_EVT_OVERFLOW_STATUS`. Implement
against `dfc_registers_pkg.json`'s RTL-021-owned entries.

## 7. Verification obligations

- **`VP-MOD-021`**: ingress/filter/replication/arbitration/backpressure
  per `ARCH-ROUTE-001`–`008` using `ARCH-BUF-009`/`010`'s generic queue
  discipline; commit atomicity and configuration-epoch handling satisfy
  `ARCH-RTL021-001`/`ARCH-VAL-021`.
- **`VP-BUS-006`**: every canonical field (source/destination/type/
  payload-length/flag/metadata/timestamp/reserved) accepts or rejects
  exactly per SS11.1.
- **`VP-BUS-007`**: **all 25 source/destination pairs** in the fixed 5×5
  matrix are exhaustively checked — legal pairs selectable, prohibited
  pairs never activatable. 25 is a small enough space to genuinely
  exhaust, not sample.
- **`VP-BUS-008`**: every routing-entry validation field, with the exact
  first-error code from the `007` list.
- **`VP-BUS-009`**: commit atomically replaces all active entries; an
  in-flight record completes under its captured configuration epoch — the
  epoch-capture behavior (SS4 above) needs a dedicated
  "reconfigure-mid-flight" test, since it's the one place a naive
  implementation might accidentally apply the *new* configuration to an
  already-in-progress record.
