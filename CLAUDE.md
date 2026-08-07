# CLAUDE.md — Dragon Core (Revision A, `-002` baseline)

This file governs how Claude Code works in this repository. It is itself a
derived artifact under `RCA-DFC-CHTR-002` SS3.3: it implements the eight-
document technical specification set and must not become an alternate
source of product definition (CHTR-DOC-006). If anything below conflicts
with the `-002` documents, the documents win and this file is wrong.

## The eight normative documents

Located under `docs/`. Each owns exactly one subject (CHTR-002 SS3.1); no
other document may repeat, strengthen, weaken, specialize, or redefine an
owned fact (CHTR-DOC-003).

| Doc | Owns |
|---|---|
| `docs/business/RCA-DFC-CHTR-002.md` | Mission, scope, platforms, external-host model, top-level constraints |
| `docs/requirements/RCA-DFC-PBIO-002.md` | Device/platform/board/aircraft/software/interface/verification responsibility boundaries |
| `docs/requirements/RCA-DFC-SRS-002.md` | Externally observable behavior, capacities, performance, timing, safety, reliability |
| `docs/architecture/RCA-DFC-ARCH-002.md` | Internal decomposition, module allocation, algorithms, states, priorities, internal interfaces, clocks/resets, CDC/RDC, shared types, numeric allocations |
| `docs/architecture/RCA-DFC-REG-002.md` | Host-visible register offsets, fields, access classes, reset values, encodings, validation, read/write behavior, side effects |
| `docs/verification/RCA-DFC-VP-002.md` | Verification methods, environments, cases, coverage, required outcomes |
| `docs/verification/RCA-DFC-RTM-002.md` | Relationships among requirement/architecture/register/module/verification identifiers |
| `docs/architecture/RCA-DFC-RTL-STD-002.md` | SystemVerilog implementation rules, coding conventions, structural rules |

## Working rules for Claude Code in this repo

1. **Never invent behavior.** CHTR-DOC-006: no RTL, spec, testbench, or
   integration artifact may add behavior absent from its owning `-002`
   document. If a fact is missing, say so in `OPEN_ISSUES.md` — do not fill
   the gap with a plausible-sounding default.
2. **Cite the owner, don't restate it.** When authoring a module spec,
   script, or comment that depends on a fact from another document, cite the
   identifier (e.g. `ARCH-VAL-002`, `REG-ENC-005`) rather than copying the
   rule's text. If the owning document changes, restated copies silently
   rot; citations don't.
3. **Generated files are not editable.** Per `RTLSTD-ORG-003`: everything in
   `include/`, `tools/*/*.json` outputs, and `rtl/infrastructure/generated/`
   is produced by `tools/pkggen/` and `tools/reggen/` from the `-002` docs.
   If output is wrong, fix the extractor or the input JSON, then regenerate
   — never hand-edit generated output. `RTLSTD-ORG-010`: a clean run of the
   generators must reproduce every generated file with no manual patching.
4. **One register/type/interrupt source of truth.** `tools/pkggen/extract_registers.py`,
   `extract_types.py`, and `extract_irqfault.py` are the sole mechanical path
   from REG-002/ARCH-002 into `dfc_registers_pkg`, `dfc_types_pkg`,
   `dfc_events_pkg`, and `dfc_interrupt_pkg`. Each extractor fails loud
   (nonzero exit, nothing written) rather than emitting a guess — see
   `RTLSTD-ORG-004`. If an extractor run fails, that is a real gap in either
   the extractor or the source document; do not work around it by hand-
   assembling the missing package.
5. **Module specs are derived, not source.** RTL module specs under
   `docs/rtl_specs/` implement the `-002` set; they never define new
   behavior (CHTR-DOC-006). Each spec must trace every functional claim to
   an ARCH-002/REG-002/SRS-002 identifier via RTM-002.
6. **Naming is fixed by RTL-STD-002 SS8**, not by convenience: `dfc_` module
   prefix, `_pkg` package suffix, `_q`/`_d` for registered/next state,
   `_i`/`_o` port suffixes, `_n` for active-low. Generated register/field
   identifiers must match REG-002 exactly (`RTLSTD-NAME-001`).
7. **RTL-024 is the sole integration top** (`RTLSTD-MOD-011` through `-015`):
   it instantiates every RTL-001..023 child exactly once, exposes only
   Architecture-catalog ports, and never uses hierarchical references into
   child state.
8. **Log ambiguities, don't silently resolve them.** Anything genuinely
   underspecified or conflicting in the `-002` set goes in `OPEN_ISSUES.md`
   with the specific section/identifier in question. The `spec-verifier`
   agent (`.claude/agents/spec-verifier.md`) is the tool for surfacing these
   before they reach RTL.

## Directory map (populated, not redesigned)

```
docs/            the 8 -002 documents, split by subject (see table above)
include/         generated dfc_*_pkg.sv — do not hand-edit
tools/pkggen/    3 extractors + pkggen.py + their JSON inputs/outputs
tools/reggen/    reggen.py + per-module regbank slice JSON
rtl/             RTL-001..024 source, domain-nested; generated/ subtrees are
                 machine output only
scripts/         lint.sh, sim.sh, formal.sh, gate.sh, check_coverage.py, hooks
verification/    testbench/, assertions/, formal/, regression/, coverage/
```

## Regenerating the tooling output

```bash
python3 tools/pkggen/extract_registers.py docs/architecture/RCA-DFC-REG-002.md  tools/pkggen/dfc_registers_pkg.json
python3 tools/pkggen/extract_types.py      docs/architecture/RCA-DFC-ARCH-002.md tools/pkggen/dfc_types_pkg.json
python3 tools/pkggen/extract_irqfault.py   docs/architecture/RCA-DFC-ARCH-002.md tools/pkggen/dfc_irqfault.json
# dfc_version_pkg.json / dfc_constants_pkg.json / dfc_events_pkg.json /
# dfc_interrupt_pkg.json are assembled from the above three extractors'
# already-verified output (see each file's "_source" field for provenance).
python3 tools/pkggen/pkggen.py tools/pkggen/dfc_registers_pkg.json include/dfc_registers_pkg.sv
# ...repeat pkggen.py for each of the 6 packages...
python3 tools/reggen/reggen.py tools/reggen/dfc_rtl001_regbank_slice.json tools/pkggen/dfc_registers_pkg.json rtl/infrastructure/generated
```

Every extractor is fail-loud: a nonzero exit with no output means either the
source document changed shape or a genuine spec ambiguity was found. Fix the
cause, don't suppress the check.

## Open items

Anything found while working in this repo that isn't resolvable by reading
the `-002` documents more carefully belongs in `OPEN_ISSUES.md`, not in a
comment buried in RTL.
