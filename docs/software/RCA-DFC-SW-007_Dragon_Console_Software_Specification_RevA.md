**DRAGON CONSOLE™ SOFTWARE SPECIFICATION**

Document Number: RCA-DFC-SW-007  
Revision: A  
Status: Technical Baseline  
Product: Dragon Core™ Revision A  
Program: Dragon Flight™ Core ASIC Development Program  
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | 2026-08-07 | Initial Dragon Console software baseline derived beneath the eight controlling Dragon Flight specifications; includes the VisionFive 2 embedded-host application and ULX3S/ECP5-85F FPGA-validation UUT profile | Royal Cubit Aerospace |

# Approval

| Prepared By |  |
|---|---|
| Reviewed By |  |
| Approved By |  |
| Approval Date |  |

# Table of Contents

1. Purpose
2. Scope
3. Applicable Documents
4. Definitions, Acronyms, and Abbreviations
5. Dragon Console Configuration Item Identification
6. Authority, Ownership, and Product Boundary
7. Operational Roles and Application Profiles
8. Execution and Deployment Environment
9. Software Architecture
10. Process, Thread, and Scheduling Model
11. Device, Session, and Lifecycle Model
12. VisionFive 2 Platform Integration
13. ULX3S/ECP5-85F UUT Integration Profile
14. SPI and Host-Interrupt Integration
15. Startup, Discovery, and Compatibility
16. Console Operating-State Model
17. Configuration Management Workflows
18. Observation and Status Presentation
19. Interrupt, Event, and Data Service
20. Functional-Module Console Services
21. Diagnostics and Evidence Management
22. Command and Destructive-Operation Control
23. Ambiguous-Outcome Reconciliation
24. Disconnect, Reset, and Recovery
25. FPGA Validation and Host-Conformance Operation
26. Test Campaign and Procedure Execution
27. Fixtures, Instrumentation, and External Boundaries
28. Data Model and Persistence
29. Logging, Audit, and Evidence Export
30. Human and Automation Interfaces
31. Security and Access Control
32. Concurrency and Resource Management
33. Timing and Performance
34. Error Handling and Degraded Operation
35. Portability and Production Separation
36. Internal and External Software Interfaces
37. Configuration, Schema, and Compatibility Versioning
38. Software Verification and Validation
39. Traceability and Change Control
40. Build, Package, Deployment, and Release
41. Deliverables
42. Exit Criteria
43. Baseline Statement


# 1. Purpose

This specification defines Dragon Console, an external-host engineering, maintenance, bring-up, and validation application for Dragon Core Revision A. Dragon Console executes outside the fabricated Dragon Core device and uses the Dragon SDK and typed HAL/driver interfaces to discover, configure, observe, diagnose, recover, and validate a conforming Dragon Core realization.

The Revision A baseline has two inseparable purposes:

- provide the engineering and maintenance console required by `RCA-DFC-SW-001`, Section 21; and
- serve as the embedded host console and test client on the VisionFive 2 single-board computer for an ULX3S board populated with an ECP5-85F FPGA acting as the unit under test (UUT).

The VisionFive 2-to-UUT command and data path shall use the SRS-defined SPI host transport. A separately connected Dragon Core host-interrupt signal shall be used when an applicable verification procedure requires interrupt-driven behavior. The Console shall preserve the same logical device contract, generated bindings, driver behavior, lifecycle rules, and recovery behavior intended for later production external hosts.

This specification owns only Dragon Console software behavior, composition, workflows, presentation, application data, persistence, security, automation, platform use, and verification. It does not own or redefine the product boundary, device behavior, internal hardware architecture, register contract, controlling verification cases, controlling trace relationships, RTL rules, FPGA wrapper design, board wiring, or physical implementation.

# 2. Scope

## 2.1 Included Scope

This specification covers:

- the Dragon Console executable and supporting application libraries;
- the VisionFive 2 deployment profile;
- the ULX3S/ECP5-85F UUT integration profile as a software-selected validation environment;
- local interactive and automated operation;
- Dragon SDK use, device lifecycle coordination, and typed functional services;
- identity discovery and compatibility decisions;
- desired-configuration import, validation, comparison, application, and active readback;
- observation of operating state, active conditions, sticky evidence, counters, interrupts, events, queues, messages, faults, safety status, and diagnostics;
- explicit state-changing, protected, staged, commit, acknowledge, clear, pop, reset, and test workflows;
- response-loss reconciliation and reset recovery;
- FPGA-validation and host-conformance procedure execution;
- evidence capture, persistence, export, and release identification;
- user authorization, audit, error handling, resource bounds, portability, verification, build, package, deployment, and release requirements; and
- separation of production-safe features from engineering-only and validation-only features.

## 2.2 Excluded Scope

The following are excluded:

- any executable software, processor, bootloader, runtime, memory, HAL, BSP, driver, application, or Console function inside Dragon Core;
- aircraft flight control, navigation, guidance, mission management, vehicle-control decisions, or aircraft user-interface functions;
- redefinition of any SRS behavior, Architecture contract, register field, access rule, verification case, trace relationship, or RTL rule;
- FPGA RTL, ECP5 wrapper logic, FPGA bitstream generation, ULX3S constraints, board pin mapping, or validation-only hardware observability implementation;
- VisionFive 2 or ULX3S electrical design, voltage translation, protection, signal integrity, connectors, wiring, or power sequencing;
- external ARINC 429, CAN, UART, analog, sensor, actuator, or power-interface circuitry;
- production-test or scan access except through an explicitly authorized, documented host-visible operation permitted by the controlling contract;
- qualification of a production external host; and
- aircraft certification, installation approval, operational authorization, or aircraft-level safety assessment.

## 2.3 Intended Use

Dragon Console is an engineering and maintenance application. It may support laboratory validation, FPGA bring-up, HIL operation, post-silicon bring-up, manufacturing support, and controlled maintenance. It is not a flight-control application and shall not be credited with a safety responsibility assigned to Dragon Core hardware.

`DCS-SCOPE-001` — Dragon Console shall execute entirely on an external host and shall communicate with Dragon Core only through public Dragon SDK services derived from the SRS-defined host protocol and Register-Map-defined host-visible contract.

`DCS-SCOPE-002` — The Console shall not depend on a platform-private register, scan path, testbench backdoor, RTL hierarchy, shared-buffer physical address, undocumented timing relationship, or hidden device state.

`DCS-SCOPE-003` — The Console shall use the same portable SDK and typed device services for the FPGA UUT and a later conforming ASIC, with platform variation confined to approved BSP and integration profiles.

`DCS-SCOPE-004` — Engineering convenience shall not weaken device access validation, safety enforcement, evidence retention, compatibility checks, or ambiguous-outcome recovery.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and sole normative ownership of the controlling set are defined only by `RCA-DFC-CHTR-002`, Section 3.1. The following table is an informative Console-use view and creates no alternate precedence.

| Document | Dragon Console use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product mission, exclusions, selected ECP5 and VisionFive 2 platform classes, external-host model, and single-owner rules |
| `RCA-DFC-PBIO-002.md` | Device, host, software, platform, board, test, data-custody, safety, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior, logical interfaces, performance, timing, safety, reliability, and SPI host obligations |
| `RCA-DFC-ARCH-002.md` | Device-side internal contracts needed to interpret coherent access, state, events, queues, diagnostics, reset, and reconciliation |
| `RCA-DFC-REG-002.md` | Sole normative source for host-visible registers, fields, access classes, reset values, legality, protection, read/write behavior, and side effects |
| `RCA-DFC-VP-002.md` | Sole normative source for device and host-boundary verification methods, environments, cases, coverage, outcomes, and evidence definitions |
| `RCA-DFC-RTM-002.md` | Sole normative source for relationships among controlling technical identifiers |
| `RCA-DFC-RTL-STD-002.md` | RTL implementation and structural rules; not a Console software coding standard |

## 3.2 Governing Software Specifications

| Document | Governing relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | External-host software architecture and Dragon Console architectural allocation |
| `RCA-DFC-SW-002`, Revision B | External embedded-host firmware behavior applicable to embedded deployment services |
| `RCA-DFC-SW-003`, Revision B | Public HAL, driver, BSP, typed API, lifecycle, transport-result, and recovery contracts |
| `RCA-DFC-SW-004`, Revision B | Software coding and implementation standard |
| `RCA-DFC-SW-005`, Revision B | Software verification and validation requirements |
| `RCA-DFC-SW-006`, Revision B | Software build, package, deployment, release, manifest, integrity, and archival requirements |

## 3.3 Historical Reference

No historical Dragon Console specification was supplied or used. This Revision A specification is newly derived from the controlling technical specifications and the governing software baseline.

## 3.4 Authority and Single-Definition Rules

`DCS-DOC-001` — Dragon Console shall apply `CHTR-DOC-001` through `CHTR-DOC-007`.

`DCS-DOC-002` — A consumed device fact shall be obtained from its controlling owner or generated binding and shall not be copied into hand-maintained Console source or configuration as an alternate definition.

`DCS-DOC-003` — Generated host definitions shall remain derived artifacts of the Register Map-controlled source and shall not become an alternate register specification.

`DCS-DOC-004` — A Console label, menu, workflow, script, test procedure, expected-result file, or screenshot shall not establish device behavior absent from a controlling specification.

