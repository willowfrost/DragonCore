---
name: impl-module
description: Use when implementing, extending, or reviewing RTL-001 through RTL-024 SystemVerilog source in this repository. Encodes RCA-DFC-RTL-STD-002's mandatory rules so module code conforms without re-deriving them from the standard each time.
---

# Implementing a Dragon Core RTL module

This skill exists so implementation work follows `RCA-DFC-RTL-STD-002` (the
sole owner of coding conventions, structural rules, and RTL conformance
requirements) without re-reading all 31 sections every time. It summarizes;
**RTL-STD-002 is still the normative source** — cite its rule IDs in module
headers and comments, don't restate their text.

## Before writing anything

1. Confirm the module's controlling spec exists under `docs/rtl_specs/`. If
   it doesn't, that's a gap to raise, not license to invent behavior
   (CHTR-DOC-006).
2. Confirm `include/dfc_*_pkg.sv` is current for this module — check the
   module's control/status struct in `dfc_types_pkg` (ARCH-002 Appendix B)
   and its owned registers in `dfc_registers_pkg` (REG-002). If either looks
   stale, regenerate (see `CLAUDE.md`) before writing RTL against it.

## Structural rules (RTL-STD-002 SS6-8)

- One primary synthesizable module per file; filename matches module name
  (`RTLSTD-ORG-001`).
- Module header identifies: module name, purpose, controlling module spec,
  clocks, resets, formal interfaces, register ownership (`RTLSTD-MOD-001`).
- Ports grouped: clocks, resets, control, configuration, status, functional
  in, functional out, evidence, bounded test hooks (`RTLSTD-MOD-002`).
  Every port has explicit direction, type, packed width (`RTLSTD-MOD-003`),
  and must match the Architecture formal port catalog exactly — name,
  direction, width, type, producer/consumer, CDC/RDC treatment
  (`RTLSTD-MOD-004`).
- Every state-holding object has exactly one procedural owner
  (`RTLSTD-MOD-007`). No technology primitives, pad cells, memory macros,
  clock cells, or vendor primitives in technology-independent modules
  (`RTLSTD-MOD-008`).
- Naming (RTL-STD-002 SS8, table is normative):

  | Object | Convention | Example |
  |---|---|---|
  | Module | `dfc_` prefix, snake_case | `dfc_timestamp_engine` |
  | Package | `dfc_..._pkg` | `dfc_types_pkg` |
  | Parameter/localparam | UPPER_SNAKE | `FIFO_DEPTH` |
  | Signal | snake_case | `event_pending` |
  | Active-low | `_n` suffix | `core_rst_n` |
  | Registered state | `_q` suffix | `state_q` |
  | Next state | `_d` suffix | `state_d` |
  | Port | `_i` / `_o` suffix | `evt_valid_o` |
  | Enum type | `_e` suffix | `dri_state_e` |
  | Packed struct type | `_t` suffix | `dfc_event_record_t` |

  No `temp`, `data1`, `flag`, `misc`, `spare`, `future` outside a small
  obvious local scope (`RTLSTD-NAME-003`). Generated register/field names
  must match REG-002 exactly (`RTLSTD-NAME-001`) — never hand-alias them.

## Clock and reset (RTL-STD-002 SS9-10)

- Use only the Architecture-assigned clock; no RTL-generated clocks, no
  combinational clock gating (`RTLSTD-CLK-001/002`). A data signal is never
  a clock (`RTLSTD-CLK-007`).
- Reset assertion/release must implement the *exact* Architecture contract
  for the receiving domain — don't generalize a specific exception into a
  generic "synchronized per domain" pattern (`RTLSTD-RST-001/002`).
- Unqualified reset release is never data, an enable, or a transaction
  indicator (`RTLSTD-RST-003`).
- Every state-holding object resets to the value the Register Map,
  Architecture, or module spec defines (`RTLSTD-RST-005`) — imported from
  generated definitions, never hand-copied (`RTLSTD-RST-009`).
- Reset must not fabricate a transaction, response, interrupt, event,
  fault, route, or output activation (`RTLSTD-RST-008`).

## CDC/RDC (RTL-STD-002 SS11)

- Every clock/async boundary must match an Architecture CDC/RDC inventory
  entry (`RTLSTD-CDC-001`). No combinational paths across clock domains,
  ever (`RTLSTD-CDC-007`).
- A stable single-bit level uses the Architecture synchronizer structure;
  never consume the first synchronizer stage in functional logic
  (`RTLSTD-CDC-002`). A pulse crosses domains only via handshake, toggle,
  counter, or pulse-stretch guaranteeing capture at all permitted clock
  ratios (`RTLSTD-CDC-003`).
- Asynchronous external inputs are synchronized and qualified *before* use
  by counters, FSMs, event/interrupt logic, routing, or safety logic
  (`RTLSTD-CDC-008`) — never used directly in arithmetic, state transitions,
  or safety decisions (`RTLSTD-CDC-011`).

## Register-contract implementation (RTL-STD-002 SS14)

- RTL-001 is the sole host-visible DRI register endpoint; other modules get
  decoded controls and return typed status via Architecture-defined
  interfaces (`RTLSTD-REG-001`) — never decode register addresses locally.
- Decode, field extraction, access enforcement, reset values, and masks
  come from generated definitions (`dfc_registers_pkg`), never hand-derived
  (`RTLSTD-REG-002`, `RTLSTD-REG-013`).
- Read-to-clear is prohibited unless REG-002 explicitly defines that access
  class for the field (`RTLSTD-REG-004`).
- A command write (`WO-CMD`) produces exactly one bounded action, never a
  repeated action while a request/response stalls (`RTLSTD-REG-009`).
- Sticky evidence (`W1C`) implements the Register Map's specified
  simultaneous set/clear priority — new hardware assertion dominates a
  simultaneous host clear wherever REG-002 specifies set-dominates-clear
  (`RTLSTD-REG-008`, `RTLSTD-REG-017`).
- A whole-value saturating-counter clear (`COUNTER-CLR`) decodes an accepted
  all-ones write into one one-cycle clear pulse, an all-zero write as
  no-effect, and rejects every other value with an access error
  (`RTLSTD-REG-016`) — never implement it as a 32-bit bitwise clear mask.

## DRI interface discipline (RTL-STD-002 SS13)

- Request fields stay stable while a valid request awaits acceptance
  (`RTLSTD-DRI-002`); response fields stay stable while a valid response
  awaits acceptance (`RTLSTD-DRI-005`). Never exceed the Architecture's
  outstanding-operation limit (`RTLSTD-DRI-003`).
- Exactly one response per accepted request, unless reset or an
  Architecture-defined abort invalidates the transaction (`RTLSTD-DRI-004`).
- Decode/alignment/access/protection/endpoint/timeout errors never modify
  target or unrelated state (`RTLSTD-DRI-007`).
- DRI acceptance is the single CORE_CLK edge where VALID and READY are both
  asserted; decode, first-error selection, timeout age, and side-effect
  eligibility all derive from that one accepted-request object
  (`RTLSTD-DRI-011`).

## Before calling a module "done"

Check it against `RTL-STD-002` SS29-31 (assertions/formal hooks, static
conformance, mandatory source-conformance requirements) and confirm every
functional claim in its spec traces to an ARCH-002/REG-002/SRS-002
identifier via RTM-002. If something doesn't trace, that's an open item,
not a judgment call to make silently — log it in `OPEN_ISSUES.md`.
