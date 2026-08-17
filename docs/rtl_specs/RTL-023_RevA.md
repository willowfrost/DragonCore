# RTL-023 Module Specification — User-Configurable Routing Logic

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, SRS-002, VP-002.

## 1. Identity and role

RTL-023 is the Dragon Core user-configurable signal router: **16 staged
entries**, each mapping one source signal to one destination with
polarity inversion and edge/level mode, atomically committed as a whole
bank against a **fixed source/destination authorization matrix**. This is
the last module in the entire RTL-001..024 set — every other module's
functional behavior is now specified. Owns REG-002's User Routing block
(0x4100–0x41FF, 11 registers).

Controlling documents: `ARCH-002` SS13.2 (the entire functional contract,
below), Appendix F.1 `ARCH-RTL023-001`, `REG-ENC-018`, `SRS-002`
`DFC-FUNC-0121`–`0138`, VP-002 `VP-MOD-023`/`VP-USER-005`–`009`.

## 2. Ports (19 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`
(`RTL-002.module_reset_o[22]`), `control_i` (`dfc_rtl023_control_t`, 34
bits)/`status_o` (`dfc_rtl023_status_t`, 75 bits), `timestamp_i`,
`operating_state_i`, `observational_mode_i`, condition-enable pair.
RTL-023-specific: source-signal sampling ports for whatever the Appendix
C source-ID catalog names as routable — this spec does not re-derive
that full source/destination ID catalog (`CHTR-DOC-003`); confirm exact
port wiring against Appendix A's RTL-023 row and Appendix C's source/
destination ID tables directly before implementation.

## 3. Exact signal routing contract (`ARCH-002` SS13.2 — the entire module)

- **16 entries**, each: 8-bit source ID, 8-bit destination ID, enable,
  invert, mode (**0 level, 1 rising one-cycle pulse, 2 falling one-cycle
  pulse, 3 either-edge one-cycle pulse**). **Source values are sampled
  synchronously; prior source state is updated every enabled cycle** —
  edge history tracking runs continuously while enabled, not just when
  actively driving an output.

**Fixed authorization** (confirmed exact rules, not a simple range check):
- Source IDs **1–31 may drive destinations 1–8**.
- Source IDs **1–31 may drive destinations 21–24**.
- **Only** source IDs **1–16 may drive destinations 13–20** — a
  *narrower* source range than the 1–31 rule above; don't conflate the
  two destination-group rules into one shared source range.
- **No source may drive destinations 9–12 in Revision A**, because
  RTL-022's outputs are inert (a direct architectural consequence of
  RTL-022's own SS13.1 contract — this isn't an independent rule, it
  follows from RTL-022 having nothing live to route *to*).
- **Source 0 may be staged only for a disabled entry** — source ID 0 is
  legal to write, but only paired with `enable=0`; an enabled entry can
  never reference source 0.
- **Source 37 (constant-one) may drive level-mode destinations 21–24
  only** — a fixed logic-one source, restricted to level mode and that
  specific destination range (edge modes on a constant source would be
  meaningless, hence the mode restriction).
- **Every other pair is rejected.**

**Exclusivity and combination:**
- **Destinations 1–12 are exclusive**: a commit containing more than one
  *enabled* entry targeting the same such destination is **rejected
  entirely** (whole-bank rejection, per the commit contract below) — not
  "last one wins" or "first one wins."
- **Destinations 13–24 are wired-OR**: runtime output is the OR of every
  authorized active entry's result. For exclusive destinations (1–12),
  the one committed entry's result is used directly (no OR needed since
  only one can exist).
- **Disable, reset, invalid state, or effective-operational-enable low
  forces all destinations to zero** — a hard override independent of any
  entry's own state.

**Commit priority:** `VALIDATE_COMMIT` has **priority over
`DISABLE_ENTRY`**; if **both** are commanded simultaneously, **the
complete operation is rejected BUSY with no active change** — this is
neither "commit wins" nor "disable wins"; it's an outright rejection of
the ambiguous simultaneous command. **New command-result evidence
dominates clear** — same discipline as every other module's
evidence-vs-clear priority.

Per `ARCH-RTL023-001`: **edge history updates while enabled even when
effective outputs are gated** (e.g. by `EFFECTIVE_OPERATIONAL_ENABLE`
being low) — this specifically **prevents a stale edge on re-enable**: if
edge tracking paused while gated, re-enabling could spuriously fire on an
edge that actually happened during the gated interval. Keep the tracking
logic running continuously; gate only the *output*, never the *history*.

## 4. Registers owned (REG-002 0x4100–0x41FF, 11 registers)

Per-entry staged source/destination/enable/invert/mode configuration
(`UROUTE_STAGE_SOURCE`/`_DEST`/`_CONTROL`, entry-select register,
`VALIDATE_COMMIT`/`DISABLE_ENTRY` commands), active-bank readback
(`UROUTE_ACTIVE_SOURCE`/`_DEST`), per-entry status (active/valid/
activity-count), aggregate status, and `RTL023_EVT_OVERFLOW_STATUS`.
Implement against `dfc_registers_pkg.json`'s RTL-023-owned entries.

## 5. Verification obligations

- **`VP-MOD-023`**/**`VP-USER-006`**/**`007`**: whole-bank atomic
  validation/commit, first-error retention, exact source/destination
  authorization (all the specific range rules above — not a generalized
  "in range" check), exclusivity, wired-OR, active polarity, level/edge
  behavior, disable behavior, and activation priority match SS13.2
  exactly.
- **`VP-USER-005`**: staging accepts every legal combination and rejects
  every unauthorized, reserved, conflicting, duplicate-exclusive, or
  malformed entry — given the asymmetric authorization rules (three
  different source-range/destination-range pairings, plus two special-
  cased sources), this needs deliberately structured coverage across each
  rule, not generalized range-boundary sampling.
- **`VP-USER-008`** (cross-cutting, binds directly here): user routes
  **cannot reach** safety, clocks, resets, protected writes, host
  transport control, test authorization, direct transmitter control, or
  any undefined internal endpoint — worth explicit confirmation that the
  fixed source/destination ID catalog this module can reference never
  includes any of those, not just that the *logic* prevents it.
- **`VP-USER-009`**: edge-history-updates-while-gated (SS3 above) gets
  its own dedicated test — gate the output, drive an edge, re-enable, and
  confirm no stale/spurious pulse fires.
