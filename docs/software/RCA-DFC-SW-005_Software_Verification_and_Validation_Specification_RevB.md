**ROYAL CUBIT AEROSPACE**

**DRAGON CORE™**

**SOFTWARE VERIFICATION AND VALIDATION  
SPECIFICATION**

| Field | Value |
|---|---|
| Document Number | RCA-DFC-SW-005 |
| Revision | B |
| Status | Technical Baseline |
| Product | Dragon Core™ Revision A |
| Program | Dragon Flight™ Core ASIC Development Program |
| Organization | Royal Cubit Aerospace |
| Release Date | 2026-08-07 |

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | Undated | Historical initial baseline supplied as reference only | Royal Cubit Aerospace |
| B | 2026-08-07 | Rebuilt beneath the eight controlling specifications for verification and validation of external-host software | Royal Cubit Aerospace |

# Approval

| Role | Name | Signature | Date |
|---|---|---|---|
| Prepared By |  |  |  |
| Reviewed By |  |  |  |
| Approved By |  |  |  |

# Table of Contents

1. Purpose
2. Scope
3. Applicable Documents
4. Verification Configuration Item Identification
5. Verification Strategy
6. Verification Levels
7. Unit Verification
8. Integration Verification
9. System Verification
10. FPGA Prototype Validation
11. ASIC Bring-Up Validation
12. Hardware-in-the-Loop Validation
13. Regression Testing
14. Formal Verification Coordination
15. Static Analysis
16. Code Coverage
17. Requirements Traceability
18. Test Environment
19. Test Automation
20. Test Data Management
21. Defect Management
22. Configuration Management
23. Verification Reviews
24. Verification Deliverables
25. Exit Criteria
26. Baseline Statement

# 1. Purpose

## 1.1 Purpose of this Specification

This Software Verification and Validation Specification establishes the mandatory process, methods, evidence, review, traceability, and release criteria used to verify and validate executable software and software-derived artifacts that support Dragon Core Revision A from outside the fabricated device.

Dragon Core is a processor-free digital ASIC. It contains no processor, firmware, bootloader, operating system, executable memory, software runtime, HAL, BSP, driver, middleware, stack, heap, or application. All software governed by this specification executes on an external host or in an external development, verification, manufacturing, or maintenance environment.

This specification is subordinate to the eight controlling technical specifications identified by `RCA-DFC-CHTR-002`, Section 3.1. It defines software-only verification and validation obligations. It does not redefine product scope, responsibility boundaries, externally observable device behavior, internal hardware architecture, register semantics, controlling device-verification cases, controlling trace relationships, or RTL implementation rules.

## 1.2 Objectives

The objectives are to:

- demonstrate that each applicable software requirement is implemented correctly and completely;
- demonstrate that released software satisfies its intended external-host use without relying on undocumented device behavior;
- detect defects in source, generated artifacts, APIs, platform adapters, build products, configuration schemas, tests, tools, and documentation;
- verify correct use of the SRS-defined SPI host interface and Register-Map-defined programming model;
- establish objective, reproducible, configuration-controlled release evidence;
- maintain bidirectional traceability among software requirements, implementation, verification cases, results, defects, deviations, and released artifacts; and
- contribute software evidence to Verification-Plan-owned host-boundary, FPGA, HIL, and post-silicon cases without creating alternate device requirements or acceptance criteria.

## 1.3 Normative Language

The terms **shall** and **shall not** identify mandatory requirements. **Should** identifies a preferred practice. **May** identifies a permitted option. A statement without one of these terms is explanatory unless it is part of a table explicitly identified as mandatory.

`SWVV-PUR-001` — Every released software configuration item within Section 2 shall conform to the applicable requirements of this specification.

`SWVV-PUR-002` — Verification evidence shall apply only to the exact source, generated inputs and outputs, target profile, toolchain, dependencies, options, environment, tests, and artifact identities represented by that evidence.

`SWVV-PUR-003` — Validation shall establish fitness for the approved external-host intended use; it shall not be represented as aircraft certification, installation approval, operational authorization, or validation of functions outside the allocated software boundary.

## Table 1-1. Verification Objectives

| Objective | Required outcome |
|---|---|
| Correctness | Software behavior conforms to approved software requirements and consumed controlling contracts. |
| Completeness | Every applicable normative software requirement has an approved verification disposition. |
| Boundary conformity | Software uses only documented external-host interfaces and preserves PBIO ownership. |
| Evidence integrity | Results are repeatable, attributable, reviewable, and configuration controlled. |
| Release readiness | No unresolved release-blocking defect, gap, failed required case, or controlling-specification flag remains. |

# 2. Scope

## 2.1 Included Software

This specification applies, when developed, delivered, or used to produce release evidence by Royal Cubit Aerospace, to:

- external embedded-host firmware;
- external-host HALs, BSPs, SPI drivers, interrupt adapters, and platform services;
- the portable Dragon Core driver and typed API implementation;
- middleware, Dragon SDK libraries, configuration and recovery services;
- Dragon Console™, Dragon Gateway™, and Dragon Sentinel™ software;
- FPGA-validation, HIL, post-silicon bring-up, manufacturing, diagnostic, and maintenance software;
- generators and generated host bindings;
- protocol encoders, decoders, independent models, reference models, simulators, test doubles, fixtures, scripts, and test harnesses;
- build, packaging, analysis, coverage, reporting, and release automation; and
- user documentation, examples, configuration schemas, compatibility data, and release manifests whose correctness affects software use.

## 2.2 Included Activities

Included activities are review, static analysis, unit test, component test, integration test, software-system test, host-conformance test, FPGA and HIL software validation, post-silicon software validation, formal analysis, structural coverage, requirements coverage, regression, robustness and fault-injection test, test-data control, anomaly management, evidence review, and release qualification.

## 2.3 Excluded Scope

This specification does not own or establish:

- Dragon Core RTL verification, device acceptance criteria, device coverage requirements, or device-verification evidence definitions owned by `RCA-DFC-VP-002`;
- product scope, interfaces, device behavior, internal architecture, register meaning, or controlling trace relationships;
- FPGA-to-ASIC RTL equivalence, synthesis, gate-level, timing, DFT, physical implementation, package, pad, power, or silicon qualification;
- external analog conditioning, transceivers, wiring, power drive, aircraft-energy control, or board electrical qualification;
- customer-developed software not incorporated into the controlled Dragon Flight software baseline;
- aircraft application functions, flight-control algorithms, navigation, guidance, mission management, or installation-specific operational policy; or
- aircraft safety assessment, certification basis, installation approval, or operational authorization.

## 2.4 Boundary Rules

`SWVV-SCP-001` — Software verification shall use the ownership allocations of `RCA-DFC-PBIO-002` and shall distinguish software, host controller, board/equipment, logical wrapper, device, and verification-environment responsibilities.

`SWVV-SCP-002` — A test environment shall not compensate for, conceal, or waive an undefined or nonconforming responsibility at an ownership boundary.

`SWVV-SCP-003` — FPGA-only observability, RTL hierarchy, scan access, testbench backdoors, shared-buffer physical addresses, or undocumented platform paths may support diagnosis only when authorized; they shall not be the sole pass/fail oracle for production-interface behavior and shall not become a production software dependency.

`SWVV-SCP-004` — A software test shall not claim device conformity beyond the exact controlling Verification Plan outcome to which its evidence is accepted.

`SWVV-SCP-005` — Software verification shall demonstrate that no delivered component assumes an on-device processor, on-device firmware, direct Dragon Core memory mapping, OpenFrame-provided host service, or any host path other than the controlling external interface.

## 2.5 Controlling-Specification Change Flags

| Flag | Owning specification | Finding | Required action |
|---|---|---|---|
| None | — | The eight controlling specifications provide a consistent processor-free product boundary, external-host programming contract, verification ownership, host-system cases, coverage outcomes, evidence definitions, and trace basis sufficient for this software V&V baseline. | No controlling-specification change is required by Revision B. |

## Table 2-1. Scope Summary

| Included | Excluded |
|---|---|
| External-host software and generated artifacts | On-device software, because none exists |
| Software-only requirements and intended-use validation | Alternate device behavior or register definitions |
| Contribution to VP-owned host, FPGA, HIL, and ASIC cases | Ownership of VP cases or device acceptance |
| Verification tools and evidence affecting software release | Aircraft-level certification and installation assurance |

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and subject ownership of the following documents are defined only by `RCA-DFC-CHTR-002`, Section 3.1. This table is an informative software-verification use view and creates no document-order precedence.

| Document | Sole controlling subject used by this specification |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product mission, scope, exclusions, platforms, external-host model, fixed constraints, and single-owner rules |
| `RCA-DFC-PBIO-002.md` | Device, software, platform, board, aircraft, interface, data, safety, and verification responsibility boundaries |
| `RCA-DFC-SRS-002.md` | Externally observable behavior, host-interface obligations, capacities, performance, timing, safety, reliability, and logical interfaces |
| `RCA-DFC-ARCH-002.md` | Internal decomposition, algorithms, states, priorities, interfaces, protocols, clocks, resets, crossings, shared resources, and logical wrapper |
| `RCA-DFC-REG-002.md` | Host-visible offsets, fields, access classes, encodings, reset values, validation, read/write behavior, protection, and side effects |
| `RCA-DFC-VP-002.md` | Device-verification methods, environments, cases, coverage, required outcomes, and evidence definitions |
| `RCA-DFC-RTM-002.md` | Relationships among existing controlling requirement, architecture, register, RTL, and verification identifiers |
| `RCA-DFC-RTL-STD-002.md` | SystemVerilog implementation and RTL conformance rules |

