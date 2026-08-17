**DRAGON SENTINEL™ SOFTWARE SPECIFICATION**

Document Number: RCA-DFC-SW-009  
Revision: A  
Status: Technical Baseline  
Product: Dragon Core™ Revision A  
Program: Dragon Flight™ Core ASIC Development Program  
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | 2026-08-07 | Initial Dragon Sentinel software baseline derived beneath the eight controlling Dragon Flight specifications | Royal Cubit Aerospace |

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
5. Dragon Sentinel Configuration Item Identification
6. Authority, Ownership, and Product Boundary
7. Operational Roles and Deployment Profiles
8. Execution and Deployment Environment
9. Software Architecture
10. Process, Thread, and Scheduling Model
11. Device-Service, Sentinel, and Consumer Session Model
12. Southbound Dragon Service Interface
13. Observation Acquisition and Normalization
14. Startup, Discovery, and Compatibility
15. Sentinel Operating-State Model
16. Supervision Policy and Configuration
17. Device-State Qualification and Health Assessment
18. Watchdog Service Coordination
19. Interrupt, Event, and Diagnostic Evidence Retrieval
20. Monitoring and System-Health Supervision
21. Fault, Safety, Interlock, and Lost-Link Observation
22. Host-Side Anomaly Detection and Correlation
23. Alert Model, Routing, Acknowledgement, and Escalation
24. Ambiguous-Outcome Reconciliation
25. Disconnect, Restart, and Recovery
26. Queue, Backpressure, and Loss Management
27. Time, Freshness, Ordering, and Correlation
28. Persistence and Data Custody
29. Logging, Audit, and Evidence Export
30. Security and Trust Boundaries
31. Availability, Isolation, and Failover
32. Concurrency and Resource Management
33. Timing, Rate, and Performance
34. Error Handling and Degraded Operation
35. Human Administration and Automation Interfaces
36. Portability and Platform Adaptation
37. Internal and External Software Interfaces
38. Schema, Policy, and Compatibility Versioning
39. Software Verification and Validation
40. Traceability and Change Control
41. Build, Package, Deployment, and Release
42. Deliverables and Exit Criteria
43. Baseline Statement

# 1. Purpose

This specification defines Dragon Sentinel, the continuous external supervision service for one or more Dragon Core device contexts. Dragon Sentinel observes qualified device state, retrieves retained evidence, coordinates approved service policy, schedules authorized watchdog service when configured, detects host-side anomalies, preserves operational records, and publishes alerts to authorized consumers.

Dragon Sentinel executes entirely outside the fabricated Dragon Core device. It supplements but does not replace Dragon Core hardware monitoring, fault collection, watchdog, interlock, lost-link, or logical safety-output behavior. It is not an aircraft flight-control function and shall not be credited as the sole means of detecting or responding to a condition that a controlling specification assigns to hardware.

This specification owns Sentinel software composition, lifecycle, supervision state, policy consumption, observation qualification, optional watchdog scheduling, anomaly detection, alert semantics, persistence, recovery, deployment, verification, and release requirements. It does not own or redefine product scope, device behavior, internal hardware architecture, register meaning, SPI behavior, hardware safety policy, controlling verification cases, controlling trace relationships, RTL rules, physical interfaces, aircraft application policy, or installation approval.

`DSS-PUR-001` — Dragon Sentinel shall provide continuous, bounded, externally hosted supervision through public Dragon SDK or authenticated device-service interfaces.

`DSS-PUR-002` — Dragon Sentinel shall preserve every active, sticky, pending, historical, commanded, effective, diagnostic, result, and recovery distinction supplied by the typed Dragon software stack.

`DSS-PUR-003` — Dragon Sentinel shall never substitute software inference for a controlling device readback, retained evidence item, definitive command result, or hardware safety response.

`DSS-PUR-004` — Loss or failure of Dragon Sentinel shall not prevent Dragon Core from performing configured autonomous hardware supervision.

# 2. Scope

## 2.1 Included Scope

This specification covers:

- the Dragon Sentinel executable and supporting libraries;
- supervised device-context discovery, attachment, compatibility, observation, recovery, and detachment;
- periodic and interrupt-assisted collection of lifecycle, configuration, monitoring, health, interrupt, event, diagnostic, fault, interlock, lost-link, watchdog, and safety-output observations;
- approved watchdog-service scheduling and its fail-safe suspension rules;
- host-side deadline, queue, persistence, service, resource, compatibility, freshness, and evidence-availability anomaly detection;
- alert creation, update, deduplication, routing, acknowledgement, escalation, suppression control, and closure;
- explicit separation of active device conditions, sticky device evidence, Sentinel-detected conditions, alerts, acknowledgements, and operator annotations;
- persistence, audit, evidence export, security, availability, failover, recovery, verification, packaging, deployment, release, and maintenance obligations; and
- compact embedded, hosted service, redundant service, laboratory, FPGA/HIL, maintenance, and production-safe deployment profiles.

## 2.2 Excluded Scope

The following are excluded:

- any executable software, processor, runtime, scheduler, persistent store, Sentinel component, or application inside Dragon Core;
- direct SPI-master or raw-register access by Sentinel application logic;
- redefinition of a register, field, access class, operating state, timing rule, queue behavior, event meaning, fault meaning, safety response, or command side effect;
- replacement of hardware watchdog, fault manager, interlock, lost-link, system-health, or safety-output behavior with software;
- automatic clearing of device fault, event, interrupt, overflow, diagnostic, or safety evidence merely because an alert was acknowledged, suppressed, or closed;
- aircraft flight control, navigation, guidance, mission management, vehicle-control decisions, or direct aircraft-energy control;
- ownership of installation alert thresholds, escalation contacts, external notification infrastructure, aircraft hazard classification, or aircraft-level safety assessment;
- unrestricted production-test, fault-injection, scan, RTL-hierarchical, platform-private, arbitrary-memory, or physical shared-buffer access; and
- physical network media, external adapters, signal conditioning, transceivers, loads, actuators, wiring, power, and environmental design.

## 2.3 Intended Use

Dragon Sentinel is intended to run as a long-lived external-host service near the Dragon device service. It may support operational embedded hosts, laboratory systems, maintenance installations, FPGA/HIL validation, post-silicon bring-up, and ground-support systems. A deployment may supervise one or more device contexts, but each context shall retain independent identity, state, policy, queues, records, recovery, and access authorization.

`DSS-SCOPE-001` — Every Dragon Core operation performed by Sentinel shall use a public typed service governed by `RCA-DFC-SW-001` and `RCA-DFC-SW-003`.

`DSS-SCOPE-002` — Sentinel shall not depend on a platform-private register, undocumented opcode, RTL hierarchy, testbench backdoor, physical shared-buffer address, or hidden device state.

`DSS-SCOPE-003` — Sentinel shall remain removable or restartable without preventing Dragon Core hardware from reaching host-access-ready operation or performing enabled autonomous supervision.

`DSS-SCOPE-004` — A deployment shall not enable watchdog service, a device state-changing operation, or an alert action merely because the underlying SDK exposes it; each requires explicit policy, authorization, compatibility, and verification allocation.

`DSS-SCOPE-005` — Sentinel shall not be represented as a safety-certified replacement for any hardware function unless a later installation-specific safety process independently allocates and approves that role.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and sole normative ownership of the controlling set are defined only by `RCA-DFC-CHTR-002`, Section 3.1. The following table is an informative Sentinel-use view and creates no alternate precedence.

| Document | Dragon Sentinel use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product mission, exclusions, external-host model, fixed constraints, and single-owner rules |
| `RCA-DFC-PBIO-002.md` | Device, software, host, data, security, safety, interface, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior, autonomous supervision, evidence, and host-recovery obligations |
| `RCA-DFC-ARCH-002.md` | Device-side contracts needed to interpret state, timing, events, diagnostics, monitoring, safety, and reconciliation |
| `RCA-DFC-REG-002.md` | Sole normative source for host-visible registers, fields, access, legality, protection, behavior, and side effects |
| `RCA-DFC-VP-002.md` | Sole normative source for device and host-boundary verification methods, cases, outcomes, and evidence definitions |
| `RCA-DFC-RTM-002.md` | Sole normative source for relationships among controlling technical identifiers |
| `RCA-DFC-RTL-STD-002.md` | RTL implementation and structural rules; not a Dragon Sentinel software standard |

## 3.2 Governing Software Specifications

| Document | Governing relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | External-host architecture and Dragon Sentinel architectural allocation, including `SW-SENT-001` through `SW-SENT-005` |
| `RCA-DFC-SW-002`, Revision B | External embedded-host firmware services used in compact embedded deployments |
| `RCA-DFC-SW-003`, Revision B | Public HAL, BSP, driver, typed API, lifecycle, result, and recovery contracts |
| `RCA-DFC-SW-004`, Revision B | Software coding and implementation standard |
| `RCA-DFC-SW-005`, Revision B | Software verification and validation requirements |
| `RCA-DFC-SW-006`, Revision B | Build, package, deployment, release, manifest, integrity, and archival requirements |
| `RCA-DFC-SW-007`, Revision A | Console interaction and engineering workflow peer; it does not own Sentinel behavior |
| `RCA-DFC-SW-008`, Revision A | Gateway integration peer and optional authorized alert consumer; it does not own Sentinel behavior |

