**DRAGON CORE™ EMBEDDED FIRMWARE SPECIFICATION**

Document Number: RCA-DFC-SW-002
Revision: B
Status: Technical Baseline
Product: Dragon Core™ Revision A
Program: Dragon Flight™ Core ASIC Development Program
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date       | Description | Author |
|----------|------------|-------------|--------|
| A | 2026-07-03 | Historical initial baseline skeleton | Royal Cubit Aerospace |
| B | 2026-08-07 | Rebuilt beneath the eight controlling specifications as the external embedded-host firmware implementation baseline | Royal Cubit Aerospace |

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
4. Firmware Identification
5. Firmware Architecture
6. Firmware Responsibilities
7. Firmware Initialization
8. Runtime Architecture
9. Firmware State Machine
10. Hardware Interface Architecture
11. Interrupt Processing
12. Event Processing
13. Configuration Management
14. Health Monitoring
15. Fault Management
16. Watchdog Servicing
17. Communication Services
18. User Logic Support
19. Resource Management
20. Performance Requirements
21. Error Handling
22. Security Considerations
23. Firmware APIs
24. Verification Requirements
25. Formal Verification Objectives
26. Development Environment
27. Deliverables
28. Exit Criteria
29. Baseline Statement

# 1. Purpose

This Embedded Firmware Specification defines the implementation requirements for firmware that executes on an **external embedded host processor** and controls or observes Dragon Core Revision A through the documented host interface. Dragon Core is a processor-free ASIC and contains no firmware, bootloader, Board Support Package (BSP), operating system, runtime, stack, heap, executable memory, or instruction-executing processor, as required by `CHTR-TECH-001` through `CHTR-TECH-005` and `CHTR-EXCL-002`.

Within this document, **firmware** means the external-host embedded software configuration item. It does not mean code resident in the fabricated Dragon Core device, the OpenFrame platform, the ECP5 validation image, an RTL module, or a technology wrapper.

This specification is subordinate to the eight controlling technical specifications identified by `RCA-DFC-CHTR-002`, Section 3.1. It implements the external embedded-host profile of `RCA-DFC-SW-001` Revision C. It owns firmware-only implementation requirements, including component decomposition, execution and concurrency rules, lifecycle workflows, memory and scheduling policy, API behavior, error disposition, external persistence use, build controls, and software verification.

This specification does not own or redefine:

- product mission, product scope, selected platforms, or the external-host model;
- responsibility boundaries;
- externally observable Dragon Core behavior or timing;
- internal hardware architecture, algorithms, states, interfaces, or allocations;
- register offsets, fields, access classes, reset values, encodings, or side effects;
- controlling verification methods, cases, coverage, or evidence definitions;
- relationships among controlling identifiers; or
- SystemVerilog implementation rules.

`FW-DOC-001` — Firmware shall implement the applicable controlling contracts without creating an alternate device, interface, register, verification, traceability, or RTL definition.

`FW-DOC-002` — If implementation exposes a conflict, ambiguity, omission, or unimplementable controlling contract, dependent work shall stop until the document that owns the subject is corrected; firmware shall not invent a substitute.

# 2. Scope

## 2.1 Included Scope

This specification applies to Royal Cubit Aerospace external embedded-host firmware that uses Dragon Core as an SPI-mapped peripheral. It covers bare-metal and real-time operating system deployments and the reusable firmware portions of an external validation-host deployment.

Included subjects are:

- external-host platform adaptation for SPI, interrupt reception, monotonic time, synchronization, and optional persistence;
- generated register bindings and typed access helpers;
- command transport, response validation, serialization, and ambiguous-outcome reconciliation;
- device discovery, compatibility evaluation, initialization, configuration, enablement, operation, shutdown, reconnect, and reset recovery;
- interrupt, event, diagnostic, health, fault, watchdog, communication, and user-resource services;
- bounded memory, queue, task, scheduling, and timing policy;
- external desired-configuration and evidence persistence interfaces;
- firmware APIs, error reporting, security boundaries, and engineering-profile isolation; and
- firmware unit, component, integration, host-conformance, FPGA, and hardware-in-the-loop verification.

## 2.2 Excluded Scope

The following are excluded:

- any executable software or general-purpose computing inside Dragon Core;
- device startup logic, hardware state machines, digital protocol engines, safety-supervision algorithms, and shared-buffer implementation;
- RTL, FPGA bitstreams, ASIC physical implementation, OpenFrame integration, and board-level electrical design;
- operating-system kernel internals, host boot firmware unrelated to the Dragon Core service, and general-purpose application frameworks;
- Dragon Console™, Dragon Gateway™, and Dragon Sentinel™ application implementation, except for the firmware APIs they consume;
- aircraft-specific flight control, navigation, guidance, mission management, energy control, calibration policy, and certification activity; and
- undocumented test, scan, platform-private, RTL-hierarchical, or physical shared-memory access.

## 2.3 Product and Safety Boundary

`FW-SCOPE-001` — All firmware code, data, stacks, queues, persistent records, and execution resources shall remain outside the fabricated device in accordance with `CHTR-TECH-002`, `CHTR-EXCL-002`, `PBIO-HOST-003`, and `PBIO-HOST-004`.

`FW-SCOPE-002` — Firmware shall use only the SRS-defined host protocol and Register-Map-defined host-visible contract, as required by `PBIO-HOST-006`.

`FW-SCOPE-003` — Firmware shall not assume, replace, bypass, or suppress a hardware safety responsibility allocated to Dragon Core by `PBIO-SAFE-001` through `PBIO-SAFE-004`.

`FW-SCOPE-004` — Firmware may configure and observe authorized logical safety behavior, but it shall not expose an API that directly requests an active logical safety-output level.

`FW-SCOPE-005` — Loss, reset, delay, or corruption of firmware shall be treated as an external-host condition and shall not be represented as loss of the autonomous hardware behavior required by `DFC-SAFE-0001`, `DFC-SAFE-0021`, and `DFC-REL-0004`.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order, technical subject ownership, and single-definition rules are controlled only by `RCA-DFC-CHTR-002`, Section 3. The following is an informative firmware-use view and creates no alternate order or precedence.

| Document | Firmware use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product scope, processor-free constraint, selected platforms, external-host model, and document-ownership rules |
| `RCA-DFC-PBIO-002.md` | Device, host, software, board, safety, test, data, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior, logical interfaces, performance, safety, and reliability obligations |
| `RCA-DFC-ARCH-002.md` | Device-side internal contracts required to use coherent access, events, queues, diagnostics, reset, and reconciliation correctly |
| `RCA-DFC-REG-002.md` | Sole source for host-visible registers, fields, legality, protection, read/write behavior, and side effects |
| `RCA-DFC-VP-002.md` | Controlling verification methods, environments, cases, outcomes, coverage, and evidence |
| `RCA-DFC-RTM-002.md` | Relationships among controlling requirement, architecture, register, RTL, and verification identifiers |
| `RCA-DFC-RTL-STD-002.md` | SystemVerilog coding and structural rules; not a firmware coding standard |

## 3.2 Governing Software Architecture

`RCA-DFC-SW-001_Dragon_Flight_Software_Architecture_Specification_RevC.md` defines the external software architecture implemented by this firmware profile. It remains subordinate to the eight controlling specifications and does not displace their subject ownership.

`FW-DOC-003` — This firmware shall preserve the external embedded-host constraints `SW-FW-001` through `SW-FW-004` and every applicable cross-cutting `SW-*` architecture rule.

