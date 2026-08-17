**DRAGON FLIGHT™ AIRCRAFT SIMULATION SOFTWARE SPECIFICATION**

Document Number: RCA-DFC-SW-011  
Revision: A  
Status: Technical Baseline  
Product: Dragon Core™ Revision A  
Program: Dragon Flight™ Core ASIC Development Program  
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | 2026-08-09 | Initial Dragon Flight Aircraft Simulation software baseline; includes the second VisionFive 2 embedded simulation host and the aircraft-side ULX3S/ECP5-85F FPGA-validation profile | Royal Cubit Aerospace |

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
5. Aircraft Simulation Configuration Item Identification
6. Authority, Ownership, and Product Boundary
7. Operational Roles and Application Profiles
8. Execution and Deployment Environment
9. Software Architecture
10. Process, Thread, and Scheduling Model
11. Simulation Session and Lifecycle Model
12. Second VisionFive 2 Platform Integration
13. ULX3S/ECP5-85F Aircraft-Side UUT Integration Profile
14. Aircraft-Side Interconnect and Fixture Profile
15. Startup, Discovery, and Compatibility
16. Aircraft Simulation Operating-State Model
17. Simulation Time and Synchronization
18. Aircraft, Environment, and Dynamics Models
19. Scenario and Campaign Definition
20. Input-Stimulus Synthesis and Qualification
21. Aircraft-Side Digital Interface Services
22. Output Observation and Closed-Loop Response
23. Fault and Anomaly Injection
24. Dragon Console and Test-Director Coordination
25. Ambiguous Fixture-Command Outcome and Reconciliation
26. Disconnect, Reset, and Recovery
27. FPGA/HIL Validation and Deterministic Replay
28. Data Model and Persistence
29. Logging, Audit, and Evidence Export
30. Human and Automation Interfaces
31. Security and Access Control
32. Concurrency and Resource Management
33. Timing and Performance
34. Error Handling and Degraded Operation
35. Portability and Production Separation
36. Internal and External Software Interfaces
37. Schema, Model, and Compatibility Versioning
38. Software Verification and Validation
39. Traceability and Change Control
40. Build, Package, Deployment, and Release
41. Deliverables
42. Exit Criteria
43. Baseline Statement


# 1. Purpose

This specification defines Dragon Flight Aircraft Simulation, an external embedded application that supplies deterministic aircraft, environment, databus, sensor, discrete, and fault stimulus for Dragon Core Revision A FPGA and hardware-in-the-loop validation. The application executes on a second VisionFive 2 single-board computer and connects through controlled fixtures and adapters to the aircraft-side logical interfaces of an ULX3S board populated with an ECP5-85F FPGA acting as the unit under test (UUT).

The first VisionFive 2 running Dragon Console remains the exclusive Dragon Core validation host for the SPI command/data path and host-interrupt reception. The second VisionFive 2 defined here is an external test-equipment controller. It shall not become a second SPI master, an alternate host-register path, or an owner of Dragon Core hardware behavior.

The Aircraft Simulation shall generate repeatable open-loop and closed-loop scenarios, stimulate documented digital inputs, observe documented digital outputs, emulate permitted external protocol endpoints, control approved fault fixtures, correlate observations, and produce reproducible evidence. It may model aircraft behavior for test purposes, but it is not flight software, an aircraft application computer, a production aircraft simulator, or a certification authority.

This specification owns only Aircraft Simulation software behavior, model execution, scenario control, stimulus synthesis, fixture coordination, external-side protocol behavior, observation, application data, persistence, security, platform use, and software verification. It does not own or redefine Dragon Core behavior, logical interfaces, register behavior, verification cases, RTL, FPGA wrappers, board wiring, transceiver behavior, electrical characteristics, or aircraft assurance.

`DFAS-PUR-001` — Aircraft Simulation shall execute entirely outside Dragon Core and shall interact with the UUT only through documented aircraft-side logical boundaries and approved external fixtures.

`DFAS-PUR-002` — Aircraft Simulation shall preserve the independent ownership of device behavior, FPGA integration, board/fixture behavior, external protocol-endpoint behavior, model behavior, and verification outcomes.

`DFAS-PUR-003` — A simulation result shall not be represented as proof of aircraft airworthiness, flight-model fidelity beyond its approved validation, or conformity of behavior outside the tested Dragon Core boundary.

`DFAS-PUR-004` — The same scenario, model, stimulus, observation, and evidence semantics shall be usable with a conforming FPGA or fabricated-device test environment through declared adapters.

# 2. Scope

## 2.1 Included Scope

This specification covers:

- the Aircraft Simulation executable, platform-neutral libraries, model packages, scenario engine, fixture adapters, protocol endpoints, and evidence services;
- deployment on the second VisionFive 2 single-board computer;
- the aircraft-side ULX3S/ECP5-85F UUT profile;
- independent open-loop, coordinated open-loop, and bounded closed-loop execution;
- deterministic simulation time, real-time pacing, pause, resume, step, and replay;
- versioned aircraft, propulsion, rotor, environment, sensor, discrete, databus-peer, load, and fault models;
- synthesis of rotor, engine, pulse/frequency, health/discrete, GPIO, user-input, ARINC 429 receive, CAN receive, UART receive, and external error indications when present in the approved interface profile;
- observation of GPIO, user, ARINC 429 transmit, CAN transmit, UART transmit, logical safety outputs, and fixture status when present in the approved interface profile;
- controlled protocol endpoint emulation, backpressure, traffic generation, response behavior, and error generation;
- safe external loads, loopbacks, analyzers, transceivers, conditioning, and fault-injection fixture control through declared adapters;
- coordination with Dragon Console or an authorized test director without sharing SPI ownership;
- scenario campaigns, deterministic seeds, expected-result bindings, raw captures, comparison, persistence, audit, evidence export, and release identification;
- security, resource bounds, error handling, recovery, portability, verification, build, deployment, and release requirements; and
- strict separation of validation-only simulation features from production external-host software.

## 2.2 Excluded Scope

The following are excluded:

- any processor, executable software, runtime, model, or storage inside Dragon Core;
- SPI-master operation, host-interrupt ownership, direct register access, device configuration, device diagnostics, or host reconciliation owned by Dragon Console and the Dragon SDK;
- redefinition of a Dragon Core input, output, timing, protocol, state, fault, safety, register, or verification requirement;
- FPGA RTL, ECP5 wrapper logic, bitstream generation, ULX3S constraints, board pin mapping, clock generation, reset implementation, or validation-only hardware observability;
- electrical design, analog conditioning, ADC/DAC behavior, transceiver hardware, voltage translation, termination, isolation, protection, power sequencing, connectors, and wiring;
- activation of real aircraft actuators, aircraft energy, propulsion equipment, flight surfaces, or safety loads;
- operational flight control, navigation, guidance, mission management, pilot training, certified aircraft dynamics, or operational decision making;
- production-test ownership except control of an expressly approved external fixture interface;
- qualification of the first VisionFive 2 host, Dragon Console, Dragon SDK, or Dragon Core device beyond evidence allocated by an approved verification procedure; and
- aircraft certification, installation approval, operational authorization, or aircraft-level safety assessment.

## 2.3 Intended Use

Aircraft Simulation is a laboratory verification application for FPGA bring-up, external digital-interface validation, HIL execution, regression, fault campaigns, endurance campaigns, and later post-silicon reuse. It shall operate only in a controlled test environment with fixture-safe outputs and identified UUT, software, model, scenario, wiring, and instrumentation baselines.

`DFAS-SCOPE-001` — The second VisionFive 2 shall not be connected or configured as an independent Dragon Core SPI master while Dragon Console owns the UUT session.

`DFAS-SCOPE-002` — Aircraft Simulation shall not depend on a testbench backdoor, RTL hierarchy, wrapper-private register, hidden FPGA state, or undocumented pad behavior.

`DFAS-SCOPE-003` — Software-derived aircraft meaning shall remain distinct from raw logical-boundary observations and shall not alter the controlling meaning of a Dragon Core signal.

`DFAS-SCOPE-004` — Engineering convenience shall not weaken fixture interlocks, output limits, compatibility checks, evidence custody, or ambiguous-command recovery.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and sole normative ownership of the controlling set are defined only by `RCA-DFC-CHTR-002`, Section 3.1. The following table is an informative Aircraft Simulation use view and creates no alternate precedence.

| Document | Aircraft Simulation use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product mission, exclusions, selected ECP5 and VisionFive 2 platform classes, external-host model, and single-owner rules |
| `RCA-DFC-PBIO-002.md` | Device, software, FPGA, board, aircraft, test-equipment, interface, data, safety, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior, aircraft-side logical interfaces, timing, performance, safety, and reliability requirements |
| `RCA-DFC-ARCH-002.md` | Logical wrapper interface, signal ownership, timing interpretation, protocol behavior, clocks, resets, and internal contracts needed by verification |
| `RCA-DFC-REG-002.md` | Host-visible programming contract consumed indirectly through coordinated test configuration and evidence; not an Aircraft Simulation access interface |
| `RCA-DFC-VP-002.md` | Sole normative source for verification methods, environments, cases, outcomes, and evidence definitions |
| `RCA-DFC-RTM-002.md` | Sole normative source for relationships among controlling technical identifiers |
| `RCA-DFC-RTL-STD-002.md` | RTL implementation rules used to classify UUT evidence; not an Aircraft Simulation coding standard |

