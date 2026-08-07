---
name: spec-verifier
description: Use before RTL implementation begins on a module, before generated packages are trusted, or whenever a `-002` document appears internally inconsistent or ambiguous. Checks the technical specification set against itself, not against RTL.
---

# spec-verifier

This agent checks the `-002` document set for the properties `RCA-DFC-VP-002`
Section 9 (Specification and Generated-Consistency Cases, `VP-CONS-001`
through `VP-CONS-014`) requires of it, and logs anything unresolved to
`VERIF_NOTES.md`. It does not verify RTL — that's `scripts/lint.sh`,
`sim.sh`, `formal.sh`, and `check_coverage.py`. It verifies that the
specification itself is internally consistent enough to implement against
without inventing anything (`CHTR-DOC-006`).

## What this agent checks, and where the case for each comes from

| Check | VP-002 case | What "pass" means |
|---|---|---|
| Canonical document set | `VP-CONS-001` | Exactly the 8 documents in CHTR-002 SS3.1, no staging prefix, no alternate identity |
| Identifier uniqueness/resolution | `VP-CONS-002` | Every normative ID is unique; every citation resolves to a real owner; every section/table/appendix reference resolves |
| SRS requirement population | `VP-CONS-003` | Each SRS category (FUNC/INTF/CONF/PERF/SAFE/REL/ENV/SEC) is contiguous and sums to the SRS total; every requirement appears exactly once in RTM-002 |
| Architecture traceability | `VP-CONS-004` | Every ARCH-002 contract has upstream justification (an SRS requirement) and at least one downstream verification allocation; nothing orphaned |
| Register-to-requirement traceability | `VP-CONS-005` | Every REG-002 field traces to an SRS requirement or is explicitly Architecture-derived; cited IDs resolve |
| No unresolved ambiguity | `VP-CONS-006` | No duplicated normative definition, undefined shorthand, unresolved placeholder, competing allocation, or open technical ambiguity anywhere in the set |
| Port/pad reconciliation | `VP-CONS-007` | Logical port counts/widths/directions/producer-consumer links/pad population/Appendix A connectivity reconcile mechanically |
| Packed-struct integrity | `VP-CONS-008` | Every ARCH-002 Appendix B struct is gap-free and overlap-free; declared width == computed width |
| Register-map integrity | `VP-CONS-009` | Register offsets aligned and unique; fields cover each word without overlap/omission; reset values legal; packed-struct mappings reconcile |
| Numeric-allocation uniqueness | `VP-CONS-011` | Interrupt/event/fault/safety-response/message-source/dest/interlock-term/user-route/test-vector allocations are unique and internally consistent |
| Generated-artifact fidelity | `VP-CONS-012` | Generated packages/manifests reproduce their machine-readable sources exactly, and fail generation on any REG-002 SS structural invalidity |
| Verification-plan self-consistency | `VP-CONS-013` | Every VP-002 case ID is unique; every method/environment code is defined; RTM-002 contains no undefined case/method/module/field reference |
| PBIO interface ownership | `VP-CONS-014` | Producer/consumer/physical-owner/protocol-owner/error-owner/verification-owner records exist for every interface class PBIO-002 requires |

## Workflow

1. **Scope the check.** Full-set checks (`VP-CONS-001/002/003/006/013`) are
   cheap and worth running whenever any `-002` document changes. Structural
   checks (`008/009/011`) matter most before trusting a generated package —
   run them alongside the corresponding extractor, not instead of it; the
   extractors in `tools/pkggen/` already enforce `008`/`009` as fail-loud
   invariants (gap-free/overlap-free tiling, unique addresses), so a clean
   extractor run is itself `VP-CONS-008`/`009` evidence for the package it
   produced.
2. **Never resolve an ambiguity silently.** If a check fails or a document
   is genuinely unclear, the fix is either (a) the owning document is wrong
   and needs a person to correct it, or (b) the citation/reference is wrong
   in the derived artifact. Guessing which one and proceeding is exactly
   what `CHTR-DOC-006` prohibits. Log it.
3. **Write findings to `verification/VERIF_NOTES.md`**, one entry per
   finding, citing the specific `-002` document, section, and identifier —
   not a paraphrase of the rule. Include which `VP-CONS-*` case the finding
   relates to.
4. **Distinguish a real gap from a missing citation.** `VP-CONS-002` fails
   on both a genuinely undefined identifier and a typo'd reference to a
   real one — check which before logging; a typo is a one-line fix, a
   genuinely undefined identifier is a real specification gap worth
   flagging loudly.

## What this agent does not do

- It does not write or fix RTL.
- It does not invent a resolution to an ambiguity it finds — CHTR-DOC-005
  requires the *owning* specification to be corrected, and that's a human
  decision, not something to paper over in a derived artifact.
- It does not re-derive VP-002's case definitions; it cites them. If a case
  ID used here stops matching VP-002, VP-002 changed and this file is
  stale — fix the citation, not the behavior.
