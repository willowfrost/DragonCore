**DRAGON SDK™ SOFTWARE SPECIFICATION**

Document Number: RCA-DFC-SW-010  
Revision: A  
Status: Technical Baseline  
Product: Dragon Core™ Revision A  
Program: Dragon Flight™ Core ASIC Development Program  
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | 2026-08-09 | Initial Dragon SDK software baseline derived beneath the eight controlling Dragon Flight specifications | Royal Cubit Aerospace |

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
5. Dragon SDK Configuration Item Identification
6. Authority, Ownership, and Product Boundary
7. SDK Consumers and Deployment Profiles
8. Language, Build, and Runtime Environment
9. Software Architecture
10. Package and Module Organization
11. Device Context, Service, and Ownership Model
12. Public Facade and Capability Model
13. Generated Binding and Metadata Integration
14. Startup, Discovery, and Compatibility
15. SDK Lifecycle and State Model
16. Public Type and Data Model
17. Status, Result, and Completion Model
18. Transport, HAL, Driver, and Device-Service Integration
19. Lifecycle and Configuration Services
20. Observation, Interrupt, Event, and Diagnostic Services
21. Functional-Module Service Families
22. Protected, Destructive, and State-Changing Operations
23. Ambiguous-Outcome Reconciliation
24. Disconnect, Reset, and Recovery
25. Callback, Subscription, and Asynchronous Operation
26. Concurrency, Thread Safety, Reentrancy, and Cancellation
27. Memory, Resource, and Bounded-Operation Management
28. Time, Deadline, Ordering, and Freshness
29. Logging, Diagnostics, Audit, and Evidence
30. Security and Trust Boundaries
31. Language Bindings and ABI Stability
32. Portability and Platform Adaptation
33. Application and Service Integration
34. Test Support, Models, and Simulation
35. Error Handling and Degraded Operation
36. API Documentation, Examples, and Developer Guidance
37. Versioning and Compatibility
38. Software Verification and Validation
39. Traceability and Change Control
40. Build, Package, Deployment, and Release
41. Deliverables
42. Exit Criteria
43. Baseline Statement

# 1. Purpose

This specification defines Dragon SDK, the public external-host software development kit for Dragon Core Revision A. Dragon SDK packages controlled generated definitions, the approved HAL and driver interfaces, typed device and domain models, reusable lifecycle and functional services, developer documentation, safe examples, test support, and provenance needed by Dragon Flight applications and authorized integrators.

Dragon SDK executes entirely on a processor external to the fabricated Dragon Core device. Dragon Core is processor-free and contains no SDK component, firmware, operating system, executable memory, software runtime, stack, heap, or persistent software store.

This specification owns SDK package composition, public-facade policy, capability exposure, service-level objects, metadata projection, supported language bindings, application integration, documentation, examples, test support, compatibility declaration, verification, and release. It does not redefine device behavior, register semantics, SPI behavior, lower-level HAL/driver/BSP call contracts, application behavior, hardware safety authority, controlling verification cases, controlling trace relationships, RTL rules, or physical interfaces.

`DSDK-PUR-001` — Dragon SDK shall provide one controlled, typed, externally hosted software interface for authorized Dragon Core applications and services.

`DSDK-PUR-002` — The SDK shall preserve every requested, staged, active, commanded, effective, current, sticky, pending, snapshot, terminal, cached, derived, stale, and historical distinction supplied by the controlling software stack.

`DSDK-PUR-003` — The SDK shall expose device capabilities without transferring device-definition authority from the controlling specifications or generated bindings.

`DSDK-PUR-004` — The SDK shall make safe lifecycle, definitive-result, evidence-preservation, reconciliation, and reset-recovery behavior the ordinary public integration path.

# 2. Scope

## 2.1 Included Scope

This specification covers:

- canonical SDK packages, headers, libraries, metadata, schemas, documentation, examples, tools, and test support;
- public device-context construction, attachment, discovery, compatibility, lifecycle, and recovery services;
- controlled integration of generated register/status definitions and the SW-003 HAL, driver, and BSP API;
- typed configuration, observation, interrupt, event, diagnostic, databus, monitoring, safety-status, reset, and reconciliation services;
- public value, observation, command-result, evidence, capability, version, deadline, and error models;
- direct privileged in-process use and authenticated device-service client use as distinct deployment modes;
- synchronous, asynchronous, callback, subscription, cancellation, and bounded resource behavior;
- application integration for Dragon Console, Dragon Gateway, Dragon Sentinel, and future authorized consumers;
- test doubles, independent protocol fixtures, conformance support, developer guidance, verification, packaging, release, and maintenance; and
- production, engineering, FPGA/HIL, simulation, post-silicon, maintenance, and compact embedded profiles.

## 2.2 Excluded Scope

The following are excluded:

- any executable SDK component or data store inside Dragon Core;
- an ASIC-local processor, firmware, BSP, direct MMIO aperture, boot sequence, or OpenFrame-supplied host interface;
- redefinition of a register, field, access class, encoding, reset value, capacity, state, timing limit, side effect, or hardware response;
- redefinition of SW-003 public HAL, driver, or BSP function contracts;
- Dragon Console user workflows, Dragon Gateway northbound protocol behavior, or Dragon Sentinel supervision and alert behavior;
- aircraft control, installation policy, calibration authority, certification basis, or physical energy control;
- unrestricted production raw-register, production-test, scan, fault-injection, RTL-hierarchical, wrapper-private, arbitrary-memory, or shared-buffer access; and
- ownership of operating-system services, hardware controllers, wiring, electrical adaptation, transceivers, external storage infrastructure, or network infrastructure.

## 2.3 Intended Use

Dragon SDK is intended to be the sole supported application-facing software kit for Dragon Core integrations. Applications may use it through an authenticated device service or, in a compact trusted deployment, as an in-process component sharing a process with the exclusive device owner. Both modes shall preserve identical typed semantics, lifecycle rules, result classifications, and recovery behavior.

`DSDK-SCOPE-001` — Production applications shall use public Dragon SDK services and shall not construct register addresses, field masks, SPI frames, protection sequences, or response encodings.

`DSDK-SCOPE-002` — The SDK shall use only the SRS-defined host protocol and Register-Map-defined host-visible contract, consistent with `PBIO-HOST-006`.

`DSDK-SCOPE-003` — FPGA, simulation, and ASIC deployments shall use the same portable SDK semantics; platform differences shall remain below the SDK boundary.

`DSDK-SCOPE-004` — Exposure of an SDK operation shall not by itself authorize an application, user, deployment, or remote client to invoke that operation.

`DSDK-SCOPE-005` — The SDK shall not be credited as a substitute for a hardware safety responsibility assigned to Dragon Core.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and sole normative ownership of the controlling set are defined only by `RCA-DFC-CHTR-002`, Section 3.1. This table is an informative SDK-use view and creates no alternate precedence.

| Document | Dragon SDK use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product mission, exclusions, external-host model, fixed constraints, and hierarchical single-owner rules |
| `RCA-DFC-PBIO-002.md` | Device, host software, platform, security, data, safety, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior and complete external-host recovery contract |
| `RCA-DFC-ARCH-002.md` | Device-side architecture needed for typed state, workflow, evidence, and recovery interpretation |
| `RCA-DFC-REG-002.md` | Sole normative source for host-visible registers, fields, access, legality, behavior, and side effects |
| `RCA-DFC-VP-002.md` | Sole normative source for controlling verification methods, cases, outcomes, and evidence definitions |
| `RCA-DFC-RTM-002.md` | Sole normative source for relationships among controlling technical identifiers |
| `RCA-DFC-RTL-STD-002.md` | RTL implementation and structural rules; not an SDK software standard |

## 3.2 Governing Software Specifications

| Document | Governing relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | External-host software architecture and Dragon SDK allocation, including `SW-SDK-001` through `SW-SDK-005` |
| `RCA-DFC-SW-002`, Revision B | External embedded-host firmware requirements and compact-deployment services |
| `RCA-DFC-SW-003`, Revision B | Canonical HAL, driver, BSP, typed device API, lifecycle, result, concurrency, and recovery contracts |
| `RCA-DFC-SW-004`, Revision B | Software coding and implementation standard |
| `RCA-DFC-SW-005`, Revision B | Software verification and validation requirements |
| `RCA-DFC-SW-006`, Revision B | Build, package, deployment, release, manifest, integrity, and archival requirements |
| `RCA-DFC-SW-007`, Revision A | Dragon Console application peer and SDK consumer |
| `RCA-DFC-SW-008`, Revision A | Dragon Gateway application peer and SDK consumer |
| `RCA-DFC-SW-009`, Revision A | Dragon Sentinel service peer and SDK consumer |

## 3.3 Historical Reference

