**ROYAL CUBIT AEROSPACE**

**DRAGON CORE™ SOFTWARE CODING STANDARD**

| Field | Value |
|---|---|
| Document Number | RCA-DFC-SW-004 |
| Revision | B |
| Status | Technical Baseline |
| Product | Dragon Core™ Revision A |
| Program | Dragon Flight™ Core ASIC Development Program |
| Organization | Royal Cubit Aerospace |

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | Undated | Historical initial baseline supplied as reference only | Royal Cubit Aerospace |
| B | 2026-08-07 | Rebuilt beneath the eight controlling specifications for external-host software implementation | Royal Cubit Aerospace |

# Approval

| Prepared By | |
|---|---|
| Reviewed By | |
| Approved By | |
| Approval Date | |

# Table of Contents

1. Purpose
2. Scope
3. Applicable Documents
4. Definitions, Acronyms, and Abbreviations
5. Coding Philosophy
6. Software Development Principles
7. Source File Organization
8. File Naming Conventions
9. Directory Structure Requirements
10. Source File Header Requirements
11. Commenting Standards
12. Documentation Requirements
13. Language Standards
14. Compiler Compliance Requirements
15. C Language Rules
16. C++ Language Rules
17. Header File Requirements
18. Include File Management
19. Naming Conventions
20. Data Type Standards
21. Constant and Enumeration Rules
22. Structure and Union Requirements
23. Function Design Rules
24. Parameter Passing Requirements
25. Return Value Requirements
26. Error Handling Standards
27. Status Code Conventions
28. Assertions and Defensive Programming
29. Memory Management Rules
30. Dynamic Memory Restrictions
31. Pointer Usage Rules
32. Register Access Requirements
33. Hardware Abstraction Rules
34. Interrupt Service Routine (ISR) Standards
35. Concurrency and Thread Safety
36. Volatile Variable Usage
37. Atomic Operations
38. State Machine Implementation Rules
39. Timing and Delay Requirements
40. Logging Standards
41. Diagnostic Message Standards
42. Performance Requirements
43. Security Coding Requirements
44. Portability Requirements
45. MISRA Compliance Strategy
46. Static Analysis Requirements
47. Compiler Warning Policy
48. Code Review Requirements
49. Unit Testing Requirements
50. Integration Testing Requirements
51. Traceability Requirements
52. Configuration Management Requirements
53. Coding Examples
54. Deliverables
55. Exit Criteria
56. Baseline Statement

# 1. Purpose

## 1.1 Purpose of this Standard

This standard defines mandatory source-level implementation, review, analysis, test, build, and release rules for Dragon Flight software that executes outside the fabricated Dragon Core Revision A device. It governs how conforming software is written; it does not define Dragon Core product behavior.

Dragon Core is a processor-free digital ASIC. It contains no processor, firmware, operating system, bootloader, executable memory, runtime, HAL, BSP, driver, application, stack, or heap, as controlled by `CHTR-TECH-001` through `CHTR-TECH-005` and `CHTR-EXCL-002`.

`SWCS-DOC-001` — Every conforming implementation shall preserve the eight-document ownership hierarchy and the single-owner rules `CHTR-DOC-001` through `CHTR-DOC-007`.

`SWCS-DOC-002` — Software shall obtain device behavior, interface behavior, register meaning, verification definitions, trace relationships, and RTL rules only from their controlling owners; source code, generated artifacts, examples, tests, and this standard shall not become alternate technical authorities.

## 1.2 Engineering Objectives

- prevent undefined, unspecified, implementation-defined, and unbounded behavior from entering production software without explicit control;
- preserve one external-host programming model for FPGA validation and production ASIC use;
- make resource use, time, concurrency, ownership, side effects, and failures explicit;
- support independent review, static analysis, unit testing, integration testing, reproducible builds, and long-term maintenance;
- keep portable code independent of host processor, operating system, compiler extensions, endianness, alignment, and SPI-controller details; and
- ensure that software cannot weaken, bypass, conceal, or replace hardware-owned safety behavior.

## 1.3 Applicability

This standard applies to Royal Cubit Aerospace-developed or delivered external embedded-host firmware, HAL code, BSPs, drivers, middleware, SDK libraries, services, applications, consoles, gateways, diagnostics, FPGA-validation clients, ASIC bring-up clients, manufacturing and engineering tools, generators, verification software, test fixtures, scripts, examples, and build automation.

## 1.4 Compliance and Change Flags

`SWCS-DOC-003` — Compliance is mandatory for production source and for verification or generation source whose defect could invalidate production artifacts or evidence.

`SWCS-DOC-004` — A conflict, ambiguity, omission, or unimplementable controlling contract shall be flagged against its owning specification before dependent implementation proceeds; software shall not invent substitute device behavior.

No change to a controlling specification is required to establish this Revision B baseline.

## 1.5 Normative Language

The terms **shall** and **shall not** identify mandatory requirements. **Should** identifies a preferred practice for which an alternative requires documented engineering rationale. **May** identifies a permitted option. Informative prose and examples do not create requirements unless they cite an applicable `SWCS-*` identifier.

# 2. Scope

## 2.1 Included Scope

This standard covers source organization, naming, documentation, C and optional C++ usage, build tools, compiler controls, types, interfaces, memory, concurrency, interrupt service, register access through the external SPI software stack, error handling, diagnostics, security, portability, analysis, review, testing, traceability, configuration control, deliverables, and release exit criteria.

## 2.2 Excluded Scope

This standard does not define:

- software or firmware inside Dragon Core;
- SystemVerilog rules, which are owned by `RCA-DFC-RTL-STD-002`;
- device mission, scope, boundaries, observable behavior, internal architecture, register fields, verification cases, or controlling trace relationships;
- an ASIC-local processor bus, direct MMIO aperture, exception model, cache policy, or boot sequence;
- OpenFrame physical implementation, FPGA wrapper implementation, board circuitry, transceivers, wiring, or aircraft integration;
- customer application policy, aircraft control, certification basis, or operational authorization; or
- third-party source not modified or redistributed by Royal Cubit Aerospace, except for integration, interface, security, and license controls stated here.

## 2.3 Software Product Boundary

| Software region | This standard applies | Boundary rule |
|---|---:|---|
| Portable driver, HAL coordination, middleware, firmware services | Yes | Full compliance |
| Host BSP and platform adapters | Yes | Full compliance; justified platform-specific constructs allowed only at the boundary |
| Public SDK and application bindings | Yes | Full compliance for delivered code |
| Generators and generated source | Yes | Generator and output controls both apply |
| Verification tools and independent models | Yes | Equivalent rigor proportionate to evidence impact |
| Unmodified third-party dependency | Interface controls only | Version, provenance, license, vulnerability, and isolation review required |
| Dragon Core RTL | No | Governed by `RCA-DFC-RTL-STD-002` |

`SWCS-SCOPE-001` — FPGA-validation and production software shall use the same SRS-defined SPI transport and Register-Map-defined logical contract through the API and BSP boundaries defined by `RCA-DFC-SW-003` Revision B.

`SWCS-SCOPE-002` — No source file shall imply an on-device RISC-V processor, embedded Dragon Core firmware, ASIC-local BSP, direct Dragon Core MMIO, or OpenFrame-supplied host interface.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

| Document | Sole subject consumed by this standard |
|---|---|
| `RCA-DFC-CHTR-002` | Product scope, exclusions, selected platforms, external-host model, and single-owner rules |
| `RCA-DFC-PBIO-002` | Device, host-software, platform, board, data, safety, and verification responsibility boundaries |
| `RCA-DFC-SRS-002` | Externally observable behavior, SPI interface, timing, safety, reliability, and logical interfaces |
| `RCA-DFC-ARCH-002` | Internal allocation, algorithms, states, priorities, interfaces, shared types, and logical wrapper architecture |
| `RCA-DFC-REG-002` | Host-visible offsets, fields, access classes, encodings, validation, side effects, and reset values |
| `RCA-DFC-VP-002` | Controlling device-verification methods, cases, coverage, outcomes, and evidence |
| `RCA-DFC-RTM-002` | Relationships among existing controlling identifiers |
| `RCA-DFC-RTL-STD-002` | SystemVerilog rules consumed for boundary awareness only |

## 3.2 Governing Software Specifications

| Document | Relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | Governing external-host software architecture |
| `RCA-DFC-SW-002`, Revision B | Governing external embedded-host firmware implementation requirements |
| `RCA-DFC-SW-003`, Revision B | Governing HAL, driver, BSP API, lifecycle, result, concurrency, and recovery contracts |

## 3.3 Historical Reference

`RCA-DFC-SW-004`, Revision A was used only as historical input. Its embedded-processor, direct-MMIO, production RISC-V BSP, Wishbone host, and common FPGA/ASIC processor-software assumptions are superseded and are prohibited in Revision B.

## 3.4 External Standards Baseline

| Standard | Project use |
|---|---|
| ISO/IEC 9899:2018 | Mandatory language baseline for portable production C17 source |
| ISO/IEC 14882:2017 | Baseline for optional C++17 application bindings, host tools, and tests |
| MISRA C:2023 | Production C rule framework, applied by the compliance profile in Section 45 |
| MISRA C++:2023 | Production C++ rule framework when C++ is approved for a configuration item |
| MISRA Compliance:2020 | Compliance-plan, deviation, and evidence process |
| SEI CERT C and CERT C++ | Security-oriented supplemental guidance selected and version-pinned by the release compliance manifest |