`DCS-DOC-005` — If implementation or verification exposes a conflict, ambiguity, omission, unreachable behavior, or unimplementable contract, dependent work shall stop and the owning specification shall be corrected before the Console invents a substitute.

## 3.5 Controlling-Specification Change Flags

No change to a controlling specification is required to establish this Revision A baseline.

The ULX3S board populated with an ECP5-85F is defined here only as the Console's identified FPGA-validation UUT profile within the Charter-selected ECP5 technology class. This does not redefine the Charter's selected platforms or make an FPGA board, package, pin, wrapper, or bitstream property part of the Dragon Core product contract. Exact FPGA wrapper, constraints, pin mapping, build identity, wiring, and fixture definitions shall be supplied by their owning integration artifacts.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition in this specification |
|---|---|
| Active configuration | Device-active value reported through Register-Map-defined active readback; distinct from a desired or staged value. |
| Ambiguous outcome | A state-changing host operation for which software cannot validate a definitive response and therefore cannot safely infer whether an effect occurred. |
| Automation client | An authorized local program or script using the Console's controlled command interface. |
| Campaign | A versioned, ordered collection of test procedures, inputs, expected outcomes, evidence requirements, and completion rules. |
| Console | Dragon Console application and its controlled supporting components. |
| Desired configuration | Validated external configuration the user intends to apply; it is not active until device readback proves activation. |
| Device session | One Console-owned lifecycle and service context for one discovered Dragon Core instance. |
| ECP5-85F | The user-selected ECP5 FPGA density used by the ULX3S UUT profile; not a redefinition of Dragon Core logical behavior. |
| Engineering profile | A build and runtime profile permitting specifically authorized diagnostics and state-changing engineering operations. |
| FPGA validation profile | The VisionFive 2 and ULX3S/ECP5-85F profile used for controlled FPGA and host-interface verification. |
| Host reconciliation | Determination of an ambiguous command's terminal device outcome using the controlling host-reconciliation and diagnostic contract. |
| HIL | Hardware in the loop. |
| Operator | An authenticated or locally authorized person interacting with the Console. |
| SDK | Dragon Software Development Kit governed by `RCA-DFC-SW-001` and `RCA-DFC-SW-003`. |
| SPI | Serial Peripheral Interface. |
| Sticky evidence | Device-retained historical indication defined by a controlling specification; distinct from a Console log. |
| UUT | Unit under test; for the Revision A FPGA profile, the ULX3S board containing the ECP5-85F Dragon Core realization. |
| Validation-only feature | Console, fixture, or FPGA integration behavior permitted only in a named validation profile and prohibited from becoming a production dependency. |
| VisionFive 2 | Charter-selected primary external FPGA-validation host on which the Console application executes. |

Device-side terminology, units, identifiers, encodings, access classes, capacities, and timing retain the definitions of their controlling owners.

# 5. Dragon Console Configuration Item Identification

## 5.1 Software Configuration Items

| Configuration item | Purpose | Execution or storage location |
|---|---|---|
| `dragon_console` | Main embedded Console application, lifecycle coordinator, presentation, command control, and evidence workflow | VisionFive 2 or approved external host |
| `dragon_console_core` | Platform-neutral application services, session state machine, workflow engine, data model, and policy enforcement | Linked into the Console application |
| `dragon_console_vf2` | VisionFive 2 platform integration and deployment adapter | VisionFive 2 |
| `dragon_console_fpga_profile` | ULX3S/ECP5-85F validation-environment identity, capabilities, fixture references, and approved test-profile data | External host storage |
| `dragon_console_cli` | Interactive command-line or terminal presentation adapter | External host |
| `dragon_console_automation` | Controlled local automation interface and batch procedure executor | External host |
| `dragon_console_evidence` | Versioned schemas, serializers, exporters, and integrity metadata for Console evidence | External host storage |
| `dragon_console_tests` | Unit, component, integration, target, regression, and acceptance tests | Verification environments |

## 5.2 Identification Requirements

`DCS-CI-001` — Every executable and application library shall identify its semantic version, source revision, build identifier, build profile, target platform, toolchain, dependency manifest, governing software revisions, and controlling-specification revisions.

`DCS-CI-002` — Each execution record shall identify the Console release, Dragon SDK release, generated-binding identity, VisionFive 2 platform profile, UUT profile, FPGA image identity, FPGA wrapper identity, board/fixture identity, and discovered device identity as independent values.

`DCS-CI-003` — A filename, build date, product label, or platform name alone shall not establish compatibility.

`DCS-CI-004` — Debug, engineering, FPGA-validation, HIL, maintenance, and production-safe profiles shall have distinct machine-readable identities.

# 6. Authority, Ownership, and Product Boundary

## 6.1 Responsibility Allocation

| Subject | Dragon Console owns | Dragon Console shall not own |
|---|---|---|
| User workflow | Selection, validation, confirmation, presentation, audit | Device access legality or hardware safety enforcement |
| Configuration | Desired values, external persistence, comparison, ordered application | Register field meaning, device validation, or activation semantics |
| Observation | Acquisition schedule, labeling, freshness, history, export | Device state generation or evidence semantics |
| Commands | Authorization, typed request construction, result presentation, reconciliation | Device command side effects or terminal-result encoding |
| Validation | Procedure orchestration and Console-generated evidence | Controlling verification cases or FPGA logical behavior |
| Platform | VisionFive 2 process integration and use of approved BSP | SPI controller hardware, board wiring, FPGA wrapper, or physical timing definition |
| Safety | Clear presentation and conservative software operation | Substitution for hardware watchdog, fault, interlock, lost-link, or safety-output behavior |

## 6.2 Boundary Requirements

`DCS-BND-001` — The Console shall consume the public Dragon SDK and shall not directly construct register addresses, field masks, wire opcodes, CRC parameters, or response encodings in application code.

`DCS-BND-002` — Raw engineering access, when compiled and authorized, shall use only the engineering API governed by `RCA-DFC-SW-003` and generated logical identifiers.

`DCS-BND-003` — The Console shall not infer Dragon Core internal design from the FPGA target, RTL revision, wrapper, or captured timing beyond facts exposed by the controlling contract.

`DCS-BND-004` — The Console shall label software-derived interpretations separately from raw device observations and shall retain the source observation used for each derived conclusion.

`DCS-BND-005` — Host failure, Console termination, operator inactivity, or a lost UI connection shall not be represented as changing Dragon Core hardware responsibilities.

# 7. Operational Roles and Application Profiles

## 7.1 Roles

| Role | Minimum permitted scope |
|---|---|
| Observer | Nondestructive identity, status, configuration readback, event copy, diagnostic, and evidence viewing |
| Maintainer | Observer scope plus specifically authorized configuration and maintenance workflows |
| Validation engineer | Maintainer scope plus approved FPGA/HIL procedures, fixture coordination, and validation-only operations |
| Administrator | Local user/profile management, release installation, policy, key, and audit administration; no implicit permission to issue device commands |
| Automation identity | Explicit command allowlist and campaign scope without interactive privilege inheritance |

## 7.2 Build and Runtime Profiles

| Profile | Required disposition |
|---|---|
| Observation | Nondestructive operation only |
| Maintenance | Reviewed maintenance commands and configuration workflows |
| FPGA validation | VisionFive 2 plus ULX3S/ECP5-85F UUT, controlled procedures, engineering evidence, and permitted validation hooks |
| HIL | Approved fixtures, signal sources, analyzers, and fault injection at owned external boundaries |
| Production-safe | No raw writes, FPGA-private access, unrestricted test operations, or software fault injection |

`DCS-PROF-001` — Effective permissions shall be the intersection of build-profile capability, runtime-profile capability, authenticated role, device compatibility, device operating state, and procedure authorization.

`DCS-PROF-002` — A profile shall default to the least privilege needed for its declared purpose.

`DCS-PROF-003` — Changing to a more privileged profile shall require application restart or an equivalently strong reinitialization that invalidates prior session authority.

`DCS-PROF-004` — Production-safe packages shall omit validation-only implementations, raw-write surfaces, fixture-control adapters, and fault-injection capabilities rather than merely hiding their presentation.

# 8. Execution and Deployment Environment

## 8.1 Baseline Target

The required Revision A target is an embedded application executing on the VisionFive 2 single-board computer. The approved build profile shall identify the operating environment, kernel or runtime where applicable, filesystem and persistence locations, device permissions, time source, process supervision, and platform BSP version.

## 8.2 Deployment Requirements

`DCS-ENV-001` — The Console shall start, operate, stop, and recover under the VisionFive 2 target profile without requiring a development workstation.

`DCS-ENV-002` — The Console shall support headless operation through a local terminal and controlled automation interface.

`DCS-ENV-003` — The application shall not require a graphical display, desktop environment, network service, or cloud connection for core device operation and FPGA validation.

`DCS-ENV-004` — Optional remote presentation shall not own device sessions or bypass local authorization, command serialization, audit, or recovery policy.

`DCS-ENV-005` — Installation shall validate package identity, integrity metadata, target compatibility, runtime dependencies, storage capacity, permissions, and required device interfaces before enabling the application.

`DCS-ENV-006` — The application shall use bounded storage policies and shall signal low-space and persistence-unavailable conditions before evidence is silently lost.

# 9. Software Architecture

## 9.1 Logical Components