## 3.3 Historical Reference

No historical Dragon Sentinel specification was supplied or used. This Revision A specification is newly derived from the controlling technical specifications and the governing software baseline.

## 3.4 Authority and Single-Definition Rules

`DSS-DOC-001` — Dragon Sentinel shall apply `CHTR-DOC-001` through `CHTR-DOC-007`.

`DSS-DOC-002` — A device fact shall be consumed from its controlling owner or generated typed binding and shall not be copied into Sentinel source, schemas, policy, or documentation as an alternate definition.

`DSS-DOC-003` — Sentinel policy may select an allowed operation, sampling cadence, escalation action, or alert rule but shall not independently redefine a device encoding, capacity, access rule, safety response, or timing contract.

`DSS-DOC-004` — Generated bindings, exported schemas, and derived dashboards shall retain source identity and shall not become alternate controlling specifications.

`DSS-DOC-005` — If implementation or verification exposes a conflict, ambiguity, omission, unreachable behavior, or unimplementable contract, dependent work shall stop and the owning specification shall be corrected before Sentinel invents a substitute.

## 3.5 Controlling-Specification Change Flags

No change to a controlling specification is required to establish this Revision A baseline.

The controlling specifications provide complete external-host observability, evidence, watchdog service, interrupt service, reconciliation, recovery, and boundary ownership needed by Dragon Sentinel. Deployment-specific alert thresholds, notification endpoints, retention intervals, escalation rosters, credentials, platform resource budgets, and operational policies remain controlled external inputs and do not require changes to the Dragon Core technical specification set.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition in this specification |
|---|---|
| Active condition | A presently asserted device or Sentinel condition; distinct from sticky historical evidence. |
| Alert | A versioned Sentinel record communicating a qualified condition, its severity, provenance, lifecycle, and disposition. |
| Alert acknowledgement | A consumer record that an alert was seen; it does not clear the source condition or device evidence. |
| Ambiguous outcome | A state-changing operation for which a definitive device result was not validated and software cannot safely infer whether an effect occurred. |
| Consumer | An authenticated process, console, gateway, maintenance system, or other endpoint receiving Sentinel observations or alerts. |
| Definitive result | A validated terminal result establishing success or an applicable failure class for the requested operation. |
| Desired policy | Persisted Sentinel supervision intent; it is not effective until validated, activated, and reported as active. |
| Device context | One isolated software lifecycle and service context for one physical Dragon Core instance. |
| Device service | Privileged external-host software that owns physical-device access, lifecycle, serialization, scheduling, diagnostics, and recovery. |
| Effective policy | Validated Sentinel policy currently governing a device context. |
| Evidence gap | A known interval or sequence range for which expected observation or evidence is unavailable, lost, stale, or unproven. |
| Host-side anomaly | A qualified Sentinel observation about external software, host resources, persistence, scheduling, connectivity, or evidence handling; distinct from device-reported evidence. |
| Observation | Typed device or host state with provenance, semantic class, collection time, device time when available, freshness, and quality. |
| Service lease | Exclusive, time-bounded authority for one Sentinel instance to perform configured state-changing service for a device context. |
| Sticky evidence | Device-retained historical indication defined by a controlling specification; distinct from an alert or host log. |
| Suppression | Authorized control of alert delivery or repetition; it does not alter source state or evidence. |
| Watchdog service | An authorized typed operation that services the hardware watchdog under a verified external scheduling policy. |

API, BSP, CRC, FPGA, HAL, HIL, SDK, SPI, UUT, UTC, and other device-side terms retain the definitions of their controlling owners. Device units, identifiers, encodings, access classes, capacities, and timing values are not redefined here.

# 5. Dragon Sentinel Configuration Item Identification

## 5.1 Software Configuration Items

| Configuration item | Purpose | Execution or storage location |
|---|---|---|
| `dragon_sentinel` | Main service, lifecycle coordination, supervision, alerting, and administration | Approved external host |
| `dragon_sentinel_core` | Protocol-neutral state machines, policy model, observation qualification, anomaly logic, and alert lifecycle | Linked library or service component |
| `dragon_sentinel_southbound` | Authenticated client for public device-service and Dragon SDK operations | Sentinel process |
| `dragon_sentinel_collectors` | Typed periodic and event-driven observation collectors | Sentinel process |
| `dragon_sentinel_watchdog` | Optional exclusive watchdog-service scheduler and safety guards | Isolated Sentinel component |
| `dragon_sentinel_rules` | Versioned host-side anomaly and alert-rule evaluation framework | Sentinel process |
| `dragon_sentinel_persistence` | Durable observations, alerts, gaps, policy, audit, and recovery checkpoints | Approved external persistent store |
| `dragon_sentinel_publishers` | Authenticated alert and observation consumer adapters | Sentinel process or isolated adapter processes |
| `dragon_sentinel_admin` | Controlled administrative and diagnostic interface | Sentinel host |
| `dragon_sentinel_schemas` | Machine-readable policy, observation, alert, audit, and export schemas | Release package and deployment store |
| `dragon_sentinel_tests` | Unit, component, integration, fault, timing, recovery, and HIL verification assets | Verification environment |

## 5.2 Identification Requirements

`DSS-CI-001` — Every Sentinel configuration item shall have a unique name, semantic version, source revision, build identity, integrity value, and compatibility declaration.

`DSS-CI-002` — A deployed instance shall report executable, library, schema, rule-set, policy, platform, and generated-binding identities without exposing secrets.

`DSS-CI-003` — Production, engineering, FPGA/HIL, test, and simulation artifacts shall be distinguishable by package identity and runtime profile.

`DSS-CI-004` — An unapproved or unidentified component shall prevent the affected device context from entering Sentinel `OPERATIONAL` and shall prevent watchdog-service authority.

`DSS-CI-005` — Release identity shall accompany exported Sentinel evidence sufficient to reproduce its interpretation.

# 6. Authority, Ownership, and Product Boundary

## 6.1 Responsibility Allocation

| Subject | Sentinel responsibility | External owner retained |
|---|---|---|
| Device behavior | Observe and interpret through typed contracts | Controlling technical specifications and Dragon Core hardware |
| Physical access | Request typed service operations | Device service, HAL, BSP, driver, and platform |
| Supervision policy | Validate, activate, execute, and audit approved policy | Installation and operational authority approves policy |
| Watchdog scheduling | Perform only when explicitly configured and exclusively authorized | Hardware owns watchdog behavior; installation owns service policy |
| Alerting | Detect host-side conditions and publish typed alerts | Consumers own their response; external infrastructure owns delivery |
| Persistence | Preserve Sentinel records and exported device evidence | Deployment owns storage service, backup, and retention authorization |
| Safety action | Observe and report | Dragon Core hardware and installation-specific external systems own action |

## 6.2 Boundary Requirements

`DSS-BND-001` — Dragon Core shall always be treated as an external processor-free hardware peripheral.

`DSS-BND-002` — Sentinel shall not call platform SPI primitives, map the device register space, or bypass the device-service transaction coordinator.

`DSS-BND-003` — Sentinel shall not claim that an alert acknowledgement, operator annotation, or external notification modified any device condition.

`DSS-BND-004` — Sentinel-derived health shall be labeled as software assessment and shall remain distinct from the device primary state, qualifiers, module status, fault class, and safety-output state.

`DSS-BND-005` — Installation policy shall not authorize Sentinel to perform a device operation prohibited by a controlling specification, generated binding, device state, or software compatibility contract.

`DSS-BND-006` — Sentinel shall preserve device autonomy during Sentinel absence, restart, disconnection, persistence failure, or consumer failure.

# 7. Operational Roles and Deployment Profiles

## 7.1 Operational Roles

| Role | Permitted responsibility |
|---|---|
| Sentinel service identity | Continuous observation, approved service, anomaly detection, persistence, and alert publication |
| Administrator | Install, configure, start, stop, inspect, and recover Sentinel within authorized scope |
| Policy approver | Approve supervision, watchdog, alert, retention, and escalation policy |
| Operator | Observe state and alerts, acknowledge alerts, and add controlled annotations |
| Maintainer | Diagnose Sentinel, retrieve evidence, and perform approved maintenance workflows |
| Auditor | Read immutable configuration, policy, alert, action, and release evidence |
| Consumer service | Receive authorized observations or alerts through a defined schema |

## 7.2 Deployment Profiles

| Profile | Required characteristics |
|---|---|
| Compact embedded | Sentinel and device service may share an executable while preserving logical boundaries, serialization, and least privilege |
| Hosted service | Separate Sentinel process uses authenticated local or network device-service interfaces |
| Redundant service | Multiple eligible instances use exclusive per-device service leases and deterministic takeover |
| Laboratory | Increased diagnostics and capture are allowed; engineering operations remain explicitly authorized |
| FPGA/HIL | ECP5 UUT and validation host are supported through the same public contracts and identified test profile |
| Production-safe | Engineering, injection, raw-access, and production-test capabilities are absent or inaccessible |

## 7.3 Role and Profile Requirements