No historical Dragon SDK specification was supplied or used. This Revision A specification is newly derived from the controlling technical specifications and the governing software baseline.

## 3.4 Authority and Single-Definition Rules

`DSDK-DOC-001` — Dragon SDK shall apply `CHTR-DOC-001` through `CHTR-DOC-007`.

`DSDK-DOC-002` — A device fact shall be consumed from its controlling owner or generated typed binding and shall not be copied into SDK source, metadata, schemas, documentation, or examples as an alternate definition.

`DSDK-DOC-003` — SW-003 shall remain the owner of lower-level HAL, driver, BSP, typed device-function, lifecycle, result, and concurrency contracts; this specification shall own only the SDK composition and higher public-facade subjects allocated here.

`DSDK-DOC-004` — SW-007, SW-008, and SW-009 shall retain ownership of their application-specific workflows, protocols, supervision, alerts, presentation, and policy.

`DSDK-DOC-005` — If implementation or verification exposes a conflict, ambiguity, omission, unreachable behavior, or unimplementable contract, dependent work shall stop and the owning specification shall be corrected before the SDK invents a substitute.

## 3.5 Controlling-Specification Change Flags

No change to a controlling specification is required to establish this Revision A baseline.

The controlling specifications define the external-host boundary, device programming contract, active readback, evidence, transport-result, reconciliation, recovery, and verification responsibilities required by Dragon SDK. Language-binding selection, package composition, application capabilities, documentation style, supported platform profiles, and release cadence are subordinate software decisions and do not require changes to the controlling technical set.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition in this specification |
|---|---|
| Application capability | An unforgeable or policy-checked SDK authority granting a named subset of public operations for a specific device context. |
| Application context | SDK state belonging to one consumer and its authorization, subscriptions, and operation handles; distinct from the device context. |
| Binding manifest | Machine-readable provenance that identifies controlling inputs, generator, generated outputs, and compatibility scope. |
| Canonical binding | The required C17 API and data representation against which optional language bindings are verified. |
| Definitive result | A validated terminal outcome establishing success or a specific failure class for the requested operation. |
| Device context | One isolated SDK lifecycle, compatibility, command, recovery, and observation context for one physical Dragon Core instance. |
| Device service | Privileged external-host software that exclusively owns physical-device access, lifecycle, serialization, service scheduling, diagnostics, and recovery. |
| Evidence object | Immutable SDK representation of raw device evidence plus provenance and acquisition metadata. |
| Observation | Typed state with semantic class, provenance, acquisition time, freshness, validity, and quality. |
| Operation handle | Unique SDK object identifying one admitted synchronous or asynchronous request and its lifecycle. |
| Public facade | Stable application-facing SDK surface composed of typed services, models, capabilities, and documented results. |
| Reconciliation | Typed workflow that determines what can be proven after uncertain completion of a state-changing operation. |
| SDK direct mode | Trusted in-process deployment in which the SDK contains or calls the exclusive SW-003 device owner. |
| SDK service-client mode | Deployment in which the SDK communicates with an authenticated device service and does not own SPI or the physical device handle. |
| Semantic class | Classification such as current, sticky, snapshot, terminal, cached, derived, stale, requested, staged, active, commanded, or effective. |
| Typed service | Public operation family that uses domain types and controlled workflows rather than raw register or wire values. |

ABI, API, BSP, C17, CRC, FPGA, HAL, HIL, SDK, SPI, UUT, UTC, and other device-side terms retain the definitions of their governing owners. Device units, encodings, capacities, and timing values are not redefined here.

# 5. Dragon SDK Configuration Item Identification

## 5.1 Software Configuration Items

| Configuration item | Purpose | Execution or storage location |
|---|---|---|
| `dragon_sdk_core` | Portable context, lifecycle, capability, result, metadata, service, and recovery facade | External host library or device-service process |
| `dragon_sdk_c` | Canonical C17 public headers and stable callable interface | External host application or service |
| `dragon_sdk_driver_adapter` | Controlled integration of SW-003 HAL/driver APIs into the SDK facade | Privileged direct-mode component |
| `dragon_sdk_service_client` | Authenticated typed client for an external Dragon device service | Unprivileged or separated application process |
| `dragon_sdk_models` | Public immutable values, observations, results, evidence, and configuration objects | SDK package |
| `dragon_sdk_generated` | Generated register/status definitions, validators, metadata, and source manifest | Generated package component |
| `dragon_sdk_services` | Reusable lifecycle, configuration, observation, interrupt, event, diagnostic, databus, and recovery services | SDK package |
| `dragon_sdk_test_support` | Deterministic doubles, fixtures, matchers, clocks, failure injection, and conformance helpers | Verification package; excluded from production runtime |
| `dragon_sdk_examples` | Safe, buildable, nonnormative integration examples | Developer package |
| `dragon_sdk_docs` | API reference, integration guides, migration guides, and compatibility matrix | Developer and release package |
| `dragon_sdk_tools` | Manifest, schema, binding, compatibility, and package-validation utilities | Build or developer host |

## 5.2 Identification Requirements

`DSDK-CI-001` — Every SDK configuration item shall have a unique name, semantic version, source revision, build identity, integrity value, license declaration, and compatibility declaration.

`DSDK-CI-002` — Every loaded SDK instance shall be able to report SDK release, canonical ABI version, binding-manifest identity, service-schema version when applicable, deployment profile, device-service version when applicable, and discovered device identity as independent values.

`DSDK-CI-003` — Production, engineering, FPGA/HIL, simulation, and test-support artifacts shall be distinguishable by package identity and runtime profile.

`DSDK-CI-004` — An unidentified, mixed-manifest, modified, or incompatible component shall prevent state-changing SDK service admission.

`DSDK-CI-005` — Release identity shall accompany SDK-created evidence and diagnostic exports sufficient to reproduce their interpretation.

# 6. Authority, Ownership, and Product Boundary

## 6.1 Responsibility Allocation

| Subject | SDK responsibility | Authority retained elsewhere |
|---|---|---|
| Device behavior and register meaning | Consume and expose typed projections | Controlling SRS, Architecture, and Register Map |
| Physical transport | Invoke approved driver or service client | SW-003 driver/BSP and host platform owner |
| Public package composition | Define and maintain | This specification |
| Lower-level call semantics | Re-export or adapt without semantic change | SW-003 |
| Application authorization | Enforce supplied capability decision | Deployment security-policy owner |
| Configuration policy | Validate representability and execute typed plan | Application or installation owner |
| Persistence | Supply serializable objects and provenance | External application, service, and storage owner |
| Hardware safety response | Observe and report | Dragon Core and external physical-safety owners |
| Application behavior | Provide reusable primitives | SW-007, SW-008, SW-009, or future application owner |
| Conformity evidence | Produce software evidence | SW-005 and controlling VP retain verification authority |

## 6.2 Boundary Requirements

`DSDK-BND-001` — The SDK shall execute entirely outside the fabricated Dragon Core device.

`DSDK-BND-002` — In service-client mode, the SDK shall not possess the physical-device handle, SPI-controller handle, host-interrupt handle, or command serializer.

`DSDK-BND-003` — In direct mode, one trusted SDK/device-service composition shall be the exclusive physical-device and command-serialization owner for each device context.

`DSDK-BND-004` — The SDK shall not expose RTL ports, hierarchy, physical shared-buffer addresses, wrapper-private state, or undocumented platform paths.

`DSDK-BND-005` — Host absence, SDK failure, or application failure shall not suppress or transfer a hardware safety obligation, consistent with `PBIO-HOST-008`.

# 7. SDK Consumers and Deployment Profiles

## 7.1 Consumer Classes

| Consumer | Normal SDK use |
|---|---|
| Dragon Console | Engineering, maintenance, bring-up, validation, guided command, and evidence workflows |
| Dragon Gateway | Authenticated southbound typed operations and observations for external integration |
| Dragon Sentinel | Continuous observation, evidence retrieval, authorized service, and recovery coordination |
| Embedded host firmware | Compact deterministic device service and application integration |
| Verification client | Controlled test execution, observation, and evidence acquisition |
| Future application | Capability-limited typed integration approved under change control |

## 7.2 Deployment Profiles

| Profile | Required boundary |
|---|---|
| Hosted service client | Application SDK communicates with an authenticated device service; no SPI access |
| Compact trusted embedded | SDK and exclusive device service may share an executable while logical boundaries remain distinct |
| FPGA/HIL validation | Common SDK plus approved validation BSP/service, UUT profile, and verification support |
| Post-silicon bring-up | Common SDK plus production-host BSP and bounded engineering profile |
| Production safe | Least-privilege capabilities; engineering raw access and test support absent |
| Simulation | Deterministic service or device double with explicit simulated identity |

## 7.3 Profile Requirements