## 3.2 Software Baseline Documents

| Document | Software subject verified |
|---|---|
| `RCA-DFC-SW-001`, Revision C | External-host software architecture |
| `RCA-DFC-SW-002`, Revision B | External embedded-host firmware requirements |
| `RCA-DFC-SW-003`, Revision B | External-host HAL, driver, and BSP API requirements |
| `RCA-DFC-SW-004`, Revision B | Software coding, review, analysis, test, trace, build, and release rules |
| `RCA-DFC-SW-005`, Revision B | Software verification and validation process, evidence, and release criteria |

The supplied Revision A of this document is historical reference only. Any historical statement assigning executable software to the fabricated device, assuming a RISC-V or other internal processor, using direct MMIO, relying on Wishbone as the external host interface, or assigning device-verification ownership to this software specification is superseded.

## 3.3 Authority and Single-Definition Rules

`SWVV-DOC-001` — All verification activities shall preserve `CHTR-DOC-001` through `CHTR-DOC-007`.

`SWVV-DOC-002` — Subject ownership, not document order, shall resolve authority.

`SWVV-DOC-003` — Tests, models, oracles, expected-result tables, generated bindings, trace databases, and reports shall cite controlling identifiers and shall not repeat, strengthen, weaken, specialize, or redefine an owned technical fact.

`SWVV-DOC-004` — If verification reveals a conflict, ambiguity, omission, untestable requirement, missing outcome, or incomplete definition, affected work shall stop at that boundary and a change flag shall be raised against the owning specification.

`SWVV-DOC-005` — A local assumption, test waiver, defect disposition, model behavior, or implementation convention shall not repair a controlling-specification defect.

`SWVV-DOC-006` — The controlling RTM shall not be modified by a subordinate software trace record unless the RTM owner formally accepts a scope change.

## 3.4 Referenced Standards and Project Profiles

Language, compiler, MISRA, CERT, security, quality, assurance, and tool-confidence profiles are selected and version-pinned by `RCA-DFC-SW-004` and the applicable release compliance plan. This specification does not create a second coding-standard profile or aircraft-certification claim.

## Table 3-1. Conflict Disposition

| Detected issue | Required disposition |
|---|---|
| Software implementation disagrees with software requirement | Correct implementation or revise the owning software specification through change control. |
| Software requirement disagrees with controlling fact | Flag and correct the controlling owner before revising dependent software requirements. |
| Test oracle disagrees with owning requirement | Correct the oracle; observed implementation behavior is not authority. |
| Controlling behavior is absent or ambiguous | Block affected verification and raise a controlling-specification change flag. |

# 4. Verification Configuration Item Identification

## 4.1 Verification Configuration Item Definition

A Software Verification Configuration Item (SVCI) is a uniquely identified, version-controlled software product, generated artifact, test asset, tool configuration, environment definition, data set, document, or evidence package whose identity can affect a verification result or release decision.

## 4.2 Required SVCI Classes

| SVCI class | Required examples |
|---|---|
| Production software | Firmware images, libraries, applications, services, HALs, BSPs, drivers, and public headers |
| Generated products | Register bindings, metadata, schemas, compatibility tables, documentation extracts, and manifests |
| Source inputs | Software specifications, machine-readable register source, source code, build scripts, generator source, and configuration |
| Verification software | Unit tests, harnesses, test doubles, independent models, protocol analyzers, fixture control, and result checkers |
| Tools and environment | Compiler, linker, generator, analysis tools, coverage tools, operating system, container/image, target board, controller, and fixture |
| Data and expected results | Vectors, known answers, seeds, configurations, fault schedules, timing profiles, and golden files |
| Evidence | Logs, reports, traces, captures, coverage databases, reviews, defects, deviations, approvals, and release summary |

## 4.3 Identification Requirements

`SWVV-CI-001` — Every SVCI shall have a stable identifier, version or immutable digest, owner, purpose, origin, approval state, and relationship to the applicable release.

`SWVV-CI-002` — A test result shall record the identities of the software under test, test implementation, generated bindings, model or device build, target profile, toolchain, dependencies, environment, data set, configuration, and seed when applicable.

`SWVV-CI-003` — Production and engineering configurations shall be separate SVCIs with separate identities, build graphs, manifests, tests, and release dispositions.

`SWVV-CI-004` — A generated output shall record its generator identity, input identities, generation options, output digest, and consistency-check result.

`SWVV-CI-005` — A result missing any identity required to reproduce or interpret it shall be incomplete and shall not satisfy release evidence.

`SWVV-CI-006` — A modified SVCI shall invalidate prior evidence according to documented impact analysis; evidence shall not be carried forward solely because a filename or version label is unchanged.

## 4.4 Verification Baseline

Before an execution contributes release evidence, a verification baseline shall identify:

- applicable controlling and software specification revisions;
- source and generated-artifact revisions;
- release and engineering profiles;
- target hardware, BSP, operating system, toolchain, dependencies, and fixtures;
- selected cases, procedures, data, and expected-result sources;
- approved deviations and known limitations; and
- required evidence and acceptance reviewers.

## Table 4-1. SVCI Acceptance Record

| Field | Required content |
|---|---|
| Identity | Stable ID, revision, digest, and configuration state |
| Authority | Owner and approved source |
| Applicability | Release, target, profile, and selected cases |
| Dependencies | Exact upstream SVCIs and environment |
| Evidence | Result artifacts and review state |
| Disposition | Pass, fail, blocked, not applicable, or approved deviation |

# 5. Verification Strategy

## 5.1 Strategy

Software verification shall combine prevention, early defect detection, independent expected results, layered dynamic testing, boundary-conformance testing, regression, review, traceability, and controlled release evidence. Validation shall exercise approved external-host intended uses on representative platforms and at realistic ownership boundaries.

## 5.2 Verification Methods

| Method | Software use |
|---|---|
| Review and inspection | Requirements, design, source, generated output, configuration, procedure, result, and documentation examination |
| Static analysis | Language, coding-rule, data-flow, concurrency, resource, security, and defect analysis without execution |
| Analysis | Bounds, timing, stack, resource, compatibility, equivalence, data-flow, and impact arguments |
| Dynamic test | Controlled execution with self-checking expected outcomes |
| Formal method | Proof or exhaustive bounded analysis of suitable software properties |
| Demonstration | Supplementary intended-use observation; never the sole basis when an objective checker is practical |

Device-facing evidence accepted for a controlling `VP-*` case shall use the method, environment, required components, outcome, and evidence definition owned by `RCA-DFC-VP-002`. Software-only methods may add rigor but shall not alter that controlling case.

## 5.3 Independent Oracles

`SWVV-STR-001` — Expected results shall derive from approved owning requirements, independently calculated known answers, or an independent model; production code shall not generate its own expected result.

`SWVV-STR-002` — A protocol encoder and its checker shall not share the same unverified encoding function, lookup table, or generated constant path when that sharing can mask an error.

`SWVV-STR-003` — Generated host bindings shall be checked against the approved machine-readable Register Map source by an independent consistency mechanism.

`SWVV-STR-004` — Observed device or software behavior shall not become the expected result merely because it is repeatable.

## 5.4 Verification Independence

`SWVV-STR-005` — The author of production code shall not be the sole approver of its requirements interpretation, safety- or security-relevant logic, public API, concurrency, recovery, or release evidence.

`SWVV-STR-006` — Independence shall increase with failure consequence, complexity, novelty, platform dependence, concurrency, privilege, persistent-data impact, and difficulty of detecting an error in operation.

`SWVV-STR-007` — A verification reviewer shall have sufficient access, competence, authority, and organizational freedom to reject incomplete or nonconforming evidence.

## 5.5 Risk and Negative Testing

`SWVV-STR-008` — Risk-based prioritization may change execution order but shall not remove verification of an applicable normative requirement.

`SWVV-STR-009` — Each interface shall be tested for nominal, boundary, invalid, reserved, malformed, unauthorized, unavailable, timeout, cancellation, partial-completion, resource-exhaustion, concurrency, reset, and recovery behavior as applicable.

`SWVV-STR-010` — State-changing device operations shall be tested for failure before submission, after possible acceptance, during response, after definitive completion, and during reconciliation; no ambiguous operation shall be blindly retried.

## 5.6 Result States

Every case execution shall have exactly one primary result:

- **Pass** — every required outcome was observed and all evidence is complete;
- **Fail** — at least one required outcome was not met;
- **Blocked** — execution or evaluation could not complete because a prerequisite or environment failed;
- **Not Run** — execution has not occurred for the applicable baseline; or
- **Not Applicable** — documented applicability analysis proves the case does not apply.

A waiver or deviation is an approval record attached to a non-passing condition; it is not a pass result.