| Component | Principal responsibility |
|---|---|
| Presentation adapter | Human-readable views, prompts, confirmations, progress, and results |
| Automation adapter | Versioned command schema, batch execution, and machine-readable results |
| Command authority | Role checks, profile checks, preconditions, confirmation, and audit correlation |
| Workflow engine | Ordered typed operations, deadlines, cancellation policy, and postcondition verification |
| Device-session service | Lifecycle, Dragon SDK context, serialization, interrupt/event service, and recovery |
| Configuration service | Desired configuration, validation, diff, plan, apply, active readback, and persistence |
| Observation service | Typed acquisition, freshness, history, snapshots, and display models |
| Validation service | Campaign execution, expected-result binding, fixture coordination, and evidence assembly |
| Evidence service | Structured logs, raw observations, captures, hashes, export, and retention |
| Platform adapter | VisionFive 2 process, storage, time, interrupt, and approved BSP integration |

## 9.2 Dependency Rules

`DCS-ARCH-001` — Presentation and automation adapters shall request semantic application commands and shall not call the BSP, SPI primitive, or generated register accessors directly.

`DCS-ARCH-002` — All device operations shall pass through one device-session service and one Dragon SDK device context per physical UUT.

`DCS-ARCH-003` — Configuration, observation, diagnostics, and validation components shall share typed domain models while retaining the requested, staged, active, current, sticky, pending, historical, and derived distinctions.

`DCS-ARCH-004` — The workflow engine shall be independent of the terminal rendering technology and VisionFive 2 device-node naming.

`DCS-ARCH-005` — Validation-only adapters shall remain outside the production-safe dependency graph.

## 9.3 Failure Containment

`DCS-ARCH-006` — A presentation failure shall not corrupt the device session, command result, audit record, or retained evidence.

`DCS-ARCH-007` — An exporter failure shall preserve the source evidence in local controlled storage and shall report the failed export distinctly.

`DCS-ARCH-008` — An automation-client disconnect shall not create an implicit retry, rollback, acknowledgement, clear, reset, or continuation of an unapproved state-changing workflow.

# 10. Process, Thread, and Scheduling Model

## 10.1 Execution Model

The Console may be implemented as one process or as a locally supervised set of processes. Logical ownership shall remain the same in either realization.

The minimum logical execution activities are:

- command coordinator;
- deferred host-interrupt and event service;
- scheduled observation;
- persistence and evidence writer;
- presentation or automation request handling; and
- validation procedure execution when enabled.

## 10.2 Scheduling Requirements

`DCS-EXEC-001` — One device session shall permit at most one state-changing or selector/snapshot/protected/staged/reconciliation workflow at a time.

`DCS-EXEC-002` — Host-interrupt service, watchdog service when explicitly configured, response reconciliation, and reset detection shall receive deadlines and priorities independent of UI activity.

`DCS-EXEC-003` — Rendering, report generation, compression, export, and slow storage shall not execute while holding a Dragon SDK device lock.

`DCS-EXEC-004` — Callbacks shall enqueue bounded work and shall not recursively call the driver or perform unbounded I/O.

`DCS-EXEC-005` — Application shutdown shall stop new command admission, resolve or mark outstanding operations, quiesce service tasks, persist required records, mask the host-side interrupt receiver, close the device context, and close evidence storage in that order.

`DCS-EXEC-006` — Cancellation shall stop only work not yet admitted or shall transition an admitted state-changing operation to definitive-result evaluation and reconciliation; it shall never claim rollback by assumption.

# 11. Device, Session, and Lifecycle Model

## 11.1 Session Identity

One device session shall bind:

- one physical connection profile;
- one Dragon SDK device context;
- one discovered device identity and lifecycle generation;
- one generated-binding compatibility decision;
- one command coordinator;
- one observation and interrupt/event service context;
- one desired-configuration context; and
- one evidence namespace.

## 11.2 Session Requirements

`DCS-SES-001` — The Console shall not merge observations, commands, evidence, configuration, or reconciliation records from different physical devices or lifecycle generations.

`DCS-SES-002` — Every cached observation shall carry device-session identity, lifecycle generation, host acquisition time, source, freshness, and validity.

`DCS-SES-003` — A device identity change, reset indication, transport replacement, or binding-profile change shall create a new lifecycle generation and invalidate prior live-state caches.

`DCS-SES-004` — Historical evidence shall remain accessible after a session closes but shall be visibly separated from live observations.

`DCS-SES-005` — The Revision A VisionFive 2 profile shall support one active UUT session. Multi-UUT support may be added only with independent contexts, physical identities, command coordinators, evidence namespaces, and resource budgets.

# 12. VisionFive 2 Platform Integration

## 12.1 Platform Role

The VisionFive 2 is the external embedded host. It owns application execution, memory, storage, SPI-master operation through the approved BSP, reception of the Dragon Core host interrupt when connected, monotonic time, synchronization, process supervision, user access, and evidence persistence.

## 12.2 Platform Requirements

`DCS-VF2-001` — The Console shall use the VisionFive 2 BSP contract defined by `RCA-DFC-SW-003`, including SPI transaction, host interrupt, monotonic time, locking, ordering, and actual-transfer reporting services.

`DCS-VF2-002` — The platform profile shall identify the SPI controller instance, chip-select implementation, controller mode, supported clock range, interrupt input when present, interrupt polarity and sensitivity, reset coordination, cache/DMA behavior, deadline resolution, and cancellation behavior without embedding those facts in portable Console logic.

`DCS-VF2-003` — The platform adapter shall prove continuous chip select for one complete command/response exchange and shall reject a platform configuration that cannot preserve it.

`DCS-VF2-004` — The platform adapter shall report actual captured length and transport termination. A successful host-controller return alone shall not be treated as a successful Dragon Core operation.

`DCS-VF2-005` — Host cache maintenance, DMA descriptors, controller FIFOs, memory barriers, interrupt-controller acknowledgement, and device permissions shall remain platform responsibilities.

`DCS-VF2-006` — Platform-specific failures shall be recorded separately from Dragon Core protocol results and device-reported failures.

`DCS-VF2-007` — The target package shall include a reproducible platform self-test that checks storage, monotonic time, SPI loop or fixture behavior where available, interrupt reception where connected, and required permissions without issuing an unauthorized Dragon Core state-changing command.

# 13. ULX3S/ECP5-85F UUT Integration Profile

## 13.1 UUT Definition

For the Revision A FPGA-validation profile, the UUT is an ULX3S development board populated with an ECP5-85F FPGA and loaded with an identified Dragon Core FPGA realization. The UUT profile identifies an integration environment; it does not define Dragon Core logical behavior.

## 13.2 Required UUT Metadata

| Metadata class | Required identification |
|---|---|
| Board | ULX3S board identity and applicable board revision |
| FPGA | ECP5-85F device identity |
| Image | Bitstream/build identifier, source revision, build configuration, and integrity value |
| Wrapper | FPGA technology-wrapper identifier and revision |
| Constraints | Constraint-set identifier and revision |
| Connection | Approved wiring/fixture identifier and revision |
| Clock/reset | Integration-profile identifiers for supplied clock and reset behavior |
| Logical contract | Applicable Dragon Core product, SRS, Architecture, Register Map, and generated-binding revisions |

## 13.3 UUT Requirements

`DCS-UUT-001` — The Console shall refuse validation-result status when required UUT, image, wrapper, constraint, fixture, or generated-binding identity is absent or incompatible.

`DCS-UUT-002` — The Console shall not use ULX3S board resources, ECP5 primitives, wrapper registers, debug signals, or validation observability as a substitute for the public SPI/register contract.

`DCS-UUT-003` — Optional validation instrumentation may be correlated with Console records only when separately identified, time-related by a documented method, and excluded from the device pass/fail oracle unless the controlling Verification Plan permits it.

`DCS-UUT-004` — Removing validation-only instrumentation shall not change the portable Console, SDK, command, configuration, observation, recovery, or expected device behavior.

`DCS-UUT-005` — A different ULX3S revision, ECP5 density, FPGA image, wrapper, or fixture shall be treated as a different validation-environment configuration and shall not silently inherit prior evidence.

# 14. SPI and Host-Interrupt Integration

## 14.1 SPI Command and Data Path

The Console shall access the UUT through the Dragon SDK using the SRS-defined SPI transport and generated host definitions. Numeric protocol facts and register encodings remain owned by the controlling specifications and generated artifacts.

## 14.2 Host Interrupt Path

The Dragon Core host interrupt is a separate logical indication from the SPI command/data path. It may be absent during early polled bring-up, but full interrupt and host-conformance evidence shall not pass unless the applicable integration profile connects and verifies it.

## 14.3 Integration Requirements

`DCS-IF-001` — The Console shall not split one Dragon Core command and response across separate chip-select assertions.

`DCS-IF-002` — The Console shall use absolute deadlines and shall preserve actual transferred extent, response-integrity classification, device status, completed-word count, and terminal outcome returned by the SDK.

`DCS-IF-003` — The Console shall not retry a state-changing command solely because of timeout, short response, CRC failure, process interruption, or client disconnection.

`DCS-IF-004` — Host-interrupt top-half handling shall be bounded, shall acknowledge only the host interrupt controller when required, and shall defer Dragon Core service to the device-session worker.

`DCS-IF-005` — Deferred interrupt service shall use the SDK sequence governed by the controlling contract and shall reread pending state before host-side unmask.