## 3.3 Historical Reference

The supplied `RCA-DFC-SW-002` Revision A is historical reference only. Its useful subject organization is retained, but statements that imply firmware inside Dragon Core, firmware-controlled device boot, firmware initialization of internal clocks or reset logic, memory-mapped host access not mediated by the defined SPI transport, firmware ownership of device fault or safety algorithms, or undocumented user-programmable logic are superseded.

## 3.4 Authority and Change Flags

`FW-DOC-004` — This specification shall apply `CHTR-DOC-001` through `CHTR-DOC-007`. A consumed fact shall be cited rather than copied as a second normative definition.

`FW-DOC-005` — Generated host definitions required by the Register Map are derived artifacts. They shall preserve the controlling source identifiers and shall not become an independently maintained register definition.

| Flag | Controlling owner | Finding | Required action |
|---|---|---|---|
| None | — | The eight controlling specifications define a consistent external-host boundary, complete host-visible programming contract, active readback, retained evidence, command reconciliation, reset recovery, and host-verification basis sufficient for Revision B firmware. | No controlling-specification change is required. |

## 3.5 Firmware Implementation Standard

ISO/IEC 9899:2018 is the language standard selected by Section 26 for the portable C17 firmware core. Project coding, safety, security, assurance, and certification standards may impose additional software-process constraints, but they shall not alter a Dragon Core technical fact owned by the eight controlling specifications.

# 4. Firmware Identification

## 4.1 Configuration Item

| Item | Definition |
|---|---|
| Firmware name | Dragon Core External Embedded-Host Firmware |
| Document number | RCA-DFC-SW-002 |
| Revision | B |
| Product supported | Dragon Core Revision A |
| Execution location | Processor outside the fabricated Dragon Core device |
| Configuration-item class | External embedded-host firmware |
| Primary implementation language | ISO/IEC 9899:2018 C17 |
| Permitted execution profiles | Bare metal, real-time operating system, and reusable embedded components hosted by the selected validation environment |
| Primary device transport | Platform HAL implementation of the SRS-defined SPI host transport |
| Host interrupt | Platform HAL input consuming the SRS-defined host interrupt output |
| Device programming model | Generated bindings derived from the Register-Map-controlled machine-readable source |
| Persistent storage | External and optional by deployment; never inside Dragon Core |
| Release identity | Firmware semantic version plus source, build, configuration-schema, generated-binding, and controlling-specification manifest identities |

## 4.2 Identification Rules

`FW-ID-001` — Every firmware image or library release shall contain or accompany a machine-readable manifest identifying source revision, compiler and linker, build options, target profile, API version, configuration-schema version, generated-binding identity, and controlling-specification revisions.

`FW-ID-002` — Firmware version, Dragon Core product revision, register-map revision, capability set, FPGA image identity, ASIC build identity, and persistent-schema version are independent identifiers and shall not substitute for one another.

`FW-ID-003` — A firmware image shall not describe itself as code for an internal Dragon Core processor or as part of the fabricated ASIC image.

`FW-ID-004` — Production, engineering, simulation, and HIL profiles shall be uniquely identified and shall not be interchangeable.

# 5. Firmware Architecture

## 5.1 Architectural Objectives

The firmware architecture shall provide:

- one portable implementation for conforming external hosts;
- exact use of the generated Dragon Core register contract;
- deterministic and bounded time-critical service;
- explicit separation of mechanism, device semantics, and installation policy;
- evidence-preserving startup and recovery;
- no blind retry of an ambiguously completed state-changing command;
- replaceable host-platform adapters; and
- testable components with no undocumented hardware dependencies.

## 5.2 Layer Architecture

| Layer | Components | Permitted dependency |
|---:|---|---|
| 6 | External application adapter | Firmware services and public firmware API |
| 5 | Lifecycle, configuration, interrupt, event, diagnostic, watchdog, communication, and recovery services | Typed device driver |
| 4 | Typed device driver and device models | Generated register access and transaction coordinator |
| 3 | Generated bindings, access validators, coherent-operation helpers | Command transport |
| 2 | SPI command transport, response classifier, host-reconciliation service | Platform HAL |
| 1 | BSP/HAL for SPI, interrupt, monotonic time, synchronization, and optional storage | External host hardware or RTOS |
| 0 | Dragon Core logical device boundary | SRS and Register Map contract only |

## 5.3 Required Components

| Component | Primary responsibility |
|---|---|
| Platform HAL | Adapt external SPI master, interrupt input, monotonic timer, synchronization, memory ordering, and platform errors |
| Generated bindings | Provide register and field definitions, access metadata, legal-value metadata, and source provenance |
| Command transport | Construct commands, execute transfers, validate responses, classify completion, and retain raw evidence |
| Transaction coordinator | Serialize commands and protect multi-command semantic transactions from invalid interleaving |
| Typed device driver | Implement legal scalar, protected, staged/commit, snapshot/pop, queue, counter, reset, and reconciliation operations |
| Lifecycle manager | Own discovery, compatibility, initialization, enablement, shutdown, reconnect, reset recovery, and firmware state |
| Configuration service | Validate desired configuration, apply it in dependency order, verify active readback, and maintain an activation journal |
| Interrupt and event services | Defer interrupt work, identify sources, retrieve evidence, persist or hand off records, and apply explicit acknowledgement or pop operations |
| Diagnostic service | Acquire current, sticky, counter, terminal, reset, clock, buffer, and communication evidence without conflation |
| Watchdog service | Schedule and perform authorized external watchdog service under an analyzed timing policy |
| Capability services | Provide typed monitoring, GPIO, databus, routing, user-resource, and safety-configuration operations |
| Persistence adapter | Store desired configuration, retrieved evidence, audit records, and firmware metadata outside Dragon Core when the deployment requires persistence |

## 5.4 Architecture Rules

`FW-ARCH-001` — One device context shall own one physical Dragon Core instance, one lifecycle state machine, and one command-serialization authority.

`FW-ARCH-002` — An application shall not call platform SPI primitives or embed register offsets, masks, protection values, opcodes, status encodings, source identifiers, or event formats.

`FW-ARCH-003` — Platform-dependent code shall be confined to the HAL/BSP and deployment integration layer.

`FW-ARCH-004` — Cross-layer data shall use fixed-width types, explicit units, immutable observations, and structured results.

`FW-ARCH-005` — Test doubles shall implement the production interfaces and shall not grant a production component capabilities absent from the documented host boundary.

`FW-ARCH-006` — Optional component omission shall not remove command serialization, compatibility checking, response validation, ambiguity reconciliation, active readback, or evidence-preservation behavior.

# 6. Firmware Responsibilities

## 6.1 Responsibility Allocation

| Firmware owns | Firmware consumes but does not own |
|---|---|
| SPI-master use and host-controller handling | Dragon Core SPI-target behavior |
| Legal configuration selection and application policy | Register legality and device validation |
| External interrupt scheduling and service workflow | Device interrupt aggregation, pending state, and source allocation |
| Event retrieval, external retention, and distribution | Device event creation, record format, ordering, and finite retention |
| Desired configuration and nonvolatile storage | Device reset values and volatile active configuration |
| Host-side health interpretation and alert policy | Device monitoring, fault classification, and safety algorithms |
| Host watchdog service schedule and timing evidence | Device watchdog window, key enforcement, timeout, and responses |
| Firmware memory, tasks, queues, deadlines, and logs | Device internal storage, arbitration, timing, and loss behavior |
| Recovery orchestration and external audit | Device reset scopes, terminal results, and retained evidence |