`SWCS-REF-001` — A release shall record the exact edition, corrigenda, amendments, tool interpretation, and project classification used for each external rule set.

`SWCS-REF-002` — An external standard shall not redefine a Dragon Core technical fact owned by the controlling set.

## 3.5 Authority and Conflict Resolution

Subject ownership, not document order, resolves authority. This coding standard owns only software implementation practice. A software specification owns its assigned software architecture or API fact; the eight controlling specifications retain authority for the subjects allocated by `RCA-DFC-CHTR-002`, Section 3.1.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition |
|---|---|
| API | Application Programming Interface. |
| BSP | External-host Board Support Package adapting the driver to a processor, operating system, SPI controller, interrupt input, time source, locks, and ordering primitives. |
| Dragon Core | Processor-free Dragon Core Revision A digital supervisory ASIC. |
| Firmware | Executable software for an external embedded host; never software inside Dragon Core. |
| Generated binding | Machine-generated software projection of the Register Map-controlled source, including identifiers, masks, access metadata, and manifest identity. |
| HAL | External-host hardware abstraction and coordination layer above the BSP. |
| ISR | External-host Interrupt Service Routine associated with the Dragon Core host interrupt or a host-controller event. |
| MMIO | Memory-mapped I/O local to an external-host controller; not a Dragon Core host-access mechanism. |
| Production profile | Build configuration excluding raw access, fault injection, test authorization, simulator backdoors, and other engineering-only capability. |
| Reconciliation | Determination of an accepted state-changing SPI command's terminal outcome after response loss or ambiguity, using the controlling host-reconciliation and active-readback contracts. |
| SCI | Software Configuration Item. |
| SPI | SRS-defined external serial host transport used to access Dragon Core. |
| Undefined behavior | Language behavior for which the applicable language standard imposes no requirements. |

`SWCS-TERM-001` — Source, comments, APIs, logs, tests, and documentation shall use controlling names and shall preserve distinctions among current, sticky, counter, pending, terminal, staged, active, requested, commanded, effective, cached, derived, and stale information.

`SWCS-TERM-002` — The terms firmware, HAL, BSP, driver, runtime, stack, and heap shall never be used to describe contents of the fabricated Dragon Core device.

# 5. Coding Philosophy

## 5.1 Engineering Principles

Correctness, determinism, clarity, explicit ownership, evidence preservation, portability, and testability take precedence over terseness, cleverness, speculative abstraction, or premature optimization.

`SWCS-PHIL-001` — Code shall be understandable by inspection without dependence on undocumented behavior, tribal knowledge, debugger state, or compiler accident.

`SWCS-PHIL-002` — Normal, boundary, invalid, timeout, partial-completion, reset, cancellation, concurrency, and recovery behavior shall be designed together.

`SWCS-PHIL-003` — A software convenience shall not conceal a device side effect, discard raw evidence, collapse distinct result classes, or permit blind retry of an ambiguously completed operation.

`SWCS-PHIL-004` — Production code shall use the smallest mechanism that completely and explicitly satisfies its contract.

## 5.2 Safety and Ownership

`SWCS-PHIL-005` — Software may configure, observe, service, retrieve, persist, and request only operations exposed by the controlling host-visible contract; it shall not bypass or replace hardware-owned safety enforcement.

`SWCS-PHIL-006` — Software-derived policy, interpretation, cache state, logs, and persistent records shall remain distinguishable from device state and device evidence.

# 6. Software Development Principles

`SWCS-PRN-001` — Each module shall have one primary responsibility, explicit inputs and outputs, documented ownership, and a bounded public interface.

`SWCS-PRN-002` — Dependencies shall point downward through the `RCA-DFC-SW-001` layer model; a higher layer shall not bypass typed driver APIs to reach the BSP or generated register layer.

`SWCS-PRN-003` — Portable code shall depend only on public project interfaces, fixed-width language types, generated logical definitions, and explicitly approved standard-library facilities.

`SWCS-PRN-004` — Platform-specific headers, intrinsics, controller registers, operating-system services, and assembly shall remain within `bsp/<platform>/` or another reviewed platform boundary.

`SWCS-PRN-005` — Every loop, wait, retry, queue, buffer, callback set, allocation, recursion depth, and operation sequence shall be statically bounded or constrained by an explicit runtime limit.

`SWCS-PRN-006` — Generated source shall be regenerated from controlled input, checked for staleness, and never manually edited.

`SWCS-PRN-007` — Production and engineering build graphs shall prevent engineering-only objects and symbols from entering a production artifact.

`SWCS-PRN-008` — A nonconforming implementation shall be corrected at the source; tests, wrappers, examples, or callers shall not compensate for it silently.

# 7. Source File Organization

## 7.1 Required Ordering

An implementation file shall use this order when applicable:

1. mandatory file header;
2. own public header;
3. project headers;
4. approved system or standard-library headers;
5. compile-time assertions and configuration checks;
6. private types, constants, and declarations;
7. private file-scope objects;
8. private function prototypes when unavoidable;
9. public function definitions; and
10. private function definitions.

`SWCS-FILE-001` — A source file shall implement one cohesive responsibility and shall not combine unrelated modules for convenience.

`SWCS-FILE-002` — Public declarations shall reside in public headers; private declarations and objects shall have internal linkage whenever practical.

`SWCS-FILE-003` — Each implementation file shall include its own public header first so missing dependencies and declaration mismatches are detected.

`SWCS-FILE-004` — File size alone is not a waiver or failure criterion, but a file whose review, testing, or ownership is obscured shall be decomposed.

`SWCS-FILE-005` — No source file shall contain copied register offsets, field masks, device encodings, or protocol constants when a generated binding owns them.

# 8. File Naming Conventions

| Artifact | Required form | Example |
|---|---|---|
| Portable C source | lowercase snake case, `.c` | `dfc_event.c` |
| Public C header | lowercase snake case, `.h` | `dfc_event.h` |
| Optional C++ source | lowercase snake case, `.cpp` | `dfc_console_session.cpp` |
| Optional C++ header | lowercase snake case, `.hpp` | `dfc_console_session.hpp` |
| Unit test | `test_<unit>.<ext>` | `test_dfc_event.c` |
| Platform BSP | `dfc_bsp_<platform>.<ext>` | `dfc_bsp_visionfive2.c` |
| Generated artifact | generator-owned deterministic name | `dfc_reg_bindings.h` |

`SWCS-NFILE-001` — File and directory names shall use portable lowercase ASCII letters, digits, and underscores; spaces, case-only distinctions, locale-dependent characters, and shell-significant punctuation are prohibited.

`SWCS-NFILE-002` — Production public symbols and portable file names shall use the `dfc_` prefix; BSP artifacts shall use `dfc_bsp_`; test-only names shall be unmistakably test-scoped.

`SWCS-NFILE-003` — A rename shall update build, include, trace, documentation, package, and manifest references atomically.

# 9. Directory Structure Requirements

| Path | Required content |
|---|---|
| `include/dfc/` | Stable public C17 headers |
| `src/core/` | Portable lifecycle, transport coordination, results, and reconciliation |
| `src/modules/` | Typed module services |
| `generated/` | Generated bindings, metadata, and provenance manifest |
| `bsp/<platform>/` | Platform-specific adaptation |
| `tests/unit/` | Unit tests and deterministic doubles |
| `tests/integration/` | Protocol, model, simulator, FPGA, HIL, and ASIC-facing tests |
| `tools/` | Generators, consistency checks, packaging, and release tools |
| `examples/` | Nonnormative, compiled examples using public APIs |
| `docs/` | Software design, API, integration, compliance, and release documentation |
| `third_party/` | Approved vendored dependencies and notices, when used |

`SWCS-DIR-001` — Source, generated, test, documentation, and build-output trees shall remain separate.

`SWCS-DIR-002` — Build output shall be produced outside controlled source directories and shall be removable without loss of authored or generated baseline content.

`SWCS-DIR-003` — Circular directory dependencies and relative includes that escape an owning subtree are prohibited.

`SWCS-DIR-004` — The repository layout shall remain consistent with `RCA-DFC-SW-003`, Section 7; a justified extension shall preserve the same ownership boundaries.

# 10. Source File Header Requirements

Each authored source, header, generator, test, and build-control file shall identify:

- organization and component;
- concise purpose and ownership boundary;
- applicable license or copyright notice;
- generated status and source identity when generated;
- safety, concurrency, blocking, or privilege notes when materially relevant; and
- trace reference when the file implements a discrete requirement set.

`SWCS-HDR-001` — File headers shall not contain manually maintained revision logs, author histories, approval claims, or source-control keywords that can diverge from controlled history.

`SWCS-HDR-002` — A generated file header shall state that manual edits are prohibited and shall identify generator, input identity, schema version, and reproducibility digest or manifest reference.

`SWCS-HDR-003` — A file header shall not restate device behavior, register definitions, or API contracts owned elsewhere.

`SWCS-HDR-004` — Copyright, license, export, confidentiality, and third-party notices shall match the approved release record.

# 11. Commenting Standards

`SWCS-COM-001` — Comments shall explain intent, invariants, ownership, units, side effects, concurrency, safety relevance, or non-obvious rationale; they shall not paraphrase obvious syntax.