`DSS-ROLE-001` — Every action shall be attributable to one authenticated service or human role.

`DSS-ROLE-002` — Role assignment shall follow least privilege and separation of duties for policy approval, deployment, operation, and audit.

`DSS-ROLE-003` — A compact deployment shall preserve the same command admission, audit, result, reconciliation, and recovery rules as a separated deployment.

`DSS-ROLE-004` — A production-safe profile shall not load or expose engineering-only publisher, injection, test, or raw diagnostic modules.

`DSS-ROLE-005` — A profile transition shall require controlled restart or an equivalently verified atomic activation; partial profile changes are prohibited.

# 8. Execution and Deployment Environment

## 8.1 Required Platform Services

Sentinel requires monotonic time, optional trusted wall-clock correlation, bounded scheduling, authenticated interprocess communication, secure configuration, durable storage, structured logging, process supervision, memory protection, and controlled software update services. A deployment using notifications additionally requires authenticated external delivery adapters.

## 8.2 Deployment Requirements

`DSS-ENV-001` — Platform adapters shall isolate operating-system, clock, storage, IPC, notification, and credential mechanisms from Sentinel domain logic.

`DSS-ENV-002` — Sentinel correctness shall use monotonic time for deadlines, intervals, leases, and freshness; wall-clock changes shall not extend a deadline or watchdog-service window.

`DSS-ENV-003` — Platform resource limits shall be declared for threads, memory, descriptors, queues, storage, CPU share, and external connections.

`DSS-ENV-004` — Failure of optional notification infrastructure shall not block device observation, evidence persistence, or configured local alerting.

`DSS-ENV-005` — Host boot order shall prevent Sentinel from issuing device operations until the device service, persistent store, identity, configuration, and compatibility prerequisites are established.

`DSS-ENV-006` — A platform unable to meet declared timing or durability assumptions shall enter a bounded degraded state and shall not perform watchdog service.

# 9. Software Architecture

## 9.1 Logical Components

| Component | Responsibility |
|---|---|
| Lifecycle coordinator | Device-context creation, startup, compatibility, state transition, reconnect, and shutdown |
| Southbound client | Typed authenticated access to device service and Dragon SDK |
| Observation scheduler | Periodic and interrupt-assisted collection with deadlines and priorities |
| Normalizer | Provenance, quality, freshness, semantic class, and coherent observation construction |
| Evidence retriever | Event, interrupt, diagnostic, counter, and retained-evidence collection |
| Watchdog coordinator | Exclusive, policy-governed hardware-watchdog service |
| State assessor | Qualified Sentinel state and device-context assessment without redefining device state |
| Anomaly engine | Host-side condition qualification, correlation, hysteresis, and recovery |
| Alert manager | Alert identity, lifecycle, routing, acknowledgement, suppression, and escalation |
| Persistence manager | Durable records, checkpoints, gaps, retention, export, and recovery |
| Administration service | Controlled configuration, inspection, health, and maintenance operations |

## 9.2 Dependency Rules

`DSS-ARCH-001` — Application components shall depend on typed domain services and shall not depend directly on HAL, BSP, SPI, register, or generated low-level transport interfaces.

`DSS-ARCH-002` — Device state-changing operations shall pass through one per-device coordinator that preserves serialization, authorization, definitive-result handling, and reconciliation.

`DSS-ARCH-003` — Observation, anomaly, and alert models shall remain protocol-neutral; adapters shall translate without changing semantics.

`DSS-ARCH-004` — Device-derived facts shall retain device identity, source, collection result, freshness, and semantic class through every component.

`DSS-ARCH-005` — A component failure shall not silently discard another component's retained evidence or convert an unknown state into a normal state.

## 9.3 Failure Containment

`DSS-ARCH-006` — Publisher failure shall be isolated from observation, watchdog scheduling, persistence, and recovery.

`DSS-ARCH-007` — Rule-engine failure shall produce a visible Sentinel service fault and shall not erase prior alerts or source evidence.

`DSS-ARCH-008` — Persistence failure shall prevent claims of durable custody and shall trigger configured bounded fail-safe behavior.

`DSS-ARCH-009` — Watchdog coordination shall be isolated so overload in reporting, export, or administration cannot delay a scheduled service decision.

# 10. Process, Thread, and Scheduling Model

## 10.1 Execution Model

The implementation may use processes, threads, tasks, or an event loop. The externally visible behavior shall remain equivalent: per-device serialization, bounded priority service, nonblocking alert delivery, independent persistence, explicit cancellation, and deterministic shutdown.

## 10.2 Scheduling Requirements

`DSS-SCHED-001` — Watchdog decision and service work, when enabled, shall have the highest Sentinel application scheduling priority for that device context.

`DSS-SCHED-002` — Interrupt and evidence retrieval shall have bounded priority above ordinary polling, reporting, export, and administration.

`DSS-SCHED-003` — No external consumer, administrator, rule, formatter, logger, or storage operation shall execute unbounded work in a device-service callback or watchdog scheduling path.

`DSS-SCHED-004` — Every scheduled activity shall define release condition, deadline, maximum execution budget, cancellation behavior, overrun evidence, and retry policy.

`DSS-SCHED-005` — A missed critical deadline shall be detected independently of the task that missed it.

`DSS-SCHED-006` — Shutdown shall stop new work, revoke state-changing authority, complete or abandon in-flight work by policy, persist final gaps, and terminate within a declared bound.

# 11. Device-Service, Sentinel, and Consumer Session Model

## 11.1 Session Classes

| Session | Owner | Scope |
|---|---|---|
| Device-service session | Sentinel southbound client | One authenticated logical connection to typed Dragon services |
| Device context | Lifecycle coordinator | One physical device identity and all associated Sentinel state |
| Service lease | Watchdog or state-changing coordinator | Exclusive authority for approved operations on one device context |
| Consumer session | Publisher adapter | One authenticated alert or observation consumer |
| Administrative session | Administration service | One authenticated management principal and bounded operation set |

## 11.2 Session Requirements

`DSS-SES-001` — A device context shall bind to verified device identity and shall not silently transfer accumulated state to a different physical device.

`DSS-SES-002` — Reconnection shall repeat authentication, discovery, identity, compatibility, and reconciliation before ordinary operation resumes.

`DSS-SES-003` — Consumer connection state shall not determine device state, watchdog state, or evidence-retention state.

`DSS-SES-004` — Session identifiers shall be unique within their retention scope and shall accompany actions, observations, alerts, and audit records.

`DSS-SES-005` — Expiration or loss of a service lease shall atomically revoke the affected Sentinel instance's authority to issue state-changing or watchdog-service operations.

`DSS-SES-006` — Session teardown shall preserve unresolved command correlation and evidence gaps for recovery.

# 12. Southbound Dragon Service Interface

## 12.1 Interface Use

Sentinel shall use the public Dragon SDK or an authenticated device-service API that preserves the same typed lifecycle, operation, result, provenance, and recovery contracts. In-process linking is permitted only when it preserves those boundaries.

## 12.2 Southbound Requirements

`DSS-SB-001` — Sentinel shall use typed discovery, lifecycle, state, configuration-readback, interrupt, event, diagnostic, monitoring, health, watchdog, fault, interlock, lost-link, safety-status, reset-status, and reconciliation services.

`DSS-SB-002` — Sentinel shall not construct raw register addresses, field masks, SPI frames, protection sequences, or device command encodings.

`DSS-SB-003` — Every southbound result shall retain device identity, operation identity, request correlation, result class, completion evidence, and transport or service diagnostics supplied by the interface.

`DSS-SB-004` — A lost connection shall invalidate cached authority and freshness but shall not rewrite the last known device observation as current.

`DSS-SB-005` — Sentinel shall apply interface timeouts as local bounds and shall not reinterpret a timeout as proof that a device operation failed before acceptance.

`DSS-SB-006` — Southbound version incompatibility shall prevent `OPERATIONAL` state and watchdog service.

# 13. Observation Acquisition and Normalization

## 13.1 Observation Classes

| Class | Required distinction |
|---|---|
| Current device state | Present hardware value or condition read through a typed service |
| Sticky device evidence | Retained historical device indication, unchanged by Sentinel acknowledgement |
| Device event | Retained timestamped hardware event record and retrieval provenance |
| Device diagnostic | Host-path, configuration, queue, overflow, reset, service, or module diagnostic |
| Host observation | Sentinel, device-service, platform, storage, or delivery state |
| Derived assessment | Explicitly labeled computation from identified inputs and rule version |

## 13.2 Normalization Requirements

`DSS-OBS-001` — Each observation shall include device-context identity, source class, source identifier, collection monotonic time, device raw time when supplied, quality, freshness, and schema version.

`DSS-OBS-002` — Sentinel shall label observations as current, sticky, event, counter, commanded, active, effective, cached, stale, unavailable, ambiguous, or derived as applicable.

`DSS-OBS-003` — A cached value shall retain its original collection time and shall never be relabeled as a successful current read.

`DSS-OBS-004` — A composite assessment shall expose the quality and freshness of each required constituent or report the composite as incomplete.

`DSS-OBS-005` — Read failure shall produce an explicit unavailable observation and shall not reuse an older normal value without a stale indicator.