## 6.2 Functional Responsibilities

`FW-RESP-001` — Firmware shall discover and validate device identity, product revision, register-map revision, build identity, and capabilities before making state-changing services available.

`FW-RESP-002` — Firmware shall validate desired configuration before the first device write and shall confirm active or effective readback after each dependency-significant change.

`FW-RESP-003` — Firmware shall preserve raw device evidence and distinguish it from host interpretation, derived engineering units, and application policy.

`FW-RESP-004` — Firmware shall maintain an explicit record of every state-changing request, definitive result or reconciliation outcome, and applicable post-operation readback.

`FW-RESP-005` — Firmware shall coordinate time-critical interrupt, watchdog, reconciliation, and evidence-retrieval work so that bulk or presentation work cannot starve it.

`FW-RESP-006` — Firmware shall report software-side timeout, queue loss, persistence failure, deadline miss, and invariant failure independently from device-reported conditions.

## 6.3 Prohibited Responsibilities

`FW-RESP-007` — Firmware shall not implement or claim ownership of Dragon Core hardware startup, operating-state priority, fault-source classification, interlock evaluation, lost-link detection, databus wire protocols, event arbitration, or logical safety-output activation.

`FW-RESP-008` — Firmware shall not compensate for a nonconforming device, wrapper, board, or host interface by relying on undocumented behavior.

`FW-RESP-009` — Firmware shall not clear evidence, reset a subsystem, disable supervision, or reapply configuration merely to produce a nominal display state.

# 7. Firmware Initialization

## 7.1 Initialization Principles

Dragon Core reaches host-access-ready operation through deterministic hardware startup under `CHTR-TECH-011` and `DFC-REL-0001`. Firmware initializes the **external host service**, not the Dragon Core clock tree, reset tree, internal register bank, event store, or device state machines.

## 7.2 Required Initialization Sequence

| Phase | Firmware action | Exit condition |
|---:|---|---|
| 1. Local platform | Initialize memory, locks, monotonic time, SPI master, interrupt input, logging, and optional persistence; keep device state-changing services closed | All mandatory HAL self-checks pass |
| 2. Host-ready discovery | Poll nondestructively with bounded backoff | Host-ready is independently observed or the deployment deadline expires |
| 3. Identity and compatibility | Read product identity, product revision, register-map revision, build identity, and capabilities | Exact compatible generated binding is selected |
| 4. Pre-change observation | Capture operating qualifiers, current state, active configuration, sticky evidence, counters, reset and host-terminal records, queue state, and retained events required by policy | Required pre-change evidence is secured without clear or pop |
| 5. Desired-state validation | Validate schema, target identity, capabilities, ranges, dependencies, authorization, and required services | Entire desired object is accepted locally |
| 6. Safe application | Maintain effective operation inhibited; apply protected and staged objects in declared dependency order | Every operation has a definitive result and active readback |
| 7. Service activation | Start interrupt, event, diagnostics, persistence, and watchdog scheduling required by the approved configuration | Each mandatory service reports ready |
| 8. Operational request | Request permitted operational enable | Effective operational state is independently read back |
| 9. Publication | Publish the device context to application clients | Identity, configuration, services, and observed state are coherent |

## 7.3 Initialization Requirements

`FW-INIT-001` — No state-changing command shall precede compatibility selection and required nondestructive pre-change observation.

`FW-INIT-002` — Unknown product revision, register-map revision, required capability, or reserved status encoding shall block state-changing access.

`FW-INIT-003` — A failure of compatibility, validation, protection, commit, active readback, service startup, or effective enable shall prevent the context from entering firmware OPERATIONAL state.

`FW-INIT-004` — Initialization shall retain enough progress and command evidence to distinguish a local failure, a definitive device rejection, an ambiguous outcome, a reset, and a lost connection.

`FW-INIT-005` — Safety-related configuration shall be applied and verified while externally effective operation remains inhibited; firmware shall not test a safety output through a production pad.

`FW-INIT-006` — Reinitialization after firmware restart shall use the reconnect workflow and shall not assume Dragon Core reset or loss of active configuration.

# 8. Runtime Architecture

## 8.1 Execution Model

The firmware may use a superloop, cooperative scheduler, or preemptive RTOS. Every profile shall preserve the same semantic execution authorities:

- one command executor per device context;
- one lifecycle authority;
- bounded hard-interrupt handling;
- deferred device service;
- monotonic deadline scheduling;
- bounded inter-service queues; and
- explicit application request admission.

## 8.2 Service Priority Classes

| Priority class | Work |
|---|---|
| Critical | In-flight command completion or reconciliation; configured watchdog-service decision; loss-of-host-interface handling |
| High | Interrupt-source service; safety, fault, reset, overflow, and evidence-preservation acquisition |
| Normal | Configuration workflows, queue operations, monitoring acquisition, and application commands |
| Background | Bulk diagnostics, historical export, presentation refresh, and maintenance statistics |

The classes define firmware scheduling order only and do not redefine hardware priorities.

## 8.3 Runtime Rules

`FW-RUN-001` — The command executor shall serialize all SPI commands for one device, including commands requested by interrupt, watchdog, application, and recovery services.

`FW-RUN-002` — A protected, selector, snapshot/pop, staged/commit, queue-entry, reset, or reconciliation workflow shall hold exclusive semantic ownership for every command whose interleaving could change the outcome.

`FW-RUN-003` — Long operations shall yield only at a transaction boundary that preserves the meaning of the active workflow.

`FW-RUN-004` — Every wait, retry, drain loop, queue, and lock acquisition shall have a declared bound or caller-visible deadline.

`FW-RUN-005` — Hard-interrupt context shall perform only the bounded platform acknowledgement and deferred-work notification required by the selected host.

`FW-RUN-006` — Cached observations shall carry freshness and lifecycle-generation metadata and shall become stale on reset, reconnect, compatibility loss, or uncertain command completion as applicable.

`FW-RUN-007` — Shutdown shall stop new work, complete or reconcile the in-flight command, preserve required evidence, flush durable records, disable local scheduling, release platform resources, and mark cached observations stale.

# 9. Firmware State Machine

## 9.1 State Definitions

The following are firmware workflow states. They are not Dragon Core primary operating states and have no device register encoding.

| Firmware state | Meaning |
|---|---|
| `FW_UNINITIALIZED` | No platform or device context is usable |
| `FW_PLATFORM_READY` | Required local HAL resources are ready; no device compatibility has been established |
| `FW_DISCOVERING` | Firmware is awaiting host-ready and reading identity |
| `FW_INCOMPATIBLE` | Device identity, revision, or capabilities do not permit state-changing access |
| `FW_OBSERVING` | Compatibility is established and nondestructive pre-change observation is in progress |
| `FW_CONFIGURING` | A validated desired configuration is being applied and confirmed |
| `FW_OPERATIONAL` | Required services are active and effective device state has been confirmed |
| `FW_DEGRADED_OBSERVED` | Firmware observes Dragon Core DEGRADED or a nonfatal firmware-service degradation |
| `FW_FAULTED_OBSERVED` | Firmware observes Dragon Core FAULTED while retaining diagnostic service where possible |
| `FW_RECOVERING` | Transport, reconnect, reset, configuration, or service recovery is in progress |
| `FW_SERVICE_FAILED` | A mandatory local firmware service cannot meet its contract |
| `FW_STOPPED` | Context has completed controlled shutdown |