`DSDK-PROF-001` — A consumer shall declare its SDK profile and requested capability set before state-changing services become available.

`DSDK-PROF-002` — Profile selection shall be explicit, immutable for an open application context, and included in diagnostics and evidence.

`DSDK-PROF-003` — Engineering, test, or simulation capability shall never be enabled by an absent configuration value, failed identity check, or compatibility fallback.

`DSDK-PROF-004` — A production package shall omit or make unreachable engineering raw access, test doubles, fault injection, and production-test authorization helpers.

# 8. Language, Build, and Runtime Environment

## 8.1 Canonical Environment

The canonical SDK binding shall be portable ISO/IEC 9899:2018 C17. It shall use fixed-width types, explicit byte-order conversion, caller-visible deadlines, documented ownership, and controlled allocation. Optional C++ or other language bindings may be supplied only as verified adapters over the canonical semantics.

## 8.2 Runtime Requirements

`DSDK-ENV-001` — The SDK core shall not require an operating system, filesystem, network stack, heap, exception runtime, dynamic loader, or floating-point unit unless a selected profile explicitly declares that dependency.

`DSDK-ENV-002` — Hosted integrations shall isolate operating-system, IPC, TLS, persistence, and credential dependencies in approved adapters outside the portable core.

`DSDK-ENV-003` — Every target shall define integer widths, alignment, endianness, atomic support, monotonic time, lock behavior, and allocation policy at build or context construction time.

`DSDK-ENV-004` — Public structures crossing an ABI or persistence boundary shall not depend on compiler padding, host word size, enum representation, or native endianness.

`DSDK-ENV-005` — The SDK shall conform to `RCA-DFC-SW-004` and shall be built and released under `RCA-DFC-SW-006`.

# 9. Software Architecture

## 9.1 Logical Components

| Component | Responsibility |
|---|---|
| Public facade | Stable capability-scoped API and lifecycle entry points |
| Context manager | Application and device context identity, state, ownership, and teardown |
| Service catalog | Typed lifecycle, configuration, observation, functional, evidence, and recovery services |
| Model layer | Immutable public values, metadata, observations, results, and evidence |
| Compatibility engine | Binding selection, version/capability evaluation, and access gating |
| Driver adapter | Direct-mode use of SW-003 typed driver APIs |
| Service client | Authenticated service-mode request, response, subscription, and reconnect mapping |
| Generated layer | Exact definitions, validators, names, units, access metadata, and provenance |
| Async dispatcher | Bounded completion, observation, and callback delivery outside command locks |
| Diagnostic recorder | Structured SDK-side records, metrics, and provenance |

## 9.2 Dependency Rules

`DSDK-ARCH-001` — Application code shall depend on the public facade and public models, not on generated register headers, BSP headers, SPI helpers, or SDK internals.

`DSDK-ARCH-002` — Public services shall depend on typed SW-003 operations or an equivalent authenticated service contract and shall not duplicate wire framing or register workflow logic.

`DSDK-ARCH-003` — Generated code shall not depend on application, policy, storage, network, user-interface, or operating-system modules.

`DSDK-ARCH-004` — Optional language bindings shall depend on the canonical facade and shall not create an alternate device workflow.

`DSDK-ARCH-005` — Logging, documentation, examples, and test support shall not become runtime authorities for device facts.

## 9.3 Failure Containment

`DSDK-ARCH-006` — Failure of one application context, subscriber, formatter, exporter, or optional binding shall not corrupt another application or device context.

`DSDK-ARCH-007` — An invariant failure shall close or quarantine the affected context and preserve the original device uncertainty and evidence references.

# 10. Package and Module Organization

## 10.1 Required Package Layout

| Package path | Controlled content |
|---|---|
| `include/dragon/` | Canonical stable public headers |
| `src/core/` | Portable facade, contexts, models, capabilities, results, and lifecycle |
| `src/services/` | Reusable typed service implementations |
| `src/adapters/driver/` | SW-003 direct-mode adapter |
| `src/adapters/service/` | Authenticated device-service client adapter |
| `generated/` | Generated definitions, validators, metadata, schemas, and manifest |
| `bindings/<language>/` | Optional verified language bindings |
| `tests/` | Unit, component, integration, compatibility, and conformance tests |
| `test_support/` | Explicitly nonproduction doubles, fixtures, clocks, and fault injection |
| `examples/` | Buildable safe examples using only public APIs |
| `docs/` | API reference, guides, migration notes, and compatibility information |
| `tools/` | Generation, manifest, ABI, schema, and package checks |

## 10.2 Organization Requirements

`DSDK-PKG-001` — Public headers shall include only public headers and explicitly approved standard headers.

`DSDK-PKG-002` — Internal headers, generated raw register definitions, service transport internals, and BSP dependencies shall not be installed as application-facing headers.

`DSDK-PKG-003` — A package shall contain exactly one binding-manifest identity and one compatible set of generated outputs.

`DSDK-PKG-004` — Generated artifacts shall be reproducible and shall fail validation if manually edited.

`DSDK-PKG-005` — Test-support and example packages shall be separable from the production runtime package.

# 11. Device Context, Service, and Ownership Model

## 11.1 Context Classes

| Context | Ownership and purpose |
|---|---|
| SDK runtime | Process-wide immutable release services and allocators |
| Application context | One consumer identity, profile, authorization, queues, and callbacks |
| Device context | One physical device identity, lifecycle generation, compatibility, observations, and operation coordination |
| Operation context | One admitted request, deadline, cancellation state, result, and evidence references |
| Subscription context | One bounded observation selection, delivery policy, sequence, and loss state |

## 11.2 Context Requirements

`DSDK-CTX-001` — Each context shall have explicit construction, validation, ownership, lifetime, and destruction rules.

`DSDK-CTX-002` — A device context shall bind to exactly one physical-device identity and one access mode for its open lifetime.

`DSDK-CTX-003` — Device reset, identity change, service-session replacement, or recovery shall increment a lifecycle generation and invalidate incompatible cached or borrowed objects.

`DSDK-CTX-004` — An application context shall not obtain a broader capability by attaching to an already privileged device context.

`DSDK-CTX-005` — Destruction shall prove that no operation, callback, subscription delivery, deferred task, or borrowed object can retain a live reference.

# 12. Public Facade and Capability Model

## 12.1 Public Service Categories

The public facade shall expose discovery, lifecycle, compatibility, configuration, observation, interrupt, event, diagnostics, monitoring, communications, routing, safety-status, reset, recovery, metadata, and software-diagnostic services as separately authorizable categories.

## 12.2 Capability Requirements

`DSDK-CAP-001` — Every state-changing public call shall require an application capability identifying the operation family, target device context, and applicable scope.

`DSDK-CAP-002` — Read, configure, clear, acknowledge, pop, push, service, reset, recover, engineering, and administration authorities shall remain distinct.

`DSDK-CAP-003` — Capability validation shall precede device access, service request creation, protected sequencing, and audit completion reporting.

`DSDK-CAP-004` — A capability shall not be inferred from a public symbol being linked, a device supporting the operation, or a caller knowing a register name.

`DSDK-CAP-005` — Public APIs shall expose typed intent and documented effect; they shall not expose unrestricted address/value writes in production profiles.

## 12.3 Facade Requirements

`DSDK-FAC-001` — Every public operation shall document preconditions, authorization, lifecycle states, deadline behavior, atomicity, side effects, completion classes, ambiguity handling, retry disposition, and postconditions.

`DSDK-FAC-002` — Optional capability absence shall be reported explicitly and shall not be normalized into success or an empty observation.

# 13. Generated Binding and Metadata Integration

## 13.1 Generated Content

Generated content may include register and field identifiers, masks, shifts, access metadata, legal values, units, signedness, capability associations, protection groups, workflow descriptors, status decoding, names, descriptions, and source trace identifiers where the controlling machine-readable source provides them.

## 13.2 Generation Requirements

`DSDK-GEN-001` — Generated outputs shall derive from the approved Register Map-controlled machine-readable source and shall identify the exact source revision and digest.

`DSDK-GEN-002` — Hand-authored SDK code shall not duplicate numeric register addresses, masks, opcodes, status values, protection values, reserved-bit rules, or device timing constants available from generated outputs.

`DSDK-GEN-003` — The generator shall reject duplicate identifiers, overlapping fields, unresolved references, unsupported access classes, inconsistent widths, and incomplete metadata required by the SDK.

`DSDK-GEN-004` — Generated public metadata shall preserve unknown values as raw values and shall not silently coerce them to a known enumeration.

`DSDK-GEN-005` — A generated-definition mismatch shall block package release and state-changing runtime access.

`DSDK-GEN-006` — Generated bindings shall be treated as derived artifacts, not as an alternate normative register specification.

# 14. Startup, Discovery, and Compatibility