`SWVV-STR-011` — Aggregation shall not convert fail, blocked, not run, not applicable without rationale, waived, or missing evidence into pass.

`SWVV-STR-012` — Test retries shall not conceal nondeterminism. Every attempt and its reason shall remain visible, and a flaky required case shall block release until corrected or formally dispositioned.

## Table 5-1. Strategy Summary

| Strategy element | Mandatory outcome |
|---|---|
| Prevention | Reviews, coding rules, generated-data checks, and controlled builds prevent classes of defects. |
| Detection | Static, dynamic, formal, and platform tests expose implementation and integration defects. |
| Independence | Expected results and approvals are sufficiently independent of the item under test. |
| Recovery focus | Ambiguity, resets, interrupted service, and evidence preservation receive explicit coverage. |
| Evidence | Each claim is supported by attributable raw and summarized records. |

# 6. Verification Levels

## 6.1 Verification Hierarchy

| Level | Primary purpose | Representative environment |
|---:|---|---|
| L0 | Requirements, generated-data, source, build, and static conformance | Review, generator checker, compiler, static analyzer |
| L1 | Isolated unit correctness | Host-native test runner with deterministic doubles |
| L2 | Component and API-contract correctness | BSP double, independent protocol model, controlled operating-system services |
| L3 | Multi-component software integration | Independent device model or RTL simulation through the public host boundary |
| L4 | External-host conformance and intended-use validation | VisionFive 2/ECP5, HIL, fixtures, real SPI and interrupt controllers |
| L5 | Production-platform software validation | Production BSP, validation board, fabricated ASIC, controlled fixtures |
| L6 | Released software-system validation | Representative deployment, configuration, persistence, diagnostics, and operator workflows |

## 6.2 Progression Rules

`SWVV-LVL-001` — Lower-level verification shall precede dependent higher-level verification unless a documented reason and containment permit parallel execution.

`SWVV-LVL-002` — A higher-level pass shall not waive a failed or missing lower-level requirement whose defect could be masked by integration behavior.

`SWVV-LVL-003` — Each level shall verify behavior observable at its owned boundary and shall preserve lower-level failure classifications when propagating results.

`SWVV-LVL-004` — Common portable software shall use the same logical contract and public APIs across FPGA and production-ASIC profiles; platform variation shall remain in approved BSP and integration layers.

`SWVV-LVL-005` — Test-only access shall be explicitly identified, compile-time isolated where applicable, absent from production artifacts, and covered by configuration and release checks.

## 6.3 Applicability Matrix

Every release execution plan shall map each SVCI and requirement to applicable levels. Omitting a level requires documented rationale based on architecture, change impact, platform availability, and release phase.

## Table 6-1. Minimum Level by Item Type

| Item type | Minimum applicable levels |
|---|---|
| Pure library or generator | L0, L1, L2 |
| Portable Dragon Core driver | L0 through L4; L5 for production-ASIC release |
| Platform BSP | L0 through applicable real-platform level |
| External firmware/application | L0 through L4 and L6; L5 when released for production ASIC |
| Test or evidence-producing tool | L0, appropriate unit/component checks, and confidence assessment |

# 7. Unit Verification

## 7.1 Purpose and Scope

Unit verification establishes correctness of the smallest practical software element through a stable public or controlled internal boundary with deterministic dependencies.

## 7.2 Mandatory Unit Subjects

Unit verification shall cover, as applicable:

- input, output, null, range, alignment, ownership, lifetime, and lifecycle validation;
- integer width, signedness, conversion, overflow, saturation, and unit handling;
- protocol encode/decode, byte order, length, marker, fill, CRC, reserved values, and truncation;
- every public status mapping and preservation of raw device evidence;
- state machines, transitions, forbidden transitions, reset, cancellation, and recovery;
- deadlines, time wrap, monotonic-time failure, queue bounds, allocation failure, and resource cleanup;
- serialization, lock ordering, callback races, close/destroy races, and reentrancy rules;
- configuration schema validation, migration, active-readback comparison, and persistence failure;
- protected sequences, staged validation/commit, snapshots, pops, clears, acknowledgements, services, and resets;
- partial completion at every possible position and ambiguous-outcome reconciliation; and
- production/engineering feature isolation and generated-manifest validation.

## 7.3 Unit Test Rules

`SWVV-UNIT-001` — Unit tests shall be deterministic, order independent, self-checking, bounded, and free of required wall-clock sleeps or external network services.

`SWVV-UNIT-002` — Tests shall not modify production source to gain test access or change semantics under test.

`SWVV-UNIT-003` — A deterministic BSP double shall inject failure before submission, during transfer, after possible acceptance, during response, and after definitive device completion.

`SWVV-UNIT-004` — Encode/decode and CRC tests shall use independent known answers and shall cover every supported command length, corruption boundary, and malformed response class.

`SWVV-UNIT-005` — Every state-changing API shall prove that automatic retry is absent after acceptance may have occurred and that reconciliation precedes any permitted reapplication or dependent work.

`SWVV-UNIT-006` — Assertions in test builds shall not substitute for production error handling, and removing assertions shall not change required behavior.

`SWVV-UNIT-007` — A unit-test failure shall fail the applicable verification job; automatic retry used only to obtain a pass is prohibited.

`SWVV-UNIT-008` — Unit evidence shall identify case, requirement, software revision, build profile, dependencies, seed, result, duration, and retained failure diagnostics.

## 7.4 Property, Fuzz, and Mutation Testing

Property-based, fuzz, and mutation testing should supplement example-based tests for parsers, decoders, state machines, schemas, and security boundaries. Inputs shall remain reproducible through stored corpora or seeds. A crash, hang, out-of-bounds access, undefined behavior, invariant violation, or unclassified result is a failure.

## Table 7-1. Unit Completion Criteria

| Criterion | Required disposition |
|---|---|
| Applicable requirements | All mapped to passing unit cases or justified at a higher level |
| Structural coverage | Collected and fully analyzed under Section 16 |
| Negative behavior | Applicable invalid, failure, timeout, ambiguity, and recovery paths exercised |
| Open defects | No release-blocking unit defect remains |

# 8. Integration Verification

## 8.1 Purpose

Integration verification establishes that software components preserve their contracts when combined and that ownership, data, control, timing, error, and recovery behavior remain correct across component boundaries.

## 8.2 Integration Sequence

Integration shall progress through applicable combinations of:

1. portable driver with deterministic BSP double;
2. HAL/BSP with host-controller abstraction and interrupt scheduler;
3. driver and typed services with an independent protocol/device model;
4. firmware or application with configuration, persistence, logging, and recovery services;
5. software stack with RTL simulation through the documented external host boundary;
6. common software with the VisionFive 2/ECP5 platform and controlled fixtures; and
7. common software with the production BSP and fabricated device.

## 8.3 Interface Coverage

`SWVV-INT-001` — Each software interface shall be tested for data representation, direction, ownership, ordering, blocking, concurrency, timeout, cancellation, error propagation, resource lifetime, shutdown, and version compatibility as applicable.

`SWVV-INT-002` — Host-interface integration shall cover discovery, compatibility, initialization, protected configuration, active readback, interrupt service, event retrieval, diagnostics, persistence handoff, response-loss reconciliation, reconnect, reset recovery, and reapplication of nondefault volatile configuration.

`SWVV-INT-003` — Tests shall distinguish failures owned by software, the external host controller, board/equipment integration, platform wrapper, Dragon Core, and the verification environment.

`SWVV-INT-004` — Fault injection shall occur through controlled documented hooks and shall not suppress natural faults, alter production error handling beyond the injection boundary, or remain reachable in the production profile.

`SWVV-INT-005` — Integration tests shall verify that generated bindings, public headers, implementation, documentation, examples, and compatibility manifests describe one API and programming contract.

`SWVV-INT-006` — Interrupt testing shall include an interrupt arriving before, during, and after service; multiple pending sources; a persistent source; a newly arriving source; masked sources; host-controller loss; and polling recovery where supported.

`SWVV-INT-007` — Event and queue testing shall preserve raw evidence before destructive acknowledgement or pop and shall cover empty, full, overflow, underflow, rejected access, loss counters, persistence failure, and ambiguous completion as applicable.

## 8.4 Independent Device Model

The independent model shall implement only behavior needed by its declared test scope. Its expected behavior shall trace to owning identifiers, and it shall fail closed on unsupported access. Model correctness shall be reviewed and checked with known-answer, mutation, metamorphic, or comparison tests appropriate to its role.

`SWVV-INT-008` — A model shall not silently accept undocumented addresses, normalize illegal values, invent reset values, infer hidden state, or compensate for malformed host behavior.

## Table 8-1. Integration Evidence

| Evidence | Required content |
|---|---|
| Interface matrix | Producer, consumer, contract, versions, cases, and result |
| Transaction record | Request, response, timing, classification, and correlation identity |
| Fault record | Injection point, ownership, expected propagation, observed propagation, and cleanup |
| Compatibility result | Binding, API, schema, device identity, and target-profile compatibility |

# 9. System Verification

## 9.1 Software-System Scope

Software-system verification establishes end-to-end behavior of the released external-host software configuration. It does not replace device-system verification owned by `RCA-DFC-VP-002`.