## 9.2 Transition Rules

`FW-STATE-001` — Firmware state shall be held separately from the device primary state and independent device qualifiers.

`FW-STATE-002` — Entry to `FW_OPERATIONAL` shall require compatible identity, validated active configuration, ready mandatory services, and confirmed effective device state.

`FW-STATE-003` — `FW_INCOMPATIBLE` shall permit only explicitly supported nondestructive diagnostic access and shall prohibit state-changing commands.

`FW-STATE-004` — Observation of device DEGRADED or FAULTED shall not itself clear, reset, acknowledge, or reconfigure the device.

`FW-STATE-005` — Any transport discontinuity, device reset indication, lifecycle-generation mismatch, or ambiguous state-changing result shall move dependent workflows to `FW_RECOVERING`.

`FW-STATE-006` — `FW_SERVICE_FAILED` shall stop or inhibit affected state-changing services and watchdog servicing according to the approved external policy while preserving diagnostic access where safe.

`FW-STATE-007` — Recovery shall return through discovery, observation, configuration comparison, and effective-state confirmation; it shall not jump directly to `FW_OPERATIONAL`.

# 10. Hardware Interface Architecture

## 10.1 Platform HAL Contract

The HAL shall provide:

- full-duplex SPI transfer and chip-select control required by the host controller;
- actual transferred-length and platform-error reporting;
- host interrupt registration, mask/unmask, host-controller acknowledgement, and deferred signaling;
- monotonic time, duration, deadline, and bounded-delay services;
- mutual exclusion, notification, and memory-ordering primitives required by the execution profile;
- controlled access to static or caller-supplied memory; and
- optional external logging, persistence, and platform identity services.

## 10.2 Command Result Model

Each transport result shall represent, as applicable:

- local submission and transfer status;
- actual transferred length;
- response integrity and protocol validation;
- definitive device status;
- completed-word count and returned data;
- local timeout or platform error;
- definitive versus ambiguous outcome;
- raw capture or diagnostic reference; and
- reconciliation classification when performed.

## 10.3 Interface Rules

`FW-HSI-001` — The transport shall consume the command and response behavior owned by `DFC-INTF-0011` through `DFC-INTF-0036` without redefining frame encoding, timing, CRC, acceptance, completion, or status.

`FW-HSI-002` — A short transfer, malformed response, invalid response CRC, or missing terminal response shall never be promoted to successful completion.

`FW-HSI-003` — Multiword commands shall preserve the controlling ordered, non-atomic semantics. Firmware shall not represent them as atomic unless the Register Map defines a staging/commit operation for the object.

`FW-HSI-004` — Wire serialization shall use explicit byte operations and generated accessors. Casting a compiler-packed host structure onto wire bytes is prohibited.

`FW-HSI-005` — Host word size, alignment, compiler padding, processor endianness, operating system, and SPI-controller implementation shall not alter the logical register result.

`FW-HSI-006` — Raw register access, if present in an engineering profile, shall remain serialized, use generated definitions, expose all side effects, and be absent or disabled in production profiles.

## 10.4 Ambiguous-Outcome Reconciliation

For an ambiguous state-changing command, firmware shall:

1. block later dependent state-changing commands;
2. retain the raw host-side transaction evidence;
3. read the coherent host-reconciliation record through its Register-Map-defined procedure;
4. compare command identity, sequence, starting address, operation, status, and completed extent as applicable;
5. classify the outcome as completed, partially completed, failed before effect, not represented, or indeterminate;
6. inspect active configuration or target state when needed; and
7. permit retry only when reconciliation and readback prove that duplication cannot occur.

`FW-HSI-007` — A reset, pop, clear, push, service, commit, acknowledgement, recovery command, or other state-changing operation shall never be blindly retried after an ambiguous outcome.

# 11. Interrupt Processing

## 11.1 Service Sequence

Firmware shall:

1. record host interrupt reception using monotonic time;
2. perform the bounded host-controller acknowledgement required by the platform;
3. schedule deferred device service;
4. read complete pending and encoded-source state through typed APIs;
5. service the source-owned condition or resource;
6. apply device acknowledgement or clear only when the Register Map defines and policy requests it;
7. reread pending state until the bounded drain condition is met; and
8. preserve unrelated interrupt, event, fault, and diagnostic evidence.

## 11.2 Interrupt Requirements

`FW-IRQ-001` — The host interrupt line shall be treated as a wakeup indication, not as complete source identity or proof that one particular condition remains active.

`FW-IRQ-002` — Firmware shall preserve simultaneous sources and shall handle a new source that asserts during service.

`FW-IRQ-003` — Host-controller acknowledgement shall not be represented as Dragon Core source acknowledgement or clear.

`FW-IRQ-004` — A still-active source after an authorized clear shall remain reportable; firmware shall use bounded backoff and escalation rather than an unbounded service loop.

`FW-IRQ-005` — Polling fallback may supplement interrupt service but shall use the same source-specific service semantics.

`FW-IRQ-006` — Interrupt latency, drain depth, deferred-work queue occupancy, and missed-service conditions shall be measured or evidenced for the selected deployment.

# 12. Event Processing

## 12.1 Retrieval Pipeline

| Stage | Firmware responsibility |
|---|---|
| Detect | Schedule retrieval from interrupt or bounded polling without blocking critical service |
| Snapshot | Obtain one coherent oldest retained event without removal |
| Validate | Preserve raw fields; classify known identifiers through generated definitions |
| Persist or hand off | Secure the raw record with device identity, host receipt time, and ingestion sequence |
| Pop | Remove only the validated snapshot when retention policy authorizes removal |
| Publish | Distribute immutable raw and typed views to subscribers |

## 12.2 Event Requirements

`FW-EVT-001` — The device raw timestamp shall remain the event's primary timestamp. Correlated, monotonic-host, or wall-clock time shall be stored as separate derived metadata.

`FW-EVT-002` — Firmware shall not modify an event record to fit a known decoder. Unknown identifiers, flags, or source values shall be retained as raw compatibility evidence.

`FW-EVT-003` — Persistence or required handoff shall complete before destructive pop. If it fails, popping shall stop unless an explicitly approved degraded-retention policy records the deliberate loss.

`FW-EVT-004` — An ambiguous pop outcome shall be reconciled before another snapshot/pop sequence begins.

`FW-EVT-005` — Device event-store overflow and producer-loss evidence shall create an explicit evidence-gap record in external storage and shall remain distinct from firmware queue or persistence loss.

`FW-EVT-006` — Firmware shall not attempt to change the mandatory device overwrite-oldest policy or assume that an event record replaces its underlying primary status or counter evidence.

# 13. Configuration Management

## 13.1 Desired-Configuration Object

The external desired-configuration object shall include:

- schema and configuration identity;
- target product, product revision, register-map revision, and required capabilities;
- generated-binding and source-manifest identity;
- typed desired values, feature enables, and activation groups;
- dependency ordering and protection requirements;
- provenance, authorization, approval, and change record as applicable; and
- an integrity digest.

## 13.2 Configuration Workflow

`FW-CFG-001` — Firmware shall validate the complete desired object before the first write, including types, units, ranges, cross-field relations, capabilities, authorization, and dependency order.

`FW-CFG-002` — Configuration shall be applied while externally effective operation is inhibited and in a deterministic dependency order.

`FW-CFG-003` — Each protected operation shall retain exclusive command ownership for the entire authorization and target sequence.