`SWCS-COM-002` — Public functions shall document preconditions, postconditions, blocking behavior, deadline behavior, permitted contexts, ownership, output validity, side effects, and result interpretation.

`SWCS-COM-003` — A comment shall not transform an unsafe, undefined, nonportable, or nonconforming implementation into an acceptable one.

`SWCS-COM-004` — Commented-out code, stale TODO markers, unresolved FIXME markers, misleading examples, and disabled assertions are prohibited in a release baseline.

`SWCS-COM-005` — Trace comments shall cite stable requirement or contract identifiers and shall not copy their normative prose.

`SWCS-COM-006` — Comments shall be updated in the same change as the code whose meaning they describe.

# 12. Documentation Requirements

| Documentation | Required content |
|---|---|
| API reference | Types, lifecycle, contexts, deadlines, ownership, concurrency, results, side effects, compatibility, and examples |
| BSP integration guide | Required primitives, controller assumptions, chip-select behavior, interrupt integration, timing, locking, and error reporting |
| Internal design | Module boundaries, dependencies, state, algorithms, resource bounds, and recovery |
| Compliance plan | Language, MISRA/CERT profile, tools, deviations, warning policy, and evidence |
| Verification record | Tests, configurations, models, coverage, results, anomalies, and trace |
| Release manifest | Source, generated input/output, tools, options, dependencies, licenses, artifacts, digests, and compatibility |

`SWCS-DOCM-001` — Documentation shall distinguish normative software contracts from nonnormative examples and generated views.

`SWCS-DOCM-002` — Documentation shall describe external-host execution explicitly and shall not imply an ASIC-local runtime.

`SWCS-DOCM-003` — Examples shall compile in continuous integration and shall use typed public APIs, explicit deadlines, complete result handling, and evidence-preserving recovery.

`SWCS-DOCM-004` — Known limitations shall identify whether ownership lies in software, host platform, board/external interface, device, or verification environment.

# 13. Language Standards

## 13.1 Approved Languages

| Use | Language baseline | Restriction |
|---|---|---|
| Portable production library and external embedded firmware core | ISO/IEC 9899:2018 C17 | Mandatory |
| Optional application binding or hosted tool | ISO/IEC 14882:2017 C++17 | Requires SCI approval; public device API remains C17 |
| Generators and development utilities | Controlled Python 3 | Exact interpreter and dependencies pinned |
| Build description | Approved declarative build language | Version pinned; no hidden network fetch during controlled build |
| Platform boundary | C17 plus reviewed assembly or intrinsics | Only when no adequate portable facility exists |

`SWCS-LANG-001` — Each SCI shall declare its approved language, dialect, compiler, and extension policy; mixed-language boundaries shall have explicit ABI and ownership contracts.

`SWCS-LANG-002` — Portable public headers shall compile as C17 and under a supported C++17 compatibility compile using `extern "C"` guards without requiring C++.

`SWCS-LANG-003` — Compiler extensions, inline assembly, intrinsics, and nonstandard pragmas are prohibited outside an approved platform boundary and require a documented fallback or verification double.

`SWCS-LANG-004` — Python and build scripts that affect generated or release artifacts shall be treated as controlled source, tested, analyzed where practical, and executed in a pinned environment.

`SWCS-LANG-005` — A language or dialect change requires compatibility, toolchain, MISRA/CERT, ABI, generated-source, verification, and release impact analysis.

# 14. Compiler Compliance Requirements

`SWCS-COMP-001` — A controlled build shall identify compiler, assembler, linker, archiver, standard library, target, ABI, options, linker description, and environment.

`SWCS-COMP-002` — The selected strict language mode shall be enabled; unsupported extensions and permissive modes shall be disabled unless individually approved.

`SWCS-COMP-003` — At least one reference toolchain shall compile the complete production profile, and portability-critical code shall be checked by a second compiler or equivalent independent analysis when practical.

`SWCS-COMP-004` — Debug, analysis, coverage, sanitizer, release, and target builds shall use controlled configurations; differences that affect semantics shall be documented and tested.

`SWCS-COMP-005` — Optimization shall not change observable software behavior. Release optimization levels and link-time optimization shall be verified on the target profile.

`SWCS-COMP-006` — Compiler assumptions affecting signed overflow, aliasing, alignment, floating point, atomics, structure layout, enumeration size, and character signedness shall be explicit and shall not leak into portable interfaces.

`SWCS-COMP-007` — A compiler defect workaround shall be isolated, referenced to a reproducible defect record, verified, and periodically reviewed for removal.

# 15. C Language Rules

`SWCS-C-001` — Production C shall conform to C17 and the Section 45 compliance profile; undefined behavior is prohibited.

`SWCS-C-002` — Every expression shall make sequencing, type conversion, signedness, width, and overflow intent unambiguous. Mixed signed/unsigned arithmetic requires explicit validated conversion.

`SWCS-C-003` — Signed overflow, invalid shifts, division by zero, invalid pointer arithmetic, out-of-range conversion, uninitialized read, use-after-lifetime, and strict-aliasing violations are prohibited.

`SWCS-C-004` — Assignments and side effects within controlling expressions are prohibited. Boolean conditions shall be essentially Boolean and shall not depend on incidental nonzero values.

`SWCS-C-005` — Every `if`, `else`, `for`, `while`, and `do` body shall use braces. Every `switch` shall have a documented `default`, explicit termination for each case, and no implicit fallthrough.

`SWCS-C-006` — `goto`, variable-length arrays, `setjmp`/`longjmp`, locale-dependent processing, unrestricted formatted input, and recursion are prohibited in production portable code.

`SWCS-C-007` — Function-like macros shall be replaced by functions or typed inline functions whenever practical. A macro argument shall never be evaluated more than once.

`SWCS-C-008` — Standard-library facilities with unbounded, locale-dependent, global-state, unsafe-string, process-control, or hidden-allocation behavior require explicit approval and wrapper isolation.

`SWCS-C-009` — Compile-time assumptions shall use `_Static_assert`; runtime assumptions about external or mutable data shall be validated and handled, not asserted away.

# 16. C++ Language Rules

`SWCS-CPP-001` — C++ is optional and shall not be required to use the public Dragon Core C API.

`SWCS-CPP-002` — An approved production C++ SCI shall conform to C++17 and the Section 45 C++ profile; compiler-specific ABI exposure across public boundaries is prohibited.

`SWCS-CPP-003` — Exceptions, run-time type information, dynamic casts, global constructors with order dependencies, and implicit dynamic allocation are prohibited in embedded production profiles unless the SCI compliance plan explicitly permits and verifies them.

`SWCS-CPP-004` — Resource acquisition shall use deterministic ownership and RAII where C++ is used, but destructors shall not throw or conceal operational failure.

`SWCS-CPP-005` — Templates shall remain bounded, reviewable, and diagnosable; template metaprogramming shall not obscure control flow, resource use, or generated code size.

`SWCS-CPP-006` — C++ wrappers shall preserve every C API status, raw device result, partial completion, ambiguity classification, side effect, deadline, and ownership rule.

`SWCS-CPP-007` — Standard containers or algorithms that allocate, invalidate references unpredictably, throw, or have unbounded execution shall not be used in deterministic embedded paths.

# 17. Header File Requirements

`SWCS-HFILE-001` — Every public and private header shall be self-contained, include only what it uses, and compile as the first include of a minimal translation unit.

`SWCS-HFILE-002` — Include guards shall use a globally unique project prefix; `#pragma once` may supplement but shall not replace guards in portable public headers.

`SWCS-HFILE-003` — Public headers shall expose fixed-width types, opaque handles, explicit units, and stable declarations only; platform-controller types and private object layouts are prohibited.

`SWCS-HFILE-004` — Public wire, event, message, and register representations shall not rely on compiler packing, native bitfields, native enumeration width, alignment, host word size, or host endianness.

`SWCS-HFILE-005` — Public ABI changes require semantic-version, compatibility, layout, source, binary, documentation, and migration analysis.

`SWCS-HFILE-006` — Mutable global objects shall not be defined in headers. Header-defined objects shall have deliberate linkage and one-definition behavior in every supported language mode.

# 18. Include File Management

The required include order is: own header, project public headers, project private headers, generated headers, approved third-party headers, and system/standard headers. Alphabetical order shall be used within a group unless dependency order is unavoidable and documented.

`SWCS-INC-001` — Circular includes, transitive-include dependence, absolute paths, parent-directory escapes, and case-ambiguous paths are prohibited.

`SWCS-INC-002` — Conditional inclusion shall depend only on controlled target-profile or feature declarations and shall not create an alternate Dragon Core logical contract.

`SWCS-INC-003` — Third-party headers shall be isolated behind project adapters when they expose warnings, macros, platform types, unstable ABI, or incompatible language assumptions.

`SWCS-INC-004` — A source file shall not suppress diagnostics around a broad include region without a reviewed, narrowly scoped compatibility wrapper.

`SWCS-INC-005` — Generated headers shall carry manifest identity and shall be checked against the selected product and Register Map revision before compilation or initialization.

# 19. Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Public function | `dfc_<noun>_<verb>` or approved API name | `dfc_event_read_status` |
| Public type | `dfc_<name>_t` | `dfc_deadline_t` |
| Public enumeration constant | `DFC_<TYPE>_<VALUE>` | `DFC_STATUS_OK` |
| Public compile-time constant | `DFC_<SUBJECT>` | `DFC_DEVICE_STORAGE_SIZE` |
| BSP symbol | `dfc_bsp_<subject>` | `dfc_bsp_ops_t` |
| Private file-scope function | lowercase snake case | `decode_response` |
| Local variable | lowercase snake case | `completed_words` |
| Boolean | positive predicate | `response_valid` |