## 9.2 Mandatory End-to-End Scenarios

The applicable software system shall be verified for:

- installation or image loading, startup, manifest discovery, and configuration selection;
- cold power-up, warm software restart, Dragon Core reset, host reconnect, and power-cycle recovery;
- exact device compatibility and rejection of incompatible or unknown identity;
- desired-configuration validation, ordered application, protected access, staged commit, active readback, and mismatch handling;
- interrupt reception, bounded deferred service, event persistence, diagnostic preservation, and operator/API notification;
- normal databus, GPIO, monitoring, fault, safety-supervision, and diagnostic workflows exposed through approved typed APIs;
- lost or truncated response, partial completion, coherent terminal reconciliation, retry refusal, and dependent-work blocking;
- watchdog scheduling, deadline failure, suspension, ambiguous service, and recovery policy;
- external persistence unavailable, corrupt, stale, incompatible, full, or restored from backup;
- resource exhaustion, time-source failure, controller failure, process restart, and controlled shutdown;
- security privilege, malformed external input, configuration authorization, log redaction, and engineering-feature isolation;
- long-duration operation, repeated reset/reconnect cycles, and bounded resource use; and
- upgrade, downgrade prohibition where applicable, schema migration, rollback, and evidence continuity.

## 9.3 Intended-Use Validation

`SWVV-SYS-001` — Validation scenarios shall derive from approved software use cases, PBIO responsibilities, operational workflows, maintenance workflows, and applicable Verification Plan host-system cases.

`SWVV-SYS-002` — A validation environment shall be representative in processor architecture, operating system or runtime class, SPI controller behavior, interrupt delivery, time service, storage behavior, resource limits, and deployment configuration, or each difference shall be analyzed.

`SWVV-SYS-003` — Human-facing behavior shall be validated for correct units, identity, timestamps, state distinctions, warning severity, irreversible-action confirmation, raw-evidence access, and unambiguous error/recovery guidance.

`SWVV-SYS-004` — Validation shall demonstrate that autonomous Dragon Core hardware operation is not incorrectly represented as continuous software control and that software does not claim completion before definitive device outcome and required readback.

## 9.4 Performance and Robustness

`SWVV-SYS-005` — Measured software latency, throughput, queue occupancy, stack, memory, storage, and processor use shall satisfy approved software budgets under nominal and worst-supported loads.

`SWVV-SYS-006` — Timing evidence shall use a controlled monotonic source, state the measurement point and uncertainty, and separate host scheduling, controller transfer, device response, storage, and presentation contributions.

`SWVV-SYS-007` — Endurance tests shall check leaks, unbounded growth, counter wrap, time wrap, sequence wrap, stale cache use, repeated recovery, and evidence retention.

## Table 9-1. System Result Dimensions

| Dimension | Required outcome |
|---|---|
| Functional | Approved workflows complete with correct state and evidence. |
| Recovery | Interrupted or ambiguous workflows reach a safe, classified disposition. |
| Performance | Approved budgets are met with stated uncertainty. |
| Security | Privilege and engineering boundaries remain enforced. |
| Usability | Operators and integrators receive accurate, unambiguous information. |

# 10. FPGA Prototype Validation

## 10.1 Purpose and Ownership

FPGA prototype validation establishes that the external-host software operates correctly through the common logical Dragon Core contract on the selected VisionFive 2/ECP5 validation platform. The Verification Plan owns FPGA device cases, required outcomes, environments, coverage, and evidence. This section owns only the software preparation, execution discipline, software-specific checks, and evidence contribution.

## 10.2 Required Software Validation

`SWVV-FPGA-001` — FPGA validation shall use the public portable driver, generated host definitions, and approved VisionFive 2 BSP through the documented SPI and interrupt interfaces.

`SWVV-FPGA-002` — The software shall discover and record the FPGA image identity independently from the host software, BSP, generated-binding, configuration, and fixture identities.

`SWVV-FPGA-003` — Validation shall exercise cold initialization, compatibility, configuration, active readback, interrupts, events, communication queues, diagnostics, reset recovery, response-loss reconciliation, and persistence handoff applicable to the release.

`SWVV-FPGA-004` — Actual SPI controller behavior shall be verified for selected frequency, chip-select continuity, byte and bit order, actual transfer length, timeout, cancellation, and interrupt scheduling behavior required by the public BSP contract.

`SWVV-FPGA-005` — FPGA-only instrumentation may correlate internal evidence with host observations but shall not change portable software behavior or replace production-boundary pass/fail criteria.

`SWVV-FPGA-006` — Removing all validation-only instrumentation shall leave portable source, public API behavior, generated logical bindings, and required results unchanged.

`SWVV-FPGA-007` — Software evidence offered for a `VP-*` case shall cite that case and preserve its required raw artifacts without restating the controlling expected outcome.

## 10.3 Platform Variance

A failure shall be classified by ownership before correction. FPGA wrapper variance, VisionFive 2 controller behavior, board/equipment behavior, BSP behavior, portable-driver behavior, device behavior, and fixture behavior shall remain distinguishable.

## Table 10-1. FPGA Software Evidence

| Record | Required identity |
|---|---|
| Host | Hardware, operating system/runtime, controller, BSP, and software build |
| FPGA | Board, bitstream/image, logical wrapper, clock/reset profile, and build ID |
| Contract | Controlling specifications, generated bindings, API, and configuration |
| Fixture | Hardware, firmware, connections, calibration/status, and script revision |
| Result | VP case when applicable, software case, raw capture, checker output, and disposition |

# 11. ASIC Bring-Up Validation

## 11.1 Purpose and Ownership

ASIC bring-up validation establishes that production external-host software and its production BSP use the fabricated Dragon Core device through the same logical programming contract verified on FPGA. Post-silicon device acceptance and physical-platform criteria remain owned by the Verification Plan and future ASIC Integration Specification.

## 11.2 Bring-Up Sequence

Software bring-up shall proceed conservatively from nondestructive observation to bounded state change:

1. verify host, board, BSP, software, generated-binding, and device identities;
2. verify SPI controller configuration and electrical/integration readiness outside the portable driver claim;
3. read identity, build, readiness, reset, and safe-default evidence;
4. establish exact compatibility and reject unsupported configurations;
5. exercise nondestructive register reads and representative bounded typed operations;
6. validate protected and staged workflows with active readback;
7. validate interrupts, events, diagnostics, queues, reset, truncation, and reconciliation;
8. validate recovery and nondefault volatile-configuration reapplication; and
9. execute the applicable common host-contract and system-validation suite.

## 11.3 Requirements

`SWVV-ASIC-001` — There shall be no ASIC-local software, RISC-V BSP, direct device MMIO, OpenFrame-supplied Dragon Core host service, or undocumented bring-up path.

`SWVV-ASIC-002` — Production bring-up shall use the same portable source, public API, generated logical bindings, result classification, and recovery rules used for FPGA validation; platform-specific change shall be confined to approved BSP and integration artifacts.

`SWVV-ASIC-003` — A physical-platform variance shall be corrected in its owning integration or BSP artifact and shall not be hidden by a portable-driver conditional.

`SWVV-ASIC-004` — Bring-up software shall default to nondestructive access and shall require explicit authorization for reset, clear, pop, test, injection, protected, or output-affecting operations.

`SWVV-ASIC-005` — A lost or truncated response during bring-up shall use the ordinary reconciliation and readback workflow; an engineering operator shall not bypass retry restrictions.

`SWVV-ASIC-006` — Logical comparison with the FPGA baseline shall account for approved device/build, clock, controller, fixture, and physical-platform differences and shall not assume bitstream-to-silicon identity by observation alone.

## Table 11-1. Bring-Up Gates

| Gate | Required evidence before progression |
|---|---|
| Observation | Correct identities, readiness, reset evidence, and safe defaults |
| Compatibility | Supported device/binding/API combination established |
| State change | Protected access, response validation, ambiguity handling, and readback proven |
| Operational suite | Interrupt, event, diagnostic, queue, reset, persistence, and recovery cases passed |
| Release use | Applicable VP and software exit criteria approved |

# 12. Hardware-in-the-Loop Validation

## 12.1 Purpose

HIL validation establishes software behavior with representative timing, external interfaces, fixtures, interrupts, resets, faults, loads, and persistence services. It exercises the software as an external host and contributes to Verification-Plan-owned HIL and host-system outcomes.

## 12.2 HIL Environment

The HIL configuration shall identify the Dragon Core realization, external host, BSP, controller, interrupt path, digital fixtures, transceivers or equipment simulators, timing references, power/reset control, storage services, network isolation, and evidence collection path.

## 12.3 Required Scenarios

`SWVV-HIL-001` — HIL shall cover initialization, protected configuration, active readback, interrupt service, event retrieval, diagnostics, persistence, response-loss reconciliation, reset recovery, and configuration reapplication using only documented interfaces.

`SWVV-HIL-002` — Real-time scenarios shall include minimum and maximum supported rates, simultaneous activity, burst load, queue boundaries, delayed host service, host interruption, and long-duration operation as applicable.