## 3.2 Governing Software Specifications

| Document | Governing relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | External software architecture and FPGA-development software allocation |
| `RCA-DFC-SW-002`, Revision B | External embedded-application lifecycle, bounded execution, and target behavior |
| `RCA-DFC-SW-003`, Revision B | HAL/BSP patterns and typed result conventions when reused by platform or fixture adapters |
| `RCA-DFC-SW-004`, Revision B | Software coding and implementation standard |
| `RCA-DFC-SW-005`, Revision B | Software verification and validation requirements |
| `RCA-DFC-SW-006`, Revision B | Build, package, deployment, release, manifest, integrity, and archival requirements |
| `RCA-DFC-SW-007`, Revision A | Dragon Console ownership of the first VisionFive 2, SPI host path, device configuration, and host-side validation workflows |
| `RCA-DFC-SW-010`, Revision A | Reusable SDK types, test-support patterns, model separation, and compatibility rules where applicable |

## 3.3 Historical Reference

No historical Aircraft Simulation specification was supplied or used. This Revision A specification is newly derived from the controlling technical specifications and governing software baseline.

## 3.4 Authority and Single-Definition Rules

`DFAS-DOC-001` — Aircraft Simulation shall apply `CHTR-DOC-001` through `CHTR-DOC-007`.

`DFAS-DOC-002` — Signal identity, direction, width, polarity, protocol, timing, safe state, and legal behavior shall be obtained from the owning specification or a generated interface artifact and shall not be independently hand-defined in model or fixture code.

`DFAS-DOC-003` — A scenario, model, fixture profile, expected-result table, capture decoder, script, display, or report shall not establish Dragon Core behavior absent from a controlling specification.

`DFAS-DOC-004` — Simulation models may define external aircraft-side behavior only; they shall not become alternate models of undocumented Dragon Core internal behavior.

`DFAS-DOC-005` — If implementation or verification exposes a conflict, ambiguity, omission, unreachable outcome, or unimplementable contract, dependent work shall stop and the owning specification shall be corrected before software invents a substitute.

## 3.5 Controlling-Specification Change Flags

No change to a controlling specification is required to establish this Revision A baseline.

The controlling set already assigns external physical stimulus, capture, equipment timing, protocol-endpoint behavior, and interpretation to external test, board, aircraft, and software owners while defining the common ECP5 logical wrapper and FPGA/HIL verification environments. This specification selects a second VisionFive 2 as the embedded controller for those external responsibilities. The selection does not redefine the Charter-selected primary validation host, create a second product platform, or alter Dragon Core behavior.

Exact ULX3S board revision, ECP5-85F package, FPGA wrapper, constraints, pin mapping, interconnect, adapter hardware, transceivers, fixture logic, calibration, and safe-load definitions remain separately controlled integration inputs.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition in this specification |
|---|---|
| Aircraft-side boundary | Documented logical UUT interfaces representing connections toward external aircraft sensors, buses, discretes, loads, and equipment; excludes the SPI host and host-interrupt interfaces. |
| Aircraft Simulation | The software configuration item defined by this specification. |
| Ambiguous fixture outcome | A state-changing fixture command for which software cannot prove whether the commanded external effect occurred. |
| Campaign | A versioned collection of scenarios, configurations, expected outcomes, evidence requirements, and completion rules. |
| Closed loop | Execution in which observed UUT outputs influence later external-model state or stimulus under a declared causal and timing model. |
| Dragon Console | The SW-007 application on the first VisionFive 2 that exclusively owns the UUT SPI and host-interrupt paths. |
| External model | A software model of aircraft, environment, sensor, bus-peer, load, or operator behavior outside Dragon Core. |
| Fixture | Controlled hardware or firmware external to the UUT that performs electrical adaptation, signal generation, capture, loading, isolation, or fault injection. |
| HIL | Hardware in the loop. |
| Open loop | Execution in which scheduled stimulus does not depend on observed UUT outputs. |
| Real-time factor | Ratio of simulation-time advance to host monotonic-time advance during paced execution. |
| Scenario | A versioned initial condition, model configuration, ordered action set, timing plan, expected-result binding, and termination rule. |
| Second VisionFive 2 | The embedded computer dedicated to Aircraft Simulation and aircraft-side fixture control; distinct from the first VisionFive 2 running Dragon Console. |
| Simulation time | Logical time used by scenario and models; distinct from UUT time, host monotonic time, synchronized wall time, and capture-instrument time. |
| Stimulus epoch | Monotonic simulation-owned identifier for one applied set of external inputs and its associated observations. |
| UUT | ULX3S board containing the identified ECP5-85F Dragon Core FPGA realization under test. |

Device-side terminology, units, identifiers, encodings, capacities, and timing retain the definitions of their controlling owners.

# 5. Aircraft Simulation Configuration Item Identification

## 5.1 Software Configuration Items

| Configuration item | Purpose | Execution or storage location |
|---|---|---|
| `dragon_aircraft_sim` | Main embedded application, lifecycle coordinator, scenario control, model execution, and evidence workflow | Second VisionFive 2 |
| `dragon_aircraft_sim_core` | Platform-neutral scheduler, state machines, time service, model graph, scenario engine, and policy enforcement | Linked application library |
| `dragon_aircraft_models` | Versioned aircraft, propulsion, rotor, environment, sensor, load, and bus-peer model packages | Controlled host storage |
| `dragon_aircraft_fixture_api` | Typed fixture, adapter, signal-source, analyzer, load, and injection interfaces | Linked application library |
| `dragon_aircraft_vf2` | Second VisionFive 2 operating-system, time, I/O, storage, network, and process-supervision adapter | Second VisionFive 2 |
| `dragon_aircraft_ulx3s_profile` | Aircraft-side ULX3S/ECP5-85F UUT, wiring, fixture, capability, and safety profile | Controlled host storage |
| `dragon_aircraft_scenarios` | Versioned scenarios, campaigns, expected-result bindings, and deterministic seeds | Controlled host storage |
| `dragon_aircraft_evidence` | Schemas, serializers, capture correlation, integrity metadata, and exporters | Controlled host storage |
| `dragon_aircraft_cli` | Local human administration and controlled interactive operation | Second VisionFive 2 |
| `dragon_aircraft_automation` | Test-director and automated campaign interface | Second VisionFive 2 |
| `dragon_aircraft_tests` | Unit, component, integration, target, fixture, regression, and acceptance tests | Verification environments |

## 5.2 Identification Requirements

`DFAS-CI-001` — Every executable, library, model package, scenario package, fixture adapter, and schema shall identify its semantic version, source revision, build identifier, profile, toolchain, dependencies, and governing revisions.

`DFAS-CI-002` — Each run shall identify Aircraft Simulation release, model set, scenario, deterministic seed, second VisionFive 2 profile, UUT image, FPGA wrapper, constraint set, board, fixture, wiring, calibration/status, instrumentation, Dragon Console release, and controlling-source revisions as independent values.

`DFAS-CI-003` — A filename, timestamp, board label, model name, or campaign name alone shall not establish compatibility or evidence identity.

`DFAS-CI-004` — Engineering, FPGA/HIL, fault-injection, endurance, replay, and production-safe-disabled profiles shall have distinct machine-readable identities.

# 6. Authority, Ownership, and Product Boundary

## 6.1 Responsibility Allocation

| Subject | Aircraft Simulation owns | Aircraft Simulation shall not own |
|---|---|---|
| External models | Model state, equations, approximations, declared fidelity, and validation evidence | Dragon Core state or aircraft certification |
| Scenario policy | Initial conditions, stimulus schedule, external responses, expected-result references, and termination | Device requirements or controlling VP case outcomes |
| Stimulus | Requested logical values, timing, protocol endpoint behavior, and provenance | Electrical realization or UUT acceptance behavior |
| Observation | Acquisition scheduling, external capture, freshness, correlation, and derived external interpretation | Device output generation or hidden internal state |
| Fixture control | Typed command, authorization, state tracking, health checking, and reconciliation | Fixture electrical design, calibration authority, or undocumented UUT access |
| Validation contribution | Scenario orchestration and software/fixture evidence | Sole pass/fail authority for Dragon Core conformity |
| Safety | Fixture-safe software limits, interlocks, and controlled shutdown requests | Dragon Core hardware safety or real aircraft-energy control |

## 6.2 Boundary Requirements

`DFAS-BND-001` — Aircraft Simulation shall address interfaces by generated logical identity and declared fixture mapping, not by unreviewed operating-system node names or physical-pin literals in portable logic.

`DFAS-BND-002` — Electrical adaptation, analog conversion, line transceivers, protection, isolation, termination, loading, and wiring shall remain identified external fixture responsibilities.