`DCS-IF-006` — A polling-only bring-up profile shall be labeled incomplete for any Verification Plan outcome requiring host-interrupt behavior.

`DCS-IF-007` — SPI captures used as evidence shall identify the session, operation, host timing basis, controller configuration, and UUT configuration and shall preserve raw bytes without making them an alternate protocol definition.

# 15. Startup, Discovery, and Compatibility

## 15.1 Startup Sequence

The Console shall perform the following application sequence without redefining device startup:

1. Validate the installed package, build profile, platform profile, UUT profile, storage, and local policy.
2. Establish the VisionFive 2 BSP and post-reset SPI quiet preconditions.
3. Construct and open the Dragon SDK device context.
4. Discover product, revision, capabilities, register-map revision, device build identity, host readiness, operating state, and initial diagnostics.
5. Select the exact generated-binding compatibility profile.
6. Create the device-session evidence header before state-changing access.
7. Read active configuration and retained evidence nondestructively.
8. Compare desired and active configuration without applying changes automatically.
9. Register and enable host-interrupt reception only after device-side interrupt configuration and application readiness.
10. Enter an operating state permitted by the compatibility result and selected application profile.

## 15.2 Compatibility Requirements

`DCS-START-001` — The Console shall complete identity discovery and compatibility validation before exposing any state-changing command.

`DCS-START-002` — Product revision, register-map revision, capability bitmap, device build identity, FPGA image identity, SDK version, binding identity, and Console version shall be evaluated as independent compatibility axes.

`DCS-START-003` — An unknown or incompatible device may be observed only through a bounded compatibility-safe discovery path; ordinary reads, writes, clears, pops, resets, test commands, and configuration application shall remain unavailable.

`DCS-START-004` — Startup shall preserve and display preexisting device evidence before any authorized clear.

`DCS-START-005` — The Console shall not infer readiness or compatibility from a successful SPI electrical transfer alone.

# 16. Console Operating-State Model

## 16.1 Application States

| State | Meaning | Permitted device activity |
|---|---|---|
| `STOPPED` | No application session | None |
| `PLATFORM_CHECK` | Local environment validation | Platform self-test only |
| `CONNECTING` | BSP and SDK context construction | Compatibility-safe access only |
| `DISCOVERING` | Identity and capability discovery | Nondestructive discovery |
| `INCOMPATIBLE` | Compatibility rejected | Bounded identity display only |
| `OBSERVING` | Compatible nondestructive session | Reads and event copy as defined |
| `CONFIGURING` | Authorized desired-configuration workflow | Serialized typed configuration operations |
| `OPERATIONAL` | Configured observation and authorized service | Profile-authorized typed operations |
| `VALIDATING` | Controlled FPGA/HIL procedure active | Procedure-allowlisted operations |
| `RECONCILING` | State-changing result uncertain | Reconciliation and diagnostics only |
| `RECOVERING` | Reset, reconnect, or lifecycle recovery | Nondestructive discovery and recovery plan |
| `DEGRADED` | Session remains observable with a declared limitation | Explicit limited allowlist |
| `FAILED` | Invariants or required services cannot be preserved | No ordinary device commands |
| `SHUTTING_DOWN` | Controlled termination | Completion/reconciliation and close only |

## 16.2 State Requirements

`DCS-STATE-001` — Console states are software workflow states and shall not be presented as alternate Dragon Core primary operating states.

`DCS-STATE-002` — Every transition shall have an identified cause, source state, destination state, permitted actions, denied actions, audit record, and recovery rule.

`DCS-STATE-003` — Entry into `RECONCILING`, `RECOVERING`, `INCOMPATIBLE`, or `FAILED` shall immediately stop admission of ordinary state-changing commands.

`DCS-STATE-004` — `DEGRADED` operation shall display the exact unavailable service, lost assurance, affected data freshness, prohibited actions, and exit condition.

# 17. Configuration Management Workflows

## 17.1 Configuration Objects

The Console shall maintain distinct objects for:

- desired external configuration;
- validated desired configuration;
- discovered active device configuration;
- generated configuration difference;
- reviewed application plan;
- per-operation command results;
- final active-readback result; and
- retained configuration evidence.

## 17.2 Configuration Requirements

`DCS-CFG-001` — Desired configuration shall use a versioned semantic schema and generated logical identifiers; it shall not store unchecked register addresses or hand-maintained bit masks.

`DCS-CFG-002` — Import shall validate syntax, schema version, product applicability, register-map compatibility, capability applicability, value type, range, unit, legal enumeration, cross-field constraints supplied by the SDK, and unknown-field policy before device access.

`DCS-CFG-003` — The Console shall display desired, staged, active, default, and prior-observed values distinctly.

`DCS-CFG-004` — A configuration plan shall identify every affected typed object, required protected-write step, staged group, commit, dependency, operating-state precondition, expected active readback, and recovery disposition.

`DCS-CFG-005` — Applying a plan shall require explicit authorization and shall not automatically enable operational behavior unless that enable is a separately reviewed step.

`DCS-CFG-006` — Successful transport does not establish active configuration. Each changed object shall receive applicable active readback and comparison before it is reported active.

`DCS-CFG-007` — A partial, rejected, ambiguous, or readback-mismatched configuration plan shall stop at the affected dependency boundary and shall preserve all completed extents and evidence.

`DCS-CFG-008` — Following reset or identity change, the Console shall rediscover active configuration and shall not reapply nondefault values until caller policy, compatibility, and recovery preconditions are revalidated.

`DCS-CFG-009` — Configuration export shall identify whether each value is desired, validated, staged-observed, active-observed, default-derived, or unavailable.

# 18. Observation and Status Presentation

## 18.1 Observation Classes

The Console shall support typed presentation of:

- device identity and compatibility;
- host readiness and Dragon Core operating state;
- module readiness and current status;
- desired, staged, and active configuration;
- current conditions and effective outputs;
- sticky evidence and terminal records;
- pending interrupt and event state;
- queue, FIFO, mailbox, and route state;
- saturating counters and loss indicators;
- reset and clock evidence;
- host reconciliation results; and
- software-side freshness, loss, persistence, and service health.

## 18.2 Presentation Requirements

`DCS-OBS-001` — Requested, commanded, staged, active, effective, current, sticky, pending, historical, cached, and derived values shall have distinct labels and machine-readable classes.

`DCS-OBS-002` — Each live observation shall display or expose its acquisition time, lifecycle generation, freshness, source, validity, and any read error.

`DCS-OBS-003` — A stale value shall remain visibly stale and shall not be recolored, reordered, or described as current merely because a newer read failed.

`DCS-OBS-004` — Active conditions and sticky historical evidence shall be displayed independently; clearing one shall not alter the displayed history of the other unless a new read proves the change.

`DCS-OBS-005` — Device-reported counters and loss evidence shall be distinct from Console queue drops, missed polls, persistence failures, or export failures.

`DCS-OBS-006` — Units and decoded enumerations shall come from typed SDK metadata or controlled presentation mappings traceable to the owning source.

`DCS-OBS-007` — The Console shall retain the raw typed observation underlying every displayed derived status and shall permit evidence export without relying on a screenshot.

# 19. Interrupt, Event, and Data Service

## 19.1 Service Model

The Console shall coordinate host interrupt reception, Dragon Core pending-state service, bounded event retrieval, communication data retrieval, typed acknowledgement, and external persistence through the Dragon SDK.

## 19.2 Service Requirements

`DCS-SVC-001` — Interrupt service shall preserve the controlling order among vector or pending reads, owning-resource service, acknowledgement or clear, pending reread, and host-side unmask.

`DCS-SVC-002` — A same-cycle new source, still-active source, and unrelated pending source shall remain distinguishable and shall not be suppressed by a broad clear.

`DCS-SVC-003` — Event and queue retrieval shall use bounded batches and shall preserve source order, record identity, device timestamp, acquisition time, lifecycle generation, and retrieval result.

`DCS-SVC-004` — A destructive pop, acknowledgement, or clear shall occur only through a typed workflow that identifies the exact target and preserves required evidence before destruction.

`DCS-SVC-005` — Event-store overwrite, queue overflow, protocol drop, counter saturation, Console backpressure, and persistence loss shall be recorded as separate loss classes.

`DCS-SVC-006` — When external persistence required by the active campaign is unavailable, the Console shall stop destructive retrieval or clearing unless the procedure explicitly permits continued operation and records the resulting evidence limitation.

`DCS-SVC-007` — Polling shall supplement but shall not be reported as passing interrupt behavior required by the controlling Verification Plan.

# 20. Functional-Module Console Services

## 20.1 Required Service Families

The Console shall expose typed services, when supported by discovered capabilities, for:

- system identity, lifecycle, operating state, reset, clocks, and timestamp;
- interrupt controller and event logger;
- GPIO;
- rotor RPM, engine RPM, pulse/frequency, sensor monitoring, and system health;
- watchdog, fault manager, interlock engine, lost-link supervisor, and logical safety outputs;
- ARINC 429 receive and transmit;
- Classical CAN;
- UART;
- databus routing;
- mask-defined user logic; and
- user-configurable routing.

## 20.2 Module-Service Requirements

`DCS-MOD-001` — Each module view shall derive availability from discovered capability and compatibility rather than a compile-time assumption or platform name.

