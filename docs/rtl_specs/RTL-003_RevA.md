# RTL-003 Module Specification — Interrupt Controller

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006: no new
behavior). Cites ARCH-002, REG-002, VP-002 throughout.

## 1. Identity and role

RTL-003 is the Dragon Core Interrupt Controller: the **sole aggregator** of
32 fixed interrupt-source positions (24 assigned, 8 reserved, Appendix C.4)
into `host_irq_n_o`. It implements the RAW/LATCH/PENDING/ACKED state
machine (ARCH-002 SS8.1) per source bit and owns REG-002's Interrupt
Controller block (0x0100–0x01FF, 8 registers).

Controlling documents: `ARCH-002` SS8.1 (equations), Appendix C.4 (source
matrix), Appendix F.1 `ARCH-RTL003-001` (derivation contract), Appendix
F.3 (RTL-003's own condition-mask bit allocation: bit 0 illegal
reserved-source activity, bit 1 event-slot overflow — RTL-003 generates no
self-interrupt), REG-002 0x0100 block, VP-002 `VP-MOD-003`/`VP-INF-004`.

## 2. Ports (16 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[2]`), `control_i`/`status_o`, `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (RTL-003's own diagnostic event,
source index 2 into RTL-005), `operating_state_i`, `observational_mode_i`,
`event_condition_enable_i`/`irq_condition_enable_i` (Appendix F.3 index 2).
RTL-003-specific: **`irq_source_i[31:0]`** (the fixed Appendix C.4 matrix —
one dedicated producer port per assigned bit, tied inactive for reserved
bits 24–31), **`host_irq_n_o`** (the sole host-visible aggregate output,
Appendix A "RTL-024 - Dragon Core Top-Level Integration" consumer via
RTL-024's own port, ultimately the `host_irq_n_o` external pad).

## 3. Interrupt equations (ARCH-002 SS8.1 — the entire functional core)

For each source bit `i` (0–23 assigned, 24–31 reserved):

```
RAW[i]         = irq_source_i[i] | injected_i[i]
LATCH[i]_next  = RAW[i] | (LATCH[i] & !CLEAR[i])
PENDING[i]     = ENABLE[i] & LATCH[i]
ACKED[i]_next  = (ACKED[i] | ACK[i]) & !(CLEAR[i] & !RAW[i])

VECTOR_VALID   = |PENDING
VECTOR_SOURCE  = lowest-numbered set PENDING bit
host_irq_n     = !(GLOBAL_IRQ_ENABLE & VECTOR_VALID)
```

**New RAW dominates a simultaneous CLEAR** — a source reasserting in the
same cycle a host clear targets it is *not* cleared. **Reserved bits
24–31** have RAW/LATCH/PENDING/ACKED tied zero; a write selecting them is
rejected. `injected_i` is the production-test injection path
(`TEST_IRQ_INJECT`, REG-002 0x0610) — bounded, never a functional source.

Per `ARCH-RTL003-001`: reset clears all state; **clear dominates
acknowledgement for an inactive source** (i.e. if `CLEAR[i]` is accepted
while `RAW[i]` is already 0, any simultaneous `ACK[i]` does not "stick" —
`ACKED[i]_next`'s `!(CLEAR[i] & !RAW[i])` term forces it low that cycle).
**Ready** is high after vector initialization; **fault** is
reserved/internal illegal-state evidence only — RTL-003 has no other
fault source.

## 4. Registers owned (REG-002 0x0100–0x01FF, 8 registers)

Host-visible views of the per-source state above: raw status, latched
status, pending/vector status, enable mask, acknowledge command, clear
command, and injection control — plus `RTL003_EVT_OVERFLOW_STATUS`
(W1C/RO pair, same template as every other module's event-overflow
register, REG-002's uniform pattern). Exact offsets/field layouts are
REG-002's own authority; this spec does not repeat them (`CHTR-DOC-003`) —
implement directly against `dfc_registers_pkg.json`'s RTL-003-owned
entries.

## 5. Verification obligations

- **`VP-MOD-003`**: RAW, LATCH, PENDING, ACKED, cleared, enabled, vector,
  priority, aggregate IRQ, reserved-source, reset, and injection behavior
  satisfy `ARCH-RTL003-001` and `ARCH-VAL-003`.
- **`VP-INF-004`**: the equations above hold for every implemented source,
  every reserved source, and all simultaneous set/clear/ack combinations
  — not sampled, exercised exhaustively per source bit.

## 6. Known dependency gap

`irq_source_i[31:0]` has no real producers until RTL-002 and its 22
siblings exist. A first implementation can only be exercised with
injected/forced values on this port — log as an open item when
implementation begins, per the same disclosure pattern used in
`dfc_rtl001.sv`/`dfc_rtl024.sv`.
