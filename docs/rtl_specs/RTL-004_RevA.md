# RTL-004 Module Specification — Timestamp Engine

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, SRS-002, VP-002.

## 1. Identity and role

RTL-004 is the Dragon Core Timestamp Engine: the **sole producer of the
always-running 64-bit raw microsecond timestamp** (`timestamp_o`,
broadcast to every other module) and of an independently correlated
(host-offset) time value. Owns REG-002's Timestamp block (0x0200–0x02FF,
10 registers).

Controlling documents: `ARCH-002` SS8.2 (`ARCH-TIME-001`–`006`), Appendix
F.1 `ARCH-RTL004-001`, Appendix F.3 condition-mask index 3 (correlation
commit / arithmetic error / snapshot complete / event-slot overflow — "no
ordinary interrupt is generated" by RTL-004), `SRS-002` `DFC-PERF-0004`/
`0005` (64-bit non-wrap ≥500,000 years; coherent 64-bit snapshot), VP-002
`VP-MOD-004`/`VP-INF-005`/`VP-INF-006`.

## 2. Ports

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[3]`), `control_i`/`status_o`, `evt_valid_o`/
`evt_ready_i`/`evt_record_o` (source index 3), `operating_state_i`,
`observational_mode_i`, condition-enable pair (index 3).
RTL-004-specific: **`timestamp_o`** (`logic [63:0]`, the sole raw-time
broadcast every other module's `timestamp_i` consumes — RTL-004 does not
consume its own output; it is the origin).

## 3. Timestamp and correlation contract (ARCH-002 SS8.2, `ARCH-TIME-001`–`006`)

- **`ARCH-TIME-001`**: raw timestamp and a 6-bit phase counter both reset
  to zero. The phase counter advances every valid CORE_CLK edge after
  release; it produces a tick when its *prior* value was 49, and that same
  edge resets phase to zero and increments raw timestamp.
- **`ARCH-TIME-002`**: the **first tick is the 50th valid rising edge**
  after synchronized release; subsequent ticks occur every 50 edges. Raw
  time **never stops**; the legacy enable control reads constant one
  (`DFC-CONF-0034` — software has no means to stop it).
- **`ARCH-TIME-003`** (SNAPSHOT): captures raw timestamp, correlated
  timestamp, correlation-valid, and update sequence from **one
  pre-increment hardware instant**. If SNAPSHOT and a tick coincide, the
  snapshot contains the value *before* that tick.
- **`ARCH-TIME-004`** (COMMIT): validates and atomically copies the staged
  signed 64-bit two's-complement offset, increments the 16-bit wrapping
  update sequence, and sets correlation-valid. If SNAPSHOT and COMMIT
  coincide, **COMMIT occurs first** — the snapshot sees the newly
  committed offset.
- **`ARCH-TIME-005`**: correlated time = unsigned raw time + signed offset,
  modulo `2^64`, when enabled and valid; otherwise raw time. Signed
  overflow/underflow sets **sticky** correlation-error evidence; the
  arithmetic never mutates raw time itself.
- **`ARCH-TIME-006`** (priority, highest to lowest): **reset, module
  reset, COMMIT, SNAPSHOT, tick, clear evidence.** A new arithmetic error
  dominates a simultaneous clear of that evidence.

Per `ARCH-RTL004-001`: ready is high after release; fault is an illegal
command or a correlation arithmetic/control error.

## 4. Registers owned (REG-002 0x0200–0x02FF, 10 registers)

Raw timestamp readback (low/high), SNAPSHOT command + captured
raw/correlated/sequence readback, staged-offset write + COMMIT command,
correlation-valid/error status, and `RTL004_EVT_OVERFLOW_STATUS`. Exact
offsets/fields are REG-002's authority — do not repeat them here
(`CHTR-DOC-003`); implement against `dfc_registers_pkg.json`'s
RTL-004-owned entries directly.

## 5. Verification obligations

- **`VP-MOD-004`**: always-running time, divider phase, snapshot, signed
  correlation, overflow, sequence, reset, priority, ready, fault, event,
  and validation all satisfy `ARCH-RTL004-001` and `ARCH-VAL-004`.
- **`VP-INF-005`**: raw timestamp starts at reset value and advances
  continuously after qualified release; host control cannot stop it.
- **`VP-INF-006`**: phase/first-tick/subsequent-ticks/snapshot
  instant/signed-offset arithmetic/modulo result/update sequence/
  correlation validity/overflow evidence/simultaneous-command priority all
  match `ARCH-TIME-001`–`006` exactly — this is largely an arithmetic
  correctness case (`A-CALC` method), not just a state-machine one.

## 6. Note on downstream dependency

RTL-004 is a true leaf in the module dependency graph — it consumes no
other module's control/status and can be fully implemented and verified
today with zero dependency on RTL-002/003/005 existing. It is the
strongest early implementation candidate after RTL-001/024/SPI-bridge,
since `timestamp_i` on RTL-001's DRI-side ports already expects a real
source. Recommend implementing RTL-004 next.