`DCS-MOD-002` — Module views shall use the typed API family governed by `RCA-DFC-SW-003` and shall not duplicate module-specific register workflows.

`DCS-MOD-003` — Unsupported, disabled, unconfigured, not ready, active, faulted, inhibited, and unavailable shall remain distinct states.

`DCS-MOD-004` — Communication views shall distinguish received data, transmitted data, pending data, accepted requests, completed transmissions, rejected requests, protocol errors, and loss evidence.

`DCS-MOD-005` — Safety-related views shall distinguish request, authorization, inhibit, commanded output, effective logical output, active fault, sticky evidence, and external interpretation.

`DCS-MOD-006` — The Console shall not convert a logical safety output into an aircraft actuator command or imply that displayed low-voltage logic directly controls aircraft energy.

`DCS-MOD-007` — User logic and routing views shall expose only the finite mask-defined functions, endpoints, and legal routes provided by generated definitions and discovered capability.

# 21. Diagnostics and Evidence Management

## 21.1 Diagnostic Classes

The Console shall preserve independence among:

- current status;
- sticky device evidence;
- terminal operation and reconciliation records;
- event records;
- interrupt state;
- fault state;
- reset and clock evidence;
- per-source and aggregate loss counters;
- production-test terminal status when authorized;
- BSP and host-controller diagnostics;
- Console service diagnostics; and
- persistence and export diagnostics.

## 21.2 Diagnostic Requirements

`DCS-DIAG-001` — Diagnostic acquisition shall be nondestructive unless an approved procedure explicitly selects a defined snapshot, pop, clear, command, injection, or test operation.

`DCS-DIAG-002` — A diagnostic clear shall identify the exact W1C mask or whole-counter operation through a typed SDK request and shall show the evidence that will change.

`DCS-DIAG-003` — Newly observed evidence shall be persisted before a user-authorized destructive clear when the active policy requires retention.

`DCS-DIAG-004` — The Console shall never clear a device fault, interrupt, event, counter, diagnostic, or sticky indication solely to suppress an alert or simplify presentation.

`DCS-DIAG-005` — Diagnostic reports shall preserve raw device values, typed decoding, acquisition context, derived conclusions, and any unavailable or stale fields.

`DCS-DIAG-006` — FPGA-private instrumentation shall be stored in a separate evidence class and shall not be merged into device-reported diagnostics.

# 22. Command and Destructive-Operation Control

## 22.1 Controlled Operation Classes

The following are controlled operations:

- configuration write, protected write, staged write, commit, and enable;
- interrupt acknowledge or clear;
- event, queue, FIFO, or mailbox pop;
- diagnostic or counter clear;
- watchdog service or policy change;
- fault, interlock, lost-link, or safety-related command;
- databus transmission;
- route or user-logic change;
- module, safety-domain, system, SPI-domain, or test-domain reset request;
- test authorization, production-test operation, loopback, or injection; and
- raw engineering write when permitted.

## 22.2 Command Requirements

`DCS-CMD-001` — A controlled operation shall require a typed request, compatible session, permitted Console state, permitted profile, authorized role, satisfied preconditions, explicit deadline, and evidence correlation identifier.

`DCS-CMD-002` — A destructive operation shall require explicit selection of its exact scope and effect; wildcard, all-source, all-counter, or broad-clear defaults are prohibited.

`DCS-CMD-003` — Interactive confirmation shall display the device identity, operation, target, requested value or mask, expected effect, affected evidence, reversibility, and recovery consequence.

`DCS-CMD-004` — Automation shall use an explicit allowlist and shall supply the same semantic information required for interactive confirmation; an automation flag shall not bypass authorization or compatibility checks.

`DCS-CMD-005` — A displayed or machine-reported success shall require a definitive SDK result and every applicable postcondition, including active readback.

`DCS-CMD-006` — Partial completion, rejection, ambiguous completion, indeterminate result, or postcondition mismatch shall not be reported as success.

`DCS-CMD-007` — Command history shall preserve requested input, preconditions, admitted time, transport result, device result, completed extent, readback, reconciliation, retry disposition, and final Console classification.

# 23. Ambiguous-Outcome Reconciliation

## 23.1 Entry Conditions

The Console shall enter reconciliation after any state-changing operation for which a definitive response and required postconditions are unavailable, including response loss, truncation, invalid integrity, uncertain controller termination, process interruption after admission, or SDK classification as ambiguous.

## 23.2 Reconciliation Requirements

`DCS-REC-001` — Entry into reconciliation shall block later state-changing operations for the affected device context until a terminal disposition or recovery boundary is established.

`DCS-REC-002` — The Console shall preserve the original operation ID, lifecycle generation, command identity, transmitted extent, captured response, transport classification, device status when available, and completed-word count.

`DCS-REC-003` — Reconciliation shall use only the SDK workflow derived from the host-reconciliation record, active readback, current state, sticky evidence, counters, and diagnostics defined by controlling specifications.

`DCS-REC-004` — The Console shall classify the outcome as no effect proven, complete, partial, rejected, ambiguous, or indeterminate and shall preserve the SDK retry disposition.

`DCS-REC-005` — A state-changing command shall not be retried until reconciliation proves retry safe or an approved recovery policy establishes a new lifecycle boundary.

`DCS-REC-006` — Reconciliation results shall show independently the original command result, terminal device evidence, active readback, Console conclusion, and any unresolved limitation.

`DCS-REC-007` — Failure to reconcile shall transition the session to `RECOVERING`, `DEGRADED`, or `FAILED`; it shall not silently resume ordinary operation.

# 24. Disconnect, Reset, and Recovery

## 24.1 Recovery Triggers

Recovery shall begin after:

- SPI transport loss or replacement;
- host-interrupt service failure that invalidates service assurance;
- detected device reset or identity change;
- Console restart with an existing UUT;
- VisionFive 2 restart or power interruption;
- ambiguous reset request;
- lost configuration assurance;
- incompatible generated bindings; or
- failure of a required persistence or timing service.

## 24.2 Recovery Sequence

1. Stop ordinary command admission and stop any watchdog service whose timing or policy guarantees are no longer valid.
2. Preserve outstanding operation and software evidence.
3. Reestablish platform and SPI preconditions.
4. Rediscover device identity, lifecycle, reset state, compatibility, active configuration, and retained evidence nondestructively.
5. Reconcile an outstanding state-changing operation when the controlling evidence permits.
6. Compare active configuration with desired configuration.
7. Create and authorize a new reapplication plan for lost nondefault volatile configuration.
8. Verify active readback and required readiness.
9. Reestablish interrupt service and other policy-driven services.
10. Resume only the operations permitted by the final recovery classification.

## 24.3 Recovery Requirements

`DCS-RCV-001` — Reset or reconnect shall invalidate cached live state, selectors, snapshots, pending protected access, staged-workflow assumptions, and prior lifecycle authority.

`DCS-RCV-002` — Historical external records shall survive device reset and shall not be represented as retained device evidence.

`DCS-RCV-003` — Nondefault volatile configuration shall be reapplied only after fresh compatibility, desired-configuration validation, device-state discovery, and operator or approved-policy authorization.

`DCS-RCV-004` — An ambiguous reset request shall not be repeated by default; the Console shall rediscover reset state and terminal evidence first.

`DCS-RCV-005` — A failed recovery step shall preserve the exact last proven state and shall not claim that the UUT is configured, operational, or safe for the next procedure.

# 25. FPGA Validation and Host-Conformance Operation

## 25.1 Validation Role

The Console shall provide the VisionFive 2 host-client functions needed to execute the applicable ECP5 FPGA, HIL, and external-host conformance outcomes owned by `RCA-DFC-VP-002`. It shall orchestrate and record those outcomes without redefining them.

## 25.2 Required Validation Capabilities

The FPGA-validation profile shall support:

- UUT and environment identity capture;
- complete identity and register-block discovery;
- typed exercise of every supported access class and public functional API;
- protected, staged, commit, active-readback, selector, snapshot, pop, and clear workflows;
- SPI boundary, error, abort, truncation, timeout, and reconciliation scenarios permitted by the approved fixture;
- host-interrupt service and simultaneous-source scenarios;
- reset, reconnect, active-configuration reconstruction, and reapplication scenarios;
- event, queue, counter, loss, diagnostic, and long-duration retrieval;
- procedure-directed external fixture coordination;
- raw SPI capture association;
- comparison with an independent expected model; and
- reproducible evidence packaging.

## 25.3 Validation Requirements

`DCS-VAL-001` — Each validation run shall identify the applicable Verification Plan case or subordinate software test requirement; the Console shall not create a competing controlling case identifier.

`DCS-VAL-002` — Expected device results shall derive from controlling specifications and an independent oracle, not from copying Console implementation output or observed UUT state.

`DCS-VAL-003` — Pass/fail shall be automatic and unambiguous for every automated step; visual inspection may supplement but shall not be the sole criterion.

`DCS-VAL-004` — A case requiring host interrupt, external interface stimulus, protocol analysis, response interruption, or fault injection shall not pass when the required fixture capability is absent.

`DCS-VAL-005` — A case shall fail or be explicitly incomplete when required evidence, identity, raw capture, expected comparison, or postcondition is missing.

`DCS-VAL-006` — The Console shall distinguish a Console defect, SDK defect, BSP defect, FPGA integration defect, board/fixture defect, UUT nonconformance, controlling-specification issue, and environmental failure in result records without silently assigning blame.