## 14.1 Startup Sequence

1. Validate SDK runtime and application context configuration.
2. Establish an authenticated device-service session or construct the exclusive direct-mode SW-003 context.
3. Open compatibility-safe access and read identity, product revision, register-map revision, capability bitmap, build identity, host readiness, and initial diagnostics.
4. Select and validate the exact generated binding and service compatibility profile.
5. Establish device-context lifecycle generation and mark existing cached state invalid.
6. Read required active configuration and retained evidence without modifying device state.
7. Enable only the public services permitted by compatibility, capability, deployment profile, and authorization.

## 14.2 Compatibility Requirements

`DSDK-COMP-001` — Compatibility checks shall complete before any public state-changing service becomes available, implementing `SW-SDK-004`.

`DSDK-COMP-002` — Product revision, register-map revision, capability bitmap, device build identity, SDK version, canonical ABI version, binding identity, service-schema version, and deployment profile shall be evaluated as independent axes.

`DSDK-COMP-003` — Unknown required capability, changed field meaning, incompatible workflow, or missing generated metadata shall block the affected service.

`DSDK-COMP-004` — Partial-compatibility mode may permit explicitly tested nondestructive identity and diagnostic reads while preserving unknown raw values; it shall not permit state-changing access.

`DSDK-COMP-005` — Compatibility failure shall identify the failing axes without exposing credentials or private platform details.

# 15. SDK Lifecycle and State Model

## 15.1 Device-Context States

| State | Meaning | Permitted work |
|---|---|---|
| `NEW` | Constructed but unattached | Local validation only |
| `ATTACHING` | Transport or service session being established | Compatibility-safe operations only |
| `READ_ONLY` | Identity known; full state-changing compatibility or authorization absent | Approved nondestructive services |
| `READY` | Compatible, qualified, and available for authorized services | Capability-permitted operations |
| `RECONCILING` | An accepted state-changing outcome may be uncertain | Reconciliation and required evidence reads only |
| `RECOVERING` | Reset, disconnect, identity change, or state invalidation is being handled | Recovery workflow only |
| `DEGRADED` | Bounded service remains available with declared limitations | Explicitly allowed services |
| `CLOSING` | New work stopped; in-flight work is completing or reconciling | Teardown work only |
| `CLOSED` | Resources released and objects invalid | None |
| `FAILED` | SDK invariant or unrecoverable adapter failure | Diagnostics and destruction only |

## 15.2 Lifecycle Requirements

`DSDK-LIFE-001` — Every public operation shall declare the lifecycle states in which it is admitted.

`DSDK-LIFE-002` — Context state transitions shall be atomic, observable, and recorded with reason and lifecycle generation.

`DSDK-LIFE-003` — A reconnect shall create a new service session and requalify device identity; it shall not resume using prior assumptions.

`DSDK-LIFE-004` — `READY` shall require verified compatibility, valid access mode, and no unresolved state-changing outcome.

`DSDK-LIFE-005` — Closing a context shall not claim rollback of a command that may have been accepted.

# 16. Public Type and Data Model

## 16.1 Required Public Types

| Type family | Required content |
|---|---|
| Identity | Product, revision, map, capability, build, binding, SDK, service, and profile identities |
| Value | Exact-width raw value, signedness, unit identity, validity, and optional decoded name |
| Observation | Typed value/object, semantic class, provenance, acquisition time, freshness, quality, and lifecycle generation |
| Configuration | Desired values, field presence, schema, target constraints, policy metadata, and validation findings |
| Command result | Admission, submission, acceptance certainty, terminal class, device status, completed extent, readback, and retry disposition |
| Evidence | Raw payload, decoded fields, source identity, sequence, timestamps, loss state, and custody references |
| Deadline | Absolute monotonic deadline and explicit unit |
| Capability | Opaque authority reference and declared scope |

## 16.2 Type Requirements

`DSDK-TYPE-001` — Public numeric device values shall retain exact width, signedness, scaling, and raw representation.

`DSDK-TYPE-002` — Requested, staged, active, commanded, effective, current, sticky, pending, snapshot, terminal, cached, derived, stale, and historical values shall not share an unqualified representation.

`DSDK-TYPE-003` — Unknown enumeration and bit values shall remain representable and diagnosable.

`DSDK-TYPE-004` — Borrowed objects shall declare owner, immutability, valid lifetime, and invalidation event; owned objects shall declare release responsibility.

`DSDK-TYPE-005` — Public serialized objects shall carry schema and provenance sufficient for deterministic validation before use.

`DSDK-TYPE-006` — Presentation conversions shall preserve the authoritative raw value and identify the conversion as derived.

# 17. Status, Result, and Completion Model

## 17.1 Completion Classes

| Class | Meaning |
|---|---|
| Rejected locally | No device or service request was submitted |
| Definitive success | Validated terminal success plus required postconditions |
| Definitive failure | Validated terminal failure with known completion extent |
| Partial completion | Earlier ordered effects completed; later work did not complete |
| Ambiguous | An effect may have occurred and required proof is unavailable |
| Indeterminate | Reconciliation cannot establish a safe conclusion |
| Cancelled before submission | Cancellation proved no request was submitted |
| Cancelled after possible acceptance | Cancellation request occurred, but result requires reconciliation |

## 17.2 Result Requirements

`DSDK-RES-001` — Results shall preserve SDK status, service status when applicable, SW-003/BSP status when applicable, raw device SPI status, endpoint result, completed-word count, actual transferred extent, integrity classification, and diagnostic references without destructive normalization.

`DSDK-RES-002` — A public success shall require a definitive result and every documented postcondition, including active readback when required.

`DSDK-RES-003` — Partial completion shall identify the last definitive completed step, first failed or unresolved step, completed extent, and known active readback.

`DSDK-RES-004` — Retry disposition shall be explicit: prohibited, permitted unchanged, permitted after recovery, permitted after reconciliation, or application decision after proven no effect.

`DSDK-RES-005` — Absence of an error code, process return success, queued admission, or transport completion shall not by itself constitute device-operation success.

`DSDK-RES-006` — Result objects shall be immutable after terminal publication.

# 18. Transport, HAL, Driver, and Device-Service Integration

## 18.1 Integration Modes

| Mode | SDK lower boundary |
|---|---|
| Direct | SW-003 typed driver/HAL interface under exclusive ownership |
| Service client | Authenticated, versioned, typed device-service interface |
| Test | Deterministic SDK lower-boundary double with explicit simulated identity |

## 18.2 Integration Requirements

`DSDK-INT-001` — Direct mode shall use SW-003 APIs and shall not reproduce SPI framing, CRC, response parsing, register sequencing, protected access, or reconciliation algorithms.

`DSDK-INT-002` — Service-client mode shall preserve the same operation, observation, result, evidence, deadline, cancellation, and ambiguity semantics as direct mode.

`DSDK-INT-003` — Only the direct-mode device owner or external device service shall serialize physical commands; application-level SDK clients shall not create competing serializers.

`DSDK-INT-004` — A service boundary shall authenticate peers, authorize operations, version schemas, bind requests to device and application contexts, and preserve end-to-end correlation identifiers.

`DSDK-INT-005` — A lower-layer error shall remain attributable to platform, transport, protocol integrity, device rejection, service boundary, compatibility, or SDK policy.

`DSDK-INT-006` — The SDK shall use absolute deadlines and shall not extend a caller deadline through hidden retries, reconnects, queueing, or clock conversion.

# 19. Lifecycle and Configuration Services

## 19.1 Lifecycle Services

The SDK shall provide typed operations for context attachment, identity discovery, compatibility qualification, active-state acquisition, readiness assessment, configuration planning, authorized configuration application, active readback, operational enablement where supported, and controlled closure.

## 19.2 Configuration Requirements

`DSDK-CFG-001` — Configuration input shall be validated for syntax, schema, target identity, capability, type, range, unit, legal enumeration, cross-field constraints, unknown-field policy, authorization, and profile before device access.

`DSDK-CFG-002` — Planning shall produce an ordered, bounded, reviewable operation plan that identifies protected groups, staged/commit objects, expected side effects, readback, and rollback limitations.

`DSDK-CFG-003` — Application of a configuration plan shall stop on first failure or ambiguity unless the controlling workflow requires completion of an already accepted atomic commit.

`DSDK-CFG-004` — Every changed active object shall be read back and compared with the approved desired object before success is reported.

`DSDK-CFG-005` — Desired configuration, staged configuration, active configuration, and externally persisted configuration shall remain distinct.

`DSDK-CFG-006` — The SDK shall not clear unrelated sticky evidence, counters, interrupts, events, queues, or reconciliation state while applying configuration.

`DSDK-CFG-007` — Nondefault volatile configuration shall remain an external-host persistence and reapplication responsibility under `PBIO-HOST-004` and `PBIO-HOST-007`.