`SWCS-NAME-001` — Names shall convey domain meaning, unit, state class, direction, or ownership when needed to prevent ambiguity.

`SWCS-NAME-002` — Abbreviations shall be limited to approved project terminology; visually confusable, single-letter, encoded-type, and Hungarian-style names are prohibited except conventional loop indices of narrow scope.

`SWCS-NAME-003` — Names shall distinguish device state from software state and shall preserve `raw`, `sticky`, `pending`, `active`, `staged`, `requested`, `commanded`, `effective`, `cached`, `derived`, and `stale` distinctions.

`SWCS-NAME-004` — A value representing time, rate, size, count, address, mask, index, or sequence shall carry an unambiguous type or unit-bearing name.

`SWCS-NAME-005` — Reserved language, implementation, standard-library, and generated-name namespaces shall not be used by authored source.

# 20. Data Type Standards

`SWCS-TYPE-001` — Public and persisted integer quantities shall use `<stdint.h>` fixed-width types or project semantic typedefs based on them.

`SWCS-TYPE-002` — Plain `char`, `short`, `int`, `long`, `size_t`, pointer width, and native enumeration size shall not define wire width, register width, persistent format, or public ABI width.

`SWCS-TYPE-003` — `bool` shall represent software truth values only. Device bit values and masks shall use generated or fixed-width integer types until explicitly decoded.

`SWCS-TYPE-004` — Units shall not be implicit. Time and duration interfaces shall use unit-bearing semantic types or names such as `_us`; conversions shall be checked for range and rounding.

`SWCS-TYPE-005` — Floating point shall not be used for register encoding, protocol framing, equality-based state decisions, safety policy, or exact counters. A presentation conversion such as frequency to `double` shall retain the exact integer source and document precision and error behavior.

`SWCS-TYPE-006` — Narrowing conversion shall be explicit and preceded by a range proof or runtime check. Widening shall preserve signedness and value.

`SWCS-TYPE-007` — Endianness conversion shall use named encode/decode functions operating on byte arrays; type punning and host-structure overlay are prohibited.

`SWCS-TYPE-008` — Alignment requirements shall be expressed through standard language facilities and verified at construction boundaries.

# 21. Constant and Enumeration Rules

`SWCS-CONST-001` — Magic numbers are prohibited when a named value can express intent. Generated device constants shall be used directly and shall not be copied under new names.

`SWCS-CONST-002` — Integer literals shall have an appropriate type suffix and representation. Masks and protocol fields should use hexadecimal; physical counts and user-facing quantities should use decimal unless another base is clearer.

`SWCS-CONST-003` — Enumeration values crossing an ABI, file, message, or wire boundary shall have explicit numeric assignments and an explicitly sized storage representation.

`SWCS-CONST-004` — Every external or decoded enumeration shall be validated. Reserved or unknown values shall produce the defined safe software error and shall not be coerced to a valid operational value.

`SWCS-CONST-005` — Bit masks shall use generated definitions or typed project constants; shifts shall use an unsigned operand and a validated shift count.

`SWCS-CONST-006` — Compile-time configuration constants shall be centralized, documented, range-checked with static assertions, and recorded in the release manifest.

# 22. Structure and Union Requirements

`SWCS-STRUCT-001` — A structure shall represent one cohesive abstraction and shall document ownership, lifetime, mutability, units, and validity rules.

`SWCS-STRUCT-002` — Public structures shall be initialized completely. Reserved members intended for compatible growth shall be named, sized explicitly, required to be zero, and verified on input.

`SWCS-STRUCT-003` — Compiler bitfields are prohibited for registers, SPI frames, event records, canonical messages, persistent formats, and public ABI data.

`SWCS-STRUCT-004` — Unions used for type punning are prohibited. A tagged union may be used only when the tag is validated before member access and every variant is initialized and tested.

`SWCS-STRUCT-005` — `packed` attributes and pragma packing are prohibited in portable public or protocol code. External representations shall be serialized field by field.

`SWCS-STRUCT-006` — `memcmp` shall not establish semantic equality of a structure that may contain padding, inactive union members, reserved bytes, pointers, or nondeterministic state.

`SWCS-STRUCT-007` — Opaque context structures shall not be copied, persisted, compared bytewise, or accessed outside the owning implementation.

# 23. Function Design Rules

`SWCS-FUNC-001` — A function shall have one coherent purpose, explicit preconditions and postconditions, and a reviewable control-flow graph.

`SWCS-FUNC-002` — Cyclomatic complexity, nesting, parameter count, and length shall be limited by the project analysis profile. Exceeding a limit requires decomposition or an approved evidence-backed deviation.

`SWCS-FUNC-003` — Hidden side effects, mutable static local state, nonlocal jumps, and dependence on initialization order are prohibited.

`SWCS-FUNC-004` — A blocking function shall accept or derive an absolute monotonic deadline, document cancellation behavior, and return a distinct timeout or cancellation result.

`SWCS-FUNC-005` — A state-changing device API shall expose complete command outcome, including raw device status, completed-word count, ambiguity, and retry disposition as required by `RCA-DFC-SW-003`.

`SWCS-FUNC-006` — Helpers shall not bypass lifecycle, locking, validation, protected-access, readback, reconciliation, or evidence-preservation rules of their public operation.

`SWCS-FUNC-007` — Recursion is prohibited in deterministic production paths. Indirect recursion through callbacks or dispatch tables shall be detected and prevented.

# 24. Parameter Passing Requirements

`SWCS-PARAM-001` — Input parameters shall precede output parameters unless an existing approved public API defines another order.

`SWCS-PARAM-002` — Read-only pointed-to input shall be `const`. A pointer parameter shall document ownership, required alignment, valid length, aliasing, nullability, and lifetime.

`SWCS-PARAM-003` — Public pointers are non-null unless the declaration and documentation explicitly identify an optional parameter.

`SWCS-PARAM-004` — Every array or byte-buffer pointer shall be accompanied by a validated element count or byte length of an appropriate unsigned type.

`SWCS-PARAM-005` — Output objects shall belong to the caller and shall be initialized to a documented deterministic state before any operation that can fail after argument validation.

`SWCS-PARAM-006` — Variadic application functions are prohibited. Approved diagnostic formatting shall be isolated behind checked wrappers and compile-time format diagnostics.

`SWCS-PARAM-007` — An index, mask, enumeration, duration, address, count, capability, or lifecycle state shall be validated before lock acquisition or side effects whenever practical.

# 25. Return Value Requirements

`SWCS-RET-001` — Every fallible operation shall return or produce a typed result; callers shall inspect it before using dependent output or continuing a state-changing workflow.

`SWCS-RET-002` — A return value shall not collapse software validation, BSP/transport failure, definitive device rejection, partial completion, deadline expiry, cancellation, incompatible device, and ambiguous outcome into one undifferentiated error.

`SWCS-RET-003` — State-changing public APIs shall require a non-null command-result output when `RCA-DFC-SW-003` requires one; callers shall not discard ambiguity accidentally.

`SWCS-RET-004` — A function shall document output validity for every result class. Stale caller data shall not be mistaken for newly returned data.

`SWCS-RET-005` — `void` shall be used only for operations that cannot fail and have no reportable condition, or for private helpers whose caller has already established and proves the complete contract.

`SWCS-RET-006` — Ignored results require an explicit, reviewed disposition construct; casting to `void` without rationale is prohibited for fallible or side-effecting calls.

# 26. Error Handling Standards

## 26.1 Error Classes

| Class | Required disposition |
|---|---|
| Caller contract error | Reject before side effect; return deterministic software status |
| Local resource or lifecycle error | Preserve state; report exact class |
| BSP/transport error before submission | Retry only if policy, deadline, and idempotence permit |
| Failure after possible acceptance | Mark outcome ambiguous; reconcile before retry or recovery |
| Definitive device rejection | Preserve raw status and evidence; do not translate into success |
| Partial multiword completion | Report exact completed count; do not roll back or imply atomicity |
| Compatibility failure | Prevent operational use; preserve diagnostic access as specified |
| Internal invariant failure | Enter bounded fail-safe software state and retain evidence |

`SWCS-ERR-001` — Errors shall be detected at the boundary that can classify them accurately and shall not be silently swallowed, logged-only, or replaced with a default operational value.

`SWCS-ERR-002` — Cleanup shall preserve the primary error unless a cleanup failure has higher defined significance; both shall remain observable when required.

`SWCS-ERR-003` — Retry shall be bounded by count and absolute deadline. Automatic retry of a state-changing operation is prohibited after acceptance may have occurred.

`SWCS-ERR-004` — Recovery shall begin with nondestructive identity, lifecycle, terminal reconciliation, active-configuration, and retained-evidence observation as required by the governing software specifications.

`SWCS-ERR-005` — Error injection, simulation-only failure, and production error paths shall share the same production handling code after the controlled injection boundary.

# 27. Status Code Conventions

`dfc_status_t`, `dfc_command_result_t`, and their semantic classes are owned by `RCA-DFC-SW-003`, Section 10. This section controls their implementation use and does not assign competing numeric values.

