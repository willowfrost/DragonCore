**DRAGON CORE™ SOFTWARE ARCHITECTURE SPECIFICATION**

Document Number: RCA-DFC-SW-001
Revision: C
Status: Technical Baseline
Product: Dragon Core™ Revision A
Program: Dragon Flight™ Core ASIC Development Program
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date       | Description                                                                 | Author                |
|----------|------------|-----------------------------------------------------------------------------|-----------------------|
| A        | 2026-07-03 | Initial historical software-architecture skeleton                           | Royal Cubit Aerospace |
| B        | Undated    | Historical interim revision supplied as reference only                      | Royal Cubit Aerospace |
| C        | 2026-08-07 | Rebuilt beneath the eight controlling specifications for the external-host software architecture | Royal Cubit Aerospace |

# Approval

| Prepared By   |     |
|---------------|-----|
| Reviewed By   |     |
| Approved By   |     |
| Approval Date |     |

# Table of Contents

1. Purpose
2. Scope
3. Applicable Documents
4. Definitions, Acronyms, and Abbreviations
5. Referenced Standards
6. Software Architectural Context
7. Software Design Philosophy
8. Software Design Principles
9. Software Domains
10. Software Layer Architecture
11. Software Component Overview
12. Hardware/Software Interface Architecture
13. System Initialization and Host Startup Architecture
14. Memory Architecture
15. Hardware Abstraction Layer (HAL)
16. Driver Architecture
17. Middleware Architecture
18. External Embedded Host Firmware Architecture
19. Host Software Architecture
20. Dragon SDK Architecture
21. Dragon Console Architecture
22. Dragon Gateway Architecture
23. Dragon Sentinel Architecture
24. FPGA Development Software Architecture
25. Software Verification Framework
26. Interrupt Architecture
27. Event Processing Architecture
28. Configuration Management Architecture
29. Logging and Diagnostics Architecture
30. Error Handling and Fault Recovery
31. Security Architecture
32. Performance Requirements
33. Resource Management
34. Portability Requirements
35. Software Development Environment
36. Build and Release Architecture
37. API Versioning and Compatibility
38. Software Traceability
39. Software Verification Strategy
40. Software Maintenance Strategy
41. Future Expansion Architecture
42. Deliverables
43. Exit Criteria
44. Baseline Statement


1. Purpose
==========

This Software Architecture Specification defines the architecture of executable software that controls, observes, validates, and supports Dragon Core Revision A from outside the fabricated device. It is a subordinate software specification beneath the eight-document technical specification set identified by `RCA-DFC-CHTR-002`, Section 3.1.

This specification owns software-only organization: software layers, component responsibilities, process boundaries, external-host initialization and recovery sequences, API behavior, concurrency policy, external persistence, logging, software verification, packaging, compatibility, and maintenance. It does not own or redefine product scope, responsibility boundaries, device behavior, internal hardware architecture, register meaning, verification-plan cases, trace relationships among controlling identifiers, or RTL implementation rules.

The architecture provides one coherent framework for:

- generated external-host definitions;
- platform SPI and interrupt adaptation;
- a transport-independent Dragon Core driver;
- typed device services and the Dragon SDK;
- configuration, interrupt, event, diagnostic, persistence, and recovery services;
- Dragon Console™, Dragon Gateway™, and Dragon Sentinel™;
- external embedded-host firmware;
- FPGA and hardware-in-the-loop support software; and
- software unit, integration, conformance, and system verification.

All executable software remains external to Dragon Core in accordance with `CHTR-TECH-001` through `CHTR-TECH-005`, `CHTR-EXCL-002`, and `PBIO-HOST-003` through `PBIO-HOST-009`.

# 2. Scope

## 2.1 Included Scope

This specification applies to Royal Cubit Aerospace software and generated host artifacts that use the Dragon Core SPI and host-visible register contract. It covers bare-metal, real-time operating system, and hosted operating-system deployments on external processors, including the VisionFive 2 validation host identified by `CHTR-TECH-006` through `CHTR-TECH-008`.

Included architectural subjects are:

- external-host startup, discovery, configuration, enablement, service, shutdown, reconnect, and reset recovery;
- generated register bindings and typed access helpers;
- SPI command execution, response validation, ambiguous-outcome reconciliation, and interrupt reception;
- coherent access to staged, active, current, sticky, pending, snapshot, queue, mailbox, event, and counter data;
- external configuration persistence and long-term evidence retention;
- software component, process, thread, synchronization, resource, error, and security boundaries;
- SDK and application APIs;
- FPGA validation and host-conformance clients; and
- software build, verification, release, traceability, and maintenance.

## 2.2 Excluded Scope

The following are excluded:

- any processor, firmware, bootloader, runtime, HAL, driver, middleware, application, or executable memory inside Dragon Core;
- RTL behavior, device algorithms, register definitions, SPI wire-protocol definitions, or verification-case definitions already owned by the controlling specifications;
- aircraft flight control, navigation, guidance, mission management, or direct aircraft-energy control;
- external analog conditioning, transceivers, power drive, wiring, calibration, and installation-specific electrical design;
- selection of an application operating system, programming language, database engine, network protocol, or user-interface toolkit; and
- aircraft certification, installation approval, operational authorization, and aircraft-level safety assessment.

## 2.3 Software Product Boundary

`SW-SCOPE-001` — Software shall interact with Dragon Core only through the SRS-defined external host interface and the Register-Map-defined host-visible contract, as required by `PBIO-HOST-006`.

`SW-SCOPE-002` — Software shall not depend on scan, production-test internals, platform-private paths, RTL hierarchy, shared-buffer physical addresses, undocumented timing, or hidden device state.

`SW-SCOPE-003` — Software shall not assume responsibility for a hardware safety function allocated to Dragon Core by `PBIO-SAFE-001` through `PBIO-SAFE-004`.

`SW-SCOPE-004` — Software shall own configuration policy, persistence, long-term records, interpretation, and recovery actions only on the external side of the ownership boundary defined by `RCA-DFC-PBIO-002`.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and sole normative ownership of the following documents are controlled only by `RCA-DFC-CHTR-002`, Section 3.1. This list is an informative software-use view and creates no alternate precedence.

| Document | Software use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product scope, fixed constraints, platform selections, external-host model, and document-ownership rules |
| `RCA-DFC-PBIO-002.md` | Device, software, platform, board, test, data, safety, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior and host-interface obligations |
| `RCA-DFC-ARCH-002.md` | Device-side internal contracts needed to interpret coherent access, recovery, events, queues, and diagnostics |
| `RCA-DFC-REG-002.md` | Sole source for registers, fields, access, reset, legality, protection, read/write behavior, and side effects |
| `RCA-DFC-VP-002.md` | Device and host-boundary verification methods, cases, coverage, outcomes, and evidence |
| `RCA-DFC-RTM-002.md` | Relationships among controlling requirement, architecture, register, RTL, and verification identifiers |
| `RCA-DFC-RTL-STD-002.md` | RTL coding and structural rules; not a software source-code standard |

## 3.2 Historical Reference

The supplied historical `RCA-DFC-SW-001` content is informative only. Any historical statement that places executable software, a processor, boot memory, a runtime, firmware, HAL, BSP, middleware, or application inside Dragon Core is superseded and prohibited by the controlling specifications.