# 20. Observation, Interrupt, Event, and Diagnostic Services

## 20.1 Service Families

| Service | Required semantic behavior |
|---|---|
| Observation | Read typed current, active, sticky, counter, queue, and status objects with provenance |
| Interrupt | Read raw, enabled, pending, primary, and aggregate state; acknowledge and clear distinctly |
| Event | Snapshot, decode, hand off, persist, and pop through distinct bounded operations |
| Diagnostic | Read current state, sticky evidence, counters, loss, reset/clock evidence, and reconciliation records distinctly |
| Timestamp | Preserve raw device time, correlated time, host acquisition time, and uncertainty separately |

## 20.2 Service Requirements

`DSDK-OBS-001` — Every returned observation shall identify whether it is current, sticky, snapshot, terminal, cached, derived, or stale, implementing `SW-SDK-002`.

`DSDK-OBS-002` — Interrupt acknowledgement, interrupt-source clear, device evidence clear, fault clear, event pop, queue operation, and host-controller acknowledgement shall remain distinct calls and result types.

`DSDK-OBS-003` — Event retrieval shall preserve the raw event record and decoded fields, and shall report device-side loss separately from SDK, service, transport, subscriber, or persistence loss.

`DSDK-OBS-004` — Destructive pop or clear shall occur only after the caller-selected handoff or custody precondition has succeeded.

`DSDK-OBS-005` — A broad clear-all convenience function shall not be present in the production public facade.

`DSDK-OBS-006` — Deferred interrupt service shall be bounded, shall reread pending device state before host-side unmask, and shall dispatch application notifications outside command locks.

# 21. Functional-Module Service Families

## 21.1 Required Service Families

The SDK shall provide capability-scoped typed services, as supported by the discovered device, for timestamp; GPIO; rotor RPM; engine RPM; pulse/frequency measurement; sensor monitor; system health; watchdog; fault manager; interlock engine; lost-link supervisor; safety outputs; ARINC 429 receive and transmit; Classical CAN; UART; databus routing; mask-defined user logic; and user-configurable routing.

## 21.2 Module-Service Requirements

`DSDK-MOD-001` — Each service family shall expose the SW-003 typed contract without copying or changing its register, workflow, result, and evidence semantics.

`DSDK-MOD-002` — Channel, route, source, destination, fault, interrupt, and other finite identifiers shall be validated against generated capability metadata before submission.

`DSDK-MOD-003` — Raw hardware values shall remain available alongside any derived engineering or presentation value.

`DSDK-MOD-004` — Commanded state, effective state, external physical state, active condition, and retained evidence shall remain distinct wherever applicable.

`DSDK-MOD-005` — Revision A mask-defined user logic shall remain inert except for the identity, status, and diagnostic mailbox operations allowed by the controlling contract.

`DSDK-MOD-006` — User-configurable routing shall be described and exposed only as finite predefined routing, never as field-programmable logic.

`DSDK-MOD-007` — Safety-output services shall not imply ownership of external drivers, loads, actuators, or aircraft energy.

# 22. Protected, Destructive, and State-Changing Operations

## 22.1 Controlled Operation Classes

Protected writes, staged commits, clears, acknowledgements, pops, pushes, watchdog service, reset requests, recovery commands, routing activation, safety-output commands, and communication transmissions are separate controlled classes.

## 22.2 Operation Requirements

`DSDK-CMD-001` — Every state-changing operation shall document authorization, atomicity, ordered partial completion, side effects, evidence impact, ambiguity handling, recovery, and required readback, implementing `SW-SDK-003`.

`DSDK-CMD-002` — Protected and staged workflows shall execute under exclusive command ownership without interleaving.

`DSDK-CMD-003` — A destructive request shall identify the exact target object or mask and the evidence or data that can change.

`DSDK-CMD-004` — Reserved bits, unsupported capabilities, illegal combinations, and unknown required fields shall be rejected before submission while preserving device enforcement as authoritative.

`DSDK-CMD-005` — Multiword operations shall be represented as ordered and non-atomic unless the Register Map defines an explicit atomic staging/commit object.

`DSDK-CMD-006` — A public convenience operation shall not conceal multiple independently failing device operations; its result shall expose the complete plan and per-step outcomes.

`DSDK-CMD-007` — No SDK component shall automatically repeat a state-changing command after possible device acceptance.

# 23. Ambiguous-Outcome Reconciliation

## 23.1 Entry Conditions

Reconciliation is required after response loss, response truncation, invalid response integrity, uncertain controller termination, service disconnection after admission, process interruption after possible submission, cancellation after possible acceptance, reset during an operation, or any lower-layer ambiguous classification.

## 23.2 Reconciliation Requirements

`DSDK-REC-001` — An affected device context shall enter `RECONCILING` before later ordinary state-changing work is admitted.

`DSDK-REC-002` — The SDK shall invoke the SW-003 or device-service reconciliation operation and obtain applicable terminal record, active readback, current state, sticky evidence, counters, and diagnostics.

`DSDK-REC-003` — Reconciliation shall classify the outcome as no effect proven, complete, partial, rejected, ambiguous, or indeterminate and shall preserve all supporting evidence references.

`DSDK-REC-004` — A request may be repeated only when the lower-layer retry disposition and active-state proof establish that duplication cannot occur.

`DSDK-REC-005` — An unresolved or indeterminate outcome shall block dependent state-changing work and require caller-visible disposition.

`DSDK-REC-006` — Idempotency keys, application request identifiers, IPC acknowledgement, and process-local state shall not substitute for device-level host reconciliation.

`DSDK-REC-007` — Reconciliation shall not clear evidence, reset the device, or reapply configuration before required pre-recovery evidence is captured.

# 24. Disconnect, Reset, and Recovery

## 24.1 Recovery Triggers

Recovery shall begin after device reset evidence, readiness loss, identity change, transport replacement, device-service session loss, SDK restart, lifecycle-generation mismatch, active-readback inconsistency, or unresolved operation completion.

## 24.2 Recovery Sequence

1. Stop new ordinary work and mark affected observations stale.
2. Complete or reconcile the in-flight operation where possible.
3. Reestablish the lower-layer connection and rediscover identity and readiness.
4. Revalidate compatibility, capability, binding, profile, and authorization.
5. Capture current state, reset evidence, diagnostics, retained evidence, and terminal reconciliation data nondestructively.
6. Compare active volatile configuration with approved desired configuration.
7. Reapply lost nondefault volatile configuration through ordinary typed workflows when policy authorizes it.
8. Reestablish interrupt, event, queue, subscription, watchdog, and application services.
9. Verify required postconditions before returning the context to `READY`.

## 24.3 Recovery Requirements

`DSDK-RCV-001` — Reconnect shall never presume that the device reset, remained configured, or retained process-local state.

`DSDK-RCV-002` — Reset shall not be used as a general-purpose retry, ambiguity eraser, or substitute for reconciliation.

`DSDK-RCV-003` — Recovery shall preserve pre-reset and post-reset evidence as separately identified records.

`DSDK-RCV-004` — Reapplied configuration shall be validated and actively read back before dependent services resume.

`DSDK-RCV-005` — Application contexts shall receive explicit lifecycle-generation change and subscription-gap notifications.

`DSDK-RCV-006` — Recovery failure shall leave the context `DEGRADED` or `FAILED` with an exact service-availability declaration.

# 25. Callback, Subscription, and Asynchronous Operation

## 25.1 Asynchronous Objects

| Object | Required properties |
|---|---|
| Operation handle | Unique ID, lifecycle generation, deadline, state, result, cancellation status |
| Completion callback | Immutable result, declared context, bounded execution policy |
| Subscription | Typed selection, capacity, delivery mode, sequence, freshness, loss policy |
| Observation batch | Immutable ordered items, source range, gap metadata, ownership |

## 25.2 Requirements

`DSDK-ASYNC-001` — Asynchronous admission shall return a unique operation handle and shall not be reported as device success.

`DSDK-ASYNC-002` — Callbacks shall execute outside device command, context-state, subscription, and allocator locks.

`DSDK-ASYNC-003` — A callback shall not recursively perform a device transaction; it may enqueue later work through a documented application mechanism.

`DSDK-ASYNC-004` — Subscription queues shall be bounded and shall expose sequence gaps, drops, coalescing, staleness, and closure explicitly.

`DSDK-ASYNC-005` — Unsubscribe shall define whether an already executing callback may complete and shall prevent later delivery after its documented completion point.

`DSDK-ASYNC-006` — Slow or failed subscribers shall not block device service, reconciliation, evidence custody, or other subscribers beyond their assigned budgets.

# 26. Concurrency, Thread Safety, Reentrancy, and Cancellation

## 26.1 Concurrency Model