`SWCS-STAT-001` — Public status values shall use stable named constants and explicit storage; internal errno values, exceptions, controller codes, or operating-system statuses shall not escape without typed mapping and preserved raw detail where required.

`SWCS-STAT-002` — Zero shall denote success only where the owning API defines it. Code shall compare with the named success value rather than assume a numeric representation.

`SWCS-STAT-003` — Unknown future status values shall be handled as non-success, retained for diagnostics when possible, and never coerced to a familiar rejection.

`SWCS-STAT-004` — Logs, callbacks, persistent records, and language bindings shall preserve the original status family, raw value, operation identity, and lifecycle generation.

`SWCS-STAT-005` — Status-to-string conversion shall be total, side-effect free, nonallocating in embedded profiles, and safe for unknown values.

# 28. Assertions and Defensive Programming

`SWCS-DEF-001` — Public and trust-boundary inputs shall be validated in production code regardless of assertion configuration.

`SWCS-DEF-002` — Assertions shall detect programmer invariants and impossible internal states; they shall not validate external data, device status, timing, allocation failure, or any recoverable runtime condition.

`SWCS-DEF-003` — Assertion behavior shall be deterministic for each target profile and shall not activate a device output, issue a hidden retry, clear evidence, or leak sensitive state.

`SWCS-DEF-004` — Removing assertions for a release build shall not remove required evaluation, side effects, validation, or recovery.

`SWCS-DEF-005` — Bounds, arithmetic, state transitions, capability checks, lifecycle generation, and pointer/length pairs shall be validated before use.

`SWCS-DEF-006` — An illegal internal state shall enter an explicit error path, initialize outputs safely, prevent further state-changing device commands, and retain diagnostics sufficient for investigation.

# 29. Memory Management Rules

`SWCS-MEM-001` — Ownership, lifetime, mutability, alignment, capacity, initialized extent, and concurrency protection shall be defined for every buffer and object.

`SWCS-MEM-002` — Embedded steady-state paths shall use caller-provided storage, static storage with controlled ownership, fixed-capacity pools, or bounded stack allocation.

`SWCS-MEM-003` — Stack use shall be measured or conservatively analyzed for each task, ISR, callback, and call chain under worst-case nesting.

`SWCS-MEM-004` — Buffer operations shall validate source length, destination capacity, overlap, termination, and arithmetic overflow before access.

`SWCS-MEM-005` — Sensitive data and credentials shall not be stored unless required by an external host responsibility; when stored, lifetime and clearing shall be explicit and verified against compiler optimization.

`SWCS-MEM-006` — Dragon Core context storage shall meet `DFC_DEVICE_STORAGE_SIZE` and `DFC_DEVICE_STORAGE_ALIGN`, shall not be copied, and shall remain valid until orderly destruction completes.

`SWCS-MEM-007` — Resource release shall be idempotent where practical and shall not race active callbacks, transfers, or concurrent users.

# 30. Dynamic Memory Restrictions

`SWCS-DYN-001` — Portable embedded firmware and driver steady-state operation shall not require heap allocation.

`SWCS-DYN-002` — Dynamic allocation after initialization is prohibited in deterministic, ISR, callback, watchdog, recovery, and safety-related service paths.

`SWCS-DYN-003` — An SCI that permits dynamic allocation shall define allocator ownership, initialization phase, capacity, fragmentation bound, allocation-failure behavior, lifetime, concurrency, leak detection, and test evidence.

`SWCS-DYN-004` — Allocation failure shall be handled as an expected runtime result and shall not produce partial initialization, leaked ownership, or an operational default.

`SWCS-DYN-005` — General-purpose allocation and deallocation shall not occur while a driver command lock, ISR lock, or device-side protected workflow is held.

`SWCS-DYN-006` — Hosted tools may use managed dynamic storage, but input sizes and aggregate resource use shall remain bounded against untrusted or malformed data.

# 31. Pointer Usage Rules

`SWCS-PTR-001` — A pointer shall be initialized before first use and shall never outlive the referenced object.

`SWCS-PTR-002` — Pointer arithmetic is permitted only within one validated array object; creation of one-past pointers may support comparison but not dereference.

`SWCS-PTR-003` — Conversions between object pointers and integers, between incompatible object-pointer types, or between function and object pointers are prohibited in portable code.

`SWCS-PTR-004` — Casting away `const` or `volatile` is prohibited unless the original object possesses the required qualification and the isolated platform API forces the conversion.

`SWCS-PTR-005` — Function pointers shall use exact compatible prototypes, immutable operation tables after initialization, and validated non-null entries before dispatch.

`SWCS-PTR-006` — Borrowed pointers shall have an explicit lifetime and shall not escape a callback, lock scope, context generation, or owning object without a documented retention contract.

`SWCS-PTR-007` — Raw byte access to an object's representation is permitted only for standard-defined operations with explicit bounds and shall not be used to serialize semantic structures.

# 32. Register Access Requirements

Dragon Core host access is serialized SPI, not direct MMIO. Register meaning is owned exclusively by `RCA-DFC-REG-002`; SPI framing and behavior are controlled by the SRS and Architecture; the public software contract is owned by `RCA-DFC-SW-003`.

`SWCS-REG-001` — Production software shall use typed APIs and generated register bindings. Hand-authored offsets, masks, access classes, reserved-bit rules, encodings, reset values, or side effects are prohibited.

`SWCS-REG-002` — Portable code shall not cast an address to a volatile pointer, map a Dragon Core register aperture, or use byte/halfword processor loads and stores to access Dragon Core.

`SWCS-REG-003` — SPI frames and responses shall be serialized and decoded with explicit byte operations; compiler-packed structures, bitfields, and host-endian word overlays are prohibited.

`SWCS-REG-004` — Exactly one command coordinator shall serialize transactions for an open device context, preserve chip-select and deadline rules through the BSP, and retain actual transfer length and raw response data needed for classification.

`SWCS-REG-005` — Multiword operations shall be treated as ordered and non-atomic. Earlier completed words remain effective after a later failure unless the Register Map defines an explicit staged atomic commit.

`SWCS-REG-006` — Read, write, protected write, validate, commit, snapshot, pop, push, clear, acknowledge, service, reset, and recovery shall remain distinct operations.

`SWCS-REG-007` — A state-changing operation whose response is lost or truncated after possible acceptance shall be classified ambiguous and reconciled before retry, reapplication, or another dependent state change.

`SWCS-REG-008` — Reserved bits shall be written as zero and validated from generated metadata; read values shall be masked or decoded according to the owning field contract without concealing an invalid device result.

`SWCS-REG-009` — Read-modify-write is permitted only when the Register Map defines the complete operation as safe. It shall not be used for W1C, counter clear, command, protected, staged, snapshot, pop, push, service, or mixed-side-effect fields.

`SWCS-REG-010` — Active readback shall be used to confirm configuration workflows; cached desired configuration shall not be treated as proof of device-active state.

# 33. Hardware Abstraction Rules

`SWCS-HAL-001` — The BSP shall own external-host SPI-controller use, host interrupt integration, monotonic time, locking, memory ordering, platform diagnostics, and optional external persistence primitives only.

`SWCS-HAL-002` — The BSP shall not decode Dragon Core registers, implement module policy, select configuration values, interpret aircraft meaning, or hide definitive device errors.

`SWCS-HAL-003` — Portable code shall access platform services only through the immutable, validated BSP operation table defined by `RCA-DFC-SW-003`.

`SWCS-HAL-004` — BSP operations shall report completion phase and actual transferred length sufficiently to distinguish failure before submission from failure after possible device acceptance.

`SWCS-HAL-005` — Platform controller acknowledgement and Dragon Core interrupt acknowledgement are separate. The BSP shall not clear device evidence as a side effect of host-controller service.

`SWCS-HAL-006` — A BSP difference shall not create FPGA-versus-ASIC differences in the logical device contract or portable driver behavior.

`SWCS-HAL-007` — Every BSP shall provide deterministic test doubles or equivalent controlled substitution for unit and integration verification.

# 34. Interrupt Service Routine (ISR) Standards

`SWCS-ISR-001` — A Dragon Core host-interrupt ISR is external-host software. It shall acknowledge only the host interrupt controller as required, record or schedule service, and return promptly.

`SWCS-ISR-002` — An ISR shall not execute Dragon Core SPI transactions, acquire a blocking driver command lock, allocate memory, perform persistence, format unbounded text, dispatch application callbacks, or wait for device state.

`SWCS-ISR-003` — Device interrupt vector read, owning-resource service, Dragon Core acknowledge, evidence clear, event handling, and callback dispatch shall occur in bounded deferred context in the documented order.

`SWCS-ISR-004` — ISR-shared data shall use an approved atomic or interrupt-masking protocol; `volatile` alone is not synchronization.

`SWCS-ISR-005` — ISR execution time, nesting, stack, wakeup loss, storm handling, and deferred-queue saturation shall be bounded and verified.

`SWCS-ISR-006` — A host-controller interrupt shall not be presented to software as proof that a particular Dragon Core source remains pending; deferred service shall read authoritative device state.

# 35. Concurrency and Thread Safety

`SWCS-CONC-001` — Each shared resource shall have one documented owner and one documented synchronization mechanism.

`SWCS-CONC-002` — One command lock shall serialize each device context. A documented global lock order shall prevent deadlock among context, callback, persistence, logging, and application locks.