`DFAS-BND-003` — The software shall label commanded stimulus, fixture-reported applied state, independently observed boundary state, UUT output, and model-derived interpretation as distinct data classes.

`DFAS-BND-004` — A model or fixture failure shall not be reported as a Dragon Core pass, fail, fault, or output unless the applicable evidence objectively supports that classification.

`DFAS-BND-005` — Aircraft Simulation shall never request or enable connection to a real aircraft-energy load in the Revision A FPGA-validation profile.

`DFAS-BND-006` — Host failure, simulator termination, missed deadlines, or loss of coordination shall not be represented as transferring Dragon Core hardware safety responsibility to software.

# 7. Operational Roles and Application Profiles

## 7.1 Roles

| Role | Minimum permitted scope |
|---|---|
| Observer | View identities, model state, scenario state, stimulus, captures, health, and evidence |
| Simulation operator | Load approved model/scenario packages and execute nondestructive campaigns |
| Validation engineer | Configure approved fixtures, execute FPGA/HIL cases, and authorize bounded external stimulus |
| Fault-injection engineer | Validation-engineer scope plus specifically approved fault actions under fixture-safe conditions |
| Administrator | Install releases, manage profiles, roles, keys, storage, and audit; no implicit run authority |
| Automation identity | Explicit campaign and command allowlist without interactive privilege inheritance |

## 7.2 Application Profiles

| Profile | Required disposition |
|---|---|
| Dry run | Models and scenario validation without physical UUT stimulus |
| Open-loop FPGA | Scheduled aircraft-side stimulus and output capture |
| Closed-loop FPGA/HIL | Declared UUT-output feedback into external models |
| Fault injection | Approved fixture and protocol faults with enforced safe envelope |
| Endurance | Long-duration bounded traffic, monitoring, loss, and recovery campaign |
| Replay | Recorded or regenerated deterministic stimulus with controlled comparison |

`DFAS-PROF-001` — Effective authority shall be the intersection of build profile, runtime profile, authenticated role, UUT compatibility, fixture readiness, scenario authorization, and current application state.

`DFAS-PROF-002` — Fault injection, electrical contention, output-affecting loopback, and fixture override shall be denied unless explicitly present in the selected profile and scenario authorization.

`DFAS-PROF-003` — Missing, invalid, or incompatible profile data shall reduce capability and shall never enable an engineering action by fallback.

# 8. Execution and Deployment Environment

## 8.1 Baseline Environment

The Revision A target is a dedicated second VisionFive 2 running a controlled embedded Linux or conforming real-time environment. Required platform services include process supervision, monotonic time, optional synchronized time, bounded memory, controlled storage, network isolation, authenticated local administration, fixture I/O, and evidence transfer.

## 8.2 Deployment Requirements

`DFAS-ENV-001` — The target image shall identify operating-system image, kernel, runtime, drivers, device tree, service configuration, network policy, installed package manifest, and security baseline.

`DFAS-ENV-002` — The second VisionFive 2 shall be provisioned independently from the first VisionFive 2 and shall not inherit its SPI device permissions or host-interrupt ownership.

`DFAS-ENV-003` — The runtime shall provide monotonic time with measured resolution and drift, bounded scheduling behavior, controlled storage, and health supervision sufficient for the selected scenario timing class.

`DFAS-ENV-004` — Unsupported background services, automatic updates, frequency-scaling behavior, and network traffic that can invalidate required timing shall be disabled or bounded by the controlled image.

`DFAS-ENV-005` — Evidence and configuration storage shall detect exhaustion, read-only transition, corruption, and write failure before required evidence is silently lost.

`DFAS-ENV-006` — Application restart shall not automatically resume physical stimulus or fault injection.

# 9. Software Architecture

## 9.1 Logical Components

| Component | Responsibility |
|---|---|
| Lifecycle coordinator | Compatibility, run admission, state transitions, recovery, and shutdown |
| Time coordinator | Simulation time, pacing, synchronization, deadlines, epochs, and time-quality records |
| Scenario engine | Validated action graph, preconditions, branching, assertions, termination, and campaign sequencing |
| Model runtime | Deterministic execution of aircraft, environment, sensor, load, and bus-peer models |
| Stimulus synthesizer | Conversion of validated model/scenario outputs to typed logical-boundary requests |
| Fixture service | Serialization, command/result tracking, health, safe state, capture, and reconciliation |
| Protocol endpoint service | External ARINC, CAN, UART, pulse, discrete, and GPIO endpoint behavior |
| Observation service | Raw capture, decoding, freshness, ordering, correlation, and loss accounting |
| Closed-loop coordinator | Causal transfer of qualified observations into later model steps |
| Fault manager | Authorized external fault plans, interlocks, activation, verification, and removal |
| Coordination service | Authenticated synchronization with Dragon Console or test director |
| Evidence service | Structured records, raw captures, hashes, exports, and retention |
| Platform adapter | Second VisionFive 2 time, I/O, storage, networking, and process integration |

## 9.2 Dependency Rules

`DFAS-ARCH-001` — Models and scenarios shall request semantic aircraft-side quantities or logical signals and shall not directly call operating-system drivers or manipulate fixture transport frames.

`DFAS-ARCH-002` — All physical stimulus and capture shall pass through one fixture service per controlled endpoint.

`DFAS-ARCH-003` — Portable model logic shall be independent of ULX3S pin numbers, ECP5 primitives, VisionFive 2 device nodes, and fixture transport encodings.

`DFAS-ARCH-004` — Protocol endpoint models shall be separated from physical transceiver adapters and from Dragon Core protocol implementations.

`DFAS-ARCH-005` — Validation-only and fault-injection dependencies shall remain outside any production external-host package dependency graph.

## 9.3 Failure Containment

`DFAS-ARCH-006` — A user-interface, exporter, report, or network-client failure shall not bypass stimulus serialization, fixture interlocks, evidence capture, or controlled shutdown.

`DFAS-ARCH-007` — Failure of one optional model or interface shall stop dependent scenario actions and shall not silently substitute stale or default stimulus.

`DFAS-ARCH-008` — A coordination-client disconnect shall not create an implicit scenario retry, fixture retry, fault removal, or continuation.

# 10. Process, Thread, and Scheduling Model

## 10.1 Execution Model

The software may use one process or a supervised process set. At minimum it shall provide logical activities for lifecycle/command coordination, paced model execution, fixture I/O, capture processing, evidence writing, health supervision, and human or automation requests.

## 10.2 Scheduling Requirements

`DFAS-EXEC-001` — One simulation session shall permit at most one active scenario action that changes a given physical endpoint or fixture state at a time.

`DFAS-EXEC-002` — Model deadlines, stimulus deadlines, capture service, fixture health, safe-state actions, and evidence-loss detection shall receive priority independent of UI or report activity.

`DFAS-EXEC-003` — Rendering, export, compression, and slow storage shall not execute while holding a model-step, fixture-command, or capture-ordering lock.

`DFAS-EXEC-004` — Callbacks shall enqueue bounded work and shall not recursively command a fixture or advance simulation time.

`DFAS-EXEC-005` — Controlled shutdown shall stop new scenario admission, freeze model advance, command approved fixture-safe state, reconcile outstanding fixture commands, stop capture, persist required evidence, and close services in that order.

`DFAS-EXEC-006` — Cancellation shall not claim that already applied physical stimulus or a committed fixture action was rolled back.

# 11. Simulation Session and Lifecycle Model

## 11.1 Session Identity

One session shall bind one target profile, UUT identity, fixture/wiring baseline, model set, scenario/campaign, deterministic seed, time basis, coordination peer set, authorization context, capture namespace, and evidence namespace.

## 11.2 Lifecycle Requirements

`DFAS-SES-001` — Observations, stimuli, model state, commands, and evidence from different sessions or lifecycle generations shall not be merged as one live run.

`DFAS-SES-002` — A UUT image change, fixture reset, wiring/profile change, model replacement, time-basis change, or process restart shall create a new lifecycle generation.

`DFAS-SES-003` — Every stimulus and observation shall carry session identity, lifecycle generation, stimulus epoch, simulation time, host monotonic time, source, validity, and sequence information.

`DFAS-SES-004` — Historical evidence shall remain accessible but visibly distinct from current model and fixture state.

`DFAS-SES-005` — Revision A shall support one active UUT aircraft-side session per second VisionFive 2. Multi-UUT operation shall require independent endpoints, timing budgets, state, evidence, and isolation.

# 12. Second VisionFive 2 Platform Integration

## 12.1 Platform Role

The second VisionFive 2 owns Aircraft Simulation execution, model state, scenario data, fixture-controller interfaces, local storage, time services, process supervision, administration, and evidence contribution. It does not own the UUT SPI or host-interrupt interface.

## 12.2 Platform Requirements

`DFAS-VF2-001` — The platform profile shall identify every I/O controller, network interface, serial interface, GPIO used for fixture control, time source, storage volume, driver, permission, and device-tree dependency.

`DFAS-VF2-002` — Platform-specific I/O shall be exposed to portable logic only through typed, bounded, deadline-aware adapters returning actual completion and error status.