`SWVV-HIL-003` — Fault scenarios shall distinguish natural device/interface faults, authorized injection, external fixture faults, host-controller faults, software faults, and evidence-path faults.

`SWVV-HIL-004` — HIL timing shall use synchronized or correlated clocks with recorded uncertainty sufficient to evaluate each claimed deadline or ordering result.

`SWVV-HIL-005` — Automated fixtures shall fail safe, expose their own health, and prevent a fixture malfunction from being reported as a product pass.

`SWVV-HIL-006` — HIL shall verify that production behavior remains correct when diagnostic instrumentation is disabled or removed.

`SWVV-HIL-007` — HIL evidence contributing to `VP-HIL-*`, `VP-HOST-*`, `VP-INT-*`, or `VP-COV-*` outcomes shall preserve the exact Verification Plan case identity and required evidence fields.

## 12.4 Real-Time Acceptance

A timing pass requires the specified observation points, load, configuration, repetitions, clock relationship, uncertainty, minimum/maximum observations, and outlier disposition. Average latency alone shall not establish a bounded requirement.

## Table 12-1. HIL Evidence Sources

| Source | Purpose |
|---|---|
| Host log | Software lifecycle, command, result, recovery, and application evidence |
| SPI capture | Independent request/response, chip-select, length, timing, and corruption evidence |
| Interrupt capture | Host-controller delivery and software-service timing |
| Fixture capture | External stimulus and response correlation |
| Device evidence | Documented register, event, fault, counter, and reconciliation observations |

# 13. Regression Testing

## 13.1 Regression Policy

Regression establishes that approved behavior remains unchanged except where an approved change intentionally modifies it.

## 13.2 Regression Triggers

`SWVV-REGRESS-001` — Regression impact analysis shall follow every change to requirements, architecture, API, source, generated input, generator, binding, schema, toolchain, dependency, build option, HAL, BSP, target, fixture, model, test, environment, deviation, or documentation that can affect behavior or evidence.

`SWVV-REGRESS-002` — A controlling-specification change shall trigger review of every cited owner identifier and every affected software requirement, generated artifact, model, case, expected result, and released configuration.

`SWVV-REGRESS-003` — A defect correction shall rerun the exposing case, a focused neighborhood of related cases, and every case selected by dependency and hazard/impact analysis.

## 13.3 Selection Rules

`SWVV-REGRESS-004` — The regression selector shall account for shared headers, generated bindings, public ABI, transport, lifecycle, concurrency, recovery, persistence, security, BSP, toolchain, and configuration dependencies.

`SWVV-REGRESS-005` — Full regression shall run before a production release unless an approved release plan defines an equivalent partitioned execution whose combined evidence covers the full applicable baseline.

`SWVV-REGRESS-006` — A skipped test shall remain visible with rationale, impact, owner, approval, and closure plan; omission from a dashboard is not disposition.

`SWVV-REGRESS-007` — Regression shall preserve historical trends for pass/fail stability, duration, coverage, defects, flaky behavior, and environment failures without allowing metrics to replace engineering review.

`SWVV-REGRESS-008` — Cached results may be reused only when immutable identity and impact analysis prove that the software, test, dependencies, environment, data, and applicable requirements are unchanged.

## 13.4 Failure Analysis

Every new regression failure shall be triaged as product defect, test defect, model/oracle defect, environment defect, configuration defect, requirement issue, or unexplained. An unexplained failure is release blocking.

## Table 13-1. Regression Depth

| Change class | Minimum regression response |
|---|---|
| Documentation only, no normative or executable effect | Link/document checks and reviewed impact analysis |
| Isolated implementation correction | Exposing case, unit/component neighborhood, affected integration, and coverage review |
| Shared API, generated binding, transport, concurrency, or recovery | Full affected-platform software regression |
| Controlling contract, compiler, major dependency, or target platform | Full applicable baseline plus compatibility and platform validation |

# 14. Formal Verification Coordination

## 14.1 Software Formal Methods

Formal methods may be used for bounded software state machines, serialization, lifecycle transitions, retry inhibition, protected workflows, parser properties, resource bounds, and other properties whose environment assumptions can be modeled soundly.

## 14.2 Candidate Properties

| Property area | Candidate objective |
|---|---|
| Lifecycle | Operational state is unreachable before compatibility, required configuration, and service readiness. |
| Serialization | At most one command owns a device context at a time. |
| Protected workflow | No unrelated command interleaves within an authorization sequence. |
| Ambiguity | A possibly accepted state change is never automatically retried before reconciliation. |
| Event handling | Required preservation or handoff precedes destructive pop or clear. |
| Resource use | Queue, callback, stack, and allocation bounds are never exceeded under modeled assumptions. |

## 14.3 Formal Evidence Rules

`SWVV-FORM-001` — Each proof shall identify the property, owning requirements, model, abstraction, assumptions, constraints, bounds, tool/version/options, result, proof coverage, and review disposition.

`SWVV-FORM-002` — Assumptions shall be traced to guaranteed environment behavior or verified separately; an assumption shall not exclude the failure condition the property is intended to detect.

`SWVV-FORM-003` — Bounded proof shall be labeled bounded and shall not be represented as unbounded correctness.

`SWVV-FORM-004` — Vacuity, unreachable antecedents, overconstraint, abstraction error, and uncovered state shall be analyzed.

`SWVV-FORM-005` — Formal software results supplement dynamic integration and intended-use validation unless an approved plan explicitly establishes equivalent evidence for a software-only requirement.

## 14.4 Coordination with RTL Formal Verification

`SWVV-FORM-006` — Software formal properties shall not be represented as proof of Dragon Core RTL behavior. RTL proof methods and outcomes remain owned by `RCA-DFC-VP-002` and RTL verification artifacts.

`SWVV-FORM-007` — Shared transaction or state abstractions shall cite SRS, Architecture, and Register Map owners and shall preserve the external software/device boundary.

## Table 14-1. Formal Review Checklist

| Review subject | Required question |
|---|---|
| Property | Does it state the intended requirement without weakening it? |
| Assumptions | Are all assumptions guaranteed, visible, and noncircular? |
| Reachability | Is the relevant antecedent and state space reachable? |
| Bound | Is the bound sufficient and accurately claimed? |
| Tool result | Is the result reproducible and independently reviewed? |

# 15. Static Analysis

## 15.1 Analysis Scope

Static analysis shall implement the language, MISRA, CERT, warning, generated-source, and project-rule profiles controlled by `RCA-DFC-SW-004` and the release compliance plan.

## 15.2 Required Analysis

`SWVV-STATIC-001` — Every production source file, generated source file, and applicable verification source file shall be analyzed under its selected configuration.

`SWVV-STATIC-002` — The configured suite shall address language violations, undefined or implementation-defined behavior, data flow, null and bounds safety, integer conversion, resource lifetime, dead code, concurrency, tainted input, insecure library use, and configured coding rules.

`SWVV-STATIC-003` — Compiler, assembler, linker, archiver, generator, and build warnings shall be treated according to `RCA-DFC-SW-004`; a release shall contain zero unexplained warnings.

`SWVV-STATIC-004` — Analysis shall cover every supported build profile whose preprocessor definitions, language mode, target ABI, optimization, or dependency set changes compiled behavior.

`SWVV-STATIC-005` — A suppression or deviation shall identify the exact rule, location, rationale, risk, containment, reviewer, approver, affected configurations, and supporting evidence.

`SWVV-STATIC-006` — Generated code is not exempt. Compliance may be established through generator construction evidence, complete output analysis, or an approved combination.

`SWVV-STATIC-007` — A clean tool report shall not establish compliance for rules or defect classes outside tool coverage; manual review or another method shall close the gap.

`SWVV-STATIC-008` — New findings and changes to baseline findings shall fail the analysis gate until corrected or formally dispositioned.

## 15.3 Security and Supply-Chain Analysis

Static verification shall include approved dependency inventory, version and integrity checks, license review, secret scanning, unsafe API checks, and vulnerability disposition appropriate to the release. Network vulnerability data may inform a release decision only when its retrieval date and source are recorded.

## Table 15-1. Static Analysis Evidence

| Evidence | Required content |
|---|---|
| Profile | Rules, tool coverage, severity, options, include paths, defines, and target |
| Findings | Stable identity, location, classification, owner, status, and history |
| Deviations | Rationale, risk, containment, evidence, approval, and expiration/review condition |
| Summary | Files analyzed, exclusions, tool failures, counts, trends, and release conclusion |

# 16. Code Coverage

## 16.1 Coverage Purpose

Coverage measures verification completeness and exposes unexercised implementation structure. Coverage is not, by itself, proof of correctness.

## 16.2 Required Coverage Dimensions

`SWVV-COV-001` — Coverage shall include every applicable normative software requirement, public API, unit, function, result class, lifecycle state and transition, error path, recovery path, platform profile, and configuration variant.

`SWVV-COV-002` — Production C code shall collect statement, branch, condition, and function coverage; additional decision or MC/DC coverage shall be collected when selected by an approved assurance plan.

`SWVV-COV-003` — Generated production code shall be included unless an approved generator-based verification argument provides equivalent evidence and identifies every excluded output.