Public functions shall be thread-safe for distinct contexts. Calls affecting one device context shall be serialized, scheduled, or rejected according to their operation class. Protected, staged, snapshot, selector, reconciliation, reset, and recovery workflows are noninterleavable.

## 26.2 Requirements

`DSDK-CON-001` — Lock order, ownership, recursion policy, wait policy, and maximum hold expectations shall be documented and verified.

`DSDK-CON-002` — No SDK lock shall be held across application callback, logging sink, persistence sink, authentication service, network wait, or unbounded allocation.

`DSDK-CON-003` — Cancellation shall be classified as before submission, after submission but before proven acceptance, after possible acceptance, or after terminal completion.

`DSDK-CON-004` — Cancellation after possible acceptance shall enter reconciliation and shall not claim rollback.

`DSDK-CON-005` — Context closure shall stop admission, drain or cancel queued work, complete or reconcile in-flight work, stop delivery, and invalidate borrowed objects in a defined order.

`DSDK-CON-006` — Priority policy shall prevent bulk observation, export, or low-priority application work from starving reconciliation or bounded safety-relevant evidence service.

# 27. Memory, Resource, and Bounded-Operation Management

## 27.1 Managed Resources

Managed resources include contexts, operation slots, command queues, result objects, observation storage, callback entries, subscription queues, decoder workspaces, generated metadata, service-client buffers, diagnostic records, and optional caches.

## 27.2 Requirements

`DSDK-MEM-001` — Every collection, queue, batch, drain, retry, wait, callback list, and service loop shall have an explicit bound or caller-supplied deadline.

`DSDK-MEM-002` — The SDK shall support caller-supplied or profile-bounded storage for embedded deployments.

`DSDK-MEM-003` — Allocation failure shall not corrupt context state, lose an admitted operation result, or clear device evidence.

`DSDK-MEM-004` — Secrets shall not be copied into general diagnostics, result objects, examples, core dumps, or reusable buffers.

`DSDK-MEM-005` — Cache entries shall carry lifecycle generation, acquisition time, semantic class, source, and invalidation reason.

`DSDK-MEM-006` — Resource exhaustion shall degrade optional caching, formatting, or bulk delivery before reconciliation and essential evidence handling, subject to deployment policy.

# 28. Time, Deadline, Ordering, and Freshness

## 28.1 Time Domains

The SDK shall distinguish host monotonic time, host civil time, raw device timestamp, correlated device timestamp, service-receipt time, application-delivery time, and external-source time.

## 28.2 Requirements

`DSDK-TIME-001` — Deadlines shall be absolute monotonic values with explicit units and overflow-safe arithmetic.

`DSDK-TIME-002` — One caller deadline shall bound queue wait, service call, driver work, reconciliation allowed by the call, callback completion policy, and cleanup as documented.

`DSDK-TIME-003` — Freshness shall be computed from declared source and acquisition metadata and shall not be inferred solely from cache presence.

`DSDK-TIME-004` — Raw device timestamps shall remain unmodified; host correlation and civil-time presentation shall be separate derived fields.

`DSDK-TIME-005` — Ordering claims shall identify their domain: device event sequence, accepted-command sequence, service sequence, SDK delivery sequence, or application receipt order.

`DSDK-TIME-006` — Clock discontinuity, correlation uncertainty, and unavailable time shall be represented explicitly rather than replaced with zero or current host time.

# 29. Logging, Diagnostics, Audit, and Evidence

## 29.1 Record Classes

| Record | Minimum content |
|---|---|
| SDK diagnostic | Severity, component, context, operation, lifecycle generation, time, code, and correlation |
| Operation audit | Caller identity reference, capability, request summary, admission, result, readback, and evidence references |
| Compatibility record | Independent version axes, capability evaluation, profile, and disposition |
| Recovery record | Trigger, prior state, reconciliation, rediscovery, reapplication, gaps, and final state |
| Evidence export | Raw data, decoded form, provenance, custody, loss state, and release identities |

## 29.2 Requirements

`DSDK-LOG-001` — SDK diagnostics shall remain distinct from device diagnostics and shall not fabricate a hardware fault, event, or counter.

`DSDK-LOG-002` — Records shall preserve correlation among application request, operation handle, service request, SW-003 command result, accepted-command sequence when available, reconciliation, readback, and exported evidence.

`DSDK-LOG-003` — Redaction shall remove or replace sensitive external context without altering raw Dragon Core evidence fields.

`DSDK-LOG-004` — Logging failure shall be reported separately and shall not transform a failed or ambiguous device operation into success.

`DSDK-LOG-005` — Audit and evidence export shall use versioned schemas and integrity metadata.

`DSDK-LOG-006` — The SDK shall expose software-side queue loss, callback overrun, persistence refusal, service disconnect, and stale-cache metrics separately from device-side loss evidence.

# 30. Security and Trust Boundaries

## 30.1 Trust Boundaries

Dragon Core protected-operation and production-test mechanisms are bounded hardware controls, not user authentication, cryptographic identity, secure boot, key storage, or an on-device software trust boundary, consistent with `PBIO-SEC-001` through `PBIO-SEC-003`.

## 30.2 Requirements

`DSDK-SEC-001` — External host and deployment owners shall provide authentication, authorization policy, credential storage, process isolation, network security, secure persistence, and physical access control.

`DSDK-SEC-002` — The SDK shall enforce least-privilege application capabilities in addition to, and not as a replacement for, device enforcement.

`DSDK-SEC-003` — In service-client mode, every request and subscription shall bind to an authenticated session, authorized device context, operation scope, and replay policy.

`DSDK-SEC-004` — Protected-operation helpers shall not describe fixed hardware authorization sequences as secrets or credential management.

`DSDK-SEC-005` — Production-test, fault-injection, simulation-control, and raw engineering capabilities shall require separate nonproduction packages, profiles, authorization, and audit.

`DSDK-SEC-006` — Public error text and diagnostic exports shall not disclose credentials, private keys, tokens, secret material, unrestricted test authorization, or private platform addresses.

`DSDK-SEC-007` — Package, binding, schema, and service-interface integrity shall be verified before activation.

# 31. Language Bindings and ABI Stability

## 31.1 Canonical and Optional Bindings

The C17 binding is canonical. Optional bindings shall translate ownership, lifetimes, exact-width values, deadlines, cancellation, capabilities, observations, results, and errors without changing semantic behavior.

## 31.2 Requirements

`DSDK-ABI-001` — SDK-owned public C symbols shall use the `dfc_sdk_` prefix. Incorporated SW-003-owned symbols shall retain their governed `dfc_` names and semantics; platform-private symbols shall not enter either public namespace.

`DSDK-ABI-002` — Public ABI objects shall use opaque handles or versioned size-tagged structures where forward-compatible extension is required.

`DSDK-ABI-003` — Optional bindings shall preserve unknown enumeration values, raw evidence, partial completion, ambiguity, retry disposition, and lifecycle generation.

`DSDK-ABI-004` — Exceptions, promises, futures, or language-specific cancellation shall map to the canonical result and reconciliation model and shall not conceal uncertain device completion.

`DSDK-ABI-005` — Binding-generated documentation and symbols shall be checked against the canonical API manifest in continuous integration.

`DSDK-ABI-006` — Removal, renaming, layout change, ownership change, or semantic change to a public element shall follow the declared compatibility and deprecation policy.

# 32. Portability and Platform Adaptation

## 32.1 Portability Model

The SDK core shall be portable across conforming external hosts. Platform SPI, host interrupt, time, locks, barriers, diagnostics, persistence, and service transport remain below declared adapters. The selected VisionFive 2/ULX3S ECP5-85F validation environment is one supported integration profile and does not define a second SDK behavior.

## 32.2 Requirements

`DSDK-PORT-001` — Platform-specific code, operating-system headers, compiler intrinsics, controller registers, and IPC/TLS implementations shall remain below approved adapter boundaries.

`DSDK-PORT-002` — Serialization shall use explicit byte order and generated accessors; casting native packed structures onto wire or persistent data is prohibited.

`DSDK-PORT-003` — The same SDK conformance suite shall run against each supported direct-mode and service-client adapter.

`DSDK-PORT-004` — FPGA validation, simulation, and production ASIC integrations shall preserve the same public types, lifecycle, results, capabilities, workflows, and recovery semantics.

`DSDK-PORT-005` — A platform variance shall be corrected in its owning BSP, service adapter, or integration artifact and shall not be hidden by changing public SDK semantics.

# 33. Application and Service Integration

## 33.1 Integration Contracts