`SWCS-CONC-003` — No callback into application code shall occur while an internal driver, BSP, or command lock is held.

`SWCS-CONC-004` — A public API shall document thread safety, reentrancy, interrupt-context legality, blocking, cancellation, and lifecycle restrictions.

`SWCS-CONC-005` — Data races, double-checked initialization without a valid memory-order proof, unbounded priority inversion, and lock-order inversion are prohibited.

`SWCS-CONC-006` — Close, reset recovery, cancellation, callback unregister, and destruction shall coordinate with in-flight operations and shall not permit use-after-lifetime or late callback delivery.

`SWCS-CONC-007` — Software queue backpressure shall be bounded and shall report software-side loss separately from device-side loss.

# 36. Volatile Variable Usage

`SWCS-VOL-001` — `volatile` shall be used only for an object whose accesses are externally observable to the C abstract machine for a justified platform reason, such as an external-host controller register or narrowly defined ISR communication object.

`SWCS-VOL-002` — Dragon Core registers shall not be represented by volatile C objects because Dragon Core is accessed through serialized SPI transactions.

`SWCS-VOL-003` — `volatile` shall not be used to provide atomicity, mutual exclusion, cross-core memory ordering, thread synchronization, or lifecycle safety.

`SWCS-VOL-004` — Volatile access shall remain inside the BSP or platform adapter and shall be wrapped by typed functions with documented ordering and side effects.

`SWCS-VOL-005` — Qualification shall appear at the pointed-to object level intended by the interface; casts that remove volatile qualification are prohibited.

# 37. Atomic Operations

`SWCS-ATOM-001` — C11/C17 atomics may be used only with explicitly selected types, lock-free assumptions, memory orders, and target support verified by the BSP/toolchain profile.

`SWCS-ATOM-002` — Sequential consistency shall be the default. Weaker ordering requires a documented happens-before proof and focused concurrency tests.

`SWCS-ATOM-003` — An atomic operation shall not be assumed ISR-safe, lock-free, or signal-safe merely because the language accepts it; generated code and runtime-library dependencies shall be inspected.

`SWCS-ATOM-004` — Atomics shall not replace ownership design, transaction serialization, lifecycle coordination, or the Dragon Core command lock.

`SWCS-ATOM-005` — Atomic counters shall define overflow behavior. Operational and diagnostic counts shall not wrap silently.

`SWCS-ATOM-006` — Cross-process or device memory ordering shall be implemented by the platform-specific primitive required by the BSP contract, not by an unverified compiler barrier.

# 38. State Machine Implementation Rules

`SWCS-FSM-001` — Each software state machine shall define its states, events, guards, actions, priorities, initial state, terminal states, illegal-state behavior, timeout behavior, and ownership.

`SWCS-FSM-002` — Software lifecycle state shall remain distinct from the Dragon Core primary operating state and from independent device qualifiers.

`SWCS-FSM-003` — State shall use an explicit enumeration with assigned values. External or persisted state values shall be validated before use.

`SWCS-FSM-004` — A transition shall compute and validate required effects before committing the new state; partial transition must be impossible or explicitly recoverable.

`SWCS-FSM-005` — Every state/event pair shall have an explicit outcome: transition, deliberate no-op, deferred event, or typed rejection.

`SWCS-FSM-006` — Reset detection, identity change, lifecycle-generation change, response ambiguity, and compatibility loss shall have explicit higher-priority transitions into recovery or unusable state.

`SWCS-FSM-007` — State machines shall be unit tested for every legal transition, illegal state, simultaneous event priority, timeout, cancellation, reset, and recovery path.

# 39. Timing and Delay Requirements

`SWCS-TIME-001` — Deadlines shall use an external-host monotonic time source and absolute deadline representation as defined by `RCA-DFC-SW-003`; wall-clock time shall not control protocol or recovery timeouts.

`SWCS-TIME-002` — Deadline arithmetic shall be checked for overflow, wrap, unit conversion, and expired-at-entry behavior.

`SWCS-TIME-003` — Busy-wait delays are prohibited in portable code. A BSP delay or poll may be used only when bounded, necessary, and within the caller's absolute deadline.

`SWCS-TIME-004` — Polling loops shall have a maximum iteration or absolute deadline, provide cancellation where required, and avoid starving interrupt, watchdog, reconciliation, or recovery service.

`SWCS-TIME-005` — Retry backoff shall be bounded and shall never extend beyond the original operation deadline or convert an ambiguous side effect into an automatic retry.

`SWCS-TIME-006` — Device raw timestamps, host monotonic time, correlated time, and civil time shall use distinct types or APIs and shall never be substituted implicitly.

`SWCS-TIME-007` — Worst-case execution time, scheduling latency, interrupt latency, transaction duration, and service cadence shall be measured or conservatively bounded for release profiles whose requirements depend on them.

# 40. Logging Standards

## 40.1 Log Classes

| Class | Intended use |
|---|---|
| Fatal | Software cannot continue its assigned function safely |
| Error | Operation failed or evidence requires action |
| Warning | Recoverable abnormal condition or degraded margin |
| Information | Bounded lifecycle, configuration, or maintenance milestone |
| Debug/Trace | Engineering-only detailed execution evidence |

`SWCS-LOG-001` — Logging shall be bounded, nonblocking or deadline-aware, and incapable of changing Dragon Core command ordering or device behavior.

`SWCS-LOG-002` — A log record shall include monotonic host time, component, severity, operation identity, lifecycle generation, typed software status, and preserved raw device/transport detail when applicable.

`SWCS-LOG-003` — Software logs shall be clearly distinguishable from Dragon Core event records, sticky evidence, counters, and terminal reconciliation records.

`SWCS-LOG-004` — Logging shall not substitute for returning an error, preserving a raw result, updating required software state, or retrieving hardware evidence.

`SWCS-LOG-005` — Credentials, keys, unrestricted test authorization, personal data, and unnecessary payload contents shall not be logged.

`SWCS-LOG-006` — Rate limiting and loss counting shall prevent a log storm; dropped software log records shall be observable without being confused with device event loss.

`SWCS-LOG-007` — Debug and trace logging shall be removable or disabled in the production profile without altering functional behavior, timing correctness, or evaluation of required expressions.

# 41. Diagnostic Message Standards

`SWCS-DIAG-001` — Diagnostic messages shall use stable machine-readable identifiers separate from localized or human-readable text.

`SWCS-DIAG-002` — A message shall state what failed, the owning software boundary, the operation and lifecycle identity, the observed result, and a bounded recovery disposition; it shall not speculate about an unobserved device cause.

`SWCS-DIAG-003` — Formatting shall be bounded by explicit destination capacity. Unchecked `sprintf`, unbounded string concatenation, and format strings derived from untrusted input are prohibited.

`SWCS-DIAG-004` — Diagnostics shall preserve unknown raw values in a safe numeric representation and shall not label an unknown future code as a known condition.

`SWCS-DIAG-005` — Human-facing diagnostics may add interpretation but shall retain access to the unmodified machine-readable source record.

`SWCS-DIAG-006` — Production and engineering diagnostics shall be separated; engineering diagnostics shall not expose raw write, test, injection, or hidden access in a production build.

# 42. Performance Requirements

Device performance requirements remain owned by `RCA-DFC-SRS-002` and their verification by `RCA-DFC-VP-002`. This section governs software implementation budgets only.

`SWCS-PERF-001` — Each release profile shall define budgets for stack, static memory, optional pool memory, command latency, interrupt top-half time, deferred service latency, callback work, queue capacity, and sustained SPI utilization.

`SWCS-PERF-002` — Performance optimization shall follow measurement, preserve semantics, and retain a readable reference or independent oracle for high-risk optimized code.

`SWCS-PERF-003` — CPU, memory, or I/O saturation shall not cause silent device-evidence loss, blind retry, missed ambiguity, unbounded blocking, or starvation of higher-priority recovery and watchdog service.

`SWCS-PERF-004` — Performance tests shall include worst-case legal message size, queue occupancy, interrupt density, event density, callback load, concurrency, timeout, response truncation, and recovery.

`SWCS-PERF-005` — Cached observations may improve performance only when freshness, lifecycle generation, acquisition time, and invalidation are explicit; a cache shall not replace authoritative active readback where confirmation is required.

`SWCS-PERF-006` — A performance result shall identify hardware, operating environment, build profile, compiler/options, load, data set, sample method, and acceptance budget.

# 43. Security Coding Requirements

`SWCS-SEC-001` — Every external input, configuration object, persistent record, message, file, environment value, command-line option, callback registration, and device response shall be treated according to an explicit trust boundary and validated before use.

`SWCS-SEC-002` — Length, count, offset, index, allocation, and multiplication/addition used for memory access shall be checked for range and integer overflow before evaluation or conversion.

`SWCS-SEC-003` — Production applications shall use typed APIs. Engineering raw register access, test authorization, fault injection, simulator backdoors, and unrestricted diagnostic capability shall be excluded from production linking and export surfaces.

`SWCS-SEC-004` — Protected-write sequences and physical test authorization shall not be represented as cryptographic authentication, secure boot, credential storage, or an on-device software trust boundary.

`SWCS-SEC-005` — Credentials and signing material required by the external host environment shall remain outside source, binaries, logs, examples, fixtures, and ordinary configuration packages and shall use the system owner's approved secret-management boundary.