`DSS-OBS-006` — Nondestructive reads shall be preferred; destructive evidence operations shall be performed only by the evidence-custody workflow.

# 14. Startup, Discovery, and Compatibility

## 14.1 Startup Sequence

For each device context Sentinel shall:

1. validate its release, profile, credentials, policy, schemas, storage, and platform prerequisites;
2. authenticate to the device service;
3. discover device and software-service identity;
4. validate product, revision, register-map, capability, generated-binding, SDK, policy, and schema compatibility;
5. acquire an exclusive service lease if state-changing service is configured;
6. read present device state, independent qualifiers, active configuration, retained diagnostics, counters, queue state, events, and terminal reconciliation evidence without first modifying device state;
7. compare desired and active policy inputs;
8. reconcile unresolved prior operations and record evidence gaps;
9. activate observation and alerting; and
10. enable approved watchdog service only after every applicable prerequisite passes.

## 14.2 Compatibility Requirements

`DSS-START-001` — Sentinel shall not infer compatibility from device communication alone.

`DSS-START-002` — An unknown product, revision, capability, binding, schema, policy, or service version shall enter `INCOMPATIBLE` unless an explicit approved compatibility rule accepts it.

`DSS-START-003` — Startup inspection shall be read-only until identity, compatibility, authorization, and unresolved-operation reconciliation are complete.

`DSS-START-004` — Sentinel shall report each failed prerequisite individually and shall not collapse them into a generic offline indication.

`DSS-START-005` — Sentinel shall preserve startup observations and the exact compatibility decision inputs in the audit record.

`DSS-START-006` — A normal observation loop shall not start while an incompatible or unidentified device could be mistaken for the intended context.

# 15. Sentinel Operating-State Model

## 15.1 Sentinel States

| State | Meaning |
|---|---|
| `DISCONNECTED` | No authenticated device-service session exists |
| `DISCOVERING` | Identity, compatibility, state, and evidence are being acquired |
| `INCOMPATIBLE` | A required compatibility relationship is not approved |
| `OBSERVING` | Read-only observation is active before full policy activation |
| `CONFIGURING` | Approved Sentinel policy or authorized device configuration workflow is in progress |
| `OPERATIONAL` | Required supervision services and evidence custody are within declared bounds |
| `DEGRADED_OBSERVED` | Device or Sentinel recoverable condition is observed while bounded service continues |
| `FAULTED_OBSERVED` | Device or Sentinel critical condition is observed; permitted service is restricted |
| `RECOVERING` | Reconnect, restart, requalification, reconciliation, or evidence recovery is in progress |
| `SERVICE_FAILED` | Required Sentinel service cannot be provided within policy bounds |

These are Sentinel workflow states. They are not alternate Dragon Core primary operating states.

## 15.2 State Requirements

`DSS-STATE-001` — Sentinel shall base device assessment on the primary state and every independently required qualifier; it shall not infer qualifiers solely from primary-state encoding.

`DSS-STATE-002` — Each transition shall identify cause, source observations, rule version, prior state, next state, monotonic time, and device time when available.

`DSS-STATE-003` — Unknown, stale, incomplete, or contradictory required inputs shall not result in `OPERATIONAL`.

`DSS-STATE-004` — Recovery to `OPERATIONAL` shall require fresh requalification of all required inputs and closure or explicit disposition of evidence gaps.

`DSS-STATE-005` — Device `DEGRADED` and `FAULTED` states shall remain visible independently from Sentinel `DEGRADED_OBSERVED`, `FAULTED_OBSERVED`, or `SERVICE_FAILED`.

`DSS-STATE-006` — State transitions shall be deterministic for a given ordered observation set and active policy.

# 16. Supervision Policy and Configuration

## 16.1 Policy Classes

| Policy class | Examples of owned choices |
|---|---|
| Observation | Required sources, sampling cadence, interrupt use, freshness, and bounded drain |
| Watchdog service | Enablement, lease ownership, scheduling margin, suspension, and recovery prerequisites |
| Anomaly rules | Host-side thresholds, hysteresis, qualification, severity, and recovery |
| Alerting | Routing, escalation, suppression, acknowledgement, repetition, and closure |
| Persistence | Record classes, durability, retention, capacity thresholds, and export |
| Recovery | Reconnect, backoff, checkpoint use, evidence-gap handling, and requalification |

## 16.2 Policy Requirements

`DSS-POL-001` — Policy shall be schema-validated, versioned, integrity-protected, attributable, approved, and compatible before activation.

`DSS-POL-002` — Policy activation shall be atomic per device context; partial activation is prohibited.

`DSS-POL-003` — Sentinel shall preserve desired, staged, active, rejected, and prior policy separately.

`DSS-POL-004` — Invalid, incomplete, expired, unauthorized, or incompatible policy shall reject without altering active policy.

`DSS-POL-005` — A policy change affecting watchdog service, state-changing authority, critical observation cadence, or alert routing shall require explicit approval and a verified transition plan.

`DSS-POL-006` — Policy shall reference device facts through stable typed names or compatibility predicates and shall not copy Register-Map-owned numeric definitions.

`DSS-POL-007` — Sentinel shall expose active policy identity and the effective value of every supervision parameter without exposing secrets.

# 17. Device-State Qualification and Health Assessment

## 17.1 Assessment Inputs

Device assessment may consume typed primary state, host readiness, initialization, observational mode, effective operational enable, subsystem readiness and fault, active configuration, monitoring status, fault class, safety status, diagnostics, counters, queue state, and evidence availability. The required input set is profile- and policy-controlled.

## 17.2 Assessment Requirements

`DSS-ASSESS-001` — Sentinel shall retain each controlling device value independently and shall not replace a detailed cause with an aggregate summary.

`DSS-ASSESS-002` — A commanded enable shall not be treated as effective operation without the applicable active and effective readbacks.

`DSS-ASSESS-003` — Active conditions and sticky historical evidence shall contribute separately to assessment and alerting.

`DSS-ASSESS-004` — A device recovery indication shall not close an alert while required sticky evidence, counter change, event retrieval, or active readback remains unresolved.

`DSS-ASSESS-005` — Conflicting device observations shall produce a contradiction anomaly and trigger fresh coherent acquisition before interpretation.

`DSS-ASSESS-006` — Sentinel-derived health severity shall identify the exact source observations and rule that produced it.

`DSS-ASSESS-007` — Sentinel shall not clear or modify device state to make an assessment appear normal.

# 18. Watchdog Service Coordination

## 18.1 Service Preconditions

Watchdog service is optional. Before issuing any service operation, Sentinel shall have an authenticated compatible device-service session, verified device identity, fresh watchdog status, effective compatible policy, exclusive service lease, valid monotonic timing, sufficient scheduling margin, known command-result state, and acceptable platform health.

## 18.2 Scheduling Requirements

`DSS-WDOG-001` — Sentinel shall derive each service deadline and permitted issue interval from typed active device configuration and approved policy, not from copied device constants.

`DSS-WDOG-002` — Service shall be scheduled with a declared worst-case margin covering scheduler latency, IPC, serialization, device-service latency, and result handling.

`DSS-WDOG-003` — Sentinel shall never intentionally service before the active permitted window or after the active deadline.

`DSS-WDOG-004` — A service operation shall be issued at most once for a given scheduled opportunity unless a definitive result proves that retry is permitted and no ambiguous effect exists.

`DSS-WDOG-005` — Sentinel shall record scheduled time, issue time, result time, active configuration identity, policy identity, lease identity, and timing margin for every service opportunity.

## 18.3 Suspension and Recovery

`DSS-WDOG-006` — Watchdog service shall stop or remain disabled when timing guarantees, compatibility, device identity, configuration validity, service lease, platform health, or command-result certainty is lost.

`DSS-WDOG-007` — Connection loss, process failover, scheduler overrun, monotonic-clock anomaly, policy change, or persistence failure affecting required evidence shall revoke service eligibility.

`DSS-WDOG-008` — Sentinel shall not send a speculative retry after timeout, response loss, cancellation, or failover.

`DSS-WDOG-009` — Service may resume only after reconnect, reconciliation, fresh status and active-configuration readback, exclusive lease acquisition, policy requalification, and verified timing margin.

`DSS-WDOG-010` — Failure to service shall be reported as a Sentinel condition independently from any device-reported watchdog timeout or recovery evidence.

# 19. Interrupt, Event, and Diagnostic Evidence Retrieval

## 19.1 Retrieval Model

The host interrupt is a wakeup indication. Source identity, pending state, event contents, diagnostics, and clear behavior shall be obtained through typed services. Sentinel may supplement interrupt-driven service with bounded polling.

## 19.2 Evidence-Custody Requirements

`DSS-EVID-001` — Sentinel shall read the complete applicable pending state and shall not infer the device source solely from an external interrupt edge.

`DSS-EVID-002` — Event retrieval shall snapshot a complete record, validate it, persist the raw record and provenance, and only then request removal when policy authorizes removal.

`DSS-EVID-003` — Sentinel shall preserve retained device event order and shall distinguish device raw timestamp order from host collection order.

`DSS-EVID-004` — Empty, full, overflow, drop, underflow, rejected-access, source-loss, store-overwrite, coalescing, and counter evidence shall be retained as independent conditions.

