# Dragon Core Project — Continuity Reference

**Purpose:** this document exists so a new chat session working on this
project does not need to be walked through decisions and findings that
have already been made and confirmed. Read this before starting any new
work. If something here conflicts with a specific instruction the person
gives in a new session, the new instruction wins — this is memory, not a
constraint on what's allowed to change.

---

## 1. Environment facts (do not re-derive these — they're confirmed, not guessed)

- **Windows is the sole active development platform.** No Linux dev
  environment exists or is planned unless explicitly stated otherwise.
- **PowerShell (`.ps1`) is the only actively maintained script format.**
  `.sh` versions of the same scripts were retired deliberately — confirmed
  directly that `bash --version` returns "not recognized" in a plain
  Windows terminal on this machine. If Linux development is ever actually
  taken up, recreate `.sh` scripts fresh at that point; do not maintain
  both formats in parallel.
- **Exception:** Claude Code's own bash tool can still work on this
  Windows machine via bundled Git Bash/MSYS2 (confirmed: `uname -a`
  reported `MINGW64_NT`). This is a different thing from the person's own
  plain terminal lacking bash — don't conflate the two when diagnosing a
  script failure.
- **PowerShell version is 5.1** (Windows PowerShell, not PowerShell 7/
  `pwsh`). This matters concretely: `$ErrorActionPreference = "Continue"`
  does **not** reliably suppress `NativeCommandError` wrapping when a
  native executable (yosys, iverilog, sby, etc.) writes to stderr *and*
  exits nonzero — it only worked for benign, exit-0 informational stderr
  lines. **The confirmed, working fix for every native tool invocation in
  every `.ps1` script in this project is routing through `cmd /c
  "command > log 2>&1"` instead of PowerShell's own `*>` redirection.**
  If a new `.ps1` script is ever written that calls a native tool
  directly via `&` with `*>` redirection, expect it to fail the same way
  the first time it hits a real tool error — apply the `cmd /c` pattern
  from the start.
- **Python is registered as `python`, not `python3`, on this machine.**
  Windows has a built-in "App Execution Alias" stub that intercepts
  `python3.exe`/`python.exe` and redirects to the Microsoft Store with a
  misleading message when no real Python is registered under that exact
  name — this looks like "Python not found" but is a different, Windows-
  specific failure mode. Any script invoking Python should check both
  `python` and `python3`, and should reject a match whose `Source` path
  contains `WindowsApps` (that's the fake stub, not a real interpreter).
- **Every Python script in this project that reads a `.md` specification
  document must open it with `encoding="utf-8"` explicit** — never a bare
  `open(path)`. Confirmed as a real, live bug, not a theoretical one:
  `extract_types.py`'s header pattern requires an exact em-dash character
  (`—`, U+2014); this project's sandbox testing environment always
  defaults to UTF-8, but this machine's actual Python appeared to default
  to a different encoding, silently misreading that one character and
  breaking every header match in the document simultaneously (symptom:
  "0 structs found" where 47 were expected, even though the file's real
  content was correct and had already been independently verified).
  `extract_registers.py` kept working throughout this same failure
  because its own header pattern only uses plain ASCII characters,
  identical across encodings — which is exactly why only *some*
  extractors failed and not others. All six extractor scripts now
  explicitly specify `encoding="utf-8"` on every file read and write;
  any *new* script added to this project that reads a `.md` document
  must do the same from the start.
- **The FPGA toolchain is `oss-cad-suite`**, a native Windows build
  including `yosys`, `nextpnr-ecp5`, `ecppack`, `sby`, `yosys-smtbmc`, and
  the `boolector` SMT solver. Confirmed installed and working.
- **Known packaging bug in this `oss-cad-suite` build:** `yosys-smtbmc`
  ships as `yosys-smtbmc.exe.exe` (double extension) paired with
  `yosys-smtbmc.exe-script.py`. The launcher stub derives its companion
  script's name from its own filename at runtime, so this pairing
  actually works — but `sby` looks for the correctly-named
  `yosys-smtbmc.exe`, which doesn't exist. **Fix: copy (not rename)**
  both files to their correctly-named counterparts
  (`yosys-smtbmc.exe` + `yosys-smtbmc-script.py`), leaving the originals
  intact. If this environment is ever rebuilt, expect to hit this again.
- **Target hardware:** ULX3S board, Lattice ECP5 **`LFE5U-85F-6BG381C`**,
  nextpnr package name `CABGA381`. Pin mapping for this project's SPI
  interface uses `gp[0:4]` (confirmed free, general-purpose header pins,
  not shared with configuration flash/SDRAM/WiFi) — see
  `fpga/ecp5/ulx3s_dfc.lpf` for the exact, real, fetched-not-memorized
  constraint values. **The full, corrected single-ended/differential
  picture across both headers, confirmed directly against ULX3S's own
  official manual (an earlier note here, based only on a schematic
  excerpt, was incomplete — corrected once, don't re-introduce the
  incomplete version):** `gp`/`gn` positions **0-7 (J1) and 22-27 (J2)
  are single-ended-only** (each independently usable); positions **8-13
  (J1) and 14-21 (J2) are differential-capable** (`gp[N]`/`gn[N]`
  committed together as one logical signal) but per the manual can also
  be used as ordinary single-ended pins if needed. This matters for
  every future pin assignment: see `ULX3S_CONNECTION_MAP.md`'s own
  Section 4 note before choosing a position for a new interface.

---

## 2. Toolchain-specific SystemVerilog findings (load-bearing — will recur if not respected in any new RTL)

These were each found by actually running real tools, not by inspection.
Treat every one as a hard constraint on how RTL and formal harnesses get
written in this project going forward, not just a historical note.

- **Wildcard package imports (`import pkg::*;`) fail to parse under
  Yosys's native `read_verilog` frontend** — confirmed on two Yosys
  versions three years apart, so this is architectural, not a version
  bug. Icarus Verilog tolerates this pattern fine, which is exactly why
  it went undetected through pure simulation for a long time. This
  pattern is *also* already banned by `RTLSTD-LANG-008` for unrelated
  reasons — the toolchain finding is independent confirmation the rule
  is correct, not the origin of it. `RTLSTD-LANG-008`'s actual wording
  (confirmed directly against `RCA-DFC-RTL-STD-002.md`) is already
  fully general: *"Wildcard package imports shall not be used in
  functional RTL."* No module-scoping of any kind — this governs every
  RTL module in this project, not just the ones that exist today.
  **This applies explicitly and without exception to RTL-002 through
  RTL-023 and any module written after them, not only RTL-001/RTL-024
  (the only modules implemented so far).** Every cross-package
  reference in this project must be fully qualified
  (`pkgname::SYMBOL`) at the use site. Never write a bare
  `import ...::*;` in any `.sv` file, generated or hand-authored,
  regardless of which module it belongs to. `lint.ps1` has an automated
  check for this (`RTLSTD-LANG-008 wildcard-import scan`) that scans
  every `.sv` file recursively under `include/` and `rtl/` by file
  extension, not by an enumerated module list — so a brand-new module
  written under a not-yet-existing path (e.g.
  `rtl/monitoring/src/dfc_rtl006.sv`) is caught automatically the first
  time `lint.ps1` runs against it, with no update to the check itself
  required. If the check ever fires, fix the generator (if the file is
  generated) or the hand-authored source directly; do not suppress the
  check, and do not treat "this is a new module, the rule must not
  apply to it yet" as a valid reason to leave a wildcard import in
  place.
- **Yosys's native frontend cannot parse concurrent SVA at all**
  (`assert property (...)`, `|->`, `|=>`, `s_eventually` — none of it).
  Confirmed via minimal isolated test cases, not assumption.
- **`default clocking ... endclocking` / `default disable iff` fails
  under both Icarus and Yosys's native frontend.** Every property in a
  formal harness must state its own explicit clocking/disable clause
  instead of relying on a shared default.
- **`read_slang` (available via the `yowasp-yosys` pip package, a current
  Yosys build with a real, standards-complete SV/SVA frontend) parses
  concurrent SVA syntax correctly, but the Yosys-slang plugin does not
  yet translate `|->`/`|=>` into Yosys's internal checkable formal
  representation** — confirmed directly via a real `design.log`:
  `"error: encountered unsupported SVA feature"` on every property using
  either operator. slang itself understands the syntax; the translation
  into something Yosys can actually check does not exist yet in this
  plugin version.
- **The confirmed, working fix for formal properties in this toolchain:
  write every property as an IMMEDIATE assertion inside a clocked
  `always_ff` block**, not a concurrent `assert property`. Same-cycle
  (`|->`-style) properties translate directly. Next-cycle (`|=>`-style)
  properties need explicit "previous value" staging registers to
  reproduce the one-cycle delay. Unbounded liveness properties
  (`s_eventually` with no bound) generally cannot be expressed this way
  at all — check whether a bounded property elsewhere in the same
  harness already implies the unbounded one (this happened once in this
  project: a bounded response-deadline property made a separate
  unbounded "eventually responds" property redundant, and the redundant
  one was dropped with the reasoning documented, not silently deleted).
- **Icarus rejects a *labeled* immediate assertion** (`P1: assert
  (...);`) but accepts the same assertion unlabeled. This only matters
  if you're trying to use Icarus as a secondary sanity-check tool for a
  file that's really targeted at `sby`/Yosys (as was done in this
  project) — it does not affect `sby` itself, which handles labeled
  immediate assertions correctly and uses the label in its own PASS/FAIL
  reporting.
- **A `.*` wildcard port connection in Icarus errors on an unmatched
  port** rather than silently leaving it unconnected — this was a wrong
  assumption that caused a real, undiagnosed elaboration error the first
  time a new port was added to a module instantiated via `.*` elsewhere.
  If you add a port to any module, check every `.*`-style instantiation
  of it and add an explicit `.new_port_name()` override if needed.
- **A formal harness must force a genuine reset cycle at the very start
  of every trace it explores, or BMC/k-induction can start from an
  arbitrary "anyinit" state** (including inside the real DUT's own
  registers) that could never occur on real silicon, producing false
  counterexamples with nothing to do with actual design behavior. The
  confirmed, working fix: don't make the reset signal a free top-level
  input to the formal harness; generate it internally with a
  deterministic one-shot pulse (an `initial`-block-driven register that
  starts at 0 and is forced to 1 on the first clock edge, used as the
  reset signal). This exact technique was already independently
  confirmed working for the ECP5 PLL's own power-on-reset counter
  earlier in this project (`fpga/ecp5/ulx3s_dfc_top.sv`).
- **Any helper/bookkeeping register the formal harness itself declares**
  (not part of the real DUT — e.g. "previous value" staging registers for
  a `|=>`-style property) **must have an explicit reset branch too**, or
  it's subject to the exact same anyinit-state false-failure risk as the
  main reset signal, just scoped to that one register.
- **A hierarchical dot-notation reference into an instance's internal
  signal** (`u_dut.some_internal_signal`, referenced from the
  *instantiating* module) **does not resolve under Yosys's native
  frontend** — it gets parsed as one bizarre escaped identifier rather
  than dot-notation into the instance, and `prep`/`CHECK` reports it as
  an undriven wire.
- **SystemVerilog `bind` compiles with zero errors under Yosys's native
  frontend but silently produces zero cells** — the bound checker module
  never actually gets instantiated at all. This is a worse failure mode
  than an explicit error, since it looks like success. **Neither
  hierarchical dot-notation nor `bind` should be relied on to observe a
  DUT's internal signal from a formal harness in this toolchain.**
