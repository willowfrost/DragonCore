# RTL-005 Module Specification — Event Logger

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-005 is the Dragon Core Event Logger: the **sole arbiter and store**
for all 24 producers' diagnostic event records. It implements per-producer
pending-slot arbitration (one record per producer, rotating round-robin
service) into a **64-entry, 128-bit-per-record event store** — architecturally
the sole exception to the centralized shared-buffer service
(`ARCH-EVT-004`). Owns REG-002's Event Logger block (0x0300–0x03FF, 14
registers).

Controlling documents: `ARCH-002` SS8.3 (`ARCH-EVT-001`–`008`), Appendix
F.1 `ARCH-RTL005-001`, Appendix F.3 index 4 (event-related condition-mask
bits, note the store-overflow/source-overflow priority split), VP-002
`VP-MOD-005`/`VP-INF-007`–`012`.

## 2. Ports

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[4]`), `control_i`/`status_o`, `timestamp_i`,
`operating_state_i`, `observational_mode_i`, `global_event_enable_i`
(`RTL-002.global_event_enable_o` — gates *normal* event acceptance;
safety-mandatory and `0x007E`/`0x007F` overflow events bypass this gate
entirely per Appendix F.3), condition-enable pair (index 4).
RTL-005-specific (the module's actual functional interface):
**`evt_valid_i[23:0]`/`evt_ready_o[23:0]`/`evt_record_i[23:0]`** — 24
independent valid/ready channels, one per producer (`ARCH-CONN-006`), each
carrying `dfc_event_record_t` (128 bits, Appendix B). **`irq_req_o`** —
RTL-005's own diagnostic interrupt (source index 1 into RTL-003).

## 3. Arbitration and store contract (ARCH-002 SS8.3)

- **`ARCH-EVT-001`**: each of 24 producers owns **one pending record
  slot**. An arriving enabled record enters an empty slot; an arrival to
  an *occupied* slot increments that source's saturating loss counter,
  sets its overflow evidence, and schedules diagnostic event `0x007E`
  (producer-slot overflow).
- **`ARCH-EVT-002`** (service priority, highest to lowest): **event-store
  overflow `0x007F`, then source overflow `0x007E`, then ordinary
  producers by rotating round-robin** starting after the last accepted
  ordinary source. **At most one record is stored per CORE_CLK.**
- **`ARCH-EVT-003`**: multiple losses of the *same* overflow class coalesce
  while its report is pending, but counts include every loss. `0x007F` has
  priority over `0x007E`.
- **`ARCH-EVT-004`**: the event store is **four `64×32` register arrays**
  forming 64 atomic 128-bit records — a deliberate, disclosed architectural
  exception to the shared-buffer service (`VP-INF-012` verifies this
  exception is actually implemented this way, not aliased).
- **`ARCH-EVT-005`**: push to a non-full store appends at tail; POP removes
  the oldest; **push-only while full overwrites the oldest**, advances
  head and tail together, keeps level at 64, sets overflow, increments the
  store-overflow counter, and schedules `0x007F`.
- **`ARCH-EVT-006`**: simultaneous push+POP on a non-empty store removes
  the old head **and** appends the new record with level **unchanged**.
  POP on empty is rejected and sets pop-error. `CLEAR_ALL` has priority
  over POP and ordinary push.
- **`ARCH-EVT-007`**: an internally generated `0x007E`/`0x007F` record
  **never** recursively increments a source/store overflow counter or
  schedules another overflow record solely because the diagnostic record
  itself meets full storage — storing one while full uses a coincident
  internal pop+push, not a recursive overflow path.
- **`ARCH-EVT-008`** (`CAPTURE_OLDEST`): atomically snapshots the oldest
  complete record **without removal**. If CAPTURE, POP, and push coincide:
  CLEAR_ALL first; otherwise snapshot old head, then POP, then push.

Per `ARCH-RTL005-001`: ready is high after pointers and pending slots
clear; fault is retained internal-storage/control error or a configured
event-overflow fault condition.

Common queue table (Appendix F.2) governs ordinary push/pop simultaneity
everywhere *except* the store-overwrite exception above, which
`ARCH-EVT-005`–`007` alone govern (`REG-COH-006`).

## 4. Registers owned (REG-002 0x0300–0x03FF, 14 registers)

Store status/level, `CAPTURE_OLDEST`/POP/`CLEAR_ALL` commands, snapshot
readback (record fields per `dfc_event_record_t`), per-producer drop-source
readback, event-store and producer-overflow counters, and
`RTL005_EVT_OVERFLOW_STATUS`. Offsets/fields are REG-002's authority —
implement against `dfc_registers_pkg.json` directly.

## 5. Verification obligations

- **`VP-MOD-005`**: producer arbitration, atomic records, register-array
  store, overwrite, snapshot, pop, clear, diagnostic-overflow
  priority/coalescing/nonrecursion, reset, ready, fault, and validation
  satisfy `ARCH-RTL005-001` and `ARCH-VAL-005`.
- **`VP-INF-007`**–`011`: each producer's pending-slot conservation,
  arbitration fairness/priority, store push/pop/snapshot/clear exact
  matching of `ARCH-EVT-004`–`008`, overflow scheduling/priority/coalescing
  matching `ARCH-EVT-001`–`003`, and the nonrecursion guarantee
  (`ARCH-EVT-007`) each get their own dedicated case — this module's
  overflow-handling correctness is verification-heavy relative to its
  port count.
- **`VP-INF-012`**: the register-array store is confirmed as the
  architectural exception it claims to be, not accidentally implemented
  as (or aliased to) shared-buffer storage.

## 6. Known dependency gap

All 24 `evt_valid_i`/`evt_record_i` channels need real producers to
exercise arbitration fairness meaningfully; with only RTL-001 real today,
a first implementation is testable for its store/overflow/snapshot
mechanics using injected records, but not for true 24-way arbitration
fairness until more producers exist. Disclose this the same way as
RTL-001/024's own stub gaps.