| Consumer | SDK integration boundary |
|---|---|
| Dragon Console | Public typed services, operation results, observations, metadata, evidence, and test support |
| Dragon Gateway | Capability-limited service client, typed operations, subscriptions, and reconciliation |
| Dragon Sentinel | Long-lived observation, evidence, watchdog-service capability when authorized, and recovery notifications |
| Embedded firmware | Direct-mode facade over exclusive SW-003 device owner or local service composition |
| Verification software | Production-equivalent facade plus separately packaged test-support interfaces |

## 33.2 Requirements

`DSDK-APP-001` — Applications shall not retain borrowed SDK objects beyond their documented lifetime or lifecycle generation.

`DSDK-APP-002` — Application policy shall select among allowed SDK operations but shall not redefine device legality, encoding, timing, evidence, or safety behavior.

`DSDK-APP-003` — Gateway idempotency, Sentinel alert deduplication, and Console confirmation shall remain application mechanisms and shall not replace SDK/device reconciliation.

`DSDK-APP-004` — One application failure or disconnect shall not force another application context to lose observations or capabilities except where the shared device lifecycle requires it.

`DSDK-APP-005` — Network-facing integrations shall expose narrower application protocols and shall not mirror the SDK or register map as an unrestricted remote interface.

`DSDK-APP-006` — Application-specific persistence schemas may embed SDK objects only with their SDK schema, provenance, and compatibility identities preserved.

# 34. Test Support, Models, and Simulation

## 34.1 Test-Support Components

The SDK test package may include deterministic clocks, allocators, lower-boundary doubles, service doubles, independent protocol fixtures, scripted device models, result builders, observation matchers, controlled failure injection, record validators, and conformance clients.

## 34.2 Requirements

`DSDK-TEST-001` — Test doubles shall identify themselves as simulated and shall never be selected by production-profile fallback.

`DSDK-TEST-002` — The independent protocol oracle used to verify generated encoding or driver integration shall not reuse the implementation logic under test.

`DSDK-TEST-003` — Failure injection shall cover before admission, before submission, after possible acceptance, during response, after device completion, during readback, during reconciliation, and during callback delivery.

`DSDK-TEST-004` — Test support shall model partial completion, unknown values, capability variation, reset, identity change, stale caches, queue loss, service disconnect, and lifecycle-generation invalidation.

`DSDK-TEST-005` — A simulator or double shall not be used as the sole oracle for device conformity; controlling VP and hardware evidence retain that authority.

`DSDK-TEST-006` — Removing test-support packages and validation-only instrumentation shall not change production SDK behavior.

# 35. Error Handling and Degraded Operation

## 35.1 Error Classes

| Class | Examples | Required disposition |
|---|---|---|
| Argument/model | Null, invalid type, range, unit, schema, or ownership | Reject locally without device access |
| Authorization | Missing or insufficient capability | Reject and audit according to policy |
| Lifecycle | Closed, recovering, stale generation, incompatible state | Reject or route to recovery |
| Platform/transport | Controller, IPC, TLS, timeout, truncation, integrity | Preserve certainty; reconcile if effect may have occurred |
| Device | Access, protection, state, endpoint, resource, or command failure | Preserve exact device result and readback |
| Compatibility | Product, map, capability, binding, ABI, or schema mismatch | Gate affected services |
| Resource | Allocation, queue, callback, subscription, or storage pressure | Apply bounded degradation and report loss |
| SDK invariant | Corruption, impossible transition, ownership violation | Quarantine context and preserve evidence |

## 35.2 Requirements

`DSDK-ERR-001` — Error mapping shall preserve original lower-layer codes, raw status, completed extent, certainty, and diagnostic references.

`DSDK-ERR-002` — Read-only nondestructive operations may be retried only under bounded policy and within the original deadline.

`DSDK-ERR-003` — State-changing retry shall follow the exact definitive-result and reconciliation rules of Sections 17 and 23.

`DSDK-ERR-004` — Degraded operation shall publish the unavailable services, reason, start time, evidence gap, and recovery condition.

`DSDK-ERR-005` — An unsupported capability, unknown value, empty queue, stale observation, authorization denial, and internal error shall be distinct outcomes.

`DSDK-ERR-006` — Error handling shall not automatically clear evidence, reset the device, reapply configuration, discard raw data, or widen caller authority.

# 36. API Documentation, Examples, and Developer Guidance

## 36.1 Required Documentation

The SDK shall provide an API reference, architecture overview, quick-start guide, lifecycle guide, configuration guide, observation/evidence guide, concurrency guide, recovery guide, security guide, language-binding guide, platform integration guide, compatibility matrix, migration guide, and release notes.

## 36.2 Documentation Requirements

`DSDK-DOCS-001` — Each public symbol shall document availability, ownership, thread safety, reentrancy, lifecycle states, capability, deadline, completion, side effects, evidence effects, ambiguity, retry, and version introduced.

`DSDK-DOCS-002` — Examples shall use active readback and evidence-preserving error handling and shall not demonstrate blind retries or broad diagnostic clears, implementing `SW-SDK-005`.

`DSDK-DOCS-003` — Examples shall compile and execute against supported test support in continuous integration.

`DSDK-DOCS-004` — Documentation shall label simulated data, derived values, cached observations, application policy, and nonproduction capabilities explicitly.

`DSDK-DOCS-005` — Documentation shall not copy numeric controlling facts when a generated symbolic reference or direct controlling citation is available.

`DSDK-DOCS-006` — Migration guidance shall identify source, binary, schema, behavior, capability, and deployment impacts independently.

# 37. Versioning and Compatibility

## 37.1 Independent Version Axes

SDK release, canonical API version, canonical ABI version, optional binding version, generated-binding manifest, service protocol/schema, persistent object schema, product revision, register-map revision, capability bitmap, device build identity, platform adapter, and application version are independent.

## 37.2 Requirements

`DSDK-VER-001` — Public breaking changes require a major API version change; additive compatible changes require a minor change; behavior-preserving corrections require a patch change.

`DSDK-VER-002` — ABI compatibility shall be declared independently from source/API compatibility.

`DSDK-VER-003` — Service-client protocol negotiation shall not imply device compatibility; both shall be evaluated.

`DSDK-VER-004` — Deprecated elements shall be explicit, documented, tested, and assigned a removal version or continuing-support policy.

`DSDK-VER-005` — Unknown optional fields shall follow documented preservation/ignore rules; unknown required fields shall reject the object.

`DSDK-VER-006` — Persistent-object migration shall be explicit, validated before replacement, reversible where practical, and preserve original provenance.

`DSDK-VER-007` — Compatibility matrices shall identify tested combinations and shall not claim compatibility by filename, semantic-version range, or best effort alone.

# 38. Software Verification and Validation

## 38.1 Verification Levels

| Level | Primary objective |
|---|---|
| Static | Coding-standard, generated-source, API, ABI, schema, dependency, and security conformance |
| Unit | Models, validation, lifecycle, capability, results, errors, resources, and utilities |
| Component | Services, adapters, async delivery, reconciliation, and recovery against independent doubles |
| Integration | SDK plus SW-003 driver or authenticated device service and independent device model |
| FPGA/HIL | Common SDK against ULX3S/ECP5-85F UUT through the approved host integration |
| ASIC bring-up | Common SDK against fabricated Dragon Core through a production-host adapter |
| Application | Console, Gateway, Sentinel, and embedded-consumer conformance to SDK contracts |

## 38.2 Mandatory Verification Subjects

Verification shall cover public argument and ownership validation; every lifecycle transition; capability enforcement; binding generation and manifest matching; exact type preservation; definitive, partial, ambiguous, and indeterminate results; protected and staged workflows; observation semantics; interrupt and event distinctions; all functional service families; deadlines; cancellation; callbacks; subscriptions; concurrency; resource exhaustion; disconnect; reset; recovery; compatibility; language bindings; documentation examples; production/test isolation; and package integrity.

## 38.3 Verification Requirements

`DSDK-VV-001` — Verification shall conform to `RCA-DFC-SW-005` and shall consume rather than redefine controlling VP cases and expected outcomes.

`DSDK-VV-002` — Every normative `DSDK-*` requirement shall trace to one or more verification cases and objective evidence.

`DSDK-VV-003` — Every state-changing public operation shall have tests for local rejection, definitive success, every applicable definitive failure, each partial-completion boundary, response loss, reconciliation, forbidden retry, reset, and active readback.

`DSDK-VV-004` — Public C headers shall compile as C17 and under the supported C++ compatibility compile; optional bindings shall pass semantic conformance against the canonical binding.

`DSDK-VV-005` — FPGA/HIL validation shall satisfy applicable host-system responsibilities under `PBIO-VER-008` and record applicable controlling VP case identifiers without redefining them.

`DSDK-VV-006` — Statement, branch, and condition coverage shall be reported for the SDK core and services; uncovered defensive paths shall be justified and otherwise tested by controlled fault injection.