## 3.3 Authority and Conflict Resolution

`SW-DOC-001` — This specification shall apply `CHTR-DOC-001` through `CHTR-DOC-007`.

`SW-DOC-002` — A consumed technical fact shall be referenced by its owning identifier and shall not be repeated as an independent software definition.

`SW-DOC-003` — If software development exposes a conflict, ambiguity, omission, or unimplementable device contract, work depending on that fact shall stop and the owning controlling specification shall be corrected before software invents a substitute.

`SW-DOC-004` — Generated external-host definitions required by `REG-GENART-002` are derived artifacts and shall not become an alternate register specification.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition in this specification |
|---|---|
| Active configuration | The hardware-used value exposed through Register-Map-defined active readback; distinct from a software desired value and a device staged value. |
| Ambiguous outcome | A host command for which software cannot validate a definitive response, including response loss or truncation after possible command acceptance. |
| BSP | Board Support Package executing on an external host processor. |
| Device context | One software object owning transport serialization, generated bindings, cached identity, lifecycle state, and service coordination for one Dragon Core instance. |
| Dragon SDK | The public software package containing generated definitions, transport and driver APIs, typed services, models, and developer utilities. |
| External embedded host | A processor outside the fabricated Dragon Core device that may execute firmware or an operating system and act as the SPI master. |
| HAL | External-host hardware abstraction for SPI, interrupt, monotonic time, synchronization, and optional persistence services. |
| Host reconciliation | Software determination of an ambiguous accepted command's terminal device result using the coherent host-reconciliation record required by the controlling specifications. |
| Observed state | Nondestructively read current state, sticky evidence, counters, queue state, retained records, and active configuration. |
| Desired configuration | The validated external persistent configuration software intends to apply; it is not device-active until confirmed by readback. |
| Service policy | External software rules governing interrupt service, event retrieval, watchdog service, retries, persistence, diagnostics, and recovery. |
| SDK | Software Development Kit. |
| SPI | Serial Peripheral Interface. |
| Sticky evidence | A device-retained historical indication as defined by the SRS, Architecture, and Register Map; distinct from software logs. |

Device-side terms retain the definitions of their controlling owners. A software API name shall not redefine a device-side term.

# 5. Referenced Standards

This architecture does not select a certification basis or programming-language standard. A subordinate software requirements, safety, coding, or assurance plan may select applicable standards without altering the controlling Dragon Core contract.

At minimum, each implementation shall identify and control:

- the selected language and language-version standard;
- compiler, linker, runtime, operating-system, and library versions;
- applicable secure-coding and static-analysis rules;
- serialization and persistent-data format specifications;
- time-source and threading semantics; and
- any assurance, cybersecurity, quality, or certification standards claimed for that software release.

`RCA-DFC-RTL-STD-002` applies to SystemVerilog RTL and generated RTL artifacts. It shall not be cited as the software coding standard for external executable software.

# 6. Software Architectural Context

## 6.1 Architectural Position

The software system is an external consumer of one mapped peripheral. Dragon Core independently reaches host-ready operation, enforces its own register contract, and performs configured autonomous hardware supervision without executing software, as controlled by `CHTR-TECH-009` through `CHTR-TECH-012`.

## 6.2 Context Boundaries

| Boundary | Software responsibility | Responsibility retained elsewhere |
|---|---|---|
| Host SPI master to Dragon Core SPI target | Compliant master transactions, response validation, host timeout, serialization, and recovery | Dragon Core target behavior and on-device evidence under `PBIO-HOST-001` and `PBIO-HOST-005` |
| Host interrupt input | Reception, scheduling, service, and external missed-service evidence | Device interrupt aggregation and on-device pending state |
| Persistent configuration | Schema, validation, storage, versioning, approval, and reapplication | Volatile device acceptance, enforcement, and active readback |
| Event and diagnostic retention | Retrieval, durable storage, indexing, interpretation, and disposition | On-device capture, finite retention, ordering, and loss evidence |
| External digital interfaces | Software configuration and interpretation where authorized | Electrical adaptation, board behavior, and device digital protocol ownership allocated by PBIO |
| Safety | Installation policy, operator authorization, and external records | Dragon Core hardware supervision and external physical energy control |

## 6.3 Software Architecture Stack

The software stack consists of applications, domain services, typed device services, a register driver, a command transport, and platform adapters. Dependencies point toward lower layers; hardware-specific and operating-system-specific code is confined to adapters.

## 6.4 Governing Constraints

`SW-CTX-001` — One device context shall have one command-serialization authority.

`SW-CTX-002` — Applications shall use typed services or SDK APIs and shall not embed register offsets, masks, status values, protection constants, or protocol encodings.

`SW-CTX-003` — Generated host definitions shall derive from the Register-Map machine-readable source required by `REG-GENART-004`.

`SW-CTX-004` — Device observation shall remain nondestructive unless the caller explicitly requests a Register-Map-defined command or side effect.

## 6.5 Controlling-Specification Change Flags

| Flag | Controlling owner | Finding | Required action |
|---|---|---|---|
| None | — | The eight controlling specifications provide a consistent external-host boundary, complete host-visible programming contract, active readback, diagnostic retention, command reconciliation, reset recovery, and host-verification basis sufficient for this software architecture. | No controlling-specification change is required by Revision C. |

# 7. Software Design Philosophy

## 7.1 Fundamental Philosophy

Hardware owns deterministic device behavior and safety supervision; software owns external policy, orchestration, persistence, presentation, and recovery. Neither side shall silently compensate for a defect owned by the other.

## 7.2 Architectural Principles

`SW-PHIL-001` — Observe before modify.

`SW-PHIL-002` — Confirm active state rather than assuming command success.

`SW-PHIL-003` — Preserve raw evidence before acknowledgement, clear, pop, or reset.

`SW-PHIL-004` — Treat every state-changing operation as unsuccessful until a definitive response or successful reconciliation establishes its outcome.

`SW-PHIL-005` — Keep policy above mechanism: transport code shall not choose aircraft or maintenance policy.

`SW-PHIL-006` — Fail closed for compatibility, authorization, configuration validity, and uncertain safety-related actions.

## 7.3 Lifecycle Philosophy

Generated definitions, implementation, tests, evidence, and release manifests shall be produced from controlled inputs. A software release shall identify the exact controlling-specification and generator revisions against which it was built and verified.

# 8. Software Design Principles

## 8.1 Core Rules

`SW-DES-001` — Public APIs shall use fixed-width types and explicit units.

`SW-DES-002` — APIs shall distinguish current state, sticky evidence, counters, terminal records, staged configuration, active configuration, requested state, commanded state, and effective state.

`SW-DES-003` — APIs shall return structured results; a Boolean success value alone is insufficient for a host transaction.

`SW-DES-004` — No read API shall hide a pop, acknowledge, clear, commit, service, or reset side effect.

`SW-DES-005` — No write helper shall silently change reserved bits, coerce an illegal value, or retry an ambiguous state-changing command.

`SW-DES-006` — Selector, staging, snapshot, pop, protected-write, and reconciliation operations shall be represented as bounded transactions guarded by the device-context serializer.

`SW-DES-007` — Logging shall retain raw device values and separately identify derived interpretation.

`SW-DES-008` — All externally supplied configuration shall be schema-validated before any device write.