`DFAS-VF2-003` — DMA, cache maintenance, memory barriers, controller FIFOs, interrupt acknowledgement, and operating-system permissions shall remain platform-adapter responsibilities.

`DFAS-VF2-004` — CPU affinity, scheduling policy, clock source, frequency policy, interrupt routing, and I/O buffering used by a timing-qualified profile shall be recorded and verified at startup.

`DFAS-VF2-005` — The target package shall include a nondestructive platform self-test for time, storage, networking, required fixture links, capture paths, and permissions.

`DFAS-VF2-006` — Platform failures shall be recorded separately from fixture, model, scenario, coordination, and UUT observations.

# 13. ULX3S/ECP5-85F Aircraft-Side UUT Integration Profile

## 13.1 UUT Definition

The Revision A UUT is an ULX3S development board populated with an ECP5-85F FPGA and loaded with an identified Dragon Core FPGA realization. This profile identifies a validation environment and does not define product behavior.

## 13.2 Required UUT Metadata

| Metadata class | Required identification |
|---|---|
| Board and FPGA | ULX3S revision, ECP5-85F device/package, and board identity |
| Image | FPGA build identifier, source revision, configuration, and integrity value |
| Wrapper and constraints | Technology-wrapper, constraint-set, clock/reset, and pin-map revisions |
| Aircraft-side mapping | Logical-signal-to-wrapper-to-board-to-fixture mapping revision |
| Host side | First VisionFive 2, Console, SDK, SPI/interrupt wiring, and configuration identities |
| Fixture | Adapter, transceiver, load, analyzer, cable, wiring, calibration/status, and firmware identities |
| Logical contract | Applicable Charter, PBIO, SRS, Architecture, Register Map, VP, RTM, and generated-interface revisions |

## 13.3 UUT Requirements

`DFAS-UUT-001` — Required validation execution shall be refused when UUT image, wrapper, constraint, mapping, fixture, or logical-contract identity is absent or incompatible.

`DFAS-UUT-002` — Aircraft Simulation shall not access ECP5 primitives, wrapper-private registers, debug signals, or validation observability as a substitute for documented logical interfaces.

`DFAS-UUT-003` — Approved validation instrumentation shall be separately identified and time-correlated and shall not become the sole oracle unless permitted by the controlling Verification Plan.

`DFAS-UUT-004` — A board, FPGA density, image, wrapper, constraint, mapping, or fixture change shall create a distinct validation-environment configuration.

`DFAS-UUT-005` — The profile shall confirm that the first VisionFive 2 exclusively owns UUT SPI and host interrupt before physical aircraft-side execution is enabled.

# 14. Aircraft-Side Interconnect and Fixture Profile

## 14.1 Interconnect Allocation

The approved integration record shall map each documented aircraft-side logical interface through the ECP5 wrapper, ULX3S board, external adapter, fixture endpoint, and second VisionFive 2 service. It shall identify producer, consumer, direction, polarity, width, clock or rate basis, reset behavior, safe state, electrical owner, protocol owner, error owner, and verification owner.

## 14.2 Fixture Requirements

`DFAS-FIX-001` — Software shall load a machine-readable interface mapping generated from or independently checked against controlling integration sources.

`DFAS-FIX-002` — The fixture profile shall identify drive capability, observation capability, bidirectional ownership, safe state, contention prevention, rate limits, settling time, health indication, and calibration/status for every endpoint.

`DFAS-FIX-003` — Bidirectional GPIO shall require explicit direction agreement between UUT configuration and fixture drive state before external drive is enabled.

`DFAS-FIX-004` — Logical safety outputs shall connect only to fixture-safe observation or bounded dummy loads and shall never control aircraft energy.

`DFAS-FIX-005` — External ARINC, CAN, and UART electrical behavior shall use identified transceivers or adapters; software shall not claim physical-layer conformance from logic-level emulation alone.

`DFAS-FIX-006` — Fixture readiness shall fail on mapping mismatch, stale firmware, failed self-test, expired calibration where applicable, unsafe load, unverified isolation, or unavailable capture.

`DFAS-FIX-007` — Fixture command and observation paths shall expose their own loss, overflow, timeout, reset, and health evidence.

# 15. Startup, Discovery, and Compatibility

## 15.1 Startup Sequence

Aircraft Simulation shall:

1. validate the installed package, security policy, second VisionFive 2 profile, storage, and time services;
2. load and validate UUT, aircraft-side mapping, fixture, model, scenario, and evidence schemas;
3. run nondestructive platform and fixture self-tests;
4. establish authenticated coordination with Dragon Console or the test director when required;
5. acquire exact UUT, image, configuration, host-session, fixture, and instrumentation identity;
6. place or prove every controlled endpoint in its declared fixture-safe state;
7. create the run and evidence header before any physical stimulus;
8. validate scenario preconditions, timing class, resource budget, expected-result bindings, and authorization;
9. arm capture before enabling stimulus; and
10. enter `READY` only after all required compatibility decisions pass.

## 15.2 Compatibility Requirements

`DFAS-START-001` — No physical stimulus or fault action shall be available before identity, mapping, fixture-health, time-quality, and authorization validation completes.

`DFAS-START-002` — Software, model, scenario, schema, UUT image, logical interface, wrapper, board, fixture, wiring, Console, and VP-case revisions shall be evaluated as independent compatibility axes.

`DFAS-START-003` — Unknown or incompatible configurations may be inspected only through a bounded nondestructive path.

`DFAS-START-004` — Startup shall preserve preexisting capture and fixture diagnostic evidence before any authorized clear or reset.

`DFAS-START-005` — Successful fixture communication alone shall not establish endpoint mapping, UUT readiness, or safe stimulus authority.

# 16. Aircraft Simulation Operating-State Model

## 16.1 Application States

| State | Meaning | Permitted physical activity |
|---|---|---|
| `STOPPED` | No session | None |
| `PLATFORM_CHECK` | Local platform validation | Nondestructive self-test |
| `CONNECTING` | Fixture and coordination setup | Safe-state and identity operations |
| `DISCOVERING` | Baseline acquisition and compatibility | Nondestructive observation |
| `INCOMPATIBLE` | Compatibility rejected | Identity and diagnostic display only |
| `SAFE` | Fixture safe state established | Observation and safe-state commands |
| `READY` | Scenario validated and capture armed | No scenario stimulus yet |
| `RUNNING` | Scenario/model execution | Scenario-authorized stimulus and observation |
| `PAUSED` | Simulation time stopped | Hold or safe behavior explicitly defined by scenario |
| `RECONCILING` | Fixture command result uncertain | Reconciliation and safe-state assessment only |
| `RECOVERING` | Restart, reset, disconnect, or time recovery | Nondestructive discovery and safe-state workflow |
| `DEGRADED` | Declared limitation with bounded operation | Explicit limited allowlist |
| `FAILED` | Required invariants cannot be preserved | Safe-state effort and evidence only |
| `SHUTTING_DOWN` | Controlled termination | Safe-state, reconciliation, capture close |

## 16.2 State Requirements

`DFAS-STATE-001` — Simulation states shall not be presented as Dragon Core operating states or aircraft operational states.

`DFAS-STATE-002` — Every transition shall define cause, source, destination, admitted actions, denied actions, audit record, timeout, and recovery rule.

`DFAS-STATE-003` — Entry into `RECONCILING`, `RECOVERING`, `INCOMPATIBLE`, or `FAILED` shall stop admission of ordinary physical stimulus and fault commands.

`DFAS-STATE-004` — `PAUSED` shall identify whether each endpoint is held, continues autonomously, or is commanded safe; no implicit rule is permitted.

`DFAS-STATE-005` — `DEGRADED` shall state the lost capability, affected evidence, prohibited actions, timing impact, and exit condition.

# 17. Simulation Time and Synchronization

## 17.1 Time Domains

The software shall distinguish simulation time, second-host monotonic time, first-host monotonic time, UUT time, fixture time, instrument time, and wall time. Correlation does not make these clocks interchangeable.

## 17.2 Time Requirements

`DFAS-TIME-001` — Simulation time shall be monotonic within a run and shall advance only under the selected execution mode.

`DFAS-TIME-002` — Fixed-step, variable-step, real-time paced, accelerated, paused, and single-step modes shall be explicitly identified and mutually controlled.

`DFAS-TIME-003` — Each model shall declare its integration method, nominal step, permitted jitter, numerical tolerance, and behavior on missed deadline.

`DFAS-TIME-004` — A synchronized campaign shall record offset, uncertainty, drift estimate, update sequence, and validity for every correlated clock.

`DFAS-TIME-005` — Time correlation shall not reorder captured events contrary to raw source sequence or uncertainty bounds.

`DFAS-TIME-006` — Loss of required time quality shall stop or degrade the scenario according to an explicit rule and shall never be silently ignored.

`DFAS-TIME-007` — Replay shall use recorded logical ordering and simulation timestamps and shall not depend on reproducing wall-clock dates.

# 18. Aircraft, Environment, and Dynamics Models

## 18.1 Model Classes

