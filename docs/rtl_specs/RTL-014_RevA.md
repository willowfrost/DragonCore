# RTL-014 Module Specification — Interlock Engine

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, VP-002.

## 1. Identity and role

RTL-014 evaluates **8 independent four-term boolean expressions**,
atomically committed as a whole bank, producing per-expression violation
evidence and guarded-action permission signals, and requesting **lane 2**
of the safety-response matrix on violation. Owns REG-002's Interlock block
(0x3200–0x32FF, 10 registers).

Controlling documents: `ARCH-002` SS10.3 `ARCH-SAFE-006`, Appendix F.1
`ARCH-RTL014-001`, Appendix C.8 (lane 2, source IDs 0–7, authorization
bits 16–23), VP-002 `VP-MOD-014`/`VP-SAFE-006`/`VP-SAFE-007`.

## 2. Ports (19 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[13]`), `control_i`/`status_o`, `timestamp_i`,
`evt_valid_o`/`evt_ready_i`/`evt_record_o` (source index 13),
`operating_state_i`, `observational_mode_i`, condition-enable pair.
RTL-014-specific: **`response_req_o`** (lane 2, 8 possible source IDs
0–7 — one per expression). The four **term inputs** each expression
evaluates are not a dedicated external port group of RTL-014's own; per
`ARCH-002`'s user-logic feedback note (Appendix C.3, "38–255
Illegal/reserved... user-logic feedback into safety interlocks"), terms
are drawn from the broader condition-signal fabric (GPIO, sensor,
health, etc.) — confirm the exact term-source wiring against Appendix A's
full RTL-014 port rows before implementation; this spec does not invent
that wiring.

## 3. Expression, commit, and violation contract (`ARCH-SAFE-006`)

- **Eight expressions**, each using **four terms**, each term
  independently invertible, combined by exactly one of: **AND, OR, 3-of-4,
  or `(t0&t1)|(t2&t3)`** — four legal operators, no others.
- **`COMMIT_ALL`** validates **all** terms, operators, guards, response
  masks, and reserved bits, checked **in entry order then field order**;
  **the first error rejects the entire bank** — a single bad field in
  entry 7 rejects entries 0–6 too, even if they were individually legal.
  This is whole-bank atomicity, not per-entry.
- **Violation** = `enabled & !expression` — an expression that evaluates
  false while its entry is enabled.
- **`ARCH-RTL014-001`**: reset clears all active expressions to
  **disabled**. `COMMIT` validates then **atomically replaces all eight
  entries** before the next evaluation; a violation on the *newly
  committed* bank **may assert on that very next edge** — there is no
  grace period after commit.
- **Guard permission changes inactive in the same edge that violation
  qualifies** (`ARCH-SAFE-006`'s final clause) — i.e. when a violation
  becomes qualified, the corresponding guarded-action permission signal
  drops in that *same* cycle, not the next one. `VP-SAFE-007` specifically
  calls this the **"no prohibited one-cycle output window"** requirement
  — a one-cycle delay here would itself be a defect, not just slow
  response.

## 4. Registers owned (REG-002 0x3200–0x32FF, 10 registers)

Per-entry term/operator/inversion/guard/response-mask staging registers,
`COMMIT_ALL` command, active-bank readback, violation status, and
`RTL014_EVT_OVERFLOW_STATUS`. Per `REG-ENC-018`/`REG-COH-002`-style
staging: staged fields are independently writable; nothing takes effect
until `COMMIT_ALL` succeeds. Implement against
`dfc_registers_pkg.json`'s RTL-014-owned entries.

## 5. Verification obligations

- **`VP-MOD-014`**: all operators/terms/inversions/guards, whole-bank
  validation/commit, first error, evaluation timing, response sources,
  evidence, reset, ready, fault, and validation satisfy
  `ARCH-RTL014-001`/`ARCH-VAL-014`.
- **`VP-SAFE-006`**: each term/inversion/operator/guard/response-mask/
  reserved-value combination is validated individually; `COMMIT_ALL`'s
  atomicity, first-error retention, and "evaluates the new bank at the
  specified time" (SS3 above) are each their own dedicated cases — with 8
  entries × 4 terms × 4 operators, exhaustive-but-structured coverage
  (not per-permutation exhaustion) is the practical target.
- **`VP-SAFE-007`**: the zero-cycle guard-permission-drop requirement gets
  its own timing-focused case — this is the one place in this module
  where "eventually correct" is explicitly insufficient.