## 8.2 Defensive Boundaries

Unrecognized product revision, register-map revision, capability combination, status encoding, event identifier, source identifier, or reserved output shall be surfaced as an explicit compatibility or protocol error. It shall not be interpreted by analogy to a known value.

# 9. Software Domains

## 9.1 Domain Allocation

| Domain | Responsibilities |
|---|---|
| Platform | SPI controller, interrupt input, clocks, timers, synchronization, optional storage, and operating-system adaptation |
| Transport | SPI frame construction, transfer, CRC/response validation, completed-count capture, timeout, and raw transaction evidence |
| Device access | Generated registers and fields, access-class enforcement, typed reads/writes, protection, staging, snapshot, and queue commands |
| Lifecycle | Discovery, compatibility, initialization, configuration, enablement, reconnect, reset recovery, and shutdown |
| Services | Interrupt, event, timestamp, diagnostics, watchdog scheduling, monitoring, databus, routing, and safety-configuration support |
| Persistence | Desired configuration, retrieved events, diagnostics, audit records, maintenance history, and release identity |
| Applications | Console, Gateway, Sentinel, engineering utilities, and installation-specific clients |
| Verification | Mocks, emulators, conformance clients, HIL control, evidence capture, and regression orchestration |

## 9.2 Domain Interaction Rules

`SW-DOM-001` — Applications shall not call platform SPI primitives directly.

`SW-DOM-002` — Persistence shall store device-originated evidence without changing its meaning or replacing device evidence that has not been serviced.

`SW-DOM-003` — Installation-specific policy shall enter through explicit application or configuration interfaces and shall not be embedded in generated bindings or the transport.

`SW-DOM-004` — Verification utilities may inject faults or use production-test operations only through documented, authorized paths and shall remain isolated from production builds.

# 10. Software Layer Architecture

## 10.1 Layer Model

| Layer | Principal content | Permitted downward dependency |
|---:|---|---|
| 6 | Dragon Console, Dragon Gateway, Dragon Sentinel, installation applications | Domain services and public SDK |
| 5 | Lifecycle, configuration, event, interrupt, diagnostic, persistence, and recovery services | Typed device services |
| 4 | Dragon SDK public facade and typed device service APIs | Register driver and models |
| 3 | Generated register model, access helpers, transaction coordinator | Transport interface |
| 2 | Dragon Core SPI transport and interrupt adapter | Platform HAL |
| 1 | External-host HAL/BSP/OS adapters | Host hardware and operating system |
| 0 | Dragon Core external boundary | SRS and Register Map contract only |

## 10.2 Dependency Rules

`SW-LAYER-001` — A lower layer shall not import an application or policy layer.

`SW-LAYER-002` — Cross-layer callbacks shall carry typed immutable observations or explicit commands and shall not expose mutable lower-layer state.

`SW-LAYER-003` — A platform adapter shall be replaceable without changing generated register definitions, device-service semantics, or application behavior.

`SW-LAYER-004` — Test doubles shall implement the same interfaces as production layers and shall not add capabilities unavailable at the documented device boundary.

# 11. Software Component Overview

## 11.1 Required Components

| Component | Responsibility |
|---|---|
| Register artifact generator | Produce host constants, typed fields, legality metadata, helpers, and manifests from the controlled machine-readable register source |
| Platform HAL | Supply SPI, interrupt, monotonic time, lock, memory, and optional persistence primitives |
| SPI transport | Execute one complete external-host command and return a fully classified transport result |
| Device driver | Provide typed register, protected, snapshot/pop, staged/commit, queue, and reconciliation operations |
| Device lifecycle manager | Own discovery, compatibility, initialization, state transitions, reconnect, reset recovery, and shutdown |
| Domain services | Own software coordination for each device capability without redefining hardware behavior |
| Persistence service | Store desired configuration, retrieved evidence, audit records, and compatibility metadata externally |
| Dragon SDK | Publish stable APIs, models, documentation, and examples |
| Applications | Provide operator, gateway, supervisory, and validation workflows |
| Verification support | Provide independent models, mocks, host conformance, HIL automation, and evidence collection |

## 11.2 Optional Composition

Small embedded hosts may link the required components into one image. Hosted systems may place applications, persistence, and gateway services in separate processes. Process placement shall not change ownership, serialization, or recovery rules.

# 12. Hardware/Software Interface Architecture

## 12.1 Sole Production Interface

Production software shall use the SRS-defined SPI host transport and the Register-Map-defined logical register contract. The transport shall preserve the complete command and response behavior owned by `DFC-INTF-0011` through `DFC-INTF-0036` without independently redefining its encoding.

## 12.2 Transport Result

Every transport operation shall return a result containing, as applicable:

- transport completion and response-integrity state;
- definitive device status when validated;
- completed-word count;
- returned read words;
- local host timeout or platform error;
- whether the outcome is definitive or ambiguous;
- a transaction capture reference suitable for diagnostics; and
- any completed reconciliation result.

## 12.3 Transaction Coordination

`SW-HSI-001` — Only the device-context command serializer may initiate SPI commands for that device.

`SW-HSI-002` — Multiword operations shall preserve ordered, non-atomic behavior and shall not be presented as atomic unless they use a Register-Map-defined staging/commit object.

`SW-HSI-003` — A protected sequence shall hold exclusive command ownership from the first key operation through the protected target operation and its definitive completion or reconciliation.

`SW-HSI-004` — A selector-based, snapshot/pop, staged/commit, or host-reconciliation sequence shall hold the lock for every command whose interleaving could change its meaning.

`SW-HSI-005` — Applications shall not infer device state from a host interrupt line, requested value, cached value, or command transmission alone; they shall use defined readback.

## 12.4 Ambiguous Outcome Reconciliation

When a state-changing command has an ambiguous outcome, software shall:

1. stop issuing later dependent state-changing commands;
2. preserve the raw host-side transaction evidence;
3. perform the coherent host-reconciliation read defined by the Register Map;
4. compare the returned command identity and terminal members with the ambiguous operation;
5. classify the operation as completed, partially completed, failed before the affected word, not represented, or still indeterminate;
6. inspect active configuration or target state when needed; and
7. retry only when the combined reconciliation and readback prove that the retry cannot duplicate an already effective action.

A blind retry of a reset, pop, clear, push, service, commit, acknowledgement, or other state-changing command is prohibited.

# 13. System Initialization and Host Startup Architecture

## 13.1 Separation of Device Startup and Host Startup

Dragon Core startup is deterministic hardware behavior owned by the SRS and Architecture. This section defines only external-host software startup. Software shall not claim to boot Dragon Core or supply device initialization code.

## 13.2 Host Startup Phases

| Phase | Software action and exit condition |
|---:|---|
| 1. Platform readiness | Initialize host SPI, interrupt input, monotonic timer, synchronization, logging, and persistence; no device writes |
| 2. Host-ready discovery | Poll using bounded backoff until the device reports host-ready or the external startup deadline expires |
| 3. Identity and compatibility | Read product, product revision, register-map revision, build identity, and capabilities; select an exact compatible generated binding |
| 4. Nondestructive observation | Read operating state, qualifiers, active configuration, sticky evidence, counters, queue state, and prior retained records required by policy before any clear |
| 5. Desired-state validation | Validate the external configuration schema, target identity, capabilities, ranges, dependencies, protection needs, and installation authorization |
| 6. Safe configuration | Keep effective operation inhibited; apply configuration in dependency order using required protected and staged commits; confirm active readback |
| 7. Service activation | Start interrupt, event, diagnostic, persistence, and watchdog-service scheduling required by the selected configuration |
| 8. Operational enablement | Request permitted operational enable only after all prerequisite readbacks pass; confirm effective operational enable independently |
| 9. Steady operation | Publish the initialized device only after state, configuration, services, and compatibility are coherent |