Models may include aircraft kinematics and dynamics, propulsion, rotor, power-state abstractions, environment, sensor behavior, discrete systems, external bus peers, actuator/load abstractions, operator actions, and fault processes. Only models needed for an approved test purpose shall be included.

## 18.2 Model Requirements

`DFAS-MOD-001` — Every model shall declare purpose, state vector, inputs, outputs, units, reference frames, equations or algorithm, parameters, initial conditions, limits, numerical method, validity envelope, fidelity claims, and verification evidence.

`DFAS-MOD-002` — A model shall reject missing, dimensionally inconsistent, nonfinite, out-of-range, or incompatible parameters before execution.

`DFAS-MOD-003` — Model state shall be initialized deterministically from versioned inputs and deterministic seeds.

`DFAS-MOD-004` — Stochastic behavior shall use an identified reproducible generator and seed stream; nondeterministic entropy shall not enter a reproducible run.

`DFAS-MOD-005` — Numerical saturation, clipping, wrap, singularity handling, discontinuity, and solver failure shall be explicit and observable.

`DFAS-MOD-006` — Model-derived engineering units shall not be confused with the Dragon Core-visible digital representation at the fixture boundary.

`DFAS-MOD-007` — Model fidelity shall be validated only to the range and use claimed by its model-qualification record.

`DFAS-MOD-008` — An external aircraft model shall not be used as the sole oracle for Dragon Core conformity.

# 19. Scenario and Campaign Definition

## 19.1 Scenario Content

A scenario shall identify initial conditions, models and parameters, deterministic seeds, execution mode, action graph, signal profiles, protocol traffic, faults, assertions, expected-result references, capture plan, evidence plan, timeouts, safe-state plan, and termination criteria.

## 19.2 Scenario Requirements

`DFAS-SCN-001` — Scenario syntax and semantics shall be defined by a versioned schema with unknown-field rejection by default.

`DFAS-SCN-002` — Every action shall define preconditions, target, value or payload, units, time basis, deadline, completion criterion, failure disposition, and evidence requirement.

`DFAS-SCN-003` — Branching shall depend only on identified qualified observations or model state and shall record the evaluated condition and selected branch.

`DFAS-SCN-004` — Parallel actions shall declare endpoint ownership and shall be rejected when they can contend, reorder a required sequence, or exceed a resource budget.

`DFAS-SCN-005` — Expected results shall cite the controlling requirement or VP case and an independently derived external-model expectation where applicable.

`DFAS-SCN-006` — A campaign shall define scenario order, isolation, reset/recovery preconditions, stop-on-failure policy, rerun policy, and aggregate completion rules.

`DFAS-SCN-007` — Editing an approved scenario, model parameter, seed, expected result, mapping, or fixture profile shall create a new controlled identity.

# 20. Input-Stimulus Synthesis and Qualification

## 20.1 Stimulus Pipeline

The pipeline shall preserve model/scenario quantity, semantic conversion, logical signal request, fixture command, fixture-applied state, independent capture when available, and UUT acceptance evidence as distinct stages.

## 20.2 Stimulus Requirements

`DFAS-STIM-001` — Every stimulus shall identify source model or action, engineering value when applicable, conversion, logical representation, target endpoint, intended application time, actual command time, applied-state evidence, and validity.

`DFAS-STIM-002` — Unit conversion, calibration, quantization, pulse synthesis, and protocol encoding shall use controlled versioned definitions and independently tested bounds.

`DFAS-STIM-003` — Stimulus outside an endpoint's declared logical, electrical-fixture, rate, duty-cycle, transition, or scenario limit shall be rejected before command admission.

`DFAS-STIM-004` — A value shall not be reported applied solely because it was requested or accepted by a transport.

`DFAS-STIM-005` — Slew, ramp, step, pulse train, dropout, chatter, bounce, burst, and randomized profiles shall define exact timing and boundary behavior.

`DFAS-STIM-006` — Simultaneous stimulus shall preserve the scenario-defined epoch and shall record actual skew and whether the required tolerance was met.

`DFAS-STIM-007` — A stale, invalid, or failed model output shall not be silently replaced by the last value unless the scenario explicitly declares and records hold-last-value behavior.

# 21. Aircraft-Side Digital Interface Services

## 21.1 Service Families

| Family | External simulation responsibility |
|---|---|
| Rotor and engine | Conditioned pulse generation, frequency/rate profiles, dropout, jitter, and source validity |
| General pulse/frequency | Two documented external pulse/frequency sources and qualified timing profiles |
| Health/discrete | Eight conditioned digital source behaviors, transitions, debounce/chatter scenarios, and validity |
| GPIO | Direction-aware external drive, observation, tri-state/contention prevention, and load behavior |
| User logical I/O | Documented Revision A input stimulus and observation subject to the controlling contract |
| ARINC 429 | External receive-side word source, transmit-side analyzer, adapter-error control, and declared electrical adapter |
| Classical CAN | External bus peer, arbitration/traffic, transmit observation, receive drive, and transceiver-error control |
| UART | External serial peer, receive traffic, transmit capture, framing profiles, and adapter behavior |
| Logical safety output | Safe observation and bounded dummy-load behavior only |

## 21.2 Interface Requirements

`DFAS-IF-001` — Interface counts, directions, polarity, encodings, rates, and timing shall come from controlling or generated interface definitions.

`DFAS-IF-002` — Pulse sources shall declare target frequency, edge schedule, duty cycle, jitter profile, missing-pulse behavior, phase relation, and actual generated-edge capture.

`DFAS-IF-003` — Discrete and health stimuli shall support stable, transition, bounce/chatter, simultaneous, invalid-fixture, and recovery cases within approved limits.

`DFAS-IF-004` — ARINC endpoint behavior shall distinguish logical bit-stream generation, word/protocol behavior, adapter-error stimulus, and physical line-adapter behavior.

`DFAS-IF-005` — CAN endpoint behavior shall provide independent traffic, arbitration, acknowledge, error, overload, bus-off-related peer behavior, and transceiver-error stimulus as allocated to the external side.

`DFAS-IF-006` — UART endpoint behavior shall provide independent data, baud/framing selection, gaps, parity/framing error stimulus, break behavior, and receive/transmit capture as supported by the fixture.

`DFAS-IF-007` — Protocol generators and analyzers shall not reuse UUT implementation logic as their sole encoder, decoder, CRC, parity, or expected-result oracle.

`DFAS-IF-008` — Backpressure, queue loss, capture loss, and generator underrun shall be measured and reported separately from UUT-reported loss.

`DFAS-IF-009` — User and GPIO output-enable state shall be independently observed before any external drive to a bidirectional line.

`DFAS-IF-010` — A logical safety-output observation shall preserve polarity, transition time, reset inactivity, and fixture-load identity without implying physical actuator behavior.

# 22. Output Observation and Closed-Loop Response

## 22.1 Observation Classes

The software shall support raw samples, decoded protocol records, edge records, output-enable state, logical safety-output state, fixture health, capture loss, synchronized annotations, model-derived interpretation, and expected-result comparison.

## 22.2 Observation Requirements

`DFAS-OBS-001` — Every observation shall identify physical source, logical signal, session, lifecycle, capture sequence, source time when available, host time, simulation time correlation, validity, freshness, and loss status.

`DFAS-OBS-002` — Commanded, fixture-reported, independently captured, decoded, expected, and derived values shall have distinct representations.

`DFAS-OBS-003` — A stale value shall remain visibly stale after a failed acquisition and shall not be represented as a new sample.

`DFAS-OBS-004` — Raw captures underlying decoded or derived results shall be retained when required by the procedure.

`DFAS-OBS-005` — Closed-loop feedback shall use only qualified observations whose delay, uncertainty, sequence, and validity satisfy the model input contract.

`DFAS-OBS-006` — The closed-loop coordinator shall prevent a same-epoch causal cycle unless the model explicitly defines and solves that algebraic loop.

`DFAS-OBS-007` — Capture overflow, missed edge, decoder loss, timestamp uncertainty, and fixture reset shall invalidate affected comparisons rather than produce a false pass.

# 23. Fault and Anomaly Injection

## 23.1 Fault Classes

Permitted external faults may include missing or abnormal pulses, discrete chatter, adapter-error indications, protocol parity/framing/traffic errors, CAN peer conditions, UART errors, external-source dropout, logical contention attempts rejected before application, fixture disconnect, reset/power-control requests handled by the owning fixture, and evidence-path failures. Device-internal fault injection is excluded unless separately authorized by a controlling verification procedure and owning interface.

## 23.2 Fault Requirements

`DFAS-FI-001` — Every fault shall identify injection point, owner, authorization, preconditions, activation method, expected external and UUT evidence, prohibited side effects, duration, removal method, and safe recovery.

`DFAS-FI-002` — Fault activation shall require an approved scenario and profile and shall not be available as an unrestricted raw command.

`DFAS-FI-003` — Natural UUT behavior, external endpoint fault, fixture fault, injected fault, software fault, and evidence-path fault shall remain distinguishable.

`DFAS-FI-004` — The application shall verify both activation and removal through fixture or independent observation when available.