`FW-CFG-004` — Each staged object shall use explicit select, stage, validate/commit, result, and active-readback operations; staging shall never be presented as active configuration.

`FW-CFG-005` — Active readback shall be compared with the typed desired value before dependent configuration proceeds.

`FW-CFG-006` — Rejection shall retain the prior desired object, exact device result, and configuration-error evidence; firmware shall not silently clamp, normalize, or substitute a value.

`FW-CFG-007` — Because a multi-object configuration is not globally atomic unless the controlling contract states otherwise, firmware shall maintain an activation journal identifying each object not started, staged, committed, confirmed, rejected, or indeterminate.

`FW-CFG-008` — Reset or power loss shall invalidate cached active configuration. Firmware shall compare complete active readback with the desired object and reapply lost volatile configuration only through the normal validated workflow.

`FW-CFG-009` — Configuration-schema migration shall create a new validated object with retained provenance; best-effort runtime reinterpretation is prohibited.

# 14. Health Monitoring

## 14.1 Monitoring Model

Firmware health monitoring observes and publishes hardware-produced current state, qualification state, validity, thresholds, age, sticky evidence, counters, and recovery indications. It may add host-side freshness, deadline, communication, persistence, and service-health observations, but those shall use a separate namespace and shall not be represented as Dragon Core hardware status.

## 14.2 Health Requirements

`FW-HEALTH-001` — Firmware shall preserve the distinction among raw, synchronized, qualified, active, valid, stale, threshold, sticky, recovered, and aggregate indications wherever the controlling contract exposes them.

`FW-HEALTH-002` — Firmware shall not infer an independent qualifier solely from the primary operating state, interrupt line, requested configuration, or cached prior value.

`FW-HEALTH-003` — Health sampling shall use a deployment-defined bounded cadence compatible with the applicable SRS timing and freshness requirements.

`FW-HEALTH-004` — Engineering-unit conversion, calibration, trend analysis, and alert policy shall remain external interpretations with retained links to the raw device values, in accordance with `PBIO-HOST-009`.

`FW-HEALTH-005` — A diagnostic clear shall identify the exact field or counter, prior value, requester, reason, definitive result, and post-clear observation.

`FW-HEALTH-006` — Firmware shall not clear sticky evidence merely because the active condition has recovered.

# 15. Fault Management

## 15.1 Firmware Role

Dragon Core hardware owns fault collection, classification, recoverability, priority, primary selection, event and interrupt generation, and authorized safety responses. Firmware owns observation, external policy, evidence retention, operator or application notification, and authorized recovery requests.

## 15.2 Fault Requirements

`FW-FAULT-001` — Firmware shall preserve simultaneous fault-source identity and shall not reduce the source set to the reported primary fault.

`FW-FAULT-002` — Active fault state, latched historical state, recoverability, primary selection, response state, degraded state, interrupt state, event evidence, and counters shall remain separately represented.

`FW-FAULT-003` — Firmware shall not invent a fault source, classification, recoverability property, priority, or safety response absent from the Architecture and Register Map.

`FW-FAULT-004` — An authorized recovery command shall be issued only after the source condition and controlling prerequisites have been observed and external policy permits the action.

`FW-FAULT-005` — A rejected or ambiguously completed recovery command shall preserve evidence and enter the normal reconciliation workflow.

`FW-FAULT-006` — Firmware observation of FAULTED shall continue nondestructive diagnostic and retained-event acquisition where permitted; reset shall not be an automatic generic retry.

# 16. Watchdog Servicing

## 16.1 Service Policy

The hardware watchdog supervises an external service source as required by `DFC-FUNC-0098` through `DFC-FUNC-0100`. Firmware may act as that source only when the deployment has an approved, analyzed schedule.

## 16.2 Watchdog Requirements

`FW-WDOG-001` — Before enabling watchdog service, firmware shall validate the selected window and timeout configuration, measure or bound worst-case scheduling and transport delay, and establish a monotonic service deadline.

`FW-WDOG-002` — Service shall be scheduled within the configured legal window with margin for release-build worst-case execution, interrupt latency, command serialization, and bounded transport variation.

`FW-WDOG-003` — Watchdog service shall use the Register-Map-defined protected and keyed operation through the command serializer.

`FW-WDOG-004` — An early, late, invalid, rejected, or ambiguous service shall be reported distinctly. An ambiguous service shall not be blindly retried.

`FW-WDOG-005` — If firmware loses compatibility, monotonic timing integrity, command-result certainty, or the ability to meet the analyzed window, it shall stop or leave disabled watchdog service according to the approved external policy and shall preserve host-side failure evidence.

`FW-WDOG-006` — Watchdog timeout, recovery, interrupt, event, fault, interlock, and safety-response indications shall be treated as independent hardware evidence and shall not be synthesized from the service-call return alone.

`FW-WDOG-007` — Bulk diagnostics, application traffic, or persistence work shall not starve a pending watchdog-service decision.

# 17. Communication Services

## 17.1 Service Scope

Firmware provides typed configuration, status, queue, and recovery operations for GPIO, ARINC 429, Classical CAN, UART, sensor updates, and bounded databus routing. Dragon Core hardware owns the device-side digital protocols and routing algorithms; external circuitry owns electrical adaptation under the PBIO allocation.

## 17.2 Receive Operations

`FW-COMM-001` — Receive service shall obtain coherent complete entries through the applicable snapshot/read/pop sequence and shall not expose a partial entry.

`FW-COMM-002` — Receive data shall retain raw payload, metadata, device timestamp, sequence, source identity, status, and host receipt time without conflation.

`FW-COMM-003` — An empty, underflow, overflow, protocol-error, or ambiguous-pop condition shall be represented explicitly and shall preserve related evidence.

## 17.3 Transmit Operations

`FW-COMM-004` — Transmit service shall validate payload length, metadata, capability, queue state, and application authorization before staging a request.

`FW-COMM-005` — A multiword transmit request shall remain exclusive from first staging write through push result and applicable readback.

`FW-COMM-006` — A full queue, rejected push, partial command completion, bus-off restriction, or ambiguous push shall not be presented as successful transmission.

`FW-COMM-007` — Acceptance into a device transmit queue and completion on an external bus shall be represented as different states when the controlling contract distinguishes them.

## 17.4 Routing and Interface Rules

`FW-COMM-008` — Routing configuration shall use only the fixed sources, destinations, authorization matrix, filters, and committed objects defined by the controlling specifications.

`FW-COMM-009` — Firmware shall not implement a second routing engine, alter a received message to make it routable, or access physical shared-buffer addresses.

`FW-COMM-010` — CAN, ARINC 429, UART, GPIO, and external-adapter error evidence shall remain distinguishable from host SPI and firmware-service errors.

# 18. User Logic Support

## 18.1 Mask-Defined User Logic

Revision A user logic is finite and fixed by fabrication masks under `CHTR-TECH-005`. Firmware may access only the documented control, status, diagnostic input, and mailbox contract of the active product capability profile.

## 18.2 User Routing and Mailbox Requirements

`FW-USER-001` — Firmware shall not accept, load, interpret, or claim support for an FPGA bitstream, microcode image, executable image, structural user-logic program, or arbitrary internal connection description for Dragon Core.

`FW-USER-002` — Firmware shall treat the Revision A user-logic profile as inert except for behavior explicitly exposed by the controlling register contract.

`FW-USER-003` — Mailbox push and pop operations shall preserve complete-entry semantics, full/empty status, source identity, ordering, and independent loss evidence.