`SWVV-COV-004` — Coverage shall include nominal, boundary, malformed, unauthorized, timeout, partial-completion, ambiguous, reset, concurrency, resource-exhaustion, and recovery classes applicable to each component.

`SWVV-COV-005` — Host-contract coverage shall include cold initialization, compatibility, protected configuration, active readback, interrupt service, event retrieval, diagnostics, response loss, reconciliation, reset recovery, sequence wrap, persistence, and nondefault volatile-configuration reapplication.

`SWVV-COV-006` — Software evidence contributing to device coverage shall reference the exact `VP-COV-*` outcome and shall not create a competing field, state, or device-code coverage threshold.

## 16.3 Coverage Analysis

`SWVV-COV-007` — Every uncovered production statement, branch, condition, function, state, transition, requirement, or result class shall be tested, proven unreachable, removed, or accepted through an approved deviation.

`SWVV-COV-008` — Defensive code claimed unreachable shall be supported by static or formal evidence that includes callers, configuration variants, external inputs, concurrency, and fault paths.

`SWVV-COV-009` — Code introduced only to satisfy a coverage metric without implementing a requirement or bounded defensive purpose is prohibited.

`SWVV-COV-010` — Coverage-tool exclusions, filters, path mappings, merged-run rules, and source-revision consistency shall be configuration controlled and reviewed.

`SWVV-COV-011` — Coverage collected from a different binary or source revision shall not be merged into release evidence.

## 16.4 Threshold Policy

All applicable software requirements require an approved verification disposition. This specification does not invent a universal numeric structural-code threshold. Any numeric threshold shall be defined by the approved release or assurance plan, shall not weaken complete uncovered-code analysis, and shall apply to the exact configuration claimed.

## Table 16-1. Coverage Closure

| Coverage gap | Permitted closure |
|---|---|
| Missing requirement case | Add and pass a case, or correct applicability/requirement through change control |
| Reachable uncovered code | Add tests or remove unjustified code |
| Unreachable defensive code | Provide reviewed static/formal proof and owning rationale |
| Tool-inserted code | Document tool origin, non-product status, and exclusion rule |
| Inapplicable variant | Record exact build/profile applicability and review |

# 17. Requirements Traceability

## 17.1 Software Trace Model

The software trace system is a derived record connecting software requirements to design, implementation, generated artifacts, verification cases, results, defects, deviations, reviews, and releases. It does not replace `RCA-DFC-RTM-002`, which alone owns relationships among controlling technical identifiers.

## 17.2 Trace Requirements

`SWVV-TRACE-001` — Every normative `SW-*`, `FW-*`, `API-*`, `SWCS-*`, and `SWVV-*` requirement applicable to a release shall trace forward to implementation or process realization and to one or more verification cases or approved non-test methods.

`SWVV-TRACE-002` — Every production source module, public API, generated object, and release verification case shall trace backward to an approved requirement or documented bounded defensive purpose.

`SWVV-TRACE-003` — Device-facing software requirements and tests may cite controlling `CHTR-*`, `PBIO-*`, `DFC-*`, `ARCH-*`, `REG-*`, `VP-*`, `RTM-*`, and `RTLSTD-*` identifiers; a citation is a reference and shall not copy or redefine the controlling content.

`SWVV-TRACE-004` — Each trace link shall identify source and target revisions, relationship type, applicability, verification method, result status, and unresolved anomaly or deviation.

`SWVV-TRACE-005` — Trace generation shall detect duplicate identifiers, malformed identifiers, missing sources, missing targets, orphan requirements, orphan code, orphan APIs, orphan generated fields, orphan tests, and unresolved results.

`SWVV-TRACE-006` — A requirement change shall trigger bidirectional impact analysis across design, code, generated artifacts, interfaces, tests, data, models, evidence, documentation, compatibility, and released configurations.

`SWVV-TRACE-007` — Trace closure shall not be inferred from filename similarity, directory location, comments, common wording, or aggregate coverage.

## 17.3 Verification Case Record

Each case shall identify:

- stable case identifier and revision;
- traced software requirement identifiers and referenced controlling owners;
- verification level, method, and environment;
- preconditions, inputs, steps or executable procedure, and independent oracle;
- expected result, tolerances, timing points, and pass/fail logic;
- required evidence and cleanup;
- applicability by target/profile; and
- review and approval state.

## Table 17-1. Bidirectional Trace

| Direction | Required question |
|---|---|
| Requirement to evidence | Where is this requirement implemented and objectively verified? |
| Evidence to requirement | Which approved requirement or bounded purpose justifies this case and result? |
| Code to requirement | Why does this production behavior exist? |
| Defect to regression | Which correction and cases prove closure and prevent recurrence? |

# 18. Test Environment

## 18.1 Environment Classes

| Environment | Required use |
|---|---|
| Host-native | Unit, property, fuzz, static, generator, schema, and tool testing |
| Controlled software integration | BSP doubles, independent model, service integration, persistence and fault tests |
| RTL-coupled | Host software through documented SPI/interrupt boundary to simulation |
| FPGA | VisionFive 2/ECP5 validation through common logical wrapper |
| HIL | Representative interfaces, timing, loads, faults, resets, and fixtures |
| Post-silicon | Production BSP and fabricated device on controlled validation hardware |

## 18.2 Environment Control

`SWVV-ENV-001` — Each environment shall have a controlled manifest identifying hardware, firmware, operating system, runtime, toolchain, dependencies, configuration, network state, time source, fixtures, calibration/status, and automation revision.

`SWVV-ENV-002` — Environment readiness checks shall run before required cases and shall detect stale software, wrong binding, incompatible device/image, controller misconfiguration, fixture failure, insufficient storage, clock error, and unavailable evidence paths.

`SWVV-ENV-003` — Environment health failures shall produce blocked or fail results according to the case contract; they shall not produce product passes.

`SWVV-ENV-004` — Simulation and model time shall be distinguished from host monotonic time, device time, wall time, and synchronized fixture time.

`SWVV-ENV-005` — External network access shall not be required for a controlled release execution unless explicitly approved, recorded, and shown not to change inputs nondeterministically.

`SWVV-ENV-006` — Secrets, private keys, production credentials, and unrestricted test authorization shall not appear in ordinary test source, logs, images, fixtures, or evidence packages.

`SWVV-ENV-007` — Shared environments shall isolate concurrent executions so ports, devices, interrupts, files, clocks, fixtures, and evidence cannot cross-contaminate results.

## 18.3 Representativeness and Differences

`SWVV-ENV-008` — Each environment difference from the intended release platform shall be identified and analyzed for behavior, timing, concurrency, ABI, endian, alignment, resource, controller, storage, and failure-mode impact.

`SWVV-ENV-009` — Host-native or simulated success shall not waive applicable real-controller, FPGA, HIL, or production-platform verification.

## Table 18-1. Environment Qualification Record

| Field | Required content |
|---|---|
| Identity | Immutable environment/build manifest |
| Capability | Interfaces, rates, faults, timing accuracy, observability, and limitations |
| Readiness | Preflight results and calibration/health state |
| Representativeness | Differences from intended platform and impact |
| History | Changes, incidents, maintenance, and requalification status |

# 19. Test Automation

## 19.1 Automation Principles

Automation shall make verification repeatable without hiding failure, ambiguity, skipped work, or environment dependence.

## 19.2 Requirements

`SWVV-AUTO-001` — Every automated test shall produce a deterministic exit status and structured result identifying pass, fail, blocked, not run, or not applicable.

`SWVV-AUTO-002` — Automation shall capture commands, relevant environment, start/end times, case identities, requirement identities, software/test revisions, seed, raw outputs, checker results, and artifact locations.

`SWVV-AUTO-003` — A harness shall time out bounded operations, terminate safely, preserve partial evidence, release owned resources, and identify whether termination could have left a device state change ambiguous.

`SWVV-AUTO-004` — Parallel execution shall be allowed only when device, controller, fixture, port, file, credential, timing, and evidence resources are isolated or explicitly serialized.

`SWVV-AUTO-005` — Automatic test retry shall be disabled for release verdicts. Diagnostic reruns shall retain all attempts and shall not replace the original failure.

`SWVV-AUTO-006` — Dashboards and summaries shall link to immutable raw evidence and shall preserve non-passing counts without filtering or rounding them away.

`SWVV-AUTO-007` — Automation shall validate that the executable and coverage-instrumented artifact match the recorded source and manifest.

`SWVV-AUTO-008` — Test automation source shall conform to applicable coding, review, static-analysis, and unit-verification rules when its failure could create an incorrect pass or corrupt release evidence.

`SWVV-AUTO-009` — Randomized tests shall record seed, generator/version, corpus, constraints, and minimized failing input when available.

`SWVV-AUTO-010` — Automation changes shall receive impact analysis and regression before their results are accepted for release.

## 19.3 Tool Confidence

An evidence-producing or error-detecting tool shall be assessed for the consequence of inserting an error or failing to detect one. Confidence may be established by independent output checking, qualification under an approved assurance process, proven use with controlled version, or a documented combination.

`SWVV-AUTO-011` — A tool whose output is not independently checked shall not be accepted solely on vendor reputation or a successful exit code.

## Table 19-1. Automation Failure Classes