`DFAS-FI-005` — A failed or ambiguous removal shall enter `RECONCILING` or `FAILED`, inhibit ordinary execution, and require safe-state assessment.

`DFAS-FI-006` — Fault campaigns shall include prohibited-side-effect checks and shall not pass solely because expected fault evidence appeared.

`DFAS-FI-007` — Fixture limits shall prevent software from commanding unsafe voltage, current, contention, or real aircraft-energy effects.

# 24. Dragon Console and Test-Director Coordination

## 24.1 Coordination Boundary

Coordination may use an authenticated isolated network or local test-director service. It carries run identity, readiness, barriers, commands, annotations, and result references. It shall not carry a second direct SPI path or transfer Dragon Console's device-session ownership.

## 24.2 Coordination Requirements

`DFAS-COORD-001` — The coordination protocol shall use versioned typed messages with session identity, sender identity, sequence, command identity, deadline, and result status.

`DFAS-COORD-002` — Start barriers shall prove Console readiness, UUT identity, active configuration identity, Aircraft Simulation readiness, fixture safe state, capture readiness, and time-quality status.

`DFAS-COORD-003` — The Aircraft Simulation shall accept device configuration and operating-state facts only as qualified observations from the owning Console/service and shall not treat them as direct register evidence.

`DFAS-COORD-004` — Console or test-director disconnection shall stop coordinated scenario progression according to the declared campaign policy and shall not create an implicit retry.

`DFAS-COORD-005` — Duplicate, stale, out-of-session, unauthorized, or incompatible coordination messages shall be rejected and audited.

`DFAS-COORD-006` — Cross-host events shall retain each host's monotonic timestamp, correlation estimate, uncertainty, and source sequence.

`DFAS-COORD-007` — Neither peer shall declare the other's physical command complete without an explicit definitive result and required postcondition evidence.

# 25. Ambiguous Fixture-Command Outcome and Reconciliation

## 25.1 Entry Conditions

Ambiguity exists after timeout, short or corrupt reply, controller reset, link loss, process interruption, incomplete transfer, lost acknowledgement, or any result that cannot prove whether a state-changing fixture command took effect.

## 25.2 Reconciliation Requirements

`DFAS-REC-001` — An ambiguous fixture command shall not be retried automatically.

`DFAS-REC-002` — The application shall record command identity, requested effect, transport extent, observed reply, last known fixture state, independent captures, and the reason certainty was lost.

`DFAS-REC-003` — Reconciliation shall use a fixture-defined idempotent query, command sequence/terminal record, independent observation, or controlled reset-to-safe procedure whose authority is documented by the fixture owner.

`DFAS-REC-004` — While ambiguity remains, dependent stimulus, model advance, expected-result evaluation, and ordinary fault actions shall be inhibited.

`DFAS-REC-005` — If the prior effect cannot be proven, the run shall be invalidated for affected outcomes and the fixture shall be placed in a proven safe state before a new session.

`DFAS-REC-006` — Fixture reconciliation shall not be confused with Dragon Core host-transaction reconciliation owned by Dragon Console and the device contract.

# 26. Disconnect, Reset, and Recovery

## 26.1 Recovery Triggers

Triggers include second-host restart, fixture reset, UUT reset reported by Console, UUT identity change, time discontinuity, capture loss, coordination loss, model failure, storage failure, or inability to prove safe fixture state.

## 26.2 Recovery Sequence

Recovery shall stop admission, freeze model progression, preserve evidence, establish fixture-safe state, reconcile outstanding commands, rediscover identities and health, create a new lifecycle generation, revalidate mappings/models/scenarios/time, rearm capture, and require explicit authorization before resuming or restarting.

## 26.3 Recovery Requirements

`DFAS-RCV-001` — No cached fixture state, UUT state, model output, or time correlation shall survive a lifecycle-generation change as live truth.

`DFAS-RCV-002` — A UUT reset shall cause scenario disposition to be evaluated with Dragon Console; Aircraft Simulation shall not assume device configuration was retained or reapplied.

`DFAS-RCV-003` — A fixture reset shall invalidate commanded/applied state until safe state and endpoint status are read back or independently observed.

`DFAS-RCV-004` — Recovery shall preserve prior evidence and shall not clear UUT or fixture diagnostics merely to resume execution.

`DFAS-RCV-005` — Automatic resume is prohibited after process restart, identity change, fault ambiguity, time discontinuity, or lost safe-state proof.

# 27. FPGA/HIL Validation and Deterministic Replay

## 27.1 Validation Role

Aircraft Simulation contributes external stimulus, capture, timing, scenario, model, fixture, and result evidence to Verification-Plan-owned FPGA, HIL, interface, fault-injection, and endurance cases. The controlling Verification Plan remains the authority for required methods and outcomes.

## 27.2 Validation Requirements

`DFAS-VAL-001` — Required execution shall identify the applicable VP case, scope, method, environment, required outcome, and evidence fields without redefining them.

`DFAS-VAL-002` — FPGA/HIL execution shall exercise documented logical boundaries and shall not use wrapper-private behavior to compensate for a nonconforming public interface.

`DFAS-VAL-003` — External generators and analyzers shall use independent expected logic appropriate to their verification purpose.

`DFAS-VAL-004` — A deterministic replay shall reproduce scenario inputs, seeds, logical ordering, model steps, and stimulus epochs and shall report every permitted timing difference.

`DFAS-VAL-005` — Replay against a different UUT, image, fixture, software, model, or time profile shall be a comparison run, not a continuation of the original run.

`DFAS-VAL-006` — Long-duration campaigns shall account for generator, capture, queue, storage, coordination, and UUT-reported loss independently.

`DFAS-VAL-007` — A run shall be blocked, not passed, when required fixture, capture, time, authorization, identity, or evidence prerequisites are unavailable.

`DFAS-VAL-008` — Intermittent or nonreproducible divergence shall remain a failure or unresolved anomaly until classified and corrected by the owning source.

# 28. Data Model and Persistence

## 28.1 Persistent Data Classes

Persistent classes include manifests, profiles, models, parameters, scenarios, campaigns, seeds, run headers, time correlations, stimulus records, observations, captures, fixture commands/results, faults, comparisons, audit records, anomalies, exports, and retention metadata.

## 28.2 Persistence Requirements

`DFAS-DATA-001` — Persistent records shall use versioned schemas and preserve provenance, units, source identity, lifecycle, ordering, validity, and integrity metadata.

`DFAS-DATA-002` — Source models, scenario inputs, run outputs, derived results, and exported reports shall remain distinguishable.

`DFAS-DATA-003` — Writes required for evidence shall be transactional or recoverable and shall detect partial files, truncation, corruption, and capacity exhaustion.

`DFAS-DATA-004` — Storage failure shall not be hidden by continued physical execution when the scenario requires retained evidence.

`DFAS-DATA-005` — Retention, deletion, export, and redaction shall follow controlled policy and preserve auditability.

`DFAS-DATA-006` — Secrets and credentials shall not be stored in scenario, model, capture, or ordinary evidence files.

# 29. Logging, Audit, and Evidence Export

## 29.1 Record Types

The application shall produce structured operational logs, security audit records, model-step summaries, stimulus records, raw capture references, decoded observations, fixture command/result records, coordination records, timing-quality records, fault records, comparison results, anomaly records, and release/run manifests.

## 29.2 Logging and Export Requirements

`DFAS-LOG-001` — Every state-changing request shall record requester, authorization, profile, session, command, parameters, preconditions, definitive result or ambiguity, postcondition evidence, and time data.

`DFAS-LOG-002` — Logs shall distinguish UUT observations, fixture status, simulator status, model results, and operator annotations.

`DFAS-LOG-003` — Required evidence shall preserve raw source data or a cryptographically identified immutable reference to it.

`DFAS-LOG-004` — Export shall include a manifest, file hashes, schema versions, identities, run disposition, anomalies, missing evidence, and transformation history.

`DFAS-LOG-005` — Screenshots and rendered reports may supplement but shall not replace machine-readable evidence.

`DFAS-LOG-006` — Time correction or annotation shall not overwrite original timestamps or source sequence.

# 30. Human and Automation Interfaces

## 30.1 Minimum Human Interface

The interface shall present platform/UUT/fixture/model/scenario identity, readiness, state, simulation time, time quality, active stimulus, observed outputs, faults, loss, resource health, evidence status, and safe-state status.

## 30.2 Interface Requirements

`DFAS-UI-001` — Requested, admitted, commanded, applied, observed, expected, derived, stale, invalid, and lost data shall be visibly distinct.

`DFAS-UI-002` — Fault injection and output-affecting actions shall display exact target, effect, duration, safe limit, required authorization, and removal plan before confirmation.

`DFAS-UI-003` — A displayed pass shall require completed required comparisons and evidence; transport success or visual resemblance is insufficient.

`DFAS-UI-004` — The automation interface shall provide the same authorization, validation, serialization, evidence, and reconciliation rules as the human interface.

`DFAS-UI-005` — Automation commands shall be typed, versioned, bounded, idempotency-aware, and correlated to definitive results.