## 13.3 Initialization Failure

`SW-INIT-001` — A compatibility, configuration, protection, commit, active-readback, service-start, or effective-enable failure shall prevent publication of the device as operational.

`SW-INIT-002` — Failure handling shall preserve observational access and evidence retrieval where the device contract permits it.

`SW-INIT-003` — Software shall not clear evidence merely to obtain a nominal status.

`SW-INIT-004` — Safety-related configuration shall be applied and verified while hardware outputs remain inhibited; software shall not test a safety output through a production pad.

# 14. Memory Architecture

## 14.1 External Memory Only

All executable code, stacks, heaps, queues, databases, configuration stores, and long-term logs defined here reside outside Dragon Core. Device internal storage is accessed only through Register-Map-defined abstractions; software shall not model physical shared-buffer addresses as host-visible memory.

## 14.2 Software Memory Classes

| Class | Required behavior |
|---|---|
| Generated immutable data | Read-only constants, field metadata, schemas, and compatibility tables tied to a manifest |
| Device context | One bounded allocation per device; explicit lifetime and synchronization ownership |
| Transaction workspace | Fixed or bounded buffers sized for documented host commands and responses |
| Observation snapshots | Immutable typed copies with host receipt time and source identity |
| Configuration image | Desired values plus schema, compatibility, provenance, approval, and digest metadata |
| Persistent evidence | Append-oriented records with integrity checks and retention policy |

## 14.3 Memory Rules

`SW-MEM-001` — Buffer sizes and arithmetic shall be checked before use; external lengths shall not select unchecked allocation or indexing.

`SW-MEM-002` — Embedded profiles shall support statically allocated or caller-supplied storage for steady-state operation.

`SW-MEM-003` — Secret-bearing external application data, if any, shall not be written into Dragon Core registers or logs unless the controlling register contract explicitly requires that value.

`SW-MEM-004` — Persistent records shall distinguish retrieval time from device raw timestamp and shall retain the raw record unchanged.

# 15. Hardware Abstraction Layer (HAL)

## 15.1 HAL Boundary

The HAL is external-host software. It abstracts host hardware and operating-system services; it does not abstract or redefine Dragon Core registers.

## 15.2 Required HAL Services

- full-duplex SPI transfer with explicit chip-select control as required by the selected host;
- interrupt registration, masking, acknowledgement at the host controller, and deferred-work signaling;
- monotonic time and bounded delay services;
- mutual exclusion and optional condition/event primitives;
- memory barriers or device-I/O ordering required by the host platform;
- structured platform error reporting; and
- optional persistent-storage, logging, and secure host-credential services.

## 15.3 HAL Rules

`SW-HAL-001` — HAL SPI behavior shall be validated against the host-side obligations consumed from the SRS.

`SW-HAL-002` — The HAL shall report actual transferred length and platform errors; short transfers shall never be promoted to valid device responses.

`SW-HAL-003` — Interrupt callbacks shall perform bounded host-controller work and schedule device service outside hard-interrupt context unless a selected platform proves that direct service is safe and bounded.

`SW-HAL-004` — Monotonic scheduling shall not depend on wall-clock adjustments.

# 16. Driver Architecture

## 16.1 Driver Responsibilities

The driver owns command serialization, typed access, host-side access checks, response parsing, protected sequences, coherent helper transactions, reconciliation, and device-context lifecycle. Device hardware remains the final enforcer of legality.

## 16.2 Driver API Families

| API family | Purpose |
|---|---|
| Discovery | Identity, revision, capability, and compatibility reads |
| Scalar access | Typed read and legal write of one register-owned object |
| Protected access | Exclusive authorization and protected target operation |
| Staged object | Select, stage, validate/commit, result, and active readback |
| Snapshot/pop | Capture, inspect, optionally pop, and validate source state |
| Queue/mailbox | Push or retrieve complete entries with full/empty/error handling |
| Counter/evidence | Exact W1C and whole-counter clear helpers with independent reads |
| Reconciliation | Coherent terminal-record read and ambiguous-operation classification |
| Reset | Protected reset request, terminal result, re-discovery, and recovery handoff |

## 16.3 Driver Rules

`SW-DRV-001` — Raw register access, if provided for engineering builds, shall be explicitly unsafe, disabled in production profiles by default, and still use generated definitions and the command serializer.

`SW-DRV-002` — The driver shall reject writes with nonzero reserved bits or invalid host-known encodings before transport, while preserving device rejection as the authoritative result.

`SW-DRV-003` — The driver shall not cache volatile active configuration as authoritative across reset, reconnect, or ambiguous command completion.

`SW-DRV-004` — Counter-clear helpers shall expose whole-counter and bitwise-W1C operations as different types.

`SW-DRV-005` — The driver shall preserve partial completion of a multiword command in its result.

# 17. Middleware Architecture

## 17.1 Middleware Services

Middleware coordinates device use without embedding installation policy in low-level mechanisms. Services include lifecycle, configuration, interrupt, event, timestamp, monitoring, databus, diagnostics, persistence, and recovery.

## 17.2 Service Interaction

All services share one device context and submit commands through one serialized coordinator. Long-running workflows are state machines that release the serializer only at boundaries where interleaving cannot invalidate a protected, selector, snapshot, staged, or reconciliation transaction.

## 17.3 Middleware Rules

`SW-MW-001` — Services shall publish immutable observations with explicit device identity, host receipt time, and freshness state.

`SW-MW-002` — Services shall never treat a software log as proof that corresponding on-device evidence was cleared or serviced.

`SW-MW-003` — Cross-service dependencies shall be explicit; configuration activation shall notify affected services only after active readback succeeds.

`SW-MW-004` — Backpressure in an application consumer shall not block time-critical interrupt, watchdog, or evidence-retrieval work; bounded queues and loss reporting are required.

# 18. External Embedded Host Firmware Architecture

## 18.1 Boundary Correction

This section applies only to firmware executing on an external processor. Dragon Core contains no embedded firmware, BSP, bootloader, runtime, or instruction-executing processor.

## 18.2 Embedded Profile

An external embedded profile may combine HAL, driver, selected services, and an application in one image. It shall retain the same generated definitions, transaction result model, serializer, initialization phases, reconciliation rules, and active-readback checks as hosted profiles.

## 18.3 Embedded Rules

`SW-FW-001` — Startup order shall not assume Dragon Core requires host firmware to leave RESET_ACTIVE or reach HOST_READY.

`SW-FW-002` — Watchdog service scheduling shall use a monotonic, analyzed execution budget and shall not be enabled when the host cannot satisfy the selected service policy.

`SW-FW-003` — Interrupt and polling paths shall be bounded and priority analyzed for the selected real-time environment.

`SW-FW-004` — Loss of host firmware shall not be described as loss of Dragon Core hardware supervision; externally observable lost-link or watchdog behavior remains controlled by the device configuration.