`DSS-EVID-005` — A clear shall affect only the explicitly authorized evidence item and shall not be coupled to alert acknowledgement, publication, export, or suppression.

`DSS-EVID-006` — New evidence discovered during bounded drain shall remain reportable and shall not be lost because the external interrupt was already acknowledged by the host controller.

`DSS-EVID-007` — Failure to persist an event before authorized removal shall prevent removal and shall create a host-side custody anomaly.

`DSS-EVID-008` — Sentinel shall detect sequence, counter, overflow, and collection gaps and shall represent each gap explicitly even when exact lost content is unknowable.

# 20. Monitoring and System-Health Supervision

## 20.1 Monitored Families

Sentinel may observe rotor, engine, pulse/frequency, sampled-sensor, system-health, GPIO, databus, routing, user-function, shared-resource, clock/reset, and module readiness status through typed services. It shall not reimplement the hardware measurement, qualification, threshold, hysteresis, age, or aggregation algorithms owned by the controlling specifications.

## 20.2 Supervision Requirements

`DSS-MON-001` — Sentinel shall preserve measured value, validity, threshold condition, timeout or stale state, saturation, recovery, and configuration identity as separate fields where supplied.

`DSS-MON-002` — Sentinel shall distinguish raw, synchronized, qualified, active, sticky asserted, sticky recovered, and qualification-failure health indications.

`DSS-MON-003` — A Sentinel display or alert shall not recompute a device threshold result and present it as the hardware result.

`DSS-MON-004` — Optional host-derived trends or predictions shall be labeled derived, shall identify their input interval and rule version, and shall not suppress contradictory device evidence.

`DSS-MON-005` — Missing, stale, invalid, saturated, or contradictory measurements shall be reportable independently from out-of-range valid measurements.

`DSS-MON-006` — Sentinel shall preserve per-channel identity and shall not replace a channel-specific condition with only an aggregate health indication.

`DSS-MON-007` — Configuration changes affecting interpretation shall start a new assessment epoch and shall not retroactively reinterpret previously stored raw evidence.

# 21. Fault, Safety, Interlock, and Lost-Link Observation

## 21.1 Safety-Domain Observation

Sentinel observes but does not own fault classification, recoverability, primary-source selection, response lanes, authorization, interlock evaluation, lost-link qualification, safety-output latching, inhibit causes, or effective logical outputs.

## 21.2 Requirements

`DSS-SAFE-001` — Sentinel shall publish active and latched fault-source vectors, class validity, recoverability, primary source, multiple-source indication, and applicable response evidence without collapsing them.

`DSS-SAFE-002` — Sentinel shall distinguish requested, latched-request, commanded, effective, inhibited, faulted, reset-held, and physical-observation-unavailable safety-output information.

`DSS-SAFE-003` — Every reported safety-output inhibit shall preserve each independently supplied inhibit cause; an aggregate indication shall not replace causes.

`DSS-SAFE-004` — Interlock status shall identify selected entry, active committed definition identity, current result, violation, guard, response, and retained evidence as provided by typed services.

`DSS-SAFE-005` — Lost-link status shall preserve monitor identity, selected activity source, qualifying, active loss, recovery, elapsed state, injected attribution, and retained evidence.

`DSS-SAFE-006` — Sentinel shall not issue a fault clear, interlock commit, lost-link injection, safety-output command, or safety reset as an automatic alert side effect.

`DSS-SAFE-007` — Engineering injection or test observations shall remain explicitly tagged and shall never be merged with natural evidence without attribution.

`DSS-SAFE-008` — A physical safety effect shall not be claimed from a logical register observation alone; external adaptation and physical verification remain outside Sentinel.

# 22. Host-Side Anomaly Detection and Correlation

## 22.1 Host-Side Condition Classes

| Class | Examples |
|---|---|
| Scheduling | Missed release, deadline, overrun, insufficient watchdog margin |
| Connectivity | Device-service disconnect, authentication failure, repeated timeout |
| Evidence | Queue loss, collection gap, persistence failure, unavailable or stale evidence |
| Compatibility | Unknown device, binding, service, schema, rule, or policy relationship |
| Resource | Memory, storage, descriptor, CPU, thread, queue, or rate exhaustion |
| Integrity | Configuration, policy, package, schema, or record integrity failure |
| Redundancy | Lease conflict, split authority, duplicate service attempt, failed takeover |

## 22.2 Detection Requirements

`DSS-ANOM-001` — Host-side anomalies shall be identified separately from device-reported faults, events, diagnostics, and counters.

`DSS-ANOM-002` — Every rule shall define input set, qualification, hysteresis or debounce where applicable, severity, recovery, missing-input behavior, and rule version.

`DSS-ANOM-003` — An unavailable required input shall not be interpreted as a deasserted condition.

`DSS-ANOM-004` — Repeated observations of one continuing condition shall update one condition instance unless policy explicitly defines separate occurrences.

`DSS-ANOM-005` — Correlation shall preserve all constituent source identifiers and shall not delete or downgrade the original observations.

`DSS-ANOM-006` — Rule evaluation shall be deterministic for the same ordered input set, policy, and rule version.

`DSS-ANOM-007` — A rule execution failure, budget overrun, or incompatible rule set shall create a Sentinel service anomaly and shall not silently skip evaluation.

# 23. Alert Model, Routing, Acknowledgement, and Escalation

## 23.1 Alert Record

Each alert shall contain a stable alert identifier, device context, condition identifier, source class, severity, lifecycle state, first and latest occurrence times, occurrence count, active/recovered state, evidence references, rule and policy identity, delivery state, acknowledgement records, suppression state, escalation state, and closure disposition.

## 23.2 Alert Requirements

`DSS-ALERT-001` — Alert creation shall require a qualified source condition or an explicit Sentinel service failure; transport or consumer success shall not determine condition truth.

`DSS-ALERT-002` — Acknowledgement shall record principal, time, comment, and alert version and shall not clear source state, device evidence, or the alert's occurrence history.

`DSS-ALERT-003` — Suppression shall be authorized, scoped, time-bounded where applicable, attributable, and visible; it shall not stop source observation or evidence custody.

`DSS-ALERT-004` — Recovery shall close or transition an alert only after the rule's recovery conditions and required evidence disposition are satisfied.

`DSS-ALERT-005` — Routing failure shall produce delivery evidence and a separate Sentinel condition without blocking other destinations.

`DSS-ALERT-006` — Escalation shall be idempotent within a declared alert version and destination scope.

`DSS-ALERT-007` — Severity, priority, routing, and escalation shall remain separate attributes.

`DSS-ALERT-008` — External notification content shall include enough identity and provenance to avoid confusing devices, installations, natural conditions, injected conditions, active conditions, and historical evidence.

`DSS-ALERT-009` — An alert shall never assert that a device condition cleared solely because delivery succeeded, a user acknowledged it, or a suppression expired.

# 24. Ambiguous-Outcome Reconciliation

## 24.1 Entry Conditions

Sentinel shall enter reconciliation after response truncation, timeout after possible acceptance, cancellation after dispatch, connection loss during a state-changing operation, process failure with unresolved work, service failover, or any result classified as ambiguous by the Dragon software stack.

## 24.2 Reconciliation Requirements

`DSS-RECON-001` — Sentinel shall not infer success or failure from request intent, elapsed time, transport error, cached state, or absence of an alert.

`DSS-RECON-002` — Sentinel shall use the typed host-reconciliation service and applicable active, status, counter, queue, event, and diagnostic readbacks before deciding outcome.

`DSS-RECON-003` — A protected authorization attempt shall be treated as consumed or unknown according to the governing API contract and shall not be reused speculatively.

`DSS-RECON-004` — No dependent operation, retry, watchdog service, alert closure, or policy activation shall proceed while its prerequisite operation remains unresolved.

`DSS-RECON-005` — If evidence cannot distinguish outcomes, Sentinel shall retain `AMBIGUOUS`, expose the uncertainty, and require policy-defined human or system disposition.

`DSS-RECON-006` — Reconciliation shall be repeatable and idempotent and shall preserve all conflicting or incomplete evidence.

`DSS-RECON-007` — Failover shall not transfer state-changing authority until the successor reconciles predecessor operations.

# 25. Disconnect, Restart, and Recovery

## 25.1 Recovery Triggers

Recovery triggers include device-service disconnect, device reset, host restart, Sentinel restart, identity change, configuration change, lease loss, time anomaly, persistence recovery, schema or policy change, and unresolved command outcome.

## 25.2 Recovery Sequence

Sentinel shall revoke state-changing authority, mark observations stale, preserve unresolved work, reconnect with bounded backoff, authenticate, rediscover identity, revalidate compatibility, read present state and evidence before modification, reconcile operations, detect reset and configuration epochs, retrieve retained evidence, reestablish policy, reacquire any lease, and requalify timing before service resumes.

## 25.3 Requirements

`DSS-REC-001` — Recovery shall never assume that volatile device configuration survived reset or power loss.

`DSS-REC-002` — Reapplication of nondefault device configuration, if allocated to Sentinel by deployment policy, shall use the governing typed lifecycle workflow and active readback.