`DFAS-UI-006` — Human emergency stop shall request the fixture-defined safe-state sequence and preserve evidence; it shall not claim instantaneous removal of an unverified physical effect.

# 31. Security and Access Control

## 31.1 Security Boundary

Security protects the second VisionFive 2, packages, models, scenarios, fixtures, network coordination, evidence, credentials, and administrative functions. Laboratory isolation does not remove the need for authorization and audit.

## 31.2 Security Requirements

`DFAS-SEC-001` — Installed executables, models, scenarios, profiles, and configuration shall be integrity verified before use.

`DFAS-SEC-002` — Human and automation identities shall be authenticated; privileges shall be least-privilege and explicitly scoped.

`DFAS-SEC-003` — Network coordination shall use authenticated peers, replay protection, bounded messages, schema validation, and an allowlist of permitted operations.

`DFAS-SEC-004` — Fault injection, fixture override, electrical-contention testing, reset/power control, and evidence deletion shall require separate authorization and audit.

`DFAS-SEC-005` — The second VisionFive 2 shall not expose general remote shell, unrestricted fixture control, or raw physical I/O in an approved validation profile unless separately controlled and justified.

`DFAS-SEC-006` — Security failure shall fail closed for new physical commands while preserving safe-state and evidence actions.

# 32. Concurrency and Resource Management

## 32.1 Managed Resources

Managed resources include model instances, endpoint ownership, fixture queues, capture buffers, protocol queues, coordination sessions, file descriptors, memory pools, worker threads, storage, and evidence exporters.

## 32.2 Resource Requirements

`DFAS-RES-001` — Every queue, buffer, pool, subscription, capture, and retained history shall have a declared finite bound and overflow behavior.

`DFAS-RES-002` — Endpoint command ownership shall be serialized and shall prevent conflicting writers.

`DFAS-RES-003` — Resource exhaustion shall produce exact software evidence and shall invalidate affected comparisons rather than silently discard required data.

`DFAS-RES-004` — High-rate raw capture may use bounded spill storage, but backpressure and loss behavior shall be explicit.

`DFAS-RES-005` — Parallel campaigns shall be prohibited unless UUT, fixture, endpoints, time, files, credentials, and evidence namespaces are isolated.

# 33. Timing and Performance

## 33.1 Timing Ownership

Dragon Core timing requirements remain owned by the SRS and Architecture. This section owns only the simulator's ability to generate, observe, correlate, and record external timing sufficiently for an approved procedure.

## 33.2 Requirements

`DFAS-PERF-001` — Each profile shall define model step, scheduler jitter, command latency, output-update latency, capture resolution, capture latency, correlation uncertainty, queue depth, and sustained traffic limits.

`DFAS-PERF-002` — Timing qualification shall use measured target evidence under representative worst-case CPU, I/O, capture, storage, and network load.

`DFAS-PERF-003` — Missing a required stimulus or observation deadline shall produce a run-visible error and shall not be concealed by later catch-up.

`DFAS-PERF-004` — Accelerated execution shall be permitted only when physical endpoint and UUT timing obligations remain satisfied or physical I/O is disabled.

`DFAS-PERF-005` — Long-duration runs shall demonstrate bounded drift, memory use, storage growth, queue occupancy, capture loss, and thermal/resource behavior for their declared duration.

`DFAS-PERF-006` — Performance claims shall identify measurement point, clock, load, percentile or bound, sample count, and configuration.

# 34. Error Handling and Degraded Operation

## 34.1 Error Classes

Errors shall distinguish input/schema, model, scenario, scheduling, platform, fixture transport, fixture state, mapping, capture, protocol peer, coordination, storage, security, evidence, and observed UUT behavior.

## 34.2 Error Requirements

`DFAS-ERR-001` — Errors shall have stable typed codes, severity, source owner, context, retry classification, evidence impact, and recovery action.

`DFAS-ERR-002` — Software shall not automatically retry a state-changing fixture command after an ambiguous outcome.

`DFAS-ERR-003` — Degraded operation shall use an explicit allowlist and shall display unavailable capabilities and invalidated evidence.

`DFAS-ERR-004` — Unexpected exceptions, invariant violations, memory corruption indicators, or failed safe-state proof shall stop ordinary physical operation.

`DFAS-ERR-005` — A suspected UUT nonconformance shall preserve the exact stimulus, captures, identities, timing, and environmental evidence needed for ownership classification.

# 35. Portability and Production Separation

## 35.1 Portability Model

Model, scenario, time, observation, comparison, and evidence cores shall be portable. VisionFive 2, ULX3S, fixture, transceiver, analyzer, and operating-system variation shall remain behind declared adapters and profiles.

## 35.2 Requirements

`DFAS-PORT-001` — Portable code shall not depend on CPU endianness, word size, unaligned access, device-node naming, GPIO numbering, or native structure layout.

`DFAS-PORT-002` — A new fixture or fabricated-device environment shall implement the same typed semantic adapter contracts and shall receive independent conformance verification.

`DFAS-PORT-003` — Validation-only models, fault injection, fixture control, and aircraft simulation shall not be linked into a production Dragon Core host runtime by default.

`DFAS-PORT-004` — Use of Aircraft Simulation with fabricated devices shall require a separately approved board/fixture profile and shall not imply production deployment.

`DFAS-PORT-005` — FPGA-only observability shall not become a portable functional dependency.

# 36. Internal and External Software Interfaces

## 36.1 Required Interfaces

| Interface | Required contract |
|---|---|
| Model API | Deterministic initialize, step, observe, checkpoint, restore-for-replay, and terminate behavior |
| Scenario API | Validate, plan, admit, execute, pause, resume, cancel, and result behavior |
| Time API | Simulation, monotonic, correlation, deadline, pacing, and quality services |
| Fixture API | Capability, health, safe state, command, definitive result, query, capture, and reconciliation |
| Protocol endpoint API | Traffic, timing, error, backpressure, capture, and endpoint-state services |
| Coordination API | Authenticated readiness, barrier, command, annotation, status, and result-reference messages |
| Evidence API | Append, correlate, seal, verify, export, and retention behavior |
| Administration API | Profile, package, identity, policy, storage, and audit management |

## 36.2 Interface Requirements

`DFAS-API-001` — Every public interface shall define ownership, caller context, input validation, units, deadlines, thread safety, cancellation, completion, errors, and compatibility.

`DFAS-API-002` — State-changing APIs shall distinguish request acceptance, physical application, independent observation, terminal result, and ambiguous result.

`DFAS-API-003` — Unknown enumeration values, fields, message types, capabilities, or versions shall fail according to an explicit forward-compatibility rule.

`DFAS-API-004` — Raw fixture transports and operating-system I/O shall not be exposed as general application interfaces.

`DFAS-API-005` — Interface schemas shall preserve source identity, sequence, lifecycle, time domain, validity, and provenance.

# 37. Schema, Model, and Compatibility Versioning

## 37.1 Independent Version Axes

Independent axes include software API/ABI, executable release, model schema and package, scenario schema and package, fixture API and firmware, interface mapping, evidence schema, coordination protocol, UUT product/revision, FPGA image/wrapper, and controlling-specification revisions.

## 37.2 Requirements

`DFAS-VER-001` — Compatibility shall be determined from a machine-readable matrix of independent axes and capabilities.

`DFAS-VER-002` — Semantic version change rules shall identify incompatible schema, model equation, parameter, timing, interface, and evidence changes.

`DFAS-VER-003` — Migration shall preserve original data, record the tool and transformation, validate the result, and produce a new identity.

`DFAS-VER-004` — An unknown major version shall be rejected; minor-version tolerance shall be limited to explicitly ignorable additive content.

`DFAS-VER-005` — A model or scenario version shall not be inferred compatible solely because parsing succeeds.

# 38. Software Verification and Validation

## 38.1 Verification Levels

Verification shall include unit, component, integration, target, fixture-conformance, coordinated FPGA/HIL, endurance, security, recovery, reproducibility, and release-acceptance levels in accordance with SW-005.

## 38.2 Mandatory Verification Subjects

Mandatory subjects include model determinism and numeric bounds; schema validation; scenario planning; time and pacing; stimulus conversion; interface generators and analyzers; fixture state/result/reconciliation; endpoint contention prevention; capture ordering and loss; closed-loop causality; fault authorization and removal; coordination; persistence; evidence integrity; security; resource exhaustion; recovery; and target timing.

## 38.3 Verification Requirements

`DFAS-VV-001` — Every normative DFAS requirement shall trace to one or more objective verification cases and evidence records.

`DFAS-VV-002` — Expected software behavior shall derive from this specification and governing owners; tests shall not merely duplicate implementation logic.

`DFAS-VV-003` — Models shall receive analytic checks, known-answer tests, boundary tests, conservation or invariant checks where applicable, sensitivity tests, numerical-stability tests, and independent review.

`DFAS-VV-004` — Fixture adapters shall be tested for legal, boundary, malformed, timeout, partial, duplicate, reset, disconnect, overflow, ambiguous, and safe-state conditions.

`DFAS-VV-005` — Target verification shall measure timing, drift, loss, resource bounds, shutdown, restart, and safe-state behavior on the second VisionFive 2 with representative fixtures.