`SWCS-SEC-006` — Dependencies shall be version-pinned, provenance-recorded, license-reviewed, vulnerability-reviewed, and built without uncontrolled network retrieval.

`SWCS-SEC-007` — Parsers and decoders shall reject malformed, truncated, overlong, duplicate, inconsistent, unknown-critical, and out-of-range input deterministically without partial state change.

`SWCS-SEC-008` — Security hardening flags, stack protection, control-flow protection, relocation/read-only protection, and sanitizers shall be enabled when supported and compatible with the target, with omissions documented.

`SWCS-SEC-009` — Fuzzing shall cover SPI response decoders, configuration parsers, persistent-record readers, diagnostic parsers, and other untrusted byte-oriented interfaces where practical.

# 44. Portability Requirements

`SWCS-PORT-001` — Portable layers shall not depend on processor endianness, word size, alignment, unaligned access, native bitfield order, enumeration width, signed `char`, pointer representation, operating-system handles, or compiler packing.

`SWCS-PORT-002` — FPGA validation and production ASIC use shall share the same portable source and generated logical bindings; platform variation shall remain in the BSP and approved integration configuration.

`SWCS-PORT-003` — Fixed-width encode/decode functions shall define wire byte order explicitly and shall be tested on little-endian and big-endian models or an equivalent forced-endian test harness.

`SWCS-PORT-004` — Public ABI shall use C17-compatible declarations, opaque handles, explicit calling convention where necessary, and stable size/alignment contracts.

`SWCS-PORT-005` — File paths, line endings, timestamps, locale, filesystem ordering, time zone, and environment variables shall not make a controlled build or generated output nondeterministic.

`SWCS-PORT-006` — Platform-specific behavior shall be selected through an explicit target profile, not inferred from incidental compiler macros throughout portable source.

`SWCS-PORT-007` — Porting to a new host shall require a new or validated BSP and shall not modify the logical register contract, typed API semantics, or recovery behavior.

# 45. MISRA Compliance Strategy

## 45.1 Compliance Profile

Production C shall be assessed against MISRA C:2023. Production C++ shall be assessed against MISRA C++:2023 when C++ is approved. `MISRA Compliance:2020` shall govern plan, enforcement, deviation, and evidence. A release may state a narrower regulatory or assurance claim only through a separately approved plan.

`SWCS-MISRA-001` — Mandatory and required rules applicable to the selected language and implementation shall be enforced. Advisory rules shall be analyzed and assigned a project disposition rather than ignored wholesale.

`SWCS-MISRA-002` — The compliance plan shall identify rule edition, applicability, decidability, tool coverage, manual review coverage, severity, and required evidence.

`SWCS-MISRA-003` — A deviation shall identify the exact rule, location, technical necessity, risk, containment, supporting analysis/test evidence, reviewer, approver, affected configurations, and expiration or review condition.

`SWCS-MISRA-004` — Project-wide or directory-wide deviations require evidence that every covered occurrence shares the same bounded rationale. Blanket suppression is prohibited.

`SWCS-MISRA-005` — Generated source is not exempt. Compliance may be established by generator construction, output analysis, or an approved combined argument that identifies both input and generated evidence.

`SWCS-MISRA-006` — A tool's clean report shall not alone establish compliance where the rule is undecidable, only partially checked, or outside the tool's coverage.

`SWCS-MISRA-007` — CERT findings shall be reconciled with MISRA findings without weakening either applicable project disposition.

# 46. Static Analysis Requirements

`SWCS-SA-001` — Static analysis shall cover production source, public headers, generated source, build-time generators whose output is released, and verification code whose result contributes release evidence.

`SWCS-SA-002` — The configured analysis suite shall address language violations, undefined behavior, data flow, null and bounds safety, integer conversion, resource lifetime, concurrency, dead code, tainted input, insecure library use, and configured MISRA/CERT rules.

`SWCS-SA-003` — Analysis shall run in continuous integration using the same target macros, include paths, generated bindings, compiler assumptions, and material build options as the corresponding release profile.

`SWCS-SA-004` — Every finding shall have a stable identity and disposition of fixed, accepted deviation, tool false positive, duplicate, or not applicable, with rationale and reviewer.

`SWCS-SA-005` — A baseline shall not conceal newly introduced findings. Severity reclassification or suppression changes require review equivalent to a code change.

`SWCS-SA-006` — Analysis tool, version, ruleset, configuration, and result digest shall be recorded in release evidence.

`SWCS-SA-007` — Sanitizers and dynamic analysis shall supplement but shall not replace static analysis; static analysis shall not replace required execution tests.

# 47. Compiler Warning Policy

`SWCS-WARN-001` — Production and verification builds shall enable a documented high-warning profile and shall treat enabled warnings as errors.

`SWCS-WARN-002` — A release shall contain zero unexplained compiler, assembler, linker, archiver, generator, and build-system warnings.

`SWCS-WARN-003` — Diagnostic suppression shall be the narrowest possible scope, shall identify tool and warning, and shall reference an approved deviation or third-party isolation rationale.

`SWCS-WARN-004` — Unknown-warning suppression flags shall not be used to make heterogeneous toolchains appear clean.

`SWCS-WARN-005` — Warnings from generated and project-owned source shall be corrected in the generator or source rather than suppressed in generated output.

`SWCS-WARN-006` — Third-party warnings shall be isolated and recorded; system-header treatment shall not suppress diagnostics for project source.

`SWCS-WARN-007` — Warning-profile changes require regression, static-analysis correlation, and release-record update.

# 48. Code Review Requirements

`SWCS-REVIEW-001` — Every change to production source, public headers, generated input, generator, BSP, build logic, test oracle, compliance configuration, or release packaging shall receive independent review before baseline entry.

`SWCS-REVIEW-002` — The author shall not be the sole approver. Safety-, security-, concurrency-, recovery-, generated-contract-, and public-ABI-affecting changes require a reviewer competent in the affected domain.

`SWCS-REVIEW-003` — Review shall examine requirements and ownership, interface contract, types, bounds, error and ambiguity handling, concurrency, memory, timing, security, portability, tests, trace, documentation, and configuration impact.

`SWCS-REVIEW-004` — Review shall compare generated or coded behavior with the owning source and shall reject copied or invented device facts.

`SWCS-REVIEW-005` — Every finding shall be resolved, accepted through the deviation process, or recorded as a release-blocking open item; informal verbal disposition is insufficient.

`SWCS-REVIEW-006` — Large mechanical changes shall be separated from semantic changes when practical so reviewers can establish intent and effect.

`SWCS-REVIEW-007` — Review evidence shall identify change, revision, reviewers, checklist/profile, findings, resolutions, and approval time.

# 49. Unit Testing Requirements

`SWCS-UT-001` — Each unit shall be tested through its public or controlled internal boundary with deterministic dependencies and without modifying production source for test access.

`SWCS-UT-002` — Tests shall cover nominal, boundary, invalid, malformed, timeout, cancellation, allocation/resource exhaustion, partial completion, ambiguity, reset, lifecycle, concurrency, and recovery behavior applicable to the unit.

`SWCS-UT-003` — Every state-changing API shall prove that no automatic retry occurs after acceptance may have happened and that reconciliation precedes any allowed reapplication.

`SWCS-UT-004` — Encode/decode tests shall use independent known answers and shall cover every supported word count, byte order, CRC boundary, marker/fill condition, corruption class, and truncated length.

`SWCS-UT-005` — Test doubles shall inject failure before submission, during transfer, after possible acceptance, during response, and after definitive completion.

`SWCS-UT-006` — Statement, branch, and condition coverage shall be measured for production code. Uncovered defensive code shall be tested, formally or statically shown unreachable, or dispositioned with evidence.

`SWCS-UT-007` — Tests shall be deterministic, order independent, self-checking, bounded, and free of dependence on wall-clock sleeps or external network services.

`SWCS-UT-008` — A test failure shall fail the build; retries used to mask flaky tests are prohibited.

# 50. Integration Testing Requirements

`SWCS-IT-001` — Integration tests shall progress through BSP double, independent protocol/device model, RTL simulation, FPGA validation, HIL, and production ASIC as applicable to the release phase.

`SWCS-IT-002` — Host-conformance integration shall cover discovery, compatibility, initialization, protected configuration, active readback, interrupt service, event retrieval, diagnostics, persistence handoff, response-loss reconciliation, reset recovery, and nondefault volatile-configuration reapplication.

`SWCS-IT-003` — Integration tests shall distinguish software, host controller, board/interface, wrapper, device, and test-environment failures according to PBIO ownership.

`SWCS-IT-004` — FPGA-only instrumentation may correlate evidence but shall not become the pass/fail oracle for behavior controlled at the common logical boundary.

`SWCS-IT-005` — Fault injection shall not suppress natural faults, alter production error handling after the injection boundary, or remain reachable in the production profile.

`SWCS-IT-006` — Tests contributing to controlling Verification Plan evidence shall cite applicable `VP-*` case identifiers and preserve the raw artifacts required by that plan without redefining expected device behavior.

`SWCS-IT-007` — Regression selection shall include every test affected through shared headers, generated bindings, transport, lifecycle, concurrency, recovery, BSP, build, dependency, or public API changes.

# 51. Traceability Requirements

`SWCS-TRACE-001` — Every normative `SWCS-*` requirement shall trace to its implementation rule, automated or manual check, verification evidence, deviation if any, and release disposition.