| Failure | Required result |
|---|---|
| Test assertion fails | Fail |
| Prerequisite or fixture unavailable | Blocked unless the case defines the condition as the tested outcome |
| Harness crashes or loses evidence | Fail or blocked; never pass |
| Timeout after possible state change | Fail with ambiguous-state handling and preserved evidence |
| Report generation fails | Verification incomplete until evidence is recovered and validated |

# 20. Test Data Management

## 20.1 Test Data Classes

Test data includes configurations, register/protocol vectors, known answers, randomized seeds, fuzz corpora, fixture stimuli, timing schedules, fault plans, persistent stores, captured traffic, golden files, expected-result tables, credentials or certificates when specially authorized, and anonymized field-derived samples.

## 20.2 Requirements

`SWVV-DATA-001` — Every controlled data set shall have an identifier, revision or digest, owner, origin, schema, units, legal range, applicability, generation method, review state, and retention rule.

`SWVV-DATA-002` — Expected results shall be separated from observed results and protected from automatic overwrite during execution.

`SWVV-DATA-003` — Boundary data shall include minimum, maximum, just-inside, just-outside, zero, reserved, malformed, empty, full, wrap, and simultaneous cases applicable to each type.

`SWVV-DATA-004` — Random or generated data shall be reproducible from controlled seeds and generator identity; generation constraints shall not remove required error or boundary classes.

`SWVV-DATA-005` — Golden data shall trace to an independent calculation or approved owner, not merely to a previous execution of the item under test.

`SWVV-DATA-006` — Captured operational or field-derived data shall be authorized, minimized, sanitized, provenance recorded, and prevented from introducing secrets or personal information into release evidence.

`SWVV-DATA-007` — Corrupt, stale, incompatible, missing, duplicate, truncated, and unauthorized configuration/persistence data shall be included in robustness testing.

`SWVV-DATA-008` — Test data used for destructive, injection, reset, output-affecting, or protected operations shall identify authorization and safe fixture conditions.

`SWVV-DATA-009` — A data-set change shall trigger review of every dependent case, oracle, coverage claim, and prior result proposed for reuse.

## 20.3 Integrity and Retention

Raw input, raw output, processed result, and report shall remain distinguishable. Transformations shall be scripted, version controlled, and reproducible. Digests shall protect released evidence packages.

## Table 20-1. Test Data Lifecycle

| Phase | Required control |
|---|---|
| Create/acquire | Provenance, authorization, schema, and generation method |
| Review | Independence, range, expected-result basis, and safety/security classification |
| Use | Exact identity recorded by execution |
| Transform | Controlled script, options, source/output identity, and audit trail |
| Retain/dispose | Approved retention, access, integrity, and secure disposal |

# 21. Defect Management

## 21.1 Defect Definition

A defect is any observed or discovered nonconformance in a requirement, design, source, generated artifact, API, documentation, test, oracle, model, environment, tool, data set, evidence record, or process that can affect correctness, completeness, reproducibility, safety, security, or release confidence.

## 21.2 Defect Record

`SWVV-DEF-001` — Each defect shall identify discovery context, affected SVCIs and requirements, reproducible evidence, observed and expected behavior, ownership class, severity, priority, affected releases/configurations, containment, assignee, and status.

`SWVV-DEF-002` — Severity shall reflect technical consequence and detectability; priority shall reflect planned response. They shall not be silently interchanged to reduce release impact.

`SWVV-DEF-003` — A suspected controlling-specification issue shall be linked to a change flag against the single normative owner and shall block dependent closure until resolved.

`SWVV-DEF-004` — Root-cause analysis shall address why the defect was introduced, why it escaped earlier controls, whether similar defects exist, and which prevention or detection control must change.

`SWVV-DEF-005` — A correction shall include review, exposing-case pass, regression selected by impact, structural-coverage review, trace update, and evidence that the root cause—not only the symptom—was addressed.

`SWVV-DEF-006` — Closing as duplicate, not reproducible, not a defect, deferred, accepted, or not applicable shall require documented technical rationale and approval.

`SWVV-DEF-007` — A deferred or accepted defect shall identify residual risk, affected requirements/configurations, operational or engineering limitation, mitigation, approver, release visibility, and closure/review condition.

`SWVV-DEF-008` — A test, model, environment, or tool defect shall trigger impact analysis of every result it could have incorrectly passed, failed, blocked, or omitted.

## 21.3 Release Blocking

The following are release blocking unless an authorized governing process explicitly approves a bounded deviation without misrepresenting conformity:

- failed applicable requirement;
- unexplained or nondeterministic result;
- missing identity or raw evidence;
- unresolved ambiguous state-change behavior;
- open safety-, security-, compatibility-, or data-integrity defect;
- incorrect pass caused by a test, oracle, model, environment, or tool;
- unresolved controlling-specification change flag; or
- missing required platform, coverage, trace, or review evidence.

## Table 21-1. Defect Ownership Classes

| Class | Examples |
|---|---|
| Requirement | Conflict, ambiguity, omission, unverifiable wording |
| Product software | Implementation, API, state, timing, resource, recovery, security |
| Generated artifact | Stale, inconsistent, incomplete, wrong source or encoding |
| Verification | Wrong oracle, inadequate case, false pass/fail, missing evidence |
| Environment | Controller, fixture, timing, configuration, contamination |
| Process | Missing review, uncontrolled change, trace or approval failure |

# 22. Configuration Management

## 22.1 Controlled Items

Source, specifications, headers, generators, generated inputs and outputs, tests, models, data, build scripts, tool configurations, environment definitions, procedures, deviations, defects, manifests, documentation, and evidence shall be version controlled.

## 22.2 Requirements

`SWVV-CM-001` — Every verification execution accepted for release shall start from an approved or uniquely identified baseline and shall record all deviations from it.

`SWVV-CM-002` — A release manifest shall identify source revision, controlling and software specification revisions, generated-binding source and generator, toolchain, dependencies, target profile, build options, tests, environments, artifacts, licenses, and cryptographic digests.

`SWVV-CM-003` — Controlled release builds and tests shall perform no implicit network retrieval and shall resolve dependencies from approved pinned sources with recorded integrity.

`SWVV-CM-004` — Reproducible-build verification shall compare artifacts produced from identical controlled inputs or document every unavoidable nondeterministic field and prove it does not affect executable behavior.

`SWVV-CM-005` — Generated-definition mismatch, stale output, duplicate identifier, unresolved required reference, incompatible manifest, unapproved dependency, or unrecorded build option shall fail the applicable gate.

`SWVV-CM-006` — Release evidence shall be immutable after approval. Correction or addition shall create a new identified evidence version with an audit trail.

`SWVV-CM-007` — Production and engineering software, test authorization, fixtures, and evidence shall remain separately identified and controlled.

`SWVV-CM-008` — Emergency changes remain subject to retrospective independent review, complete impact analysis, required regression, trace update, and baseline approval before general release.

`SWVV-CM-009` — Access to modify release baselines, expected results, verdicts, deviations, and approvals shall be limited to authorized roles and auditable.

## 22.3 Change Control

Every change request shall identify cause, owner, affected requirements, interfaces, code, generated artifacts, tests, models, data, tools, environments, evidence, documentation, compatibility, released configurations, regression, and approval route.

## Table 22-1. Baseline Audit

| Audit question | Required result |
|---|---|
| Are all inputs identified and approved? | Yes |
| Can source and generated products be reproduced? | Yes, or bounded nondeterminism is approved and harmless |
| Do artifacts and evidence match the manifest? | Yes |
| Are engineering features absent from production? | Demonstrated |
| Are changes, deviations, and approvals complete? | Yes |

# 23. Verification Reviews

## 23.1 Required Reviews

| Review | Primary purpose |
|---|---|
| Requirements/verifiability review | Correct ownership, clarity, completeness, testability, and acceptance basis |
| Verification readiness review | Baseline, environment, cases, data, oracles, safety, and evidence readiness |
| Test procedure/code review | Correct method, independence, coverage, failure behavior, and reproducibility |
| Result/anomaly review | Verdict correctness, evidence completeness, defect ownership, and impact |
| Coverage and trace review | Closure of requirements, code, variants, gaps, and orphan detection |
| Release V&V review | Complete evidence, deviations, residual risk, and exit-criteria decision |

## 23.2 Review Requirements

`SWVV-REV-001` — Review entry criteria, required participants, inputs, checklist/profile, quorum or approval authority, and exit criteria shall be defined before the review.

`SWVV-REV-002` — Reviewers shall examine subject ownership, requirement interpretation, expected-result independence, interfaces, types, bounds, concurrency, timing, security, recovery, coverage, traceability, environment, configuration, and evidence integrity as applicable.

`SWVV-REV-003` — Safety-, security-, public-API-, compatibility-, generated-contract-, concurrency-, and recovery-affecting evidence shall include a reviewer competent in the affected domain.

`SWVV-REV-004` — The author or executor shall not be the sole approver of release-credit evidence.

`SWVV-REV-005` — Every finding shall be resolved, linked to an approved defect or deviation, or retained as an explicit open exit item; verbal disposition is insufficient.

`SWVV-REV-006` — Review records shall identify subject revision, participants and roles, date, inputs, findings, resolutions, recusals or independence limitations, decision, and approvals.