# 19. Host Software Architecture

## 19.1 Hosted Process Model

A hosted deployment should use one privileged device-service process per physical device or one process managing multiple isolated device contexts. User interfaces, network gateways, and analytics should communicate with that service through authenticated local interfaces rather than obtaining direct SPI access.

## 19.2 Process Responsibilities

| Process role | Responsibility |
|---|---|
| Device service | Exclusive physical access, lifecycle, configuration, service scheduling, diagnostics, and recovery |
| Console client | Human interaction, requested operations, status display, and audit annotation |
| Gateway client/service | Authorized external integration and protocol translation |
| Sentinel service | Continuous observation, watchdog scheduling where configured, evidence retrieval, and alert publication |
| Persistence service | Durable configuration, event, diagnostic, and audit storage |

## 19.3 Host Rules

`SW-HOST-001` — Operating-system device permissions shall prevent multiple independent masters from bypassing the device serializer.

`SW-HOST-002` — Process restart shall execute reconnect recovery, not assume the device reset or retained the process's cached state.

`SW-HOST-003` — Network-facing components shall not expose raw register writes as a general remote API.

# 20. Dragon SDK Architecture

## 20.1 SDK Contents

The Dragon SDK shall contain:

- generated register and status definitions;
- the HAL service interfaces;
- SPI transport and device driver;
- typed device and domain models;
- lifecycle, configuration, interrupt, event, diagnostic, and recovery services suitable for reuse;
- test doubles and independent protocol fixtures where appropriate;
- API documentation and safe examples; and
- a manifest binding the SDK to controlling sources and generated artifacts.

## 20.2 Public API Rules

`SW-SDK-001` — Public APIs shall not expose implementation-specific RTL module ports or centralized shared-buffer addresses.

`SW-SDK-002` — A returned observation shall identify whether it is current, sticky, snapshot, terminal, cached, derived, or stale.

`SW-SDK-003` — State-changing APIs shall document authorization, atomicity, side effects, ambiguity handling, and recovery behavior.

`SW-SDK-004` — Compatibility checks shall occur before public state-changing services become available.

`SW-SDK-005` — Examples shall use active readback and evidence-preserving error handling; examples shall not demonstrate blind retries or broad diagnostic clears.

# 21. Dragon Console Architecture

## 21.1 Purpose

Dragon Console is an engineering and maintenance user interface over the Dragon SDK. It is not an aircraft flight-control interface and does not own hardware safety behavior.

## 21.2 Capabilities

- device discovery, identity, compatibility, and lifecycle display;
- desired-versus-active configuration comparison;
- guided protected and staged configuration workflows;
- operating-state, current-state, sticky-evidence, counter, queue, interrupt, fault, and safety-inhibit views;
- event retrieval, export, and acknowledgement workflows;
- response-loss reconciliation display;
- authorized reset and diagnostic operations; and
- FPGA/HIL engineering support in explicitly selected nonproduction profiles.

## 21.3 Console Rules

`SW-CONSOLE-001` — The Console shall label requested, staged, active, commanded, effective, current, sticky, pending, and historical data distinctly.

`SW-CONSOLE-002` — Destructive operations shall require explicit selection of the exact effect and shall display the evidence that will be changed.

`SW-CONSOLE-003` — Production-test, fault-injection, raw-access, and engineering features shall be absent or inaccessible in production operator profiles.

`SW-CONSOLE-004` — A displayed success shall require a definitive device result and applicable active readback.

# 22. Dragon Gateway Architecture

## 22.1 Purpose

Dragon Gateway integrates authorized external systems with Dragon Core services. It translates external requests into typed SDK operations and publishes typed observations; it does not mirror the register map as an unrestricted network protocol.

## 22.2 Gateway Rules

`SW-GW-001` — Every external command shall pass authentication, authorization, schema validation, compatibility validation, rate limiting, and audit recording before it can request a device operation.

`SW-GW-002` — Idempotency tokens at the gateway shall not substitute for device host reconciliation.

`SW-GW-003` — Gateway retries shall follow the same definitive-result and ambiguous-outcome rules as local clients.

`SW-GW-004` — Gateway disconnection shall not interrupt local device supervision, evidence retrieval, or configured watchdog scheduling.

`SW-GW-005` — External protocols and schemas shall version independently from the Dragon Core register-map revision while declaring their compatibility relationship.

# 23. Dragon Sentinel Architecture

## 23.1 Purpose

Dragon Sentinel is the continuous external supervision service. It observes device state, coordinates service policy, retrieves evidence, schedules authorized watchdog service when configured, detects host-side anomalies, and publishes alerts. It supplements but does not replace Dragon Core hardware supervision.

## 23.2 Sentinel State

Sentinel shall maintain explicit software states for disconnected, discovering, incompatible, observing, configuring, operational, degraded-observed, faulted-observed, recovering, and service-failed. These are software workflow states and shall not be represented as alternate Dragon Core primary operating states.

## 23.3 Sentinel Rules

`SW-SENT-001` — Sentinel shall base device state on independent readback qualifiers and not infer them solely from the primary-state encoding.

`SW-SENT-002` — Sentinel shall preserve and publish the distinction between active conditions and sticky historical evidence.

`SW-SENT-003` — Watchdog service shall stop or remain disabled when timing guarantees, device compatibility, configuration validity, or command-result certainty are lost, subject to the approved external service policy.

`SW-SENT-004` — Sentinel shall detect and report software-side queue loss, persistence failure, missed deadlines, and unavailable evidence separately from device-reported loss.

`SW-SENT-005` — Sentinel shall never clear a device fault or diagnostic solely to suppress an alert.

# 24. FPGA Development Software Architecture

## 24.1 Purpose

FPGA development software supports the ECP5 realization and VisionFive 2 validation host while preserving the same SRS, Register Map, generated bindings, driver, SDK, initialization, and recovery behavior intended for production hosts.

## 24.2 Components

- FPGA image and build-identity discovery;
- VisionFive 2 HAL/BSP adapter;
- host conformance client;
- digital fixture and protocol-analyzer control;
- HIL scenario orchestration;
- capture, comparison, and evidence packaging; and
- engineering-only test and injection clients separated from production software.

## 24.3 Rules

`SW-FPGA-001` — FPGA-only observability shall not enter the production driver or become a functional dependency.

`SW-FPGA-002` — Host conformance shall use only generated host definitions and documented interfaces in accordance with `VP-GEN-016`.

`SW-FPGA-003` — Results shall identify the FPGA image, host software, generated definitions, configuration, fixture, and controlling-source revisions.

# 25. Software Verification Framework

## 25.1 Framework Layers

| Layer | Verification purpose |
|---|---|
| Unit | Pure encoding, validation, state machine, result classification, model, and persistence behavior |
| Component | HAL contract, transport, driver, generator, service, and application behavior with controlled doubles |
| Integration | Multiple software layers with an independent device model or RTL simulation |
| Host conformance | Exact command traffic and device-boundary results using the `T-HOST` method owned by the Verification Plan |
| FPGA/HIL | Real host, device image, adapters, fixtures, interrupts, resets, response interruption, and persistence |
| System | End-to-end startup, operation, fault, reconnect, reset recovery, and evidence retention |

## 25.2 Independent Oracles