`FW-USER-004` — User-configurable signal routing shall use the documented finite source and destination selections, authorization, staging, validation/commit, active readback, and conflict evidence.

`FW-USER-005` — Firmware shall not expose unrestricted clocks, resets, pads, privileged writes, host transport, safety activation, RTL hierarchy, or shared-buffer access through a user API.

`FW-USER-006` — Engineering tools may display generated, nonnormative names for permitted endpoints but shall retain the controlling numeric identity and shall not create a new endpoint.

# 19. Resource Management

## 19.1 Firmware Resources

Firmware resources include device contexts, command descriptors, transaction buffers, task stacks, timers, locks, deferred-work items, observations, application request queues, persistence buffers, and diagnostic records. Device queue and buffer capacities are observed resources, not firmware-owned memory.

## 19.2 Resource Requirements

`FW-RES-001` — The embedded profile shall support static or caller-supplied allocation for all steady-state mandatory services.

`FW-RES-002` — Dynamic allocation, if allowed during initialization, shall be complete before operational publication or shall have an explicit failure and fragmentation analysis.

`FW-RES-003` — Every firmware queue and storage pool shall have a declared capacity, admission rule, high-water evidence, and overflow disposition.

`FW-RES-004` — Firmware-side drops shall produce independent counters or durable records and shall never increment, replace, or be merged with a Dragon Core loss counter.

`FW-RES-005` — Resource exhaustion shall shed background and optional work before critical or high-priority work, subject to the approved deployment policy.

`FW-RES-006` — Buffer sizes, counts, offsets, duration arithmetic, and index calculations shall be checked for overflow and bounds before use.

`FW-RES-007` — Transaction and observation buffers containing stale or partially received data shall not be reused as valid output after an error.

`FW-RES-008` — Firmware shall not model the centralized Dragon Core shared-buffer allocation as host-addressable memory.

# 20. Performance Requirements

## 20.1 Ownership and Budgeting

Dragon Core performance and timing are owned by `DFC-PERF-0001` through `DFC-PERF-0026`. Firmware shall derive deployment budgets from the applicable controlling limits and selected configuration without copying those limits into a second normative table.

## 20.2 Firmware Performance Requirements

`FW-PERF-001` — Each deployment shall define and verify external deadlines for host-ready discovery, command completion, interrupt service, event drain, watchdog service, monitoring refresh, reconnect, reset recovery, and required persistence.

`FW-PERF-002` — Worst-case execution-time and blocking analysis shall include the command serializer, HAL, interrupt masking, critical sections, task scheduling, SPI transfers, response validation, reconciliation, and bounded retry or backoff.

`FW-PERF-003` — SPI utilization analysis shall account for simultaneous watchdog, interrupt, event, diagnostic, configuration, and application demand and shall reserve capacity for critical and high-priority work.

`FW-PERF-004` — Firmware shall measure or otherwise evidence command latency, queue occupancy, service latency, deadline miss, retry, reconciliation, event-drain rate, and persistence latency for the release profile.

`FW-PERF-005` — Performance optimization shall not remove validation, response integrity checking, serialization, active readback, evidence preservation, or ambiguity handling.

`FW-PERF-006` — A deployment whose measured or analyzed worst case cannot meet its configured watchdog or evidence-retention service policy shall fail readiness and shall not enter `FW_OPERATIONAL` with that policy enabled.

# 21. Error Handling

## 21.1 Error Classes and Disposition

| Error class | Examples | Required firmware disposition |
|---|---|---|
| Platform | SPI controller, timer, interrupt controller, RTOS, memory, or storage failure | Preserve device uncertainty; isolate the local cause; enter recovery or service-failed state |
| Transport | Short transfer, malformed response, CRC failure, timeout, response loss | Classify as definitive or ambiguous; reconcile state-changing work |
| Access and protection | Invalid address, reserved value, unauthorized or illegal access | Do not retry unchanged; report exact result and evidence |
| Configuration | Local schema, range, relation, capability, commit, or readback mismatch | Block dependents; retain desired object and prior confirmed active state |
| Resource | Busy, full, empty, overflow, underflow, drop, or backpressure | Apply bounded policy and preserve independent loss evidence |
| Device state | Startup, degraded, faulted, reset, test, loss of ready | Update lifecycle state; reacquire observations; do not trust stale cache |
| External interface | Adapter, transceiver, conditioning, wiring, or remote endpoint fault | Separate external-owner diagnosis from device and firmware evidence |
| Firmware | Invariant violation, queue loss, deadline miss, persistence failure, assertion, or memory error | Fail the affected service safely and preserve audit evidence |

## 21.2 Retry Rules

`FW-ERR-001` — Nondestructive reads may be retried only under a bounded policy after transport recovery.

`FW-ERR-002` — A state-changing operation may be retried only after definitive failure before effect or after reconciliation plus readback proves that duplication cannot occur.

`FW-ERR-003` — Busy and transient resource conditions shall use bounded backoff and a caller-visible deadline.

`FW-ERR-004` — The original error, every retry, and the terminal disposition shall remain linked in one operation record.

`FW-ERR-005` — Recovery shall capture required current state, sticky evidence, counters, terminal records, and retained events before clear, reset, or reapplication.

## 21.3 Reconnect and Reset Recovery

Firmware shall reestablish platform transport, rediscover identity and compatibility, read the host-reconciliation record when an operation was outstanding, acquire nondestructive state and evidence, determine reset scope where possible, invalidate affected caches, compare confirmed active configuration with the desired object, reapply lost volatile configuration through normal protected or staged paths, restart affected services, and confirm effective state before operational publication.

`FW-ERR-006` — A reset shall not be used as a general-purpose error retry.

`FW-ERR-007` — Module or safety-domain reset recovery shall invalidate only software state whose hardware owner lies within the observed reset scope; a system or external reset shall invalidate the complete device-side volatile view.

# 22. Security Considerations

## 22.1 Security Boundary

Dragon Core protected-write and production-test authorization are bounded hardware controls, not cryptographic authentication, secure boot, key storage, or an on-device software trust boundary, consistent with `PBIO-SEC-001` through `PBIO-SEC-003`.

## 22.2 Firmware Security Requirements

`FW-SEC-001` — External platform boot integrity, firmware authenticity, user identity, credential storage, process or task isolation, network security, least privilege, and audit policy shall remain external-host responsibilities.

`FW-SEC-002` — Only the device service or equivalent trusted firmware component shall own production SPI access; application components shall receive narrower typed capabilities.

`FW-SEC-003` — Protected-write keys shall be treated as protocol authorization values, not cryptographic secrets, and shall not bypass application authorization.

`FW-SEC-004` — Configuration and firmware artifacts shall be integrity-checked before activation. Release signing, if selected by project policy, shall be an external release control.

`FW-SEC-005` — Production-test, injection, raw-register, and destructive diagnostic capabilities shall exist only in separately identified engineering builds or profiles and shall require explicit authorization and audit evidence.

`FW-SEC-006` — Production firmware shall not reach an engineering-only function through an undocumented command, hidden flag, memory patch, or alternate SPI path.

`FW-SEC-007` — Externally supplied lengths, identifiers, configuration data, messages, and API requests shall be validated before allocation, indexing, conversion, or device access.

`FW-SEC-008` — Sensitive application context shall be redacted according to external policy without altering raw Dragon Core evidence fields.

# 23. Firmware APIs

## 23.1 API Families