`DCS-VAL-007` — Validation-only access shall not be used to compensate for a nonconforming public SPI or register contract.

# 26. Test Campaign and Procedure Execution

## 26.1 Campaign Model

A campaign shall be a signed or integrity-protected, versioned set of procedures. Each procedure shall define:

- purpose and governing requirement or case;
- required Console, SDK, binding, UUT, image, wrapper, fixture, and environment identities;
- required role and application profile;
- preconditions and initial observations;
- typed ordered actions and deadlines;
- expected results and independent oracle reference;
- destructive effects and confirmation policy;
- required captures and evidence;
- cleanup and recovery; and
- pass, fail, blocked, aborted, and incomplete criteria.

## 26.2 Procedure Requirements

`DCS-CAMP-001` — A procedure shall be schema validated and compatibility checked before its first device action.

`DCS-CAMP-002` — A procedure shall not contain unchecked register addresses, wire encodings, shell commands, or arbitrary executable code in place of typed Console operations.

`DCS-CAMP-003` — Procedure variables shall have explicit types, units, bounds, sources, defaults, and mutability.

`DCS-CAMP-004` — Resume after interruption shall occur only at an explicitly declared safe checkpoint whose device state and external evidence are revalidated.

`DCS-CAMP-005` — A failed or aborted step shall execute only its declared safe cleanup; it shall not assume that a state-changing command failed or that device state rolled back.

`DCS-CAMP-006` — Randomized procedures shall record their seed and generated inputs and shall remain reproducible.

`DCS-CAMP-007` — Campaign results shall retain every procedure version, ordered operation, raw result, expected comparison, operator or automation identity, and final disposition.

# 27. Fixtures, Instrumentation, and External Boundaries

## 27.1 Boundary Allocation

| Element | Console responsibility | External owner responsibility |
|---|---|---|
| SPI capture | Correlate capture identity and operation | Analyzer connection, calibration, and raw acquisition |
| Host interrupt | Record host reception and service | Physical wiring, voltage compatibility, and receiver configuration |
| Reset | Issue only approved software request or coordinate procedure | Physical reset generation and board behavior |
| Digital stimulus | Command approved fixture adapter | Signal generation, electrical levels, timing accuracy, and protection |
| Protocol interfaces | Coordinate and collect records | Transceivers, analyzers, termination, and digital-boundary access |
| Fault injection | Authorize and record approved injection | Physical or integration-owned injection implementation |

## 27.2 Fixture Requirements

`DCS-FIX-001` — Each fixture adapter shall declare capabilities, units, limits, calibration status where applicable, command semantics, safe states, and failure behavior.

`DCS-FIX-002` — The Console shall validate fixture identity and capability before starting a dependent procedure.

`DCS-FIX-003` — Fixture operations shall be time-correlated with Console operations by a documented method and shall record correlation uncertainty.

`DCS-FIX-004` — Loss of fixture control shall stop dependent procedure steps, preserve evidence, and request the adapter's defined safe state without claiming that the physical environment reached it unless confirmed.

`DCS-FIX-005` — External electrical behavior shall not be attributed to Dragon Core when responsibility belongs to a board, transceiver, fixture, load, or instrument.

# 28. Data Model and Persistence

## 28.1 Persistent Data Classes

The Console shall persist, as applicable:

- application, SDK, binding, platform, UUT, image, wrapper, fixture, and specification identities;
- desired configuration and configuration application records;
- raw typed observations and derived presentation records;
- command and reconciliation records;
- events, diagnostics, counters, and loss records;
- campaigns, procedure inputs, expected-result references, and results;
- audit records;
- raw capture references and integrity metadata; and
- software-side health, storage, export, and recovery records.

## 28.2 Persistence Requirements

`DCS-DATA-001` — Persistent schemas shall be versioned independently from the Console API, Dragon SDK, register map, FPGA image, and device revision.

`DCS-DATA-002` — Every record shall carry a stable record identifier, record type, schema version, creation time, device session, lifecycle generation when applicable, source, validity, and integrity status.

`DCS-DATA-003` — Raw observations shall be immutable after commit. Corrections or interpretations shall be new linked records.

`DCS-DATA-004` — A device timestamp and a host timestamp shall remain independent values; correlation shall record the method and uncertainty.

`DCS-DATA-005` — Persistence shall use crash-consistent commit behavior so a restart can distinguish committed, incomplete, and corrupt records.

`DCS-DATA-006` — Retention limits shall never silently delete evidence required by an active or released campaign. Deletion shall follow an authorized, audited retention policy.

`DCS-DATA-007` — Import shall validate schema, integrity, provenance, compatibility, and size bounds before data becomes active configuration or executable procedure input.

# 29. Logging, Audit, and Evidence Export

## 29.1 Record Types

| Record | Required purpose |
|---|---|
| Operational log | Application lifecycle, service health, warnings, and errors |
| Command audit | Authority, request, confirmation, admission, result, and postcondition |
| Device evidence | Raw typed observations, events, diagnostics, counters, and reconciliation |
| Validation result | Procedure, expected result, actual result, raw captures, and disposition |
| Export manifest | Included records, identities, hashes, omissions, and exporter version |

## 29.2 Logging and Export Requirements

`DCS-LOG-001` — Logs shall use structured fields and stable severity and category values; human text shall supplement rather than replace typed data.

`DCS-LOG-002` — Sensitive credentials, secrets, private keys, authentication tokens, and unrelated user data shall not be written to logs or evidence packages.

`DCS-LOG-003` — An audit record shall be created before command admission and completed with the definitive, reconciled, or unresolved result.

`DCS-LOG-004` — Evidence export shall be read-only with respect to device state and shall not clear, pop, acknowledge, reset, or otherwise modify the UUT.

`DCS-LOG-005` — Each export shall include a manifest of identities, schemas, time bases, record counts, hashes, missing data, known limitations, and tool version.

`DCS-LOG-006` — A rendered report shall remain traceable to immutable source records and shall not be the sole retained evidence.

`DCS-LOG-007` — Export success shall require completed output, integrity verification, and durable-close confirmation from the selected storage service.

# 30. Human and Automation Interfaces

## 30.1 Minimum Human Interface

The minimum required human interface is a local command-line or terminal interface usable on a headless VisionFive 2. An optional graphical or remote presentation may be added as an adapter over the same application services.

## 30.2 Human-Interface Requirements

`DCS-UI-001` — Commands shall use semantic names, explicit targets, typed values, units, and unambiguous help text.

`DCS-UI-002` — The prompt or status header shall show the active profile, user role, device identity, lifecycle generation, Console state, compatibility state, and whether displayed observations are live or historical.

`DCS-UI-003` — Dangerous abbreviations, position-dependent destructive arguments, and implicit selection of the last device or last destructive target are prohibited.

`DCS-UI-004` — Interactive output shall distinguish success, rejection, partial completion, ambiguity, stale data, unavailable data, blocked precondition, and software failure without relying only on color.

`DCS-UI-005` — Help and examples shall demonstrate active readback, evidence-preserving diagnostics, exact-scope clear, and reconciliation; they shall not demonstrate blind retry or broad clear.

## 30.3 Automation Interface Requirements

`DCS-AUTO-001` — The automation interface shall use a versioned local schema with stable command and result types.

`DCS-AUTO-002` — Machine-readable results shall include operation ID, lifecycle generation, admission status, transport classification, device result, completed extent, postcondition, reconciliation, retry disposition, and evidence references.

`DCS-AUTO-003` — Automation requests shall be idempotent only where the semantic operation is proven idempotent; a client request identifier shall not substitute for device reconciliation.

`DCS-AUTO-004` — Automation shall not gain raw BSP or SPI access through shell escape, plugin loading, arbitrary code, or an undocumented maintenance endpoint.

# 31. Security and Access Control

## 31.1 Security Boundary

Dragon Console security protects external-host software, configuration, commands, credentials, evidence, packages, and local interfaces. It supplements but does not replace Dragon Core hardware enforcement.

## 31.2 Security Requirements

`DCS-SEC-001` — The Console shall authenticate interactive and automation identities when the deployment environment supports multiple identities or remote access.

`DCS-SEC-002` — Authorization shall be deny-by-default and shall be evaluated for every controlled operation.

`DCS-SEC-003` — Package, campaign, configuration, and imported evidence integrity shall be verified before use according to the release profile.

`DCS-SEC-004` — Privileged platform access to SPI, interrupt, storage, or fixtures shall be limited to the Console service components that require it.

`DCS-SEC-005` — Validation-only capabilities shall require both an engineering build profile and an authorized runtime profile.

`DCS-SEC-006` — The Console shall validate all external lengths, counts, paths, identifiers, strings, enumerations, and resource requests before allocation or device access.

`DCS-SEC-007` — Local and optional remote interfaces shall apply bounded request rates, bounded concurrent clients, bounded message sizes, and authenticated session expiry.

`DCS-SEC-008` — A security failure shall not cause an implicit device clear, reset, disable, retry, or safety command.

# 32. Concurrency and Resource Management

## 32.1 Bounded Resources

The Console shall define finite limits for:

- active sessions;
- queued commands;
- outstanding automation requests;
- observation cache entries;
- event and communication queues;
- log and evidence buffers;
- open campaign steps;
- fixture operations;
- export jobs;
- file sizes and storage consumption; and
- callbacks and subscribers.