Expected results shall derive from controlling specifications and independent models, not from reusing implementation encoding or copying observed device state. Generated bindings may be verified against the same machine-readable source but shall be compared by an independently implemented checker.

## 25.3 Framework Rules

`SW-VF-001` — Every test shall be self-checking and produce unambiguous pass/fail results.

`SW-VF-002` — Tests shall cover legal, boundary, reserved, malformed, unauthorized, timeout, abort, truncation, partial-completion, full/empty, overflow, reset, reconnect, and simultaneous conditions applicable to software.

`SW-VF-003` — Test evidence shall satisfy the applicable records required by `RCA-DFC-VP-002`, Sections 8 and 28.

# 26. Interrupt Architecture

## 26.1 Service Model

The host interrupt signal is a wakeup indication. Device pending state and source identity are obtained through Register-Map-defined reads. Service is deferred to the serialized device-service context.

## 26.2 Service Sequence

Software shall:

1. record the host interrupt reception time;
2. schedule bounded device service;
3. read the complete pending state and encoded source through typed APIs;
4. service the source-owned resource or condition;
5. apply acknowledgement and clear only as defined for that source;
6. reread pending state until the service policy's bounded drain condition is met; and
7. preserve unrelated interrupt, event, fault, and diagnostic evidence.

## 26.3 Interrupt Rules

`SW-IRQ-001` — Software shall handle multiple simultaneous sources and a newly asserted source during service.

`SW-IRQ-002` — Host-controller acknowledgement shall not be treated as device-source acknowledgement.

`SW-IRQ-003` — A still-active source shall remain reportable after a clear attempt; software shall not spin without bounded backoff and escalation.

`SW-IRQ-004` — Polling fallback may supplement interrupt service but shall preserve the same source-service semantics.

# 27. Event Processing Architecture

## 27.1 Retrieval Model

Event records are finite device evidence. Software shall retrieve them in retained order using explicit snapshot and pop operations, persist the raw record, and only then remove it when policy authorizes removal.

## 27.2 Event Pipeline

| Stage | Responsibility |
|---|---|
| Capture request | Schedule retrieval without blocking higher-priority host service |
| Snapshot | Obtain one coherent oldest record without removal |
| Decode | Validate known identifiers and preserve unknown values as raw incompatibility evidence |
| Persist | Durably record raw fields, device identity, host receipt time, and ingestion sequence |
| Pop | Remove only the record corresponding to the validated snapshot |
| Publish | Distribute immutable typed and raw views to subscribers |

## 27.3 Event Rules

`SW-EVT-001` — Device raw timestamp shall remain the primary record timestamp; correlated or wall-clock time shall be stored as separate derived metadata.

`SW-EVT-002` — Store-overflow or producer-loss evidence shall create an explicit evidence-gap record in external storage and shall not be treated as an ordinary event only.

`SW-EVT-003` — Failure to persist shall stop destructive popping unless an approved degraded retention policy explicitly permits loss and records that decision.

`SW-EVT-004` — A response ambiguity during pop shall be reconciled before another pop.

# 28. Configuration Management Architecture

## 28.1 Configuration Objects

An external desired-configuration object shall include:

- schema version and configuration identity;
- target product, product revision, register-map revision, and required capabilities;
- generated-binding and source-manifest identity;
- typed desired values and feature enables;
- dependency and activation grouping;
- provenance, authorization, approval, and change record as applicable; and
- integrity digest.

## 28.2 Application Rules

`SW-CFG-001` — Configuration shall be validated completely before the first device write.

`SW-CFG-002` — Software shall apply configuration while effective operation is inhibited and in a deterministic dependency order.

`SW-CFG-003` — Each staged object shall be committed explicitly and compared with active readback before dependent configuration proceeds.

`SW-CFG-004` — Rejected configuration shall leave the external desired object unchanged, retain the device result and configuration-error evidence, and not be silently normalized.

`SW-CFG-005` — Reset or power loss shall invalidate cached active configuration; software shall compare complete active readback with the desired object and reapply only through normal validated paths.

`SW-CFG-006` — Configuration migration shall produce a new validated object; runtime best-effort reinterpretation of an older schema is prohibited.

# 29. Logging and Diagnostics Architecture

## 29.1 Diagnostic Record Classes

Software logging shall distinguish:

- raw SPI transaction evidence;
- definitive and reconciled command results;
- device current state;
- device sticky evidence;
- device counters;
- device event records;
- active configuration snapshots;
- software workflow transitions;
- software-side timeouts, queue loss, persistence failure, and authorization decisions; and
- external physical or application observations.

## 29.2 Diagnostic Rules

`SW-DIAG-001` — Nondestructive reads shall precede diagnostic clear during discovery and recovery.

`SW-DIAG-002` — Every clear record shall identify the exact device field or counter, prior observed value, requester, reason, definitive result, and post-clear observation.

`SW-DIAG-003` — Aggregated summaries shall retain links to independent underlying evidence and shall not replace it.

`SW-DIAG-004` — Sensitive external context shall be redacted by policy without altering raw Dragon Core evidence fields.

# 30. Error Handling and Fault Recovery

## 30.1 Error Classes

| Class | Examples | Software disposition |
|---|---|---|
| Platform | SPI controller, interrupt, timer, storage, process, or OS failure | Isolate platform cause; preserve device uncertainty |
| Transport | Short transfer, malformed response, CRC failure, timeout, response loss | Classify as definitive or ambiguous; reconcile when applicable |
| Access/protection | Invalid address, access, authorization, reserved value | Do not retry unchanged; report exact result |
| Configuration | Range, relation, commit, capability, or active-readback mismatch | Preserve prior active state; block dependents |
| Resource | Busy, full, empty, overflow, underflow, or drop | Apply bounded service/backoff; retain loss evidence |
| Device state | Startup, degraded, faulted, reset, test, or lost ready | Enter lifecycle recovery; do not assume cache validity |
| External interface | Adapter, transceiver, conditioning, or remote endpoint fault | Separate device evidence from external-owner diagnosis |
| Software | Queue loss, deadline miss, persistence failure, invariant violation | Fail affected service safely and preserve audit evidence |

## 30.2 Retry Policy

`SW-ERR-001` — Read-only nondestructive operations may be retried with bounded policy after transport recovery.

`SW-ERR-002` — A state-changing operation may be retried only after definitive failure before effect or successful reconciliation plus state readback establishes that duplication cannot occur.

`SW-ERR-003` — Busy and transient resource states shall use bounded backoff and a caller-visible deadline.

`SW-ERR-004` — Recovery shall not clear evidence, reset the device, or reapply configuration until the pre-recovery state required by policy has been captured.

## 30.3 Reconnect and Reset Recovery

Recovery shall reestablish transport, rediscover identity and compatibility, read the reconciliation record when an operation was outstanding, capture state and evidence nondestructively, compare active configuration with desired configuration, reapply lost volatile configuration through normal protected/commit paths, restart services, and confirm effective state. A reset is not a general-purpose error retry.

# 31. Security Architecture

## 31.1 Security Boundary

Dragon Core protected-write and production-test authorization are bounded hardware controls, not cryptographic authentication, secure boot, key storage, or an on-device software trust boundary, as allocated by `PBIO-SEC-001` through `PBIO-SEC-003`.

## 31.2 External Software Controls