| API family | Required purpose |
|---|---|
| Context and lifecycle | Create, initialize, discover, query compatibility, recover, shut down, and destroy one device context |
| Observation | Read typed current, sticky, counter, terminal, active, snapshot, queue, fault, and diagnostic state |
| Configuration | Validate desired objects; execute protected and staged operations; compare active readback |
| Interrupt and event | Schedule service, read source state, retrieve and hand off events, acknowledge, clear, or pop explicitly |
| Watchdog | Evaluate service readiness, request service, and obtain timing and result evidence |
| Communication | Receive, transmit, queue, sensor-update, recovery, GPIO, and routing operations |
| User resources | Mailbox and finite user-routing operations supported by the active capability profile |
| Diagnostics | Acquire raw transport evidence, counters, reset scope, clock status, loss evidence, and reconciliation results |

## 23.2 Common Result Model

Every state-changing API result shall contain or reference:

- operation identity and lifecycle generation;
- local admission and validation result;
- transport classification;
- definitive device result or ambiguity state;
- completed extent for multiword work;
- reconciliation outcome when used;
- applicable post-operation readback;
- timestamp and diagnostic reference; and
- caller-visible recovery disposition.

## 23.3 API Requirements

`FW-API-001` — Public APIs shall use opaque context handles, fixed-width integer types, explicit signedness, explicit units, and caller-visible deadlines.

`FW-API-002` — A Boolean success value alone is insufficient for a state-changing device operation.

`FW-API-003` — Read APIs shall be nondestructive unless their name and contract explicitly identify a pop, acknowledge, clear, commit, service, reset, or other side effect.

`FW-API-004` — APIs shall distinguish desired, staged, active, requested, commanded, effective, raw, synchronized, qualified, current, sticky, pending, historical, terminal, cached, derived, and stale values as applicable.

`FW-API-005` — Reserved bits shall be written as required by the generated contract; helpers shall not silently preserve, set, clear, or normalize an unauthorized value.

`FW-API-006` — Counter-clear, bitwise W1C, acknowledgement, snapshot, pop, push, commit, service, recovery, and reset operations shall use distinct typed functions.

`FW-API-007` — An API that returns a borrowed buffer or observation shall define ownership, immutability, lifetime, alignment, and concurrency behavior.

`FW-API-008` — Callback execution context and reentrancy shall be documented. A callback shall not recursively initiate a device transaction unless the API explicitly schedules it through the coordinator.

`FW-API-009` — Breaking API changes require a major version change; compatible additions require a minor change; behavior-preserving corrections require a patch change.

`FW-API-010` — Exact generated bindings shall be selected by validated compatibility, not filename similarity, product-name similarity, or best effort.

# 24. Verification Requirements

## 24.1 Verification Strategy

Firmware verification shall include static analysis, unit tests, component tests with controlled doubles, integration tests with an independent device model or RTL simulation, host-conformance tests, FPGA validation, HIL tests, regression tests, coverage analysis, and release-profile timing evidence as applicable.

Host-boundary verification shall consume the methods, environments, outcomes, and evidence definitions of `RCA-DFC-VP-002`, including `VP-GEN-016` through `VP-GEN-018`, scope V5, method `T-HOST`, environment EV-16, `VP-HIL-001` through `VP-HIL-008`, and `VP-COV-016` through `VP-COV-020`. Firmware-only tests may add cases but shall not redefine a controlling VP case.

## 24.2 Mandatory Scenarios

Verification shall cover at least:

- cold firmware start with Dragon Core already ready, still starting, faulted, and unavailable;
- exact compatibility, unknown revision, missing capability, and reserved encoding;
- pre-change evidence capture and prohibition of premature writes;
- complete desired-configuration validation, protected operation, staged commit, rejection, partial progress, and active readback mismatch;
- simultaneous interrupts, new source during service, persistent active source, and polling fallback;
- event snapshot, persistence or handoff, pop, overflow, producer loss, unknown identifier, and ambiguous pop;
- response loss before acceptance and after acceptance, invalid CRC, truncation, partial multiword completion, host reconciliation, and retry prohibition;
- host disconnect and reconnect while autonomous hardware behavior continues;
- module, safety-domain, system, and external reset recovery with correct cache invalidation;
- watchdog legal service, early or late service, deadline failure, ambiguous service, and service suspension;
- receive and transmit empty, full, overflow, underflow, rejection, bus-off, and partial-entry prevention;
- mask-defined user-resource restrictions and invalid route selection;
- firmware queue exhaustion, persistence failure, platform-timer failure, and software invariant violation;
- production and engineering capability isolation; and
- equivalent logical behavior across every supported HAL profile.

## 24.3 Verification Rules

`FW-VER-001` — Every normative `FW-*` requirement shall trace to implementation and at least one verification case or justified analysis.

`FW-VER-002` — Expected results shall derive from controlling specifications and an independent oracle, not from reusing the production encoder, decoder, or observed implementation output as its own expectation.

`FW-VER-003` — Tests shall be self-checking and shall produce unambiguous pass, fail, blocked, and not-applicable outcomes.

`FW-VER-004` — Fault injection and production-test operations shall use documented authorized paths and engineering profiles only.

`FW-VER-005` — Required test evidence shall identify firmware build, generated bindings, device or model build, desired configuration, platform, fixture, test case, seed when applicable, timing source, result, and retained artifacts.

`FW-VER-006` — Regression shall run after changes to source, generated inputs, generator, HAL, compiler, linker, dependencies, configuration schema, controlling specification, or target platform.

`FW-VER-007` — FPGA-only observability may support diagnosis but shall not be the sole oracle for a production-interface requirement.

`FW-VER-008` — Verification shall demonstrate that no on-device processor, boot firmware, firmware memory, or firmware-dependent device startup assumption exists in the delivered implementation or documentation.

## 24.4 Coverage and Completion

Coverage shall include normative-requirement coverage, API and component coverage, error and transition coverage, boundary-value coverage, concurrency and ordering coverage, and applicable statement, branch, condition, and function coverage. Numeric coverage thresholds, if required, shall be set by the project software verification or assurance plan rather than invented here.

# 25. Formal Verification Objectives

## 25.1 Scope

Formal methods are encouraged for bounded firmware logic whose state and environment assumptions can be modeled soundly. Formal results supplement, not replace, dynamic testing and do not establish conformity of Dragon Core RTL unless performed under the controlling hardware verification plan.

## 25.2 Candidate Properties

| Property area | Objective |
|---|---|
| Lifecycle | `FW_OPERATIONAL` is unreachable before compatibility, active configuration, and mandatory service readiness |
| Serialization | At most one command owns the device transport at a time |
| Protected sequence | No unrelated command interleaves between authorization and protected target completion |
| Staging and commit | Staged state is never published as active before successful commit and readback |
| Reconciliation | An ambiguous state-changing command is never blindly retried |
| Event retrieval | A record is not popped before required persistence or handoff |
| Watchdog | Service is not intentionally issued outside the configured legal scheduling policy |
| Resource bounds | Queue indices, counts, and buffer accesses remain within declared bounds |
| State distinction | Firmware state never overwrites or aliases device primary state or independent qualifiers |
| Engineering isolation | Production profile cannot reach raw, test, or injection capabilities |

## 25.3 Formal-Method Requirements

`FW-FORMAL-001` — Each proof shall identify assumptions, environment model, property, bounded or unbounded scope, tool and version, result, coverage, and unresolved limitations.

`FW-FORMAL-002` — Assumptions shall not exclude a legal error, reset, response loss, concurrency condition, or reserved input solely to make the property provable.