`DSS-REC-003` — Sentinel shall distinguish device reset, device replacement, service restart, Sentinel restart, and communication interruption.

`DSS-REC-004` — Backoff shall be bounded, observable, and cancellable and shall not extend a safety- or watchdog-related deadline.

`DSS-REC-005` — Prior alerts and evidence shall remain associated with their original device and configuration epochs.

`DSS-REC-006` — Recovery failure shall enter `SERVICE_FAILED` or a policy-defined restricted state and shall not loop silently.

`DSS-REC-007` — A recovered connection shall not erase a recorded evidence gap.

# 26. Queue, Backpressure, and Loss Management

## 26.1 Managed Queues

Managed queues include collection work, device observations, raw events, persistence work, rule inputs, alerts, publication destinations, administration requests, and exports. Device-owned queues remain governed by the controlling specifications.

## 26.2 Requirements

`DSS-QUEUE-001` — Every Sentinel queue shall have a declared finite capacity, item type, ownership, priority, overflow policy, and observable occupancy.

`DSS-QUEUE-002` — Critical device evidence shall not be silently overwritten by lower-priority telemetry, formatting, reporting, or administrative work.

`DSS-QUEUE-003` — Any dropped, coalesced, expired, overwritten, rejected, or unavailable Sentinel item shall increment or record attributable loss evidence.

`DSS-QUEUE-004` — Sentinel-side loss shall remain distinct from device queue loss, device event-source loss, and device event-store overwrite.

`DSS-QUEUE-005` — Backpressure from one consumer shall not block unrelated consumers, evidence retrieval, persistence, or watchdog decisions.

`DSS-QUEUE-006` — Coalescing is permitted only for a declared semantic class and shall preserve first time, latest time, occurrence count, severity changes, and source identity.

`DSS-QUEUE-007` — Resource exhaustion shall trigger bounded shedding by declared priority and a visible degraded or failed service state.

# 27. Time, Freshness, Ordering, and Correlation

## 27.1 Time Domains

Sentinel handles device raw timestamp, optional device correlated timestamp, host monotonic time, and optional trusted wall time. These domains shall remain explicitly identified. Stored Dragon Core event records retain device raw time.

## 27.2 Requirements

`DSS-TIME-001` — Deadlines, intervals, freshness, leases, backoff, and watchdog scheduling shall use monotonic time.

`DSS-TIME-002` — Wall time shall be used only for presentation, external correlation, or retention policy and shall carry synchronization quality.

`DSS-TIME-003` — Sentinel shall not rewrite a stored device raw timestamp after a correlation update.

`DSS-TIME-004` — Correlated presentation shall identify offset or correlation-sequence provenance and shall preserve the original raw value.

`DSS-TIME-005` — Observation ordering shall use source sequence, device raw time, host collection sequence, and monotonic time as applicable; no single clock shall be assumed sufficient for every source.

`DSS-TIME-006` — Clock step, loss of synchronization, monotonic anomaly, or correlation uncertainty shall be observable and shall invalidate affected freshness or service guarantees.

`DSS-TIME-007` — Freshness limits shall be defined per observation class and shall not be extended by rereading cached data.

# 28. Persistence and Data Custody

## 28.1 Persistent Data Classes

| Class | Required content |
|---|---|
| Identity | Device, service, Sentinel release, schema, rule, policy, platform, and deployment identity |
| Observations | Selected raw and normalized values with provenance, quality, freshness, and epoch |
| Evidence | Device events, diagnostics, counters, gaps, injected attribution, and retrieval custody |
| Alerts | Complete lifecycle, delivery, acknowledgement, suppression, escalation, and closure records |
| Operations | State-changing request, authorization, result, reconciliation, and disposition |
| Recovery | Checkpoints, session transitions, leases, restart causes, and unresolved work |
| Audit | Administrative, policy, security, export, and release events |

## 28.2 Requirements

`DSS-PERS-001` — Persistence shall preserve original raw evidence and shall store derived interpretation separately.

`DSS-PERS-002` — Each durable record shall include schema version, integrity protection, device context, epoch, source, and creation sequence.

`DSS-PERS-003` — A record shall be acknowledged as durable only after the configured durability boundary confirms it.

`DSS-PERS-004` — Retention, compaction, archival, and deletion shall be controlled, attributable, and unable to make remaining records falsely appear complete.

`DSS-PERS-005` — Storage-capacity thresholds shall be monitored before exhaustion and shall trigger declared shedding and escalation policy.

`DSS-PERS-006` — Corrupt, incompatible, or partially committed records shall be quarantined and shall not be silently accepted.

`DSS-PERS-007` — Recovery from backup or replication shall preserve record identity and shall detect duplicate or missing sequence ranges.

# 29. Logging, Audit, and Evidence Export

## 29.1 Record Types

Operational logs support diagnosis; audit records support accountability; evidence records preserve source behavior. These record classes may share infrastructure but shall remain semantically distinguishable.

## 29.2 Requirements

`DSS-AUD-001` — Audit records shall cover authentication, authorization, policy approval and activation, role changes, service leases, state-changing operations, watchdog service, alert acknowledgement and suppression, export, restart, and release change.

`DSS-AUD-002` — Logs and audit records shall include stable correlation identifiers but shall exclude plaintext secrets, private keys, authentication tokens, and unnecessary sensitive payloads.

`DSS-AUD-003` — Evidence export shall declare device context, time domain, observation interval, known gaps, source revisions, schema, policy, rule set, Sentinel release, and integrity values.

`DSS-AUD-004` — Export shall preserve device raw records and shall not substitute a rendered summary for source evidence.

`DSS-AUD-005` — Failed, partial, cancelled, and retried exports shall be attributable and shall not be represented as complete.

`DSS-AUD-006` — Audit failure affecting required accountability shall enter a declared degraded or failed service state.

# 30. Security and Trust Boundaries

## 30.1 Trust Boundaries

Trust boundaries exist among Sentinel, device service, persistent store, policy store, identity provider, administrator, consumer adapters, notification infrastructure, and software-update service. In-process placement does not remove logical trust boundaries.

## 30.2 Requirements

`DSS-SEC-001` — Every external interface shall authenticate its peer, authorize each operation, validate schema and bounds, and apply least privilege.

`DSS-SEC-002` — Device-service credentials shall not be exposed to consumers, publishers, rule content, logs, or exported evidence.

`DSS-SEC-003` — Watchdog-service, state-changing, policy-management, alert-suppression, and evidence-deletion privileges shall be independently controllable.

`DSS-SEC-004` — Configuration, policy, rule sets, schemas, packages, plugins, and updates shall be integrity-verified before use.

`DSS-SEC-005` — Untrusted text and external payloads shall never become executable rule, path, format string, command, or device operation without controlled parsing and authorization.

`DSS-SEC-006` — Secret material shall use approved platform custody, rotation, access control, and zeroization mechanisms.

`DSS-SEC-007` — Repeated authentication, schema, rate, replay, integrity, or authorization failures shall produce bounded security evidence without enabling denial-of-service amplification.

`DSS-SEC-008` — Engineering or test credentials and trust roots shall be excluded from production-safe packages and profiles.

# 31. Availability, Isolation, and Failover

## 31.1 Availability Model

Sentinel availability is external-host availability and shall not be confused with Dragon Core hardware availability. Redundancy may improve external supervision continuity but shall never create multiple concurrent masters for state-changing service.

## 31.2 Requirements

`DSS-AVL-001` — Each device context shall have at most one effective service lease for watchdog or state-changing operations.

`DSS-AVL-002` — Standby instances may observe through authorized services only when the device-service architecture permits it without bypassing serialization or duplicating destructive reads.

`DSS-AVL-003` — A successor shall authenticate, verify device identity, reconcile predecessor work, read current state, acquire the lease, and requalify timing before service.

`DSS-AVL-004` — Quorum, lease store, or cluster failure shall revoke state-changing authority rather than permit split authority.

`DSS-AVL-005` — Failure of one device context, consumer, publisher, or export shall not corrupt or indefinitely block unrelated contexts.

`DSS-AVL-006` — Availability targets, restart bounds, recovery-point objectives, and recovery-time objectives shall be deployment inputs and shall be verified for the selected profile.

`DSS-AVL-007` — Failover shall create an attributable continuity record including last proven observation, last durable record, unresolved operations, and known gaps.

# 32. Concurrency and Resource Management

## 32.1 Managed Resources

Managed resources include device contexts, leases, sessions, scheduler slots, transactions, observations, evidence records, rules, alerts, queues, storage batches, publishers, subscriptions, files, descriptors, memory, and CPU budgets.

## 32.2 Requirements

`DSS-CONC-001` — Mutable per-device lifecycle and state-changing work shall be serialized or protected by an equivalently verified ownership mechanism.

`DSS-CONC-002` — Locks shall have declared ordering; blocking I/O and callbacks shall not execute while holding a lock that can block critical service.

`DSS-CONC-003` — Cancellation shall distinguish work not dispatched, dispatched with definitive result, and dispatched with ambiguous outcome.

`DSS-CONC-004` — Resource acquisition and release shall be exception-safe and shall preserve unresolved evidence on failure.