## 32.2 Resource Requirements

`DCS-RES-001` — Every finite resource shall have a declared capacity, admission rule, full behavior, loss indication, recovery rule, and verification coverage.

`DCS-RES-002` — Resource exhaustion shall fail the requesting software operation without corrupting the device session or claiming a device failure.

`DCS-RES-003` — Software queue loss shall be counted and reported separately from device queue loss.

`DCS-RES-004` — The Console shall not require dynamic allocation after session initialization for deadline-critical interrupt, reconciliation, or watchdog-service paths.

`DCS-RES-005` — Lock ordering shall be documented and shall prevent a presentation, persistence, exporter, fixture, or authentication lock from blocking the Dragon SDK command lock indefinitely.

`DCS-RES-006` — Backpressure shall propagate as an explicit software status and shall not produce an automatic destructive pop, clear, or retry.

# 33. Timing and Performance

## 33.1 Timing Ownership

Device timing is owned by the SRS and Architecture. This section defines Console software obligations for meeting or measuring applicable host-side behavior without restating numeric device limits.

## 33.2 Requirements

`DCS-PERF-001` — Each device operation shall use an absolute monotonic deadline derived from the selected workflow and applicable controlling bound.

`DCS-PERF-002` — The Console shall record requested deadline, admission time, SPI start and completion times when supplied by the BSP, result time, and postcondition-read time for validation operations.

`DCS-PERF-003` — UI refresh, log formatting, report generation, and export shall not be used as timing references for host-interface conformance.

`DCS-PERF-004` — The validation profile shall characterize host scheduling, SPI-controller, interrupt-service, storage, and fixture latency sufficiently to determine whether an applicable case can make its required claim.

`DCS-PERF-005` — When timing assurance is lost, the Console shall stop any host service requiring that assurance and shall report the affected service and device evidence separately.

`DCS-PERF-006` — Long-duration runs shall monitor process liveness, memory and storage margins, queue high-water marks, missed deadlines, interrupt service, persistence latency, and clock-correlation stability.

# 34. Error Handling and Degraded Operation

## 34.1 Error Classes

| Error class | Examples | Required disposition |
|---|---|---|
| Input | Invalid command, schema, unit, range, or profile | Reject before device access |
| Authority | Missing role, profile, or confirmation | Reject and audit |
| Platform | SPI controller, interrupt, time, storage, permission, or process service | Isolate, record, and recover or degrade |
| Transport | Timeout, short transfer, cancellation uncertainty | Preserve extent; reconcile state change |
| Protocol | Marker, length, status, reserved field, or integrity failure | Reject response; reconcile state change |
| Device | Definitive rejection or reported fault | Preserve exact device result and evidence |
| Postcondition | Active-readback or required-state mismatch | Do not report success |
| Persistence | Commit, capacity, integrity, or export failure | Preserve source data and limit destructive work |
| Invariant | Impossible state or internal consistency failure | Stop command admission and enter `FAILED` |

## 34.2 Error Requirements

`DCS-ERR-001` — Error mapping shall preserve the original SDK status, BSP status, device status, completed extent, and raw diagnostic references.

`DCS-ERR-002` — Retries shall be bounded, explicit, and limited to operations whose controlling semantics and SDK disposition permit retry.

`DCS-ERR-003` — A local timeout shall not be reported as proof that no device effect occurred.

`DCS-ERR-004` — A degraded mode shall have an explicit operation allowlist and shall not be entered merely to keep a validation campaign running.

`DCS-ERR-005` — An internal invariant failure shall create a diagnostic record, stop ordinary device commands, preserve evidence, and require a new process or session lifecycle before recovery.

`DCS-ERR-006` — User-facing messages shall identify what is known, what is unknown, what evidence exists, what operations are blocked, and the safe next action.

# 35. Portability and Production Separation

## 35.1 Portability Model

The Console core shall be portable across conforming external hosts. The Revision A deployment requirement is VisionFive 2. Later production hosts may reuse the application core only through an approved BSP and platform profile that preserve the same SDK semantics.

## 35.2 Requirements

`DCS-PORT-001` — Portable Console code shall not depend on VisionFive 2 controller types, filesystem paths, interrupt numbers, native endianness, word size, alignment, or operating-system handles.

`DCS-PORT-002` — The ULX3S/ECP5-85F name may select a validation profile but shall not change portable device behavior or register interpretation.

`DCS-PORT-003` — FPGA-versus-ASIC variation shall be limited to validated implementation identity, separately controlled integration metadata, available fixtures, and explicitly isolated validation features.

`DCS-PORT-004` — Production-safe builds shall use the same typed SDK workflows validated on FPGA and shall not replace them with a production-only direct access path.

`DCS-PORT-005` — Optional remote, graphical, database, or fixture adapters shall be replaceable without changing the device-session or command-authority semantics.

# 36. Internal and External Software Interfaces

## 36.1 Required Interfaces

| Interface | Contract owner |
|---|---|
| Dragon SDK typed API | `RCA-DFC-SW-003` |
| VisionFive 2 BSP | `RCA-DFC-SW-003` and approved platform profile |
| Desired configuration schema | This specification and its controlled schema artifact |
| Console automation schema | This specification and its controlled schema artifact |
| Campaign/procedure schema | This specification and its controlled schema artifact |
| Evidence/export schema | This specification and its controlled schema artifact |
| Fixture adapter contract | This specification plus fixture-owned capability profile |
| User presentation | This specification |

## 36.2 Interface Requirements

`DCS-API-001` — Internal component interfaces shall use typed semantic objects and shall not expose raw pointers to mutable device-session state.

`DCS-API-002` — Every request shall carry caller identity, profile, device session, expected lifecycle generation, command type, deadline, and correlation identifier as applicable.

`DCS-API-003` — Every state-changing result shall carry the complete `dfc_command_result_t` semantics or a lossless Console representation of them.

`DCS-API-004` — Interface version negotiation shall fail closed when a required field, result class, or security property is unsupported.

`DCS-API-005` — External adapters shall not retain a borrowed SDK object or device-session pointer beyond its documented lifetime.

`DCS-API-006` — Plugins or dynamically loaded extensions shall not be part of the Revision A trusted device-command path unless separately specified, reviewed, signed, versioned, and verified.

# 37. Configuration, Schema, and Compatibility Versioning

## 37.1 Independent Version Axes

The following shall be independently versioned:

- Console application and public automation API;
- Console persistent schema;
- desired-configuration schema;
- campaign/procedure schema;
- evidence/export schema;
- Dragon SDK API and ABI;
- generated bindings and supported register-map range;
- VisionFive 2 platform profile;
- UUT, FPGA image, wrapper, constraint, and fixture profiles; and
- Dragon Core product, device build, capability, and register-map revision.

## 37.2 Versioning Requirements

`DCS-VER-001` — A compatibility matrix shall identify supported combinations without collapsing independent version axes into one release number.

`DCS-VER-002` — A breaking semantic or security change to a Console-owned public schema shall change its major version.

`DCS-VER-003` — Migration shall create a new versioned record set or configuration object and shall preserve the original input and migration report.

`DCS-VER-004` — Unknown required fields, unsupported major versions, incompatible bindings, or unverified migrations shall fail closed before device access.

`DCS-VER-005` — A release shall document compatibility separately for observation, configuration, maintenance, FPGA validation, HIL, and production-safe use.

# 38. Software Verification and Validation

## 38.1 Verification Levels

| Level | Minimum subjects |
|---|---|
| Unit | Parsers, validators, state machine, authority, result classification, models, persistence, export, and render-independent formatting |
| Component | Workflow engine, device session, configuration, observation, evidence, automation, fixture adapter, and platform adapter with controlled doubles |
| Integration | Console plus SDK and independent device model or RTL simulation |
| Target | Console on VisionFive 2 with controlled SPI and interrupt fixtures |
| FPGA/HIL | VisionFive 2 plus identified ULX3S/ECP5-85F UUT and required external fixtures |
| System | End-to-end startup, configuration, operation, validation, recovery, persistence, export, and shutdown |

## 38.2 Mandatory Verification Subjects

`DCS-VV-001` — Every `DCS-` requirement shall trace to at least one verification case and objective result.

`DCS-VV-002` — Unit and component tests shall cover every Console state and transition, role/profile decision, error class, result class, schema version decision, resource boundary, and retry disposition.

`DCS-VV-003` — Negative tests shall cover malformed and oversized input, unknown fields, invalid units, incompatible versions, unauthorized operations, expired sessions, storage failure, short SPI transfer, response corruption, timeout, interrupt storms, reset, identity change, client disconnect, and process restart.

`DCS-VV-004` — State-changing tests shall cover definitive success, definitive rejection, partial completion, no-effect proof, ambiguity, indeterminate outcome, reconciliation success, reconciliation failure, and postcondition mismatch.

`DCS-VV-005` — FPGA target tests shall exercise the applicable `VP-FPGA-001` through `VP-FPGA-007` and `VP-HIL-001` through `VP-HIL-008` host-client obligations without redefining their required outcomes.

`DCS-VV-006` — Target testing shall demonstrate continuous chip select, actual-length reporting, full required SPI range used by the cases, host-interrupt service when connected, deadline behavior, cache/DMA correctness where applicable, and concurrent interrupt/transaction behavior.