`SWVV-REV-007` — A review shall be repeated or supplemented when the reviewed item changes beyond the approved impact boundary.

## 23.3 Review Decision

Permitted decisions are approved, approved with recorded conditions, rejected, or deferred. Approval with conditions does not satisfy release exit until every condition is closed or formally accepted by the authorized release authority.

## Table 23-1. Release V&V Review Inputs

| Input | Required state |
|---|---|
| Baseline and manifest | Complete and internally consistent |
| Trace and coverage | Closed or explicitly dispositioned |
| Test/static/formal results | Applicable results passed and reviewed |
| Defects and deviations | Residual risk visible and approved |
| Platform evidence | Applicable FPGA, HIL, and ASIC evidence accepted |
| Controlling flags | None unresolved |

# 24. Verification Deliverables

## 24.1 Required Deliverables

| Deliverable | Required content |
|---|---|
| Software V&V specification | This approved Revision B document |
| Release verification execution plan | Scope, SVCIs, levels, methods, environments, cases, schedule, independence, and acceptance |
| Verification cases and procedures | Stable IDs, traces, preconditions, data, actions, oracles, pass/fail logic, and evidence |
| Verification software package | Tests, harnesses, doubles, models, fixtures, scripts, and controlled tool configurations |
| Data package | Inputs, known answers, seeds, corpora, configurations, schemas, provenance, and digests |
| Results package | Raw logs/captures, structured results, static/formal reports, coverage, timing, and summaries |
| Trace and coverage package | Bidirectional software trace, applicability, structural analysis, and gap dispositions |
| Defect/deviation package | Findings, root causes, corrections, regression, residual risk, and approvals |
| Platform package | FPGA, HIL, and ASIC software evidence with applicable VP references |
| Release V&V report | Baseline, activities, results, limitations, residual risk, exit criteria, and approval recommendation |

## 24.2 Evidence Record Requirements

`SWVV-DEL-001` — Every deliverable shall be traceable to one release manifest and one approved production or engineering profile.

`SWVV-DEL-002` — Raw evidence shall be retained with processed summaries so an independent reviewer can reproduce the verdict.

`SWVV-DEL-003` — A report shall identify failed, blocked, not-run, not-applicable, waived, and deviated items separately; only true passes shall be counted as pass.

`SWVV-DEL-004` — Evidence shall record time in an unambiguous format and identify the clock source where timing affects the claim.

`SWVV-DEL-005` — Generated reports shall record their generator, source inputs, options, and digest.

`SWVV-DEL-006` — No deliverable shall contain secrets, private keys, unrestricted test authorization, undocumented access, stale generated content, or an unresolved release-blocking finding represented as closed.

`SWVV-DEL-007` — Documentation, procedures, and examples shall be complete, internally consistent, validated, and ready for direct baseline use.

## 24.3 Retention

Retention duration, access, backup, restoration test, and disposal shall be defined by project configuration and records policy. Evidence needed to reproduce a released conformity claim shall remain associated with that release.

## Table 24-1. Minimum Result Header

| Field | Required content |
|---|---|
| Case | ID, revision, requirements, method, and level |
| Item under test | Artifact IDs, manifest, profile, and digest |
| Environment | Host/device/model, tools, dependencies, fixtures, and configuration |
| Execution | Time, operator/automation, seed/data, duration, and attempts |
| Verdict | Primary state, expected/observed comparison, and anomalies |
| Evidence | Immutable raw and processed artifact references |

# 25. Exit Criteria

## 25.1 General Exit Criteria

Revision B software V&V compliance for a release is complete only when:

- every applicable normative software requirement has an approved verification disposition;
- every normative identifier is unique and every required reference resolves;
- source, generated bindings, API declarations, documentation, examples, and manifests are mutually consistent;
- all required reviews, static analyses, unit tests, integration tests, software-system tests, and regression tests pass;
- applicable FPGA, HIL, and post-silicon software validation evidence is complete and accepted under the controlling Verification Plan where required;
- every state-changing API has partial-completion, ambiguity, reconciliation, readback, deadline, reset, and retry-refusal evidence;
- generated bindings match the approved Register Map source and generation manifest;
- required structural, requirement, API, state, error, platform, and configuration coverage is complete and every gap is dispositioned;
- software trace has no unresolved orphan requirement, production behavior, public API, generated object, test, result, defect, or release artifact;
- compiler/build warnings, static-analysis findings, coding-rule findings, review findings, security findings, and tool-confidence obligations satisfy the approved compliance plan;
- performance, stack, memory, storage, queue, callback, timing, and concurrency bounds are established for applicable profiles;
- production and engineering capabilities are demonstrably isolated;
- no direct MMIO, ASIC-local software, internal processor assumption, hidden access path, copied register authority, or FPGA-private production dependency remains;
- release source, tools, dependencies, environment, manifests, digests, licenses, documentation, defects, deviations, residual risk, and approvals are complete; and
- no failed required case, unexplained nondeterminism, missing evidence, unresolved controlling-specification change flag, or release-blocking defect remains.

## 25.2 Exit Requirements

`SWVV-EXIT-001` — A release may claim conformity only for the exact baseline represented by its approved evidence.

`SWVV-EXIT-002` — A higher-level successful demonstration shall not override a lower-level failure, missing requirement, incorrect oracle, or incomplete evidence.

`SWVV-EXIT-003` — A blocked, not-run, failed, waived, deviated, or not-applicable result shall remain explicit and shall not be converted to pass through omission, aggregation, or management decision.

`SWVV-EXIT-004` — A conditional release approval shall identify every condition, affected requirement and configuration, residual risk, mitigation, responsible owner, approver, and closure date or review event.

`SWVV-EXIT-005` — If a release phase does not yet require a production-ASIC, HIL, or other platform level, the V&V report shall state the limitation and shall not imply completion of that level.

## Table 25-1. Exit Decision

| Decision | Meaning |
|---|---|
| Approve | All applicable exit criteria are satisfied for the identified release scope. |
| Approve with conditions | Authorized bounded conditions are explicit; conformity claims exclude unsatisfied scope. |
| Defer | Required evidence or resolution is incomplete. |
| Reject | One or more release-blocking nonconformances remain. |

# 26. Baseline Statement

## 26.1 Baseline Declaration

RCA-DFC-SW-005 Revision B is the Software Verification and Validation Specification baseline for external-host Dragon Flight software supporting Dragon Core Revision A. It supersedes Revision A for all new software verification, validation, evidence, release, and maintenance use.

## 26.2 Governing Relationship

This specification remains subordinate to the eight controlling specifications identified by `RCA-DFC-CHTR-002`, Section 3.1, and verifies the software subjects defined by `RCA-DFC-SW-001` Revision C, `RCA-DFC-SW-002` Revision B, `RCA-DFC-SW-003` Revision B, and `RCA-DFC-SW-004` Revision B. It creates no alternate product, boundary, externally observable behavior, internal hardware architecture, register contract, device-verification plan, controlling trace relationship, or RTL rule.

## 26.3 Fixed Baseline Conclusions

- Dragon Core is processor-free and contains no executable software.
- All firmware, HAL, BSP, driver, middleware, SDK, application, persistence, diagnostics, and recovery software executes externally.
- FPGA validation and production ASIC access use one SRS-defined SPI host transport and one Register-Map-defined logical programming model.
- The Verification Plan remains the sole owner of device-verification methods, environments, cases, coverage, required outcomes, and evidence definitions.
- Software verification contributes host-system evidence without redefining device acceptance.
- State-changing operations with uncertain completion are reconciled and confirmed through documented readback before retry or dependent work.
- Raw device evidence is preserved before destructive acknowledgement, clear, pop, or reset when required by the software workflow.
- No change to a controlling specification is required to establish this Revision B baseline.

## 26.4 Change Control

`SWVV-BASE-001` — Any future change to software verification scope, levels, methods, independence, environment, result classification, coverage, traceability, automation, tool confidence, defect disposition, evidence, review, or exit criteria shall revise this specification and complete downstream impact analysis.

`SWVV-BASE-002` — A change requiring new product behavior, boundary allocation, device interface, architecture, register meaning, device-verification definition, controlling trace relationship, or RTL rule shall first revise the applicable controlling specification.

`SWVV-BASE-003` — Historical content may be consulted for rationale only and shall not restore superseded on-device firmware, processor, Wishbone-host, direct-MMIO, Caravel, or software-owned device-verification assumptions.

## 26.5 Approval Effect

Approval establishes this document as the governing software V&V specification for its stated scope. Approval does not approve a particular software release; each release requires its own identified execution evidence, V&V report, exit decision, and configuration baseline.

## Table 26-1. Baseline Approval Summary

| Subject | Revision B conclusion |
|---|---|
| Product boundary | External-host software only; no on-device executable component |
| Controlling authority | Eight-document hierarchy and single-owner rules preserved |
| Device verification | Owned exclusively by `RCA-DFC-VP-002` |
| Software verification | Owned by this specification for subordinate software requirements and evidence |
| Controlling-specification changes | None required |
| Superseded document | `RCA-DFC-SW-005`, Revision A |