`DSS-CONC-005` — Per-device and per-consumer quotas shall prevent one context from exhausting shared resources.

`DSS-CONC-006` — Queue, memory, storage, thread, and descriptor high-water marks shall be observable and testable.

`DSS-CONC-007` — Deadlock, livelock, starvation, duplicate dispatch, use-after-release, and unbounded growth shall be prevented by design and verified.

# 33. Timing, Rate, and Performance

## 33.1 Timing Ownership

Device timing requirements remain owned by the controlling specifications. Sentinel owns only external software timing budgets, observation cadences, alert latency objectives, service margins, queue bounds, persistence latency, and recovery bounds.

## 33.2 Requirements

`DSS-PERF-001` — Each deployment shall define worst-case budgets for critical collection, evidence drain, persistence, alert creation, local delivery, watchdog decision, and recovery activities.

`DSS-PERF-002` — Budgets shall include scheduler, IPC, serialization, device service, storage, rule, and adapter latency where applicable.

`DSS-PERF-003` — Rate controls shall exist for polling, reconnect, alerts, logs, exports, consumers, and administrative requests.

`DSS-PERF-004` — Performance overload shall degrade by declared priority and shall not silently violate watchdog-service or evidence-custody assumptions.

`DSS-PERF-005` — Worst-case verification shall include simultaneous interrupts, full device event storage, multiple active faults, consumer backpressure, storage delay, restart, and recovery.

`DSS-PERF-006` — Measured timing evidence shall identify platform, load, release, policy, device image or fabricated revision, and instrumentation.

# 34. Error Handling and Degraded Operation

## 34.1 Error Classes

Error classes include configuration, compatibility, authentication, authorization, transport, service, device rejection, ambiguity, observation, freshness, scheduling, persistence, queue, rule, alert delivery, resource, integrity, time, lease, recovery, and internal invariant failures.

## 34.2 Requirements

`DSS-ERR-001` — Errors shall be typed and shall preserve source, operation, device context, correlation, time, retryability, ambiguity, and evidence references.

`DSS-ERR-002` — Expected device rejection shall not be reported as transport success or internal software failure.

`DSS-ERR-003` — Retry policy shall consider idempotency, device acceptance, side effects, deadlines, lease ownership, and reconciliation; a transient label alone shall not authorize retry.

`DSS-ERR-004` — Degraded operation shall declare which services remain valid, which are suspended, which evidence may be incomplete, and what recovery is required.

`DSS-ERR-005` — Internal invariant failure shall stop the affected unsafe path, preserve diagnostic context, and trigger supervised restart or `SERVICE_FAILED`.

`DSS-ERR-006` — Error reporting shall be bounded and shall prevent recursive alert or log storms while retaining occurrence counts.

`DSS-ERR-007` — Sentinel shall not clear a device fault or diagnostic solely to suppress an error or alert.

# 35. Human Administration and Automation Interfaces

## 35.1 Administration Interface

The administration interface may be CLI, local API, service manager integration, or a Console-facing typed interface. It shall expose Sentinel configuration, status, identity, policy, alerts, queues, resources, sessions, leases, gaps, and diagnostics without becoming a raw device-access interface.

## 35.2 Requirements

`DSS-ADMIN-001` — Administrative operations shall be authenticated, authorized, schema-validated, attributable, and audited.

`DSS-ADMIN-002` — Destructive or authority-changing operations shall require explicit target selection and confirmation appropriate to the deployment.

`DSS-ADMIN-003` — Status output shall distinguish desired, staged, active, stale, unknown, degraded, failed, suppressed, acknowledged, and recovered states.

`DSS-ADMIN-004` — Automation shall use stable machine-readable interfaces and definitive exit or result status; screen scraping is not a production interface.

`DSS-ADMIN-005` — Administrative restart, policy change, lease transfer, evidence deletion, and alert suppression shall display their effect and required recovery.

`DSS-ADMIN-006` — A human interface shall not label acknowledgement as device clear, suppression as recovery, or cached data as current.

# 36. Portability and Platform Adaptation

## 36.1 Portability Model

Sentinel core logic shall be portable across approved external hosts. Platform differences shall be isolated behind governed adapters for time, scheduling, process control, IPC, storage, credentials, networking, logging, and updates.

## 36.2 Requirements

`DSS-PORT-001` — Platform adapters shall implement explicit interfaces and shall not alter domain semantics.

`DSS-PORT-002` — Endianness, integer width, alignment, locale, time representation, path syntax, and filesystem behavior shall not change stored or transmitted Sentinel schemas.

`DSS-PORT-003` — A platform port shall verify monotonic clock, scheduler bounds, durable-write semantics, atomic replacement, credential custody, IPC authentication, and process supervision.

`DSS-PORT-004` — The ECP5 FPGA validation realization and production ASIC realization shall use the same typed observation, result, reconciliation, and Sentinel state semantics.

`DSS-PORT-005` — FPGA-only observability or test control shall remain in an identified engineering profile and shall not become a production dependency.

`DSS-PORT-006` — Platform-specific tuning shall be versioned deployment configuration, not conditional reinterpretation of controlling device behavior.

# 37. Internal and External Software Interfaces

## 37.1 Required Interfaces

| Interface | Direction | Required content |
|---|---|---|
| Dragon device service / SDK | Bidirectional | Typed lifecycle, observation, evidence, service, result, and reconciliation operations |
| Persistent store | Bidirectional | Durable records, transactions, query, retention, backup, and health |
| Identity and policy | Inbound | Authenticated principals, roles, approved policy, integrity, and expiry |
| Alert consumers | Outbound and acknowledgement inbound | Versioned alerts, delivery results, acknowledgements, and optional subscriptions |
| Administration | Bidirectional | Controlled status, configuration, lifecycle, diagnostics, and export |
| Platform services | Bidirectional | Monotonic time, scheduling, process supervision, logging, credentials, and update |

## 37.2 Interface Requirements

`DSS-IF-001` — Every interface shall define schema, version negotiation, authentication, authorization, limits, timeout, cancellation, error, retry, ordering, and compatibility behavior.

`DSS-IF-002` — Cross-process messages shall be length-bounded, schema-validated, and resilient to truncation, duplication, delay, reordering, and peer restart as applicable.

`DSS-IF-003` — An adapter shall not discard provenance, quality, freshness, ambiguity, active/sticky distinction, or evidence-gap information.

`DSS-IF-004` — Interface failure shall remain isolated and shall create typed service evidence.

`DSS-IF-005` — Public interfaces shall not expose internal pointers, paths, memory layouts, raw credentials, or undocumented device operations.

`DSS-IF-006` — Interface conformance shall be verified independently from end-to-end functional tests.

# 38. Schema, Policy, and Compatibility Versioning

## 38.1 Independent Version Axes

| Axis | Owner |
|---|---|
| Dragon Core product and register-map revisions | Controlling technical specifications |
| Generated host bindings and Dragon SDK | Governing software build |
| Device-service interface | Device-service software package |
| Sentinel executable and component APIs | Dragon Sentinel release |
| Observation, alert, audit, policy, and export schemas | Dragon Sentinel schema package |
| Rule sets and deployment policy | Controlled rule and policy baselines |
| Platform profile | Deployment package |

## 38.2 Requirements

`DSS-VER-001` — Independent version axes shall not be collapsed into one version number.

`DSS-VER-002` — Every release shall contain an explicit compatibility matrix for supported combinations.

`DSS-VER-003` — Unknown major schema or service versions shall reject; unknown optional minor content may be ignored only when the governing schema explicitly permits it.

`DSS-VER-004` — Stored records shall retain their original schema and interpretation identities and shall not be silently rewritten on read.

`DSS-VER-005` — Migration shall be explicit, reversible or recoverable, integrity-checked, and independently verified against source records.

`DSS-VER-006` — Rule or policy changes shall begin a new interpretation epoch and shall preserve the prior version for audit and reproduction.

# 39. Software Verification and Validation

## 39.1 Verification Levels

| Level | Principal subjects |
|---|---|
| Unit | State transitions, policy validation, normalization, freshness, anomaly rules, alert lifecycle, and persistence encoding |
| Component | Southbound client, collectors, watchdog coordinator, store, rule engine, publisher, security, and administration |
| Integration | Device-service doubles, independent device model, storage, identity, and alert consumers |
| Host conformance | Typed operations and exact device-boundary behavior using controlling host-verification evidence |
| FPGA/HIL | ECP5 UUT, representative host, interrupts, reset, event pressure, timing, failure, and recovery |
| System | Long-duration supervision, overload, redundancy, deployment, upgrade, rollback, and evidence export |

## 39.2 Mandatory Verification Subjects

Verification shall cover:

- all Sentinel states and every legal and rejected transition;
- independent device-state qualifiers and active/sticky distinctions;
- startup, compatibility, read-before-modify, reset, reconnect, and device replacement;
- watchdog window scheduling, margin, suspension, ambiguity, lease loss, and failover;
- interrupt storms, simultaneous sources, event-store pressure, source loss, overwrite, empty retrieval, and persistence failure;
- monitoring validity, stale data, contradiction, configuration epochs, and derived assessment labels;
- fault, interlock, lost-link, safety-output, natural, injected, active, latched, requested, commanded, effective, and inhibited distinctions;
- host-side anomaly qualification, hysteresis, missing inputs, rule failure, and recovery;
- alert acknowledgement, suppression, routing failure, escalation, recovery, and closure;
- queue capacity, backpressure, shedding, coalescing, gaps, and loss evidence;
- authentication, authorization, malformed input, replay, integrity, secrets, and least privilege;
- crash, restart, corrupt checkpoint, migration, storage exhaustion, backup restore, and audit completeness; and
- release identity, compatibility, installation, update, rollback, and reproduction.

## 39.3 Verification Requirements

`DSS-VV-001` — Verification shall conform to `RCA-DFC-SW-005` and shall consume rather than redefine applicable `RCA-DFC-VP-002` cases and evidence.

`DSS-VV-002` — Expected results shall derive from controlling specifications, independent models, and explicit Sentinel requirements, not from reusing implementation decision logic.

`DSS-VV-003` — Tests shall be deterministic where required, self-checking, repeatable, configuration-controlled, and traceable to unique requirement identifiers.

`DSS-VV-004` — Fault injection shall distinguish injected host failures, injected device test evidence, and natural device conditions.

`DSS-VV-005` — Timing verification shall measure worst-case loaded execution with instrumentation whose effect is characterized.

`DSS-VV-006` — No production release shall rely solely on simulation for watchdog scheduling, process restart, persistent durability, device interrupt integration, or failover behavior applicable to its profile.

`DSS-VV-007` — Verification shall demonstrate that Sentinel loss or failure does not prevent configured Dragon Core autonomous supervision.

# 40. Traceability and Change Control

## 40.1 Trace Model

Each Sentinel requirement shall trace upward to one or more governing software or controlling boundary needs where applicable and downward to design, implementation, verification, result evidence, and release configuration items. This derived trace does not alter the normative controlling RTM.

## 40.2 Required Trace Links

| Source group | Minimum governing relationship |
|---|---|
| `DSS-PUR`, `DSS-SCOPE`, `DSS-BND` | Charter external-host model, PBIO ownership, and `SW-SENT-001` through `SW-SENT-005` |
| `DSS-OBS`, `DSS-ASSESS`, `DSS-EVID`, `DSS-MON`, `DSS-SAFE` | SRS external behavior, Architecture evidence contracts, Register Map, and typed SDK |
| `DSS-WDOG`, `DSS-RECON`, `DSS-REC` | SRS watchdog and reconciliation behavior, Architecture recovery contracts, and typed API |
| `DSS-SEC`, `DSS-AUD`, `DSS-PERS`, `DSS-AVL` | PBIO external ownership and governing software standards |
| `DSS-VV` | Software V&V specification and applicable controlling Verification Plan evidence |

## 40.3 Requirements

`DSS-TRACE-001` — Every normative requirement identifier in this specification shall be unique and shall have implementation and verification disposition before release.

`DSS-TRACE-002` — A trace link shall identify the owning source and shall not copy its normative content as a competing definition.

`DSS-TRACE-003` — Changes to a controlling device fact shall enter Sentinel only through updated controlling sources, generated bindings, compatibility data, and approved software change control.

`DSS-TRACE-004` — A discovered controlling-specification defect shall be raised against the owning document and shall block dependent Sentinel baselining until resolved.

`DSS-TRACE-005` — Requirement, design, code, test, evidence, defect, waiver, tool, dependency, and release links shall be configuration-controlled.

# 41. Build, Package, Deployment, and Release

## 41.1 Required Packages

| Package | Required content |
|---|---|
| Runtime | Sentinel executable, approved libraries, platform adapters, and service definitions |
| Schema | Policy, observation, alert, audit, administration, and export schemas |
| Rules and defaults | Approved base rule set and safe inactive example configuration without deployment secrets |
| Platform | Profile-specific service manager, resource limits, permissions, storage, logging, and update integration |
| Development | Public internal APIs, stubs, examples, and diagnostics needed by authorized developers |
| Verification | Tests, doubles, fixtures, configurations, expected results, coverage, and evidence tools |
| Documentation | Installation, configuration, operation, administration, recovery, security, interface, and release guidance |

## 41.2 Release Requirements

`DSS-REL-001` — Build and release shall conform to `RCA-DFC-SW-006`.

`DSS-REL-002` — Builds shall be reproducible from controlled source, dependencies, generators, schemas, rules, toolchains, and build instructions.

`DSS-REL-003` — Release manifests shall identify supported device, register-map, generated-binding, SDK, service, platform, schema, rule, policy, and migration relationships.

`DSS-REL-004` — Production packages shall exclude test credentials, engineering-only functions, fault injection, raw access, and unapproved diagnostic adapters.

`DSS-REL-005` — Installation and update shall verify integrity, prerequisites, storage compatibility, permissions, service identity, configuration, rollback, and post-install health before activation.

`DSS-REL-006` — Rollback shall account for schema, policy, rule, and persistent-record compatibility and shall never discard unresolved operations or evidence gaps silently.

`DSS-REL-007` — A release shall not be approved with unresolved critical requirements, failed mandatory tests, unknown compatibility, or an unverified watchdog-service path enabled by its production profile.

# 42. Deliverables and Exit Criteria

## 42.1 Required Deliverables

The Dragon Sentinel baseline shall include:

- approved source and generated artifacts;
- runtime, schema, rule, platform, verification, and documentation packages;
- public and internal interface definitions;
- policy schema and validated safe example profiles;
- security architecture, threat analysis, and credential-handling guidance;
- verification plans, procedures, independent expected results, reports, coverage, defects, and regression evidence;
- compatibility matrix, traceability data, dependency and tool manifests, and software bill of materials;
- installation, administration, operation, alert-response, recovery, failover, backup, restore, update, rollback, and evidence-export guidance; and
- signed or otherwise integrity-protected release manifest and approval record.

`DSS-DEL-001` — Deliverables shall be mutually consistent, complete, versioned, integrity-protected, and directly traceable to the approved release.

`DSS-DEL-002` — Documentation shall preserve the processor-free Dragon Core boundary and shall not instruct a user to install software inside the device or access it through undocumented means.

## 42.2 Exit Criteria

Revision A implementation release is complete only when:

1. every normative requirement has approved implementation and verification disposition;
2. all required configuration items and interfaces are baselined;
3. compatibility is demonstrated for every claimed device, service, platform, schema, and deployment profile;
4. mandatory unit, component, integration, host, FPGA/HIL, security, overload, recovery, and release tests pass;
5. worst-case watchdog-service timing is verified for every profile that enables it;
6. evidence custody, loss reporting, alert semantics, persistence, restart, migration, failover, and rollback are verified;
7. no unresolved critical or high-severity defect remains without formal approved disposition;
8. production packages contain no prohibited engineering capability or secret;
9. traceability, manifests, integrity, reproducibility, archival, and release approval are complete; and
10. every required change to a controlling specification, if later discovered, has been approved and incorporated before dependent release.

`DSS-EXIT-001` — Exit evidence shall identify the exact Sentinel release, device realization, generated definitions, service, platform, policy, rule set, schemas, fixtures, and controlling-source revisions used.

# 43. Baseline Statement

## 43.1 Baseline Declaration

This Revision A specification establishes Dragon Sentinel as a continuous external-host supervision service beneath the eight controlling Dragon Flight specifications and the governing Dragon Flight software baseline.

## 43.2 Governing Relationship

Dragon Sentinel consumes device behavior through the public Dragon SDK or authenticated device-service boundary. It does not alter the processor-free Dragon Core product boundary, create an alternate register contract, redefine hardware behavior, or supersede autonomous hardware supervision.

## 43.3 Fixed Baseline Conclusions

- Dragon Sentinel executes outside Dragon Core.
- Dragon Sentinel observes, qualifies, persists, and alerts; Dragon Core hardware owns device monitoring and safety behavior.
- Device state is based on controlling typed readback, including independent qualifiers.
- Active conditions, sticky evidence, host-side anomalies, alerts, acknowledgements, suppression, and recovery remain distinct.
- Watchdog service is optional, exclusive, policy-controlled, timing-bounded, and suspended whenever certainty is lost.
- Device evidence is preserved before any authorized destructive retrieval action.
- Ambiguous state-changing outcomes require device-level reconciliation before retry or dependent action.
- Sentinel loss or failure does not disable configured Dragon Core autonomous supervision.
- FPGA/HIL and production realizations use the same public semantic contracts; engineering-only features remain isolated.

## 43.4 Controlling-Specification Disposition

No required change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` was identified while establishing this baseline.

## 43.5 Change Control

Any later change affecting Dragon Sentinel scope, safety boundary, state model, watchdog authority, device-service contract, observation semantics, evidence custody, alert semantics, compatibility, security, verification, or release behavior shall be processed through approved configuration and change control. A change to a controlling fact shall be made first in its owning specification.

## 43.6 Approval Statement

Upon approval, this document becomes the governing Dragon Sentinel software specification for Dragon Core Revision A and remains subordinate to the eight controlling Dragon Flight specifications and the governing software architecture, API, coding, verification, and build-and-release specifications identified herein.