`DCS-VV-007` — Long-duration testing shall exercise maximum legal Console workload, bounded resource behavior, storage rotation, evidence integrity, reconnect, reset, counter saturation, event overwrite, and absence of unexplained loss.

`DCS-VV-008` — Security verification shall include privilege boundaries, package and import integrity, request bounds, secret redaction, local-interface isolation, and absence of validation-only capabilities from production-safe packages.

`DCS-VV-009` — Verification evidence shall conform to `RCA-DFC-SW-005` and shall identify exact software, data, platform, UUT, fixture, expected oracle, and controlling-source revisions.

`DCS-VV-010` — No known failure, unexplained intermittent result, required manual-only judgment, unverified migration, or unbounded resource shall remain at release.

# 39. Traceability and Change Control

## 39.1 Trace Model

Dragon Console traceability shall link:

- controlling and governing source identifiers;
- this specification's `DCS-` requirements;
- architecture components and interfaces;
- source modules and generated artifacts;
- unit, component, integration, target, FPGA, HIL, and system tests;
- build and package artifacts;
- defects, reviews, deviations, and approvals; and
- released evidence.

## 39.2 Traceability Requirements

`DCS-TRACE-001` — Traceability shall be bidirectional from each `DCS-` requirement to implementation and verification evidence and back from each released component and test to its governing requirement.

`DCS-TRACE-002` — Consumed controlling identifiers shall be preserved exactly and shall not be renumbered under this specification.

`DCS-TRACE-003` — A change to the Charter, PBIO, SRS, Architecture, Register Map, Verification Plan, RTM, RTL standard, or governing software baseline shall trigger documented Console impact analysis.

`DCS-TRACE-004` — A change to generated bindings, SDK behavior, persistent schema, target profile, UUT profile, fixture profile, security policy, or command workflow shall trigger affected regression selection and compatibility review.

`DCS-TRACE-005` — A required change to a controlling specification shall be recorded against the owning document and shall block dependent implementation or pass status until resolved.

# 40. Build, Package, Deployment, and Release

## 40.1 Required Packages

The build and release process shall produce at least:

- VisionFive 2 observation/maintenance package;
- VisionFive 2 FPGA-validation package;
- optional production-safe portable package when authorized;
- versioned schemas and default policies;
- controlled campaigns and procedures;
- user, administrator, deployment, recovery, and evidence-export documentation;
- manifest, checksums, signatures where required, dependency inventory, and software bill of materials; and
- software V&V evidence and release approval records.

## 40.2 Release Requirements

`DCS-REL-001` — Builds, analysis, tests, package assembly, manifest generation, and integrity metadata shall follow `RCA-DFC-SW-006`.

`DCS-REL-002` — The FPGA-validation package shall identify the Console, SDK, generated bindings, VisionFive 2 profile, UUT profile, FPGA hardware image reference, wrapper, fixture, and applicable Verification Plan cases without merging hardware and software identities.

`DCS-REL-003` — The FPGA hardware image shall remain a separately owned artifact even when distributed beside the Console package.

`DCS-REL-004` — Installation shall be transactional or recoverable and shall preserve the prior approved package and user evidence for rollback.

`DCS-REL-005` — Rollback shall not migrate newer persistent data destructively without an approved, tested reverse-migration or export plan.

`DCS-REL-006` — Release notes shall identify supported hardware and software combinations, required wiring and fixtures by controlled reference, known limitations, security disposition, migration, rollback, and evidence compatibility.

`DCS-REL-007` — Production-safe and FPGA-validation artifacts shall have distinguishable names, manifests, installed paths, capabilities, and approval records.

# 41. Deliverables

## 41.1 Required Deliverables

The Dragon Console Revision A baseline shall deliver:

1. approved source code for all configuration items in Section 5;
2. VisionFive 2 target executable and controlled installation package;
3. FPGA-validation executable and ULX3S/ECP5-85F UUT profile;
4. compatible Dragon SDK, VisionFive 2 BSP, and generated-binding dependencies or exact approved references;
5. desired-configuration, automation, campaign, procedure, evidence, and export schemas;
6. approved FPGA and host-conformance campaigns and procedures;
7. sample configurations that contain no alternate device definitions;
8. local user, command, deployment, administration, recovery, and validation documentation;
9. unit, component, integration, VisionFive 2 target, FPGA, HIL, regression, security, and acceptance tests;
10. traceability records;
11. build and release manifests, integrity metadata, dependency inventory, and software bill of materials;
12. software V&V report and unresolved-defect statement;
13. evidence schema and export tools; and
14. release approval and archival package.

## 41.2 Delivery Requirements

`DCS-DEL-001` — Every deliverable shall carry configuration identity, revision, integrity value, governing baseline, compatibility scope, and approval status.

`DCS-DEL-002` — Documentation shall distinguish the public Dragon Core contract, Console-owned behavior, FPGA integration inputs, fixture responsibilities, and validation-only capabilities.

`DCS-DEL-003` — No delivered example, procedure, or default shall issue an unrestricted raw write, broad evidence clear, blind retry, automatic operational enable, or undocumented FPGA-private access.

# 42. Exit Criteria

Dragon Console Revision A is complete only when all of the following are true:

1. Every `DCS-` requirement is implemented or formally declared not applicable with approved rationale.
2. Bidirectional traceability is complete and contains no orphan requirement, implementation component, test, or release artifact.
3. The Console builds reproducibly for the approved VisionFive 2 target profile.
4. Static analysis, compiler warnings, coding-standard checks, dependency checks, and security checks pass under the approved policy.
5. Unit, component, integration, target, FPGA, HIL, regression, recovery, persistence, migration, security, and acceptance tests pass as applicable.
6. The VisionFive 2 communicates with the identified ULX3S/ECP5-85F UUT through the conforming SPI path and verifies the host-interrupt path for every case that requires it.
7. Identity discovery, compatibility, configuration, active readback, interrupt/event service, diagnostics, protected access, reconciliation, reset recovery, persistence, and evidence export pass end to end.
8. Validation-only behavior is isolated from production-safe artifacts and is not a portable functional dependency.
9. Every finite resource and failure mode has verified bounded behavior and observable disposition.
10. Required evidence identifies the exact Console, SDK, bindings, VisionFive 2 profile, UUT, image, wrapper, constraints, fixture, procedure, and controlling baseline.
11. No unresolved critical or high-severity defect, unexplained platform divergence, ambiguous required behavior, failed controlling case, or unapproved deviation remains.
12. User, administrator, deployment, recovery, validation, and release documentation is complete and reviewed.
13. Release packages, manifests, integrity metadata, rollback materials, archives, and approvals are complete.
14. Any future finding that requires a controlling-specification change is resolved in the owning document before dependent release approval.

# 43. Baseline Statement

## 43.1 Baseline Declaration

This document establishes `RCA-DFC-SW-007`, Revision A, as the Dragon Console software specification for Dragon Core Revision A.

## 43.2 Governing Relationship

This specification is subordinate to the eight controlling Dragon Flight technical specifications and to the governing software specifications identified in Section 3. It defines only Dragon Console software subjects allocated to it and does not become an alternate owner of any controlling technical fact.

## 43.3 Fixed Baseline Conclusions

The Revision A baseline fixes the following conclusions:

- Dragon Console is external-host software and never executes inside Dragon Core.
- The required embedded target is the VisionFive 2 single-board computer.
- The Revision A FPGA-validation UUT profile is an ULX3S board populated with an ECP5-85F FPGA.
- The Console-to-UUT command and data path is the conforming Dragon Core SPI host transport.
- Full interrupt validation additionally requires the separately connected Dragon Core host-interrupt signal.
- The Console uses the common Dragon SDK, generated bindings, typed APIs, lifecycle, result, reconciliation, and recovery contracts intended for production external hosts.
- FPGA integration, board, fixture, image, wrapper, constraint, and wiring identities remain separate from Dragon Core logical behavior and Console software identity.
- A Console success requires a definitive device result and every applicable postcondition, including active readback.
- Ambiguous state-changing outcomes block later dependent commands until reconciled or placed behind an approved recovery boundary.
- Engineering and validation features are explicitly isolated and absent from production-safe packages.
- Device evidence, Console evidence, fixture evidence, and derived conclusions remain distinguishable and traceable.

## 43.4 Controlling-Specification Disposition

No required change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` was identified while establishing this baseline.

The ULX3S/ECP5-85F UUT choice is a Console validation-profile definition within the existing ECP5 platform class. It requires controlled FPGA integration and fixture artifacts but does not require a change to a controlling specification unless the program later elects to make the exact board, FPGA density, wrapper, pin mapping, or physical integration a top-level Dragon Core product requirement.

## 43.5 Change Control

Any future change affecting device behavior, register meaning, logical interface behavior, controlling verification outcomes, controlling trace relationships, RTL rules, product boundaries, or selected top-level platforms shall be made first in the applicable controlling owner. Any change confined to Console workflow, presentation, software policy, schema, persistence, platform adapter, UUT profile, automation, evidence, or application verification shall be controlled under this specification and the governing software baseline.

## 43.6 Approval Statement

Approval of this document authorizes implementation and verification of Dragon Console Revision A within the boundaries and dependencies stated herein. It does not authorize fabrication, aircraft installation, operational use, or a change to the controlling Dragon Core technical baseline.