`DSDK-VV-007` — Verification shall distinguish SDK, binding, driver, BSP, service, application, FPGA/ASIC integration, UUT, fixture, environment, and controlling-specification causes.

# 39. Traceability and Change Control

## 39.1 Trace Model

This specification traces SDK requirements downstream to design, public symbols, source, generated artifacts, tests, evidence, documentation, and release manifests. It cites upstream controlling or governing sources but does not duplicate the controlling RTM's technical relationships.

## 39.2 Required Trace Links

| Source | Required downstream link |
|---|---|
| `DSDK-*` requirement | Component allocation, public/private interface, verification case, and evidence |
| Public API element | Owning requirement, implementation, tests, documentation, and version |
| Generated item | Controlling machine-readable source, generator version, output digest, and consistency test |
| SDK schema | Owning model requirement, compatibility policy, validator, and migration test |
| Release artifact | Source/build identity, binding manifest, verification evidence, and compatibility declaration |

## 39.3 Requirements

`DSDK-TRACE-001` — Every normative identifier shall be unique and shall resolve to an allocated implementation and verification disposition.

`DSDK-TRACE-002` — Trace shall not be inferred from filename, directory location, symbol similarity, test name, or undocumented convention.

`DSDK-TRACE-003` — A change to a public type, operation, capability, result, schema, binding, adapter, workflow, or compatibility rule shall trigger affected application, documentation, ABI, migration, security, and regression analysis.

`DSDK-TRACE-004` — A controlling-specification change shall propagate through the owning identifier, generator and bindings, SW-003 integration, SDK services, applications, tests, and releases.

`DSDK-TRACE-005` — A discovered controlling defect shall be flagged to its owner and shall not be preserved as an SDK-only alternate definition.

# 40. Build, Package, Deployment, and Release

## 40.1 Required Packages

| Package | Required content |
|---|---|
| Runtime | Canonical public headers, production libraries, required metadata, licenses, and manifest |
| Developer | Runtime plus API reference, guides, safe examples, build integration, and compatibility data |
| Service client | Authenticated service adapter and versioned schemas where deployed separately |
| Platform integration | Approved direct-mode adapter references and integration guide; BSP remains governed by SW-003 |
| Test support | Doubles, fixtures, matchers, controlled injection, and conformance tools; nonproduction only |
| Symbols/source | Debug symbols or controlled source as required by release policy |

## 40.2 Release Requirements

`DSDK-REL-001` — Build and release shall comply with `RCA-DFC-SW-006` and shall identify source, tools, dependencies, options, target, profile, SDK/API/ABI versions, generated-binding manifest, schemas, tests, and evidence.

`DSDK-REL-002` — Runtime, developer, service-client, binding, platform, and test-support packages shall declare dependencies and compatibility independently.

`DSDK-REL-003` — Production and engineering/test packages shall be separately named, signed or integrity-protected according to release policy, and noninterchangeable.

`DSDK-REL-004` — A release shall be reproducible under the controlled build environment and shall contain a dependency and license inventory.

`DSDK-REL-005` — Release shall be blocked by an unresolved generated mismatch, ABI failure, verification failure, security finding, controlling-specification flag, or undocumented public change.

`DSDK-REL-006` — Deployment shall verify package identity, integrity, compatibility, and profile before activation and shall preserve the prior approved version for rollback where platform policy permits.

`DSDK-REL-007` — Rollback shall evaluate persistent-schema, service-schema, binding, ABI, application, and device compatibility before replacing an active SDK.

# 41. Deliverables

## 41.1 Required Deliverables

The approved Dragon SDK Revision A baseline shall include:

1. canonical C17 public headers and runtime libraries;
2. SDK core, service, driver-adapter, and service-client source or controlled build inputs;
3. generated definitions, metadata, schemas, generator identity, source identity, and binding manifest;
4. optional language bindings accepted for the release;
5. API reference, architecture overview, integration, lifecycle, configuration, evidence, recovery, security, compatibility, migration, and release documentation;
6. safe buildable examples;
7. test doubles, fixtures, conformance tools, and independent oracles where applicable;
8. unit, component, integration, FPGA/HIL, binding, ABI, security, coverage, and application-conformance evidence as applicable;
9. build, dependency, compiler, option, integrity, license, compatibility, and release manifests; and
10. approved deviations, limitations, and change records.

## 41.2 Delivery Requirements

`DSDK-DEL-001` — Generated bindings and their provenance manifest are required deliverables, not disposable build intermediates.

`DSDK-DEL-002` — Delivered documentation and examples shall correspond exactly to the packaged API and profile.

`DSDK-DEL-003` — No deliverable shall contain credentials, private keys, unrestricted test authorization, undocumented production access, or hand-copied controlling constants.

`DSDK-DEL-004` — Every package shall identify required dependencies and shall fail clearly when a required dependency or compatible binding is absent.

`DSDK-DEL-005` — Only fully validated, internally consistent, release-approved artifacts shall be distributed as the baseline.

# 42. Exit Criteria

Revision A is complete only when all of the following are true:

1. all 43 sections are present and internally consistent;
2. every normative `DSDK-*` identifier is unique and traced;
3. all cited controlling and governing identifiers resolve;
4. public SDK ownership is separated from SW-003 lower-level API ownership and SW-007 through SW-009 application ownership;
5. all executable SDK components are unambiguously external to Dragon Core;
6. generated definitions match the approved controlling source and manifest;
7. compatibility gates precede state-changing service availability;
8. current, sticky, snapshot, terminal, cached, derived, stale, requested, staged, active, commanded, effective, and historical states remain distinct;
9. all state-changing APIs preserve partial completion, ambiguity, reconciliation, retry, and readback semantics;
10. direct mode and service-client mode pass the common semantic conformance suite;
11. required C17, optional binding, ABI, static-analysis, unit, component, integration, FPGA/HIL, coverage, security, documentation-example, and package tests pass as applicable;
12. production packages exclude engineering raw access, test doubles, fault injection, and unrestricted test authorization;
13. release manifests, documentation, compatibility declarations, and evidence correspond to the delivered bytes;
14. no device behavior, register meaning, verification case, trace relationship, or RTL rule is redefined here;
15. no unresolved defect, deviation, security finding, or controlling-specification change flag remains; and
16. the completed Markdown passes structure, identifier, table, reference, and terminology validation.

`DSDK-EXIT-001` — An SDK implementation release may claim conformity to this specification only when its downstream trace, verification evidence, compatibility declaration, package manifest, and applicable host-boundary outcomes pass.

# 43. Baseline Statement

## 43.1 Baseline Declaration

RCA-DFC-SW-010 Revision A is the software specification baseline for Dragon SDK supporting Dragon Core Revision A. It is the controlling subordinate specification for SDK package composition, public-facade policy, capability exposure, public service-level objects, generated-metadata integration, language bindings, documentation, examples, test support, compatibility declaration, and SDK release acceptance.

## 43.2 Governing Relationship

This specification remains subordinate to the eight controlling specifications identified by `RCA-DFC-CHTR-002`, Section 3.1, and implements the Dragon SDK architecture of `RCA-DFC-SW-001` Revision C. `RCA-DFC-SW-003` Revision B retains authority for HAL, driver, BSP, typed device API, lifecycle, result, concurrency, and recovery contracts. Application specifications retain authority for application behavior.

## 43.3 Fixed Baseline Conclusions

- Dragon Core is processor-free and contains no SDK component or executable software.
- Dragon SDK executes only on an external host and uses only the controlled host-visible contract.
- The canonical C17 facade and optional bindings preserve one semantic model.
- Generated definitions, typed SW-003 operations, service-level models, and application integrations remain separate layers.
- One exclusive device owner and command serializer exists per physical device context.
- Service-client applications do not own SPI or the physical-device handle.
- Compatibility is proven before state-changing services become available.
- State-changing operations preserve definitive result, partial completion, ambiguity, reconciliation, retry disposition, and active readback.
- Current state, retained evidence, application records, cached observations, and derived interpretation remain distinct.
- Production and engineering/test capabilities remain isolated.
- Hardware safety authority remains with Dragon Core and the applicable external physical-system owners.

## 43.4 Controlling-Specification Disposition

No change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` is required to establish this Revision A SDK baseline.

## 43.5 Change Control

Any future change to SDK package composition, public types, capabilities, service semantics, lifecycle, results, language bindings, schemas, compatibility, documentation obligations, test support, or release acceptance shall revise this specification and complete downstream impact analysis. A change requiring new device behavior, register meaning, interface behavior, verification definition, trace relationship, or RTL rule shall first revise the applicable controlling specification.

## 43.6 Approval Statement

Upon approval, this document is ready for direct placement beneath the eight controlling Dragon Flight specifications as `RCA-DFC-SW-010_Dragon_SDK_Software_Specification_RevA.md`.