- **The confirmed, correct way to give a formal harness (or any external
  verification code) access to an internal DUT signal: add a real,
  permanent, always-connected observability output port directly to the
  production RTL module itself.** This is not a stub, not a workaround,
  and not a violation of `RTLSTD-MOD-014`'s general prohibition on
  exposing internal state — it's a deliberate, documented exception for
  formal-verification observability, and the added port becomes a
  genuine, permanent part of the module's real interface, on equal
  footing with every other port. (Real example in this project:
  `dfc_rtl001.sv`'s `dbg_regbank_write_en_o`.)
- **When writing any formal property: whether it should be `assert` or
  `assume` depends on who controls the signals it references, not on
  what feels natural to write.** A property about signals the DUT
  cannot control (free, host-driven inputs) must be an `assume` — a
  constraint on the environment the DUT is entitled to rely on — not an
  `assert`, which is a claim about the DUT's own behavior. Conflating
  these produces properties that fail for reasons that have nothing to
  do with the DUT (the solver is simply free to violate an `assert`
  written against something nothing constrains). Separately: a property
  about "same-cycle" behavior should generally check what the DUT itself
  presents/guarantees (e.g., "is a response being presented"), not
  something that additionally depends on a free host input also
  cooperating that same cycle (e.g., "is a response being accepted" —
  which depends on the host's own free ready signal too) unless that
  joint condition is genuinely what's being specified.
- **Package-scoped enums (`pkg::type_t` port/variable types, `pkg::LITERAL`
  values) parse and elaborate cleanly under both Icarus and this Yosys
  build** — confirmed via a real isolated test (a minimal package + module
  using this exact style, run through `yowasp-yosys` with zero errors) and
  independently reconfirmed by `dfc_rtl002.sv`/`dfc_types_pkg.sv`'s real
  `dfc_operating_state_t` compiling and synthesizing clean. Do not treat
  "enums don't work in this toolchain" as a real finding — it isn't one.
  What *does* fail is the already-documented wildcard-import case above;
  a hazy memory of "enum trouble" is more likely that, a different Yosys
  version, or one of the specific constructs below, not enums themselves.
- **A ternary expression whose two branches are different enum literals
  of the same enum type requires an explicit cast under Icarus**
  (`state_d = cond ? pkg::A : pkg::B;` → `error: This assignment requires
  an explicit cast.`), even though both branches share the enum type and
  the assignment target is that same enum type. Confirmed via a real
  compile failure in `dfc_rtl002.sv`. **Fix: restructure as `if`/`else`
  assigning each branch's literal directly** — cleaner than a cast anyway,
  and this is now this project's standard style for any next-state mux
  between enum literals.
- **Icarus rejects a packed-struct named-aggregate literal (`'{member:
  value, ...}`) used directly in a continuous `assign`** ("syntax error
  in continuous assignment") — confirmed via a real compile failure in
  `dfc_rtl024.sv`. This is distinct from the same syntax working fine
  inside a testbench `initial`/task context (`rtl002_state_tb.sv` uses
  plain per-field dot-assignment instead, which was never an issue).
  **Fix for a continuous-assignment context: individual per-field
  `assign target.member = value;` statements**, not a single aggregate.
- **Icarus rejects `break` inside a `for` loop** (`sorry: break statements
  not supported`) — confirmed via a real compile failure in
  `rtl024_skeleton_tb.sv`. **Fix: a flag-gated loop body** (`if
  (!reached) begin ... if (condition) reached = 1'b1; end`) instead of
  `break`, iterating the full loop bound either way.
- **A combinational signal read inside the SAME `always_ff` block that
  also updates it that cycle reads the OLD, pre-update value** — this is
  ordinary, correct Verilog semantics, but it produced a real, genuine
  off-by-one bug in `dfc_rtl002.sv`'s reset-command completion logic: a
  counter's completion condition (`if (ready_streak_q == 2'd2)`) was
  checked in the same always_ff cycle that also updated
  `ready_streak_q <= ready_streak_q + 1`, so completion actually fired on
  the *third* consecutive qualifying cycle instead of the intended
  second — only caught by actually running the simulation, not by
  inspection. **Fix: compute the "next value" combinationally as its own
  named signal** (e.g. `wire [1:0] ready_streak_next = ...;`) and check
  completion against that, not against the stale registered value. Watch
  for this pattern anywhere a counter's terminal value is checked in the
  same cycle it's incremented.
- **A compound top-level reset condition mixing the real asynchronous
  reset signal with an additional non-sensitivity-list signal
  (`if (!core_rst_n_i || module_reset_i) ... else ...`) fails under
  Yosys's PROC_DFF pass** with `ERROR: Multiple edge sensitive events
  found for this signal!`, even though the exact same register's
  sensitivity list (`@(posedge clk or negedge core_rst_n_i)`) is
  syntactically fine and Icarus never complains about this pattern at
  all. Confirmed directly: `dfc_rtl002.sv` had two `always_ff` blocks with
  otherwise-identical reset semantics — one written as
  `if (!core_rst_n_i) ... else if (module_reset_i) ... else ...` (parsed
  clean) and one written as the compound-OR form above (failed) — fixing
  the second to match the first's structure resolved it, reconfirmed via
  a real Yosys run showing 0 errors. **Standing rule for this project:
  the real async-reset signal must be checked in its own, standalone
  top-level `if`, never OR'd together with any other reset-like condition
  in the same branch** — additional synchronous reset sources belong in
  a subsequent `else if`, exactly matching the sensitivity list's own
  async-reset signal and nothing else.
- **STANDING, PROJECT-WIDE RULE, confirmed via three separate real build
  failures AND a subsequent real, clean `build_ecp5.ps1` pass — both
  confirmed against the person's actual production toolchain (`Yosys
  0.66+252` in `oss-cad-suite`) — read this before writing any module from
  RTL-003 onward: a package-scoped name used as a declared TYPE fails to
  parse on this exact toolchain, in every position tried so far — a
  port's declared type (`output dfc_types_pkg::dfc_operating_state_t
  operating_state_o` → "unexpected TOK_PACKAGESEP, expecting ')' or ','
  or '='"), `$bits()` given a bare package-scoped type name in a port's
  width expression rather than an expression (→ "unexpected ')',
  expecting OP_CAST"), and a plain internal variable's declared type
  (`dfc_types_pkg::dfc_operating_state_t state_q, state_d;` → "unexpected
  TOK_PACKAGESEP, expecting TOK_ID or '#'"). None of these three could be
  reproduced against either `yowasp-yosys` build available in a sandbox
  session (0.66.0.0.post1165 or 0.68.0.0.post1208 — both accept all three
  patterns fine) — this is a real, specific-commit parser gap within the
  person's own exact build, not something to dismiss because it didn't
  reproduce elsewhere. Given that, and given the sandbox's inability to
  validate a fix against the exact failing parser, `dfc_rtl002.sv` was
  ultimately rewritten to avoid `dfc_types_pkg::` in EVERY position, not
  only the ones that failed — including plain VALUE/enum-literal
  references (`dfc_types_pkg::RESET_ACTIVE` used as an rvalue), out of
  caution, since that usage could not be positively verified safe either
  at the time. **This turned out to be more conservative than necessary
  and was subsequently reverted** (see below) — the settled, current rule
  is the narrower one two paragraphs down, not this first-pass
  over-caution.**
  Checked directly against `dfc_rtl001.sv` (already real, already
  synthesized, already place-and-routed successfully on this exact
  production toolchain): every one of RTL-001's ports is a plain
  `logic`/`logic [N:0]`, never `pkg::type_t`, but RTL-001 already relies
  on package-scoped VALUE references in expressions
  (`dfc_registers_pkg::DFC_ADDR_PROTECT_KEY`,
  `dfc_constants_pkg::DFC_PROTECT_KEY1/2`,
  `dfc_constants_pkg::DFC_PROTECT_TIMEOUT_CYCLES`) and has already built
  clean with them. So the real, precise, SETTLED finding is narrower than
  "avoid the package entirely": `pkg::VALUE` in an expression is
  confirmed safe on this toolchain and should be used (not locally
  duplicated); `pkg::TYPE` as a declared type is confirmed broken, in
  every position tried, and must never be used. `dfc_rtl002.sv` was
  updated again to reflect this — its primary-state comparisons/
  assignments now reference `dfc_types_pkg::RESET_ACTIVE` etc. directly
  as values (no local `ST_*` duplicate constants), while `state_q`/
  `state_d` themselves, and `control_i`/`status_o`'s struct-field
  handling, still use the flat-vector/bit-slice workaround since those
  really are declared-type or struct-field-position cases with no
  `pkg::VALUE`-shaped alternative. RTL-001 never "solved" this — it
  simply never used the pattern that breaks, since none of its ports or
  internal signals are declared with a package-scoped type. RTL-002 is
  the first module in this project to declare anything of a
  package-scoped type at all, which is exactly why this surfaced only now
  — and every module from RTL-003 onward has the identical exposure,
  since every module's own spec defines its `control_i`/`status_o` ports
  as `dfc_types_pkg::dfc_rtlNNN_control_t`/`_status_t`.
  **MANDATORY PATTERN for every module from RTL-003 onward — confirmed
  working end-to-end: Icarus, both available sandbox Yosys versions, AND
  a real, clean `build_ecp5.ps1` pass on the person's actual production
  toolchain (Build ID `20260817_131045`, 61.20 MHz PASS at 50 MHz
  required). This superseded an earlier, less complete version of this
  guidance that's no longer current — read this version, not an older
  memory of it:**
  - Never declare a port, or any internal `reg`/`logic`/`wire`, using
    `dfc_types_pkg::some_type_t` as its type. Declare it as a plain
    `logic [W-1:0]` instead.
  - **Size every such vector using the generated `dfc_types_pkg::
    DFC_<STRUCTNAME>_WIDTH` constant** (e.g. `logic [dfc_types_pkg::
    DFC_RTL003_CONTROL_WIDTH-1:0] control_i`) — NOT a hardcoded numeric
    literal, and NOT `$bits(pkg::type)` (a separately-confirmed-broken
    construct: "unexpected ')', expecting OP_CAST"). `pkggen.py` now
    emits one `_WIDTH` localparam per struct/enum in `dfc_types_pkg.sv`
    automatically — this closes what was, for RTL-002 alone, a real,
    disclosed, hand-maintained duplication risk; there is no reason to
    reintroduce that risk for RTL-003 onward. A `pkg::VALUE` reference
    inside a port's packed-dimension width expression was, at the time
    this pattern was first used, a calculated but *unconfirmed* risk
    (same expression grammar as other proven-safe `pkg::VALUE` uses, but
    an untested position) — it is now CONFIRMED SAFE by the real
    `build_ecp5.ps1` pass above, which used exactly this construct for
    `dfc_rtl002.sv`'s `control_i`/`status_o`/`evt_record_o`/
    `operating_state_o` ports.
  - For a struct port whose individual fields are read inside the module
    (e.g. a `control_i` input): extract each needed field as an
    individually-named bit-slice wire from the flat vector, sliced using
    the generated `dfc_types_pkg::DFC_<STRUCTNAME>__<FIELDNAME>_HI`/`_LO`
    constants (e.g. `wire ctl_degraded_ack = control_i[dfc_types_pkg::
    DFC_RTL003_CONTROL__IRQ_ENABLE__ENABLE_HI];`) — NOT a hand-copied
    literal bit position. `pkggen.py` computes these directly from
    ARCH-002 Appendix B's real field ordering every time
    `dfc_types_pkg.sv` is regenerated, so a future ARCH-002 change to a
    struct's layout is picked up automatically instead of requiring a
    hand-updated literal in every module that uses it. Do not reintroduce
    a package-struct-typed internal variable as a workaround for
    readability; that is exactly the pattern that fails.
  - For a struct/enum port that is only ever WRITTEN (e.g. `status_o`,
    `operating_state_o`): the internal signal driving it can safely stay
    a plain `logic [W-1:0]` too, packed via individual bit-range
    assignments using the same generated `_HI`/`_LO` constants — an
    enum/struct-to-vector assignment direction was never the failing
    case, but there is no working alternative for the declared type
    itself on this toolchain, so use the same flat-vector approach on
    both sides for consistency.
  - **Conversely: DO reference `dfc_types_pkg::` directly wherever it's
    used as a plain VALUE, never as a declared type** — comparisons,
    assignments, anything that reads as an rvalue (e.g.
    `state_q == dfc_types_pkg::NORMAL`). This is confirmed safe (RTL-001
    already relies on the identical pattern with `dfc_registers_pkg::
    DFC_ADDR_PROTECT_KEY`/`dfc_constants_pkg::DFC_PROTECT_KEY1`, both
    real, already-synthesized) and has zero duplication cost — do not
    locally re-declare a hand-duplicated constant for this case.
  - **This pattern now has near-zero ongoing hand-maintenance cost**, a
    real improvement over how RTL-002 first shipped it: `pkggen.py`
    generates the width/bit-position constants, so a future ARCH-002
    change to any struct's layout is picked up automatically by every
    module that references the generated constants (not by hand-updating
    literals project-wide, which was the original, disclosed risk). The
    one remaining manual step is regenerating `dfc_types_pkg.sv` itself
    when ARCH-002 changes — already handled by `regenerate.ps1`'s
    staleness check (see Section 3), which now also detects generator
    script changes, not just source-document changes.
  - **Every file that declares a `control_i`/`status_o`/`operating_state`/
    event-record signal for a given module needs this same treatment, not
    just the module's own `.sv` file** — this was missed once for real:
    `dfc_rtl024.sv` (the integrating top-level, which instantiates
    RTL-002 and declares its own local `rtl002_status`/
    `rtl002_operating_state`/`rtl002_control_stub` signals) and
    `rtl002_state_tb.sv` (RTL-002's own standalone testbench, which
    declares its own local copies of the same four signals to connect to
    the DUT) both independently needed the identical fix, found only
    because the person asked "shouldn't dfc_rtl024.sv also be rewritten
    too?" rather than the fix being applied comprehensively the first
    time. When RTL-003 is real and something else (`dfc_rtl024.sv`, a
    formal harness, another module's port list) needs to reference its
    control/status types, check ALL of them, not just the new module's
    own file.
  - Do NOT decide this file-by-file without checking this note first — a
    future session that hasn't read this will very likely re-introduce
    `pkg::type_t` ports for RTL-003 onward (since that's the natural,
    spec-literal way to write them) and hit the identical real build
    failure again.

---

## 3. Organizational / coding conventions already established

- **`RTLSTD-ORG-003`: generated files are never hand-edited.** If a
  generated file is wrong, fix the generator script or its input JSON,
  then regenerate from scratch. This was followed consistently even
  under real time pressure this session (a genuine bug in a generated
  register bank file was fixed in `reggen.py`, not patched directly).
- **`CHTR-DOC-003` (single-owner-per-fact rule):** a document that
  consumes another document's technical fact must cite an owning
  identifier, never repeat, restate, strengthen, weaken, or redefine it.
  This is a rule *inside* `RCA-DFC-CHTR-002.md`, not a separate file —
  don't go looking for a standalone document by that name.
- **3rd-party reference documents** (VisionFive2 datasheets, ECP5
  datasheet, ULX3S schematics/constraint files) are explicitly and
  correctly exempt from this project's own document-governance rules.
  This is expected, not a gap to fix.
- **Directory structure**, confirmed and stable:
  - `docs/` — the specification baseline (business/requirements/
    architecture/rtl_specs/verification/software subfolders). **CORRECTED
    characterization — read this before treating anything under `docs\`
    as unchangeable:** these documents were audited/ratified to reach a
    state complete and consistent enough to *begin* RTL/software work
    from — that milestone is what "the `-002` baseline" refers to, not a
    permanent freeze. The standing rule, confirmed directly by the
    person after this was mischaracterized once in an earlier session:
    if a real gap, inconsistency, or conflict is found in any of these
    documents (exactly the kind of thing `OPEN_ISSUES.md` logs), **the
    document gets changed, after approval, and anything downstream
    affected by that change gets redone so the resulting design stays
    functional.** This has already happened for real: some top-level
    documents were revised after real gaps surfaced during RTL-spec
    writing, and again during software-spec writing. Don't withhold a
    real fix or ask excessive permission out of a mistaken belief that
    `docs\` is frozen — the actual discipline is: propose the specific
    change, get it approved, then update everything the change touches
    for real (same standard as any other real fix in this project) —
    not "never touch it."
  - **Repo root** — living reference documents, distinct from `docs\`'s
    frozen-baseline specs: `PROJECT_CONTINUITY.md` (this file),
    `OPEN_ISSUES.md` (real, disclosed gaps/ambiguities), and
    `ULX3S_CONNECTION_MAP.md` (real physical board wiring — which
    `gp<N>` signal maps to which J1/J2 header position, confirmed
    against the actual board, not just the schematic — see that file's
    own header for exactly how each fact was confirmed). All three get
    updated as part of the work that makes them stale, not deferred to a
    separate cleanup pass.
  - `include/` — shared, generated `dfc_*_pkg.sv` packages (all six now
    fully generator-driven — see Section 4)
  - `rtl/<domain>/generated/` — machine-generated RTL (e.g.
    `rtl/infrastructure/generated/`)
  - `rtl/<domain>/src/` — hand-authored RTL for that domain (e.g.
    `rtl/infrastructure/src/dfc_rtl001.sv`)
  - `rtl/top/` — top-level integration (`dfc_rtl024.sv`) and the SPI
    bridge — technology-independent, no platform-specific content
  - `fpga/ecp5/` — everything platform-specific for this target (the
    ULX3S wrapper, the PLL module, the `.lpf` constraints, build
    instructions) — deliberately kept separate from `rtl/top/`
  - `scripts/` — `.ps1` build/lint/sim/formal/gate/regenerate scripts and
    Claude Code hooks
  - `tools/pkggen/` — every extractor (`extract_registers.py`,
    `extract_types.py`, `extract_irqfault.py`, `split_irqfault.py`,
    `extract_version.py`, `extract_constants.py`) plus `pkggen.py` itself
    — **not** `tools/reggen/`, a common mix-up; keep the two separate
  - `tools/reggen/` — `reggen.py` (now v3: real cross-module control/
    status forwarding, not just address decode — see Section 4),
    `dfc_rtl001_regbank_slice.json`, and one `rtl<NNN>_field_map.json`
    per module that's had this real forwarding wired up (as of RTL-014:
    `rtl002` through `rtl014_field_map.json`; `reggen.py` is now v5, adding
    selector-indexed staged registers) — each hand-verified directly against
    REG-002.md's own per-field bit tables, cited by contract ID. This is
    NOT yet a fully generic, auto-extracted mechanism for all 353
    registers (`extract_registers.py` doesn't preserve per-field bit
    ranges project-wide) — every future module needing this same
    treatment needs its own hand-verified field-map file until that's
    generalized. Log the "generalize this" item in `OPEN_ISSUES.md`;
    don't let it get silently repeated as one-off manual work 21 more
    times without at least considering the investment.
  - `tools/.srchash/` — `regenerate.ps1`'s own disposable staleness-check
    state (one hash per source document); gitignored; safe to delete
    entirely to force a full regeneration on the next run
  - `verification/testbench/<module>/` and `verification/formal/<module>/`
  - `output/{logs,netlists,bitstreams,reports}/` — tracked build
    artifacts, each run's files timestamped so nothing gets silently
    overwritten
  - `output/_scratch/` — disposable build working directory, gitignored,
    fully wiped and regenerated by `build_ecp5.ps1` on every run
- **`lint.ps1`/`sim.ps1` check the full repo every run, not a
  per-module subset.** This was a deliberate redesign decision (the
  original `gate.sh` assumed per-module filtering these scripts never
  actually implemented). If per-module filtering ever becomes genuinely
  useful once more modules are real, add an explicit `-Module` parameter
  at that point — don't assume the capability already exists.
- **No file in this project's generated chain may be hand-assembled or
  require a manual step, at any stage — not just the final `.sv`
  output.** This is a stricter reading of `RTLSTD-ORG-003` than "don't
  hand-edit the `.sv` file" alone: hand-assembling the *JSON that feeds*
  a generator is functionally the same violation, one step removed. All
  six `include/dfc_*_pkg.sv` files are now produced by a real extractor
  reading the actual `.md` source documents, with zero manual steps
  anywhere in the chain — including the two (`dfc_events_pkg`,
  `dfc_interrupt_pkg`) that share their first extraction stage
  (`extract_irqfault.py`) and are then split mechanically
  (`split_irqfault.py`) rather than each having a wastefully-duplicate
  standalone extractor, and the one (`dfc_version_pkg`) that is derived
  from `dfc_registers_pkg.json`'s *already-verified* data rather than
  re-parsing `REG-002.md` a second, redundant time.
- **`reggen.py`'s slice file must cover every address in the full
  register map, not just RTL-001-owned registers** — a real, confusing
  discovery, worth stating explicitly so it isn't relitigated. Despite
  its name, `dfc_rtl001_regbank_slice.json` is not a subset scoped to
  RTL-001's own registers; RTL-001 physically decodes and stores (or
  passes through) the *entire* REG-002 address space, including the
  ~180 registers whose data actually lives in other modules
  (`readback: external`). `reggen.py`'s own validation
  (`missing = full_addrs - slice_addrs`) enforces this: it fails loud if
  the slice doesn't cover every address dfc_registers_pkg.json defines.
  When REG-002 grows (as it did this session, 314→353 registers), this
  slice file needs new entries added for every new address, pulled
  mechanically from the already-extracted `dfc_registers_pkg.json`
  register metadata (name/addr/reset/access_summary/owner/readback/
  contract_id/protection) — never invented by hand.
- **`dfc_rtl001.sv`'s hand-authored `_status_i` tie-off block does not
  automatically track the regbank it instantiates, and this has already
  caused a real, confirmed gap once.** When `reggen.py` regenerates
  `dfc_config_regbank_regs.sv` with new external-status ports (as it did
  when REG-002 grew to 353 registers — 38 new ports), nothing updates
  `dfc_rtl001.sv`'s own tie-off list, since that file is hand-authored,
  not generated. The result: 38 undriven wires reaching real synthesis
  undetected by simulation (1,220 "used but has no driver" warnings on a
  real build) until someone actually read the synthesis log. Confirmed
  fixed once (all 38 tied off to `'0` in the file's existing style,
  verified via real compilation and a real Yosys run showing 0 problems)
  — but this is a recurring risk, not a one-time fix: **any future
  REG-002 growth that adds new `external`-classified registers will need
  this same manual cross-check against `dfc_rtl001.sv`'s tie-off block.**
  There is no automated check for this yet (unlike the wildcard-import
  scan `lint.ps1` already has) — a real "does dfc_rtl001.sv tie off every
  regbank port the regbank actually declares" check would close this gap
  properly; until one exists, treat any REG-002 growth as a trigger to
  manually diff the regbank's port list against this file's tie-off
  block, not just re-run the generators and assume it's covered.
- **A fix made in an isolated sandbox/session is not real for the
  project until the changed file is actually handed back and placed at
  its real path.** This project hit this gap once directly (a fix was
  made and verified in one working session but never redelivered, so the
  project kept referencing the old, unfixed file) — always redeliver any
  file that was actually changed, not just describe the change.
- **The person's local repo tree and the Claude Project's uploaded file
  store can silently drift apart, and a file-renaming mistake on the
  person's side can leave a stale document sitting at the expected path
  indefinitely without any visible symptom until a tool that reads it
  actually fails.** This happened concretely this session: several
  `docs/` specification files on the person's local machine were not
  properly renamed/replaced during an update, leaving genuinely older
  versions in place (314-register `REG-002.md`, a 0-rich-struct
  `ARCH-002.md`) while the *Project's* uploaded copies were already
  correct — confirmed by running the real extractors directly against
  each side and comparing. Byte-for-byte `diff` (or running the actual
  consuming tool) is the only reliable way to confirm two copies of a
  document actually match; do not assume a file is current just because
  it's at the expected path or was recently touched. As of this
  document's writing, the person has confirmed the local tree and the
  Project's file store are back in sync for all 8 top-level baseline
  documents plus `RTL-001_RevB.md` and `RTL-024_RevC.md` — but this class
  of drift can recur any time either side is edited independently.
- **Chat-interface download links cannot be made "download-only" vs.
  "open a preview"** — that behavior is controlled by the person's own
  browser/app based on file type, not something configurable from a
  chat session. If asked, say so plainly rather than keep offering
  workarounds that don't address the actual constraint.
- **A generator can have a real, silent coverage gap that goes unnoticed
  until a new consumer actually needs the missing piece** — confirmed
  concretely this session: `extract_types.py` was scoped to Appendix B
  only, so ARCH-002 SS4.1's `dfc_operating_state_t` enum table (a
  different section, with a structurally different table shape than
  Appendix B's struct tables) was never extracted at all. `dfc_types_pkg.sv`
  had zero `typedef enum` in it — confirmed by grep across every
  generated package — since the day RTL-001/the SPI bridge were first
  verified; it simply never surfaced because RTL-001 never referenced the
  enum. It only became visible once RTL-002 needed it. **Lesson: "this
  generator has been running clean for a long time" is not evidence it
  covers everything a *new* module will need** — check the new module's
  actual type/field requirements against what the generator really
  emits (grep the real output), don't assume coverage from a clean
  history. Fixed for real: `extract_types.py` gained a second,
  independently-scoped section parser (`parse_operating_state`, scanning
  the whole document for SS4.1's heading rather than staying inside the
  Appendix-B-only scan) with its own fail-loud verification (exact
  expected state names, all 3-bit encodings, no duplicate encodings, a
  `Reserved` row confirmed present); `pkggen.py` gained a matching
  `emit_enum()` consuming the new `"enums"` JSON key. Both patches were
  run for real against the actual `RCA-DFC-ARCH-002.md` and the
  regenerated `dfc_types_pkg.sv` was recompiled/resimulated/resynthesized
  clean end-to-end (see Section 4) — not just written and assumed.

---

## 4. Current true implementation status (as of this document's writing — update this section, don't leave it stale)

- **RTL-001** (Configuration Register Bank + DRI controller): **real,
  fully implemented.** Verified via real simulation (49 checks across 4
  testbenches), real synthesis, real place-and-route, and **real timing
  closure at 67.27 MHz** on the actual target device (required: 50 MHz;
  re-confirmed after the 353-register regbank growth and the tie-off fix
  below — closure actually improved from an intermediate 61.60 MHz once
  the 38 previously-undriven wires were tied off, plausibly because the
  placer had cleaner, more constrained logic to work with). Never yet
  physically flashed to real hardware.
- **SPI-to-DRI bridge:** real, fully implemented, same verification
  status as RTL-001. Went through a real, multi-round timing-closure
  fix (the original response-builder computed too much in one
  combinational cycle; fixed via a multi-cycle pipeline restructuring,
  confirmed via real place-and-route, not just simulation).
- **`dfc_rtl024.sv`** (top-level integration): a genuine skeleton — real
  clock/reset generation, the real SPI bridge instantiated, **RTL-002 now
  also a real instantiation** (see below), but RTL-003 through RTL-023
  are still labeled stub instantiations with safe tie-offs, not real
  logic.
- **RTL-002** (System Control Logic): **real, implemented and integrated
  into `dfc_rtl024.sv`.** Implements the primary operating-state FSM
  (exact priority order, reserved-state safety net), the
  `EFFECTIVE_OPERATIONAL_ENABLE` equation verbatim, SUBSYS_ENABLE
  mandatory/optional masking and readiness/fault aggregation, the
  499,000-cycle mandatory-init timeout, per-episode `DEGRADED_ACK`
  handling, and a real `RESET_CONTROL`/`RESET_STATUS` busy/assert/wait-
  ready command sequencer (SYSTEM_RESET, one MODULE_RESET bit, or
  SAFETY_DOMAIN_RESET — exactly one scope at a time, with real
  multiple-scope and busy-reject evidence). Verified via real simulation
  in two testbenches — `rtl002_state_tb.sv` (standalone, 28/28 checks)
  and the updated `rtl024_skeleton_tb.sv` (all three real modules
  together plus the real generated regbank, 15/15 checks, including the
  full 499,000-cycle mandatory-init timeout genuinely running to
  completion and landing in FAULTED — the correct, disclosed consequence
  of RTL-003 through RTL-023 still being stubs, not a defect). **Confirmed
  end-to-end on the person's real production toolchain via an actual
  `build_ecp5.ps1` run (Build ID `20260817_131045`)** — real Yosys 0.66+252
  synthesis, real `nextpnr-ecp5` place-and-route, and **real timing closure
  at 61.20 MHz** (required: 50 MHz; converged normally, no
  `--timing-allow-fail` needed; resource utilization 12% LUTs/7% DFFs,
  well under half capacity). This followed a real back-and-forth this
  session, worth keeping as a model of the discipline this project
  expects: the person ran the actual build three separate times and
  reported back the exact new failure each time (a compound-reset Yosys
  failure, then two distinct `pkg::type_t`-as-declared-type parse
  failures — a port, then a plain internal variable — see Section 2's
  standing rule), each one fixed for real and re-sent, until the fourth
  attempt passed clean. **`dfc_rtl024.sv` and `rtl002_state_tb.sv` needed
  the identical `pkg::type_t` fix too** (found only because the person
  asked "shouldn't dfc_rtl024.sv also be rewritten?" rather than assuming
  the RTL-002 fix alone was sufficient) — a real lesson that this class of
  fix must be swept across every file that declares the affected types,
  not just the one that happened to fail first. `pkggen.py` was also
  extended this session to emit `_WIDTH`/`_HI`/`_LO` bit-position VALUE
  constants for every struct/enum, and all four files were updated to
  reference those generated constants instead of hand-copied bit
  literals — closing the duplication/drift risk for RTL-002 and setting
  the confirmed, working pattern for RTL-003 onward. Two genuine RTL bugs
  and four genuine Icarus/Yosys toolchain-specific syntax issues were also
  found and fixed by actually running these tools this session — see
  Section 2 for the specific findings (ternary-with-enum-literals cast
  requirement, packed-struct aggregate literal in a continuous assign,
  `break` in a `for` loop, the ready-streak off-by-one, and the
  compound-reset-condition Yosys failure). **Disclosed, real scope gaps,
  not silent no-ops:** `TEST_DEBUG` is structurally present but
  unreachable (no qualified test-active input exists on this module's
  port list yet); event generation (`evt_valid_o`/`evt_record_o`) is not
  implemented (RTL-002's spec doesn't enumerate its event IDs/payloads);
  the real RTL-001↔RTL-002 control/status bus does not exist yet on
  either side (`dfc_rtl001.sv` has no `rtl002_control_o`/
  `rtl002_status_i` ports, so
  `dfc_rtl024.sv` currently drives RTL-002's `control_i` from a static
  placeholder holding RTL-002 spec SS6's documented reset values, and
  ties RTL-002's own `module_ready_i[0]`/`module_fault_i[0]` — meant to
  reflect RTL-001 — to a disclosed stub too); `module_reset_o[0]` (the
  SYSTEM_RESET RTL-001-config-clear pulse) has no real consumer since
  `dfc_rtl001.sv` has no `module_reset_i` port; the `HOST_READY`
  qualifier, the reused 499,000-cycle recovery-timeout bound, and the
  `RESET_STATUS.last_result`/`.last_scope` bit-exact encodings are each a
  disclosed interpretation/implementation choice where the spec doesn't
  give an exact value. All of this is spelled out in `dfc_rtl002.sv`'s
  own file header — read it before extending or trusting this module
  further.
  **UPDATE — a later session closed the two most-cited gaps above for
  real, not just cosmetically:**
  - **The real RTL-001↔RTL-002 control/status bus now exists**, on both
    sides. `reggen.py` was extended (v3) to consume a hand-verified
    field-map (`tools/reggen/rtl002_field_map.json`, cited against
    REG-002.md's own per-field bit tables) and emit real, mechanically-
    generated bit-exact forwarding: `dfc_config_regbank_regs.sv` now
    exposes one aggregated `rtl002_control_o` output (SYS_CONTROL/
    SUBSYS_ENABLE/RESET_CONTROL, with real one-cycle pulse capture for
    the WO-CMD/W1C fields, replacing both the old permanent-zero tie for
    RESET_CONTROL and the incorrect "just hold whatever was last
    written" treatment SYS_CONTROL's DEGRADED_ACK bit got before) and one
    aggregated `rtl002_status_i` input (SYS_STATUS/SUBSYS_READY/
    SUBSYS_FAULT/RESET_STATUS/RESET_DIAGNOSTIC). `dfc_rtl001.sv` and
    `dfc_rtl024.sv` were updated to use these real ports, deleting the
    static placeholder entirely. **A real, independent bug was found and
    fixed in the same pass**: every "external"-class register
    unconditionally got `write_illegal_o = 1'b1` in the old generator,
    meaning the host could not clear `RESET_STATUS`/`RESET_DIAGNOSTIC`
    sticky evidence via the register interface at all, regardless of the
    missing wiring — fixed alongside the wiring itself. Proven end-to-end
    with a new testbench, `rtl002_integration_tb.sv` (11/11 checks): a
    real host write via RTL-001's real DRI path genuinely changes RTL-002's
    real `effective_operational_enable`, and RTL-002's real internal state
    genuinely reaches back to a host register read. This is NOT yet a
    generic mechanism for all 353 registers — see the `tools/reggen/`
    note in Section 3 for what's still manual per module.
  - **`test_active_i` is now a real port** on `dfc_rtl002.sv` (confirmed
    against the real Architecture port catalog: producer
    `RTL-024.test_active_o`), and `TEST_DEBUG` is now a genuinely
    reachable FSM state (entry/exit logic real, respecting the documented
    priority — DEGRADED still outranks TEST_DEBUG). Still only
    structurally complete, not functionally complete: `dfc_rtl024.sv`
    ties this port to a disclosed stub (`1'b0`) since RTL-024 has no real
    production-test infrastructure yet (CAPTURE/SHIFT/SAFE_LOOPBACK,
    physical authorization timing) — that remains real, separate,
    not-yet-scheduled work.
  - **Event generation (`evt_valid_o`/`evt_record_o`) is now real**, not
    a stub: event `0x0001` (operating-state transitions) and `0x0004`
    (controlled-reset transitions), source index 1 per ARCH-002 Appendix
    C.5, with a genuine one-deep pending-record holding register and
    real, counted overflow evidence (`event_overflow`/`event_drop_count`,
    previously hardcoded to 0). Disclosed simplifications remain (a
    transition's implicit "exit" subtype is collapsed into the single
    "entry" record; the 0x0001 event's prior/new-state bit packing within
    the detail field is a documented interpretation, not a bit-exact
    citation) — see the block's own header comment in `dfc_rtl002.sv`.
    `evt_valid_o` still has no real consumer (no RTL-005 exists yet), so
    the output is genuinely unconsumed rather than stubbed on RTL-002's
    own side.
  - **RTL-001 now has its own real `status_o`** (19-bit
    `dfc_rtl001_status_t`): `ready=1` is genuinely real (no complex
    startup, no `module_reset_i`, always ready once released from reset);
    `fault`/`event_overflow`/`event_drop_count` remain honest disclosed
    gaps (CONFIG_ERROR_STATUS capture and RTL-001's own event generation
    are not implemented) rather than invented values. This closes what
    was previously the single most consequential remaining gap in this
    module's integration: RTL-001 is a *mandatory*-mask module
    (`0x80F81F` bit 0), so without this fix RTL-002 could never reach
    NORMAL even after every other module became real, since a mandatory
    bit would permanently read not-ready. `module_ready_i[0]`/
    `module_fault_i[0]` in `dfc_rtl024.sv` now reflect this real signal
    instead of a permanent placeholder.
  - All of the above verified via a full regression this session: every
    real testbench in the project, 91/91 checks passing (`rtl002_state_tb.sv`
    28/28, `rtl024_skeleton_tb.sv` 15/15, `dri_transaction_tb.sv` 12/12,
    `regbank_smoke_tb.sv` 12/12, `spi_bridge_tb.sv` 13/13,
    `rtl002_integration_tb.sv` 11/11), plus Yosys 0.66.0.0.post1165 and
    0.68.0.0.post1208 both exit 0 with zero errors on the full chain.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    6/6 testbenches (91/91 checks, matching the sandbox exactly),
    `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction success against the real RTL-001, not just "no error").
    A real `build_ecp5.ps1` run (Build ID `20260818_093015`) also passed
    completely clean: **68.12 MHz PASS at 50 MHz required** (even better
    than the earlier 61.20 MHz closure), critical path comfortably inside
    budget (2.69 ns logic + 11.99 ns routing = 14.68 ns against a 20 ns
    period), 12% LUT / 7% DFF utilization, "Program finished normally,"
    no `--timing-allow-fail` needed.
  - **A real, genuine combinational-loop bug was found and fixed along
    the way to this clean build — not a synthesis-tool artifact, traced
    and confirmed by direct algebraic dependency analysis.** The
    self-loop this session's earlier work introduced (RTL-002's own
    `status_o.ready`/`.fault` looped directly back into its own
    `module_ready_i[1]`/`module_fault_i[1]`, disclosed at the time as "a
    simplification") had a real defect specifically for `fault`: bit 1 is
    one of `mandatory_fault_now`'s own mandatory-mask bits (`0x80F81F`),
    and `status_o.fault` is computed as `... || mandatory_fault_now ||
    ...` — meaning `module_fault_i[1]` was algebraically a function of
    itself. `READY` never had this problem (`host_ready_q &&
    init_complete_q` never reads `module_ready_i`). **Fix: `dfc_rtl024.sv`
    now registers this specific self-loop** (`rtl002_ready_self_q`/
    `rtl002_fault_self_q`, one real clock cycle of delay) instead of
    wiring it combinationally — breaking the cycle for real, not working
    around a tool quirk. Confirmed as the TRUE root cause, not just a
    plausible one: with ABC9 disabled (`-noabc9`, a real diagnostic flag
    added to `build_ecp5.ps1` this session), the fix alone produced a
    clean build; with ABC9 re-enabled (the normal configuration), the
    SAME fix also produced a clean build (68.12 MHz) — meaning the
    ORIGINAL, differently-shaped `dri_req_write_o` loop that motivated
    the whole investigation was the identical underlying bug, with ABC9
    simply optimizing it into a form that happened not to trip nextpnr's
    loop-checker until a `-noabc9` run exposed the true, real cause
    structurally. Two blind alleys tried and correctly ruled out first,
    each with real evidence, not assumption: a different `nextpnr-ecp5
    --seed` (added as a script option) produced a byte-identical checksum
    and identical loop — ruling out placement, since packing (where the
    loop actually originates) runs before and independent of placement;
    Yosys's own `CHECK` pass on the fully technology-mapped netlist
    reported zero problems both times, correctly pointing away from a
    Yosys-frontend-level issue and toward either ABC9's specific
    wide-mux construction or something else entirely — which the
    `-noabc9` test then correctly isolated.
  - **Three further real, independent bugs were found and fixed getting
    `gate.ps1` to actually pass clean**, none related to the
    combinational-loop investigation above:
    1. `reggen.py`'s generated module was named from the slice's
       descriptive `"module"` metadata field (`rtl001_regbank_regs`),
       completely independent of its own hardcoded output filename
       (`dfc_config_regbank_regs.sv`) — a real, pre-existing
       `RTLSTD-ORG-001` violation dating from before this session's work,
       simply never caught by an actual `lint.ps1` run against this exact
       file until now. Fixed by deriving the module name from the same
       single source as the filename (`OUT_MODULE_NAME` in `reggen.py`'s
       `main()`), so they can't drift apart again by construction; updated
       `dfc_rtl001.sv`'s and `regbank_smoke_tb.sv`'s instantiations to
       match the renamed module.
    2. `dfc_rtl024.sv` used `rtl002_control`/`rtl002_status`/
       `rtl001_status` in `u_rtl001`'s port connections before their own
       declarations later in the file — tolerated by the sandbox's Icarus
       (module-item order is generally unconstrained in standard
       SystemVerilog) but rejected by the person's real Icarus, which
       enforces declaration-before-use for named port connections
       specifically. Fixed by moving the three declarations immediately
       before their first use — correct on every toolchain regardless of
       this specific difference, and this was a real gap in this
       session's own verification discipline (should have been caught
       before delivery, not after a real, avoidable failure).
    3. `verification/formal/rtl-001/dri_one_outstanding.sby` never read
       `dfc_types_pkg.sv`, because `dfc_rtl001.sv` never referenced that
       package before this session's RTL-002 integration work added its
       real `rtl002_control_o`/`rtl002_status_i`/`status_o` ports (sized
       via `dfc_types_pkg::` VALUE constants) — same root cause and same
       fix shape as the earlier `build_ecp5.ps1` source-list gap. Fixed
       by adding it to both `[script]`'s read order (before
       `dfc_rtl001.sv`) and `[files]`. This one could not be verified in
       the sandbox before delivery (no SymbiYosys available there) —
       flagged honestly as unconfirmed at the time, then genuinely
       confirmed by the person's own real, subsequent `formal.ps1` run.
  - **`build_ecp5.ps1` gained two new diagnostic parameters this
    session**, both real and reusable for future investigations, not
    single-use hacks: `-Seed <int>` (passes through to `nextpnr-ecp5
    --seed`) and `-NoAbc9` (passes `-noabc9` to `synth_ecp5`, using
    Yosys's older, simpler LUT mapper). Its place-and-route failure
    message was also fixed to distinguish a genuine combinational-loop
    error from a timing miss (it previously always suggested checking
    for a marginal timing miss, which was actively misleading for the
    loop case, since timing analysis never even ran).
- **RTL-003 (Interrupt Controller): real, implemented and integrated into
  `dfc_rtl024.sv`.** Implements ARCH-002 SS8.1's RAW/LATCH/PENDING/ACKED
  equations exactly (new RAW dominates simultaneous CLEAR; CLEAR dominates
  ACK for an inactive source), the full 24-assigned/8-reserved Appendix C.4
  source allocation (reserved bits 24-31 permanently tied zero), the
  lowest-numbered-set-bit VECTOR_SOURCE/VECTOR_VALID priority encoder, the
  active-high `aggregate_pending_o` gating equation
  (`GLOBAL_IRQ_ENABLE & VECTOR_VALID`), and the production-test
  `TEST_IRQ_INJECT` injection path (bounded, one-cycle, ORed into RAW).
  Real cross-module register forwarding for all 8 REG-002 0x0100-0x011C/
  0x0610 registers (`IRQ_ENABLE`/`IRQ_RAW_STATUS`/`IRQ_PENDING`/`IRQ_ACK`/
  `IRQ_ACKED`/`IRQ_CLEAR`/`IRQ_VECTOR`/`RTL003_EVT_OVERFLOW_STATUS`) via
  `reggen.py` **v4** (extended this session to accept multiple simultaneous
  field-maps through the same generated regbank file, not just RTL-002's)
  and `tools/reggen/rtl003_field_map.json`. Real, counted own-diagnostic
  event generation (0x0008, illegal-reserved-source-activity, source index
  2) via the same one-deep pending-slot/overflow-counting shape already
  proven for RTL-002.
  - **THE REAL, CONFIRMED RTL-002<->RTL-024 INTERRUPT GAP IS CLOSED:**
    `dfc_rtl024.sv`'s `assign host_irq_n_o = 1'b1;` placeholder and the
    dummy `unused_stub_sink` sink for RTL-002's real `irq_req_o` are both
    gone. RTL-002's real interrupt request now genuinely reaches RTL-003's
    real `irq_source_i[0]`, and RTL-003's real aggregate output now
    genuinely drives the real external `host_irq_n_o` pad (via a plain
    inversion in `dfc_rtl024.sv` -- see below for why the inversion, not
    RTL-003 itself, owns the active-low pad semantics).
  - **A genuine spec/architecture conflict was found and resolved, not
    silently guessed:** `RTL-003_RevA.md` SS2 describes this module's
    aggregate output as if it were literally named/owned as `host_irq_n_o`.
    ARCH-002's own formal port catalog (the actual owner of this fact,
    CHTR-DOC-003) names the real 16th port `aggregate_pending_o`
    (active-high, feeding `RTL-024.aggregate_pending_i`), with `host_irq_n_o`
    itself being RTL-024's own external pad in ARCH-002's separate RTL-024
    port table. Resolved in favor of ARCH-002; logged in `OPEN_ISSUES.md`
    item 1.
  - **Disclosed, real scope gaps, not silent no-ops** (full detail in
    `dfc_rtl003.sv`'s own header and `OPEN_ISSUES.md` items 2-6):
    `RTL003_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` has no real host-clear path
    (ARCH-002's own `dfc_rtl003_control_t` has no field for it -- an
    ARCH-002-level gap, not something this module or its field-map can
    invent, and identical in kind to RTL-002's own pre-existing
    `RTL002_EVT_OVERFLOW_STATUS` gap); `event_condition_enable_i`/
    `irq_condition_enable_i` are real ports tied to a disclosed stub
    (`64'h0`) since RTL-001 doesn't implement the underlying per-module
    CONDITION_MASK storage/forwarding mechanism yet (Appendix F.3) -- means
    RTL-003's own diagnostic event can never actually fire in this
    integration yet; `irq_source_i` bits other than 0 (RTL-002) are
    disclosed stub-zero pending RTL-004 through RTL-023/RTL-001's own
    `irq_req_o`, per `RTL-003_RevA.md` SS6's own acknowledged dependency
    gap; `global_irq_enable_i` is wired from the real `rtl002_control` net
    directly (not a proper `RTL-002.global_irq_enable_o` port, which
    `dfc_rtl002.sv` does not actually have -- a pre-existing RTL-002 gap
    this integration exposed but did not create, see `OPEN_ISSUES.md`
    item 5).
  - **Proven via a new, real integration testbench**,
    `rtl003_integration_tb.sv` (22/22 checks): a real host write via
    RTL-001's real DRI path genuinely changes RTL-003's real RAW/LATCH/
    PENDING/ACKED/aggregate-pending state (including the reserved-bit
    illegal-activity fault path), and RTL-003's real internal state
    genuinely reaches back to a host register read -- same template as
    `rtl002_integration_tb.sv`. **Additionally proven completely
    end-to-end** via a real, driven `rtl024_skeleton_tb.sv` check: real SPI
    host writes (PROTECT_KEY authorization, `SYS_CONTROL.GLOBAL_IRQ_ENABLE`,
    `IRQ_ENABLE`) over the real physical SPI pins, followed by RTL-002's own
    real, autonomous FAULTED-triggered `irq_req_o`, genuinely assert the
    real external `host_irq_n_o` pad through RTL-003's real aggregation --
    the concrete, physical-pad-level proof the gap is closed, not merely a
    port-boundary-level one.
  - Every other existing testbench was checked for breakage from RTL-003's
    two new `dfc_rtl001.sv` ports (`rtl003_control_o`/`rtl003_status_i`,
    replacing 6 individual stub-tied status ports) the same way RTL-002's
    integration required checking previously: `regbank_smoke_tb.sv` needed
    its Check 3 ("external field mirrors status_i combinationally")
    re-redirected a second time (SYS_STATUS -> IRQ_RAW_STATUS for RTL-002 ->
    now TIME_STATUS, since IRQ_RAW_STATUS is aggregated too as of this
    session); `dri_transaction_tb.sv` (`.*` wildcard instantiation) and
    `rtl002_integration_tb.sv` (explicit named ports) both needed the two
    new ports declared/tied off, same class of fix as before. All confirmed
    via real, individual `iverilog`/`vvp` runs before the full regression,
    not assumed.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    7/7 testbenches (120/120 checks), `formal.ps1` both `bmc` and `prove`
    tasks genuinely PASS (real k-induction against real RTL-001, unaffected
    by the RTL-003 changes), coverage check ran clean (18/353 registers
    textually referenced, up from 6/353, expected given RTL-003's own
    registers are now exercised). A real `build_ecp5.ps1` run (Build ID
    `20260819_210250`, default invocation, no special flags) also passed
    completely clean: **63.66 MHz PASS at 50 MHz required**, 12% LUT / 7%
    DFF utilization, "Program finished normally", no `--timing-allow-fail`
    needed.
  - **A real, one-off `nextpnr-ecp5` router-internal assertion crash was
    hit and investigated during this session's build attempts, then
    confirmed non-reproducible** — a default-seed run crashed with
    `ERROR: Assert 'valid_arcs.count(arc)' failed in router1.cc:360`
    partway through routing; confirmed NOT a combinational loop (no
    matching log text) and NOT reproducible (an immediate retry of the
    identical default invocation completed cleanly at 63.66 MHz, and a
    separate `-Seed 42` retry also completed cleanly at 61.49 MHz) — a
    one-off nextpnr router-robustness limitation tied to one particular
    placement draw (nextpnr's own default seed is evidently not fixed
    run-to-run), not a property of the design. Logged in `OPEN_ISSUES.md`
    item 7 in case it recurs more persistently on a future module's build.
  - `reggen.py` **v4**: extended this session specifically to support
    multiple simultaneous consumer field-maps (RTL-002's and RTL-003's)
    through the same generated `dfc_config_regbank_regs.sv`, since v3 only
    ever accepted one field-map file per run. `scripts\regenerate.ps1` was
    updated to collect every `tools\reggen\rtl*_field_map.json` file present
    (in filename order) and pass all of them in one invocation, rather than
    hardcoding a fixed pair — a new module's field-map file is picked up
    automatically the next time it regenerates.
- **A later fix-and-verify session (2026-08-20) closed `OPEN_ISSUES.md`
  items 2 and 5 for real, on already-implemented RTL-002/RTL-003 — no new
  module work was started.**
  - **Item 2 (no way to clear `EVENT_OVERFLOW` via the register
    interface): CLOSED.** `RCA-DFC-ARCH-002.md` was confirmed already
    updated (directly against the real document, before any other work
    began) with `dfc_rtl002_control_t` grown 59→60 bits and
    `dfc_rtl003_control_t` grown 128→129 bits, each with one new
    `rtl00N_evt_overflow_status__event_overflow` field at the struct's new
    highest bit. `regenerate.ps1` regenerated `dfc_types_pkg.sv` from this
    real change; every pre-existing field's `_HI`/`_LO` constant in both
    structs was confirmed byte-identical to before (only the new field at
    bit 59/128 is new) — the edit's placement was correct, nothing else
    shifted. `tools/reggen/rtl002_field_map.json` and
    `rtl003_field_map.json` each gained one new `control_registers` entry
    mapping the register's real `EVENT_OVERFLOW` W1C bit to the new struct
    field, same pattern as the existing RESET_STATUS/RESET_DIAGNOSTIC
    entries — confirmed via a real `reggen.py` run that
    `write_illegal_o` for both `RTL002_EVT_OVERFLOW_STATUS` and
    `RTL003_EVT_OVERFLOW_STATUS` is now `1'b0` (was `1'b1`).
    `dfc_rtl002.sv`/`dfc_rtl003.sv` each gained a real bit-slice wire off
    the new field and real clear logic on their sticky `event_overflow_q`
    register (gated so a genuinely new overflow event landing the same
    cycle as the clear request wins, per REG-0044/REG-011C's own
    documented field priority — `DROP_COUNT` itself is left untouched, per
    REG-002's own "DROP_COUNT is read-only" side-effect text). New, real
    checks were added to `rtl002_integration_tb.sv` and
    `rtl003_integration_tb.sv`: each withholds its module's event
    handshake to force a genuine (not fabricated) overflow condition,
    confirms `event_overflow_q` sets, issues the real host clear write
    through RTL-001's real DRI path, and confirms `event_overflow_q`
    actually clears. (One real testbench bug was found and fixed while
    writing RTL-003's version of this test: Part 6 of
    `rtl003_integration_tb.sv` had already permanently set `IRQ_ENABLE`'s
    reserved bit 24 — an RW-class field, not a one-cycle pulse, unlike
    `IRQ_ACK`/`IRQ_CLEAR` — which kept `illegal_reserved_activity`
    continuously high and blocked any further rising-edge event detection;
    fixed by writing `IRQ_ENABLE` back to its legitimate value before
    forcing the new overflow condition.)
  - **Item 5 (`dfc_rtl002.sv` missing 4 real ARCH-002 ports): CLOSED.**
    Added `global_irq_enable_o`, `global_event_enable_o`,
    `event_condition_enable_i`, `irq_condition_enable_i` as real ports on
    `dfc_rtl002.sv`. `global_event_enable_o` is driven from the exact wire
    already used internally to gate event generation
    (`ctl_global_event_enable`); `global_irq_enable_o` is driven from a
    new, identically-patterned extraction wire off `control_i`
    (RTL-002 previously had no internal use for that bit at all).
    `event_condition_enable_i`/`irq_condition_enable_i` are tied to a
    disclosed stub (`64'h0`) in `dfc_rtl024.sv`, consistent with
    `OPEN_ISSUES.md` item 6, and intentionally consumed inside
    `dfc_rtl002.sv` via an unused-port sink per RTLSTD-MOD-009 (same
    pattern `dfc_rtl003.sv` already used). `dfc_rtl024.sv` was updated to
    connect `RTL-003.global_irq_enable_i` to the new real
    `global_irq_enable_o` port, **removing the workaround that read
    `rtl002_control` directly.** `rtl002_state_tb.sv` (`.*` wildcard
    instantiation) and `rtl002_integration_tb.sv` (explicit named ports)
    both needed the four new ports declared/tied off, same class of fix
    every prior port addition in this project has needed.
  - **A real, genuine forward-reference compile bug was found and fixed
    while wiring the EVENT_OVERFLOW clear logic, caught by a real
    `lint.ps1` run, not by inspection:** the new `overflow_sets_this_cycle`
    wire in both `dfc_rtl002.sv` and `dfc_rtl003.sv` was first written
    immediately after `evt_candidate_valid`'s own declaration — textually
    *before* `evt_pending_q` (the signal it reads) was declared further
    down the same file. The person's real Icarus rejected this
    ("Unable to bind wire/reg/memory `evt_pending_q`... Check for
    declaration after use"), even though this is a different case from
    the project's previously-documented named-port-connection
    declaration-order finding (Section 2) — this one is a plain
    continuous-assignment forward reference to an ordinary signal, and
    Icarus rejected it too. Fixed by moving both wire declarations to
    immediately after `evt_pending_q`/`event_overflow_q`/
    `event_drop_count_q`'s own declarations, right before the `always_ff`
    block that uses them.
  - **Verified end-to-end, for real, on the person's own toolchain:** full
    Icarus regression, 7/7 testbenches, **133/133 checks** (up from
    120/120 — the new RTL-002/RTL-003 overflow-clear checks account for
    the delta); a real `gate.ps1` run passed completely clean (`lint.ps1`
    PASSED, `sim.ps1` 7/7, `formal.ps1` both `bmc` and `prove` genuinely
    PASS against real RTL-001 — unaffected by this session's RTL-002/003
    changes — coverage check ran clean at 20/353 registers referenced, up
    from 18/353, expected given the two new EVT_OVERFLOW_STATUS registers
    are now exercised); a real `build_ecp5.ps1` run (Build ID
    `20260820_074244`, default invocation, no special flags) also passed
    completely clean: **63.17 MHz PASS at 50 MHz required**, 12-13%
    LUT / 7% DFF utilization, "Program finished normally," no
    `--timing-allow-fail` needed.
- **RTL-004 (Timestamp Engine): real, implemented and integrated into
  `dfc_rtl024.sv`.** Implements ARCH-002 SS8.2's full ARCH-TIME-001 through
  006 contract: a 6-bit phase counter dividing CORE_CLK by 50 (first tick
  is the 50th valid edge after release, matching the spec exactly), a
  real always-running 64-bit raw timestamp that never stops regardless of
  TIME_CONTROL.ENABLE (the legacy field is forwarded for struct
  completeness but deliberately never gates the counter, per the spec's
  own explicit disclosure), real SNAPSHOT capture (pre-tick value, per
  ordinary nonblocking-assignment semantics), real COMMIT of a staged
  signed 64-bit correlation offset with a real 16-bit wrapping update
  sequence, and real signed-overflow/underflow detection via a genuine
  65-bit sign-extended addition (a disclosed interpretation, since REG-002/
  ARCH-002 give no bit-exact algorithm for this). Real cross-module
  register forwarding for all 12 REG-002 0x0200-0x022C registers
  (`TIME_CONTROL`/`TIME_STATUS`/`TIME_SNAPSHOT`/`TIME_RAW_LO`/
  `TIME_RAW_HI`/`TIME_SYNC_OFFSET_LO`/`TIME_SYNC_OFFSET_HI`/
  `TIME_SYNC_COMMIT`/`TIME_SYNC_STATUS`/`RTL004_EVT_OVERFLOW_STATUS`/
  `TIME_ACTIVE_OFFSET_LO`/`TIME_ACTIVE_OFFSET_HI`) via `reggen.py` v4 and
  `tools/reggen/rtl004_field_map.json`. Real, counted own-event generation
  (event ID 0x0009, source index 3, subtypes commit/arithmetic-error/
  snapshot, each gated by its own Appendix F.3 condition-mask bit) via the
  same one-deep pending-slot/overflow-counting shape already proven for
  RTL-002/RTL-003.
  - **THE REAL, CONFIRMED TIMESTAMP-BROADCAST GAP IS CLOSED:** RTL-002's
    and RTL-003's `timestamp_i` ports were previously hard-tied to `64'h0`
    in `dfc_rtl024.sv` with an explicit "RTL-004 does not exist yet"
    comment. Both now genuinely receive RTL-004's real, live raw counter
    via a single `rtl004_timestamp` net. Proven not just at the port
    boundary but with a real consumer: `rtl004_integration_tb.sv`
    instantiates a real RTL-002 alongside RTL-001/RTL-004 specifically to
    confirm RTL-002's own real `evt_record_o.TIMESTAMP` field is genuinely
    nonzero and tracks RTL-004's live counter monotonically, not the old
    stub.
  - **Three real ARCH-002 gaps were found and fixed, each with the
    person's explicit approval before any RTL was written** (full detail
    in `dfc_rtl004.sv`'s own header and `OPEN_ISSUES.md` items 7-9): (1)
    `dfc_rtl004_control_t` (70 bits) had no clear-request field for
    `TIME_STATUS.SNAPSHOT_VALID`/`SYNC_VALID` (2 of its 4 real W1C bits) --
    grown to 72 bits; (2) the same already-known `EVENT_OVERFLOW`-clear
    gap already fixed for RTL-002/RTL-003 recurred for RTL-004's own
    `RTL004_EVT_OVERFLOW_STATUS` -- exactly as predicted in this
    document's own lessons-learned (see the RTL-003 entry above) -- grown
    to 73 bits; (3) `dfc_rtl004_status_t` (105 bits) had no field at all
    to carry the real active correlation offset back to
    `TIME_ACTIVE_OFFSET_LO`/`_HI` (both `readback: external`, no other
    real data source) -- grown to 169 bits. All three used the identical
    growth-at-new-highest-bit pattern already established, confirmed via
    a real `regenerate.ps1` run that every pre-existing field's bit
    position in both structs is unchanged.
  - **Two further real, disclosed resolutions, neither requiring an
    ARCH-002 edit** (`OPEN_ISSUES.md` items 10-11): ARCH-002's own RTL-004
    port-catalog table lists a self-referencing `timestamp_i` input
    (producer and consumer both "RTL-004") that directly contradicts
    RTL-004_RevA.md's own explicit text ("RTL-004 does not consume its own
    output; it is the origin") — treated as a table-generation artifact
    (same resolution style as the RTL-003 `host_irq_n_o` conflict);
    `dfc_rtl004.sv` has 13 real ports, not 14. Separately, RTL-004_RevA.md
    says "10 registers" where REG-002 (the owning document) says and
    lists 12 — resolved in favor of REG-002.
  - **Disclosed, real scope gaps, not silent no-ops:** `status_o.fault` is
    driven only by correlation-arithmetic-error evidence — ARCH-RTL004-001
    also names "illegal command" as a fault source, but
    `dfc_rtl004_control_t`'s `time_snapshot__capture`/
    `time_sync_commit__commit` are plain 1-bit command-pulse fields (unlike
    RTL-003's IRQ registers, forwarded at full 32-bit width specifically so
    RTL-003 can police its own reserved bits), so RTL-004 has no bit
    position to ever observe host-side reserved-bit misuse in the first
    place — the same underlying RTL-001 per-field-validation gap
    (`OPEN_ISSUES.md` item 4) manifesting differently here, not a new
    defect. `event_condition_enable_i`/`irq_condition_enable_i` are real
    ports tied to a disclosed stub (`64'h0`) since RTL-001 doesn't
    implement the underlying CONDITION_MASK storage/forwarding mechanism
    yet (`OPEN_ISSUES.md` item 6) — means none of RTL-004's own events can
    actually fire in this integration yet.
  - **Proven via a new, real integration testbench**,
    `rtl004_integration_tb.sv` (24/24 checks): a real host write via
    RTL-001's real DRI path genuinely changes RTL-004's real behavior
    (TIME_CONTROL, SNAPSHOT, COMMIT), and RTL-004's real internal state
    genuinely reaches back to a host register read (TIME_STATUS,
    TIME_RAW_LO/HI, TIME_ACTIVE_OFFSET_LO/HI, TIME_SYNC_STATUS) — including
    the real EVENT_OVERFLOW clear path and the real timestamp-broadcast
    check described above. **Additionally proven inside the actual RTL-024
    top-level integration**, not just in isolation: `rtl024_skeleton_tb.sv`
    was updated with a real SPI read of SUBSYS_READY confirming bit 3
    (RTL-004) reflects RTL-004's real readiness, white-box checks of
    RTL-004's own real ready/fault, and a check that the real
    `rtl004_timestamp` broadcast net genuinely advances during the
    existing long mandatory-init-timeout wait.
  - Every other existing testbench was checked for breakage from RTL-004's
    two new `dfc_rtl001.sv` ports (`rtl004_control_o`/`rtl004_status_i`,
    replacing 7 individual stub-tied status ports) the same way RTL-002's/
    RTL-003's integration required checking previously: `regbank_smoke_tb.sv`
    needed its Check 3 ("external field mirrors status_i combinationally")
    re-redirected a third time (SYS_STATUS -> IRQ_RAW_STATUS -> TIME_STATUS
    -> now EVT_STATUS, since TIME_STATUS is aggregated too as of this
    session); `dri_transaction_tb.sv` (`.*` wildcard instantiation) needed
    the two new ports declared/tied off, same class of fix as before. All
    confirmed via real, individual `iverilog`/`vvp` runs before the full
    regression, not assumed.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    8/8 testbenches (162/162 checks — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+27+13=162, not restated from memory), `formal.ps1`
    both `bmc` and `prove` tasks genuinely PASS (real k-induction against
    real RTL-001, unaffected by the RTL-004 changes), coverage check ran
    clean (32/353 registers textually referenced, up from 20/353, expected
    given RTL-004's own 12 registers are now exercised). A real
    `build_ecp5.ps1` run (Build ID `20260820_133515`, default invocation,
    no special flags) also passed completely clean: **65.52 MHz PASS at
    50 MHz required**, 13% LUT / 8% DFF utilization, "Program finished
    normally," no `--timing-allow-fail` needed.
  - **A real, genuine `build_ecp5.ps1` gap was found and fixed getting a
    clean build**, the same class of gap RTL-002 first hit (see this
    document's own Section 4 lesson on it): `dfc_rtl004.sv` was missing
    from both `$SourceFiles` and the synthesis `.ys` script's read order --
    the first `build_ecp5.ps1` attempt failed cleanly at the Yosys
    hierarchy-check stage ("Module `\dfc_rtl004' referenced... is not part
    of the design") rather than silently synthesizing a stale design.
    Fixed by adding it in both places, immediately after `dfc_rtl003.sv`,
    matching the existing pattern exactly.
- **RTL-005 (Event Logger): real, implemented and integrated into
  `dfc_rtl024.sv`.** Implements ARCH-002 SS8.3's full ARCH-EVT-001 through
  008 contract: 24 independent one-deep producer pending slots (one per
  producer, index 4 self-looped to RTL-005's own diagnostic-event
  generation per ARCH-002's own port catalog -- a genuine design, not a
  table-generation artifact like RTL-004's `timestamp_i` case), a real
  64x128-bit register-array event store (head/tail/level pointers, not
  aliased to the shared-buffer service), real overwrite-oldest-while-full
  behavior with a genuine nonrecursive exception for internally generated
  0x007E/0x007F diagnostic records, real CAPTURE_OLDEST/POP/CLEAR_ALL
  command handling (POP invalidates the snapshot per REG-002's own text;
  CLEAR_ALL has priority over POP and ordinary push and touches only
  head/tail/level, not producer slots or other sticky evidence), and real,
  counted own-diagnostic-event generation (event IDs 0x000A/0x007E/0x007F,
  source index 4) with its own one-deep pending layer identical in shape to
  every other module's own event generation. Real cross-module register
  forwarding for all 15 REG-002 0x0300-0x0338 registers (`EVT_CONTROL`,
  `EVT_STATUS`, `EVT_COUNT`, `EVT_OVERFLOW_COUNT`, `EVT_SOURCE_ENABLE`,
  `EVT_SNAPSHOT`, `EVT_DATA0`-`3`, `EVT_POP`, `EVT_CLEAR`,
  `EVT_DROP_SOURCE`, `EVT_ARB_STATUS`, `EVT_POP_ERROR_COUNT`) via
  `reggen.py` v4 and `tools/reggen/rtl005_field_map.json`.
  - **THE REAL, CONFIRMED EVENT-BUS GAP IS CLOSED:** RTL-002/003/004's own
    `evt_valid_o`/`evt_ready_i`/`evt_record_o` (previously genuinely
    unconsumed, tied to `()`/`1'b1`/`()` with an explicit "no RTL-005
    exists yet" comment) now genuinely reach RTL-005's real
    `evt_valid_i[1]`/`[2]`/`[3]`, and RTL-002's real `global_event_enable_o`
    now genuinely reaches RTL-005's real `global_event_enable_i`.
  - **One real ARCH-002 gap was found and fixed, with explicit approval,
    before this module was implemented** (OPEN_ISSUES.md item 12):
    `dfc_rtl005_control_t` had no clear-request field for
    `EVT_STATUS.SNAPSHOT_VALID` -- grown 128->129 bits, same
    growth-at-new-highest-bit pattern already established for items 2/7/8.
  - **One genuine, disclosed gap logged but NOT fixed this session**
    (OPEN_ISSUES.md item 14): REG-002 owns no
    `RTL005_EVT_OVERFLOW_STATUS`-equivalent register for RTL-005's own
    generic `status_o.event_overflow`/`event_drop_count` pair -- real and
    reachable internally (confirmed via a real, forced test), but with no
    REG-002 address, so the host can neither read nor clear it. Proposed
    fix (a 16th RTL-005-owned register) logged for a future decision, not
    silently invented.
  - **A real, pre-existing testbench gap was found and fixed** while
    checking every existing `dfc_rtl001` instantiation site for breakage,
    not just the ones RTL-004's own session mentioned (OPEN_ISSUES.md item
    15): `rtl002_integration_tb.sv`/`rtl003_integration_tb.sv` were each
    missing `rtl004_control_o`/`rtl004_status_i` from their `dfc_rtl001`
    instantiation entirely (floating/undriven inputs, not merely
    stub-tied) since RTL-004's own integration session added those ports
    without updating either file.
  - **Proven via a new, real integration testbench**,
    `rtl005_integration_tb.sv` (37/37 checks): a real host write via
    RTL-001's real DRI path genuinely changes RTL-005's real behavior
    (EVT_SOURCE_ENABLE, EVT_SNAPSHOT, EVT_POP, EVT_CLEAR), and RTL-005's
    real internal state genuinely reaches back to a host register read
    (EVT_STATUS, EVT_COUNT, EVT_DATA0-3, EVT_POP_ERROR_COUNT) -- including
    a real RTL-004 SNAPSHOT-complete event (0x0009) genuinely arriving in
    RTL-005's real store and being genuinely host-readable via
    EVT_DATA0-3/EVT_POP (not a fabricated or injected value), the new
    SNAPSHOT_VALID clear-path fix, and RTL-005's own self-generation
    overflow layer. **Additionally proven inside the actual RTL-024
    top-level integration**: `rtl024_skeleton_tb.sv` was updated with a
    real SPI read of SUBSYS_READY confirming bit 4 (RTL-005) reflects
    RTL-005's real readiness, and a real check that RTL-002's own real,
    autonomous FAULTED-triggered event genuinely reached RTL-005's real
    store (EVT_STATUS.NOT_EMPTY/EVT_COUNT) through the real event-bus
    wiring, not a hierarchical force.
  - Every other existing testbench was checked for breakage from RTL-005's
    two new `dfc_rtl001.sv` ports (`rtl005_control_o`/`rtl005_status_i`,
    replacing 9 individual stub-tied status ports): `regbank_smoke_tb.sv`
    needed its Check 3 ("external field mirrors status_i combinationally")
    redirected a fourth time (SYS_STATUS -> IRQ_RAW_STATUS -> TIME_STATUS
    -> EVT_STATUS -> now GPIO_RAW_IN, since EVT_STATUS is aggregated too as
    of this session); `dri_transaction_tb.sv` (`.*` wildcard instantiation)
    and `rtl002/003/004_integration_tb.sv` (explicit named ports) all
    needed the new ports declared/tied off. All confirmed via a real,
    individual `iverilog`/`vvp` run before the full regression.
  - **CONFIRMED, end-to-end, on the person's real machine -- a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    9/9 testbenches (**205/205 checks** -- verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+33+13=205, not restated from memory), `formal.ps1`
    both `bmc` and `prove` tasks genuinely PASS (real k-induction against
    real RTL-001, unaffected by the RTL-005 changes), coverage check ran
    clean (42/353 registers textually referenced, up from 32/353, expected
    given RTL-005's own 15 registers are now exercised). A real
    `build_ecp5.ps1` run (Build ID `20260820_200244`, default invocation,
    no special flags) also passed completely clean: **62.70 MHz PASS at
    50 MHz required**, TRELLIS_COMB 19% / TRELLIS_FF 15% utilization
    (up from 12-13%/7-8% for prior modules, expected given the real
    64x128-bit event store plus 24x128-bit producer-slot array this module
    adds — roughly 11,000 additional flip-flops), "Program finished
    normally," no `--timing-allow-fail` needed.
  - **A real, genuine timing-closure bug was found and fixed getting this
    clean build — not a synthesis-tool artifact, and not fixed on the
    first attempt.** The round-robin arbiter's original code computed each
    of 24 candidates' rotated index via a conditional-subtract (an
    adder/comparator) chained together with the priority decision, 24
    deep — a real `nextpnr-ecp5` run confirmed this directly (Max
    frequency 44.21 MHz, FAIL at 50 MHz, critical path naming
    `dfc_rtl005.sv:348`). **A first fix attempt (parallelizing the 24
    per-candidate adders, still 24 real adders just no longer chained)
    made timing WORSE (38.14 MHz)** — confirmed via a real, subsequent
    build, not assumed; 24 real carry-chain (CCU2C) cells is expensive
    regardless of scheduling. **The real fix**: replaced per-candidate
    arithmetic entirely with the standard round-robin-arbiter technique —
    a REGISTERED priority mask (`rr_mask_q`), updated via one 5-bit
    increment feeding one barrel shift (`24'hFFFFFF << next_ptr`, muxes
    not carry chains), with arbitration itself reduced to two static
    bitwise ANDs and two fixed-position priority encoders (no runtime
    index arithmetic at all). This is what produced the clean 62.70 MHz
    closure above. Full detail, including the "why the first fix was
    wrong" lesson for RTL-006 onward, in `OPEN_ISSUES.md` item 17. All
    three code states were reconfirmed via a full Icarus regression
    (9/9 testbenches, 205/205 checks, unchanged throughout) — this was
    purely a timing-closure issue, never a functional/simulation one.
- **RTL-006 (GPIO Controller): real, implemented and integrated into
  `dfc_rtl024.sv`.** Implements ARCH-002 SS9's full ARCH-MON-001 contract:
  a real two-flop synchronizer plus millisecond-scale stable-time
  qualification counter per channel (qualification value zero passes
  through without delay; nonzero commits only after that many consecutive
  1ms samples agree, on a real free-running `ms_tick` generator assuming
  the project's nominal 50 MHz CORE_CLK), independently-masked rising/
  falling/active-high/active-low/either-edge subconditions per channel
  gated by the real Appendix F.3 condition-mask ports, the unconditional
  OE-gating equation (`direction && module_enable && effective_operational_
  enable && !TEST_DEBUG && !observational_mode`, structurally unconditional
  before any route/data logic via the registered-output reset branch), and
  real, counted own-diagnostic-event generation (event ID 0x0010, source
  index 5). Real cross-module register forwarding for all 15 REG-002
  0x0400-0x0438 registers via `reggen.py` v4 and
  `tools/reggen/rtl006_field_map.json`.
  - **THE REAL, CONFIRMED GPIO-PAD GAP IS CLOSED:** `gpio_i`/`gpio_o`/
    `gpio_oe_o` (previously hard-tied `8'h00`/`8'h00`/unconsumed with an
    explicit "RTL-006 not instantiated" comment) now genuinely reach a
    real `dfc_rtl006` instance, and from there the real external ECP5
    pads via `ulx3s_dfc_top.sv`'s new tristate wiring on `gp5`-`gp7`/
    `gp22`-`gp26` (J1 positions 5-7 + J2 positions 22-26, the first 8 of
    the 9 real, confirmed single-ended-only positions Section 4 of
    `ULX3S_CONNECTION_MAP.md` had reserved — see that document's own new
    Section 5 for the fetched-not-memorized site confirmation, `gp27`
    left as the one remaining open position). This is the first
    Infrastructure module in this build with a real, physical,
    bidirectional aircraft-facing interface, not a purely internal/logical
    one like RTL-002 through RTL-005.
  - **Two real ARCH-002-class gaps were found and fixed before/during this
    module's implementation, both explicitly anticipated by this session's
    own task instructions:**
    1. `dfc_rtl006_control_t` (122 bits) had no clear-request field for
       `RTL006_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` — the fifth real
       instance of this exact gap class (RTL-002/003's own EVT_OVERFLOW_
       STATUS, RTL-004's SNAPSHOT_VALID/SYNC_VALID, RTL-005's
       SNAPSHOT_VALID). Fixed the same way: ARCH-002 grew the struct
       122->123 bits, adding the new field at the new highest bit (122) —
       every pre-existing field's bit position confirmed unchanged via a
       real `regenerate.ps1` run. `OPEN_ISSUES.md` item 20.
    2. RTL-006's own real ARCH-002 port catalog names its `module_enable_i`/
       `effective_operational_enable_i` producers as `RTL-002.
       module_enable_o[5]`/`RTL-002.effective_operational_enable_o` — both
       real ports ARCH-002 already specified on RTL-002 (24 ports), but
       `dfc_rtl002.sv` implemented neither before this session (an
       implementation gap in already-shipped RTL-002, not a document gap,
       same class as `OPEN_ISSUES.md` item 5). Fixed by adding both as
       real outputs on `dfc_rtl002.sv` (`module_enable_o` = the real
       SUBSYS_ENABLE bitmap with mandatory bits forced on, ORed with the
       already-computed `effective_optional_enable` wire;
       `effective_operational_enable_o` = a direct passthrough of the
       already-computed `effective_operational_enable` wire) — zero new
       logic, just exposing two already-computed signals correctly.
       `OPEN_ISSUES.md` item 22.
  - **A real, previously-undiscovered gap in RTL-002/003/004's own
    already-shipped `RTLNNN_EVT_OVERFLOW_STATUS` registers was found while
    building `rtl006_field_map.json`, logged but NOT fixed this session
    (out of scope) — `OPEN_ISSUES.md` item 21:** each of those three
    modules' real host-WRITE (clear) path works, but none of their
    field-maps ever added the matching `status_registers` entry, so a host
    READ of any of those three registers' `EVENT_OVERFLOW`/`DROP_COUNT`
    fields still always returns zero via the OLD individual, permanently
    stub-tied status port — confirmed directly in the real generated
    `dfc_config_regbank_regs.sv`, not assumed. `rtl006_field_map.json`'s
    own `status_registers` section closes this for RTL-006 from the start
    (mapped onto the struct's existing generic `event_overflow`/
    `event_drop_count` fields), confirmed via a real host READ in
    `rtl006_integration_tb.sv` Part 6 — not a white-box check.
  - **A real, minor `extract_registers.py` bug was found while building the
    field-map, logged but NOT fixed this session (cosmetic only, does not
    affect generated protection/decode/forwarding behavior)** —
    `OPEN_ISSUES.md` item 23: `GPIO_DIR`'s real compound `Owner` field
    (`RTL-001 / RTL-006` in the source document) extracts as `RTL-006 /
    RTL-024` in the generated manifest; every other RTL-006 register with
    a plain single-value owner extracts correctly.
  - **Disclosed, real interpretations, not silent inventions** (full detail
    in `dfc_rtl006.sv`'s own header): "either-edge" (F.3 bits 32-39)
    implemented as an alternate gate for the same rise/fall-enabled edge
    signal, since REG-002/ARCH-002 give it no dedicated enable register or
    distinct C.7 event subtype of its own; "illegal configuration" (the
    module's own `ready`/`fault` contract) implemented as any channel's
    configured qualification time exceeding the real ARCH-VAL-006 0-100ms
    range (RTL-001 has no per-field range validation yet, so this value can
    genuinely reach `control_i` — same "defend against what RTL-001
    doesn't yet reject" precedent as RTL-003's reserved-bit handling);
    "unrecoverable qualification logic error" and the pad-assignment
    legality clause both have no real detection mechanism in this
    implementation, same class of disclosed gap as RTL-004/005's own
    fault-source disclosures; `route_gpio_req_i` (RTL-023.route_dest_o) is
    a real port permanently tied to a disclosed stub (8'h0), since
    RTL-022/023 are permanently out of scope for this build, not a
    "not yet built" gap like every other stubbed signal in this project.
  - **Proven via a new, real integration testbench**,
    `rtl006_integration_tb.sv` (35/35 checks): a real host write via
    RTL-001's real DRI path genuinely changes RTL-006's real behavior
    (GPIO_DIR/GPIO_OUT driving the real `gpio_oe_o`/`gpio_o`), and a real,
    simulated external pin transition on `gpio_i` genuinely reaches a real
    host read of GPIO_SYNC_IN/GPIO_QUAL_IN through the real two-flop
    synchronizer — including a real test of the qualification timer
    genuinely rejecting a too-short transition and genuinely accepting a
    qualifying one (held a full simulated 1ms sample), real rising- and
    falling-edge and active-high-level event/irq generation, and the real
    host-READ-level RTL006_EVT_OVERFLOW_STATUS fix described above.
    **Additionally proven inside the actual RTL-024 top-level
    integration**: `rtl024_skeleton_tb.sv` was updated with a real SPI read
    of SUBSYS_READY confirming bit 5 (RTL-006) reflects RTL-006's real
    readiness, a real SPI write reaching `control_i` (GPIO_STATUS
    readback) with the real, correctly-gated consequence that
    `gpio_oe_o`/`gpio_o` stay low while RTL-002 is still in STARTUP (never
    NORMAL/DEGRADED in this stub topology — the same disclosed
    stub-topology consequence already established for RTL-002's own
    FAULTED outcome, not a defect), and a real external `gpio_i` pin
    transition reaching a real SPI read of GPIO_SYNC_IN.
  - Every other existing testbench was checked for breakage from RTL-006's
    two new `dfc_rtl001.sv` ports (`rtl006_control_o`/`rtl006_status_i`,
    replacing 6 individual stub-tied status ports) and from `dfc_rtl002.sv`'s
    two new ports (`module_enable_o`/`effective_operational_enable_o`):
    `regbank_smoke_tb.sv` needed its Check 3 ("external field mirrors
    status_i combinationally") redirected a fifth time (SYS_STATUS ->
    IRQ_RAW_STATUS -> TIME_STATUS -> EVT_STATUS -> GPIO_RAW_IN -> now
    ROTOR_STATUS, since GPIO_RAW_IN is aggregated too as of this session)
    and needed the two new `dfc_rtl001` ports removed from its own
    `dfc_config_regbank_regs` instantiation (the individual
    `gpio_raw_in_status_i`/`gpio_sync_in_status_i`/`gpio_qual_in_status_i`/
    `gpio_event_status_status_i`/`rtl006_evt_overflow_status_status_i`
    ports it explicitly declared/connected no longer exist on the
    regenerated module — this incidentally also fixed a real, pre-existing
    gap: this file never declared/connected `gpio_status_status_i` at all,
    a floating-input bug now moot since that port no longer exists either);
    `dri_transaction_tb.sv` (`.*` wildcard instantiation of `dfc_rtl001`)
    and `rtl002/003/004/005_integration_tb.sv` (explicit named ports) all
    needed the two new `dfc_rtl001` ports declared/tied off;
    `rtl002_state_tb.sv` (`.*` wildcard instantiation of `dfc_rtl002`)
    needed the two new `dfc_rtl002` ports declared (unused, tied for
    wildcard elaboration); `rtl002_integration_tb.sv`/
    `rtl004_integration_tb.sv` (explicit named ports for `dfc_rtl002`)
    needed the same two new ports tied open. All confirmed via a real,
    individual `iverilog`/`vvp` run before the full regression, not
    assumed.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    10/10 testbenches (**254/254 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+35+47+13=254, not restated from memory),
    `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-006 changes),
    coverage check ran clean (57/353 registers textually referenced, up
    from 42/353, expected given RTL-006's own 15 registers are now
    exercised). A real `build_ecp5.ps1` run (Build ID `20260821_090802`,
    default invocation, no special flags) also passed completely clean:
    **62.21 MHz PASS at 50 MHz required**, real critical path 1.94 ns
    logic + 12.45 ns routing, **TRELLIS_COMB 20% / TRELLIS_FF 16%**
    utilization (up from RTL-005's 19%/15%, a modest, expected increase
    given RTL-006's own per-channel synchronizer/qualification/edge-
    detection logic), "Program finished normally," no
    `--timing-allow-fail` needed.
- **RTL-007 (Rotor RPM Monitor): real, implemented and integrated into
  `dfc_rtl024.sv`.** The first Monitoring-domain module. Implements
  ARCH-002 SS9's ARCH-MON-002/003/005 contract: a two-flop CDC-PULSE
  synchronizer on the real `rotor_i` pad, edge qualification against a
  real, live (not registered-and-lagged — see below) elapsed-cycle
  counter, hysteretic automatic period-mode/count-mode switching (2
  consecutive sub-1,000-cycle periods to enter count mode, 2 consecutive
  periods over 1,250 cycles to return), a real bit-serial 64-iteration
  shift-subtract RPM divider (ties round up via an explicit remainder
  test, real defended division-by-zero for PPR=0), real saturating
  16-bit RPM (never wraps), real LOW/HIGH hysteretic threshold latches,
  real no-edge TIMEOUT detection, and real, counted own-diagnostic-event
  generation (event ID 0x0030, source index 6, subtypes low/high/timeout/
  updated/saturation/recovery/configuration-reject per ARCH-002 Appendix
  C.7's own row for this ID). Real cross-module register forwarding for
  all 11 REG-002 0x2000-0x2028 registers (`ROTOR_CONTROL`/
  `ROTOR_THRESH_LOW`/`ROTOR_THRESH_HIGH`/`ROTOR_PULSES_PER_REV`/
  `ROTOR_TIMEOUT_US`/`ROTOR_EDGE_FILTER`/`ROTOR_HYSTERESIS`/
  `RTL007_EVT_OVERFLOW_STATUS` control forwarding; `ROTOR_STATUS`/
  `ROTOR_RPM`/`ROTOR_PERIOD_TICKS`/`RTL007_EVT_OVERFLOW_STATUS` status
  forwarding) via `reggen.py` v4 and `tools/reggen/rtl007_field_map.json`.
  - **THE REAL, CONFIRMED ROTOR PHYSICAL-PIN GAP IS CLOSED:** `rotor_i`
    (previously hard-tied `1'b0` in `dfc_rtl024.sv`) now genuinely reaches
    the real external `gp27`/J2-27 pad (the last remaining single-ended-
    only board position — see `ULX3S_CONNECTION_MAP.md`'s new Section 6
    for the fetched-not-memorized site confirmation, D13). RTL-007's own
    `irq_req_o` now genuinely reaches RTL-003's real `irq_source_i[8]`,
    and its `evt_valid_o`/`evt_record_o` now genuinely reach RTL-005's
    real `evt_valid_i[6]`/`evt_record_i[6]`. `fault_req_o` is a real
    output left genuinely unconsumed (RTL-013 does not exist yet), same
    disclosed pattern as RTL-005's own `fault_req_o`.
  - **One real ARCH-002 gap, found and fixed before this module was
    implemented, explicitly anticipated by this session's own task
    instructions** (the sixth real instance of this exact gap class):
    `dfc_rtl007_control_t` (135 bits) had no clear-request field for
    `RTL007_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` — grown 135->136 bits,
    same growth-at-new-highest-bit pattern already established.
    `rtl007_field_map.json`'s own `status_registers` section also closes
    the RTL-002/003/004-style host-READ gap (`OPEN_ISSUES.md` item 21)
    for RTL-007 from the start, same discipline RTL-006 already
    established.
  - **Two real, hard-won RTL/testbench lessons found and fixed during this
    module's own bring-up — kept in detail in `OPEN_ISSUES.md` items 26-27
    since both recur identically for RTL-008/009 (Engine RPM Monitor,
    Pulse/Frequency Monitor), which share ARCH-MON-002's identical
    edge-to-edge period measurement:**
    1. A same-cycle registered-copy read (the original `period_ticks_q`)
       lags one full measurement behind a live free-running counter read
       combinationally the same cycle — confirmed via a real simulation
       failure (ROTOR_RPM saturated to 0xFFFF, a real divide-by-zero
       substitute, because the divisor read a still-zero value one cycle
       before the real period ever became visible). Fixed by reading the
       live `cycles_since_accepted_q` counter directly everywhere a
       "just-completed period" value was needed, never through a
       registered intermediate.
    2. That same counter, reset to 0 on edge acceptance, under-reports the
       true elapsed-cycle count by exactly one when read combinationally
       at the moment of the NEXT acceptance. Fixed by resetting to 1
       instead (a "cycles elapsed including this one" counter), confirmed
       via a real, subsequent simulation showing an exact, bit-for-bit
       match against a testbench-driven 3000-cycle gap.
    3. (Testbench-side, not an RTL bug) a reusable "produce one edge, wait
       N more cycles" pulse-generator task's `N` argument controls the
       gap to the NEXT edge it produces, not the gap FROM whatever edge
       preceded the call — confirmed via two real, distinct simulation
       failures before landing on the fix: a second, distinct task
       (`rotor_edge_after`) that waits explicit N cycles THEN produces one
       edge THEN returns immediately, for every "one-off gap from
       whatever came before" use, keeping the original back-to-back-pair
       task only for exact, two-edges-spaced-exactly-N-apart use.
  - **A real, genuine Yosys `PROC_DFF` failure ("Multiple edge sensitive
    events found for this signal!") was found and fixed getting a clean
    `build_ecp5.ps1` run** — the exact same standing, project-wide
    compound-reset-condition rule already documented in this section
    (first found on `dfc_rtl002.sv`) was violated throughout
    `dfc_rtl007.sv`'s own first draft (`if (!core_rst_n_i || module_reset_i
    || !active) ...` in ten separate `always_ff` blocks) — every one
    restructured into the correct shape (the real async reset checked in
    its own, standalone top-level `if`, `module_reset_i`/`!active` in a
    subsequent `else if`), reconfirmed via a real, unchanged-behavior
    `sim.ps1` re-run (44/44 checks) before retrying the real build.
  - **Disclosed, real scope limits, not silent gaps:** `module_enable_i`
    (this module's own optional-mask port) gates all measurement/event/
    irq/fault activity together with `ROTOR_CONTROL.ENABLE` via a single
    derived `active` signal — the most conservative reading of the port's
    own documented "disabled module contributes no degraded/fault
    request" semantic; `operating_state_i`/`observational_mode_i` are
    real, structurally-required ports with no functional use (RTL-007's
    own spec never names either in an equation, unlike RTL-006's explicit
    OE contract); `ARCH-VAL-007`'s own "qualification 0-100 ms" clause has
    no corresponding real field anywhere in this module (disclosed,
    `OPEN_ISSUES.md` item 25, no functional consequence either way).
  - **Proven via a new, real integration testbench**,
    `rtl007_integration_tb.sv` (44/44 checks): a real host write via
    RTL-001's real DRI path genuinely changes RTL-007's real behavior
    (PPR/thresholds/hysteresis/timeout/edge-filter), and a real,
    testbench-driven pulse train on `rotor_i` (exact, known inter-edge
    gaps) genuinely produces a real, bit-exact RPM/period-ticks value
    through the real divider — including real LOW/HIGH enter/exit,
    real saturation/RANGE_ERROR, real no-edge TIMEOUT, real LOW-threshold
    event generation (0x0030, decoded exactly, not a fabricated value),
    real HIGH-threshold IRQ generation (captured over the real one-cycle-
    pulse window, not a delayed sample that would miss it), the real
    RTL007_EVT_OVERFLOW_STATUS host-read-and-clear round trip, and real
    illegal-configuration-to-fault detection. **Additionally proven inside
    the actual RTL-024 top-level integration**: `rtl024_skeleton_tb.sv`
    was updated with a real SPI read of SUBSYS_READY confirming bit 6
    (RTL-007) reflects RTL-007's real readiness, a real, protected
    SUBSYS_ENABLE write genuinely enabling the optional module-6 bit
    (RTL-007's entire measurement pipeline is gated by `module_enable_i`,
    unlike RTL-006's GPIO_SYNC_IN readback, which needs no such
    enable), and a real transition on this file's own external `rotor_i`
    top-level pin genuinely reaching a real host SPI READ of ROTOR_RPM
    (RPM=500, exact) — the concrete, physical-pad-level proof the gap is
    closed, not merely a port-boundary-level one.
  - Every other existing testbench was checked for breakage from
    RTL-007's two new `dfc_rtl001.sv` ports (`rtl007_control_o`/
    `rtl007_status_i`, replacing 4 individual stub-tied status ports):
    `regbank_smoke_tb.sv` needed its Check 3 ("external field mirrors
    status_i combinationally") redirected a sixth time (SYS_STATUS ->
    IRQ_RAW_STATUS -> TIME_STATUS -> EVT_STATUS -> GPIO_RAW_IN ->
    ROTOR_STATUS -> now ENGINE_STATUS, since ROTOR_STATUS is aggregated
    too as of this session); `dri_transaction_tb.sv` (`.*` wildcard
    instantiation) and `rtl002/003/004/005/006_integration_tb.sv`
    (explicit named ports) all needed the new ports declared/tied off.
    All confirmed via a real, individual `iverilog`/`vvp` run before the
    full regression.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    11/11 testbenches (**309/309 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+35+44+58+13=309, not restated from memory),
    `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-007 changes),
    coverage check ran clean (68/353 registers textually referenced, up
    from 57/353, expected given RTL-007's own 11 registers are now
    exercised). A real `build_ecp5.ps1` run (Build ID `20260821_132952`,
    default invocation, no special flags) also passed completely clean:
    **52.87 MHz PASS at 50 MHz required**, real critical path 2.18 ns
    logic + 12.22 ns routing = 14.40 ns, **TRELLIS_COMB 20% / TRELLIS_FF
    17%** utilization (comparable to RTL-006's 20%/16%, plus 2 real
    MULT18X18D hard blocks — 2/156, 1% — inferred for the bit-serial
    divider's period/count-mode dividend multiplies), "Program finished
    normally," no `--timing-allow-fail` needed. Real margin over the 50
    MHz requirement is narrower than prior modules (2.87 MHz vs. RTL-006's
    12.21 MHz) — expected given the real 64-iteration divider's own
    64-bit subtract/compare critical path is genuinely deeper than any
    prior module's own per-cycle arithmetic; worth a closer look if
    RTL-008/009's own, architecturally-identical dividers compound this
    further. `nextpnr-ecp5`'s own internal placement retry (a real,
    unprompted re-placement after an initial failed 48.71 MHz attempt,
    confirmed in the real log, not a script-level retry) is what produced
    the final, passing placement — the same real, evidenced
    nextpnr-internal-retry behavior this project has seen before (see
    `OPEN_ISSUES.md` item 18's own nextpnr-robustness note), not a
    concerning sign on its own.
- **RTL-008 (Engine RPM Monitor): real, implemented and integrated into
  `dfc_rtl024.sv`.** The second Monitoring-domain module, functionally
  identical to RTL-007 (same ARCH-MON-002/003/005 algorithm) applied to a
  completely independent engine edge input/register block/state, per
  ARCH-RTL008-001's own "separate state prevents rotor/engine coupling"
  requirement. Implements the identical CDC synchronizer, edge
  qualification, hysteretic period/count-mode switching, bit-serial
  64-iteration RPM divider, and threshold/timeout/event/irq mechanics as
  RTL-007, parameterized by its own real register set (engine's own
  0-20000 ARCH-VAL-008 range and 20,000-default HIGH threshold, vs.
  rotor's 0-1000/1,000). Real cross-module register forwarding for all 11
  REG-002 0x2100-0x2128 registers (`ENGINE_CONTROL`/`ENGINE_THRESH_LOW`/
  `ENGINE_THRESH_HIGH`/`ENGINE_PULSES_PER_REV`/`ENGINE_TIMEOUT_US`/
  `ENGINE_EDGE_FILTER`/`ENGINE_HYSTERESIS`/`RTL008_EVT_OVERFLOW_STATUS`
  control forwarding; `ENGINE_STATUS`/`ENGINE_RPM`/`ENGINE_PERIOD_TICKS`/
  `RTL008_EVT_OVERFLOW_STATUS` status forwarding) via `reggen.py` v4 and
  `tools/reggen/rtl008_field_map.json`. Real, counted own-diagnostic-event
  generation (event ID 0x0031, source index 7, same subtype scheme as
  RTL-007's own 0x0030).
  - **THE REAL, CONFIRMED ENGINE PHYSICAL-PIN GAP IS CLOSED:** `engine_i`
    (previously hard-tied `1'b0` in `dfc_rtl024.sv`) now genuinely reaches
    the real external `gp8`/J1-8 pad — **the first pin this project has
    assigned from the differential-capable range** (the single-ended-only
    range having been fully exhausted by RTL-007 — see
    `ULX3S_CONNECTION_MAP.md`'s own new Section 7 for the fetched-not-
    memorized site confirmation, A4, and the disclosed note that `gn8`
    (SITE A5) is now implicitly unavailable for a true LVDS pair with
    `gp8` if that range is ever needed for real differential signaling
    later). RTL-008's own `irq_req_o` now genuinely reaches RTL-003's real
    `irq_source_i[9]`, and its `evt_valid_o`/`evt_record_o` now genuinely
    reach RTL-005's real `evt_valid_i[7]`/`evt_record_i[7]`. `fault_req_o`
    is a real output left genuinely unconsumed (RTL-013 does not exist
    yet), same disclosed pattern as RTL-007's own.
  - **One real ARCH-002 gap, found and fixed before this module was
    implemented, approved before implementation (the seventh real instance
    of this exact gap class):** `dfc_rtl008_control_t` (135 bits) had no
    clear-request field for `RTL008_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` —
    grown 135->136 bits, same growth-at-new-highest-bit pattern already
    established. `rtl008_field_map.json`'s own `status_registers` section
    also closes the RTL-002/003/004-style host-READ gap (`OPEN_ISSUES.md`
    item 21) for RTL-008 from the start, same discipline RTL-006/RTL-007
    already established.
  - **A real, three-part timing-closure investigation into ALREADY-SHIPPED
    RTL-007 was required and completed this session, approved before any
    change to that file (`OPEN_ISSUES.md` item 31 has the full account):**
    RTL-007's own already-narrow 52.87 MHz margin could not absorb RTL-008
    duplicating its identical, genuinely expensive edge-qualification
    comparator and RPM-divider multiply. Confirmed as a real design-margin
    problem (not placement luck) via 4 real failed build attempts
    (default/-noabc9/two -Seed retries, 43-49 MHz) before touching any
    RTL. Three sequential real fixes, applied identically to both
    `dfc_rtl007.sv` and `dfc_rtl008.sv`: (1) replaced the 32-bit
    `cycles_since_accepted_q >= ctl_min_edge_cycles` magnitude comparator
    with a cheap equality-test-plus-sticky-latch (same architectural class
    as RTL-005's own round-robin-arbiter fix, `OPEN_ISSUES.md` item 17),
    with one disclosed, narrow behavioral difference (a live
    MIN_EDGE_CYCLES reduction strictly after the counter has already
    passed the new value doesn't retroactively qualify until the next
    accepted edge); (2) made the RPM divider's two mutually-exclusive
    multiplies' resource sharing explicit at the RTL level (mux inputs,
    not results) instead of relying on Yosys's own automatic sharing pass
    — a pure refactor, though its own first draft had a real, self-found
    regression (an accidentally 32-bit-widened second operand) that had to
    be caught and fixed; (3) pipelined the divider's own multiply into a
    new, isolated `MEAS_MULT` state (one extra CORE_CLK cycle of latency,
    65-cycle divide instead of 64 — negligible, already covered by every
    testbench's own generous margin), applied to BOTH the fresh-trigger
    path and the previously-overlooked "redo while busy" path. Verified via
    a full Icarus regression unchanged throughout all three fixes
    (12/12 testbenches, 368/368 checks).
  - **Disclosed, real interpretations, not silent inventions:** ARCH-VAL-008's
    own "qualification 0-100 ms" clause has no corresponding field anywhere
    in this module's real register set either (identical, almost-certainly
    copy-forward gap already logged for RTL-007, `OPEN_ISSUES.md` item 29)
    — zero functional consequence, disclosed rather than invented.
    `module_enable_i` gating and the unused `operating_state_i`/
    `observational_mode_i` ports follow the identical disclosed pattern
    already established for RTL-007.
  - **Proven via a new, real integration testbench**,
    `rtl008_integration_tb.sv` (47/47 checks): a real host write via
    RTL-001's real DRI path genuinely changes RTL-008's real behavior
    (thresholds/PPR/timeout/edge-filter scaled to the engine's own real
    0-20000 range), and a real, testbench-driven pulse train on `engine_i`
    genuinely produces a real, bit-exact RPM/period-ticks value through
    RTL-008's real divider — including real LOW/HIGH enter/exit, real
    saturation/RANGE_ERROR, real no-edge TIMEOUT, real LOW-threshold event
    generation, real HIGH-threshold IRQ generation, the real
    RTL008_EVT_OVERFLOW_STATUS host-read-and-clear round trip, real
    illegal-configuration-to-fault detection, and — per RTL-008_RevA.md
    SS6's own explicit verification obligation — a real, automated
    INDEPENDENCE check: a real `dfc_rtl007` instance driven with a
    genuinely different, simultaneous `rotor_i` pulse pattern is confirmed
    to leave RTL-008's own real `ENGINE_RPM` completely unaffected, and
    vice versa, in both directions. A real, self-found testbench-only bug
    (not a DUT bug) was found and fixed during this file's own bring-up —
    see `OPEN_ISSUES.md` item 30 for the full account (test period values
    too short relative to ARCH-MON-002's own 1,000-cycle period/count-mode
    hysteresis threshold silently tripped a genuine mode switch, freezing
    every subsequent RPM reading). **Additionally proven inside the actual
    RTL-024 top-level integration**: `rtl024_skeleton_tb.sv` was updated
    with a real SPI read of SUBSYS_READY confirming bit 7 (RTL-008)
    reflects RTL-008's real readiness, a real, protected SUBSYS_ENABLE
    write genuinely enabling the optional module-7 bit, and a real
    transition on this file's own external `engine_i` top-level pin
    (1500-cycle gap, PPR=1, genuinely saturating to RPM=0xFFFF — a
    deliberately different pulse gap/PPR combination than the ROTOR_RPM
    check, proving this is RTL-008's own real, independent divider result)
    genuinely reaching a real host SPI READ of ENGINE_RPM, plus a real
    check that RTL-007's own ROTOR_RPM state is genuinely unaffected by
    RTL-008's own pulse train just driven.
  - Every other existing testbench was checked for breakage from RTL-008's
    two new `dfc_rtl001.sv` ports (`rtl008_control_o`/`rtl008_status_i`,
    replacing 4 individual stub-tied status ports): `regbank_smoke_tb.sv`
    needed its Check 3 ("external field mirrors status_i combinationally")
    redirected a seventh time (SYS_STATUS -> IRQ_RAW_STATUS -> TIME_STATUS
    -> EVT_STATUS -> GPIO_RAW_IN -> ROTOR_STATUS -> ENGINE_STATUS -> now
    PULSE0_STATUS, since ENGINE_STATUS is aggregated too as of this
    session); `dri_transaction_tb.sv` (`.*` wildcard instantiation) and
    `rtl002/003/004/005/006/007_integration_tb.sv` (explicit named ports)
    all needed the new ports declared/tied off. All confirmed via a real,
    individual `iverilog`/`vvp` run before the full regression.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    12/12 testbenches (**368/368 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+35+44+47+70+13=368, not restated from memory),
    `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-008 changes),
    coverage check ran clean (78/353 registers textually referenced, up
    from 68/353 — 10 of RTL-008's own 11 registers now exercised,
    `ENGINE_EDGE_FILTER` untested by any real testbench just as RTL-007's
    own `ROTOR_EDGE_FILTER` is, a pre-existing, consistent gap, not new).
    A real `build_ecp5.ps1` run (Build ID `20260821_220624`, default
    invocation, no special flags, after all three real timing fixes above)
    also passed completely clean: **55.84 MHz PASS at 50 MHz required** —
    a WIDER margin than RTL-007 alone ever had (52.87 MHz), not just a
    narrow recovery — **TRELLIS_COMB 22% / TRELLIS_FF 17%** utilization,
    4/156 (2%) MULT18X18D hard blocks (2 per module, unchanged count from
    RTL-007 alone — the timing fixes changed HOW the multiplies are
    scheduled, not how many physical DSP blocks they use), "Program
    finished normally," no `--timing-allow-fail` needed.
- **RTL-009 (Pulse/Frequency Measurement): real, implemented and
  integrated into `dfc_rtl024.sv`.** The third and last Monitoring-domain
  module using ARCH-MON-002's edge-qualification/mode-selection algorithm,
  and the first module in this project with TWO fully independent
  measurement channels in a single module, sharing one physical 2-bit
  `pulse_i[1:0]` port. Each channel implements its own, entirely
  independent CDC synchronizer, edge qualification (sticky min-edge latch,
  "reset to 1 not 0" counter), hysteretic period/count-mode switching, and
  a pipelined-multiply bit-serial 64-iteration Q17.15 divider — the
  confirmed-working RTL-007/008 architecture (`OPEN_ISSUES.md` items
  26/27/30/31) applied to BOTH channels from the very first line written,
  not rediscovered a third time. Real cross-module register forwarding for
  all 19 REG-002 0x2200-0x2254 registers (`PULSE0_CONTROL`/`PULSE0_THRESH_
  LOW_Q17_15`/`PULSE0_THRESH_HIGH_Q17_15`/`PULSE0_TIMEOUT_US`/`PULSE0_EDGE_
  FILTER`/`PULSE0_HYSTERESIS_Q17_15`/`PULSE1_*` mirrors/`RTL009_EVT_
  OVERFLOW_STATUS` control forwarding; `PULSE0_STATUS`/`PULSE0_FREQ_Q17_
  15`/`PULSE0_PERIOD_TICKS`/`PULSE1_*`/`RTL009_EVT_OVERFLOW_STATUS` status
  forwarding) via `reggen.py` v4 and `tools/reggen/rtl009_field_map.json`.
  Real, counted own-diagnostic-event generation (event ID 0x0032, source
  index 8) shared by both channels through ONE pending slot.
  - **THE REAL, CONFIRMED PULSE PHYSICAL-PIN GAP IS CLOSED:** `pulse_i[1:0]`
    (previously hard-tied/unreferenced in `dfc_rtl024.sv`) now genuinely
    reaches the real external `gp9`/J1-9 and `gp10`/J1-10 pads — the next
    two positions in the differential-capable range after RTL-008's `gp8`
    (see `ULX3S_CONNECTION_MAP.md`'s own new Section 8 for the
    fetched-not-memorized site confirmation, A2/C4). RTL-009's own
    `irq_req_o` now genuinely reaches RTL-003's real `irq_source_i[10]`,
    and its `evt_valid_o`/`evt_record_o` now genuinely reach RTL-005's real
    `evt_valid_i[8]`/`evt_record_i[8]`. `fault_req_o` is a real output left
    genuinely unconsumed (RTL-013 does not exist yet), same disclosed
    pattern as RTL-005/007/008.
  - **One real ARCH-002 gap, found and fixed before this module was
    implemented, approved before implementation (the eighth real instance
    of this exact gap class):** `dfc_rtl009_control_t` (334 bits) had no
    clear-request field for `RTL009_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` —
    grown 334->335 bits, same growth-at-new-highest-bit pattern already
    established. `rtl009_field_map.json`'s own `status_registers` section
    also closes the RTL-002/003/004-style host-READ gap (`OPEN_ISSUES.md`
    item 21) for RTL-009 from the start, same discipline RTL-006/007/008
    already established.
  - **A real design this module genuinely needed that RTL-007/008 (single
    producer each) never did: shared-event-slot arbitration between two
    internal producers.** Both channels' own diagnostic events compete for
    ONE pending slot (dfc_rtl009.sv has a single `evt_valid_o`/`evt_ready_
    i`/`evt_record_o` triple, not one pair per channel, per the
    Architecture port catalog). Disclosed, locally-chosen priority (no
    spec guidance exists on cross-channel priority): channel 0 wins ties;
    the losing channel's candidate is genuinely counted as dropped (not
    silently lost), with `event_drop_count_q` incrementing by the actual
    number of losses in a single cycle (0, 1, or 2 — a real generalization
    beyond RTL-007/008's own single-producer, always-increment-by-1 shape).
    See `OPEN_ISSUES.md` item 33 for the real, disclosed gap this exposes
    (no channel-indicator bit exists anywhere in `dfc_event_record_t`, so a
    host must correlate an 0x0032 event against `PULSE0_STATUS`/
    `PULSE1_STATUS`'s own independent sticky bits to determine origin).
  - **Disclosed, real simplifications, genuinely different from and in one
    respect simpler than RTL-007/008:** RTL-009 has no PPR field at all, so
    (a) there is no analogous divide-by-zero defense needed (the divisor is
    always the live period-ticks counter, which is provably >=1, or a
    hardwired constant 1) and (b) the count-mode arithmetic uses a single
    disclosed, mathematically EXACT algebraic simplification
    ((50,000,000<<15)/100,000 = 16,384,000 exactly, for every edge_count
    value) to keep the multiply operand widths bounded, rather than a
    literal multiply-then-divide-by-100,000 reading that would need a
    ~73-bit intermediate. ARCH-VAL-009's own "qualification 0-100 ms"
    clause has no corresponding field, the third real instance of this
    class (`OPEN_ISSUES.md` item 34, same as items 25/29).
  - **Proven via a new, real integration testbench**,
    `rtl009_integration_tb.sv` (60/60 checks): real host writes via
    RTL-001's real DRI path genuinely change both channels' real behavior
    independently, real simulated pulse trains on BOTH `pulse_i[0]` and
    `pulse_i[1]` produce real, self-consistent Q17.15 frequency
    measurements in both period mode (exact-dividing gaps, bit-exact
    checks) and count mode (a real, hand-derived-and-then-simulation-
    confirmed 99-edge count over the real 100,000-cycle gate window,
    landing on the exact expected multiple of 16,384,000), real LOW/HIGH
    threshold enter/exit and IRQ generation, a real no-edge TIMEOUT, the
    real `RTL009_EVT_OVERFLOW_STATUS` host-read-and-clear round trip, a
    real forced two-producer shared-slot arbitration test (channel 0 wins,
    channel 1's loss is genuinely counted), real illegal-configuration-to-
    fault detection, and — per the task's own explicit requirement — a
    real, explicit channel-independence cross-check (channel 0 vs. channel
    1 within this single module, same pattern as RTL-008's own cross-check
    against RTL-007). **Three real, hard-won testbench-authoring lessons
    were found and fixed during this file's own bring-up, kept in
    `OPEN_ISSUES.md` item 35 for future modules:** the count-mode switch
    needs exactly three pulses, not two; an edge landing exactly on the
    count-mode gate boundary is genuinely not counted (reset wins the
    tie); and a missing settle delay between an inlined pulse pair's two
    edges shifts the measured period by exactly one cycle — invisible to
    RPM-rounding checks elsewhere in this project, but not to RTL-009's own
    exact Q17.15 division, which is what surfaced it (this last lesson
    also required a real, matching fix in `rtl024_skeleton_tb.sv`'s own new
    RTL-009 section, found the same way). **Additionally proven inside the
    actual RTL-024 top-level integration**: `rtl024_skeleton_tb.sv` was
    updated with a real SPI read of `SUBSYS_READY` confirming bit 8
    (RTL-009) reflects RTL-009's real readiness, a real protected
    `SUBSYS_ENABLE` write genuinely enabling the optional module-8 bit, and
    a real transition on this file's own external `pulse_i[0]` top-level
    pin (2000-cycle gap, genuinely producing 819,200,000 = 25,000 Hz)
    genuinely reaching a real host SPI READ of `PULSE0_FREQ_Q17_15`, plus a
    real check that RTL-008's own `ENGINE_RPM` state is genuinely
    unaffected by RTL-009's own pulse train just driven.
  - Every other existing testbench was checked for breakage from RTL-009's
    two new `dfc_rtl001.sv` ports (`rtl009_control_o`/`rtl009_status_i`,
    replacing 7 individual stub-tied status ports): `regbank_smoke_tb.sv`
    needed its Check 3 redirected an eighth time (... -> PULSE0_STATUS ->
    now SENSOR_STATUS, since PULSE0_STATUS is aggregated too as of this
    session); `dri_transaction_tb.sv` and `rtl002/003/004/005/006/008_
    integration_tb.sv` all needed the new ports declared/tied off. **A
    real, pre-existing gap was found and fixed while doing this same check
    for `rtl007_integration_tb.sv` specifically** (same class as
    `OPEN_ISSUES.md` item 15): that file's own `dfc_rtl001` instantiation
    was missing the `rtl008_control_o`/`rtl008_status_i` pair ENTIRELY
    (floating, not merely stub-tied) since RTL-008's own integration
    session never updated it — fixed alongside adding RTL-009's own pair.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    13/13 testbenches (**441/441 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+35+44+47+60+83+13=441, not restated from memory),
    `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-009 changes),
    coverage check ran clean (95/353 registers textually referenced, up
    from 78/353, expected given RTL-009's own 19 registers are now
    exercised). A real `build_ecp5.ps1` run (Build ID `20260822_151859`,
    default invocation, no special flags) also passed completely clean.
    **A genuine, real build gap was found and fixed to get there**: the
    first attempt failed at the Yosys hierarchy-check stage ("Module
    `\dfc_rtl009' referenced... is not part of the design") because
    `dfc_rtl009.sv` was missing from both `$SourceFiles` and the synthesis
    `.ys` script's read order — the same class of gap RTL-002/004 first
    hit (see this document's own Section 4 lessons on it) — fixed by
    adding it in both places, immediately after `dfc_rtl008.sv`. Once
    fixed: **52.14 MHz PASS at 50 MHz required** (confirmed from the real
    LAST "Max frequency" line in the real pnr.log — an EARLIER, pessimistic
    pre-route placement estimate in the same log read 41.92 MHz FAIL; the
    build manifest's own generated note explicitly warns "earlier lines in
    that log may show pessimistic pre-route estimates," and the real,
    final, post-route result is the one that counts), **TRELLIS_COMB 27% /
    TRELLIS_FF 19%** utilization (up from RTL-008's 22%/17%, expected given
    RTL-009 duplicates the divider architecture across two more channels),
    12/156 (7%) MULT18X18D hard blocks, "Program finished normally," no
    `--timing-allow-fail` needed — **the pipelined-multiply pattern applied
    to both channels from the start held real margin above 50 MHz without
    requiring any further change to already-shipped RTL-007/008**, closing
    the risk this document's own prior lessons-learned entry (Section 5)
    flagged before this module was written.
- **RTL-010 (Sensor Monitor Interface): real, implemented and integrated
  into `dfc_rtl024.sv`.** The fourth Monitoring-domain module, and the
  first with NO physical pin at all — confirmed directly against ARCH-002's
  own 16-port catalog before any RTL was written; sensor values arrive
  exclusively through host writes to the staged `SENSOR_UPDATE_SELECT`/
  `_VALUE`/`_META`/`_COMMIT` registers, not a dedicated external pad.
  `fpga/ecp5/ulx3s_dfc.lpf` and `ULX3S_CONNECTION_MAP.md` needed NO change
  for this module — a real, confirmed absence, not an oversight. Two
  independent signed 32-bit sampled-sensor channels with signed threshold/
  hysteresis comparison and an age/staleness model (ARCH-MON-006/007), the
  first module in this project needing genuine signed comparison
  arithmetic (`$signed()` casts, ordinary IEEE-1800 syntax with no
  toolchain finding against it). Real cross-module register forwarding for
  all 25 REG-002 0x2300-0x236C registers via `reggen.py` v4 and
  `tools/reggen/rtl010_field_map.json` (19 control registers, 10 status
  registers — every external RTL-010 register's host-READ path closed from
  the start, same discipline RTL-006 onward established). Real, counted
  own-diagnostic-event generation (event ID 0x0033, source index 9) shared
  by both channels PLUS the module-wide accepted/rejected commit events,
  through ONE pending slot (a 4-way shared-slot arbitration — reject >
  channel 0 > channel 1 > accept — the first module needing more than a
  2-way arbitration).
  - **One real ARCH-002 gap, found and fixed before this module was
    implemented, approved before implementation (the ninth real instance
    of this exact gap class):** `dfc_rtl010_control_t` (345 bits) had no
    clear-request field for `RTL010_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` —
    grown 345->346 bits, same growth-at-new-highest-bit pattern already
    established (`OPEN_ISSUES.md` item 36).
  - **A real, disclosed gap logged but NOT fixed this session** (a real
    dependency on RTL-021, which does not exist yet): ARCH-MON-007/
    ARCH-RTL010-001 both describe "host commit precedes ROUTED commit,"
    but ARCH-002's own 16-port catalog gives RTL-010 no port at all for a
    routed update — unlike the already-familiar `event_condition_enable_i`/
    `irq_condition_enable_i` stub pattern, there is no port here to tie off
    in the first place. `dfc_rtl010.sv` implements only the real host-commit
    half; the "host wins a same-cycle conflict against a routed commit"
    half of VP-MON-007 cannot be exercised until RTL-021 exists and
    ARCH-002 gains a real port for it (`OPEN_ISSUES.md` item 38).
  - **Resolved without an ARCH-002 edit** (same class as items 1/10/11/13/
    19/22): `RTL-010_RevA.md`'s own restated summary of Appendix F.3 index 9
    disagreed with ARCH-002's real table (missing the two module-wide
    update-accepted/update-rejected condition bits entirely) — resolved in
    favor of ARCH-002 (`OPEN_ISSUES.md` item 37).
  - **Four real, disclosed design interpretations**, each forced by a
    genuine gap rather than guessed: recovery shares its own condition's
    mask bit (no standalone recovery bit exists in RTL-010's own F.3 row,
    unlike RTL-007/008/009); layered enable gating derived directly from
    F.3's own preamble formula (per-channel-per-condition enables REPLACE,
    not AND with, the module-wide ones); the commit accept/reject
    precondition is `active`, and "all staged update members" describes
    atomicity, not a completeness check; and threshold evaluation runs
    continuously (every active cycle), not only at commit time, since
    thresholds are plain RW registers independent of the staged commit
    mechanism (`OPEN_ISSUES.md` item 39).
  - **Proven via a new, real integration testbench**,
    `rtl010_integration_tb.sv` (50/50 checks): real host writes via RTL-001's
    real DRI path genuinely change both channels' configuration
    independently, a real staged host commit atomically produces real
    value/valid/source/sequence/age readback, real channel independence
    checked in both directions, the complete signed representation
    (negative/zero/positive/INT32_MIN/INT32_MAX) against real signed LOW/
    HIGH comparison, hysteresis enter/exit at the exact real boundary, the
    real commit-rejection path (module disabled), a real, live 1 ms age
    tick proving `SENSOR0_CURRENT_AGE_MS` genuinely advances and
    `MAX_AGE_MS=0` genuinely disables staleness (not "stale after 0 ms"),
    the real `RTL010_EVT_OVERFLOW_STATUS` host-read-and-clear round trip,
    and real illegal-configuration-to-fault detection. **Additionally
    proven inside the actual RTL-024 top-level integration**:
    `rtl024_skeleton_tb.sv` was updated with a real SPI read of
    `SUBSYS_READY` confirming bit 9 (RTL-010) reflects RTL-010's real
    readiness, a real protected `SUBSYS_ENABLE` write genuinely enabling
    the optional module-9 bit, and a real staged commit driven entirely
    over this file's own external SPI pins reaching a real host SPI READ
    of `SENSOR0_VALUE`, plus a real check that RTL-009's own
    `PULSE0_FREQ_Q17_15` state is genuinely unaffected by RTL-010's commit.
  - Every other existing testbench was checked for breakage from RTL-010's
    two new `dfc_rtl001.sv` ports (`rtl010_control_o`/`rtl010_status_i`,
    replacing 10 individual stub-tied status ports): `regbank_smoke_tb.sv`
    needed its Check 3 redirected a ninth time (... -> SENSOR_STATUS ->
    now HEALTH_RAW_IN, since SENSOR_STATUS is aggregated too as of this
    session) and `dri_transaction_tb.sv` needed the new ports declared/tied
    off.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    14/14 testbenches (**508/508 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+35+44+47+60+50+100+13=508, not restated from
    memory), `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-010 changes),
    coverage check ran clean (120/353 registers textually referenced, up
    from 119/353 before the final SENSOR1_CURRENT_AGE_MS coverage fix).
    **Two genuine, real build gaps were found and fixed to get there.**
    First: the initial `build_ecp5.ps1` attempt failed at the Yosys
    hierarchy-check stage ("Module `\dfc_rtl010' referenced... is not part
    of the design") because `dfc_rtl010.sv` was missing from both
    `$SourceFiles` and the synthesis `.ys` script's read order — the same
    class of gap RTL-002/004/009 each hit before it — fixed by adding it in
    both places, immediately after `dfc_rtl009.sv`. Second, a real timing
    regression: two independent place-and-route runs then failed with the
    IDENTICAL result (47.98 MHz FAIL at 50 MHz), confirmed genuinely
    reproducible (not placement variance) before touching any RTL. The
    failing critical path was entirely inside the already-shipped
    `dfc_rtl024_spi_bridge.sv` (not RTL-010's own logic) — RTL-010's added
    die area evidently consumed just enough routing headroom to break an
    already-marginal SPI-bridge path (its own `B_WORD` state read a
    variable-index array 4 times combinationally in one cycle, feeding a
    chained CRC computation — the identical class of bug this file's own
    header already documented fixing once before on the write side).
    **Approval was sought and given before touching this already-shipped
    file** (per this session's own task instructions); fixed the same
    structural way, splitting `B_WORD` into `B_WORD_FETCH`/`B_WORD_CRC` so
    the array read is a plain register with no same-cycle combinational
    consumer (`OPEN_ISSUES.md` item 40). Verified end-to-end after the fix:
    the full 508/508-check regression unchanged, a real `gate.ps1` run
    clean, and a real `build_ecp5.ps1` run (Build ID `20260822_220658`)
    reaching **50.30 MHz PASS at 50 MHz required** (TRELLIS_COMB 29%/
    TRELLIS_FF 19% utilization, no `--timing-allow-fail`) — a narrow
    margin (under 1% headroom) flagged for RTL-011 onward the same way
    RTL-007's own narrow margin correctly predicted RTL-008's later
    regression (item 31).
  - **A later, dedicated fix-and-reverify session (2026-08-23) closed the
    real, root-cause architectural gap behind item 40's own narrow margin
    — not another reactive pipeline stage, and no new module work was
    started.** Confirmed directly by reading the file: `word_idx_q` (the
    write/capture-side index) and `build_word_idx_q` (the response-
    build-side index) into `rdata_words_q [0:15]` were BOTH purely
    sequential counters (start at 0, advance by exactly 1 per use, count
    up to the transaction's own word count, reset — never an arbitrary
    jump), meaning the array's real 16-way write demux and 16-way read
    mux existed only to serve access that was actually strictly
    sequential. Both of this file's own prior fixes (the original write-
    side capture-staging fix and item 40's `B_WORD_FETCH`/`B_WORD_CRC`
    split) had paid a real pipeline-latency cost to route AROUND that
    mux without ever removing it — which is exactly why RTL-010's own
    session hit a fresh regression in this same file at all (`OPEN_ISSUES.md`
    item 40): each new module's die area keeps eating into the same fixed
    routing budget the mux keeps consuming. **Replaced the array with a
    genuine 16-deep shift register** (`rdata_shift_q`, one single write
    process shared by both the capture and build sides, since the array
    used to be written from one process and read from the other): fixed
    insertion at index 0, a static point-to-point shift chain for every
    other position — no address decode of any kind. The former
    `capture_data_q`/`capture_idx_q`/`capture_pending_q` staging
    registers (which existed only to tolerate the now-removed write-side
    mux) are gone. **The one genuinely new piece of design**: since a
    transaction can capture 0-16 real words, the first word captured
    doesn't sit at a fixed position by itself, so a new response-builder
    state (`B_ALIGN`) pads the shift register with don't-care shifts
    (tracked by a new `shift_count_q` counter) until exactly 16 total
    shifts have occurred, after which the first captured word is ALWAYS
    at the fixed `rdata_shift_q[15]` — skipped entirely for a 0- or
    16-word transaction, which already need no padding. `B_WORD_FETCH`/
    `B_WORD_CRC` deliberately stay split exactly as item 40 left them
    (that pipeline cut's own value doesn't depend on whether a mux used
    to feed it, and un-splitting them was out of scope). New latency is
    bounded and justified the same way both prior fixes justified theirs:
    worst case 49 CORE_CLK cycles (980 ns @ 50 MHz) for the whole
    builder, comfortably inside DFC-INTF-0024's 1600 ns wait-fill budget
    at the fastest legal 10 MHz SCLK — and the write side is actually
    FASTER than before (the former 1-cycle capture-staging delay is gone,
    since the shift destination is now fixed rather than variable-
    indexed). **Verified the mux was actually removed, not just that
    timing happened to pass**, via a real, direct `nextpnr-ecp5` `Info:
    Device utilisation:` comparison against the immediately-preceding
    real build (`20260822_220658`): TRELLIS_COMB dropped from 25044 to
    24865 cells (both /83640) and TRELLIS_FF from 16432 to 16406 — real,
    absolute-count reductions, not a coincidence of placement (both
    builds used the same default, unseeded `build_ecp5.ps1` invocation);
    the rounded percentages read identically (29%/19%) in both builds,
    confirming why the raw counts, not the percentages, had to be the
    actual evidence. Verified end-to-end: a full Icarus regression
    (14/14 testbenches, **508/508 checks, unchanged** — a pure
    architectural refactor with zero functional regression, confirmed by
    hand-summing every testbench's own reported count:
    12+12+16+28+30+24+37+35+44+47+60+50+100+13=508), a real `gate.ps1`
    run (lint/sim/formal `bmc`+`prove`/coverage all clean, coverage
    unchanged at 120/353 — expected, since this fix touches no
    register-visible behavior), and a real `build_ecp5.ps1` run (Build
    ID `20260823_081313`, **53.69 MHz PASS at 50 MHz required** — a
    wider margin than item 40's own 50.30 MHz, not a narrow recovery).
    Full account, including the exact before/after utilisation table,
    in `OPEN_ISSUES.md` item 41. **Lesson for RTL-011 onward, superseding
    item 40's own "expect this margin to need attention again" warning:**
    where a variable-index array turns out to be addressed only
    sequentially (confirm this directly from the index variables' own
    update logic, never assumed), replacing it with a shift register
    removes the mux/demux at its root instead of buying temporary
    headroom by pipelining around it — worth checking for on any future
    module whose own per-word/per-slot storage looks superficially like
    genuine random access but, on inspection, never actually is.
- **RTL-011 (System Health Monitor): real, implemented and integrated into
  `dfc_rtl024.sv`.** The fifth and final Monitoring-domain module,
  completing that domain. Confirmed before any code was written that its
  real architecture parallels RTL-006 (GPIO)'s own two-flop-synchronizer/
  millisecond-qualification-timer skeleton, not RTL-007-010's divider
  architecture — adapted for 8 dedicated health-discrete channels with
  ARCH-MON-008's own two-counter qualification-attempt-failure mechanism
  (a genuinely new piece of design RTL-006 never needed) and sticky
  active/recovered evidence (independently timed and cleared — recovery
  does not clear sticky-asserted, per RTL-011_RevA.md SS3's own explicit
  warning). Real cross-module register forwarding for all 15 REG-002
  0x2400-0x2438 registers (`HEALTH_CONTROL`/`HEALTH_POLARITY`/
  `HEALTH_FAULT_ENABLE`/`HEALTH_EVENT_ENABLE`/`HEALTH_IRQ_ENABLE`/
  `HEALTH_QUAL_0_3`/`_4_7`/`HEALTH_STICKY`/`RTL011_EVT_OVERFLOW_STATUS`
  control forwarding; `HEALTH_RAW_IN`/`HEALTH_SYNC_IN`/`HEALTH_QUAL_IN`/
  `HEALTH_ACTIVE`/`HEALTH_STICKY`/`RTL011_EVT_OVERFLOW_STATUS`/
  `HEALTH_QUALIFICATION`/`HEALTH_STATUS` status forwarding) via `reggen.py`
  v4 and `tools/reggen/rtl011_field_map.json`. Real, counted own-diagnostic
  event generation (event ID 0x0034, source index 10, subtypes asserted/
  qualification-failure/recovery per ARCH-002 Appendix C.7's own row for
  this ID).
  - **THE REAL, CONFIRMED HEALTH PHYSICAL-PIN GAP IS CLOSED:** `health_i[7:0]`
    (previously hard-tied `8'h00`) now genuinely reaches the real external
    `gp14`-`gp21`/J2-14 through J2-21 pads — confirmed to need 8 real
    physical pins (not zero, unlike RTL-010) directly against ARCH-002's
    own 17-port catalog and the CDC-HEALTH table entry before writing any
    RTL. This consumes the ENTIRE remaining unshared differential-capable
    pin range in one module — see `ULX3S_CONNECTION_MAP.md`'s own new
    Section 9 for the fetched-not-memorized site confirmation
    (U18/N17/N16/L16/H18/F17/D18/C18) and the explicit flag that only the
    WiFi-shared `gp11`-`gp13` remain open afterward (`OPEN_ISSUES.md` item
    47). RTL-011's own `irq_req_o` now genuinely reaches RTL-003's real
    `irq_source_i[12]`, and its `evt_valid_o`/`evt_record_o` now genuinely
    reach RTL-005's real `evt_valid_i[10]`/`evt_record_i[10]`.
    `fault_req_o` is a real output left genuinely unconsumed (its
    architected destination, RTL-013.fault_source_i[4], "System-health
    aggregate fault," does not exist yet), same disclosed pattern as every
    other not-yet-connected `fault_req_o` in this integration.
  - **One real ARCH-002 gap, found and fixed before this module was
    implemented, approved before implementation (the tenth real instance
    of this exact gap class):** `dfc_rtl011_control_t` (121 bits) had no
    clear-request field for `RTL011_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` —
    grown 121->122 bits, same growth-at-new-highest-bit pattern already
    established. `rtl011_field_map.json`'s own `status_registers` section
    also closes the RTL-002/003/004-style host-READ gap (`OPEN_ISSUES.md`
    item 21) for every external RTL-011 register from the start, same
    discipline RTL-006 through RTL-010 already established.
  - **Resolved without an ARCH-002 edit, same resolution style as items
    1/10/11/13/19/22/37:** `RTL-011_RevA.md`'s own restated register count
    (13) disagreed with REG-002's real, owning 15-register block summary —
    resolved in favor of REG-002 (`OPEN_ISSUES.md` item 44).
  - **A real, disclosed architectural finding, confirmed by direct
    algebraic analysis before the testbench was ever written, not
    discovered by a failing guess:** for a 1-bit-per-channel input,
    qualification-ATTEMPT-FAILURE (ARCH-MON-008's own "no commit within
    `min(255,4xQ)` samples" condition) is mathematically unreachable via
    any external drive pattern — `attempt_limit` is provably always `>= Q`
    for the same live Q, so a continuously-disagreeing 1-bit channel always
    commits at or before its own attempt window closes. The mechanism
    itself is still real and correct by construction (confirmed via a
    related, genuine same-cycle race this analysis surfaced and fixed at
    the sole Q=255 tie boundary); `rtl011_integration_tb.sv` cannot
    externally trigger it, same disclosed reachability-gap class as
    RTL-010's own untestable routed-commit half of VP-MON-007. Full
    derivation in `dfc_rtl011.sv`'s own header and `OPEN_ISSUES.md` item
    45.
  - **Proven via a new, real integration testbench**,
    `rtl011_integration_tb.sv` (60/60 checks): real host writes via
    RTL-001's real DRI path genuinely change RTL-011's real behavior across
    all 8 channels, and real simulated external transitions on `health_i`
    genuinely produce correct synchronized/qualified/sticky-latched results
    — including a real, genuinely-too-short transition correctly rejected
    and a genuinely-qualifying one correctly accepted (matching RTL-006's
    own precedent), RTL-011_RevA.md SS5's own dedicated case (force active
    → sticky sets → force inactive → confirm recovered pulses once AND
    sticky remains set until an explicit clear, with the "pulses once, not
    a level" claim confirmed by clearing RECOVERED and proving it stays
    clear), polarity inversion, the aggregate-fault equation (a
    fault-disabled active channel doesn't contribute; a fault-enabled one
    does, live not sticky), real event/irq generation with bit-exact
    subtype/channel/detail-field packing, the real `RTL011_EVT_OVERFLOW_
    STATUS` host-read-and-clear round trip, and real illegal-configuration-
    to-fault detection (deliberately distinct from the aggregate fault
    signal — see the module's own header). Two real testbench-authoring
    lessons were found and fixed during this file's own bring-up, kept
    here since they generalize: (1) a register write that reconfigures a
    channel's own polarity away from its RESET-DEFAULT value can itself
    produce a real, genuine active-to-inactive transition (since the
    default polarity is active-LOW and every channel starts at a
    zero/low qualified value) — any future module whose own reset-default
    configuration interacts with a live input value this way should clear
    resulting sticky evidence before relying on a "clean" baseline in a
    later test part; (2) a real register write that requires PROTECT_KEY
    authorization (confirmed directly against the generated regbank's own
    `protected_o` output per register, not assumed from REG-002's prose
    alone) silently no-ops without it — checking only the LAST of several
    back-to-back writes' own response code missed this. **Additionally
    proven inside the actual RTL-024 top-level integration**:
    `rtl024_skeleton_tb.sv` was updated with a real SPI read of
    `SUBSYS_READY` confirming bit 10 (RTL-011) reflects RTL-011's real
    readiness, a real protected `SUBSYS_ENABLE` write genuinely enabling
    the optional module-10 bit, and a real transition on this file's own
    external `health_i[0]` top-level pin genuinely reaching a real host SPI
    read of `HEALTH_SYNC_IN`/`HEALTH_ACTIVE`, plus a real check that
    RTL-010's own `SENSOR0_VALUE` state is genuinely unaffected by RTL-011's
    commit.
  - Every other existing testbench was checked for breakage from RTL-011's
    two new `dfc_rtl001.sv` ports (`rtl011_control_o`/`rtl011_status_i`,
    replacing 8 individual stub-tied status ports — `health_raw_in`/
    `health_sync_in`/`health_qual_in`/`health_active`/`health_sticky`/
    `rtl011_evt_overflow_status`/`health_qualification`/`health_status`):
    `regbank_smoke_tb.sv` needed its Check 3 redirected a tenth time
    (... -> HEALTH_RAW_IN -> now WDOG_STATUS, since HEALTH_RAW_IN is
    aggregated too as of this session) and its own individual RTL-011
    status_i declarations/connections removed entirely; `dri_transaction_tb.sv`
    (`.*` wildcard instantiation) needed the new ports declared/tied off.
    `rtl002` through `rtl010_integration_tb.sv`'s own `dfc_rtl001`
    instantiations were checked directly and confirmed NOT to break (named
    port connections, not `.*` wildcards — an unconnected new port is
    legal Verilog, not a compile error) — they simply don't exercise
    RTL-011's own register pair, a disclosed, pre-existing, non-breaking
    gap already true of RTL-010's own pair in those same files before this
    session, not something this session introduced.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED, `sim.ps1`
    15/15 testbenches (**581/581 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+37+35+44+47+60+50+60+113+13=581, not restated from
    memory), `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-011 changes),
    coverage check ran clean (134/353 registers textually referenced, up
    from 120/353, expected given RTL-011's own 15 registers are now
    exercised).
    **One genuine, real build gap was found and fixed to get a clean
    build**, the same class of gap RTL-002/004/009/010 each hit before it:
    the first `build_ecp5.ps1` attempt failed at the Yosys hierarchy-check
    stage ("Module `\dfc_rtl011' referenced... is not part of the design")
    because `dfc_rtl011.sv` was missing from both `$SourceFiles` and the
    synthesis `.ys` script's read order — fixed by adding it in both
    places, immediately after `dfc_rtl010.sv` (`OPEN_ISSUES.md` item 46).
    Once fixed, a real `build_ecp5.ps1` run (Build ID `20260826_152459`,
    default invocation, no special flags) passed completely clean:
    **50.12 MHz PASS at 50 MHz required** (real critical path 2.18 ns
    logic + 10.81 ns routing = 12.99 ns, confirmed from the real, final,
    post-route "Max frequency" line — an EARLIER, pessimistic pre-route
    estimate in the same log read 41.44 MHz FAIL, same "earlier lines can
    be pessimistic" caveat this project's own build manifest always
    carries), **TRELLIS_COMB 25221/83640 (30%) / TRELLIS_FF 16641/83640
    (19%)** utilization, 12/156 (7%) MULT18X18D, "Program finished
    normally," no `--timing-allow-fail` needed. **A real, narrow-margin
    flag, not glossed over:** this is only 0.12 MHz (0.24%) above the 50
    MHz requirement — narrower than RTL-010's own already-narrow 50.30 MHz
    (item 40) despite that session's later, dedicated root-cause fix
    (item 41) widening the SPI bridge's own margin to 53.69 MHz beforehand
    — meaning RTL-011's own added die area consumed essentially all of
    that regained headroom by itself. The build genuinely passed with no
    workaround, so no further action was taken this session per this
    project's own standing rule (only investigate/fix when a build
    actually fails) — but per the identical "expect this margin to need
    attention again" lesson RTL-007's own narrow margin already proved
    correct once (predicting RTL-008's later regression) and RTL-010's own
    narrow margin proved correct a second time (this module), **RTL-012
    onward should expect this margin to need real attention very soon,
    not treat 50.12 MHz as comfortable working room.**
- **RTL-012 (Watchdog Manager): real, implemented and integrated into
  `dfc_rtl024.sv`.** The first Safety-domain module. A protected, windowed
  service-timer with key checking, requesting lane 0 of the safety-response
  authorization matrix on timeout, per ARCH-002 SS10.3 `ARCH-SAFE-005`/
  Appendix F.1 `ARCH-RTL012-001`. Confirmed before any code was written
  that its own real register set (a microsecond free-running counter
  compared against two live boundaries) is closer in shape to RTL-004's
  own microsecond correlation-timer divider than to any Monitoring-domain
  module's divider/CDC architecture, and that RTL-002's own RESET_CONTROL/
  RESET_STATUS multi-cycle busy/assert/wait-ready command sequencer does
  NOT apply here — a watchdog service/recovery request resolves
  combinationally against the live elapsed counter in the same cycle the
  command pulse arrives, no multi-cycle busy state needed. Real
  cross-module register forwarding for all 8 REG-002 0x3000-0x301C
  registers (`WDOG_CONTROL`/`WDOG_WINDOW_OPEN_US`/`WDOG_TIMEOUT_US`/
  `WDOG_SERVICE`/`WDOG_STATUS`/`WDOG_RECOVERY`/`RTL012_EVT_OVERFLOW_STATUS`
  control forwarding; `WDOG_STATUS`/`WDOG_ELAPSED_US`/
  `RTL012_EVT_OVERFLOW_STATUS` status forwarding) via `reggen.py` v4 and
  `tools/reggen/rtl012_field_map.json`. Real, counted own-diagnostic event
  generation (event ID 0x0040, source index 11, subtypes early/late/
  missing-timeout/invalid-key/recovered/service-accepted per ARCH-002
  Appendix C.7's own row for this ID).
  - **NO PHYSICAL PIN, NO `module_enable_i`:** confirmed directly against
    RTL-012's own real 17-port catalog before writing any RTL — every port
    is the standard clock/reset/control/status/event/irq/fault group, an
    internal same-domain signal to a not-yet-existing sibling module
    (`response_req_o` → RTL-016, `service_activity_o` → RTL-015), or a
    broadcast input from an already-real module. Mandatory-class (Appendix
    D.1 bit 11, part of the `0x80F81F` mandatory mask), so unlike every
    Monitoring-domain module tested before it, its `SUBSYS_READY` bit is
    real and asserted from reset with no `SUBSYS_ENABLE` write needed at
    all (`OPEN_ISSUES.md` item 55). RTL-012's own `irq_req_o` now genuinely
    reaches RTL-003's real `irq_source_i[13]`, and its `evt_valid_o`/
    `evt_record_o` now genuinely reach RTL-005's real `evt_valid_i[11]`/
    `evt_record_i[11]`. `fault_req_o`/`response_req_o`/`service_activity_o`
    are real outputs left genuinely unconsumed (their architected
    destinations, RTL-013/RTL-016/RTL-015, do not exist yet).
  - **One real ARCH-002 gap, found and fixed before this module was
    implemented, approved before implementation (the eleventh real
    instance of this exact gap class):** `dfc_rtl012_control_t` (110 bits)
    had no clear-request field for
    `RTL012_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW` — grown 110→111 bits, same
    growth-at-new-highest-bit pattern already established
    (`OPEN_ISSUES.md` item 49).
  - **A genuine, new class of ARCH-002 internal inconsistency was found and
    resolved, with explicit approval, not silently:** Appendix F.3's own
    RTL-012 condition-mask row and Appendix C.7's own event-subtype row for
    ID 0x0040 — two tables inside the SAME owning document — don't align
    positionally (F.3 folds "late" and "missing" onto one bit; C.7 keeps
    them as two distinct subtypes; REG-002's real `WDOG_STATUS` has exactly
    4 sticky bits, matching neither table read literally). Resolved by
    keeping LATE and TIMEOUT/MISSING as two independently real, distinct
    conditions — proven as two independently-observed real event subtypes
    in `rtl012_integration_tb.sv` Parts 5 and 7. Full derivation in
    `dfc_rtl012.sv`'s own header and `OPEN_ISSUES.md` item 50.
  - **Two further real, disclosed, narrow gaps, neither requiring an
    ARCH-002 edit:** (1) this project's existing WO-CMD pulse-capture
    mechanism cannot distinguish a host writing exactly `0x00000000` to
    `WDOG_SERVICE` from "no write this cycle," so that one specific value
    is silently treated as no service attempt rather than
    `BAD_SERVICE_KEY` (`OPEN_ISSUES.md` item 51); (2)
    `WDOG_CONTROL.WINDOW_ENABLE` has no wired functional effect anywhere —
    `ARCH-SAFE-005` (the sole owning contract) never conditions any real
    equation on it (`OPEN_ISSUES.md` item 52).
  - **RECOVER/recovery-completion sequencing is a real, disclosed design**
    derived from `ARCH-RTL012-001`/`ARCH-VAL-012`/REG-3018's own text, not
    a bit-exact citation (no field exists to make it one): RECOVER is
    accepted only while genuinely timed out (clears the live condition but
    NOT sticky `TIMEOUT` evidence nor `RESPONSE_PENDING`); exactly one
    subsequent valid in-window service then completes recovery, clearing
    `RESPONSE_PENDING`. Full derivation in `dfc_rtl012.sv`'s own header and
    `OPEN_ISSUES.md` item 53.
  - **Proven via a new, real integration testbench**,
    `rtl012_integration_tb.sv` (59/59 checks): real host writes via
    RTL-001's real DRI path genuinely change RTL-012's real behavior, and
    every named `VP-SAFE-004` window boundary is its own real, exact test
    vector — EARLY at MIN_WINDOW-1, legal exactly at MIN_WINDOW, legal at
    MAX_WINDOW-1, and LATE exactly at MAX_WINDOW (the genuine simultaneous
    timeout/late-service race `ARCH-RTL012-001` names explicitly, proven
    with `TIMEOUT` genuinely setting while `SERVICE_ACCEPTED` genuinely
    stays clear on the identical cycle) — plus missing/timeout with no
    service at all, INVALID key independent of window position, full
    RECOVERY sequencing (both the accepted-while-timed-out and
    rejected-while-not-timed-out cases), the real
    `RTL012_EVT_OVERFLOW_STATUS` host-read-and-clear round trip, and real
    illegal-configuration detection (`MIN_WINDOW_US >= MAX_WINDOW_US`,
    `MAX_WINDOW_US == 0`, and `SAFETY_RESPONSE_MASK` reserved bits). Timing
    methodology disclosed in the file's own header: rather than blindly
    counting CORE_CLK cycles against a free-running tick generator, the
    file waits on the DUT's own live `elapsed_us_q` via a hierarchical
    reference (`wait (u_rtl012.elapsed_us_q == target)`) — legal, standard
    testbench practice, not synthesizable RTL — since one microsecond tick
    (50 cycles) comfortably exceeds a full DRI round trip (~4 cycles), the
    target is guaranteed stable for the whole write. **Two real testbench
    bugs were found and fixed during this file's own bring-up, kept here
    since they're a real, generalizable lesson:** (1) `WDOG_RECOVERY` is a
    REG-002-protected register — the first draft wrote it without the
    PROTECT_KEY sequence, so RTL-001 silently rejected it (protected
    error), leaving RTL-012 permanently timed out and causing every
    subsequent `wait_until_elapsed` call to block forever (elapsed_us_q
    could never again equal a target below the still-climbing live value)
    — a real, deterministic hang, not a flaky one, traced directly to the
    missing PROTECT_KEY dance once `$fflush` was added to the check tasks
    to unmask exactly where output stopped; (2) a boundary-proof check
    written as `elapsed_us_q > (last_boundary)` immediately after only a
    short, sub-one-tick wait can genuinely still read the OLD boundary
    value even when the timer correctly did not reset — fixed by checking
    `!= 0`/`>= known_nonzero` against a value the test itself first
    established via `wait_until_elapsed`, not a value inferred from timing
    assumptions alone.
  - **A real, pre-existing testbench gap, materially larger than any prior
    instance of this class, was found and fixed while checking every
    existing `dfc_rtl001` instantiation site (`OPEN_ISSUES.md` item 54):**
    8 of the 10 pre-existing per-module integration testbenches
    (`rtl002_integration_tb.sv` through `rtl009_integration_tb.sv`) were
    missing `rtl010_control_o`/`rtl010_status_i` AND `rtl011_control_o`/
    `rtl011_status_i` ENTIRELY (not merely stub-tied), since neither
    RTL-010's nor RTL-011's own session swept every existing testbench;
    `rtl010_integration_tb.sv` was likewise missing RTL-011's own pair.
    Fixed for all 10 files, confirmed via a real, direct `grep` across
    every file rather than trusting any single prior session's own account.
  - `regbank_smoke_tb.sv`'s Check 3 was redirected an eleventh time
    (`... → HEALTH_RAW_IN → WDOG_STATUS → now FAULT_STATUS`, since
    `WDOG_STATUS` is aggregated too as of this session) and its own
    individual RTL-012 `status_i` declarations/connections removed
    entirely; `dri_transaction_tb.sv` (`.*` wildcard instantiation) needed
    the new ports declared/tied off.
  - **`build_ecp5.ps1` needed NO edit for source discovery** — confirmed
    directly, not assumed: the `$SourceFiles` auto-discovery mechanism
    RTL-011's own session built (`OPEN_ISSUES.md` item 46's fix) already
    covers `rtl\safety\src\dfc_rtl012.sv` automatically, closing what would
    otherwise have been the fifth recurrence of the "forgot the new file"
    class of gap (`OPEN_ISSUES.md` item 56).
  - **A real timing-closure fix to already-shipped RTL-005 was needed and
    made, approved before implementation (`OPEN_ISSUES.md` item 57):** the
    first `build_ecp5.ps1` run after RTL-012 was added failed timing at
    47.73 MHz (FAIL at 50 MHz) — the real critical-path report named a
    chain entirely inside already-shipped code (RTL-010's status register
    → RTL-004's `error_q` → the SPI bridge's `rdata_shift_q` → RTL-005's
    `store_q[56]`), the exact same worst-path sink item 48's own prior
    investigation had already flagged as this design's own standing margin
    risk. Root cause: `dfc_rtl005.sv`'s `store_q[tail_q] <= slot_record_q
    [push_idx]` (a runtime-indexed 24:1 read-mux feeding a runtime-indexed
    64-way write, both in one cycle). Fixed by pipelining the store write
    into two cycles (same technique as item 41's own SPI-bridge fix) —
    the pointer/level bookkeeping is unchanged, only the 128-bit data
    payload's landing is delayed one cycle — with an explicit
    read-after-write forwarding mux on the `EVT_SNAPSHOT` read closing the
    one-cycle hazard this creates (a `CAPTURE_OLDEST`/POP of the
    just-pushed slot before its data lands). **The new test proving this
    (`rtl005_integration_tb.sv` Part 7) was verified to actually catch the
    regression it claims to catch**: a real, temporary negative-control run
    (forwarding reverted, then restored) confirmed the test genuinely FAILS
    without the fix, reading back stale data from an earlier test part
    instead of the real just-pushed record — not merely passing by
    coincidence. Full derivation in `dfc_rtl005.sv`'s own header and
    `OPEN_ISSUES.md` item 57.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean (after the RTL-005 fix above)**:
    `lint.ps1` PASSED (21 files compile/elaborate OK, no wildcard imports,
    no stub/TODO markers, `RTLSTD-ORG-001` filename check clean), `sim.ps1`
    16/16 testbenches (**660/660 checks** — verified by adding up each
    testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+43+35+44+47+60+50+60+59+127+13=660, not restated
    from memory — the +6 over RTL-012's own original 654 is
    `rtl005_integration_tb.sv`'s new Part 7, 37→43), `formal.ps1` both
    `bmc` and `prove` tasks genuinely PASS (real k-induction against real
    RTL-001, unaffected by either the RTL-012 or RTL-005 changes — one
    real, transient `basecase` solver crash was hit on an earlier run and
    confirmed non-reproducible via an immediate retry, `OPEN_ISSUES.md`
    item 56), coverage check ran clean (142/353 registers textually
    referenced, up from 134/353, exactly the expected +8 given RTL-012's
    own 8 registers are now exercised).
  - **A real `build_ecp5.ps1` run genuinely failed timing BEFORE the
    RTL-005 fix above** (Build ID `20260827_094707`): **47.73 MHz, FAIL at
    50 MHz required** — the real critical-path report named the RTL-005
    `store_q` bottleneck described above, confirmed to not touch
    `dfc_rtl012.sv`'s own logic at all. **After the RTL-005 fix, a real,
    subsequent `build_ecp5.ps1` run (Build ID `20260827_133447`) passed
    completely clean: `Program finished normally`, real critical path
    2.18 ns logic + 10.50 ns routing = 12.68 ns, and — the number that
    matters — the real, final, post-route Max frequency line reads
    `50.28 MHz (PASS at 50.00 MHz)`** (an earlier, pessimistic pre-route
    estimate in the same log read 39.73 MHz FAIL — the same "later lines
    are the real result" caveat this project's own build manifests always
    carry). Device utilisation: **TRELLIS_COMB 26144/83640 (31%),
    TRELLIS_FF 16828/83640 (20%), MULT18X18D 12/156 (7%)**. No
    `--timing-allow-fail` needed. **A real, notable margin improvement, not
    just a narrow recovery:** 50.28 MHz is a WIDER margin than RTL-011's
    own already-razor-thin 50.12 MHz, despite BOTH RTL-012's own new logic
    AND the RTL-005 fix's own two new pipeline registers adding real area —
    confirming the RTL-005 fix genuinely reduced the design's worst-path
    depth rather than merely trading one bottleneck for an equally-bad one.
    The new worst path (confirmed via the real, final critical-path report)
    now runs through the SPI bridge's own `dri_req_addr_o`/`dri_req_write_o`
    signal fan-out — a different bottleneck than RTL-005's former
    `store_q` write, exactly the "closing one bottleneck reveals the next-
    tightest one" pattern this project's own timing-closure history already
    established (item 31). The build genuinely passed with no workaround,
    so per this project's own standing rule (only investigate/fix when a
    build actually fails), no further timing work was done this session.
- **RTL-013 (Fault Manager): real, implemented and integrated into
  `dfc_rtl024.sv`.** The second Safety-domain module, and the sole
  consumer of the fixed 32-bit fault-source matrix (ARCH-002 Appendix
  C.6). Implements the full SS10.1 classification contract: per-bit
  ACTIVE/STICKY tracking with "new detection dominates clear" and "clear
  effective only when ACTIVE is zero," lowest-numbered-active-else-sticky
  primary-source selection, the fixed 0x00017FEF recoverability mask
  (decoded from the real forwarded control field, not a local literal —
  cross-checked bit-for-bit against Appendix C.6's own per-source class
  column), the level-vs-latched distinction between `degraded_req_o`
  (recoverable-active only) and `faulted_req_o` (nonrecoverable
  active-or-sticky), `safety_inhibit_o` (active-only nonrecoverable), a
  lane-1 `response_req_o` with a real LATCH_UNTIL_HOST_CLEAR level/latch
  policy (SS10.4's own analogous `LATCHED_REQUEST[c]` equation, the
  closest real cited precedent), TEST_FAULT_INJECT gated on qualified
  TEST_DEBUG, and real, counted own-diagnostic event generation (event ID
  0x0041, source index 12). Real cross-module register forwarding for all
  9 REG-002 0x3100-0x3120 registers via `reggen.py` v4 and
  `tools/reggen/rtl013_field_map.json`.
  - **THE REAL, CONFIRMED FAULT-SOURCE MATRIX GAP IS CLOSED for every bit
    whose real producer already exists in this build:** RTL-005's,
    RTL-007's, RTL-008's, RTL-009's, RTL-010's, RTL-011's, and RTL-012's
    own real `fault_req_o` outputs (previously each genuinely unconsumed)
    now genuinely reach RTL-013's real `fault_source_i[5]`/`[6]`/`[7]`/
    `[8]`/`[9]`/`[4]`/`[0]` respectively — the concrete, non-stub proof
    that the Monitoring-before-Safety build-order decision paid off.
    Bits whose producer doesn't exist yet (RTL-014/015/016, RTL-017
    through RTL-023) stay disclosed stub-zero.
  - **A real, pre-existing gap in already-shipped RTL-002 was found and
    closed**: ARCH-002's own RTL-002 port catalog already specified
    `degraded_req_i`/`faulted_req_i` (producer RTL-013), but `dfc_rtl002.sv`
    implemented neither until now — same class of gap as items 5/22/54
    (a sibling module's own port-catalog nonconformance surfacing during a
    later module's integration). Both are now real inputs, folded into the
    primary-state FSM as ADDITIONAL causes alongside the pre-existing
    `module_fault_i`-based mandatory/optional aggregation. Confirmed live
    end-to-end: forcing RTL-013's real `faulted_req_o` in
    `rtl024_skeleton_tb.sv` genuinely drives RTL-002 into FAULTED through
    this newly-wired path (that test's own RTL-013 section is deliberately
    sequenced AFTER the pre-existing 499,000-cycle mandatory-init-timeout
    wait, so both real paths get proven without one defeating the other).
  - **One real ARCH-002 struct-growth fix**, approved before implementation
    (the twelfth real instance of the EVENT_OVERFLOW-clear-field gap
    class): `dfc_rtl013_control_t` grew 112→113 bits.
  - **One real, newly-found `reggen.py` generator gap was found and fixed
    in the generator itself** (not worked around): `FAULT_RECOVERABLE_MASK`
    is a CONST register REG-311C requires to reject every write
    (ACCESS_ERROR), but still needs to forward its fixed value into
    RTL-013's own control struct — reggen.py's pre-existing "any
    control_registers entry clears write_illegal_o" rule was wrong for
    this first-ever CONST-only entry; fixed to fall back to the ordinary
    readback-based rule when every field in an entry is class CONST.
    Confirmed via a real regeneration diff that this is the ONLY register
    whose `write_illegal_o` changed, and every pre-existing RW/WO-CMD/W1C
    entry across all 12 consumer modules is unaffected.
  - **Disclosed designs for behaviors with no owning-document equation to
    cite** (CHTR-DOC-006): FAULT_RESPONSE.LATCH_UNTIL_HOST_CLEAR's own
    level/latch policy (a real, live bug was found and fixed here during
    testbench bring-up — `response_trigger` must gate on ACTIVE-only
    nonrecoverable evidence, not active-or-sticky, or the level policy
    could never auto-clear); the DEGRADED_STATUS ACTIVE/ENTRY/
    RECOVERY_AVAILABLE/RECOVERED lifecycle; event 0x0041's own four
    subtype definitions and their simultaneous-condition priority;
    ARCH-VAL-013's "test-active" qualifier (RTL-013 has no dedicated
    `test_active_i` port, so `operating_state_i == TEST_DEBUG` is used).
  - No physical pin, no `module_enable_i` (mandatory-class, matching
    RTL-012's own precedent, confirmed against RTL-013's real 19-port
    catalog before any code was written).
  - **Proven via a new, real integration testbench**,
    `rtl013_integration_tb.sv` (71/71 checks): real host writes via
    RTL-001's real DRI path genuinely change RTL-013's real behavior, and
    real fault conditions genuinely forced on already-real producer
    modules (RTL-007's rotor timeout, RTL-011's health fault — both
    instantiated for real in this testbench, not synthesized at RTL-013's
    own boundary) are genuinely observed and correctly classified,
    including the SS10.1 "clear ineffective while active" rule, the
    level-vs-latched distinction, and the real EVENT_OVERFLOW clear path
    (the twelfth real instance of that gap class). **Additionally proven
    inside the actual RTL-024 top-level integration**: `rtl024_skeleton_tb.sv`
    was extended with real SPI reads confirming SUBSYS_READY bit 12
    reflects RTL-013's real mandatory-class readiness with no
    SUBSYS_ENABLE write, plus a real, whole-system proof that TWO
    genuinely independent, simultaneously-forced real producers (RTL-011
    and RTL-007) both reach RTL-013's real fault-source matrix and that
    RTL-013's own real `faulted_req_o`/`degraded_req_o` reach RTL-002's
    real ports.
  - Every other existing testbench was checked for breakage from RTL-013's
    two new `dfc_rtl001.sv` ports (`rtl013_control_o`/`rtl013_status_i`,
    replacing 6 individual stub-tied status ports) and RTL-002's two new
    `degraded_req_i`/`faulted_req_i` ports: `regbank_smoke_tb.sv` needed
    its Check 3 redirected a twelfth time (`... → FAULT_STATUS → now
    ILOCK_STATUS`, since FAULT_STATUS is aggregated too as of this
    session) and its own individual RTL-013 `status_i` declarations
    removed entirely; `dri_transaction_tb.sv` (`.*` wildcard) needed the
    new port pair declared/tied off; `rtl002_integration_tb.sv`/
    `rtl004_integration_tb.sv` (explicit named ports) and
    `rtl002_state_tb.sv` (`.*` wildcard) needed the two new RTL-002 ports
    tied inactive; `rtl002` through `rtl012_integration_tb.sv` (10 files)
    plus `rtl012_integration_tb.sv` itself needed the RTL-013 stub pair
    added, confirmed via a real, direct check of every existing
    `dfc_rtl001` instantiation site rather than trusting scope alone.
  - **A real, hard-won testbench-authoring lesson**: a brand-new
    testbench with a completely missing clock generator produces total
    silence (zero output, clean exit) rather than an obvious error — see
    `OPEN_ISSUES.md` item 63. **A real, disclosed side effect of this
    project's own whole-system testbench growing long in simulated time**:
    RTL-012's own configured `WDOG_TIMEOUT_US` genuinely elapses for real
    by the time later sections run — see `OPEN_ISSUES.md` item 64.
  - **CONFIRMED, end-to-end, on the person's real machine — a real
    `gate.ps1` run passed completely clean**: `lint.ps1` PASSED (22 files),
    `sim.ps1` 17/17 testbenches (**756/756 checks** — verified by adding up
    each testbench's own individually-reported count from the real output:
    12+12+16+28+30+24+43+35+44+47+60+50+60+59+71+152+13=756, not restated
    from memory — the delta over RTL-012's own 660 baseline is
    `rtl013_integration_tb.sv`'s new 71 plus `rtl024_skeleton_tb.sv`'s
    growth from 113→152, both genuinely new coverage, not a discrepancy),
    `formal.ps1` both `bmc` and `prove` tasks genuinely PASS (real
    k-induction against real RTL-001, unaffected by the RTL-013 changes),
    coverage check ran clean (152/353 registers textually referenced, up
    from 142/353).
  - **A real, three-attempt timing-closure investigation was needed to get
    a clean `build_ecp5.ps1` run** — the fourth confirmation of
    PROJECT_CONTINUITY.md's own item-48 "wide fan-in hub" warning finally
    tipping over into a genuine failure, same discipline as items 17/31/
    40/41/57. First real attempt: **40.14 MHz, FAIL at 50 MHz** (12%
    utilization, ruling out resource exhaustion). Fix 1 (real,
    contributory): `dfc_rtl013.sv`'s own primary-source priority search
    had threaded a "found" flag through two 17-iteration `for` loops — the
    identical 17-deep serial-chain shape as RTL-005's own round-robin
    arbiter bug (item 17) — replaced with a genuine `casez` priority
    encoder (40.14→40.36 MHz, real but insufficient alone). Fix 2
    (investigated, confirmed NOT the actual cause, kept as a real, honest
    lesson): the critical path was named as running through already-
    shipped `dfc_rtl010.sv`'s own 64-bit signed subtraction
    (`ch0_range_ext`/`ch1_range_ext`, 31 bits wider than the 32-bit signed
    operands could ever need) — narrowed to 33 bits with explicit approval
    (a prior-shipped file), but a real, direct build-to-build comparison
    showed a BYTE-IDENTICAL post-route result, proving Yosys's own
    optimizer had already trimmed the unused width regardless of the
    declared RTL width. The narrowing was kept anyway (genuinely correct,
    harmless) but logged honestly as not the fix that worked. Fix 3 (the
    real fix): `rtl013_fault_source` in `dfc_rtl024.sv` — a brand-new,
    wide (7-source) combinational fan-in from physically-scattered real
    modules' own `fault_req_o` outputs feeding straight into RTL-013's own
    further logic — was itself a new instance of the exact "wide fan-in
    hub" pattern item 48 already flagged. Fixed with the same "capture
    this cycle, commit the next" technique already proven for the SPI
    bridge (item 41) and RTL-005's event store (item 57): registered the
    aggregation one CORE_CLK cycle before RTL-013 ever sees it. Full
    account in `OPEN_ISSUES.md` item 65. **CONFIRMED, end-to-end, on the
    person's real machine, after all three fixes**: a full Icarus
    regression (17/17 testbenches, 756/756 checks, unchanged throughout —
    confirming this was purely a timing-closure investigation, not a
    functional one), a real `gate.ps1` run (lint/sim/formal/coverage all
    clean), and a real `build_ecp5.ps1` run (Build ID `20260828_134327`,
    **50.19 MHz PASS at 50 MHz required**, TRELLIS_COMB 26057/83640
    (31%), TRELLIS_FF 16926/83640 (20%), MULT18X18D 12/156 (7%), no
    `--timing-allow-fail` needed). **Lesson for RTL-014 onward,
    reinforcing item 48's own warning with a real, now-proven fix
    pattern:** any new module creating its own wide aggregation across
    several already-scattered real producers (not merely "one more input
    to an existing hub") should have that aggregation's own output
    registered from the start, before it reaches further combinational
    logic.
- **RTL-014 (Interlock Engine): real, implemented and integrated into
  `dfc_rtl024.sv` (2026-10-02).** The third Safety-domain module. It
  evaluates eight atomically committed four-term expressions (AND / OR /
  3-of-4 / `(t0&t1)|(t2&t3)`, with per-term inversion), produces
  guarded-action permission and violation evidence, and requests lane 2 of
  the safety-response matrix (ARCH-SAFE-003/006, ARCH-RTL014-001,
  ARCH-VAL-014). Module spec corrected to `docs/rtl_specs/RTL-014_RevB.md`
  (Rev A retired: wrong 19-port list, "10 registers", no staging/commit
  detail). All 16 REG-002 0x3200-0x323C registers are forwarded for
  real through `tools/reggen/rtl014_field_map.json`. Full disclosed design:
  `dfc_rtl014.sv`'s own header and `OPEN_ISSUES.md` items 66-79.
  - **Decisions were made under the person's explicit "run it end to end,
    stop stopping" instruction**, not item-by-item approval. Every one is
    logged in OPEN_ISSUES 66-79 for review. Read those before extending
    RTL-014 or building RTL-016, its consumer.
  - **ARCH-002 growth.** `dfc_rtl014_control_t` grew 68→513 bits. It gained
    the REG-002-mandated selected-entry `SAFETY_RESPONSE_MASK` member (a
    REG-002-vs-ARCH-002 conflict), the 13th EVENT_OVERFLOW-clear field, and
    the complete 8×55-bit staged bank. `dfc_rtl014_status_t` grew 53→108
    bits for the five `ILOCK_ACTIVE_*` selected-entry readbacks, which
    previously had no status fields at all, then grew to 115 bits for the
    new REG-002 `ILOCK_STATUS.FIRST_ERROR_ENTRY`/`FIRST_ERROR_CODE` fields.
    Those closed REG-COH-003's first-error retention, and ARCH-VAL-014 now
    owns the field order and code table (item 69). Every pre-existing field
    kept its bit position (item 67).
  - **`reggen.py` v5: selector-indexed staged registers (item 68).** This
    is a genuinely new generator capability, needed because REG-COH-001/
    REG-3228/VP-SAFE-016 require 8 independent staged entries, but each
    STAGE_* register was a single store. The five STAGE_* registers are now
    8 stores each, written and read at `ILOCK_ENTRY_SELECT`, and the whole
    bank is forwarded to RTL-014. Outside RTL-014, the regeneration diff is
    two cosmetic lines (version header, one trailing comma). Every other
    consumer is byte-identical. A future module with a selector-indexed
    staging bank (RTL-015 monitors, RTL-016 channels, RTL-021 routes) can
    reuse this by declaring `indexed_registers` in its own field-map.
  - **THE `internal_source_vector` GAP IS CLOSED (item 76).** ARCH-002's
    `dragon_core_top.internal_source_vector[63:0]` never existed before.
    `dfc_rtl024.sv` now builds it per C.1 from real RTL-006/007/008/009/
    010/011/012/013/014 status, with bit 30 (RTL-015) a disclosed stub and
    bits 33-36 (RTL-022) permanently zero. **It is registered from the
    start** (`internal_source_vector_q`), applying the item-65 lesson
    proactively rather than after a failure.
  - **Wiring.** RTL-014's `fault_req_o` now reaches RTL-013
    `fault_source_i[1]` (C.6 "Interlock violation" — an earlier briefing
    wrongly said RTL-014 doesn't feed RTL-013). `irq_req_o` reaches
    RTL-003 `irq_source_i[15]`. Events reach RTL-005 slot 13, and
    ready/fault reach RTL-002 bit 13. `interlock_satisfied_o`/
    `interlock_inhibit_o`/`response_req_o` are real but unconsumed until
    RTL-016 exists. No physical pin (item 77). Mandatory class, ready from
    reset (D.1 bit 13).
  - **Same-edge guard rule (ARCH-SAFE-006 / VP-SAFE-007).** Violation,
    guard, inhibit, satisfied, response, and fault outputs all register
    from one evaluation on one edge. It is proven on every clock edge in
    `rtl014_integration_tb.sv` Part 6, and a real **negative control**
    (inhibit made one cycle late) was confirmed to fail that check. A
    violation on a freshly committed bank asserts on the very next edge
    (no grace period), also proven.
  - **Tests.**
    - `rtl014_integration_tb.sv`: 105/105 checks. It uses real RTL-006 GPIO
      pins as the term producer and a real RTL-013 as the fault consumer.
      It covers whole-bank atomicity (entry 7 bad → entries 0-6 not
      committed, prior bank and staged bank preserved), first error by
      entry and by field, every illegal term/operator/guard class, all
      four operators and inversion, sticky/latch policy, lane-2 priority,
      ENABLE=0, events, and the EVENT_OVERFLOW round trip.
    - `rtl024_skeleton_tb.sv`: 152→185 checks. It adds a real SPI
      stage+protected-commit and a real external `gpio_i[2]` pad driving a
      host-readable violation/guard change through the registered source
      vector, plus RTL-013 seeing fault source 1.
  - **Other testbench changes.** The RTL-014 stub pair was added to all 12
    `rtl0NN_integration_tb.sv` files and `dri_transaction_tb.sv`.
    `regbank_smoke_tb.sv` Check 3 was redirected a 13th time
    (ILOCK_STATUS → LLINK_STATUS); its 5 previously floating
    `ilock_active_*` inputs are now moot.
  - **Real lesson (item 79a): Git Bash on this machine has no `iverilog` on
    PATH.** An `iverilog ... | head` pipeline reports success even when
    the compiler was never found. All real compile/sim/build runs must use
    the PowerShell scripts or the PowerShell tool.
  - **New project-wide open question (item 74).** All 13 event producers
    put the C.5 *index* in `evt_record.source_id`, but C.5's "Source ID"
    column is index+1. Not fixed; it needs a decision.
  - **Verified on the person's machine.** `gate.ps1` passed clean:
    - lint PASSED;
    - `sim.ps1` 18/18 testbenches, **894/894 checks**, hand-summed from
      each testbench's own reported count:
      12+12+16+28+30+24+43+35+44+47+60+50+60+59+71+105+185+13=894;
    - `formal.ps1` `bmc` and `prove` both PASS;
    - coverage 168/353, up exactly 16 from 152, matching RTL-014's 16
      registers.

    **Real builds, three of them, every result reported:**
    1. Build `20261002_130553` (before the item-69 first-error fields)
       passed at 52.18 MHz.
    2. The final-tree build `20261002_164121` **FAILED at 48.41 MHz**
       (3.61 ns logic / 17.04 ns routing; router 11159 s). The worst path
       was entirely inside already-shipped RTL-005's push cone. Its
       lowest-set-bit encoders were "last assignment wins" `for` loops,
       which synthesize as a 24-deep serial chain (the same shape as item
       65 fix 1), feeding a binary-indexed 24:1 × 128-bit record read.
       RTL-014 made slot 13 a live producer, which widened that mux.
       Fixed in `dfc_rtl005.sv` (timing fix #3: parallel one-hot grant,
       one-hot AND-OR read, OR-encoded `push_idx`, identical semantics),
       under the person's finish-without-stopping instruction. Disclosed in
       `OPEN_ISSUES.md` item 80.
    3. After the fix, `gate.ps1` passed again (894/894). Build
       `20261002_203309` (default invocation) **passed at 55.02 MHz PASS
       at 50 MHz required**. That is the real, final post-route line; the
       pre-route estimate read 42.89 MHz. Critical path 2.18 ns logic +
       10.08 ns routing. TRELLIS_COMB 30251/83640 (36%), TRELLIS_FF
       19045/83640 (22%), MULT18X18D 12/156. "Program finished normally";
       no `--timing-allow-fail`.

    This is the widest margin since RTL-010, and router time dropped
    11159 s → 1356 s. The new worst path starts at RTL-001's `req_accept`
    and no longer touches RTL-005. `dfc_rtl014.sv` was picked up by
    `build_ecp5.ps1`'s auto-discovery with no script edit (item 58).

    **Real lesson for RTL-015 onward:** every new event producer makes
    RTL-005's slot mux genuinely wider, because a previously constant-zero
    slot stops being optimized away. Also, when running builds here, launch
    `build_ecp5.ps1` as a detached process and never concurrently with
    `gate.ps1`. place-and-route can run for over two hours, beyond a tool
    call's limit, and running it alongside the gate killed one synthesis
    run outright.
- **RTL-015 (Lost-Link Supervisor): real, implemented and integrated into
  `dfc_rtl024.sv` (2026-10-03).** The fourth Safety-domain module. Eight
  independent activity monitors with qualification/absence-timeout/
  recovery, bounded test injection, and lane-3 safety requests
  (ARCH-SAFE-007/008, ARCH-RTL015-001, ARCH-VAL-015). All 10 REG-002
  0x3300-0x3324 registers forwarded for real through
  `tools/reggen/rtl015_field_map.json`, reusing RTL-014's `reggen.py` v5
  `indexed_registers` mechanism unchanged. Full disclosed design:
  `dfc_rtl015.sv`'s own header and `OPEN_ISSUES.md` items 81-89.
  - **Decisions made under the person's "run it end to end" instruction**,
    logged in OPEN_ISSUES 81-89 for review, same discipline as RTL-014's
    own session (items 66-80).
  - **Item 81, the biggest resolved finding: the monitor index and the
    activity-ID index are the SAME fixed 1:1 space, not two separate
    configurable spaces as RTL-015_RevA.md and the task's own briefing
    both assumed.** REG-002's real `LLINK_MONITOR_CONTROL` field table has
    no activity-ID-select field at all — `LLINK_MONITOR_SELECT` picks
    which monitor's config/readback you're addressing, the same role as
    RTL-014's `ILOCK_ENTRY_SELECT`, never an activity source.
  - **Item 83: the `activity_i` bit wiring had FIVE conflicting Appendix A
    rows**, not one — the largest instance yet of the recurring
    "later/sibling row disagrees with the port's own definition" class
    (items 1/10/11/13/19/22/37/44/61/74, now a tenth instance). One of the
    five (RTL-021/Databus Routing) wasn't even a legal activity ID.
    Resolved in favor of RTL-015's own Appendix A row, which restates
    ARCH-SAFE-007's ID order verbatim.
  - **ARCH-002 growth (item 82):** `dfc_rtl015_control_t` grew 128→961
    bits — 8×104 bits for a complete per-monitor config bank (all 8
    monitors run simultaneously; the pre-existing selected-view struct
    fields can't carry that) plus the 14th EVENT_OVERFLOW-clear field.
    `dfc_rtl015_status_t` needed **no growth** — `LLINK_STATUS`'s LOST_*
    fields were already full 8-bit vectors, and `LLINK_ELAPSED_US` was
    already architected as a single selected-monitor readback.
  - **Real producers wired for the first time:** RTL-012's own
    `service_activity_o` port — real since RTL-012's own session, sitting
    unconsumed ever since — now genuinely reaches RTL-015
    `activity_i[7]`. GPIO transition (`activity_i[4]`) and health
    transition (`activity_i[5]`) are derived fresh in `dfc_rtl024.sv` via
    edge detection on RTL-006's/RTL-011's already-real qualified levels
    (no module exposes a dedicated pulse port for this), registered one
    cycle before RTL-015 sees it. `internal_source_vector` bit 30 ("any
    lost link") is now RTL-015's own real reduction-OR, replacing the
    prior disclosed stub.
  - **Two real RTL bugs were found and fixed during this module's own
    bring-up, confirmed by real simulation traces, not by inspection
    (items 88/89):**
    1. `recovery_progress_q[m]` originally free-ran independent of
       whether the monitor was actually LOST. With `QUALIFY_US=0`
       ("disabled", always within-qualify), it accumulated stale credit
       BEFORE a loss even began — the instant a real timeout set
       `active_q[m]`, the stale credit already satisfied `RECOVERY_US`,
       clearing it the very next cycle, which let the timeout re-fire
       immediately, clearing again, forever. A genuine, continuous
       one-cycle oscillation, caught by a real per-cycle trace. Fixed:
       held at zero whenever not currently LOST.
    2. Per-monitor `ENABLE` was extracted but never gated anything.
       Fixed to hold the timers at zero while disabled, and — found via a
       real test failure, the same `item 64`-class "a leftover real timer
       elapses by the time a later test part runs" effect — to also
       release an already-latched `LOST_ACTIVE[m]` the moment a monitor
       is disabled, not just suppress future sets.
  - **Tests.**
    - `rtl015_integration_tb.sv`: 40/40 checks. Real RTL-006 GPIO and
      real RTL-012 watchdog-service activity producers; a real RTL-013
      fault consumer. Covers the fixed mapping, selector-indexed banking,
      timeout/qualify/recovery timing, injection (natural-dominates,
      test-inactive rejection, tagged event), configuration rejection,
      simultaneous-loss priority, and the EVENT_OVERFLOW round trip.
    - `rtl024_skeleton_tb.sv`: 185→197 checks. Adds a real SPI
      configuration of monitor 4 and a real external `gpio_i[3]` pad
      driving a host-readable LOST_ACTIVE through the registered activity
      vector, plus RTL-013 seeing fault source 2.
  - **Other testbench changes.** The RTL-015 stub pair was added to all 13
    `rtl0NN_integration_tb.sv` files and `dri_transaction_tb.sv`.
    `regbank_smoke_tb.sv` Check 3 was redirected a 14th time (LLINK_STATUS
    → SAFETY_STATUS).
  - **Module spec corrected:** `docs/rtl_specs/RTL-015_RevB.md` supersedes
    Rev A (retired) — the activity-ID-select claim and the activity order
    were both wrong; Rev A's "10 registers" count was correct, unlike
    RTL-014's own Rev A.
  - **Verified on the person's machine.** `gate.ps1`: lint PASSED (24
    files); sim 19/19 testbenches, 946/946 checks total; formal 2/2
    (bmc+prove) PASS; coverage 178/353 registers (+10, exactly RTL-015's
    new register count). `build_ecp5.ps1` (LFE5U-85F-6BG381C) PASSED
    timing: real, final `pnr.log` line (the last one, per this project's
    standing convention that earlier lines are pessimistic pre-route
    estimates) reads `Max frequency for clock '$glbnet$core_clk': 50.53
    MHz (PASS at 50.00 MHz)`. Worst path (posedge→posedge, RTL-010→
    RTL-005): 4.30 ns logic + 15.49 ns routing = 19.79 ns total.
    Utilization: TRELLIS_COMB 33811/83640 (40%), TRELLIS_FF 20549/83640
    (24%), MULT18X18D 12/156 (7%), TRELLIS_IO 34/365 (9%), EHXPLLL 1/4
    (25%). Build ID `20261003_145704`.
- **RTL-016 (Safety Output Controller): real, implemented and integrated
  into `dfc_rtl024.sv`.** The FIFTH and FINAL Safety-domain module —
  closes the Safety domain (RTL-012 through RTL-016). Aggregates all four
  real safety-response lanes (RTL-012/013/014/015) plus RTL-014's real
  guard-indexed interlock inhibit and RTL-013's real per-channel fault
  inhibit, into four independently-configured logical safety outputs with
  a real nine-term PERMIT gate. See `dfc_rtl016.sv`'s own header and
  `OPEN_ISSUES.md` items 90-98 for every disclosed decision; summary:
  - **RTL-016_RevA's port list, several SS10.4 equation terms, and the
    control/status struct widths were all wrong (item 90-94)**, more so
    than any prior module's Rev A: the real Appendix A port catalog has
    22 ports, not ~16 (6 ports RevA's own SS2 never named: `irq_req_o`,
    `fault_req_o`, `interlock_satisfied_i`, `interlock_inhibit_i`,
    `effective_operational_enable_i`, `test_inhibit_i`); `GLOBAL_INHIBIT`
    is its own independent RW field (reset 1), not `!ENABLE` (RevA's own
    equation); `FAULT_INHIBIT` is genuinely per-channel (RTL-013's real
    `safety_inhibit_o` is 4 bits, even though all four currently carry the
    same value); `dfc_rtl016_control_t`/`status_t` are 53/52 bits, not
    RevA's claimed 52/47.
  - **TEST_DEBUG is a real, separate term this module must OR in itself
    (item 93)**: `test_inhibit_i`'s own Appendix A producer description is
    only "physical test authorization OR test-active" — ARCH-002's real
    TEST_INHIBIT definition adds TEST_DEBUG as a third OR term this module
    supplies from its own `operating_state_i`.
  - **PERMIT[c] is a real nine-term AND (item 94)**, including
    `RESET_HELD[c]` (RevA's own version had eight terms and omitted it).
  - **INTERLOCK_INHIBIT[c] uses RTL-014's GUARD-indexed `interlock_inhibit_o`,
    not its ENTRY-indexed `interlock_satisfied_o` (item 95)** — the single
    most structurally subtle finding this session, confirmed directly from
    `dfc_rtl014.sv`'s own header comment ("the two ports would be redundant
    complements if both were per guard"). `interlock_satisfied_i` is a
    real Appendix A port this module receives with NO functional use and
    NO REG-002 status field anywhere to expose it — a disclosed, genuinely
    unused input, not a bug.
  - **The two-key response-authorization model (item 96)**, resolved from
    first principles: a request reaches channel `c` only when BOTH the
    producer's own 4-bit response-mask bit `c` is set AND this module's
    own 32-bit per-channel `SAFETY_RESPONSE_MASK` authorization bit
    (`8*lane+source_id`) is set — two independently-configured permission
    layers, not one.
  - **`dfc_rtl016_control_t` grew 53->226 bits (items 90, plus a 15th
    EVENT_OVERFLOW-clear-field gap instance found while writing the field
    map)**: a complete 4-channel array (`safety_channel_c<0..3>__*`, 43
    bits each) added via `reggen.py` v5's `indexed_registers` mechanism,
    reused unchanged a third time; `dfc_rtl016_status_t` needed NO growth
    (`SAFETY_CHANNEL_STATUS` is intentionally a single selected-channel
    view, `SAFETY_STATUS` is already a full per-channel aggregate).
  - **Real, empirically-confirmed finding, NOT caused by RTL-016 (item
    98)**: `rtl024_skeleton_tb.sv`'s long-standing "RTL-002 reaches FAULTED
    via the ~499,000-cycle mandatory-init timeout" outcome is UNCHANGED
    even with RTL-016 real and every mandatory-mask module now ready. The
    real root cause (confirmed by running the test, not assumed) is a
    genuine structural self-reference in RTL-002's own FSM:
    `mandatory_ready_now` requires `module_ready_i[1]` (RTL-002's own
    self-looped status), but RTL-002's own `status_o.ready` requires
    `init_complete_q`, which is only set once STARTUP successfully leaves
    — a gate that can never be satisfied by itself. Not fixed here (out of
    RTL-016's scope; a real, disclosed finding about already-shipped
    RTL-002).
  - **`rtl024_skeleton_tb.sv` extended, 219 checks (was 197)**: a real,
    whole-system RTL-016 section reusing RTL-014's already-live entry-0
    interlock violation as the authorized request, proving the two-key
    authorization and the real OPERATIONAL_INHIBIT block (correctly
    inactive, since the whole system never reaches NORMAL per item 98).
  - **New `rtl016_integration_tb.sv`, 71 checks**: real RTL-012 (lane 0)
    producer forced through a genuine WDOG timeout; lanes 1-3 driven
    directly as controlled stimulus (lane 2's real cross-module wiring
    already proven whole-system). Covers every PERMIT term independently,
    the two-key authorization (positive and negative), ACTIVE_HIGH
    polarity both ways, LATCH_RESPONSE's full set/hold/clear-after-
    inactive/re-enable-clears cycle, the disabled-channel-with-stale-mask
    live FAULTED/fault_req_o cross-field defense (item 9), multiple
    lanes OR'ing without canceling (ARCH-RTL016-001), and the event/
    overflow round trip.
  - **New physical pins**: `safety_out_o[3:0]` = `gn8`/`gn9`/`gn10`/`gn14`
    (ULX3S_CONNECTION_MAP.md Section 10) — the lowest four of eleven real
    "orphaned" `gn<N>` pins (differential counterparts of already-committed
    single-ended `gp<N>` positions), not the WiFi-shared `gp11`-`gp13`
    range, preserving that range for RTL-017/019/020. `ulx3s_dfc_top.sv`
    gained its first-ever real connection for `safety_out_o` (previously
    `()`, unconnected at the top level).
  - **Verified on the person's machine.** `gate.ps1`: lint PASSED (25
    files); sim 20/20 testbenches, 1039/1039 checks total (946 RTL-015
    baseline + 71 new `rtl016_integration_tb.sv` + 22 new whole-system
    `rtl024_skeleton_tb.sv` checks, independently summed and exact); formal
    2/2 (bmc+prove) PASS; coverage 186/353 registers (+8, exactly RTL-016's
    new register count).
    `build_ecp5.ps1` (LFE5U-85F-6BG381C) real final timing: FAILED on the
    first run (49.52 MHz vs 50.00 MHz, a real, already-marginal path
    inside already-shipped `dfc_rtl014.sv` -- RTL-016's own added
    placement/routing pressure tipped it over), fixed with a real,
    disclosed change (`interlock_terms_q`, item 99), then re-verified
    (`gate.ps1` identical 1039/1039) and rebuilt clean: real, final
    `pnr.log` line (the last one) reads `Max frequency for clock
    '$glbnet$core_clk': 51.22 MHz (PASS at 50.00 MHz)`. Worst path
    (posedge→posedge): 3.36 ns logic + 16.17 ns routing = 19.53 ns total.
    Utilization: TRELLIS_COMB 35176/83640 (42%), TRELLIS_FF 20938/83640
    (25%), MULT18X18D 12/156 (7%), TRELLIS_IO 38/365 (10%), EHXPLLL 1/4
    (25%). Build ID `20261004_142815`.
- **RTL-017 (ARINC 429 Receive Interface) is REAL — the first Databus-domain
  module and the first real client of the shared-buffer service.**
  RTL-018 through RTL-023 remain spec-complete but not yet implemented.
  - **Two new files**: `rtl/databus/src/dfc_rtl017.sv` (the queue engine
    — 8-entry queue over the 32-word client-0 segment, internal WRITE >
    SNAPSHOT > ROUTE arbiter serializing all buffer access through one
    `buf_req`/`buf_rsp` port, host-POP-vs-route-transfer same-head
    arbitration per ARCH-RTL017-001) and
    `rtl/top/dfc_rtl024_arinc_rx_adapter.sv` (the real ARCH-BUS-001 bit-
    timing-recovery adapter — transition-based oversampling, odd-parity
    check, gap-based framing, built from first principles since ARCH-002
    specifies behavior, not a cycle-accurate state machine, with every
    interpretation choice disclosed in the file's own header).
  - **Real architecture fork, not assumed in advance**: `ARX_CONTROL`
    (0x1000)'s 5 fields could not be mapped by `reggen.py` against the
    original 278-bit `dfc_rtl024_control_t` (v5 requires whole-struct
    coverage) — split into a new, dedicated
    `dfc_rtl024_arinc_rx_adapter_control_t`/`_status_t` struct pair after
    explicit user approval, confirming first that no renumbering was
    needed and that the SPI bridge doesn't depend on the old struct's bit
    positions (see `OPEN_ISSUES.md` item 107 for the full account).
  - **Two real, genuine bugs found and fixed via real failed testbench
    runs, not by inspection** (`OPEN_ISSUES.md` item 110): (1) the
    internal arbiter could get permanently stuck presenting an unaccepted
    route message, starving WRITE/SNAPSHOT of service — fixed by
    decoupling the held route message (`route_pending_q`) from the
    arbiter's own `op_q`/`phase_q`; (2) a host CAPTURE command pulse
    arriving while the arbiter was mid-WRITE/mid-ROUTE was silently
    dropped — fixed with a `capture_pending_q` latch, the same pattern
    `write_pending_q` already used for adapter words. Both were masked in
    this integration only because `msg_ready_i` is tied to a permanent 1
    (RTL-021 doesn't exist yet) — a real future consumer applying
    backpressure would have hit bug (1) for real.
  - **New `rtl017_integration_tb.sv`, 19 checks**: queue push/pop/
    overflow, error-code classification (parity/overrun/adapter, REG-
    ENC-008), one-outstanding-discipline runtime monitor (a real,
    dedicated check of RTL-017's OWN FSM, not inherited from the shared-
    buffer arbiter's own formal proof), and the host-POP-vs-route-
    transfer simultaneous-contention case (`RTL-017_RevA.md` SS6's own
    named test).
  - **`rtl024_skeleton_tb.sv` extended for real, 232 checks (was 219 after
    RTL-016)**: a genuine end-to-end case — a real bit-level NRZ ARINC
    word (correct `BIT_PERIOD_HIGH` timing, qualifying idle gap, odd
    parity) driven on the real `arinc_rx_i` pad, through the real
    adapter, into RTL-017's real queue, through the real arbiter, into
    the real `PDPW16KD`-backed shared-buffer memory, and back out via the
    real route-drain — closing `OPEN_ISSUES.md` item 102 for real, not a
    narrower substitute. Host enable/configuration driven over the real
    external SPI pins (`PROTECT_KEY`-gated `SUBSYS_ENABLE`/`ARX_CONTROL`
    writes — a real finding here too: `ARX_CONTROL` needs the PROTECT_KEY
    arm sequence for EVERY write, not just when changing `HIGH_SPEED`
    while already enabled, since `reggen.py` has no way to implement that
    narrower condition and instead marks the whole register protected).
  - **Incidental breakage found and fixed**: `dri_transaction_tb.sv` and
    `regbank_smoke_tb.sv` both still referenced RTL-017's OLD individual
    per-register stub ports (`arx_status_status_i` etc.), removed when
    the aggregated `rtl017_control_o`/`status_i` ports were added — both
    fixed to the new aggregated port names and re-verified passing.
  - **New physical pins**: `arinc_rx_i` = `gn15` (SITE P16),
    `arinc_rx_adapter_error_i` = `gn16` (SITE M17) — the next two in
    Section 10's own already-confirmed `gn14-gn21` SITE ordering
    (ULX3S_CONNECTION_MAP.md Section 11). Confirmed as 2 real pins, not
    1 — `arinc_rx_adapter_error_i` (the transceiver's own fault output)
    is a genuine external Appendix A port, not internal/stale, tightening
    the remaining Databus pin budget to 8 more needed (RTL-018/019/020)
    against 11 remaining conductors (`OPEN_ISSUES.md` item 109).
  - **Verified on the person's machine.** `gate.ps1`: lint PASSED; sim
    22/22 testbenches, 0 failures (includes the new 19-check
    `rtl017_integration_tb.sv` and the extended 232-check
    `rtl024_skeleton_tb.sv`); formal 2/2 (RTL-001 one-outstanding +
    RTL-024 buffer arbiter, both bmc+prove) PASS — no new formal
    properties added for RTL-017 itself, the task only asked to confirm
    the existing ones still hold against a real client; coverage 189/353
    registers (53.5%, +3 over RTL-016's 186/353).
    `build_ecp5.ps1` (LFE5U-85F-6BG381C): **`DP16KD` placement is
    genuinely nonzero for the first time ever in this project — `1/208`,
    confirmed directly in `nextpnr-ecp5`'s own log output** (`OPEN_ISSUES.md`
    item 104's own required follow-up, resolved). Placement, routing, and
    timing analysis all genuinely completed and PASSED (`Max frequency
    for clock '$glbnet$core_clk': 50.02 MHz (PASS at 50.00 MHz)`, real
    `pnr.log`, Build ID `20261006_112421`). **But `nextpnr-ecp5` then
    crashes every time, immediately after printing its own slack
    histogram, with `ERROR: Expecting string value but got integer 0.` —
    before writing either the textcfg or the report JSON, so no bitstream
    is produced.** Isolated via a real, independent repro (same exact
    invocation with `--report` removed entirely — identical crash,
    identical point, preserved at
    `output/logs/ecp5_pnr_20261006_112421_noreport_isolation.log`),
    ruling out the `--report` JSON writer as the specific cause. This is
    a genuine, confirmed `nextpnr-0.10-82-g2b560ad0` toolchain bug,
    triggered specifically by a nonzero BRAM-class cell placement — this
    project has simply never exercised that code path before now, since
    `DP16KD` was provably `0/208` (optimized away) in every prior build.
    **Not yet fixed** — needs either a toolchain upgrade/patch (a decision
    beyond what an RTL session should make unilaterally) or a confirmed
    workaround, neither attempted here beyond the one isolation test
    above. See `OPEN_ISSUES.md` item 112 for the full account. This
    blocks bitstream generation for RTL-017 (and will block every future
    module's build too, until resolved) — it does NOT call RTL-017's own
    correctness into question: lint/sim/formal all genuinely pass, and
    the real PnR timing result itself, as far as it got, was a clean
    PASS.
- **Build script structural fix (2026-08-26): `build_ecp5.ps1`'s
  `$SourceFiles` list is no longer hardcoded.** This exact gap had been
  hit and reactively fixed 4 separate times (RTL-002, RTL-004, RTL-009,
  RTL-011 -- `OPEN_ISSUES.md` items and the Section 3/4 lessons above) —
  a new module's `.sv` file forgotten from the list on the first build
  attempt every time, always caught the same way (a Yosys hierarchy-check
  failure: "Module ... referenced ... is not part of the design"). Fixed
  for real, not just for the currently-known module set: `build_ecp5.ps1`
  now discovers every real module source file at run time via
  `Get-ChildItem` — every `rtl\<domain>\src\*.sv` for each domain
  directory under `rtl\` except `top` (so a brand-new domain directory,
  or a currently-empty one like `rtl\safety\`/`rtl\databus\`/
  `rtl\programmable\` gaining its first real module, needs no script
  change at all), plus `rtl\top\*.sv` directly (the top-level integration
  and SPI bridge live there with no `src\` subfolder). `rtl\<domain>\
  generated\` is deliberately excluded from this scan since
  `dfc_config_regbank_regs.sv` is already covered by the fixed,
  always-included file list (the three `include\dfc_*_pkg.sv` packages
  RTL-001+ actually reference, the generated regbank, and the three
  `fpga\ecp5\` platform files). The synthesis `.ys` script's own
  `read_verilog` list — the *other* half of this exact recurring gap per
  every one of the four prior incidents' own wording ("missing from both
  `$SourceFiles` and the synthesis `.ys` script's read order") — is now
  generated FROM `$SourceFiles` rather than a second, independently
  hardcoded list, closing both halves of the gap at once instead of only
  the one this task named. **Verified for real, not just "doesn't
  error":** the auto-discovered list was compared programmatically
  against the exact prior explicit list and confirmed identical as a set
  (all 20 files — RTL-001 through RTL-011, the SPI bridge, the top-level
  wrapper, and every fixed file — no module missing, nothing extra
  pulled in); the only difference found was the relative order of the
  two `rtl\top` files (`dfc_rtl024.sv` now sorts before
  `dfc_rtl024_spi_bridge.sv`, the reverse of the old hardcoded order) —
  a real, subsequent `build_ecp5.ps1` run with this reordering in place
  (Build ID `20260826_171940`) reproduced **50.12 MHz PASS at 50 MHz
  required** bit-for-bit against the last confirmed RTL-011 build (same
  TRELLIS_COMB 30%/TRELLIS_FF 19%/MULT18X18D 7% utilization), confirming
  empirically that Yosys/nextpnr's result here does not depend on
  `read_verilog` file order — this was a genuine, purely mechanical
  change with zero effect on synthesis output, not merely an untested
  assumption. The manifest's own "Source files" section (already driven
  by `$SourceFiles`, unchanged) continues to print the full, correct
  20-file list. **The RTL-002/004/009/010/011 checklist item this
  document itself carried ("add the new module to both `$SourceFiles`
  and the synthesis script") is retired as of this fix** — see the
  RTL-004 lessons entry below for the now-obsolete text, kept struck
  through rather than deleted so a future session sees why it no longer
  applies. RTL-012 onward: adding a new module's `.sv` file under the
  correct `rtl\<domain>\src\` path is sufficient by itself; no
  `build_ecp5.ps1` edit is needed for source discovery.
- *(Historical entries below this point predate RTL-006 and are kept for*
  *the record, not current status — see the RTL-006 through RTL-011*
  *entries above for the project's real, current state.)*
- **Full regression across every real testbench in the project, run for
  real this session (both individually and via `gate.ps1`'s own `sim.ps1`
  step), all green — 120/120 checks, 0 failures:**
  `rtl002_state_tb.sv` (28/28), `rtl024_skeleton_tb.sv` (22/22),
  `rtl003_integration_tb.sv` (22/22, new this session),
  `rtl002_integration_tb.sv` (11/11), `dri_transaction_tb.sv` (12/12),
  `regbank_smoke_tb.sv` (12/12), `spi_bridge_tb.sv` (13/13) — see the
  RTL-003 entry above for exactly which of these needed real fixes for
  RTL-003's new `dfc_rtl001.sv` ports vs. which were unaffected.
- **`dfc_types_pkg.sv` was missing `dfc_operating_state_t` entirely until
  this session** — a real, silent generator-coverage gap dating back to
  before RTL-001 was first verified (see Section 3 for the root cause and
  fix). `extract_types.py` and `pkggen.py` were both patched and re-run
  for real against the actual `RCA-DFC-ARCH-002.md`; the truly-regenerated
  `dfc_types_pkg.sv` was then swapped into the sim/synth trees in place of
  a temporary hand-patched stand-in used earlier in the same session, and
  everything (both testbenches above, plus the Yosys elaboration check)
  was re-run and reconfirmed clean against the real generated file, not
  the stand-in.
- **`build_ecp5.ps1` needed a real, concrete update for RTL-002 and was
  fixed this session:** its `$SourceFiles` list and the synthesis `.ys`
  script it generates were both missing `include\dfc_types_pkg.sv`
  (never needed before RTL-002, since RTL-001 doesn't reference that
  package) and `rtl\infrastructure\src\dfc_rtl002.sv` itself. Without
  this fix, running the script as it stood would have silently
  synthesized the old RTL-001-only design even with the new files
  present on disk. Fixed and reconfirmed via a real Yosys run of the
  updated file list (0 errors).
- **`lint.ps1`/`sim.ps1`/`gate.ps1`/`formal.ps1`/all three Claude Code
  hooks needed NO changes for RTL-002** — confirmed, not assumed. All
  five discover files by recursive directory scan, not a hardcoded list.
  One specific concern was checked directly rather than assumed away:
  `sim.ps1` sweeps the *entire* `include/`+`rtl/` tree into every single
  testbench's compile, so now that `dfc_rtl024.sv` exists, a testbench
  that doesn't use it (e.g. `dri_transaction_tb.sv`) will have it swept
  in anyway as an orphan, unconnected top-level module in the same
  `iverilog`/`vvp` run. Reproduced this exact scenario directly: it's
  harmless — the orphan module's floating, undriven ports never do
  anything, the real testbench's own `$finish()` ends the whole run
  cleanly, and the pass/fail text `sim.ps1` scans for isn't corrupted
  (confirmed: `dri_transaction_tb.sv` still reported a clean 12/12,
  `vvp` exit code 0, when compiled against the full real tree including
  `dfc_rtl024.sv`/`dfc_rtl002.sv`).
- **Files changed this session were redelivered, not just described** —
  per this document's own standing lesson above about sandbox fixes not
  being real until placed at their real path. As of this document's
  writing: `dfc_rtl002.sv` (→ `rtl/infrastructure/src/`),
  `rtl002_state_tb.sv` (→ `verification/testbench/rtl-002/`),
  `dfc_rtl024.sv` (→ `rtl/top/`, replacing the prior skeleton),
  `rtl024_skeleton_tb.sv` (→ wherever the prior version already lived),
  `extract_types.py` and `pkggen.py` (→ `tools/pkggen/`), and
  `build_ecp5.ps1` (→ `scripts/`) have all been handed back to the
  person this session. **Confirm these are actually placed at their real
  paths in the person's local tree before trusting any of this section
  as the project's live state in a future session** — this document
  records what was verified in this session's sandbox/chat exchange, not
  an independent confirmation that the person's machine reflects it yet.
- **`REG-002.md` grew from 314 to 353 registers** since RTL-001/the SPI
  bridge were first verified — a real, deliberate baseline addition
  (packed 16-bit counter-pair diagnostic registers across multiple
  modules, e.g. `BUFFER_CLIENT_ERROR_COUNT_0_1`,
  `ROUTE_INGRESS_LOSS_COUNT_0_1`, `ULI_MAILBOX_LOSS_COUNT_0_1`; new
  access class `COUNTER16-CLR`, cited `REG-ENC-021`/`ARCH-GEN-006`
  through `008`). All six `include/dfc_*_pkg.sv` packages and
  `rtl/infrastructure/generated/dfc_config_regbank_regs.sv` are
  confirmed regenerated and verified against this current, correct
  353-register baseline — not the stale 314-register one.
- **All six `include/dfc_*_pkg.sv` packages now have a complete,
  real, mechanical generator chain, confirmed via actual runs, not
  written and assumed:**
  - `dfc_registers_pkg.sv` — `extract_registers.py` → `pkggen.py`
  - `dfc_types_pkg.sv` — `extract_types.py` → `pkggen.py`. As of this
    session, `extract_types.py` covers BOTH ARCH-002 Appendix B (52
    structs) AND SS4.1's `dfc_operating_state_t` enum table (a separate,
    independently-scoped section parser — see Section 3 for why these
    needed to be separate) — the enum was a real, silent gap until this
    session, not present since the project's start.
  - `dfc_events_pkg.sv` / `dfc_interrupt_pkg.sv` — `extract_irqfault.py`
    → `split_irqfault.py` → `pkggen.py` (shared first stage, mechanical
    split, not two duplicate extractors)
  - `dfc_version_pkg.sv` — derived from `dfc_registers_pkg.json`'s
    already-verified data via `extract_version.py` → `pkggen.py` (no
    document re-parsing)
  - `dfc_constants_pkg.sv` — `extract_constants.py` (parses a specific,
    narrow prose pattern in `REG-002.md` plus one `ARCH-002.md` table
    row) → `pkggen.py`
  - All six confirmed to produce zero wildcard imports; `pkggen.py`
    itself (unchanged from early in this project) is the shared choke
    point that guarantees this regardless of which extractor produced
    the input JSON.
- **`regenerate.ps1`** (dependency-staleness check + auto-regeneration,
  closing the project's own #7/#8 punch-list items) is real, wired into
  both `gate.ps1` and `build_ecp5.ps1` as their mandatory first step, and
  **confirmed working end-to-end in a real run on the person's own
  machine** — correctly detected `REG-002.md`/`ARCH-002.md` changes,
  regenerated all six packages plus the register bank, and reported
  "unchanged" correctly on documents that hadn't changed.
- **Formal verification** (`verification/formal/rtl-001/
  dri_one_outstanding.sby` + `dri_one_outstanding_formal.sv`): **real
  and genuinely passing** — 4 properties proven via full k-induction
  against real RTL-001 (not a stub), using a real, permanent
  observability port added to `dfc_rtl001.sv` (`dbg_regbank_write_en_o`)
  for the one property that needed it. Re-confirmed passing again after
  the 353-register regeneration. This took many real rounds of finding
  and fixing genuine bugs (in the harness, not RTL-001) — see Section 2
  above for the specific findings.
- **`gate.ps1`** (the full regenerate → lint → sim → formal → coverage
  chain): **has passed clean end-to-end on the person's own machine**,
  against the current, correct 353-register baseline — confirmed via a
  real run, not the earlier 314-register state.
- **`check_coverage.py`** textual reference coverage: 6/353 registers
  referenced across current testbenches (recalculated denominator,
  correctly reflecting the 353-register baseline). This is expected, not
  a defect — 347 of the unreferenced registers belong to RTL-002 through
  RTL-023, which don't exist as real RTL yet. Within RTL-001's own owned
  registers specifically, a handful (e.g. `PRODUCT_REV`,
  `SUBSYS_ENABLE`, `CONFIG_ERROR_STATUS`) have no dedicated test yet — a
  legitimate, optional hardening task, separate from building new
  modules.
- **The project's own 8 top-level baseline documents, plus
  `RTL-001_RevB.md` and `RTL-024_RevC.md`, have each been individually
  confirmed current** — either by running the real extractor against
  them directly (`REG-002.md`, `ARCH-002.md`) or by a byte-for-byte
  `diff` against the person's own freshly-uploaded local copy (the
  remaining 8). The Claude Project's uploaded file store was the
  reliable, current reference throughout this whole exercise; the
  staleness was only ever on the person's local disk, caused by files
  not being properly renamed/replaced during an earlier update.
- **The current project state was committed to git**, summary "skeleton
  baseline" — a clean, verified checkpoint: real, current documents;
  real, working generators; a real, passing full-chain `gate.ps1` run.
  This is a trustworthy point to build forward from, not one that needs
  immediate follow-up correction.
- **Workflow decision, REVISED — RTL implementation now happens via
  Claude Code Desktop, not the chat interface.** The original decision
  (recorded below, now superseded) was to keep implementation work in a
  chat interface for direct, hands-on involvement. That was tried for
  RTL-003 and hit a real, concrete wall: a plain chat session has no
  direct file-tree access, so every file the work touched had to be
  manually uploaded one at a time — for a task the size of adding a new
  module (new `.sv` file, a new `reggen.py` field-map, edits to
  `dfc_rtl001.sv`/`dfc_rtl024.sv`, a new integration testbench, updates
  to the existing skeleton testbench), this required uploading far too
  many files, and the session made no real progress before stalling.
  **Claude Code Desktop, pointed at the real `DragonCore\` folder, does
  not have this problem** — it reads and edits the real files directly,
  and (unlike this chat's own sandbox) has direct access to the real
  PowerShell, real SymbiYosys, and real `nextpnr-ecp5` toolchain, closing
  every "I can't test this myself" gap this project hit repeatedly
  earlier (the combinational-loop investigation, the `.sby` formal-
  harness fix, the PowerShell script edits). **Going forward: give
  Claude Code the actual implementation work (writing, wiring,
  integrating, and testing each new RTL module), and use a chat interface
  for strategic/architectural tradeoff discussions** (module-scope
  decisions, business/pitch questions) where iterative, correction-as-
  you-go reasoning fits a conversational format better than an agentic
  execute-a-task format. This document remains the single source of
  truth read by whichever interface is doing the work — keep it current
  regardless of which one made the change.
  - *(Original, now-superseded reasoning, kept for the historical
    record: "the person has chosen to keep doing RTL implementation work
    in this chat interface specifically because manually uploading/
    placing files and running the real build keeps them actively,
    directly involved... not because of any gap in Claude Code's
    capability." That gap turned out to be real in practice, not
    hypothetical — see above.)*
- **11 software specs (`SW-001` through `SW-011`)** exist and are
  uploaded to the project, but are **deliberately not yet audited or
  reconciled against the RTL specs** — this is an intentional, planned
  single reconciliation point, not an oversight. Do not start that
  reconciliation without the person explicitly asking for it.
- **Physical board flashing has never been done.** This is a deliberate,
  reserved step — held back on purpose, to be triggered specifically
  when there's a concrete reason (e.g., investor interest), not done
  preemptively. Do not suggest flashing the board as a routine next step
  without checking whether that trigger condition has actually arrived.

---

## 5. Active plan going forward (as agreed with the person — follow this unless explicitly redirected)

- **REAL, DELIBERATE SCOPE CHANGE (decided after RTL-001/RTL-002's real
  integration was confirmed working) — READ THIS BEFORE PLANNING ANY
  FURTHER MODULE WORK:** the person has determined there is no direct
  market for the originally-scoped 24-module Dragon Flight/Dragon Core
  product, and is now completing this project as a **demo/portfolio tool
  for future engineering consulting work**, not as a product ship target.
  **The scope-reduction decision itself does not require editing any
  specification** — REG-002/ARCH-002/every RTL spec's *content* is
  unaffected by choosing not to build RTL-022/023, and RTL-001/RTL-002's
  real implementations are untouched by this decision. This is a
  narrower claim than "specifications never change" — see Section 3's
  corrected note on `docs\` governance: a real gap or inconsistency
  found later (as has already happened, e.g. the `EVENT_OVERFLOW`
  clear-path fix) still gets fixed through the normal approve-then-
  update-everything-affected process; this scope decision just happens
  not to be that kind of case. What changes here is the **build-out
  target**: after a careful,
  turn-by-turn walkthrough of the actual architecture (confirmed against
  real register ownership, not assumed), the settled decision is:
  - **Build RTL-003 through RTL-021 in full**, each with the same
    real-integration-and-real-test discipline as RTL-001/RTL-002 (see
    below) — covering Infrastructure, Monitoring, Safety, and Databus in
    their entirety, including RTL-021 (Databus Router).
  - **RTL-022 (User Logic Island) and RTL-023 (User Routing) will NOT be
    implemented, ever, as part of this build.** This was a deliberate,
    reasoned choice, not an oversight: RTL-022 is a "programmable" slot
    for user-supplied custom logic with no real content of its own to
    demonstrate (already independently confirmed elsewhere in this
    project as "entirely inert this revision"), and RTL-023 exists only
    to serve RTL-022 — neither has anything to show in a demo without
    pre-supplied content the project doesn't have. RTL-021, by contrast,
    is NOT "programmable" in that sense — it's an ordinary,
    register-configured routing table (`ROUTE_STAGE_SOURCE`/`_DEST`,
    `ROUTE_VALIDATE_COMMIT`, etc.), fully demonstrable on its own exactly
    like any other module, which is why it stays in scope while RTL-022/
    023 are cut.
  - **Confirmed, by direct inspection of the real register/mask
    architecture, that this requires ZERO changes to RTL-001 or
    RTL-024.** Both already treat "module not yet built" and "module
    permanently omitted" identically: RTL-001's register decode already
    mechanically tie-offs every not-yet-owned register (including
    `ULI_*`/`UROUTE_*`, RTL-022/023's real register names, which stay in
    REG-002 unused since the spec itself is not being edited); RTL-024's
    fixed 24-bit `module_ready_i`/`module_fault_i`/`module_reset_o`
    vectors already stub bits for any not-yet-real module the same way
    regardless of whether that module is "not built yet" or "never will
    be." Bits 21/22 (RTL-022/023) are confirmed NOT in the mandatory
    mask (`0x80F81F`), so their permanent absence can never force
    RTL-002 into `FAULTED`, and — checked directly against the real
    `optional_enabled_fault_now` formula in `dfc_rtl002.sv`
    (`|(module_fault_i & effective_optional_enable)`) — it can't even
    cause `DEGRADED`, since that only responds to a module's FAULT
    output, which a permanently-stubbed module never asserts regardless
    of its `SUBSYS_ENABLE` bit. The only consequence is a purely
    cosmetic one (those `SUBSYS_ENABLE`/`SUBSYS_READY`/`SUBSYS_FAULT`
    bits reading "enabled"/"not ready" for modules that will never
    exist), addressable entirely on the host-software side (not
    reading/displaying those specific bits, or optionally clearing the
    `SUBSYS_ENABLE` bits at boot for accuracy) if desired — never an RTL
    change, on any module.
  - **This decision does not need to be revisited or re-litigated in any
    future session.** It was reached through careful, verified reasoning
    against the real architecture (not a snap judgement), confirmed
    module-by-module rather than assumed, and should be treated as
    settled unless the person explicitly reopens it.
  - **The target module count for this project is now 21 (RTL-001
    through RTL-021), not 24.** Update any future planning, effort
    estimates, or checkpoint language accordingly — do not silently
    default back to "all 24 modules" out of habit or because that's what
    an older section of this document (or an RTL spec's own text)
    describes as the original full scope.
- **RTL-002 through RTL-016 are now all real and implemented — the Safety
  domain (RTL-012 through RTL-016: Watchdog Manager, Fault Manager,
  Interlock Engine, Lost-Link Supervisor, Safety Output Controller) is
  COMPLETE.** RTL-016 was the first real CONSUMER of RTL-012/013/014/015's
  own `response_req_o` lanes (0-3) and RTL-014's `interlock_inhibit_o`
  (`interlock_satisfied_o` turned out to be genuinely unused — item 95),
  and now owns the physical `safety_out_o[3:0]` pads for real. See
  `OPEN_ISSUES.md` items 90-98 for its own full disclosed scope, most
  notably item 98 (a real, pre-existing RTL-002 structural finding, not an
  RTL-016 defect) and item 95 (the guard-vs-entry interlock-indexing
  finding). **RTL-017 (ARINC 429 Receive Interface) is now REAL too** —
  see Section 4's own RTL-017 entry and `OPEN_ISSUES.md` items 107-111
  for the full account (the struct-split architecture fork, two real
  design bugs found and fixed via real testbench failures, the pin-budget
  tightening, and the three "first real exercise" risk confirmations).
  **The next real step is RTL-018 (ARINC 429 Transmit Interface)**, read
  `OPEN_ISSUES.md` items 100-111 first (the shared-buffer service and
  RTL-017's own real client precedent). One module at a time, using the
  exact same real-verification discipline as RTL-001 through RTL-017
  (compile, simulate, and only then trust — never claim something works
  without actually running it).
  **RTL-013's own session reconfirmed a pattern this document has now
  flagged three separate times (RTL-002/003's own port-catalog gaps in
  RTL-002, then RTL-006's own module_enable_o/effective_operational_
  enable_o gap in RTL-002 again, now degraded_req_i/faulted_req_i in
  RTL-002 a third time): whenever a LATER module's own real port catalog
  names an EARLIER, already-shipped module as its producer/consumer,
  check that earlier module's own real port list directly before assuming
  it's already conformant — ARCH-002 had already specified the fact
  correctly every single time; the gap was always in the earlier module's
  own implementation, not the specification. RTL-014 onward should expect
  this same class of check against RTL-002 (the single most
  frequently-referenced producer/consumer in the whole port catalog) and
  every other already-shipped module it names.**
  **The margin-risk warning this document carried into RTL-012's own
  session ("RTL-012 onward should treat this as a live, standing risk")
  was correct a fourth time**: RTL-012's own `build_ecp5.ps1` run genuinely
  failed timing (47.73 MHz), root-caused to the exact `store_q` bottleneck
  item 48's own investigation had already flagged, and fixed for real (not
  worked around) by pipelining RTL-005's event-store write — see this
  document's own RTL-012 entry in Section 4 for the full account. The
  fixed design now closes at **50.28 MHz, a WIDER margin than RTL-011's own
  50.12 MHz** despite RTL-012's own added area, so this specific bottleneck
  is genuinely closed, not merely deferred — but the underlying dynamic
  item 48 identified (wide-fanin hubs — the register-readback mux, the
  event-record mux, the fault/ready OR-trees — each gaining one more input
  per new module) is architectural, not a one-time fix, and the new worst
  path (the SPI bridge's own `dri_req_addr_o`/`dri_req_write_o` fan-out)
  confirms the pattern continues to shift rather than disappear.
  **RTL-013's own session confirmed the warning a fifth time, and this one
  hit harder than any prior instance**: a real `build_ecp5.ps1` run failed
  outright at 40.14 MHz (not a narrow miss like RTL-010/011/012's own
  builds), because RTL-013's own real fault-source matrix is itself a
  brand-new wide aggregation hub, not merely one more input to an existing
  one. Fixed for real (after two other real investigations, one genuinely
  contributory and one confirmed NOT the actual cause — see this
  document's own RTL-013 entry in Section 4 and `OPEN_ISSUES.md` item 65
  for the full three-attempt account) by registering the new aggregation
  one cycle before it reaches further logic, closing at **50.19 MHz**.
  **RTL-014 onward should apply this lesson proactively, not reactively**:
  any new module that aggregates several already-scattered real
  producers into one signal should register that aggregation's own output
  from the start, before a real build failure forces the discovery a
  second time.
  **RTL-011's own session reconfirmed the SPI bridge's own real timing
  margin is a live, recurring risk, not settled once and for all: a real
  `build_ecp5.ps1` run closed at only 50.12 MHz, 0.12 MHz (0.24%) above
  the 50 MHz requirement — narrower than RTL-010's own already-narrow
  50.30 MHz (item 40), despite item 41's later, dedicated root-cause fix
  (the `rdata_words_q` shift-register replacement) having widened that
  same margin to 53.69 MHz first. RTL-011's own added die area alone
  consumed essentially all of that regained headroom. The build genuinely
  passed with no `--timing-allow-fail`, so no further action was taken
  this session per this project's own standing rule (only investigate/fix
  when a build actually fails) — but this is now the THIRD time a
  narrow-margin flag has correctly predicted the next module would eat
  the remaining headroom (RTL-007's 52.87 MHz predicted RTL-008's
  regression; RTL-010's 50.30 MHz predicted this one). Full account in
  `OPEN_ISSUES.md` item 47 and this document's own RTL-011 entry in
  Section 4 above. **RTL-012 onward should treat this as a live, standing
  risk to check at the start of its own session, not something to
  rediscover the hard way a fourth time** — read items 17/31/40/41 for the
  full pattern (registered-mask arbiters instead of per-cycle arithmetic;
  pipelined multiplies instead of same-cycle combinational chains; a
  variable-index array that's actually only ever accessed sequentially
  replaced with a shift register) before assuming a fresh timing failure
  needs a brand-new fix shape rather than one of these already-proven
  ones.
  **RTL-009's own session confirmed the pipelined-multiply pattern
  (`OPEN_ISSUES.md` items 26/27/30/31) generalizes cleanly to two channels
  in one module** — see Section 4's own RTL-009 entry below for the real
  `build_ecp5.ps1` result. RTL-009 also needed genuinely NEW design work
  beyond what RTL-007/008 required: a real, disclosed two-level event-
  arbitration scheme for its own shared one-deep pending slot (two
  producers, one slot, channel 0 wins ties, the loser genuinely counted as
  dropped) — read `OPEN_ISSUES.md` items 33/35 before any future module
  that similarly aggregates multiple internal producers into one shared
  event/IRQ resource.
  **RTL-005's own
  implementation session already closed the real, previously-disclosed
  event-bus gap for RTL-002/003/004's own `evt_valid_o`/`evt_record_o`**
  (see Section 4's RTL-005 entry) — RTL-006 onward should wire its own
  event output into RTL-005's real `evt_valid_i[5]` (and so on for each
  subsequent module's own index) as part of that module's own integration,
  the same discipline already established.
  **RTL-005's own real, additional lessons for RTL-006 onward:** (1) **a
  module that is simultaneously an arbiter/store AND its own producer
  needs a genuine two-layer design, not one** — a generation-side one-deep
  pending register (mirroring every other module's own event-generation
  shape) feeding, via the INTEGRATOR's own external wiring (not internal
  self-reference), into the SAME producer-slot mechanism used for every
  other source; collapsing these into one layer either creates a
  tautological self-reference or loses the ability to represent "a new
  candidate while the previous one is still pending" at all — check this
  before assuming a self-referencing port-catalog row is a table-generation
  artifact (RTL-005's was real; RTL-004's `timestamp_i` self-reference
  was not — see `dfc_rtl005.sv`'s own header for the full distinguishing
  reasoning); (2) **a generic per-module struct field (e.g. the common
  `event_overflow`/`event_drop_count` pair every Appendix B struct
  carries) is not guaranteed to have a corresponding REG-002 register** —
  RTL-005 is the first module where this generic pair has genuinely no
  host-visible address at all (`OPEN_ISSUES.md` item 14); don't assume a
  struct's generic fields are automatically host-reachable just because
  every module's struct includes them mechanically; (3) **check every
  EXISTING `dfc_rtl001` instantiation site directly for missing ports
  before trusting a prior session's own "testbenches checked" account** —
  RTL-004's own session only checked `dri_transaction_tb.sv`/
  `regbank_smoke_tb.sv` and missed that `rtl002_integration_tb.sv`/
  `rtl003_integration_tb.sv` were left with `rtl004_control_o`/
  `rtl004_status_i` entirely unconnected (`OPEN_ISSUES.md` item 15) — this
  was only found this session by checking every site, not by trusting the
  prior session's stated scope.
  **Before writing RTL-006's port list (or any module after it): read
  Section 2's standing rule on `pkg::type_t` first.** Every module's own
  spec defines its `control_i`/`status_o` ports as a package-scoped struct
  type — writing them that way, as the spec literally shows, will very
  likely reproduce the exact real production-build failure RTL-002 already
  hit (three times, before the confirmed-working pattern was reached) —
  RTL-003 and RTL-004 both followed the same confirmed-working pattern
  from the start with zero repeat toolchain failures of that specific
  class, confirming the pattern really does generalize cleanly to new
  modules, not just RTL-002. Follow the
  same confirmed, generator-backed workaround pattern (flat `logic [W-1:0]`
  ports/variables sized via generated `dfc_types_pkg::DFC_*_WIDTH`
  constants, individually-named bit-slice wires sliced via generated
  `_HI`/`_LO` constants for fields actually read) from the start. Also
  check every OTHER file that will need to reference the new module's
  control/status types (`dfc_rtl024.sv`'s own instantiation, any new
  testbench, and — new lesson from RTL-003 specifically — `reggen.py`'s
  own field-map mechanism now supports multiple simultaneous consumers
  through one invocation, so a new module's `tools/reggen/rtl<NNN>_
  field_map.json` is picked up automatically by `regenerate.ps1` without
  needing its own separate reggen.py invocation) — this was missed once
  for RTL-002 itself (see Section 2).
- **RTL-003's own real, additional lessons for RTL-004 onward** (beyond the
  `pkg::type_t` pattern above): (1) **check the owning `-002` document, not
  just the module's own spec, when a module spec makes a port-naming claim**
  — RTL-003_RevA.md's `host_irq_n_o` claim was wrong; ARCH-002's own port
  catalog was the real authority (`OPEN_ISSUES.md` item 1); (2) **a sibling
  module's own port-catalog nonconformance can surface concretely during a
  later module's integration** even though it isn't that later module's own
  bug — RTL-002 is still missing `global_irq_enable_o`/`global_event_enable_o`/
  `event_condition_enable_i`/`irq_condition_enable_i` (`OPEN_ISSUES.md`
  item 5); check whether a new module's integration needs anything from an
  earlier "already done" module before assuming that module is fully
  conformant; (3) **a struct with no spare bits for a register's real W1C
  semantics is a genuine ARCH-002-level gap, not something a field-map can
  route around** — `RTL003_EVT_OVERFLOW_STATUS`/`RTL002_EVT_OVERFLOW_STATUS`
  both hit this (`OPEN_ISSUES.md` item 2); expect every future module's own
  `RTL0NN_EVT_OVERFLOW_STATUS` to hit the identical gap until ARCH-002 itself
  is revised; (4) **`nextpnr-ecp5`'s own placement seed is not fixed
  run-to-run when `-Seed` isn't passed** — a real, one-off router-internal
  crash was NOT reproducible on an immediate retry of the identical default
  invocation (`OPEN_ISSUES.md` item 7); don't over-react to a single crashed
  `build_ecp5.ps1` run without first retrying the exact same invocation once.
- **RTL-004's own real, additional lessons for RTL-005 onward:** (1) **read
  every field's real access class in REG-002 against every corresponding
  field in ARCH-002's own struct BEFORE writing any RTL, not after** — this
  session found 3 separate missing-struct-field gaps (2 missing W1C
  clear-request fields, 1 missing status-readback field) purely by
  cross-checking `tools/reggen/rtl004_field_map.json` against REG-002's
  real per-field tables before implementation began, each requiring its
  own approved ARCH-002 edit (`OPEN_ISSUES.md` items 7-9) — do this
  cross-check for RTL-005 too, don't assume a struct is complete just
  because `pkggen.py` validates it tiles its own declared width with no
  gaps (that only proves internal consistency, not completeness against
  REG-002); (2) **a struct field's real width can silently limit what a
  module can ever detect** — RTL-004's `time_snapshot__capture`/
  `time_sync_commit__commit` are 1-bit fields (unlike RTL-003's full-width
  IRQ registers), so RTL-004 has no way to observe host-side reserved-bit
  misuse on those two commands at all; check each new module's own control
  struct field widths against what its spec's "illegal command" fault
  condition actually needs before assuming the fault path is fully
  implementable; (3) **a module whose real output has no real consumer yet
  is still worth broadcasting for real** — RTL-004's `timestamp_o` reached
  RTL-002/RTL-003 for real this session even though neither module is
  RTL-004's own direct integration concern, closing a real, previously-
  disclosed stub (`64'h0`, "RTL-004 does not exist yet") that had been
  sitting in `dfc_rtl024.sv` since RTL-002 was first written — check
  whether a new module's real output can close any such pre-existing
  stub elsewhere in `dfc_rtl024.sv`, not just wire the new module's own
  ports; (4) **`build_ecp5.ps1`'s `$SourceFiles`/synthesis-script gap
  recurs for every new module** — RTL-004 hit the identical missing-
  source-file gap RTL-002 first hit (see this document's own Section 4
  lesson on it); the fix shape (add to both `$SourceFiles` and the
  synthesis `.ys` script's read order, immediately after the previous
  module) was a checklist item for every module going forward, not
  something to rediscover fresh each time. **OBSOLETE as of 2026-08-26 --
  see the "Build script structural fix" entry near the end of Section 4:
  `build_ecp5.ps1` now discovers every `rtl\<domain>\src\*.sv` and
  `rtl\top\*.sv` file automatically at run time, in both `$SourceFiles`
  and the synthesis `.ys` script's read order (the latter is now
  generated FROM `$SourceFiles`, not a second hardcoded list), so this
  checklist item no longer applies to RTL-012 onward. Do not hand-edit
  `$SourceFiles` for a new module going forward -- adding the new
  module's `.sv` file under the correct `rtl\<domain>\src\` (or
  `rtl\top\`) path is sufficient by itself.**
- **RTL-008 (Engine RPM Monitor): COMPLETE TASK SPECIFICATION — STATUS:
  DONE, verified for real (see the RTL-008 entry in Section 4 above for
  the actual `gate.ps1`/`build_ecp5.ps1` results: 12/12 testbenches,
  368/368 checks, lint/formal/coverage all clean; the second
  Monitoring-domain module, and the first module assigned from the
  differential-capable pin range, per `ULX3S_CONNECTION_MAP.md`'s own new
  Section 7 — the single-ended-only range having been fully exhausted by
  RTL-007).** Followed the RTL-003 task-spec template below (items 1-10,
  substituting RTL-008's own module/registers/ports throughout) plus the
  one ARCH-002 struct-growth fix (the seventh real instance of the
  EVENT_OVERFLOW-clear gap class), the real physical pin assignment, one
  real, hard-won testbench-only bug found and fixed during this module's
  own bring-up (test period values tripping ARCH-MON-002's own
  period/count-mode hysteresis switch, `OPEN_ISSUES.md` item 30), and —
  the real, additional, larger piece of this session's work — a real,
  three-part timing-closure investigation and fix into ALREADY-SHIPPED
  RTL-007 itself (`OPEN_ISSUES.md` item 31), required because RTL-007's
  own already-narrow 52.87 MHz margin could not absorb RTL-008 duplicating
  its identical expensive arithmetic. Do not re-execute this for RTL-008
  again; use the RTL-003 template below as the shape for RTL-009's own
  task spec instead, and read `OPEN_ISSUES.md` items 26/27/30/31 BEFORE
  writing RTL-009's own RTL or testbench — RTL-009 shares the identical
  edge-qualification/RPM-divider architecture (now across two channels in
  one module) and must be implemented using the three CONFIRMED-WORKING
  timing fixes from the start, not RTL-007's original, more expensive
  shape.
- **RTL-007 (Rotor RPM Monitor): COMPLETE TASK SPECIFICATION — STATUS:
  DONE, verified for real (see the RTL-007 entry in Section 4 above for
  the actual `gate.ps1`/`build_ecp5.ps1` results: 11/11 testbenches,
  309/309 checks, lint/formal/coverage all clean; the first
  Monitoring-domain module, and the module that exhausted the board's
  single-ended-only pin range, per `ULX3S_CONNECTION_MAP.md`'s own new
  Section 6 — RTL-008 onward must use the differential-capable range).**
  Followed the RTL-003 task-spec template below (items 1-10, substituting
  RTL-007's own module/registers/ports throughout) plus the one ARCH-002
  struct-growth fix (the sixth real instance of the EVENT_OVERFLOW-clear
  gap class), the real physical pin assignment, and two real, hard-won
  RTL/testbench lessons found and fixed during this module's own
  bring-up — a same-cycle registered-copy-vs-live-counter read lag, and a
  reset-to-0-vs-1 off-by-one on an elapsed-cycle counter, both detailed in
  `OPEN_ISSUES.md` items 26-27 specifically because they recur identically
  for RTL-008/009's own, architecturally-identical period measurement —
  do not re-execute this for RTL-007 again; use the RTL-003 template below
  as the shape for RTL-008's own task spec instead, and read
  `OPEN_ISSUES.md` items 26-27 BEFORE writing RTL-008/009's own RTL or
  testbench.
- **RTL-006 (GPIO Controller): COMPLETE TASK SPECIFICATION — STATUS: DONE,
  verified for real (see the RTL-006 entry in Section 4 above for the
  actual `gate.ps1`/`build_ecp5.ps1` results: 10/10 testbenches, 254/254
  checks, lint/formal/coverage all clean; Build ID `20260821_090802`,
  **62.21 MHz PASS at 50 MHz required**, TRELLIS_COMB 20%/TRELLIS_FF 16%
  utilization; the first Infrastructure module with a real, physical,
  bidirectional aircraft-facing pad interface, per `ULX3S_CONNECTION_MAP.md`'s
  own new Section 5).** Followed the RTL-003 task-spec template below
  (items 1-10, substituting RTL-006's own module/registers/ports
  throughout) plus the one ARCH-002 struct-growth fix, the real
  `dfc_rtl002.sv` port-conformance fix (`module_enable_o`/
  `effective_operational_enable_o`), and the two genuine, disclosed-not-
  fixed gaps described above (RTL-002/003/004's own EVT_OVERFLOW_STATUS
  readback, `extract_registers.py`'s compound-owner parsing) — do not
  re-execute this for RTL-006 again; use the RTL-003 template below as
  the shape used for RTL-007's own task spec above.
- **RTL-005 (Event Logger): COMPLETE TASK SPECIFICATION — STATUS: DONE,
  verified for real (see the RTL-005 entry in Section 4 above for the
  actual `gate.ps1`/`build_ecp5.ps1` results: 9/9 testbenches, 205/205
  checks, lint/formal/coverage all clean; Build ID `20260820_200244`,
  **62.70 MHz PASS at 50 MHz required**, TRELLIS_COMB 19%/TRELLIS_FF 15%
  utilization — reached only after finding and fixing a real timing-
  closure bug in the round-robin arbiter, see OPEN_ISSUES.md item 17).**
  Followed the RTL-003 task-spec template below (items 1-10, substituting
  RTL-005's own module/registers/ports throughout) plus the one ARCH-002
  struct-growth fix and the one genuine, disclosed-not-fixed register gap
  described above — do not re-execute this for RTL-005 again.
- **RTL-004 (Timestamp Engine): COMPLETE TASK SPECIFICATION — STATUS:
  DONE, verified for real (see the RTL-004 entry in Section 4 above for the
  actual `gate.ps1`/`build_ecp5.ps1` results: Build ID `20260820_133515`,
  65.52 MHz PASS at 50 MHz required, 162/162 testbench checks).** Followed
  the RTL-003 task-spec template below (items 1-10, substituting RTL-004's
  own module/registers/ports throughout) plus the three ARCH-002
  struct-growth fixes described above — do not re-execute this for RTL-004
  again.
- **RTL-003 (Interrupt Controller): COMPLETE TASK SPECIFICATION — STATUS:
  DONE, verified for real (see the RTL-003 entry in Section 4 above for the
  actual `gate.ps1`/`build_ecp5.ps1` results: Build ID `20260819_210250`,
  63.66 MHz PASS at 50 MHz required, 120/120 testbench checks).** Kept
  below verbatim as the historical record of what was required and
  executed, item by item — do not re-execute this for RTL-003 again; use
  it as the template shape for RTL-004's own task spec instead. Every item
  1-10 below was completed for real, not assumed:
  1. **Read the real spec first.** RTL-003's own spec document lives
     under `docs\` (the specification baseline — see the corrected
     characterization above; not unchangeable, but do not guess at its
     contents from memory or from this document's summaries). Read it
     before writing any code.
  2. **Implement `rtl\infrastructure\src\dfc_rtl003.sv`** following the
     confirmed `pkg::type_t` workaround pattern from Section 2 exactly
     (flat `logic [W-1:0]` ports sized via generated `dfc_types_pkg::
     DFC_RTL003_CONTROL_WIDTH`/`DFC_RTL003_STATUS_WIDTH`, bit-slice wires
     via generated `_HI`/`_LO` constants) — never the spec-literal
     package-scoped struct type, which reproduces an already-solved real
     production build failure.
  3. **CLOSE THE REAL, CONFIRMED RTL-002↔RTL-024 INTERRUPT GAP as part of
     this module's own integration work — this is not a separate task,
     it is what RTL-003 existing actually means:**
     - In `dfc_rtl024.sv` today: `host_irq_n_o` is hard-tied
       (`assign host_irq_n_o = 1'b1;`), and RTL-002's real `irq_req_o`
       output (captured into `rtl002_irq_req`) is fed only into a dummy
       `unused_stub_sink` XOR chain — a real, already-disclosed gap
       (see that assign's own header comment), never a silent oversight,
       but it has never been closed because RTL-003 (the module meant to
       close it) didn't exist until now.
     - RTL-003 must take a real input for RTL-002's `rtl002_irq_req`
       (removing it from the dummy sink), plus stub inputs for every
       other not-yet-real module's future interrupt source per
       ARCH-002's full IRQ source matrix (Appendix C.4, 32 entries) —
       same disclosed-stub pattern already used for `SUBSYS_ENABLE`.
     - RTL-003 must implement real `IRQ_ENABLE`/`IRQ_PENDING`/`IRQ_ACK`/
       `IRQ_ACKED`/`IRQ_CLEAR`/`IRQ_VECTOR` register logic (real
       cross-module forwarding through RTL-001, per item 4 below).
     - `dfc_rtl024.sv`'s `assign host_irq_n_o = 1'b1;` must be replaced
       with RTL-003's real, aggregated interrupt output — this is the
       concrete, testable proof the gap is actually closed, not just
       described as closed.
  4. **Build `tools\reggen\rtl003_field_map.json`** (same format as
     `rtl002_field_map.json` — hand-verified directly against REG-002.md's
     real per-field bit tables, cited by contract ID) and use it with
     `reggen.py` to wire RTL-003's real registers (`IRQ_ENABLE`,
     `IRQ_PENDING`, `IRQ_ACK`, `IRQ_ACKED`, `IRQ_CLEAR`, `IRQ_VECTOR`,
     `IRQ_CONDITION_MASK_LO`/`_HI`, `RTL003_EVT_OVERFLOW_STATUS`, etc.)
     through RTL-001's real register bus — the same real cross-module
     forwarding pattern already proven for RTL-002, not a disconnected
     placeholder repeat of RTL-002's original mistake.
  5. **Update `dfc_rtl001.sv` and `dfc_rtl024.sv` for real** — add
     RTL-003's real ports, delete any stub/placeholder tie-offs for it,
     and check every OTHER file that references types/signals this
     touches (this was missed once for RTL-002 itself — see Section 2's
     own account of that).
  6. **Write a real end-to-end integration test**,
     `verification\testbench\rtl-003\rtl003_integration_tb.sv`, same
     template as `rtl002_integration_tb.sv`: a real host write via the
     DRI path must actually change RTL-003's real behavior, and RTL-003's
     real status must actually reach back to a host read — not just its
     own isolated testbench.
  7. **Update the EXISTING skeleton testbench,
     `verification\testbench\rtl-024\rtl024_skeleton_tb.sv`, to test the
     complete system end-to-end with RTL-003 added — this is a required
     deliverable, not optional.** At minimum: instantiate RTL-003 for
     real in the skeleton alongside RTL-001/002/024, and add a real check
     that a real interrupt condition (e.g. from RTL-002) genuinely
     asserts `host_irq_n_o` through RTL-003's real aggregation logic —
     the concrete test that the gap closed in item 3 actually works
     end-to-end, not just at RTL-003's own boundary.
  8. **Check the other existing testbenches for breakage the same way
     RTL-002's integration did** (`dri_transaction_tb.sv`,
     `regbank_smoke_tb.sv`, `rtl002_state_tb.sv`) — new ports on
     `dfc_rtl001.sv`/`dfc_rtl024.sv` have twice already broken wildcard
     `.*` port connections or declaration ordering in files that don't
     obviously look related; check and fix all of them, don't wait to be
     asked.
  9. **Verify for real, on the real toolchain, before calling any of this
     done** — Icarus simulation for every testbench above, then an actual
     `scripts\gate.ps1` run (lint/sim/formal/coverage) and an actual
     `scripts\build_ecp5.ps1` run (real Yosys synthesis, real
     `nextpnr-ecp5` place-and-route, real timing result), both passing
     clean. Claude Code has direct access to the real PowerShell,
     SymbiYosys, and `nextpnr-ecp5` toolchain this project's chat-interface
     sandbox never had — use that; running the real scripts yourself and
     reporting the real result is expected, not optional, and is exactly
     the gap that made a plain chat interface impractical for this task.
  10. **Do not mark this module "done" in this document's Section 4 status
      list until a real `gate.ps1` run has passed clean and a real
      `build_ecp5.ps1` run has produced a real timing result** — matching
      the standard every other module in this project has already been
      held to.
- **RTL-003 onward: don't stop at "the module compiles and passes its own
  standalone testbench" — that was RTL-002's original mistake** (shipping
  a module completely disconnected from the register bus/host, discovered
  only when the person asked directly whether the system was actually
  interconnected as the spec describes, not a bunch of separate modules
  occupying space on the FPGA). For every module from RTL-003 onward:
  wire it for real into `dfc_rtl001.sv`'s register bus (using `reggen.py`
  v3 + a new, hand-verified `tools/reggen/rtl<NNN>_field_map.json` — see
  Section 3's `tools/reggen/` note for what's still manual there) and
  into `dfc_rtl024.sv`'s module fan-in/fan-out, delete whatever stub that
  module's own placeholder was using, and prove the real round trip with
  a real integration test (`rtl002_integration_tb.sv` is the template:
  real host write → real module behavior change → real module status →
  real host read) — not just that module's own isolated testbench.
  Aircraft-facing modules (RTL-006/007/008/009/010/011/017/018/019/020,
  or whichever module owns which physical signal) additionally need real,
  confirmed-available pin assignments in `fpga/ecp5/ulx3s_dfc.lpf` when
  that module is actually coded — don't invent or assume a pin mapping in
  advance of that module's own implementation session. **Before choosing
  *which* physical position to assign, read `ULX3S_CONNECTION_MAP.md`'s
  Section 4 first** — it records the real, confirmed electrical picture
  (see Section 1's own note too): `gp`/`gn` positions **0-7 (J1) and
  22-27 (J2) are single-ended-only** (9 such positions currently open);
  positions **8-13 (J1) and 14-21 (J2) are differential-capable** but can
  also be used single-ended if genuinely needed. Every aircraft-facing
  module built so far uses ordinary single-ended signals per its own real
  spec — **exhaust the single-ended-only positions first** (they cover
  RTL-006's 8 channels comfortably on their own) before using a
  differential-capable position for an ordinary signal; that's a real,
  available fallback, not a hard restriction, just the less-preferred
  choice when a single-ended-only position is available instead. **When
  the assignment is made, also update `ULX3S_CONNECTION_MAP.md` (repo
  root) in the same session, not as an afterthought** — that document
  exists specifically so the `gp<N>`-to-signal correspondence and
  physical J1/J2 position for every wired interface stays in one place,
  confirmed against the real board rather than re-derived from memory
  each time. Add a new section to it the same way its existing SPI
  section was built: transcribe the real, new `.lpf` addition, confirm
  the physical header position, and cite how each fact was actually
  confirmed — don't just restate a section from an older revision of
  this same file. If a pin assignment is made in `.lpf` but
  `ULX3S_CONNECTION_MAP.md` isn't updated in the
  same session, treat that as an incomplete task, not a follow-up to
  defer.
- **RTL-002's real full-chip `nextpnr-ecp5` place-and-route timing-
  closure checkpoint is DONE, most recently reconfirmed via a real
  `build_ecp5.ps1` run** (Build ID `20260818_093015`, after the real
  self-loop combinational-fix session described in Section 4): real
  Yosys 0.66+252 synthesis, real place-and-route, **68.12 MHz PASS at
  50 MHz required** (improved from the original 61.20 MHz confirmation,
  Build ID `20260817_131045`), converged normally with no
  `--timing-allow-fail` needed, 12% LUT/7% DFF utilization. This closes
  out the item that used to sit here as outstanding — sandbox Yosys
  `proc`/`opt`/`check` elaboration alone was correctly never treated as
  equivalent to a real place-and-route result earlier in this same
  session, and that distinction held: don't let
  "Yosys elaboration passed" get conflated with "timing closure
  confirmed" for any future module either — they are different claims
  with different evidence, and only the latter is what actually happened
  here.
- **The person is a solo developer** currently pursuing funding; they
  have made a deliberate choice not to parallelize FPGA/RTL work with
  host-software or aircraft-simulator-software work right now, since
  context-switching between those skill domains is costly for a team of
  one. Respect this — don't suggest starting host/aircraft software work
  as a "you could do this in parallel" suggestion unless asked. The
  explicit goal is to push the FPGA/RTL implementation as complete as
  possible on its own first, partly to support an in-progress funding
  conversation with a more substantial demonstrated prototype.
- **After each natural domain batch of new modules**, **run a real
  full-chip synthesis/place-and-route checkpoint** via `build_ecp5.ps1`
  — not full formal verification each time necessarily, just confirm the
  design still fits and still closes timing. This is specifically to
  catch a timing/routing-congestion problem while only a handful of new
  modules are suspect, rather than discovering it only after all 24 are
  done. Watch for: did `nextpnr-ecp5` converge normally, or did it need
  `--timing-allow-fail`, run unusually long, or report a new marginal/
  failing critical path — **this**, not raw utilization percentage, is
  the real risk category this project has confirmed evidence for (both
  real timing bugs found in RTL-001/the SPI bridge were about routing
  distance/combinational depth, not resource exhaustion). Given
  RTL-001 + the SPI bridge + the RTL-024 skeleton has consistently
  synthesized to well under half the ECP5-85F's capacity, resource fit
  is not expected to be the binding constraint as more modules are
  added — timing/convergence is.
- **RTL-023's user logic island can be reduced in scope as a size-release
  valve** if resource fit ever becomes genuinely tight — this is
  low-cost specifically because RTL-022 (what it routes to/from) is
  deliberately, entirely inert in this revision, so there's no real
  functional behavior to lose by trimming it.
- **Host-side HIL (Dragon Console + one VisionFive2) is already
  unblocked** — RTL-001 and the SPI bridge are real and hardware-
  verified. **Aircraft-side HIL (the second VisionFive2 + GPIO/
  protoboard) is deliberately deferred** until enough of RTL-002–023 is
  real to make testing it meaningful. Both of these are currently on
  hold per the person's own stated priority (finish more RTL first), not
  because of any technical blocker on the host-side half. Physical board
  flashing plus a minimal host diagnostic script (not the full Dragon
  Console) is the planned first real hardware milestone, deliberately
  held in reserve to trigger on a concrete external event (e.g., a VC
  response to an outreach email already sent) rather than done
  preemptively.
- **The original 12-issue punch list (script/build-automation cleanup)
  is fully closed as of this document.** All of: `.ps1`-only scripts
  (old `.sh` retired), the wildcard-import standing policy (this
  section, Section 2, and `RTLSTD-LANG-008` itself all confirmed
  correctly general), and full build automation (`regenerate.ps1`, all
  six package generators, wired into `gate.ps1`/`build_ecp5.ps1`) are
  done and confirmed via real runs. Nothing outstanding from that list
  remains — the next work is RTL-003, not more tooling cleanup (RTL-002
  itself is now done, see Section 4).

---

## 6. Business/product context (relevant if asked to help with anything pitch- or funding-adjacent)

- **REAL, DELIBERATE CHANGE IN PROJECT PURPOSE (superseding the
  investor-facing framing below where the two conflict):** the person
  has determined there is **no direct market for the Dragon Flight/
  Dragon Core product as originally conceived**, and has pivoted this
  project's actual goal to a **demo/portfolio tool for future
  engineering-consulting work**, not a product being pitched for its own
  sake. See Section 5's scope-change entry for the concrete technical
  consequence (target module count now 21, not 24). This purpose pivot
  itself doesn't require editing any specification — only the eventual
  purpose of the finished system, and which modules get built at all,
  are affected by it (specs still get updated through the normal,
  approved process whenever a real gap is found, same as always — see
  Section 3). If asked to help with consulting-facing
  positioning, framing, or outreach material going forward, treat that
  as the live, current objective — not the VC-investor framing further
  below, which reflects an earlier, since-superseded goal for this same
  underlying project. The same accuracy discipline applies regardless of
  audience: don't round up "21 real, working modules" into more than
  that, and don't describe RTL-022/023 as anything other than
  deliberately, permanently out of scope.
- Company: **Royal Cubit Aerospace.** Product family: **Dragon Flight /
  Dragon Core.**
- The person is a solo developer explicitly using AI as their entire
  design team, and is building a funding narrative partly around that
  fact. **Accuracy of any claim matters more than usual here** — a
  technical claim in pitch material should match verified project state
  exactly, not be rounded up. (A real example from this project: the
  word "prototype" in an actual investor email was flagged as ahead of
  verified state, since the board has never been physically flashed —
  the underlying RTL/verification work was accurately described as
  strong on its own terms, without needing that specific word.)
- **An initial outreach email and pitch deck/video have already been
  sent to at least one VC firm.** The person's stated plan is to push
  the RTL implementation (RTL-002 through RTL-023) as far as possible
  before any response arrives, specifically so a more complete prototype
  can be shown if a conversation develops — and to hold physical board
  flashing plus a minimal host diagnostic script in reserve as the
  concrete next hardware milestone, triggered by that response rather
  than done preemptively.
- If asked to review pitch material, business plans, or similar for
  technical accuracy: check specific claims against the real state
  documented in Section 4 above, not against how impressive the project
  generally is. Don't weigh in on business/pitch strategy itself — stay
  scoped to technical accuracy when that's what's being asked for.