`SW-SEC-001` — Host software shall own user identity, authentication, authorization, credential storage, network security, process isolation, least-privilege device access, and audit policy.

`SW-SEC-002` — Only the device service shall possess production SPI access; applications shall receive narrower typed capabilities.

`SW-SEC-003` — Protected-key helpers shall not be described as secret management and shall never bypass application authorization.

`SW-SEC-004` — Production-test and injection capabilities shall require a separate engineering build/profile, explicit physical and software authorization, and audit evidence.

`SW-SEC-005` — Configuration and software artifacts shall be integrity-checked before activation; release signing, when selected, is an external software-release control.

`SW-SEC-006` — Network requests shall not map directly to unrestricted register operations.

# 32. Performance Requirements

## 32.1 Ownership

Device performance and timing are owned by SRS `DFC-PERF-0001` through `DFC-PERF-0026`. This section defines software architectural performance obligations without restating device limits.

## 32.2 Software Obligations

`SW-PERF-001` — Each deployment shall define external deadlines for startup, interrupt service, event drain, watchdog service, diagnostic acquisition, persistence, reconnect, and reset recovery that are compatible with the selected controlling device limits and service policy.

`SW-PERF-002` — The command serializer shall provide priority classes so bounded watchdog, interrupt, reconciliation, and evidence-preservation work is not starved by bulk diagnostics or application traffic.

`SW-PERF-003` — Long-running bulk reads shall be partitioned at transaction boundaries without interleaving inside a protected, staged, selector, snapshot, or reconciliation transaction.

`SW-PERF-004` — Software shall measure queue depth, service latency, deadline miss, retry, reconciliation, persistence latency, and software-side loss.

`SW-PERF-005` — Performance optimization shall not remove validation, response checking, active readback, or evidence preservation.

# 33. Resource Management

## 33.1 Managed Resources

Software manages device-context ownership, SPI command slots, service priorities, host memory, worker threads, external queues, file/database capacity, log retention, and application subscriptions. It observes but does not own the capacity of device resources.

## 33.2 Resource Rules

`SW-RES-001` — Every software queue shall be bounded or governed by an explicit storage limit and loss policy.

`SW-RES-002` — Software-side drops shall produce independent counters and durable evidence; they shall not be merged with device counters.

`SW-RES-003` — One device context shall have one lifecycle owner and one serializer; ownership transfer shall be explicit and quiescent.

`SW-RES-004` — Shutdown shall stop new work, complete or reconcile the in-flight command, preserve required evidence, flush durable records, release interrupt and SPI resources, and mark cached observations stale.

`SW-RES-005` — Resource exhaustion shall degrade optional presentation or bulk work before time-critical service, subject to the approved deployment policy.

# 34. Portability Requirements

## 34.1 Portability Boundary

Portable layers shall depend only on fixed-width types, explicit byte arrays, declared endianness conversions, HAL interfaces, and generated logical definitions. No public data structure shall depend on compiler padding, host word size, or host endianness.

## 34.2 Supported Profiles

The architecture supports:

- bare-metal external host firmware;
- real-time operating systems;
- hosted operating systems;
- the VisionFive 2 FPGA-validation host; and
- future conforming external hosts with adequate SPI, interrupt, time, synchronization, memory, and persistence services.

## 34.3 Portability Rules

`SW-PORT-001` — Platform differences shall be confined to HAL/BSP and deployment composition.

`SW-PORT-002` — Serialization shall use generated field accessors and explicit byte order; casting packed host structs onto wire data is prohibited.

`SW-PORT-003` — Timing shall use monotonic duration types with explicit units.

`SW-PORT-004` — The same conformance suite shall run against each supported HAL implementation.

# 35. Software Development Environment

## 35.1 Controlled Environment

Each build shall identify source revision, controlling specification revisions, machine-readable register source, generator version, compiler/toolchain, dependencies, build options, target profile, and test configuration.

## 35.2 Required Capabilities

- formatting, lint, static analysis, and dependency checks;
- unit and integration test execution;
- generator and generated-artifact consistency checks;
- identifier and Markdown/reference checks for specifications consumed by generators;
- deterministic build and manifest generation;
- host conformance and HIL orchestration interfaces; and
- archival of logs, captures, coverage, and release artifacts.

## 35.3 Environment Rules

`SW-DEV-001` — Developer-local hand edits to generated files shall fail continuous integration.

`SW-DEV-002` — Warnings shall be reviewed; blanket suppression is prohibited.

`SW-DEV-003` — Test-only backdoors, production-test access, fault injection, and raw engineering APIs shall be compile-time or package-profile isolated from production releases.

# 36. Build and Release Architecture

## 36.1 Build Pipeline

The pipeline shall validate controlled inputs, generate host artifacts, compile all selected profiles, run static checks and tests, package artifacts, generate a manifest and dependency inventory, verify reproducibility, and publish only after exit criteria pass.

## 36.2 Release Contents

An applicable release shall include:

- generated host definitions and machine-readable provenance;
- HAL interfaces and supported adapters;
- driver, SDK, and selected services/applications;
- configuration schemas and migration tools;
- API and operator documentation;
- verification executables, results, and coverage summaries;
- build manifest, dependency inventory, digests, and licenses; and
- known limitations and exact compatibility declaration.

## 36.3 Release Rules

`SW-BUILD-001` — Generated artifacts and compiled software shall carry a common build-manifest identity.

`SW-BUILD-002` — A release shall not include an unresolved generated-definition mismatch or controlling-specification change flag.

`SW-BUILD-003` — Production and engineering profiles shall be separately identifiable and noninterchangeable.

# 37. API Versioning and Compatibility

## 37.1 Independent Version Axes

Software API version, persistent-schema version, application protocol version, product revision, register-map revision, build identity, and capability set are independent. No one axis shall be used as a substitute for another.

## 37.2 Compatibility Policy

`SW-API-001` — Exact generated bindings shall be selected by validated product and register-map compatibility, not by filename similarity or best effort.

`SW-API-002` — Unknown required capability or changed field meaning shall block state-changing access.

`SW-API-003` — Read-only diagnostic access under partial compatibility may be permitted only through an explicitly tested compatibility profile that preserves unknown raw values.

`SW-API-004` — Public API breaking changes require a major API-version change; additive compatible changes require a minor change; fixes that preserve behavior require a patch change.

`SW-API-005` — Persistent-data migration shall be explicit, reversible where practical, validated before replacement, and retain original provenance.

# 38. Software Traceability

## 38.1 Trace Model

Software architecture identifiers in this document shall trace downstream to software requirements, component design, source, tests, and release evidence. Upstream citations shall point to the exact controlling identifiers consumed by the software rule.

This document shall not reproduce the RTM's relationships among SRS, Architecture, Register Map, RTL, and Verification Plan identifiers.

## 38.2 Required Trace Links

| Source | Required downstream link |
|---|---|
| `SW-*` architecture rule | One or more software requirements or explicit rationale |
| Software requirement | Component/API allocation and verification case |
| Generated artifact | Machine-readable source item, generator version, and consistency test |
| Source component | Requirements/design identifiers and tests |
| Test result | Case, build, configuration, evidence, and outcome |
| Release artifact | Manifest, source/build identity, and passing exit evidence |

## 38.3 Trace Rules