`SWCS-TRACE-002` — Software requirements implemented from `RCA-DFC-SW-001`, `RCA-DFC-SW-002`, and `RCA-DFC-SW-003` shall trace to source modules and tests without adding rows to the controlling RTM unless its owning scope is formally revised.

`SWCS-TRACE-003` — Device-facing tests may cite controlling `DFC-*`, `ARCH-*`, `REG-*`, and `VP-*` identifiers; the citations are trace links and shall not copy or redefine their content.

`SWCS-TRACE-004` — Source trace shall be maintained at module, function, generated-object, or test level appropriate to the implementation; pervasive line-by-line requirement comments are not required and shall not create noise.

`SWCS-TRACE-005` — A change shall identify upstream cause, affected software requirements, source, generated artifacts, interfaces, tests, evidence, documentation, compatibility, and released configurations.

`SWCS-TRACE-006` — Orphan requirements, orphan production code, orphan public APIs, orphan generated fields, and orphan release tests are prohibited.

`SWCS-TRACE-007` — Trace reports shall be generated from controlled identifiers where practical and checked for duplicate, missing, malformed, and unresolved references.

# 52. Configuration Management Requirements

`SWCS-CM-001` — Source, headers, generators, generated inputs and outputs, tests, build scripts, tool configurations, documentation, deviations, manifests, and release evidence shall be version controlled.

`SWCS-CM-002` — A release manifest shall identify source revision, submodules, controlling and software specification revisions, generator and machine-readable register source, toolchain, dependencies, target profile, options, tests, artifacts, licenses, and cryptographic digests.

`SWCS-CM-003` — Controlled builds shall perform no implicit network retrieval and shall resolve dependencies from approved pinned sources with recorded integrity.

`SWCS-CM-004` — Reproducible-build verification shall compare artifacts created from identical controlled inputs or document every unavoidable nondeterministic field and prove it does not affect executable behavior.

`SWCS-CM-005` — Production and engineering configurations shall have separate identities, build graphs, manifests, and artifacts.

`SWCS-CM-006` — Generated-definition mismatch, stale output, duplicate identifier, unresolved required reference, incompatible manifest, or unapproved dependency shall fail the build.

`SWCS-CM-007` — Emergency changes remain subject to retrospective independent review, full regression, trace update, and baseline approval before general release.

`SWCS-CM-008` — Release artifacts shall be immutable after approval; a correction creates a new identified release.

# 53. Coding Examples

Examples are nonnormative illustrations of rules already defined by this standard and the governing API specification. Exact public declarations remain owned by `RCA-DFC-SW-003`.

## 53.1 Checked Integer Narrowing

```c
static dfc_status_t checked_u32_to_u16(uint32_t value, uint16_t *out_value)
{
    if (out_value == NULL) {
        return DFC_STATUS_INVALID_ARGUMENT;
    }

    *out_value = UINT16_C(0);
    if (value > UINT16_MAX) {
        return DFC_STATUS_INVALID_ARGUMENT;
    }

    *out_value = (uint16_t)value;
    return DFC_STATUS_OK;
}
```

## 53.2 Explicit Byte Decoding

```c
static uint32_t decode_u32_be(const uint8_t bytes[static 4])
{
    return ((uint32_t)bytes[0] << 24U) |
           ((uint32_t)bytes[1] << 16U) |
           ((uint32_t)bytes[2] << 8U) |
           (uint32_t)bytes[3];
}
```

## 53.3 State-Changing Result Handling

```c
dfc_command_result_t command_result = {0};
dfc_status_t status = dfc_configuration_apply(device,
                                               change_plan,
                                               deadline,
                                               &command_result);

if (status == DFC_STATUS_OK) {
    /* Active readback and required postconditions have been confirmed. */
} else if (status == DFC_STATUS_AMBIGUOUS) {
    /* Enter the API-defined reconciliation workflow before any retry. */
} else {
    /* Preserve the typed software status and complete command result. */
}
```

`SWCS-EX-001` — Examples shall initialize outputs, use explicit types and units, check every fallible result, and avoid copied register definitions.

`SWCS-EX-002` — Examples shall not demonstrate direct MMIO, blind retry, unchecked casts, ignored ambiguity, hidden allocation, or test-only production access.

`SWCS-EX-003` — Every delivered example shall compile and run in the applicable automated verification profile.

# 54. Deliverables

| Deliverable | Required content |
|---|---|
| Coding standard | This approved Revision B document |
| Compliance package | Language/MISRA/CERT plan, rule mapping, deviations, warning and analysis profiles |
| Source package | Production, BSP, generator, test, example, and build source within approved scope |
| Generated package | Bindings, metadata, input identity, generator identity, and consistency result |
| Verification package | Review, unit, integration, analysis, coverage, sanitizer/fuzz, platform, and anomaly evidence as applicable |
| Release package | Libraries/images/tools, public headers, API and integration documentation, manifest, digests, licenses, compatibility, and release notes |

`SWCS-DEL-001` — Every delivered artifact shall be traceable to one release manifest and one approved production or engineering profile.

`SWCS-DEL-002` — Generated bindings, generators, compliance records, and verification evidence are controlled deliverables, not disposable intermediates.

`SWCS-DEL-003` — No deliverable shall contain credentials, private keys, unrestricted test authorization, undocumented access, stale generated content, or unresolved release-blocking findings.

`SWCS-DEL-004` — Documentation and examples shall be complete, internally consistent, validated, and ready for direct baseline use.

# 55. Exit Criteria

Revision B implementation compliance is complete only when:

- every applicable `SWCS-*` requirement is implemented, verified, and traceable or has an approved deviation;
- every normative identifier is unique and every referenced controlling or software document resolves;
- the portable public interface compiles as C17 and under the supported C++ compatibility configuration;
- no on-device processor, firmware runtime, direct Dragon Core MMIO, ASIC-local BSP, alternate host path, copied register authority, or FPGA-private production dependency remains;
- generated bindings match the approved Register Map source and manifest;
- compiler warnings, configured static-analysis findings, MISRA/CERT dispositions, review findings, and build checks satisfy the approved compliance plan;
- required unit, integration, sanitizer, fuzz, coverage, FPGA, HIL, and ASIC evidence passes for the release phase;
- state-changing operations have partial-completion, ambiguity, reconciliation, readback, deadline, reset, and retry-refusal evidence;
- memory, stack, time, concurrency, interrupt, queue, and callback bounds are established;
- production and engineering capabilities are demonstrably isolated;
- release source, tools, dependencies, manifests, digests, licenses, documentation, trace, deviations, and approvals are complete; and
- no unresolved controlling-specification change flag or release-blocking anomaly remains.

`SWCS-EXIT-001` — A release may claim conformity only for the exact source, generated bindings, target profile, toolchain, options, dependency set, tests, and manifest represented by its evidence.

`SWCS-EXIT-002` — A failed, blocked, waived, deviated, or not-applicable result shall remain explicit and shall not be converted to pass through omission or aggregation.

# 56. Baseline Statement

## 56.1 Baseline Declaration

RCA-DFC-SW-004 Revision B is the software coding-standard baseline for Dragon Flight external-host software supporting Dragon Core Revision A. It supersedes Revision A for all new software implementation, review, verification, release, and maintenance use.

## 56.2 Governing Relationship

This standard remains subordinate to the eight controlling specifications identified by `RCA-DFC-CHTR-002`, Section 3.1, and implements the software architecture, firmware, and API boundaries of `RCA-DFC-SW-001` Revision C, `RCA-DFC-SW-002` Revision B, and `RCA-DFC-SW-003` Revision B. It creates no alternate product, boundary, externally observable behavior, architecture, register, verification, RTM, or RTL definition.

## 56.3 Fixed Baseline Conclusions

- Dragon Core is processor-free and contains no executable software.
- All firmware, HAL, BSP, driver, application, tooling, persistence, and recovery software executes outside the fabricated device.
- FPGA validation and production ASIC access use one SRS-defined SPI transport and one Register-Map-defined logical programming model.
- Portable production code uses C17, generated bindings, explicit serialization, typed results, bounded resources, and evidence-preserving recovery.
- Direct Dragon Core MMIO, host-structure wire overlay, copied register definitions, blind retry, and engineering backdoors in production are prohibited.
- Multiword commands remain ordered and non-atomic except where the Register Map defines explicit staged commit.
- Ambiguous state-changing operations are reconciled and confirmed through active readback before retry or dependent work.
- Software state and records remain distinguishable from device state and hardware evidence.
- Production and engineering profiles remain isolated and independently identifiable.

## 56.4 Controlling-Specification Disposition

No change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` is required to establish this Revision B coding-standard baseline.

## 56.5 Change Control

Any future change to language baseline, coding rules, MISRA/CERT profile, compiler policy, public ABI practice, memory model, concurrency model, register-access practice, recovery rule, analysis, review, test, trace, configuration, or release criteria shall revise this standard and complete downstream impact analysis. A change requiring new device behavior, register meaning, interface behavior, verification definition, trace relationship, or RTL rule shall first revise the applicable controlling owner.

## 56.6 Approval Statement

Upon approval, this document is ready for direct placement beneath the eight controlling Dragon Flight specifications as `RCA-DFC-SW-004_Dragon_Core_Software_Coding_Standard_RevB.md`.