`FW-FORMAL-003` — A proof failure or vacuous proof shall be treated as unresolved until the property, model, implementation, or controlling ambiguity is corrected and reverified.

`FW-FORMAL-004` — Formal models shall use independent abstractions of the controlling contract and shall not silently import a defect from production source.

# 26. Development Environment

## 26.1 Language and Portability Baseline

The portable firmware core shall use ISO/IEC 9899:2018 C17. Platform-specific assembly or compiler intrinsics may be used only inside the HAL/BSP when required by the selected host and shall have a portable test double or equivalent verification boundary. C++ shall not be required by the portable firmware interface; a C++ application binding may wrap the C API without changing its semantics.

## 26.2 Controlled Toolchain

Each controlled build shall identify:

- source and submodule revisions;
- generator and machine-readable register-source revisions;
- compiler, assembler, linker, archiver, build system, and static-analysis tool versions;
- target processor, ABI, RTOS or bare-metal profile, memory model, and linker layout;
- compile, link, feature, warning, optimization, and instrumentation options;
- third-party dependencies and licenses;
- test configuration and hardware or model identity; and
- reproducibility manifest and artifact digests.

## 26.3 Development Rules

`FW-DEV-001` — Generated register artifacts shall be regenerated from controlled source and shall not be hand edited.

`FW-DEV-002` — The build shall fail on generated-definition mismatch, duplicate identifiers, unresolved required references, incompatible manifest selection, or stale generated output.

`FW-DEV-003` — Release builds shall treat enabled compiler diagnostics and project-selected static-analysis violations according to documented severity policy; blanket suppression is prohibited.

`FW-DEV-004` — Formatting, lint, static analysis, unit tests, component tests, integration tests, generated-consistency checks, and manifest creation shall be automated.

`FW-DEV-005` — Production and engineering build graphs shall be separate enough that test, injection, raw-access, and diagnostic backdoor objects cannot enter a production image accidentally.

`FW-DEV-006` — Reproducible-build verification shall compare release artifacts produced from the same controlled inputs or document every unavoidable nondeterministic field.

`FW-DEV-007` — Tool qualification or certification credit shall not be claimed unless established by a separate approved assurance plan.

# 27. Deliverables

## 27.1 Required Deliverables

| Deliverable | Required content |
|---|---|
| Firmware specification | This approved Revision B document |
| Source | Portable core, HAL interfaces, selected HAL/BSP implementations, driver, services, and API |
| Generated artifacts | Host bindings, validation metadata, event/source definitions, and provenance manifest |
| Build system | Controlled generation, compilation, analysis, test, packaging, and reproducibility automation |
| Configuration package | Schema, validated defaults or examples, migration tools, target declarations, and integrity metadata |
| Verification package | Tests, independent models or fixtures, results, coverage, timing evidence, anomalies, and trace |
| API documentation | Lifecycle, data semantics, side effects, concurrency, deadlines, errors, compatibility, and examples |
| Integration documentation | HAL contract, platform assumptions, memory and scheduling budgets, startup, recovery, and security profile |
| Release package | Images or libraries, manifest, digests, release notes, compatibility declaration, licenses, and known limitations |

## 27.2 Delivery Requirements

`FW-DEL-001` — Every delivered binary, library, generated file, configuration object, and verification result shall be traceable to the release manifest.

`FW-DEL-002` — Documentation and examples shall use typed APIs, active readback, explicit side effects, and evidence-preserving recovery; they shall not demonstrate copied register constants or blind retry.

`FW-DEL-003` — No deliverable shall imply that firmware executes inside Dragon Core or owns a hardware safety function.

`FW-DEL-004` — Only complete, internally consistent, validated release artifacts shall be placed in the baseline release package.

`FW-DEL-005` — Known limitations shall distinguish firmware limitations, host-platform limitations, board or external-interface limitations, and device limitations.

# 28. Exit Criteria

Revision B specification and its conforming firmware implementation are ready for baseline only when all applicable criteria below are satisfied:

- all 29 sections are present and internally consistent;
- every normative `FW-*` identifier is unique and traceable;
- all controlling and software-architecture references resolve;
- no on-device processor, firmware runtime, software memory, firmware-controlled hardware boot, alternate host path, or firmware-owned hardware safety algorithm is implied;
- generated definitions match the controlled Register Map source;
- startup, compatibility, configuration, active readback, serialization, ambiguous-outcome reconciliation, interrupt/event service, watchdog policy, reconnect, reset recovery, and evidence retention are complete;
- current, sticky, counter, pending, terminal, staged, active, requested, commanded, effective, cached, derived, and stale states remain distinct;
- static analysis and required build checks pass under the approved severity policy;
- required unit, component, integration, host-conformance, FPGA, HIL, regression, coverage, and timing evidence passes or is formally dispositioned as not applicable;
- production and engineering capabilities are demonstrably isolated;
- no release-blocking defect, unresolved interface ambiguity, or controlling-specification change flag remains; and
- release artifacts, manifests, traceability, documentation, and approvals are complete.

`FW-EXIT-001` — A firmware release may claim conformity to this specification only when its exact source, generated-binding, target-profile, configuration, verification, and release-manifest identities satisfy the approved exit evidence.

`FW-EXIT-002` — A failed, blocked, waived, or not-applicable verification outcome shall remain explicit and shall not be converted to pass by omission or aggregation.

# 29. Baseline Statement

## 29.1 Baseline Declaration

RCA-DFC-SW-002 Revision B is the implementation specification baseline for Dragon Core external embedded-host firmware. It supersedes Revision A for all firmware-development, verification, release, and maintenance use.

## 29.2 Governing Relationship

This specification remains subordinate to the eight controlling specifications identified by `RCA-DFC-CHTR-002`, Section 3.1 and implements the external embedded-host profile of `RCA-DFC-SW-001` Revision C. It creates no alternate product, boundary, externally observable behavior, internal architecture, register, verification, RTM, or RTL definition.

## 29.3 Fixed Baseline Conclusions

- Dragon Core is processor-free and contains no firmware, as controlled by `CHTR-TECH-001` through `CHTR-TECH-005` and `CHTR-EXCL-002`.
- The firmware configuration item executes entirely on an external host processor.
- Firmware uses one SRS-defined SPI transport and one Register-Map-defined host-visible contract through generated bindings.
- Dragon Core hardware owns deterministic startup, device behavior, retained evidence, and allocated safety supervision.
- Firmware owns external initialization workflow, configuration policy, persistence, orchestration, API behavior, host recovery, and software evidence.
- Ambiguous state-changing operations are reconciled and read back; they are never blindly retried.
- Hardware and firmware states, and current, sticky, pending, counter, terminal, staged, active, requested, commanded, effective, cached, derived, and stale values remain distinct.
- Production and engineering capabilities remain isolated.

## 29.4 Controlling-Specification Disposition

No change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` is required to establish this Revision B firmware baseline.

## 29.5 Change Control

Any future change to firmware component allocation, lifecycle behavior, API semantics, concurrency, persistence, compatibility, security, timing policy, or verification obligations shall revise this specification and complete downstream impact analysis. A change requiring new device behavior, register meaning, interface behavior, verification definition, trace relationship, or RTL rule shall first revise the applicable controlling owner.

## 29.6 Approval Statement

Upon approval, this document is ready for direct placement beneath the eight controlling Dragon Flight specifications as `RCA-DFC-SW-002_Dragon_Flight_Embedded_Firmware_Specification_RevB.md`.