`SW-TRACE-001` — Every normative `SW-*` rule shall be unique and resolved.

`SW-TRACE-002` — A derived software requirement shall cite its software-architecture source and applicable controlling technical source.

`SW-TRACE-003` — Trace shall not be inferred from directory location, filename similarity, or undocumented convention.

# 39. Software Verification Strategy

## 39.1 Verification Objectives

Verification shall establish correctness of generation, transport use, typed access, initialization, configuration, active readback, interrupt and event service, persistence, ambiguity reconciliation, reconnect, reset recovery, security boundaries, portability, and application behavior.

## 39.2 Mandatory Scenarios

At minimum, software verification shall cover:

- cold startup and host-ready discovery;
- exact compatibility and incompatible-device rejection;
- safe desired-configuration application and active readback;
- protected and staged operations with success and every applicable rejection class;
- simultaneous interrupts and source-preserving service;
- event snapshot, persistence, pop, overflow, and evidence-gap handling;
- response loss before acceptance and after acceptance, including partial completion;
- host reconciliation and retry prohibition;
- host disconnect/reconnect with autonomous device operation;
- module, safety-domain, system, and external reset recovery;
- volatile-configuration loss and reapplication;
- watchdog scheduling success and host-side deadline failure;
- software queue and persistence failure;
- production versus engineering capability isolation; and
- equivalent behavior across supported platform adapters.

## 39.3 Alignment with the Controlling Verification Plan

Host-boundary verification shall reuse the methods, environments, required components, HIL cases, coverage outcomes, and evidence definitions owned by `RCA-DFC-VP-002`, particularly `VP-GEN-016` through `VP-GEN-018`, scope V5, `T-HOST`, EV-16, `VP-HIL-001` through `VP-HIL-008`, and `VP-COV-016` through `VP-COV-020`.

Software-only tests may add cases but shall not redefine a controlling VP case or claim device conformity beyond the VP outcome.

# 40. Software Maintenance Strategy

## 40.1 Maintenance Classes

Maintenance includes defect correction, security remediation, toolchain/dependency update, platform-port update, compatibility update, configuration-schema migration, performance improvement, and documentation correction.

## 40.2 Change Analysis

Every change shall identify affected architecture rules, software requirements, components, generated artifacts, APIs, schemas, compatibility profiles, security boundaries, tests, evidence, and release artifacts.

## 40.3 Maintenance Rules

`SW-MAINT-001` — A controlling-specification change shall trigger impact analysis from the owning identifier through generated artifacts and software trace.

`SW-MAINT-002` — A discovered controlling defect shall be flagged to its owner; software shall not preserve a workaround as a competing definition.

`SW-MAINT-003` — Emergency fixes shall still preserve transaction serialization, ambiguity handling, active readback, evidence retention, and safety boundaries.

`SW-MAINT-004` — Deprecated APIs shall remain explicit, documented, and tested until removed by the declared compatibility policy.

# 41. Future Expansion Architecture

## 41.1 Permitted Expansion

Future host processors, operating systems, language bindings, applications, gateways, storage systems, and analysis services may be added behind existing architectural interfaces.

## 41.2 Expansion Rules

`SW-EXP-001` — Expansion shall not presume a new Dragon Core register, route, endpoint, capacity, processor, memory, test path, or device behavior.

`SW-EXP-002` — A future device capability shall first be defined by its controlling specification owner, then generated and consumed by software.

`SW-EXP-003` — New applications shall use typed SDK capabilities and shall not acquire direct platform SPI ownership.

`SW-EXP-004` — New network or cloud functions shall remain external and shall preserve local supervision, least privilege, bounded queues, audit, and disconnected operation.

`SW-EXP-005` — Future AI, analytics, or prognostics may interpret copied external data but shall not be described as a Dragon Core hardware function or direct aircraft-control authority.

# 42. Deliverables

## 42.1 Architecture Deliverables

- this controlled Revision C specification;
- software requirements derived from its `SW-*` rules;
- component and interface designs;
- machine-readable register source and generated host artifacts supplied under the Register Map contract;
- HAL adapters, driver, SDK, services, and selected applications;
- configuration schemas and validated examples;
- test suites, conformance clients, HIL automation, results, and evidence;
- build and release manifests; and
- user, integration, maintenance, and recovery documentation.

## 42.2 Acceptance Criteria

`SW-DEL-001` — Every delivered executable and generated artifact shall identify its source and compatibility manifest.

`SW-DEL-002` — Documentation shall describe external-software behavior without implying on-device firmware or software-owned hardware safety.

`SW-DEL-003` — No deliverable shall contain hand-copied register constants where a required generated definition exists.

`SW-DEL-004` — Only fully validated, internally consistent release artifacts shall be distributed as baseline deliverables.

# 43. Exit Criteria

Revision C architecture exit requires all of the following:

- all 44 sections are present and internally consistent;
- every normative `SW-*` identifier is unique;
- all cited controlling document and identifier references resolve;
- no device behavior, register meaning, verification case, trace relationship, or RTL rule is redefined here;
- all executable software is unambiguously outside the fabricated device;
- initialization, configuration, active readback, response-loss reconciliation, interrupt/event service, persistence, reconnect, and reset recovery are complete;
- current, sticky, counter, event, terminal, staged, and active state remain distinct;
- production and engineering capabilities are isolated;
- controlling-specification change flags are resolved or explicitly block release; and
- the completed Markdown passes structure, identifier, reference, and content validation.

`SW-EXIT-001` — A software implementation release may claim conformity to this architecture only when its downstream trace, tests, evidence, compatibility declaration, and applicable `RCA-DFC-VP-002` host-boundary outcomes pass.

# 44. Baseline Statement

## 44.1 Baseline Declaration

RCA-DFC-SW-001 Revision C is the software-architecture baseline for the Dragon Flight external-host software ecosystem supporting Dragon Core Revision A. It supersedes prior revisions of RCA-DFC-SW-001 for software-architecture use.

## 44.2 Governing Relationship

This specification remains subordinate to the eight controlling specifications identified by `RCA-DFC-CHTR-002`, Section 3.1. It defines no alternate device, interface, register, verification, traceability, or RTL contract.

## 44.3 Fixed Architectural Conclusions

- Dragon Core is processor-free and executes no software.
- Every executable component described here runs outside the fabricated device.
- Software uses one documented SPI and register contract through generated definitions.
- Hardware owns deterministic startup, device behavior, and allocated safety supervision.
- Software owns external policy, configuration persistence, long-term records, orchestration, interpretation, and host recovery.
- State-changing command ambiguity is resolved through coherent reconciliation and readback, never blind retry.
- Active configuration, current state, sticky evidence, counters, terminal records, and retained events remain independently represented and serviced.

## 44.4 Controlling-Specification Disposition

No change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` is required to establish this Revision C software architecture.

## 44.5 Change Control

Any future change that alters the software boundary, public API behavior, initialization or recovery sequence, persistence model, compatibility policy, security boundary, application allocation, or verification obligation shall revise this specification and complete downstream impact analysis. Any change that requires new device behavior shall first revise the applicable controlling specification owner.

## 44.6 Approval Statement

Upon approval, this document is ready for direct placement beneath the eight controlling Dragon Flight specifications as `RCA-DFC-SW-001_Dragon_Flight_Software_Architecture_Specification_RevC.md`.