`DFAS-VV-006` — Coordinated verification shall prove exclusive SPI ownership by Dragon Console and absence of an Aircraft Simulation backdoor to host-visible state.

`DFAS-VV-007` — Verification shall distinguish software, model, scenario, platform, fixture, mapping, instrumentation, Console, FPGA integration, and UUT causes.

`DFAS-VV-008` — Required regression shall follow every change capable of affecting stimulus, timing, observation, comparison, safety, or evidence.

# 39. Traceability and Change Control

## 39.1 Trace Model

Software trace shall link DFAS requirements to controlling and governing sources, architecture components, interfaces, source modules, analyses, verification cases, evidence, anomalies, changes, builds, and releases. It shall not modify the controlling RTM.

## 39.2 Principal Upstream Allocations

| Subject | Principal upstream identifiers |
|---|---|
| Hierarchy and derivation | `CHTR-DOC-001` through `CHTR-DOC-007`; `CHTR-PRN-009`; `CHTR-PRN-010` |
| External software and platform | `CHTR-TECH-002`; `CHTR-TECH-006` through `CHTR-TECH-009`; `CHTR-TECH-013` through `CHTR-TECH-016` |
| Product exclusions | `CHTR-EXCL-001`; `CHTR-EXCL-003` through `CHTR-EXCL-006` |
| FPGA and fixture ownership | `PBIO-FPGA-001` through `PBIO-FPGA-007`; `PBIO-TEST-002`; `PBIO-DATA-001` through `PBIO-DATA-004` |
| Safety and verification boundary | `PBIO-SAFE-003` through `PBIO-SAFE-005`; `PBIO-VER-001` through `PBIO-VER-010` |
| Aircraft-side logical interfaces | `DFC-INTF-0001` through `DFC-INTF-0010`; `DFC-INTF-0040` through `DFC-INTF-0060` |
| FPGA/HIL verification | `VP-GEN-004` through `VP-GEN-007`; `VP-GEN-013`; `VP-FPGA-004` through `VP-FPGA-007`; `VP-HIL-002` through `VP-HIL-004` |
| Software architecture | `SW-FPGA-001` through `SW-FPGA-003`; applicable SW-001 lifecycle, evidence, security, and verification rules |

## 39.3 Requirements

`DFAS-TRACE-001` — Trace links shall cite identifiers and shall not duplicate controlling requirement text as an alternate source.

`DFAS-TRACE-002` — Every released model, scenario, fixture profile, and campaign shall trace to its approved purpose and verification use.

`DFAS-TRACE-003` — A change shall receive impact analysis across models, scenarios, interfaces, timing, fixtures, evidence, tests, packages, and affected controlling cases.

`DFAS-TRACE-004` — A discovered controlling-specification defect shall be recorded against the owning document; dependent software shall not resolve it locally.

`DFAS-TRACE-005` — No controlling-specification change is required by this Revision A baseline.

# 40. Build, Package, Deployment, and Release

## 40.1 Required Packages

The release shall contain or identify the target executable, portable libraries, second VisionFive 2 adapter, approved fixture adapters, models, schemas, scenarios, campaigns, configuration profiles, service definitions, tests, documentation, manifests, SBOM, integrity/signing data, and release evidence.

## 40.2 Release Requirements

`DFAS-REL-001` — Builds shall be reproducible from controlled source, generated inputs, pinned toolchains, dependencies, and build configuration under SW-006.

`DFAS-REL-002` — Engineering, fault-injection, dry-run, FPGA/HIL, and release-test artifacts shall have separate package identities and capability manifests.

`DFAS-REL-003` — Deployment shall verify compatibility, signature/integrity, storage, rollback package, service permissions, fixture ownership, and safe state before activation.

`DFAS-REL-004` — Install, update, rollback, and uninstall shall not automatically apply physical stimulus or resume a prior scenario.

`DFAS-REL-005` — The release manifest shall bind software, models, scenarios, schemas, fixtures, target image, dependencies, tests, anomalies, approvals, and governing revisions.

`DFAS-REL-006` — Production credentials, private signing keys, unrestricted fixture controls, and uncontrolled local modifications shall not enter the release package.

# 41. Deliverables

## 41.1 Required Deliverables

| Deliverable | Minimum content |
|---|---|
| Source package | Application, libraries, adapters, models, generators, schemas, tests, and build definitions |
| Target package | Signed/integrity-identified second VisionFive 2 deployment and service configuration |
| Model package | Model descriptions, equations/algorithms, parameters, validity envelopes, qualification, and tests |
| Scenario package | Approved scenarios, campaigns, seeds, expected-result references, and schemas |
| Integration package | UUT, interface mapping, fixture, wiring, transceiver, instrumentation, and time profiles |
| Verification package | Plans, cases, results, coverage, timing, determinism, target, fixture, HIL, and regression evidence |
| Release package | Manifests, SBOM, integrity/signing data, compatibility matrix, installation, rollback, and approvals |
| User documentation | Operation, safety limits, profiles, evidence, recovery, administration, and troubleshooting |

## 41.2 Delivery Requirements

`DFAS-DEL-001` — Delivered artifacts shall be internally consistent, machine-verifiable where applicable, and identified by the release manifest.

`DFAS-DEL-002` — Documentation shall distinguish Dragon Core, FPGA integration, first-host Console, second-host Aircraft Simulation, fixture, model, and aircraft-side responsibilities.

`DFAS-DEL-003` — Known anomalies, deviations, limitations, unsupported profiles, model validity limits, and evidence gaps shall accompany the release.

`DFAS-DEL-004` — No artifact shall require an undocumented external source or manual modification to reproduce the approved build or run.

# 42. Exit Criteria

Revision A is complete only when:

1. every DFAS requirement is uniquely identified and traced;
2. all mandatory software verification passes with no unresolved severity-one or release-blocking anomaly;
3. model determinism, numerical bounds, validity envelopes, and claimed fidelity are verified;
4. the second VisionFive 2 target meets timing, resource, security, restart, and safe-state requirements;
5. interface mappings, fixture adapters, generators, analyzers, transceivers, loads, and capture paths pass their conformance checks;
6. exclusive SPI and host-interrupt ownership by the first VisionFive 2 is verified;
7. open-loop, coordinated, closed-loop, fault, recovery, endurance, and replay profiles pass applicable acceptance cases;
8. ambiguous fixture-command outcomes and recovery are verified without blind retry;
9. evidence packages are complete, reproducible, integrity verified, and independently reviewable;
10. build, install, update, rollback, packaging, manifests, and archival pass SW-006 requirements;
11. all interfaces, models, scenarios, schemas, profiles, and compatibility relationships are baselined; and
12. no unresolved requirement conflict, controlling-specification defect, safety-boundary violation, or undocumented dependency remains.

# 43. Baseline Statement

## 43.1 Baseline Declaration

This document establishes the Revision A technical baseline for Dragon Flight Aircraft Simulation.

## 43.2 Governing Relationship

Aircraft Simulation is subordinate to the eight controlling Dragon Flight specifications and to SW-001 through SW-006. It coordinates with SW-007 Dragon Console while preserving exclusive ownership of the UUT host path by Dragon Console. It may consume compatible SW-010 SDK types and test-support components without making the SDK an owner of aircraft-side physical behavior.

## 43.3 Fixed Baseline Conclusions

The Revision A baseline fixes the following conclusions:

1. Aircraft Simulation executes on a dedicated second VisionFive 2 outside Dragon Core.
2. The ULX3S/ECP5-85F is the FPGA-validation UUT, not a new product definition.
3. The first VisionFive 2 and Dragon Console exclusively own UUT SPI and host-interrupt access.
4. The second VisionFive 2 supplies and observes aircraft-side logical behavior only through approved external adapters and fixtures.
5. Aircraft, environment, sensor, bus-peer, load, and fault models are external test models and do not redefine Dragon Core or establish aircraft certification.
6. Scenario, stimulus, fixture-applied state, raw observation, UUT output, and derived interpretation remain distinct.
7. Physical adaptation, transceivers, wiring, loading, and safe electrical behavior remain separately controlled fixture and board responsibilities.
8. Deterministic time, replay, evidence custody, explicit ambiguity recovery, and safe-state proof are mandatory.
9. Controlling Verification Plan methods and outcomes remain authoritative for product conformity.

## 43.4 Controlling-Specification Disposition

No required change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` was identified while establishing this baseline.

## 43.5 Change Control

Any change affecting responsibility allocation, logical interfaces, device timing or behavior, verification methods or outcomes, trace relationships, or RTL rules shall be resolved in the owning controlling specification before this subordinate document is revised to consume it. Changes confined to Aircraft Simulation implementation, models, scenarios, adapters, schemas, workflows, evidence, or deployment remain under this document and the governing software change process.

## 43.6 Approval Statement

Approval of this document authorizes implementation and verification of Dragon Flight Aircraft Simulation Revision A within the boundaries defined herein. It does not authorize alteration of a controlling specification, connection to real aircraft-energy equipment, operational flight use, or aircraft-certification credit.
